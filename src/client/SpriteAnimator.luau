--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local SpriteAnimator = {}

function SpriteAnimator.new(parent: Instance, sheet: Types.SpriteSheet, color: Color3, isVIP: boolean): Types.SpriteAnimator
	for name, clip in sheet.Clips do
		assert(clip.FirstFrame >= 0 and clip.FirstFrame % 1 == 0, name .. ": invalid first frame")
		assert(clip.FrameCount >= 1 and clip.FrameCount % 1 == 0 and clip.FirstFrame + clip.FrameCount <= 16, name .. ": exceeds 4x4 atlas")
		assert(clip.FPS > 0 and clip.FPS < math.huge, name .. ": invalid FPS")
	end
	assert(sheet.Clips.Idle, "Sprite sheet requires an Idle clip")
	local root = Instance.new("Frame")
	root.Name = "CartoonGuest"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Size = UDim2.fromOffset(56, 76)
	root.BackgroundTransparency = 1

	local image = Instance.new("ImageLabel")
	image.Name = "SpriteSheet"
	image.AnchorPoint = Vector2.new(0.5, 1)
	image.Position = UDim2.fromScale(0.5, 1)
	image.Size = UDim2.fromOffset(76, 76)
	image.BackgroundTransparency = 1
	image.Image = sheet.AssetId
	image.ImageRectSize = Vector2.new(256, 256)
	image.Visible = sheet.AssetId ~= ""
	image.Parent = root

	local fallback = Instance.new("Frame")
	fallback.Name = "VectorFallback"
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.BackgroundTransparency = 1
	fallback.Visible = sheet.AssetId == ""
	fallback.Parent = root
	local parts: { GuiObject } = { image, fallback }
	local function shape(name: string, x: number, y: number, w: number, h: number, tint: Color3, radius: number): Frame
		local part = Instance.new("Frame")
		part.Name = name
		part.Position = UDim2.fromOffset(x, y)
		part.Size = UDim2.fromOffset(w, h)
		part.BackgroundColor3 = tint
		part.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = part
		part.Parent = fallback
		table.insert(parts, part)
		return part
	end
	shape("Shadow", 9, 68, 38, 7, Color3.fromRGB(20, 18, 35), 8).BackgroundTransparency = 0.5
	local leftLeg = shape("LeftShoe", 17, 56, 9, 16, Color3.fromRGB(32, 40, 65), 4)
	local rightLeg = shape("RightShoe", 30, 56, 9, 16, Color3.fromRGB(32, 40, 65), 4)
	local leftArm = shape("LeftArm", 8, 34, 9, 24, color, 5)
	local rightArm = shape("RightArm", 39, 34, 9, 24, color, 5)
	shape("Shirt", 15, 32, 26, 28, color, 8)
	shape("ShirtShine", 19, 35, 4, 17, color:Lerp(Color3.new(1, 1, 1), 0.45), 2)
	shape("Face", 14, 8, 28, 28, Color3.fromRGB(241, 189, 140), 12)
	shape("Hair", 13, 5, 30, 12, Color3.fromRGB(50, 32, 48), 7)
	shape("LeftEye", 21, 21, 3, 4, Color3.fromRGB(40, 30, 45), 2)
	shape("RightEye", 32, 21, 3, 4, Color3.fromRGB(40, 30, 45), 2)
	shape("Smile", 25, 29, 7, 2, Color3.fromRGB(150, 75, 65), 1)
	if isVIP then
		shape("VIPBadge", 26, 39, 7, 7, Color3.fromRGB(255, 219, 80), 2)
	end
	root.Parent = parent

	local current = "Idle"
	local elapsed = 0
	local lastFrame = -1
	local lastZ = -1
	local destroyed = false
	local function play(name: string)
		assert(sheet.Clips[name], "Unknown sprite clip: " .. name)
		if current ~= name then
			current = name
			elapsed = 0
			lastFrame = -1
		end
	end
	local function update(dt: number, zIndex: number)
		if destroyed then return end
		elapsed += math.max(0, dt)
		local clip = sheet.Clips[current]
		local step = math.floor(elapsed * clip.FPS)
		local frame = clip.FirstFrame + (if clip.Looped then step % clip.FrameCount else math.min(step, clip.FrameCount - 1))
		if frame ~= lastFrame then
			image.ImageRectOffset = Vector2.new((frame % 4) * 256, math.floor(frame / 4) * 256)
			lastFrame = frame
		end
		if fallback.Visible then
			local phase = (frame - clip.FirstFrame) / clip.FrameCount * math.pi * 2
			local swing = math.sin(phase)
			local dancing = current == "Dance"
			leftArm.Rotation = swing * (if dancing then 65 else 20)
			rightArm.Rotation = -leftArm.Rotation
			leftLeg.Rotation = if current == "Walk" then swing * 22 else 0
			rightLeg.Rotation = -leftLeg.Rotation
			fallback.Position = UDim2.fromOffset(0, -math.abs(swing) * (if dancing then 6 else 2))
		end
		if lastZ ~= zIndex then
			root.ZIndex = zIndex
			-- All parts share the guest's depth; sibling order draws the face over the body.
			for _, part in parts do part.ZIndex = zIndex end
			lastZ = zIndex
		end
	end
	update(0, 5)
	return {
		Root = root,
		Play = play,
		Update = update,
		Destroy = function()
			if destroyed then return end
			destroyed = true
			root:Destroy()
		end,
	}
end

return SpriteAnimator
