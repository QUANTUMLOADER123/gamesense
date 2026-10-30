-- Executor: paste this entire script into your executor.
-- Roblox Studio: put plague.lua in a ModuleScript named Plague and replace
-- the next line with: local Plague = require(path.to.Plague)
local Plague = loadstring(game:HttpGet("https://raw.githubusercontent.com/QUANTUMLOADER123/gamesense/arena/62b0e5ca-gamesense/plague.lua"))()

local window = Plague.new({
    Title = "plaguecheat.cc - kult",
    Accent = Color3.fromRGB(77, 122, 181),
    -- CoreGui and Insert are the defaults. For a Studio LocalScript, use:
    -- Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
})

local rage = window:Tab("Rage")
local legit = window:Tab("Legit")
local visuals = window:Tab("Visuals")
local skins = window:Tab("Skins")
local misc = window:Tab("Misc")

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
local esp = players:Section("Player ESP", "Left", {Height = 195})
local chams = players:Section("Chams", "Left", {Height = 150})
local other = players:Section("Other ESP", "Right", {Height = 125})
local effects = players:Section("Effects", "Right", {Height = 220})

-- These controls demonstrate the UI only; they do not add game features.
local blue = Color3.fromRGB(77, 122, 181)
local white = Color3.fromRGB(220, 220, 220)
esp:Toggle({Name = "Box", Flag = "box", Default = true, Color = blue})
esp:Toggle({Name = "Health", Flag = "health", Default = true, Color = blue})
esp:Toggle({Name = "Name", Flag = "name", Color = white})
esp:Toggle({Name = "Weapon", Flag = "weapon", Default = true, Color = white})
esp:Toggle({Name = "Weapon icon", Flag = "weapon_icon", Default = true, Color = white})
esp:Toggle({Name = "Ammo", Flag = "ammo", Color = blue})
esp:Toggle({Name = "Out of view indicator", Flag = "indicator", Color = blue})
esp:Toggle({Name = "Skeleton", Flag = "skeleton", Color = white})
esp:Toggle({Name = "Hitmarker", Flag = "hitmarker"})
esp:Toggle({Name = "Hitsound", Flag = "hitsound"})
chams:Dropdown({Name = "Material", Flag = "material", Options = {"Textured", "Flat", "Wireframe"}, Default = "Textured"})
chams:Toggle({Name = "Visible", Flag = "visible", Color = blue})
chams:Toggle({Name = "Occluded", Flag = "occluded", Color = Color3.fromRGB(0, 0, 0)})
chams:Toggle({Name = "Local player", Flag = "local_player", Color = white})
chams:Toggle({Name = "Viewmodel", Flag = "viewmodel", Color = white})
other:Toggle({Name = "Dropped weapons", Flag = "dropped", Color = white})
other:Toggle({Name = "Projectile prediction", Flag = "prediction", Color = blue})
other:Toggle({Name = "Penetration crosshair", Flag = "crosshair"})
other:Toggle({Name = "Sniper reticle", Flag = "reticle"})
other:Toggle({Name = "Spectators", Flag = "spectators"})
effects:Toggle({Name = "Remove smoke", Flag = "smoke"})
effects:Toggle({Name = "Remove flashbang", Flag = "flashbang"})
effects:Toggle({Name = "Remove legs", Flag = "legs"})
effects:Toggle({Name = "Remove visual punch", Flag = "punch"})
effects:Dropdown({Name = "Scope", Options = {"-", "Remove"}, Default = "-"})
effects:Keybind({Name = "Third person", Flag = "third_person_key", Callback = function(key) print("Pressed:", key.Name) end})
effects:Toggle({Name = "Nightmode", Flag = "nightmode", Default = true})
effects:Slider({Name = "Intensity", Flag = "intensity", Min = 0, Max = 100, Default = 30, Compact = true})
effects:Toggle({Name = "Bullet tracers", Flag = "tracers", Color = white})
effects:Toggle({Name = "Bullet impacts", Flag = "impacts"})
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
