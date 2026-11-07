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
Minecraft.Version = "1.0.0"

local Tab = {}
Tab.__index = Tab

local Row = {}
Row.__index = Row

local Settings = {}
Settings.__index = Settings

-- Layout metrics. Every panel uses the same width and height, so the menu always
-- reads as one even row of columns no matter how many tabs are added.
local M = {
    PanelWidth = 178,
    PanelHeight = 430,
    Gap = 8,
    Padding = 14,
    Header = 28,
    Title = 34,
    RowHeight = 20,
    RowGap = 2,
    Inset = 6,
    Search = 24,
}
Minecraft.Metrics = M

local T = {
    Layout = TweenInfo.new(0.24, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
    Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Pop = TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Color = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Fade = TweenInfo.new(0.16, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
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

-- Six themes. Each one derives its panel shades from a single base color, which
-- keeps every theme consistent and makes the theme tween cheap.
local THEMES = {}
local function addTheme(name, base, accent, text, muted)
    THEMES[#THEMES + 1] = {
        Name = name,
        Window = shade(base, -0.58),
        Panel = base,
        Header = shade(base, 0.07),
        Border = shade(base, -0.42),
        Row = shade(base, 0.12),
        RowStroke = shade(base, 0.22),
        Hover = shade(base, 0.24),
        On = mix(base, accent, 0.32),
        Text = text,
        Muted = muted,
        Accent = accent,
        Popup = shade(base, 0.04),
        Track = shade(base, -0.12),
    }
end
addTheme("Midnight", rgb(37, 28, 54), rgb(186, 152, 255), rgb(219, 213, 235), rgb(146, 138, 170))
addTheme("Slate", rgb(27, 37, 51), rgb(112, 178, 255), rgb(207, 219, 235), rgb(136, 156, 180))
addTheme("Amethyst", rgb(48, 30, 58), rgb(255, 158, 226), rgb(232, 214, 232), rgb(170, 146, 170))
addTheme("Crimson", rgb(48, 26, 30), rgb(255, 122, 112), rgb(235, 214, 212), rgb(175, 143, 140))
addTheme("Emerald", rgb(22, 44, 33), rgb(126, 226, 168), rgb(212, 232, 220), rgb(140, 168, 152))
addTheme("Amber", rgb(48, 38, 22), rgb(255, 197, 106), rgb(236, 224, 202), rgb(176, 160, 132))
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
local function collectFade(object, list)
    list = list or {}
    for _, property in ipairs({"BackgroundTransparency", "TextTransparency"}) do
        local ok, value = pcall(function()
            return object[property]
        end)
        if ok and type(value) == "number" then
            list[#list + 1] = {Object = object, Property = property, Base = value}
        end
    end
    if pcall(function()
        return object.Transparency
    end) then
        local ok, value = pcall(function()
            return object.Transparency
        end)
        if ok and type(value) == "number" then
            list[#list + 1] = {Object = object, Property = "Transparency", Base = value}
        end
    end
    local ok, children = pcall(function()
        return object:GetChildren()
    end)
    if ok then
        for _, child in ipairs(children) do
            collectFade(child, list)
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
                    item.Object[item.Property] = target
                else
                    tween(item.Object, {[item.Property] = target}, T.Fade)
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
        Size = UDim2.fromOffset(M.Padding * 2 + M.PanelWidth, M.Padding * 2 + M.Header + M.PanelHeight),
        ZIndex = 1,
    }, window.Gui)
    if window.Root.ClassName == "CanvasGroup" then
        window.Root.GroupTransparency = 0
    end

    window.Shadow = create("Frame", {
        Name = "Shadow",
        BackgroundColor3 = rgb(0, 0, 0),
        BackgroundTransparency = 0.62,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(-6, -6),
        Size = UDim2.new(1, 12, 1, 12),
        ZIndex = 0,
    }, window.Root)
    create("UICorner", {CornerRadius = UDim.new(0, 4)}, window.Shadow)

    window.ScaleObject = create("UIScale", {Scale = window.Scale}, window.Root)

    window.Header = create("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, M.Header),
        ZIndex = 10,
    }, window.Root)

    window.Logo = create("Frame", {
        Name = "Logo",
        BackgroundColor3 = window.Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, (M.Header - 10) / 2),
        Size = UDim2.fromOffset(10, 10),
        ZIndex = 2,
    }, window.Header)
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, window.Logo)

    window.TitleLabel = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = window.Title,
        TextSize = 15,
        TextColor3 = window.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -200, 0, M.Header),
        ZIndex = 2,
    }, window.Header)

    window.ThemePrev = create("TextButton", {
        Name = "ThemePrev",
        Text = "<",
        Font = window.Font,
        TextSize = 14,
        TextColor3 = window.Theme.Muted,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Position = UDim2.new(1, -94, 0, 0),
        Size = UDim2.fromOffset(18, M.Header),
        ZIndex = 2,
    }, window.Header)

    window.ThemeName = create("TextLabel", {
        Name = "ThemeName",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "1/6 " .. window.Theme.Name,
        TextSize = 12,
        TextColor3 = window.Theme.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.new(1, -176, 0, 0),
        Size = UDim2.fromOffset(78, M.Header),
        ZIndex = 2,
    }, window.Header)

    window.ThemeNext = create("TextButton", {
        Name = "ThemeNext",
        Text = ">",
        Font = window.Font,
        TextSize = 14,
        TextColor3 = window.Theme.Muted,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Position = UDim2.new(1, -18, 0, 0),
        Size = UDim2.fromOffset(18, M.Header),
        ZIndex = 2,
    }, window.Header)

    window.Body = create("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(M.Padding, M.Padding + M.Header),
        Size = UDim2.fromOffset(M.PanelWidth, M.PanelHeight),
        ZIndex = 5,
    }, window.Root)

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

    window:SetupHeader()
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

