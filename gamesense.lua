local library = {}
library.__index = library
library.pages = {}
library.pages.__index = library.pages
library.sections = {}
library.sections.__index = library.sections

local tween_service = game:GetService("TweenService")
local input_service = game:GetService("UserInputService")
local core_gui = game:GetService("CoreGui")

local color_from_rgb = Color3.fromRGB
local color_from_hsv = Color3.fromHSV
local udim2_new = UDim2.new
local vector2_new = Vector2.new
local color_sequence_new = ColorSequence.new
local number_sequence_new = NumberSequence.new
local number_sequence_keypoint_new = NumberSequenceKeypoint.new
local color_sequence_keypoint_new = ColorSequenceKeypoint.new
local tween_info_new = TweenInfo.new

local accent_color = color_from_rgb(255, 120, 30)

library.renders = {}
library.connections = {}
library.folder_name = "PuppyWare"
library.assets_folder = "Assets"
library.configs_folder = "Configs"

local function render_object(render_type, properties)
    local instance = Instance.new(render_type)
    local render_time = nil
    if properties then
        for property, value in pairs(properties) do
            if property == "RenderTime" then
                render_time = value
            else
                instance[property] = value
            end
        end
    end
    library.renders[#library.renders + 1] = {instance, properties or {}, false, render_time}
    return instance
end

local function create_connection(signal, callback)
    local connection = signal:Connect(callback)
    library.connections[#library.connections + 1] = connection
    return connection
end

local function make_draggable(frame, handle)
    handle = handle or frame
    local dragging = false
    local drag_start = nil
    local start_position = nil
    local drag_connection = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        dragging = true
        drag_start = input.Position
        start_position = frame.Position
        drag_connection = input_service.InputChanged:Connect(function(move_input)
            if move_input.UserInputType ~= Enum.UserInputType.MouseMovement or not dragging then
                return
            end
            local delta = move_input.Position - drag_start
            frame.Position = udim2_new(start_position.X.Scale, start_position.X.Offset + delta.X, start_position.Y.Scale, start_position.Y.Offset + delta.Y)
        end)
        local release_connection
        release_connection = input_service.InputEnded:Connect(function(end_input)
            if end_input.UserInputType ~= Enum.UserInputType.MouseButton1 or not dragging then
                return
            end
            dragging = false
            if drag_connection then
                drag_connection:Disconnect()
                drag_connection = nil
            end
            release_connection:Disconnect()
        end)
    end)
end

local function mouse_location()
    return input_service:GetMouseLocation()
end

local function serialise_list(list)
    local result = ""
    for _, value in pairs(list) do
        result = result .. value .. ", "
    end
    return result:sub(1, #result - 2)
end

local function sort_options(indices, options)
    local result = {}
    for index, value in pairs(options) do
        if table.find(indices, index) then
            result[#result + 1] = value
        end
    end
    return result
end

local function is_mouse_over_frame(frame)
    local mouse = mouse_location()
    local position = frame.AbsolutePosition
    local size = frame.AbsoluteSize
    return mouse.X >= position.X and mouse.Y >= position.Y and mouse.X <= position.X + size.X and mouse.Y <= position.Y + size.Y
end

function library:CreateWindow(properties)
    properties = properties or {}
    local window = {
        Pages = {},
        Accent = accent_color,
        Enabled = true,
        Key = Enum.KeyCode.Insert
    }

    local screen_gui = render_object("ScreenGui", {
        DisplayOrder = 9999,
        Enabled = true,
        IgnoreGuiInset = true,
        Parent = core_gui,
        ResetOnSpawn = false,
        ZIndexBehavior = "Global"
    })

    local main_frame = render_object("Frame", {
        AnchorPoint = vector2_new(0.5, 0.5),
        BackgroundColor3 = color_from_rgb(25, 25, 25),
        BorderColor3 = color_from_rgb(12, 12, 12),
        BorderMode = "Inset",
        BorderSizePixel = 1,
        Parent = screen_gui,
        Position = udim2_new(0.5, 0, 0.5, 0),
        Size = udim2_new(0, 660, 0, 560)
    })

    local main_inner_border = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(40, 40, 40),
        BorderSizePixel = 0,
        Parent = main_frame,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2)
    })

    local main_inner_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderColor3 = color_from_rgb(60, 60, 60),
        BorderMode = "Inset",
        BorderSizePixel = 1,
        Parent = main_frame,
        Position = udim2_new(0, 3, 0, 3),
        Size = udim2_new(1, -6, 1, -6)
    })

    local tabs_holder = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = main_inner_frame,
        Position = udim2_new(0, 0, 0, 4),
        Size = udim2_new(0, 74, 1, -4)
    })

    local pages_holder = render_object("Frame", {
        AnchorPoint = vector2_new(1, 0),
        BackgroundColor3 = color_from_rgb(0, 0, 0),
        BorderSizePixel = 0,
        Parent = main_inner_frame,
        Position = udim2_new(1, 0, 0, 4),
        Size = udim2_new(1, -73, 1, -4)
    })

    local top_gradient = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = main_inner_frame,
        Position = udim2_new(0, 0, 0, 0),
        Size = udim2_new(1, 0, 0, 4)
    })

    render_object("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = tabs_holder,
        FillDirection = "Vertical",
        HorizontalAlignment = "Left",
        VerticalAlignment = "Top"
    })

    render_object("UIPadding", {
        Parent = tabs_holder,
        PaddingTop = UDim.new(0, 9)
    })

    local pages_inner_border = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(45, 45, 45),
        BorderSizePixel = 0,
        Parent = pages_holder,
        Position = udim2_new(0, 1, 0, 0),
        Size = udim2_new(1, -1, 1, 0)
    })

    render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = top_gradient,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        Image = "rbxassetid://8508019876",
        ImageColor3 = color_from_rgb(255, 255, 255)
    })

    local pages_inner_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(20, 20, 20),
        BorderSizePixel = 0,
        Parent = pages_inner_border,
        Position = udim2_new(0, 1, 0, 0),
        Size = udim2_new(1, -1, 1, 0)
    })

    local pages_folder = render_object("Folder", {
        Parent = pages_inner_frame
    })

    render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = pages_inner_frame,
        Position = udim2_new(0, 0, 0, 0),
        Size = udim2_new(1, 0, 1, 0),
        Image = "rbxassetid://8547666218",
        ImageColor3 = color_from_rgb(12, 12, 12),
        ScaleType = "Tile",
        TileSize = udim2_new(0, 8, 0, 8)
    })

    window["TabsHolder"] = tabs_holder
    window["PagesHolder"] = pages_folder

    make_draggable(main_frame, top_gradient)

    function window:SetPage(active_page)
        for _, page in pairs(window.Pages) do
            if page.Open and page ~= active_page then
                page:Set(false)
            end
        end
    end

    function window:Fade(state)
        for _, render in pairs(library.renders) do
            if not render[3] then
                local instance = render[1]
                local props = render[2] or {}
                local duration = render[4] or 0.25
                local easing = state and Enum.EasingDirection.Out or Enum.EasingDirection.In
                local info = tween_info_new(duration, Enum.EasingStyle.Linear, easing)
                if instance.ClassName == "Frame" and (props.BackgroundTransparency or 0) ~= 1 then
                    tween_service:Create(instance, info, {BackgroundTransparency = state and (props.BackgroundTransparency or 0) or 1}):Play()
                elseif instance.ClassName == "ImageLabel" then
                    if (props.BackgroundTransparency or 0) ~= 1 then
                        tween_service:Create(instance, info, {BackgroundTransparency = state and (props.BackgroundTransparency or 0) or 1}):Play()
                    end
                    if (props.ImageTransparency or 0) ~= 1 then
                        tween_service:Create(instance, info, {ImageTransparency = state and (props.ImageTransparency or 0) or 1}):Play()
                    end
                elseif instance.ClassName == "TextLabel" then
                    if (props.BackgroundTransparency or 0) ~= 1 then
                        tween_service:Create(instance, info, {BackgroundTransparency = state and (props.BackgroundTransparency or 0) or 1}):Play()
                    end
                    if (props.TextTransparency or 0) ~= 1 then
                        tween_service:Create(instance, info, {TextTransparency = state and (props.TextTransparency or 0) or 1}):Play()
                    end
                elseif instance.ClassName == "ScrollingFrame" then
                    if (props.BackgroundTransparency or 0) ~= 1 then
                        tween_service:Create(instance, info, {BackgroundTransparency = state and (props.BackgroundTransparency or 0) or 1}):Play()
                    end
                    if (props.ScrollBarImageTransparency or 0) ~= 1 then
                        tween_service:Create(instance, info, {ScrollBarImageTransparency = state and (props.ScrollBarImageTransparency or 0) or 1}):Play()
                    end
                end
            end
        end
    end

    function window:Unload()
        screen_gui:Remove()
        for _, connection in pairs(library.connections) do
            connection:Disconnect()
        end
        library = nil
    end

    create_connection(input_service.InputBegan, function(input)
        if input.KeyCode == window.Key then
            window.Enabled = not window.Enabled
            window:Fade(window.Enabled)
            input_service.MouseIconEnabled = window.Enabled
        elseif input.KeyCode == Enum.KeyCode.X then
            window:Unload()
        end
    end)

    return setmetatable(window, library)
