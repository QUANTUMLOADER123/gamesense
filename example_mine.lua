--[[
    example_mine.lua -- Minecraft UI demo for Roblox.

    Paste this whole file into your executor (or a LocalScript in Studio).
    The library is loaded straight from GitHub; nothing else is required.

    Controls (like in the reference Minecraft cheat menu):
      * Insert               -- show / hide the menu
      * Left click on a row  -- toggle / press the option
      * Right click on a row -- open the animated settings block (the "..." rows)
      * Search box           -- filter every panel at once (under the panels)
      * Theme               -- set once in Minecraft.new({Theme = 1..6})
      * window:SetTheme(n)  -- crossfade to another palette at runtime

    IMPORTANT: this is UI only. Toggles, sliders and dropdowns do not add game
    features -- wire your own logic into the Callback functions.
]]

-- Shared libraries cache HTTP results, so the URL carries a version query to
-- make sure the newest minecraft.lua is fetched. Bump it if you edit the file.
local LIB_URL = "https://raw.githubusercontent.com/QUANTUMLOADER123/gamesense/arena/8d6efc34-gamesense/minecraft.lua?v=1.10.0"

local function httpGet(url)
    -- Several executors cache game:HttpGet; request(url, true) forces a refresh.
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end
    return game:HttpGet(url)
end

local ok, Minecraft = pcall(function()
    local source = httpGet(LIB_URL)
    local chunk = loadstring(source)
    if not chunk then
        error("minecraft.lua returned by HttpGet could not be parsed (stale cache?)")
    end
    return chunk()
end)
if not ok or type(Minecraft) ~= "table" then
    -- Roblox Studio: save minecraft.lua as a ModuleScript named "Minecraft"
    -- and use: local Minecraft = require(script.Parent.Minecraft)
    local module = script and script.Parent and script.Parent:FindFirstChild("Minecraft")
    if module then
        Minecraft = require(module)
    else
        error("Could not load minecraft.lua: " .. tostring(Minecraft))
    end
end

local Player = game:GetService("Players").LocalPlayer

--==========================================================================--
-- Window
--==========================================================================--
local window = Minecraft.new({
    Theme = 1,          -- 1..6 (Nebula, Cyber, Bloom, Ember, Mint, Gold)
    ToggleKey = Enum.KeyCode.Insert,
    -- Acrylic = "auto",    -- "auto" (default) = real frosted glass behind the
    --                      --   panels when the client supports it (graphics
    --                      --   quality >= 8), "on" = force, "off" = never
    -- BlurMode = "screen", -- "screen" = blur the whole view (default)
    --                      -- "local"  = keep the game sharp, dim only behind panels
    -- BlurSize = 24,       -- blur strength
    -- Dim = true,          -- dark scrim
    -- DimTransparency = 0.55, -- 0 = black, 1 = none
    -- GlassTransparency = 0.22, -- panel opacity, 0 = solid, 1 = fully clear
    Search = true,
    -- Parent = Player:WaitForChild("PlayerGui"), -- for a Studio LocalScript
})

--==========================================================================--
-- Tabs. Each AddTab adds one more panel of the same size; the window widens
-- and the panels scroll/slide into place.
--==========================================================================--
local combat = window:AddTab("Combat")
local movement = window:AddTab("Movement")
local visuals = window:AddTab("Visuals")
local playerTab = window:AddTab("Player")
local misc = window:AddTab("Miscellaneous")

--==========================================================================--
-- Combat
--==========================================================================--
combat:AddToggle({
    Name = "Anti Bot",
    Flag = "anti_bot",
    Callback = function(enabled) print("Anti Bot:", enabled) end,
})

combat:AddToggle({
    Name = "Attack Aura",
    Flag = "attack_aura",
    -- Rows with Settings show "..." on the right; right click slides them open.
    Settings = function(s)
        s:Slider({Name = "Range", Min = 1, Max = 8, Step = 0.1, Default = 3.5, Suffix = " studs", Flag = "aura_range",
            Callback = function(value) print("Range:", value) end})
        s:Dropdown({Name = "Target", Options = {"Players", "NPCs", "Everyone"}, Default = "Players", Flag = "aura_target"})
        s:Toggle({Name = "Through walls", Default = true, Flag = "aura_walls"})
        s:Keybind({Name = "Hold key", Default = Enum.KeyCode.Q, Flag = "aura_key"})
    end,
})

