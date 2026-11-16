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
local SocialFn = Remotes:WaitForChild("ClubSocial") :: RemoteFunction

local CurrentState: Types.ClubState = GetStateFn:InvokeServer()
local Guests: { Types.GuestEntity } = {}
local SpriteAnimator = require(script.Parent:WaitForChild("SpriteAnimator"))
local GlossyUI = require(script.Parent:WaitForChild("GlossyUI"))
local ClubArt = require(script.Parent:WaitForChild("ClubArt"))
local HudIcons = require(script.Parent:WaitForChild("HudIcons"))
local GuestNavigation = require(script.Parent:WaitForChild("GuestNavigation"))
local GuestControllerModule = require(script.Parent:WaitForChild("GuestController"))
local MusicControllerModule = require(script.Parent:WaitForChild("MusicController"))
local SocialPanelModule = require(script.Parent:WaitForChild("SocialPanel"))
local Animators: { [number]: Types.SpriteAnimator } = {}
local CharacterCreator = require(script.Parent:WaitForChild("CharacterCreator"))
local Appearance = require(Shared:WaitForChild("Appearance"))
local CharacterEditor: Types.CharacterEditor? = nil
local MusicController = MusicControllerModule.new()
local SocialPanel: Types.SocialPanel? = nil
local CrowdController: Types.GuestController? = nil

-- Viewport Zoom constants
local MIN_ZOOM = 0.5
local MAX_ZOOM = 1.8
local currentZoom = 1.0

-- Edit mode states
local CurrentMode: Types.EditMode = "None"
local SelectedBuildItem: string? = nil
local MovingItemUid: string? = nil
local MovingItemId: string? = nil
local CurrentRotation: number = 0

-- UI Root ScreenGui
local Screen = Instance.new("ScreenGui")
Screen.Name = "NeonClub2DGui"
Screen.IgnoreGuiInset = true
Screen.ResetOnSpawn = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
Screen.Parent = PlayerGui

local Backdrop = Instance.new("Frame")
Backdrop.Size = UDim2.fromScale(1, 1)
Backdrop.BackgroundColor3 = Color3.fromRGB(27, 32, 40)
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
HoverTile.Size = UDim2.fromOffset(128, 64)
HoverTile.Rotation = 0
HoverTile.BorderSizePixel = 0
HoverTile.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
HoverTile.BackgroundTransparency = 1
HoverTile.Visible = false
HoverTile.ZIndex = 80000
HoverTile.Parent = CursorLayer
ClubArt.cursor(HoverTile)
local HoverEdges = HoverTile:GetChildren()

local HoverStroke = Instance.new("UIStroke")
HoverStroke.Thickness = 0
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
		local def = GameConfig.ITEMS[item.ItemId]
		local rot = item.Rot or 0
		local fx = if def then def.FootprintX else 1
		local fy = if def then def.FootprintY else 1
		if rot % 2 ~= 0 then fx, fy = fy, fx end
		if gx >= item.GX and gx < item.GX + fx and gy >= item.GY and gy < item.GY + fy then
			return item
		end
	end
	return nil
end

local function isAreaFree(gx: number, gy: number, fx: number, fy: number, ignoreUid: string?): boolean
	if gx < 1 or (gx + fx - 1) > CurrentState.GridWidth or gy < 1 or (gy + fy - 1) > CurrentState.GridHeight then
		return false
	end
	for ix = gx, gx + fx - 1 do
		for iy = gy, gy + fy - 1 do
			for uid, item in CurrentState.PlacedItems do
				if uid ~= ignoreUid then
					local def = GameConfig.ITEMS[item.ItemId]
					local rot = item.Rot or 0
					local efx = if def then def.FootprintX else 1
					local efy = if def then def.FootprintY else 1
					if rot % 2 ~= 0 then efx, efy = efy, efx end
					if ix >= item.GX and ix < item.GX + efx and iy >= item.GY and iy < item.GY + efy then
						return false
					end
				end
			end
		end
	end
	return true
end