end

function library:CreatePage(properties)
    properties = properties or {}
    local page = {
        Image = properties.image or properties.Image or properties.icon or properties.Icon,
        Size = properties.size or properties.Size or udim2_new(0, 50, 0, 50),
        Open = false,
        Window = self
    }

    local tab = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = page.Window["TabsHolder"],
        Size = udim2_new(1, 0, 0, 72)
    })

    local tab_border = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(0, 0, 0),
        BorderSizePixel = 0,
        Parent = tab,
        Size = udim2_new(1, 0, 1, 0),
        Visible = false,
        ZIndex = 2
    })

    local tab_image = render_object("ImageLabel", {
        AnchorPoint = vector2_new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = tab,
        Position = udim2_new(0.5, 0, 0.5, 0),
        Size = page.Size,
        ZIndex = 2,
        Image = page.Image,
        ImageColor3 = color_from_rgb(100, 100, 100)
    })

    local tab_button = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = tab,
        Size = udim2_new(1, 0, 1, 0),
        Text = ""
    })

    local border_inner = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(40, 40, 40),
        BorderSizePixel = 0,
        Parent = tab_border,
        Position = udim2_new(0, 0, 0, 1),
        Size = udim2_new(1, 1, 1, -2),
        ZIndex = 2
    })

    local inner_inner = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(20, 20, 20),
        BorderSizePixel = 0,
        Parent = border_inner,
        Position = udim2_new(0, 0, 0, 1),
        Size = udim2_new(1, 0, 1, -2),
        ZIndex = 2
    })

    render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = inner_inner,
        Size = udim2_new(1, 0, 1, 0),
        Image = "rbxassetid://8509210785",
        ImageColor3 = color_from_rgb(12, 12, 12),
        ScaleType = "Tile",
        TileSize = udim2_new(0, 8, 0, 8),
        ZIndex = 2
    })

    local page_frame = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = page.Window["PagesHolder"],
        Position = udim2_new(0, 20, 0, 20),
        Size = udim2_new(1, -40, 1, -40),
        Visible = false
    })

    local page_left = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = page_frame,
        Size = udim2_new(0.5, -10, 1, 0)
    })

    local page_right = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = page_frame,
        Position = udim2_new(0.5, 10, 0, 0),
        Size = udim2_new(0.5, -10, 1, 0)
    })

    render_object("UIListLayout", {
        Padding = UDim.new(0, 18),
        Parent = page_left,
        FillDirection = "Vertical",
        HorizontalAlignment = "Left",
        VerticalAlignment = "Top"
    })

    render_object("UIListLayout", {
        Padding = UDim.new(0, 18),
        Parent = page_right,
        FillDirection = "Vertical",
        HorizontalAlignment = "Left",
        VerticalAlignment = "Top"
    })

    page["Page"] = page_frame
    page["Left"] = page_left
    page["Right"] = page_right

    function page:Set(state)
        page.Open = state
        page_frame.Visible = state
        tab_border.Visible = state
        tab_image.ImageColor3 = state and color_from_rgb(255, 255, 255) or color_from_rgb(90, 90, 90)
        if state then
            page.Window:SetPage(page)
        end
    end

    create_connection(tab_button.MouseButton1Click, function()
        if not page.Open then
            page:Set(true)
        end
    end)

    create_connection(tab_button.MouseEnter, function()
        tab_image.ImageColor3 = color_from_rgb(172, 172, 172)
    end)

    create_connection(tab_button.MouseLeave, function()
        tab_image.ImageColor3 = page.Open and color_from_rgb(255, 255, 255) or color_from_rgb(90, 90, 90)
    end)

    if #page.Window.Pages == 0 then
        page:Set(true)
    end
    page.Window.Pages[#page.Window.Pages + 1] = page
    return setmetatable(page, library.pages)
end

function library.pages:CreateSection(properties)
    properties = properties or {}
    local section = {
        Name = properties.name or properties.Name or properties.title or properties.Title or "New Section",
        Size = properties.size or properties.Size or 150,
        Side = properties.side or properties.Side or "Left",
        Content = {},
        Window = self.Window,
        Page = self
    }

    local holder = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(40, 40, 40),
        BorderColor3 = color_from_rgb(12, 12, 12),
        BorderMode = "Inset",
        BorderSizePixel = 1,
        Parent = section.Page[section.Side],
        Size = udim2_new(1, 0, 0, section.Size),
        ZIndex = 2
    })

    local extra = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 2
    })

    local holder_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(23, 23, 23),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 2
    })

    local title_inline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(23, 23, 23),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 9, 0, -1),
        Size = udim2_new(0, 0, 0, 2),
        ZIndex = 5
    })

    local title = render_object("TextLabel", {
        AnchorPoint = vector2_new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 12, 0, 0),
        Size = udim2_new(1, -26, 0, 15),
        ZIndex = 5,
        Font = "Code",
        RichText = true,
        Text = "<b>" .. section.Name .. "</b>",
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 11,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    local gradient_top = render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = extra,
        Position = udim2_new(0, 1, 0, 1),
        Rotation = 180,
        Size = udim2_new(1, -2, 0, 20),
        Visible = false,
        ZIndex = 4,
        Image = "rbxassetid://7783533907",
        ImageColor3 = color_from_rgb(23, 23, 23)
    })

    local gradient_bottom = render_object("ImageLabel", {
        AnchorPoint = vector2_new(0, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = extra,
        Position = udim2_new(0, 0, 1, 0),
        Size = udim2_new(1, -2, 0, 20),
        Visible = false,
        ZIndex = 4,
        Image = "rbxassetid://7783533907",
        ImageColor3 = color_from_rgb(23, 23, 23)
    })

    local arrow_up = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = extra,
        Position = udim2_new(1, -21, 0, 0),
        Size = udim2_new(0, 15, 0, 14),
        Text = "",
        Visible = false,
        ZIndex = 4
    })

    local arrow_down = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = extra,
        Position = udim2_new(1, -21, 1, -14),
        Size = udim2_new(0, 15, 0, 14),
        Text = "",
        Visible = false,
        ZIndex = 4
    })

    render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = arrow_up,
        Position = udim2_new(0, 4, 0, 4),
        Size = udim2_new(0, 7, 0, 6),
        ZIndex = 4,
        Image = "rbxassetid://8548757311",
        ImageColor3 = color_from_rgb(205, 205, 205)
    })

    render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = arrow_down,
        Position = udim2_new(0, 4, 0, 4),
        Size = udim2_new(0, 7, 0, 6),
        ZIndex = 4,
        Image = "rbxassetid://8548723563",
        ImageColor3 = color_from_rgb(205, 205, 205)
    })

    local scrollbar = render_object("Frame", {
        AnchorPoint = vector2_new(1, 0),
        BackgroundColor3 = color_from_rgb(45, 45, 45),
        BorderSizePixel = 0,
        Parent = extra,
        Position = udim2_new(1, 0, 0, 0),
        Size = udim2_new(0, 6, 1, 0),
        Visible = false,
        ZIndex = 4
    })

    render_object("Frame", {
        BackgroundColor3 = color_from_rgb(45, 45, 45),
        BorderSizePixel = 0,
        Parent = extra,
        Position = udim2_new(0, 0, 0, -1),
        Size = udim2_new(1, 0, 0, 1),
        ZIndex = 4
    })

    local content_holder = render_object("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder_frame,
        Size = udim2_new(1, 0, 1, 0),
        ZIndex = 4,
        AutomaticCanvasSize = "Y",
        BottomImage = "rbxassetid://7783554086",
        CanvasSize = udim2_new(0, 0, 0, 0),
        MidImage = "rbxassetid://7783554086",
        ScrollBarImageColor3 = color_from_rgb(65, 65, 65),
        ScrollBarImageTransparency = 0,
        ScrollBarThickness = 5,
        TopImage = "rbxassetid://7783554086",
        VerticalScrollBarInset = "None"
    })

    render_object("UIListLayout", {
        Padding = UDim.new(0, 0),
        Parent = content_holder,
        FillDirection = "Vertical",
        HorizontalAlignment = "Center",
        VerticalAlignment = "Top"
    })

    render_object("UIPadding", {
        Parent = content_holder,
        PaddingTop = UDim.new(0, 15),
        PaddingBottom = UDim.new(0, 15)
    })

    title_inline.Size = udim2_new(0, title.TextBounds.X + 6, 0, 2)

    section["Holder"] = content_holder
    section["Extra"] = extra

    function section:CloseContent()
        if section.Content.Open then
            section.Content:Close()
            section.Content = {}
        end
    end

    create_connection(content_holder:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
        local needs_scroll = content_holder.AbsoluteCanvasSize.Y > content_holder.AbsoluteWindowSize.Y
        gradient_top.Visible = needs_scroll
        gradient_bottom.Visible = needs_scroll
        scrollbar.Visible = needs_scroll
        if needs_scroll then
            arrow_up.Visible = content_holder.CanvasPosition.Y > 5
            arrow_down.Visible = content_holder.CanvasPosition.Y + 5 < content_holder.AbsoluteCanvasSize.Y - content_holder.AbsoluteSize.Y
        end
    end)

    create_connection(content_holder:GetPropertyChangedSignal("CanvasPosition"), function()
        if section.Content.Open then
            section.Content:Close()
            section.Content = {}
        end
        arrow_up.Visible = content_holder.CanvasPosition.Y > 1
        arrow_down.Visible = content_holder.CanvasPosition.Y + 1 < content_holder.AbsoluteCanvasSize.Y - content_holder.AbsoluteSize.Y
    end)

    create_connection(arrow_up.MouseButton1Click, function()
        content_holder.CanvasPosition = Vector2.new(0, math.clamp(content_holder.CanvasPosition.Y - 10, 0, content_holder.AbsoluteCanvasSize.Y - content_holder.AbsoluteSize.Y))
    end)

    create_connection(arrow_down.MouseButton1Click, function()
        content_holder.CanvasPosition = Vector2.new(0, math.clamp(content_holder.CanvasPosition.Y + 10, 0, content_holder.AbsoluteCanvasSize.Y - content_holder.AbsoluteSize.Y))
    end)

    return setmetatable(section, library.sections)
