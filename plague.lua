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

-- Sampled from the CS2 reference screenshot; text remains readable at 1x.
local C = {
    background = Color3.fromRGB(14, 14, 14),
    header = Color3.fromRGB(20, 20, 20),
    panel = Color3.fromRGB(21, 21, 21),
    field = Color3.fromRGB(12, 12, 12),
    border = Color3.fromRGB(29, 29, 29),
    text = Color3.fromRGB(210, 210, 210),
    muted = Color3.fromRGB(137, 137, 137),
    accent = Color3.fromRGB(80, 115, 164),
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
    -- Draw inside the object instead of centering a stroke outside its bounds.
    -- This keeps all four edges visible even inside a clipping ScrollingFrame.
    parent.BorderSizePixel = 1
    parent.BorderColor3 = color or C.border
    parent.BorderMode = Enum.BorderMode.Inset
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
        Font = Enum.Font.Arial, TextSize = size or 13, TextColor3 = color or C.text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = value or "",
    }, parent)
end

local function button(parent, value)
    return create("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Font = Enum.Font.Arial, TextSize = 13, TextColor3 = C.text,
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
    local caption = text(buttonObject, name, 13, color)
    caption.Position = UDim2.fromOffset(18, 0)
    caption.Size = UDim2.new(1, -21, 1, 0)
    caption.TextTruncate = Enum.TextTruncate.AtEnd
    buttonObject.Text = ""
    return function(newColor) caption.TextColor3 = newColor; tint(newColor) end
end

local function swatchChecker(parent, position, size)
    local base = create("Frame", {Position = position, Size = size, BackgroundColor3 = Color3.fromRGB(65, 65, 65), BorderSizePixel = 0}, parent)
    for y = 0, 1 do
        for x = 0, 3 do
            if (x + y) % 2 == 0 then
                create("Frame", {Position = UDim2.fromScale(x / 4, y / 2), Size = UDim2.fromScale(0.25, 0.5), BackgroundColor3 = Color3.fromRGB(145, 145, 145), BorderSizePixel = 0}, base)
            end
        end
    end
    return base
end

local function safeCall(callback, ...)
    if callback then
        local ok, err = pcall(callback, ...)
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
    local scale = option(options, "Scale", 1)
    assert(type(scale) == "number" and scale > 0, "Plague Scale must be a positive number")
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
    self.Scale = create("UIScale", {Scale = scale}, root)
    border(root, Color3.fromRGB(43, 43, 43))
    local header = create("Frame", {Size = UDim2.new(1, 0, 0, 25), BackgroundColor3 = C.header, BorderSizePixel = 0, Active = true}, root)
    local title = text(header, options.Title or "Plaguecheat.cc", 13, C.text)
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
        Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 19),
        BackgroundColor3 = C.header, BorderSizePixel = 0,
    }, root)
    local subBar = create("ScrollingFrame", {
        Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -14, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
    }, subLayer)
    list(subBar, 0, true)
    self.SubBar, self.SubLayer = subBar, subLayer
    self.SubDivider = create("Frame", {Position = UDim2.fromOffset(0, 45), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.border, BorderSizePixel = 0}, root)
    self.Content = create("Frame", {Position = UDim2.fromOffset(12, 55), Size = UDim2.new(1, -24, 1, -65), BackgroundTransparency = 1, BorderSizePixel = 0}, root)
    -- Popups are direct high-Z children of the window, never children of a
    -- clipping section. No full-size transparent overlay blocks normal clicks.
    self.PopupLayer = root
    self:_layoutSubtabs()

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
        if self.PopupDrag and (input == self.PopupDrag.input or input.UserInputType == Enum.UserInputType.MouseMovement) then
            self.PopupDrag.update(input.Position)
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if self.Drag and (input == self.Drag.input or input.UserInputType == Enum.UserInputType.MouseButton1) then self.Drag = nil end
        if self.SliderDrag and (input == self.SliderDrag.input or input.UserInputType == Enum.UserInputType.MouseButton1) then self.SliderDrag = nil end
        if self.PopupDrag and (input == self.PopupDrag.input or input.UserInputType == Enum.UserInputType.MouseButton1) then self.PopupDrag = nil end
    end)
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if self.OpenPopup and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local p = input.Position
            local function inside(object)
                local pos, size = object.AbsolutePosition, object.AbsoluteSize
                return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
            end
            if not inside(self.OpenPopup.frame) and not inside(self.OpenPopup.anchor) then self:_closePopup() end
        end
        if self.OpenPopup and input.KeyCode == Enum.KeyCode.Escape and not self.CapturingKey then self:_closePopup(); return end
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

