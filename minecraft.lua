-- Minecraft :: a Roblox UI library that recreates the classic Minecraft cheat
-- menu: a row of equal-size panels, bordered option rows with a hover state and
-- animated per-row settings that slide open underneath the option.
-- UI only -- gameplay logic lives in the callbacks.
--
--   local Minecraft = loadstring(game:HttpGet(".../minecraft.lua"))()
--   local window = Minecraft.new({Title = "Minecraft", Theme = 1})
--   local combat = window:AddTab("Combat")
--   combat:AddToggle({Name = "Attack Aura", Settings = function(s)
--       s:Slider({Name = "Range", Min = 1, Max = 8, Default = 4})
--   end, Callback = function(on) print(on) end})

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Minecraft = {}
Minecraft.__index = Minecraft
Minecraft.Version = "1.7.0"
Minecraft.Build = 17 -- incremented on every visible change, used by examples to detect stale caches

local Tab = {}
Tab.__index = Tab

local Row = {}
Row.__index = Row

local Settings = {}
Settings.__index = Settings

-- Layout metrics. Every panel uses the same width and height, so the menu always
-- reads as one even row of columns no matter how many tabs are added.
local M = {
    PanelWidth = 226,
    PanelHeight = 520,
    Gap = 9,
    Title = 42,
    RowHeight = 30,
    RowGap = 4,
    Inset = 10,
    Search = 32,
    SearchWidth = 280,
}
-- One place to tune the whole look: panel 6px, rows 5px, small controls 3-4px.
Minecraft.Radius = {Panel = 9, Row = 7, Control = 5, Small = 4}
Minecraft.Metrics = M

