--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = require(Shared:WaitForChild("GameConfig"))
local Iso = require(Shared:WaitForChild("IsometricMath"))
local SpriteAnimator = require(script.Parent:WaitForChild("SpriteAnimator"))
local Navigation = require(script.Parent:WaitForChild("GuestNavigation"))
local GuestController = {}
local C = Config.CROWD
local function getQueueSlotCoords(slotIndex: number): (number, number, "Left" | "Right")
	local qx = 0.15
	local qy = 1.85 + (slotIndex - 1) * 0.85
	return qx, qy, "Right"
end

local ENTRANCE = Vector2.new(1, 1)
local ENTRY_DOOR_OUTSIDE = Vector2.new(0.15, 1.15)
local ENTRY_DOOR_INSIDE  = Vector2.new(1.15, 1.15)
local EXIT_DOOR_INSIDE   = Vector2.new(1.15, 1.45)
local EXIT_DOOR_OUTSIDE  = Vector2.new(-0.35, 1.45)

local function statusLabel(root: Frame): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "GuestStatus"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -2)
	label.Size = UDim2.fromOffset(112, 18)
	label.BackgroundColor3 = Color3.fromRGB(25, 23, 43)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = label
	label.Parent = root
	return label
end

local function render(animator: Types.SpriteAnimator, label: TextLabel, x: number, y: number, clip: string, dt: number, facing: ("Left" | "Right")?)
	local point = Iso.gridToScreen(x, y)
	animator.Root.Position = UDim2.fromOffset(point.X, point.Y)
	animator.Play(clip)
	local z = Iso.characterZIndex(x, y)
	animator.Update(dt, z, facing)
	label.ZIndex = if x < 0.9 or y < 0.9 then z + 1 else Iso.getInteriorZIndex(x, y, 9)
end

local function makeRing(parent: Instance, post: Types.PlacedItem, radius: number): Folder
	local ring = Instance.new("Folder")
	ring.Name = "BouncerCoverage_" .. post.Uid
	-- Project a circle in grid space so the visual exactly matches distance checks.
	for i = 0, 63 do
		local angle = i / 64 * math.pi * 2
		local nextAngle = (i + 1) / 64 * math.pi * 2
		local gx, gy = post.GX + math.cos(angle) * radius, post.GY + math.sin(angle) * radius
		local a = Iso.gridToScreen(gx, gy)
		local b = Iso.gridToScreen(post.GX + math.cos(nextAngle) * radius, post.GY + math.sin(nextAngle) * radius)
		local delta = b - a
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = UDim2.fromOffset(delta.Magnitude + 1, 2)
		line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		line.BackgroundColor3 = Color3.fromRGB(255, 75, 95)
		line.BackgroundTransparency = 0.2
		line.BorderSizePixel = 0
		line.ZIndex = Iso.getZIndex(gx, gy, 3)
		line.Parent = ring
	end
	ring.Parent = parent
	return ring
end

-- Returns position, next waypoint index, and whether the route is complete.
local function advance(x: number, y: number, path: { Vector2 }, index: number, speed: number, dt: number): (number, number, number, boolean)
	local point = Vector2.new(x, y)
	local budget = speed * dt
	while index <= #path do
		local delta = path[index] - point
		local distance = delta.Magnitude
		if distance > budget then
			point += delta.Unit * budget
			break
		end
		point = path[index]
		budget -= distance
		index += 1
	end
	return point.X, point.Y, index, index > #path
end

