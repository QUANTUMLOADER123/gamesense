# Minecraft UI для Roblox

Библиотека в стиле софта для Minecraft: ряд одинаковых панелей, строки-опции с рамкой и «•••» справа,
и настройки, которые с анимацией выезжают прямо под опцией (место освобождается, соседние строки
уезжают вниз, при закрытии — обратно). Это только интерфейс: игровую логику пишите в `Callback`.

Пример: [`example_mine.lua`](example_mine.lua). Превью тем: [`minecraft_preview.html`](minecraft_preview.html).

## Загрузка

```lua
local Minecraft = loadstring(game:HttpGet("https://raw.githubusercontent.com/QUANTUMLOADER123/gamesense/arena/8d6efc34-gamesense/minecraft.lua"))()
```

В Roblox Studio положите `minecraft.lua` в ModuleScript `Minecraft` и подключите через
`local Minecraft = require(script.Parent.Minecraft)` (так же сделано в примере с фолбэком).

## Окно

Окно — это только ряд панелей и поле поиска под ними. Заголовка нет, фон прозрачный,
перетаскивания нет: меню всегда стоит по центру экрана.

```lua
local window = Minecraft.new({
    Theme = 1,                      -- 1..6 или имя: "Midnight", "Slate", ...
    ToggleKey = Enum.KeyCode.Insert,
    Blur = true,                    -- реальный блюр мира + стекло под панелями
    BlurSize = 20,                  -- сила блюра
    GlassTransparency = 0.30,       -- 0 = плотное стекло, 1 = полностью прозрачно
    -- Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
})
```

Размеры: панель 226 × 520, строки 30px, отступ 4px, скругления панель 9 / строка 7 /
контрол 5 / мелкое 4 — всё в `Minecraft.Radius` и `Minecraft.Metrics`, можно менять до создания окна.

Стекло (frosted layer) рисуется под панелями и поиском, а не на весь экран: полупрозрачный
градиент от цвета темы + тонкая акцентная рамка. Внутри панелей — вертикальный градиент,
тонкий блик по верхней кромке и мягкий neon glow у строк (сильнее у включённых и открытых).

В Roblox нет UI-«backdrop blur», поэтому настоящий блюр даёт `BlurEffect` в `Lighting`
(`MinecraftUIBlur`): он плавно появляется при открытии меню, пропадает при `Insert`
и удаляется в `window:Destroy()`. Управление: `window:SetBlur(24)` — сила блюра,
`window:SetGlass(0.5)` — плотность стекла.

Чекбоксы в настройках рисуют настоящую галочку (две скруглённые полоски, без ассетов).

* `Insert` — показать/скрыть (плавное затухание);
* поле «Поиск» под панелями фильтрует все панели сразу, несовпавшие строки скрываются,
  открытые настройки закрываются;
* тема задаётся только при создании окна; при желании потом можно `window:SetTheme(3)`
  или `window:CycleTheme(-1)` — это меняет цвета уже созданного меню;
* `window:Toggle(false)`, `window:Destroy()`.

Панель добавляется так:

```lua
local combat = window:AddTab("Combat")
```

Каждая панель одного размера (178 × 430). Сколько вкладок — столько панелей в ряд; окно расширяется
с анимацией, панели плавно встают на места, на маленьком экране меню само уменьшает масштаб.

## Строки

```lua
combat:AddToggle({Name = "Anti Bot", Flag = "anti_bot", Callback = function(on) print(on) end})

combat:AddToggle({
    Name = "Attack Aura",
    Flag = "attack_aura",
    Settings = function(s)                 -- есть настройки -> справа появляются "..." 
        s:Slider({Name = "Range", Min = 1, Max = 8, Step = 0.1, Default = 4, Suffix = " studs"})
        s:Dropdown({Name = "Target", Options = {"Players", "NPCs"}, Default = "Players"})
        s:Toggle({Name = "Through walls", Default = true})
        s:Input({Name = "Filter", Placeholder = "nickname"})
        s:Keybind({Name = "Hold key", Default = Enum.KeyCode.Q})
        s:ColorPicker({Name = "Color", Default = Color3.fromRGB(186, 152, 255)})
        s:Button({Name = "Apply", Callback = function() end})
        s:Label("Текст подсказки")
    end,
})

combat:AddSlider({Name = "CPS Limit", Min = 1, Max = 20, Default = 12})
combat:AddDropdown({Name = "Aspect Ratio", Options = {"Default", "4:3", "16:9"}, Default = "Default"})
combat:AddInput({Name = "Nickname", Placeholder = "type here"})
combat:AddKeybind({Name = "Panic", Default = Enum.KeyCode.Delete})
combat:AddColorPicker({Name = "Box color", Default = Color3.fromRGB(255, 80, 80)})
combat:AddButton({Name = "Reset", Callback = function() end})
combat:AddSection("World")                 -- заголовок раздела
combat:AddLabel("просто текст")
```

**Управление (как в референсе):**

* левый клик по строке — включить/выключить или нажать (у слайдера — потянуть по строке);
* правый клик по строке с настройками — открыть/закрыть блок настроек (снизу, с анимацией);
* строка с `Premium = true` показывает бейдж `PREMIUM`;
* включённая опция подсвечивается фоном и рамкой в цвет темы.

`Settings` можно передать и таблицей функций: `Settings = {build1, build2}`.

## Темы

| # | Имя | Акцент |
|---|-----|--------|
| 1 | Nebula | индиго-фиолетовый |
| 2 | Cyber | циан |
| 3 | Bloom | маджента |
| 4 | Ember | коралловый |
| 5 | Mint | мятный |
| 6 | Gold | янтарный |

Тема задаётся в `Minecraft.new({Theme = ...})`. Названия окна больше нет — заголовок убран.

`Minecraft.Themes` — список тем, `Minecraft.Metrics` — размеры (можно менять до создания окна).

## Значения и конфиги

У строк есть `:Get()`, `:Set(value, silent)` (при `silent = true` callback не вызывается), а у toggle
ещё `:ToggleValue()`. Все значения дублируются в `window.Flags` по `Flag`.

```lua
local config = window:SaveConfig()   -- таблица: числа, строки, списки, цвета, тема
window:LoadConfig(config)            -- применяет и к флагам, и к контролам
window:GetFlag("attack_aura")
```

## Проверка

```bash
npx --yes --package=fengari-node-cli -c "fengari tests/minecraft_mock.lua"
npx --yes --package=fengari-node-cli -c "fengari tests/plague_mock.lua"
```

Это тесты на моках Roblox-объектов: проверяются вкладки, позиции панелей, открытие/закрытие настроек,
слайдеры/дропдауны/кейбинды, поиск, темы, пикер цвета, драг и конфиги. Не визуальный тест.
