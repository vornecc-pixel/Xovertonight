-- main.lua (Arceus X UI Only)
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"

-- 1. Load Splash first
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

-- 2. Define the checks
local checks = {
    "initializing engine...",
    "verifying signature...",
    "loading modules...",
    "ready.",
}

-- 3. Play the splash. When it finishes, the function inside runs.
showLoading(checks, function()
    
    -- 4. Load WindUI *after* the splash finishes
    local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    if not WindUI then error("[AX] WindUI failed to load") end

    -- 5. Apply the Theme
    local MakeArceusTheme = loadstring(game:HttpGet(repoBase .. "ArceusX.lua"))()
    WindUI:AddTheme(MakeArceusTheme(WindUI))
    WindUI:SetTheme("ArceusX")

    -- 6. Create the Window (Notice the custom X Icon)
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
        OpenButton = { 
            Title = "AX", 
            Enabled = true, 
            CornerRadius = UDim.new(1, 0), 
            StrokeThickness = 2,
            Icon = "rbxassetid://7770167407" -- This is the X logo for the floating button
        },
        -- Change this to your preferred "X" logo decal ID
        Icon = "rbxassetid://7770167407", 
    })

    -- 7. Set up the Tabs
    local HomeTab = Window:Tab({ Title = "Home", Icon = "house" })
    local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

    HomeTab:Section({ Title = "Welcome", Opened = true })
    HomeTab:Paragraph({
        Title = "Arceus X",
        Desc = "UI loaded successfully.",
        Image = "sparkles",
        ImageSize = 18,
    })

    HomeTab:Button({
        Title = "Test Notification",
        Desc = "Click to make sure the theme works.",
        Callback = function()
            WindUI:Notify({ Title = "AX", Content = "System online.", Icon = "check", Duration = 3 })
        end,
    })

    SettingsTab:Section({ Title = "UI Settings", Opened = true })
    SettingsTab:Slider({
        Title = "UI Scale",
        Value = { Min = 0.5, Max = 1.5, Default = 1 },
        Step = 0.05,
        Callback = function(val) Window:SetUIScale(val) end,
    })
end)
