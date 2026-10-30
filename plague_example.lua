-- Executor: paste this entire script into your executor.
-- Roblox Studio: put plague.lua in a ModuleScript named Plague and replace
-- the next line with: local Plague = require(path.to.Plague)
local Plague = loadstring(game:HttpGet("https://raw.githubusercontent.com/QUANTUMLOADER123/gamesense/arena/62b0e5ca-gamesense/plague.lua"))()

local window = Plague.new({
    Title = "Plague | Roblox",
    Accent = Color3.fromRGB(77, 122, 181),
    ToggleKey = Enum.KeyCode.RightShift,
})

local visuals = window:Tab("Visuals")
local players = visuals:Subtab("Players")
local world = visuals:Subtab("World")
local esp = players:Section("Player ESP", "Left")
local appearance = players:Section("Appearance", "Right")

-- These callbacks are examples only; the library does not add ESP or other game features.
esp:Toggle({Name = "Enabled", Flag = "esp_enabled", Default = false, Callback = function(value)
    print("ESP enabled:", value)
end})
esp:Toggle({Name = "Name", Flag = "show_name", Default = true})
esp:Toggle({Name = "Health", Flag = "show_health", Default = true})
esp:Slider({Name = "Distance", Flag = "distance", Min = 0, Max = 1000, Default = 250, Step = 10, Suffix = "m", Callback = function(value)
    print("Distance:", value)
end})
esp:Dropdown({Name = "Elements", Flag = "elements", Options = {"Box", "Name", "Health", "Weapon"}, Default = {"Box", "Name"}, Multi = true, Callback = function(values)
    print("Selected:", table.concat(values, ", "))
end})
appearance:ColorPicker({Name = "Color", Flag = "esp_color", Default = Color3.fromRGB(77, 122, 181), Callback = function(color)
    print("Color:", color)
end})
appearance:Dropdown({Name = "Style", Flag = "style", Options = {"Simple", "Outlined", "Corner"}, Default = "Simple"})
appearance:Keybind({Name = "Action key", Flag = "action_key", Default = Enum.KeyCode.F, Callback = function(key)
    print("Pressed:", key.Name)
end, Changed = function(key)
    print("Key changed:", key and key.Name or "None")
end})
world:Section("World", "Left"):Label("Add your own world settings here")

local misc = window:Tab("Misc")
local general = misc:Subtab("General")
local settings = general:Section("Settings", "Left")
settings:Textbox({Name = "Profile name", Flag = "profile", Default = "Default", Callback = function(value)
    print("Profile:", value)
end})
settings:Button({Name = "Print flags", Callback = function()
    for flag, value in pairs(window.Flags) do print(flag, value) end
end})
settings:Button({Name = "Unload menu", Callback = function() window:Destroy() end})

-- Right Shift hides/shows the menu. Click the header and drag to move it.
-- Controls return objects with :Set(value, silent) and :Get(); Button returns its UI object.
-- Example: local toggle = section:Toggle({Name = "Enabled"}); toggle:Set(true)
