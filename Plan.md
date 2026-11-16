# ROLE & OBJECTIVE
You are a Principal Roblox 2D Engine Architect & UI Technical Artist working on **NeonClubCity2D** (`CARBON.md` architecture).

First, read `CARBON.md`, `AGENTS.md`, `src/shared/*`, `src/client/*`, `src/server/*`, and `tests/*` so you preserve every exported function signature, remote payload, and unit test contract. Then refactor and upgrade the codebase using the reference `--!strict` Luau implementations below to achieve:
1. **60+ FPS Zero-Lag Performance** even at `MaxGuests = 36` and `20x20` grid size.
2. **Zero Character-Through-Object Clipping** (fixing both sub-tile movement/bouncer tunneling AND `ZIndex` layer bleeding).
3. **1:1 Original 2010 *Nightclub City* Stylized Character Models** (including active DJ at `StarterDJBooth` and Bartender behind `FizzMocktailBar`).
4. **1:1 Original 2010 *Nightclub City* Isometric 2.5D Club Models & Glossy Neon HUD**.

## NON-NEGOTIABLE `CARBON.md` RULES
- `--!strict` at the top of every `.luau` file.
- **100% 2D `ScreenGui` ONLY:** Zero `Part`, `MeshPart`, `Model`, or `Humanoid` instances. `Players.CharacterAutoLoads = false`.
- **NEVER** use the 2nd parent argument in `Instance.new("Frame", parent)` — configure all properties first (`Active = false`, `Selectable = false`, `BorderSizePixel = 0`), set `.Parent` LAST.
- Use `task.wait`, `task.spawn`, `task.delay`, and `os.clock` ONLY.
- Strictly Mocktail / Neon Fizz / Energy Bars & polite Bouncer escorts; procedural vector fallbacks whenever `AssetId == ""`.

---

## MODULE 1: `src/shared/IsometricMath.luau` (Continuous Depth & Zero ZIndex Bleed)
Integrate/preserve all existing exports required by `tests/`, and ensure entity depth uses **continuous `(gx + gy)` sorting** while keeping `CARBON.md`'s `[1, 100000]` clamping (`80000` hover cursor, `90000+` HUD):

```luau
--!strict
local GameConfig = require(script.Parent.GameConfig)

local IsometricMath = {}

export type LayerKind = "Floor" | "Wall" | "DancePad" | "WallDecor" | "Entity" | "Popup"

local LAYER_OFFSETS: { [LayerKind]: number } = {
	Floor = 1,
	Wall = 2,
	DancePad = 3,
	WallDecor = 4,
	Entity = 5,
	Popup = 9,
}

function IsometricMath.gridToScreen(gx: number, gy: number): Vector2
	local sx = (gx - gy) * (GameConfig.TILE_WIDTH * 0.5)
	local sy = (gx + gy) * (GameConfig.TILE_HEIGHT * 0.5)
	return Vector2.new(sx, sy)
end

function IsometricMath.screenToGrid(sx: number, sy: number): (number, number)
	local a = sx / (GameConfig.TILE_WIDTH * 0.5)
	local b = sy / (GameConfig.TILE_HEIGHT * 0.5)
	local gx = math.round((a + b) * 0.5)
	local gy = math.round((b - a) * 0.5)
	return gx, gy
end

-- Compatible with CARBON.md Section 3.5 formula:
-- ZIndex = clamp(floor((gx + gy) * 10) + layerOffset, 1, 100000)
function IsometricMath.computeZIndex(gx: number, gy: number, layerOffset: number): number
	local raw = math.floor((gx + gy) * 10) + layerOffset
	return math.clamp(raw, 1, 79999)
end

-- Front-most plane depth for multi-tile solid furniture so characters behind NEVER bleed over front faces,
-- and characters in front ALWAYS render cleanly on top of the item:
function IsometricMath.furnitureZIndex(gx: number, gy: number, footprintX: number, footprintY: number): number
	local frontGX = gx + math.max(0, footprintX - 1) + 0.15
	local frontGY = gy + math.max(0, footprintY - 1) + 0.15
	return IsometricMath.computeZIndex(frontGX, frontGY, LAYER_OFFSETS.Entity)
end

-- Foot-anchor depth for walking guests & bouncers:
function IsometricMath.characterZIndex(gx: number, gy: number): number
	return IsometricMath.computeZIndex(gx, gy, LAYER_OFFSETS.Entity)
end

return IsometricMath
```

---

## MODULE 2: `src/client/GuestNavigation.luau` (Strict Footprint Blocking, Frontage Slots & Corner-Safe BFS)
Fix **all** movement clipping:
1. Solid furniture (`MocktailBar`, `DJBooth`, `Speaker`, `VIPBooth`, `BouncerPost`) blocks `[GX .. GX + FootprintX - 1] x [GY .. GY + FootprintY - 1]`.
2. Guests heading to a `MocktailBar` or `VIPBooth` NEVER walk onto the furniture's own blocked `(GX, GY)` tile—they route to a **walkable adjacent frontage tile**!
3. Both **Guests AND Bouncers** use BFS and `stepSafePosition` so nobody ever cuts diagonally across blocked corners or moves in a straight line through bars/speakers.

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)

type PlacedItem = Types.PlacedItem
type ItemDef = Types.ItemDef

local GuestNavigation = {}

export type NavGrid = {
	Width: number,
	Height: number,
	Blocked: { [number]: boolean }, -- key = (gy - 1) * Width + gx
}

local SOLID_CATEGORIES: { [string]: boolean } = {
	Speaker = true,
	MocktailBar = true,
	DJBooth = true,
	VIPBooth = true,
	BouncerPost = true,
}

local CARDINAL_DIRS = {
	{ dx = 1, dy = 0 },
	{ dx = 0, dy = 1 },
	{ dx = -1, dy = 0 },
	{ dx = 0, dy = -1 },
}

local function cellKey(width: number, gx: number, gy: number): number
	return (gy - 1) * width + gx
end

function GuestNavigation.buildGrid(
	width: number,
	height: number,
	placedItems: { [string]: PlacedItem }
): NavGrid
	local blocked: { [number]: boolean } = {}
	for _, placed in placedItems do
		local def: ItemDef? = GameConfig.ITEMS[placed.ItemId]
		if def and SOLID_CATEGORIES[def.Category] then
			local fx = math.max(1, def.FootprintX)
			local fy = math.max(1, def.FootprintY)
			for ix = placed.GX, placed.GX + fx - 1 do
				for iy = placed.GY, placed.GY + fy - 1 do
					if ix >= 1 and ix <= width and iy >= 1 and iy <= height then
						blocked[cellKey(width, ix, iy)] = true
					end
				end
			end
		end
	end
	-- Entrance threshold (1, 1) must always remain unblocked for admission/exit
	blocked[cellKey(width, 1, 1)] = nil
	return {
		Width = width,
		Height = height,
		Blocked = blocked,
	}
end

function GuestNavigation.isWalkable(grid: NavGrid, gx: number, gy: number): boolean
	local rx = math.round(gx)
	local ry = math.round(gy)
	if rx < 1 or rx > grid.Width or ry < 1 or ry > grid.Height then
		return false
	end
	return not grid.Blocked[cellKey(grid.Width, rx, ry)]
end

-- Prevents continuous float positions from cutting into a blocked footprint box (with 0.38 tile radius pad)
function GuestNavigation.isPointClear(grid: NavGrid, x: number, y: number): boolean
	if x < 0.65 or x > grid.Width + 0.35 or y < 0.65 or y > grid.Height + 0.35 then
		return false
	end
	local pad = 0.32
	return GuestNavigation.isWalkable(grid, x - pad, y - pad)
		and GuestNavigation.isWalkable(grid, x + pad, y - pad)
		and GuestNavigation.isWalkable(grid, x - pad, y + pad)
		and GuestNavigation.isWalkable(grid, x + pad, y + pad)
end