end

function library.sections:CreateToggle(properties)
    properties = properties or {}
    local toggle = {
        Name = properties.name or properties.Name or properties.title or properties.Title or "New Toggle",
        State = properties.state or properties.State or properties.def or properties.Def or properties.default or properties.Default or false,
        Callback = properties.callback or properties.Callback or properties.callBack or properties.CallBack or function() end,
        Window = self.Window,
        Page = self.Page,
        Section = self
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = toggle.Section.Holder,
        Size = udim2_new(1, 0, 0, 18),
        ZIndex = 3
    })

    local outline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 20, 0, 5),
        Size = udim2_new(0, 8, 0, 8),
        ZIndex = 3
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 0),
        Size = udim2_new(1, -41, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = toggle.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 0),
        Size = udim2_new(1, -41, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = toggle.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextTransparency = 0.5,
        TextXAlignment = "Left"
    })

    local button = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Size = udim2_new(1, 0, 1, 0),
        Text = ""
    })

    local outline_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(77, 77, 77),
        BorderSizePixel = 0,
        Parent = outline,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 3
    })

    local gradient = render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(140, 140, 140)),
        Rotation = 90,
        Parent = outline_frame
    })

    function toggle:Set(state)
        toggle.State = state
        outline_frame.BackgroundColor3 = state and toggle.Window.Accent or color_from_rgb(77, 77, 77)
        toggle.Callback(toggle:Get())
    end

    function toggle:Get()
        return toggle.State
    end

    create_connection(button.MouseButton1Click, function()
        toggle:Set(not toggle:Get())
    end)

    create_connection(button.MouseEnter, function()
        gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(180, 180, 180))
    end)

    create_connection(button.MouseLeave, function()
        gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(140, 140, 140))
    end)

    toggle:Set(toggle.State)
    return toggle
end