-- Panning state
local isPanning = false
local panStart = Vector2.zero
local canvasStart = WorldCanvas.Position
local panMoved = false
local panButton: Enum.UserInputType? = nil
local panDirection = Vector2.zero

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
	if CurrentMode == "None" or (CharacterEditor and CharacterEditor.IsOpen()) then
		HoverTile.Visible, GhostPreview.Visible, TooltipBadge.Visible = false,false,false
		return
	end
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

		local fx = def.FootprintX
		local fy = def.FootprintY
		if CurrentRotation % 2 ~= 0 then fx, fy = fy, fx end
		local canAfford = CurrentState.Cash >= def.Cost
		local areaFree = isAreaFree(gx, gy, fx, fy, nil)
		local isValid = areaFree and canAfford

		local tintColor = if isValid
			then Color3.fromRGB(34, 197, 94)
			elseif not areaFree then Color3.fromRGB(239, 68, 68)
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
		GhostLabel.Text = string.format("%s (R:%d)", def.Name, CurrentRotation * 90)

		TooltipBadge.Visible = true
		TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - (def.HeightPx * WorldScale.Scale) - 10)
		TooltipStroke.Color = tintColor

		if not canAfford then
			TooltipBadge.Text = string.format("Need $%d (Have $%d)", def.Cost, CurrentState.Cash)
			TooltipBadge.TextColor3 = Color3.fromRGB(252, 165, 165)
		elseif not areaFree then
			TooltipBadge.Text = "Cannot Place (Blocked/Out of Bounds)"
			TooltipBadge.TextColor3 = Color3.fromRGB(252, 165, 165)
		else
			TooltipBadge.Text = string.format("Build: %s ($%d) [Press R to Rotate]", def.Name, def.Cost)
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
			local fx = if def then def.FootprintX else 1
			local fy = if def then def.FootprintY else 1
			if CurrentRotation % 2 ~= 0 then fx, fy = fy, fx end
			local areaFree = isAreaFree(gx, gy, fx, fy, MovingItemUid)
			local isValid = areaFree
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
				GhostLabel.Text = string.format("Moving: %s (R:%d)", def.Name, CurrentRotation * 90)

				TooltipBadge.Visible = true
				TooltipBadge.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - (def.HeightPx * WorldScale.Scale) - 10)
				TooltipStroke.Color = tintColor
				TooltipBadge.Text = if isValid then "Click to Relocate [R to Rotate]" else "Tile Blocked/Out of Bounds!"
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
local PulsePads: { Frame } = {}
local lastLayout = ""
local lastRoomSize = ""
function rebuildWorld()
	local entries = { tostring(CurrentState.GridWidth), tostring(CurrentState.GridHeight), MovingItemUid or "" }
	for uid, item in CurrentState.PlacedItems do table.insert(entries, uid .. item.ItemId .. ":" .. item.GX .. ":" .. item.GY) end
	table.sort(entries)
	local signature = table.concat(entries, "|")
	if signature == lastLayout then updateHoverCursor(); return end
	lastLayout = signature
	table.clear(PulsePads)
	local roomSize = CurrentState.GridWidth .. ":" .. CurrentState.GridHeight
	if roomSize ~= lastRoomSize then
		lastRoomSize = roomSize
		TileLayer:ClearAllChildren()
		ClubArt.room(TileLayer, CurrentState.GridWidth, CurrentState.GridHeight)
	end
	ObjectLayer:ClearAllChildren()

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

		if def.AssetId == "" then
			for _, band in ClubArt.furniture(itemBtn, def) do table.insert(PulsePads, band) end
		end
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
	if CharacterEditor and CharacterEditor.IsOpen() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local gx, gy, inBounds = getMouseGrid()
		if not inBounds then
			return
		end
		local occupied = getPlacedItemAt(gx, gy)

		if CurrentMode == "Build" and SelectedBuildItem then
			local def = GameConfig.ITEMS[SelectedBuildItem]
			local fx = if def then def.FootprintX else 1
			local fy = if def then def.FootprintY else 1
			if CurrentRotation % 2 ~= 0 then fx, fy = fy, fx end
			if isAreaFree(gx, gy, fx, fy, nil) then
				local buildItem = SelectedBuildItem
				local rot = CurrentRotation
				task.spawn(function()
					ActionFn:InvokeServer("PlaceItem", { ItemId = buildItem, GX = gx, GY = gy, Rot = rot })
				end)
			end
		elseif CurrentMode == "Move" then
			if MovingItemUid == nil and occupied then
				MovingItemUid = occupied.Uid
				MovingItemId = occupied.ItemId
				CurrentRotation = occupied.Rot or 0
				rebuildWorld()
				updateHoverCursor()
				refreshHud()
			elseif MovingItemUid ~= nil then
				local def = if MovingItemId then GameConfig.ITEMS[MovingItemId] else nil
				local fx = if def then def.FootprintX else 1
				local fy = if def then def.FootprintY else 1
				if CurrentRotation % 2 ~= 0 then fx, fy = fy, fx end
				if isAreaFree(gx, gy, fx, fy, MovingItemUid) then
					local uidToMove = MovingItemUid
					local rotToMove = CurrentRotation
					MovingItemUid = nil
					MovingItemId = nil
					task.spawn(function()
						ActionFn:InvokeServer("MoveItem", { Uid = uidToMove, NewGX = gx, NewGY = gy, NewRot = rotToMove })
					end)
					rebuildWorld()
					updateHoverCursor()
					refreshHud()
				end
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
	if input.UserInputType == Enum.UserInputType.MouseButton1 then panDirection = Vector2.zero end
	if input.UserInputType == panButton then
		isPanning = false
		panButton = nil
		-- If right-clicked without dragging, cancel active mode
		if input.UserInputType == Enum.UserInputType.MouseButton2 and not panMoved then
			if CurrentMode ~= "None" or MovingItemUid ~= nil then
				setMode("None")
			end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	local kind = input.UserInputType
	local mouse = UserInputService:GetMouseLocation()
	local overHud = false
	for _, ui in PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
		if ui:IsDescendantOf(Screen) and ui.ZIndex >= 90000 then overHud = true; break end
	end
	if not overHud and not UserInputService:GetFocusedTextBox() and
		(kind == Enum.UserInputType.MouseButton2 or kind == Enum.UserInputType.MouseButton3
		or (kind == Enum.UserInputType.MouseButton1 and CurrentMode == "None")) then
		isPanning, panMoved, panButton = true, false, kind
		panStart, canvasStart = mouse, WorldCanvas.Position
	end
	if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape then
		setMode("None")
	elseif not gameProcessed and input.KeyCode and input.KeyCode == (Enum.KeyCode :: any).R then
		if CurrentMode == "Build" or CurrentMode == "Move" then
			CurrentRotation = ((CurrentRotation or 0) + 1) % 4
			updateHoverCursor()
		end
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	isPanning = false
	panButton = nil
	panDirection = Vector2.zero
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if CharacterEditor and CharacterEditor.IsOpen() then return end
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
	elseif CurrentMode ~= "None" and input.UserInputType == Enum.UserInputType.MouseMovement then
		updateHoverCursor()
	end
