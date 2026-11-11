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
-- Vector3 with the arithmetic the acrylic code relies on (+, -, *, /, Magnitude).
local vmeta = {
    __add = function(a, b) return vec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
    __sub = function(a, b) return vec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
    __mul = function(a, k) return vec3(a.X * k, a.Y * k, a.Z * k) end,
    __div = function(a, k) return vec3(a.X / k, a.Y / k, a.Z / k) end,
}
function vec3(x, y, z)
    return setmetatable({X = x, Y = y, Z = z}, vmeta)
end
function vmeta.__index(t, k)
    if k == 'Magnitude' then
        return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
    end
    return nil
end
Vector3 = {new = function(x, y, z) return vec3(x, y, z) end}

CFrame = {}
function CFrame.new(x, y, z)
    return setmetatable({X = x, Y = y, Z = z, XVector = vec3(1, 0, 0), YVector = vec3(0, 1, 0),
        ZVector = vec3(0, 0, -1)}, {})
end
function CFrame.fromMatrix(position, xv, yv, zv)
    return setmetatable({Position = position, XVector = xv, YVector = yv, ZVector = zv}, {})
end
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

-- Camera + workspace: the acrylic sheets are built from ScreenPointToRay.
local cameraSignals = {}
local camera = {
    ClassName = 'Camera',
    ViewportSize = {X = 1280, Y = 720},
    CFrame = CFrame.new(0, 0, 0),
    FieldOfView = 70,
}
function camera:GetPropertyChangedSignal(name)
    cameraSignals[name] = cameraSignals[name] or signal()
    return cameraSignals[name]
end
function camera:FindFirstChild(name)
    for _, child in ipairs(self.children or {}) do
        if child.Name == name then return child end
    end
    return nil
end
-- A simple perspective projection: 1 unit in front of the camera spans
-- viewportPixels / (2 * tan(fov/2)) world units, which is what the real camera
-- does and what makes the acrylic size assertions meaningful.
function camera:ScreenPointToRay(x, y)
    local depth = 1
    local halfHeight = math.tan(math.rad(self.FieldOfView) / 2) * depth
    local perPixel = (halfHeight * 2) / self.ViewportSize.Y
    local origin = vec3(0, 0, 0)
    local direction = vec3((x - self.ViewportSize.X / 2) * perPixel, -(y - self.ViewportSize.Y / 2) * perPixel, -depth)
    return {Origin = origin, Direction = direction}
end
local cameraFolder = {children = {}, Name = 'CameraFolder'}
function cameraFolder:FindFirstChild(name)
    for _, child in ipairs(self.children) do
        if child.Name == name then return child end
    end
    return nil
end
workspace = {CurrentCamera = camera}
Minecraft = nil

-- Glass refraction is a high-quality feature; pretend this client can render it.
settings = function()
    return {Rendering = {QualityLevel = 10}}
end
UserSettings = function()
    return {GetService = function()
        return {SavedQualityLevel = {Value = 10}}
    end}
end

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
assert(window.Glass == nil, "no glass plate behind the window any more")
-- Default mode blurs the whole screen.
assert(window.BlurMode == "screen", "screen blur mode by default")
assert(window.BlurEffect and window.BlurEffect.ClassName == "BlurEffect")
assert(window.Dim and window.Dim.Size.X.Scale == 1 and window.Dim.Size.Y.Scale == 1,
    "full-screen dim layer")
assert(window.Dim.Parent == window.Gui and window.Dim.ZIndex < window.Root.ZIndex,
    "dim sits under the menu")

--==========================================================================--
-- Acrylic backdrop (Fluent-style glass sheet in front of the camera)
--==========================================================================--
assert(window.AcrylicSupported == true, "high quality client supports acrylic")
assert(window.AcrylicEnabled == true, "acrylic is on by default on capable clients")
assert(window.BodyAcrylic and window.SearchAcrylic, "glass sheets for panels and search")
assert(window.BodyAcrylic.Enabled ~= false)
local glass = window.BodyAcrylic.Model
assert(glass.ClassName == "Part", "acrylic is a real 3D part")
assert(glass.Material == Enum.Material.Glass, "glass material does the frosting")
assert(glass.Anchored == true and glass.CanCollide == false and glass.CastShadow == false,
    "the sheet never moves, collides or shadows")
