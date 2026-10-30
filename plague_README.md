# Plague UI для Roblox

Тёмная UI-библиотека в стиле меню Plaguecheat: верхние вкладки, сабтабы и секции в двух колонках. Это только интерфейс — игровые функции нужно реализовать самостоятельно в callbacks.

## Загрузка

```lua
local Plague = loadstring(game:HttpGet("https://raw.githubusercontent.com/QUANTUMLOADER123/gamesense/arena/62b0e5ca-gamesense/plague.lua"))()
```

Для Roblox Studio сохраните `plague.lua` как ModuleScript и используйте `require(...)` из LocalScript. В Studio `loadstring`/`game:HttpGet` не являются обычным способом загрузки клиентского кода.

Полный пример: [`plague_example.lua`](plague_example.lua). По умолчанию окно открывается в `PlayerGui`, закрывается/открывается на Right Shift и перетаскивается за верхнюю панель. `Parent`, `Title`, `Name`, `Size`, `Accent` и `ToggleKey` задаются в `Plague.new({...})`.

## Структура и элементы

```lua
local window = Plague.new({Title = "Plague"})
local tab = window:Tab("Visuals")
local sub = tab:Subtab("Players")
local section = sub:Section("Player ESP", "Left") -- также "Right"

local enabled = section:Toggle({Name = "Enabled", Flag = "enabled", Default = false,
    Callback = function(value) print(value) end})
section:Slider({Name = "Distance", Min = 0, Max = 100, Step = 1, Default = 50})
section:Dropdown({Name = "Mode", Options = {"Simple", "Full"}, Default = "Simple"})
section:Dropdown({Name = "Parts", Options = {"Name", "Health"}, Default = {"Name"}, Multi = true})
section:ColorPicker({Name = "Color", Default = Color3.fromRGB(77, 122, 181)})
section:Textbox({Name = "Name", Default = "Player", Placeholder = "Enter name"})
section:Keybind({Name = "Action", Default = Enum.KeyCode.F,
    Callback = function(key) print("Pressed", key.Name) end,
    Changed = function(key) print("New key", key) end})
section:Button({Name = "Click", Callback = function() print("Clicked") end})
section:Label("Information")

enabled:Set(true)       -- меняет значение и вызывает Callback
print(enabled:Get())
print(window.Flags.enabled)
-- window:Toggle(false) -- скрыть; window:Toggle(true) -- показать
-- window:Destroy()     -- удалить интерфейс и отключить обработчики
```

Контролы значения возвращают `:Get()` и `:Set(value, silent)`; при `silent = true` callback не вызывается, но `Flags` обновляется. Начальные значения callbacks не вызывают. `Keybind.Callback` срабатывает при нажатии, `Changed` — при смене клавиши; Escape снимает привязку. Имена `Flag` должны быть уникальными в пределах окна. `Button` возвращает Roblox `TextButton`, а `Label` поддерживает `:Set(text)`.
