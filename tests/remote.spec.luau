--!strict
local function remote(name)
	for _, object in instances do if object.Name == name then return object end end
	error("missing remote " .. name)
end
local a, b = player(100), player(200)
players.PlayerAdded:Fire(a); players.PlayerAdded:Fire(b)
assert(not a.Kicked and not b.Kicked)
assert(players.CharacterAutoLoads == false, "character spawning enabled")
local get = remote("GetClubState").OnServerInvoke
local action = remote("PerformClubAction").OnServerInvoke
local social = remote("ClubSocial").OnServerInvoke
local function call(fn, ...)
	mockTime += 1
	return fn(...)
end
local ok, result = call(social, a, "Friends", nil)
assert(ok and result.Cards[1].UserId == 200 and result.Cards[1].Online)
ok, result = call(social, a, "Visit", 200)
assert(ok and result.Cash == 0, "visit failed or exposed private cash")
local balance = get(a).Cash
assert(not call(action, a, "ExpandClub", {}), "visitor expanded club")
assert(not call(action, a, "PlaceItem", {ItemId = "BassTower", GX = 8, GY = 8}), "visitor changed furniture")
assert(not call(social, a, "Visit", 999), "nonfriend visit accepted")
assert(call(social, a, "Tip", 200))
assert(get(a).Cash == balance - Config.TIP_AMOUNT)
assert(not call(social, a, "Tip", 200), "remote tip cooldown bypassed")
assert(call(social, a, "Home", nil))
assert(not call(action, a, "SetGenre", {Genre = "Invalid"}))
assert(call(action, a, "SetGenre", {Genre = "SynthPop"}))
assert(get(a).ActiveGenre == "SynthPop")
assert(not call(action, a, "PlaceItem", {ItemId = "BassTower", GX = 0/0, GY = 3}))
assert(not call(action, a, "PlaceItem", {ItemId = "BassTower", GX = 7.5, GY = 3}))
assert(not call(action, a, "TriggerDJSkill", {Skill = {}}))
players.PlayerRemoving:Fire(a); players.PlayerRemoving:Fire(b)
assert(not serverDb.Records.Player_100.Lock and not serverDb.Records.Player_200.Lock, "leave did not release locks")
assert(serverDb.Records.Player_100.State.ActiveGenre == "SynthPop", "genre not persisted on leave")
assert(serverDb.Records.Player_200.State.Cash == balance + Config.TIP_AMOUNT, "recipient credit not saved on leave")
print("PASS real remote handlers: friends, read-only visits, tips, genres, invalid requests, and leave-save")
--!strict
local c = player(300)
players.PlayerAdded:Fire(c)
get(c).Cash = 123456
-- Execute only shutdown tasks immediately; recurring server loops remain queued.
task.spawn = function(callback, ...) callback(...) end
game.CloseCallback()
assert(serverDb.Records.Player_300.State.Cash == 123456 and not serverDb.Records.Player_300.Lock)
print("PASS BindToClose flush and lock release")
