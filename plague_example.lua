-- Executor: paste this entire script into your executor.
-- Roblox Studio: put plague.lua in a ModuleScript named Plague and replace
-- the next line with: local Plague = require(path.to.Plague)
local Plague = loadstring(game:HttpGet("https://raw.githubusercontent.com/QUANTUMLOADER123/gamesense/arena/62b0e5ca-gamesense/plague.lua"))()

local window = Plague.new({
    Title = "Plaguecheat.cc",
    Accent = Color3.fromRGB(77, 122, 181),
    -- CoreGui and Insert are the defaults. For a Studio LocalScript, use:
    -- Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
})

local rage = window:Tab("Rage", {Icon = "target"})
local legit = window:Tab("Legit", {Icon = "user"})
local visuals = window:Tab("Visuals", {Icon = "eye"})
local skins = window:Tab("Skins", {Icon = "palette"})
local misc = window:Tab("Misc", {Icon = "settings"})

rage:Subtab("General"):Section("Rage", "Left"):Label("Your settings here")
legit:Subtab("General"):Section("Legit", "Left"):Label("Your settings here")
local skinTab = skins:Subtab("Selection", {Icon = "layers"})
local skinLeft = skinTab:Section("Weapon Selection", "Left")
local skinRight = skinTab:Section("Skin Selection", "Right")
skinLeft:Listbox({Name = "Items", Flag = "item", Height = 220, Options = {"Default", "Pistol", "Rifle", "Gloves", "Knife"}, Default = "Default"})
skinRight:Listbox({Name = "Styles", Flag = "skin", Height = 220, Options = {"Default", "Blue", "Red", "Gold"}, Default = "Default"})
skinRight:Slider({Name = "Wear", Flag = "wear", Min = 0, Max = 100, Default = 0, Suffix = "%"})

local players = visuals:Subtab("Players", {Icon = "user"})
local world = visuals:Subtab("World", {Icon = "globe"})
local esp = players:Section("Player ESP", "Left")
local chams = players:Section("Chams", "Left")
local other = players:Section("Other ESP", "Right")
local effects = players:Section("Effects", "Right")

-- These controls demonstrate the UI only; they do not add game features.
local blue = Color3.fromRGB(77, 122, 181)
local white = Color3.fromRGB(220, 220, 220)
esp:Toggle({Name = "Box", Flag = "box", Color = blue})
esp:Toggle({Name = "Health", Flag = "health", Default = true, Color = blue})
esp:Toggle({Name = "Name", Flag = "name", Default = true, Color = white})
esp:Toggle({Name = "Weapon", Flag = "weapon", Color = white})
esp:Toggle({Name = "Weapon icon", Flag = "weapon_icon", Default = true, Color = white})
esp:Toggle({Name = "Ammo", Flag = "ammo", Default = true, Color = blue})
esp:Toggle({Name = "Out of view indicator", Flag = "indicator", Default = true, Color = blue})
esp:Toggle({Name = "Skeleton", Flag = "skeleton", Default = true, Color = white})
chams:Dropdown({Name = "Material", Flag = "material", Options = {"Textured", "Flat", "Wireframe"}, Default = "Textured"})
chams:Toggle({Name = "Visible", Flag = "visible", Default = true, Color = blue})
chams:Toggle({Name = "Occluded", Flag = "occluded", Color = Color3.fromRGB(0, 0, 0)})
chams:Toggle({Name = "Local player", Flag = "local_player", Color = white})
chams:Toggle({Name = "Viewmodel", Flag = "viewmodel", Color = white})
other:Toggle({Name = "Dropped weapons", Flag = "dropped", Default = true, Color = white})
other:Dropdown({Name = "Display", Flag = "display", Options = {"Text", "Icon"}, Default = "Text"})
other:Toggle({Name = "Dropped weapons ammo", Flag = "dropped_ammo", Default = true, Color = blue})
other:Toggle({Name = "Projectile prediction", Flag = "prediction", Default = true, Color = blue})
effects:Toggle({Name = "Remove smoke", Flag = "smoke"})
effects:Toggle({Name = "Remove flashbang", Flag = "flashbang"})
effects:Toggle({Name = "Remove legs", Flag = "legs"})
effects:Toggle({Name = "Remove visual punch", Flag = "punch"})
effects:Dropdown({Name = "Scope", Options = {"Default", "Remove"}, Default = "Default"})
effects:Keybind({Name = "Third person", Flag = "third_person_key", Callback = function(key) print("Pressed:", key.Name) end})
effects:Toggle({Name = "Nightmode", Flag = "nightmode", Default = true})
effects:Slider({Name = "Intensity", Flag = "intensity", Min = 0, Max = 100, Default = 30, Suffix = "%"})
effects:Toggle({Name = "Bullet tracers", Flag = "tracers", Default = true, Color = blue})
world:Section("World", "Left"):Label("Add your own world settings here")

local settings = misc:Subtab("General", {Icon = "settings"}):Section("Settings", "Left")
settings:Textbox({Name = "Profile name", Flag = "profile", Default = "Default"})
settings:Dropdown({Name = "Elements", Flag = "elements", Options = {"Box", "Name", "Health"}, Default = {"Box", "Name"}, Multi = true})
settings:ColorPicker({Name = "Accent example", Default = blue})
settings:Button({Name = "Print flags", Icon = "folder", Callback = function()
    for flag, value in pairs(window.Flags) do print(flag, value) end
end})
settings:Button({Name = "Unload menu", Icon = "settings", Callback = function() window:Destroy() end})

window:SelectTab(visuals)
-- Insert hides/shows the menu. Click and drag the top bar to move it.
-- Controls return objects with :Set(value, silent) and :Get().
-- Click the small swatch beside a toggle to edit its RGB color.
