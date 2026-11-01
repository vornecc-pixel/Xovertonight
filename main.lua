-- main.lua (Arceus X UI Only)
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

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

    -- 6. Create the Window (Acrylic OFF to stop mobile lag/shaking)
    local Window = WindUI:CreateWindow({
        Title    = "AX",
        Author   = "Arceus X",
        Folder   = "AX",
        Size     = UDim2.fromOffset(580, 460),
        Theme    = "ArceusX",
        Acrylic  = false, 
        Resizable = true,
        Topbar = { Height = 52, ButtonsType = "Default" },
        User = { Enabled = true },
        OpenButton = { 
            Title = "AX", 
            Enabled = true, -- Re-enabled WindUI's native OpenButton
            Icon = "rbxassetid://7770167407"
        },
        Icon = "rbxassetid://7770167407", 
    })

    -- 7. Set up the Tabs
    local HomeTab = Window:Tab({ Title = "Home", Icon = "house" })
    local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

    HomeTab:Section({ Title = "Welcome", Opened = true })
    HomeTab:Paragraph({
        Title = "Arceus X",
        Desc = "UI loaded successfully. Use the keybind to toggle the menu.",
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

    -- Settings Tab: UI Settings
    SettingsTab:Section({ Title = "UI Settings", Opened = true })
    SettingsTab:Slider({
        Title = "UI Scale",
        Value = { Min = 0.5, Max = 1.5, Default = 1 },
        Step = 0.05,
        Callback = function(val) Window:SetUIScale(val) end,
    })
    
    -- Custom Keybind Toggle (Now perfectly syncs with the UI)
    local isOpen = true
    SettingsTab:Keybind({
        Title = "Toggle UI Keybind",
        Desc = "Press any key to toggle the whole UI.",
        Value = "RightShift", 
        Callback = function()
            isOpen = not isOpen
            if isOpen then
                Window:Open()
            else
                Window:Close()
            end
        end
    })

    -- Settings Tab: Stability
    SettingsTab:Section({ Title = "Performance & Stability", Opened = true })
    SettingsTab:Toggle({
        Title = "Fix Game Shake (Physics)",
        Desc = "If your character still shakes, toggle this. It briefly anchors you to stop physics jitter.",
        Value = false,
        Callback = function(state)
            if state then
                task.spawn(function()
                    while state do
                        if LP.Character then
                            local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                hrp.Anchored = true 
                                task.wait(0.05)
                                hrp.Anchored = false
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
    })

    -- Settings Tab: Configs
    SettingsTab:Section({ Title = "Config Manager", Opened = true })
    local configName = "default"
    SettingsTab:Input({
        Title = "Config Name",
        Value = "default",
        Placeholder = "Enter config name...",
        Callback = function(text)
            configName = text
        end
    })
    
    SettingsTab:Button({
        Title = "Save Config",
        Desc = "Saves current UI state to the given name.",
        Callback = function()
            WindUI:SaveConfig(configName)
            WindUI:Notify({ Title = "Config", Content = "Saved: " .. configName, Icon = "save", Duration = 3 })
        end
    })

    SettingsTab:Button({
        Title = "Load Config",
        Desc = "Loads saved UI state.",
        Callback = function()
            WindUI:LoadConfig(configName)
            WindUI:Notify({ Title = "Config", Content = "Loaded: " .. configName, Icon = "download", Duration = 3 })
        end
    })

    SettingsTab:Button({
        Title = "Create New Config",
        Desc = "Creates a new config file based on current settings.",
        Callback = function()
            WindUI:SaveConfig(configName)
            WindUI:Notify({ Title = "Config", Content = "Created: " .. configName, Icon = "file-plus", Duration = 3 })
        end
    })

    SettingsTab:Button({
        Title = "Delete Config",
        Desc = "Deletes the selected config.",
        Callback = function()
            WindUI:DeleteConfig(configName)
            WindUI:Notify({ Title = "Config", Content = "Deleted: " .. configName, Icon = "trash", Duration = 3 })
        end
    })

    SettingsTab:Toggle({
        Title = "Auto-Load Config",
        Desc = "Automatically loads the selected config on execution.",
        Value = false,
        Callback = function(state)
            if state then
                WindUI:LoadConfig(configName)
            end
        end
    })

    -- Settings Tab: Danger Zone
    SettingsTab:Section({ Title = "Danger Zone", Opened = false })
    SettingsTab:Button({
        Title = "Unload Everything",
        Desc = "Completely removes the UI and stops all scripts.",
        Callback = function()
            if Window then Window:Destroy() end
            for _, v in pairs((gethui and gethui() or LP:WaitForChild("PlayerGui")):GetChildren()) do
                if v:IsA("ScreenGui") and v.Name ~= "AX_Loading" then
                    v:Destroy()
                end
            end
        end
    })
end)
