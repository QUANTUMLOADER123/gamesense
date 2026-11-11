-- Minecraft :: a Roblox UI library that recreates the classic Minecraft cheat
-- menu: a row of equal-size panels, option rows with a hover state and animated
-- per-row settings that slide open underneath the option.
--
--   * real frosted glass behind the panels (Fluent-style 3D acrylic, optional)
--   * six neon themes, one shared motion vocabulary, no outlines anywhere
--   * UI only -- gameplay logic lives in the callbacks
--
--   local Minecraft = loadstring(game:HttpGet(".../minecraft.lua"))()
--   local window = Minecraft.new({Theme = 1})
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
Minecraft.Version = "1.11.0"
Minecraft.Build = 21 -- incremented on every visible change, used by examples to detect stale caches

local Tab = {}
Tab.__index = Tab

local Row = {}
Row.__index = Row

local Settings = {}
Settings.__index = Settings

-- Layout metrics. Every panel uses the same width and height, so the menu always
-- reads as one even row of columns no matter how many tabs are added.
local M = {
    PanelWidth = 236,
    PanelHeight = 536,
    Gap = 10,
    -- The tab name sits ABOVE the panel, like a caption; the panel itself starts
    -- straight into its rows (no inner title bar any more).
    Title = 34,
    RowHeight = 32,
    RowGap = 5,
    Inset = 12,
    Search = 36,
    SearchWidth = 300,
    -- Shared vertical rhythm. Every control in a settings block uses these, so
    -- the column reads as one evenly-spaced list instead of a pile of boxes.
    BlockPadding = 9,
    BlockGap = 7,
    -- Acrylic backdrop inset: the glass plate is pulled in a hair so the
    -- rounded corners of the panel still get their own edge shading.
    AcrylicInset = 2,
}
-- One place to tune the whole look: panels are the roundest, then rows,
-- then the small controls inside settings blocks.
Minecraft.Radius = {Panel = 18, Row = 10, Control = 7, Small = 5}
Minecraft.Metrics = M

