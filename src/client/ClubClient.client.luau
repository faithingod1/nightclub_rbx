--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

task.spawn(function()
	for _ = 1, 5 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		if ok then
			break
		end
		task.wait(0.2)
	end
end)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Iso = require(Shared:WaitForChild("IsometricMath"))

local Remotes = ReplicatedStorage:WaitForChild("ClubRemotes")
local GetStateFn = Remotes:WaitForChild("GetClubState") :: RemoteFunction
local ActionFn = Remotes:WaitForChild("PerformClubAction") :: RemoteFunction
local StateUpdatedEv = Remotes:WaitForChild("ClubStateUpdated") :: RemoteEvent

local CurrentState: Types.ClubState = GetStateFn:InvokeServer()
local Guests: { Types.GuestEntity } = {}
local SpriteAnimator = require(script.Parent:WaitForChild("SpriteAnimator"))
local GlossyUI = require(script.Parent:WaitForChild("GlossyUI"))
local ClubArt = require(script.Parent:WaitForChild("ClubArt"))
local Animators: { [number]: Types.SpriteAnimator } = {}

-- Viewport Zoom constants
local MIN_ZOOM = 0.5
local MAX_ZOOM = 1.8
local currentZoom = 1.0

-- Edit mode states
local CurrentMode: Types.EditMode = "None"
local SelectedBuildItem: string? = nil
local MovingItemUid: string? = nil
local MovingItemId: string? = nil

-- UI Root ScreenGui
local Screen = Instance.new("ScreenGui")
Screen.Name = "NeonClub2DGui"
Screen.IgnoreGuiInset = true
Screen.ResetOnSpawn = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
Screen.Parent = PlayerGui

local Backdrop = Instance.new("Frame")
Backdrop.Size = UDim2.fromScale(1, 1)
Backdrop.BackgroundColor3 = Color3.fromRGB(14, 12, 26)
Backdrop.BorderSizePixel = 0
Backdrop.Parent = Screen

-- Isometric Canvas with UIScale for mouse-wheel zoom
local WorldCanvas = Instance.new("Frame")
WorldCanvas.Name = "IsometricWorld"
WorldCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
WorldCanvas.Position = UDim2.new(0.5, 0, 0.28, 0)
WorldCanvas.Size = UDim2.fromOffset(0, 0)
WorldCanvas.BackgroundTransparency = 1
WorldCanvas.Parent = Backdrop

local WorldScale = Instance.new("UIScale")
WorldScale.Scale = currentZoom
WorldScale.Parent = WorldCanvas

local TileLayer = Instance.new("Folder")
TileLayer.Name = "Tiles"
TileLayer.Parent = WorldCanvas

local ObjectLayer = Instance.new("Folder")
ObjectLayer.Name = "Objects"
ObjectLayer.Parent = WorldCanvas

local CursorLayer = Instance.new("Folder")
CursorLayer.Name = "CursorLayer"
CursorLayer.Parent = WorldCanvas

local GuestLayer = Instance.new("Folder")
GuestLayer.Name = "Guests"
GuestLayer.Parent = WorldCanvas

-- Glowing Hover Tile & Ghost Preview
local HoverTile = Instance.new("Frame")
HoverTile.Name = "HoverTile"
HoverTile.AnchorPoint = Vector2.new(0.5, 0.5)
HoverTile.Size = UDim2.fromOffset(68, 68)
HoverTile.Rotation = 45
HoverTile.BorderSizePixel = 0
HoverTile.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
HoverTile.BackgroundTransparency = 0.65
HoverTile.Visible = false
HoverTile.ZIndex = 80000
HoverTile.Parent = CursorLayer

local HoverStroke = Instance.new("UIStroke")
HoverStroke.Thickness = 2.5
HoverStroke.Color = Color3.fromRGB(0, 255, 200)
HoverStroke.Transparency = 0.1
HoverStroke.Parent = HoverTile

local GhostPreview = Instance.new("ImageLabel")
GhostPreview.Name = "GhostPreview"
GhostPreview.AnchorPoint = Vector2.new(0.5, 1)
GhostPreview.Size = UDim2.fromOffset(88, 80)
GhostPreview.BorderSizePixel = 0
GhostPreview.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
GhostPreview.BackgroundTransparency = 0.45
GhostPreview.Visible = false
GhostPreview.ZIndex = 80005
GhostPreview.Parent = CursorLayer

local GhostCorner = Instance.new("UICorner")
GhostCorner.CornerRadius = UDim.new(0, 8)
GhostCorner.Parent = GhostPreview

local GhostStroke = Instance.new("UIStroke")
GhostStroke.Thickness = 2
GhostStroke.Color = Color3.fromRGB(0, 255, 200)
GhostStroke.Parent = GhostPreview

