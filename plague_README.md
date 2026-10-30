# Plague UI для Roblox

Тёмная UI-библиотека в стиле меню Plaguecheat: верхние вкладки, сабтабы и секции в двух колонках. Это только интерфейс — игровые функции нужно реализовать самостоятельно в callbacks.

## Загрузка

```lua
local Plague = loadstring(game:HttpGet("https://raw.githubusercontent.com/QUANTUMLOADER123/gamesense/arena/62b0e5ca-gamesense/plague.lua"))()
```

Для Roblox Studio сохраните `plague.lua` как ModuleScript и используйте `require(...)` из LocalScript. В Studio `loadstring`/`game:HttpGet` не являются обычным способом загрузки клиентского кода.

Полный пример: [`plague_example.lua`](plague_example.lua). По умолчанию окно создаётся в `CoreGui`, закрывается/открывается на Insert и перетаскивается за верхнюю панель. Заголовок по умолчанию — `plaguecheat.cc - <имя локального игрока>`. Доступ к `CoreGui` нужен со стороны среды выполнения; в обычном LocalScript Studio передайте `Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")`. `Parent`, `Title`, `Name`, `Size`, `Scale`, `Font`, `Accent` и `ToggleKey` задаются в `Plague.new({...})`.

## Структура и элементы

```lua
local window = Plague.new({Title = "Plague"})
local tab = window:Tab("Visuals", {Icon = "eye"})
local sub = tab:Subtab("Players")
local section = sub:Section("Player ESP", "Left", {Height = 195}) -- также "Right"

local enabled = section:Toggle({Name = "Enabled", Flag = "enabled", Default = false,
    Callback = function(value) print(value) end})
section:Toggle({Name = "Box", Default = true, Color = Color3.fromRGB(111, 129, 148),
    ColorFlag = "box_color", ColorCallback = function(color) print(color) end})
section:Slider({Name = "Distance", Min = 0, Max = 100, Step = 1, Default = 50})
section:Dropdown({Name = "Mode", Options = {"Simple", "Full"}, Default = "Simple"})
section:Dropdown({Name = "Parts", Options = {"Name", "Health"}, Default = {"Name"}, Multi = true})
section:Listbox({Name = "Profiles", Options = {"Default", "Custom"}, Default = "Default", Height = 120})
section:ColorPicker({Name = "Color", Flag = "color", AlphaFlag = "opacity", Alpha = 1,
    Default = Color3.fromRGB(111, 129, 148), Callback = function(color, alpha) print(color, alpha) end})
section:Textbox({Name = "Name", Default = "Player", Placeholder = "Enter name"})
section:Keybind({Name = "Action", Default = Enum.KeyCode.F,
    Callback = function(key) print("Pressed", key.Name) end,
    Changed = function(key) print("New key", key) end})
section:Button({Name = "Click", Icon = "settings", Callback = function() print("Clicked") end})
section:Label("Information")

enabled:Set(true)       -- меняет значение и вызывает Callback
print(enabled:Get())
print(window.Flags.enabled)
-- window:Toggle(false) -- скрыть; window:Toggle(true) -- показать
-- window:Destroy()     -- удалить интерфейс и отключить обработчики
```

Контролы значения возвращают `:Get()` и `:Set(value, silent)`; при `silent = true` callback не вызывается, но `Flags` обновляется. Начальные значения callbacks не вызывают. `Keybind.Callback` срабатывает при нажатии, `Changed` — при смене клавиши; Escape снимает привязку. Имена `Flag` должны быть уникальными в пределах окна. `Button` возвращает Roblox `TextButton`, а `Label` поддерживает `:Set(text)`.

У `Toggle` можно задать `Color`, `ColorFlag` и `ColorCallback`: справа появится цветной квадрат, по нажатию открывающий HSV-пикер. Для прозрачности используйте `Alpha` (по умолчанию 1), `ColorAlphaFlag`, а также `:SetAlpha(alpha, silent)` и `:GetAlpha()`. `ColorCallback(color, alpha)` вызывается при изменении цвета или альфы. Также доступны `:SetColor(color, silent)` и `:GetColor()`. Значение альфы — непрозрачность: 0 полностью прозрачно, 1 непрозрачно.

## Иконки и списки

У вкладок и кнопок параметр `Icon` необязателен; сабтабы текстовые. Полоса сабтабов появляется только если их больше одного. Встроенные имена: `target`, `eye`, `user`, `globe`, `settings`, `palette`, `layers`, `folder`, `sliders`, `check`, `down`, `copy`. Они рисуются из Roblox Frames, поэтому не требуют загрузки изображений или asset ID. `Listbox` и открытый `Dropdown` прокручиваются; раскрывающиеся списки и пикер показываются поверх меню, не раздвигая секции; выбранный пункт подсвечивается. Слайдер можно перемещать мышью или менять кнопками «−»/«+».

Референсы: [CS2 Rage/Visuals](https://en.exloader.net/tree/modifications/plaguecheat-cc-cs2/), [CS2 Misc](https://modvault.net/plaguecheat/), [старые версии](https://cheatermad.com/free-cs2-cheating-plaguecheat-cc-release/). Дизайн разных версий отличается; за основу взята компактная тёмная CS2-версия.

## Проверка

Из корня репозитория: `npx --yes --package=fengari-node-cli -c "fengari tests/plague_mock.lua"`. Это тесты взаимодействий на моках Roblox, не визуальный тест в Studio или игре.

Масштаб окна по умолчанию `Scale = 1` (490 × 420 пикселей при стандартном размере). Масштаб можно изменить, например `Plague.new({Scale = 1.2})` для более крупного меню или `Scale = 0.85` для компактного. У секции можно задать `{Height = 195}`: содержимое будет прокручиваться внутри неё, не сдвигая соседние секции. Без `Height` секция растёт по содержимому, как раньше. Для раскрывающегося списка доступны `Name = ""` (без подписи) и `FullWidth = true` (полная ширина). Для компактного слайдера — `Compact = true`.

У `ColorPicker` есть `:Set(color, silent)`, `:Get()`, `:SetAlpha(alpha, silent)`, `:GetAlpha()` и `:Open()`. `Flag` хранит `Color3`, `AlphaFlag` — число 0–1. Попапы закрываются по Escape, нажатию вне попапа, смене вкладки или скрытию окна.

Цвета по запросу: фон `#0d0d0d`, панели `#141414`, неактивный текст `#8c8c8c`, акцент `#6f8194`. Фон содержит ту же тайловую текстуру `rbxassetid://8547666218`, что в `gamesense.lua` (её загрузка зависит от доступности Roblox asset).

Квадрат справа внизу HSV-пикера копирует `#RRGGBBAA`, где `AA` — непрозрачность. При доступном `setclipboard`/`toclipboard` копирование происходит автоматически; если функция отсутствует, появляется выделенный текст для ручного копирования.

Шрифт по умолчанию — `Enum.Font.Code`, как в `gamesense.lua`, при этом размер сохранён читаемым. Его можно выбрать для отдельного окна: `Plague.new({Font = Enum.Font.Gotham})` или `Enum.Font.SourceSans`. Текстура применяется только на фоне, внутри панелей её нет.