end)

-- Top Stats & Status HUD
local TopHud = Instance.new("Frame")
TopHud.Name = "TopHud"
TopHud.AnchorPoint = Vector2.new(0.5, 0)
TopHud.Position = UDim2.new(0.5, 40, 0, 52)
TopHud.Size = UDim2.fromOffset(760, 52)
TopHud.BackgroundColor3 = Color3.fromRGB(26, 39, 55)
TopHud.ZIndex = 90000
TopHud.Parent = Backdrop
GlossyUI.style(TopHud)

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 10)
topCorner.Parent = TopHud

local topStroke = Instance.new("UIStroke")
topStroke.Thickness = 1.5
topStroke.Color = Color3.fromRGB(98, 179, 214)
topStroke.Parent = TopHud

local ClubLogo = Instance.new("TextButton")
ClubLogo.Size = UDim2.fromOffset(118, 50)
ClubLogo.Position = UDim2.fromOffset(4, 2)
ClubLogo.BackgroundTransparency = 1
ClubLogo.Text = "MY LOOK\nCUSTOMIZE"
ClubLogo.Font = Enum.Font.GothamBlack
ClubLogo.TextSize = 15
ClubLogo.TextColor3 = Color3.fromRGB(134, 243, 255)
ClubLogo.TextStrokeColor3 = Color3.fromRGB(7, 20, 36)
ClubLogo.TextStrokeTransparency = 0
ClubLogo.ZIndex = 90001
ClubLogo.Parent = TopHud

