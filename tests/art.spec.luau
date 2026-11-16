--!strict
rebuildWorld()
assert(#ObjectLayer:GetChildren() == 6,"missing furniture category")
assert(#PulsePads > 0,"dance lighting not registered")
local function validGeometry(parent)
	for _, item in parent:GetDescendants() do
		assert(item.ClassName == "UIGradient" or item.ClassName == "Frame" or item.ClassName == "ImageButton" or item.ClassName == "UICorner" or item.ClassName == "UIStroke" or item.ClassName == "TextLabel", "non-UI instance")
		if item.Size then
			assert(item.Size.X.Offset == item.Size.X.Offset and item.Size.X.Offset > 0, "invalid width")
			assert(item.Size.Y.Offset == item.Size.Y.Offset and item.Size.Y.Offset > 0, "invalid height")
		end
	end
end
validGeometry(TileLayer)
validGeometry(ObjectLayer)
for _, button in ObjectLayer:GetChildren() do
	for _, child in button:GetDescendants() do
		if child.ZIndex then assert(child.ZIndex == button.ZIndex,"furniture depth differs from root") end
	end
end
print("PASS six furniture categories, finite geometry, UI-only artwork, and furniture depth")
print("10x10 room instances:",#TileLayer:GetDescendants())
assert(#TileLayer:GetDescendants() < 1500,"room complexity regression")
local created = #instances
CurrentState.Cash += 100
rebuildWorld()
assert(#instances == created,"income update rebuilt artwork")
local oldPads = PulsePads[1]
local roomPart = TileLayer:GetChildren()[1]
CurrentState.PlacedItems.BassTower.GX = 9
rebuildWorld()
assert(oldPads.Destroyed and PulsePads[1] ~= oldPads,"layout edit did not replace artwork/effects")
assert(not roomPart.Destroyed and roomPart == TileLayer:GetChildren()[1],"furniture edit rebuilt static room")
MovingItemUid = "BassTower"
rebuildWorld()
local faded = false
for _, child in ObjectLayer:GetDescendants() do if child.BackgroundTransparency == 0.6 then faded = true end end
assert(faded,"move selection not faded")
print("PASS cash-update cache, layout invalidation, effect replacement, and move selection")
local oldTint = PulsePads[1].BackgroundColor3
HoverTile.ZIndex = 98
local tint = Color3.new(1,0,0)
HoverTile.BackgroundColor3 = tint
effects(0.11)
assert(PulsePads[1].BackgroundColor3 ~= oldTint,"dance lighting does not advance")
local edges = HoverTile:GetChildren()
assert(#edges == 4,"diamond cursor missing sides")
for _, edge in edges do
	assert(edge.ZIndex == 98 and edge.BackgroundColor3 == tint,"cursor color/depth not updated")
end
print("PASS production frame loop updates dance lighting and cursor depth/color")
MovingItemUid = nil
CurrentState.GridWidth, CurrentState.GridHeight = 20,20
rebuildWorld()
validGeometry(TileLayer)
print("20x20 room instances:",#TileLayer:GetDescendants())
assert(#TileLayer:GetDescendants() < 2500,"large-room complexity regression")
print("PASS maximum-size room construction (not a Studio FPS measurement)")

for _, id in {"DJRefresh","DJBass","DJShout","Restock","BuildShop","MoveItem","SellItem"} do
	local button = Instance.new("Frame")
	button.ZIndex, button.Size = 90001, UDim2.fromOffset(76,68)
	modules.HudIcons.draw(button,id)
	assert(#button:GetChildren() > 0, "missing toolbar artwork: " .. id)
	validGeometry(button)
	for _, child in button:GetChildren() do
		assert(child.ZIndex == 90002, "toolbar icon below button")
		assert(child.Position.X.Offset >= 0 and child.Position.X.Offset + child.Size.X.Offset <= 76, "icon outside button")
	end
end
print("PASS seven toolbar illustrations, bounds, and layering")
