--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = require(Shared:WaitForChild("GameConfig"))
local Appearance = require(Shared:WaitForChild("Appearance"))
local Rules = {}

function Rules.integer(value: any, minimum: number, maximum: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

function Rules.recalculate(state: Types.ClubState)
	local popularity, luxury, capacity = 20, 10, 50
	for _, item in state.PlacedItems do
		local def = Config.ITEMS[item.ItemId]
		if def then
			popularity += def.Popularity
			luxury += def.Luxury
			capacity += def.StorageCapacity or 0
		end
	end
	state.Popularity, state.Luxury, state.MaxMocktailStock = popularity, luxury, capacity
	state.MocktailStock = math.min(state.MocktailStock, capacity)
end

function Rules.new(): Types.ClubState
	local state: Types.ClubState = {
		GridWidth = 10, GridHeight = 10, Cash = Config.STARTING_CASH,
		Appearance = Appearance.default(),
		MocktailStock = 150, MaxMocktailStock = 300, Popularity = 0, Luxury = 0,
		ActiveGenre = "Electro", DJSetEndsAt = os.time() + 180,
		SkillCooldowns = { RefreshSet = 0, DropTheBass = 0, MicShoutout = 0 },
		PlacedItems = {}, NextCelebrityAt = os.time() + 30,
	}
	for _, item in {
		{ "StarterDJBooth", 2, 4 },
		{ "BassTower", 2, 3 }, { "BassTower", 2, 5 },
		{ "FizzMocktailBar", 4, 1 }, { "FizzMocktailBar", 5, 1 }, { "FizzMocktailBar", 6, 1 },
		{ "VelvetVIPBooth", 8, 3 }, { "VelvetVIPBooth", 8, 5 }, { "VelvetVIPBooth", 8, 8 },
	} do
		local uid = HttpService:GenerateGUID(false)
		state.PlacedItems[uid] = { Uid = uid, ItemId = item[1] :: string, GX = item[2] :: number, GY = item[3] :: number }
	end
	-- A complete starter dance zone; saved layouts are never replaced on load.
	for gx = 3, 6 do
		for gy = 3, 6 do
			local uid = HttpService:GenerateGUID(false)
			state.PlacedItems[uid] = { Uid = uid, ItemId = "NeonDancePad", GX = gx, GY = gy }
		end
	end
	Rules.recalculate(state)
	return state
end

-- Copy only whitelisted serializable fields. Reject malformed records, never reset them.
function Rules.decode(raw: any): Types.ClubState?
	if typeof(raw) ~= "table" or not Rules.integer(raw.Cash, 0, 1e12)
		or not Rules.integer(raw.GridWidth, 10, 20) or raw.GridWidth % 2 ~= 0
		or raw.GridHeight ~= raw.GridWidth or typeof(raw.PlacedItems) ~= "table"
		or not Rules.integer(raw.MocktailStock, 0, 1e9) then return nil end
	local state: Types.ClubState = {
		GridWidth = raw.GridWidth, GridHeight = raw.GridHeight, Cash = raw.Cash,
		Appearance = Appearance.validate(raw.Appearance) or Appearance.default(),
		MocktailStock = raw.MocktailStock, MaxMocktailStock = 50, Popularity = 20, Luxury = 10,
		ActiveGenre = if Config.MUSIC_GENRES[raw.ActiveGenre] then raw.ActiveGenre else "Electro",
		DJSetEndsAt = if Rules.integer(raw.DJSetEndsAt, 0, 1e12) then raw.DJSetEndsAt else 0,
		SkillCooldowns = { RefreshSet = 0, DropTheBass = 0, MicShoutout = 0 },
		PlacedItems = {}, NextCelebrityAt = if Rules.integer(raw.NextCelebrityAt, 0, 1e12) then raw.NextCelebrityAt else os.time() + 30,
	}
	local occupied: { [string]: boolean } = {}
	for uid, item in raw.PlacedItems do
		if typeof(uid) ~= "string" or #uid > 100 or typeof(item) ~= "table" then return nil end
		local def = Config.ITEMS[item.ItemId]
		local rot = if Rules.integer(item.Rot, 0, 3) then item.Rot else 0
		local fx = def.FootprintX
		local fy = def.FootprintY
		if rot % 2 ~= 0 then fx, fy = fy, fx end
		if not def or not Rules.integer(item.GX, 1, state.GridWidth - fx + 1)
			or not Rules.integer(item.GY, 1, state.GridHeight - fy + 1) then return nil end
		for x = item.GX, item.GX + fx - 1 do
			for y = item.GY, item.GY + fy - 1 do
				local key = x .. ":" .. y
				if occupied[key] then return nil end
				occupied[key] = true
			end
		end
		state.PlacedItems[uid] = { Uid = uid, ItemId = item.ItemId, GX = item.GX, GY = item.GY, Rot = rot }
	end
	if typeof(raw.SkillCooldowns) == "table" then
		for skill in state.SkillCooldowns do
			local time = raw.SkillCooldowns[skill]
			if Rules.integer(time, 0, 1e12) then state.SkillCooldowns[skill] = time end
		end
	end
	local c = raw.Celebrity
	if typeof(c) == "table" and typeof(c.Id) == "string" then
		for _, def in Config.CELEBRITIES do
			if c.Name == def.Name and c.Genre == def.Genre and Rules.integer(c.EndsAt, 0, 1e12)
				and Rules.integer(c.Progress, 0, Config.CELEBRITY_GOAL) then
				state.Celebrity = { Id = c.Id, Name = def.Name, Genre = def.Genre, EndsAt = c.EndsAt,
					Progress = c.Progress, Goal = Config.CELEBRITY_GOAL, Reward = def.Reward, Rewarded = c.Rewarded == true }
			end
		end
	end
	Rules.recalculate(state)
	return state
end

function Rules.expand(state: Types.ClubState): (boolean, string)
	local tier = Config.EXPANSIONS[state.GridWidth]
	if not tier then return false, "Club is already 20 x 20" end
	if state.Cash < tier.Cost then return false, "Not enough cash for this expansion" end
	state.Cash -= tier.Cost
	state.GridWidth, state.GridHeight = tier.Size, tier.Size
	return true, string.format("Expanded to %d x %d", tier.Size, tier.Size)
end

function Rules.tickCelebrity(state: Types.ClubState, now: number, seconds: number)
	local visit = state.Celebrity
	if visit and now >= visit.EndsAt then state.Celebrity = nil; visit = nil end
	if not visit and now >= state.NextCelebrityAt then
		local def = Config.CELEBRITIES[math.random(1, #Config.CELEBRITIES)]
		visit = { Id = HttpService:GenerateGUID(false), Name = def.Name, Genre = def.Genre,
			EndsAt = now + Config.CELEBRITY_DURATION, Progress = 0, Goal = Config.CELEBRITY_GOAL,
			Reward = def.Reward, Rewarded = false }
		state.Celebrity = visit
		state.NextCelebrityAt = now + Config.CELEBRITY_INTERVAL
	end
	if not visit or visit.Rewarded then return end
	local booth = false
	for _, item in state.PlacedItems do if item.ItemId == "VelvetVIPBooth" then booth = true; break end end
	if booth and state.ActiveGenre == visit.Genre and state.MocktailStock > 0 and state.DJSetEndsAt > now then
		visit.Progress = math.min(visit.Goal, visit.Progress + seconds)
		if visit.Progress >= visit.Goal then
			state.Cash += visit.Reward
			visit.Rewarded = true
		end
	end
end

return Rules
