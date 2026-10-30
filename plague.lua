-- Plague: a compact Roblox UI library inspired by the Plaguecheat menu.
-- UI only: controls do not implement gameplay features.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Plague = {}
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Subtab = {}
Subtab.__index = Subtab
local Section = {}
Section.__index = Section

local C = {
    background = Color3.fromRGB(12, 12, 13),
    header = Color3.fromRGB(17, 17, 18),
    panel = Color3.fromRGB(18, 18, 19),
    field = Color3.fromRGB(13, 13, 14),
    border = Color3.fromRGB(36, 36, 38),
    text = Color3.fromRGB(220, 220, 222),
    muted = Color3.fromRGB(133, 133, 137),
    accent = Color3.fromRGB(77, 122, 181),
}

local childOrder = setmetatable({}, {__mode = "k"})
local function create(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    if parent and object:IsA("GuiObject") and (not properties or properties.LayoutOrder == nil) then
        childOrder[parent] = (childOrder[parent] or 0) + 1
        object.LayoutOrder = childOrder[parent]
    end
    object.Parent = parent
    return object
end

local function border(parent, color)
    return create("UIStroke", {Color = color or C.border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
end

local function list(parent, padding, horizontal)
    return create("UIListLayout", {
        FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, padding or 0),
    }, parent)
end

local function text(parent, value, size, color)
    return create("TextLabel", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = Enum.Font.Arial, TextSize = size or 12, TextColor3 = color or C.text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = value or "",
    }, parent)
end

local function button(parent, value)
    return create("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Font = Enum.Font.Arial, TextSize = 12, TextColor3 = C.text,
        Text = value or "",
    }, parent)
end

-- Pixel icons are drawn with native Frames, not downloaded assets or font glyphs.
-- This makes them usable offline and avoids private/deleted Roblox image IDs.
local Icons = {
    target = {"000010000", "001111100", "010010010", "010010010", "111111111", "010010010", "010010010", "001111100", "000010000"},
    eye = {"000000000", "000111000", "011000110", "100111001", "101111101", "100111001", "011000110", "000111000", "000000000"},
    user = {"001111100", "010000010", "010000010", "001111100", "000000000", "001111100", "010000010", "100000001", "111111111"},
    globe = {"001111100", "010111010", "101010101", "101010101", "111111111", "101010101", "101010101", "010111010", "001111100"},
    settings = {"000111000", "100111001", "111000111", "011010110", "110000011", "011010110", "111000111", "100111001", "000111000"},
    palette = {"001111100", "010000010", "101010101", "100000001", "101010101", "100000001", "010001110", "001110000", "000000000"},
    layers = {"000010000", "000111000", "011111110", "110101011", "011111110", "110101011", "011111110", "001111100", "000100000"},
    folder = {"111100000", "100011111", "100000001", "100000001", "100000001", "100000001", "100000001", "111111111", "000000000"},
    sliders = {"010001000", "010001000", "111001111", "010001000", "010001000", "010111000", "010001000", "010001000", "010001000"},
    check = {"000000000", "000000001", "000000010", "100000100", "010001000", "001010000", "000100000", "000000000", "000000000"},
    down = {"000000000", "000000000", "010000010", "001000100", "000101000", "000010000", "000000000", "000000000", "000000000"},
}
Plague.Icons = Icons

local function icon(parent, name, color)
    local pattern = Icons[name]
    assert(pattern, "Plague: unknown icon '" .. tostring(name) .. "'")
    local holder = create("Frame", {Name = "Icon_" .. name, Size = UDim2.fromOffset(9, 9), BackgroundTransparency = 1, BorderSizePixel = 0}, parent)
    local pixels = {}
    for y, line in ipairs(pattern) do
        local x = 1
        while x <= #line do
            if line:sub(x, x) == "1" then
                local first = x
                while x <= #line and line:sub(x, x) == "1" do x = x + 1 end
                table.insert(pixels, create("Frame", {
                    Position = UDim2.fromOffset(first - 1, y - 1), Size = UDim2.fromOffset(x - first, 1),
                    BackgroundColor3 = color, BorderSizePixel = 0,
                }, holder))
            else
                x = x + 1
            end
        end
    end
    local function tint(newColor)
        for _, pixel in ipairs(pixels) do pixel.BackgroundColor3 = newColor end
    end
    return holder, tint