local GhostLabel = Instance.new("TextLabel")
GhostLabel.Size = UDim2.new(1, 0, 0, 22)
GhostLabel.Position = UDim2.new(0, 0, 0, 4)
GhostLabel.BackgroundTransparency = 1
GhostLabel.Font = Enum.Font.GothamBold
GhostLabel.TextSize = 11
GhostLabel.TextColor3 = Color3.new(1, 1, 1)
GhostLabel.ZIndex = 80006
GhostLabel.Parent = GhostPreview

local TooltipBadge = Instance.new("TextLabel")
TooltipBadge.Name = "TooltipBadge"
TooltipBadge.AnchorPoint = Vector2.new(0.5, 1)
TooltipBadge.Size = UDim2.fromOffset(200, 28)
TooltipBadge.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
TooltipBadge.TextColor3 = Color3.new(1, 1, 1)
TooltipBadge.Font = Enum.Font.GothamBold
TooltipBadge.TextSize = 12
TooltipBadge.ZIndex = 90050
TooltipBadge.Visible = false
TooltipBadge.Parent = Backdrop

local TooltipCorner = Instance.new("UICorner")
TooltipCorner.CornerRadius = UDim.new(0, 6)
TooltipCorner.Parent = TooltipBadge

local TooltipStroke = Instance.new("UIStroke")
TooltipStroke.Thickness = 1.5
TooltipStroke.Color = Color3.fromRGB(0, 255, 200)
TooltipStroke.Parent = TooltipBadge

-- Helper to convert mouse position to grid tile accounting for GUI inset and UIScale
local function getMouseGrid(): (number, number, boolean)
	local mousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local rel = mousePos - WorldCanvas.AbsolutePosition
	local unscaledRel = rel / WorldScale.Scale
	local gx, gy = Iso.screenToGrid(unscaledRel.X, unscaledRel.Y)
	local inBounds = (gx >= 1 and gx <= CurrentState.GridWidth and gy >= 1 and gy <= CurrentState.GridHeight)
	return gx, gy, inBounds
end

local function getPlacedItemAt(gx: number, gy: number): Types.PlacedItem?
	for _, item in CurrentState.PlacedItems do
		if item.GX == gx and item.GY == gy then
			return item
		end
	end
	return nil
end

-- Panning state
local isPanning = false
local panStart = Vector2.zero
local canvasStart = WorldCanvas.Position
local panMoved = false

-- Forward declaration of UI refresh functions
local refreshHud: () -> ()
local updateDockStyles: () -> ()
local updateHoverCursor: () -> ()
local rebuildWorld: () -> ()

local function setMode(mode: Types.EditMode, buildItemId: string?)
	if CurrentMode == mode and SelectedBuildItem == buildItemId and mode ~= "None" then
		CurrentMode = "None"
		SelectedBuildItem = nil
		MovingItemUid = nil
		MovingItemId = nil
	else
		CurrentMode = mode
		SelectedBuildItem = if mode == "Build" then (buildItemId or "NeonDancePad") else nil
		MovingItemUid = nil
		MovingItemId = nil
	end
	updateDockStyles()
	updateHoverCursor()
	refreshHud()
	rebuildWorld()
end