-- Motion tokens. One family of curves for the whole menu: Quint for movement
-- (fast start, long settle), Back for "pop" moments (checkboxes, popups),
-- Sine for colour so theme swaps never look like a hard cut.
local T = {
    Layout = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Expand = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Collapse = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Quick = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Pop = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    PopSoft = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Color = TweenInfo.new(0.26, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
    Fade = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    FadeFast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Hover = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
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

-- Pixel icons ---------------------------------------------------------------
-- Same technique as the checkbox tick: rows of "#" are merged into 1px-tall
-- frames. No image assets, no blurring at fractional scale, and every icon can
-- be recoloured per theme.
local function pixelIcon(parent, pattern, color, zIndex)
    local width = 0
    for _, row in ipairs(pattern) do
        width = math.max(width, #row)
    end
    local holder = create("Frame", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(width, #pattern),
        ZIndex = zIndex or 4,
    }, parent)
    local pixels = {}
    for rowIndex, row in ipairs(pattern) do
        local column = 1
        while column <= #row do
            if row:sub(column, column) == "#" then
                local first = column
                while column <= #row and row:sub(column, column) == "#" do
                    column = column + 1
                end
                pixels[#pixels + 1] = create("Frame", {
                    Name = "Pixel",
                    BackgroundColor3 = color or Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(first - 1, rowIndex - 1),
                    Size = UDim2.fromOffset(column - first, 1),
                    ZIndex = zIndex or 4,
                }, holder)
            else
                column = column + 1
            end
        end
    end
    return holder, pixels
end

-- Real glow ------------------------------------------------------------------
-- Not stacked translucent frames (that reads as a halo of rings): Roblox ships a
-- soft radial texture, so one ImageLabel tinted to the accent and stretched with
-- Slice gives a genuinely blurred bloom around any rounded rectangle.
local GLOW_TEXTURE = "rbxasset://textures/glow.png"

local function addGlow(parent, color, options)
    options = options or {}
    local padding = options.Padding or 10
    local glow = create("ImageLabel", {
        Name = options.Name or "Glow",
        BackgroundTransparency = 1,
        Image = GLOW_TEXTURE,
        ImageColor3 = color or Color3.new(1, 1, 1),
        ImageTransparency = options.Transparency or 0.45,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(Vector2.new(64, 64), Vector2.new(64, 64)),
        SliceScale = options.SliceScale or 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, padding * 2, 1, padding * 2),
        ZIndex = options.ZIndex or 1,
    }, parent)
    glow.Padding = padding
    return glow
end

Minecraft.addGlow = addGlow

Minecraft.Icons = {
    -- Hollow chevron: six pixel runs, so it reads as an outline arrow rather
    -- than a solid triangle at 1x.
    Chevron = {
        "##...##",
        ".##.##.",
        "..###..",
        "...#...",
    },
    Search = {
        ".####..",
        "##..##.",
        "##..##.",
        "##..##.",
        ".####..",
        "....##.",
        ".....##",
    },
}

--==========================================================================--
-- Acrylic backdrop
--==========================================================================--
-- Roblox has no per-GUI backdrop-filter, so real frosted glass is done the way
-- Fluent does it: a flat, fully transparent *glass* part is parked a hair in
-- front of the camera and stretched to cover the panel rectangle. The engine
-- then samples the scene behind that glass and blurs it, which reads as an
-- acrylic sheet under the menu while the rest of the screen stays sharp.
--
-- Two things matter for it to work:
--   * GraphicsQualityLevel >= 8 (glass refraction is a high-quality feature)
--   * the part must be a child of the camera and never collide or cast shadows
-- Everything is pcall-guarded: on clients where glass parts are unsupported the
-- menu simply keeps its normal translucent panels.

local Acrylic = {}
Minecraft.Acrylic = Acrylic

local function quality()
    local ok, value = pcall(function()
        return settings().Rendering.QualityLevel
    end)
    if ok and type(value) == "number" then
        return value
    end
    -- UserGameSettings has the numeric level on most clients.
    local ok2, level = pcall(function()
        return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
    end)
    if ok2 and type(level) == "number" then
        return level
    end
    return 10
end

local function screenToWorld(camera, point, distance)
    local ray = camera:ScreenPointToRay(point.X, point.Y)
    return ray.Origin + ray.Direction * distance, ray
end

-- A single acrylic sheet anchored to a Frame. Returns a handle with :Refresh
-- (re-fit), :SetVisible, :Destroy and the underlying Model.
local function createAcrylic(camera, frame, options)
    options = options or {}
    if not camera or not frame then
        return nil
    end

    local distance = options.Distance or 0.001
    -- One folder per camera, shared by every sheet: keeps the camera's child list
    -- clean and makes cleanup a single Destroy.
    local folder = options.Folder
    if not folder or not isAlive(folder) then
        local okFolder
        okFolder, folder = pcall(function()
            local existing = camera:FindFirstChild("MinecraftUIAcrylic")
            if existing then
                return existing
            end
            local made = Instance.new("Folder")
            made.Name = "MinecraftUIAcrylic"
            made.Parent = camera
            return made
        end)
        if not okFolder or not folder then
            return nil
        end
    end

    -- Core properties first, then the optional physics/collision flags inside a
    -- pcall: they are newer than the base Part API on some clients.
    local model = create("Part", {
        Name = "Acrylic",
        Color = Color3.new(0, 0, 0),
        Material = Enum.Material.Glass,
        Size = Vector3.new(1, 1, 0),
        Anchored = true,
        CanCollide = false,
        Locked = true,
        CastShadow = false,
        Transparency = 1,
    }, folder)
    pcall(function()
        model.CanTouch = false
        model.CanQuery = false
        model.Massless = true
    end)
    local mesh = create("SpecialMesh", {
        MeshType = Enum.MeshType.Brick,
        Offset = Vector3.new(0, 0, -0.000001),
    }, model)
    model.CFrame = CFrame.new(0, 0, -100)

    local handle = {
        Model = model,
        Folder = folder,
        Visible = false,
        Enabled = options.Enabled ~= false,
        OwnFolder = options.OwnFolder ~= false,
    }

    -- Absolute position/size of the frame, in viewport pixels. Roblox reports
    -- AbsolutePosition excluding the top inset when IgnoreGuiInset is off; the
    -- ScreenGui here sets IgnoreGuiInset = true, so no correction is needed.
    local function measure()
        local ok, position = pcall(function()
            return frame.AbsolutePosition
        end)
        local ok2, size = pcall(function()
            return frame.AbsoluteSize
        end)
        if not ok or not ok2 or not position or not size or size.X <= 0 or size.Y <= 0 then
            return nil
        end
        local inset = M.AcrylicInset
        return {
            topLeft = Vector2.new(position.X + inset, position.Y + inset),
            topRight = Vector2.new(position.X + size.X - inset, position.Y + inset),
            bottomRight = Vector2.new(position.X + size.X - inset, position.Y + size.Y - inset),
        }
    end

    function handle:Refresh()
        if not isAlive(model) then
            return
        end
        if not self.Enabled or not self.Visible then
            return
        end
        local points = measure()
        if not points then
            return
        end
        local current = workspace.CurrentCamera
        if not current then
            return
        end
        local topLeft, topRight, bottomRight
        local ok = pcall(function()
            topLeft = screenToWorld(current, points.topLeft, distance)
            topRight = screenToWorld(current, points.topRight, distance)
            bottomRight = screenToWorld(current, points.bottomRight, distance)
        end)
        if not ok or not topLeft or not topRight or not bottomRight then
            return
        end
        local width = (topRight - topLeft).Magnitude
        local height = (topRight - bottomRight).Magnitude
        if width <= 0 or height <= 0 then
            return
        end
        pcall(function()
            model.CFrame = CFrame.fromMatrix((topLeft + bottomRight) / 2, current.CFrame.XVector, current.CFrame.YVector, current.CFrame.ZVector)
            mesh.Scale = Vector3.new(width, height, 0)
        end)
    end

    function handle:SetVisible(value)
        self.Visible = value and true or false
        if not isAlive(model) then
            return
        end
        -- 0.98 is the sweet spot Fluent uses: visible enough to refract the scene,
        -- invisible enough that the UI on top stays readable.
        pcall(function()
            model.Transparency = (self.Visible and self.Enabled) and 0.98 or 1
        end)
        if self.Visible then
            self:Refresh()
        end
    end

    function handle:Destroy()
        self.Visible = false
        if isAlive(model) then
            pcall(function()
                model:Destroy()
            end)
        end
        -- The folder is shared by every sheet of one window; the window destroys
        -- it in Minecraft:Destroy once all sheets are gone.
        self.Destroyed = true
    end

    handle:SetVisible(false)
    return handle
end

Acrylic.create = createAcrylic

-- True when this client can actually render glass refraction.
function Acrylic.Supported()
    return quality() >= 8
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

    -- Panel opacity is configurable: 0 = solid, 1 = fully clear.
    window.PanelTransparency = clamp(options.GlassTransparency or 0.22, 0, 1)

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

    -- There is no full-screen blur and no full-screen scrim. The game stays
    -- sharp and bright everywhere; only the strips directly behind the panels,
    -- the search bar and the popups get frosted, via the acrylic sheets below.
    -- BlurMode is kept for API compatibility: "screen" used to add a global
    -- BlurEffect + black Dim. It no longer does anything.
    window.BlurMode = options.BlurMode or "local"
    window.BlurSize = options.BlurSize or 24

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
        Position = UDim2.fromOffset(0, M.Title),
        Size = UDim2.fromOffset(M.PanelWidth, M.PanelHeight),
        ZIndex = 5,
    }, window.Root)

    -- No dark plate behind the panels: it was rejected twice. The acrylic sheet
    -- and the panel tint carry the contrast instead.

    -- Acrylic (real frosted glass behind the panels) --------------------------
    -- "auto" -> on when the client's graphics quality can render glass
    -- "on"   -> force it, "off" -> never create glass parts.
    window.AcrylicMode = options.Acrylic or "auto"
    if window.AcrylicMode == nil or window.AcrylicMode == false then
        window.AcrylicMode = "off"
    end
    window.Acrylics = {}
    window.AcrylicSupported = Acrylic.Supported()
    window.AcrylicEnabled = window.AcrylicMode ~= "off" and (window.AcrylicMode == "on" or window.AcrylicSupported)

    -- Falling stars --------------------------------------------------------
    -- A field of slow, diagonal meteors behind the menu. Each star is a thin
    -- streak with a bright head and a fading tail, and it leaves a short trail
    -- of dimmer motes that lag behind it. Everything is tween-driven, so there
    -- is no per-frame loop and the cost stays flat.
    window.StarsLayer = create("Frame", {
        Name = "Stars",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 0,
        ClipsDescendants = false,
    }, window.Gui)
    window.Stars = {}

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
    window:_SetupAcrylic()
    window:_SetupStars()

    -- Fade the menu in once it is built. The acrylic sheets come up slightly
    -- later so the glass reads as "condensing" under the menu, not as a flash.
    if not window.Options.NoIntro then
        if window.Root.ClassName == "CanvasGroup" then
            window.Root.GroupTransparency = 1
            window.ScaleObject.Scale = window.Scale * 0.96
            tween(window.Root, {GroupTransparency = 0}, TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tween(window.ScaleObject, {Scale = window.Scale}, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
        end
        if window.AcrylicEnabled then
            task.delay(0.06, function()
                if window.Open then
                    window:_SetAcrylicVisible(true)
                end
            end)
        end
    else
        if window.Root.ClassName == "CanvasGroup" then
            window.Root.GroupTransparency = 0
            window.ScaleObject.Scale = window.Scale
        end
        if window.AcrylicEnabled then
            task.defer(function()
                if window.Open then
                    window:_SetAcrylicVisible(true)
                end
            end)
        end
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
        -- Dip through a light fade so the per-object colour tweens cross-fade
        -- instead of showing two palettes at once.
        tween(self.Root, {GroupTransparency = 0.14}, TweenInfo.new(0.10, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))
        task.delay(0.11, function()
            if isAlive(self.Root) then
                tween(self.Root, {GroupTransparency = self.Open and 0 or 1}, T.Color)
            end
        end)
    end
    -- Acrylic is a 3D object, not part of the CanvasGroup: re-fit every sheet so
    -- it does not look frozen while the GUI cross-fades.
    self:_RefreshAcrylic()
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
    if self.SearchFrame then
        tween(self.SearchFrame, {BackgroundTransparency = math.min(1, self.PanelTransparency + 0.10)}, T.Color)
    end
end

-- Real world blur strength. In "local" mode this promotes the window to a
-- full-screen blur on demand (the BlurEffect is created once, lazily).
-- Kept for API compatibility. A global BlurEffect is exactly what the menu must
-- NOT have, so this only records the value and turns the local acrylic up.
function Minecraft:SetBlur(size)
    self.BlurSize = math.max(tonumber(size) or 0, 0)
    self.BlurMode = "local"
    if self.BlurEffect and isAlive(self.BlurEffect) then
        pcall(function()
            self.BlurEffect:Destroy()
        end)
        self.BlurEffect = nil
    end
    -- A stronger "blur" reads as more acrylic: nudge the panel tint a bit denser
    -- so the local frosting visibly deepens instead of doing nothing.
    self:SetGlass(clamp(0.22 - self.BlurSize / 400, 0, 1))
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
        BackgroundTransparency = math.min(1, window.PanelTransparency + 0.10),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(M.SearchWidth, M.Search),
        ZIndex = 6,
    }, window.Root)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, window.SearchFrame)
    window.SearchGlow = create("ImageLabel", {
        Name = "SearchGlow",
        BackgroundTransparency = 1,
        Image = "rbxasset://textures/glow.png",
        ImageColor3 = window.Theme.Accent,
        ImageTransparency = 0.68,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(Vector2.new(64, 64), Vector2.new(64, 64)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 16, 1, 16),
        ZIndex = 1,
    }, window.SearchFrame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, window.SearchGlow)
    window.SearchGradient = create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(window.Theme.PanelTop, window.Theme.PanelBottom),
    }, window.SearchFrame)
    -- Pixel magnifier: drawn from 1px frames like the checkbox tick, so it has
    -- no image dependency and stays crisp at every scale.
    local GLASS_ICON = {
        ".####..",
        "##..##.",
        "##..##.",
        "##..##.",
        ".####..",
        "....##.",
        ".....##",
    }
    local icon = create("Frame", {
        Name = "SearchIcon",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, M.Inset + 1, 0.5, -3),
        Size = UDim2.fromOffset(#GLASS_ICON[1], #GLASS_ICON),
        ZIndex = 2,
    }, window.SearchFrame)
    window.SearchIcon = icon
    window.SearchIconPixels = {}
    for rowIndex, pattern in ipairs(GLASS_ICON) do
        local column = 1
        while column <= #pattern do
            if pattern:sub(column, column) == "#" then
                local first = column
                while column <= #pattern and pattern:sub(column, column) == "#" do
                    column = column + 1
                end
                local pixel = create("Frame", {
                    Name = "Pixel",
                    BackgroundColor3 = window.Theme.Muted,
                    BackgroundTransparency = 0.25,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(first - 1, rowIndex - 1),
                    Size = UDim2.fromOffset(column - first, 1),
                    ZIndex = 2,
                }, icon)
                window.SearchIconPixels[#window.SearchIconPixels + 1] = pixel
            else
                column = column + 1
            end
        end
    end

    window.SearchBox = create("TextBox", {
        Name = "SearchBox",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "",
        PlaceholderText = window.Options.SearchPlaceholder or "Search",
        PlaceholderColor3 = window.Theme.Muted,
        TextSize = 13,
        TextColor3 = window.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Position = UDim2.fromOffset(M.Inset + 15, 0),
        Size = UDim2.new(1, -(M.Inset * 2 + 15), 1, 0),
        ZIndex = 2,
    }, window.SearchFrame)
    window.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        window:Filter(window.SearchBox.Text)
    end)
    -- Focus pulls the bar forward: brighter text, accent icon.
    window.SearchBox.Focused:Connect(function()
        window.SearchFocused = true
        for _, pixel in ipairs(window.SearchIconPixels) do
            applyColor(pixel, "BackgroundColor3", window.Theme.Accent, false, 0.16)
        end
        tween(window.SearchFrame, {BackgroundTransparency = 0.18}, T.Hover)
    end)
    window.SearchBox.FocusLost:Connect(function()
        window.SearchFocused = false
        for _, pixel in ipairs(window.SearchIconPixels) do
            applyColor(pixel, "BackgroundColor3", window.Theme.Muted, false, 0.16)
        end
        tween(window.SearchFrame, {BackgroundTransparency = 0.32}, T.Hover)
    end)
    window:_Bind(window.SearchFrame, function(theme, instant)
        applyColor(window.SearchFrame, "BackgroundColor3", theme.Panel, instant, 0.26)
        if window.SearchGlow and isAlive(window.SearchGlow) then
            applyColor(window.SearchGlow, "ImageColor3", theme.Accent, instant, 0.26)
        end
        if window.SearchGradient and isAlive(window.SearchGradient) then
            window.SearchGradient.Color = ColorSequence.new(theme.PanelTop, theme.PanelBottom)
        end
        applyColor(window.SearchBox, "PlaceholderColor3", theme.Muted, instant, 0.26)
        applyColor(window.SearchBox, "TextColor3", theme.Text, instant, 0.26)
        if not window.SearchFocused then
            for _, pixel in ipairs(window.SearchIconPixels or {}) do
                applyColor(pixel, "BackgroundColor3", theme.Muted, instant, 0.26)
            end
        end
    end)
