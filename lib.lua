-- Redux :: modern interface library for Roblox

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.__index = Library

local Fonts = {
    Display = Enum.Font.Montserrat,
    Body    = Enum.Font.Gotham,
    Medium  = Enum.Font.GothamMedium,
    Bold    = Enum.Font.GothamBold,
}

local Theme = {
    Accent       = Color3.fromRGB(118, 138, 250),
    AccentSoft   = Color3.fromRGB(88, 104, 200),
    Background   = Color3.fromRGB(16, 17, 22),
    Sidebar      = Color3.fromRGB(21, 22, 28),
    Surface      = Color3.fromRGB(26, 27, 34),
    SurfaceAlt   = Color3.fromRGB(33, 35, 43),
    SurfaceHover = Color3.fromRGB(42, 45, 55),
    Outline      = Color3.fromRGB(46, 49, 62),
    Text         = Color3.fromRGB(242, 244, 250),
    TextMuted    = Color3.fromRGB(148, 153, 168),
    Danger       = Color3.fromRGB(233, 92, 92),
    Radius       = UDim.new(0, 10),
    RadiusSmall  = UDim.new(0, 6),
    Transp       = 0
}
Library.Theme = Theme
Library.Fonts = Fonts

local Ease = {
    OutQuad   = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    OutCubic  = TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
    OutQuint  = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    InOutQuad = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
    Spring    = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Snap      = TweenInfo.new(0.10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
}
Library.Ease = Ease

local function Create(class, props, children)
    local obj = Instance.new(class)
    for k, v in next, props or {} do obj[k] = v end
    for _, child in next, children or {} do child.Parent = obj end
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

local function Tween(obj, props, info)
    local t = TweenService:Create(obj, info or Ease.OutQuad, props)
    t:Play()
    return t
end

local function Ripple(parent, color)
    local mouse = LocalPlayer:GetMouse()
    local r = Create("Frame", {
        BackgroundColor3 = color or Theme.Accent,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(mouse.X - parent.AbsolutePosition.X, mouse.Y - parent.AbsolutePosition.Y),
        ZIndex = 5,
    })
    r.Parent = parent
    Corner(UDim.new(1, 0)).Parent = r
    local target = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2
    Tween(r, { Size = UDim2.fromOffset(target, target), BackgroundTransparency = 1 }, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    task.delay(0.5, function() if r then r:Destroy() end end)
end

local function Draggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    conn:Disconnect()
                end
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
    self.Subtitle = config.Subtitle or "redux"
    self.Tabs = {}
    self.Flags = {}
    self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift
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

    local Root = Create("Frame", {
        Name = "Root",
        Size = UDim2.fromOffset(660, 420),
        Position = UDim2.new(0.5, -330, 0.5, -210),
        BackgroundTransparency = 1,
    })
    Root.Parent = ScreenGui
    self.Root = Root

    local Main = Create("Frame", {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = Theme.Transp,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 1,
    })
    Main.Parent = Root
    Corner(UDim.new(0, 14)).Parent = Main
    Stroke(Theme.Outline, 1, 0.5).Parent = Main
    self.Window = Main

    local Body = Create("Frame", {
        Name = "Body",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 2,
    })
    Body.Parent = Main
    Corner(UDim.new(0, 14)).Parent = Body

    local Sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.fromOffset(160, 420),
        BackgroundColor3 = Theme.Sidebar,
        BackgroundTransparency = Theme.Transp,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    Sidebar.Parent = Body
    Corner(UDim.new(0, 14)).Parent = Sidebar

    local SideDivider = Create("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Outline,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    SideDivider.Parent = Sidebar

    local Brand = Create("Frame", {
        Name = "Brand",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
    })
    Brand.Parent = Sidebar

    local BrandLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 16),
        Size = UDim2.new(1, -28, 0, 22),
        Font = Fonts.Display,
        Text = config.Name or "Interface",
        TextColor3 = Theme.Text,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    BrandLabel.Parent = Brand

    local BrandSub = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 34),
        Size = UDim2.new(1, -28, 0, 14),
        Font = Fonts.Body,
        Text = config.Subtitle or "redux",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    BrandSub.Parent = Brand

    local TabHolder = Create("Frame", {
        Name = "TabHolder",
        Position = UDim2.fromOffset(10, 60),
        Size = UDim2.new(1, -20, 1, -70),
        BackgroundTransparency = 1,
    })
    TabHolder.Parent = Sidebar
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }).Parent = TabHolder
    self.TabHolder = TabHolder

    local Content = Create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(160, 0),
        Size = UDim2.new(1, -160, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 2,
    })
    Content.Parent = Body
    self.Content = Content

    local TopBar = Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    TopBar.Parent = Content
    self.TopBar = TopBar
    Draggable(Root, TopBar)

    local TabBar = Create("Frame", {
        Name = "TabBar",
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.new(1, -120, 0, 24),
        BackgroundTransparency = 1,
    })
    TabBar.Parent = TopBar
    self.TabBar = TabBar

    local PageHolder = Create("Frame", {
        Name = "PageHolder",
        Position = UDim2.fromOffset(0, 52),
        Size = UDim2.new(1, 0, 1, -52),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 1,
    })
    PageHolder.Parent = Content
    self.PageHolder = PageHolder

    local function MakeWindowButton(icon, offsetX, hoverColor)
        local btn = Create("TextButton", {
            Size = UDim2.fromOffset(24, 24),
            Position = UDim2.new(1, offsetX, 0, 14),
            BackgroundColor3 = Theme.SurfaceAlt,
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 11,
        })
        btn.Parent = TopBar
        Corner(UDim.new(0, 6)).Parent = btn
        local iconLbl = Create("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(10, 10),
            Position = UDim2.fromOffset(7, 7),
            Image = icon,
            ImageColor3 = Theme.TextMuted,
            ZIndex = 12,
        })
        iconLbl.Parent = btn
        btn.MouseEnter:Connect(function()
            Tween(btn, { BackgroundColor3 = hoverColor or Theme.SurfaceHover, BackgroundTransparency = 0 }, Ease.OutQuad)
            Tween(iconLbl, { ImageColor3 = Theme.Text }, Ease.OutQuad)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, { BackgroundColor3 = Theme.SurfaceAlt, BackgroundTransparency = Theme.Transp }, Ease.OutQuad)
            Tween(iconLbl, { ImageColor3 = Theme.TextMuted }, Ease.OutQuad)
        end)
        return btn, iconLbl
    end

    local Minimize, minIcon = MakeWindowButton("rbxassetid://6031090990", -66)
    local Close, closeIcon = MakeWindowButton("rbxassetid://6031090995", -36, Theme.Danger)

    Close.MouseButton1Click:Connect(function() self:Toggle() end)

    self.Minimized = false
    local FullSize = UDim2.fromOffset(660, 420)
    Minimize.MouseButton1Click:Connect(function()
        self.Minimized = not self.Minimized
        if self.Minimized then
            Tween(Root, { Size = UDim2.fromOffset(260, 52) }, Ease.OutCubic)
            Sidebar.Visible = false
            Content.Position = UDim2.fromOffset(0, 0)
            Content.Size = UDim2.new(1, 0, 1, 0)
            BrandLabel.Parent = TopBar
            BrandLabel.Position = UDim2.fromOffset(18, 16)
            BrandLabel.Size = UDim2.new(0, 100, 0, 22)
            TabBar.Position = UDim2.new(0, 120, 0, 14)
            TabBar.Size = UDim2.new(1, -200, 0, 24)
            PageHolder.Visible = false
        else
            Tween(Root, { Size = FullSize }, Ease.OutCubic)
            BrandLabel.Parent = Brand
            BrandLabel.Position = UDim2.fromOffset(18, 16)
            BrandLabel.Size = UDim2.new(1, -28, 0, 22)
            Sidebar.Visible = true
            Content.Position = UDim2.fromOffset(160, 0)
            Content.Size = UDim2.new(1, -160, 1, 0)
            TabBar.Position = UDim2.fromOffset(14, 14)
            TabBar.Size = UDim2.new(1, -120, 0, 24)
            PageHolder.Visible = true
        end
    end)

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == self.ToggleKey then self:Toggle() end
    end))

    self.Visible = true
