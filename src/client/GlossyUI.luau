--!strict
local TweenService = game:GetService("TweenService")
local GlossyUI = {}

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