combat:AddToggle({
    Name = "Auto Explosion",
    Flag = "auto_explosion",
    Settings = function(s)
        s:Slider({Name = "Delay", Min = 0, Max = 2, Step = 0.05, Default = 0.35, Suffix = "s"})
        s:Toggle({Name = "Only in combat", Default = true})
    end,
})

combat:AddToggle({Name = "Auto Swap", Flag = "auto_swap"})
combat:AddToggle({Name = "Auto Totem", Flag = "auto_totem", Default = true})
combat:AddButton({Name = "Panic (disable all)", Callback = function()
    for flag, value in pairs(window.Flags) do
        if type(value) == "boolean" and value then
            print("Disabling", flag)
        end
    end
    print("All combat features disabled")
end})
combat:AddSlider({Name = "CPS Limit", Min = 1, Max = 20, Step = 1, Default = 12, Flag = "cps",
    Callback = function(value) print("CPS:", value) end})

--==========================================================================--
-- Movement
--==========================================================================--
movement:AddToggle({Name = "Air Jump", Flag = "air_jump"})
movement:AddToggle({
    Name = "Dragon Flight",
    Flag = "dragon_flight",
    Settings = function(s)
        s:Slider({Name = "Speed", Min = 1, Max = 200, Step = 1, Default = 60, Flag = "flight_speed"})
        s:Dropdown({Name = "Mode", Options = {"Velocity", "CFrame", "LookVector"}, Default = "Velocity"})
        s:Toggle({Name = "Anti kick", Default = true})
    end,
})
movement:AddToggle({Name = "Elytra Flight", Flag = "elytra_flight"})
movement:AddToggle({Name = "Flight", Flag = "flight"})
movement:AddToggle({
    Name = "Free Camera",
    Flag = "freecam",
    Settings = function(s)
        s:Slider({Name = "Zoom", Min = 1, Max = 5, Step = 0.1, Default = 2, Suffix = "x"})
        s:Keybind({Name = "Key", Default = Enum.KeyCode.C})
    end,
})
movement:AddToggle({Name = "No Jump Delay", Flag = "no_jump_delay"})
movement:AddToggle({Name = "No Push", Flag = "no_push"})
movement:AddToggle({Name = "No Slow", Flag = "no_slow"})
movement:AddSlider({Name = "Speed", Min = 0, Max = 30, Step = 0.5, Default = 16, Flag = "walk_speed",
    Settings = function(s)
        s:Toggle({Name = "Only while sprinting", Default = true})
        s:Slider({Name = "Smoothness", Min = 0, Max = 100, Step = 1, Default = 40})
    end})

--==========================================================================--
-- Visuals
--==========================================================================--
visuals:AddSection("World")
visuals:AddToggle({
    Name = "Block ESP",
    Flag = "block_esp",
    Settings = function(s)
        s:Input({Name = "Block", Placeholder = "minecraft:chest", Default = "chest", Flag = "block_esp_id"})
        s:Slider({Name = "Distance", Min = 16, Max = 512, Step = 8, Default = 128})
        s:ColorPicker({Name = "Outline", Default = Color3.fromRGB(186, 152, 255),
            Flag = "block_esp_color", AlphaFlag = "block_esp_alpha", DefaultAlpha = 0.8,
            Callback = function(color, alpha) print("Outline", color, alpha) end})
    end,
})
visuals:AddToggle({Name = "China Hat", Flag = "china_hat", Premium = true})
visuals:AddToggle({
    Name = "Full Bright",
    Flag = "full_bright",
    Settings = function(s)
        s:Slider({Name = "Brightness", Min = 1, Max = 10, Step = 0.5, Default = 4})
    end,
})
visuals:AddToggle({Name = "Hands", Flag = "hands"})
visuals:AddToggle({Name = "Hud", Flag = "hud", Settings = function(s)
    s:Toggle({Name = "Watermark", Default = true})
    s:Toggle({Name = "FPS counter", Default = true})
    s:ColorPicker({Name = "Text color", Default = Color3.fromRGB(255, 255, 255)})
end})
visuals:AddDropdown({
    Name = "Aspect Ratio",
    Options = {"Default", "4:3", "16:9", "21:9", "Custom"},
    Default = "Default",
    Flag = "aspect",
    Callback = function(value) print("Aspect:", value) end,
})
visuals:AddSlider({Name = "FOV", Min = 70, Max = 120, Step = 1, Default = 90, Flag = "fov"})