function library.sections:CreateSlider(properties)
    properties = properties or {}
    local slider = {
        Name = properties.name or properties.Name or properties.title or properties.Title or nil,
        State = properties.state or properties.State or properties.def or properties.Def or properties.default or properties.Default or 0,
        Min = properties.min or properties.Min or properties.minimum or properties.Minimum or 0,
        Max = properties.max or properties.Max or properties.maximum or properties.Maximum or 100,
        Ending = properties.ending or properties.Ending or properties.suffix or properties.Suffix or "",
        Decimals = 1 / (properties.decimals or properties.Decimals or properties.tick or properties.Tick or 1),
        Callback = properties.callback or properties.Callback or properties.callBack or properties.CallBack or function() end,
        Holding = false,
        Window = self.Window,
        Page = self.Page,
        Section = self
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = slider.Section.Holder,
        Size = udim2_new(1, 0, 0, (slider.Name and 24 or 13) + 5),
        ZIndex = 3
    })

    local outline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 40, 0, slider.Name and 18 or 5),
        Size = udim2_new(1, -99, 0, 7),
        ZIndex = 3
    })

    if slider.Name then
        render_object("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = holder,
            Position = udim2_new(0, 41, 0, 4),
            Size = udim2_new(1, -41, 0, 10),
            ZIndex = 3,
            Font = "Code",
            RichText = true,
            Text = slider.Name,
            TextColor3 = color_from_rgb(205, 205, 205),
            TextSize = 9,
            TextStrokeTransparency = 1,
            TextXAlignment = "Left"
        })

        render_object("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = holder,
            Position = udim2_new(0, 41, 0, 4),
            Size = udim2_new(1, -41, 0, 10),
            ZIndex = 3,
            Font = "Code",
            RichText = true,
            Text = slider.Name,
            TextColor3 = color_from_rgb(205, 205, 205),
            TextSize = 9,
            TextStrokeTransparency = 1,
            TextTransparency = 0.5,
            TextXAlignment = "Left"
        })
    end

    local button = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Size = udim2_new(1, 0, 1, 0),
        Text = ""
    })

    local outline_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(71, 71, 71),
        BorderSizePixel = 0,
        Parent = outline,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 3
    })

    local fill = render_object("Frame", {
        BackgroundColor3 = slider.Window.Accent,
        BorderSizePixel = 0,
        Parent = outline_frame,
        Size = udim2_new(0, 0, 1, 0),
        ZIndex = 3
    })

    local outline_gradient = render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(175, 175, 175)),
        Rotation = 270,
        Parent = outline_frame
    })

    local fill_gradient = render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(175, 175, 175)),
        Rotation = 90,
        Parent = fill
    })

    local value_label = render_object("TextLabel", {
        AnchorPoint = vector2_new(0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = fill,
        Position = udim2_new(1, 0, 0.5, 1),
        Size = udim2_new(0, 2, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = "",
        TextColor3 = color_from_rgb(255, 255, 255),
        TextSize = 11,
        TextStrokeTransparency = 0.5,
        TextXAlignment = "Center"
    })

    render_object("TextLabel", {
        AnchorPoint = vector2_new(0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = fill,
        Position = udim2_new(1, 0, 0.5, 1),
        Size = udim2_new(0, 2, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = "",
        TextColor3 = color_from_rgb(255, 255, 255),
        TextSize = 11,
        TextStrokeTransparency = 0.5,
        TextXAlignment = "Center"
    })

    function slider:Set(state)
        slider.State = math.clamp(math.round(state * slider.Decimals) / slider.Decimals, slider.Min, slider.Max)
        value_label.Text = "<b>" .. slider.State .. slider.Ending .. "</b>"
        fill.Size = udim2_new(1 - ((slider.Max - slider.State) / (slider.Max - slider.Min)), 0, 1, 0)
        slider.Callback(slider:Get())
    end

    function slider:Refresh()
        local mouse = mouse_location()
        local relative_x = math.clamp(mouse.X - fill.AbsolutePosition.X, 0, outline_frame.AbsoluteSize.X) / outline_frame.AbsoluteSize.X
        slider:Set(slider.Min + (slider.Max - slider.Min) * relative_x)
    end

    function slider:Get()
        return slider.State
    end

    create_connection(button.MouseButton1Down, function()
        slider:Refresh()
        slider.Holding = true
        outline_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(215, 215, 215))
        fill_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(215, 215, 215))
    end)

    create_connection(button.MouseEnter, function()
        outline_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(215, 215, 215))
        fill_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(215, 215, 215))
    end)

    create_connection(button.MouseLeave, function()
        local end_color = slider.Holding and color_from_rgb(215, 215, 215) or color_from_rgb(175, 175, 175)
        outline_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), end_color)
        fill_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), end_color)
    end)

    create_connection(input_service.InputChanged, function(input)
        if slider.Holding then
            slider:Refresh()
        end
    end)

    create_connection(input_service.InputEnded, function(input)
        if slider.Holding and input.UserInputType == Enum.UserInputType.MouseButton1 then
            slider.Holding = false
            outline_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(175, 175, 175))
            fill_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(175, 175, 175))
        end
    end)

    slider:Set(slider.State)
    return slider
end