-- Real-time hover cursor & ghost preview updater
function updateHoverCursor()
	local gx, gy, inBounds = getMouseGrid()

	if not inBounds then
		HoverTile.Visible = false
		GhostPreview.Visible = false
		TooltipBadge.Visible = false
		return
	end

	local pos = Iso.gridToScreen(gx, gy)
	local occupied = getPlacedItemAt(gx, gy)
	local screenPos = WorldCanvas.AbsolutePosition + (pos * WorldScale.Scale)

	HoverTile.Position = UDim2.fromOffset(pos.X, pos.Y)
	HoverTile.ZIndex = Iso.getZIndex(gx, gy, 8)

	if CurrentMode == "Build" and SelectedBuildItem then
		local def = GameConfig.ITEMS[SelectedBuildItem]
		if not def then
			HoverTile.Visible = false
			GhostPreview.Visible = false
			TooltipBadge.Visible = false
			return
		end

		local canAfford = CurrentState.Cash >= def.Cost
		local isValid = (not occupied) and canAfford

		local tintColor = if isValid
			then Color3.fromRGB(34, 197, 94)
			elseif occupied then Color3.fromRGB(239, 68, 68)
			else Color3.fromRGB(245, 158, 11)

		HoverTile.Visible = true
		HoverTile.BackgroundColor3 = tintColor
		HoverStroke.Color = tintColor

		GhostPreview.Visible = true
		GhostPreview.Position = UDim2.fromOffset(pos.X, pos.Y + GameConfig.TILE_HEIGHT * 0.35)
		GhostPreview.Size = UDim2.fromOffset(88, def.HeightPx)
		GhostPreview.BackgroundColor3 = def.FallbackColor
		GhostPreview.Image = def.AssetId
		GhostPreview.ZIndex = Iso.getZIndex(gx, gy, 9)
		GhostStroke.Color = tintColor
		GhostLabel.Text = def.Name

		TooltipBadge.Visible = true
		TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - (def.HeightPx * WorldScale.Scale) - 10)
		TooltipStroke.Color = tintColor

		if not canAfford then
			TooltipBadge.Text = string.format("Need $%d (Have $%d)", def.Cost, CurrentState.Cash)
			TooltipBadge.TextColor3 = Color3.fromRGB(252, 165, 165)
		elseif occupied then
			TooltipBadge.Text = "Tile Already Occupied!"
			TooltipBadge.TextColor3 = Color3.fromRGB(252, 165, 165)
		else
			TooltipBadge.Text = string.format("Build: %s ($%d)", def.Name, def.Cost)
			TooltipBadge.TextColor3 = Color3.fromRGB(187, 247, 208)
		end

	elseif CurrentMode == "Move" then
		if MovingItemUid == nil then
			HoverTile.Visible = true
			if occupied then
				local def = GameConfig.ITEMS[occupied.ItemId]
				local name = if def then def.Name else occupied.ItemId
				HoverTile.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
				HoverStroke.Color = Color3.fromRGB(245, 158, 11)
				GhostPreview.Visible = false
				TooltipBadge.Visible = true
				TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - 40)
				TooltipStroke.Color = Color3.fromRGB(245, 158, 11)
				TooltipBadge.Text = "Click to Pick Up: " .. name
				TooltipBadge.TextColor3 = Color3.fromRGB(254, 240, 138)
			else
				HoverTile.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
				HoverStroke.Color = Color3.fromRGB(148, 163, 184)
				GhostPreview.Visible = false
				TooltipBadge.Visible = true
				TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - 30)
				TooltipStroke.Color = Color3.fromRGB(148, 163, 184)
				TooltipBadge.Text = "Click an item to move"
				TooltipBadge.TextColor3 = Color3.fromRGB(226, 232, 240)
			end
		else
			local def = if MovingItemId then GameConfig.ITEMS[MovingItemId] else nil
			local isValid = (not occupied) or (occupied.Uid == MovingItemUid)
			local tintColor = if isValid then Color3.fromRGB(34, 197, 94) else Color3.fromRGB(239, 68, 68)

			HoverTile.Visible = true
			HoverTile.BackgroundColor3 = tintColor
			HoverStroke.Color = tintColor

			if def then
				GhostPreview.Visible = true
				GhostPreview.Position = UDim2.fromOffset(pos.X, pos.Y + GameConfig.TILE_HEIGHT * 0.35)
				GhostPreview.Size = UDim2.fromOffset(88, def.HeightPx)
				GhostPreview.BackgroundColor3 = def.FallbackColor
				GhostPreview.Image = def.AssetId
				GhostPreview.ZIndex = Iso.getZIndex(gx, gy, 9)
				GhostStroke.Color = tintColor
				GhostLabel.Text = "Moving: " .. def.Name

				TooltipBadge.Visible = true
				TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - (def.HeightPx * WorldScale.Scale) - 10)
				TooltipStroke.Color = tintColor
				TooltipBadge.Text = if isValid then "Click to Relocate Here" else "Tile Occupied!"
				TooltipBadge.TextColor3 = if isValid then Color3.fromRGB(187, 247, 208) else Color3.fromRGB(252, 165, 165)
			else
				GhostPreview.Visible = false
				TooltipBadge.Visible = false
			end
		end

	elseif CurrentMode == "Remove" then
		HoverTile.Visible = true
		GhostPreview.Visible = false
		if occupied then
			local def = GameConfig.ITEMS[occupied.ItemId]
			local refund = if def then math.floor(def.Cost * 0.7) else 0
			local name = if def then def.Name else occupied.ItemId

			HoverTile.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
			HoverStroke.Color = Color3.fromRGB(239, 68, 68)
			TooltipBadge.Visible = true
			TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - 40)
			TooltipStroke.Color = Color3.fromRGB(239, 68, 68)
			TooltipBadge.Text = string.format("Sell %s (+$%d)", name, refund)
			TooltipBadge.TextColor3 = Color3.fromRGB(254, 202, 202)
		else
			HoverTile.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
			HoverStroke.Color = Color3.fromRGB(148, 163, 184)
			TooltipBadge.Visible = true
			TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - 30)
			TooltipStroke.Color = Color3.fromRGB(148, 163, 184)
			TooltipBadge.Text = "Click an item to sell"
			TooltipBadge.TextColor3 = Color3.fromRGB(226, 232, 240)
		end
	else
		HoverTile.Visible = false
		GhostPreview.Visible = false
		TooltipBadge.Visible = false
	end
