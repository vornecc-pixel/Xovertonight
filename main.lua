-- main.lua (Arceus X UI Only)
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
            Enabled = false, -- Custom floating button used instead
        },
        Icon = "rbxassetid://7770167407", 
    })

    -- 7. UI Visibility Logic (Reused by float button and keybind)
    local mainGuiVisible = true
    local floatGui -- Forward declaration

    local function SetUIVisibility(state)
        mainGuiVisible = state
        
        -- Toggle the main window
        for _, v in pairs((gethui and gethui() or LP:WaitForChild("PlayerGui")):GetChildren()) do
            if v:IsA("ScreenGui") and v.Name ~= "AX_Floating" and v.Name ~= "AX_Loading" then
                v.Enabled = mainGuiVisible
            end
        end
        
        -- Toggle the floating minimize button and stats box
        if floatGui then
            floatGui.Enabled = not mainGuiVisible
        end
    end

    -- 8. Set up the Tabs
    local HomeTab = Window:Tab({ Title = "Home", Icon = "house" })
    local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

    HomeTab:Section({ Title = "Welcome", Opened = true })
    HomeTab:Paragraph({
        Title = "Arceus X",
        Desc = "UI loaded successfully. Use the keybind or the floating X to minimize/restore.",
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
    
    -- Custom Keybind Toggle
    SettingsTab:Keybind({
        Title = "Toggle UI Keybind",
        Desc = "Press any key to toggle the main UI. Toggle the switch to enable/disable.",
        Value = "RightShift", 
        Callback = function()
            SetUIVisibility(not mainGuiVisible)
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
            if floatGui then floatGui:Destroy() end
            if Window then Window:Destroy() end
            for _, v in pairs((gethui and gethui() or LP:WaitForChild("PlayerGui")):GetChildren()) do
                if v:IsA("ScreenGui") and v.Name ~= "AX_Floating" and v.Name ~= "AX_Loading" then
                    v:Destroy()
                end
            end
        end
    })

    -- 9. Minimize Button & Ping/FPS Stats Box
    floatGui = Instance.new("ScreenGui")
    floatGui.Name = "AX_Floating"
    floatGui.ResetOnSpawn = false
    floatGui.Enabled = false -- Start hidden because the main UI is currently open
    floatGui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")

    local floatBtn = Instance.new("ImageButton")
    floatBtn.Size = UDim2.fromOffset(45, 45)
    floatBtn.Position = UDim2.new(0, 20, 0, 20)
    floatBtn.BackgroundColor3 = Color3.fromHex("#150F23")
    floatBtn.Image = "rbxassetid://7770167407"
    floatBtn.ImageColor3 = Color3.fromHex("#A855F7")
    floatBtn.Parent = floatGui
    
    local fCorner = Instance.new("UICorner"); fCorner.CornerRadius = UDim.new(0, 8); fCorner.Parent = floatBtn
    local fStroke = Instance.new("UIStroke"); fStroke.Color = Color3.fromHex("#8B5CF6"); fStroke.Thickness = 2; fStroke.Parent = floatBtn

    local statsBox = Instance.new("Frame")
    statsBox.Size = UDim2.fromOffset(120, 45)
    statsBox.Position = UDim2.new(0, 75, 0, 20)
    statsBox.BackgroundColor3 = Color3.fromHex("#0A0710")
    statsBox.BorderSizePixel = 0
    statsBox.Parent = floatGui
    local sCorner = Instance.new("UICorner"); sCorner.CornerRadius = UDim.new(0, 8); sCorner.Parent = statsBox
    local sStroke = Instance.new("UIStroke"); sStroke.Color = Color3.fromHex("#8B5CF6"); sStroke.Thickness = 1; sStroke.Transparency = 0.5; sStroke.Parent = statsBox

    local pingLabel = Instance.new("TextLabel")
    pingLabel.Size = UDim2.new(1, 0, 0.5, 0)
    pingLabel.Position = UDim2.new(0, 0, 0, 2)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Text = "Ping: 0 ms"
    pingLabel.TextColor3 = Color3.fromHex("#C4B5FD")
    pingLabel.Font = Enum.Font.GothamMedium
    pingLabel.TextSize = 12
    pingLabel.Parent = statsBox

    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(1, 0, 0.5, 0)
    fpsLabel.Position = UDim2.new(0, 0, 0.5, 0)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "FPS: 60"
    fpsLabel.TextColor3 = Color3.fromHex("#C4B5FD")
    fpsLabel.Font = Enum.Font.GothamMedium
    fpsLabel.TextSize = 12
    fpsLabel.Parent = statsBox

    -- Make Float Button Draggable
    local dragging, dragInput, dragStart, startPos
    local isDragging = false

    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = floatBtn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)
    
    floatBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and isDragging then
            local delta = input.Position - dragStart
            floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            statsBox.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X + 55, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Click Float Button to Restore UI
    local lastClick = 0
    floatBtn.MouseButton1Click:Connect(function()
        if tick() - lastClick < 0.2 then return end
        lastClick = tick()
        SetUIVisibility(true) -- Forces the main UI to show up and the float to hide
    end)

    -- Loop to update Ping and FPS (Optimized for 1-second updates)
    task.spawn(function()
        local frameCount = 0
        local lastTime = tick()
        
        RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
        end)

        while task.wait(1) do
            local currentTime = tick()
            local fps = math.floor(frameCount / (currentTime - lastTime))
            fpsLabel.Text = "FPS: " .. fps
            frameCount = 0
            lastTime = currentTime
            
            local pingVal = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
            pingLabel.Text = "Ping: " .. pingVal
        end
    end)
end)