function library.sections:CreateDropdown(properties)
    properties = properties or {}
    local dropdown = {
        Name = properties.name or properties.Name or properties.title or properties.Title or "New Dropdown",
        State = properties.state or properties.State or properties.def or properties.Def or properties.default or properties.Default or 1,
        Options = properties.options or properties.Options or properties.list or properties.List or {1, 2, 3},
        Callback = properties.callback or properties.Callback or properties.callBack or properties.CallBack or function() end,
        Content = {Open = false},
        Window = self.Window,
        Page = self.Page,
        Section = self
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = dropdown.Section.Holder,
        Size = udim2_new(1, 0, 0, 39),
        ZIndex = 3
    })

    local outline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 40, 0, 15),
        Size = udim2_new(1, -98, 0, 20),
        ZIndex = 3
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 4),
        Size = udim2_new(1, -41, 0, 10),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = dropdown.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 4),
        Size = udim2_new(1, -41, 0, 10),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = dropdown.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextTransparency = 0.5,
        TextXAlignment = "Left"
    })

    local button = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Size = udim2_new(1, 0, 1, 0),
        Text = ""
    })

    local outline_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(36, 36, 36),
        BorderSizePixel = 0,
        Parent = outline,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 3
    })

    render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(220, 220, 220)),
        Rotation = 270,
        Parent = outline_frame
    })

    local value_label = render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = outline_frame,
        Position = udim2_new(0, 8, 0, 0),
        Size = udim2_new(1, 0, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = "",
        TextColor3 = color_from_rgb(155, 155, 155),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = outline_frame,
        Position = udim2_new(1, -11, 0.5, -4),
        Size = udim2_new(0, 7, 0, 6),
        Image = "rbxassetid://8532000591",
        ImageColor3 = color_from_rgb(255, 255, 255),
        ZIndex = 3
    })

    function dropdown:Set(state)
        dropdown.State = state
        value_label.Text = tostring(dropdown.Options[state])
        dropdown.Callback(dropdown:Get())
        if dropdown.Content.Open then
            dropdown.Content:Refresh()
        end
    end

    function dropdown:Get()
        return dropdown.State
    end

    function dropdown:Open()
        dropdown.Section:CloseContent()
        local open_items = {}
        local connections = {}
        local input_check
        local open_holder = render_object("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = dropdown.Section.Extra,
            Position = udim2_new(0, outline.AbsolutePosition.X - dropdown.Section.Extra.AbsolutePosition.X, 0, outline.AbsolutePosition.Y - dropdown.Section.Extra.AbsolutePosition.Y + 21),
            Size = udim2_new(1, -98, 0, (18 * #dropdown.Options) + 2),
            ZIndex = 6
        })

        local open_outline = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(12, 12, 12),
            BorderSizePixel = 0,
            Parent = open_holder,
            Size = udim2_new(1, 0, 1, 0),
            ZIndex = 6
        })

        local open_frame = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(35, 35, 35),
            BorderSizePixel = 0,
            Parent = open_outline,
            Position = udim2_new(0, 1, 0, 1),
            Size = udim2_new(1, -2, 1, -2),
            ZIndex = 6
        })

        for index, option in pairs(dropdown.Options) do
            local option_frame = render_object("Frame", {
                BackgroundColor3 = color_from_rgb(35, 35, 35),
                BorderSizePixel = 0,
                Parent = open_frame,
                Position = udim2_new(0, 0, 0, 18 * (index - 1)),
                Size = udim2_new(1, 0, 1 / #dropdown.Options, 0),
                ZIndex = 6
            })

            local option_label = render_object("TextLabel", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = option_frame,
                Position = udim2_new(0, 8, 0, 0),
                Size = udim2_new(1, 0, 1, 0),
                ZIndex = 6,
                Font = "Code",
                RichText = true,
                Text = tostring(option),
                TextColor3 = index == dropdown.State and dropdown.Window.Accent or color_from_rgb(205, 205, 205),
                TextSize = 9,
                TextStrokeTransparency = 1,
                TextXAlignment = "Left"
            })

            local option_button = render_object("TextButton", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = option_frame,
                Size = udim2_new(1, 0, 1, 0),
                Text = "",
                ZIndex = 6
            })

            connections[#connections + 1] = create_connection(option_button.MouseButton1Click, function()
                dropdown:Set(index)
            end)

            connections[#connections + 1] = create_connection(option_button.MouseEnter, function()
                option_frame.BackgroundColor3 = color_from_rgb(40, 40, 40)
            end)

            connections[#connections + 1] = create_connection(option_button.MouseLeave, function()
                option_frame.BackgroundColor3 = color_from_rgb(35, 35, 35)
            end)

            open_items[#open_items + 1] = {index, option_label, option_frame, option_button}
        end

        function dropdown.Content:Close()
            dropdown.Content.Open = false
            outline_frame.BackgroundColor3 = color_from_rgb(36, 36, 36)
            for _, connection in pairs(connections) do
                connection:Disconnect()
            end
            if input_check then
                input_check:Disconnect()
            end
            for _, item in pairs(open_items) do
                item[2]:Remove()
                item[3]:Remove()
                item[4]:Remove()
            end
            open_holder:Remove()
            open_outline:Remove()
            open_frame:Remove()
            input_check = nil
            connections = nil
            open_items = nil
        end

        function dropdown.Content:Refresh()
            for _, item in pairs(open_items) do
                item[2].TextColor3 = item[1] == dropdown.State and dropdown.Window.Accent or color_from_rgb(205, 205, 205)
            end
        end

        dropdown.Content.Open = true
        dropdown.Section.Content = dropdown.Content
        outline_frame.BackgroundColor3 = color_from_rgb(46, 46, 46)

        task.wait()

        input_check = create_connection(input_service.InputBegan, function(input)
            if dropdown.Content.Open and input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mouse = mouse_location()
                local inside = false
                for _, item in pairs(open_items) do
                    local option_button = item[4]
                    if mouse.X >= option_button.AbsolutePosition.X and mouse.Y >= option_button.AbsolutePosition.Y and mouse.X <= option_button.AbsolutePosition.X + option_button.AbsoluteSize.X and mouse.Y <= option_button.AbsolutePosition.Y + option_button.AbsoluteSize.Y then
                        inside = true
                        break
                    end
                end
                if not inside then
                    dropdown.Section:CloseContent()
                end
            end
        end)
    end

    create_connection(button.MouseButton1Down, function()
        if dropdown.Content.Open then
            dropdown.Section:CloseContent()
        else
            dropdown:Open()
        end
    end)

    create_connection(button.MouseEnter, function()
        outline_frame.BackgroundColor3 = color_from_rgb(46, 46, 46)
    end)

    create_connection(button.MouseLeave, function()
        outline_frame.BackgroundColor3 = dropdown.Content.Open and color_from_rgb(46, 46, 46) or color_from_rgb(36, 36, 36)
    end)

    dropdown:Set(dropdown.State)
    return dropdown
end

function library.sections:CreateMultibox(properties)
    properties = properties or {}
    local multibox = {
        Name = properties.name or properties.Name or properties.title or properties.Title or "New Multibox",
        State = properties.state or properties.State or properties.def or properties.Def or properties.default or properties.Default or {1},
        Options = properties.options or properties.Options or properties.list or properties.List or {1, 2, 3},
        Minimum = properties.min or properties.Min or properties.minimum or properties.Minimum or 0,
        Maximum = properties.max or properties.Max or properties.maximum or properties.Maximum or 1000,
        Callback = properties.callback or properties.Callback or properties.callBack or properties.CallBack or function() end,
        Content = {Open = false},
        Window = self.Window,
        Page = self.Page,
        Section = self
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = multibox.Section.Holder,
        Size = udim2_new(1, 0, 0, 39),
        ZIndex = 3
    })

    local outline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 40, 0, 15),
        Size = udim2_new(1, -98, 0, 20),
        ZIndex = 3
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 4),
        Size = udim2_new(1, -41, 0, 10),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = multibox.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 4),
        Size = udim2_new(1, -41, 0, 10),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = multibox.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextTransparency = 0.5,
        TextXAlignment = "Left"
    })

    local button = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Size = udim2_new(1, 0, 1, 0),
        Text = ""
    })

    local outline_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(36, 36, 36),
        BorderSizePixel = 0,
        Parent = outline,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 3
    })

    render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(220, 220, 220)),
        Rotation = 270,
        Parent = outline_frame
    })

    local value_label = render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = outline_frame,
        Position = udim2_new(0, 8, 0, 0),
        Size = udim2_new(1, 0, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = "",
        TextColor3 = color_from_rgb(155, 155, 155),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    render_object("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = outline_frame,
        Position = udim2_new(1, -11, 0.5, -4),
        Size = udim2_new(0, 7, 0, 6),
        Image = "rbxassetid://8532000591",
        ImageColor3 = color_from_rgb(255, 255, 255),
        ZIndex = 3
    })

    function multibox:Set(state)
        table.sort(state)
        multibox.State = state
        local serialised = serialise_list(sort_options(multibox:Get(), multibox.Options))
        value_label.Text = serialised == "" and "-" or serialised
        multibox.Callback(multibox:Get())
        if multibox.Content.Open then
            multibox.Content:Refresh()
        end
    end

    function multibox:Get()
        return multibox.State
    end

    function multibox:Open()
        multibox.Section:CloseContent()
        local open_items = {}
        local connections = {}
        local input_check
        local open_holder = render_object("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = multibox.Section.Extra,
            Position = udim2_new(0, outline.AbsolutePosition.X - multibox.Section.Extra.AbsolutePosition.X, 0, outline.AbsolutePosition.Y - multibox.Section.Extra.AbsolutePosition.Y + 21),
            Size = udim2_new(1, -98, 0, (18 * #multibox.Options) + 2),
            ZIndex = 6
        })

        local open_outline = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(12, 12, 12),
            BorderSizePixel = 0,
            Parent = open_holder,
            Size = udim2_new(1, 0, 1, 0),
            ZIndex = 6
        })

        local open_frame = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(21, 21, 21),
            BorderSizePixel = 0,
            Parent = open_outline,
            Position = udim2_new(0, 1, 0, 1),
            Size = udim2_new(1, -2, 1, -2),
            ZIndex = 6
        })

        for index, option in pairs(multibox.Options) do
            local option_frame = render_object("Frame", {
                BackgroundColor3 = color_from_rgb(35, 35, 35),
                BorderSizePixel = 0,
                Parent = open_frame,
                Position = udim2_new(0, 0, 0, 18 * (index - 1)),
                Size = udim2_new(1, 0, 1 / #multibox.Options, 0),
                ZIndex = 6
            })

            local option_label = render_object("TextLabel", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = option_frame,
                Position = udim2_new(0, 8, 0, 0),
                Size = udim2_new(1, 0, 1, 0),
                ZIndex = 6,
                Font = "Code",
                RichText = true,
                Text = tostring(option),
                TextColor3 = table.find(multibox.State, index) and multibox.Window.Accent or color_from_rgb(205, 205, 205),
                TextSize = 9,
                TextStrokeTransparency = 1,
                TextXAlignment = "Left"
            })

            local option_button = render_object("TextButton", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = option_frame,
                Size = udim2_new(1, 0, 1, 0),
                Text = "",
                ZIndex = 6
            })

            connections[#connections + 1] = create_connection(option_button.MouseButton1Click, function()
                local new_table = multibox:Get()
                if table.find(new_table, index) then
                    if #new_table - 1 >= multibox.Minimum then
                        table.remove(new_table, table.find(new_table, index))
                    end
                else
                    if #new_table + 1 <= multibox.Maximum then
                        table.insert(new_table, index)
                    end
                end
                multibox:Set(new_table)
            end)

            connections[#connections + 1] = create_connection(option_button.MouseEnter, function()
                option_frame.BackgroundColor3 = color_from_rgb(40, 40, 40)
            end)

            connections[#connections + 1] = create_connection(option_button.MouseLeave, function()
                option_frame.BackgroundColor3 = color_from_rgb(35, 35, 35)
            end)

            open_items[#open_items + 1] = {index, option_label, option_frame, option_button}
        end

        function multibox.Content:Close()
            multibox.Content.Open = false
            outline_frame.BackgroundColor3 = color_from_rgb(36, 36, 36)
            for _, connection in pairs(connections) do
                connection:Disconnect()
            end
            if input_check then
                input_check:Disconnect()
            end
            for _, item in pairs(open_items) do
                item[2]:Remove()
                item[3]:Remove()
                item[4]:Remove()
            end
            open_holder:Remove()
            open_outline:Remove()
            open_frame:Remove()
            input_check = nil
            connections = nil
            open_items = nil
        end

        function multibox.Content:Refresh()
            for _, item in pairs(open_items) do
                item[2].TextColor3 = table.find(multibox.State, item[1]) and multibox.Window.Accent or color_from_rgb(205, 205, 205)
            end
        end

        multibox.Content.Open = true
        multibox.Section.Content = multibox.Content
        outline_frame.BackgroundColor3 = color_from_rgb(46, 46, 46)

        task.wait()

        input_check = create_connection(input_service.InputBegan, function(input)
            if multibox.Content.Open and input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mouse = mouse_location()
                local inside = false
                for _, item in pairs(open_items) do
                    local option_button = item[4]
                    if mouse.X >= option_button.AbsolutePosition.X and mouse.Y >= option_button.AbsolutePosition.Y and mouse.X <= option_button.AbsolutePosition.X + option_button.AbsoluteSize.X and mouse.Y <= option_button.AbsolutePosition.Y + option_button.AbsoluteSize.Y then
                        inside = true
                        break
                    end
                end
                if not inside then
                    multibox.Section:CloseContent()
                end
            end
        end)
    end

    create_connection(button.MouseButton1Down, function()
        if multibox.Content.Open then
            multibox.Section:CloseContent()
        else
            multibox:Open()
        end
    end)

    create_connection(button.MouseEnter, function()
        outline_frame.BackgroundColor3 = color_from_rgb(46, 46, 46)
    end)

    create_connection(button.MouseLeave, function()
        outline_frame.BackgroundColor3 = multibox.Content.Open and color_from_rgb(46, 46, 46) or color_from_rgb(36, 36, 36)
    end)

    multibox:Set(multibox.State)
    return multibox
end

function library.sections:CreateKeybind(properties)
    properties = properties or {}
    local keybind = {
        Name = properties.name or properties.Name or properties.title or properties.Title or "New Keybind",
        State = properties.state or properties.State or properties.def or properties.Def or properties.default or properties.Default or nil,
        Mode = properties.mode or properties.Mode or "Hold",
        Callback = properties.callback or properties.Callback or properties.callBack or properties.CallBack or function() end,
        Active = false,
        Holding = false,
        Window = self.Window,
        Page = self.Page,
        Section = self
    }

    local valid_keys = {
        KeyCodes = {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Z", "X", "C", "V", "B", "N", "M", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero", "Insert", "Tab", "Home", "End", "LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift", "CapsLock"},
        Inputs = {"MouseButton1", "MouseButton2", "MouseButton3"},
        Shortened = {["MouseButton1"] = "M1", ["MouseButton2"] = "M2", ["MouseButton3"] = "M3", ["Insert"] = "INS", ["LeftAlt"] = "LA", ["LeftControl"] = "LC", ["LeftShift"] = "LS", ["RightAlt"] = "RA", ["RightControl"] = "RC", ["RightShift"] = "RS", ["CapsLock"] = "CL"}
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = keybind.Section.Holder,
        Size = udim2_new(1, 0, 0, 18),
        ZIndex = 3
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 0),
        Size = udim2_new(1, -41, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = keybind.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 0),
        Size = udim2_new(1, -41, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = keybind.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextTransparency = 0.5,
        TextXAlignment = "Left"
    })

    local button = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Size = udim2_new(1, 0, 1, 0),
        Text = ""
    })

    local value_label = render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 0),
        Size = udim2_new(1, -61, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = "",
        TextColor3 = color_from_rgb(114, 114, 114),
        TextStrokeColor3 = color_from_rgb(15, 15, 15),
        TextSize = 9,
        TextStrokeTransparency = 0,
        TextXAlignment = "Right"
    })

    function keybind:Set(state)
        keybind.State = state or {}
        keybind.Active = false
        local current = keybind:Get()
        value_label.Text = "[" .. (#current > 0 and keybind:Shorten(current[2]) or "-") .. "]"
        keybind.Callback(keybind:Get())
    end

    function keybind:Get()
        return keybind.State
    end

    function keybind:Shorten(str)
        for index, value in pairs(valid_keys.Shortened) do
            str = string.gsub(str, index, value)
        end
        return str
    end

    function keybind:Change(key)
        if not key.EnumType then
            return false
        end
        if key.EnumType ~= Enum.KeyCode and key.EnumType ~= Enum.UserInputType then
            return false
        end
        if not table.find(valid_keys.KeyCodes, key.Name) and not table.find(valid_keys.Inputs, key.Name) then
            return false
        end
        keybind:Set({key.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType", key.Name})
        return true
    end

    create_connection(button.MouseButton1Click, function()
        keybind.Holding = true
        value_label.TextColor3 = color_from_rgb(255, 0, 0)
    end)

    create_connection(button.MouseButton2Click, function()
        keybind:Set()
    end)

    create_connection(button.MouseEnter, function()
        value_label.TextColor3 = color_from_rgb(164, 164, 164)
    end)

    create_connection(button.MouseLeave, function()
        value_label.TextColor3 = keybind.Holding and color_from_rgb(255, 0, 0) or color_from_rgb(114, 114, 114)
    end)

    create_connection(input_service.InputBegan, function(input)
        if keybind.Holding then
            local key = input.KeyCode.Name ~= "Unknown" and input.KeyCode or input.UserInputType
            if keybind:Change(key) then
                keybind.Holding = false
                value_label.TextColor3 = color_from_rgb(114, 114, 114)
            end
        end
        local current = keybind:Get()
        if current[1] and current[2] then
            if input.KeyCode == Enum[current[1]][current[2]] or input.UserInputType == Enum[current[1]][current[2]] then
                if keybind.Mode == "Hold" then
                    keybind.Active = true
                elseif keybind.Mode == "Toggle" then
                    keybind.Active = not keybind.Active
                end
            end
        end
    end)

    create_connection(input_service.InputEnded, function(input)
        local current = keybind:Get()
        if current[1] and current[2] then
            if input.KeyCode == Enum[current[1]][current[2]] or input.UserInputType == Enum[current[1]][current[2]] then
                if keybind.Mode == "Hold" then
                    keybind.Active = false
                end
            end
        end
    end)

    keybind:Set(keybind.State)
    return keybind
end

function library.sections:CreateButton(properties)
    properties = properties or {}
    local button = {
        Name = properties.name or properties.Name or properties.text or properties.Text or "Button",
        Callback = properties.callback or properties.Callback or function() end,
        Window = self.Window,
        Page = self.Page,
        Section = self
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = button.Section.Holder,
        Size = udim2_new(1, 0, 0, 28),
        ZIndex = 3
    })

    local outline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 40, 0, 5),
        Size = udim2_new(1, -80, 0, 18),
        ZIndex = 3
    })

    local frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(36, 36, 36),
        BorderSizePixel = 0,
        Parent = outline,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 3
    })

    render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(200, 200, 200)),
        Rotation = 90,
        Parent = frame
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        Font = "Code",
        Text = button.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextXAlignment = "Center",
        Size = udim2_new(1, 0, 1, 0),
        ZIndex = 4,
        Parent = frame
    })

    local click = render_object("TextButton", {
        BackgroundTransparency = 1,
        Size = udim2_new(1, 0, 1, 0),
        ZIndex = 5,
        Text = "",
        Parent = holder
    })

    local tween_info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween_press = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    function button:Set(text)
        frame.TextLabel.Text = text or button.Name
    end

    create_connection(click.MouseEnter, function()
        tween_service:Create(frame, tween_info, {BackgroundColor3 = color_from_rgb(46, 46, 46)}):Play()
    end)

    create_connection(click.MouseLeave, function()
        tween_service:Create(frame, tween_info, {BackgroundColor3 = color_from_rgb(36, 36, 36)}):Play()
    end)

    create_connection(click.MouseButton1Down, function()
        tween_service:Create(frame, tween_press, {BackgroundColor3 = color_from_rgb(26, 26, 26)}):Play()
    end)

    create_connection(click.MouseButton1Click, function()
        button.Callback()
        tween_service:Create(frame, tween_info, {BackgroundColor3 = color_from_rgb(46, 46, 46)}):Play()
    end)

    return button