--==========================================================================--
-- Player
--==========================================================================--
playerTab:AddToggle({Name = "Anti AFK", Flag = "anti_afk", Default = true})
playerTab:AddToggle({Name = "Auto Armor", Flag = "auto_armor"})
playerTab:AddToggle({
    Name = "Auto Eat GApple",
    Flag = "auto_gapple",
    Settings = function(s)
        s:Slider({Name = "Health", Min = 1, Max = 20, Step = 1, Default = 8, Suffix = " hp"})
        s:Slider({Name = "Delay", Min = 0, Max = 3, Step = 0.1, Default = 0.4, Suffix = "s"})
    end,
})
playerTab:AddToggle({Name = "Auto Potion", Flag = "auto_potion"})
playerTab:AddToggle({Name = "Auto Respawn", Flag = "auto_respawn", Default = true})
playerTab:AddToggle({Name = "Auto Tool", Flag = "auto_tool"})
playerTab:AddToggle({Name = "Auto Trade", Flag = "auto_trade"})
playerTab:AddToggle({Name = "Auto Transfer", Flag = "auto_transfer"})
playerTab:AddToggle({Name = "Blink", Premium = true})

--==========================================================================--
-- Miscellaneous
--==========================================================================--
misc:AddToggle({Name = "Air Place", Flag = "air_place"})
misc:AddToggle({Name = "Auto Leave", Flag = "auto_leave", Settings = function(s)
    s:Slider({Name = "Health", Min = 1, Max = 20, Step = 1, Default = 4})
end})
misc:AddToggle({Name = "Auto Tpaccept", Flag = "auto_tpaccept"})
misc:AddToggle({Name = "Discord Activity", Flag = "discord_activity"})
misc:AddToggle({Name = "Funtime Helper", Flag = "funtime_helper"})
misc:AddToggle({Name = "Inventory Plus", Flag = "inventory_plus", Settings = function(s)
    s:Toggle({Name = "Sort on open", Default = true})
    s:Dropdown({Name = "Sort by", Options = {"Name", "Count", "Rarity"}, Default = "Name"})
end})
misc:AddToggle({Name = "Multi Actions", Flag = "multi_actions"})
misc:AddToggle({Name = "Name Protect", Flag = "name_protect"})
misc:AddToggle({Name = "Open Walls", Flag = "open_walls"})
misc:AddButton({Name = "Print all flags", Callback = function()
    for flag, value in pairs(window.Flags) do
        print(string.format("%s = %s", flag, tostring(value)))
    end
end})
misc:AddButton({Name = "Unload menu", Callback = function()
    window:Destroy()
end})

--==========================================================================--
-- Themes / config helpers
--==========================================================================--
-- window:SetTheme(3)        -- Bloom (see the theme table in the README)
-- window:CycleTheme(1)      -- next theme
-- window:SetAcrylic("off")  -- drop the frosted-glass backdrop (or "on"/"auto")
-- window.AcrylicSupported   -- true when this client can render glass blur
-- window:Filter("aura")     -- programmatic search
-- The window has no title bar and cannot be dragged: it is a fixed row of panels.
-- window:Toggle(false)      -- hide, window:Toggle(true) -- show
--
-- local config = window:SaveConfig()  -- plain table: booleans, numbers,
-- window:LoadConfig(config)           -- strings, lists, colors and the theme

-- Show the menu with a small intro animation.
window:Toggle(true)

-- Handy for consoles: announce where the library lives.
print(("Minecraft UI v%s loaded for %s"):format(Minecraft.Version, Player.Name))
-- If this fires, your executor served a cached copy of minecraft.lua.
assert(Minecraft.Build and Minecraft.Build >= 20,
    "stale minecraft.lua in cache -- clear the executor cache or bump LIB_URL")