end

local function decorateButton(buttonObject, name, iconName, color)
    local picture, tint = icon(buttonObject, iconName, color)
    picture.Position = UDim2.new(0, 5, 0.5, -4)
    local caption = text(buttonObject, name, 12, color)
    caption.Position = UDim2.fromOffset(18, 0)
    caption.Size = UDim2.new(1, -21, 1, 0)
    caption.TextTruncate = Enum.TextTruncate.AtEnd
    buttonObject.Text = ""
    return function(newColor) caption.TextColor3 = newColor; tint(newColor) end
end

local function safeCall(callback, value)
    if callback then
        local ok, err = pcall(callback, value)
        if not ok then warn("[Plague] callback: " .. tostring(err)) end
    end
end

local function option(options, key, fallback)
    local value = options[key]
    if value == nil then return fallback end
    return value
end

function Plague.new(options)
    options = options or {}
    local self = setmetatable({
        Accent = options.Accent or C.accent, ToggleKey = options.ToggleKey or Enum.KeyCode.Insert,
        Flags = {}, Tabs = {}, Connections = {}, Visible = true, Destroyed = false,
    }, Window)
    local player = Players.LocalPlayer
    assert(player, "Plague must run on the client")
    -- CoreGui requires an environment with permission to parent GUIs there.
    -- In a normal LocalScript, callers can pass PlayerGui explicitly instead.
    local gui = create("ScreenGui", {Name = options.Name or "Plague", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    local ok, err = pcall(function() gui.Parent = options.Parent or CoreGui end)
    if not ok then
        gui:Destroy()
        error("Plague: cannot parent to CoreGui; pass Parent = Players.LocalPlayer.PlayerGui in Studio. " .. tostring(err))
    end
    self.Gui = gui
    local root = create("Frame", {
        Name = "Window", Size = options.Size or UDim2.fromOffset(490, 420),
        Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.background, BorderSizePixel = 0,
    }, gui)
    self.Root = root
    border(root, Color3.fromRGB(60, 60, 62))
    local header = create("Frame", {Size = UDim2.new(1, 0, 0, 25), BackgroundColor3 = C.header, BorderSizePixel = 0, Active = true}, root)
    local title = text(header, options.Title or "Plaguecheat.cc", 12, C.text)
    title.Position = UDim2.fromOffset(7, 0)
    title.Size = UDim2.new(0, 135, 1, 0)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    local tabBar = create("ScrollingFrame", {
        Position = UDim2.fromOffset(142, 0), Size = UDim2.new(1, -149, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(),
    }, header)
    local tabLayout = list(tabBar, 0, true)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    self.TabBar = tabBar
    -- Keep the tabs flush to the right, while still allowing overflow to scroll.
    local function resizeTabs()
        local width = math.max(tabBar.AbsoluteSize.X, tabLayout.AbsoluteContentSize.X)
        tabBar.CanvasSize = UDim2.fromOffset(width, 0)
        tabBar.CanvasPosition = Vector2.new(math.max(0, width - tabBar.AbsoluteSize.X), 0)
    end
    self:_connect(tabBar:GetPropertyChangedSignal("AbsoluteSize"), resizeTabs)
    self:_connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), resizeTabs)
    resizeTabs()
    create("Frame", {Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = self.Accent, BorderSizePixel = 0}, root)
    local subLayer = create("Frame", {
        Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 25),
        BackgroundColor3 = C.header, BorderSizePixel = 0,
    }, root)
    local subBar = create("ScrollingFrame", {
        Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -14, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
    }, subLayer)
    list(subBar, 0, true)
    self.SubBar = subBar
    create("Frame", {Position = UDim2.fromOffset(0, 51), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.border, BorderSizePixel = 0}, root)
    self.Content = create("Frame", {Position = UDim2.fromOffset(12, 63), Size = UDim2.new(1, -24, 1, -75), BackgroundTransparency = 1, BorderSizePixel = 0}, root)

    self:_connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.Drag = {input = input, start = input.Position, position = root.Position}
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if self.Drag and (input == self.Drag.input or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - self.Drag.start
            local p = self.Drag.position
            root.Position = UDim2.new(p.X.Scale, p.X.Offset + delta.X, p.Y.Scale, p.Y.Offset + delta.Y)
        end
        if self.SliderDrag and (input == self.SliderDrag.input or input.UserInputType == Enum.UserInputType.MouseMovement) then
            self.SliderDrag.update(input.Position.X)
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if self.Drag and (input == self.Drag.input or input.UserInputType == Enum.UserInputType.MouseButton1) then self.Drag = nil end
        if self.SliderDrag and (input == self.SliderDrag.input or input.UserInputType == Enum.UserInputType.MouseButton1) then self.SliderDrag = nil end
    end)
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if self.CapturingKey then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local capture = self.CapturingKey
                self.CapturingKey = nil
                if input.KeyCode == Enum.KeyCode.Escape then capture(nil) else capture(input.KeyCode) end
            end
            return
        end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == self.ToggleKey then self:Toggle() return end
        if processed then return end
        for _, bind in ipairs(self.Keybinds or {}) do
            if bind.key and input.KeyCode == bind.key then safeCall(bind.callback, bind.key) end
        end
    end)
    return self
