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
	local toolbar = panel("ClubFeatures", 760, 34, UDim2.new(0.5, 40, 0, 110), Vector2.new(0.5, 0))
	local friendBar = panel("FriendsBar", 760, 54, UDim2.new(0.5, 0, 1, -6), Vector2.new(0.5, 1))

	local function label(parentGui: GuiObject, text: string, x: number, y: number, width: number, height: number): TextLabel
		local ui = Instance.new("TextLabel")
		ui.Size, ui.Position = UDim2.fromOffset(width, height), UDim2.fromOffset(x, y)
		ui.BackgroundTransparency = 1
		ui.TextColor3 = Color3.new(1, 1, 1)
		ui.Font, ui.TextSize, ui.TextWrapped = Enum.Font.GothamBold, 11, true
		ui.Text, ui.ZIndex = text, parentGui.ZIndex + 1
		ui.Parent = parentGui
		return ui
	end
	local status = label(toolbar, "", 272, 0, 380, 34)
	local previewTag = label(toolbar, if social.Parent and social.Parent:GetAttribute("SessionOnly") then "Unsaved (Studio)" else "", 652, 0, 104, 34)
	previewTag.TextColor3 = Color3.fromRGB(255, 218, 100)
	previewTag.TextSize = 10
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
	local djGenresBtn = button(toolbar, "DJ Genres", 6, 3, 90, 28, function()
		if visiting then status.Text = "Return home to change music" else modal.Visible = not modal.Visible end
	end)
	local expandBtn: TextButton
	expandBtn = button(toolbar, "Expand Club", 102, 3, 150, 28, function()
		if visiting then status.Text = "Return home to expand"; return end
		request(action, "ExpandClub", {}, function() end)
	end)
	local returnHomeBtn: TextButton
	returnHomeBtn = button(toolbar, "Return Home", 258, 3, 105, 28, function()
		request(social, "Home", nil, function(home)
			visiting = nil
			returnHomeBtn.Visible = false
			expandBtn.Visible = true
			djGenresBtn.Visible = true
			onHome(home)
		end)
	end)
	returnHomeBtn.Visible = false

	local tipDjBtn: TextButton
	tipDjBtn = button(toolbar, "Tip DJ $" .. Config.TIP_AMOUNT, 368, 3, 105, 28, function()
		if not visiting then status.Text = "Visit a friend's club to tip their DJ"; return end
		request(social, "Tip", visiting, function() end)
	end)
	tipDjBtn.Visible = false

	local friendButtons: { TextButton } = {}
	local function drawFriends()
		for _, ui in friendButtons do ui:Destroy() end
		table.clear(friendButtons)
		for slot = 1, 6 do
			local friend = cards[(page - 1) * 6 + slot]
			if not friend then break end
			local ui = button(friendBar, (if friend.Online then "ONLINE" else "SAVED CLUB") .. "\n" .. friend.Name,
				110 + (slot - 1) * 100, 4, 96, 46, function()
				request(social, "Visit", friend.UserId, function(club)
					visiting = friend.UserId
					modal.Visible = false
					returnHomeBtn.Visible = true
					tipDjBtn.Visible = true
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
			status.Text = if result.Preview then "Studio preview (unsaved)"
				elseif #cards == 0 then "No friends found. Invite friends on Roblox." else "Select a friend to visit their club"
		end)
	end
	button(friendBar, "FRIENDS\nRefresh", 4, 4, 70, 46, refreshFriends)
	button(friendBar, "<", 78, 4, 26, 46, function() page = math.max(1, page - 1); drawFriends() end)
	button(friendBar, ">", 712, 4, 42, 46, function() page = math.min(math.max(1, math.ceil(#cards / 6)), page + 1); drawFriends() end)
	local function fit()
		local scale = math.min(1, math.max(0.1, (parent.AbsoluteSize.X - 24) / 760))
		for _, frame in roots do
			local uiScale = frame:FindFirstChildOfClass("UIScale")
			if not uiScale then uiScale = Instance.new("UIScale"); uiScale.Parent = frame end
			uiScale.Scale = if frame == modal then math.min(1, (parent.AbsoluteSize.X - 24) / 420) else scale
		end
		if typeof(parent) == "Instance" then
			local topHud = parent:FindFirstChild("TopHud", true)
			if topHud and topHud:IsA("GuiObject") then
				local topY = topHud.Position.Y.Offset + topHud.Size.Y.Offset + 6
				toolbar.Position = UDim2.new(topHud.Position.X.Scale, topHud.Position.X.Offset, 0, topY)
			end
		end
	end
	local resize = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	refreshFriends()
	return {
		Update = function(newState: Types.ClubState)
			state = newState
			local tier = Config.EXPANSIONS[state.GridWidth]
			expandBtn.Text = if tier then string.format("Expand %dx%d - $%d", tier.Size, tier.Size, tier.Cost) else "Maximum size: 20 x 20"
			local visit = state.Celebrity
			if visit and visit.EndsAt > os.time() then
				status.Text = if visit.Rewarded then string.format("%s: mission complete! +$%d", visit.Name, visit.Reward)
					else string.format("%s | Play %s + VIP booth: %d/%ds | Reward $%d",
						visit.Name, visit.Genre, visit.Progress, visit.Goal, visit.Reward)
			else status.Text = string.format("%s • Celebrity in %ds", Config.MUSIC_GENRES[state.ActiveGenre].Name, math.max(0, state.NextCelebrityAt - os.time())) end
		end,
		Destroy = function() destroyed = true; resize:Disconnect(); for _, frame in roots do frame:Destroy() end end,
	}
end
return SocialPanel
