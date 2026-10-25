-- Kavo Redux :: modern interface library for Roblox
-- clean architecture, custom tweening, no dead weight

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.__index = Library

local Theme = {
    Accent       = Color3.fromRGB(120, 140, 255),
    AccentSoft   = Color3.fromRGB(90, 105, 200),
    Background   = Color3.fromRGB(18, 19, 24),
    Surface      = Color3.fromRGB(26, 27, 34),
    SurfaceAlt   = Color3.fromRGB(32, 34, 42),
    SurfaceHover = Color3.fromRGB(40, 43, 53),
    Outline      = Color3.fromRGB(46, 49, 60),
    Text         = Color3.fromRGB(240, 242, 248),
    TextMuted    = Color3.fromRGB(150, 155, 170),
    Danger       = Color3.fromRGB(235, 90, 90),
    Success      = Color3.fromRGB(110, 210, 140),
    Radius       = UDim.new(0, 8),
    RadiusSmall  = UDim.new(0, 6),
}
Library.Theme = Theme

local Ease = {
    OutQuad    = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    OutCubic   = TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
    OutQuint   = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    InOutQuad  = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
    Spring     = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Snap       = TweenInfo.new(0.10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
}
Library.Ease = Ease

local function Create(class, props, children)
    local obj = Instance.new(class)
    for k, v in next, props or {} do
        obj[k] = v
    end
    for _, child in next, children or {} do
        child.Parent = obj
    end
    return obj
end

local function Corner(radius)
    return Create("UICorner", { CornerRadius = radius or Theme.Radius })
end

local function Stroke(color, thickness, transparency)
    return Create("UIStroke", {
        Color = color or Theme.Outline,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Padding(all, extra)
    local p = Create("UIPadding")
    if type(all) == "number" then
        p.PaddingTop = UDim.new(0, all)
        p.PaddingBottom = UDim.new(0, all)
        p.PaddingLeft = UDim.new(0, all)
        p.PaddingRight = UDim.new(0, all)
    else
        for k, v in next, all do p[k] = v end
    end
    if extra then for k, v in next, extra do p[k] = v end end
    return p
end

local function Tween(obj, props, info)
    local t = TweenService:Create(obj, info or Ease.OutQuad, props)
    t:Play()
    return t
end

local function Ripple(button, color)
    local mouse = LocalPlayer:GetMouse()
    local ripple = Create("Frame", {
        BackgroundColor3 = color or Theme.Accent,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(mouse.X - button.AbsolutePosition.X, mouse.Y - button.AbsolutePosition.Y),
        ZIndex = 5,
    })
    ripple.Parent = button
    local corner = Corner(UDim.new(1, 0))
    corner.Parent = ripple
    local target = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2
    Tween(ripple, { Size = UDim2.fromOffset(target, target), BackgroundTransparency = 1 }, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    task.delay(0.45, function() if ripple then ripple:Destroy() end end)
end

local function Draggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function Round(obj, radius, color, thickness, transparency)
    Corner(radius).Parent = obj
    if color then Stroke(color, thickness, transparency).Parent = obj end
end

function Library.new(config)
    config = config or {}
    local self = setmetatable({}, Library)
    self.Name = config.Name or "Interface"
    self.Tabs = {}
    self.ActiveTab = nil
    self.Flags = {}
    self.Window = nil
    self._connections = {}
    self:_Build(config)
    return self
end

function Library:_Build(config)
    local ScreenGui = Create("ScreenGui", {
        Name = self.Name .. "_" .. tostring(math.random(1, 1e6)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
    })
    ScreenGui.Parent = CoreGui
    self.ScreenGui = ScreenGui

    local Main = Create("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(640, 400),
        Position = UDim2.new(0.5, -320, 0.5, -200),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    Main.Parent = ScreenGui
    Round(Main, UDim.new(0, 12), Theme.Outline, 1)
    self.Window = Main
    Draggable(Main)

    local Shadow = Create("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://1316045217",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, 40, 1, 40),
        ZIndex = -1,
    })
    Shadow.Parent = Main

    local Sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.fromOffset(150, 400),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
    })
    Sidebar.Parent = Main
    self.Sidebar = Sidebar

    local SidebarDivider = Create("Frame", {
        Name = "Divider",
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Outline,
        BorderSizePixel = 0,
    })
    SidebarDivider.Parent = Sidebar

    local Brand = Create("Frame", {
        Name = "Brand",
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
    })
    Brand.Parent = Sidebar

    local BrandDot = Create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(16, 24),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    BrandDot.Parent = Brand
    Corner(UDim.new(1, 0)).Parent = BrandDot

    local BrandLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(30, 16),
        Size = UDim2.new(1, -40, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = config.Name or "Interface",
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    BrandLabel.Parent = Brand

    local BrandSub = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(30, 30),
        Size = UDim2.new(1, -40, 0, 14),
        Font = Enum.Font.Gotham,
        Text = config.Subtitle or "redux build",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    BrandSub.Parent = Brand

    local TabHolder = Create("Frame", {
        Name = "TabHolder",
        Position = UDim2.fromOffset(8, 56),
        Size = UDim2.new(1, -16, 1, -64),
        BackgroundTransparency = 1,
    })
    TabHolder.Parent = Sidebar

    Create("UIListLayout", {
        Name = "Layout",
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }).Parent = TabHolder

    self.TabHolder = TabHolder

    local Content = Create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(150, 0),
        Size = UDim2.new(1, -150, 1, 0),
        BackgroundTransparency = 1,
    })
    Content.Parent = Main
    self.Content = Content

    local TopBar = Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
    })
    TopBar.Parent = Content
    self.TopBar = TopBar

    local TabBar = Create("Frame", {
        Name = "TabBar",
        Position = UDim2.fromOffset(12, 14),
        Size = UDim2.new(1, -90, 0, 24),
        BackgroundTransparency = 1,
    })
    TabBar.Parent = TopBar
    self.TabBar = TabBar

    local CloseBtn = Create("TextButton", {
        Name = "Close",
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.new(1, -36, 0, 14),
        BackgroundColor3 = Theme.SurfaceAlt,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    CloseBtn.Parent = TopBar
    Round(CloseBtn, Theme.RadiusSmall)
    local closeIcon = Create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.fromOffset(6, 6),
        Image = "rbxassetid://10747384394",
        ImageColor3 = Theme.TextMuted,
    })
    closeIcon.Parent = CloseBtn
    CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn, { BackgroundColor3 = Theme.Danger }, Ease.OutQuad) Tween(closeIcon, { ImageColor3 = Theme.Text }, Ease.OutQuad) end)
    CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn, { BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad) Tween(closeIcon, { ImageColor3 = Theme.TextMuted }, Ease.OutQuad) end)
    CloseBtn.MouseButton1Click:Connect(function() self:Toggle() end)

    local Minimize = Create("TextButton", {
        Name = "Minimize",
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.new(1, -66, 0, 14),
        BackgroundColor3 = Theme.SurfaceAlt,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    Minimize.Parent = TopBar
    Round(Minimize, Theme.RadiusSmall)
    local minIcon = Create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.fromOffset(6, 6),
        Image = "rbxassetid://10734896269",
        ImageColor3 = Theme.TextMuted,
    })
    minIcon.Parent = Minimize
    Minimize.MouseEnter:Connect(function() Tween(Minimize, { BackgroundColor3 = Theme.SurfaceHover }, Ease.OutQuad) Tween(minIcon, { ImageColor3 = Theme.Text }, Ease.OutQuad) end)
    Minimize.MouseLeave:Connect(function() Tween(Minimize, { BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad) Tween(minIcon, { ImageColor3 = Theme.TextMuted }, Ease.OutQuad) end)
    self.Minimized = false
    Minimize.MouseButton1Click:Connect(function()
        self.Minimized = not self.Minimized
        if self.Minimized then
            Tween(Main, { Size = UDim2.fromOffset(640, 52) }, Ease.OutCubic)
        else
            Tween(Main, { Size = UDim2.fromOffset(640, 400) }, Ease.OutCubic)
        end
    end)

    local PageHolder = Create("Frame", {
        Name = "PageHolder",
        Position = UDim2.fromOffset(0, 52),
        Size = UDim2.new(1, 0, 1, -52),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    })
    PageHolder.Parent = Content
    self.PageHolder = PageHolder

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            self:Toggle()
        end
    end))