end

function Window:_connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function Window:Toggle(value)
    if value == nil then value = not self.Visible end
    self.Visible = value == true
    self.Root.Visible = self.Visible
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Drag, self.SliderDrag, self.CapturingKey = nil, nil, nil
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    self.Gui:Destroy()
end

function Window:Tab(name, options)
    options = options or {}
    local tab = setmetatable({Window = self, Name = name, Subtabs = {}}, Tab)
    local nav = button(self.TabBar, name)
    nav.Size = UDim2.fromOffset(math.max(35, #name * 6 + 12) + (options.Icon and 14 or 0), 25)
    nav.TextColor3 = C.muted
    if options.Icon then tab.Tint = decorateButton(nav, name, options.Icon, C.muted) end
    tab.Button = nav
    self:_connect(nav.MouseButton1Click, function() self:SelectTab(tab) end)
    self:_connect(nav.MouseEnter, function()
        nav.TextColor3 = C.text
        if tab.Tint then tab.Tint(C.text) end
    end)
    self:_connect(nav.MouseLeave, function()
        local color = self.ActiveTab == tab and C.text or C.muted
        nav.TextColor3 = color
        if tab.Tint then tab.Tint(color) end
    end)
    table.insert(self.Tabs, tab)
    if not self.ActiveTab then self:SelectTab(tab) end
    return tab
end

function Window:SelectTab(tab)
    assert(tab.Window == self, "Tab belongs to another window")
    self.ActiveTab = tab
    for _, item in ipairs(self.Tabs) do
        local active = item == tab
        item.Button.TextColor3 = active and C.text or C.muted
        if item.Tint then item.Tint(active and C.text or C.muted) end
        for _, sub in ipairs(item.Subtabs) do
            sub.Button.Visible = active
            sub.Page.Visible = active and item.ActiveSubtab == sub
        end
    end
end

function Tab:Subtab(name, options)
    options = options or {}
    local window = self.Window
    local sub = setmetatable({Tab = self, Window = window, Name = name}, Subtab)
    local nav = button(window.SubBar, name)
    nav.Size = UDim2.fromOffset(math.max(35, #name * 6 + 12) + (options.Icon and 14 or 0), 25)
    nav.TextColor3 = C.muted
    if options.Icon then sub.Tint = decorateButton(nav, name, options.Icon, C.muted) end
    sub.Button = nav
    local page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = window.Accent,
        ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), Visible = false,
    }, window.Content)
    sub.Page = page
    for i = 1, 2 do
        local column = create("Frame", {
            Position = UDim2.new((i - 1) * 0.5, i == 1 and 0 or 4, 0, 0),
            Size = UDim2.new(0.5, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, BorderSizePixel = 0,
        }, page)
        list(column, 10)
        if i == 1 then sub.Left = column else sub.Right = column end
    end
    table.insert(self.Subtabs, sub)
    window:_connect(nav.MouseButton1Click, function() self:SelectSubtab(sub) end)
    window:_connect(nav.MouseEnter, function()
        nav.TextColor3 = C.text
        if sub.Tint then sub.Tint(C.text) end
    end)
    window:_connect(nav.MouseLeave, function()
        local color = self.ActiveSubtab == sub and C.text or C.muted
        nav.TextColor3 = color
        if sub.Tint then sub.Tint(color) end
    end)
    if not self.ActiveSubtab then self:SelectSubtab(sub) end
    nav.Visible = window.ActiveTab == self
    page.Visible = window.ActiveTab == self and self.ActiveSubtab == sub
    return sub
end

function Tab:SelectSubtab(sub)
    assert(sub.Tab == self, "Subtab belongs to another tab")
    self.ActiveSubtab = sub
    for _, item in ipairs(self.Subtabs) do
        local active = item == sub
        item.Button.TextColor3 = active and C.text or C.muted
        if item.Tint then item.Tint(active and C.text or C.muted) end
        item.Page.Visible = active and self.Window.ActiveTab == self
    end
end

function Subtab:Section(name, side)
    local parent = (side == "Right" or side == "right" or side == 2) and self.Right or self.Left
    local frame = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel, BorderSizePixel = 0}, parent)
    border(frame)
    create("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, frame)
    list(frame, 1)
    local heading = text(frame, name, 11, C.muted)
    heading.Size = UDim2.new(1, 0, 0, 16)
    return setmetatable({Frame = frame, Window = self.Window}, Section)
end

local function row(section, height)
    return create("Frame", {Size = UDim2.new(1, 0, 0, height or 19), BackgroundTransparency = 1, BorderSizePixel = 0}, section.Frame)
end

local function register(section, options, value)
    local flag = options.Flag
    if flag then section.Window.Flags[flag] = value end
    return function(newValue)
        if flag then section.Window.Flags[flag] = newValue end
        safeCall(options.Callback, newValue)
    end
end

function Section:Label(value)
    local label = text(self.Frame, value, 12, C.muted)
    label.Size = UDim2.new(1, 0, 0, 20)
    label.TextTruncate = Enum.TextTruncate.AtEnd
    return {Set = function(_, newValue) label.Text = tostring(newValue) end}
end

function Section:Button(options)
    local b = button(self.Frame, options.Name or "Button")
    b.Size = UDim2.new(1, 0, 0, 24)
    b.BackgroundTransparency = 0
    b.BackgroundColor3 = C.field
    border(b)
    if options.Icon then decorateButton(b, options.Name or "Button", options.Icon, C.text) end
    self.Window:_connect(b.MouseButton1Click, function() safeCall(options.Callback) end)
    return b
end

function Section:Toggle(options)
    local value = option(options, "Default", false) == true
    local changed = register(self, options, value)
    local r = row(self)
    local b = button(r, "")
    b.Size = UDim2.fromScale(1, 1)
    local box = create("Frame", {Size = UDim2.fromOffset(7, 7), Position = UDim2.new(0, 5, 0.5, -3), BackgroundColor3 = C.field, BorderSizePixel = 0}, b)
    border(box)
    local label = text(b, options.Name or "Toggle", 12)
    label.Position = UDim2.fromOffset(23, 0)
    label.Size = UDim2.new(1, -23, 1, 0)
    local control = {}
    function control:Set(newValue, silent)
        value = newValue == true
        box.BackgroundColor3 = value and self._accent or C.field
        label.TextColor3 = value and C.text or C.muted
        if silent then if options.Flag then self._window.Flags[options.Flag] = value end else changed(value) end
    end
    function control:Get() return value end
    control._accent, control._window = self.Window.Accent, self.Window
    self.Window:_connect(b.MouseButton1Click, function() control:Set(not value) end)
    control:Set(value, true)
    if options.Color then
        -- Optional right-aligned swatch, like the color controls in the reference menu.
        local swatch = button(r, "")
        swatch.Position = UDim2.new(1, -20, 0.5, -4)
        swatch.Size = UDim2.fromOffset(16, 8)
        swatch.BackgroundTransparency = 0
        swatch.BackgroundColor3 = options.Color
        border(swatch)
        label.Size = UDim2.new(1, -48, 1, 0)
        local pickerHolder = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false}, self.Frame)
        list(pickerHolder, 0)
        local inner = setmetatable({Frame = pickerHolder, Window = self.Window}, Section)
        local picker, color = nil, options.Color
        local window = self.Window
        if options.ColorFlag then window.Flags[options.ColorFlag] = color end
        function control:SetColor(newColor, silent)
            assert(typeof(newColor) == "Color3", "Toggle color expects a Color3")
            color = newColor
            swatch.BackgroundColor3 = color
            if picker then picker:Set(color, true) end
            if options.ColorFlag then window.Flags[options.ColorFlag] = color end
            if not silent then safeCall(options.ColorCallback, color) end
        end
        function control:GetColor() return color end
        self.Window:_connect(swatch.MouseButton1Click, function()
            if not picker then
                picker = inner:ColorPicker({Default = color, Inline = true, Callback = function(newColor)
                    control:SetColor(newColor)
                end})
            end
            pickerHolder.Visible = not pickerHolder.Visible
        end)
    end
    return control