end

-- World Rebuild (Tiles & Placed Items)
local lastLayout = ""
function rebuildWorld()
	local entries = { tostring(CurrentState.GridWidth), tostring(CurrentState.GridHeight), MovingItemUid or "" }
	for uid, item in CurrentState.PlacedItems do table.insert(entries, uid .. item.ItemId .. ":" .. item.GX .. ":" .. item.GY) end
	table.sort(entries)
	local signature = table.concat(entries, "|")
	if signature == lastLayout then updateHoverCursor(); return end
	lastLayout = signature
	TileLayer:ClearAllChildren()
	ObjectLayer:ClearAllChildren()
	ClubArt.room(TileLayer, CurrentState.GridWidth, CurrentState.GridHeight)

	for _, placed in CurrentState.PlacedItems do
		local def = GameConfig.ITEMS[placed.ItemId]
		if not def then
			continue
		end
		local pos = Iso.gridToScreen(placed.GX, placed.GY)
		local zLayer = if def.Category == "DancePad" then 3 else 5
		local isBeingMoved = (placed.Uid == MovingItemUid)

		local itemBtn = Instance.new("ImageButton")
		itemBtn.AnchorPoint = Vector2.new(0.5, 1)
		itemBtn.Position = UDim2.fromOffset(pos.X, pos.Y + GameConfig.TILE_HEIGHT * 0.35)
		itemBtn.Size = if def.Category == "DancePad" then UDim2.fromOffset(128,64) else UDim2.fromOffset(88, def.HeightPx)
		if def.Category == "DancePad" then itemBtn.Position = UDim2.fromOffset(pos.X,pos.Y+32) end
		itemBtn.BackgroundColor3 = def.FallbackColor
		itemBtn.BackgroundTransparency = 1
		itemBtn.Image = def.AssetId
		itemBtn.BorderSizePixel = 0
		itemBtn.AutoButtonColor = false
		itemBtn.ZIndex = Iso.getZIndex(placed.GX, placed.GY, zLayer)
		itemBtn.Parent = ObjectLayer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = itemBtn

		if isBeingMoved then
			local selectStroke = Instance.new("UIStroke")
			selectStroke.Thickness = 2
			selectStroke.Color = Color3.fromRGB(245, 158, 11)
			selectStroke.Parent = itemBtn
		end

		if def.AssetId == "" then ClubArt.furniture(itemBtn, def) end
		if isBeingMoved then
			for _, child in itemBtn:GetDescendants() do
				if child:IsA("Frame") then child.BackgroundTransparency = 0.6 end
			end
		end

		-- Direct item click handler for Move and Remove
		itemBtn.Activated:Connect(function()
			if CurrentMode == "Remove" then
				task.spawn(function()
					ActionFn:InvokeServer("RemoveItem", { Uid = placed.Uid })
				end)
			elseif CurrentMode == "Move" and MovingItemUid == nil then
				MovingItemUid = placed.Uid
				MovingItemId = placed.ItemId
				rebuildWorld()
				updateHoverCursor()
				refreshHud()
			end
		end)
	end

	updateHoverCursor()
end

-- Ground tile input & World Panning
Backdrop.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
		isPanning = true
		panMoved = false
		panStart = UserInputService:GetMouseLocation()
		canvasStart = WorldCanvas.Position

	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		local gx, gy, inBounds = getMouseGrid()
		if not inBounds then
			return
		end
		local occupied = getPlacedItemAt(gx, gy)

		if CurrentMode == "Build" and SelectedBuildItem then
			if not occupied then
				local buildItem = SelectedBuildItem
				task.spawn(function()
					ActionFn:InvokeServer("PlaceItem", { ItemId = buildItem, GX = gx, GY = gy })
				end)
			end
		elseif CurrentMode == "Move" then
			if MovingItemUid == nil and occupied then
				MovingItemUid = occupied.Uid
				MovingItemId = occupied.ItemId
				rebuildWorld()
				updateHoverCursor()
				refreshHud()
			elseif MovingItemUid ~= nil and (not occupied or occupied.Uid == MovingItemUid) then
				local uidToMove = MovingItemUid
				MovingItemUid = nil
				MovingItemId = nil
				task.spawn(function()
					ActionFn:InvokeServer("MoveItem", { Uid = uidToMove, NewGX = gx, NewGY = gy })
				end)
				rebuildWorld()
				updateHoverCursor()
				refreshHud()
			end
		elseif CurrentMode == "Remove" and occupied then
			local uidToRemove = occupied.Uid
			task.spawn(function()
				ActionFn:InvokeServer("RemoveItem", { Uid = uidToRemove })
			end)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
		isPanning = false
		-- If right-clicked without dragging, cancel active mode
		if input.UserInputType == Enum.UserInputType.MouseButton2 and not panMoved then
			if CurrentMode ~= "None" or MovingItemUid ~= nil then
				setMode("None")
			end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape then
		setMode("None")
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		-- Mouse-wheel zoom clamped between 0.5 and 1.8
		local delta = input.Position.Z * 0.1
		currentZoom = math.clamp(currentZoom + delta, MIN_ZOOM, MAX_ZOOM)
		WorldScale.Scale = currentZoom
		refreshHud()
		updateHoverCursor()

	elseif isPanning and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = UserInputService:GetMouseLocation() - panStart
		if delta.Magnitude > 3 then
			panMoved = true
		end
		WorldCanvas.Position = UDim2.new(
			canvasStart.X.Scale,
			canvasStart.X.Offset + delta.X,
			canvasStart.Y.Scale,
			canvasStart.Y.Offset + delta.Y
		)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		updateHoverCursor()
	end