-- Individually readable glossy stat capsules.
local StatLabels: { TextLabel } = {}
for i, title in { "CASH", "POPULARITY", "LUXURY", "MOCKTAILS", "DJ SET" } do
	local badge = Instance.new("TextLabel")
	badge.Name = title
	badge.Position = UDim2.fromOffset(128 + (i - 1) * 122, 5)
	badge.Size = UDim2.fromOffset(116, 40)
	badge.BackgroundColor3 = if i == 1 then Color3.fromRGB(47, 122, 78) else Color3.fromRGB(35, 119, 162)
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 12
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
SubBanner.Position = UDim2.new(0.5, 0, 1, -156)
SubBanner.Size = UDim2.fromOffset(680, 24)
SubBanner.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
SubBanner.TextColor3 = Color3.fromRGB(226, 232, 240)
SubBanner.Font = Enum.Font.GothamMedium
SubBanner.TextSize = 11
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
BottomDock.Position = UDim2.new(0.5, 0, 1, -66)
BottomDock.Size = UDim2.fromOffset(680, 62)
BottomDock.BackgroundColor3 = Color3.fromRGB(26, 43, 62)
BottomDock.ZIndex = 90000
BottomDock.Parent = Backdrop
GlossyUI.style(BottomDock)

local dockCorner = Instance.new("UICorner")
dockCorner.CornerRadius = UDim.new(0, 10)
dockCorner.Parent = BottomDock

local dockStroke = Instance.new("UIStroke")
dockStroke.Thickness = 1.5
dockStroke.Color = Color3.fromRGB(98, 179, 214)
dockStroke.Parent = BottomDock

local DockLayout = Instance.new("UIListLayout")
DockLayout.FillDirection = Enum.FillDirection.Horizontal
DockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
DockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
DockLayout.Padding = UDim.new(0, 5)
DockLayout.Parent = BottomDock

-- Build Items Shelf (opens above BottomDock when Build is active)
local BuildShelf = Instance.new("Frame")
BuildShelf.Name = "BuildShelf"
BuildShelf.AnchorPoint = Vector2.new(0.5, 1)
BuildShelf.Position = UDim2.new(0.5, 0, 1, -134)
BuildShelf.Size = UDim2.fromOffset(880, 72)
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
	btn.Size = UDim2.fromOffset(if width > 50 then 68 else 30, 52)
	btn.BackgroundColor3 = color
	btn.Text = if id == "ZoomIn" then "+" elseif id == "ZoomOut" then "-" else ""
	btn.TextWrapped = true
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.ZIndex = 90001
	btn.Parent = BottomDock
	GlossyUI.style(btn)
	HudIcons.draw(btn, id)
	local names = {DJRefresh="DJ Set", DJBass="Bass Drop", DJShout="Shoutout", Restock="Mocktails", BuildShop="Build", MoveItem="Move", SellItem="Sell"}
	if names[id] then
		local caption = Instance.new("TextLabel")
		caption.Size, caption.Position = UDim2.new(1,0,0,16), UDim2.fromOffset(0,34)
		caption.BackgroundTransparency = 1
		caption.Text, caption.Font, caption.TextSize = names[id], Enum.Font.GothamBold, 10
		caption.TextColor3, caption.ZIndex = Color3.new(1,1,1), 90002
		caption.Parent = btn
	end
	btn.MouseEnter:Connect(function() SubBanner.Text = label; SubBanner.Visible = true end)
	btn.MouseLeave:Connect(function() refreshHud() end)

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
	if CrowdController then
		CrowdController.Rally()
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
ZoomLabel.Size = UDim2.fromOffset(42, 52)
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
	SubBanner.Visible = CurrentMode ~= "None"
	local now = os.time()
	local refreshCd = math.max(0, (CurrentState.SkillCooldowns.RefreshSet or 0) - now)
	local bassCd = math.max(0, (CurrentState.SkillCooldowns.DropTheBass or 0) - now)
	local shoutCd = math.max(0, (CurrentState.SkillCooldowns.MicShoutout or 0) - now)

	local bRefresh = DockButtons["DJRefresh"]
	if bRefresh then
		local cap = bRefresh:FindFirstChildWhichIsA("TextLabel")
		if cap then cap.Text = if refreshCd > 0 then string.format("%ds", refreshCd) else "DJ Set" end
	end
	local bBass = DockButtons["DJBass"]
	if bBass then
		local cap = bBass:FindFirstChildWhichIsA("TextLabel")
		if cap then cap.Text = if bassCd > 0 then string.format("%ds", bassCd) else "Bass Drop" end
	end
	local bShout = DockButtons["DJShout"]
	if bShout then
		local cap = bShout:FindFirstChildWhichIsA("TextLabel")
		if cap then cap.Text = if shoutCd > 0 then string.format("%ds", shoutCd) else "Shoutout" end
	end

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
		SubBanner.Text = "🎮 Drag to Pan | Arrows / FIT | Wheel to Zoom  •  Right-Click Drag to Pan Club  •  Click Shop / Move / Sell to edit"
		SubBanner.TextColor3 = Color3.fromRGB(203, 213, 225)
		subStroke.Color = Color3.fromRGB(99, 102, 241)
	end