function GuestController.new(parent: Instance, initialState: Types.ClubState): Types.GuestController
	local state = initialState
	local nav = Navigation.new(state)
	local guests: { Types.CrowdGuest } = {}
	local guards: { [string]: Types.CrowdGuard } = {}
	local slots: { [string]: number } = {}
	local rng = Random.new()
	local clock = 0
	local arrivalAt = 0
	local admissionAt = 0
	local decisionAt = 0
	local nextId = 0
	local destroyed = false
	local layout = ""
	local root = Instance.new("Folder")
	root.Name = "Crowd"
	root.Parent = parent

	local function release(g: Types.CrowdGuest)
		if g.SlotKey then slots[g.SlotKey] = nil end
		g.SlotKey = nil
		g.TargetUid = nil
	end

	local function route(g: Types.CrowdGuest, point: Vector2, activity: Types.GuestMode): boolean
		local path = nav.Path(Vector2.new(g.GX, g.GY), point)
		if not path then return false end
		g.Path, g.PathIndex = path, 1
		g.TargetGX, g.TargetGY = point.X, point.Y
		g.Activity = activity
		g.Mode = if activity == "Leaving" then "Leaving" else "Walking"
		return true
	end

	local function leave(g: Types.CrowdGuest): boolean
		release(g)
		if route(g, EXIT_DOOR_INSIDE, "Leaving") then
			table.insert(g.Path, EXIT_DOOR_OUTSIDE)
			return true
		end
		g.Path, g.PathIndex = {}, 1
		if not g.GuardUid then g.Mode = if g.IsRowdy then "RowdyCrasher" else "Chatting" end
		g.WaitUntil = clock + 2
		return false
	end

	local function choose(g: Types.CrowdGuest, preferDance: boolean?)
		release(g)
		local candidates: { Types.PlacedItem } = {}
		for _, item in state.PlacedItems do table.insert(candidates, item) end
		-- Randomize equally desirable choices, but let VIPs prefer their lounge.
		for i = #candidates, 2, -1 do
			local j = rng:NextInteger(1, i)
			candidates[i], candidates[j] = candidates[j], candidates[i]
		end
		for pass = 1, 2 do
			for _, item in candidates do
				local def = Config.ITEMS[item.ItemId]
				local vip = g.IsVIP and not preferDance and item.ItemId == "VelvetVIPBooth" and pass == 1
				local dance = def and def.Category == "DancePad" and (pass == 2 or not g.IsVIP or preferDance)
				if not vip and not dance then continue end
				local offsets = if vip then { Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(0, -1) }
					else { Vector2.new(-0.2, -0.2), Vector2.new(0.2, -0.2), Vector2.new(-0.2, 0.2), Vector2.new(0.2, 0.2) }
				for index, offset in offsets do
					local key = item.Uid .. ":" .. index
					local activity: Types.GuestMode = if g.IsRowdy then "RowdyCrasher" elseif vip then "VIPChilling" else "Dancing"
					if not slots[key] and route(g, Vector2.new(item.GX, item.GY) + offset, activity) then
						slots[key] = g.Id
						g.SlotKey, g.TargetUid = key, item.Uid
						return
					end
				end
			end
		end
		-- No reachable feature: chat on a free tile and retry later.
		for _ = 1, 12 do
			local point = Vector2.new(rng:NextInteger(1, state.GridWidth), rng:NextInteger(1, state.GridHeight))
			if route(g, point, if g.IsRowdy then "RowdyCrasher" else "Chatting") then return end
		end
		g.Mode = if g.IsRowdy then "RowdyCrasher" else "Chatting"
		g.Path = {}
		g.PathIndex = 1
		g.WaitUntil = clock + 2
	end

	local function spawnGuest(queueCount: number, celebrity: Types.CelebrityVisit?)
		nextId += 1
		local rowdy = celebrity == nil and nextId % C.RowdyEvery == 0
		local vip = celebrity ~= nil or (not rowdy and nextId % 5 == 0)
		local color = if rowdy then Color3.fromRGB(240, 80, 90) else Color3.fromHSV((nextId * 0.13) % 1, 0.65, 0.95)
		local animator = SpriteAnimator.new(root, Config.GUEST_SPRITE, color, vip)
		local label = statusLabel(animator.Root)
		local qx, qy = getQueueSlotCoords(queueCount + 1)
		table.insert(guests, {
			Id = nextId, GX = qx, GY = qy, TargetGX = qx, TargetGY = qy,
			Speed = rng:NextNumber(1.5, 2.1), Happiness = 100, IsVIP = vip,
			Mode = "Queueing", SpriteColor = color, GuiRoot = animator.Root,
			Animator = animator, Status = label, Path = {}, PathIndex = 1,
			Activity = "Queueing", WaitUntil = 0, LeaveAt = clock + C.VisitSeconds + rng:NextNumber(0, 40),
			IsRowdy = rowdy,
			CelebrityId = if celebrity then celebrity.Id else nil,
			CelebrityName = if celebrity then celebrity.Name else nil,
		})
	end

	local function findGuest(id: number): Types.CrowdGuest?
		for _, g in guests do if g.Id == id then return g end end
		return nil
	end

	local function rebuild(newState: Types.ClubState)
		if destroyed then return end
		state = newState
		local signature = { tostring(state.GridWidth), tostring(state.GridHeight) }
		for _, item in state.PlacedItems do
			table.insert(signature, item.Uid .. ":" .. item.ItemId .. ":" .. item.GX .. ":" .. item.GY)
		end
		table.sort(signature)
		local nextLayout = table.concat(signature, "|")
		if nextLayout == layout then return end
		layout = nextLayout
		nav = Navigation.new(state)
		-- Layout changes invalidate routes, reservations, and staff positions.
		for _, guard in guards do guard.Animator.Destroy(); guard.Ring:Destroy() end
		table.clear(guards)
		table.clear(slots)
		for _, g in guests do
			g.GuardUid = nil
			g.SlotKey, g.TargetUid = nil, nil
			if g.Mode == "Queueing" then continue end
			if g.Mode == "Leaving" then
				-- Preserve the final outside leg instead of routing back inside.
				if g.GY >= 1 then leave(g) end
			elseif g.Mode == "Entering" then
				if not nav.Walkable(1, 1) then
					g.Mode = "Queueing"
					g.Path, g.PathIndex = {}, 1
				end
			else
				choose(g)
			end
		end
		for _, post in state.PlacedItems do
			local def = Config.ITEMS[post.ItemId]
			if post.ItemId ~= "BouncerStation" or not def or not def.EffectRadius then continue end
			local point = Vector2.new(post.GX, post.GY)
			for _, offset in { Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(0, -1) } do
				local candidate = point + offset
				if nav.Walkable(candidate.X, candidate.Y) then point = candidate; break end
			end
			local animator = SpriteAnimator.new(root, Config.GUEST_SPRITE, Color3.fromRGB(45, 60, 85), false)
			local label = statusLabel(animator.Root)
			label.Text = "SECURITY"
			guards[post.Uid] = {
				GX = point.X, GY = point.Y, Post = post, Radius = def.EffectRadius,
				Animator = animator, Status = label, Ring = makeRing(root, post, def.EffectRadius),
				Path = {}, PathIndex = 1, Escorting = false,
			}
		end
	end

	local function think(delta: number)
		local queue: { Types.CrowdGuest } = {}
		for _, g in guests do if g.Mode == "Queueing" then table.insert(queue, g) end end
		for index, g in queue do
			local qx, qy = getQueueSlotCoords(index)
			g.TargetGX = qx
			g.TargetGY = qy
		end
		local celebrity = state.Celebrity
		local celebrityPresent = false
		for _, g in guests do
			if g.CelebrityId then
				if celebrity and g.CelebrityId == celebrity.Id and celebrity.EndsAt > os.time() then celebrityPresent = true
				elseif g.Mode ~= "Leaving" then
					if g.Mode == "Queueing" then g.Mode = "Leaving"; g.Path = { EXIT_DOOR_OUTSIDE }; g.PathIndex = 1 else leave(g) end
				end
			end
		end
		if celebrity and celebrity.EndsAt > os.time() and not celebrityPresent and #guests < C.MaxGuests and #queue < C.MaxQueue then
			spawnGuest(#queue, celebrity)
			arrivalAt = clock + C.ArrivalInterval
		end
		if clock >= arrivalAt and #guests < C.MaxGuests - 1 and #queue < C.MaxQueue then
			spawnGuest(#queue)
			arrivalAt = clock + C.ArrivalInterval
		end
		local first = queue[1]
		local firstAtHead = first and math.abs(first.GY - 1.85) < 0.15
		if first and first.Mode == "Queueing" and clock >= admissionAt and firstAtHead and nav.Walkable(1, 1) then
			first.Mode, first.Activity = "Entering", "Entering"
			first.Path, first.PathIndex = { ENTRY_DOOR_OUTSIDE, ENTRY_DOOR_INSIDE }, 1
			admissionAt = clock + C.AdmissionInterval
		end
		-- Claim covered crashers before applying their happiness penalty.
		for uid, guard in guards do
			if guard.GuestId then continue end
			for _, g in guests do
				local inside = g.Mode ~= "Queueing" and g.Mode ~= "Entering" and g.Mode ~= "Leaving"
				if g.IsRowdy and inside and not g.GuardUid and (Vector2.new(g.GX, g.GY) - Vector2.new(guard.Post.GX, guard.Post.GY)).Magnitude <= guard.Radius then
					local path = nav.Path(Vector2.new(guard.GX, guard.GY), Vector2.new(g.GX, g.GY))
					if path and nav.Path(Vector2.new(g.GX, g.GY), EXIT_DOOR_INSIDE) then
						release(g)
						g.Mode, g.GuardUid = "Escorted", uid
						g.Path = {}
						g.PathIndex = 1
						guard.GuestId, guard.Path, guard.PathIndex = g.Id, path, 1
						break
					end
				end
			end
		end
		for _, g in guests do
			if g.Mode == "Queueing" or g.Mode == "Entering" or g.Mode == "Escorted" or g.Mode == "Leaving" then continue end
			if not g.IsRowdy then
				local nearby = 0
				for _, other in guests do
					if other.IsRowdy and not other.GuardUid and (other.Mode == "RowdyCrasher" or other.Mode == "Walking") then
						local covered = false
						for _, guard in guards do
							if (Vector2.new(other.GX, other.GY) - Vector2.new(guard.Post.GX, guard.Post.GY)).Magnitude <= guard.Radius then covered = true; break end
						end
						if not covered and (Vector2.new(g.GX, g.GY) - Vector2.new(other.GX, other.GY)).Magnitude <= C.RowdyRadius then nearby += 1 end
					end
				end
				g.Happiness = math.clamp(g.Happiness + (if nearby > 0 then -C.HappinessLossPerSecond * nearby else C.HappinessRecoveryPerSecond) * delta, 0, 100)
			end
			if not g.CelebrityId and (g.Happiness <= 15 or clock >= g.LeaveAt) and clock >= g.WaitUntil then
				leave(g)
			elseif g.Mode ~= "Walking" and clock >= g.WaitUntil then
				choose(g)
			end
		end
	end

	local function update(dt: number)
		if destroyed then return end
		-- Bound simulation time after a suspended client; movement never overshoots.
		dt = math.clamp(dt, 0, 0.1)
		clock += dt
		if clock >= decisionAt then
			think(C.DecisionInterval)
			decisionAt = clock + C.DecisionInterval
		end
		for _, guard in guards do
			local g = if guard.GuestId then findGuest(guard.GuestId) else nil
			if g and guard.Escorting then
				guard.GX, guard.GY = g.GX + 0.28, g.GY
			elseif g then
				local done: boolean
				guard.GX, guard.GY, guard.PathIndex, done = advance(guard.GX, guard.GY, guard.Path, guard.PathIndex, C.GuardSpeed, dt)
				if done and leave(g) then guard.Escorting = true end
			else
				guard.GX, guard.GY, guard.PathIndex = advance(guard.GX, guard.GY, guard.Path, guard.PathIndex, C.GuardSpeed, dt)
			end
			guard.Status.Text = if g then "ESCORTING" else "SECURITY"
			local guardFacing: "Left" | "Right" = "Right"
			if guard.PathIndex <= #guard.Path then
				local wp = guard.Path[guard.PathIndex]
				local sDx = (wp.X - guard.GX) - (wp.Y - guard.GY)
				if sDx < -0.05 then guardFacing = "Left" elseif sDx > 0.05 then guardFacing = "Right" end
			end
			render(guard.Animator, guard.Status, guard.GX, guard.GY, if g or guard.PathIndex <= #guard.Path then "Walk" else "Idle", dt, guardFacing)
		end
		for i = #guests, 1, -1 do
			local g = guests[i]
			local moving = g.Mode == "Walking" or g.Mode == "Entering" or g.Mode == "Leaving"
			if g.Mode == "Queueing" then
				local difference = g.TargetGY - g.GY
				local nextY = g.GY + math.sign(difference) * math.min(math.abs(difference), g.Speed * dt)
				moving = math.abs(nextY - g.GY) > 0.001
				g.GY = nextY
			elseif moving then
				local done: boolean
				g.GX, g.GY, g.PathIndex, done = advance(g.GX, g.GY, g.Path, g.PathIndex, if g.GuardUid then 2.4 else g.Speed, dt)
				if done then
					if g.Mode == "Leaving" then
						local guard = if g.GuardUid then guards[g.GuardUid] else nil
						if guard then
							guard.GuestId, guard.Escorting = nil, false
							local target = Vector2.new(guard.Post.GX, guard.Post.GY)
							local homePath: { Vector2 }? = nil
							for _, offset in { Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(0, -1) } do
								homePath = nav.Path(ENTRANCE, target + offset)
								if homePath then break end
							end
							guard.Path = homePath or {}
							guard.PathIndex = 1
						end
						release(g)
						g.Animator.Destroy()
						table.remove(guests, i)
						continue
					elseif g.Mode == "Entering" then choose(g)
					else
						g.Mode = g.Activity
						g.WaitUntil = clock + rng:NextNumber(6, 14)
					end
				end
			end
			local text = if g.Mode == "Escorted" or g.GuardUid then "ESCORTED OUT"
				elseif g.CelebrityName then g.CelebrityName
				elseif g.IsRowdy then "ROWDY CRASHER"
				elseif g.Mode == "Queueing" then (if math.abs(g.GY - 1.85) < 0.2 then "NEXT IN LINE" else "IN QUEUE")
				elseif g.Mode == "VIPChilling" then "VIP LOUNGE"
				elseif g.IsVIP then "HIGH ROLLER"
				else string.format("%s | %d%%", g.Mode, math.round(g.Happiness))
			g.Status.Text = text
			g.Status.Visible = g.IsVIP or g.IsRowdy or g.Happiness < 60 or (g.Mode == "Queueing" and math.abs(g.GY - 1.85) < 0.2)
			g.Status.TextColor3 = if g.IsRowdy or g.Happiness < 40 then Color3.fromRGB(255, 120, 125)
				elseif g.IsVIP then Color3.fromRGB(255, 219, 80) else Color3.fromRGB(180, 255, 206)
			local guestFacing: "Left" | "Right" = "Right"
			if moving then
				local nextTarget = if g.Path and g.Path[g.PathIndex] then g.Path[g.PathIndex] else Vector2.new(g.TargetGX, g.TargetGY)
				local sDx = (nextTarget.X - g.GX) - (nextTarget.Y - g.GY)
				if sDx < -0.05 then guestFacing = "Left" elseif sDx > 0.05 then guestFacing = "Right" end
			end
			render(g.Animator, g.Status, g.GX, g.GY, if moving then "Walk" elseif g.Mode == "Dancing" or g.Mode == "RowdyCrasher" then "Dance" else "Idle", dt, guestFacing)
		end
	end

	rebuild(state)
	for i = 0, C.MaxQueue - 1 do spawnGuest(i) end
	arrivalAt = C.ArrivalInterval
	return {
		Update = update,
		SetState = rebuild,
		Rally = function()
			for _, g in guests do
				if g.Mode ~= "Queueing" and g.Mode ~= "Entering" and g.Mode ~= "Leaving" and not g.GuardUid and not g.IsRowdy then choose(g, true) end
			end
		end,
		Destroy = function()
			if destroyed then return end
			destroyed = true
			for _, g in guests do g.Animator.Destroy() end
			for _, guard in guards do guard.Animator.Destroy() end
			root:Destroy()
			table.clear(guests)
			table.clear(guards)
			table.clear(slots)
		end,
	}
end

return GuestController