end

function Minecraft:Filter(query)
    query = (query or ""):lower()
    for _, tab in ipairs(self.Tabs) do
        tab:Filter(query)
    end
end

--==========================================================================--
-- Acrylic wiring
--==========================================================================--
-- Attach an acrylic sheet to a frame (a panel, the search bar, a popup), sized
-- from that frame's on-screen rectangle. Sheets are re-fitted whenever the
-- camera moves or the frame is resized/repositioned, so the glass sticks to the
-- UI instead of drifting when the player looks around.
function Minecraft:_AttachAcrylic(frame, options)
    if not self.AcrylicEnabled or not frame then
        return nil
    end
    local camera
    local ok = pcall(function()
        camera = workspace.CurrentCamera
    end)
    if not ok or not camera then
        return nil
    end
    -- One folder per window, created on first use.
    if not self.AcrylicFolder or not isAlive(self.AcrylicFolder) then
        local made
        local ok = pcall(function()
            made = Instance.new("Folder")
            made.Name = "MinecraftUIAcrylic"
            made.Parent = camera
        end)
        if not ok or not made then
            return nil
        end
        self.AcrylicFolder = made
    end
    options = options or {}
    options.Folder = self.AcrylicFolder
    local handle = createAcrylic(camera, frame, options)
    if not handle then
        return nil
    end
    self.Acrylics[#self.Acrylics + 1] = handle

    -- Frame geometry changes (layout animation, tab count change, scale fit).
    local function connect(object)
        if not object then
            return
        end
        pcall(function()
            self.Connections[#self.Connections + 1] = object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                handle:Refresh()
            end)
            self.Connections[#self.Connections + 1] = object:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                handle:Refresh()
            end)
        end)
    end
    connect(frame)
    connect(frame.Parent)

    -- Camera changes: every sheet needs re-fitting.
    if not self._AcrylicCameraBound and camera then
        self._AcrylicCameraBound = true
        local refresh = function()
            for _, item in ipairs(self.Acrylics) do
                if item.Visible then
                    item:Refresh()
                end
            end
        end
        pcall(function()
            self.Connections[#self.Connections + 1] = camera:GetPropertyChangedSignal("CFrame"):Connect(refresh)
            self.Connections[#self.Connections + 1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
            self.Connections[#self.Connections + 1] = camera:GetPropertyChangedSignal("FieldOfView"):Connect(refresh)
        end)
        self._AcrylicRefresh = refresh
    end

    -- Respawn swaps workspace.CurrentCamera; the glass must move to the new one.
    if not self._AcrylicWorkspaceBound then
        self._AcrylicWorkspaceBound = true
        pcall(function()
            self.Connections[#self.Connections + 1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
                self:_RebindAcrylic()
            end)
        end)
    end

    return handle
end

-- Rebuild every sheet against the camera that is current right now.
function Minecraft:_RebindAcrylic()
    if not self.AcrylicEnabled then
        return
    end
    for _, sheet in ipairs(self.Acrylics) do
        pcall(function()
            sheet:Destroy()
        end)
    end
    self.Acrylics = {}
    for _, tab in ipairs(self.Tabs) do
        tab.Acrylic = nil
    end
    self.SearchAcrylic = nil
    self:_SetupAcrylic()
    self:_SetAcrylicVisible(self.Open)
end

function Minecraft:_SetupAcrylic()
    if not self.AcrylicEnabled or self._AcrylicBuilding then
        return
    end
    self._AcrylicBuilding = true
    -- In Studio / on respawn the camera can be nil while the menu is being built.
    -- Try again shortly instead of silently giving up for the whole session.
    local camera
    pcall(function()
        camera = workspace.CurrentCamera
    end)
    if not camera then
        self._AcrylicBuilding = false
        self._AcrylicRetries = (self._AcrylicRetries or 0) + 1
        if self._AcrylicRetries <= 10 then
            task.delay(0.5, function()
                if self.AcrylicEnabled and not self.SearchAcrylic and isAlive(self.Gui) then
                    self:_SetupAcrylic()
                    self:_SetAcrylicVisible(self.Open)
                end
            end)
        end
        return
    end

    -- One sheet PER panel + one for the search bar. There is deliberately no
    -- single sheet spanning the whole menu: each region gets its own frosted
    -- island, and the gaps between columns stay perfectly sharp.
    local ok = pcall(function()
        for _, tab in ipairs(self.Tabs) do
            if not tab.Acrylic then
                tab.Acrylic = self:_AttachAcrylic(tab.Panel, {Distance = 0.001})
            end
        end
        if not self.SearchAcrylic then
            self.SearchAcrylic = self:_AttachAcrylic(self.SearchFrame, {Distance = 0.0012})
        end
    end)
    self._AcrylicBuilding = false
    if not ok then
        return
    end

    -- Start hidden; the intro reveals the sheets after the first frame so the
    -- glass never snaps on before the menu has settled.
    for _, tab in ipairs(self.Tabs) do
        if tab.Acrylic then
            tab.Acrylic:SetVisible(false)
        end
    end
    if self.SearchAcrylic then
        self.SearchAcrylic:SetVisible(false)
    end
end

-- Called when a new tab appears after the window was built.
function Minecraft:_AttachTabAcrylic(tab)
    if not self.AcrylicEnabled or not tab or not tab.Panel then
        return
    end
    local camera
    pcall(function()
        camera = workspace.CurrentCamera
    end)
    if not camera then
        return
    end
    if not tab.Acrylic then
        tab.Acrylic = self:_AttachAcrylic(tab.Panel, {Distance = 0.001})
    end
    if tab.Acrylic then
        tab.Acrylic:SetVisible(false)
    end
end

function Minecraft:_SetAcrylicVisible(value)
    for _, tab in ipairs(self.Tabs) do
        if tab.Acrylic then
            tab.Acrylic:SetVisible(value)
        end
    end
    if self.SearchAcrylic then
        self.SearchAcrylic:SetVisible(value)
    end
end

function Minecraft:_RefreshAcrylic()
    for _, tab in ipairs(self.Tabs) do
        if tab.Acrylic and tab.Acrylic.Visible then
            tab.Acrylic:Refresh()
        end
    end
    if self.SearchAcrylic and self.SearchAcrylic.Visible then
        self.SearchAcrylic:Refresh()
    end
end

function Minecraft:SetAcrylic(mode)
    if mode == "auto" then
        mode = self.AcrylicSupported and "on" or "off"
    end
    self.AcrylicMode = mode
    if mode == "off" then
        for _, tab in ipairs(self.Tabs) do
            if tab.Acrylic then
                tab.Acrylic:Destroy()
                tab.Acrylic = nil
            end
        end
        if self.SearchAcrylic then
            self.SearchAcrylic:Destroy()
            self.SearchAcrylic = nil
        end
        if self.AcrylicFolder and self.AcrylicFolder.Parent then
            pcall(function()
                self.AcrylicFolder:Destroy()
            end)
        end
        self.AcrylicFolder = nil
        self.AcrylicEnabled = false
        return
    end
    if not self.AcrylicEnabled then
        self.AcrylicEnabled = true
        self:_SetupAcrylic()
        self:_SetAcrylicVisible(self.Open)
    end
end

--==========================================================================--
-- Falling stars
--==========================================================================--
-- Each meteor is: a head (small round dot), a tail (a thin frame rotated to the
-- travel direction, fading out backwards) and two lagging motes that read as a
-- glitter trail. They spawn above/left of the viewport and fall diagonally, then
-- respawn. Tweens only, no RunService loop, so dozens of them are cheap.
local STAR_ANGLE = 38          -- degrees, falling down-right
local STAR_COLORS = {
    {Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 130, 255)},
    {Color3.fromRGB(190, 235, 255), Color3.fromRGB(86, 226, 255)},
    {Color3.fromRGB(255, 225, 245), Color3.fromRGB(255, 132, 216)},
}

local function makeStar(window, index)
    local theme = window.Theme
    local palette = STAR_COLORS[(index - 1) % #STAR_COLORS + 1]
    local length = 18 + (index * 7) % 26
    local thickness = (index % 3 == 0) and 2 or 1

    local holder = create("Frame", {
        Name = "Star" .. index,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 1),
        Rotation = -STAR_ANGLE,
        Size = UDim2.fromOffset(thickness, length),
        ZIndex = 0,
    }, window.StarsLayer)

    -- Tail: fades from the head (bottom, opaque) to the tip (top, clear).
    local tail = create("Frame", {
        Name = "Tail",
        BackgroundColor3 = palette[2],
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 0,
    }, holder)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, tail)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(0.55, 0.75),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, tail)

    -- Head: a bright core wrapped in a soft bloom (radial texture), so the
    -- meteor reads as a light source instead of a scratch on the screen.
    local halo = create("ImageLabel", {
        Name = "Halo",
        BackgroundTransparency = 1,
        Image = GLOW_TEXTURE,
        ImageColor3 = palette[1],
        ImageTransparency = 0.35,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.fromOffset(18, 18),
        SliceCenter = Rect.new(Vector2.new(64, 64), Vector2.new(64, 64)),
        ScaleType = Enum.ScaleType.Slice,
        ZIndex = 1,
    }, holder)
    local head = create("Frame", {
        Name = "Head",
        BackgroundColor3 = palette[1],
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.fromOffset(3, 3),
        ZIndex = 2,
    }, holder)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, head)

    -- Two lagging motes give the streak a glittery feel.
    local motes = {}
    for m = 1, 2 do
        motes[m] = create("Frame", {
            Name = "Mote" .. m,
            BackgroundColor3 = palette[1],
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 1, m * 3),
            Size = UDim2.fromOffset(2, 2),
            ZIndex = 0,
        }, holder)
        create("UICorner", {CornerRadius = UDim.new(1, 0)}, motes[m])
    end

    return {
        Holder = holder,
        Tail = tail,
        Head = head,
        Halo = halo,
        Motes = motes,
        Palette = palette,
        Length = length,
        Seed = index,
    }
