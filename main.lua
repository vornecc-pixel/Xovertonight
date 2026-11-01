-- main.lua (Arceus X UI Only)
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"

-- 1. Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then error("[AX] WindUI failed to load") end

-- 2. Apply Theme
local MakeArceusTheme = loadstring(game:HttpGet(repoBase .. "ArceusX.lua"))()
WindUI:AddTheme(MakeArceusTheme(WindUI))
WindUI:SetTheme("ArceusX")

-- 3. Build the UI *immediately* but hide it
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

-- Hide the UI and its open button until the animation finishes
Window.UIElements.Main.Visible = false
if Window.OpenButtonMain and Window.OpenButtonMain.Button then
    Window.OpenButtonMain:Visible(false)
end

-- 4. Set up the UI Tabs (Empty placeholders)
local HomeTab = Window:Tab({ Title = "Home", Icon = "house" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

HomeTab:Section({ Title = "Welcome", Opened = true })
HomeTab:Paragraph({
    Title = "Arceus X",
    Desc = "The UI is fully loaded and ready for your custom features.",
    Image = "sparkles",
    ImageSize = 18,
})

HomeTab:Button({
    Title = "Test Notification",
    Desc = "Click to make sure everything is working.",
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

-- 5. Load the Splash and pass the UI frame as the target
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

showLoading({
    "initializing engine...",
    "verifying signature...",
    "loading modules...",
    "ready.",
}, Window.UIElements.Main, function()
    -- 6. This runs when the 64-bit X finishes flying to the top left
    Window.UIElements.Main.Visible = true
    
    -- Bouncy "activation" effect when the UI appears
    Window.UIElements.Main.Size = UDim2.fromOffset(560, 440) 
    game:GetService("TweenService"):Create(Window.UIElements.Main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(580, 460)
    }):Play()
    
    if Window.OpenButtonMain and Window.OpenButtonMain.Button then
        Window.OpenButtonMain:Visible(true)
    end
end)