local T = {
    Layout = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Expand = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Collapse = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Quick = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Pop = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Color = TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
    Fade = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    FadeFast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function shade(color, amount)
    if amount >= 0 then
        return color:Lerp(Color3.new(1, 1, 1), amount)
    end
    return color:Lerp(Color3.new(0, 0, 0), -amount)
end

local function mix(a, b, t)
    return a:Lerp(b, t)
end

-- Six themes. Each palette is built from a saturated base plus a neon accent so
-- panels read as tinted glass over the blurred game, like the reference menus.
local THEMES = {}
local function addTheme(name, base, accent, text, muted, glow)
    THEMES[#THEMES + 1] = {
        Name = name,
        Window = shade(base, -0.62),
        Panel = base,
        PanelTop = shade(base, 0.10),
        PanelBottom = shade(base, -0.14),
        Header = shade(base, 0.07),
        Border = mix(shade(base, 0.30), accent, 0.35),
        Row = shade(base, 0.14),
        RowStroke = shade(base, 0.26),
        Hover = shade(base, 0.28),
        On = mix(base, accent, 0.55),
        OnEdge = accent,
        Text = text,
        Muted = muted,
        Accent = accent,
        Glow = glow or accent,
        Popup = shade(base, 0.06),
        Track = shade(base, -0.16),
        Title = shade(base, 0.20),
    }
end
-- Neon, high-contrast palettes (indigo / violet / cyan / magenta family).
addTheme("Nebula", rgb(38, 28, 74), rgb(150, 130, 255), rgb(233, 229, 255), rgb(158, 152, 196), rgb(158, 120, 255))
addTheme("Cyber", rgb(20, 46, 72), rgb(86, 226, 255), rgb(224, 244, 255), rgb(140, 178, 200), rgb(86, 210, 255))
addTheme("Bloom", rgb(56, 28, 62), rgb(255, 132, 216), rgb(252, 228, 246), rgb(190, 150, 186), rgb(255, 110, 210))
addTheme("Ember", rgb(62, 26, 34), rgb(255, 126, 96), rgb(255, 232, 226), rgb(196, 152, 148), rgb(255, 110, 80))
addTheme("Mint", rgb(20, 52, 46), rgb(94, 245, 186), rgb(224, 255, 244), rgb(146, 190, 176), rgb(80, 240, 176))
addTheme("Gold", rgb(58, 42, 20), rgb(255, 202, 92), rgb(255, 244, 224), rgb(190, 168, 132), rgb(255, 190, 70))
Minecraft.Themes = THEMES

local function resolveTheme(value)
    if type(value) == "number" then
        return math.clamp(math.floor(value), 1, #THEMES)
    elseif type(value) == "string" then
        for index, theme in ipairs(THEMES) do
            if theme.Name:lower() == value:lower() then
                return index
            end
        end
    end
    return 1
end

local function create(class, properties, parent)
    local object = Instance.new(class)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function tween(object, properties, info)
    local animation = TweenService:Create(object, info or T.Quick, properties)
    animation:Play()
    return animation
end

local function applyColor(object, property, color, instant, duration)
    if instant then
        object[property] = color
        return
    end
    tween(object, {[property] = color}, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
end

local function applyNumber(object, property, value, instant, duration, info)
    if instant then
        object[property] = value
        return
    end
    tween(object, {[property] = value}, info or TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
end

local function isAlive(object)
    if type(object) ~= "userdata" and type(object) ~= "table" then
        return false
    end
    local ok, parent = pcall(function()
        return object.Parent
    end)
    return ok and parent ~= nil
end

local function clamp(value, minimum, maximum)
    return math.min(maximum, math.max(minimum, value))
end

-- Begin a mouse/touch drag. `handler` receives the input position on every move.
local function beginDrag(input, handler)
    handler(input.Position)
    local moving
    moving = UserInputService.InputChanged:Connect(function(move)
        if move.UserInputType == Enum.UserInputType.MouseMovement or move.UserInputType == Enum.UserInputType.Touch then
            handler(move.Position)
        end
    end)
    local finished
    finished = UserInputService.InputEnded:Connect(function(release)
        if release.UserInputType == Enum.UserInputType.MouseButton1 or release.UserInputType == Enum.UserInputType.Touch then
            if moving then
                moving:Disconnect()
            end
            if finished then
                finished:Disconnect()
            end
        end
    end)
end

-- Collect the transparencies of a subtree so it can fade in and out as one unit.
-- Fade helper. The first time an object is seen its real transparency is
-- remembered as the base, so opening/closing a block always animates around the
-- same value instead of drifting to "fully transparent forever".
local function collectFade(object, list)
    list = list or {}
    local function remember(property)
        local ok, value = pcall(function()
            return object[property]
        end)
        if not ok or type(value) ~= "number" then
            return
        end
        for _, item in ipairs(list) do
            if item.Object == object and item.Property == property then
                return
            end
        end
        list[#list + 1] = {Object = object, Property = property, Base = value}
    end
    remember("BackgroundTransparency")
    remember("TextTransparency")
    remember("Transparency")
    local ok, children = pcall(function()
        return object:GetChildren()
    end)
    if ok then
        for _, child in ipairs(children) do
            if not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIGradient")
                and not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIScale") then
                collectFade(child, list)
            end
        end
    end
    return list
end

local function applyFade(list, alpha, instant, delay)
    alpha = clamp(alpha, 0, 1)
    local function run()
        for _, item in ipairs(list) do
            if isAlive(item.Object) then
                local target = item.Base + (1 - item.Base) * alpha
                if instant then
                    pcall(function()
                        item.Object[item.Property] = target
                    end)
                else
                    local info = T.Fade
                    if alpha == 0 then
                        info = T.FadeFast
                    end
                    tween(item.Object, {[item.Property] = target}, info)
                end
            end
        end
    end
    if delay and delay > 0 then
        task.delay(delay, run)
    else
        run()
    end
end

--==========================================================================--
-- Window
--==========================================================================--

function Minecraft.new(options)
    options = options or {}
    local window = setmetatable({}, Minecraft)
    window.Options = options
    window.Flags = {}
    window.Tabs = {}
    window.Refreshers = {}
    window.Connections = {}
    window.Font = options.Font or Enum.Font.Gotham
    window.Scale = options.Scale or 1
    window.ThemeIndex = resolveTheme(options.Theme or 1)
    window.Theme = THEMES[window.ThemeIndex]
    window.ToggleKey = options.ToggleKey or options.Key or Enum.KeyCode.Insert
    window.Title = options.Title or "Minecraft"
    window.Open = true
    window.Keybinds = {}

    window.Gui = create("ScreenGui", {
        Name = "MinecraftUI",
        DisplayOrder = options.DisplayOrder or 9999,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Enabled = true,
    })
    local parented = pcall(function()
        window.Gui.Parent = options.Parent or CoreGui
    end)
    if not parented then
        window.Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Blur modes:
    --   "local" (default) -> no viewport blur; frosted panels do the work
    --   "screen"          -> BlurEffect over the whole 3D view, like a CS menu
    window.BlurMode = options.BlurMode or (options.Blur == true and "screen" or "local")
    window.BlurSize = options.BlurSize or 24
    if window.BlurMode == "screen" and options.BlurEffect ~= false then
        local okLighting, lighting = pcall(function()
            return game:GetService("Lighting")
        end)
        if okLighting and lighting then
            local existing = lighting:FindFirstChild("MinecraftUIBlur")
            if existing then
                existing:Destroy()
            end
            local okBlur, blur = pcall(function()
                return create("BlurEffect", {Name = "MinecraftUIBlur", Size = 0, Enabled = true}, lighting)
            end)
            if okBlur and blur then
                window.BlurEffect = blur
                task.defer(function()
                    if isAlive(blur) and window.Open then
                        tween(blur, {Size = window.BlurSize}, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
                    end
                end)
            end
        end
    end

    -- Dark scrim. In "local" mode it only sits behind the panels (a sibling of
    -- the root, sized to it), so the screen keeps its colour. In "screen" mode
    -- it covers the viewport together with the blur.
    window.DimValue = options.DimTransparency or (window.BlurMode == "screen" and 0.55 or 0.35)
    if options.Dim ~= false then
        if window.BlurMode == "screen" then
            window.Dim = create("Frame", {
                Name = "Dim",
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = window.DimValue,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 1,
            }, window.Gui)
        end
    end

    -- CanvasGroup lets the whole menu fade as one unit. Fall back to a Frame on
    -- clients that do not expose CanvasGroup yet.
    local groupClass = "Frame"
    if pcall(function()
        return Instance.new("CanvasGroup")
    end) then
        groupClass = "CanvasGroup"
    end
    window.Root = create(groupClass, {
        Name = "Root",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(M.PanelWidth, M.PanelHeight + M.Gap + M.Search),
        ZIndex = 5,
    }, window.Gui)
    if window.Root.ClassName == "CanvasGroup" then
        window.Root.GroupTransparency = 0
    end

    window.ScaleObject = create("UIScale", {Scale = window.Scale}, window.Root)

    window.Body = create("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(M.PanelWidth, M.PanelHeight),
        ZIndex = 5,
    }, window.Root)

    if window.BlurMode ~= "screen" and window.Options.Dim ~= false then
        window.Dim = create("Frame", {
            Name = "LocalDim",
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = window.DimValue,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(-M.Gap - 4, -M.Gap - 4),
            Size = UDim2.new(1, (M.Gap + 4) * 2, 1, (M.Gap + 4) * 2),
            ZIndex = 0,
        }, window.Root)
        create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel + 4)}, window.Dim)
    end

    window.PopupLayer = create("Frame", {
        Name = "PopupLayer",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 60,
    }, window.Root)

    window.Shield = create("TextButton", {
        Name = "Shield",
        Text = "",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
    }, window.PopupLayer)
    window.Shield.MouseButton1Click:Connect(function()
        window:ClosePopup()
    end)

    window:SetupSearch()
    window:SetupInput()

    -- Fade the menu in once it is built.
    if window.Root.ClassName == "CanvasGroup" then
        window.Root.GroupTransparency = 1
        window.ScaleObject.Scale = window.Scale * 0.97
        tween(window.Root, {GroupTransparency = 0}, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
        tween(window.ScaleObject, {Scale = window.Scale}, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    end

    return window
end

function Minecraft:_Bind(target, apply)
    local entry = {Target = target, Apply = apply}
    self.Refreshers[#self.Refreshers + 1] = entry
    apply(self.Theme, true)
    return entry
end

function Minecraft:Refresh(instant)
    local theme = self.Theme
    for _, entry in ipairs(self.Refreshers) do
        if not entry.Target or isAlive(entry.Target) then
            entry.Apply(theme, instant)
        end
    end
end

-- Smooth palette crossfade used by SetTheme: every bound object glides to the
-- new colours instead of snapping.
function Minecraft:AnimateTheme()
    local theme = self.Theme
    for _, entry in ipairs(self.Refreshers) do
        if not entry.Target or isAlive(entry.Target) then
            entry.Apply(theme, false)
        end
    end
    if self.Root.ClassName == "CanvasGroup" then
        tween(self.Root, {GroupTransparency = 0.12}, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
        task.delay(0.09, function()
            if isAlive(self.Root) then
                tween(self.Root, {GroupTransparency = self.Open and 0 or 1}, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            end
        end)
    end
end

function Minecraft:SetTheme(value)
    local index = resolveTheme(value)
    if index == self.ThemeIndex then
        return
    end
    self.ThemeIndex = index
    self.Theme = THEMES[index]
    self:AnimateTheme()
end

function Minecraft:CycleTheme(direction)
    local index = self.ThemeIndex + (direction or 1)
    if index > #THEMES then
        index = 1
    elseif index < 1 then
        index = #THEMES
    end
    self:SetTheme(index)
end

-- Kept for backwards compatibility: panels are translucent on their own now,
-- there is no separate tint layer behind the window.
function Minecraft:SetGlass(transparency)
    self.PanelTransparency = clamp(transparency or 0.22, 0, 1)
    for _, tab in ipairs(self.Tabs) do
        tween(tab.Panel, {BackgroundTransparency = self.PanelTransparency}, T.Color)
    end
end

-- Real world blur strength. In "local" mode this promotes the window to a
-- full-screen blur on demand (the BlurEffect is created once, lazily).
function Minecraft:SetBlur(size)
    self.BlurSize = math.max(tonumber(size) or 0, 0)
    if not self.BlurEffect then
        local ok, lighting = pcall(function()
            return game:GetService("Lighting")
        end)
        if not ok or not lighting then
            return
        end
        local okBlur, blur = pcall(function()
            return create("BlurEffect", {Name = "MinecraftUIBlur", Size = 0, Enabled = true}, lighting)
        end)
        if not okBlur then
            return
        end
        self.BlurEffect = blur
        self.BlurMode = "screen"
    end
    if isAlive(self.BlurEffect) then
        tween(self.BlurEffect, {Size = self.Open and self.BlurSize or 0}, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    end
end

function Minecraft:SetScale(scale)
    self.Scale = scale or 1
    tween(self.ScaleObject, {Scale = self.Scale}, T.Pop)
end

-- The window has no title bar any more: it is a fixed row of panels, so it is
-- not draggable. Kept as a no-op so older snippets do not break.
function Minecraft:SetupHeader()
    return nil
end

function Minecraft:SetupSearch()
    local window = self
    window.SearchFrame = create("Frame", {
        Name = "Search",
        BackgroundColor3 = window.Theme.Panel,
        BackgroundTransparency = 0.32,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(M.SearchWidth, M.Search),
        ZIndex = 6,
    }, window.Root)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, window.SearchFrame)
    window.SearchGradient = create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(window.Theme.PanelTop, window.Theme.PanelBottom),
    }, window.SearchFrame)
    window.SearchBox = create("TextBox", {
        Name = "SearchBox",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "",
        PlaceholderText = window.Options.SearchPlaceholder or "Search",
        PlaceholderColor3 = window.Theme.Muted,
        TextSize = 12,
        TextColor3 = window.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -16, 1, 0),
        ZIndex = 2,
    }, window.SearchFrame)
    window.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        window:Filter(window.SearchBox.Text)
    end)
    window:_Bind(window.SearchFrame, function(theme, instant)
        applyColor(window.SearchFrame, "BackgroundColor3", theme.Panel, instant, 0.26)
        if window.SearchGradient and isAlive(window.SearchGradient) then
            window.SearchGradient.Color = ColorSequence.new(theme.PanelTop, theme.PanelBottom)
        end
        applyColor(window.SearchBox, "PlaceholderColor3", theme.Muted, instant, 0.26)
        applyColor(window.SearchBox, "TextColor3", theme.Text, instant, 0.26)
    end)
end

function Minecraft:Filter(query)
    query = (query or ""):lower()
    for _, tab in ipairs(self.Tabs) do
        tab:Filter(query)
    end
end

function Minecraft:SetupInput()
    local window = self
    local connection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == window.ToggleKey then
            window:Toggle()
            return
        end
        if window.Capturing then
            local capture = window.Capturing
            window.Capturing = nil
            capture(input)
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape then
            if window.Popup then
                window:ClosePopup()
            end
            return
        end
        if not window.Open then
            return
        end
        for _, bind in ipairs(window.Keybinds) do
            if bind.Key and bind.Key == input.KeyCode and bind.Callback then
                bind.Callback(input.KeyCode)
            end
        end
    end)
    window.Connections[#window.Connections + 1] = connection
end

function Minecraft:Toggle(value)
    if value == nil then
        value = not self.Open
    end
    self.Open = value and true or false
    if self.BlurEffect and isAlive(self.BlurEffect) then
        tween(self.BlurEffect, {Size = self.Open and self.BlurSize or 0}, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    end
    if self.Dim then
        tween(self.Dim, {BackgroundTransparency = self.Open and self.DimValue or 1}, T.Color)
    end
    if self.Popup then
        self:ClosePopup(true)
    end
    if self.Root.ClassName == "CanvasGroup" then
        if self.Open then
            self.Gui.Enabled = true
            tween(self.Root, {GroupTransparency = 0}, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            tween(self.ScaleObject, {Scale = self.Scale}, T.Pop)
        else
            local animation = tween(self.Root, {GroupTransparency = 1}, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            tween(self.ScaleObject, {Scale = self.Scale * 0.97}, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            task.delay(0.2, function()
                if not self.Open then
                    self.Gui.Enabled = false
                end
            end)
            return animation
        end
    else
        self.Gui.Enabled = self.Open
    end
end

function Minecraft:Show()
    self:Toggle(true)
end

function Minecraft:Hide()
    self:Toggle(false)
end

function Minecraft:_UpdateLayout(instant)
    local count = math.max(#self.Tabs, 1)
    local bodyWidth = count * M.PanelWidth + (count - 1) * M.Gap
    local width = bodyWidth
    local height = M.PanelHeight + M.Gap + M.Search

    if instant then
        self.Root.Size = UDim2.fromOffset(width, height)
        self.Body.Size = UDim2.fromOffset(bodyWidth, M.PanelHeight)
        self.Body.Position = UDim2.fromOffset(0, 0)
    else
        tween(self.Root, {Size = UDim2.fromOffset(width, height)}, T.Layout)
        tween(self.Body, {Size = UDim2.fromOffset(bodyWidth, M.PanelHeight), Position = UDim2.fromOffset(0, 0)}, T.Layout)
    end

    self:_Fit(width, height)

    if self.SearchFrame then
        local target = UDim2.new(0.5, 0, 0, M.PanelHeight + M.Gap)
        if instant then
            self.SearchFrame.Position = target
        else
            tween(self.SearchFrame, {Position = target}, T.Layout)
        end
    end

    for index, tab in ipairs(self.Tabs) do
        local target = UDim2.fromOffset((index - 1) * (M.PanelWidth + M.Gap), 0)
        if instant then
            tab.Panel.Position = target
        else
            tween(tab.Panel, {Position = target}, T.Layout)
        end
    end
end

-- Keep the menu inside the screen, like a real client would.
function Minecraft:_Fit(width, height)
    local viewport
    local ok = pcall(function()
        viewport = workspace.CurrentCamera.ViewportSize
    end)
    if not ok or not viewport then
        return
    end
    local fit = math.min(viewport.X * 0.94 / width, viewport.Y * 0.9 / height, 1)
    local target = math.min(self.Scale, fit)
    if math.abs(self.ScaleObject.Scale - target) > 0.01 then
        self.ScaleObject.Scale = target
    end
end

function Minecraft:AddTab(name, options)
    options = options or {}
    local window = self
    local theme = window.Theme
    local tab = setmetatable({
        Window = window,
        Name = name or ("Tab " .. (#window.Tabs + 1)),
        Rows = {},
        HasRows = false,
    }, Tab)

    tab.Panel = create("Frame", {
        Name = "Panel_" .. tab.Name,
        BackgroundColor3 = theme.Panel,
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.fromOffset(M.PanelWidth, M.PanelHeight),
        Position = UDim2.fromOffset((#window.Tabs) * (M.PanelWidth + M.Gap), -10),
        ZIndex = 2,
    }, window.Body)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, tab.Panel)
    -- Soft vertical tint so the glass has depth instead of one flat colour.
    tab.Gradient = create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(theme.PanelTop, theme.PanelBottom),
    }, tab.Panel)
    -- Outer neon ring (the "glow").
    -- Inner 1px highlight along the top edge, like frosted glass.
    tab.TopShine = create("Frame", {
        Name = "TopShine",
        BackgroundColor3 = theme.Text,
        BackgroundTransparency = 0.86,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 1),
        Size = UDim2.new(1, -20, 0, 1),
        ZIndex = 3,
    }, tab.Panel)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, tab.TopShine)

    tab.Title = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = tab.Name,
        TextSize = 16,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, M.Title),
        ZIndex = 2,
    }, tab.Panel)

    tab.TitleLine = create("Frame", {
        Name = "TitleLine",
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, M.Title - 1),
        Size = UDim2.new(1, -16, 0, 1),
        ZIndex = 3,
    }, tab.Panel)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, tab.TitleLine)

    tab.Scroll = create("ScrollingFrame", {
        Name = "Scroll",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, M.Title),
        Size = UDim2.new(1, 0, 1, -M.Title),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Muted,
        ScrollBarImageTransparency = 0.55,
        ClipsDescendants = true,
        ZIndex = 2,
    }, tab.Panel)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, tab.Scroll)
    create("UIPadding", {
        PaddingTop = UDim.new(0, M.Inset),
        PaddingBottom = UDim.new(0, M.Inset),
        PaddingLeft = UDim.new(0, M.Inset),
        PaddingRight = UDim.new(0, M.Inset + 2),
    }, tab.Scroll)

    tab.Content = create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 2,
    }, tab.Scroll)
    -- Without this every row sits at the same Y and only the last one is visible.
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, M.RowGap),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    }, tab.Content)

    tab.EmptyLabel = create("TextLabel", {
        Name = "Empty",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "Nothing here",
        TextSize = 12,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, 0, 0, 20),
        Visible = false,
        ZIndex = 2,
    }, tab.Content)

    window.Tabs[#window.Tabs + 1] = tab

    window:_Bind(tab.Title, function(themeNow, instant)
        applyColor(tab.Title, "TextColor3", themeNow.Text, instant, 0.26)
    end)
    window:_Bind(tab.TitleLine, function(themeNow, instant)
        applyColor(tab.TitleLine, "BackgroundColor3", themeNow.Accent, instant, 0.26)
    end)
    window:_Bind(tab.Panel, function(themeNow, instant)
        applyColor(tab.Panel, "BackgroundColor3", themeNow.Panel, instant, 0.26)
        if tab.Gradient and isAlive(tab.Gradient) then
            tab.Gradient.Color = ColorSequence.new(themeNow.PanelTop, themeNow.PanelBottom)
        end
        if tab.TopShine and isAlive(tab.TopShine) then
            applyColor(tab.TopShine, "BackgroundColor3", themeNow.Text, instant, 0.26)
        end
        applyColor(tab.Scroll, "ScrollBarImageColor3", themeNow.Muted, instant, 0.26)
        applyColor(tab.EmptyLabel, "TextColor3", themeNow.Muted, instant, 0.26)
    end)

    window:_UpdateLayout(false)
    if not window.Options.NoIntro then
        tween(tab.Panel, {Position = UDim2.fromOffset((#window.Tabs - 1) * (M.PanelWidth + M.Gap), 0)}, T.Layout)
    else
        tab.Panel.Position = UDim2.fromOffset((#window.Tabs - 1) * (M.PanelWidth + M.Gap), 0)
    end
    return tab
end

function Minecraft:SelectTab(tab)
    -- Every panel is visible at once in this style; kept for API symmetry.
    return tab
end

function Minecraft:Destroy()
    for _, connection in ipairs(self.Connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    self.Connections = {}
    self.Refreshers = {}
    self.Keybinds = {}
    if self.Popup then
        self.Popup = nil
    end
    if self.BlurEffect then
        pcall(function()
            self.BlurEffect:Destroy()
        end)
        self.BlurEffect = nil
    end
    if self.Gui then
        self.Gui:Destroy()
    end
end

--==========================================================================--
-- Rows
--==========================================================================--

local function shorten(value, limit)
    value = tostring(value or "")
    if #value > limit then
        return value:sub(1, limit - 1) .. "..."
    end
    return value
end

local function newRow(tab, name, options)
    options = options or {}
    local window = tab.Window
    local theme = window.Theme
    local row = setmetatable({
        Tab = tab,
        Window = window,
        Name = name or "Option",
        Options = options,
        SettingsHeight = 0,
        ListHeight = 0,
        SettingsOpen = false,
        ListOpen = false,
        Built = false,
        Visible = true,
        Value = nil,
    }, Row)

    row.Slot = create("Frame", {
        Name = "Row_" .. row.Name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, M.RowHeight),
        ZIndex = 2,
    }, tab.Content)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Row)}, row.Slot)

    row.Frame = create("TextButton", {
        Name = "Row",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = window.Options.NoIntro and UDim2.fromOffset(0, 0) or UDim2.fromOffset(9, 0),
        Size = window.Options.NoIntro and UDim2.new(1, 0, 0, M.RowHeight) or UDim2.new(1, -9, 0, M.RowHeight),
        Text = "",
        ZIndex = 2,
    }, row.Slot)
    if not window.Options.NoIntro then
        tween(row.Frame, {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, M.RowHeight)}, T.Layout)
    end

    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Row)}, row.Frame)
    row.Box = create("Frame", {
        Name = "Box",
        BackgroundColor3 = theme.Row,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 2,
    }, row.Frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Row)}, row.Box)

    row.Label = create("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = row.Name,
        TextSize = 15,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(M.Inset, 0),
        Size = UDim2.new(1, -(M.Inset * 2 + 26), 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, row.Frame)

    -- Value text stops before the dots column; the label stops before the value.
    row.ValueLabel = create("TextLabel", {
        Name = "Value",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "",
        TextSize = 13,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.new(0.42, 0, 0, 0),
        Size = UDim2.new(0.58, -(M.Inset + 26), 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = false,
        ZIndex = 3,
    }, row.Frame)

    row.Dots = create("TextLabel", {
        Name = "Dots",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "•••",
        TextSize = 15,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.new(1, -M.Inset - 22, 0, -2),
        Size = UDim2.fromOffset(22, M.RowHeight),
        Visible = false,
        ZIndex = 3,
    }, row.Frame)

    row.Badge = create("TextLabel", {
        Name = "Badge",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Badge or "PREMIUM",
        TextSize = 9,
        TextColor3 = theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.new(1, -M.Inset - 62, 0, 1),
        Size = UDim2.fromOffset(40, M.RowHeight),
        Visible = options.Premium == true,
        ZIndex = 3,
    }, row.Frame)

    row.Holder = create("Frame", {
        Name = "SettingsHolder",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, M.RowHeight + M.RowGap),
        Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 2,
    }, row.Slot)

    row.ListHolder = create("Frame", {
        Name = "ListHolder",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, M.RowHeight + M.RowGap),
        Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 2,
    }, row.Slot)

    if options.Settings then
        row.Dots.Visible = true
    end

    window:_Bind(row.Box, function(themeNow, instant)
        applyColor(row.ValueLabel, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(row.Badge, "TextColor3", themeNow.Accent, instant, 0.2)
        row:RefreshVisual(instant)
    end)

    row.Frame.MouseEnter:Connect(function()
        row.Hovered = true
        row:RefreshVisual()
    end)
    row.Frame.MouseLeave:Connect(function()
        row.Hovered = false
        row:RefreshVisual()
    end)

    row.Frame.MouseButton2Down:Connect(function()
        if not row.Locked then
            row:ToggleSettings()
        end
    end)
    row.Frame.MouseButton1Click:Connect(function()
        -- Tiny squish so every click has feedback, even when the row is a press.
        local size = row.Frame.Size
        row.Frame.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, M.RowHeight - 2)
        tween(row.Frame, {Size = UDim2.new(size.X.Scale, size.X.Offset, 0, M.RowHeight)}, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
        row:OnPrimaryClick()
    end)

    tab.Rows[#tab.Rows + 1] = row
    tab.HasRows = true
    window.Rows = window.Rows or {}
    window.Rows[#window.Rows + 1] = row
    if options.Flag then
        row.Flag = options.Flag
    end
    return row
end

-- One source of truth for how a row looks. Everything animates, but only these
-- four properties change: fill colour, fill alpha, edge colour and text colour.
function Row:RefreshVisual(instant)
    local theme = self.Window.Theme
    local open = self.SettingsOpen or self.ListOpen

    local fill = theme.Row
    local alpha = 0.10
    if self.Locked then
        fill, alpha = theme.Panel, 0.45
    elseif self.OnState then
        -- Enabled rows stay accented, hover just lifts them a little more.
        if self.Hovered or open then
            fill, alpha = mix(theme.On, theme.Hover, 0.6), 0.02
        else
            fill, alpha = theme.On, 0.08
        end
    elseif open or self.Hovered then
        fill, alpha = theme.Hover, open and 0.02 or 0.04
    end

    local labelColor = self.Locked and theme.Muted or theme.Text

    applyColor(self.Box, "BackgroundColor3", fill, instant, 0.16)
    applyColor(self.Box, "BackgroundTransparency", alpha, instant, 0.16)
    applyColor(self.Label, "TextColor3", labelColor, instant, 0.16)
    applyColor(self.Dots, "TextColor3", (self.OnState or open) and theme.Accent or theme.Muted, instant, 0.16)

end

function Row:SetValueText(value)
    if value == nil or value == "" then
        self.ValueLabel.Visible = false
        self.ValueLabel.Text = ""
        return
    end
    self.ValueLabel.Visible = true
    self.ValueLabel.Text = shorten(value, 16)
end

function Row:OnPrimaryClick()
    if self.Locked then
        return
    end
    if self.OnClick then
        self.OnClick()
    end
end

function Row:_Extra()
    return (self.SettingsOpen and self.SettingsHeight or 0) + (self.ListOpen and self.ListHeight or 0)
end

function Row:_ApplyHeight(instant, opening)
    local extra = self:_Extra()
    local target = UDim2.new(1, 0, 0, M.RowHeight + extra)
    if instant then
        self.Slot.Size = target
    else
        tween(self.Slot, {Size = target}, opening and T.Expand or T.Collapse)
    end
    -- Keep the two collapsible blocks stacked below the header row.
    local listOffset = M.RowHeight + M.RowGap + (self.SettingsOpen and self.SettingsHeight or 0)
    local settingsTarget = UDim2.fromOffset(0, M.RowHeight + M.RowGap)
    local listTarget = UDim2.fromOffset(0, listOffset)
    local settingsSize = UDim2.new(1, 0, 0, math.max(self.SettingsHeight - M.RowGap, 0))
    local listSize = UDim2.new(1, 0, 0, math.max(self.ListHeight - M.RowGap, 0))
    if instant then
        self.Holder.Position = settingsTarget
        self.Holder.Size = settingsSize
        self.ListHolder.Position = listTarget
        self.ListHolder.Size = listSize
    else
        tween(self.Holder, {Position = settingsTarget, Size = settingsSize}, opening and T.Expand or T.Collapse)
        tween(self.ListHolder, {Position = listTarget, Size = listSize}, T.Layout)
    end
end

function Row:EnsureSettings()
    if self.Built then
        return
    end
    self.Built = true
    local settings = setmetatable({
        Row = self,
        Window = self.Window,
        Controls = {},
        Height = 0,
    }, Settings)
    local panel = create("Frame", {
        Name = "SettingsPanel",
        BackgroundColor3 = self.Window.Theme.Window,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 2,
    }, self.Holder)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Row)}, panel)
    local padding = create("UIPadding", {
        PaddingTop = UDim.new(0, 7),
        PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, panel)
    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    }, panel)
    settings.Panel = panel
    settings.Layout = layout
    settings.Padding = padding
    self.Settings = settings

    self.Window:_Bind(panel, function(themeNow, instant)
        applyColor(panel, "BackgroundColor3", themeNow.Window, instant, 0.26)
    end)

    local handler = self.Options.Settings
    if type(handler) == "function" then
        handler(settings)
    elseif type(handler) == "table" then
        for _, build in ipairs(handler) do
            build(settings)
        end
    end

    settings:_Measure()
    panel.Size = UDim2.new(1, 0, 0, settings.Height + 12)
    -- Capture the fade list once; it is reused for every open/close so the base
    -- transparencies never get polluted by an in-progress animation.
    settings.Fade = collectFade(panel)
    applyFade(settings.Fade, 1, true)
