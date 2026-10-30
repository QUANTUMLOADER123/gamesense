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
local colorMeta={}
function colorMeta:ToHSV()
 local r,g,b=self.R,self.G,self.B
 local maxv,minv=math.max(r,g,b),math.min(r,g,b)
 local d=maxv-minv; local h=0
 if d>0 then
  if maxv==r then h=((g-b)/d)%6 elseif maxv==g then h=(b-r)/d+2 else h=(r-g)/d+4 end
  h=h/6
 end
 return h, maxv==0 and 0 or d/maxv, maxv
end
local function color(r,g,b) return setmetatable({R=r,G=g,B=b,_color=true},{__index=colorMeta}) end
Color3={fromRGB=function(r,g,b) return color(r/255,g/255,b/255) end,
 fromHSV=function(h,s,v)
  h=h%1; local i=math.floor(h*6); local f=h*6-i
  local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
  if i==0 then return color(v,t,p) elseif i==1 then return color(q,v,p) elseif i==2 then return color(p,v,t) elseif i==3 then return color(p,q,v) elseif i==4 then return color(t,p,v) else return color(v,p,q) end
 end}
NumberSequence={new=function(...) return {...} end}
ColorSequenceKeypoint={new=function(...) return {...} end}
ColorSequence={new=function(...) return {...} end}
UDim={new=function(s,o) return {Scale=s,Offset=o} end}
UDim2={new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
Vector2={new=function(x,y) return {X=x,Y=y} end}
math.clamp=function(x,a,b) return math.min(b,math.max(a,x)) end
warn=print
task={defer=function(fn) fn() end}
local all={}
Instance={new=function(class)
 local obj={ClassName=class, Name=class, children={}, AbsoluteSize={X=100,Y=100}, AbsoluteContentSize={X=100,Y=0}, AbsoluteCanvasSize={X=100,Y=100}, CanvasPosition={X=0,Y=0}, AbsolutePosition={X=0,Y=0}, propertySignals={},
 InputBegan=signal(), InputChanged=signal(), InputEnded=signal(), MouseButton1Click=signal(), MouseEnter=signal(), MouseLeave=signal(), FocusLost=signal(), Focused=signal()}
 function obj:IsA(name) return name=='GuiObject' and (self.ClassName=='Frame' or self.ClassName=='ScrollingFrame' or self.ClassName=='TextButton' or self.ClassName=='TextLabel' or self.ClassName=='TextBox' or self.ClassName=='ImageLabel') end
 function obj:Destroy() self.destroyed=true end
 function obj:CaptureFocus() self.focused=true end
 function obj:ReleaseFocus() self.focused=false end
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
local a=w:Tab('Visuals', {Icon='eye'}); local b=w:Tab('Misc', {Icon='settings'}); assert(not w.SubLayer.Visible)
assert(a.Button.Text == '' and a.Tint and #a.Button.children > 1)
local sub=a:Subtab('Players', {Icon='user'}); assert(not w.SubLayer.Visible and sub.Button.Text=='Players' and not sub.Tint)
local other=a:Subtab('World', {Icon='globe'}); assert(w.SubLayer.Visible)
local bsub=b:Subtab('General')
assert(sub.Page.Visible and not other.Page.Visible and not bsub.Page.Visible)
a:SelectSubtab(other); assert(other.Page.Visible and not sub.Page.Visible)
w:SelectTab(b); assert(bsub.Page.Visible and not other.Page.Visible and not w.SubLayer.Visible)
w:SelectTab(a); assert(other.Page.Visible and w.SubLayer.Visible)
local s=sub:Section('Player ESP','Left')
assert(w.Gui.Parent == coreGui and w.Gui.IgnoreGuiInset)
local pattern
for _,object in ipairs(w.Content.children) do if object.Name=='BackgroundPattern' then pattern=object end end
assert(pattern and pattern.Image=='rbxassetid://8547666218' and pattern.TileSize.X.Offset==8)
assert(w.Root.Size.X.Offset == 490 and w.Root.Size.Y.Offset == 420)
assert(w.Scale.Scale==1 and w.Root.BorderMode==Enum.BorderMode.Inset)
local customScale=Plague.new({Scale=1.2}); assert(customScale.Scale.Scale==1.2); customScale:Destroy()
local fixed=sub:Section('Fixed','Right',{Height=100})
assert(fixed.Container.Size.Y.Offset==100 and fixed.Frame.ClassName=='ScrollingFrame')
local padding
for _,child in ipairs(fixed.Frame.children) do if child.ClassName=='UIPadding' then padding=child end end
assert(padding and padding.PaddingRight.Offset==6)
local down
for _,o in ipairs(fixed.Container.children) do if o.Name=='ScrollDown' then down=o end end
assert(down and not down.Visible)
fixed.Frame.AbsoluteCanvasSize={X=100,Y=300}
fixed.Frame:GetPropertyChangedSignal('AbsoluteCanvasSize'):Fire()
assert(down.Visible); down.MouseButton1Click:Fire(); assert(fixed.Frame.CanvasPosition.Y==60)
fixed.Frame.CanvasPosition=Vector2.new(0,195); down.MouseButton1Click:Fire(); assert(fixed.Frame.CanvasPosition.Y==200)
fixed.Frame:GetPropertyChangedSignal('CanvasPosition'):Fire(); assert(not down.Visible)
local count=0
local toggleStart=#all
local toggle=s:Toggle({Name='Enabled',Flag='t',Default=true,Callback=function(v) count=count+1 end})
local toggleButton, checkbox
for i=toggleStart+1,#all do if all[i].ClassName=='TextButton' then toggleButton=all[i] elseif all[i].Size and all[i].Size.X.Offset==7 and all[i].Size.Y.Offset==7 then checkbox=all[i] end end
assert(toggleButton and checkbox and checkbox.children[1].Size.X.Offset==5 and checkbox.children[1].Size.Y.Offset==5)
assert(toggle:Get() and w.Flags.t); toggle:Set(false); assert(not toggle:Get() and count==1); toggle:Set(true,true); assert(count==1 and w.Flags.t)
local colorChanges=0
local colorToggle=s:Toggle({Name='Box',Color=Color3.fromRGB(1,2,3),ColorFlag='box_color',ColorAlphaFlag='box_alpha',ColorCallback=function() colorChanges=colorChanges+1 end})
local targetColor=Color3.fromRGB(100,20,10)
colorToggle:SetColor(targetColor,true); assert(math.floor(w.Flags.box_color.R*255+0.5)==100); assert(colorToggle:GetColor()==w.Flags.box_color)
local swatch
for _,o in ipairs(all) do if o.ClassName=='TextButton' and o.BackgroundColor3==targetColor then swatch=o end end
assert(swatch); local before=#all; swatch.MouseButton1Click:Fire(); assert(#all>before); assert(colorChanges==0)
assert(w.OpenPopup and w.OpenPopup.frame.Name=='ColorPopup' and w.OpenPopup.frame.Parent==w.PopupLayer)
local field,hue,alpha
for i=before+1,#all do if all[i].Name=='SaturationValue' then field=all[i] elseif all[i].Name=='Hue' then hue=all[i] elseif all[i].Name=='Alpha' then alpha=all[i] end end
assert(field and hue and alpha)
assert(field.Size.X.Offset==160 and field.Size.Y.Offset==160)
assert(hue.Size.X.Offset==12 and hue.Size.Y.Offset==160 and hue.Position.X.Offset==174)
assert(alpha.Size.X.Offset==160 and alpha.Size.Y.Offset==12 and alpha.Position.Y.Offset==174)
local copyButton, shield
for i=before+1,#all do if all[i].Name=='CopyColor' then copyButton=all[i] elseif all[i].Name=='PopupShield' then shield=all[i] end end
assert(copyButton and shield and copyButton.Size.X.Offset==12 and copyButton.Size.Y.Offset==12)
-- Even if a GuiButton underneath receives a click, a pointer pressed in the popup is captured.
local pointer={UserInputType=Enum.UserInputType.MouseButton1,Position={X=50,Y=50}}
input.InputBegan:Fire(pointer,false); assert(w.PopupCapturedInput==pointer)
local stateBefore=toggle:Get(); toggleButton.MouseButton1Click:Fire(); assert(toggle:Get()==stateBefore)
-- A click on release in the same event cycle must remain blocked as well.
local deferred={}; task.defer=function(fn) table.insert(deferred,fn) end
input.InputEnded:Fire(pointer); toggleButton.MouseButton1Click:Fire(); assert(toggle:Get()==stateBefore)
for _,fn in ipairs(deferred) do fn() end; task.defer=function(fn) fn() end
assert(not w.PopupCapturedInput)
local copied; setclipboard=function(v) copied=v end
copyButton.MouseButton1Click:Fire(); assert(copied=='#64140AFF'); setclipboard=nil
copyButton.MouseButton1Click:Fire()
local manual
for i=before+1,#all do if all[i].Name=='ManualCopy' then manual=all[i] end end
assert(manual and manual.Visible and manual.Text=='#64140AFF' and manual.focused)
manual.FocusLost:Fire(); assert(not manual.Visible)
field.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=75,Y=25}})
assert(colorChanges==1); input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
alpha.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=50,Y=0}})
assert(math.abs(colorToggle:GetAlpha()-0.5)<0.001 and w.Flags.box_alpha==0.5 and colorChanges==2)
input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position={X=80,Y=0}})
assert(math.abs(colorToggle:GetAlpha()-0.8)<0.001 and colorChanges==3)
input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
colorToggle:SetColor(Color3.fromRGB(101,20,10)); assert(colorChanges==4)
local countBeforeReopen=#all
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=1000,Y=1000}},false); assert(not w.OpenPopup)
swatch.MouseButton1Click:Fire(); assert(w.OpenPopup and #all==countBeforeReopen)
input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Escape},false); assert(not w.OpenPopup)
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
local opener, dropdownItems, dropdownPopup, second
for i=dropdownStart+1,#all do
 local o=all[i]
 if o.Name=='Icon_down' then opener=o.Parent end
 if o.Name=='DropdownItems' then dropdownItems=o elseif o.Name=='DropdownPopup' then dropdownPopup=o end
 if o.Text=='Second choice' then second=o.Parent end