function Window:_layoutSubtabs()
    local show = self.ActiveTab ~= nil and #self.ActiveTab.Subtabs > 1
    self.SubLayer.Visible = show
    self.SubDivider.Visible = show
    self.Content.Position = UDim2.fromOffset(12, show and 55 or 36)
    self.Content.Size = UDim2.new(1, -24, 1, show and -65 or -46)
end

function Window:_closePopup()
    if self.OpenPopup then self.OpenPopup.frame.Visible = false end
    self.OpenPopup = nil
    self.PopupDrag = nil
end

function Window:_positionPopup()
    local current = self.OpenPopup
    if not current then return end
    local anchor, popup = current.anchor, current.frame
    local scale = self.Scale.Scale
    local rootPos, rootSize = self.Root.AbsolutePosition, self.Root.AbsoluteSize
    local anchorPos, anchorSize = anchor.AbsolutePosition, anchor.AbsoluteSize
    local width = popup.Size.X.Offset
    local height = popup.Size.Y.Offset
    local maxX = math.max(0, rootSize.X / scale - width)
    local maxY = math.max(0, rootSize.Y / scale - height)
    local x = math.clamp((anchorPos.X - rootPos.X) / scale, 0, maxX)
    local y = (anchorPos.Y - rootPos.Y + anchorSize.Y) / scale + 2
    if y > maxY then y = (anchorPos.Y - rootPos.Y) / scale - height - 2 end
    y = math.clamp(y, 0, maxY)
    popup.Position = UDim2.fromOffset(x, y)
end

function Window:_attachPopup(anchor, popup)
    self:_connect(anchor:GetPropertyChangedSignal("AbsolutePosition"), function() if self.OpenPopup and self.OpenPopup.frame == popup then self:_positionPopup() end end)
    self:_connect(anchor:GetPropertyChangedSignal("AbsoluteSize"), function() if self.OpenPopup and self.OpenPopup.frame == popup then self:_positionPopup() end end)
end

function Window:_togglePopup(anchor, popup)
    if self.OpenPopup and self.OpenPopup.frame == popup then self:_closePopup(); return end
    self:_closePopup()
    self.OpenPopup = {anchor = anchor, frame = popup}
    popup.Visible = true
    self:_positionPopup()
end

function Window:Toggle(value)
    if value == nil then value = not self.Visible end
    self.Visible = value == true
    self.Root.Visible = self.Visible
    if not self.Visible then self:_closePopup() end
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:_closePopup()
    self.Drag, self.SliderDrag, self.PopupDrag, self.CapturingKey = nil, nil, nil, nil
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
    self:_closePopup()
    self.ActiveTab = tab
    self:_layoutSubtabs()
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

