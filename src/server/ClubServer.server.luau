--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Appearance = require(Shared:WaitForChild("Appearance"))

local Remotes = Instance.new("Folder")
Remotes.Name = "ClubRemotes"
Remotes.Parent = ReplicatedStorage

local GetStateFn = Instance.new("RemoteFunction")
GetStateFn.Name = "GetClubState"
GetStateFn.Parent = Remotes

local ActionFn = Instance.new("RemoteFunction")
ActionFn.Name = "PerformClubAction"
ActionFn.Parent = Remotes

local StateUpdatedEv = Instance.new("RemoteEvent")
StateUpdatedEv.Name = "ClubStateUpdated"
StateUpdatedEv.Parent = Remotes

local PlayerClubs: { [Player]: Types.ClubState } = {}

local Rules = require(script.Parent:WaitForChild("ClubRules"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local Data = DataManager.new()
Remotes:SetAttribute("SessionOnly", Data.Preview)
local recalculateStats = Rules.recalculate
local closing = false
local Loading: { [Player]: boolean } = {}
local Visiting: { [Player]: number } = {}
local LastAction: { [Player]: number } = {}
local SocialBusy: { [Player]: boolean } = {}
local FriendCache: { [Player]: { At: number, Cards: { Types.FriendCard } } } = {}

local SocialFn = Instance.new("RemoteFunction")
SocialFn.Name = "ClubSocial"
SocialFn.Parent = Remotes

local function join(player: Player)
	if Loading[player] or PlayerClubs[player] then return end
	Loading[player] = true
	local state, message = Data.Load(player.UserId)
	if state and not Data.Preview then
		if not Data.Flush(player.UserId) then state = nil; message = "Could not safely open your saved club. Please rejoin." end
	end
	Loading[player] = nil
	if not state then
		Data.Close(player.UserId)
		player:Kick(message)
		return
	end
	if closing or player.Parent ~= Players then Data.Close(player.UserId); return end
	PlayerClubs[player] = state
end
Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do task.spawn(join, player) end
Players.PlayerRemoving:Connect(function(player: Player)
	PlayerClubs[player] = nil
	Visiting[player], LastAction[player], SocialBusy[player], FriendCache[player] = nil, nil, nil, nil
	Data.Close(player.UserId)
end)

GetStateFn.OnServerInvoke = function(player: Player): Types.ClubState?
	local deadline = os.clock() + 30
	while not PlayerClubs[player] and player.Parent == Players and os.clock() < deadline do task.wait(0.1) end
	return PlayerClubs[player]
end

local function friends(player: Player): { Types.FriendCard }
	local cached = FriendCache[player]
	if cached and os.clock() - cached.At < 60 then return cached.Cards end
	local online: { [number]: boolean } = {}
	local ok, live = pcall(function() return player:GetFriendsOnlineAsync(200) end)
	if ok then for _, friend in live do online[friend.VisitorId] = true end end
	local cards: { Types.FriendCard } = {}
	local pages = Players:GetFriendsAsync(player.UserId)
	repeat
		for _, friend in pages:GetCurrentPage() do
			table.insert(cards, { UserId = friend.Id, Name = friend.DisplayName or friend.Username, Online = online[friend.Id] == true })
		end
		if pages.IsFinished then break end
		pages:AdvanceToNextPageAsync()
	until #cards >= 1000
	table.sort(cards, function(a, b)
		if a.Online ~= b.Online then return a.Online end
		return a.Name < b.Name
	end)
	FriendCache[player] = { At = os.clock(), Cards = cards }
	return cards
end

local function social(player: Player, action: string, userId: any): (boolean, any)
	if action == "Friends" then return true, { Cards = friends(player), Preview = Data.Preview } end
	if action == "Home" then Visiting[player] = nil; return true, PlayerClubs[player] end
	if not Rules.integer(userId, 1, 1e12) or userId == player.UserId then return false, "Select a friend's club" end
	if not player:IsFriendsWithAsync(userId) then return false, "Only friends' clubs can be visited" end
	local state = Data.Read(userId)
	if not state then return false, "This friend has no available saved club yet" end
	if action == "Visit" then
		if not PlayerClubs[player] or closing then return false, "Club is closing" end
		Visiting[player] = userId
		-- Cash and cooldowns stay private; visitors get a read-only layout snapshot.
		state.Cash = 0
		state.SkillCooldowns = { RefreshSet = 0, DropTheBass = 0, MicShoutout = 0 }
		return true, state
	elseif action == "Tip" then
		if Visiting[player] ~= userId then return false, "Visit this friend's club first" end
		local hasDJ = false
		for _, item in state.PlacedItems do
			if GameConfig.ITEMS[item.ItemId].Category == "DJBooth" then hasDJ = true; break end
		end
		if not hasDJ then return false, "This club needs a DJ booth before it can receive tips" end
		local ok, message = Data.Tip(player.UserId, userId)
		if PlayerClubs[player] then StateUpdatedEv:FireClient(player, PlayerClubs[player]) end
		return ok, message
	end
	return false, "Unknown social action"
end
SocialFn.OnServerInvoke = function(player: Player, action: any, userId: any): (boolean, any)
	if typeof(action) ~= "string" or not PlayerClubs[player] or closing then return false, "Club unavailable" end
	if SocialBusy[player] or os.clock() - (LastAction[player] or -10) < 0.25 then return false, "Please wait a moment" end
	SocialBusy[player] = true
	LastAction[player] = os.clock()
	local ok, success, result = pcall(social, player, action, userId)
	SocialBusy[player] = nil
	if not ok then return false, "Roblox could not complete that request. Please try again." end
	return success, result
end

ActionFn.OnServerInvoke = function(player: Player, action: string, payload: { [string]: any }): (boolean, string)
	local state = PlayerClubs[player]
	if not state or closing then return false, "Club not initialized" end
	if Visiting[player] then return false, "Return home to manage your club" end
	if not Data.Writable(player.UserId) then return false, "Club is saving or unavailable; try again shortly" end
	if typeof(action) ~= "string" or typeof(payload) ~= "table" then return false, "Invalid request" end
	if os.clock() - (LastAction[player] or -10) < 0.15 then return false, "Please wait a moment" end
	LastAction[player] = os.clock()

	if action == "SetAppearance" then
		local selection = Appearance.validate(payload.Appearance)
		if not selection then return false, "Choose valid character options" end
		state.Appearance = selection
		StateUpdatedEv:FireClient(player, state)
		return true, "Character saved"
	elseif action == "SetGenre" then
		if typeof(payload.Genre) ~= "string" or not GameConfig.MUSIC_GENRES[payload.Genre] then return false, "Unknown genre" end
		state.ActiveGenre = payload.Genre
		StateUpdatedEv:FireClient(player, state)
		return true, "Genre selected"
	elseif action == "ExpandClub" then
		local ok, message = Rules.expand(state)
		if ok then StateUpdatedEv:FireClient(player, state) end
		return ok, message
	elseif action == "PlaceItem" then
		local itemId = tostring(payload.ItemId or "")
		local gx = tonumber(payload.GX) or -1
		local gy = tonumber(payload.GY) or -1
		local def = GameConfig.ITEMS[itemId]

		if not def then
			return false, "Invalid item"
		end
		local rot = if Rules.integer(payload.Rot, 0, 3) then payload.Rot else 0
		local fx = def.FootprintX
		local fy = def.FootprintY
		if rot % 2 ~= 0 then fx, fy = fy, fx end

		if not Rules.integer(gx, 1, state.GridWidth - fx + 1) or not Rules.integer(gy, 1, state.GridHeight - fy + 1) then
			return false, "Out of club bounds"
		end
		if state.Cash < def.Cost then
			return false, "Not enough cash"
		end
		for ix = gx, gx + fx - 1 do
			for iy = gy, gy + fy - 1 do
				for _, existing in state.PlacedItems do
					local eDef = GameConfig.ITEMS[existing.ItemId]
					local eRot = existing.Rot or 0
					local efx = if eDef then eDef.FootprintX else 1
					local efy = if eDef then eDef.FootprintY else 1
					if eRot % 2 ~= 0 then efx, efy = efy, efx end
					if ix >= existing.GX and ix < existing.GX + efx and iy >= existing.GY and iy < existing.GY + efy then
						return false, "Tile already occupied"
					end
				end
			end
		end

		state.Cash -= def.Cost
		local uid = HttpService:GenerateGUID(false)
		state.PlacedItems[uid] = { Uid = uid, ItemId = itemId, GX = gx, GY = gy, Rot = rot }
		recalculateStats(state)
		StateUpdatedEv:FireClient(player, state)
		return true, "Placed"

	elseif action == "RestockMocktails" then
		local needed = state.MaxMocktailStock - state.MocktailStock
		if needed <= 0 then
			return false, "Bar is already full"
		end
		local cost = needed * GameConfig.RESTOCK_COST_PER_UNIT
		if state.Cash < cost then
			return false, "Not enough cash to restock"
		end
		state.Cash -= cost
		state.MocktailStock = state.MaxMocktailStock
		StateUpdatedEv:FireClient(player, state)
		return true, "Restocked"

	elseif action == "TriggerDJSkill" then
		if typeof(payload.Skill) ~= "string" or not GameConfig.DJ_SKILLS[payload.Skill] then return false, "Unknown DJ skill" end
		local skill = payload.Skill :: Types.DJSkillId
		local now = os.time()
		local readyAt = state.SkillCooldowns[skill] or 0
		if now < readyAt then
			return false, "Skill on cooldown"
		end

		if skill == "RefreshSet" then
			local cfg = GameConfig.DJ_SKILLS.RefreshSet
			if state.Cash < cfg.Cost then
				return false, "Need cash for DJ set"
			end
			state.Cash -= cfg.Cost
			state.DJSetEndsAt = now + cfg.SetDurationSec
			state.SkillCooldowns.RefreshSet = now + cfg.CooldownSec
		elseif skill == "DropTheBass" then
			local cfg = GameConfig.DJ_SKILLS.DropTheBass
			local activeDancers = math.clamp(math.floor(state.Popularity / 12), 2, 25)
			local drinksServed = math.min(state.MocktailStock, activeDancers)
			state.MocktailStock -= drinksServed
			state.Cash += (activeDancers * cfg.TipBonusPerDancer) + (drinksServed * GameConfig.MOCKTAIL_SALE_PRICE)
			state.SkillCooldowns.DropTheBass = now + cfg.CooldownSec
		elseif skill == "MicShoutout" then
			local cfg = GameConfig.DJ_SKILLS.MicShoutout
			state.Cash += cfg.VIPBonusTip + math.floor(state.Luxury * 1.5)
			state.SkillCooldowns.MicShoutout = now + cfg.CooldownSec
		else
			return false, "Unknown DJ skill"
		end

		StateUpdatedEv:FireClient(player, state)
		return true, skill

	elseif action == "RemoveItem" then
		local uid = tostring(payload.Uid or "")
		local item = state.PlacedItems[uid]
		if not item then
			local gx = tonumber(payload.GX)
			local gy = tonumber(payload.GY)
			if gx and gy then
				for _, placed in state.PlacedItems do
					if placed.GX == gx and placed.GY == gy then
						item = placed
						uid = placed.Uid
						break
					end
				end
			end
		end

		if not item then
			return false, "Item not found"
		end

		local def = GameConfig.ITEMS[item.ItemId]
		local refund = if def then math.floor(def.Cost * 0.7) else 0

		state.PlacedItems[uid] = nil
		state.Cash += refund
		recalculateStats(state)
		StateUpdatedEv:FireClient(player, state)
		return true, "Removed"

	elseif action == "MoveItem" then
		local uid = tostring(payload.Uid or "")
		local newGX = tonumber(payload.NewGX) or -1
		local newGY = tonumber(payload.NewGY) or -1

		local item = state.PlacedItems[uid]
		if not item then
			local gx = tonumber(payload.GX)
			local gy = tonumber(payload.GY)
			if gx and gy then
				for _, placed in state.PlacedItems do
					if placed.GX == gx and placed.GY == gy then
						item = placed
						uid = placed.Uid
						break
					end
				end
			end
		end

		if not item then
			return false, "Item not found"
		end

		local newRot = if Rules.integer(payload.NewRot, 0, 3) then payload.NewRot else (item.Rot or 0)
		local def = GameConfig.ITEMS[item.ItemId]
		local fx = if def then def.FootprintX else 1
		local fy = if def then def.FootprintY else 1
		if newRot % 2 ~= 0 then fx, fy = fy, fx end

		if not Rules.integer(newGX, 1, state.GridWidth - fx + 1) or not Rules.integer(newGY, 1, state.GridHeight - fy + 1) then
			return false, "Out of club bounds"
		end

		for ix = newGX, newGX + fx - 1 do
			for iy = newGY, newGY + fy - 1 do
				for otherUid, existing in state.PlacedItems do
					if otherUid ~= uid then
						local eDef = GameConfig.ITEMS[existing.ItemId]
						local eRot = existing.Rot or 0
						local efx = if eDef then eDef.FootprintX else 1
						local efy = if eDef then eDef.FootprintY else 1
						if eRot % 2 ~= 0 then efx, efy = efy, efx end
						if ix >= existing.GX and ix < existing.GX + efx and iy >= existing.GY and iy < existing.GY + efy then
							return false, "Tile already occupied"
						end
					end
				end
			end
		end

		item.GX = newGX
		item.GY = newGY
		item.Rot = newRot
		recalculateStats(state)
		StateUpdatedEv:FireClient(player, state)
		return true, "Moved"
	end

	return false, "Unknown action"
end

task.spawn(function()
	while true do
		task.wait(3)
		local now = os.time()
		for player, state in PlayerClubs do
			if not Data.Writable(player.UserId) or closing then continue end
			Rules.tickCelebrity(state, now, 3)
			if now < state.DJSetEndsAt and state.MocktailStock > 0 then
				local guestCount = math.clamp(math.floor(state.Popularity / 15), 1, 30)
				local drinksSold = math.min(state.MocktailStock, guestCount)
				local coverIncome = math.floor(GameConfig.BASE_COVER_CHARGE + (state.Luxury * 0.25))
				state.MocktailStock -= drinksSold
				state.Cash += coverIncome + (drinksSold * GameConfig.MOCKTAIL_SALE_PRICE)
			end
			StateUpdatedEv:FireClient(player, state)
		end
	end
end)
-- Save one profile per task so a slow request cannot block other players.
task.spawn(function()
	while not closing do
		task.wait(GameConfig.PERSISTENCE.AutosaveSeconds)
		for player in PlayerClubs do
			if closing then break end
			task.spawn(function()
				local session = Data.Sessions[player.UserId]
				if not session or session.Closing or session.Busy then return end
				if not Data.Preview and (session.Failed or session.Expires <= os.time()) then
					player:Kick("Your save session expired. Please rejoin to reopen your club safely.")
					return
				end
				if not Data.Flush(player.UserId) then
					player:Kick("Saving became unavailable. Please rejoin to recover your saved club.")
				elseif PlayerClubs[player] then StateUpdatedEv:FireClient(player, PlayerClubs[player]) end
			end)
		end
	end
end)

game:BindToClose(function()
	closing = true
	local pending = 0
	for id in Data.Sessions do
		pending += 1
		task.spawn(function() Data.Close(id); pending -= 1 end)
	end
	local deadline = os.clock() + 28
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)
