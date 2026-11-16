--!strict
-- 2D breadth-first search and point-clearance navigation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

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
			local rot = placed.Rot or 0
			local fx = math.max(1, def.FootprintX)
			local fy = math.max(1, def.FootprintY)
			if rot % 2 ~= 0 then
				fx, fy = fy, fx
			end
			for ix = placed.GX, placed.GX + fx - 1 do
				for iy = placed.GY, placed.GY + fy - 1 do
					if ix >= 1 and ix <= width and iy >= 1 and iy <= height then
						blocked[cellKey(width, ix, iy)] = true
					end
				end
			end
		end
	end
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

-- Prevents continuous float positions from cutting into a blocked footprint box
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
): Vector2?
	local candidates: { Vector2 } = {}
	local fx = math.max(1, def.FootprintX)
	local fy = math.max(1, def.FootprintY)

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
	return pick
end

-- Pure 4-connected orthogonal BFS (zero diagonal corner clipping across furniture edges!)
function GuestNavigation.findPath(
	grid: NavGrid,
	fromX: number,
	fromY: number,
	toX: number,
	toY: number
): { Vector2 }?
	local sx = math.clamp(math.round(fromX), 1, grid.Width)
	local sy = math.clamp(math.round(fromY), 1, grid.Height)
	local tx = math.clamp(math.round(toX), 1, grid.Width)
	local ty = math.clamp(math.round(toY), 1, grid.Height)

	if not GuestNavigation.isWalkable(grid, sx, sy) or not GuestNavigation.isWalkable(grid, tx, ty) then
		return nil
	end

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
		return nil
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

-- Step along waypoints: prevents ANY movement into blocked tiles
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
		local centerX = math.round(curX)
		local centerY = math.round(curY)
		return centerX, centerY, waypointIndex, facing, false
	end
end

-- Compatibility wrapper for Navigation.new(state)
function GuestNavigation.new(state: Types.ClubState)
	local grid = GuestNavigation.buildGrid(state.GridWidth, state.GridHeight, state.PlacedItems)
	return {
		Grid = grid,
		Walkable = function(x: number, y: number): boolean
			return GuestNavigation.isWalkable(grid, x, y)
		end,
		NearestWalkable = function(x: number, y: number): Vector2
			local nx, ny = GuestNavigation.nearestWalkable(grid, x, y)
			return Vector2.new(nx, ny)
		end,
		Path = function(from: Vector2, target: Vector2): { Vector2 }?
			return GuestNavigation.findPath(grid, from.X, from.Y, target.X, target.Y)
		end,
	}
end

return GuestNavigation