assert(glass.CanTouch == false and glass.CanQuery == false and glass.Massless == true,
    "the sheet is invisible to physics and raycasts")
assert(glass.Size.X == 1 and glass.Size.Y == 1 and glass.Size.Z == 0, "flat unit plate scaled by the mesh")
assert(glass.Size.Z == 0, "zero thickness, like Fluent")
local mesh = findChild(glass, "SpecialMesh")
assert(mesh and mesh.MeshType == Enum.MeshType.Brick, "brick special mesh stretches the plate")
assert(mesh.Offset.Z < 0 and mesh.Offset.Z > -0.001, "mesh offset pushes it off the camera")
assert(glass.Parent and glass.Parent.Parent == camera, "sheet lives under the camera")
assert(glass.Parent.Name == "MinecraftUIAcrylic", "sheets live in a named folder")
onAcrylic = nil

-- Hidden until shown: the intro should not flash a black rectangle.
assert(glass.Transparency == 1, "sheet starts invisible")
window:Toggle(true)
flush()
assert(glass.Transparency == 0.98, "sheet fades in with the menu")
assert(window.BodyAcrylic.Model.CFrame and window.BodyAcrylic.Model.CFrame.Position, "sheet is positioned in space")

-- The mesh is scaled to the on-screen size of the panel cluster.
local function approx(a, b, tolerance)
    return math.abs(a - b) <= (tolerance or 0.001)
end
-- Projected size of the panel rectangle at the sheet's distance (0.001).
local perPixel = (math.tan(math.rad(camera.FieldOfView) / 2) * 2) / camera.ViewportSize.Y
local expectedHeight = (window.Body.AbsoluteSize.Y - 4) * perPixel * 0.001
assert(approx(mesh.Scale.Y, expectedHeight, expectedHeight * 0.01),
    "sheet height follows the panel rectangle: " .. tostring(mesh.Scale.Y) .. " vs " .. tostring(expectedHeight))
assert(mesh.Scale.X > 0 and mesh.Scale.Y > 0, "sheet has real dimensions")
assert(mesh.Scale.Z == 0, "sheet stays flat")

-- Camera movement re-fits every sheet (otherwise the glass drifts off the UI).
cameraSignals["CFrame"]:Fire()
cameraSignals["ViewportSize"]:Fire()
cameraSignals["FieldOfView"]:Fire()

-- Hiding the menu hides the glass and destroys nothing mid-animation.
window:Toggle(false)
assert(glass.Transparency == 1, "sheet disappears with the menu")
window:Toggle(true)
flush()
assert(glass.Transparency == 0.98, "sheet returns")