end

function Library:Toggle()
    local root = self.Root
    if not root then return end
    self.Visible = not self.Visible
    if self.Visible then
        root.Visible = true
        if not self.Minimized then
            root.Size = UDim2.fromOffset(660, 0)
            Tween(root, { Size = UDim2.fromOffset(660, 420) }, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
        else
            root.Size = UDim2.fromOffset(260, 0)
            Tween(root, { Size = UDim2.fromOffset(260, 52) }, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
        end
    else
        local targetW = self.Minimized and 260 or 660
        Tween(root, { Size = UDim2.fromOffset(targetW, 0) }, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.In))
        task.delay(0.24, function() root.Visible = false end)
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
            ZIndex = 500,
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
        Size = UDim2.fromOffset(300, 64),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 501,
    })
    card.Parent = holder
    Corner(UDim.new(0, 10)).Parent = card
    local stroke = Stroke(Theme.Outline, 1)
    stroke.Transparency = 1
    stroke.Parent = card

    local accentBar = Create("Frame", {
        Size = UDim2.new(0, 3, 1, -20),
        Position = UDim2.fromOffset(8, 10),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ZIndex = 502,
    })
    accentBar.Parent = card
    Corner(UDim.new(1, 0)).Parent = accentBar

    local titleLbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 10),
        Size = UDim2.new(1, -28, 0, 18),
        Font = Fonts.Bold,
        Text = title or "Notification",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 502,
    })
    titleLbl.Parent = card

    local contentLbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 30),
        Size = UDim2.new(1, -28, 0, 24),
        Font = Fonts.Body,
        Text = content or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextTransparency = 1,
        ZIndex = 502,
    })
    contentLbl.Parent = card

    Tween(card, { BackgroundTransparency = Theme.Transp }, Ease.OutQuad)
    Tween(stroke, { Transparency = 0 }, Ease.OutQuad)
    Tween(accentBar, { BackgroundTransparency = 0 }, Ease.OutQuad)
    Tween(titleLbl, { TextTransparency = 0 }, Ease.OutQuad)
    Tween(contentLbl, { TextTransparency = 0 }, Ease.OutQuad)

    task.delay(duration or 4, function()
        Tween(card, { BackgroundTransparency = 1 }, Ease.OutQuad)
        Tween(stroke, { Transparency = 1 }, Ease.OutQuad)
        Tween(accentBar, { BackgroundTransparency = 1 }, Ease.OutQuad)
        Tween(titleLbl, { TextTransparency = 1 }, Ease.OutQuad)
        Tween(contentLbl, { TextTransparency = 1 }, Ease.OutQuad)
        task.delay(0.3, function() card:Destroy() end)
    end)