end)

-- Top Stats & Status HUD
local TopHud = Instance.new("Frame")
TopHud.Name = "TopHud"
TopHud.AnchorPoint = Vector2.new(0.5, 0)
TopHud.Position = UDim2.new(0.5, 0, 0, 12)
TopHud.Size = UDim2.fromOffset(900, 58)
TopHud.BackgroundColor3 = Color3.fromRGB(85, 135, 207)
TopHud.ZIndex = 90000
TopHud.Parent = Backdrop
GlossyUI.style(TopHud)

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 10)
topCorner.Parent = TopHud

local topStroke = Instance.new("UIStroke")
topStroke.Thickness = 1.5
topStroke.Color = Color3.fromRGB(79, 70, 229)
topStroke.Parent = TopHud

-- Individually readable glossy stat capsules.
local StatLabels: { TextLabel } = {}
for i, title in { "CASH", "POPULARITY", "LUXURY", "MOCKTAILS", "DJ SET" } do
	local badge = Instance.new("TextLabel")
	badge.Name = title
	badge.Position = UDim2.fromOffset(10 + (i - 1) * 178, 7)
	badge.Size = UDim2.fromOffset(168, 44)
	badge.BackgroundColor3 = if i == 1 then Color3.fromRGB(74, 155, 73) else Color3.fromRGB(43, 76, 132)
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 13
	badge.Text = title
	badge.ZIndex = 90001
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge
	badge.Parent = TopHud
	GlossyUI.style(badge)
	table.insert(StatLabels, badge)
end

-- Sub banner for active mode instructions
local SubBanner = Instance.new("TextLabel")
SubBanner.AnchorPoint = Vector2.new(0.5, 0)
SubBanner.Position = UDim2.new(0.5, 0, 0, 76)
SubBanner.Size = UDim2.fromOffset(680, 26)
SubBanner.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
SubBanner.TextColor3 = Color3.fromRGB(226, 232, 240)
SubBanner.Font = Enum.Font.GothamMedium
SubBanner.TextSize = 12
SubBanner.ZIndex = 90000
SubBanner.Parent = Backdrop

local subCorner = Instance.new("UICorner")
subCorner.CornerRadius = UDim.new(0, 8)
subCorner.Parent = SubBanner

local subStroke = Instance.new("UIStroke")
subStroke.Thickness = 1
subStroke.Color = Color3.fromRGB(99, 102, 241)
subStroke.Parent = SubBanner

-- Bottom Dock Toolbar
local BottomDock = Instance.new("Frame")
BottomDock.Name = "BottomDock"
BottomDock.AnchorPoint = Vector2.new(0.5, 1)
BottomDock.Position = UDim2.new(0.5, 0, 1, -12)
BottomDock.Size = UDim2.fromOffset(980, 68)
BottomDock.BackgroundColor3 = Color3.fromRGB(85, 135, 207)
BottomDock.ZIndex = 90000
BottomDock.Parent = Backdrop
GlossyUI.style(BottomDock)

local dockCorner = Instance.new("UICorner")
dockCorner.CornerRadius = UDim.new(0, 12)
dockCorner.Parent = BottomDock

local dockStroke = Instance.new("UIStroke")
dockStroke.Thickness = 1.5
dockStroke.Color = Color3.fromRGB(67, 56, 202)
dockStroke.Parent = BottomDock

local DockLayout = Instance.new("UIListLayout")
DockLayout.FillDirection = Enum.FillDirection.Horizontal
DockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
DockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
DockLayout.Padding = UDim.new(0, 6)
DockLayout.Parent = BottomDock