end

function Minecraft:_StarViewport()
    local ok, size = pcall(function()
        local camera = workspace.CurrentCamera
        return camera and camera.ViewportSize or nil
    end)
    if ok and size and size.X > 0 and size.Y > 0 then
        return size
    end
    return Vector2.new(1280, 720)
end

-- One fall cycle: start off-screen top-left, land off-screen bottom-right.
function Minecraft:_LaunchStar(star, firstRun)
    if not star or not isAlive(star.Holder) then
        return
    end
    local viewport = self:_StarViewport()
    local padding = 120
    -- Spread starts over the full width plus a margin on the left so stars enter
    -- from beyond the edge instead of popping in inside the screen.
    local startX = -padding + (star.Seed * 0.61803398875 % 1) * (viewport.X + padding * 2)
    local startY = -padding - (star.Seed * 0.2718281828 % 1) * viewport.Y * 0.6
    local travel = viewport.Y + padding * 2
    local endX = startX + travel * math.sin(math.rad(STAR_ANGLE))
    local endY = startY + travel * math.cos(math.rad(STAR_ANGLE))

    star.Holder.Position = UDim2.fromOffset(startX, startY)
    star.Holder.Visible = true

    local duration = 2.6 + (star.Seed % 5) * 0.55
    local delay = firstRun and ((star.Seed % 11) * 0.28) or ((star.Seed * 0.37) % 2.4)

    local function fly()
        if not isAlive(star.Holder) then
            return
        end
        tween(star.Holder, {
            Position = UDim2.fromOffset(endX, endY),
        }, TweenInfo.new(duration, Enum.EasingStyle.Linear))

        -- Fade in at the top and out at the bottom so nothing pops.
        local fadeIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local fadeOut = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(star.Tail, {BackgroundTransparency = 0.25}, fadeIn)
        tween(star.Head, {BackgroundTransparency = 0}, fadeIn)
        if star.Halo then
            tween(star.Halo, {ImageTransparency = 0.2}, fadeIn)
        end
        task.delay(duration - 0.9, function()
            if not isAlive(star.Tail) then
                return
            end
            tween(star.Tail, {BackgroundTransparency = 1}, fadeOut)
            tween(star.Head, {BackgroundTransparency = 1}, fadeOut)
            if star.Halo then
                tween(star.Halo, {ImageTransparency = 1}, fadeOut)
            end
            for _, mote in ipairs(star.Motes) do
                tween(mote, {BackgroundTransparency = 1}, fadeOut)
            end
        end)

        -- Restart after the flight plus a random-ish pause.
        task.delay(duration + 0.35 + (star.Seed % 7) * 0.45, function()
            if not self.Open or not isAlive(star.Holder) then
                return
            end
            self:_LaunchStar(star, false)
        end)
    end

    if delay > 0 then
        task.delay(delay, fly)
    else
        fly()
    end
