local library = {}
library.__index = library

local tween_service = game:GetService("TweenService")
local input_service = game:GetService("UserInputService")
local core_gui = game:GetService("CoreGui")
local run_service = game:GetService("RunService")

local color_from_rgb = Color3.fromRGB
local color_from_hsv = Color3.fromHSV
local udim2_new = UDim2.new
local vector2_new = Vector2.new
local color_sequence_new = ColorSequence.new
local number_sequence_new = NumberSequence.new
local number_sequence_keypoint_new = NumberSequenceKeypoint.new
local color_sequence_keypoint_new = ColorSequenceKeypoint.new
local tween_info_new = TweenInfo.new

local icons = {
    rage = "rbxassetid://8547236654",
    aimbot = "rbxassetid://8547249956",
    visuals = "rbxassetid://8547254518",
    settings = "rbxassetid://8547256547",
    skins = "rbxassetid://8547258459",
    config = "rbxassetid://8547269749"
}

library.icons = icons
library.renders = {}
library.connections = {}
library.accent_objects = {}

local function render_object(render_type, properties)
    local instance = Instance.new(render_type)
    if properties then
        for property, value in pairs(properties) do
            instance[property] = value
        end
    end
    library.renders[#library.renders + 1] = instance
    return instance
end

local function create_connection(signal, callback)
    local connection = signal:Connect(callback)
    library.connections[#library.connections + 1] = connection
    return connection
end

local function register_accent(object, property)
    library.accent_objects[#library.accent_objects + 1] = {object, property}
end

local function make_draggable(frame, handle)
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

local function round_to_step(value, step)
    return math.floor(value / step + 0.5) * step
end

function library:set_accent(color)
    self.Accent = color
    for _, entry in pairs(library.accent_objects) do
        entry[1][entry[2]] = color
    end
end

function library:CreateWindow(properties)
    properties = properties or {}
    local window = {
        Pages = {},
        Accent = properties.accent or properties.Accent or color_from_rgb(255, 120, 30),
        Enabled = true,
        Key = properties.key or properties.Key or Enum.KeyCode.Insert
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

    render_object("Frame", {
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
        for _, instance in pairs(library.renders) do
            if instance.ClassName == "Frame" or instance.ClassName == "ImageLabel" or instance.ClassName == "TextLabel" or instance.ClassName == "ScrollingFrame" then
                pcall(function()
                    local info = tween_info_new(0.25, Enum.EasingStyle.Linear, state and Enum.EasingDirection.Out or Enum.EasingDirection.In)
                    if instance:FindFirstChildOfClass("UIGradient") == nil then
                        tween_service:Create(instance, info, {BackgroundTransparency = state and 0 or 1}):Play()
                    end
                end)
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

    window:set_accent(window.Accent)

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
        Padding = UDim.new(0, 12),
        Parent = page_left,
        FillDirection = "Vertical",
        HorizontalAlignment = "Left",
        VerticalAlignment = "Top"
    })

    render_object("UIListLayout", {
        Padding = UDim.new(0, 12),
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

    function page:section(properties)
        return page:_CreateSection(properties)
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

library.pages = {}
library.pages.__index = library.pages

function library.pages:_CreateSection(properties)
    properties = properties or {}
    local section = {
        Name = properties.name or properties.Name or "New Section",
        Side = properties.side or properties.Side or "Left",
        Width = properties.width or properties.Width or 1,
        Window = self.Window,
        Page = self
    }

    local holder = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(40, 40, 40),
        BorderColor3 = color_from_rgb(12, 12, 12),
        BorderMode = "Inset",
        BorderSizePixel = 1,
        Parent = section.Page[section.Side],
        Size = udim2_new(section.Width, 0, 0, 100),
        AutomaticSize = "Y",
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

    local content_holder = render_object("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder_frame,
        Position = udim2_new(0, 0, 0, 0),
        Size = udim2_new(1, 0, 1, -2),
        ZIndex = 4,
        AutomaticCanvasSize = "Y",
        CanvasSize = udim2_new(0, 0, 0, 0),
        ScrollBarImageColor3 = color_from_rgb(65, 65, 65),
        ScrollBarImageTransparency = 0,
        ScrollBarThickness = 5,
        VerticalScrollBarInset = "None"
    })

    render_object("UIListLayout", {
        Padding = UDim.new(0, 4),
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

    task.defer(function()
        title_inline.Size = udim2_new(0, title.TextBounds.X + 6, 0, 2)
    end)

    section["Holder"] = content_holder
    section["Extra"] = extra

    function section:CloseContent()
        if section.Content and section.Content.Open then
            section.Content:Close()
            section.Content = {}
        end
    end

    return setmetatable(section, library.sections)
end

library.sections = {}
library.sections.__index = library.sections

function library.sections:checkbox(properties)
    if type(properties) == "string" then
        properties = {name = properties, state = false, callback = function() end}
    end
    local checkbox = {
        Name = properties.name or properties.Name or "New Checkbox",
        State = properties.state or properties.State or false,
        Callback = properties.callback or properties.Callback or function() end,
        Window = self.Window
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
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
        Text = checkbox.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
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

    render_object("UIGradient", {
        Color = color_sequence_new(color_from_rgb(255, 255, 255), color_from_rgb(140, 140, 140)),
        Rotation = 90,
        Parent = outline_frame
    })

    register_accent(outline_frame, "BackgroundColor3")

    function checkbox:set(state)
        checkbox.State = state
        outline_frame.BackgroundColor3 = state and checkbox.Window.Accent or color_from_rgb(77, 77, 77)
        checkbox.Callback(checkbox.State)
    end

    function checkbox:get()
        return checkbox.State
    end

    create_connection(button.MouseButton1Click, function()
        checkbox:set(not checkbox:get())
    end)

    checkbox:set(checkbox.State)
    return checkbox
end

function library.sections:slider(properties)
    if type(properties) == "string" then
        properties = {name = properties}
    end
    local slider = {
        Name = properties.name or properties.Name or nil,
        State = properties.state or properties.State or 0,
        Min = properties.min or properties.Min or 0,
        Max = properties.max or properties.Max or 100,
        Suffix = properties.suffix or properties.Suffix or "",
        Decimals = properties.decimals or properties.Decimals or 1,
        Callback = properties.callback or properties.Callback or function() end,
        Holding = false,
        Window = self.Window
    }
    slider.Step = 1 / slider.Decimals

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
        Size = udim2_new(1, 0, 0, (slider.Name and 24 or 13) + 5),
        ZIndex = 3
    })

    local minus_button = render_object("TextButton", {
        BackgroundColor3 = color_from_rgb(30, 30, 30),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 20, 0, slider.Name and 18 or 5),
        Size = udim2_new(0, 14, 0, 10),
        Text = "−",
        TextColor3 = color_from_rgb(180, 180, 180),
        TextSize = 12,
        Font = "Code",
        ZIndex = 3
    })

    local plus_button = render_object("TextButton", {
        BackgroundColor3 = color_from_rgb(30, 30, 30),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(1, -34, 0, slider.Name and 18 or 5),
        Size = udim2_new(0, 14, 0, 10),
        Text = "+",
        TextColor3 = color_from_rgb(180, 180, 180),
        TextSize = 12,
        Font = "Code",
        ZIndex = 3
    })

    local outline = render_object("Frame", {
        BackgroundColor3 = color_from_rgb(12, 12, 12),
        BorderSizePixel = 0,
        Parent = holder,
        Position = udim2_new(0, 40, 0, slider.Name and 18 or 5),
        Size = udim2_new(1, -99, 0, 10),
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
            Text = slider.Name,
            TextColor3 = color_from_rgb(205, 205, 205),
            TextSize = 9,
            TextStrokeTransparency = 1,
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

    register_accent(fill, "BackgroundColor3")

    local value_label = render_object("TextLabel", {
        AnchorPoint = vector2_new(0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = fill,
        Position = udim2_new(1, 0, 0.5, 1),
        Size = udim2_new(0, 2, 1, 0),
        ZIndex = 3,
        Font = "Code",
        Text = "",
        TextColor3 = color_from_rgb(255, 255, 255),
        TextSize = 11,
        TextStrokeTransparency = 0.5,
        TextXAlignment = "Center"
    })

    function slider:set(state)
        slider.State = math.clamp(round_to_step(state, slider.Step), slider.Min, slider.Max)
        value_label.Text = tostring(slider.State) .. slider.Suffix
        local ratio = (slider.State - slider.Min) / (slider.Max - slider.Min)
        fill.Size = udim2_new(ratio, 0, 1, 0)
        slider.Callback(slider.State)
    end

    function slider:get()
        return slider.State
    end

    function slider:refresh()
        local mouse = mouse_location()
        local relative_x = math.clamp(mouse.X - fill.AbsolutePosition.X, 0, outline_frame.AbsoluteSize.X) / outline_frame.AbsoluteSize.X
        slider:set(slider.Min + (slider.Max - slider.Min) * relative_x)
    end

    create_connection(minus_button.MouseButton1Click, function()
        slider:set(slider.State - slider.Step)
    end)

    create_connection(plus_button.MouseButton1Click, function()
        slider:set(slider.State + slider.Step)
    end)

    create_connection(button.MouseButton1Down, function()
        slider:refresh()
        slider.Holding = true
    end)

    create_connection(input_service.InputChanged, function(input)
        if slider.Holding and input.UserInputType == Enum.UserInputType.MouseMovement then
            slider:refresh()
        end
    end)

    create_connection(input_service.InputEnded, function(input)
        if slider.Holding and input.UserInputType == Enum.UserInputType.MouseButton1 then
            slider.Holding = false
        end
    end)

    slider:set(slider.State)
    return slider
end

function library.sections:dropdown(properties)
    if type(properties) == "string" then
        properties = {name = properties}
    end
    local dropdown = {
        Name = properties.name or properties.Name or "Dropdown",
        State = properties.state or properties.State or 1,
        Options = properties.options or properties.Options or {1, 2, 3},
        Callback = properties.callback or properties.Callback or function() end,
        Content = {Open = false},
        Window = self.Window
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
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
        Text = dropdown.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
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

    local value_label = render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = outline_frame,
        Position = udim2_new(0, 8, 0, 0),
        Size = udim2_new(1, 0, 1, 0),
        ZIndex = 3,
        Font = "Code",
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

    function dropdown:set(state)
        dropdown.State = state
        value_label.Text = tostring(dropdown.Options[state])
        dropdown.Callback(dropdown.State)
    end

    function dropdown:get()
        return dropdown.State
    end

    function dropdown:open()
        if self.Page then
            self.Page:CloseContent()
        end
        if dropdown.Section then
            dropdown.Section:CloseContent()
        end

        local open_holder = render_object("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = self.Extra,
            Position = udim2_new(0, outline.AbsolutePosition.X - self.Extra.AbsolutePosition.X, 0, outline.AbsolutePosition.Y - self.Extra.AbsolutePosition.Y + 21),
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

        local open_items = {}
        local connections = {}

        for index, option in pairs(dropdown.Options) do
            local option_frame = render_object("Frame", {
                BackgroundColor3 = color_from_rgb(35, 35, 35),
                BorderSizePixel = 0,
                Parent = open_frame,
                Position = udim2_new(0, 0, 0, 18 * (index - 1)),
                Size = udim2_new(1, 0, 0, 18),
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
                dropdown:set(index)
                dropdown.Content:Close()
            end)

            connections[#connections + 1] = create_connection(option_button.MouseEnter, function()
                option_frame.BackgroundColor3 = color_from_rgb(45, 45, 45)
            end)

            connections[#connections + 1] = create_connection(option_button.MouseLeave, function()
                option_frame.BackgroundColor3 = color_from_rgb(35, 35, 35)
            end)

            open_items[#open_items + 1] = {index, option_label, option_frame, option_button}
        end

        function dropdown.Content:Close()
            dropdown.Content.Open = false
            for _, connection in pairs(connections) do
                connection:Disconnect()
            end
            for _, item in pairs(open_items) do
                item[3]:Remove()
            end
            open_holder:Remove()
        end

        dropdown.Content.Open = true
        self.Content = dropdown.Content
    end

    create_connection(button.MouseButton1Click, function()
        if dropdown.Content.Open then
            dropdown.Content:Close()
        else
            dropdown:open()
        end
    end)

    dropdown:set(dropdown.State)
    return dropdown
end

function library.sections:multibox(properties)
    if type(properties) == "string" then
        properties = {name = properties}
    end
    local multibox = {
        Name = properties.name or properties.Name or "Multibox",
        State = properties.state or properties.State or {1},
        Options = properties.options or properties.Options or {1, 2, 3},
        Minimum = properties.min or properties.Min or 0,
        Maximum = properties.max or properties.Max or 1000,
        Callback = properties.callback or properties.Callback or function() end,
        Content = {Open = false},
        Window = self.Window
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
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
        Text = multibox.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
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

    local value_label = render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = outline_frame,
        Position = udim2_new(0, 8, 0, 0),
        Size = udim2_new(1, 0, 1, 0),
        ZIndex = 3,
        Font = "Code",
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

    function multibox:set(state)
        table.sort(state)
        multibox.State = state
        local serialised = serialise_list(sort_options(multibox.State, multibox.Options))
        value_label.Text = serialised == "" and "-" or serialised
        multibox.Callback(multibox.State)
    end

    function multibox:get()
        return multibox.State
    end

    function multibox:open()
        if self.Section then
            self.Section:CloseContent()
        end

        local open_holder = render_object("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = self.Extra,
            Position = udim2_new(0, outline.AbsolutePosition.X - self.Extra.AbsolutePosition.X, 0, outline.AbsolutePosition.Y - self.Extra.AbsolutePosition.Y + 21),
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

        local open_items = {}
        local connections = {}

        for index, option in pairs(multibox.Options) do
            local option_frame = render_object("Frame", {
                BackgroundColor3 = color_from_rgb(35, 35, 35),
                BorderSizePixel = 0,
                Parent = open_frame,
                Position = udim2_new(0, 0, 0, 18 * (index - 1)),
                Size = udim2_new(1, 0, 0, 18),
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
                local new_table = table.clone(multibox.State)
                if table.find(new_table, index) then
                    if #new_table - 1 >= multibox.Minimum then
                        table.remove(new_table, table.find(new_table, index))
                    end
                else
                    if #new_table + 1 <= multibox.Maximum then
                        table.insert(new_table, index)
                    end
                end
                multibox:set(new_table)
                option_label.TextColor3 = table.find(multibox.State, index) and multibox.Window.Accent or color_from_rgb(205, 205, 205)
            end)

            connections[#connections + 1] = create_connection(option_button.MouseEnter, function()
                option_frame.BackgroundColor3 = color_from_rgb(45, 45, 45)
            end)

            connections[#connections + 1] = create_connection(option_button.MouseLeave, function()
                option_frame.BackgroundColor3 = color_from_rgb(35, 35, 35)
            end)

            open_items[#open_items + 1] = {index, option_label, option_frame, option_button}
        end

        function multibox.Content:Close()
            multibox.Content.Open = false
            for _, connection in pairs(connections) do
                connection:Disconnect()
            end
            for _, item in pairs(open_items) do
                item[3]:Remove()
            end
            open_holder:Remove()
        end

        multibox.Content.Open = true
        self.Content = multibox.Content
    end

    create_connection(button.MouseButton1Click, function()
        if multibox.Content.Open then
            multibox.Content:Close()
        else
            multibox:open()
        end
    end)

    multibox:set(multibox.State)
    return multibox
end

function library.sections:keybind(properties)
    if type(properties) == "string" then
        properties = {name = properties}
    end
    local keybind = {
        Name = properties.name or properties.Name or "Keybind",
        State = properties.state or properties.State or nil,
        Mode = properties.mode or properties.Mode or "Hold",
        Callback = properties.callback or properties.Callback or function() end,
        Active = false,
        Holding = false,
        Window = self.Window
    }

    local valid_keys = {
        KeyCodes = {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Z", "X", "C", "V", "B", "N", "M", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero", "Insert", "Tab", "Home", "End", "LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift", "CapsLock"},
        Inputs = {"MouseButton1", "MouseButton2", "MouseButton3"},
        Shortened = {["MouseButton1"] = "M1", ["MouseButton2"] = "M2", ["MouseButton3"] = "M3", ["Insert"] = "INS", ["LeftAlt"] = "LA", ["LeftControl"] = "LC", ["LeftShift"] = "LS", ["RightAlt"] = "RA", ["RightControl"] = "RC", ["RightShift"] = "RS", ["CapsLock"] = "CL"}
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
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
        Text = keybind.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
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
        Text = "[ - ]",
        TextColor3 = color_from_rgb(114, 114, 114),
        TextStrokeColor3 = color_from_rgb(15, 15, 15),
        TextSize = 9,
        TextStrokeTransparency = 0,
        TextXAlignment = "Right"
    })

    function keybind:set(state)
        keybind.State = state or {}
        keybind.Active = false
        local key = keybind.State[2] or "-"
        for index, value in pairs(valid_keys.Shortened) do
            key = string.gsub(key, index, value)
        end
        value_label.Text = "[ " .. key .. " ]"
        keybind.Callback(keybind.State)
    end

    function keybind:get()
        return keybind.State
    end

    create_connection(button.MouseButton1Click, function()
        keybind.Holding = true
        value_label.TextColor3 = color_from_rgb(255, 0, 0)
    end)

    create_connection(button.MouseButton2Click, function()
        keybind:set()
    end)

    create_connection(input_service.InputBegan, function(input)
        if keybind.Holding then
            local key = input.KeyCode.Name ~= "Unknown" and input.KeyCode or input.UserInputType
            if key.EnumType == Enum.KeyCode and table.find(valid_keys.KeyCodes, key.Name) then
                keybind:set({"KeyCode", key.Name})
                keybind.Holding = false
                value_label.TextColor3 = color_from_rgb(114, 114, 114)
            elseif key.EnumType == Enum.UserInputType and table.find(valid_keys.Inputs, key.Name) then
                keybind:set({"UserInputType", key.Name})
                keybind.Holding = false
                value_label.TextColor3 = color_from_rgb(114, 114, 114)
            end
        end
    end)

    keybind:set(keybind.State)
    return keybind
end

function library.sections:button(properties)
    if type(properties) == "string" then
        properties = {name = properties}
    end
    local button = {
        Name = properties.name or properties.Name or "Button",
        Callback = properties.callback or properties.Callback or function() end,
        Window = self.Window
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
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

    create_connection(click.MouseButton1Click, function()
        button.Callback()
    end)

    return button
end

function library.sections:colorpicker(properties)
    if type(properties) == "string" then
        properties = {name = properties}
    end
    local colorpicker = {
        Name = properties.name or properties.Name or "Colorpicker",
        State = properties.state or properties.State or color_from_rgb(255, 255, 255),
        Callback = properties.callback or properties.Callback or function() end,
        Content = {Open = false},
        Window = self.Window,
        Hue = 0,
        Saturation = 1,
        Value = 1,
        Alpha = 1
    }

    local holder = render_object("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
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
        Text = colorpicker.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
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
        BackgroundColor3 = colorpicker.State,
        BorderSizePixel = 0,
        Parent = outline,
        Position = udim2_new(0, 1, 0, 1),
        Size = udim2_new(1, -2, 1, -2),
        ZIndex = 3
    })

    function colorpicker:set(state)
        colorpicker.State = state
        outline_frame.BackgroundColor3 = state
        colorpicker.Callback(colorpicker.State)
    end

    function colorpicker:get()
        return colorpicker.State
    end

    function colorpicker:open()
        if self.Section then
            self.Section:CloseContent()
        end

        local connections = {}
        local input_check
        local sliding = {palette = false, hue = false, alpha = false}

        colorpicker.Hue, colorpicker.Saturation, colorpicker.Value = colorpicker.State:ToHSV()

        local open_holder = render_object("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = self.Extra,
            Position = udim2_new(0, outline.AbsolutePosition.X - self.Extra.AbsolutePosition.X, 0, outline.AbsolutePosition.Y - self.Extra.AbsolutePosition.Y + 10),
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
        end

        colorpicker.Content.Open = true
        self.Content = colorpicker.Content

        update_color()

        connections[#connections + 1] = create_connection(palette_color.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            sliding.palette = true
            local rx = math.clamp((input.Position.X - palette_color.AbsolutePosition.X) / palette_color.AbsoluteSize.X, 0, 1)
            local ry = math.clamp((input.Position.Y - palette_color.AbsolutePosition.Y) / palette_color.AbsoluteSize.Y, 0, 1)
            colorpicker.Saturation = rx
            colorpicker.Value = 1 - ry
            palette_dragger.Position = udim2_new(rx, -2, ry, -2)
            update_color()
        end)

        connections[#connections + 1] = create_connection(hue_color.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            sliding.hue = true
            local ry = math.clamp((input.Position.Y - hue_color.AbsolutePosition.Y) / hue_color.AbsoluteSize.Y, 0, 1)
            colorpicker.Hue = ry
            hue_dragger.Position = udim2_new(0, -1, ry, -2)
            update_color()
        end)

        connections[#connections + 1] = create_connection(alpha_color.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            sliding.alpha = true
            local rx = math.clamp((input.Position.X - alpha_color.AbsolutePosition.X) / alpha_color.AbsoluteSize.X, 0, 1)
            colorpicker.Alpha = rx
            alpha_dragger.Position = udim2_new(rx, -2, 0, -1)
        end)

        connections[#connections + 1] = create_connection(input_service.InputChanged, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end
            if sliding.palette then
                local rx = math.clamp((input.Position.X - palette_color.AbsolutePosition.X) / palette_color.AbsoluteSize.X, 0, 1)
                local ry = math.clamp((input.Position.Y - palette_color.AbsolutePosition.Y) / palette_color.AbsoluteSize.Y, 0, 1)
                colorpicker.Saturation = rx
                colorpicker.Value = 1 - ry
                palette_dragger.Position = udim2_new(rx, -2, ry, -2)
                update_color()
            elseif sliding.hue then
                local ry = math.clamp((input.Position.Y - hue_color.AbsolutePosition.Y) / hue_color.AbsoluteSize.Y, 0, 1)
                colorpicker.Hue = ry
                hue_dragger.Position = udim2_new(0, -1, ry, -2)
                update_color()
            elseif sliding.alpha then
                local rx = math.clamp((input.Position.X - alpha_color.AbsolutePosition.X) / alpha_color.AbsoluteSize.X, 0, 1)
                colorpicker.Alpha = rx
                alpha_dragger.Position = udim2_new(rx, -2, 0, -1)
            end
        end)

        connections[#connections + 1] = create_connection(input_service.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                sliding.palette = false
                sliding.hue = false
                sliding.alpha = false
            end
        end)
    end

    create_connection(button.MouseButton1Click, function()
        if colorpicker.Content.Open then
            colorpicker.Content:Close()
        else
            colorpicker:open()
        end
    end)

    colorpicker:set(colorpicker.State)
    return colorpicker
end

function library.sections:label(properties)
    if type(properties) == "string" then
        properties = {name = properties}
    end
    local label = {Name = properties.name or properties.Name or "Label"}

    render_object("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Holder,
        Size = udim2_new(1, 0, 0, 16),
        ZIndex = 3,
        Font = "Code",
        Text = label.Name,
        TextColor3 = color_from_rgb(205, 205, 205),
        TextSize = 9,
        TextStrokeTransparency = 1,
        TextXAlignment = "Left"
    })

    return label
end

return library
