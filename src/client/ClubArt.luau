--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Iso = require(Shared:WaitForChild("IsometricMath"))
local Types = require(Shared:WaitForChild("Types"))
local Art = {}
local rgb = Color3.fromRGB

local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number, radius: number?): Frame
	local f = Instance.new("Frame")
	f.Position, f.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	f.BackgroundColor3, f.BorderSizePixel, f.ZIndex = color, 0, z
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = f
	end
	f.Parent = parent
	return f
end
local function line(parent: Instance, a: Vector2, b: Vector2, color: Color3, z: number, thickness: number?)
	local d = b - a
	local f = rect(parent, (a.X+b.X)/2, (a.Y+b.Y)/2, d.Magnitude, thickness or 2, color, z)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
end
-- Split convex polygons into right triangles: constant instance count per face.
local MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(0.4999,0),
	NumberSequenceKeypoint.new(0.5001,1), NumberSequenceKeypoint.new(1,1),
})
local function polygon(parent: Instance, points: { Vector2 }, color: Color3, z: number): { Frame }
	local faces: { Frame } = {}
	local function triangle(a: Vector2,b: Vector2,c: Vector2)
		-- Splitting on the longest edge keeps the altitude inside the triangle.
		if (c-a).Magnitude > (b-a).Magnitude then b,c=c,b end
		if (c-b).Magnitude > (b-a).Magnitude then a,c=c,a end
		local edge = b-a
		if edge.Magnitude < 0.001 then return end
		local unit = edge.Unit
		local ac = c-a
		local foot = a+unit*(ac.X*unit.X+ac.Y*unit.Y)
		local up = c-foot
		if up.Magnitude < 0.001 then return end
		for _, endpoint in {a,b} do
			local base = endpoint-foot
			if base.Magnitude < 0.001 then continue end
			local center = foot+(base+up)*0.5
			local face = rect(parent,center.X,center.Y,base.Magnitude,up.Magnitude,color,z)
			face.AnchorPoint = Vector2.new(0.5,0.5)
			face.Rotation = math.deg(math.atan2(base.Y,base.X))
			local mask = Instance.new("UIGradient")
			local sign = if base.X*up.Y-base.Y*up.X > 0 then 1 else -1
			mask.Rotation = sign*math.deg(math.atan2(base.Magnitude,up.Magnitude))
			mask.Transparency = MASK
			mask.Parent = face
			table.insert(faces,face)
		end
	end
	for i=2,#points-1 do triangle(points[1],points[i],points[i+1]) end
	return faces
end

local function text(parent: Instance, value: string, x: number, y: number, w: number, h: number, z: number, color: Color3?)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position, t.Size = UDim2.fromOffset(x,y), UDim2.fromOffset(w,h)
	t.Text, t.Font, t.TextSize = value, Enum.Font.GothamBold, 12
	t.TextColor3, t.ZIndex = color or rgb(230,240,255), z
	t.Parent = parent
end
local function diamond(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number)
	return polygon(parent,{Vector2.new(x,y-h/2),Vector2.new(x+w/2,y),Vector2.new(x,y+h/2),Vector2.new(x-w/2,y)},color,z)
end