-- Disabling acrylic removes the parts entirely.
window:SetAcrylic("off")
assert(window.AcrylicEnabled == false and window.Acrylics and #window.Acrylics > 0)
assert(window.BodyAcrylic == nil and window.SearchAcrylic == nil, "sheets are detached")
window:SetAcrylic("on")
flush()
assert(window.BodyAcrylic and window.BodyAcrylic.Model.Transparency == 0.98, "acrylic can be re-enabled")
assert(window.AcrylicTint == nil, "no dark plate is laid behind the panels")

-- Sheets of one window share a single folder under the camera.
assert(window.AcrylicFolder and window.AcrylicFolder.Name == "MinecraftUIAcrylic", "one folder per window")
assert(window.BodyAcrylic.Folder == window.AcrylicFolder, "body sheet uses that folder")
assert(window.SearchAcrylic.Folder == window.AcrylicFolder, "search sheet uses that folder")

-- A late camera is picked up by the bounded retry instead of leaving the menu
-- without glass for the whole session.
local savedCamera = workspace.CurrentCamera
workspace.CurrentCamera = nil
local lateWindow = Minecraft.new({})
assert(lateWindow.BodyAcrylic == nil, "no camera yet, no sheet")
workspace.CurrentCamera = savedCamera
flush()
assert(lateWindow.BodyAcrylic, "retry attaches the sheet once the camera exists")
assert(lateWindow.BodyAcrylic.Model.Transparency == 0.98, "and it is visible")
lateWindow:Destroy()

-- Acrylic can be switched off explicitly.
local lowQuality = Minecraft.new({Acrylic = "off"})
assert(lowQuality.AcrylicEnabled == false and lowQuality.BodyAcrylic == nil, "acrylic can be disabled")
assert(lowQuality.SearchAcrylic == nil and lowQuality.AcrylicTint == nil, "no glass sheets, no plate")
lowQuality:Destroy()

-- ...and a client that cannot render glass skips it even on "auto".
local savedQuality = settings
settings = function()
    return {Rendering = {QualityLevel = 5}}
end
assert(Minecraft.Acrylic.Supported() == false, "quality below 8 is not supported")
local weakClient = Minecraft.new({})
assert(weakClient.AcrylicSupported == false and weakClient.AcrylicEnabled == false,
    "auto never forces glass on weak clients")
assert(weakClient.BodyAcrylic == nil and #weakClient.Acrylics == 0, "nothing is created")
weakClient:Toggle(false)
weakClient:Toggle(true)
weakClient:Destroy()
settings = savedQuality

-- Local mode keeps the game sharp and only dims behind the panels.
local localWindow = Minecraft.new({BlurMode = "local"})
assert(localWindow.BlurMode == "local" and localWindow.BlurEffect == nil, "no full-screen blur locally")
assert(localWindow.Dim and localWindow.Dim.Name == "LocalDim", "local plate exists")
assert(localWindow.DimHalo and localWindow.DimHalo.Name == "LocalDimHalo", "local halo exists")
assert(localWindow.Dim.Parent == localWindow.Root and localWindow.Dim.ZIndex == 0,
    "local scrim sits behind the panels")
assert(localWindow.Dim.BackgroundTransparency ~= localWindow.DimHalo.BackgroundTransparency,
    "halo and plate use different opacities")
localWindow:Toggle(false)
assert(localWindow.Dim.BackgroundTransparency == 1 and localWindow.DimHalo.BackgroundTransparency == 1,
    "both local layers fade out when hidden")
localWindow:Toggle(true)
assert(localWindow.Dim.BackgroundTransparency == localWindow.DimValue, "plate returns with the menu")
localWindow:Destroy()
assert(not window.Header and not window.TitleLabel and not window.Shadow, "no title bar, no backdrop")
assert(window.Root.BackgroundTransparency == 1, "root itself is transparent")

-- Empty window lays out one panel wide: panels + search underneath.
assert(window.Root.Size.X.Offset == 236, "single panel width")
assert(window.Root.Size.Y.Offset == 536 + 10 + 34, "panels + search height")

local combat = window:AddTab("Combat")
local movement = window:AddTab("Movement")
local visuals = window:AddTab("Visuals")
assert(#window.Tabs == 3)
assert(combat.Panel.Size.X.Offset == 236 and combat.Panel.Size.Y.Offset == 536, "equal panel size")
assert(movement.Panel.Position.X.Offset == 246 and visuals.Panel.Position.X.Offset == 492, "panel gap")
assert(window.Root.Size.X.Offset == 3 * 236 + 2 * 10, "root grows with tabs")
assert(combat.Title.Text == "Combat" and combat.Title.TextXAlignment == Enum.TextXAlignment.Center)

--==========================================================================--
-- Search field lives under the panels
--==========================================================================--
local search = window.SearchFrame
assert(search and search.Position.Y.Offset == 536 + 10, "search sits below the panels")
assert(search.Size.X.Offset == 300 and search.AnchorPoint.X == 0.5, "search is centered")
assert(window.SearchBox.PlaceholderText == "Search")

-- Rows must be laid out by a real UIListLayout, otherwise they overlap.
local contentLayout = findChild(combat.Content, "UIListLayout")
assert(contentLayout, "content has a UIListLayout")

--==========================================================================--
-- Spacing / polish: shared metrics, pixel icons, slider knob
--==========================================================================--
assert(Minecraft.Metrics.Inset == 12 and Minecraft.Metrics.RowGap == 5, "roomier metrics")
assert(Minecraft.Metrics.BlockPadding == 9 and Minecraft.Metrics.BlockGap == 7, "settings rhythm")
assert(Minecraft.Radius.Panel == 11 and Minecraft.Radius.Row == 8, "rounder corners")
local scrollPad = findChild(combat.Scroll, "UIPadding")
assert(scrollPad and scrollPad.PaddingTop.Offset == 14 and scrollPad.PaddingLeft.Offset == 12,
    "scroll padding uses the metrics")
assert(scrollPad.PaddingRight.Offset >= 14, "right padding keeps rows clear of the scrollbar")

-- The search bar has a pixel magnifier and grows when it is focused.
assert(window.SearchIcon and window.SearchIconPixels and #window.SearchIconPixels > 8,
    "pixel search icon exists")
local focusBefore = window.SearchFrame.BackgroundTransparency
window.SearchBox.Focused:Fire()
assert(window.SearchFocused == true, "focus is tracked")
assert(window.SearchFrame.BackgroundTransparency < focusBefore, "focused search bar lifts")
window.SearchBox.FocusLost:Fire()
assert(window.SearchFrame.BackgroundTransparency == 0.32, "blur returns the resting opacity")

-- Faded scrollbar uses the accent colour, not a grey line.
assert(combat.Scroll.ScrollBarImageColor3 == window.Theme.Accent, "accent scrollbar")

-- The panel header uses a short accent pill instead of a full-width rule.
-- It animates in, so flush the deferred intro tweens first.
flush()
assert(combat.TitleLine.Size.X.Offset == 26 and combat.TitleLine.Size.Y.Offset == 2, "header pill")
assert(combat.TitleLine.Position.X.Scale == 0.5 and combat.TitleLine.AnchorPoint.X == 0.5,
    "header pill is centred")
assert(combat.TopShine == nil and combat.Sheen == nil, "no edge highlight line that reads as an outline")

--==========================================================================--
-- Toggles and settings expansion
--==========================================================================--
local toggles = {}
for _, name in ipairs({"Anti Bot", "Attack Aura", "Auto Explosion", "Auto Swap", "Auto Totem"}) do
    toggles[#toggles + 1] = combat:AddToggle({Name = name})
end
assert(#combat.Rows == 5)
assert(not toggles[1].Dots.Visible, "no dots without settings")
assert(combat.Rows[2].Slot.Size.Y.Offset == 32, "collapsed row height")

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
assert(aura.SettingsHeight > 0 and aura.Slot.Size.Y.Offset == 32 + aura.SettingsHeight)
assert(aura.Settings.Height > 0, "settings measured")
assert(math.abs(aura.Settings.Height - (22 + 16 + 27 + 2 * 7)) < 0.001, "slider + toggle + input heights")
-- The canvas already accounts for the opened block, so the scroll does not jump.
local contentHeight = combat.Content.Size.Y.Offset
assert(contentHeight > 6 * 32, "canvas grew with the settings block")
aura.Frame.MouseButton2Down:Fire()
assert(not aura.SettingsOpen and aura.Slot.Size.Y.Offset == 32)
assert(combat.Content.Size.Y.Offset == 6 * 32 + 5 * 5, "canvas shrinks back")

-- Every row gets a distinct layout order, so rows are drawn one below another.
for index, row in ipairs(combat.Rows) do
    assert(row.Slot.LayoutOrder == index or row.Slot.LayoutOrder > 0, "row has layout order")
end
local orders = {}
for _, row in ipairs(combat.Rows) do
    assert(not orders[row.Slot.LayoutOrder], "layout orders are unique")
    orders[row.Slot.LayoutOrder] = true
end

-- The settings checkbox must draw a real tick, not a filled square.
local tickRow = combat:AddToggle({Name = "Tick test", Settings = function(st)
    st:Toggle({Name = "Inner", Default = true})
end})
tickRow.Frame.MouseButton2Down:Fire()
local innerToggle = tickRow.Settings.Controls[1]
local tickBox = findChild(innerToggle.Frame, "Box")
assert(tickBox, "checkbox exists")
local tickMark = findChild(tickBox, "Mark")
assert(tickMark, "check mark container exists")
-- The tick is a pixel glyph: several row runs, short left arm and long right arm.
local tickPixels = {}
for _, child in ipairs(tickMark.children) do
    if child.Name == "Tick" then tickPixels[#tickPixels + 1] = child end
end
assert(#tickPixels > 5, "tick is drawn from pixel runs")
-- Glyph is 10 wide; height comes from the pattern (#TICK rows).
assert(tickMark.Size.X.Offset == 11 and tickMark.Size.Y.Offset == 8, "tick canvas matches the glyph")
assert(tickMark.Visible == true and tickMark.ClipsDescendants == true, "tick is clipped so it can vanish")
-- The left (short) arm must be smaller than the right (long) arm.
local leftMax, rightMax = 0, 0
for _, pixel in ipairs(tickPixels) do
    local width = pixel.Size.X.Offset
    if pixel.Position.X.Offset < 5 then
        leftMax = math.max(leftMax, pixel.Position.Y.Offset)
    else
        rightMax = math.max(rightMax, pixel.Position.Y.Offset)
    end
end
assert(leftMax > 0 and rightMax < leftMax, "left arm is short, right arm reaches higher")
-- Switching the inner toggle off must hide the tick completely.
local innerApi
for _, control in ipairs(tickRow.Settings.Controls) do
    if control.Frame.Name == "SettingToggle" then innerApi = control.Api end
end
local innerHit
for _, child in ipairs(innerToggle.Frame.children) do
    if child.ClassName == "TextButton" then innerHit = child end
end
assert(innerHit, "checkbox hit area exists")
innerHit.MouseButton1Click:Fire()
assert(tickMark.Visible == false and tickMark.Size.X.Offset == 0, "tick disappears when switched off")
tickRow.Frame.MouseButton2Down:Fire()

-- Enabled rows show a small accent bar on their left edge (a fill, not an outline).
local markerRow = combat:AddToggle({Name = "Marker check"})
assert(markerRow.Marker, "rows have an accent marker")
assert(markerRow.Marker.BackgroundTransparency == 1, "marker hidden while off")
markerRow.Frame.MouseButton1Click:Fire()
assert(markerRow.Marker.BackgroundTransparency == 0, "marker appears when enabled")
assert(markerRow.Marker.BackgroundColor3 == window.Theme.Accent, "marker is accent coloured")
assert(markerRow.Marker.Size.X.Offset == 3 and markerRow.Marker.AnchorPoint.X == 0,
    "marker hugs the left edge")
markerRow.Frame.MouseButton1Click:Fire()
assert(markerRow.Marker.BackgroundTransparency == 1, "marker disappears when disabled")

-- Every row plate carries a soft top-to-bottom shade that follows its fill.
local shaded = combat:AddToggle({Name = "Shade check"})
assert(shaded.BoxShade and shaded.BoxShade.ClassName == "UIGradient", "row plate has shading")
local shadeOff = shaded.BoxShade.Color
shaded.Frame.MouseButton1Click:Fire()
assert(shaded.BoxShade.Color ~= shadeOff, "shading follows the enabled fill")
shaded.Frame.MouseButton1Click:Fire()

-- Hover must not repaint an enabled row and leaving must restore it exactly.
local hoverRow = combat:AddToggle({Name = "Hover check", Default = true})
local enabledFill = hoverRow.Box.BackgroundColor3
local enabledAlpha = hoverRow.Box.BackgroundTransparency
hoverRow.Frame.MouseEnter:Fire()
assert(hoverRow.Hovered, "hover registered")
assert(hoverRow.Box.BackgroundTransparency ~= enabledAlpha, "hover lightens the row")
hoverRow.Frame.MouseLeave:Fire()
assert(hoverRow.Box.BackgroundColor3 == enabledFill, "fill returns to the enabled colour")
assert(hoverRow.Box.BackgroundTransparency == enabledAlpha, "alpha returns too")

-- There must be no outlines anywhere in the UI.
for _, object in ipairs(all) do
    assert(object.ClassName ~= "UIStroke", "no UIStroke instances are created")
end

-- Rows must not carry stray glow frames: they clipped against the slot and
-- produced a bright outline that lit up on hover.
for _, row in ipairs(combat.Rows) do
    assert(row.Glow == nil and row.GlowStroke == nil, "no glow frames on rows")
    for _, child in ipairs(row.Slot.children) do
        assert(child.Name ~= "Glow", "slot has no glow child")
    end
end

-- Let the staggered unfurl finish before checking the resting geometry.
flush()

-- Rows must be clickable: the hit area is the whole row, not a strip.
for _, row in ipairs(combat.Rows) do
    assert(row.Frame.Size.X.Offset == 0 and row.Frame.Size.X.Scale == 1, "row spans full width")
    assert(row.Frame.Size.Y.Offset == 32, "row is 32px tall")
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
assert(not dropdown.ListOpen and dropdown.Slot.Size.Y.Offset == 32, "list closes after pick")
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

-- Sliders inside settings carry a round knob that tracks the fill.
local knobRow = movement:AddToggle({Name = "Knob test", Settings = function(st)
    st:Slider({Name = "Fov", Min = 0, Max = 100, Default = 25})
end})
knobRow.Frame.MouseButton2Down:Fire()
local knobGroup = knobRow.Settings.Controls[1].Frame
local rail = findChild(knobGroup, "Track")
assert(rail and rail.Size.Y.Offset == 6, "fat slider rail")
local fill = findChild(rail, "Fill")
local knob = findChild(rail, "Knob")
assert(fill and knob, "fill and knob exist")
assert(knob.Position.X.Scale == 0.25 and knob.AnchorPoint.X == 0.5, "knob sits at the value")
assert(knob.Size.X.Offset == 9 and knob.Size.Y.Offset == 9, "knob is a 9px dot")
-- Dragging grows the knob and releasing deflates it.
local sliderHit
for _, child in ipairs(knobGroup.children) do
    if child.Name == "Hit" then sliderHit = child end
end
assert(sliderHit, "slider hit area exists")
sliderHit.InputBegan:Fire({UserInputType = Enum.UserInputType.MouseButton1, Position = {X = 40, Y = 8}})
assert(knob.Size.X.Offset == 13, "knob grows while dragging")
assert(rail.Size.Y.Offset == 7, "rail thickens while dragging")
input.InputEnded:Fire({UserInputType = Enum.UserInputType.MouseButton1, Position = {X = 40, Y = 8}})
assert(knob.Size.X.Offset == 9 and rail.Size.Y.Offset == 6, "knob and rail settle back")
knobRow.Frame.MouseButton2Down:Fire()

-- Dropdowns inside settings use a real chevron that rotates when opened.
local chevronRow = movement:AddToggle({Name = "Chevron", Settings = function(st)
    st:Dropdown({Name = "Mode", Options = {"A", "B"}})
end})
chevronRow.Frame.MouseButton2Down:Fire()
local chevronFrame = chevronRow.Settings.Controls[1].Frame
local header = findChild(chevronFrame, "Header")
assert(header, "dropdown header exists")
local arrow = findChild(header, "Arrow")
assert(arrow, "dropdown has a pixel chevron")
local chevronPixels = findClass(arrow, "Frame")
assert(#chevronPixels >= 6, "chevron is drawn from pixels")
header.MouseButton1Click:Fire()
assert(arrow.Rotation == 180, "chevron flips when open")
header.MouseButton1Click:Fire()
assert(arrow.Rotation == 0, "chevron returns when closed")
chevronRow.Frame.MouseButton2Down:Fire()

-- Buttons inside settings dip their label on click.
local buttonRow2 = movement:AddToggle({Name = "Button test", Settings = function(st)
    st:Button({Name = "Apply"})
end})
buttonRow2.Frame.MouseButton2Down:Fire()
local innerButton = findChild(buttonRow2.Settings.Controls[1].Frame, "Button")
assert(innerButton, "inner button exists")
innerButton.MouseButton1Click:Fire()
buttonRow2.Frame.MouseButton2Down:Fire()

local section = visuals:AddSection("ESP")
assert(section.Label.Text == "ESP" and not section.Box.Visible)
assert(section.HideMarker and not section.Marker.Visible, "sections hide the accent marker")
local plainLabel = visuals:AddLabel("just text")
assert(plainLabel.HideMarker, "labels hide the accent marker")

local colorRow = visuals:AddColorPicker({Name = "Box color", Flag = "box_color", Default = Color3.fromRGB(255, 0, 0)})
assert(window.Flags.box_color and window.Flags.box_color.R == 1)
-- Colour rows expose alpha and paint it onto their swatch.
local alphaPicker = visuals:AddColorPicker({Name = "Tracer", Flag = "tracer_color",
    AlphaFlag = "tracer_alpha", DefaultAlpha = 0.5})
assert(alphaPicker:GetAlpha() == 0.5 and window.Flags.tracer_alpha == 0.5)
alphaPicker:SetAlpha(0.25)
assert(window.Flags.tracer_alpha == 0.25)
local tracerSwatch = findChild(alphaPicker.Frame, "Swatch")
assert(tracerSwatch.BackgroundTransparency == 0.75, "swatch shows the alpha")

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
assert(combat.EmptyMark and combat.EmptyMark.Visible, "empty state shows its accent tick")
assert(combat.EmptyMark.BackgroundColor3 == window.Theme.Accent, "tick is accent coloured")
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
assert(sv and sv.Size.X.Offset == 180 and sv.Size.Y.Offset == 104, "SV field is 180x104")
assert(pickerPanel.Size.X.Offset == 196, "popup is 196 wide")
-- The SV field must be built from a white left->right ramp plus a black
-- bottom->top ramp, so the top-right corner stays pure white.
-- The field is painted as solid-colour cells (transparency gradients are
-- unreliable), so it must contain a real grid with many distinct colours.
local fieldCells = 0
local distinct = {}
for _, child in ipairs(sv.children) do
    if child.Name == "Cell" then
        fieldCells = fieldCells + 1
        local c = child.BackgroundColor3
        distinct[string.format("%.2f_%.2f_%.2f", c.R, c.G, c.B)] = true
    end
end
assert(fieldCells == 260, "field is a 20x13 grid: " .. fieldCells)
local colorCount = 0
for _ in pairs(distinct) do colorCount = colorCount + 1 end
assert(colorCount > 40, "field shows a real gradient: " .. colorCount .. " distinct colours")
assert(findChild(pickerPanel, "AlphaBar"), "alpha bar exists")
assert(findChild(pickerPanel, "Hue"), "hue strip exists")
-- The popup must be positioned inside the menu, not at some random offset.
local popupPos = pickerPanel.Position
assert(popupPos and popupPos.X and popupPos.Y, "popup has a concrete position")
assert(popupPos.X.Offset >= -1 and popupPos.Y.Offset >= -1, "popup is not placed off-screen")
assert(window.PopupLayer.ZIndex > window.Tabs[1].Panel.ZIndex, "popup renders above panels")
assert(findChild(pickerPanel, "Hex"), "popup has a hex readout")
-- Alpha travels with the colour: setting it updates the swatch transparency
-- and the stored flag.
local popup = window.Popup
assert(popup.AlphaEnabled, "alpha bar is enabled by default")
assert(popup.A == 1, "alpha defaults to opaque")
popup:SetAlpha(0.4)
assert(math.abs(popup.A - 0.4) < 0.001, "alpha is stored")
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
assert(window.Open == false and window.Dim.BackgroundTransparency == 1, "scrim fades out when hidden")
window:Toggle()
assert(window.Open == true and window.Dim.BackgroundTransparency == 0.55, "scrim returns when shown")
window:SetGlass(0.35)
assert(combat.Panel.BackgroundTransparency == 0.35, "panel transparency is adjustable")
assert(math.abs(window.SearchFrame.BackgroundTransparency - 0.45) < 1e-6,
    "search follows, a touch denser")
window:SetGlass(0.22)
-- And the constructor option works, so GlassTransparency is not a no-op.
local glassy = Minecraft.new({GlassTransparency = 0.5})
local gtab = glassy:AddTab("A")
assert(gtab.Panel.BackgroundTransparency == 0.5, "GlassTransparency is applied on creation")
glassy:Destroy()
window:SetBlur(32)
assert(window.BlurEffect and window.BlurEffect.Size == 32, "SetBlur promotes to a full-screen blur")
assert(window.BlurMode == "screen")
window:SetBlur(24)
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

local acrylicFolder = window.AcrylicFolder
local blurObject = window.BlurEffect
window:Destroy()
assert(acrylicFolder.destroyed, "acrylic folder is cleaned up with the window")
assert(window.BlurEffect == nil, "blur reference is cleared")
assert(blurObject.destroyed, "blur effect is cleaned up")
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