-- Build Items Shelf (opens above BottomDock when Build is active)
local BuildShelf = Instance.new("Frame")
BuildShelf.Name = "BuildShelf"
BuildShelf.AnchorPoint = Vector2.new(0.5, 1)
BuildShelf.Position = UDim2.new(0.5, 0, 1, -86)
BuildShelf.Size = UDim2.fromOffset(920, 80)
BuildShelf.BackgroundColor3 = Color3.fromRGB(18, 14, 34)
BuildShelf.ZIndex = 90000
BuildShelf.Visible = false
BuildShelf.Parent = Backdrop

local shelfCorner = Instance.new("UICorner")
shelfCorner.CornerRadius = UDim.new(0, 12)
shelfCorner.Parent = BuildShelf

local shelfStroke = Instance.new("UIStroke")
shelfStroke.Thickness = 1.5
shelfStroke.Color = Color3.fromRGB(6, 182, 212)
shelfStroke.Parent = BuildShelf

local ShelfLayout = Instance.new("UIListLayout")
ShelfLayout.FillDirection = Enum.FillDirection.Horizontal
ShelfLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ShelfLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ShelfLayout.Padding = UDim.new(0, 8)
ShelfLayout.Parent = BuildShelf

local ShelfCards: { [string]: TextButton } = {}

local function makeShelfCard(itemId: string)
	local def = GameConfig.ITEMS[itemId]
	if not def then
		return
	end

	local card = Instance.new("TextButton")
	card.Size = UDim2.fromOffset(140, 64)
	card.BackgroundColor3 = Color3.fromRGB(30, 26, 52)
	card.Text = ""
	card.AutoButtonColor = false
	card.ZIndex = 90001
	card.Parent = BuildShelf
	GlossyUI.style(card)

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = card

	local cStroke = Instance.new("UIStroke")
	cStroke.Thickness = 1.5
	cStroke.Color = Color3.fromRGB(75, 85, 99)
	cStroke.Parent = card

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(88, def.HeightPx)
	swatch.Position = UDim2.fromOffset(6, 3)
	swatch.BackgroundTransparency = 1
	swatch.ZIndex = 90002
	swatch.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.42
	scale.Parent = swatch
	ClubArt.furniture(swatch, def)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -52, 0, 32)
	nameLabel.Position = UDim2.fromOffset(48, 4)
	nameLabel.TextWrapped = true
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.Name
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
	nameLabel.ZIndex = 90002
	nameLabel.Parent = card

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, -16, 0, 16)
	costLabel.Position = UDim2.fromOffset(8, 46)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = string.format("$%d  •  %s", def.Cost, def.Category)
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.Font = Enum.Font.GothamMedium
	costLabel.TextSize = 10
	costLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
	costLabel.ZIndex = 90002
	costLabel.Parent = card

	card.Activated:Connect(function()
		setMode("Build", itemId)
	end)

	ShelfCards[itemId] = card
end

for _, id in { "NeonDancePad", "BassTower", "FizzMocktailBar", "StarterDJBooth", "VelvetVIPBooth", "BouncerStation" } do
	makeShelfCard(id)
end

-- Dock Button Helper
local DockButtons: { [string]: TextButton } = {}