end

function Row:ToggleSettings(force)
    if not self.Dots.Visible and not self.Options.Settings then
        return
    end
    local target = force
    if target == nil then
        target = not self.SettingsOpen
    end
    if target == self.SettingsOpen then
        return
    end
    self:EnsureSettings()
    self.SettingsOpen = target
    self.SettingsHeight = self.Settings.Height + 12 + M.RowGap
    local settings = self.Settings
    if not settings.Fade then
        settings.Fade = collectFade(settings.Panel)
    end
    local function setAlpha(alpha, instant)
        applyFade(settings.Fade, alpha, instant)
    end
    settings.SetAlpha = setAlpha
    if target then
        -- Slide the block in from above while the controls fade in with a small
        -- stagger, so the block unfolds instead of popping.
        settings.Panel.Position = UDim2.fromOffset(0, -7)
        setAlpha(1, true)
        setAlpha(0, false)
        tween(settings.Panel, {Position = UDim2.fromOffset(0, 0)}, T.Expand)
        for index, control in ipairs(settings.Controls) do
            local entry = control.Frame
            if entry then
                entry.Position = UDim2.fromOffset(0, 5)
                task.delay(0.028 * math.min(index - 1, 10), function()
                    if isAlive(entry) and self.SettingsOpen then
                        tween(entry, {Position = UDim2.fromOffset(0, 0)}, T.Layout)
                    end
                end)
            end
        end
    else
        setAlpha(1, false)
        tween(settings.Panel, {Position = UDim2.fromOffset(0, -7)}, T.FadeFast)
    end
    self:_ApplyHeight(false, target)
    self:RefreshVisual()
    if self.Options.SettingsChanged then
        self.Options.SettingsChanged(target)
    end
