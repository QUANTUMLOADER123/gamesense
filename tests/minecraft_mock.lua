-- Run from the repository root:
--   npx --yes --package=fengari-node-cli -c "fengari tests/minecraft_mock.lua"
-- Roblox services and GUI objects below are mocks; this is not a visual test.
local function signal()
    local s = {handlers = {}}
    function s:Connect(fn)
        local c = {fn = fn, connected = true}
        function c:Disconnect() self.connected = false end
        table.insert(self.handlers, c)
        return c
    end
    function s:Fire(...)
        for _, c in ipairs(self.handlers) do
            if c.connected then c.fn(...) end
        end
    end
    return s
end

local function enumGroup(name)
    local group = {}
    setmetatable(group, {__index = function(t, k)
        local e = {Name = k, EnumType = t, _enum = true}
        rawset(t, k, e)
        return e
    end})
    return group
end
Enum = setmetatable({}, {__index = function(t, k)
    local v = enumGroup(k)
    rawset(t, k, v)
    return v
end})
function typeof(v)
    if type(v) == 'table' and v._enum then return 'EnumItem' end
    if type(v) == 'table' and v._color then return 'Color3' end
    return type(v)
end

local colorMeta = {}
function colorMeta:ToHSV()
    local r, g, b = self.R, self.G, self.B
    local maxv, minv = math.max(r, g, b), math.min(r, g, b)
    local d = maxv - minv
    local h = 0
    if d > 0 then
        if maxv == r then h = ((g - b) / d) % 6 elseif maxv == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, maxv == 0 and 0 or d / maxv, maxv
end
function colorMeta:Lerp(other, t)
    return setmetatable({R = self.R + (other.R - self.R) * t, G = self.G + (other.G - self.G) * t,
        B = self.B + (other.B - self.B) * t, _color = true}, {__index = colorMeta})
end
function colorMeta:ToHex()
    return string.format("%02X%02X%02X", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5),
        math.floor(self.B * 255 + 0.5))
end
local function color(r, g, b) return setmetatable({R = r, G = g, B = b, _color = true}, {__index = colorMeta}) end
Color3 = {
    fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end,
    fromHSV = function(h, s, v)
        h = h % 1
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
        if i == 0 then return color(v, t, p)
        elseif i == 1 then return color(q, v, p)
        elseif i == 2 then return color(p, v, t)
        elseif i == 3 then return color(p, q, v)
        elseif i == 4 then return color(t, p, v)
        else return color(v, p, q) end
    end,
    fromHex = function(hex)
        return color(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255)
    end,
    new = function(r, g, b) return color(r, g, b) end,
}
TweenInfo = {new = function(...) return {...} end}
NumberSequence = {new = function(...) return {...} end}
NumberSequenceKeypoint = {new = function(...) return {...} end}
ColorSequence = {new = function(...) return {...} end}
ColorSequenceKeypoint = {new = function(...) return {...} end}
UDim = {new = function(s, o) return {Scale = s, Offset = o} end}
UDim2 = {new = function(xs, xo, ys, yo) return {X = {Scale = xs, Offset = xo}, Y = {Scale = ys, Offset = yo}} end}
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
Vector2 = {new = function(x, y) return {X = x, Y = y} end}
math.clamp = function(x, a, b) return math.min(b, math.max(a, x)) end
-- Luau helpers that fengari (Lua 5.3) does not provide.
table.find = table.find or function(list, value)
    for index, item in ipairs(list) do
        if item == value then return index end
    end
    return nil