end

function Library:Toggle()
    local w = self.Window
    if not w then return end
    self.Visible = not self.Visible
    if self.Visible then
        w.Visible = true
        w.Size = UDim2.fromOffset(640, 0)
        Tween(w, { Size = UDim2.fromOffset(640, 400) }, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
    else
        Tween(w, { Size = UDim2.fromOffset(640, 0) }, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.In))
        task.delay(0.24, function() w.Visible = false end)
    end
end

function Library:Destroy()
    for _, conn in next, self._connections do conn:Disconnect() end
    if self.ScreenGui then self.ScreenGui:Destroy() end
end

function Library:Notify(title, content, duration)
    local gui = self.ScreenGui
    local holder = gui:FindFirstChild("Notifications")
    if not holder then
        holder = Create("Frame", {
            Name = "Notifications",
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.fromOffset(300, 400),
            BackgroundTransparency = 1,
        })
        holder.Parent = gui
        Create("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
        }).Parent = holder
    end

    local card = Create("Frame", {
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(300, 60),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    card.Parent = holder
    Round(card, UDim.new(0, 10), Theme.Outline, 1)

    local accentBar = Create("Frame", {
        Size = UDim2.new(0, 3, 1, -16),
        Position = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    accentBar.Parent = card
    Corner(UDim.new(1, 0)).Parent = accentBar

    local titleLbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 10),
        Size = UDim2.new(1, -28, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = title or "Notification",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
    })
    titleLbl.Parent = card

    local contentLbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 30),
        Size = UDim2.new(1, -28, 0, 20),
        Font = Enum.Font.Gotham,
        Text = content or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextTransparency = 1,
    })
    contentLbl.Parent = card

    Tween(card, { BackgroundTransparency = 0 }, Ease.OutQuad)
    Tween(titleLbl, { TextTransparency = 0 }, Ease.OutQuad)
    Tween(contentLbl, { TextTransparency = 0 }, Ease.OutQuad)

    task.delay(duration or 4, function()
        Tween(card, { BackgroundTransparency = 1 }, Ease.OutQuad)
        Tween(titleLbl, { TextTransparency = 1 }, Ease.OutQuad)
        Tween(contentLbl, { TextTransparency = 1 }, Ease.OutQuad)
        task.delay(0.25, function() card:Destroy() end)
    end)
