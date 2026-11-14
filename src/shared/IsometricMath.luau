--!strict
local GameConfig = require(script.Parent.GameConfig)

local IsometricMath = {}

local HALF_W = GameConfig.TILE_WIDTH * 0.5
local HALF_H = GameConfig.TILE_HEIGHT * 0.5

function IsometricMath.gridToScreen(gx: number, gy: number): Vector2
	local sx = (gx - gy) * HALF_W
	local sy = (gx + gy) * HALF_H
	return Vector2.new(sx, sy)
end

function IsometricMath.screenToGrid(sx: number, sy: number): (number, number)
	local a = sx / HALF_W
	local b = sy / HALF_H
	local gx = math.round((a + b) * 0.5)
	local gy = math.round((b - a) * 0.5)
	return gx, gy
end

function IsometricMath.getZIndex(gx: number, gy: number, layerOffset: number): number
	local depthBucket = math.floor((gx + gy) * 10)
	return math.clamp(depthBucket + layerOffset, 1, 100000)
end

return IsometricMath