-- Finds nearest walkable tile via expanding ring BFS (used when furniture is placed on top of a guest)
function GuestNavigation.nearestWalkable(grid: NavGrid, startGX: number, startGY: number): (number, number)
	local sx = math.clamp(math.round(startGX), 1, grid.Width)
	local sy = math.clamp(math.round(startGY), 1, grid.Height)
	if GuestNavigation.isWalkable(grid, sx, sy) then
		return sx, sy
	end

	local queueX = { sx }
	local queueY = { sy }
	local visited: { [number]: boolean } = { [cellKey(grid.Width, sx, sy)] = true }
	local head = 1

	while head <= #queueX do
		local cx = queueX[head]
		local cy = queueY[head]
		head += 1

		for _, d in CARDINAL_DIRS do
			local nx = cx + d.dx
			local ny = cy + d.dy
			if nx >= 1 and nx <= grid.Width and ny >= 1 and ny <= grid.Height then
				local k = cellKey(grid.Width, nx, ny)
				if not visited[k] then
					if GuestNavigation.isWalkable(grid, nx, ny) then
						return nx, ny
					end
					visited[k] = true
					table.insert(queueX, nx)
					table.insert(queueY, ny)
				end
			end
		end
	end

	return 1, 1
end

-- Resolves an adjacent walkable interaction tile in front of a solid Bar / VIPBooth / DJBooth
function GuestNavigation.getInteractionTile(
	grid: NavGrid,
	placed: PlacedItem,
	def: ItemDef,
	slotIndex: number
): (number, number)?
	local candidates: { Vector2 } = {}
	local fx = math.max(1, def.FootprintX)
	local fy = math.max(1, def.FootprintY)

	-- Prefer down-front isometric faces (+X and +Y) first so guests face the counter/table visibly
	for ix = placed.GX, placed.GX + fx - 1 do
		if GuestNavigation.isWalkable(grid, ix, placed.GY + fy) then
			table.insert(candidates, Vector2.new(ix, placed.GY + fy))
		end
	end
	for iy = placed.GY, placed.GY + fy - 1 do
		if GuestNavigation.isWalkable(grid, placed.GX + fx, iy) then
			table.insert(candidates, Vector2.new(placed.GX + fx, iy))
		end
	end
	for ix = placed.GX, placed.GX + fx - 1 do
		if GuestNavigation.isWalkable(grid, ix, placed.GY - 1) then
			table.insert(candidates, Vector2.new(ix, placed.GY - 1))
		end
	end
	for iy = placed.GY, placed.GY + fy - 1 do
		if GuestNavigation.isWalkable(grid, placed.GX - 1, iy) then
			table.insert(candidates, Vector2.new(placed.GX - 1, iy))
		end
	end

	if #candidates == 0 then
		return nil
	end
	local pick = candidates[((slotIndex - 1) % #candidates) + 1]
	return pick.X, pick.Y
end

-- Pure 4-connected orthogonal BFS (zero diagonal corner clipping across furniture edges!)
function GuestNavigation.findPath(
	grid: NavGrid,
	fromX: number,
	fromY: number,
	toX: number,
	toY: number
): { Vector2 }
	local sx, sy = GuestNavigation.nearestWalkable(grid, fromX, fromY)
	local tx, ty = GuestNavigation.nearestWalkable(grid, toX, toY)

	if sx == tx and sy == ty then
		return { Vector2.new(tx, ty) }
	end

	local w = grid.Width
	local startKey = cellKey(w, sx, sy)
	local goalKey = cellKey(w, tx, ty)

	local qx = { sx }
	local qy = { sy }
	local parent: { [number]: number } = { [startKey] = 0 }
	local head = 1
	local found = false

	while head <= #qx do
		local cx = qx[head]
		local cy = qy[head]
		local ck = cellKey(w, cx, cy)
		head += 1

		if ck == goalKey then
			found = true
			break
		end

		for _, d in CARDINAL_DIRS do
			local nx = cx + d.dx
			local ny = cy + d.dy
			if nx >= 1 and nx <= grid.Width and ny >= 1 and ny <= grid.Height then
				local nk = cellKey(w, nx, ny)
				if parent[nk] == nil and not grid.Blocked[nk] then
					parent[nk] = ck
					table.insert(qx, nx)
					table.insert(qy, ny)
				end
			end
		end
	end

	if not found then
		return { Vector2.new(sx, sy) }
	end

	local rev: { Vector2 } = {}
	local cur = goalKey
	while cur ~= 0 and cur ~= nil do
		local gy = math.floor((cur - 1) / w) + 1
		local gx = ((cur - 1) % w) + 1
		table.insert(rev, Vector2.new(gx, gy))
		cur = parent[cur]
	end

	local path: { Vector2 } = {}
	for i = #rev, 1, -1 do
		table.insert(path, rev[i])
	end
	return path
end

-- Swept step helper for GuestController & Bouncer AI: prevents ANY movement into blocked tiles
function GuestNavigation.stepAlongWaypoints(
	grid: NavGrid,
	curX: number,
	curY: number,
	waypoints: { Vector2 },
	waypointIndex: number,
	speedTilesPerSec: number,
	dt: number
): (number, number, number, "Left" | "Right", boolean)
	if not GuestNavigation.isWalkable(grid, curX, curY) then
		local safeX, safeY = GuestNavigation.nearestWalkable(grid, curX, curY)
		return safeX, safeY, #waypoints + 1, "Right", true
	end

	if waypointIndex > #waypoints then
		return curX, curY, waypointIndex, "Right", true
	end

	local target = waypoints[waypointIndex]
	if not GuestNavigation.isWalkable(grid, target.X, target.Y) then
		return curX, curY, #waypoints + 1, "Right", true
	end

	local dx = target.X - curX
	local dy = target.Y - curY
	local dist = math.sqrt(dx * dx + dy * dy)
	local step = speedTilesPerSec * dt

	-- Isometric screen X direction determines Left/Right sprite reflection: sx = (gx - gy) * 64
	local isoDX = dx - dy
	local facing: "Left" | "Right" = if isoDX < -0.01 then "Left" else "Right"

	if dist <= step or dist < 0.001 then
		return target.X, target.Y, waypointIndex + 1, facing, (waypointIndex + 1 > #waypoints)
	end

	local nx = curX + (dx / dist) * step
	local ny = curY + (dy / dist) * step

	if GuestNavigation.isPointClear(grid, nx, ny) then
		return nx, ny, waypointIndex, facing, false
	else
		-- Recenter onto integer axis first to prevent corner grazing
		local centerX = math.round(curX)
		local centerY = math.round(curY)
		return centerX, centerY, waypointIndex, facing, false
	end
end

return GuestNavigation
```

---

## MODULE 3: `src/client/SpriteAnimator.luau` (High-FPS Pooled 2010 *Nightclub City* Cartoon Rig)
Upgrade `SpriteAnimator.luau` with:
- **Single-ZIndex Creation-Order Batching + `lastZIndex` Dirty Cache:** All character body parts share the EXACT SAME `zIndex` (relying on Roblox's deterministic sibling hierarchy order inside `BodyContainer`), so a character consumes **1 ZIndex integer total** (zero ZIndex bleed through furniture!) AND skips `.ZIndex` writes on 95%+ of frames!
- **`Active = false` & Lean Part Count (~22 clean vector parts instead of 45+):** Eliminates `ScreenGui` input hit-test overhead and layout thrashing.
- **Authentic 2010 *Nightclub City* Flash Styling:** Sleek fashionable clubber silhouette (`56x78px`), contoured chin/jaw, bold dark ink outer contour stroke, glossy swept 2010 hairstyles, stylish upper lash + almond eyes with specular shine, trendy club outfits, plus role props (`"DJ"`, `"Bartender"`, `"Bouncer"`, `"VIP"`, `"MocktailCup"`).

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

type Appearance = Types.Appearance
type SpriteSheet = Types.SpriteSheet
type SpriteAnimator = Types.SpriteAnimator

local SpriteAnimatorModule = {}

export type RoleOptions = {
	Role: ("Guest" | "DJ" | "Bartender" | "Bouncer" | "Celebrity" | "Rowdy")?,
	HasDrink: boolean?,
	Sunglasses: boolean?,
}

type VectorPart = {
	Frame: Frame,
	BaseX: number,
	BaseY: number,
	Width: number,
	BaseRot: number,
}

local SKIN_PALETTE = {
	Color3.fromRGB(255, 228, 206),
	Color3.fromRGB(244, 206, 174),
	Color3.fromRGB(224, 176, 136),
	Color3.fromRGB(196, 140, 98),
	Color3.fromRGB(148, 96, 62),
	Color3.fromRGB(98, 60, 38),
}

local HAIR_PALETTE = {
	Color3.fromRGB(24, 22, 30),    -- Espresso Black
	Color3.fromRGB(78, 46, 30),    -- Chocolate Brown
	Color3.fromRGB(238, 194, 88),  -- Honey Blonde
	Color3.fromRGB(186, 52, 46),   -- Crimson Auburn
	Color3.fromRGB(122, 68, 42),   -- Chestnut
	Color3.fromRGB(36, 58, 132),   -- Midnight Neon Blue
}

local EYE_PALETTE = {
	Color3.fromRGB(72, 44, 28),
	Color3.fromRGB(40, 168, 108),
	Color3.fromRGB(52, 136, 232),
	Color3.fromRGB(214, 142, 36),
	Color3.fromRGB(156, 76, 224),
	Color3.fromRGB(92, 114, 138),
}

local TOP_PALETTE = {
	Color3.fromRGB(32, 30, 42),    -- Sleek Club Black Tank
	Color3.fromRGB(158, 44, 212),  -- Electric Violet Party Top
	Color3.fromRGB(40, 44, 62),    -- VIP Charcoal Vest & Tie
	Color3.fromRGB(28, 152, 224),  -- Cyan Club Shirt
	Color3.fromRGB(224, 42, 128),  -- Hot Pink Bomber
	Color3.fromRGB(46, 184, 138),  -- Neon Mint Jacket
}

local BOTTOM_PALETTE = {
	Color3.fromRGB(212, 192, 158),
	Color3.fromRGB(48, 86, 148),
	Color3.fromRGB(32, 42, 82),
	Color3.fromRGB(198, 42, 118), -- Club Skirt / Party Bottom
	Color3.fromRGB(38, 38, 46),
}

local SHOE_PALETTE = {
	Color3.fromRGB(240, 240, 248),
	Color3.fromRGB(232, 52, 118),
	Color3.fromRGB(28, 28, 36),
	Color3.fromRGB(88, 52, 34),
}

local INK_COLOR = Color3.fromRGB(16, 14, 24)

local function makeBox(
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	cornerRadiusPx: number,
	withInkOutline: boolean,
	parent: Instance
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Active = false
	f.Selectable = false

	if cornerRadiusPx > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, cornerRadiusPx)
		c.Parent = f
	end

	if withInkOutline then
		local s = Instance.new("UIStroke")
		s.Color = INK_COLOR
		s.Thickness = 1.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
	end

	f.Parent = parent
	return f
end

function SpriteAnimatorModule.new(
	sheet: SpriteSheet?,
	appearance: Appearance?,
	options: RoleOptions?
): SpriteAnimator
	local role = if options and options.Role then options.Role else "Guest"
	local root = Instance.new("Frame")
	root.Name = "ClubCharacter2D"
	root.Size = UDim2.fromOffset(56, 76)
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundTransparency = 1
	root.Active = false
	root.Selectable = false

	local currentClip = "Idle"
	local currentFacing: "Left" | "Right" = "Right"
	local animClock = math.random() * 6.28
	local lastZIndex = -1
	local allGuiDescendants: { GuiObject } = {}

	-- Sprite Atlas Pathway (when AssetId ~= "" and no custom Appearance table)
	if sheet and sheet.AssetId ~= "" and appearance == nil then
		local shadow = makeBox("GroundShadow", 12, 67, 32, 9, Color3.fromRGB(0, 0, 0), 99, false, root)
		shadow.BackgroundTransparency = 0.45

		local sprite = Instance.new("ImageLabel")
		sprite.Name = "AtlasSprite"
		sprite.Size = UDim2.fromScale(1, 1)
		sprite.BackgroundTransparency = 1
		sprite.Image = sheet.AssetId
		sprite.ImageRectSize = Vector2.new(256, 256)
		sprite.Active = false
		sprite.Selectable = false
		sprite.Parent = root

		table.insert(allGuiDescendants, shadow)
		table.insert(allGuiDescendants, sprite)

		return {
			Root = root,
			Play = function(name: string)
				currentClip = name
			end,
			SetFacing = function(facing: "Left" | "Right")
				if currentFacing == facing then
					return
				end
				currentFacing = facing
				local clip = sheet.Clips[currentClip] or sheet.Clips.Idle
				local flipSign = if facing == "Left" then -1 else 1
				sprite.ImageRectSize = Vector2.new(256 * flipSign, 256)
				if clip then
					local col = (clip.FirstFrame - 1) % 4
					local row = math.floor((clip.FirstFrame - 1) / 4)
					local offsetX = if facing == "Left" then (col + 1) * 256 else col * 256
					sprite.ImageRectOffset = Vector2.new(offsetX, row * 256)
				end
			end,
			Update = function(dt: number, zIndex: number, facing: ("Left" | "Right")?)
				animClock += dt
				if zIndex ~= lastZIndex then
					lastZIndex = zIndex
					root.ZIndex = zIndex
					shadow.ZIndex = zIndex
					sprite.ZIndex = zIndex
				end
				local clip = sheet.Clips[currentClip] or sheet.Clips.Idle
				if clip then
					local frameIdx = if clip.Looped
						then math.floor(animClock * clip.FPS) % math.max(1, clip.FrameCount)
						else math.min(clip.FrameCount - 1, math.floor(animClock * clip.FPS))
					local idx = clip.FirstFrame - 1 + frameIdx
					local col = idx % 4
					local row = math.floor(idx / 4)
					local isLeft = (facing or currentFacing) == "Left"
					currentFacing = if isLeft then "Left" else "Right"
					sprite.ImageRectSize = Vector2.new(if isLeft then -256 else 256, 256)
					sprite.ImageRectOffset = Vector2.new(if isLeft then (col + 1) * 256 else col * 256, row * 256)
				end
			end,
			Destroy = function()
				root:Destroy()
			end,
		}
	end

	-- Procedural 2010 Nightclub City Flash Cartoon Vector Pathway
	local app: Appearance = appearance or {
		Skin = 2,
		Face = 1,
		Hair = 2,
		HairColor = 1,
		Eyes = 3,
		Top = 2,
		Bottom = 3,
		Shoes = 1,
	}

	local skinCol = SKIN_PALETTE[math.clamp(app.Skin, 1, #SKIN_PALETTE)]
	local hairCol = HAIR_PALETTE[math.clamp(app.HairColor, 1, #HAIR_PALETTE)]
	local eyeCol = EYE_PALETTE[math.clamp(app.Eyes, 1, #EYE_PALETTE)]
	local topCol = if role == "Bouncer"
		then Color3.fromRGB(22, 22, 30)
		elseif role == "Bartender" then Color3.fromRGB(38, 24, 58)
		else TOP_PALETTE[math.clamp(app.Top, 1, #TOP_PALETTE)]
	local botCol = if role == "Bouncer"
		then Color3.fromRGB(18, 18, 24)
		else BOTTOM_PALETTE[math.clamp(app.Bottom, 1, #BOTTOM_PALETTE)]
	local shoeCol = SHOE_PALETTE[math.clamp(app.Shoes, 1, #SHOE_PALETTE)]

	local registeredParts: { VectorPart } = {}
	local function reg(frame: Frame, bx: number, by: number, bw: number, brot: number): Frame
		table.insert(registeredParts, {
			Frame = frame,
			BaseX = bx,
			BaseY = by,
			Width = bw,
			BaseRot = brot,
		})
		table.insert(allGuiDescendants, frame)
		return frame
	end

	-- 1. Ground Shadow / Celebrity Spotlight Aura
	local shadowColor = if role == "Celebrity"
		then Color3.fromRGB(255, 214, 64)
		elseif role == "Rowdy" then Color3.fromRGB(255, 58, 92)
		else Color3.fromRGB(0, 0, 0)
	local shadow = makeBox("GroundShadow", 11, 66, 34, 9, shadowColor, 99, false, root)
	shadow.BackgroundTransparency = if role == "Celebrity" or role == "Rowdy" then 0.25 else 0.45
	table.insert(allGuiDescendants, shadow)

	local body = Instance.new("Frame")
	body.Name = "BodyContainer"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.Active = false
	body.Selectable = false
	body.Parent = root
	table.insert(allGuiDescendants, body)

	-- 2. Back Hair / Flowing Ponytail (Nightclub City layered silhouette)
	local backHair: Frame? = nil
	if app.Hair == 2 or app.Hair == 3 or app.Hair == 5 then
		backHair = reg(makeBox("BackHair", 9, 14, 15, 24, hairCol, 8, true, body), 9, 14, 15, -10)
	end

	-- 3. Sleek Tapered Legs & Club Footwear
	local legColor = if app.Bottom == 4 then skinCol else botCol
	local leftLeg = reg(makeBox("LeftLeg", 19, 50, 7, 17, legColor, 3, true, body), 19, 50, 7, 0)
	local rightLeg = reg(makeBox("RightLeg", 30, 50, 7, 17, legColor, 3, true, body), 30, 50, 7, 0)

	local leftShoe = reg(makeBox("LeftShoe", 17, 64, 10, 6, shoeCol, 3, true, body), 17, 64, 10, 0)
	local rightShoe = reg(makeBox("RightShoe", 30, 64, 10, 6, shoeCol, 3, true, body), 30, 64, 10, 0)

	-- 4. Fashionable 2010 Club Torso + Glossy Gradient + Accent Lapel/Tie/Skirt
	local torsoW = if role == "Bouncer" then 24 else 18
	local torsoX = math.floor((56 - torsoW) * 0.5)
	local torso = reg(makeBox("TorsoMain", torsoX, 34, torsoW, 19, topCol, 5, true, body), torsoX, 34, torsoW, 0)

	local torsoGrad = Instance.new("UIGradient")
	torsoGrad.Rotation = 90
	torsoGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 185, 205))
	torsoGrad.Parent = torso

	if app.Bottom == 4 and role == "Guest" then
		reg(makeBox("ClubSkirt", 18, 48, 20, 7, botCol, 3, true, body), 18, 48, 20, 0)
	else
		reg(makeBox("Belt", torsoX, 50, torsoW, 3, Color3.fromRGB(24, 24, 32), 0, false, body), torsoX, 50, torsoW, 0)
		reg(makeBox("BeltBuckle", 26, 50, 5, 3, Color3.fromRGB(245, 204, 72), 1, false, body), 26, 50, 5, 0)
	end

	-- Shirt V-neck / Neon Tie / Bartender Vest detail
	local accentColor = if role == "Bouncer"
		then Color3.fromRGB(220, 48, 88)
		elseif role == "Bartender" then Color3.fromRGB(0, 238, 255)
		else Color3.fromRGB(255, 255, 255)
	reg(makeBox("ChestAccent", 26, 35, 4, 11, accentColor, 2, false, body), 26, 35, 4, 0)

	-- 5. Arms & Optional Handheld Props (Neon Fizz Cup / Bartender Shaker)
	local leftArm = reg(makeBox("LeftArm", torsoX - 5, 35, 6, 16, skinCol, 3, true, body), torsoX - 5, 35, 6, 6)
	local rightArm = reg(makeBox("RightArm", torsoX + torsoW - 1, 35, 6, 16, skinCol, 3, true, body), torsoX + torsoW - 1, 35, 6, -6)

	if (options and options.HasDrink) or role == "Bartender" then
		local cupCol = if role == "Bartender"
			then Color3.fromRGB(210, 235, 255)
			else Color3.fromRGB(0, 245, 212)
		local cup = makeBox("FizzCup", 0, 11, 7, 9, cupCol, 2, true, rightArm)
		table.insert(allGuiDescendants, cup)
	end

	-- 6. Neck & Expressive 2010 Nightclub City Head (~34x31px sculpted proportion)
	reg(makeBox("Neck", 25, 30, 6, 6, skinCol, 2, false, body), 25, 30, 6, 0)

	local headCorner = if app.Face == 2 then 14 elseif app.Face == 3 then 8 else 11
	local head = reg(makeBox("FaceBase", 11, 4, 34, 29, skinCol, headCorner, true, body), 11, 4, 34, 0)
	local headGrad = Instance.new("UIGradient")
	headGrad.Rotation = 90
	headGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(232, 214, 206))
	headGrad.Parent = head

	-- Stylish Rosy Glow & Confident Club Smirk
	local blushL = reg(makeBox("BlushL", 14, 21, 6, 3, Color3.fromRGB(255, 118, 148), 99, false, body), 14, 21, 6, 0)
	blushL.BackgroundTransparency = 0.55
	local blushR = reg(makeBox("BlushR", 37, 21, 6, 3, Color3.fromRGB(255, 118, 148), 99, false, body), 37, 21, 6, 0)
	blushR.BackgroundTransparency = 0.55

	local mouthCol = if role == "Rowdy" then Color3.fromRGB(220, 48, 68) else Color3.fromRGB(168, 68, 82)
	reg(makeBox("Smirk", 25, 25, 8, 3, mouthCol, 99, false, body), 25, 25, 8, -4)

	-- Expressive Brows & Big 2010 Flash Eyes (Upper Lash + Iris + Specular Glint)
	local browRot = if role == "Rowdy" then 14 else -5
	reg(makeBox("BrowL", 16, 12, 8, 2, hairCol, 2, false, body), 16, 12, 8, browRot)
	reg(makeBox("BrowR", 33, 12, 8, 2, hairCol, 2, false, body), 33, 12, 8, -browRot)

	local eyeL = reg(makeBox("EyeL", 16, 15, 8, 7, Color3.fromRGB(252, 252, 255), 3, true, body), 16, 15, 8, 0)
	local eyeR = reg(makeBox("EyeR", 33, 15, 8, 7, Color3.fromRGB(252, 252, 255), 3, true, body), 33, 15, 8, 0)

	local irisL = makeBox("IrisL", 2, 1, 5, 5, eyeCol, 99, false, eyeL)
	local glintL = makeBox("GlintL", 1, 1, 2, 2, Color3.fromRGB(255, 255, 255), 99, false, irisL)
	local irisR = makeBox("IrisR", 2, 1, 5, 5, eyeCol, 99, false, eyeR)
	local glintR = makeBox("GlintR", 1, 1, 2, 2, Color3.fromRGB(255, 255, 255), 99, false, irisR)
	table.insert(allGuiDescendants, irisL)
	table.insert(allGuiDescendants, glintL)
	table.insert(allGuiDescendants, irisR)
	table.insert(allGuiDescendants, glintR)

	-- Optional Nightclub City Shades (Bouncers, Celebrities, or Stylized Clubbers)
	if role == "Bouncer" or role == "Celebrity" or (options and options.Sunglasses) then
		local shadeCol = if role == "Celebrity"
			then Color3.fromRGB(255, 48, 168) -- Neon Shutter Shades!
			else Color3.fromRGB(16, 18, 28)
		reg(makeBox("Shades", 14, 14, 29, 8, shadeCol, 3, true, body), 14, 14, 29, 0)
	end

	-- 7. Swept 2010 Hair Crown & Gloss Highlight Band
	local hairCrown = reg(makeBox("HairCrown", 10, 1, 36, 12, hairCol, 9, true, body), 10, 1, 36, 0)
	local hairShine = makeBox("HairShine", 6, 3, 22, 3, Color3.fromRGB(255, 255, 255), 99, false, hairCrown)
	hairShine.BackgroundTransparency = 0.72
	table.insert(allGuiDescendants, hairShine)

	-- Side swept bangs
	reg(makeBox("FrontBang", 11, 8, 16, 7, hairCol, 4, false, body), 11, 8, 16, -12)

	-- 8. DJ Over-Ear Neon Headphones / Celebrity Crown Star
	if role == "DJ" then
		reg(makeBox("HeadphoneBand", 9, 0, 38, 5, Color3.fromRGB(0, 240, 255), 99, true, body), 9, 0, 38, 0)
		reg(makeBox("EarCupL", 7, 13, 6, 11, Color3.fromRGB(255, 42, 168), 4, true, body), 7, 13, 6, 0)
		reg(makeBox("EarCupR", 43, 13, 6, 11, Color3.fromRGB(255, 42, 168), 4, true, body), 43, 13, 6, 0)
	elseif role == "Celebrity" then
		reg(makeBox("VIPStar", 24, -6, 9, 9, Color3.fromRGB(255, 215, 40), 3, true, body), 24, -6, 9, 45)
	end

	local function applyFacing(facing: "Left" | "Right")
		if currentFacing == facing then
			return
		end
		currentFacing = facing
		local isLeft = facing == "Left"
		for _, p in registeredParts do
			local tx = if isLeft then (56 - p.BaseX - p.Width) else p.BaseX
			p.Frame.Position = UDim2.fromOffset(tx, p.BaseY)
			if p.BaseRot ~= 0 then
				p.Frame.Rotation = if isLeft then -p.BaseRot else p.BaseRot
			end
		end
	end

	return {
		Root = root,
		Play = function(name: string)
			currentClip = name
		end,
		SetFacing = applyFacing,
		Update = function(dt: number, zIndex: number, facing: ("Left" | "Right")?)
			animClock += dt
			if facing then
				applyFacing(facing)
			end

			-- DIRTY ZINDEX CHECK: Zero ZIndex bleed (all children share exact zIndex via creation order!)
			if zIndex ~= lastZIndex then
				lastZIndex = zIndex
				root.ZIndex = zIndex
				for _, g in allGuiDescendants do
					g.ZIndex = zIndex
				end
			end

			local t = animClock
			if currentClip == "Walk" then
				local phase = t * 10
				local swing = math.sin(phase) * 24
				local bob = -math.abs(math.sin(phase)) * 2.5
				body.Position = UDim2.fromOffset(0, math.round(bob))
				leftLeg.Rotation = swing
				rightLeg.Rotation = -swing
				leftArm.Rotation = -swing
				rightArm.Rotation = swing
			elseif currentClip == "Dance" or role == "DJ" then
				local phase = t * 8.5
				local bounce = -math.abs(math.sin(phase)) * 4.5
				body.Position = UDim2.fromOffset(0, math.round(bounce))
				leftArm.Rotation = -115 + math.sin(phase) * 32 -- Classic Nightclub City hands-up pump!
				rightArm.Rotation = if role == "DJ"
					then 25 + math.cos(phase * 2) * 18 -- Turntable scratch hand!
					else 115 - math.cos(phase) * 32
				leftLeg.Rotation = math.sin(phase) * 9
				rightLeg.Rotation = -math.sin(phase) * 9
				if backHair then
					backHair.Rotation = -10 + math.sin(phase) * 14
				end
			else
				-- Smooth Idle / Bartender Mix
				local breathe = math.sin(t * 3.2) * 1.5
				body.Position = UDim2.fromOffset(0, math.round(breathe))
				leftLeg.Rotation = 0
				rightLeg.Rotation = 0
				leftArm.Rotation = math.sin(t * 3.2) * 5
				rightArm.Rotation = if role == "Bartender"
					then -35 + math.sin(t * 9) * 22 -- Mixing mocktail shaker!
					else -math.sin(t * 3.2) * 5
			end

			-- Natural blink every 3.6s
			local blinkMod = t % 3.6
			local eyeH = if blinkMod > 3.48 then 2 else 7
			eyeL.Size = UDim2.fromOffset(8, eyeH)
			eyeR.Size = UDim2.fromOffset(8, eyeH)
		end,
		Destroy = function()
			root:Destroy()
		end,
	}
end

return SpriteAnimatorModule
```

---

## MODULE 4: `src/client/ClubArt.luau` (Structural Diffing + 1:1 2010 *Nightclub City* Isometric Club Models)
Upgrade `ClubArt.luau` so:
1. **Structural Diffing (`syncWorld`):** Never destroys static floor/walls unless `GridWidth` or `GridHeight` changes, and diffs `PlacedItems` strictly by `Uid` + `(ItemId, GX, GY)`!
2. **Iconic 2010 *Nightclub City* 2.5D Props:**
   - **Exterior Street Entrance `(1, 1)`:** Velvet-rope queue carpet & glowing neon doorway arch.
   - **`NeonDancePad`:** Classic 4×4 multicolor illuminated glass sub-tiles pulsing on a **single shared beat call** (`updateBeat(clock, genre)`).
   - **`StarterDJBooth`:** Elevated stage, multi-bar LED equalizer front, dual vinyl decks, AND an embedded **Player DJ character** (`SpriteAnimator` using `state.Appearance` + `Role = "DJ"`).
   - **`FizzMocktailBar`:** Backlit neon cyan/magenta bar counter, glowing mocktail glasses, back-bar bottle shelf, AND an embedded **Bartender** (`Role = "Bartender"`).
   - **`VelvetVIPBooth`:** Plush isometric crimson/violet L-sofa, glowing cocktail table with Neon Fizz ice bucket, and gold VIP stanchion.
   - **`BassTower`:** Dual stacked concert subwoofers with pulsing cones and LED peak meter.

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local IsometricMath = require(ReplicatedStorage.Shared.IsometricMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SpriteAnimator = require(script.Parent.SpriteAnimator)

type ClubState = Types.ClubState
type PlacedItem = Types.PlacedItem
type SpriteAnimatorInstance = Types.SpriteAnimator

local ClubArt = {}

export type WorldRenderer = {
	SyncState: (state: ClubState) -> (),
	UpdateAnimations: (dt: number, beatClock: number) -> (),
	Destroy: () -> (),
}

type MountedProp = {
	ItemId: string,
	GX: number,
	GY: number,
	Root: Frame,
	BaseZ: number,
	Actor: SpriteAnimatorInstance?,
	PulseParts: { Frame },
}

local DANCE_GENRE_PALETTES: { [string]: { Color3 } } = {
	Electro = {
		Color3.fromRGB(0, 240, 255),
		Color3.fromRGB(255, 36, 168),
		Color3.fromRGB(142, 48, 255),
		Color3.fromRGB(48, 118, 255),
	},
	HipHop = {
		Color3.fromRGB(255, 196, 36),
		Color3.fromRGB(255, 62, 108),
		Color3.fromRGB(168, 48, 255),
		Color3.fromRGB(0, 224, 184),
	},
	SynthPop = {
		Color3.fromRGB(255, 72, 196),
		Color3.fromRGB(92, 238, 255),
		Color3.fromRGB(255, 224, 92),
		Color3.fromRGB(178, 96, 255),
	},
}

local function makePanel(
	name: string,
	pos: UDim2,
	size: UDim2,
	color: Color3,
	cornerPx: number,
	zIndex: number,
	parent: Instance
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Active = false
	f.Selectable = false
	f.ZIndex = zIndex
	if cornerPx > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, cornerPx)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

-- Renders an isometric diamond tile using a 45-degree rotated inner square inside a 2:1 Aspect Container
local function makeIsoDiamond(
	name: string,
	screenPos: Vector2,
	widthPx: number,
	heightPx: number,
	fillColor: Color3,
	borderColor: Color3?,
	zIndex: number,
	parent: Instance
): Frame
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
	holder.Size = UDim2.fromOffset(widthPx, heightPx)
	holder.BackgroundTransparency = 1
	holder.Active = false
	holder.Selectable = false
	holder.ZIndex = zIndex

	-- Scale Y by 0.5 via UIScale-safe inner flattening container? No—UIScale is uniform,
	-- so construct clean stepped isometric strips or rotated square inside clipped bands,
	-- OR use existing ClubArt diamond helper if tested in art.spec.luau!
	-- (Keep your existing art.spec.luau diamond helper if tests inspect specific child names,
	-- while applying these exact Nightclub City palettes & ZIndex values!)
	local innerSide = math.floor(heightPx * 1.4142)
	local sq = Instance.new("Frame")
	sq.Name = "DiamondCore"
	sq.AnchorPoint = Vector2.new(0.5, 0.5)
	sq.Position = UDim2.fromScale(0.5, 0.5)
	sq.Size = UDim2.fromOffset(innerSide, innerSide)
	sq.Rotation = 45
	sq.BackgroundColor3 = fillColor
	sq.BorderSizePixel = 0
	sq.Active = false
	sq.Selectable = false
	sq.ZIndex = zIndex
	if borderColor then
		local st = Instance.new("UIStroke")
		st.Color = borderColor
		st.Thickness = 1
		st.Parent = sq
	end
	sq.Parent = holder
	holder.Parent = parent
	return sq
end

function ClubArt.createRenderer(worldCanvas: Frame): WorldRenderer
	local staticShell = Instance.new("Frame")
	staticShell.Name = "StaticClubShell"
	staticShell.Size = UDim2.fromScale(1, 1)
	staticShell.BackgroundTransparency = 1
	staticShell.Active = false
	staticShell.Selectable = false
	staticShell.Parent = worldCanvas

	local propsLayer = Instance.new("Frame")
	propsLayer.Name = "PlacedPropsLayer"
	propsLayer.Size = UDim2.fromScale(1, 1)
	propsLayer.BackgroundTransparency = 1
	propsLayer.Active = false
	propsLayer.Selectable = false
	propsLayer.Parent = worldCanvas

	local builtW = 0
	local builtH = 0
	local activeGenre = "Electro"
	local lastBeatStep = -1
	local mounted: { [string]: MountedProp } = {}

	local function rebuildStaticShell(w: number, h: number)
		staticShell:ClearAllChildren()
		builtW = w
		builtH = h

		-- 1. Cutaway Back Walls (Left Wall along gy = 1, Right Wall along gx = 1)
		for gx = 1, w do
			local pos = IsometricMath.gridToScreen(gx, 1)
			local wallZ = IsometricMath.computeZIndex(gx, 0.5, 2)
			local wall = makePanel(
				"WallBackR_" .. gx,
				UDim2.fromOffset(pos.X, pos.Y - 108),
				UDim2.fromOffset(66, 98),
				Color3.fromRGB(22, 18, 38),
				2,
				wallZ,
				staticShell
			)
			-- Neon top crown strip (2010 Nightclub City purple/cyan architectural trim)
			makePanel("NeonCrown", UDim2.fromOffset(0, 4), UDim2.new(1, 0, 0, 4), Color3.fromRGB(0, 232, 255), 0, wallZ, wall)
			makePanel("NeonBase", UDim2.new(0, 0, 1, -4), UDim2.new(1, 0, 0, 4), Color3.fromRGB(238, 42, 168), 0, wallZ, wall)
		end

		for gy = 1, h do
			local pos = IsometricMath.gridToScreen(1, gy)
			local wallZ = IsometricMath.computeZIndex(0.5, gy, 2)
			local isDoor = (gy == 1)
			local wallCol = if isDoor then Color3.fromRGB(10, 8, 18) else Color3.fromRGB(18, 14, 32)
			local wall = makePanel(
				"WallBackL_" .. gy,
				UDim2.fromOffset(pos.X - 66, pos.Y - 108),
				UDim2.fromOffset(66, 98),
				wallCol,
				2,
				wallZ,
				staticShell
			)
			local trimCol = if isDoor then Color3.fromRGB(255, 214, 52) else Color3.fromRGB(238, 42, 168)
			makePanel("NeonCrown", UDim2.fromOffset(0, 4), UDim2.new(1, 0, 0, 5), trimCol, 0, wallZ, wall)
		end

		-- 2. Glossy Dark Slate Club Floor Grid + Velvet Entrance Carpet at (1, 1)
		for gx = 1, w do
			for gy = 1, h do
				local pos = IsometricMath.gridToScreen(gx, gy)
				local floorZ = IsometricMath.computeZIndex(gx, gy, 1)
				local checker = (gx + gy) % 2 == 0
				local tileCol = if gx == 1 and gy == 1
					then Color3.fromRGB(148, 22, 58) -- VIP Entrance Red Carpet
					elseif checker then Color3.fromRGB(26, 24, 42)
					else Color3.fromRGB(32, 30, 50)
				makeIsoDiamond(
					("Tile_%d_%d"):format(gx, gy),
					pos,
					GameConfig.TILE_WIDTH,
					GameConfig.TILE_HEIGHT,
					tileCol,
					Color3.fromRGB(48, 44, 76),
					floorZ,
					staticShell
				)
			end
		end
	end

	local function buildFurnitureVisual(uid: string, item: PlacedItem, state: ClubState): MountedProp
		local def = GameConfig.ITEMS[item.ItemId]
		local pos = IsometricMath.gridToScreen(item.GX, item.GY)
		local isDancePad = def and def.Category == "DancePad"
		local baseZ = if isDancePad
			then IsometricMath.computeZIndex(item.GX, item.GY, 3)
			else IsometricMath.furnitureZIndex(
				item.GX,
				item.GY,
				if def then def.FootprintX else 1,
				if def then def.FootprintY else 1
			)

		local root = Instance.new("Frame")
		root.Name = "Prop_" .. uid
		root.AnchorPoint = Vector2.new(0.5, 1)
		root.Position = UDim2.fromOffset(pos.X, pos.Y + 32)
		root.Size = UDim2.fromOffset(128, if def then math.max(64, def.HeightPx + 32) else 96)
		root.BackgroundTransparency = 1
		root.Active = false
		root.Selectable = false
		root.ZIndex = baseZ

		local pulseParts: { Frame } = {}
		local actor: SpriteAnimatorInstance? = nil

		if item.ItemId == "NeonDancePad" then
			-- Iconic 2010 Nightclub City 2x2 / 4-quadrant glowing glass floor pad
			local offsets = {
				Vector2.new(64, 18),
				Vector2.new(40, 30),
				Vector2.new(88, 30),
				Vector2.new(64, 42),
			}
			for i, off in offsets do
				local sub = makeIsoDiamond(
					"GlowQuad_" .. i,
					off,
					52,
					26,
					Color3.fromRGB(0, 240, 255),
					Color3.fromRGB(255, 255, 255),
					baseZ,
					root
				)
				table.insert(pulseParts, sub)
			end
		elseif item.ItemId == "StarterDJBooth" then
			-- Stage platform + Player DJ behind glossy LED equalizer console!
			makePanel("StageBase", UDim2.fromOffset(16, 78), UDim2.fromOffset(96, 46), Color3.fromRGB(28, 24, 48), 8, baseZ, root)

			actor = SpriteAnimator.new(nil, state.Appearance, { Role = "DJ" })
			actor.Play("Dance")
			actor.Root.Position = UDim2.fromOffset(64, 96)
			actor.Update(0, baseZ, "Right")
			actor.Root.Parent = root

			-- Front console renders AFTER actor in sibling tree with SAME baseZ -> cleanly occludes DJ's waist!
			local desk = makePanel("DJConsole", UDim2.fromOffset(20, 72), UDim2.fromOffset(88, 42), Color3.fromRGB(18, 18, 30), 6, baseZ, root)
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(0, 240, 255)
			stroke.Thickness = 2
			stroke.Parent = desk

			-- Dual Vinyl Platters + Front Equalizer Bars
			makePanel("TurntableL", UDim2.fromOffset(12, 4), UDim2.fromOffset(24, 10), Color3.fromRGB(45, 45, 62), 99, baseZ, desk)
			makePanel("TurntableR", UDim2.fromOffset(52, 4), UDim2.fromOffset(24, 10), Color3.fromRGB(45, 45, 62), 99, baseZ, desk)
			for b = 1, 6 do
				local eq = makePanel(
					"EQ_" .. b,
					UDim2.fromOffset(10 + (b - 1) * 12, 20),
					UDim2.fromOffset(8, 16),
					Color3.fromRGB(255, 42, 168),
					2,
					baseZ,
					desk
				)
				table.insert(pulseParts, eq)
			end
		elseif item.ItemId == "FizzMocktailBar" then
			-- Backlit bottle rack + Bartender + Front Neon Acrylic Bar Counter
			local rack = makePanel("BackRack", UDim2.fromOffset(24, 34), UDim2.fromOffset(80, 44), Color3.fromRGB(24, 18, 42), 5, baseZ, root)
			makePanel("ShelfGlow", UDim2.fromOffset(6, 10), UDim2.fromOffset(68, 8), Color3.fromRGB(0, 235, 255), 2, baseZ, rack)
			makePanel("ShelfGlow2", UDim2.fromOffset(6, 24), UDim2.fromOffset(68, 8), Color3.fromRGB(255, 48, 178), 2, baseZ, rack)

			actor = SpriteAnimator.new(nil, nil, { Role = "Bartender" })
			actor.Play("Idle")
			actor.Root.Position = UDim2.fromOffset(64, 104)
			actor.Update(0, baseZ, "Right")
			actor.Root.Parent = root

			local counter = makePanel("BarCounter", UDim2.fromOffset(16, 76), UDim2.fromOffset(96, 40), Color3.fromRGB(26, 22, 40), 6, baseZ, root)
			makePanel("CounterTop", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 9), Color3.fromRGB(0, 245, 212), 4, baseZ, counter)
			local neonFront = makePanel("NeonPanel", UDim2.fromOffset(8, 14), UDim2.fromOffset(80, 18), Color3.fromRGB(255, 42, 168), 4, baseZ, counter)
			table.insert(pulseParts, neonFront)
		elseif item.ItemId == "VelvetVIPBooth" then
			-- Plush crimson/purple tufted L-couch + glowing bottle-service table
			local sofa = makePanel("VIPSofaBack", UDim2.fromOffset(16, 48), UDim2.fromOffset(96, 48), Color3.fromRGB(152, 22, 86), 10, baseZ, root)
			makePanel("VIPSofaSeat", UDim2.fromOffset(8, 24), UDim2.fromOffset(80, 22), Color3.fromRGB(192, 34, 112), 6, baseZ, sofa)
			local tbl = makePanel("VIPTable", UDim2.fromOffset(36, 86), UDim2.fromOffset(56, 24), Color3.fromRGB(24, 28, 48), 6, baseZ, root)
			local tblGlow = makePanel("TableGlow", UDim2.fromOffset(4, 3), UDim2.fromOffset(48, 10), Color3.fromRGB(0, 238, 255), 4, baseZ, tbl)
			makePanel("IceBucket", UDim2.fromOffset(22, -8), UDim2.fromOffset(12, 12), Color3.fromRGB(255, 215, 64), 3, baseZ, tbl)
			table.insert(pulseParts, tblGlow)
		elseif item.ItemId == "BassTower" then
			-- Stacked concert speaker tower with dual pulsing woofers
			local cab = makePanel("SpeakerCab", UDim2.fromOffset(38, 24), UDim2.fromOffset(52, 98), Color3.fromRGB(22, 22, 32), 6, baseZ, root)
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(138, 52, 255)
			st.Thickness = 2
			st.Parent = cab
			local cone1 = makePanel("WooferTop", UDim2.fromOffset(10, 14), UDim2.fromOffset(32, 32), Color3.fromRGB(42, 42, 62), 99, baseZ, cab)
			local cone2 = makePanel("WooferBot", UDim2.fromOffset(10, 54), UDim2.fromOffset(32, 32), Color3.fromRGB(42, 42, 62), 99, baseZ, cab)
			table.insert(pulseParts, cone1)
			table.insert(pulseParts, cone2)
		else
			-- BouncerPost & fallback decor
			local podium = makePanel(
				"PropFallback",
				UDim2.fromOffset(34, 54),
				UDim2.fromOffset(60, 62),
				if def then def.FallbackColor else Color3.fromRGB(88, 88, 128),
				8,
				baseZ,
				root
			)
			makePanel("GoldPost", UDim2.fromOffset(26, -18), UDim2.fromOffset(8, 24), Color3.fromRGB(255, 212, 64), 4, baseZ, podium)
		end

		root.Parent = propsLayer
		return {
			ItemId = item.ItemId,
			GX = item.GX,
			GY = item.GY,
			Root = root,
			BaseZ = baseZ,
			Actor = actor,
			PulseParts = pulseParts,
		}
	end

	return {
		SyncState = function(state: ClubState)
			activeGenre = state.ActiveGenre
			if state.GridWidth ~= builtW or state.GridHeight ~= builtH then
				rebuildStaticShell(state.GridWidth, state.GridHeight)
			end

			-- Remove deleted or replaced Uids
			for uid, prop in mounted do
				local incoming = state.PlacedItems[uid]
				if not incoming or incoming.ItemId ~= prop.ItemId then
					if prop.Actor then
						prop.Actor.Destroy()
					end
					prop.Root:Destroy()
					mounted[uid] = nil
				end
			end

			-- Add new Uids or reposition moved Uids (ZERO rebuild when only Cash/Stock/Timers update!)
			for uid, item in state.PlacedItems do
				local existing = mounted[uid]
				if not existing then
					mounted[uid] = buildFurnitureVisual(uid, item, state)
				elseif existing.GX ~= item.GX or existing.GY ~= item.GY then
					existing.GX = item.GX
					existing.GY = item.GY
					local def = GameConfig.ITEMS[item.ItemId]
					local pos = IsometricMath.gridToScreen(item.GX, item.GY)
					local newZ = if def and def.Category == "DancePad"
						then IsometricMath.computeZIndex(item.GX, item.GY, 3)
						else IsometricMath.furnitureZIndex(
							item.GX,
							item.GY,
							if def then def.FootprintX else 1,
							if def then def.FootprintY else 1
						)
					existing.BaseZ = newZ
					existing.Root.Position = UDim2.fromOffset(pos.X, pos.Y + 32)
					existing.Root.ZIndex = newZ
					if existing.Actor then
						existing.Actor.Update(0, newZ, "Right")
					end
				end
			end
		end,

		UpdateAnimations = function(dt: number, beatClock: number)
			-- Update station DJs & Bartenders smoothly
			for _, prop in mounted do
				if prop.Actor then
					prop.Actor.Update(dt, prop.BaseZ, "Right")
				end
			end

			-- Step neon dance pads & EQ bars at a crisp, low-cost 8 Hz beat clock (zero per-frame color churn!)
			local beatStep = math.floor(beatClock * 8)
			if beatStep ~= lastBeatStep then
				lastBeatStep = beatStep
				local pal = DANCE_GENRE_PALETTES[activeGenre] or DANCE_GENRE_PALETTES.Electro
				for _, prop in mounted do
					for idx, part in prop.PulseParts do
						local colorIdx = ((beatStep + idx + prop.GX + prop.GY) % #pal) + 1
						part.BackgroundColor3 = pal[colorIdx]
					end
				end
			end
		end,

		Destroy = function()
			for _, prop in mounted do
				if prop.Actor then
					prop.Actor.Destroy()
				end
			end
			table.clear(mounted)
			staticShell:Destroy()
			propsLayer:Destroy()
		end,
	}
end

return ClubArt
```

---

## MODULE 5: `src/client/GlossyUI.luau` + Original *Nightclub City* HUD & Viewport Culling (`ClubClient.client.luau` & `GuestController.luau`)
Wire these two pieces into `GlossyUI.luau`, `GuestController.luau`, and `ClubClient.client.luau`:

### 5A. Viewport Frustum Culling in `GuestController.luau`
Inside `GuestController`'s `RenderStepped` update loop, advance logical state/movement for all guests using `GuestNavigation.stepAlongWaypoints`, and **cull off-screen `SpriteAnimator.Update` limb math**:

```luau
--!strict
-- Inside GuestController update(dt, canvasScreenPos, worldScale, viewportSize):
local screenOffset = IsometricMath.gridToScreen(guest.GX, guest.GY)
guest.Animator.Root.Position = UDim2.fromOffset(screenOffset.X, screenOffset.Y)

local px = canvasScreenPos.X + screenOffset.X * worldScale
local py = canvasScreenPos.Y + screenOffset.Y * worldScale
local margin = 96 * worldScale
local isVisible = px >= -margin
	and px <= viewportSize.X + margin
	and py >= -margin
	and py <= viewportSize.Y + margin

if isVisible then
	guest.Animator.Root.Visible = true
	local z = IsometricMath.characterZIndex(guest.GX, guest.GY)
	guest.Animator.Update(dt, z, guest.Facing)
else
	guest.Animator.Root.Visible = false
end
```

### 5B. 1:1 Original 2010 *Nightclub City* HUD Builder (`GlossyUI.luau` / `ClubClient.client.luau`)
Style the HUD at `ZIndex = 90000+` to replicate the exact **Booyah Nightclub City** layout while keeping every action (`RefreshSet`, `DropTheBass`, `MicShoutout`, `SetGenre`, `RestockMocktails`, `Build`, `Move`, `Remove`, `ExpandClub`, `MY LOOK`, `Zoom`) bound to your existing remotes:

```luau
--!strict
local GlossyUI = {}

export type PillStatRefs = {
	Container: Frame,
	ValueLabel: TextLabel,
	FillBar: Frame?,
}

-- Authentic 2010 Nightclub City Obsidian Chrome + Specular Glass + Neon Rim Styler
function GlossyUI.styleNeonChromePanel(frame: Frame, rimColor: Color3, cornerPx: number)
	frame.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerPx)
	corner.Parent = frame

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 52, 88)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(26, 22, 44)),
		ColorSequenceKeypoint.new(0.52, Color3.fromRGB(14, 12, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 22, 48)),
	})
	grad.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = rimColor
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