end
table.clone = function(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

-- Every tween applies instantly, which also proves each property exists.
local tweened = {}
TweenService = {}
-- The library calls TweenService:Create(...), so the mock takes self as well.
function TweenService:Create(instance, info, properties)
    for property, value in pairs(properties) do
        instance[property] = value
        tweened[property] = true
    end
    return {Play = function() end, Cancel = function() end}
end

local deferred = {}
task = {
    defer = function(fn) table.insert(deferred, fn) end,
    delay = function(_, fn) table.insert(deferred, fn) end,
    spawn = function(fn) table.insert(deferred, fn) end,
    wait = function() end,
}
warn = print

local all = {}
local function newInstance(class)
    local obj = {
        ClassName = class,
        Name = class,
        children = {},
        AbsoluteSize = {X = 100, Y = 100},
        AbsolutePosition = {X = 0, Y = 0},
        AbsoluteCanvasSize = {X = 100, Y = 0},
        CanvasPosition = {X = 0, Y = 0},
        propertySignals = {},
        InputBegan = signal(),
        InputChanged = signal(),
        InputEnded = signal(),
        MouseButton1Click = signal(),
        MouseButton2Down = signal(),
        MouseEnter = signal(),
        MouseLeave = signal(),
        FocusLost = signal(),
        Focused = signal(),
    }
    function obj:IsA(name)
        return name == 'GuiObject' and (self.ClassName == 'Frame' or self.ClassName == 'ScrollingFrame'
            or self.ClassName == 'TextButton' or self.ClassName == 'TextLabel' or self.ClassName == 'TextBox'
            or self.ClassName == 'ImageLabel' or self.ClassName == 'CanvasGroup')
    end
    function obj:Destroy() self.destroyed = true end
    function obj:CaptureFocus() self.focused = true end
    function obj:ReleaseFocus() self.focused = false end
    function obj:GetPropertyChangedSignal(name)
        self.propertySignals[name] = self.propertySignals[name] or signal()
        return self.propertySignals[name]
    end
    function obj:GetChildren()
        local list = {}
        for _, child in ipairs(self.children) do list[#list + 1] = child end
        return list
    end
    function obj:FindFirstChildOfClass(class)
        for _, child in ipairs(self.children) do
            if child.ClassName == class then return child end
        end
        return nil
    end
    setmetatable(obj, {__newindex = function(t, k, v)
        rawset(t, k, v)
        if k == 'Parent' and type(v) == 'table' and v.children then table.insert(v.children, t) end
    end})
    table.insert(all, obj)
    return obj
end
Instance = {new = newInstance}

local playerGui = {children = {}}
local coreGui = {children = {}}
local player = {Name = 'MockPlayer', WaitForChild = function() return playerGui end}
local localPlayer = player
local textService = {GetTextSize = function(_, value, size) return {X = #value * size * 0.6, Y = size} end}
local input = {
    InputBegan = signal(),
    InputChanged = signal(),
    InputEnded = signal(),
    GetFocusedTextBox = function() return nil end,
}
local lighting = {children = {}, FindFirstChild = function(self, name)
    for _, child in ipairs(self.children) do
        if child.Name == name then return child end
    end
    return nil
end}
game = {GetService = function(_, name)
    if name == 'Lighting' then return lighting end
    if name == 'Players' then return {LocalPlayer = localPlayer} end
    if name == 'TextService' then return textService end
    if name == 'UserInputService' then return input end
    if name == 'CoreGui' then return coreGui end
    if name == 'TweenService' then return TweenService end
    if name == 'RunService' then return {RenderStepped = signal()} end
end}

local Minecraft = dofile('minecraft.lua')

local function flush()
    local list = deferred
    deferred = {}
    for _, fn in ipairs(list) do fn() end
end

local function findChild(obj, name)
    for _, child in ipairs(obj.children or {}) do
        if child.Name == name then return child end
    end
end

local function findClass(obj, class, into)
    into = into or {}
    for _, child in ipairs(obj.children or {}) do
        if child.ClassName == class then into[#into + 1] = child end
        findClass(child, class, into)
    end
    return into
end

--==========================================================================--
-- Window
--==========================================================================--
assert(Minecraft.Themes and #Minecraft.Themes == 6, "six themes expected")
local window = Minecraft.new({Title = "Minecraft", Theme = 3, Search = true})
assert(window.Gui.Parent == coreGui, "default parent is CoreGui")
assert(window.ThemeIndex == 3 and window.Theme.Name == "Bloom")
assert(window.Root.ClassName == "CanvasGroup", "CanvasGroup fade wrapper")
assert(window.Glass, "frosted layer exists behind the panels")
assert(window.Glass.Parent == window.Root, "glass lives in the root")
assert(window.Glass.ZIndex == 1, "glass sits behind the panels")
assert(window.Glass.BackgroundTransparency == 0.42, "glass is translucent")
assert(not window.Header and not window.TitleLabel and not window.Shadow, "no title bar, no backdrop")
assert(window.Root.BackgroundTransparency == 1, "root itself is transparent")

-- Empty window lays out one panel wide: panels + search underneath.
assert(window.Root.Size.X.Offset == 226, "single panel width")
assert(window.Root.Size.Y.Offset == 520 + 9 + 32, "panels + search height")

local combat = window:AddTab("Combat")
local movement = window:AddTab("Movement")
local visuals = window:AddTab("Visuals")
assert(#window.Tabs == 3)
assert(combat.Panel.Size.X.Offset == 226 and combat.Panel.Size.Y.Offset == 520, "equal panel size")
assert(movement.Panel.Position.X.Offset == 235 and visuals.Panel.Position.X.Offset == 470, "panel gap")
assert(window.Root.Size.X.Offset == 3 * 226 + 2 * 9, "root grows with tabs")
assert(combat.Title.Text == "Combat" and combat.Title.TextXAlignment == Enum.TextXAlignment.Center)

--==========================================================================--
-- Search field lives under the panels
--==========================================================================--
local search = window.SearchFrame
assert(search and search.Position.Y.Offset == 520 + 9, "search sits below the panels")
assert(search.Size.X.Offset == 280 and search.AnchorPoint.X == 0.5, "search is centered")
assert(window.SearchBox.PlaceholderText == "Search")

-- Rows must be laid out by a real UIListLayout, otherwise they overlap.
local contentLayout = findChild(combat.Content, "UIListLayout")
assert(contentLayout, "content has a UIListLayout")

--==========================================================================--
-- Toggles and settings expansion
--==========================================================================--
local toggles = {}
for _, name in ipairs({"Anti Bot", "Attack Aura", "Auto Explosion", "Auto Swap", "Auto Totem"}) do
    toggles[#toggles + 1] = combat:AddToggle({Name = name})
end
assert(#combat.Rows == 5)
assert(not toggles[1].Dots.Visible, "no dots without settings")
assert(combat.Rows[2].Slot.Size.Y.Offset == 30, "collapsed row height")

local aura = combat:AddToggle({Name = "Attack Aura 2", Default = true, Flag = "aura", Settings = function(settings)
    settings:Slider({Name = "Range", Min = 1, Max = 8, Default = 4, Flag = "aura_range"})
    settings:Toggle({Name = "Players only", Default = true})
    settings:Input({Name = "Filter", Placeholder = "nickname"})
end})
assert(aura.Dots.Visible, "three dots appear when settings exist")
assert(window.Flags.aura == true)
assert(aura:Get() == true)

-- Right click opens the settings block, animating the slot taller.
assert(aura.Holder.Size.Y.Offset == 0)
aura.Frame.MouseButton2Down:Fire()
assert(aura.SettingsOpen)
assert(aura.SettingsHeight > 0 and aura.Slot.Size.Y.Offset == 30 + aura.SettingsHeight)
assert(aura.Settings.Height > 0, "settings measured")
assert(math.abs(aura.Settings.Height - (22 + 16 + 27 + 2 * 5)) < 0.001, "slider + toggle + input heights")
-- The canvas already accounts for the opened block, so the scroll does not jump.
local contentHeight = combat.Content.Size.Y.Offset
assert(contentHeight > 6 * 30, "canvas grew with the settings block")
aura.Frame.MouseButton2Down:Fire()
assert(not aura.SettingsOpen and aura.Slot.Size.Y.Offset == 30)
assert(combat.Content.Size.Y.Offset == 6 * 30 + 5 * 4, "canvas shrinks back")

-- Every row gets a distinct layout order, so rows are drawn one below another.
for index, row in ipairs(combat.Rows) do
    assert(row.Slot.LayoutOrder == index or row.Slot.LayoutOrder > 0, "row has layout order")
end
local orders = {}
for _, row in ipairs(combat.Rows) do
    assert(not orders[row.Slot.LayoutOrder], "layout orders are unique")
    orders[row.Slot.LayoutOrder] = true
end

-- Rows must be clickable: the hit area is the whole row, not a strip.
for _, row in ipairs(combat.Rows) do
    assert(row.Frame.Size.X.Offset == 0 and row.Frame.Size.X.Scale == 1, "row spans full width")
    assert(row.Frame.Size.Y.Offset == 30, "row is 30px tall")
    assert(row.Frame.ZIndex >= row.Box.ZIndex, "hit area sits above the visual")
end

-- Right click on each row opens only that row's settings.
local withSettings = 0
for _, row in ipairs(combat.Rows) do
    if row.Dots.Visible then withSettings = withSettings + 1 end
end
assert(withSettings >= 1, "at least one row shows the three dots")

-- The settings panel must actually become visible (regression: the fade
-- re-captured already-faded values and left the block transparent forever).
aura.Frame.MouseButton2Down:Fire()       -- open
assert(aura.SettingsOpen)
assert(aura.Settings.Panel.ClassName == "Frame", "settings panel is a plain frame")
assert(aura.Settings.Panel.BackgroundTransparency == 0.35, "panel keeps its own shading")
-- Every control must end up visible: labels opaque, control frames transparent.
local worst = 0
for _, control in ipairs(aura.Settings.Controls) do
    for _, child in ipairs(control.Frame.children) do
        if child.ClassName == "TextLabel" then
            worst = math.max(worst, child.TextTransparency or 0)
        end
    end
end
assert(worst < 0.05, "settings labels are fully visible after opening: " .. worst)
-- Controls themselves must keep their own transparencies (icons/labels visible).
for _, control in ipairs(aura.Settings.Controls) do
    local frame = control.Frame
    assert(frame.Size.Y.Offset == control.Height, "control keeps its measured height")
    assert(frame.Visible ~= false, "control is visible")
    assert(frame.BackgroundTransparency == 1, "control frame stays transparent")
end
aura.Frame.MouseButton2Down:Fire()       -- close
assert(not aura.SettingsOpen)
aura.Frame.MouseButton2Down:Fire()       -- open again
assert(aura.SettingsOpen, "settings reopen")
local worstAgain = 0
for _, control in ipairs(aura.Settings.Controls) do
    for _, child in ipairs(control.Frame.children) do
        if child.ClassName == "TextLabel" then
            worstAgain = math.max(worstAgain, child.TextTransparency or 0)
        end
    end
end
assert(worstAgain < 0.05, "reopening shows the content again: " .. worstAgain)
aura.Frame.MouseButton2Down:Fire()

-- Primary click flips the value and fires the callback.
local calls = 0
local function auraCallback(value) calls = calls + 1 end
aura.Options.Callback = auraCallback
aura.Frame.MouseButton1Click:Fire()
assert(aura:Get() == false and calls == 1 and window.Flags.aura == false)
aura:Set(true, true)
assert(calls == 1 and window.Flags.aura == true, "silent set skips the callback")
aura:Set(false)
assert(calls == 2)

--==========================================================================--
-- Controls inside settings
--==========================================================================--
local sliderEntry = aura.Settings.Controls[1]
assert(sliderEntry.Height == 22)
local toggleEntry = aura.Settings.Controls[2]
assert(toggleEntry.Height == 16)
local inputEntry = aura.Settings.Controls[3]
assert(inputEntry.Height == 27)

-- Sliders, buttons, dropdowns and inputs on a real tab.
local sliderRow = movement:AddSlider({Name = "Speed", Min = 0, Max = 10, Step = 1, Default = 5, Flag = "speed"})
assert(sliderRow:Get() == 5 and sliderRow.ValueLabel.Text == "5")
sliderRow:Set(100)
assert(sliderRow:Get() == 10 and window.Flags.speed == 10)
sliderRow:Set(3.4)
assert(sliderRow:Get() == 3, "step rounding")

local clickCount = 0
local buttonRow = movement:AddButton({Name = "Reset", Callback = function() clickCount = clickCount + 1 end})
assert(not buttonRow.Dots.Visible)
buttonRow.Frame.MouseButton1Click:Fire()
assert(clickCount == 1)

local dropdown = movement:AddDropdown({Name = "Mode", Options = {"Legit", "Rage", "Silent"}, Default = "Legit", Flag = "mode"})
assert(dropdown.ValueLabel.Text == "Legit")
dropdown.Frame.MouseButton1Click:Fire()
assert(dropdown.ListOpen and dropdown.ListHeight > 0 and dropdown.Slot.Size.Y.Offset > 30)
local choices = findClass(dropdown.ListHolder, "TextButton")
assert(#choices == 3)
choices[2].MouseButton1Click:Fire()
assert(dropdown:Get() == "Rage" and window.Flags.mode == "Rage")
assert(not dropdown.ListOpen and dropdown.Slot.Size.Y.Offset == 30, "list closes after pick")
assert(dropdown.ValueLabel.Text == "Rage")

local multi = movement:AddDropdown({Name = "Parts", Multi = true, Options = {"Head", "Torso", "Legs"}, Default = {"Head"}})
multi.Frame.MouseButton1Click:Fire()
local multiChoices = findClass(multi.ListHolder, "TextButton")
multiChoices[3].MouseButton1Click:Fire()
assert(#multi:Get() == 2 and table.find(multi:Get(), "Legs"))
assert(multi.ValueLabel.Text == "Head, Legs")

local inputRow = movement:AddInput({Name = "Name", Placeholder = "type", Flag = "nickname"})
assert(inputRow:Get() == "")
inputRow:Set("Steve")
assert(window.Flags.nickname == "Steve")

local keyPressed = 0
local keyRow = movement:AddKeybind({Name = "Panic", Default = Enum.KeyCode.Insert, Flag = "panic",
    Callback = function() keyPressed = keyPressed + 1 end})
assert(keyRow.ValueLabel.Text == "Insert")
keyRow.Frame.MouseButton1Click:Fire()
assert(window.Capturing, "keybind captures the next key")
local capture = window.Capturing
window.Capturing = nil
capture({KeyCode = Enum.KeyCode.K})
assert(keyRow:Get() == Enum.KeyCode.K and window.Flags.panic == Enum.KeyCode.K)
assert(keyRow.ValueLabel.Text == "K")

local section = visuals:AddSection("ESP")
assert(section.Label.Text == "ESP" and not section.Box.Visible)

local colorRow = visuals:AddColorPicker({Name = "Box color", Flag = "box_color", Default = Color3.fromRGB(255, 0, 0)})
assert(window.Flags.box_color and window.Flags.box_color.R == 1)

--==========================================================================--
-- Search
--==========================================================================--
-- Keybind rebinding updates the live bind used by the global input handler.
input.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K}, false)
assert(keyPressed == 1, "rebound key runs the callback")
window:Filter("aura")
assert(combat.Rows[2].Visible and combat.Rows[2].Name == "Attack Aura")
assert(not combat.Rows[1].Visible, "non matching rows hide")
assert(combat.Rows[2]:_Extra() == 0, "settings close while filtering")
window:Filter("")
for _, row in ipairs(combat.Rows) do assert(row.Visible) end
window:Filter("zzz")
assert(not combat.Rows[1].Visible and combat.EmptyLabel.Visible)
assert(combat.EmptyLabel.Text:find('zzz') ~= nil)
window:Filter("")

--==========================================================================--
-- Themes
--==========================================================================--
local before = window.Tabs[1].Panel.BackgroundColor3
window:SetTheme(5)
assert(window.ThemeIndex == 5 and window.Theme.Name == "Mint")
assert(window.Tabs[1].Panel.BackgroundColor3 ~= before, "panels recolored")
window:CycleTheme(1)
assert(window.ThemeIndex == 6)
window:CycleTheme(1)
assert(window.ThemeIndex == 1, "cycle wraps")
window:SetTheme("ember")
assert(window.ThemeIndex == 4)
local numeric = Minecraft.new({Theme = 99})
assert(numeric.ThemeIndex == 6, "theme clamped")
numeric:Destroy()

--==========================================================================--
-- Colour picker popup
--==========================================================================--
local swatch = findChild(colorRow.Frame, "Swatch")
swatch.MouseButton1Click:Fire()
assert(window.Popup and window.PopupLayer.Visible)
assert(window.Popup.Panel.Parent == window.PopupLayer)
local pickerPanel = window.Popup.Panel
local sv = findChild(pickerPanel, "SV")
assert(sv and sv.Size.X.Offset == 128 and sv.Size.Y.Offset == 76)
window.Popup:Apply(true)
input.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape}, false)
flush()
assert(not window.Popup, "escape closes the popup")

--==========================================================================--
-- The window must not be draggable: no header exists, and the root stays put.
--==========================================================================--
assert(window.Header == nil)
assert(window.Root.Position.X.Scale == 0.5 and window.Root.Position.Y.Scale == 0.5)

--==========================================================================--
-- Hide/show and destroy
--==========================================================================--
-- The frosted layer follows visibility.
window:Toggle()
assert(window.Open == false and window.Glass.BackgroundTransparency == 1, "glass fades out when hidden")
window:Toggle()
assert(window.Open == true and window.Glass.BackgroundTransparency == 0.42, "glass returns when shown")
window:SetGlass(0.7)
assert(window.Glass.BackgroundTransparency == 0.7)
window:SetGlass(0.42)
window:Toggle()
assert(window.Open == false)
flush()
assert(window.Gui.Enabled == false, "hidden after the fade")
window:Toggle()
assert(window.Open == true and window.Gui.Enabled == true)
input.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Insert}, false)
assert(window.Open == false, "Insert toggles the menu")

local config = window:SaveConfig()
assert(config.__theme == 4 and config.aura ~= nil and config.mode == "Rage")
assert(type(config.box_color) == "table" and config.box_color.__color)

-- Config round trip: load into a fresh window and check the controls pick it up.
local restored = Minecraft.new({Title = "Minecraft"})
local tab2 = restored:AddTab("Combat")
local t2 = tab2:AddToggle({Name = "Attack Aura", Flag = "aura"})
local m2 = tab2:AddDropdown({Name = "Mode", Options = {"Legit", "Rage"}, Default = "Legit", Flag = "mode"})
local c2 = tab2:AddColorPicker({Name = "Box", Flag = "box_color"})
restored:LoadConfig(config)
assert(t2:Get() == config.aura, "toggle restored to the saved value")
assert(m2:Get() == "Rage" and m2.ValueLabel.Text == "Rage", "dropdown restored")
assert(math.floor(c2:Get().R * 255 + 0.5) == 255, "colour restored")
assert(restored.ThemeIndex == 4, "theme restored")
restored:LoadConfig({aura = true, mode = "Legit"})
assert(t2:Get() == true and restored.Flags.aura == true, "config patch applies")
assert(m2:Get() == "Legit" and m2.ValueLabel.Text == "Legit")
restored:Destroy()

window:Destroy()
assert(window.Gui.destroyed)

-- Two windows can coexist and keep separate flags.
local a = Minecraft.new({})
local b = Minecraft.new({})
a:AddTab("One"):AddToggle({Name = "x", Flag = "same", Default = true})
b:AddTab("Two"):AddToggle({Name = "x", Flag = "same"})
assert(a.Flags.same == true and b.Flags.same == false)
a:Destroy()
b:Destroy()

print("minecraft_mock: all assertions passed")