local function makeDockButton(id: string, label: string, color: Color3, width: number, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(width, 48)
	btn.BackgroundColor3 = color
	btn.Text = label
	btn.TextWrapped = true
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.ZIndex = 90001
	btn.Parent = BottomDock
	GlossyUI.style(btn)

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Thickness = 1.2
	btnStroke.Color = Color3.fromRGB(255, 255, 255)
	btnStroke.Transparency = 0.8
	btnStroke.Parent = btn

	btn.Activated:Connect(onClick)
	DockButtons[id] = btn
	return btn
end

makeDockButton("DJRefresh", "🎵 Refresh Set ($50)", Color3.fromRGB(147, 51, 234), 114, function()
	ActionFn:InvokeServer("TriggerDJSkill", { Skill = "RefreshSet" })
end)

makeDockButton("DJBass", "💥 DROP BASS!", Color3.fromRGB(236, 72, 153), 102, function()
	for _, g in Guests do
		g.TargetGX = 2
		g.TargetGY = 3
	end
	ActionFn:InvokeServer("TriggerDJSkill", { Skill = "DropTheBass" })
end)

makeDockButton("DJShout", "🎤 Shoutout", Color3.fromRGB(245, 158, 11), 92, function()
	ActionFn:InvokeServer("TriggerDJSkill", { Skill = "MicShoutout" })
end)

makeDockButton("Restock", "🍹 Restock Bar", Color3.fromRGB(16, 185, 129), 102, function()
	ActionFn:InvokeServer("RestockMocktails", {})
end)

makeDockButton("BuildShop", "🔨 Build Shop", Color3.fromRGB(51, 65, 85), 108, function()
	if CurrentMode == "Build" then
		setMode("None")
	else
		setMode("Build", SelectedBuildItem or "NeonDancePad")
	end
end)

makeDockButton("MoveItem", "✋ Move Item", Color3.fromRGB(51, 65, 85), 98, function()
	if CurrentMode == "Move" then
		setMode("None")
	else
		setMode("Move")
	end
end)

makeDockButton("SellItem", "💰 Sell (70%)", Color3.fromRGB(51, 65, 85), 98, function()
	if CurrentMode == "Remove" then
		setMode("None")
	else
		setMode("Remove")
	end
end)

-- Zoom Controls
makeDockButton("ZoomOut", "🔍 -", Color3.fromRGB(39, 39, 58), 44, function()
	currentZoom = math.clamp(currentZoom - 0.15, MIN_ZOOM, MAX_ZOOM)
	WorldScale.Scale = currentZoom
	refreshHud()
	updateHoverCursor()
end)

local ZoomLabel = Instance.new("TextLabel")
ZoomLabel.Size = UDim2.fromOffset(50, 48)
ZoomLabel.BackgroundColor3 = Color3.fromRGB(30, 27, 46)
ZoomLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
ZoomLabel.Font = Enum.Font.GothamBold
ZoomLabel.TextSize = 11
ZoomLabel.Text = "100%"
ZoomLabel.ZIndex = 90001
ZoomLabel.Parent = BottomDock

local zCorner = Instance.new("UICorner")
zCorner.CornerRadius = UDim.new(0, 8)
zCorner.Parent = ZoomLabel

makeDockButton("ZoomIn", "🔍 +", Color3.fromRGB(39, 39, 58), 44, function()
	currentZoom = math.clamp(currentZoom + 0.15, MIN_ZOOM, MAX_ZOOM)
	WorldScale.Scale = currentZoom
	refreshHud()
	updateHoverCursor()
end)

-- Visual styling update for active dock buttons & shelf cards
function updateDockStyles()
	BuildShelf.Visible = (CurrentMode == "Build")

	local shopBtn = DockButtons["BuildShop"]
	if shopBtn then
		shopBtn.BackgroundColor3 = if CurrentMode == "Build"
			then Color3.fromRGB(6, 182, 212)
			else Color3.fromRGB(51, 65, 85)
	end

	local moveBtn = DockButtons["MoveItem"]
	if moveBtn then
		moveBtn.BackgroundColor3 = if CurrentMode == "Move"
			then Color3.fromRGB(217, 119, 6)
			else Color3.fromRGB(51, 65, 85)
	end

	local sellBtn = DockButtons["SellItem"]
	if sellBtn then
		sellBtn.BackgroundColor3 = if CurrentMode == "Remove"
			then Color3.fromRGB(225, 29, 72)
			else Color3.fromRGB(51, 65, 85)
	end

	for itemId, card in ShelfCards do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			if CurrentMode == "Build" and SelectedBuildItem == itemId then
				stroke.Color = Color3.fromRGB(6, 182, 212)
				stroke.Thickness = 2.5
				card.BackgroundColor3 = Color3.fromRGB(45, 40, 75)
			else
				stroke.Color = Color3.fromRGB(75, 85, 99)
				stroke.Thickness = 1.5
				card.BackgroundColor3 = Color3.fromRGB(30, 26, 52)
			end
		end
	end
end

-- Refresh HUD and Instruction Sub-Banner
function refreshHud()
	local setRemaining = math.max(0, CurrentState.DJSetEndsAt - os.time())
	ZoomLabel.Text = string.format("%d%%", math.round(currentZoom * 100))

	StatLabels[1].Text = string.format("CASH\n$%d", CurrentState.Cash)
	StatLabels[2].Text = string.format("POPULARITY\n%d", CurrentState.Popularity)
	StatLabels[3].Text = string.format("LUXURY\n%d", CurrentState.Luxury)
	StatLabels[4].Text = string.format("MOCKTAILS\n%d / %d", CurrentState.MocktailStock, CurrentState.MaxMocktailStock)
	StatLabels[5].Text = string.format("DJ SET\n%02d:%02d", math.floor(setRemaining / 60), setRemaining % 60)

	if CurrentMode == "Build" and SelectedBuildItem then
		local def = GameConfig.ITEMS[SelectedBuildItem]
		local name = if def then def.Name else SelectedBuildItem
		SubBanner.Text = string.format("🔨 BUILD MODE: Click an empty tile to place [%s]  •  Right-Click / ESC to cancel", name)
		SubBanner.TextColor3 = Color3.fromRGB(165, 243, 252)
		subStroke.Color = Color3.fromRGB(6, 182, 212)
	elseif CurrentMode == "Move" then
		if MovingItemUid == nil then
			SubBanner.Text = "✋ MOVE MODE: Click any item in the club to pick it up  •  Right-Click / ESC to cancel"
		else
			SubBanner.Text = "✋ MOVE MODE: Click an empty tile to relocate item  •  Right-Click / ESC to cancel"
		end
		SubBanner.TextColor3 = Color3.fromRGB(254, 240, 138)
		subStroke.Color = Color3.fromRGB(217, 119, 6)
	elseif CurrentMode == "Remove" then
		SubBanner.Text = "💰 SELL MODE: Click any item to sell for 70% cash  •  Right-Click / ESC to cancel"
		SubBanner.TextColor3 = Color3.fromRGB(254, 202, 202)
		subStroke.Color = Color3.fromRGB(225, 29, 72)
	else
		SubBanner.Text = "🎮 Scroll Wheel / +/- to Zoom  •  Right-Click Drag to Pan Club  •  Click Shop / Move / Sell to edit"
		SubBanner.TextColor3 = Color3.fromRGB(203, 213, 225)
		subStroke.Color = Color3.fromRGB(99, 102, 241)
	end
end

-- 2D Cartoon Guests Setup & Animation Loop
for i = 1, 36 do
	local gx = math.random(2, CurrentState.GridWidth)
	local gy = math.random(2, CurrentState.GridHeight)
	local color = Color3.fromHSV((i * 0.13) % 1, 0.65, 0.95)
	local animator = SpriteAnimator.new(GuestLayer, GameConfig.GUEST_SPRITE, color, i % 5 == 0)
	Animators[i] = animator
	local guestGui = animator.Root

	table.insert(Guests, {
		Id = i,
		GX = gx,
		GY = gy,
		TargetGX = math.random(3, CurrentState.GridWidth - 1),
		TargetGY = math.random(3, CurrentState.GridHeight - 1),
		Speed = 1.6 + math.random() * 0.8,
		Happiness = 100,
		IsVIP = (i % 5 == 0),
		Mode = "Dancing",
		SpriteColor = color,
		GuiRoot = guestGui,
	})
end

local danceUntil: { [number]: number } = {}
local hudElapsed = 0
local renderConnection = RunService.RenderStepped:Connect(function(dt: number)
	hudElapsed += dt
	if hudElapsed >= 1 then
		hudElapsed %= 1
		refreshHud()
	end
	local t = os.clock()
	for _, g in Guests do
		local dx = g.TargetGX - g.GX
		local dy = g.TargetGY - g.GY
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist < 0.1 then
			local untilTime = danceUntil[g.Id]
			if not untilTime then
				danceUntil[g.Id] = t + 2 + (g.Id % 4)
			elseif t >= untilTime then
				danceUntil[g.Id] = nil
				g.TargetGX = math.random(2, CurrentState.GridWidth)
				g.TargetGY = math.random(2, CurrentState.GridHeight)
			end
		else
			danceUntil[g.Id] = nil
			local step = math.min(dist, g.Speed * dt)
			g.GX += (dx / dist) * step
			g.GY += (dy / dist) * step
		end

		local gui = g.GuiRoot
		if gui then
			local screenPos = Iso.gridToScreen(g.GX, g.GY)
			gui.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
			local animator = Animators[g.Id]
			animator.Play(if dist < 0.1 then "Dance" else "Walk")
			animator.Update(dt, Iso.getZIndex(g.GX, g.GY, 5))
		end
	end

	-- Ghost preview gentle breathing pulse
	if GhostPreview.Visible then
		GhostPreview.BackgroundTransparency = 0.35 + 0.15 * math.sin(t * 7)
	end

	-- Continuously sync hover cursor with mouse cursor every frame
	if CurrentMode ~= "None" then
		updateHoverCursor()
	end
end)

StateUpdatedEv.OnClientEvent:Connect(function(newState: Types.ClubState)
	local earned = newState.Cash - CurrentState.Cash
	if earned > 0 then
		-- State snapshots report net income, not a specific guest transaction.
		local gx, gy = math.ceil(newState.GridWidth / 2), math.ceil(newState.GridHeight / 2)
		GlossyUI.cashPopup(WorldCanvas, earned, Iso.gridToScreen(gx, gy), Iso.getZIndex(gx, gy, 9))
	end
	CurrentState = newState
	rebuildWorld()
	refreshHud()
	updateHoverCursor()
end)

Screen.Destroying:Connect(function()
	renderConnection:Disconnect()
	for _, animator in Animators do animator.Destroy() end
	table.clear(Animators)
end)

-- Fit the toolbars on narrow windows while leaving world zoom independent.
local function fitHud()
	local scale = math.min(1, math.max(0.1, (Backdrop.AbsoluteSize.X - 24) / 980))
	for _, panel in { TopHud, SubBanner, BottomDock, BuildShelf } do
		local uiScale = panel:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Parent = panel
		end
		uiScale.Scale = scale
	end
end
Backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHud)
fitHud()

-- Initial build
rebuildWorld()
updateDockStyles()
refreshHud()