end

function Section:Slider(options)
    local min = options.Min or 0
    local max = options.Max or 100
    local step = options.Step or 1
    assert(max > min and step > 0, "Slider requires Max > Min and Step > 0")
    local value
    local changed = register(self, options, nil)
    local r = row(self, 35)
    local label = text(r, options.Name or "Slider", 12)
    label.Size = UDim2.new(1, -65, 0, 18)
    local number = text(r, "", 11, C.muted)
    number.TextXAlignment = Enum.TextXAlignment.Right
    number.Position = UDim2.new(1, -65, 0, 0)
    number.Size = UDim2.fromOffset(65, 18)
    local minus = button(r, "-")
    minus.Position = UDim2.fromOffset(0, 18)
    minus.Size = UDim2.fromOffset(14, 16)
    minus.TextColor3 = C.muted
    local plus = button(r, "+")
    plus.Position = UDim2.new(1, -14, 0, 18)
    plus.Size = UDim2.fromOffset(14, 16)
    plus.TextColor3 = C.muted
    local track = create("Frame", {Position = UDim2.fromOffset(16, 19), Size = UDim2.new(1, -32, 0, 16), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true}, r)
    local rail = create("Frame", {Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = C.field, BorderSizePixel = 0}, track)
    border(rail)
    local fill = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = self.Window.Accent, BorderSizePixel = 0}, rail)
    local control = {}
    function control:Set(newValue, silent)
        newValue = tonumber(newValue) or min
        value = math.clamp(min + math.floor((newValue - min) / step + 0.5) * step, min, max)
        value = math.floor(value * 1000000 + 0.5) / 1000000
        fill.Size = UDim2.fromScale((value - min) / (max - min), 1)
        number.Text = tostring(value) .. (options.Suffix or "")
        if silent then if options.Flag then self._window.Flags[options.Flag] = value end else changed(value) end
    end
    function control:Get() return value end
    control._window = self.Window
    local function update(x)
        if track.AbsoluteSize.X > 0 then control:Set(min + math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (max - min)) end
    end
    self.Window:_connect(minus.MouseButton1Click, function() control:Set(value - step) end)
    self.Window:_connect(plus.MouseButton1Click, function() control:Set(value + step) end)
    self.Window:_connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.Window.SliderDrag = {input = input, update = update}
            update(input.Position.X)
        end
    end)
    control:Set(option(options, "Default", min), true)
    return control
