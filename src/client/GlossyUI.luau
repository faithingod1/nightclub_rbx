--!strict
local TweenService = game:GetService("TweenService")
local GlossyUI = {}

export type PillStatRefs = {
	Container: Frame,
	ValueLabel: TextLabel,
	FillBar: Frame?,
}

-- A sharp midpoint gives the lacquered highlight of classic Flash toolbars.
function GlossyUI.style(surface: GuiObject)
	surface.BorderSizePixel = 0
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(225, 236, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 180, 215)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 221, 248)),
	})
	gradient.Parent = surface
end

-- Authentic 2010 Nightclub City Obsidian Chrome + Specular Glass + Neon Rim Styler
function GlossyUI.styleNeonChromePanel(frame: Frame, rimColor: Color3, cornerPx: number)
	frame.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerPx)
	corner.Parent = frame

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 52, 88)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(26, 22, 44)),
		ColorSequenceKeypoint.new(0.52, Color3.fromRGB(14, 12, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 22, 48)),
	})
	grad.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = rimColor
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

function GlossyUI.createStatPill(
	name: string,
	pos: UDim2,
	size: UDim2,
	anchor: Vector2,
	badgeText: string,
	badgeColor: Color3,
	withProgressBar: boolean,
	zIndex: number,
	parent: Instance
): PillStatRefs
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.AnchorPoint = anchor
	pill.Position = pos
	pill.Size = size
	pill.ZIndex = zIndex
	GlossyUI.styleNeonChromePanel(pill, badgeColor, 99)

	local badge = Instance.new("TextLabel")
	badge.Name = "IconBadge"
	badge.Position = UDim2.fromOffset(4, 4)
	badge.Size = UDim2.fromOffset(size.Y.Offset - 8, size.Y.Offset - 8)
	badge.BackgroundColor3 = badgeColor
	badge.BorderSizePixel = 0
	badge.Font = Enum.Font.GothamBlack
	badge.Text = badgeText
	badge.TextColor3 = Color3.fromRGB(14, 12, 24)
	badge.TextSize = 14
	badge.ZIndex = zIndex + 1
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = badge
	badge.Parent = pill

	local fill: Frame? = nil
	if withProgressBar then
		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(size.Y.Offset + 2, size.Y.Offset - 11)
		track.Size = UDim2.new(1, -(size.Y.Offset + 12), 0, 6)
		track.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
		track.BorderSizePixel = 0
		track.ZIndex = zIndex + 1
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = track
		track.Parent = pill

		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0.65, 1)
		bar.BackgroundColor3 = badgeColor
		bar.BorderSizePixel = 0
		bar.ZIndex = zIndex + 2
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = bar
		bar.Parent = track
		fill = bar
	end

	local val = Instance.new("TextLabel")
	val.Name = "Value"
	val.Position = UDim2.fromOffset(size.Y.Offset + 4, 2)
	val.Size = UDim2.new(1, -(size.Y.Offset + 12), 0, if withProgressBar then size.Y.Offset - 14 else size.Y.Offset - 4)
	val.BackgroundTransparency = 1
	val.Font = Enum.Font.GothamBlack
	val.TextXAlignment = Enum.TextXAlignment.Left
	val.TextColor3 = Color3.fromRGB(255, 255, 255)
	val.TextSize = 15
	val.Text = "0"
	val.ZIndex = zIndex + 2
	val.Parent = pill

	pill.Parent = parent
	return {
		Container = pill,
		ValueLabel = val,
		FillBar = fill,
	}
end

function GlossyUI.cashPopup(parent: Instance, amount: number, position: Vector2, zIndex: number)
	local label = Instance.new("TextLabel")
	label.Name = "CashPopup"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromOffset(position.X, position.Y - 32)
	label.Size = UDim2.fromOffset(180, 44)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 26
	label.Text = string.format("+$%d", amount)
	label.TextColor3 = Color3.fromRGB(168, 255, 100)
	label.TextStrokeColor3 = Color3.fromRGB(24, 68, 38)
	label.TextStrokeTransparency = 0.15
	label.ZIndex = zIndex
	label.Parent = parent
	local tween = TweenService:Create(label, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(position.X, position.Y - 120),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Once(function() label:Destroy() end)
	tween:Play()
end

return GlossyUI

