import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const {LuauState}=await import(pathToFileURL(path.resolve(process.argv[2])).href);
const runtime=await LuauState.createAsync({print:console.log});
const src=fs.readFileSync('src/client/ClubClient.client.luau','utf8');
let code=fs.readFileSync('tests/crowd-mocks.luau','utf8')+`
Enum.UserInputType={MouseButton1="left",MouseButton2="right",MouseButton3="middle",MouseMovement="move",MouseWheel="wheel"}
Enum.KeyCode={Escape="escape"}
local handlers={}
local function signal(name) return {Connect=function(_,fn) handlers[name]=fn end} end
local mouse=Vector2.new(100,100)
local UserInputService={InputBegan=signal("begin"),InputEnded=signal("end"),InputChanged=signal("move"),WindowFocusReleased=signal("blur"),GetMouseLocation=function() return mouse end,GetFocusedTextBox=function() return nil end}
local hud=false
local PlayerGui={GetGuiObjectsAtPosition=function() return if hud then {{ZIndex=90001,IsDescendantOf=function() return true end}} else {} end}
local Screen={}
local WorldCanvas={Position=UDim2.fromOffset(20,30)}
local WorldScale={Scale=1}
local isPanning,panMoved=false,false
local panButton=nil
local panDirection=Vector2.new(0,0)
local panStart=Vector2.new(0,0)
local canvasStart=WorldCanvas.Position
local CurrentMode="None"
local MovingItemUid=nil
local MIN_ZOOM,MAX_ZOOM,currentZoom=0.5,1.8,1
local function setMode(mode) CurrentMode=mode end
local function refreshHud() end
local function updateHoverCursor() end
`;
code+=src.slice(src.indexOf('UserInputService.InputEnded:Connect'),src.indexOf('-- Top Stats & Status HUD'));
code+=`
local function begin(kind) handlers.begin({UserInputType=kind},false) end
begin("left"); assert(isPanning,"left drag failed")
mouse=Vector2.new(160,70); handlers.move({UserInputType="move"})
assert(WorldCanvas.Position.X.Offset==80 and WorldCanvas.Position.Y.Offset==0,"two-axis dragging failed")
handlers["end"]({UserInputType="left"});assert(not isPanning,"left release failed")
hud=true;begin("right");assert(not isPanning,"HUD started pan")
hud=false;CurrentMode="Build";begin("left");assert(not isPanning,"build click started pan")
begin("right");assert(isPanning,"right drag failed during build")
handlers["end"]({UserInputType="right"});assert(CurrentMode=="None","right click failed to cancel edit")
begin("middle");assert(isPanning);handlers.blur();assert(not isPanning and panButton==nil,"focus-loss did not stop drag")
print("PASS production mouse handlers: left/right/middle pan, XY movement, release, HUD exclusion, build clicks, cancel, focus loss")
`;
try {await runtime.loadstring(code,'pan.spec',true)();} finally {runtime.destroy();}
