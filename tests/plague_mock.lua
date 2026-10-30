-- Run from the repository root with Lua 5.3+ or fengari-node-cli.
-- Roblox services and GUI objects below are mocks; this is not a visual test.
local function signal()
  local s = {handlers={}}
  function s:Connect(fn) local c={fn=fn, connected=true}; function c:Disconnect() self.connected=false end; table.insert(self.handlers,c); return c end
  function s:Fire(...) for _, c in ipairs(self.handlers) do if c.connected then c.fn(...) end end end
  return s
end
local function enumGroup(name)
 local group = {}
 setmetatable(group,{__index=function(t,k) local e={Name=k,EnumType=t,_enum=true}; rawset(t,k,e); return e end})
 return group
end
Enum=setmetatable({}, {__index=function(t,k) local v=enumGroup(k); rawset(t,k,v); return v end})
function typeof(v) if type(v)=='table' and v._enum then return 'EnumItem' end; if type(v)=='table' and v._color then return 'Color3' end; return type(v) end
Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255,_color=true} end}
UDim={new=function(s,o) return {Scale=s,Offset=o} end}
UDim2={new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
Vector2={new=function(x,y) return {X=x,Y=y} end}
math.clamp=function(x,a,b) return math.min(b,math.max(a,x)) end
warn=print
local all={}
Instance={new=function(class)
 local obj={ClassName=class, Name=class, children={}, AbsoluteSize={X=100,Y=100}, AbsoluteContentSize={X=100,Y=0}, AbsoluteCanvasSize={X=100,Y=100}, CanvasPosition={X=0,Y=0}, AbsolutePosition={X=0,Y=0}, propertySignals={},
 InputBegan=signal(), InputChanged=signal(), InputEnded=signal(), MouseButton1Click=signal(), MouseEnter=signal(), MouseLeave=signal(), FocusLost=signal()}
 function obj:IsA(name) return name=='GuiObject' and (self.ClassName=='Frame' or self.ClassName=='ScrollingFrame' or self.ClassName=='TextButton' or self.ClassName=='TextLabel' or self.ClassName=='TextBox') end
 function obj:Destroy() self.destroyed=true end
 function obj:GetPropertyChangedSignal(name) self.propertySignals[name]=self.propertySignals[name] or signal(); return self.propertySignals[name] end
 setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v); if k=='Parent' and v then table.insert(v.children,t) end end})
 table.insert(all,obj); return obj