end

function Row:ApplyFlag(flags)
    if self.IsSection or not self.Flag then
        return
    end
    local value = flags[self.Flag]
    if value == nil or self.ApplyValue == nil then
        return
    end
    self:ApplyValue(value)
end

function Row:SetVisible(value)
    self.Visible = value and true or false
    self.Slot.Visible = self.Visible
end

function Row:SetLocked(value)
    self.Locked = value and true or false
    self:RefreshVisual()
end

function Row:SetName(value)
    self.Name = value
    self.Label.Text = value
end

--==========================================================================--
-- Settings container
--==========================================================================--

function Settings:_Measure()
    local total = 0
    local count = 0
    for _, control in ipairs(self.Controls) do
        if control.Frame.Visible ~= false or control.AlwaysMeasure then
            total = total + control.Height
            count = count + 1
        end
    end
    if count > 1 then
        total = total + (count - 1) * 5
    end
    self.Height = total
    self.Panel.Size = UDim2.new(1, 0, 0, self.Height + 12)
    return self.Height
end

function Settings:_Resize()
    self:_Measure()
    local row = self.Row
    if row.SettingsOpen then
        local before = row.SettingsHeight
        row.SettingsHeight = self.Height + 12 + M.RowGap
        row:_ApplyHeight(false)
    end
end

function Settings:_Base(name, height)
    local theme = self.Window.Theme
    local frame = create("Frame", {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height),
        ZIndex = 3,
    }, self.Panel)
    local entry = {Frame = frame, Height = height, Window = self.Window, Settings = self}
    self.Controls[#self.Controls + 1] = entry
    return entry, frame
end

function Settings:Label(value)
    local entry, frame = self:_Base("SettingLabel", 13)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Font,
        Text = value or "",
        TextSize = 11,
        TextColor3 = self.Window.Theme.Muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(1, 0, 0, 13),
        ZIndex = 3,
    }, frame)
    self.Window:_Bind(label, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Muted, instant, 0.2)
    end)
    entry.Label = label
    return {
        Set = function(_, text)
            label.Text = text or ""
        end,
    }
end

function Settings:Toggle(options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local entry, frame = self:_Base("SettingToggle", 16)
    local value = options.Default == true

    local box = create("Frame", {
        Name = "Box",
        BackgroundColor3 = theme.Row,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -13, 0, 2),
        Size = UDim2.fromOffset(13, 13),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, box)
    -- Check mark drawn from frame segments (no asset IDs, works offline).
    local mark = create("Frame", {
        Name = "Mark",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        ZIndex = 4,
    }, box)
    local tickShort = create("Frame", {
        Name = "TickShort",
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0.1, 0.72),
        Size = UDim2.fromOffset(4, 2),
        Rotation = 45,
        ZIndex = 5,
    }, mark)
    local tickLong = create("Frame", {
        Name = "TickLong",
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0.3, 0.78),
        Size = UDim2.fromOffset(8, 2),
        Rotation = -48,
        ZIndex = 5,
    }, mark)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, tickShort)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, tickLong)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name or "Enabled",
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -20, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, frame)

    local button = create("TextButton", {
        Name = "Hit",
        Text = "",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
    }, frame)

    local api = {Flag = options.Flag}
    local function paint(instant)
        applyColor(box, "BackgroundColor3", value and theme.On or theme.Row, instant, 0.16)
        applyColor(tickShort, "BackgroundColor3", value and theme.Text or theme.Accent, instant, 0.16)
        applyColor(tickLong, "BackgroundColor3", value and theme.Text or theme.Accent, instant, 0.16)
        local scale = value and 1 or 0
        if instant then
            mark.Size = UDim2.fromOffset(10 * scale, 10 * scale)
        else
            tween(mark, {Size = UDim2.fromOffset(10 * scale, 10 * scale)}, T.Pop)
        end
    end

    window:_Bind(frame, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
        paint(instant)
    end)
    paint(true)

    function api:Get()
        return value
    end

    function api:Set(newValue, silent)
        newValue = newValue and true or false
        if newValue == value then
            return
        end
        value = newValue
        if options.Flag then
            window.Flags[options.Flag] = value
        end
        paint(false)
        if not silent and options.Callback then
            options.Callback(value)
        end
    end

    button.MouseButton1Click:Connect(function()
        api:Set(not value)
    end)

    if options.Flag then
        window.Flags[options.Flag] = value
    end

    return api
end

function Settings:Slider(options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local entry, frame = self:_Base("SettingSlider", 22)
    local minimum = options.Min or 0
    local maximum = options.Max or 100
    local step = options.Step or 1
    local value = clamp(options.Default or minimum, minimum, maximum)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name or "Value",
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -42, 0, 14),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, frame)
    local readout = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "",
        TextSize = 11,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.new(1, -44, 0, 0),
        Size = UDim2.fromOffset(44, 14),
        ZIndex = 3,
    }, frame)
    local track = create("Frame", {
        Name = "Track",
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 16),
        Size = UDim2.new(1, 0, 0, 4),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, track)
    local fill = create("Frame", {
        Name = "Fill",
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 4,
    }, track)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
    local button = create("TextButton", {
        Name = "Hit",
        Text = "",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
    }, frame)

    local function format(number)
        if step < 1 then
            return string.format("%.2f", number)
        end
        return tostring(math.floor(number + 0.5))
    end

    local api = {Flag = options.Flag}
    local function round(number)
        return clamp(math.floor((number - minimum) / step + 0.5) * step + minimum, minimum, maximum)
    end

    local function paint(instant)
        local alpha = (maximum > minimum) and ((value - minimum) / (maximum - minimum)) or 0
        if instant then
            fill.Size = UDim2.new(alpha, 0, 1, 0)
        else
            tween(fill, {Size = UDim2.new(alpha, 0, 1, 0)}, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        end
        readout.Text = format(value) .. (options.Suffix or "")
    end

    window:_Bind(frame, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
        applyColor(readout, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(track, "BackgroundColor3", themeNow.Track, instant, 0.2)
        applyColor(fill, "BackgroundColor3", themeNow.Accent, instant, 0.2)
        paint(instant)
    end)

    function api:Get()
        return value
    end

    function api:Set(newValue, silent)
        newValue = round(tonumber(newValue) or value)
        if newValue == value then
            return
        end
        value = newValue
        if options.Flag then
            window.Flags[options.Flag] = value
        end
        paint(false)
        if not silent and options.Callback then
            options.Callback(value)
        end
    end

    button.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local absolute = frame.AbsolutePosition
        local size = frame.AbsoluteSize
        local function move(position)
            local alpha = clamp((position.X - absolute.X) / math.max(size.X, 1), 0, 1)
            api:Set(minimum + alpha * (maximum - minimum))
        end
        move(input.Position)
        beginDrag(input, move)
    end)

    if options.Flag then
        window.Flags[options.Flag] = value
    end
    return api
end

function Settings:Input(options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local entry, frame = self:_Base("SettingInput", 27)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name or "Text",
        TextSize = 11,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, 11),
        ZIndex = 3,
    }, frame)
    local box = create("Frame", {
        Name = "Box",
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 12),
        Size = UDim2.new(1, 0, 0, 15),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, box)
    local textbox = create("TextBox", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Default or "",
        PlaceholderText = options.Placeholder or "Type here",
        PlaceholderColor3 = theme.Muted,
        TextSize = 11,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Position = UDim2.fromOffset(4, 0),
        Size = UDim2.new(1, -8, 1, 0),
        ZIndex = 3,
    }, box)

    local api = {Flag = options.Flag}
    window:_Bind(frame, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(box, "BackgroundColor3", themeNow.Track, instant, 0.2)
        applyColor(textbox, "TextColor3", themeNow.Text, instant, 0.2)
        applyColor(textbox, "PlaceholderColor3", themeNow.Muted, instant, 0.2)
    end)

    function api:Get()
        return textbox.Text
    end

    function api:Set(text, silent)
        textbox.Text = tostring(text or "")
        if options.Flag then
            window.Flags[options.Flag] = textbox.Text
        end
        if not silent and options.Callback then
            options.Callback(textbox.Text)
        end
    end

    textbox.FocusLost:Connect(function()
        api:Set(textbox.Text)
    end)
    if options.Flag then
        window.Flags[options.Flag] = textbox.Text
    end
    return api