end

function Library:Tab(name)
    local tabObj = { Name = name or "Tab", Subtabs = {}, Sections = {}, ActiveSub = nil }

    local btn = Create("TextButton", {
        Name = tabObj.Name,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.85,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
    })
    btn.Parent = self.TabHolder
    Corner(UDim.new(0, 7)).Parent = btn

    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Font = Fonts.Medium,
        Text = tabObj.Name,
        TextColor3 = Theme.TextMuted,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    lbl.Parent = btn

    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tabObj then
            Tween(btn, { BackgroundTransparency = 0.9, BackgroundColor3 = Theme.SurfaceAlt }, Ease.OutQuad)
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
    tabObj._button = btn
    tabObj._label = lbl

    btn.MouseButton1Click:Connect(function() self:SelectTab(tabObj) end)

    table.insert(self.Tabs, tabObj)
    if not self.ActiveTab then self:SelectTab(tabObj) end
    return self:_WrapTab(tabObj)
end

function Library:SelectTab(tabObj)
    for _, t in next, self.Tabs do
        if t == tabObj then
            t.Page.Visible = true
            Tween(t.Page, { BackgroundTransparency = 0 }, Ease.OutQuad)
            Tween(t._button, { BackgroundTransparency = 0.78, BackgroundColor3 = Theme.Accent }, Ease.OutQuad)
            Tween(t._label, { TextColor3 = Theme.Text }, Ease.OutQuad)
        else
            t.Page.Visible = false
            Tween(t._button, { BackgroundTransparency = 1 }, Ease.OutQuad)
            Tween(t._label, { TextColor3 = Theme.TextMuted }, Ease.OutQuad)
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
            BorderSizePixel = 0,
        })
        holder.Parent = bar

        local layout = Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        layout.Parent = holder

        local activeBg = Create("Frame", {
            Name = "ActiveBg",
            Size = UDim2.fromOffset(0, 24),
            BackgroundColor3 = Theme.SurfaceAlt,
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            ZIndex = 1,
        })
        activeBg.Parent = bar
        Corner(UDim.new(0, 6)).Parent = activeBg

        local buttons = {}

        for i, sub in next, tabObj.Subtabs do
            local btn = Create("TextButton", {
                Name = sub.Name,
                Size = UDim2.fromOffset(80, 24),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 3,
            })
            btn.Parent = holder

            local lbl = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Font = Fonts.Medium,
                Text = sub.Name,
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                ZIndex = 3,
            })
            lbl.Parent = btn

            buttons[i] = { btn = btn, lbl = lbl, sub = sub }

            btn.MouseButton1Click:Connect(function()
                self:_SelectSub(tabObj, sub)
            end)

            if tabObj.ActiveSub == sub then
                Tween(lbl, { TextColor3 = Theme.Text }, Ease.OutQuad)
                task.defer(function()
                    local targetX = btn.AbsolutePosition.X - bar.AbsolutePosition.X
                    activeBg.Position = UDim2.fromOffset(targetX, 0)
                    activeBg.Size = UDim2.fromOffset(btn.AbsoluteSize.X, 24)
                end)
            end
        end

        if not tabObj.ActiveSub and buttons[1] then
            self:_SelectSub(tabObj, buttons[1].sub)
        end

        tabObj._updateSubBg = function(activeSub)
            for _, data in pairs(buttons) do
                if data.sub == activeSub then
                    Tween(data.lbl, { TextColor3 = Theme.Text }, Ease.OutQuad)
                    local targetX = data.btn.AbsolutePosition.X - bar.AbsolutePosition.X
                    Tween(activeBg, { Position = UDim2.fromOffset(targetX, 0), Size = UDim2.fromOffset(data.btn.AbsoluteSize.X, 24) }, Ease.OutQuint)
                else
                    Tween(data.lbl, { TextColor3 = Theme.TextMuted }, Ease.OutQuad)
                end
            end
        end

    else
        local combo = Create("TextButton", {
            Size = UDim2.fromOffset(160, 24),
            BackgroundColor3 = Theme.SurfaceAlt,
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        })
        combo.Parent = bar
        Corner(UDim.new(0, 6)).Parent = combo
        Stroke(Theme.Outline, 1, 0.5).Parent = combo

        local comboLabel = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -30, 1, 0),
            Font = Fonts.Medium,
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
            BackgroundColor3 = Theme.Background,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 20,
        })
        dropdown.Parent = combo
        Corner(UDim.new(0, 6)).Parent = dropdown
        Stroke(Theme.Outline, 1).Parent = dropdown

        Create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }).Parent = dropdown
        Create("UIPadding", {
            PaddingTop = UDim.new(0, 6),
            PaddingBottom = UDim.new(0, 6),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
        }).Parent = dropdown

        local opened = false
        combo.MouseButton1Click:Connect(function()
            opened = not opened
            if opened then
                local target = #tabObj.Subtabs * 28 + 12
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
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Theme.SurfaceAlt,
                BackgroundTransparency = 1,
                Text = sub.Name,
                Font = Fonts.Body,
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 21,
            })
            opt.Parent = dropdown
            Corner(UDim.new(0, 4)).Parent = opt
            opt.MouseEnter:Connect(function() Tween(opt, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, Ease.OutQuad) end)
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
    end
    if tabObj._comboLabel then tabObj._comboLabel.Text = sub.Name end
    if tabObj._updateSubBg then tabObj._updateSubBg(sub) end
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
            BackgroundColor3 = Theme.Background,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            ScrollBarImageTransparency = 0.5,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            ClipsDescendants = true,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingEnabled = true,
            ZIndex = 1,
        })
        page.Parent = tabObj.Page
        Create("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Left
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
    local wrapper = {}
    wrapper.Section = function(_, sectionName)
        local section = { Name = sectionName or "Section" }
        local frame = Create("Frame", {
            Name = sectionName or "Section",
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = false,
            ZIndex = 2,
        })
        frame.Parent = page
        Round(frame, UDim.new(0, 9), Theme.Outline, 1)

        local header = Create("Frame", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            ZIndex = 2,
        })
        header.Parent = frame

        local title = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -28, 1, 0),
            Font = Fonts.Bold,
            Text = sectionName or "Section",
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        })
        title.Parent = header

        local inner = Create("Frame", {
            Name = "Inner",
            Position = UDim2.fromOffset(0, 34),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 2,
        })
        inner.Parent = frame
        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
        }).Parent = inner

        local columns = Create("Frame", {
            Name = "Columns",
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 2,
        })
        columns.Parent = inner

        local grid = Create("UIGridLayout", {
            CellSize = UDim2.new(0.5, -4, 0, 32),
            CellPadding = UDim2.new(0, 8, 0, 8),
            FillDirectionMaxCells = 2,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        grid.Parent = columns

        section._grid = grid
        section._columns = columns
        section._inner = inner
        section._frame = frame
        return self:_WrapSection(section, sub, page)
    end
    return wrapper
end

function Library:_WrapSection(section, sub, page)
    local wrapper = {}

    wrapper.Label = function(_, text)
        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Font = Fonts.Body,
            Text = text or "",
            TextColor3 = Theme.TextMuted,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 3,
        })
        lbl.Parent = section._columns
        return lbl
    end

    wrapper.Button = function(_, text, callback)
        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            ZIndex = 3,
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Fonts.Medium,
            Text = text or "Button",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 3,
        })
        lbl.Parent = btn

        btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 0 }, Ease.OutQuad) end)
        btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceAlt, BackgroundTransparency = Theme.Transp }, Ease.OutQuad) end)
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
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            ZIndex = 3,
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -80, 1, 0),
            Font = Fonts.Medium,
            Text = text or "Toggle",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
        })
        lbl.Parent = btn

        local track = Create("Frame", {
            Size = UDim2.fromOffset(28, 16),
            Position = UDim2.new(1, -38, 0.5, -8),
            BackgroundColor3 = Theme.Outline,
            BorderSizePixel = 0,
            ZIndex = 3,
        })
        track.Parent = btn
        Corner(UDim.new(1, 0)).Parent = track

        local knob = Create("Frame", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromOffset(2, 2),
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
            ZIndex = 4,
        })
        knob.Parent = track
        Corner(UDim.new(1, 0)).Parent = knob

        local dots = Create("TextButton", {
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.new(1, -64, 0.5, -10),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 4,
        })
        dots.Parent = btn
        for i = 1, 3 do
            local dot = Create("Frame", {
                Size = UDim2.fromOffset(2, 2),
                Position = UDim2.fromOffset(7 + (i - 1) * 3, 9),
                BackgroundColor3 = Theme.TextMuted,
                BorderSizePixel = 0,
                ZIndex = 4,
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

        btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 0 }, Ease.OutQuad) end)
        btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.SurfaceAlt, BackgroundTransparency = Theme.Transp }, Ease.OutQuad) end)
        btn.MouseButton1Click:Connect(function()
            apply(not state)
            if callback then callback(state) end
        end)

        dots.MouseButton1Click:Connect(function()
            if self.Popup then self.Popup:Destroy() end
            local popup = Create("Frame", {
                Name = "Popup",
                Size = UDim2.fromOffset(220, 140),
                Position = UDim2.new(0.5, -110, 0.5, -70),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                ZIndex = 100,
            })
            popup.Parent = self.ScreenGui
            Round(popup, UDim.new(0, 10), Theme.Outline, 1)
            self.Popup = popup
            Draggable(popup, popup)

            local header = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundTransparency = 1,
                ZIndex = 101,
            })
            header.Parent = popup

            local headerLbl = Create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0),
                Size = UDim2.new(1, -40, 1, 0),
                Font = Fonts.Bold,
                Text = text or "Options",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 101,
            })
            headerLbl.Parent = header

            local close = Create("TextButton", {
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(1, -28, 0, 6),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 101,
            })
            close.Parent = header
            local closeIcon = Create("ImageLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.fromOffset(5, 5),
                Image = "rbxassetid://10747384394",
                ImageColor3 = Theme.TextMuted,
                ZIndex = 102,
            })
            closeIcon.Parent = close
            close.MouseButton1Click:Connect(function() popup:Destroy() self.Popup = nil end)

            local content = Create("Frame", {
                Position = UDim2.fromOffset(0, 32),
                Size = UDim2.new(1, 0, 1, -32),
                BackgroundTransparency = 1,
                ZIndex = 101,
            })
            content.Parent = popup
            Create("UIPadding", {
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12),
            }).Parent = content

            local info = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 80),
                Font = Fonts.Body,
                Text = "Popup content for " .. (text or "") .. ".",
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 102,
            })
            info.Parent = content
        end)

        return { Set = function(_, v) apply(v) end }
    end

    wrapper.Slider = function(_, text, min, max, default, callback)
        min = min or 0 max = max or 100 default = default or min
        self.Flags[text] = default

        local frame = Create("Frame", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            ZIndex = 3,
        })
        frame.Parent = section._columns
        Round(frame, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0.5, -12, 1, 0),
            Font = Fonts.Medium,
            Text = text or "Slider",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
        lbl.Parent = frame

        local bar = Create("Frame", {
            Size = UDim2.new(0.3, 0, 0, 4),
            Position = UDim2.new(0.5, 0, 0.5, -2),
            BackgroundColor3 = Theme.Outline,
            BorderSizePixel = 0,
            ZIndex = 4,
        })
        bar.Parent = frame
        Corner(UDim.new(1, 0)).Parent = bar

        local fill = Create("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 4,
        })
        fill.Parent = bar
        Corner(UDim.new(1, 0)).Parent = fill

        local valueLbl = Create("TextButton", {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -40, 0.5, -8),
            Size = UDim2.fromOffset(30, 16),
            Font = Fonts.Bold,
            Text = tostring(default),
            TextColor3 = Theme.Accent,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 4,
        })
        valueLbl.Parent = frame

        local box = Create("TextBox", {
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 0, 0.5, -9),
            Size = UDim2.new(0.3, 0, 0, 18),
            Font = Fonts.Body,
            Text = tostring(default),
            TextColor3 = Theme.Text,
            TextSize = 12,
            Visible = false,
            ClearTextOnFocus = false,
            ZIndex = 4,
        })
        box.Parent = frame
        Round(box, UDim.new(0, 4))

        local dragging = false
        local function update(input)
            local pct = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * pct + 0.5)
            valueLbl.Text = tostring(val)
            box.Text = tostring(val)
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
        local moveConn, endConn
        moveConn = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
        endConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        table.insert(self._connections, moveConn)
        table.insert(self._connections, endConn)

        local pct = (default - min) / (max - min)
        fill.Size = UDim2.fromScale(pct, 1)

        valueLbl.MouseButton1Click:Connect(function()
            Tween(valueLbl, { TextTransparency = 1 }, Ease.OutQuad)
            Tween(bar, { BackgroundTransparency = 1 }, Ease.OutQuad)
            Tween(fill, { BackgroundTransparency = 1 }, Ease.OutQuad)
            box.Visible = true
            box:CaptureFocus()
        end)

        local function saveBox()
            local num = tonumber(box.Text)
            if num then
                local val = math.clamp(math.floor(num), min, max)
                valueLbl.Text = tostring(val)
                fill.Size = UDim2.fromScale((val - min) / (max - min), 1)
                self.Flags[text] = val
                if callback then callback(val) end
            else
                box.Text = valueLbl.Text
            end
            box.Visible = false
            box:ReleaseFocus()
            Tween(valueLbl, { TextTransparency = 0 }, Ease.OutQuad)
            Tween(bar, { BackgroundTransparency = 0 }, Ease.OutQuad)
            Tween(fill, { BackgroundTransparency = 0 }, Ease.OutQuad)
        end

        box.FocusLost:Connect(saveBox)

        return { Set = function(_, v)
            self.Flags[text] = v
            valueLbl.Text = tostring(v)
            box.Text = tostring(v)
            fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
        end }
    end

    wrapper.Textbox = function(_, text, placeholder, callback)
        local frame = Create("Frame", {
            BackgroundColor3 = Theme.SurfaceAlt,
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            ZIndex = 3,
        })
        frame.Parent = section._columns
        Round(frame, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0.4, -12, 1, 0),
            Font = Fonts.Medium,
            Text = text or "Textbox",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
        lbl.Parent = frame

        local box = Create("TextBox", {
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Position = UDim2.new(0.4, 4, 0.5, -10),
            Size = UDim2.new(0.6, -16, 0, 20),
            Font = Fonts.Body,
            PlaceholderText = placeholder or "Enter...",
            PlaceholderColor3 = Theme.TextMuted,
            Text = "",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 4,
        })
        box.Parent = frame
        Corner(UDim.new(0, 4)).Parent = box
        Create("UIPadding", { PaddingLeft = UDim.new(0, 8) }).Parent = box

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
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = false,
            ZIndex = 3,
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0.5, -12, 1, 0),
            Font = Fonts.Medium,
            Text = text or "Dropdown",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
        lbl.Parent = btn

        local valueLbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0.5, -22, 1, 0),
            Font = Fonts.Body,
            Text = default or options[1] or "Select",
            TextColor3 = Theme.Accent,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 4,
        })
        valueLbl.Parent = btn

        local arrow = Create("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -16, 0.5, -3),
            Size = UDim2.fromOffset(6, 6),
            Image = "rbxassetid://10709790948",
            ImageColor3 = Theme.TextMuted,
            ZIndex = 4,
        })
        arrow.Parent = btn

        local drop = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0, 0, 1, 4),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 10,
        })
        drop.Parent = btn
        Corner(UDim.new(0, 6)).Parent = drop
        Stroke(Theme.Outline, 1).Parent = drop

        Create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }).Parent = drop
        Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }).Parent = drop

        local opened = false
        btn.MouseButton1Click:Connect(function()
            opened = not opened
            if opened then
                drop.Visible = true
                drop.Size = UDim2.new(1, 0, 0, 0)
                Tween(drop, { Size = UDim2.new(1, 0, 0, #options * 28 + 12) }, Ease.OutCubic)
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
                Font = Fonts.Body,
                TextColor3 = Theme.TextMuted,
                TextSize = 12,
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 11,
            })
            optBtn.Parent = drop
            Corner(UDim.new(0, 4)).Parent = optBtn
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
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            ZIndex = 3,
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0.6, -12, 1, 0),
            Font = Fonts.Medium,
            Text = text or "Keybind",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
        lbl.Parent = btn

        local keyLbl = Create("TextLabel", {
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Position = UDim2.new(0.6, 0, 0.5, -9),
            Size = UDim2.new(0.4, -12, 0, 18),
            Font = Fonts.Bold,
            Text = key.Name,
            TextColor3 = Theme.Accent,
            TextSize = 11,
            ZIndex = 4,
        })
        keyLbl.Parent = btn
        Corner(UDim.new(0, 4)).Parent = keyLbl

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
            BackgroundTransparency = Theme.Transp,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            ZIndex = 3,
        })
        btn.Parent = section._columns
        Round(btn, Theme.RadiusSmall)

        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -50, 1, 0),
            Font = Fonts.Medium,
            Text = text or "Color",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
        lbl.Parent = btn

        local swatch = Create("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.new(1, -30, 0.5, -9),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            ZIndex = 4,
        })
        swatch.Parent = btn
        Round(swatch, UDim.new(0, 4), Theme.Outline, 1)

        btn.MouseButton1Click:Connect(function()
            local gui = self.ScreenGui
            local popup = Create("Frame", {
                Size = UDim2.fromOffset(200, 160),
                Position = UDim2.new(0.5, -100, 0.5, -80),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                ZIndex = 100,
            })
            popup.Parent = gui
            Round(popup, UDim.new(0, 10), Theme.Outline, 1)
            Draggable(popup, popup)

            local field = Create("ImageLabel", {
                Size = UDim2.new(1, -20, 1, -44),
                Position = UDim2.fromOffset(10, 10),
                BackgroundTransparency = 1,
                Image = "rbxassetid://6523286724",
                ZIndex = 101,
            })
            field.Parent = popup

            local cursor = Create("Frame", {
                Size = UDim2.fromOffset(10, 10),
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
                    local x = math.clamp((input.Position.X - field.AbsolutePosition.X) / field.AbsoluteSize.X, 0, 1)
                    local y = math.clamp((input.Position.Y - field.AbsolutePosition.Y) / field.AbsoluteSize.Y, 0, 1)
                    color = Color3.fromHSV(1 - x, 1 - y, 1)
                    swatch.BackgroundColor3 = color
                    self.Flags[text] = color
                    cursor.Position = UDim2.fromScale(x, y)
                    if callback then callback(color) end
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
                Position = UDim2.new(1, -28, 0, 6),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 103,
            })
            close.Parent = popup
            local closeIcon = Create("ImageLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.fromOffset(5, 5),
                Image = "rbxassetid://10747384394",
                ImageColor3 = Theme.TextMuted,
                ZIndex = 103,
            })
            closeIcon.Parent = close
            close.MouseButton1Click:Connect(function() popup:Destroy() end)
        end)
    end

    return wrapper
end

return Library