function Minecraft:SetTheme(value)
    local index = resolveTheme(value)
    if index == self.ThemeIndex then
        return
    end
    self.ThemeIndex = index
    self.Theme = THEMES[index]
    self:Refresh(false)
    applyColor(self.Logo, "BackgroundColor3", self.Theme.Accent, true)
    self.ThemeName.Text = string.format("%d/%d %s", index, #THEMES, self.Theme.Name)
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

function Minecraft:SetScale(scale)
    self.Scale = scale or 1
    tween(self.ScaleObject, {Scale = self.Scale}, T.Pop)
end

function Minecraft:SetupHeader()
    local window = self
    for _, name in ipairs({"ThemePrev", "ThemeNext"}) do
        local button = window[name]
        button.MouseEnter:Connect(function()
            applyColor(button, "TextColor3", window.Theme.Accent, false, 0.12)
        end)
        button.MouseLeave:Connect(function()
            applyColor(button, "TextColor3", window.Theme.Muted, false, 0.12)
        end)
    end
    window.ThemePrev.MouseButton1Click:Connect(function()
        window:CycleTheme(-1)
    end)
    window.ThemeNext.MouseButton1Click:Connect(function()
        window:CycleTheme(1)
    end)
    window:_Bind(window.TitleLabel, function(theme, instant)
        applyColor(window.TitleLabel, "TextColor3", theme.Text, instant, 0.26)
    end)
    window:_Bind(window.ThemeName, function(theme, instant)
        applyColor(window.ThemeName, "TextColor3", theme.Muted, instant, 0.26)
        applyColor(window.Logo, "BackgroundColor3", theme.Accent, instant, 0.26)
        window.ThemeName.Text = string.format("%d/%d %s", window.ThemeIndex, #THEMES, theme.Name)
    end)

    -- Dragging: the header is the window handle.
    window.Header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        window:ClosePopup(true)
        local origin = input.Position
        local start = window.Root.Position
        beginDrag(input, function(position)
            local deltaX = position.X - origin.X
            local deltaY = position.Y - origin.Y
            window.Root.Position = UDim2.new(start.X.Scale, start.X.Offset + deltaX / window.Scale,
                start.Y.Scale, start.Y.Offset + deltaY / window.Scale)
        end)
    end)
end

function Minecraft:SetupSearch()
    local window = self
    if window.Options.Search == false then
        return
    end
    window.SearchFrame = create("Frame", {
        Name = "Search",
        BackgroundColor3 = window.Theme.Panel,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(228, M.Search),
        AnchorPoint = Vector2.new(0.5, 0),
        ZIndex = 6,
    }, window.Root)
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, window.SearchFrame)
    window.SearchStroke = create("UIStroke", {
        Thickness = 1,
        Color = window.Theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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
        applyColor(window.SearchStroke, "Color", theme.Border, instant, 0.26)
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
    local width = M.Padding * 2 + bodyWidth
    local searchExtra = self.SearchFrame and (8 + M.Search) or 0
    local height = M.Padding * 2 + M.Header + M.PanelHeight + searchExtra

    if instant then
        self.Root.Size = UDim2.fromOffset(width, height)
        self.Body.Size = UDim2.fromOffset(bodyWidth, M.PanelHeight)
        self.Body.Position = UDim2.fromOffset(M.Padding, M.Padding + M.Header)
    else
        tween(self.Root, {Size = UDim2.fromOffset(width, height)}, T.Layout)
        tween(self.Body, {
            Size = UDim2.fromOffset(bodyWidth, M.PanelHeight),
            Position = UDim2.fromOffset(M.Padding, M.Padding + M.Header),
        }, T.Layout)
    end

    self:_Fit(width, height)

    if self.SearchFrame then
        local target = UDim2.new(0.5, 0, 0, M.Padding + M.Header + M.PanelHeight + 8)
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
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.fromOffset(M.PanelWidth, M.PanelHeight),
        Position = UDim2.fromOffset((#window.Tabs) * (M.PanelWidth + M.Gap), -10),
        ZIndex = 2,
    }, window.Body)
    create("UICorner", {CornerRadius = UDim.new(0, 3)}, tab.Panel)
    tab.Stroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, tab.Panel)

    tab.Title = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = tab.Name,
        TextSize = 15,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, M.Title),
        ZIndex = 2,
    }, tab.Panel)

    tab.TitleLine = create("Frame", {
        Name = "TitleLine",
        BackgroundColor3 = theme.Border,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, M.Title - 1),
        Size = UDim2.new(1, -12, 0, 1),
        ZIndex = 2,
    }, tab.Panel)

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
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 2,
    }, tab.Scroll)

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
        applyColor(tab.TitleLine, "BackgroundColor3", themeNow.Border, instant, 0.26)
    end)
    window:_Bind(tab.Panel, function(themeNow, instant)
        applyColor(tab.Panel, "BackgroundColor3", themeNow.Panel, instant, 0.26)
        applyColor(tab.Stroke, "Color", themeNow.Border, instant, 0.26)
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

    row.Box = create("Frame", {
        Name = "Box",
        BackgroundColor3 = theme.Row,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 2,
    }, row.Frame)
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, row.Box)
    row.BoxStroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.RowStroke,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Transparency = 0.35,
    }, row.Box)

    row.Label = create("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = row.Name,
        TextSize = 13,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(M.Inset, 0),
        Size = UDim2.new(1, -M.Inset * 2 - 26, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, row.Frame)

    row.ValueLabel = create("TextLabel", {
        Name = "Value",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "",
        TextSize = 12,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.new(1, -M.Inset - 30, 0, 0),
        Size = UDim2.fromOffset(60, M.RowHeight),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = false,
        ZIndex = 3,
    }, row.Frame)

    row.Dots = create("TextLabel", {
        Name = "Dots",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "•••",
        TextSize = 11,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.new(1, -M.Inset - 20, 0, -1),
        Size = UDim2.fromOffset(20, M.RowHeight),
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
        Position = UDim2.new(1, -M.Inset - 46, 0, 1),
        Size = UDim2.fromOffset(46, M.RowHeight),
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
        local base = row.Active and themeNow.Hover or themeNow.Row
        if row.Locked then
            base = themeNow.Panel
        end
        applyColor(row.Box, "BackgroundColor3", base, instant, 0.16)
        applyColor(row.BoxStroke, "Color", row.Active and themeNow.Accent or themeNow.RowStroke, instant, 0.16)
        applyColor(row.Label, "TextColor3", row.Locked and themeNow.Muted or themeNow.Text, instant, 0.2)
        applyColor(row.ValueLabel, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(row.Dots, "TextColor3", row.SettingsOpen and themeNow.Accent or themeNow.Muted, instant, 0.16)
        applyColor(row.Badge, "TextColor3", themeNow.Accent, instant, 0.2)
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

function Row:RefreshVisual(instant)
    local theme = self.Window.Theme
    local open = self.SettingsOpen or self.ListOpen
    local target = theme.Row
    if self.Locked then
        target = theme.Panel
    elseif open or (self.Hovered and not self.OnState) then
        target = theme.Hover
    elseif self.OnState then
        target = theme.On
    end
    local accent = (self.Hovered or open or self.OnState) and not self.Locked
    applyColor(self.Box, "BackgroundColor3", target, instant, 0.14)
    applyColor(self.BoxStroke, "Color", accent and theme.Accent or theme.RowStroke, instant, 0.14)
    applyColor(self.Dots, "TextColor3", open and theme.Accent or theme.Muted, instant, 0.14)
    applyColor(self.Label, "TextColor3", self.Locked and theme.Muted or theme.Text, instant, 0.14)
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

function Row:_ApplyHeight(instant)
    local extra = self:_Extra()
    local target = UDim2.new(1, 0, 0, M.RowHeight + extra)
    if instant then
        self.Slot.Size = target
    else
        tween(self.Slot, {Size = target}, T.Layout)
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
        tween(self.Holder, {Position = settingsTarget, Size = settingsSize}, T.Layout)
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
    create("UICorner", {CornerRadius = UDim.new(0, 3)}, panel)
    local stroke = create("UIStroke", {
        Thickness = 1,
        Color = self.Window.Theme.Border,
        Transparency = 0.35,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, panel)
    local padding = create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
    }, panel)
    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    }, panel)
    settings.Panel = panel
    settings.Layout = layout
    settings.Stroke = stroke
    settings.Padding = padding
    self.Settings = settings

    self.Window:_Bind(panel, function(themeNow, instant)
        applyColor(panel, "BackgroundColor3", themeNow.Window, instant, 0.26)
        applyColor(stroke, "Color", themeNow.Border, instant, 0.26)
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
    if target then
        self.Settings.Fade = collectFade(self.Settings.Panel)
        applyFade(self.Settings.Fade, 1, true)
        applyFade(self.Settings.Fade, 0, false)
    else
        applyFade(self.Settings.Fade, 1, false)
    end
    self:_ApplyHeight(false)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, box)
    local boxStroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, box)
    local mark = create("Frame", {
        Name = "Mark",
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 4,
    }, box)
    create("UICorner", {CornerRadius = UDim.new(0, 1)}, mark)

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
        applyColor(boxStroke, "Color", value and theme.Accent or theme.Border, instant, 0.16)
        local size = value and 7 or 0
        if instant then
            mark.Size = UDim2.fromOffset(size, size)
        else
            tween(mark, {Size = UDim2.fromOffset(size, size)}, T.Pop)
        end
        applyColor(mark, "BackgroundColor3", theme.Accent, instant, 0.16)
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
            tween(fill, {Size = UDim2.new(alpha, 0, 1, 0)}, T.Quick)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, box)
    local stroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, box)
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
        applyColor(stroke, "Color", themeNow.Border, instant, 0.2)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, button)
    local stroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.RowStroke,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, button)
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
        applyColor(stroke, "Color", themeNow.RowStroke, instant, 0.2)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
    end)
    button.MouseEnter:Connect(function()
        applyColor(button, "BackgroundColor3", window.Theme.Hover, false, 0.12)
        applyColor(stroke, "Color", window.Theme.Accent, false, 0.12)
    end)
    button.MouseLeave:Connect(function()
        applyColor(button, "BackgroundColor3", window.Theme.Row, false, 0.12)
        applyColor(stroke, "Color", window.Theme.RowStroke, false, 0.12)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, keyButton)
    local stroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, keyButton)
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
        applyColor(stroke, "Color", themeNow.Border, instant, 0.2)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, swatch)
    local stroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, swatch)

    local api = {Flag = options.Flag, Color = options.Default or Color3.fromRGB(255, 255, 255)}
    window:_Bind(frame, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
        applyColor(stroke, "Color", themeNow.Border, instant, 0.2)
    end)

    function api:Get()
        return api.Color
    end

    function api:Set(color, silent)
        api.Color = color
        swatch.BackgroundColor3 = color
        if options.Flag then
            window.Flags[options.Flag] = color
        end
        if not silent and options.Callback then
            options.Callback(color)
        end
    end

    swatch.MouseButton1Click:Connect(function()
        window:OpenColorPicker(swatch, function(color)
            api:Set(color)
        end)
    end)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, header)
    local stroke = create("UIStroke", {
        Thickness = 1,
        Color = window.Theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, header)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, list)
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
        button.MouseEnter:Connect(function()
            button.BackgroundTransparency = 0.85
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
        applyColor(stroke, "Color", open and window.Theme.Accent or window.Theme.Border, false, 0.12)
    end)

    window:_Bind(frame, function(themeNow, instant)
        applyColor(header, "BackgroundColor3", themeNow.Row, instant, 0.2)
        applyColor(stroke, "Color", open and themeNow.Accent or themeNow.Border, instant, 0.2)
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
    create("UICorner", {CornerRadius = UDim.new(0, 2)}, swatch)
    local swatchStroke = create("UIStroke", {
        Thickness = 1,
        Color = window.Theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, swatch)

    local api = {}
    row.OnClick = function() end

    function row:Get()
        return color
    end

    function row:SetValue(newColor, silent)
        color = newColor
        swatch.BackgroundColor3 = newColor
        if options.Flag then
            window.Flags[options.Flag] = newColor
        end
        if not silent and options.Callback then
            options.Callback(newColor)
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
        window:OpenColorPicker(swatch, function(newColor)
            row:SetValue(newColor)
        end)
    end)
    api.Swatch = swatch

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
    create("UICorner", {CornerRadius = UDim.new(0, 3)}, listFrame)
    create("UIStroke", {
        Thickness = 1,
        Color = theme.Border,
        Transparency = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, listFrame)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
    }, listFrame)
    local buttons = {}

    row.OnClick = function()
        row.ListOpen = not row.ListOpen
        row.ListHeight = row.ListOpen and (#choices * 16 + 6) or 0
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
    end
    if popup.Fade then
        applyFade(popup.Fade, 1, instant)
    end
    task.delay(instant and 0 or 0.16, function()
        if not self.Popup and isAlive(popup.Panel) then
            popup.Panel.Visible = false
        end
    end)
end

function Minecraft:OpenColorPicker(anchor, callback)
    if self.Popup then
        self:ClosePopup(true)
    end
    local theme = self.Theme
    local root = self.Root
    self.PopupLayer.Visible = true

    local panel = create("Frame", {
        Name = "ColorPopup",
        BackgroundColor3 = theme.Popup,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(134, 126),
        ZIndex = 70,
    }, self.PopupLayer)
    create("UICorner", {CornerRadius = UDim.new(0, 3)}, panel)
    local stroke = create("UIStroke", {
        Thickness = 1,
        Color = theme.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, panel)

    local saturation = 128
    local sv = create("Frame", {
        Name = "SV",
        BackgroundColor3 = Color3.fromRGB(255, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(saturation, 76),
        ClipsDescendants = true,
        ZIndex = 71,
    }, panel)
    create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        ZIndex = 71,
    }, sv)
    local svBlack = create("Frame", {
        Name = "Darkness",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 72,
    }, sv)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, svBlack)
    local cursor = create("Frame", {
        Name = "Cursor",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(9, 9),
        ZIndex = 74,
    }, sv)
    create("UIStroke", {Thickness = 1, Color = Color3.new(1, 1, 1)}, cursor)
    create("UIStroke", {Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.5}, cursor)

    local hue = create("Frame", {
        Name = "Hue",
        BackgroundColor3 = Color3.fromRGB(255, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(3, 83),
        Size = UDim2.fromOffset(saturation, 12),
        ZIndex = 71,
    }, panel)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
    }, hue)
    local marker = create("Frame", {
        Name = "Marker",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(3, 16),
        ZIndex = 74,
    }, hue)

    local presets = {}
    local presetColors = {
        Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(255, 96, 96),
        Color3.fromRGB(255, 196, 96),
        Color3.fromRGB(140, 235, 140),
        Color3.fromRGB(112, 178, 255),
        Color3.fromRGB(186, 152, 255),
    }
    for index, color in ipairs(presetColors) do
        local swatch = create("TextButton", {
            Name = "Preset",
            BackgroundColor3 = color,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
            Position = UDim2.fromOffset(3 + (index - 1) * 21, 101),
            Size = UDim2.fromOffset(18, 18),
            ZIndex = 72,
        }, panel)
        create("UICorner", {CornerRadius = UDim.new(0, 2)}, swatch)
        presets[index] = swatch
        swatch.MouseButton1Click:Connect(function()
            local h, s, v = color:ToHSV()
            state.H, state.S, state.V = h, s, v
            state:Apply()
        end)
    end

    local state = {
        H = 0, S = 1, V = 1,
        Panel = panel,
        Fade = nil,
        Window = self,
        Callback = callback,
    }

    function state:Apply(instant, silent)
        local color = Color3.fromHSV(self.H, self.S, self.V)
        sv.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
        cursor.Position = UDim2.fromScale(self.S, 1 - self.V)
        marker.Position = UDim2.new(self.H, 0, 0.5, 0)
        if callback and not silent then
            callback(color)
        end
        for _, swatch in ipairs(presets) do
            local swatchStroke = swatch:FindFirstChildOfClass("UIStroke")
            if not swatchStroke then
                swatchStroke = create("UIStroke", {Thickness = 1, Color = self.Window.Theme.Border}, swatch)
            end
            applyColor(swatchStroke, "Color", color, true)
        end
    end

    -- Position the popup next to the swatch, inside the window.
    local function place()
        local anchorPosition = anchor.AbsolutePosition
        local rootPosition = root.AbsolutePosition
        local scale = self.Scale
        local x = (anchorPosition.X - rootPosition.X) / scale
        local y = (anchorPosition.Y - rootPosition.Y) / scale
        panel.Position = UDim2.fromOffset(clamp(x - 60, 0, root.AbsoluteSize.X / scale - 134), y + 20)
    end
    place()

    local svInput = create("TextButton", {
        Name = "SVHit",
        Text = "",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 73,
    }, sv)
    svInput.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local function move(position)
            local absolute = sv.AbsolutePosition
            local size = sv.AbsoluteSize
            state.S = clamp((position.X - absolute.X) / math.max(size.X, 1), 0, 1)
            state.V = clamp(1 - (position.Y - absolute.Y) / math.max(size.Y, 1), 0, 1)
            state:Apply(true)
        end
        move(input.Position)
        beginDrag(input, move)
    end)

    local hueInput = create("TextButton", {
        Name = "HueHit",
        Text = "",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 73,
    }, hue)
    hueInput.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local function move(position)
            local absolute = hue.AbsolutePosition
            local size = hue.AbsoluteSize
            state.H = clamp((position.X - absolute.X) / math.max(size.X, 1), 0, 0.9999)
            state:Apply(true)
        end
        move(input.Position)
        beginDrag(input, move)
    end)

    local current = anchor.BackgroundColor3
    local h, s, v = current:ToHSV()
    state.H, state.S, state.V = h, s, v
    state:Apply(true, true)

    self.Popup = state
    self:_Bind(panel, function(themeNow, instant)
        applyColor(panel, "BackgroundColor3", themeNow.Popup, instant, 0.2)
        applyColor(stroke, "Color", themeNow.Border, instant, 0.2)
    end)
    panel.Position = UDim2.fromOffset(panel.Position.X.Offset, panel.Position.Y.Offset + 6)
    state.Fade = collectFade(panel)
    applyFade(state.Fade, 1, true)
    applyFade(state.Fade, 0, false)
    tween(panel, {Position = UDim2.fromOffset(panel.Position.X.Offset, panel.Position.Y.Offset - 6)}, T.Pop)
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