end

function Library:SetTheme(newTheme)
    for k, v in next, newTheme do
        if k == "Accent" or k == "AccentSoft" then Theme[k] = v end
    end
    local main = self.Window
    if main then
        Tween(main:FindFirstChildOfClass("UIStroke"), { Color = Theme.Outline }, Ease.OutQuad)
    end
end

function Library:Tab(name)
    local tabObj = {}
    tabObj.Name = name or "Tab"
    tabObj.Subtabs = {}
    tabObj.ActiveSub = nil
    tabObj.Sections = {}

    local btn = Create("TextButton", {
        Name = tabObj.Name,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
    })
    btn.Parent = self.TabHolder
    Round(btn, UDim.new(0, 7))

    local accent = Create("Frame", {
        Name = "Accent",
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    accent.Parent = btn
    Corner(UDim.new(1, 0)).Parent = accent

    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = tabObj.Name,
        TextColor3 = Theme.TextMuted,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    lbl.Parent = btn

    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tabObj then
            Tween(btn, { BackgroundTransparency = 0.85, BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad)
            Tween(lbl, { TextColor3 = Theme.Text }, Ease.OutQuad)
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.ActiveTab ~= tabObj then
            Tween(btn, { BackgroundTransparency = 1 }, Ease.OutQuad)
            Tween(lbl, { TextColor3 = Theme.TextMuted }, Ease.OutQuad)
        end
    end)

    local page = Create("Frame", {
        Name = tabObj.Name .. "_Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
    })
    page.Parent = self.PageHolder
    tabObj.Page = page

    btn.MouseButton1Click:Connect(function()
        self:SelectTab(tabObj)
    end)

    table.insert(self.Tabs, tabObj)
    if not self.ActiveTab then
        self:SelectTab(tabObj)
    end
    return self:_WrapTab(tabObj)
end

function Library:SelectTab(tabObj)
    for _, t in next, self.Tabs do
        if t == tabObj then
            t.Page.Visible = true
            Tween(t.Page, { BackgroundTransparency = 0 }, Ease.OutQuad)
            local btn = self.TabHolder:FindFirstChild(t.Name)
            if btn then
                Tween(btn, { BackgroundTransparency = 0.82, BackgroundColor3 = Theme.Accent }, Ease.OutQuad)
                local lbl = btn:FindFirstChildOfClass("TextLabel")
                if lbl then Tween(lbl, { TextColor3 = Theme.Text }, Ease.OutQuad) end
            end
        else
            t.Page.Visible = false
            local btn = self.TabHolder:FindFirstChild(t.Name)
            if btn then
                Tween(btn, { BackgroundTransparency = 1 }, Ease.OutQuad)
                local lbl = btn:FindFirstChildOfClass("TextLabel")
                if lbl then Tween(lbl, { TextColor3 = Theme.TextMuted }, Ease.OutQuad) end
            end
        end
    end
    self.ActiveTab = tabObj
    self:_RenderSubtabs(tabObj)
end

function Library:_RenderSubtabs(tabObj)
    local bar = self.TabBar
    for _, c in next, bar:GetChildren() do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    if #tabObj.Subtabs == 0 then return end

    if #tabObj.Subtabs <= 3 then
        local holder = Create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
        })
        holder.Parent = bar
        Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 0),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }).Parent = holder

        for i, sub in next, tabObj.Subtabs do
            local btn = Create("TextButton", {
                Name = sub.Name,
                Size = UDim2.fromOffset(90, 24),
                BackgroundColor3 = Theme.SurfaceAlt,
                BackgroundTransparency = 0,
                Text = sub.Name,
                AutoButtonColor = false,
                Font = Enum.Font.GothamMedium,
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                LayoutOrder = i,
                ClipsDescendants = true,
            })
            btn.Parent = holder
            Corner(i == 1 and UDim.new(0, 7) or UDim.new(0, 0)).Parent = btn
            if i == #tabObj.Subtabs then
                local r = Corner(UDim.new(0, 7))
                r.Parent = btn
            end
            local function setActive(on)
                if on then
                    Tween(btn, { BackgroundColor3 = Theme.Accent }, Ease.OutQuad)
                    Tween(btn, { TextColor3 = Theme.Text }, Ease.OutQuad)
                else
                    Tween(btn, { BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad)
                    Tween(btn, { TextColor3 = Theme.TextMuted }, Ease.OutQuad)
                end
            end
            sub._setActive = setActive
            btn.MouseEnter:Connect(function()
                if tabObj.ActiveSub ~= sub then
                    Tween(btn, { BackgroundColor3 = Theme.SurfaceHover }, Ease.OutQuad)
                end
            end)
            btn.MouseLeave:Connect(function()
                if tabObj.ActiveSub ~= sub then
                    Tween(btn, { BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad)
                end
            end)
            btn.MouseButton1Click:Connect(function()
                self:_SelectSub(tabObj, sub)
            end)
            sub._button = btn
        end
    else
        local combo = Create("TextButton", {
            Size = UDim2.fromOffset(160, 24),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        })
        combo.Parent = bar
        Round(combo, Theme.RadiusSmall)

        local comboLabel = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -30, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = tabObj.ActiveSub and tabObj.ActiveSub.Name or (tabObj.Subtabs[1] and tabObj.Subtabs[1].Name or "Select"),
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        comboLabel.Parent = combo

        local chevron = Create("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -20, 0, 7),
            Size = UDim2.fromOffset(10, 10),
            Image = "rbxassetid://10709790948",
            ImageColor3 = Theme.TextMuted,
        })
        chevron.Parent = combo
        tabObj._comboLabel = comboLabel

        local dropdown = Create("Frame", {
            Size = UDim2.fromOffset(160, 0),
            Position = UDim2.new(0, 0, 1, 4),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 20,
        })
        dropdown.Parent = combo
        Round(dropdown, Theme.RadiusSmall, Theme.Outline, 1)

        Create("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }).Parent = dropdown
        Create("UIPadding", {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
        }).Parent = dropdown

        local opened = false
        combo.MouseButton1Click:Connect(function()
            opened = not opened
            if opened then
                local target = #tabObj.Subtabs * 26 + 8
                dropdown.Visible = true
                dropdown.Size = UDim2.fromOffset(160, 0)
                Tween(dropdown, { Size = UDim2.fromOffset(160, target) }, Ease.OutCubic)
            else
                Tween(dropdown, { Size = UDim2.fromOffset(160, 0) }, Ease.OutCubic)
                task.delay(0.25, function() dropdown.Visible = false end)
            end
        end)

        for i, sub in next, tabObj.Subtabs do
            local opt = Create("TextButton", {
                Size = UDim2.new(1, -8, 0, 24),
                Position = UDim2.fromOffset(4, 0),
                BackgroundColor3 = Theme.SurfaceAlt,
                BackgroundTransparency = 1,
                Text = sub.Name,
                Font = Enum.Font.Gotham,
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 21,
            })
            opt.Parent = dropdown
            Round(opt, UDim.new(0, 4))
            opt.MouseEnter:Connect(function()
                Tween(opt, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, Ease.OutQuad)
            end)
            opt.MouseLeave:Connect(function()
                if tabObj.ActiveSub ~= sub then
                    Tween(opt, { BackgroundTransparency = 1, TextColor3 = Theme.TextMuted }, Ease.OutQuad)
                end
            end)
            opt.MouseButton1Click:Connect(function()
                self:_SelectSub(tabObj, sub)
                opened = false
                Tween(dropdown, { Size = UDim2.fromOffset(160, 0) }, Ease.OutCubic)
                task.delay(0.25, function() dropdown.Visible = false end)
            end)
        end
    end

    if tabObj.ActiveSub then
        self:_SelectSub(tabObj, tabObj.ActiveSub)
    elseif tabObj.Subtabs[1] then
        self:_SelectSub(tabObj, tabObj.Subtabs[1])
    end
end

function Library:_SelectSub(tabObj, sub)
    for _, s in next, tabObj.Subtabs do
        if s.Page then s.Page.Visible = (s == sub) end
        if s._setActive then s._setActive(s == sub) end
        if s._button then
            Tween(s._button, { BackgroundColor3 = (s == sub) and Theme.Accent or Theme.SurfaceAlt }, Ease.OutQuad)
            Tween(s._button, { TextColor3 = (s == sub) and Theme.Text or Theme.TextMuted }, Ease.OutQuad)
        end
    end
    if tabObj._comboLabel then tabObj._comboLabel.Text = sub.Name end
    tabObj.ActiveSub = sub
end

function Library:_WrapTab(tabObj)
    local wrapper = {}
    wrapper.Subtab = function(_, subName)
        local sub = { Name = subName or "Subtab", Sections = {} }
        local page = Create("ScrollingFrame", {
            Name = (subName or "Subtab") .. "_Sub",
            Size = UDim2.new(1, 0, 1, -52),
            Position = UDim2.fromOffset(0, 52),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            ClipsDescendants = true,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingEnabled = true,
        })
        page.Parent = tabObj.Page
        Create("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }).Parent = page
        Create("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
        }).Parent = page
        sub.Page = page
        table.insert(tabObj.Subtabs, sub)
        return self:_WrapSub(sub, page)
    end
    return wrapper
end

function Library:_WrapSub(sub, page)
    local self2 = self
    local wrapper = {}
    wrapper.Section = function(_, sectionName)
        local section = { Name = sectionName or "Section", Elements = {} }
        local frame = Create("Frame", {
            Name = sectionName or "Section",
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = true,
        })
        frame.Parent = page
        Round(frame, UDim.new(0, 9), Theme.Outline, 1)

        local header = Create("Frame", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
        })
        header.Parent = frame

        local title = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 1, 0),
            Font = Enum.Font.GothamBold,
            Text = sectionName or "Section",
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        title.Parent = header

        local divider = Create("Frame", {
            Size = UDim2.new(1, -16, 0, 1),
            Position = UDim2.fromOffset(8, 30),
            BackgroundColor3 = Theme.Outline,
            BorderSizePixel = 0,
            BackgroundTransparency = 0.4,
        })
        divider.Parent = frame

        local inner = Create("Frame", {
            Name = "Inner",
            Position = UDim2.fromOffset(0, 35),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        inner.Parent = frame
        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
        }).Parent = inner

        local columns = Create("Frame", {
            Name = "Columns",
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        columns.Parent = inner

        local grid = Create("UIGridLayout", {
            CellSize = UDim2.new(0.5, -4, 0, 30),
            CellPadding = UDim2.new(0, 8, 0, 6),
            FillDirectionMaxCells = 2,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        grid.Parent = columns

        section._grid = grid
        section._columns = columns
        section._inner = inner
        section._frame = frame

        table.insert(sub.Sections, section)
        return self:_WrapSection(section, sub, page)
    end
    return wrapper
end

function Library:_WrapSection(section, sub, page)
    local self2 = self
    local wrapper = {}

    local function addElement(element)
        element.Parent = section._columns
        return element
    end

    wrapper.Label = function(_, text, layoutOrder)
        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Font = Enum.Font.Gotham,
            Text = text or "",
            TextColor3 = Theme.TextMuted,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = layoutOrder or 0,
        })
        lbl.Parent = section._columns
        return lbl
    end

    wrapper.Button = function(_, text, callback)
        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = #section._columns:GetChildren(),
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.fromOffset(6, 0),
            Font = Enum.Font.GothamMedium,
            Text = text or "Button",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        lbl.Parent = btn

        btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceHover }, Ease.OutQuad) end)
        btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad) end)
        btn.MouseButton1Click:Connect(function()
            Ripple(btn, Theme.Accent)
            if callback then callback() end
        end)
        return btn
    end

    wrapper.Toggle = function(_, text, default, callback)
        local state = default or false
        self.Flags[text] = state

        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = #section._columns:GetChildren(),
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -50, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = text or "Toggle",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        lbl.Parent = btn

        local track = Create("Frame", {
            Size = UDim2.fromOffset(28, 16),
            Position = UDim2.new(1, -38, 0.5, -8),
            BackgroundColor3 = Theme.Outline,
            BorderSizePixel = 0,
        })
        track.Parent = btn
        Corner(UDim.new(1, 0)).Parent = track

        local knob = Create("Frame", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromOffset(2, 2),
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
        })
        knob.Parent = track
        Corner(UDim.new(1, 0)).Parent = knob

        local dots = Create("TextButton", {
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.new(1, -64, 0.5, -10),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 3,
        })
        dots.Parent = btn
        for i = 1, 3 do
            local dot = Create("Frame", {
                Size = UDim2.fromOffset(2, 2),
                Position = UDim2.fromOffset(7 + (i - 1) * 3, 9),
                BackgroundColor3 = Theme.TextMuted,
                BorderSizePixel = 0,
            })
            dot.Parent = dots
            Corner(UDim.new(1, 0)).Parent = dot
        end

        local function apply(v)
            state = v
            self.Flags[text] = v
            Tween(knob, { Position = UDim2.fromOffset(v and 14 or 2, 2) }, Ease.OutCubic)
            Tween(track, { BackgroundColor3 = v and Theme.Accent or Theme.Outline }, Ease.OutQuad)
        end
        apply(state)

        btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceHover }, Ease.OutQuad) end)
        btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad) end)
        btn.MouseButton1Click:Connect(function()
            apply(not state)
            if callback then callback(state) end
        end)

        dots.MouseButton1Click:Connect(function()
            if self.Popup then self.Popup:Destroy() end
            local popup = Create("Frame", {
                Name = "Popup",
                Size = UDim2.fromOffset(200, 140),
                Position = UDim2.new(0.5, -100, 0.5, -70),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                ZIndex = 100,
            })
            popup.Parent = self.ScreenGui
            Round(popup, UDim.new(0, 10), Theme.Outline, 1)
            self.Popup = popup

            local header = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
            })
            header.Parent = popup

            local headerLbl = Create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(12, 0),
                Size = UDim2.new(1, -40, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = text or "Options",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            headerLbl.Parent = header

            local close = Create("TextButton", {
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(1, -26, 0, 5),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
            })
            close.Parent = header
            local closeIcon = Create("ImageLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.fromOffset(5, 5),
                Image = "rbxassetid://10747384394",
                ImageColor3 = Theme.TextMuted,
            })
            closeIcon.Parent = close
            close.MouseButton1Click:Connect(function() popup:Destroy() self.Popup = nil end)

            local content = Create("Frame", {
                Position = UDim2.fromOffset(0, 30),
                Size = UDim2.new(1, 0, 1, -30),
                BackgroundTransparency = 1,
            })
            content.Parent = popup
            Create("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                PaddingBottom = UDim.new(0, 8),
            }).Parent = content

            local info = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 70),
                Font = Enum.Font.Gotham,
                Text = "Popup content for " .. (text or "") .. ". Attach additional controls here as needed.",
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
            })
            info.Parent = content

            Tween(popup, { BackgroundTransparency = 0 }, Ease.OutQuad)
        end)

        return { Set = function(_, v) apply(v) end }
    end

    wrapper.Slider = function(_, text, min, max, default, callback)
        min = min or 0 max = max or 100 default = default or min
        self.Flags[text] = default

        local frame = Create("Frame", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            LayoutOrder = #section._columns:GetChildren(),
        })
        frame.Parent = section._columns
        Round(frame, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -60, 0, 16),
            Font = Enum.Font.GothamMedium,
            Text = text or "Slider",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        lbl.Parent = frame

        local valueLbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -50, 0, 0),
            Size = UDim2.fromOffset(40, 16),
            Font = Enum.Font.GothamBold,
            Text = tostring(default),
            TextColor3 = Theme.Accent,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        valueLbl.Parent = frame

        local bar = Create("Frame", {
            Size = UDim2.new(1, -20, 0, 4),
            Position = UDim2.new(0, 10, 1, -10),
            BackgroundColor3 = Theme.Outline,
            BorderSizePixel = 0,
        })
        bar.Parent = frame
        Corner(UDim.new(1, 0)).Parent = bar

        local fill = Create("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
        })
        fill.Parent = bar
        Corner(UDim.new(1, 0)).Parent = fill

        local dragging = false
        local function update(input)
            local pct = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * pct + 0.5)
            valueLbl.Text = tostring(val)
            fill.Size = UDim2.fromScale(pct, 1)
            self.Flags[text] = val
            if callback then callback(val) end
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        local pct = (default - min) / (max - min)
        fill.Size = UDim2.fromScale(pct, 1)

        return { Set = function(_, v) self.Flags[text] = v valueLbl.Text = tostring(v) fill.Size = UDim2.fromScale((v - min) / (max - min), 1) end }
    end

    wrapper.Textbox = function(_, text, placeholder, callback)
        local frame = Create("Frame", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            LayoutOrder = #section._columns:GetChildren(),
        })
        frame.Parent = section._columns
        Round(frame, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(0.4, -10, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = text or "Textbox",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        lbl.Parent = frame

        local box = Create("TextBox", {
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Position = UDim2.new(0.4, 4, 0.5, -9),
            Size = UDim2.new(0.6, -14, 0, 18),
            Font = Enum.Font.Gotham,
            PlaceholderText = placeholder or "Enter...",
            PlaceholderColor3 = Theme.TextMuted,
            Text = "",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
        })
        box.Parent = frame
        Round(box, UDim.new(0, 4))
        Create("UIPadding", { PaddingLeft = UDim.new(0, 6) }).Parent = box

        box.FocusLost:Connect(function(enterPressed)
            if enterPressed and callback then callback(box.Text) end
        end)
        return box
    end

    wrapper.Dropdown = function(_, text, options, default, callback)
        options = options or {}
        self.Flags[text] = default or options[1] or ""

        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = #section._columns:GetChildren(),
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(0.5, -10, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = text or "Dropdown",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        lbl.Parent = btn

        local valueLbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0.5, -20, 1, 0),
            Font = Enum.Font.Gotham,
            Text = default or options[1] or "Select",
            TextColor3 = Theme.Accent,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        valueLbl.Parent = btn

        local arrow = Create("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -14, 0.5, -3),
            Size = UDim2.fromOffset(6, 6),
            Image = "rbxassetid://10709790948",
            ImageColor3 = Theme.TextMuted,
        })
        arrow.Parent = btn

        local drop = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0, 0, 1, 2),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 10,
        })
        drop.Parent = btn
        Round(drop, Theme.RadiusSmall, Theme.Outline, 1)

        local list = Create("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        list.Parent = drop
        Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }).Parent = drop

        local opened = false
        btn.MouseButton1Click:Connect(function()
            opened = not opened
            if opened then
                drop.Visible = true
                drop.Size = UDim2.new(1, 0, 0, 0)
                Tween(drop, { Size = UDim2.new(1, 0, 0, #options * 24 + 8) }, Ease.OutCubic)
            else
                Tween(drop, { Size = UDim2.new(1, 0, 0, 0) }, Ease.OutCubic)
                task.delay(0.25, function() drop.Visible = false end)
            end
        end)

        for i, opt in next, options do
            local optBtn = Create("TextButton", {
                BackgroundColor3 = Theme.SurfaceAlt,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                Text = opt,
                Font = Enum.Font.Gotham,
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 11,
            })
            optBtn.Parent = drop
            Round(optBtn, UDim.new(0, 4))
            optBtn.MouseEnter:Connect(function() Tween(optBtn, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, Ease.OutQuad) end)
            optBtn.MouseLeave:Connect(function() Tween(optBtn, { BackgroundTransparency = 1, TextColor3 = Theme.TextMuted }, Ease.OutQuad) end)
            optBtn.MouseButton1Click:Connect(function()
                valueLbl.Text = opt
                self.Flags[text] = opt
                if callback then callback(opt) end
                opened = false
                Tween(drop, { Size = UDim2.new(1, 0, 0, 0) }, Ease.OutCubic)
                task.delay(0.25, function() drop.Visible = false end)
            end)
        end

        return { Set = function(_, v) valueLbl.Text = v self.Flags[text] = v end }
    end

    wrapper.Keybind = function(_, text, defaultKey, callback)
        local key = defaultKey or Enum.KeyCode.Unknown
        self.Flags[text] = key

        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = #section._columns:GetChildren(),
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(0.6, -10, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = text or "Keybind",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        lbl.Parent = btn

        local keyLbl = Create("TextLabel", {
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Position = UDim2.new(0.6, 0, 0.5, -9),
            Size = UDim2.new(0.4, -10, 0, 18),
            Font = Enum.Font.GothamBold,
            Text = key.Name,
            TextColor3 = Theme.Accent,
            TextSize = 11,
        })
        keyLbl.Parent = btn
        Round(keyLbl, UDim.new(0, 4))

        local listening = false
        btn.MouseButton1Click:Connect(function()
            listening = true
            keyLbl.Text = "..."
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    key = input.KeyCode
                    self.Flags[text] = key
                    keyLbl.Text = key.Name
                    listening = false
                    conn:Disconnect()
                end
            end)
        end)

        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == key and not listening then
                if callback then callback() end
            end
        end)

        return { Set = function(_, v) key = v keyLbl.Text = v.Name self.Flags[text] = v end }
    end

    wrapper.ColorPicker = function(_, text, defaultColor, callback)
        local color = defaultColor or Color3.fromRGB(255, 255, 255)
        self.Flags[text] = color

        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = #section._columns:GetChildren(),
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -50, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = text or "Color",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        lbl.Parent = btn

        local swatch = Create("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.new(1, -28, 0.5, -9),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
        })
        swatch.Parent = btn
        Round(swatch, UDim.new(0, 4), Theme.Outline, 1)

        btn.MouseButton1Click:Connect(function()
            local gui = self.ScreenGui
            local popup = Create("Frame", {
                Size = UDim2.fromOffset(180, 140),
                Position = UDim2.new(0.5, -90, 0.5, -70),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                ZIndex = 100,
            })
            popup.Parent = gui
            Round(popup, UDim.new(0, 10), Theme.Outline, 1)

            local field = Create("ImageLabel", {
                Size = UDim2.new(1, -20, 1, -40),
                Position = UDim2.fromOffset(10, 10),
                BackgroundTransparency = 1,
                Image = "rbxassetid://6523286724",
                ZIndex = 101,
            })
            field.Parent = popup

            local cursor = Create("Frame", {
                Size = UDim2.fromOffset(8, 8),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                ZIndex = 102,
            })
            cursor.Parent = popup
            Round(cursor, UDim.new(1, 0), Theme.Text, 1)

            local dragging = false
            field.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local x = math.clamp((input.Position.X - field.AbsolutePosition.X) / field.AbsoluteSize.X, 0, 1)
                    local y = math.clamp((input.Position.Y - field.AbsolutePosition.Y) / field.AbsoluteSize.Y, 0, 1)
                    color = Color3.fromHSV(1 - x, 1 - y, 1)
                    swatch.BackgroundColor3 = color
                    self.Flags[text] = color
                    cursor.Position = UDim2.fromScale(x, y)
                    if callback then callback(color) end
                end
            end)

            local close = Create("TextButton", {
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(1, -26, 0, 5),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 103,
            })
            close.Parent = popup
            close.MouseButton1Click:Connect(function() popup:Destroy() end)
        end)
    end

    return wrapper
end

return Library
