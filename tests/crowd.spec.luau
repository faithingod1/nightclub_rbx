--!strict
local Config = modules.GameConfig
local Controller = modules.GuestController
local Navigation = modules.GuestNavigation
local function club()
	return { GridWidth = 10, GridHeight = 10, Cash = 2500, MocktailStock = 150, PlacedItems = {} }
end
local function place(state, id, x, y, uid)
	state.PlacedItems[uid] = { Uid = uid, ItemId = id, GX = x, GY = y }
end
local function labels()
	local result = {}
	for _, object in instances do
		if object.Name == "GuestStatus" and not object.Destroyed then table.insert(result, object) end
	end
	return result
end
local function has(text)
	for _, label in labels() do if string.find(label.Text or "", text, 1, true) then return true end end
	return false
end
local function tick(controller, seconds, observer)
	for _ = 1, math.floor(seconds * 30) do
		controller.Update(1 / 30)
		if observer then observer() end
	end
end
local function close(controller)
	controller.Destroy()
	controller.Destroy()
	controller.Update(1)
	assert(#labels() == 0, "guest/staff UI leaked")
	table.clear(instances)
end

-- Navigation routes around solid furniture and rejects sealed destinations.
local state = club()
place(state, "BassTower", 2, 1, "obstacle")
local nav = Navigation.new(state)
local route = assert(nav.Path(Vector2.new(1, 1), Vector2.new(3, 1)))
for _, point in route do assert(not (point.X == 2 and point.Y == 1), "route crossed furniture") end
place(state, "BassTower", 1, 2, "wall")
assert(Navigation.new(state).Path(Vector2.new(1, 1), Vector2.new(3, 1)) == nil, "sealed route accepted")
print("PASS navigation obstacles and unreachable targets")

-- Queue remains outside a blocked entrance, then resumes after removal.
math.randomseed(42)
state = club()
place(state, "BassTower", 1, 1, "door")
local controller = Controller.new(Instance.new("Folder"), state)
tick(controller, 10)
assert(#labels() == Config.CROWD.MaxQueue and has("IN QUEUE"), "blocked entrance did not hold queue")
state.PlacedItems.door = nil
place(state, "NeonDancePad", 3, 3, "dance")
controller.SetState(state)
local danced = false
tick(controller, 25, function()
	for _, label in labels() do
		if string.find(label.Text or "", "Dancing", 1, true) then
			danced = true
			local p = label.Parent.Position
			local gx, gy = modules.IsometricMath.screenToGrid(p.X.Offset, p.Y.Offset)
			assert(gx == 3 and gy == 3, "guest danced off its dance pad")
		end
	end
end)
assert(danced, "guests did not reach dance pad")
assert(state.Cash == 2500 and state.MocktailStock == 150, "client changed server economy")
close(controller)
print("PASS queue, admission, dancing, and economy isolation")

-- VIPs seek the lounge; moving/removing it invalidates routes and occupancy.
math.randomseed(5)
state = club()
place(state, "VelvetVIPBooth", 3, 3, "vip")
place(state, "NeonDancePad", 5, 5, "dance")
controller = Controller.new(Instance.new("Folder"), state)
local lounged = false
tick(controller, 35, function() lounged = lounged or has("VIP LOUNGE") end)
assert(lounged, "VIP never reached lounge")
state.PlacedItems.vip.GX = 7
controller.SetState(state)
tick(controller, 5)
state.PlacedItems.vip = nil
controller.SetState(state)
tick(controller, 2)
assert(not has("VIP LOUNGE"), "VIP stayed at removed booth")
close(controller)
print("PASS VIP selection and layout invalidation")

-- Uncovered crashers lower happiness; security claims them and completes escort.
math.randomseed(10)
state = club()
for x = 2, 5 do for y = 2, 5 do place(state, "NeonDancePad", x, y, x .. ":" .. y) end end
controller = Controller.new(Instance.new("Folder"), state)
local harmed = false
tick(controller, 45, function()
	for _, label in labels() do
		local happiness = tonumber(string.match(label.Text or "", "| (%d+)%%"))
		if happiness and happiness < 95 then harmed = true end
	end
end)
assert(harmed, "crashers did not affect nearby happiness")
place(state, "BouncerStation", 4, 4, "guard")
controller.SetState(state)
local segments = 0
for _, object in instances do
	if object.ClassName == "Frame" and object.Parent and object.Parent.Name == "BouncerCoverage_guard" and not object.Destroyed then segments += 1 end
end
assert(segments == 64, "coverage ring missing")
local escorted = false
local removedEscort = false
local watched = nil
tick(controller, 30, function()
	for _, label in labels() do
		if label.Text == "ESCORTED OUT" then escorted = true; watched = watched or label end
	end
	if watched and watched.Destroyed then removedEscort = true end
end)
assert(escorted and removedEscort, "bouncer did not complete an escort")
state.PlacedItems.guard = nil
controller.SetState(state)
assert(not has("SECURITY") and not has("ESCORTING"), "removed station leaked staff")
for _, object in instances do
	if object.Name == "BouncerCoverage_guard" then assert(object.Destroyed, "removed station leaked coverage ring") end
end
tick(controller, 15)
close(controller)
print("PASS happiness damage, security escort, and station removal")

-- Empty clubs keep running, capped and safe through churn and a long frame.
math.randomseed(12)
state = club()
controller = Controller.new(Instance.new("Folder"), state)
tick(controller, 200, function() assert(#labels() <= Config.CROWD.MaxGuests, "population exceeded cap") end)
controller.Update(60)
controller.Rally()
tick(controller, 5)
close(controller)
print("PASS empty club, population cap, long frame, rally, and cleanup")

-- Celebrity identity is unique, uses VIP routing, and leaves when the visit ends.
math.randomseed(15)
state = club()
place(state, "VelvetVIPBooth", 3, 3, "vip")
state.Celebrity = {Id = "celebrity-test", Name = "DJ Blox", Genre = "HipHop", EndsAt = os.time() + 120, Progress = 0, Goal = 30, Reward = 900, Rewarded = false}
controller = Controller.new(Instance.new("Folder"), state)
local appeared = false
tick(controller, 30, function()
	local count = 0
	for _, label in labels() do if label.Text == "DJ Blox" then count += 1 end end
	assert(count <= 1, "duplicate celebrity sprites")
	appeared = appeared or count == 1
end)
assert(appeared, "celebrity never joined the crowd")
state.Celebrity = nil
controller.SetState(state)
tick(controller, 30)
assert(not has("DJ Blox"), "expired celebrity never left")
close(controller)
print("PASS celebrity identity, single sprite, and departure")