function GlossyUI.createStatPill(
	name: string,
	pos: UDim2,
	size: UDim2,
	anchor: Vector2,
	badgeText: string,
	badgeColor: Color3,
	withProgressBar: boolean,
	zIndex: number,
	parent: Instance
): PillStatRefs
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.AnchorPoint = anchor
	pill.Position = pos
	pill.Size = size
	pill.ZIndex = zIndex
	GlossyUI.styleNeonChromePanel(pill, badgeColor, 99)

	local badge = Instance.new("TextLabel")
	badge.Name = "IconBadge"
	badge.Position = UDim2.fromOffset(4, 4)
	badge.Size = UDim2.fromOffset(size.Y.Offset - 8, size.Y.Offset - 8)
	badge.BackgroundColor3 = badgeColor
	badge.BorderSizePixel = 0
	badge.Font = Enum.Font.GothamBlack
	badge.Text = badgeText
	badge.TextColor3 = Color3.fromRGB(14, 12, 24)
	badge.TextSize = 14
	badge.ZIndex = zIndex + 1
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = badge
	badge.Parent = pill

	local fill: Frame? = nil
	if withProgressBar then
		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(size.Y.Offset + 2, size.Y.Offset - 11)
		track.Size = UDim2.new(1, -(size.Y.Offset + 12), 0, 6)
		track.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
		track.BorderSizePixel = 0
		track.ZIndex = zIndex + 1
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = track
		track.Parent = pill

		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0.65, 1)
		bar.BackgroundColor3 = badgeColor
		bar.BorderSizePixel = 0
		bar.ZIndex = zIndex + 2
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = bar
		bar.Parent = track
		fill = bar
	end

	local val = Instance.new("TextLabel")
	val.Name = "Value"
	val.Position = UDim2.fromOffset(size.Y.Offset + 4, 2)
	val.Size = UDim2.new(1, -(size.Y.Offset + 12), 0, if withProgressBar then size.Y.Offset - 14 else size.Y.Offset - 4)
	val.BackgroundTransparency = 1
	val.Font = Enum.Font.GothamBlack
	val.TextXAlignment = Enum.TextXAlignment.Left
	val.TextColor3 = Color3.fromRGB(255, 255, 255)
	val.TextSize = 15
	val.Text = "0"
	val.ZIndex = zIndex + 2
	val.Parent = pill

	pill.Parent = parent
	return {
		Container = pill,
		ValueLabel = val,
		FillBar = fill,
	}
