--!strict
local originalNew = Instance.new
Instance.new = function(class)
	local object = originalNew(class)
	object.Activated = {Connect = function() end}
	function object:GetChildren()
		local children = {}
		for _, other in instances do if other.Parent == self and not other.Destroyed then table.insert(children,other) end end
		return children
	end
	function object:GetDescendants()
		local result = {}
		for _, child in self:GetChildren() do
			table.insert(result,child)
			for _, descendant in child:GetDescendants() do table.insert(result,descendant) end
		end
		return result
	end
	function object:ClearAllChildren() for _, child in self:GetChildren() do child:Destroy() end end
	function object:IsA(name) return self.ClassName == name end
	return object
end
local ClubArt, Iso, GameConfig = modules.ClubArt, modules.IsometricMath, modules.GameConfig
local CurrentState = {GridWidth = 10, GridHeight = 10, Cash = 2500, PlacedItems = {}}
for index, id in {"NeonDancePad","BassTower","FizzMocktailBar","StarterDJBooth","VelvetVIPBooth","BouncerStation"} do
	CurrentState.PlacedItems[id] = {Uid=id,ItemId=id,GX=index+1,GY=4}
end
local MovingItemUid, MovingItemId, CurrentMode = nil, nil, "None"
local TileLayer, ObjectLayer = Instance.new("Folder"), Instance.new("Folder")
local hoverCalls = 0
local function updateHoverCursor() hoverCalls += 1 end
local function refreshHud() end
local ActionFn = {InvokeServer = function() end}
local task = {spawn = function(fn) fn() end}
local HoverTile = Instance.new("Frame")
HoverTile.ZIndex = 80000
HoverTile.BackgroundColor3 = Color3.new(0,1,0)
ClubArt.cursor(HoverTile)

local panDirection = Vector2.new(0,0)

local HoverEdges = HoverTile:GetChildren()
