-- main.lua (Arceus X Loader)
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/YOUR_REPO_NAME/main/"

-- 1. Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then error("[AX] WindUI failed to load") end

-- 2. Apply Theme
local MakeArceusTheme = loadstring(game:HttpGet(repoBase .. "ArceusX.lua"))()
WindUI:AddTheme(MakeArceusTheme(WindUI))
WindUI:SetTheme("ArceusX")

-- 3. Load Splash
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

-- 4. Boot sequence
showLoading({
    "initializing engine...",
    "verifying signature...",
    "loading modules...",
    "injecting Esp.lua...",
    "injecting WorldVisual.lua...",
    "ready.",
}, function()
    -- 5. Load your scripts (pcall so it doesn't break the UI if they fail)
    local successESP, ESPModule = pcall(function() return loadstring(game:HttpGet(repoBase .. "Esp.lua"))() end)
    local successWorld, WorldModule = pcall(function() return loadstring(game:HttpGet(repoBase .. "WorldVisual.lua"))() end)

    -- 6. Create Window
    local Window = WindUI:CreateWindow({
        Title    = "AX",
        Author   = "Arceus X",
        Folder   = "AX",
        Size     = UDim2.fromOffset(580, 460),
        Theme    = "ArceusX",
        Acrylic  = true,
        Resizable = true,
        Topbar = { Height = 52, ButtonsType = "Default" },
        User = { Enabled = true },
        OpenButton = { Title = "AX", Enabled = true, CornerRadius = UDim.new(1, 0), StrokeThickness = 2 },
        Icon = "rbxassetid://75808871796479",
    })

    -- 7. Tabs
    local ESPSection = Window:Tab({ Title = "ESP", Icon = "eye" })
    local WorldSection = Window:Tab({ Title = "World", Icon = "globe" })
    local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

    -- 8. ESP Wiring
    ESPSection:Section({ Title = "ESP Settings", Opened = true })
    ESPSection:Toggle({
        Title = "Enable ESP",
        Value = false,
        Callback = function(state)
            -- If your Esp.lua has a Toggle function, it fires here.
            if successESP and ESPModule and type(ESPModule.Toggle) == "function" then
                ESPModule.Toggle(state)
            end
        end,
    })

    -- 9. World Wiring
    WorldSection:Section({ Title = "World Visuals", Opened = true })
    WorldSection:Toggle({
        Title = "Enable World Mods",
        Value = false,
        Callback = function(state)
            if successWorld and WorldModule and type(WorldModule.Toggle) == "function" then
                WorldModule.Toggle(state)
            end
        end,
    })

    -- 10. Settings
    SettingsTab:Section({ Title = "UI Settings", Opened = true })
    SettingsTab:Slider({
        Title = "UI Scale",
        Value = { Min = 0.5, Max = 1.5, Default = 1 },
        Step = 0.05,
        Callback = function(val) Window:SetUIScale(val) end,
    })
end)
