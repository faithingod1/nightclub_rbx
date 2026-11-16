--!strict
-- Small procedural toolbar illustrations, sized for the original Flash-style dock.
local Icons = {}
function Icons.draw(parent: GuiObject, id: string)
	local z = parent.ZIndex + 1
	local cx = parent.Size.X.Offset / 2
	local function shape(x: number,y: number,w: number,h: number,color: Color3,radius: number?): Frame
		local f = Instance.new("Frame")
		f.Position, f.Size = UDim2.fromOffset(cx+x,y), UDim2.fromOffset(w,h)
		f.BackgroundColor3, f.BorderSizePixel, f.ZIndex = color,0,z
		if radius then local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,radius); c.Parent = f end
		f.Parent = parent
		return f
	end
	local rgb = Color3.fromRGB
	if id == "DJRefresh" then
		shape(-17,6,34,34,rgb(13,23,35),17)
		shape(-12,11,24,24,rgb(98,218,240),12)
		shape(-6,17,12,12,rgb(27,52,77),6)
		shape(9,6,4,23,rgb(241,249,255),2).Rotation = 24
	elseif id == "DJBass" then
		for i=0,4 do local h=12+(i%3)*8; shape(-20+i*9,38-h,6,h,rgb(255,150+i*15,217),2) end
	elseif id == "DJShout" then
		shape(-5,18,10,25,rgb(34,42,57),4).Rotation = 22
		shape(-12,5,24,21,rgb(224,236,244),10)
		for i=0,2 do shape(-8,10+i*4,16,2,rgb(83,110,136)) end
	elseif id == "Restock" then
		shape(-14,14,28,27,rgb(109,238,198),7)
		shape(-11,14,22,5,rgb(226,255,242),2)
		shape(5,4,4,27,rgb(250,246,226),2).Rotation = 12
		shape(-18,9,13,13,rgb(220,245,91),7)
	elseif id == "BuildShop" then
		shape(-17,18,34,23,rgb(236,177,88),4)
		shape(-20,8,40,14,rgb(88,221,239),4)
		for i=0,3 do shape(-18+i*10,8,5,14,rgb(234,251,255),2) end
		shape(-4,26,10,15,rgb(73,73,91),2)
	elseif id == "MoveItem" then
		shape(-3,5,6,36,rgb(213,239,255),2)
		shape(-18,20,36,6,rgb(213,239,255),2)
		for _, p in {{-5,4},{-5,34},{-20,18},{10,18}} do shape(p[1],p[2],10,10,rgb(213,239,255),2).Rotation=45 end
	elseif id == "SellItem" then
		shape(-17,8,34,34,rgb(196,126,35),17)
		shape(-15,6,30,30,rgb(255,218,92),15)
		local dollar=Instance.new("TextLabel")
		dollar.Position,dollar.Size=UDim2.fromOffset(cx-15,6),UDim2.fromOffset(30,30)
		dollar.BackgroundTransparency=1
		dollar.Text,dollar.TextSize,dollar.Font="$",23,Enum.Font.GothamBold
		dollar.TextColor3,dollar.ZIndex=rgb(139,87,28),z
		dollar.Parent=parent
	end
end
return Icons
