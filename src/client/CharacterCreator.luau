--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Appearance = require(Shared:WaitForChild("Appearance"))
local Animator = require(script.Parent:WaitForChild("SpriteAnimator"))
local Creator = {}
function Creator.new(parent: GuiObject, initial: Types.Appearance?, save: (Types.Appearance) -> (boolean,string)): Types.CharacterEditor
	local selected = Appearance.validate(initial) or Appearance.default()
	local busy, destroyed = false, false
	local shield = Instance.new("Frame")
	shield.Name = "CharacterEditorOverlay"
	shield.Size = UDim2.fromScale(1,1)
	shield.BackgroundColor3 = Color3.fromRGB(5,10,20)
	shield.BackgroundTransparency = 0.3
	shield.BorderSizePixel, shield.ZIndex, shield.Active, shield.Visible = 0,95999,true,false
	shield.Parent = parent
	local root = Instance.new("Frame")
	root.Name = "CharacterCreator"
	root.Size, root.Position, root.AnchorPoint = UDim2.fromOffset(590,430),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5)
	root.BackgroundColor3 = Color3.fromRGB(28,38,55)
	root.BorderSizePixel, root.ZIndex, root.Active = 0,96000,true
	local corner = Instance.new("UICorner");corner.CornerRadius=UDim.new(0,16);corner.Parent=root
	root.Parent = shield
	local function label(text: string,x: number,y: number,w: number,h: number): TextLabel
		local t=Instance.new("TextLabel")
		t.Size,t.Position=UDim2.fromOffset(w,h),UDim2.fromOffset(x,y)
		t.Text,t.TextSize,t.Font=text,14,Enum.Font.GothamBold
		t.TextColor3,t.BackgroundTransparency,t.ZIndex=Color3.new(1,1,1),1,96001
		t.Parent=root;return t
	end
	label("CREATE YOUR CLUB CHARACTER",20,12,550,34)
	local status=label("Choose your look, then save.",20,345,550,24)
	local function button(text: string,x: number,y: number,w: number,fn: () -> (), name: string?)
		local b=Instance.new("TextButton")
		b.Name = name or text
		b.Size,b.Position=UDim2.fromOffset(w,34),UDim2.fromOffset(x,y)
		b.BackgroundColor3,b.TextColor3=Color3.fromRGB(48,131,161),Color3.new(1,1,1)
		b.Text,b.TextSize,b.Font,b.ZIndex=text,13,Enum.Font.GothamBold,96002
		local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,7);c.Parent=b
		b.Parent=root;b.Activated:Connect(function() if not busy then fn() end end)
	end
	local preview: Types.SpriteAnimator? = nil
	local choices: {[string]: TextLabel} = {}
	local names = {
		Face = {"Oval", "Round", "Diamond", "Wide", "Heart", "Slim"},
		Hair = {"Messy Pixie", "Ponytail", "Sleek Bob", "Side Part", "Layered Wings", "Newsboy Cap"},
		Top = {"Black Tank", "Purple Shirt", "Vest & Tie", "Blue Casual", "Bomber Jacket", "Field Jacket"},
		Bottom = {"Khaki Slacks", "Denim Jeans", "Indigo Slim", "Green Skirt", "Charcoal Jeans"},
		Shoes = {"High-Top Canvas", "Low-Top Sneakers", "Glossy Oxfords", "Leather Boots"},
	}
	local function redraw()
		if preview then preview.Destroy() end
		preview=Animator.new(root,Config.GUEST_SPRITE,Color3.new(1,1,1),false,selected)
		preview.Root.Position=UDim2.fromOffset(145,315)
		local scale=Instance.new("UIScale");scale.Scale=3;scale.Parent=preview.Root
		preview.Update(0,96003)
		for name,t in choices do
			local index = (selected :: any)[name]
			local options = (names :: any)[name]
			t.Text = name .. ": " .. (if options then options[index] else tostring(index) .. " / " .. Appearance.Limits[name])
		end
	end
	for i,name in {"Skin","Face","Hair","HairColor","Eyes","Top","Bottom","Shoes"} do
		local y=53+(i-1)*35
		choices[name]=label(name,302,y,212,30)
		button("<",267,y,30,function()
			(selected :: any)[name]=((selected :: any)[name]-2)%Appearance.Limits[name]+1;redraw()
		end, name .. "Previous")
		button(">",520,y,30,function()
			(selected :: any)[name]=(selected :: any)[name]%Appearance.Limits[name]+1;redraw()
		end, name .. "Next")
	end
	button("SAVE CHARACTER",304,382,245,function()
		if busy then return end
		busy=true;status.Text="Saving..."
		local snapshot = Appearance.validate(selected) :: Types.Appearance
		task.spawn(function()
			local ok,success,message=pcall(save,snapshot)
			busy=false
			if destroyed then return end
			status.Text=if ok then message else "Could not save. Please try again."
			if ok and success then shield.Visible=false end
		end)
	end)
	button("CANCEL",40,382,200,function() shield.Visible=false end)
	local function resize()
		local s=root:FindFirstChildOfClass("UIScale")
		if not s then s=Instance.new("UIScale");s.Parent=root end
		s.Scale=math.min(1,math.max(0.1,(parent.AbsoluteSize.X-24)/590),math.max(0.1,(parent.AbsoluteSize.Y-24)/430))
	end
	local resizeConnection=parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	return {
		Open=function(current: Types.Appearance?)
			if busy or destroyed then return end
			selected=Appearance.validate(current) or Appearance.default()
			status.Text="Choose your look, then save."
			shield.Visible=true
			redraw()
		end,
		IsOpen=function(): boolean return shield.Visible end,
		Destroy=function()
			destroyed=true
			resizeConnection:Disconnect()
			if preview then preview.Destroy() end
			shield:Destroy()
		end,
	}
end
return Creator