function Art.room(parent: Instance, width: number, height: number)
	local function p(x: number,y: number): Vector2 return Iso.gridToScreen(x,y) end
	-- Streets and pavements share the camera and zoom of the club.
	polygon(parent,{p(-2,-2),p(width+3,-2),p(width+3,height+3),p(-2,height+3)},rgb(30,34,43),1)
	polygon(parent,{p(-0.7,-0.7),p(width+1.4,-0.7),p(width+1.4,height+1.4),p(-0.7,height+1.4)},rgb(98,108,118),1)
	polygon(parent,{p(0.5,0.5),p(width+0.5,0.5),p(width+0.5,height+0.5),p(0.5,height+0.5)},rgb(113,85,53),2)
	for x = 0.5, width+0.5 do line(parent,p(x,0.5),p(x,height+0.5),rgb(159,123,73),3,1) end
	for y = 0.5, height+0.5 do line(parent,p(0.5,y),p(width+0.5,y),rgb(75,56,38),3,1) end
	for i = 1, math.max(width,height), 2 do
		local a = p(i,-1.5)
		line(parent,a,a+Vector2.new(48,24),rgb(168,170,157),1,4)
		local b = p(-1.5,i)
		line(parent,b,b+Vector2.new(-48,24),rgb(168,170,157),1,4)
	end
	-- Receding city facades, behind the two club walls.
	for i = 1, width, 3 do
		local base = p(i,-2.8)
		local h = 125 + (i%3)*22
		rect(parent,base.X-42,base.Y-h,82,h,rgb(49,56,77),1)
		for row = 0, 2 do for col = 0, 2 do
			rect(parent,base.X-32+col*23,base.Y-h+16+row*32,13,20,if (row+col+i)%3==0 then rgb(226,185,105) else rgb(78,123,153),1,2)
		end end
	end
	for _, side in {true,false} do
		local length = if side then width else height
		for i = 1, length do
			-- Leave the entrance tile open.
			if i == 1 then continue end
			local a = if side then p(i-0.5,0.5) else p(0.5,i-0.5)
			local b = if side then p(i+0.5,0.5) else p(0.5,i+0.5)
			local lift = Vector2.new(0,110)
			local wallZ = Iso.getCutawayWallZIndex(if side then i else 0.5, if side then 0.5 else i, false)
			polygon(parent,{a,b,b-lift,a-lift},if side then rgb(29,40,54) else rgb(39,49,65),wallZ)
			-- Geometric neon strips on dark panels, as in the reference lounge.
			local middle = (a+b)*0.5
			line(parent,a-Vector2.new(0,54),middle-Vector2.new(0,94),rgb(184,83,219),wallZ,2)
			line(parent,middle-Vector2.new(0,94),b-Vector2.new(0,51),rgb(77,207,238),wallZ,2)
			line(parent,a-Vector2.new(0,8),b-Vector2.new(0,8),rgb(111,81,57),wallZ,5)

			line(parent,a-lift,b-lift,rgb(106,192,209),wallZ,5)
			if i%3 == 0 then
				local lamp=(a+b)*0.5-Vector2.new(0,77)
				rect(parent,lamp.X-7,lamp.Y-8,14,23,rgb(16,24,37),wallZ,4)
				rect(parent,lamp.X-3,lamp.Y-4,6,15,rgb(255,218,149),wallZ,3)
			end
			line(parent,a,b,rgb(17,23,34),wallZ,8)
		end
	end
	-- Entrance at tile (1,1), with a recessed opening and open glass leaf.
	local da, db = p(0.5,0.5), p(1.5,0.5)
	local lift = Vector2.new(0,116)
	local doorZ = Iso.getCutawayWallZIndex(1, 0.5, false)
	polygon(parent,{da,db,db-lift,da-lift},rgb(9,15,25),doorZ)
	line(parent,da,da-lift,rgb(181,139,74),doorZ,7)
	line(parent,db,db-lift,rgb(181,139,74),doorZ,7)
	line(parent,da-lift,db-lift,rgb(235,196,111),doorZ,8)
	local leaf = db+Vector2.new(23,-15)
	polygon(parent,{db,leaf,leaf-Vector2.new(0,104),db-Vector2.new(0,104)},rgb(49,108,130),doorZ)
	line(parent,leaf,leaf-Vector2.new(0,104),rgb(156,220,227),doorZ,3)
	line(parent,db-Vector2.new(0,50),leaf-Vector2.new(0,50),rgb(231,197,116),doorZ,4)
	polygon(parent,{da,db,db+Vector2.new(-18,9),da+Vector2.new(-18,9)},rgb(160,62,92),doorZ)
	local entrance = (da+db)*0.5-lift
	text(parent,"OPEN",entrance.X-23,entrance.Y-27,46,22,doorZ+2,rgb(255,221,137))
	local sign = p(3.5,0.5)
	local signZ = Iso.getCutawayWallZIndex(3.5, 0.5, true)
	rect(parent,sign.X-66,sign.Y-96,132,32,rgb(12,20,34),signZ,8)
	text(parent,"NEON SOCIAL",sign.X-65,sign.Y-95,130,30,signZ+1,rgb(110,240,244))

	-- Exterior sidewalk & velvet rope along the queue axis (gx = 0.18, gy = 1..6)
	local rStart = p(0.18, 1.2)
	local rEnd = p(0.18, 6.2)
	line(parent, rStart, rEnd, rgb(210, 40, 60), 45, 3)
	for slot = 1, 6 do
		local stanchion = p(0.18, 1.2 + (slot - 1) * 0.95)
		rect(parent, stanchion.X - 3, stanchion.Y - 14, 6, 14, rgb(255, 215, 60), 46, 2)
		rect(parent, stanchion.X - 5, stanchion.Y - 18, 10, 5, rgb(255, 230, 110), 46, 3)
	end
	-- Raised front edges give the room a cutaway-platform silhouette.
	local front = p(width+0.5,height+0.5)
	for _, edge in {p(width+0.5,0.5),p(0.5,height+0.5)} do
		polygon(parent,{edge,front,front+Vector2.new(0,18),edge+Vector2.new(0,18)},rgb(29,32,41),4)
		line(parent,edge,front,rgb(118,134,146),4,3)
	end
	for _, point in {p(width+1.1,1),p(1,height+1.1)} do
		rect(parent,point.X-3,point.Y-94,6,94,rgb(32,38,49),4)
		rect(parent,point.X-13,point.Y-100,26,18,rgb(255,220,135),4,7)
	end