end}
local playerGui={children={}}
local coreGui={children={}}
local input={InputBegan=signal(), InputChanged=signal(), InputEnded=signal(), GetFocusedTextBox=function() return nil end}
game={GetService=function(_,name) if name=='Players' then return {LocalPlayer={WaitForChild=function() return playerGui end}} elseif name=='UserInputService' then return input elseif name=='CoreGui' then return coreGui end end}
local Plague=dofile('plague.lua')
local w=Plague.new({})
local a=w:Tab('Visuals', {Icon='eye'}); local b=w:Tab('Misc', {Icon='settings'})
assert(a.Button.Text == '' and a.Tint and #a.Button.children > 1)
local sub=a:Subtab('Players', {Icon='user'}); local other=a:Subtab('World', {Icon='globe'}); local bsub=b:Subtab('General')
assert(sub.Page.Visible and not other.Page.Visible and not bsub.Page.Visible)
a:SelectSubtab(other); assert(other.Page.Visible and not sub.Page.Visible)
w:SelectTab(b); assert(bsub.Page.Visible and not other.Page.Visible)
w:SelectTab(a); assert(other.Page.Visible)
local s=sub:Section('Player ESP','Left')
assert(w.Gui.Parent == coreGui)
assert(w.Root.Size.X.Offset == 490 and w.Root.Size.Y.Offset == 420)
assert(w.Scale.Scale==0.73)
local fixed=sub:Section('Fixed','Right',{Height=100})
assert(fixed.Container.Size.Y.Offset==100 and fixed.Frame.ClassName=='ScrollingFrame')
local down
for _,o in ipairs(fixed.Container.children) do if o.Name=='ScrollDown' then down=o end end
assert(down and not down.Visible)
fixed.Frame.AbsoluteCanvasSize={X=100,Y=300}
fixed.Frame:GetPropertyChangedSignal('AbsoluteCanvasSize'):Fire()
assert(down.Visible); down.MouseButton1Click:Fire(); assert(fixed.Frame.CanvasPosition.Y==60)
fixed.Frame.CanvasPosition=Vector2.new(0,195); down.MouseButton1Click:Fire(); assert(fixed.Frame.CanvasPosition.Y==200)
fixed.Frame:GetPropertyChangedSignal('CanvasPosition'):Fire(); assert(not down.Visible)
local count=0
local toggle=s:Toggle({Name='Enabled',Flag='t',Default=true,Callback=function(v) count=count+1 end})
assert(toggle:Get() and w.Flags.t); toggle:Set(false); assert(not toggle:Get() and count==1); toggle:Set(true,true); assert(count==1 and w.Flags.t)
local colorChanges=0
local colorToggle=s:Toggle({Name='Box',Color=Color3.fromRGB(1,2,3),ColorFlag='box_color',ColorCallback=function() colorChanges=colorChanges+1 end})
local targetColor=Color3.fromRGB(100,20,10)
colorToggle:SetColor(targetColor,true); assert(math.floor(w.Flags.box_color.R*255+0.5)==100); assert(colorToggle:GetColor()==w.Flags.box_color)
local swatch
for _,o in ipairs(all) do if o.ClassName=='TextButton' and o.BackgroundColor3==targetColor then swatch=o end end
assert(swatch); local before=#all; swatch.MouseButton1Click:Fire(); assert(#all>before); assert(colorChanges==0)
colorToggle:SetColor(Color3.fromRGB(101,20,10)); assert(colorChanges==1)
local beforeSlider=#all
local slider=s:Slider({Flag='s',Min=-10,Max=10,Step=2,Default=3}); assert(slider:Get()==4)
local minus,plus
for i=beforeSlider+1,#all do local o=all[i]; if o.ClassName=='TextButton' and o.Text=='-' then minus=o elseif o.ClassName=='TextButton' and o.Text=='+' then plus=o end end
assert(minus and plus); minus.MouseButton1Click:Fire(); assert(slider:Get()==2); plus.MouseButton1Click:Fire(); assert(slider:Get()==4)
slider:Set(100); assert(w.Flags.s==10)
local multi=s:Dropdown({Flag='d',Multi=true,Options={'A','B','C'},Default={'A','C'}})
assert(table.concat(multi:Get())=='AC'); multi:Set({'B','X'}); assert(table.concat(w.Flags.d)=='B')
local drop=s:Dropdown({Options={'A','B'},Default='A'}); drop:Set('bad'); assert(drop:Get()==nil)
local dropdownStart=#all; local dropdownCallback=0
local clickable=s:Dropdown({Flag='clickable',Options={'First choice','Second choice'},Default='First choice',Callback=function() dropdownCallback=dropdownCallback+1 end})
local opener, dropdownItems, second
for i=dropdownStart+1,#all do
 local o=all[i]
 if o.Name=='Icon_down' then opener=o.Parent end
 if o.ClassName=='ScrollingFrame' then dropdownItems=o end
 if o.Text=='Second choice' then second=o.Parent end
end
assert(opener and dropdownItems and second and not dropdownItems.Visible)
opener.MouseButton1Click:Fire(); assert(dropdownItems.Visible)
second.MouseButton1Click:Fire(); assert(not dropdownItems.Visible and clickable:Get()=='Second choice' and w.Flags.clickable=='Second choice' and dropdownCallback==1)
local start=#all; local listbox=s:Listbox({Flag='list',Options={'One','Two'},Default='One',Height=80})
assert(listbox:Get()=='One'); local two
for i=start+1,#all do if all[i].Text=='Two' then two=all[i].Parent end end
assert(two); two.MouseButton1Click:Fire(); assert(listbox:Get()=='Two' and w.Flags.list=='Two')
local color=s:ColorPicker({Flag='color',Default=Color3.fromRGB(1,2,3)}); color:Set(Color3.fromRGB(20,30,40)); assert(math.floor(w.Flags.color.R*255+0.5)==20)
local text=s:Textbox({Flag='text',Default='abc'}); text:Set('xyz'); assert(w.Flags.text=='xyz')
local pressed=0; local key=s:Keybind({Name='Bind',Default=Enum.KeyCode.F,Flag='key',Callback=function() pressed=pressed+1 end})
input.InputBegan:Fire({KeyCode=Enum.KeyCode.F,UserInputType=Enum.UserInputType.Keyboard}, false); assert(pressed==1)
local keyButton
for _,o in ipairs(all) do if o.Text=='[F]' then keyButton=o end end
assert(keyButton); keyButton.MouseButton1Click:Fire(); input.InputBegan:Fire({KeyCode=Enum.KeyCode.Escape,UserInputType=Enum.UserInputType.Keyboard},false); assert(key:Get()==nil)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Insert,UserInputType=Enum.UserInputType.Keyboard},false); assert(not w.Visible)
w:Destroy(); assert(w.Gui.destroyed); assert(not input.InputBegan.handlers[1].connected)
print('mock smoke tests passed')
-- Exercise the actual published example against the Roblox mock.
function game:HttpGet(url) return url end
function loadstring(_) return function() return dofile('plague.lua') end end
dofile('plague_example.lua')
print('example smoke test passed')