end

function library.sections:CreateColorpicker(properties)
    properties = properties or {}
    local colorpicker = {
        Name = properties.name or properties.Name or properties.title or properties.Title or "New Colorpicker",
        State = properties.state or properties.State or properties.def or properties.Def or properties.default or properties.Default or color_from_rgb(255, 255, 255),
        Callback = properties.callback or properties.Callback or properties.callBack or properties.CallBack or function() end,
        Content = {Open = false},
        Window = self.Window,
        Page = self.Page,
        Section = self,
        Hue = 0,
        Saturation = 1,
        Value = 1,
        Alpha = 1
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = colorpicker.Section.Holder,
        Size = udim2_new(1, 0, 0, 18),
        ZIndex = 3
    })

    local outline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(1, -38, 0, 4),
        Size = udim2_new(0, 17, 0, 9),
        ZIndex = 3
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 0),
        Size = udim2_new(1, -41, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = colorpicker.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 41, 0, 0),
        Size = udim2_new(1, -41, 1, 0),
        ZIndex = 3,
        Font = "Code",
        RichText = true,
        Text = colorpicker.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextTransparency = 0.5,
        TextXAlignment = "Left"
    })

    local button = render_object("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
        Size = udim2_new(1, 0, 1, 0),
        Text = ""
    })

    local outline_frame = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(255, 255, 255),
        BorderSizePixel = 0,
        Parent = outline,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 3
    })

    local outline_gradient = render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(140, 140, 140)),
        Rotation = 90,
        Parent = outline_frame
    })

    function colorpicker:Set(state)
        colorpicker.State = state
        outline_frame.BackgroundColor3 = state
        colorpicker.Callback(colorpicker:Get())
    end

    function colorpicker:Get()
        return colorpicker.State
    end

    function colorpicker:Open()
        colorpicker.Section:CloseContent()
        local connections = {}
        local input_check
        local sliding_palette = false
        local sliding_hue = false
        local sliding_alpha = false

        colorpicker.Hue, colorpicker.Saturation, colorpicker.Value = colorpicker.State:ToHSV()

        local open_holder = render_object("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = colorpicker.Section.Extra,
            Position = udim2_new(0, outline.AbsolutePosition.X - colorpicker.Section.Extra.AbsolutePosition.X, 0, outline.AbsolutePosition.Y - colorpicker.Section.Extra.AbsolutePosition.Y + 10),
            Size = udim2_new(0, 180, 0, 175),
            ZIndex = 6
        })

        local open_outline = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(60, 60, 60),
            BorderColor3 = color_from_rgb(12, 12, 12),
            BorderMode = "Inset",
            BorderSizePixel = 1,
            Parent = open_holder,
            Size = udim2_new(1, 0, 1, 0),
            ZIndex = 6
        })

        local open_frame = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(40, 40, 40),
            BorderSizePixel = 0,
            Parent = open_outline,
            Position = udim2_new(0, 1, 0, 1),
            Size = udim2_new(1, -2, 1, -2),
            ZIndex = 6
        })

        local palette_outline = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(12, 12, 12),
            BorderSizePixel = 0,
            Parent = open_frame,
            Position = udim2_new(0, 2, 0, 2),
            Size = udim2_new(0, 152, 0, 152),
            ZIndex = 6
        })

        local hue_outline = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(12, 12, 12),
            BorderSizePixel = 0,
            Parent = open_frame,
            Position = udim2_new(1, -19, 0, 2),
            Size = udim2_new(0, 17, 0, 152),
            ZIndex = 6
        })

        local alpha_outline = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(12, 12, 12),
            BorderSizePixel = 0,
            Parent = open_frame,
            Position = udim2_new(0, 2, 1, -14),
            Size = udim2_new(0, 152, 0, 12),
            ZIndex = 6
        })

        local palette_color = render_object("Frame", {
            BackgroundColor3 = color_from_hsv(colorpicker.Hue, 1, 1),
            BorderSizePixel = 0,
            Parent = palette_outline,
            Position = udim2_new(0, 1, 0, 1),
            Size = udim2_new(1, -2, 1, -2),
            ZIndex = 6
        })

        local saturation_gradient = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(255, 255, 255),
            BorderSizePixel = 0,
            Parent = palette_color,
            Size = udim2_new(1, 0, 1, 0),
            ZIndex = 7
        })

        render_object("UIGradient", {
            Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(255, 255, 255)),
            Transparency = number_sequence_new{number_sequence_keypoint_new(0, 0), number_sequence_keypoint_new(1, 1)},
            Parent = saturation_gradient
        })

        local value_gradient = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(0, 0, 0),
            BorderSizePixel = 0,
            Parent = palette_color,
            Size = udim2_new(1, 0, 1, 0),
            ZIndex = 8
        })

        render_object("UIGradient", {
            Color = color_sequence_new(color_from_rgb(0, 0, 0), color_from_rgb(0, 0, 0)),
            Transparency = number_sequence_new{number_sequence_keypoint_new(0, 1), number_sequence_keypoint_new(1, 0)},
            Rotation = 90,
            Parent = value_gradient
        })

        local palette_dragger = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(255, 255, 255),
            BorderColor3 = color_from_rgb(0, 0, 0),
            BorderSizePixel = 1,
            Parent = palette_color,
            Position = udim2_new(colorpicker.Saturation, -2, 1 - colorpicker.Value, -2),
            Size = udim2_new(0, 4, 0, 4),
            ZIndex = 10
        })

        local hue_color = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(255, 255, 255),
            BorderSizePixel = 0,
            Parent = hue_outline,
            Position = udim2_new(0, 1, 0, 1),
            Size = udim2_new(1, -2, 1, -2),
            ZIndex = 6
        })

        render_object("UIGradient", {
            Color = color_sequence_new{
                color_sequence_keypoint_new(0, color_from_rgb(255, 0, 0)),
                color_sequence_keypoint_new(0.17, color_from_rgb(255, 255, 0)),
                color_sequence_keypoint_new(0.33, color_from_rgb(0, 255, 0)),
                color_sequence_keypoint_new(0.5, color_from_rgb(0, 255, 255)),
                color_sequence_keypoint_new(0.67, color_from_rgb(0, 0, 255)),
                color_sequence_keypoint_new(0.83, color_from_rgb(255, 0, 255)),
                color_sequence_keypoint_new(1, color_from_rgb(255, 0, 0))
            },
            Rotation = 90,
            Parent = hue_color
        })

        local hue_dragger = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(255, 255, 255),
            BorderColor3 = color_from_rgb(0, 0, 0),
            BorderSizePixel = 1,
            Parent = hue_color,
            Position = udim2_new(0, -1, colorpicker.Hue, -2),
            Size = udim2_new(1, 2, 0, 4),
            ZIndex = 10
        })

        local alpha_color = render_object("Frame", {
            BackgroundColor3 = colorpicker.State,
            BorderSizePixel = 0,
            Parent = alpha_outline,
            Position = udim2_new(0, 1, 0, 1),
            Size = udim2_new(1, -2, 1, -2),
            ZIndex = 6
        })

        render_object("UIGradient", {
            Transparency = number_sequence_new{number_sequence_keypoint_new(0, 0), number_sequence_keypoint_new(1, 1)},
            Parent = alpha_color
        })

        local alpha_dragger = render_object("Frame", {
            BackgroundColor3 = color_from_rgb(255, 255, 255),
            BorderColor3 = color_from_rgb(0, 0, 0),
            BorderSizePixel = 1,
            Parent = alpha_color,
            Position = udim2_new(colorpicker.Alpha, -2, 0, -1),
            Size = udim2_new(0, 4, 1, 2),
            ZIndex = 10
        })

        local function update_color()
            local new_color = color_from_hsv(colorpicker.Hue, colorpicker.Saturation, colorpicker.Value)
            colorpicker.State = new_color
            outline_frame.BackgroundColor3 = new_color
            palette_color.BackgroundColor3 = color_from_hsv(colorpicker.Hue, 1, 1)
            alpha_color.BackgroundColor3 = new_color
            colorpicker.Callback(new_color)
        end

        function colorpicker.Content:Close()
            colorpicker.Content.Open = false
            for _, connection in pairs(connections) do
                connection:Disconnect()
            end
            if input_check then
                input_check:Disconnect()
            end
            open_holder:Remove()
            input_check = nil
            connections = nil
        end

        function colorpicker.Content:Refresh() end

        palette_dragger.Position = udim2_new(colorpicker.Saturation, -2, 1 - colorpicker.Value, -2)
        hue_dragger.Position = udim2_new(0, -1, colorpicker.Hue, -2)
        alpha_dragger.Position = udim2_new(colorpicker.Alpha, -2, 0, -1)

        update_color()

        colorpicker.Content.Open = true
        colorpicker.Section.Content = colorpicker.Content

        connections[#connections + 1] = create_connection(palette_color.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            sliding_palette = true
            local relative_x = math.clamp((input.Position.X - palette_color.AbsolutePosition.X) / palette_color.AbsoluteSize.X, 0, 1)
            local relative_y = math.clamp((input.Position.Y - palette_color.AbsolutePosition.Y) / palette_color.AbsoluteSize.Y, 0, 1)
            colorpicker.Saturation = relative_x
            colorpicker.Value = 1 - relative_y
            palette_dragger.Position = udim2_new(relative_x, -2, relative_y, -2)
            update_color()
        end)

        connections[#connections + 1] = create_connection(hue_color.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            sliding_hue = true
            local relative_y = math.clamp((input.Position.Y - hue_color.AbsolutePosition.Y) / hue_color.AbsoluteSize.Y, 0, 1)
            colorpicker.Hue = relative_y
            hue_dragger.Position = udim2_new(0, -1, relative_y, -2)
            update_color()
        end)

        connections[#connections + 1] = create_connection(alpha_color.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            sliding_alpha = true
            local relative_x = math.clamp((input.Position.X - alpha_color.AbsolutePosition.X) / alpha_color.AbsoluteSize.X, 0, 1)
            colorpicker.Alpha = relative_x
            alpha_dragger.Position = udim2_new(relative_x, -2, 0, -1)
        end)

        connections[#connections + 1] = create_connection(input_service.InputChanged, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end
            if sliding_palette then
                local relative_x = math.clamp((input.Position.X - palette_color.AbsolutePosition.X) / palette_color.AbsoluteSize.X, 0, 1)
                local relative_y = math.clamp((input.Position.Y - palette_color.AbsolutePosition.Y) / palette_color.AbsoluteSize.Y, 0, 1)
                colorpicker.Saturation = relative_x
                colorpicker.Value = 1 - relative_y
                palette_dragger.Position = udim2_new(relative_x, -2, relative_y, -2)
                update_color()
            elseif sliding_hue then
                local relative_y = math.clamp((input.Position.Y - hue_color.AbsolutePosition.Y) / hue_color.AbsoluteSize.Y, 0, 1)
                colorpicker.Hue = relative_y
                hue_dragger.Position = udim2_new(0, -1, relative_y, -2)
                update_color()
            elseif sliding_alpha then
                local relative_x = math.clamp((input.Position.X - alpha_color.AbsolutePosition.X) / alpha_color.AbsoluteSize.X, 0, 1)
                colorpicker.Alpha = relative_x
                alpha_dragger.Position = udim2_new(relative_x, -2, 0, -1)
            end
        end)

        connections[#connections + 1] = create_connection(input_service.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                sliding_palette = false
                sliding_hue = false
                sliding_alpha = false
            end
        end)

        input_check = create_connection(input_service.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            if is_mouse_over_frame(open_holder) then
                return
            end
            colorpicker.Section:CloseContent()
        end)
    end

    create_connection(button.MouseButton1Click, function()
        if colorpicker.Content.Open then
            colorpicker.Section:CloseContent()
        else
            colorpicker:Open()
        end
    end)

    create_connection(button.MouseEnter, function()
        outline_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(180, 180, 180))
    end)

    create_connection(button.MouseLeave, function()
        outline_gradient.Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(140, 140, 140))
    end)

    colorpicker:Set(colorpicker.State)
    return colorpicker
end

return library