end

-- Authentic Nightclub City Crowd Simulation (No Object Clipping)
local nav = GuestNavigation.new(CurrentState)
CrowdController = GuestControllerModule.new(GuestLayer, CurrentState)

-- Initialize Music and Social Controllers
MusicController.Update(CurrentState)
SocialPanel = SocialPanelModule.new(
	Screen,
	CurrentState,
	ActionFn,
	SocialFn,
	function(visitedState, friendId)
		CurrentState = visitedState
		rebuildWorld()
		refreshHud()
		if CrowdController then CrowdController.SetState(visitedState) end
		if MusicController then MusicController.Update(visitedState) end
	end,
	function(homeState)
		CurrentState = homeState
		rebuildWorld()
		refreshHud()
		if CrowdController then CrowdController.SetState(homeState) end
		if MusicController then MusicController.Update(homeState) end
	end
)

local hudElapsed = 0
local lightElapsed = 0
local renderConnection = RunService.RenderStepped:Connect(function(dt: number)
	if panDirection.Magnitude > 0 then
		local move = panDirection * (480 * math.min(dt,0.1))
		local position = WorldCanvas.Position
		WorldCanvas.Position = UDim2.new(position.X.Scale,position.X.Offset+move.X,position.Y.Scale,position.Y.Offset+move.Y)
		updateHoverCursor()
	end
	lightElapsed += dt
	if lightElapsed >= 0.1 then
		lightElapsed = 0
		local tint = Color3.fromRGB(32,123,234):Lerp(Color3.fromRGB(68,221,255),0.5+0.5*math.sin(os.clock()*2))
		for _, band in PulsePads do band.BackgroundColor3 = tint end
	end
	for _, edge in HoverEdges do
		if edge:IsA("Frame") then
			edge.BackgroundColor3 = HoverTile.BackgroundColor3
			edge.ZIndex = HoverTile.ZIndex
		end
	end
	hudElapsed += dt
	if hudElapsed >= 1 then
		hudElapsed %= 1
		refreshHud()
		if MusicController then MusicController.Update(CurrentState) end
		if SocialPanel then SocialPanel.Update(CurrentState) end
	end

	-- Centralized Single-Scheduler Crowd Tick
	if CrowdController then
		CrowdController.Update(dt)
	end

	local t = os.clock()
	-- Ghost preview gentle breathing pulse
	if GhostPreview.Visible then
		GhostPreview.BackgroundTransparency = 0.35 + 0.15 * math.sin(t * 7)
	end

	-- Hover updates on mouse motion, layout changes, zoom, and arrow panning.
end)

StateUpdatedEv.OnClientEvent:Connect(function(newState: Types.ClubState)
	local oldLook = CurrentState.Appearance or Appearance.default()
	local newLook = newState.Appearance or Appearance.default()
	local changed = false
	for name in Appearance.Limits do if (oldLook :: any)[name] ~= (newLook :: any)[name] then changed=true;break end end

	local earned = newState.Cash - CurrentState.Cash
	if earned > 0 then
		-- State snapshots report net income, not a specific guest transaction.
		local gx, gy = math.ceil(newState.GridWidth / 2), math.ceil(newState.GridHeight / 2)
		GlossyUI.cashPopup(WorldCanvas, earned, Iso.gridToScreen(gx, gy), Iso.getZIndex(gx, gy, 9))
	end
	CurrentState = newState
	nav = GuestNavigation.new(newState)
	if CrowdController then
		CrowdController.SetState(newState)
	end
	if MusicController then
		MusicController.Update(newState)
	end
	if SocialPanel then
		SocialPanel.Update(newState)
	end
	rebuildWorld()
	refreshHud()
	updateHoverCursor()
end)

Screen.Destroying:Connect(function()
	renderConnection:Disconnect()
	if CharacterEditor then CharacterEditor.Destroy() end
	if CrowdController then CrowdController.Destroy() end
	if MusicController then MusicController.Destroy() end
	if SocialPanel then SocialPanel.Destroy() end
	for _, animator in Animators do animator.Destroy() end
	table.clear(Animators)
end)