end

function Section:Dropdown(options)
    local choices = options.Options or {}
    local multi = options.Multi == true
    local selected, value = {}, nil
    local changed = register(self, options, nil)
    local container = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, self.Frame)
    list(container, 3)
    local label = text(container, options.Name or "Dropdown", 12)
    label.Size = UDim2.new(1, 0, 0, 18)
    local main = button(container, "")
    main.Size = UDim2.new(1, 0, 0, 22)
    main.BackgroundTransparency = 0
    main.BackgroundColor3 = C.field
    border(main)
    local display = text(main, "", 12, C.muted)
    display.Position = UDim2.fromOffset(7, 0)
    display.Size = UDim2.new(1, -25, 1, 0)
    display.TextTruncate = Enum.TextTruncate.AtEnd
    local arrow = icon(main, "down", C.muted)
    arrow.Position = UDim2.new(1, -16, 0.5, -4)
    local items = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, math.min(math.max(#choices * 21, 21), 126)),
        BackgroundColor3 = C.field, BorderSizePixel = 0, Visible = false,
        ScrollBarThickness = 3, ScrollBarImageColor3 = self.Window.Accent,
        ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
    }, container)
    border(items)
    list(items, 1)
    local rows = {}
    local control = {}
    local function contains(choice)
        for _, item in ipairs(choices) do if item == choice then return true end end
        return false
    end
    local function copySelected()
        local out = {}
        for _, item in ipairs(choices) do if selected[item] then table.insert(out, item) end end
        return out
    end
    local function refresh()
        local shown = multi and table.concat(copySelected(), ", ") or (value and tostring(value) or "None")
        display.Text = shown == "" and "None" or shown
        for _, entry in ipairs(rows) do
            local active = multi and selected[entry.choice] or (not multi and value == entry.choice)
            entry.label.TextColor3 = active and self.Window.Accent or C.muted
            entry.check.Visible = active and true or false
        end
    end
    function control:Set(newValue, silent)
        if multi then
            selected = {}
            for _, item in ipairs(type(newValue) == "table" and newValue or {}) do if contains(item) then selected[item] = true end end
            value = copySelected()
        else
            value = contains(newValue) and newValue or nil
        end
        refresh()
        local output = multi and copySelected() or value
        if silent then if options.Flag then self._window.Flags[options.Flag] = output end else changed(output) end
    end
    function control:Get() return multi and copySelected() or value end
    control._window = self.Window
    self.Window:_connect(main.MouseButton1Click, function() items.Visible = not items.Visible end)
    for _, choice in ipairs(choices) do
        local item = button(items, "")
        item.Size = UDim2.new(1, -3, 0, 20)
        local itemLabel = text(item, tostring(choice), 12, C.muted)
        itemLabel.Position = UDim2.fromOffset(7, 0)
        itemLabel.Size = UDim2.new(1, -25, 1, 0)
        itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
        local mark = icon(item, "check", self.Window.Accent)
        mark.Position = UDim2.new(1, -14, 0.5, -4)
        table.insert(rows, {choice = choice, label = itemLabel, check = mark})
        self.Window:_connect(item.MouseButton1Click, function()
            if multi then
                selected[choice] = not selected[choice]
                control:Set(copySelected())
            else
                control:Set(choice)
                items.Visible = false
            end
        end)
    end
    if #choices == 0 then
        local empty = text(items, "  No options", 12, C.muted)
        empty.Size = UDim2.new(1, 0, 0, 20)
    end
    control:Set(options.Default, true)
    return control