end

function Settings:Button(options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local entry, frame = self:_Base("SettingButton", 20)
    local button = create("TextButton", {
        Name = "Button",
        BackgroundColor3 = theme.Row,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, button)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name or "Button",
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 4,
    }, button)

    window:_Bind(button, function(themeNow, instant)
        applyColor(button, "BackgroundColor3", themeNow.Row, instant, 0.2)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
    end)
    button.MouseEnter:Connect(function()
        applyColor(button, "BackgroundColor3", window.Theme.Hover, false, 0.14)
    end)
    button.MouseLeave:Connect(function()
        applyColor(button, "BackgroundColor3", window.Theme.Row, false, 0.14)
    end)
    button.MouseButton1Click:Connect(function()
        if options.Callback then
            options.Callback()
        end
    end)
    return {Button = button, Set = function(_, text) label.Text = text end}
end

function Settings:Keybind(options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local entry, frame = self:_Base("SettingKeybind", 16)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name or "Key",
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -56, 1, 0),
        ZIndex = 3,
    }, frame)
    local keyButton = create("TextButton", {
        Name = "Key",
        BackgroundColor3 = theme.Row,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        Position = UDim2.new(1, -54, 0, 1),
        Size = UDim2.fromOffset(54, 14),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, keyButton)
    local keyLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "",
        TextSize = 10,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 4,
    }, keyButton)

    local api = {Key = options.Default}
    local function paint()
        keyLabel.Text = api.Key and api.Key.Name or "None"
        applyColor(keyButton, "BackgroundColor3", api.Key and window.Theme.Row or window.Theme.Track, true)
        applyColor(keyLabel, "TextColor3", api.Key and window.Theme.Text or window.Theme.Muted, true)
    end

    window:_Bind(frame, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
        paint()
    end)
    paint()

    keyButton.MouseButton1Click:Connect(function()
        keyLabel.Text = "..."
        window.Capturing = function(input)
            if input.KeyCode == Enum.KeyCode.Escape then
                api.Key = nil
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                api.Key = input.KeyCode
            end
            if options.Flag then
                window.Flags[options.Flag] = api.Key
            end
            paint()
            if options.Changed then
                options.Changed(api.Key)
            end
        end
    end)

    function api:Get()
        return api.Key
    end

    function api:Set(key)
        api.Key = key
        if options.Flag then
            window.Flags[options.Flag] = key
        end
        paint()
        if options.Changed then
            options.Changed(key)
        end
    end

    if options.Flag then
        window.Flags[options.Flag] = options.Default
    end
    return api
end

