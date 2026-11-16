--!strict
local Rules, DataManager, Config = modules.ClubRules, modules.DataManager, modules.GameConfig
local state = Rules.new()
assert(Rules.decode(state), "starter roundtrip failed")
local legacy = copy(state)
legacy.Appearance = nil
local migrated = assert(Rules.decode(legacy))
assert(migrated.Appearance.Hair == modules.Appearance.default().Hair and migrated.Cash == legacy.Cash, "legacy appearance migration changed save")
local starterCount = 0
for _ in migrated.PlacedItems do starterCount += 1 end
assert(starterCount == 25, "starter lounge incomplete")
state.Cash = 1e6
for _, size in {12, 14, 16, 18, 20} do
	local prior, cost = state.Cash, Config.EXPANSIONS[state.GridWidth].Cost
	assert(Rules.expand(state))
	assert(state.GridWidth == size and state.GridHeight == size and state.Cash == prior - cost)
end
assert(not Rules.expand(state), "expanded beyond 20")
state = Rules.new(); state.Cash = 0
assert(not Rules.expand(state) and state.GridWidth == 10)
local malformed = copy(state); malformed.Cash = 0/0
assert(Rules.decode(malformed) == nil, "NaN accepted")
malformed = copy(state); malformed.PlacedItems.bad = {ItemId = "BassTower", GX = 2.5, GY = 3}
assert(Rules.decode(malformed) == nil, "fractional placement accepted")
print("PASS expansion tiers, affordability, bounds, and data validation")

state = Rules.new()
for uid, item in state.PlacedItems do
	if item.ItemId == "VelvetVIPBooth" then state.PlacedItems[uid] = nil end
end
Rules.tickCelebrity(state, mockTime + 31, 3)
local visit = assert(state.Celebrity)
local balance = state.Cash
Rules.tickCelebrity(state, mockTime + 34, 3)
assert(visit.Progress == 0, "mission progressed without VIP booth")
state.PlacedItems.vip = {Uid = "vip", ItemId = "VelvetVIPBooth", GX = 7, GY = 7}
state.ActiveGenre = visit.Genre
for step = 1, 10 do Rules.tickCelebrity(state, mockTime + 34 + step * 3, 3) end
assert(visit.Rewarded and state.Cash == balance + visit.Reward)
Rules.tickCelebrity(state, mockTime + 70, 3)
assert(state.Cash == balance + visit.Reward, "duplicate mission payout")
state = assert(Rules.decode(state))
Rules.tickCelebrity(state, mockTime + 73, 3)
assert(state.Cash == balance + visit.Reward, "mission repaid after reload")
Rules.tickCelebrity(state, mockTime + 160, 3)
assert(state.Celebrity == nil, "visit never expired")
print("PASS mission prerequisites, reward exactly once, reload, and expiry")

local db = fakeStore()
local first = DataManager.new(db, false)
local second = DataManager.new(db, false)
local home = assert(first.Load(1))
home.Cash = 7777
home.Appearance.Hair = 6
home.Appearance.Skin = 4
assert(first.Save(1))
assert(second.Load(1) == nil, "simultaneous session acquired lock")
first.Close(1)
local reopened = assert(second.Load(1))
assert(reopened.Cash == 7777, "saved cash not restored")
assert(reopened.Appearance.Hair == 6 and reopened.Appearance.Skin == 4, "appearance not restored")
assert(second.Save(1))
-- New session can recover expired lease, old server cannot overwrite it.
mockTime += Config.PERSISTENCE.LeaseSeconds + 1
assert(first.Load(1))
assert(not second.Save(1), "expired owner overwrote new session")
first.Close(1)
print("PASS persistence, competing sessions, release, and stale-owner rejection")

local broken = fakeStore()
broken.Fail = true
local unavailable = DataManager.new(broken, false)
assert(unavailable.Load(2) == nil and broken.Records.Player_2 == nil, "outage created starter save")
broken.Fail = false
broken.Records.Player_2 = {Version = 99, State = Rules.new()}
assert(unavailable.Load(2) == nil and broken.Records.Player_2.Version == 99, "unknown schema overwritten")
print("PASS failed-load and future-schema protection")

-- Durable tips: debit once, response-loss retry, offline credit and outbox recovery.
db = fakeStore()
local sender = DataManager.new(db, false)
local receiver = DataManager.new(db, false)
local a = assert(sender.Load(10))
local b = assert(receiver.Load(20))
receiver.Close(20)
local senderBefore, receiverBefore = a.Cash, b.Cash
db.Ambiguous = true
assert(sender.Tip(10, 20))
assert(a.Cash == senderBefore - Config.TIP_AMOUNT)
assert(db.Records.Player_20.PendingCredits == Config.TIP_AMOUNT, "tip duplicated or lost")
b = assert(receiver.Load(20))
assert(receiver.Flush(20))
assert(b.Cash == receiverBefore + Config.TIP_AMOUNT)
assert(not sender.Tip(10, 20), "tip cooldown bypassed")
-- Save freezes writes while awaiting storage.
db.Hook = function() assert(not receiver.Writable(20), "writes allowed during save") end
assert(receiver.Save(20)); db.Hook = nil
-- Credit commit succeeds but its reply is lost; idempotent save preserves credit.
db.Records.Player_20.PendingCredits = 25
db.Ambiguous = true
assert(receiver.Save(20))
assert(b.Cash == receiverBefore + Config.TIP_AMOUNT + 25, "ambiguous save lost or doubled credit")
mockTime += Config.TIP_COOLDOWN + 1
db.FailingKey = "Player_20"
assert(sender.Tip(10, 20))
assert(sender.Sessions[10].Outbox, "failed delivery lost durable outbox")
sender.Close(10)
db.FailingKey = nil
sender = DataManager.new(db, false)
a = assert(sender.Load(10))
assert(sender.Flush(10))
assert(not sender.Sessions[10].Outbox)
assert(receiver.Flush(20))
assert(b.Cash == receiverBefore + Config.TIP_AMOUNT * 2 + 25, "recovered transfer not credited exactly once")
sender.Close(10); receiver.Close(20)
print("PASS durable tips, cooldown, ambiguous responses, save freeze, offline delivery, and retry recovery")
