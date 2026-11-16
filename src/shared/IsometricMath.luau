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

-- Compatible with CARBON.md Section 3.5 formula:
-- ZIndex = clamp(floor((gx + gy) * 10) + layerOffset, 1, 100000)
local INTERIOR_Z_BASE = 300
local WALL_Z_BASE = 200

function IsometricMath.computeZIndex(gx: number, gy: number, layerOffset: number): number
	local raw = math.floor((gx + gy) * 10) + layerOffset
	return math.clamp(raw, 1, 79999)
end

function IsometricMath.getZIndex(gx: number, gy: number, layerOffset: number): number
	local depthBucket = math.floor((gx + gy) * 10)
	return math.clamp(depthBucket + layerOffset, 1, 100000)
end

function IsometricMath.getExteriorQueueZIndex(gx: number, gy: number): number
	local raw = 40 + math.floor((gx + gy) * 10)
	return math.clamp(raw, 10, WALL_Z_BASE - 10)
end

function IsometricMath.getCutawayWallZIndex(gx: number, gy: number, isSignDecor: boolean?): number
	local raw = WALL_Z_BASE + math.floor((gx + gy) * 2) + (if isSignDecor then 40 else 0)
	return math.clamp(raw, WALL_Z_BASE, INTERIOR_Z_BASE - 5)
end

function IsometricMath.getInteriorZIndex(gx: number, gy: number, layerOffset: number): number
	local raw = INTERIOR_Z_BASE + math.floor((gx + gy) * 10) + layerOffset
	return math.clamp(raw, INTERIOR_Z_BASE, 79999)
end

-- Front-most plane depth for multi-tile solid furniture so characters behind NEVER bleed over front faces,
-- and characters in front ALWAYS render cleanly on top of the item:
function IsometricMath.furnitureZIndex(gx: number, gy: number, footprintX: number, footprintY: number): number
	local frontGX = gx + math.max(0, footprintX - 1) + 0.15
	local frontGY = gy + math.max(0, footprintY - 1) + 0.15
	return IsometricMath.getInteriorZIndex(frontGX, frontGY, LAYER_OFFSETS.Entity)
end

-- Foot-anchor depth for walking guests & bouncers:
function IsometricMath.characterZIndex(gx: number, gy: number): number
	if gx < 0.9 or gy < 0.9 then
		return IsometricMath.getExteriorQueueZIndex(gx, gy)
	else
		return IsometricMath.getInteriorZIndex(gx, gy, LAYER_OFFSETS.Entity)
	end
end

return IsometricMath