end

-- A permanently visible, scrollable single-select list, used by skins/config pages.
function Section:Listbox(options)
    local choices = options.Options or {}
    local value
    local changed = register(self, options, nil)
    local label = text(self.Frame, options.Name or "List", 12, C.muted)
    label.Size = UDim2.new(1, 0, 0, 18)
    local items = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, math.max(40, options.Height or 120)),
        BackgroundColor3 = C.field, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = self.Window.Accent,
        ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
    }, self.Frame)
    border(items)
    list(items, 0)
    local rows, window = {}, self.Window
    local control = {}
    function control:Set(newValue, silent)
        value = nil
        for _, choice in ipairs(choices) do if choice == newValue then value = choice; break end end
        for _, entry in ipairs(rows) do
            local active = entry.choice == value
            entry.label.TextColor3 = active and C.text or C.muted
            entry.mark.Visible = active
        end
        if options.Flag then window.Flags[options.Flag] = value end
        if not silent then safeCall(options.Callback, value) end
    end
    function control:Get() return value end
    for _, choice in ipairs(choices) do
        local item = button(items, "")
        item.Size = UDim2.new(1, -3, 0, 20)
        local itemLabel = text(item, tostring(choice), 12, C.muted)
        itemLabel.Position = UDim2.fromOffset(8, 0)
        itemLabel.Size = UDim2.new(1, -24, 1, 0)
        itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
        local mark = icon(item, "check", window.Accent)
        mark.Position = UDim2.new(1, -15, 0.5, -4)
        table.insert(rows, {choice = choice, label = itemLabel, mark = mark})
        window:_connect(item.MouseButton1Click, function() control:Set(choice) end)
    end
    if #choices == 0 then
        local empty = text(items, "  No options", 12, C.muted)
        empty.Size = UDim2.new(1, 0, 0, 20)
    end
    control:Set(options.Default, true)
    return control