-- Fit the toolbars on narrow windows while leaving world zoom independent.
local function fitHud()
	local size = Backdrop.AbsoluteSize
	local scale = math.min(1, math.max(0.1, (size.X - 24) / 760))
	for _, panel in { TopHud, SubBanner, BottomDock, BuildShelf } do
		local uiScale = panel:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Parent = panel
		end
		uiScale.Scale = scale
	end

	local isWide = size.X >= 1200
	local insetY = GuiService:GetGuiInset().Y
	local unibarClearanceY = math.max(insetY, 52)
	local topY = if isWide then 8 else unibarClearanceY
	local topOffsetX = if isWide then 90 else 40
	TopHud.Position = UDim2.new(0.5, topOffsetX, 0, topY)
end

local function frameClub()
	fitHud()
	local size = Backdrop.AbsoluteSize
	if size.X < 1 or size.Y < 1 then return end
	local roomWidth = (CurrentState.GridWidth + CurrentState.GridHeight) * 64
	local roomHeight = (CurrentState.GridWidth + CurrentState.GridHeight) * 32
	local topSafeY = 108
	local bottomSafeY = math.max(topSafeY + 100, size.Y - 136)
	local safeHeight = bottomSafeY - topSafeY
	local safeCenterY = math.floor((topSafeY + bottomSafeY) * 0.5)

	currentZoom = math.clamp(math.min((size.X - 90) / (roomWidth + 128), (safeHeight - 30) / (roomHeight + 100)), MIN_ZOOM, 1)
	WorldScale.Scale = currentZoom

	local midGX = (CurrentState.GridWidth + 1) * 0.5
	local midGY = (CurrentState.GridHeight + 1) * 0.5
	local gridMidPx = Iso.gridToScreen(midGX, midGY)
	local targetCanvasX = (size.X * 0.5) - (gridMidPx.X * currentZoom)
	local targetCanvasY = (safeCenterY + 24) - (gridMidPx.Y * currentZoom)

	WorldCanvas.Position = UDim2.fromOffset(math.round(targetCanvasX), math.round(targetCanvasY))
	refreshHud()
end
Backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameClub)
frameClub()

-- Visible mouse navigation; hold an arrow to move the view in that direction.
local NavigationPad = Instance.new("Frame")
NavigationPad.Name = "CameraNavigation"
NavigationPad.Size = UDim2.fromOffset(110,110)
NavigationPad.AnchorPoint = Vector2.new(1,1)
NavigationPad.Position = UDim2.new(1,-16,1,-136)
NavigationPad.BackgroundTransparency = 1
NavigationPad.ZIndex = 90010
NavigationPad.Parent = Backdrop
for _, entry in {
	{Text="^", X=38, Y=0, Direction=Vector2.new(0,1)},
	{Text="v", X=38, Y=76, Direction=Vector2.new(0,-1)},
	{Text="<", X=0, Y=38, Direction=Vector2.new(1,0)},
	{Text=">", X=76, Y=38, Direction=Vector2.new(-1,0)},
} do
	local arrow = Instance.new("TextButton")
	arrow.Size, arrow.Position = UDim2.fromOffset(34,34), UDim2.fromOffset(entry.X,entry.Y)
	arrow.BackgroundColor3 = Color3.fromRGB(36,88,112)
	arrow.TextColor3 = Color3.fromRGB(206,251,255)
	arrow.Text, arrow.TextSize, arrow.Font = entry.Text, 24, Enum.Font.GothamBold
	arrow.ZIndex = 90011
	local corner = Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=arrow
	arrow.Parent = NavigationPad
	arrow.MouseButton1Down:Connect(function() panDirection = entry.Direction end)
end
local center = Instance.new("TextButton")
center.Size, center.Position = UDim2.fromOffset(34,34), UDim2.fromOffset(38,38)
center.Text, center.TextSize, center.Font = "FIT", 10, Enum.Font.GothamBold
center.BackgroundColor3, center.TextColor3 = Color3.fromRGB(21,40,56), Color3.new(1,1,1)
center.ZIndex = 90011
center.Parent = NavigationPad
center.Activated:Connect(frameClub)

CharacterEditor = CharacterCreator.new(Backdrop,CurrentState.Appearance,function(selection: Types.Appearance): (boolean,string)
	return ActionFn:InvokeServer("SetAppearance",{Appearance=selection})
end)
ClubLogo.Activated:Connect(function()
	isPanning,panButton,panDirection = false,nil,Vector2.zero
	setMode("None")
	if CharacterEditor then CharacterEditor.Open(CurrentState.Appearance) end
end)

-- Initial build
rebuildWorld()
updateDockStyles()
refreshHud()