end

function Art.furniture(parent: GuiObject, def: Types.ItemDef): { Frame }
	local z = parent.ZIndex
	local c = if def.Category == "DancePad" then rgb(39,161,246) else def.FallbackColor
	local category = def.Category
	if category == "DancePad" then
		diamond(parent,64,32,126,62,rgb(16,23,37),z)
		diamond(parent,64,30,104,48,c,z)
		return diamond(parent,64,30,78,34,c:Lerp(rgb(255,255,255),0.5),z)
	end
	local function box(x: number,y: number,w: number,h: number,tint: Color3)
		rect(parent,x,y,w,h,tint,z,4)
		polygon(parent,{Vector2.new(x,y),Vector2.new(x+12,y-8),Vector2.new(x+w+12,y-8),Vector2.new(x+w,y)},tint:Lerp(rgb(255,255,255),0.22),z)
		polygon(parent,{Vector2.new(x+w,y),Vector2.new(x+w+12,y-8),Vector2.new(x+w+12,y+h-8),Vector2.new(x+w,y+h)},tint:Lerp(rgb(0,0,0),0.35),z)
	end
	if category == "Speaker" then
		box(17,16,51,100,rgb(23,29,40))
		for _, y in {30,70} do
			rect(parent,23,y,38,38,c,z,19)
			rect(parent,27,y+4,30,30,rgb(9,14,23),z,15)
			rect(parent,35,y+12,14,14,rgb(62,76,94),z,7)
		end
	elseif category == "DJBooth" then
		box(3,48,72,60,rgb(38,51,65))
		rect(parent,7,55,62,4,c,z,2)
		for _, x in {12,46} do
			rect(parent,x,31,27,27,rgb(10,17,28),z,14)
			rect(parent,x+5,36,17,17,rgb(82,212,226),z,9)
			rect(parent,x+10,41,7,7,rgb(21,39,57),z,4)
		end
		for i=0,5 do rect(parent,12+i*9,75,5,10+(i%3)*5,c,z,2) end
		text(parent,"DJ",20,88,40,20,z)
	elseif category == "MocktailBar" then
		box(1,49,74,52,rgb(38,91,96))
		rect(parent,2,45,76,13,rgb(193,236,234),z,4)
		rect(parent,8,68,62,4,c,z,2)
		for i=0,3 do
			rect(parent,12+i*16,26,10,20,if i%2==0 then rgb(91,235,191) else rgb(239,174,84),z,3)
			rect(parent,16+i*16,17,3,13,rgb(236,246,255),z,1)
		end
		text(parent,"NEON FIZZ",3,77,74,20,z)
	elseif category == "VIPBooth" then
		box(2,18,73,58,rgb(15,23,32))
		rect(parent,7,23,62,28,rgb(51,69,82),z,9)
		rect(parent,9,55,60,19,rgb(39,56,70),z,7)
		rect(parent,2,45,12,34,rgb(24,36,48),z,5)
		rect(parent,67,45,12,34,rgb(24,36,48),z,5)
		box(19,84,40,10,rgb(111,80,62))
		rect(parent,35,70,8,15,rgb(255,224,134),z,4)
	else
		box(16,64,50,42,rgb(42,55,73))
		rect(parent,9,18,7,83,rgb(180,190,205),z,3)
		rect(parent,69,18,7,83,rgb(180,190,205),z,3)
		line(parent,Vector2.new(13,32),Vector2.new(72,32),rgb(210,78,104),z,6)
		text(parent,"SECURITY",7,77,70,20,z)
	end
	return {}
end

function Art.cursor(parent: GuiObject)
	local points = {Vector2.new(64,0),Vector2.new(128,32),Vector2.new(64,64),Vector2.new(0,32)}
	for i,a in points do line(parent,a,points[i%4+1],rgb(70,255,210),parent.ZIndex,3) end
end
return Art