end
assert(opener and dropdownItems and dropdownPopup and second and not dropdownPopup.Visible and dropdownPopup.Parent==w.PopupLayer and dropdownItems.Parent==dropdownPopup)
opener.MouseButton1Click:Fire(); assert(dropdownPopup.Visible)
assert(w.OpenPopup.anchor==opener)
local oldPosition=dropdownPopup.Position
opener:GetPropertyChangedSignal('AbsolutePosition'):Fire(); assert(dropdownPopup.Position~=oldPosition)
-- Opening a second popup closes the first, with neither inserted into the section.
colorToggle:SetAlpha(0.6, true); swatch.MouseButton1Click:Fire(); assert(not dropdownPopup.Visible and w.OpenPopup.frame.Name=='ColorPopup')
opener.MouseButton1Click:Fire(); assert(dropdownPopup.Visible and w.OpenPopup.anchor==opener)
local dropdownClick={UserInputType=Enum.UserInputType.MouseButton1,Position={X=25,Y=25}}
second.InputBegan:Fire(dropdownClick)
second.MouseButton1Click:Fire(); assert(not dropdownPopup.Visible and clickable:Get()=='Second choice' and w.Flags.clickable=='Second choice' and dropdownCallback==1)
local preserved=toggle:Get(); toggleButton.MouseButton1Click:Fire(); assert(toggle:Get()==preserved)
input.InputEnded:Fire(dropdownClick); assert(not w.PopupCapturedInput)
local start=#all; local listbox=s:Listbox({Flag='list',Options={'One','Two'},Default='One',Height=80})
assert(listbox:Get()=='One'); local two
for i=start+1,#all do if all[i].Text=='Two' then two=all[i].Parent end end
assert(two); two.MouseButton1Click:Fire(); assert(listbox:Get()=='Two' and w.Flags.list=='Two')
local color=s:ColorPicker({Flag='color',AlphaFlag='opacity',Default=Color3.fromRGB(1,2,3)}); color:Set(Color3.fromRGB(20,30,40)); assert(math.floor(w.Flags.color.R*255+0.5)==20)
color:SetAlpha(0.25); assert(color:GetAlpha()==0.25 and w.Flags.opacity==0.25)
color:Set(Color3.fromRGB(255,0,0),true)
local pickerStart=#all; color:Open(); assert(w.OpenPopup.frame.Name=='ColorPopup')
local sv,hueBar
for i=pickerStart+1,#all do if all[i].Name=='SaturationValue' then sv=all[i] elseif all[i].Name=='Hue' then hueBar=all[i] end end
assert(sv and hueBar)
sv.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=0,Y=0}})
assert(color:Get().R==1 and color:Get().G==1 and color:Get().B==1)
sv.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=100,Y=0}})
assert(color:Get().R==1 and color:Get().G==0 and color:Get().B==0)
sv.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=100,Y=100}})
assert(color:Get().R==0 and color:Get().G==0 and color:Get().B==0)
sv.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=100,Y=0}})
hueBar.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=0,Y=50}})
assert(color:Get().R==0 and color:Get().G==1 and color:Get().B==1)
input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1}); w:Toggle(false); assert(not w.OpenPopup); w:Toggle(true)
local text=s:Textbox({Flag='text',Default='abc'}); text:Set('xyz'); assert(w.Flags.text=='xyz')
local pressed=0; local key=s:Keybind({Name='Bind',Default=Enum.KeyCode.F,Flag='key',Callback=function() pressed=pressed+1 end})
input.InputBegan:Fire({KeyCode=Enum.KeyCode.F,UserInputType=Enum.UserInputType.Keyboard}, false); assert(pressed==1)
local keyButton
for _,o in ipairs(all) do if o.Text=='[F]' then keyButton=o end end
assert(keyButton and keyButton.Size.X.Offset==98); keyButton.MouseButton1Click:Fire(); input.InputBegan:Fire({KeyCode=Enum.KeyCode.Escape,UserInputType=Enum.UserInputType.Keyboard},false); assert(key:Get()==nil)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Insert,UserInputType=Enum.UserInputType.Keyboard},false); assert(not w.Visible)
w:Destroy(); assert(w.Gui.destroyed); assert(not input.InputBegan.handlers[1].connected)
print('mock smoke tests passed')
-- Exercise the actual published example against the Roblox mock.
function game:HttpGet(url) return url end
function loadstring(_) return function() return dofile('plague.lua') end end
dofile('plague_example.lua')
print('example smoke test passed')
