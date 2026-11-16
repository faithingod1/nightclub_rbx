--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = require(Shared:WaitForChild("GameConfig"))

local SpriteAnimator = {}
local guestSequence = 0

type VectorPart = {
	Frame: Frame,
	BaseX: number,
	BaseY: number,
	Width: number,
	Height: number,
	BaseRot: number,
	MirrorRot: boolean,
}

function SpriteAnimator.new(
	parent: Instance,
	sheet: Types.SpriteSheet,
	color: Color3,
	isVIP: boolean,
	appearance: Types.Appearance?
): Types.SpriteAnimator
	for name, clip in sheet.Clips do
		assert(clip.FirstFrame >= 0 and clip.FirstFrame % 1 == 0, name .. ": invalid first frame")
		assert(
			clip.FrameCount >= 1 and clip.FrameCount % 1 == 0 and clip.FirstFrame + clip.FrameCount <= 16,
			name .. ": exceeds 4x4 atlas"
		)
		assert(clip.FPS > 0 and clip.FPS < math.huge, name .. ": invalid FPS")
	end
	assert(sheet.Clips.Idle, "Sprite sheet requires an Idle clip")

	guestSequence += 1
	local style = if appearance then appearance.Hair else (guestSequence % 6) + 1
	local skinIndex = if appearance then appearance.Skin else ((guestSequence * 2) % 6) + 1
	local hairColorIndex = if appearance then appearance.HairColor else (guestSequence % 6) + 1
	local eyesIndex = if appearance then appearance.Eyes else ((guestSequence + 1) % 6) + 1
	local topIndex = if appearance then appearance.Top else ((guestSequence + 2) % 6) + 1
	local bottomIndex = if appearance then appearance.Bottom else ((guestSequence + 3) % 5) + 1
	local shoesIndex = if appearance then appearance.Shoes else (guestSequence % 4) + 1
	local faceIndex = if appearance then appearance.Face else (guestSequence % 6) + 1

	local skin = Config.CHARACTER.Skin[skinIndex] or Color3.fromRGB(248, 206, 172)
	local hairColor = Config.CHARACTER.HairColor[hairColorIndex] or Color3.fromRGB(92, 56, 34)
	local eyes = Config.CHARACTER.Eyes[eyesIndex] or Color3.fromRGB(38, 130, 95)
	local topColor = if appearance then (Config.CHARACTER.Top[topIndex] or color) else color
	local bottomColor = Config.CHARACTER.Bottom[bottomIndex] or Color3.fromRGB(80, 135, 195)
	local shoesColor = Config.CHARACTER.Shoes[shoesIndex] or Color3.fromRGB(235, 238, 242)

	local root = Instance.new("Frame")
	root.Name = "CartoonGuest"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Size = UDim2.fromOffset(56, 76)
	root.BackgroundTransparency = 1

	-- Atlas SpriteSheet mode (when AssetId is set and no appearance override is requested)
	local image = Instance.new("ImageLabel")
	image.Name = "SpriteSheet"
	image.AnchorPoint = Vector2.new(0.5, 1)
	image.Position = UDim2.fromScale(0.5, 1)
	image.Size = UDim2.fromOffset(76, 76)
	image.BackgroundTransparency = 1
	image.Image = sheet.AssetId
	image.ImageRectSize = Vector2.new(256, 256)
	image.Visible = sheet.AssetId ~= "" and appearance == nil
	image.Parent = root

	-- Procedural Vector Fallback mode (Glossy 2010 Flash Social Game Aesthetic)
	local fallback = Instance.new("Frame")
	fallback.Name = "VectorFallback"
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.BackgroundTransparency = 1
	fallback.Visible = not image.Visible
	fallback.Parent = root

	local parts: { GuiObject } = { image, fallback }
	local registeredVectorParts: { VectorPart } = {}

	local function addPart(
		name: string,
		x: number,
		y: number,
		w: number,
		h: number,
		tint: Color3,
		radius: number,
		baseRot: number?,
		parentOverride: Instance?
	): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Position = UDim2.fromOffset(x, y)
		frame.Size = UDim2.fromOffset(w, h)
		frame.BackgroundColor3 = tint
		frame.BorderSizePixel = 0
		if baseRot and baseRot ~= 0 then
			frame.Rotation = baseRot
		end
		if radius > 0 then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, radius)
			corner.Parent = frame
		end
		frame.Parent = parentOverride or fallback
		table.insert(parts, frame)
		table.insert(registeredVectorParts, {
			Frame = frame,
			BaseX = x,
			BaseY = y,
			Width = w,
			Height = h,
			BaseRot = baseRot or 0,
			MirrorRot = true,
		})
		return frame
	end

	-- Ground Shadow
	local shadow = addPart("GroundShadow", 10, 69, 36, 7, Color3.fromRGB(15, 18, 30), 8)
	shadow.BackgroundTransparency = 0.55

	-- Main Body Container (bobs vertically during breathing, walking, and dancing)
	local bodyContainer = Instance.new("Frame")
	bodyContainer.Name = "BodyContainer"
	bodyContainer.Size = UDim2.fromScale(1, 1)
	bodyContainer.BackgroundTransparency = 1
	bodyContainer.Parent = fallback
	table.insert(parts, bodyContainer)

	-- 1. Back Hair / Ponytail Layer (drawn behind the head and body)
	local ponytailKnot: Frame? = nil
	local ponytailTail: Frame? = nil
	if style == 2 then
		-- Ponytail Style (High ponytail with side bounce)
		ponytailKnot = addPart("PonytailKnot", 37, 10, 8, 8, topColor, 4, 0, bodyContainer)
		ponytailTail = addPart("PonytailTail", 39, 12, 14, 25, hairColor, 7, 20, bodyContainer)
		local tailHighlight = addPart("PonytailShine", 41, 14, 4, 16, hairColor:Lerp(Color3.new(1, 1, 1), 0.3), 2, 18, bodyContainer)
		tailHighlight.BackgroundTransparency = 0.3
	elseif style == 3 then
		-- Sleek Bob Back
		addPart("BobBackCurtain", 8, 10, 40, 32, hairColor, 12, 0, bodyContainer)
	elseif style == 5 then
		-- Layered Wings Back
		addPart("WingsBackLeft", 6, 8, 16, 36, hairColor, 7, -12, bodyContainer)
		addPart("WingsBackRight", 34, 8, 16, 36, hairColor, 7, 12, bodyContainer)
	end

	-- 2. Legs & Lower Body
	local isSkirt = bottomIndex == 4
	local leftLeg: Frame
	local rightLeg: Frame
	if isSkirt then
		-- Pencil Skirt with bare legs underneath
		leftLeg = addPart("LeftLegBare", 19, 53, 7, 15, skin, 3, 0, bodyContainer)
		rightLeg = addPart("RightLegBare", 30, 53, 7, 15, skin, 3, 0, bodyContainer)
		addPart("SkirtBase", 16, 46, 24, 15, bottomColor, 5, 0, bodyContainer)
		local skirtHem = addPart("SkirtHem", 16, 59, 24, 2, bottomColor:Lerp(Color3.new(0, 0, 0), 0.3), 1, 0, bodyContainer)
		skirtHem.BackgroundTransparency = 0.2
	else
		-- Trousers / Jeans
		leftLeg = addPart("LeftLeg", 18, 51, 8, 18, bottomColor, 3, 0, bodyContainer)
		rightLeg = addPart("RightLeg", 30, 51, 8, 18, bottomColor, 3, 0, bodyContainer)
		-- Trouser crease line
		local crease = addPart("PantsCrease", 27, 51, 2, 16, bottomColor:Lerp(Color3.new(0, 0, 0), 0.35), 1, 0, bodyContainer)
		crease.BackgroundTransparency = 0.3
	end

	-- 3. Detailed Footwear
	local leftShoe = addPart("LeftShoe", 15, 66, 12, 7, shoesColor, 3, 0, bodyContainer)
	local rightShoe = addPart("RightShoe", 29, 66, 12, 7, shoesColor, 3, 0, bodyContainer)
	if shoesIndex == 1 then
		-- High-Top Canvas Sneakers with white rubber toe cap, foxing sole, and laces
		addPart("LeftToeCap", 15, 68, 4, 5, Color3.fromRGB(248, 250, 252), 2, 0, bodyContainer)
		addPart("RightToeCap", 37, 68, 4, 5, Color3.fromRGB(248, 250, 252), 2, 0, bodyContainer)
		addPart("LeftSole", 15, 71, 12, 2, Color3.fromRGB(240, 243, 246), 1, 0, bodyContainer)
		addPart("RightSole", 29, 71, 12, 2, Color3.fromRGB(240, 243, 246), 1, 0, bodyContainer)
		addPart("LeftLace", 19, 67, 4, 2, Color3.fromRGB(255, 255, 255), 1, 0, bodyContainer)
		addPart("RightLace", 33, 67, 4, 2, Color3.fromRGB(255, 255, 255), 1, 0, bodyContainer)
	elseif shoesIndex == 2 then
		-- Low-Top Sneakers with clean sole
		addPart("LeftSole", 15, 71, 12, 2, Color3.fromRGB(230, 230, 235), 1, 0, bodyContainer)
		addPart("RightSole", 29, 71, 12, 2, Color3.fromRGB(230, 230, 235), 1, 0, bodyContainer)
	elseif shoesIndex == 3 then
		-- Glossy Dress Shoes with shine highlight
		local leftShine = addPart("LeftShine", 17, 67, 5, 2, Color3.fromRGB(130, 135, 150), 1, 0, bodyContainer)
		leftShine.BackgroundTransparency = 0.4
		local rightShine = addPart("RightShine", 31, 67, 5, 2, Color3.fromRGB(130, 135, 150), 1, 0, bodyContainer)
		rightShine.BackgroundTransparency = 0.4
	elseif shoesIndex == 4 then
		-- Leather Ankle Boots with rugged sole
		addPart("LeftBootSole", 15, 71, 12, 2, Color3.fromRGB(45, 28, 18), 1, 0, bodyContainer)
		addPart("RightBootSole", 29, 71, 12, 2, Color3.fromRGB(45, 28, 18), 1, 0, bodyContainer)
	end

	-- 4. Torso & Layered Outfits
	-- Dark Torso Outline for vector pop
	addPart("TorsoOutline", 14, 32, 28, 23, Color3.fromRGB(20, 22, 28), 6, 0, bodyContainer)
	-- Main Garment Body
	addPart("TorsoMain", 16, 33, 24, 21, topColor, 5, 0, bodyContainer)

	-- Waist Belt with Gold Buckle
	addPart("Belt", 16, 50, 24, 4, Color3.fromRGB(28, 26, 32), 1, 0, bodyContainer)
	addPart("BeltBuckle", 26, 50, 4, 4, Color3.fromRGB(230, 195, 75), 1, 0, bodyContainer)

	-- Detailed Top Variants
	if topIndex == 1 then
		-- Black Tank Top: Scoop neckline showing skin collar
		addPart("TankNeckline", 21, 33, 14, 5, skin, 3, 0, bodyContainer)
		local tankStrapL = addPart("TankStrapL", 17, 33, 4, 8, topColor, 2, 0, bodyContainer)
		local tankStrapR = addPart("TankStrapR", 35, 33, 4, 8, topColor, 2, 0, bodyContainer)
		tankStrapL.BorderSizePixel = 0
		tankStrapR.BorderSizePixel = 0
	elseif topIndex == 2 then
		-- Purple Button-Down Shirt: Collar points, button placket, buttons
		addPart("ShirtCollarL", 21, 33, 6, 5, topColor:Lerp(Color3.new(1, 1, 1), 0.18), 2, -18, bodyContainer)
		addPart("ShirtCollarR", 29, 33, 6, 5, topColor:Lerp(Color3.new(1, 1, 1), 0.18), 2, 18, bodyContainer)
		addPart("Placket", 27, 35, 2, 15, topColor:Lerp(Color3.new(0, 0, 0), 0.25), 1, 0, bodyContainer)
		for y = 38, 48, 5 do
			addPart("ShirtBtn" .. y, 27, y, 2, 2, Color3.fromRGB(240, 240, 245), 1, 0, bodyContainer)
		end
	elseif topIndex == 3 then
		-- White Shirt + Black Vest & Orange/Gold Satin Necktie
		addPart("InnerShirtWhite", 21, 33, 14, 17, Color3.fromRGB(245, 245, 250), 2, 0, bodyContainer)
		addPart("VestLeft", 16, 34, 6, 16, Color3.fromRGB(24, 25, 32), 2, 0, bodyContainer)
		addPart("VestRight", 34, 34, 6, 16, Color3.fromRGB(24, 25, 32), 2, 0, bodyContainer)
		addPart("Necktie", 26, 35, 4, 14, Color3.fromRGB(245, 140, 35), 2, 0, bodyContainer)
	elseif topIndex == 4 then
		-- Light Blue Casual Shirt with Chest Pocket and Button Placket
		addPart("CasualCollarL", 21, 33, 6, 5, topColor:Lerp(Color3.new(1, 1, 1), 0.15), 2, -16, bodyContainer)
		addPart("CasualCollarR", 29, 33, 6, 5, topColor:Lerp(Color3.new(1, 1, 1), 0.15), 2, 16, bodyContainer)
		addPart("Pocket", 32, 39, 5, 5, topColor:Lerp(Color3.new(0, 0, 0), 0.15), 1, 0, bodyContainer)
	elseif topIndex == 5 then
		-- Leather Bomber Jacket over Graphic Tee
		addPart("GraphicTee", 22, 35, 12, 15, Color3.fromRGB(225, 50, 75), 2, 0, bodyContainer)
		addPart("TeeDecal", 25, 38, 6, 6, Color3.fromRGB(255, 220, 80), 3, 0, bodyContainer)
		addPart("JacketLapelL", 16, 33, 7, 18, Color3.fromRGB(30, 32, 40), 2, -10, bodyContainer)
		addPart("JacketLapelR", 33, 33, 7, 18, Color3.fromRGB(30, 32, 40), 2, 10, bodyContainer)
		addPart("Zipper", 28, 42, 2, 9, Color3.fromRGB(180, 185, 195), 1, 0, bodyContainer)
	elseif topIndex == 6 then
		-- Field Jacket over Shirt with Flap Pockets
		addPart("FieldCollar", 22, 33, 12, 5, topColor:Lerp(Color3.new(1, 1, 1), 0.2), 2, 0, bodyContainer)
		addPart("FlapL", 18, 40, 5, 5, topColor:Lerp(Color3.new(0, 0, 0), 0.2), 1, 0, bodyContainer)
		addPart("FlapR", 33, 40, 5, 5, topColor:Lerp(Color3.new(0, 0, 0), 0.2), 1, 0, bodyContainer)
	end

	-- 5. Arms & Hands
	local armColor = if topIndex == 1 then skin else topColor
	local leftArm = addPart("LeftArm", 7, 34, 9, 21, armColor, 5, 0, bodyContainer)
	local rightArm = addPart("RightArm", 40, 34, 9, 21, armColor, 5, 0, bodyContainer)
	addPart("LeftHand", 8, 49, 7, 7, skin, 4, 0, bodyContainer)
	addPart("RightHand", 41, 49, 7, 7, skin, 4, 0, bodyContainer)

	-- 6. Head & Neck
	addPart("Neck", 25, 29, 6, 6, skin:Lerp(Color3.new(0, 0, 0), 0.12), 2, 0, bodyContainer)

	-- Face Shape Variations (Oversized Chibi Heads)
	local headWidth = if faceIndex == 2 then 40 elseif faceIndex == 3 then 36 elseif faceIndex == 4 then 40 elseif faceIndex == 6 then 34 else 38
	local headRadius = if faceIndex == 2 then 18 elseif faceIndex == 3 then 14 elseif faceIndex == 4 then 12 else 16
	local headX = 28 - math.floor(headWidth / 2)

	-- Head Outline
	addPart("HeadOutline", headX - 1, 2, headWidth + 2, 36, Color3.fromRGB(24, 20, 32), headRadius + 1, 0, bodyContainer)
	-- Head Base
	addPart("FaceBase", headX, 3, headWidth, 34, skin, headRadius, 0, bodyContainer)

	-- Ears
	addPart("EarL", headX - 3, 18, 5, 8, skin, 3, 0, bodyContainer)
	addPart("EarR", headX + headWidth - 2, 18, 5, 8, skin, 3, 0, bodyContainer)
	local tragus = addPart("Tragus", headX + headWidth - 1, 20, 2, 3, skin:Lerp(Color3.new(0, 0, 0), 0.22), 1, 0, bodyContainer)
	tragus.BackgroundTransparency = 0.2

	-- Soft Rosy Blush on Cheeks
	local blushL = addPart("BlushL", 12, 23, 7, 4, Color3.fromRGB(255, 120, 120), 3, 0, bodyContainer)
	blushL.BackgroundTransparency = 0.58
	local blushR = addPart("BlushR", 37, 23, 7, 4, Color3.fromRGB(255, 120, 120), 3, 0, bodyContainer)
	blushR.BackgroundTransparency = 0.58

	-- Stylized Nose Mark
	addPart("Nose", 27, 22, 3, 2, skin:Lerp(Color3.new(0, 0, 0), 0.2), 1, 0, bodyContainer)

	-- Expressive Smiling Lips
	addPart("Smile", 25, 27, 8, 3, Color3.fromRGB(175, 70, 70), 2, 0, bodyContainer)
	addPart("LipGlint", 26, 27, 6, 1, Color3.fromRGB(255, 240, 240), 1, 0, bodyContainer)

	-- 7. Expressive Anime / Flash Eyes (The iconic 2010 Social Game look)
	-- Eyebrows
	addPart("BrowL", 16, 12, 9, 2, hairColor, 1, -8, bodyContainer)
	addPart("BrowR", 31, 12, 9, 2, hairColor, 1, 8, bodyContainer)

	-- Upper Dark Lash Line
	addPart("LashL", 15, 14, 11, 2, Color3.fromRGB(20, 20, 26), 1, 0, bodyContainer)
	addPart("LashR", 30, 14, 11, 2, Color3.fromRGB(20, 20, 26), 1, 0, bodyContainer)

	-- Eye Whites (Sclera)
	local eyeWhiteL = addPart("EyeWhiteL", 16, 15, 9, 9, Color3.fromRGB(255, 255, 255), 4, 0, bodyContainer)
	local eyeWhiteR = addPart("EyeWhiteR", 31, 15, 9, 9, Color3.fromRGB(255, 255, 255), 4, 0, bodyContainer)

	-- Vibrant Irises
	local irisL = addPart("IrisL", 18, 16, 6, 7, eyes, 3, 0, bodyContainer)
	local irisR = addPart("IrisR", 32, 16, 6, 7, eyes, 3, 0, bodyContainer)

	-- Dark Pupils
	addPart("PupilL", 19, 17, 4, 5, Color3.fromRGB(18, 20, 28), 2, 0, bodyContainer)
	addPart("PupilR", 33, 17, 4, 5, Color3.fromRGB(18, 20, 28), 2, 0, bodyContainer)

	-- Dual Specular Glints (Glossy reflection highlight)
	addPart("GlintMajorL", 18, 16, 2, 2, Color3.fromRGB(255, 255, 255), 1, 0, bodyContainer)
	addPart("GlintMinorL", 21, 20, 1, 1, Color3.fromRGB(255, 255, 255), 1, 0, bodyContainer)
	addPart("GlintMajorR", 32, 16, 2, 2, Color3.fromRGB(255, 255, 255), 1, 0, bodyContainer)
	addPart("GlintMinorR", 35, 20, 1, 1, Color3.fromRGB(255, 255, 255), 1, 0, bodyContainer)

	-- 8. Front Hairstyles & Headwear
	addPart("HairCrown", 8, 1, 40, 13, hairColor, 9, 0, bodyContainer)

	if style == 1 then
		-- Messy Pixie: Layered choppy bangs and spiky crown tufts
		addPart("ChoppyBangs", 9, 7, 20, 12, hairColor, 5, -16, bodyContainer)
		addPart("CrownTuft1", 13, -2, 8, 8, hairColor, 3, -15, bodyContainer)
		addPart("CrownTuft2", 23, -3, 8, 8, hairColor, 3, 5, bodyContainer)
		addPart("CrownTuft3", 33, -2, 8, 8, hairColor, 3, 20, bodyContainer)
	elseif style == 2 then
		-- Ponytail Style: Sleek Headband, side bangs, side tress, and glossy shine streak
		addPart("Headband", 8, 6, 40, 4, Color3.fromRGB(36, 38, 48), 2, 0, bodyContainer)
		addPart("PonytailBangs", 9, 7, 18, 14, hairColor, 6, -14, bodyContainer)
		addPart("PonytailSideLock", 36, 9, 7, 16, hairColor, 4, 10, bodyContainer)
		local shine = addPart("HairShine", 14, 3, 22, 3, hairColor:Lerp(Color3.new(1, 1, 1), 0.32), 2, 0, bodyContainer)
		shine.BackgroundTransparency = 0.25
	elseif style == 3 then
		-- Sleek Bob: Symmetrical face-framing bobs and center part
		addPart("BobBangsL", 9, 6, 18, 12, hairColor, 5, -8, bodyContainer)
		addPart("BobBangsR", 28, 6, 18, 12, hairColor, 5, 8, bodyContainer)
		addPart("BobFrameL", 7, 13, 8, 20, hairColor, 4, 0, bodyContainer)
		addPart("BobFrameR", 41, 13, 8, 20, hairColor, 4, 0, bodyContainer)
	elseif style == 4 then
		-- Side Part Gentleman: Volume top with clean parting
		addPart("GentlemanSweep", 17, 2, 28, 13, hairColor, 6, 6, bodyContainer)
		addPart("GentlemanSideburn", 7, 12, 5, 14, hairColor, 3, 0, bodyContainer)
	elseif style == 5 then
		-- Layered Wings: Big winged bangs framing face
		addPart("WingedBangs", 8, 5, 26, 16, hairColor, 8, -20, bodyContainer)
		addPart("WingedSideL", 6, 12, 10, 20, hairColor, 5, -12, bodyContainer)
		addPart("WingedSideR", 40, 12, 10, 20, hairColor, 5, 12, bodyContainer)
	elseif style == 6 then
		-- Newsboy Cap: Cabbie cap with visor/brim, crown button, and hair wisps
		addPart("CapCrown", 5, -4, 46, 20, Color3.fromRGB(158, 138, 108), 12, 0, bodyContainer)
		addPart("CapButton", 26, -6, 5, 4, Color3.fromRGB(120, 102, 78), 2, 0, bodyContainer)
		addPart("CapVisor", 4, 10, 44, 6, Color3.fromRGB(120, 102, 78), 3, -4, bodyContainer)
		addPart("CapWispsL", 9, 13, 9, 9, hairColor, 3, 0, bodyContainer)
		addPart("CapWispsR", 37, 13, 9, 11, hairColor, 3, 0, bodyContainer)
	end

	-- VIP Gold Badge
	if isVIP then
		local vipStar = addPart("VIPBadge", 25, 38, 8, 8, Color3.fromRGB(255, 215, 0), 2, 0, bodyContainer)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = vipStar
	end

	root.Parent = parent

	-- Animation & Direction State
	local currentClip = "Idle"
	local elapsed = 0
	local lastFrame = -1
	local lastZ = -1
	local currentFacing: "Left" | "Right" = "Right"
	local destroyed = false

	local function setFacing(facing: "Left" | "Right")
		if currentFacing == facing then
			return
		end
		currentFacing = facing
		local isLeft = facing == "Left"

		for _, p in registeredVectorParts do
			local targetX = if isLeft then (56 - p.BaseX - p.Width) else p.BaseX
			p.Frame.Position = UDim2.fromOffset(targetX, p.BaseY)
			if p.BaseRot ~= 0 then
				p.Frame.Rotation = if isLeft then -p.BaseRot else p.BaseRot
			end
		end
	end

	local function play(name: string)
		assert(sheet.Clips[name], "Unknown sprite clip: " .. name)
		if currentClip ~= name then
			currentClip = name
			elapsed = 0
			lastFrame = -1
		end
	end

	local function update(dt: number, zIndex: number, facing: ("Left" | "Right")?)
		if destroyed then
			return
		end

		if facing and facing ~= currentFacing then
			setFacing(facing)
		end

		elapsed += math.max(0, dt)
		local clip = sheet.Clips[currentClip]
		local step = math.floor(elapsed * clip.FPS)
		local frame = clip.FirstFrame + (if clip.Looped then (step % clip.FrameCount) else math.min(step, clip.FrameCount - 1))
		local frameChanged = frame ~= lastFrame

		if frameChanged then
			image.ImageRectOffset = Vector2.new((frame % 4) * 256, math.floor(frame / 4) * 256)
			lastFrame = frame
		end

		-- Procedural Vector Animation Update
		if fallback.Visible then
			local phase = (frame - clip.FirstFrame) / clip.FrameCount * math.pi * 2
			local swing = math.sin(phase)
			local isDancing = currentClip == "Dance"
			local isWalking = currentClip == "Walk"

			-- Leg strides & Arm swings
			if isWalking then
				leftLeg.Rotation = swing * 24
				rightLeg.Rotation = -swing * 24
				leftArm.Rotation = -swing * 24
				rightArm.Rotation = swing * 24
				bodyContainer.Position = UDim2.fromOffset(0, -math.abs(swing) * 2.5)
			elseif isDancing then
				leftLeg.Rotation = swing * 8
				rightLeg.Rotation = -swing * 8
				leftArm.Rotation = 45 + swing * 35
				rightArm.Rotation = -45 - math.cos(phase) * 35
				bodyContainer.Position = UDim2.fromOffset(0, -math.abs(swing) * 5)
			else
				-- Idle Breathing
				leftLeg.Rotation = 0
				rightLeg.Rotation = 0
				leftArm.Rotation = math.sin(elapsed * 3) * 4
				rightArm.Rotation = -math.sin(elapsed * 3) * 4
				bodyContainer.Position = UDim2.fromOffset(0, math.sin(elapsed * 3) * 1.5)
			end

			-- Ponytail dynamic physics bounce
			if ponytailTail then
				local baseRot = if currentFacing == "Left" then -20 else 20
				local bounce = if isDancing then swing * 15 elseif isWalking then swing * 8 else math.sin(elapsed * 3) * 3
				ponytailTail.Rotation = baseRot + bounce
			end

			-- Subtle idle eye blink cycle (squash height every ~3.5 seconds)
			local blinkCycle = elapsed % 3.5
			local isBlinking = blinkCycle < 0.12
			local eyeH = if isBlinking then 2 else 9
			eyeWhiteL.Size = UDim2.fromOffset(9, eyeH)
			eyeWhiteR.Size = UDim2.fromOffset(9, eyeH)
			irisL.Visible = not isBlinking
			irisR.Visible = not isBlinking
		end

		if lastZ ~= zIndex then
			root.ZIndex = zIndex
			for _, part in parts do
				part.ZIndex = zIndex
			end
			lastZ = zIndex
		end
	end

	update(0, 5)

	return {
		Root = root,
		Play = play,
		Update = update,
		SetFacing = setFacing,
		Destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			root:Destroy()
		end,
	}
end

return SpriteAnimator