function Tab:Subtab(name)
    local window = self.Window
    local sub = setmetatable({Tab = self, Window = window, Name = name}, Subtab)
    local nav = button(window.SubBar, name)
    -- CS2 reference uses plain text subtabs; no icon column.
    nav.Size = UDim2.fromOffset(math.max(35, #name * 6 + 12), 19)
    nav.TextColor3 = C.muted
    sub.Button = nav
    local page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(65, 65, 68),
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
    end)
    window:_connect(nav.MouseLeave, function()
        local color = self.ActiveSubtab == sub and C.text or C.muted
        nav.TextColor3 = color
    end)
    if not self.ActiveSubtab then self:SelectSubtab(sub) end
    if window.ActiveTab == self then window:_layoutSubtabs() end
    nav.Visible = window.ActiveTab == self
    page.Visible = window.ActiveTab == self and self.ActiveSubtab == sub
    return sub
end

function Tab:SelectSubtab(sub)
    assert(sub.Tab == self, "Subtab belongs to another tab")
    self.Window:_closePopup()
    self.ActiveSubtab = sub
    for _, item in ipairs(self.Subtabs) do
        local active = item == sub
        item.Button.TextColor3 = active and C.text or C.muted
        item.Page.Visible = active and self.Window.ActiveTab == self
    end
end

function Subtab:Section(name, side, options)
    options = options or {}
    local parent = (side == "Right" or side == "right" or side == 2) and self.Right or self.Left
    local height = options.Height
    if height ~= nil then assert(type(height) == "number" and height >= 40, "Section Height must be at least 40") end
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 0),
        AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, parent)
    border(frame)
    local content
    if height then
        local heading = text(frame, name, 12, C.muted)
        heading.Position = UDim2.fromOffset(5, 3)
        heading.Size = UDim2.new(1, -10, 0, 16)
        content = create("ScrollingFrame", {
            Name = "SectionContent", Position = UDim2.fromOffset(5, 19),
            Size = UDim2.new(1, -10, 1, -23), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(69, 69, 72),
            ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(),
        }, frame)
        -- Leave space for the scroll bar, so right-aligned swatches and keybinds are not clipped.
        create("UIPadding", {PaddingRight = UDim.new(0, 6)}, content)
        list(content, 1)
        -- A real scroll control, only shown if there is content below the viewport.
        local down = button(frame, "")
        down.Name = "ScrollDown"
        down.Size = UDim2.fromOffset(14, 14)
        down.Position = UDim2.new(1, -15, 1, -14)
        local arrow = icon(down, "down", C.muted)
        arrow.Position = UDim2.fromOffset(2, 2)
        local function updateArrow()
            down.Visible = content.AbsoluteCanvasSize.Y > content.AbsoluteSize.Y + 1
                and content.CanvasPosition.Y < content.AbsoluteCanvasSize.Y - content.AbsoluteSize.Y - 1
        end
        self.Window:_connect(content:GetPropertyChangedSignal("AbsoluteCanvasSize"), updateArrow)
        self.Window:_connect(content:GetPropertyChangedSignal("AbsoluteSize"), updateArrow)
        self.Window:_connect(content:GetPropertyChangedSignal("CanvasPosition"), updateArrow)
        self.Window:_connect(down.MouseButton1Click, function()
            local maxY = math.max(0, content.AbsoluteCanvasSize.Y - content.AbsoluteSize.Y)
            content.CanvasPosition = Vector2.new(0, math.min(maxY, content.CanvasPosition.Y + 60))
        end)
        updateArrow()
    else
        content = frame
        create("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, frame)
        list(frame, 1)
        local heading = text(frame, name, 12, C.muted)
        heading.Size = UDim2.new(1, 0, 0, 16)
    end
    return setmetatable({Frame = content, Container = frame, Window = self.Window}, Section)
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
    local label = text(self.Frame, value, 13, C.muted)
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

-- Assigned below; both standalone pickers and toggle swatches share the same popup.
local createColorControl

function Section:Toggle(options)
    local value = option(options, "Default", false) == true
    local changed = register(self, options, value)
    local r = row(self)
    local b = button(r, "")
    b.Size = UDim2.fromScale(1, 1)
    local box = create("Frame", {Size = UDim2.fromOffset(7, 7), Position = UDim2.new(0, 5, 0.5, -3), BackgroundColor3 = C.field, BorderSizePixel = 0}, b)
    border(box)
    local label = text(b, options.Name or "Toggle", 13)
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
        local swatchPosition = UDim2.new(1, -20, 0.5, -4)
        local swatchSize = UDim2.fromOffset(16, 8)
        swatchChecker(r, swatchPosition, swatchSize)
        local swatch = button(r, "")
        swatch.Position = swatchPosition
        swatch.Size = swatchSize
        swatch.BackgroundTransparency = 0
        swatch.BackgroundColor3 = options.Color
        border(swatch)
        label.Size = UDim2.new(1, -48, 1, 0)
        local picker = createColorControl(self.Window, swatch, swatch, {
            Default = options.Color, Flag = options.ColorFlag,
            Alpha = options.Alpha, AlphaFlag = options.ColorAlphaFlag, Callback = options.ColorCallback,
        })
        function control:SetColor(color, silent) picker:Set(color, silent) end
        function control:GetColor() return picker:Get() end
        function control:SetAlpha(alpha, silent) picker:SetAlpha(alpha, silent) end
        function control:GetAlpha() return picker:GetAlpha() end
        self.Window:_connect(swatch.MouseButton1Click, function() picker:Open() end)
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
    local r = row(self, options.Compact and 18 or 35)
    local lineY = options.Compact and 1 or 18
    local label = text(r, options.Name or "Slider", 13)
    label.Visible = not options.Compact
    label.Size = UDim2.new(1, -65, 0, 18)
    local number = text(r, "", 12, C.muted)
    number.TextXAlignment = Enum.TextXAlignment.Right
    number.Position = UDim2.new(1, -65, 0, 0)
    number.Size = UDim2.fromOffset(65, 18)
    number.Visible = not options.Compact and not options.HideValue
    local minus = button(r, "-")
    minus.Position = UDim2.fromOffset(0, lineY)
    minus.Size = UDim2.fromOffset(14, 16)
    minus.TextColor3 = C.muted
    local plus = button(r, "+")
    plus.Position = UDim2.new(1, -14, 0, lineY)
    plus.Size = UDim2.fromOffset(14, 16)
    plus.TextColor3 = C.muted
    local track = create("Frame", {Position = UDim2.fromOffset(16, lineY + 1), Size = UDim2.new(1, -32, 0, 16), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true}, r)
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
    if options.FullWidth ~= true then
        create("UIPadding", {PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0.13, 0)}, container)
    end
    list(container, 2)
    local label = text(container, options.Name or "Dropdown", 13)
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Visible = options.Name ~= ""
    local main = button(container, "")
    main.Size = UDim2.new(1, 0, 0, 20)
    main.BackgroundTransparency = 0
    main.BackgroundColor3 = C.field
    border(main)
    local display = text(main, "", 13, C.muted)
    display.Position = UDim2.fromOffset(7, 0)
    display.Size = UDim2.new(1, -25, 1, 0)
    display.TextTruncate = Enum.TextTruncate.AtEnd
    local arrow = icon(main, "down", C.muted)
    arrow.Position = UDim2.new(1, -16, 0.5, -4)
    local items = create("ScrollingFrame", {
        Name = "DropdownPopup", Size = UDim2.fromOffset(150, math.min(math.max(#choices * 21, 21), 126)),
        BackgroundColor3 = C.field, BorderSizePixel = 0, Visible = false, ZIndex = 101,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(65, 65, 65),
        ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
    }, self.Window.PopupLayer)
    border(items)
    list(items, 1)
    self.Window:_attachPopup(main, items)
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
    self.Window:_connect(main.MouseButton1Click, function()
        items.Size = UDim2.fromOffset(math.max(120, main.AbsoluteSize.X / self.Window.Scale.Scale), items.Size.Y.Offset)
        self.Window:_togglePopup(main, items)
    end)
    for _, choice in ipairs(choices) do
        local item = button(items, "")
        item.Size = UDim2.new(1, -3, 0, 20)
        local itemLabel = text(item, tostring(choice), 13, C.muted)
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
                self.Window:_closePopup()
            end
        end)
    end
    if #choices == 0 then
        local empty = text(items, "  No options", 13, C.muted)
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
    local label = text(self.Frame, options.Name or "List", 13, C.muted)
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
        local itemLabel = text(item, tostring(choice), 13, C.muted)
        itemLabel.Position = UDim2.fromOffset(8, 0)
        itemLabel.Size = UDim2.new(1, -24, 1, 0)
        itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
        local mark = icon(item, "check", window.Accent)
        mark.Position = UDim2.new(1, -15, 0.5, -4)
        table.insert(rows, {choice = choice, label = itemLabel, mark = mark})
        window:_connect(item.MouseButton1Click, function() control:Set(choice) end)
    end
    if #choices == 0 then
        local empty = text(items, "  No options", 13, C.muted)
        empty.Size = UDim2.new(1, 0, 0, 20)
    end
    control:Set(options.Default, true)
    return control
end

function Section:Textbox(options)
    local r = row(self, 45)
    local label = text(r, options.Name or "Text", 13)
    label.Size = UDim2.new(1, 0, 0, 18)
    local box = create("TextBox", {
        Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = C.field, BorderSizePixel = 0, Font = Enum.Font.Arial, TextSize = 13,
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
    local label = text(r, options.Name or "Keybind", 13)
    label.Size = UDim2.new(1, -100, 1, 0)
    local keyButton = button(r, "")
    keyButton.Position = UDim2.new(1, -104, 0, 0)
    keyButton.Size = UDim2.fromOffset(98, 19)
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

-- HSV/opacity picker. Everything is drawn with native gradients and GUI objects.
-- Alpha is opacity: 0 = transparent, 1 = opaque.
createColorControl = function(window, anchor, swatch, options)
    local color = options.Default or Color3.fromRGB(255, 255, 255)
    assert(typeof(color) == "Color3", "ColorPicker expects a Color3")
    local alpha = math.clamp(tonumber(option(options, "Alpha", 1)) or 1, 0, 1)
    local hue, saturation, brightness = color:ToHSV()
    local popup, field, satCursor, hueCursor, alphaCursor, alphaFill, preview, alphaLabel
    local control = {}

    local function refresh()
        swatch.BackgroundColor3 = color
        swatch.BackgroundTransparency = 1 - alpha
        if options.Flag then window.Flags[options.Flag] = color end
        if options.AlphaFlag then window.Flags[options.AlphaFlag] = alpha end
        if popup then
            field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
            satCursor.Position = UDim2.fromScale(saturation, 1 - brightness)
            hueCursor.Position = UDim2.fromScale(hue, 0.5)
            alphaCursor.Position = UDim2.fromScale(alpha, 0.5)
            alphaFill.BackgroundColor3 = color
            preview.BackgroundColor3 = color
            preview.BackgroundTransparency = 1 - alpha
            alphaLabel.Text = "A  " .. tostring(math.floor(alpha * 100 + 0.5)) .. "%"
        end
    end
    local function emit(silent)
        refresh()
        if not silent then safeCall(options.Callback, color, alpha) end
    end
    function control:Set(newColor, silent)
        assert(typeof(newColor) == "Color3", "ColorPicker expects a Color3")
        color = newColor
        local h, s, v = color:ToHSV()
        -- Preserve the selected hue for white, grey and black.
        if s > 0 and v > 0 then hue = h end
        saturation, brightness = s, v
        emit(silent)
    end
    function control:Get() return color end
    function control:SetAlpha(newAlpha, silent)
        assert(type(newAlpha) == "number", "ColorPicker alpha expects a number")
        alpha = math.clamp(newAlpha, 0, 1)
        emit(silent)
    end
    function control:GetAlpha() return alpha end

    local function startDrag(object, update)
        window:_connect(object.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                window.PopupDrag = {input = input, update = update}
                update(input.Position)
            end
        end)
    end
    local function ratio(value, start, size)
        if size <= 0 then return 0 end
        return math.clamp((value - start) / size, 0, 1)
    end
    local function build()
        popup = create("Frame", {
            Name = "ColorPopup", Size = UDim2.fromOffset(208, 193),
            BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false, ZIndex = 101,
        }, window.PopupLayer)
        border(popup, Color3.fromRGB(42, 42, 42))
        field = create("Frame", {
            Name = "SaturationValue", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(192, 110),
            BackgroundColor3 = Color3.fromHSV(hue, 1, 1), BorderSizePixel = 0, Active = true, ZIndex = 102,
        }, popup)
        -- White -> chosen hue from left to right; transparent -> black top to bottom.
        local white = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 103}, field)
        create("UIGradient", {Transparency = NumberSequence.new(0, 1)}, white)
        local black = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, ZIndex = 104}, field)
        create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, black)
        satCursor = create("Frame", {Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 105}, field)
        border(satCursor, Color3.fromRGB(0, 0, 0))

        local hueBar = create("Frame", {Name = "Hue", Position = UDim2.fromOffset(8, 125), Size = UDim2.fromOffset(192, 12), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Active = true, ZIndex = 102}, popup)
        local hueKeys = {}
        for i = 0, 6 do hueKeys[#hueKeys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
        create("UIGradient", {Color = ColorSequence.new(hueKeys)}, hueBar)
        border(hueBar, C.border)
        hueCursor = create("Frame", {Size = UDim2.fromOffset(3, 14), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 104}, hueBar)
        border(hueCursor, Color3.fromRGB(0, 0, 0))

        local alphaBar = create("Frame", {Name = "Alpha", Position = UDim2.fromOffset(8, 145), Size = UDim2.fromOffset(192, 12), BackgroundColor3 = Color3.fromRGB(70, 70, 70), BorderSizePixel = 0, Active = true, ClipsDescendants = true, ZIndex = 102}, popup)
        for y = 0, 1 do
            for x = 0, 23 do
                if (x + y) % 2 == 0 then
                    create("Frame", {Position = UDim2.fromOffset(x * 8, y * 6), Size = UDim2.fromOffset(8, 6), BackgroundColor3 = Color3.fromRGB(150, 150, 150), BorderSizePixel = 0, ZIndex = 103}, alphaBar)
                end
            end
        end
        alphaFill = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 104}, alphaBar)
        create("UIGradient", {Transparency = NumberSequence.new(1, 0)}, alphaFill)
        border(alphaBar, C.border)
        alphaCursor = create("Frame", {Size = UDim2.fromOffset(3, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 105}, alphaBar)
        border(alphaCursor, Color3.fromRGB(0, 0, 0))
        alphaLabel = text(popup, "", 12, C.muted)
        alphaLabel.Position = UDim2.fromOffset(8, 163)
        alphaLabel.Size = UDim2.fromOffset(100, 20)
        alphaLabel.ZIndex = 102
        local previewBack = create("Frame", {Position = UDim2.fromOffset(166, 166), Size = UDim2.fromOffset(34, 14), BackgroundColor3 = Color3.fromRGB(85, 85, 85), BorderSizePixel = 0, ZIndex = 102}, popup)
        preview = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 103}, previewBack)
        border(previewBack, C.border)

        startDrag(field, function(pos)
            saturation = ratio(pos.X, field.AbsolutePosition.X, field.AbsoluteSize.X)
            brightness = 1 - ratio(pos.Y, field.AbsolutePosition.Y, field.AbsoluteSize.Y)
            color = Color3.fromHSV(hue, saturation, brightness)
            emit(false)
        end)
        startDrag(hueBar, function(pos)
            hue = ratio(pos.X, hueBar.AbsolutePosition.X, hueBar.AbsoluteSize.X)
            color = Color3.fromHSV(hue, saturation, brightness)
            emit(false)
        end)
        startDrag(alphaBar, function(pos)
            alpha = ratio(pos.X, alphaBar.AbsolutePosition.X, alphaBar.AbsoluteSize.X)
            emit(false)
        end)
        window:_attachPopup(anchor, popup)
        refresh()
    end
    function control:Open()
        if not popup then build() end
        window:_togglePopup(anchor, popup)
    end
    refresh()
    return control
end

function Section:ColorPicker(options)
    local r = row(self, 22)
    local top = button(r, options.Name or "Color")
    top.Size = UDim2.fromScale(1, 1)
    top.TextXAlignment = Enum.TextXAlignment.Left
    local swatchPosition, swatchSize = UDim2.new(1, -20, 0.5, -5), UDim2.fromOffset(20, 10)
    swatchChecker(top, swatchPosition, swatchSize)
    local swatch = create("Frame", {Size = swatchSize, Position = swatchPosition, BackgroundColor3 = options.Default or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0}, top)
    border(swatch)
    local control = createColorControl(self.Window, top, swatch, options)
    self.Window:_connect(top.MouseButton1Click, function() control:Open() end)
    return control
end

return Plague
