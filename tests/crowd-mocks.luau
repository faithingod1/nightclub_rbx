--!strict
-- Minimal deterministic Roblox UI stand-ins. Real production modules run below.
local modules = {}
local function require(name) return assert(modules[name], name) end
local service = setmetatable({}, { __index = function(_, name) return name end })
function service:WaitForChild(name) return name == "Shared" and self or name end
local game = { GetService = function() return service end }
local script = { Parent = service }
local Vector2 = {}
local vectorMeta = {}
function Vector2.new(x, y) return setmetatable({ X = x, Y = y }, vectorMeta) end
vectorMeta.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
vectorMeta.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
vectorMeta.__mul = function(a, b) return Vector2.new(a.X * b, a.Y * b) end
vectorMeta.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
vectorMeta.__index = function(a, key)
	local length = math.sqrt(a.X * a.X + a.Y * a.Y)
	if key == "Magnitude" then return length end
	if key == "Unit" then return Vector2.new(a.X / length, a.Y / length) end
	return nil
end
local Color3 = {}
function Color3.new(r, g, b) return { R = r, G = g, B = b, Lerp = function(self) return self end } end
Color3.fromRGB = Color3.new
Color3.fromHSV = Color3.new
local UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
local UDim2 = {
	new = function(sx, x, sy, y) return { X = { Scale = sx, Offset = x }, Y = { Scale = sy, Offset = y } } end,
}
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local Enum = { Font = { GothamBold = 1 } }
local Random = { new = function()
	return { NextNumber = function(_, a, b) return a + math.random() * (b - a) end,
		NextInteger = function(_, a, b) return math.random(a, b) end }
end }
local instances = {}
local Instance = {}
function Instance.new(class)
	local object = { ClassName = class }
	function object:Destroy()
		self.Destroyed = true
		for _, child in instances do if child.Parent == self and not child.Destroyed then child:Destroy() end end
	end
	table.insert(instances, object)
	return object
end