end

return GlossyUI
```

### Exact Nightclub City HUD Zones to Assemble in `ClubClient.client.luau`:
1. **Top-Left Cluster (`AnchorPoint = (0, 0)`):**
   - `CashPill` (`"$"`, emerald `Color3.fromRGB(46, 232, 128)`)
   - `StockPill` (`"FIZZ"`, cyan `Color3.fromRGB(0, 232, 255)`, with progress bar `MocktailStock / MaxMocktailStock` + quick Restock click button)
   - `SizeBadge` (`"10x10 CLUB"`, gold `Color3.fromRGB(255, 204, 52)`)
2. **Top-Right Reputation Cluster (`AnchorPoint = (1, 0)` — Exact 2010 Nightclub City Placement!):**
   - `PopularityPill` (`"POP"`, hot pink `Color3.fromRGB(255, 52, 168)`, with hype meter fill)
   - `LuxuryPill` (`"LUX"`, electric violet/diamond `Color3.fromRGB(168, 92, 255)`)
   - `GuestCountPill` (`"VIP"`, `Guests / MaxGuests`)
3. **Bottom-Left Interactive DJ Turntable Console (`AnchorPoint = (0, 1)`):**
   - Glossy dark-neon deck housing a **spinning vinyl record indicator** (rotates smoothly only while `DJSetEndsAt > now`), **Genre Switcher Pills** (`Electro` | `HipHop` | `SynthPop`), **DJ Set Countdown Bar**, and the 3 glossy circular DJ Skill buttons (`RefreshSet $50`, `DROP BASS!`, `Shoutout`) with live cooldown countdown text.
4. **Bottom-Center Neighbor / Crew Strip + Bottom-Right Builder Dock (`AnchorPoint = (1, 1)`):**
   - Keep `SocialPanel.luau` docked cleanly along bottom-center, and cluster `Build Shop` (opening a sleek Nightclub City horizontal item carousel showing procedural item thumbnails + `$Cost` + `+Pop` + `+Lux`), `Move`, `Sell (70%)`, `Expand`, `MY LOOK`, and `Zoom +/-` on the bottom-right.

---

## FINAL VERIFICATION STEPS (MANDATORY BEFORE FINISHING)
1. Run every automated test script in `tests/`:
   - `tests/run-art.mjs`
   - `tests/run-crowd.mjs`
   - `tests/run-server.mjs`
   - `tests/run-character.mjs`
   - `tests/run-pan.mjs`
2. Fix any test mock or assertion discrepancies while keeping 100% `--!strict` type compliance and `CARBON.md` mandates.
3. Confirm with a dedicated test case in `tests/crowd.spec.luau` that:
   - Neither Guests nor Bouncers ever occupy or cross a tile covered by `MocktailBar`, `DJBooth`, `Speaker`, `VIPBooth`, or `BouncerPost`.
   - Placing furniture onto an active guest immediately relocates them to a walkable tile via `nearestWalkable`.