function Settings:ColorPicker(options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local entry, frame = self:_Base("SettingColor", 16)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name or "Color",
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -20, 1, 0),
        ZIndex = 3,
    }, frame)
    local swatch = create("TextButton", {
        Name = "Swatch",
        BackgroundColor3 = options.Default or Color3.fromRGB(255, 255, 255),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        Position = UDim2.new(1, -16, 0, 1),
        Size = UDim2.fromOffset(16, 14),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, swatch)

    local api = {
        Flag = options.Flag,
        Color = options.Default or Color3.fromRGB(255, 255, 255),
        Alpha = options.DefaultAlpha or 1,
    }
    window:_Bind(frame, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
    end)

    local function paintSwatch()
        swatch.BackgroundColor3 = api.Color
        swatch.BackgroundTransparency = 1 - api.Alpha
    end

    function api:Get()
        return api.Color
    end

    function api:GetAlpha()
        return api.Alpha
    end

    function api:Set(color, silent)
        api.Color = color
        paintSwatch()
        if options.Flag then
            window.Flags[options.Flag] = color
        end
        if not silent and options.Callback then
            options.Callback(color, api.Alpha)
        end
    end

    function api:SetAlpha(alpha, silent)
        api.Alpha = clamp(tonumber(alpha) or 1, 0, 1)
        paintSwatch()
        if options.AlphaFlag then
            window.Flags[options.AlphaFlag] = api.Alpha
        end
        if not silent and options.Callback then
            options.Callback(api.Color, api.Alpha)
        end
    end

    swatch.MouseButton1Click:Connect(function()
        window:OpenColorPicker(swatch, function(color, alpha)
            api:Set(color, true)
            api:SetAlpha(alpha)
        end, {Alpha = options.Alpha ~= false, DefaultAlpha = api.Alpha})
    end)
    paintSwatch()
    if options.AlphaFlag then
        window.Flags[options.AlphaFlag] = api.Alpha
    end
    if options.Flag then
        window.Flags[options.Flag] = api.Color
    end
    return api
end

function Settings:Dropdown(options)
    options = options or {}
    local window = self.Window
    local entry, frame = self:_Base("SettingDropdown", 20)
    local choices = options.Options or {}
    local api = {Flag = options.Flag, Value = options.Default}
    if options.Multi then
        if type(api.Value) ~= "table" then
            api.Value = api.Value and {api.Value} or {}
        end
    end

    local header = create("TextButton", {
        Name = "Header",
        BackgroundColor3 = window.Theme.Row,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Control)}, header)
    local prefix = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name and (options.Name .. " ") or "",
        TextSize = 10,
        TextColor3 = window.Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(5, 0),
        Size = UDim2.new(0.42, -5, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    }, header)
    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "",
        TextSize = 10,
        TextColor3 = window.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -18, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    }, header)
    local arrow = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "v",
        TextSize = 10,
        TextColor3 = window.Theme.Muted,
        Position = UDim2.new(1, -13, 0, 0),
        Size = UDim2.fromOffset(11, 20),
        ZIndex = 4,
    }, header)

    local list = create("Frame", {
        Name = "Options",
        BackgroundColor3 = window.Theme.Window,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 0),
        Visible = false,
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, list)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 2),
    }, list)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
    }, list)

    local optionButtons = {}
    local open = false

    local function selectedText()
        if options.Multi then
            local picked = {}
            for _, item in ipairs(type(api.Value) == "table" and api.Value or {}) do
                picked[#picked + 1] = tostring(item)
            end
            if #picked == 0 then
                return "None"
            end
            return shorten(table.concat(picked, ", "), 16)
        end
        return api.Value ~= nil and tostring(api.Value) or "None"
    end

    local function paint(instant)
        valueLabel.Text = selectedText()
        for index, button in ipairs(optionButtons) do
            local active
            if options.Multi then
                active = type(api.Value) == "table" and table.find(api.Value, choices[index]) ~= nil
            else
                active = api.Value == choices[index]
            end
            applyColor(button, "TextColor3", active and window.Theme.Accent or window.Theme.Text, instant, 0.14)
        end
    end

    local function listHeight()
        if #choices == 0 then
            return 0
        end
        return #choices * 15 + (#choices - 1) + 4
    end

    local function layoutList(instant)
        local height = listHeight()
        list.Visible = open
        local target = UDim2.new(1, 0, 0, open and height or 0)
        local frameTarget = UDim2.new(1, 0, 0, 20 + (open and (height + 2) or 0))
        if instant then
            list.Size = target
            frame.Size = frameTarget
        else
            tween(list, {Size = target}, T.Layout)
            tween(frame, {Size = frameTarget}, T.Layout)
        end
        entry.Height = 20 + (open and (height + 2) or 0)
        self:_Resize()
    end

    for index, choice in ipairs(choices) do
        local button = create("TextButton", {
            Name = "Choice",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = " " .. tostring(choice),
            Font = window.Font,
            TextSize = 10,
            TextColor3 = window.Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Size = UDim2.new(1, 0, 0, 15),
            LayoutOrder = index,
            ZIndex = 4,
        }, list)
        optionButtons[index] = button
        create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, button)
        button.MouseEnter:Connect(function()
            button.BackgroundTransparency = 0.8
            button.BackgroundColor3 = window.Theme.Hover
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundTransparency = 1
        end)
        button.MouseButton1Click:Connect(function()
            if options.Multi then
                local current = {}
                for _, item in ipairs(type(api.Value) == "table" and api.Value or {}) do
                    current[#current + 1] = item
                end
                local at = table.find(current, choice)
                if at then
                    table.remove(current, at)
                else
                    current[#current + 1] = choice
                end
                api.Value = current
            else
                api.Value = choice
                open = false
                layoutList(false)
            end
            if options.Flag then
                window.Flags[options.Flag] = api.Value
            end
            paint(false)
            if options.Callback then
                options.Callback(api.Value)
            end
        end)
    end

    header.MouseButton1Click:Connect(function()
        open = not open
        layoutList(false)
    end)

    window:_Bind(frame, function(themeNow, instant)
        applyColor(header, "BackgroundColor3", themeNow.Row, instant, 0.2)
        applyColor(prefix, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(valueLabel, "TextColor3", themeNow.Text, instant, 0.2)
        applyColor(arrow, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(list, "BackgroundColor3", themeNow.Window, instant, 0.2)
        paint(instant)
    end)

    function api:Get()
        return api.Value
    end

    function api:Set(value, silent)
        api.Value = value
        if options.Multi and type(value) ~= "table" then
            api.Value = value and {value} or {}
        end
        if options.Flag then
            window.Flags[options.Flag] = api.Value
        end
        paint(false)
        if not silent and options.Callback then
            options.Callback(api.Value)
        end
    end

    if options.Flag then
        window.Flags[options.Flag] = api.Value
    end
    paint(true)
    return api
end

--==========================================================================--
-- Tab API
--==========================================================================--

local rowOrder = 0

function Tab:_Track(row)
    rowOrder = rowOrder + 1
    row.Slot.LayoutOrder = rowOrder
    row.LayoutOrder = rowOrder
    if self.EmptyLabel then
        self.EmptyLabel.Visible = false
    end
    self:_SyncHeight()
    return row
end

-- The scroll canvas is sized from logical row heights, so it already accounts
-- for a settings block that is still animating open.
function Tab:_SyncHeight(query)
    local total = 0
    local shown = 0
    local gap = M.RowGap
    for _, row in ipairs(self.Rows) do
        if row.Visible then
            shown = shown + 1
            total = total + (row.SectionHeight or M.RowHeight) + row:_Extra() + gap
        end
    end
    total = math.max(total - (shown > 0 and gap or 0), 0)
    self.Content.Size = UDim2.new(1, 0, 0, total)
    self.Scroll.CanvasSize = UDim2.new(0, 0, 0, total + M.Inset * 2)
    self.ContentValue = total
    if self.EmptyLabel then
        self.EmptyLabel.Visible = shown == 0 and not self.Window.Options.NoEmptyState
        self.EmptyLabel.Text = (query ~= "" and query) and ("No results for \"" .. query .. "\"") or "Nothing here"
    end
end

function Tab:Filter(query)
    local matched = 0
    for _, row in ipairs(self.Rows) do
        local haystack = (row.Name .. " " .. tostring(row.Hint or "")):lower()
        local visible = query == "" or haystack:find(query, 1, true) ~= nil
        row:SetVisible(visible)
        if visible then
            matched = matched + 1
        else
            if row.SettingsOpen then
                row:ToggleSettings(false)
            end
        end
    end
    self:_SyncHeight(query)
    return matched
end

function Tab:AddToggle(options)
    if type(options) == "string" then
        options = {Name = options}
    end
    options = options or {}
    local window = self.Window
    local row = newRow(self, options.Name or "Toggle", options)
    local value = options.Default == true
    row.Flag = options.Flag

    local function display()
        if value and options.OnText then
            row:SetValueText(options.OnText)
        elseif not value and options.OffText then
            row:SetValueText(options.OffText)
        else
            row:SetValueText(options.Display)
        end
    end

    local function paint(instant)
        row.OnState = value
        row:RefreshVisual(instant)
    end

    row.OnClick = function()
        row:SetValue(not value)
    end

    function row:Get()
        return value
    end

    function row:SetValue(newValue, silent)
        newValue = newValue and true or false
        if newValue == value then
            return
        end
        value = newValue
        if options.Flag then
            window.Flags[options.Flag] = value
        end
        display()
        paint(false)
        if not silent and options.Callback then
            options.Callback(value)
        end
    end
    row.Set = row.SetValue
    row.ApplyValue = function(_, newValue)
        row:SetValue(newValue, true)
    end
    row.ToggleValue = function()
        row:SetValue(not value)
    end

    window:_Bind(row.Frame, function(_, instant)
        paint(instant)
    end)
    if options.Flag then
        window.Flags[options.Flag] = value
    end
    display()
    self:_Track(row)
    row:RefreshVisual(true)
    return row
end

function Tab:AddButton(options)
    if type(options) == "string" then
        options = {Name = options}
    end
    options = options or {}
    local row = newRow(self, options.Name or "Button", options)
    row.OnClick = function()
        if options.Callback then
            options.Callback()
        end
    end
    self:_Track(row)
    return row
end

function Tab:AddSlider(options)
    options = options or {}
    local window = self.Window
    local row = newRow(self, options.Name or "Slider", options)
    local minimum = options.Min or 0
    local maximum = options.Max or 100
    local step = options.Step or 1
    local value = clamp(options.Default or minimum, minimum, maximum)
    row.Flag = options.Flag

    local function format(number)
        if step < 1 then
            return string.format("%.2f", number)
        end
        return tostring(math.floor(number + 0.5))
    end

    row:SetValueText(format(value) .. (options.Suffix or ""))
    row.OnState = (value ~= minimum)
    row.OnClick = function() end
    row:RefreshVisual(true)

    local function round(number)
        return clamp(math.floor((number - minimum) / step + 0.5) * step + minimum, minimum, maximum)
    end

    function row:Get()
        return value
    end

    function row:SetValue(newValue, silent)
        newValue = round(tonumber(newValue) or value)
        if newValue == value then
            return
        end
        value = newValue
        row:SetValueText(format(value) .. (options.Suffix or ""))
        if options.Flag then
            window.Flags[options.Flag] = value
        end
        if not silent and options.Callback then
            options.Callback(value)
        end
    end
    row.Set = row.SetValue
    row.ApplyValue = function(_, newValue)
        row:SetValue(newValue, true)
    end

    row.Frame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if row.Locked then
            return
        end
        local absolute = row.Box.AbsolutePosition
        local size = row.Box.AbsoluteSize
        local function move(position)
            local alpha = clamp((position.X - absolute.X) / math.max(size.X, 1), 0, 1)
            row:SetValue(minimum + alpha * (maximum - minimum))
        end
        move(input.Position)
        beginDrag(input, move)
    end)

    if options.Flag then
        window.Flags[options.Flag] = value
    end
    self:_Track(row)
    return row
end

function Tab:AddInput(options)
    options = options or {}
    local window = self.Window
    local row = newRow(self, options.Name or "Input", options)
    row.Flag = options.Flag
    local box = create("TextBox", {
        Name = "Field",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Default or "",
        PlaceholderText = options.Placeholder or "",
        PlaceholderColor3 = window.Theme.Muted,
        TextSize = 12,
        TextColor3 = window.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        ClearTextOnFocus = false,
        Position = UDim2.new(0, 40, 0, 0),
        Size = UDim2.new(1, -46, 1, 0),
        ZIndex = 4,
    }, row.Frame)
    row.Label.Size = UDim2.new(0.5, -M.Inset, 1, 0)
    row.OnClick = function()
        box:CaptureFocus()
    end

    window:_Bind(box, function(theme, instant)
        applyColor(box, "TextColor3", theme.Text, instant, 0.2)
        applyColor(box, "PlaceholderColor3", theme.Muted, instant, 0.2)
    end)

    function row:Get()
        return box.Text
    end

    function row:SetValue(text, silent)
        box.Text = tostring(text or "")
        row.OnState = box.Text ~= ""
        row:RefreshVisual(false)
        if options.Flag then
            window.Flags[options.Flag] = box.Text
        end
        if not silent and options.Callback then
            options.Callback(box.Text)
        end
    end
    row.Set = row.SetValue
    row.ApplyValue = function(_, newValue)
        row:SetValue(newValue, true)
    end

    box.FocusLost:Connect(function()
        row:SetValue(box.Text)
    end)
    if options.Flag then
        window.Flags[options.Flag] = box.Text
    end
    self:_Track(row)
    return row
end

function Tab:AddKeybind(options)
    options = options or {}
    local window = self.Window
    local row = newRow(self, options.Name or "Keybind", options)
    row.Flag = options.Flag
    local key = options.Default
    local bind = {Key = key, Callback = options.Callback}
    window.Keybinds[#window.Keybinds + 1] = bind
    row:SetValueText(key and key.Name or "None")
    row.OnState = key ~= nil
    row:RefreshVisual(true)
    row.OnClick = function()
        row:SetValueText("...")
        window.Capturing = function(input)
            if input.KeyCode == Enum.KeyCode.Escape then
                key = nil
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                key = input.KeyCode
            end
            bind.Key = key
            row.OnState = key ~= nil
            row:RefreshVisual(false)
            row:SetValueText(key and key.Name or "None")
            if options.Flag then
                window.Flags[options.Flag] = key
            end
            if options.Changed then
                options.Changed(key)
            end
        end
    end

    function row:Get()
        return key
    end

    function row:SetValue(newKey, silent)
        key = newKey
        bind.Key = newKey
        row:SetValueText(key and key.Name or "None")
        row.OnState = key ~= nil
        row:RefreshVisual(false)
        if options.Flag then
            window.Flags[options.Flag] = key
        end
        if not silent and options.Changed then
            options.Changed(key)
        end
    end
    row.Set = row.SetValue
    row.ApplyValue = function(_, newValue)
        if type(newValue) == "string" then
            newValue = Enum.KeyCode[newValue]
        end
        row:SetValue(newValue, true)
    end

    if options.Flag then
        window.Flags[options.Flag] = key
    end
    self:_Track(row)
    return row
end

function Tab:AddColorPicker(options)
    options = options or {}
    local window = self.Window
    local row = newRow(self, options.Name or "Color", options)
    row.Flag = options.Flag
    local color = options.Default or Color3.fromRGB(255, 255, 255)

    local swatch = create("TextButton", {
        Name = "Swatch",
        BackgroundColor3 = color,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        Position = UDim2.new(1, -M.Inset - 26, 0, 3),
        Size = UDim2.fromOffset(26, 14),
        ZIndex = 4,
    }, row.Frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, swatch)

    local alpha = options.DefaultAlpha or 1
    local api = {}
    row.OnClick = function() end

    function row:Get()
        return color
    end

    function row:GetAlpha()
        return alpha
    end

    local function paintSwatch()
        swatch.BackgroundColor3 = color
        swatch.BackgroundTransparency = 1 - alpha
    end

    function row:SetValue(newColor, silent)
        color = newColor
        paintSwatch()
        if options.Flag then
            window.Flags[options.Flag] = newColor
        end
        if not silent and options.Callback then
            options.Callback(newColor, alpha)
        end
    end

    function row:SetAlpha(value, silent)
        alpha = clamp(tonumber(value) or 1, 0, 1)
        paintSwatch()
        if options.AlphaFlag then
            window.Flags[options.AlphaFlag] = alpha
        end
        if not silent and options.Callback then
            options.Callback(color, alpha)
        end
    end
    row.Set = row.SetValue
    row.ApplyValue = function(_, newValue)
        if type(newValue) == "string" then
            newValue = Color3.fromHex(newValue)
        end
        row:SetValue(newValue, true)
    end

    swatch.MouseButton1Click:Connect(function()
        window:OpenColorPicker(swatch, function(newColor, newAlpha)
            row:SetValue(newColor, true)
            row:SetAlpha(newAlpha)
        end, {Alpha = options.Alpha ~= false, DefaultAlpha = alpha})
    end)
    paintSwatch()
    api.Swatch = swatch
    if options.AlphaFlag then
        window.Flags[options.AlphaFlag] = alpha
    end

    if options.Flag then
        window.Flags[options.Flag] = color
    end
    self:_Track(row)
    return row
end

function Tab:AddSection(name, options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local row = newRow(self, name or "Section", options)
    row.IsSection = true
    row.Slot.Size = UDim2.new(1, 0, 0, 24)
    row.Frame.Size = UDim2.new(1, 0, 0, 24)
    row.SectionHeight = 24
    row.Frame.AutoButtonColor = false
    row.Box.Visible = false
    row.Dots.Visible = false
    row.Label.Position = UDim2.fromOffset(0, 8)
    row.Label.Size = UDim2.new(1, 0, 0, 14)
    row.Label.TextSize = 12
    row.Label.TextXAlignment = Enum.TextXAlignment.Left
    row.Label.Text = (name or "Section"):upper()
    row.Label.TextColor3 = theme.Muted
    local line = create("Frame", {
        Name = "Rule",
        BackgroundColor3 = theme.Border,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 2,
    }, row.Frame)
    window:_Bind(line, function(themeNow, instant)
        applyColor(line, "BackgroundColor3", themeNow.Border, instant, 0.2)
        applyColor(row.Label, "TextColor3", themeNow.Muted, instant, 0.2)
    end)
    row.OnClick = function() end
    self:_Track(row)
    return row
end

function Tab:AddLabel(text)
    local row = newRow(self, text or "", {})
    row.Label.TextSize = 12
    row.Label.TextColor3 = self.Window.Theme.Text
    row.Box.Visible = false
    row.Label.Size = UDim2.new(1, 0, 1, 0)
    row.Label.Position = UDim2.fromOffset(0, 0)
    row.OnClick = function() end
    self:_Track(row)
    return row
end

function Tab:AddDropdown(options)
    options = options or {}
    local window = self.Window
    local theme = window.Theme
    local row = newRow(self, options.Name or "Dropdown", options)
    row:SetValueText(options.Default or (options.Multi and "None") or "None")

    local choices = options.Options or {}
    local value = options.Default
    row.Dots.Visible = true
    row.SettingsHeight = 0

    -- The dropdown list expands in the row's own list holder, which pushes the
    -- following rows down with the same animation used by settings blocks.
    local listFrame = create("Frame", {
        Name = "List",
        BackgroundColor3 = theme.Window,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 2),
        Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 3,
    }, row.ListHolder)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Control)}, listFrame)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
    }, listFrame)
    local buttons = {}

    row.OnClick = function()
        row.ListOpen = not row.ListOpen
        row.ListHeight = row.ListOpen and (#choices * 16 + 6) or 0
        listFrame.Position = UDim2.fromOffset(0, row.ListOpen and 0 or 2)
        if row.ListOpen then
            tween(listFrame, {Position = UDim2.fromOffset(0, 2)}, T.Expand)
        end
        if row.ListOpen and row.SettingsOpen then
            row:ToggleSettings(false)
        end
        row:_ApplyHeight(false)
        row.Tab:_SyncHeight()
        row:RefreshVisual()
    end

    local function paint()
        local text
        if options.Multi then
            local picked = {}
            for _, item in ipairs(type(value) == "table" and value or {}) do
                picked[#picked + 1] = tostring(item)
            end
            text = #picked > 0 and table.concat(picked, ", ") or "None"
        else
            text = value ~= nil and tostring(value) or "None"
        end
        row:SetValueText(text)
        for index, button in ipairs(buttons) do
            local active
            if options.Multi then
                active = type(value) == "table" and table.find(value, choices[index]) ~= nil
            else
                active = value == choices[index]
            end
            applyColor(button, "TextColor3", active and theme.Accent or theme.Text, false, 0.12)
            button.Text = (active and "> " or "  ") .. tostring(choices[index])
        end
    end

    for index, choice in ipairs(choices) do
        local button = create("TextButton", {
            Name = "Choice",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "  " .. tostring(choice),
            Font = window.Font,
            TextSize = 11,
            TextColor3 = theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(1, -4, 0, 15),
            Position = UDim2.fromOffset(2, 0),
            LayoutOrder = index,
            ZIndex = 4,
        }, listFrame)
        buttons[index] = button
        create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, button)
        button.MouseEnter:Connect(function()
            applyColor(button, "BackgroundColor3", theme.Hover, false, 0.1)
            button.BackgroundTransparency = 0.5
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundTransparency = 1
        end)
        button.MouseButton1Click:Connect(function()
            if options.Multi then
                local current = {}
                for _, item in ipairs(type(value) == "table" and value or {}) do
                    current[#current + 1] = item
                end
                local at = table.find(current, choice)
                if at then
                    table.remove(current, at)
                else
                    current[#current + 1] = choice
                end
                value = current
            else
                value = choice
                row.ListOpen = false
                row.ListHeight = 0
                row:_ApplyHeight(false)
                row.Tab:_SyncHeight()
            end
            if options.Flag then
                window.Flags[options.Flag] = value
            end
            paint()
            if options.Callback then
                options.Callback(value)
            end
        end)
    end

    window:_Bind(listFrame, function(themeNow, instant)
        applyColor(listFrame, "BackgroundColor3", themeNow.Window, instant, 0.2)
    end)

    function row:Get()
        return value
    end

    function row:SetValue(newValue, silent)
        value = newValue
        if options.Flag then
            window.Flags[options.Flag] = value
        end
        paint()
        if not silent and options.Callback then
            options.Callback(value)
        end
    end
    row.Set = row.SetValue
    row.ApplyValue = function(_, newValue)
        row:SetValue(newValue, true)
    end

    if options.Flag then
        window.Flags[options.Flag] = value
    end
    paint()
    self:_Track(row)
    return row
end

--==========================================================================--
-- Color picker popup
--==========================================================================--

function Minecraft:ClosePopup(instant)
    if not self.Popup then
        return
    end
    local popup = self.Popup
    self.Popup = nil
    self.PopupLayer.Visible = false
    if instant then
        popup.Panel.Visible = false
    else
        tween(popup.Panel, {Size = UDim2.fromOffset(popup.Width, popup.Height * 0.94), BackgroundTransparency = 1}, T.FadeFast)
    end
    task.delay(instant and 0 or 0.14, function()
        if not self.Popup and isAlive(popup.Panel) then
            popup.Panel.Visible = false
        end
    end)
end

-- Converts a GUI-space position into coordinates inside the (scaled) root.
function Minecraft:_LocalPoint(absolutePosition)
    local rootPosition = self.Root.AbsolutePosition
    local scale = (self.ScaleObject and self.ScaleObject.Scale) or 1
    return (absolutePosition.X - rootPosition.X) / scale, (absolutePosition.Y - rootPosition.Y) / scale
end

function Minecraft:_Viewport()
    local ok, size = pcall(function()
        local camera = workspace.CurrentCamera
        return camera and camera.ViewportSize or nil
    end)
    if ok and size then
        return size
    end
    return Vector2.new(1280, 720)
end

-- Places a popup of `width` x `height` next to its anchor, flipping above/below
-- and clamping inside the screen so it never spawns off-window.
function Minecraft:_PlacePopup(panel, anchor, width, height)
    local scale = (self.ScaleObject and self.ScaleObject.Scale) or 1
    local rootPosition = self.Root.AbsolutePosition
    local viewport = self:_Viewport()
    local anchorX = anchor.AbsolutePosition.X
    local anchorY = anchor.AbsolutePosition.Y
    local anchorW = anchor.AbsoluteSize.X
    local anchorH = anchor.AbsoluteSize.Y

    -- Prefer below-left of the anchor; flip up when there is no room below.
    local screenY = (anchorY + anchorH + height * scale + 8)
    local below = screenY <= viewport.Y - 8
    local y = below and (anchorY + anchorH + 6) or (anchorY - height * scale - 6)
    local x = anchorX + anchorW - width * scale

    local rootX = rootPosition.X
    local rootY = rootPosition.Y
    local maxX = rootX + self.Root.AbsoluteSize.X - width * scale - 4
    local maxY = viewport.Y - height * scale - 6
    x = math.clamp(x, rootX + 4, math.max(rootX + 4, maxX))
    y = math.clamp(y, 6, math.max(6, maxY))

    panel.AnchorPoint = Vector2.new(0, 0)
    panel.Position = UDim2.fromOffset((x - rootX) / scale, (y - rootY) / scale)
end

-- Colour picker.
-- The saturation/value field is drawn with two flat overlays instead of stacked
-- UIGradients: a white layer whose *alpha* ramps left->right and a black layer
-- whose alpha ramps bottom->top. That keeps the top-right corner pure white (no
-- transparent hole) and is what every real picker looks like.
function Minecraft:OpenColorPicker(anchor, callback, options)
    options = options or {}
    if self.Popup then
        self:ClosePopup(true)
    end
    local theme = self.Theme
    local withAlpha = options.Alpha ~= false
    self.PopupLayer.Visible = true

    local width = 196
    local fieldH = 104
    local height = 8 + fieldH + 6 + 14 + (withAlpha and (6 + 12) or 0) + 8 + 18 + 8 + 16 + 8

    local panel = create("Frame", {
        Name = "ColorPopup",
        BackgroundColor3 = theme.Popup,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(width, height),
        ZIndex = 70,
    }, self.PopupLayer)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Control)}, panel)

    local fieldW = width - 16

    -- Saturation / value field ------------------------------------------------
    local sv = create("Frame", {
        Name = "SV",
        BackgroundColor3 = Color3.fromRGB(255, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.fromOffset(fieldW, fieldH),
        ClipsDescendants = true,
        ZIndex = 71,
    }, panel)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, sv)

    -- White on the left, fully transparent on the right => saturation.
    local whiteLayer = create("Frame", {
        Name = "White",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 72,
    }, sv)
    create("UIGradient", {
        Rotation = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, whiteLayer)

    -- Transparent on top, black at the bottom => value.
    local blackLayer = create("Frame", {
        Name = "Black",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 73,
    }, sv)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, blackLayer)

    local cursor = create("Frame", {
        Name = "Cursor",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(13, 13),
        ZIndex = 76,
    }, sv)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, cursor)
    local cursorInner = create("Frame", {
        Name = "Inner",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(8, 8),
        ZIndex = 77,
    }, cursor)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, cursorInner)

    -- Hue strip: six flat segments, no multi-keypoint gradient (those are the
    -- ones that render red/black/red on some clients).
    local hueY = 8 + fieldH + 6
    local hue = create("Frame", {
        Name = "Hue",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, hueY),
        Size = UDim2.fromOffset(fieldW, 14),
        ClipsDescendants = true,
        ZIndex = 71,
    }, panel)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, hue)
    local hueColors = {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(255, 255, 0),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(0, 255, 255),
        Color3.fromRGB(0, 0, 255),
        Color3.fromRGB(255, 0, 255),
        Color3.fromRGB(255, 0, 0),
    }
    local segments = #hueColors - 1
    local segWidth = fieldW / segments
    for index = 1, segments do
        local segment = create("Frame", {
            Name = "Segment",
            BackgroundColor3 = hueColors[index],
            BorderSizePixel = 0,
            Position = UDim2.fromOffset((index - 1) * segWidth, 0),
            Size = UDim2.fromOffset(segWidth + 1, 14),
            ZIndex = 72,
        }, hue)
        create("UIGradient", {
            Color = ColorSequence.new(hueColors[index], hueColors[index + 1]),
        }, segment)
    end
    local marker = create("Frame", {
        Name = "Marker",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(4, 18),
        ZIndex = 74,
    }, hue)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, marker)

    -- Alpha strip ------------------------------------------------------------
    local alphaBar, alphaFill, alphaMarker
    if withAlpha then
        local alphaY = hueY + 14 + 6
        -- Checkerboard so transparency is readable.
        alphaBar = create("Frame", {
            Name = "AlphaBar",
            BackgroundColor3 = Color3.fromRGB(190, 190, 190),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(8, alphaY),
            Size = UDim2.fromOffset(fieldW, 12),
            ClipsDescendants = true,
            ZIndex = 71,
        }, panel)
        create("UICorner", {CornerRadius = UDim.new(1, 0)}, alphaBar)
        for row = 0, 1 do
            for column = 0, 11 do
                if (row + column) % 2 == 0 then
                    local square = create("Frame", {
                        Name = "Check",
                        BackgroundColor3 = Color3.fromRGB(150, 150, 150),
                        BorderSizePixel = 0,
                        Position = UDim2.fromOffset(column * 16, row * 6),
                        Size = UDim2.fromOffset(16, 6),
                        ZIndex = 72,
                    }, alphaBar)
                    square.BorderSizePixel = 0
                end
            end
        end
        alphaFill = create("Frame", {
            Name = "AlphaFill",
            BackgroundColor3 = Color3.fromRGB(255, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 73,
        }, alphaBar)
        create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, alphaFill)
        alphaMarker = create("Frame", {
            Name = "AlphaMarker",
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(4, 16),
            ZIndex = 74,
        }, alphaBar)
        create("UICorner", {CornerRadius = UDim.new(1, 0)}, alphaMarker)
    end

    -- Presets ----------------------------------------------------------------
    local presetsY = (withAlpha and (hueY + 14 + 6 + 12 + 8)) or (hueY + 14 + 8)
    local presets = {}
    local presetColors = {
        Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(255, 96, 96),
        Color3.fromRGB(255, 196, 96),
        Color3.fromRGB(140, 235, 140),
        Color3.fromRGB(112, 178, 255),
        Color3.fromRGB(186, 152, 255),
        Color3.fromRGB(255, 120, 210),
        Color3.fromRGB(60, 60, 72),
    }
    local swatchSize = (fieldW - 7 * 6) / 8
    for index, color in ipairs(presetColors) do
        local preset = create("TextButton", {
            Name = "Preset",
            BackgroundColor3 = color,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
            Position = UDim2.fromOffset(8 + (index - 1) * (swatchSize + 6), presetsY),
            Size = UDim2.fromOffset(swatchSize, 18),
            ZIndex = 72,
        }, panel)
        create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, preset)
        presets[index] = preset
        preset.MouseButton1Click:Connect(function()
            local h, sat, v = color:ToHSV()
            state.H, state.S, state.V = h, sat, v
            state:Apply(true)
        end)
    end

    -- Hex readout ------------------------------------------------------------
    local hex = create("TextButton", {
        Name = "Hex",
        BackgroundColor3 = theme.Track,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        Font = self.Font,
        TextSize = 11,
        TextColor3 = theme.Text,
        Position = UDim2.fromOffset(8, presetsY + 18 + 8),
        Size = UDim2.fromOffset(fieldW, 16),
        ZIndex = 72,
    }, panel)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, hex)

    local state = {
        H = 0, S = 1, V = 1, A = options.DefaultAlpha or 1,
        Panel = panel, Width = width, Height = height,
        Window = self, Callback = callback, AlphaEnabled = withAlpha,
    }

    local function hexOf(color, alpha)
        local text = string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
        if withAlpha then
            text = string.format("%s%02X", text, math.floor((alpha or 1) * 255 + 0.5))
        end
        return text
    end

    function state:Apply(instant, silent)
        local color = Color3.fromHSV(self.H, self.S, self.V)
        sv.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
        cursor.Position = UDim2.fromScale(self.S, 1 - self.V)
        marker.Position = UDim2.new(self.H, 0, 0.5, 0)
        if alphaFill then
            alphaFill.BackgroundColor3 = color
        end
        if alphaMarker then
            alphaMarker.Position = UDim2.new(self.A, 0, 0.5, 0)
        end
        hex.Text = hexOf(color, self.A)
        self.LastColor = color
        if callback and not silent then
            callback(color, self.A)
        end
    end

    function state:SetAlpha(value, silent)
        self.A = clamp(tonumber(value) or 1, 0, 1)
        if not silent then
            self:Apply(true)
        else
            if alphaMarker then
                alphaMarker.Position = UDim2.new(self.A, 0, 0.5, 0)
            end
            if alphaFill then
                alphaFill.BackgroundColor3 = Color3.fromHSV(self.H, self.S, self.V)
            end
        end
    end

    local function bindDrag(hit, target, onMove)
        hit.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local function move(position)
                local absolute = target.AbsolutePosition
                local size = target.AbsoluteSize
                onMove(clamp((position.X - absolute.X) / math.max(size.X, 1), 0, 1),
                    clamp((position.Y - absolute.Y) / math.max(size.Y, 1), 0, 1))
            end
            move(input.Position)
            beginDrag(input, move)
        end)
    end

    local svHit = create("TextButton", {
        Name = "SVHit", Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
        BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 75,
    }, sv)
    bindDrag(svHit, sv, function(x, y)
        state.S = x
        state.V = 1 - y
        state:Apply(true)
    end)

    local hueHit = create("TextButton", {
        Name = "HueHit", Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
        BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 75,
    }, hue)
    bindDrag(hueHit, hue, function(x)
        state.H = math.min(x, 0.9999)
        state:Apply(true)
    end)

    if alphaBar then
        local alphaHit = create("TextButton", {
            Name = "AlphaHit", Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
            BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 75,
        }, alphaBar)
        bindDrag(alphaHit, alphaBar, function(x)
            state:SetAlpha(x)
        end)
    end

    hex.MouseButton1Click:Connect(function()
        local copier = rawget(_G, "setclipboard") or rawget(_G, "toclipboard")
        if copier then
            pcall(copier, hex.Text)
        end
        local previous = hex.Text
        hex.Text = "copied"
        task.delay(0.6, function()
            if isAlive(hex) and hex.Text == "copied" then
                hex.Text = previous
            end
        end)
    end)

    local current = anchor.BackgroundColor3
    local h, sat, v = current:ToHSV()
    state.H, state.S, state.V = h, sat, v
    state:Apply(true, true)

    self.Popup = state
    self:_Bind(panel, function(themeNow, instant)
        applyColor(panel, "BackgroundColor3", themeNow.Popup, instant, 0.2)
        applyColor(hex, "BackgroundColor3", themeNow.Track, instant, 0.2)
        applyColor(hex, "TextColor3", themeNow.Text, instant, 0.2)
    end)

    self:_PlacePopup(panel, anchor, width, height)
    panel.Visible = true
    panel.Size = UDim2.fromOffset(width, height * 0.94)
    tween(panel, {Size = UDim2.fromOffset(width, height)}, T.Pop)
    return state