end

function Minecraft:_SetupStars(count)
    if self.Options.Stars == false then
        return
    end
    self.StarCount = count or self.Options.StarCount or 14
    for index = 1, self.StarCount do
        if not self.Stars[index] then
            local star = makeStar(self, index)
            star.Holder.Visible = false
            self.Stars[index] = star
        end
    end
    for index, star in ipairs(self.Stars) do
        self:_LaunchStar(star, true)
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
    if self.Popup then
        self:ClosePopup(true)
    end
    -- Acrylic follows the menu: it appears with the intro (after the first
    -- frame, when the root has real AbsolutePosition) and vanishes with it.
    if self.StarsLayer then
        self.StarsLayer.Visible = self.Open
    end
    if self.AcrylicEnabled then
        if self.Open then
            task.defer(function()
                if self.Open then
                    self:_SetAcrylicVisible(true)
                end
            end)
        else
            self:_SetAcrylicVisible(false)
        end
    end
    if self.Root.ClassName == "CanvasGroup" then
        if self.Open then
            self.Gui.Enabled = true
            tween(self.Root, {GroupTransparency = 0}, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            tween(self.ScaleObject, {Scale = self.Scale}, T.Pop)
        else
            local animation = tween(self.Root, {GroupTransparency = 1}, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            tween(self.ScaleObject, {Scale = self.Scale * 0.96}, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            task.delay(0.18, function()
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
    -- Captions sit in the title band above the panels, so the body starts lower.
    local height = M.Title + M.PanelHeight + M.Gap + M.Search

    if instant then
        self.Root.Size = UDim2.fromOffset(width, height)
        self.Body.Size = UDim2.fromOffset(bodyWidth, M.PanelHeight)
        self.Body.Position = UDim2.fromOffset(0, M.Title)
    else
        tween(self.Root, {Size = UDim2.fromOffset(width, height)}, T.Layout)
        tween(self.Body, {Size = UDim2.fromOffset(bodyWidth, M.PanelHeight), Position = UDim2.fromOffset(0, M.Title)}, T.Layout)
    end

    self:_Fit(width, height)

    if self.SearchFrame then
        local target = UDim2.new(0.5, 0, 0, M.Title + M.PanelHeight + M.Gap)
        -- With a single panel the search bar must not stick out past it.
        local searchWidth = math.min(M.SearchWidth, bodyWidth)
        if instant then
            self.SearchFrame.Position = target
            self.SearchFrame.Size = UDim2.fromOffset(searchWidth, M.Search)
        else
            tween(self.SearchFrame, {Position = target, Size = UDim2.fromOffset(searchWidth, M.Search)}, T.Layout)
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

    -- The layout tween may finish after the last AbsoluteSize signal; refresh
    -- once more so the glass lands exactly on the settled rectangle.
    if self.AcrylicEnabled then
        task.delay(0.36, function()
            self:_RefreshAcrylic()
        end)
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
        BackgroundTransparency = window.PanelTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.fromOffset(M.PanelWidth, M.PanelHeight),
        Position = UDim2.fromOffset((#window.Tabs) * (M.PanelWidth + M.Gap), -10),
        ZIndex = 2,
    }, window.Body)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, tab.Panel)
    -- Real bloom behind the panel (soft radial texture), so each tab reads as a
    -- lit slab instead of a flat rectangle with a fake layered halo.
    tab.Glow = create("ImageLabel", {
        Name = "PanelGlow",
        BackgroundTransparency = 1,
        Image = "rbxasset://textures/glow.png",
        ImageColor3 = theme.Accent,
        ImageTransparency = 0.72,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(Vector2.new(64, 64), Vector2.new(64, 64)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 26, 1, 26),
        ZIndex = 1,
    }, tab.Panel)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, tab.Glow)
    -- Soft vertical tint so the glass has depth instead of one flat colour.
    tab.Gradient = create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(theme.PanelTop, theme.PanelBottom),
    }, tab.Panel)
    -- Outer neon ring (the "glow").
    -- No edge highlight: a 1px line along the top read as an outline, and
    -- transparency gradients render flat on some clients. The panel's own
    -- PanelTop -> PanelBottom gradient already gives the glass its depth.

    -- The tab name is a caption ABOVE the panel, not a title bar inside it. It
    -- lives in Body (so it animates with the column) and floats over the gap.
    tab.Title = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = tab.Name,
        TextSize = 17,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0, -10),
        Size = UDim2.new(1, 0, 0, 20),
        ZIndex = 6,
    }, tab.Panel)


    tab.Scroll = create("ScrollingFrame", {
        Name = "Scroll",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.Accent,
        ScrollBarImageTransparency = 0.45,
        ScrollingEnabled = true,
        ClipsDescendants = true,
        ZIndex = 2,
    }, tab.Panel)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, tab.Scroll)
    -- Scrollbar auto-hide is newer than the rest of the API surface; guard it so
    -- older clients do not error on an unknown property.
    pcall(function()
        tab.Scroll.ScrollBarFadeDelay = 0.5
    end)
    -- Right padding leaves room for the scrollbar so rows never sit under it.
    create("UIPadding", {
        PaddingTop = UDim.new(0, M.Inset + 2),
        PaddingBottom = UDim.new(0, M.Inset + 4),
        PaddingLeft = UDim.new(0, M.Inset),
        PaddingRight = UDim.new(0, M.Inset + 4),
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

    -- Empty state: a quiet centred caption + a short accent tick above it, so a
    -- panel with no rows still looks designed instead of blank.
    tab.EmptyMark = create("Frame", {
        Name = "EmptyMark",
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 26),
        Size = UDim2.fromOffset(22, 2),
        Visible = false,
        ZIndex = 2,
    }, tab.Scroll)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, tab.EmptyMark)

    tab.EmptyLabel = create("TextLabel", {
        Name = "Empty",
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = "Nothing here",
        TextSize = 12,
        TextColor3 = theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 0, 20),
        Visible = false,
        ZIndex = 2,
    }, tab.Scroll)
    tab.EmptyMark.Visible = false

    window.Tabs[#window.Tabs + 1] = tab

    window:_Bind(tab.Title, function(themeNow, instant)
        applyColor(tab.Title, "TextColor3", themeNow.Text, instant, 0.26)
        if tab.Glow and isAlive(tab.Glow) then
            applyColor(tab.Glow, "ImageColor3", themeNow.Accent, instant, 0.26)
        end
    end)
    window:_Bind(tab.Panel, function(themeNow, instant)
        applyColor(tab.Panel, "BackgroundColor3", themeNow.Panel, instant, 0.26)
        if tab.Gradient and isAlive(tab.Gradient) then
            tab.Gradient.Color = ColorSequence.new(themeNow.PanelTop, themeNow.PanelBottom)
        end
        applyColor(tab.Scroll, "ScrollBarImageColor3", themeNow.Accent, instant, 0.26)
        applyColor(tab.EmptyLabel, "TextColor3", themeNow.Muted, instant, 0.26)
        if tab.EmptyMark then
            applyColor(tab.EmptyMark, "BackgroundColor3", themeNow.Accent, instant, 0.26)
        end
    end)

    window:_UpdateLayout(false)
    local resting = UDim2.fromOffset((#window.Tabs - 1) * (M.PanelWidth + M.Gap), 0)
    if not window.Options.NoIntro then
        -- Each new column rises into place a beat after the previous one, so
        -- adding three tabs looks like the menu unfolding sideways.
        local index = #window.Tabs
        tab.Panel.Position = UDim2.fromOffset(resting.X.Offset, -12)
        task.delay(math.min(index - 1, 5) * 0.035, function()
            if isAlive(tab.Panel) then
                tween(tab.Panel, {Position = resting}, T.Layout)
            end
        end)
    else
        tab.Panel.Position = resting
    end

    -- A tab added after the window exists still gets its own frosted island.
    if window.AcrylicEnabled then
        window:_AttachTabAcrylic(tab)
        window:_SetAcrylicVisible(window.Open)
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
    for _, sheet in ipairs(self.Acrylics or {}) do
        pcall(function()
            sheet:Destroy()
        end)
    end
    if self.AcrylicFolder and self.AcrylicFolder.Parent then
        pcall(function()
            self.AcrylicFolder:Destroy()
        end)
    end
    self.AcrylicFolder = nil
    self.Acrylics = {}
    for _, tab in ipairs(self.Tabs) do
        tab.Acrylic = nil
    end
    self.SearchAcrylic = nil
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
        -- Rows of a freshly built panel unfurl one after another instead of all
        -- sliding sideways at once. The cap keeps long lists quick.
        local index = #tab.Rows
        task.delay(math.min(index, 14) * 0.012, function()
            if isAlive(row.Frame) then
                tween(row.Frame, {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, M.RowHeight)}, T.Layout)
            end
        end)
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
    -- A hair of vertical shading inside the plate: flat fills read as stickers,
    -- this reads as a raised key. It is an opaque gradient, not an outline.
    row.BoxShade = create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(theme.Row:Lerp(Color3.new(1, 1, 1), 0.045), theme.Row),
    }, row.Box)

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

    row.Holder = create("Frame", {
        Name = "SettingsHolder",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, M.RowHeight + M.RowGap),
        Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 2,
    }, row.Slot)

    -- Row glow: a soft bloom that only shows for enabled rows and on hover.
    -- It lives in the slot (not on the plate) so the row's rounded clip never
    -- cuts it into a visible ring.
    row.Glow = create("ImageLabel", {
        Name = "RowGlow",
        BackgroundTransparency = 1,
        Image = "rbxasset://textures/glow.png",
        ImageColor3 = theme.Accent,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(Vector2.new(64, 64), Vector2.new(64, 64)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 16, 0, M.RowHeight + 16),
        ZIndex = 1,
    }, row.Slot)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Row)}, row.Glow)

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
        row:RefreshVisual(instant)
    end)

    row.Frame.MouseEnter:Connect(function()
        row.Hovered = true
        row:RefreshVisual()
        -- A barely-there lift gives the row depth without moving its hitbox.
        if not window.Options.Static then
            tween(row.Box, {Position = UDim2.fromOffset(0, -1)}, T.Hover)
        end
    end)
    row.Frame.MouseLeave:Connect(function()
        row.Hovered = false
        row:RefreshVisual()
        tween(row.Box, {Position = UDim2.fromOffset(0, 0)}, T.Hover)
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
        -- A short accent flash on the label confirms the press even for rows
        -- that do not change their background (buttons, dropdowns).
        if not row.Locked and not window.Options.Static then
            row.Label.TextColor3 = window.Theme.Accent
            task.delay(0.12, function()
                if isAlive(row.Label) then
                    row:RefreshVisual()
                end
            end)
        end
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
    elseif self.Action then
        fill, alpha = theme.On, (self.Hovered or open) and 0.02 or 0.10
    elseif open or self.Hovered then
        fill, alpha = theme.Hover, open and 0.02 or 0.04
    end

    local labelColor = self.Locked and theme.Muted or theme.Text

    -- Soft bloom: strong on enabled rows, faint on hover, off otherwise. It is a
    -- radial texture, so it fades out smoothly instead of drawing a ring.
    if self.Glow and isAlive(self.Glow) then
        applyColor(self.Glow, "ImageColor3", theme.Accent, instant, 0.22)
        -- Only rows that are ON or the action CTA glow; a hovered plain row
        -- should not light up, otherwise the whole list shimmers.
        local glowTarget = 1
        if self.OnState then
            glowTarget = (self.Hovered or open) and 0.42 or 0.60
        elseif self.Action then
            glowTarget = (self.Hovered or open) and 0.55 or 0.72
        end
        if instant then
            self.Glow.ImageTransparency = glowTarget
        else
            tween(self.Glow, {ImageTransparency = glowTarget}, T.Hover)
        end
    end

    applyColor(self.Box, "BackgroundColor3", fill, instant, 0.20)
    applyColor(self.Box, "BackgroundTransparency", alpha, instant, 0.20)
    if self.BoxShade and isAlive(self.BoxShade) then
        -- Keep the plate's subtle top-to-bottom shading in step with its fill.
        self.BoxShade.Color = ColorSequence.new(fill:Lerp(Color3.new(1, 1, 1), 0.045), fill)
    end
    applyColor(self.Label, "TextColor3", labelColor, instant, 0.20)
    applyColor(self.Dots, "TextColor3", (self.OnState or open) and theme.Accent or theme.Muted, instant, 0.20)
    -- The three-dot affordance lifts on hover instead of sitting dead.
    applyColor(self.Dots, "TextTransparency", (self.Dots.Visible and (self.Hovered or open)) and 0 or 0.35, instant, 0.20)

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
        PaddingTop = UDim.new(0, M.BlockPadding),
        PaddingBottom = UDim.new(0, M.BlockPadding),
        PaddingLeft = UDim.new(0, M.BlockPadding + 1),
        PaddingRight = UDim.new(0, M.BlockPadding + 1),
    }, panel)
    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, M.BlockGap),
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
    panel.Size = UDim2.new(1, 0, 0, settings.Height + M.BlockPadding * 2)
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
    self.SettingsHeight = self.Settings.Height + M.BlockPadding * 2 + M.RowGap
    local settings = self.Settings
    if not settings.Fade then
        settings.Fade = collectFade(settings.Panel)
    end
    local function setAlpha(alpha, instant)
        applyFade(settings.Fade, alpha, instant)
    end
    settings.SetAlpha = setAlpha
    if target then
        -- The block unfolds: the plate slides down from under the row while the
        -- controls ride up into place one after another. Stagger is capped so a
        -- very tall settings list still finishes inside a third of a second.
        settings.Panel.Position = UDim2.fromOffset(0, -8)
        setAlpha(1, true)
        setAlpha(0, false)
        task.defer(function()
            if self.SettingsOpen then
                tween(settings.Panel, {Position = UDim2.fromOffset(0, 0)}, T.Expand)
            end
        end)
        local step = math.min(0.026, 0.20 / math.max(#settings.Controls, 1))
        for index, control in ipairs(settings.Controls) do
            local entry = control.Frame
            if entry then
                entry.Position = UDim2.fromOffset(0, 6)
                task.delay(step * (index - 1), function()
                    if isAlive(entry) and self.SettingsOpen then
                        tween(entry, {Position = UDim2.fromOffset(0, 0)}, T.PopSoft)
                    end
                end)
            end
        end
    else
        -- Closing is quicker and never bounces: the plate folds up, then fades.
        setAlpha(1, false)
        tween(settings.Panel, {Position = UDim2.fromOffset(0, -8)}, T.Collapse)
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
    value = value and true or false
    if self.Visible == value then
        return
    end
    self.Visible = value
    if not isAlive(self.Slot) then
        return
    end
    if value then
        -- Filtering brings rows back by sliding them up a hair while the row
        -- fades in, so the list visibly re-forms instead of snapping.
        self.Slot.Visible = true
        if not self.Window.Options.NoIntro then
            self.Slot.Position = UDim2.fromOffset(0, 4)
            tween(self.Slot, {Position = UDim2.fromOffset(0, 0)}, T.PopSoft)
        end
    else
        self.Slot.Visible = false
    end
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
        total = total + (count - 1) * M.BlockGap
    end
    self.Height = total
    self.Panel.Size = UDim2.new(1, 0, 0, self.Height + M.BlockPadding * 2)
    return self.Height
end

function Settings:_Resize()
    self:_Measure()
    local row = self.Row
    if row.SettingsOpen then
        local before = row.SettingsHeight
        row.SettingsHeight = self.Height + M.BlockPadding * 2 + M.RowGap
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

    -- A slightly larger 15px box: at 13px the pixel tick had no room to breathe.
    local box = create("Frame", {
        Name = "Box",
        BackgroundColor3 = theme.Row,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -15, 0, 1),
        Size = UDim2.fromOffset(15, 15),
        ZIndex = 3,
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Small)}, box)
    -- Check mark drawn as a pixel glyph (same technique as the icon set):
    -- a short left arm and a longer right arm, centred in its own canvas. Two
    -- rotated bars looked like a "V" and drifted off-centre, so this is exact.
    local TICK = {
        ".........##",
        "........###",
        ".......###.",
        "##....###..",
        "###..###...",
        ".######....",
        "..####.....",
        "...##......",
    }
    local mark = create("Frame", {
        Name = "Mark",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(#TICK[1], #TICK),
        ClipsDescendants = true,
        ZIndex = 4,
    }, box)
    local tickPixels = {}
    for rowIndex, row in ipairs(TICK) do
        local column = 1
        while column <= #row do
            if row:sub(column, column) == "#" then
                local first = column
                while column <= #row and row:sub(column, column) == "#" do
                    column = column + 1
                end
                tickPixels[#tickPixels + 1] = create("Frame", {
                    Name = "Tick",
                    BackgroundColor3 = theme.Accent,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(first - 1, rowIndex - 1),
                    Size = UDim2.fromOffset(column - first, 1),
                    ZIndex = 5,
                }, mark)
            else
                column = column + 1
            end
        end
    end

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Font,
        Text = options.Name or "Enabled",
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -22, 1, 0),
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
        for _, pixel in ipairs(tickPixels) do
            applyColor(pixel, "BackgroundColor3", value and theme.Text or theme.Accent, instant, 0.16)
        end
        local glyphW, glyphH = #TICK[1], #TICK
        local scale = value and 1 or 0
        mark.Visible = value
        if instant then
            mark.Size = UDim2.fromOffset(glyphW * scale, glyphH * scale)
        else
            if value then
                mark.Size = UDim2.fromOffset(2, 2)
            end
            tween(mark, {Size = UDim2.fromOffset(glyphW * scale, glyphH * scale)}, T.Pop)
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
    -- 6px rounded rail with a glowing accent fill and a round knob that grows
    -- while the slider is being dragged. That knob is what makes a slider feel
    -- "physical" instead of like a progress bar.
    local track = create("Frame", {
        Name = "Track",
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 16),
        Size = UDim2.new(1, 0, 0, 6),
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
    local knob = create("Frame", {
        Name = "Knob",
        BackgroundColor3 = theme.Text,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(9, 9),
        ZIndex = 6,
    }, track)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
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
        local fillTarget = UDim2.new(alpha, 0, 1, 0)
        local knobTarget = UDim2.new(alpha, 0, 0.5, 0)
        if instant then
            fill.Size = fillTarget
            knob.Position = knobTarget
        else
            tween(fill, {Size = fillTarget}, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tween(knob, {Position = knobTarget}, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        end
        readout.Text = format(value) .. (options.Suffix or "")
    end

    local function setDragging(dragging)
        tween(knob, {
            Size = UDim2.fromOffset(dragging and 13 or 9, dragging and 13 or 9),
            BackgroundTransparency = dragging and 0 or 0.05,
        }, T.PopSoft)
        tween(track, {Size = UDim2.new(1, 0, 0, dragging and 7 or 6)}, T.Hover)
    end

    window:_Bind(frame, function(themeNow, instant)
        applyColor(label, "TextColor3", themeNow.Text, instant, 0.2)
        applyColor(readout, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(track, "BackgroundColor3", themeNow.Track, instant, 0.2)
        applyColor(fill, "BackgroundColor3", themeNow.Accent, instant, 0.2)
        applyColor(knob, "BackgroundColor3", themeNow.Text, instant, 0.2)
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
        setDragging(true)
        move(input.Position)
        beginDrag(input, move)
        -- beginDrag disconnects its own listeners; the knob deflates on release.
        local release
        release = UserInputService.InputEnded:Connect(function(finish)
            if finish.UserInputType == Enum.UserInputType.MouseButton1 or finish.UserInputType == Enum.UserInputType.Touch then
                setDragging(false)
                release:Disconnect()
            end
        end)

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
        applyColor(button, "BackgroundColor3", window.Theme.Hover, false, 0.16)
        tween(label, {TextColor3 = window.Theme.Accent}, T.Hover)
    end)
    button.MouseLeave:Connect(function()
        applyColor(button, "BackgroundColor3", window.Theme.Row, false, 0.16)
        tween(label, {TextColor3 = window.Theme.Text}, T.Hover)
    end)
    button.MouseButton1Click:Connect(function()
        -- Squish on press: the label dips a pixel and springs back.
        label.Position = UDim2.fromOffset(0, 1)
        tween(label, {Position = UDim2.fromOffset(0, 0)}, T.PopSoft)
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
    -- A real chevron instead of the letter "v": same pixels as the icon set,
    -- and it rotates 180 degrees when the list opens.
    local arrow, arrowPixels = pixelIcon(header, Minecraft.Icons.Chevron, window.Theme.Muted, 4)
    arrow.Name = "Arrow"
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(1, -10, 0.5, 0)

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
            button.BackgroundColor3 = window.Theme.Hover
            tween(button, {BackgroundTransparency = 0.68}, T.Hover)
        end)
        button.MouseLeave:Connect(function()
            tween(button, {BackgroundTransparency = 1}, T.Hover)
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
        tween(arrow, {Rotation = open and 180 or 0}, T.PopSoft)
    end)

    window:_Bind(frame, function(themeNow, instant)
        applyColor(header, "BackgroundColor3", themeNow.Row, instant, 0.2)
        applyColor(prefix, "TextColor3", themeNow.Muted, instant, 0.2)
        applyColor(valueLabel, "TextColor3", themeNow.Text, instant, 0.2)
        for _, pixel in ipairs(arrowPixels) do
            applyColor(pixel, "BackgroundColor3", themeNow.Muted, instant, 0.2)
        end
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
        local empty = shown == 0 and not self.Window.Options.NoEmptyState
        self.EmptyLabel.Visible = empty
        self.EmptyLabel.Text = (query ~= "" and query) and ("No results for \"" .. query .. "\"") or "Nothing here"
        if self.EmptyMark then
            self.EmptyMark.Visible = empty
        end
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

-- A plain "press me" row. With Settings it behaves like every other row: the
-- three dots appear on the right and a right click unfolds the controls below.
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

-- Pressable row that always renders as an accent CTA (used for Apply/Unload
-- style actions). Same Settings behaviour as AddButton.
function Tab:AddAction(options)
    if type(options) == "string" then
        options = {Name = options}
    end
    options = options or {}
    local row = self:AddButton(options)
    row.Action = true
    row.Box.BackgroundColor3 = row.Window.Theme.On
    row.Box.BackgroundTransparency = 0.1
    row.Label.TextXAlignment = Enum.TextXAlignment.Center
    if row.Glow then
        row.Glow.ImageTransparency = 0.72
        row.Glow.ImageColor3 = row.Window.Theme.Accent
    end
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
    row.Label.Position = UDim2.fromOffset(0, 6)
    row.Label.Size = UDim2.new(1, 0, 0, 14)
    row.Label.TextSize = 12
    row.Label.TextXAlignment = Enum.TextXAlignment.Left
    row.Label.Text = (name or "Section"):upper()
    row.Label.TextColor3 = theme.Muted
    window:_Bind(row.Label, function(themeNow, instant)
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
            applyColor(button, "BackgroundColor3", window.Theme.Hover, false, 0.12)
            tween(button, {BackgroundTransparency = 0.55}, T.Hover)
        end)
        button.MouseLeave:Connect(function()
            tween(button, {BackgroundTransparency = 1}, T.Hover)
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
    if popup.Acrylic then
        pcall(function()
            popup.Acrylic:Destroy()
        end)
        popup.Acrylic = nil
    end
    if instant then
        popup.Panel.Visible = false
    else
        tween(popup.Panel, {Size = UDim2.fromOffset(popup.Width, popup.Height * 0.92), BackgroundTransparency = 1}, T.FadeFast)
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
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Panel)}, panel)

    local fieldW = width - 16

    -- Saturation / value field ------------------------------------------------
    local function roundedClass()
        if pcall(function()
            return Instance.new("CanvasGroup")
        end) then
            return "CanvasGroup"
        end
        return "Frame"
    end

    -- The saturation/value field. Two layers, on purpose:
    --
    --   1. a solid-colour cell grid (20x13) that ALWAYS renders, used as the
    --      fallback — transparency gradients are unreliable on some clients;
    --   2. a smooth gradient image on top, tinted with the current hue, which is
    --      what you actually see when it loads (same approach as Fluent).
    --
    -- The grid is what made the old field look blocky; the image removes that,
    -- and if the image ever fails the field degrades to the grid instead of
    -- going flat white.
    local SV_GRADIENT = "rbxassetid://4155801252"

    local sv = create(roundedClass(), {
        Name = "SV",
        BackgroundColor3 = Color3.fromHSV(0, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.fromOffset(fieldW, fieldH),
        ClipsDescendants = true,
        ZIndex = 71,
    }, panel)
    if sv.ClassName == "CanvasGroup" then
        sv.GroupTransparency = 0
    end
    create("UICorner", {CornerRadius = UDim.new(0, Minecraft.Radius.Control)}, sv)

    local COLS, ROWS = 20, 13
    local cellW, cellH = fieldW / COLS, fieldH / ROWS
    local cells = {}
    for row = 0, ROWS - 1 do
        for column = 0, COLS - 1 do
            cells[row * COLS + column + 1] = create("Frame", {
                Name = "Cell",
                BackgroundColor3 = Color3.new(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(column * cellW, row * cellH),
                Size = UDim2.fromOffset(cellW + 0.6, cellH + 0.6),
                ZIndex = 72,
            }, sv)
        end
    end

    -- Smooth gradient plate: white -> hue horizontally, transparent -> black
    -- vertically, exactly like the reference pickers.
    local gradientLayer = create("ImageLabel", {
        Name = "Gradient",
        BackgroundTransparency = 1,
        Image = SV_GRADIENT,
        ScaleType = Enum.ScaleType.Stretch,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 73,
        Visible = false,
    }, sv)

    -- Repaint the grid for a hue. Runs of near-identical cells share one colour,
    -- so a drag only touches a handful of frames per row instead of 260.
    local lastHue = -1
    local function paintField(hue)
        if math.abs(hue - lastHue) < 0.004 then
            return
        end
        lastHue = hue
        for row = 0, ROWS - 1 do
            local value = 1 - (row + 0.5) / ROWS
            local runStart = 0
            local runColor = Color3.fromHSV(hue, 0.5 / COLS, value)
            for column = 0, COLS - 1 do
                local color = Color3.fromHSV(hue, (column + 0.5) / COLS, value)
                if column == COLS - 1
                    or math.abs(color.R - runColor.R) > 0.07
                    or math.abs(color.G - runColor.G) > 0.07
                    or math.abs(color.B - runColor.B) > 0.07 then
                    for at = runStart, column do
                        local cell = cells[row * COLS + at + 1]
                        if cell then
                            cell.BackgroundColor3 = runColor
                        end
                    end
                    runStart = column + 1
                    runColor = color
                end
            end
        end
        if isAlive(gradientLayer) then
            gradientLayer.ImageColor3 = Color3.fromHSV(hue, 1, 1)
        end
    end

    -- Show the smooth layer only once Roblox confirms the texture decoded.
    pcall(function()
        sv:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    end)
    local function revealGradient()
        if not isAlive(gradientLayer) then
            return
        end
        local loaded
        pcall(function()
            loaded = gradientLayer.IsLoaded
        end)
        if loaded == false then
            return
        end
        gradientLayer.Visible = true
    end
    task.defer(function()
        revealGradient()
        task.delay(0.35, revealGradient)
    end)

    local cursor = create("Frame", {
        Name = "Cursor",
        BackgroundColor3 = Color3.fromRGB(18, 16, 26),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(15, 15),
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
    local hue = create(roundedClass(), {
        Name = "Hue",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, hueY),
        Size = UDim2.fromOffset(fieldW, 14),
        ClipsDescendants = true,
        ZIndex = 71,
    }, panel)
    if hue.ClassName == "CanvasGroup" then
        hue.GroupTransparency = 0
    end
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
        alphaBar = create(roundedClass(), {
            Name = "AlphaBar",
            BackgroundColor3 = Color3.fromRGB(190, 190, 190),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(8, alphaY),
            Size = UDim2.fromOffset(fieldW, 12),
            ClipsDescendants = true,
            ZIndex = 71,
        }, panel)
        if alphaBar.ClassName == "CanvasGroup" then
            alphaBar.GroupTransparency = 0
        end
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
        paintField(self.H)
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

    -- Acrylic under the popup, so the picker is frosted too.
    state.Acrylic = self:_AttachAcrylic(panel, {Distance = 0.0012})
    if state.Acrylic then
        state.Acrylic:SetVisible(true)
    end

    -- Pop in from the anchor: slightly small + fully transparent -> settled.
    panel.Size = UDim2.fromOffset(width, height * 0.94)
    panel.BackgroundTransparency = 1
    tween(panel, {Size = UDim2.fromOffset(width, height), BackgroundTransparency = 0}, T.Pop)
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
