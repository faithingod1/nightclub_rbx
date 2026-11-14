--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = require(Shared:WaitForChild("GameConfig"))
local GlossyUI = require(script.Parent:WaitForChild("GlossyUI"))
local SocialPanel = {}

function SocialPanel.new(parent: GuiObject, initial: Types.ClubState, action: RemoteFunction, social: RemoteFunction,
	onVisit: (Types.ClubState, number) -> (), onHome: (Types.ClubState) -> ()): Types.SocialPanel
	local state = initial
	local visiting: number? = nil
	local busy = false
	local destroyed = false
	local cards: { Types.FriendCard } = {}
	local page = 1
	local roots: { GuiObject } = {}
	local function panel(name: string, width: number, height: number, position: UDim2, anchor: Vector2): Frame
		local frame = Instance.new("Frame")
		frame.Name, frame.Size, frame.Position, frame.AnchorPoint = name, UDim2.fromOffset(width, height), position, anchor
		frame.BackgroundColor3 = Color3.fromRGB(51, 87, 135)
		frame.ZIndex = 90010
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame
		GlossyUI.style(frame)
		frame.Parent = parent
		table.insert(roots, frame)
		return frame
	end
	local toolbar = panel("ClubFeatures", 980, 38, UDim2.new(0.5, 0, 0, 108), Vector2.new(0.5, 0))
	local friendBar = panel("FriendsBar", 980, 70, UDim2.new(0.5, 0, 1, -8), Vector2.new(0.5, 1))
	local mission = panel("CelebrityMission", 980, 48, UDim2.new(0.5, 0, 0, 152), Vector2.new(0.5, 0))
	local function label(parentGui: GuiObject, text: string, x: number, y: number, width: number, height: number): TextLabel
		local ui = Instance.new("TextLabel")
		ui.Size, ui.Position = UDim2.fromOffset(width, height), UDim2.fromOffset(x, y)
		ui.BackgroundTransparency = 1
		ui.TextColor3 = Color3.new(1, 1, 1)
		ui.Font, ui.TextSize, ui.TextWrapped = Enum.Font.GothamBold, 12, true
		ui.Text, ui.ZIndex = text, parentGui.ZIndex + 1
		ui.Parent = parentGui
		return ui
	end
	local missionText = label(mission, "", 8, 2, 964, 44)
	if social.Parent and social.Parent:GetAttribute("SessionOnly") then
		local preview = label(mission, "STUDIO PREVIEW - progress is not saved", 8, 48, 964, 20)
		preview.TextColor3 = Color3.fromRGB(255, 218, 100)
	end
	local status = label(toolbar, "", 570, 0, 400, 38)
	local function button(parentGui: GuiObject, text: string, x: number, y: number, width: number, height: number, callback: () -> ()): TextButton
		local ui = Instance.new("TextButton")
		ui.Size, ui.Position = UDim2.fromOffset(width, height), UDim2.fromOffset(x, y)
		ui.BackgroundColor3 = Color3.fromRGB(77, 130, 194)
		ui.TextColor3 = Color3.new(1, 1, 1)
		ui.Font, ui.TextSize, ui.TextWrapped = Enum.Font.GothamBold, 11, true
		ui.Text, ui.ZIndex = text, parentGui.ZIndex + 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = ui
		GlossyUI.style(ui)
		ui.Parent = parentGui
		ui.Activated:Connect(callback)
		return ui
	end
	local function request(remote: RemoteFunction, verb: string, payload: any, done: (any) -> ())
		if busy or destroyed then return end
		busy = true
		status.Text = "Loading..."
		task.spawn(function()
			local transport, ok, result = pcall(function() return remote:InvokeServer(verb, payload) end)
			busy = false
			if destroyed then return end
			if not transport then status.Text = "Connection unavailable; try again"
			elseif not ok then status.Text = tostring(result)
			else status.Text = if typeof(result) == "string" then result else ""; done(result) end
		end)
	end
	local modal = panel("GenreSelector", 420, 245, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	modal.ZIndex = 95000
	modal.Active = true
	modal.Visible = false
	label(modal, "CHOOSE YOUR DJ GENRE", 10, 10, 400, 30)
	label(modal, "Choose the sound of your club.", 20, 173, 380, 28)
	for index, genre in { "Electro", "HipHop", "SynthPop" } do
		button(modal, Config.MUSIC_GENRES[genre].Name, 20, 42 + (index - 1) * 42, 380, 36, function()
			request(action, "SetGenre", { Genre = genre }, function() modal.Visible = false end)
		end)
	end
	button(modal, "Close", 150, 207, 120, 28, function() modal.Visible = false end)
	button(toolbar, "DJ Genres", 6, 4, 102, 30, function()
		if visiting then status.Text = "Return home to change music" else modal.Visible = not modal.Visible end
	end)
	local expand: TextButton
	expand = button(toolbar, "Expand Club", 114, 4, 168, 30, function()
		if visiting then status.Text = "Return home to expand"; return end
		request(action, "ExpandClub", {}, function() end)
	end)
	button(toolbar, "Return Home", 288, 4, 118, 30, function()
		request(social, "Home", nil, function(home)
			visiting = nil
			onHome(home)
		end)
	end)
	button(toolbar, "Tip DJ $" .. Config.TIP_AMOUNT, 412, 4, 148, 30, function()
		if not visiting then status.Text = "Visit a friend's club to tip their DJ"; return end
		request(social, "Tip", visiting, function() end)
	end)
	local friendButtons: { TextButton } = {}
	local function drawFriends()
		for _, ui in friendButtons do ui:Destroy() end
		table.clear(friendButtons)
		for slot = 1, 6 do
			local friend = cards[(page - 1) * 6 + slot]
			if not friend then break end
			local ui = button(friendBar, (if friend.Online then "ONLINE" else "SAVED CLUB") .. "\n" .. friend.Name,
				125 + (slot - 1) * 128, 7, 120, 56, function()
				request(social, "Visit", friend.UserId, function(club)
					visiting = friend.UserId
					modal.Visible = false
					onVisit(club, friend.UserId)
					status.Text = "Visiting " .. friend.Name .. " (read-only snapshot)"
				end)
			end)
			table.insert(friendButtons, ui)
		end
	end
	local function refreshFriends()
		request(social, "Friends", nil, function(result)
			cards, page = result.Cards, 1
			drawFriends()
			status.Text = if result.Preview then "Studio preview - progress is not saved"
				elseif #cards == 0 then "No friends found. Invite friends on Roblox." else "Select a friend to visit their club"
		end)
	end
	button(friendBar, "FRIENDS\nRefresh", 6, 7, 80, 56, refreshFriends)
	button(friendBar, "<", 91, 7, 28, 56, function() page = math.max(1, page - 1); drawFriends() end)
	button(friendBar, ">", 910, 7, 60, 56, function() page = math.min(math.max(1, math.ceil(#cards / 6)), page + 1); drawFriends() end)
	local function fit()
		local scale = math.min(1, math.max(0.1, (parent.AbsoluteSize.X - 24) / 980))
		for _, frame in roots do
			local uiScale = frame:FindFirstChildOfClass("UIScale")
			if not uiScale then uiScale = Instance.new("UIScale"); uiScale.Parent = frame end
			uiScale.Scale = if frame == modal then math.min(1, (parent.AbsoluteSize.X - 24) / 420) else scale
		end
	end
	local resize = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	refreshFriends()
	return {
		Update = function(newState: Types.ClubState)
			state = newState
			local tier = Config.EXPANSIONS[state.GridWidth]
			expand.Text = if tier then string.format("Expand %dx%d - $%d", tier.Size, tier.Size, tier.Cost) else "Maximum size: 20 x 20"
			local visit = state.Celebrity
			if visit and visit.EndsAt > os.time() then
				missionText.Text = if visit.Rewarded then string.format("%s: mission complete! +$%d", visit.Name, visit.Reward)
					else string.format("%s | Play %s + VIP booth + stocked mocktails + active DJ set: %d/%ds | Reward $%d | %ds left",
						visit.Name, visit.Genre, visit.Progress, visit.Goal, visit.Reward, math.max(0, visit.EndsAt - os.time()))
			else missionText.Text = string.format("%s | Celebrity visit in %ds", Config.MUSIC_GENRES[state.ActiveGenre].Name, math.max(0, state.NextCelebrityAt - os.time())) end
		end,
		Destroy = function() destroyed = true; resize:Disconnect(); for _, frame in roots do frame:Destroy() end end,
	}
end
return SocialPanel