end

function Section:Textbox(options)
    local r = row(self, 45)
    local label = text(r, options.Name or "Text", 12)
    label.Size = UDim2.new(1, 0, 0, 18)
    local box = create("TextBox", {
        Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = C.field, BorderSizePixel = 0, Font = Enum.Font.Arial, TextSize = 12,
        TextColor3 = C.text, PlaceholderColor3 = C.muted, PlaceholderText = options.Placeholder or "",
        Text = tostring(options.Default or ""), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    }, r)
    border(box)
    create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, box)
    local changed = register(self, options, box.Text)
    local control = {}
    function control:Set(value, silent)
        box.Text = tostring(value or "")
        if silent then if options.Flag then self._window.Flags[options.Flag] = box.Text end else changed(box.Text) end
    end
    function control:Get() return box.Text end
    control._window = self.Window
    self.Window:_connect(box.FocusLost, function() changed(box.Text) end)
    return control
end

function Section:Keybind(options)
    local r = row(self)
    local label = text(r, options.Name or "Keybind", 12)
    label.Size = UDim2.new(1, -100, 1, 0)
    local keyButton = button(r, "")
    keyButton.Position = UDim2.new(1, -100, 0, 0)
    keyButton.Size = UDim2.fromOffset(100, 22)
    keyButton.TextXAlignment = Enum.TextXAlignment.Right
    keyButton.TextColor3 = C.muted
    local binding = {key = options.Default, callback = options.Callback}
    self.Window.Keybinds = self.Window.Keybinds or {}
    table.insert(self.Window.Keybinds, binding)
    local window = self.Window
    local control = {}
    function control:Set(key, silent)
        assert(key == nil or (typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode), "Keybind expects a KeyCode or nil")
        binding.key = key
        keyButton.Text = key and ("[" .. key.Name .. "]") or "[None]"
        if options.Flag then window.Flags[options.Flag] = key end
        if not silent then safeCall(options.Changed, key) end
    end
    function control:Get() return binding.key end
    self.Window:_connect(keyButton.MouseButton1Click, function()
        keyButton.Text = "[press key]"
        window.CapturingKey = function(key) control:Set(key) end
    end)
    control:Set(binding.key, true)
    return control
end

-- The picker uses three inline RGB sliders, with no external image assets.
function Section:ColorPicker(options)
    local color = options.Default or Color3.fromRGB(255, 255, 255)
    local window = self.Window
    local changed = register(self, options, color)
    local holder = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, self.Frame)
    list(holder, 4)
    local top = button(holder, options.Name or "Color")
    top.Size = UDim2.new(1, 0, 0, 22)
    top.TextXAlignment = Enum.TextXAlignment.Left
    local swatch = create("Frame", {Size = UDim2.fromOffset(20, 10), Position = UDim2.new(1, -20, 0.5, -5), BackgroundColor3 = color, BorderSizePixel = 0}, top)
    border(swatch)
    local channels = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = options.Inline == true}, holder)
    if options.Inline then top.Visible = false end
    list(channels, 3)
    local inner = setmetatable({Frame = channels, Window = window}, Section)
    local sliders = {}
    local control = {}
    function control:Set(newColor, silent)
        assert(typeof(newColor) == "Color3", "ColorPicker expects a Color3")
        color = newColor
        swatch.BackgroundColor3 = color
        if sliders[1] then
            sliders[1]:Set(math.floor(color.R * 255 + 0.5), true)
            sliders[2]:Set(math.floor(color.G * 255 + 0.5), true)
            sliders[3]:Set(math.floor(color.B * 255 + 0.5), true)
        end
        if silent then if options.Flag then window.Flags[options.Flag] = color end else changed(color) end
    end
    function control:Get() return color end
    for i, name in ipairs({"R", "G", "B"}) do
        sliders[i] = inner:Slider({Name = name, Min = 0, Max = 255, Default = 0, Callback = function()
            control:Set(Color3.fromRGB(sliders[1]:Get(), sliders[2]:Get(), sliders[3]:Get()))
        end})
    end
    self.Window:_connect(top.MouseButton1Click, function() channels.Visible = not channels.Visible end)
    control:Set(color, true)
    return control
end

return Plague
