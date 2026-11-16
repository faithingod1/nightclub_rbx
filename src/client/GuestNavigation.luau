--!strict
-- Small 2D breadth-first search; no Roblox pathfinding or physics.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = require(Shared:WaitForChild("GameConfig"))
local Navigation = {}

function Navigation.new(state: Types.ClubState)
	local blocked: { [string]: boolean } = {}
	local function key(x: number, y: number): string
		return x .. ":" .. y
	end
	for _, item in state.PlacedItems do
		local def = Config.ITEMS[item.ItemId]
		if def and def.Category ~= "DancePad" and def.Category ~= "Floor" then
			for x = item.GX, item.GX + def.FootprintX - 1 do
				for y = item.GY, item.GY + def.FootprintY - 1 do
					blocked[key(x, y)] = true
				end
			end
		end
	end
	local function walkable(x: number, y: number): boolean
		return x >= 1 and y >= 1 and x <= state.GridWidth and y <= state.GridHeight and not blocked[key(x, y)]
	end
	local function nearestWalkable(x: number, y: number): Vector2
		local gx, gy = math.clamp(math.round(x), 1, state.GridWidth), math.clamp(math.round(y), 1, state.GridHeight)
		if walkable(gx, gy) then return Vector2.new(gx, gy) end
		for r = 1, math.max(state.GridWidth, state.GridHeight) do
			for dx = -r, r do
				for dy = -r, r do
					if math.abs(dx) == r or math.abs(dy) == r then
						local nx, ny = gx + dx, gy + dy
						if walkable(nx, ny) then return Vector2.new(nx, ny) end
					end
				end
			end
		end
		return Vector2.new(1, 1)
	end
	local function path(from: Vector2, target: Vector2): { Vector2 }?
		local start = Vector2.new(math.clamp(math.round(from.X), 1, state.GridWidth), math.clamp(math.round(from.Y), 1, state.GridHeight))
		local goal = Vector2.new(math.round(target.X), math.round(target.Y))
		if not walkable(goal.X, goal.Y) then return nil end
		local queue: { Vector2 } = { start }
		local previous: { [string]: Vector2 } = {}
		local seen: { [string]: boolean } = { [key(start.X, start.Y)] = true }
		local head = 1
		while head <= #queue do
			local cell = queue[head]
			head += 1
			if cell == goal then
				local result: { Vector2 } = { target }
				while cell ~= start do
					table.insert(result, 1, cell)
					cell = previous[key(cell.X, cell.Y)]
				end
				-- Recenter before turning: avoids diagonal corner-cutting on replans.
				table.insert(result, 1, start)
				return result
			end
			for _, delta in { Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(0, -1) } do
				local nextCell = cell + delta
				local id = key(nextCell.X, nextCell.Y)
				if walkable(nextCell.X, nextCell.Y) and not seen[id] then
					seen[id] = true
					previous[id] = cell
					table.insert(queue, nextCell)
				end
			end
		end
		return nil
	end
	return { Walkable = walkable, Path = path, NearestWalkable = nearestWalkable }
end

return Navigation