end

--==========================================================================--
-- Convenience
--==========================================================================--

-- Adds several options at once: window:AddToggles(tab, {"Air Jump", "Flight"})
function Minecraft:AddToggles(tab, names, options)
    options = options or {}
    local added = {}
    for _, name in ipairs(names) do
        local merged = {}
        for key, value in pairs(options) do
            merged[key] = value
        end
        merged.Name = name
        added[#added + 1] = tab:AddToggle(merged)
    end
    return added
end

function Minecraft:GetFlag(flag)
    return self.Flags[flag]
end

function Minecraft:SetFlag(flag, value)
    self.Flags[flag] = value
end

function Minecraft:SaveConfig()
    local data = {}
    for flag, value in pairs(self.Flags) do
        -- typeof() is the Roblox-aware type check; type() reports Color3 as userdata.
        if typeof(value) == "Color3" then
            data[flag] = {__color = true, value = value:ToHex()}
        elseif typeof(value) == "EnumItem" then
            data[flag] = {__enum = true, Name = value.Name}
        elseif type(value) == "table" then
            local copy = {}
            for index, item in ipairs(value) do
                copy[index] = item
            end
            data[flag] = copy
        else
            data[flag] = value
        end
    end
    data.__theme = self.ThemeIndex
    return data
end

function Minecraft:LoadConfig(data)
    if type(data) ~= "table" then
        return
    end
    for flag, value in pairs(data) do
        if flag == "__theme" then
            self:SetTheme(value)
        elseif type(value) == "table" and value.__color then
            local parsed = Color3.fromHex(value.value)
            self.Flags[flag] = parsed
        elseif type(value) == "table" and value.__enum then
            self.Flags[flag] = Enum.KeyCode[value.Name]
        else
            self.Flags[flag] = value
        end
    end
    for _, row in ipairs(self.Rows or {}) do
        if row.ApplyFlag then
            row:ApplyFlag(self.Flags)
        end
    end
end

return Minecraft
