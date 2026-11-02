-- main.lua
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

-- 1. Loading Screen
local checks = { "Verifying Environment...", "Bypassing Metatables...", "Injecting API...", "Cloaking Memory...", "Ready." }
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

showLoading(checks, function()
    -- 2. Load WindUI
    local success, WindUI = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)
    if not success or not WindUI then return warn("WindUI failed to load.") end
    
    -- 3. Apply Arceus X Theme
    local ArceusTheme = {
        Name = "ArceusX",
        Accent = WindUI:Gradient({ ["0"] = {Color = Color3.fromHex("#6D28D9"), Transparency = 0}, ["100"] = {Color = Color3.fromHex("#A855F7"), Transparency = 0} }, {Rotation = 45}),
        Dialog = Color3.fromHex("#150F23"),
        Outline = Color3.fromHex("#8B5CF6"),
        Text = Color3.fromHex("#F5F3FF"),
        Placeholder = Color3.fromHex("#7C6A9A"),
        Background = WindUI:Gradient({ ["0"] = {Color = Color3.fromHex("#0A0710"), Transparency = 0}, ["100"] = {Color = Color3.fromHex("#150F23"), Transparency = 0} }, {Rotation = 135}),
        BackgroundTransparency = 0,
        Button = WindUI:Gradient({ ["0"] = {Color = Color3.fromHex("#7C3AED"), Transparency = 0}, ["100"] = {Color = Color3.fromHex("#A855F7"), Transparency = 0} }, {Rotation = 45}),
        Toggle = WindUI:Gradient({ ["0"] = {Color = Color3.fromHex("#6D28D9"), Transparency = 0}, ["100"] = {Color = Color3.fromHex("#A855F7"), Transparency = 0} }, {Rotation = 45}),
        Slider = Color3.fromHex("#A855F7"),
        ElementBackground = WindUI:Gradient({ ["0"] = {Color = Color3.fromHex("#16101F"), Transparency = 0}, ["100"] = {Color = Color3.fromHex("#1E1730"), Transparency = 0} }, {Rotation = 90}),
        TabBackgroundActive = WindUI:Gradient({ ["0"] = {Color = Color3.fromHex("#2A1F42"), Transparency = 0.1}, ["100"] = {Color = Color3.fromHex("#3B2A5C"), Transparency = 0} }, {Rotation = 90}),
    }
    WindUI:AddTheme(ArceusTheme)
    WindUI:SetTheme("ArceusX")
    
    -- 4. Create Window
    local Window = WindUI:CreateWindow({
        Title     = "Arceus X | Fust",
        Author    = "Private",
        Folder    = "ArceusX",
        Size      = UDim2.fromOffset(580, 500),
        Theme     = "ArceusX",
        Transparent = true,
    })
    
    -- 5. Load Mods
    local loadGunMods = loadstring(game:HttpGet(repoBase .. "GunMods.lua"))()
    local loadBowMods = loadstring(game:HttpGet(repoBase .. "BowMods.lua"))()
    
    local unloadGunMods = loadGunMods(Window, WindUI)
    local unloadBowMods = loadBowMods(Window, WindUI)

    -- 6. Watermark System
    local WatermarkEnabled = false
    local ShowFPS = true
    local ShowPing = true
    local wmRunning = true
    
    local Watermark = Drawing.new("Text")
    Watermark.Font = Drawing.Fonts.Plex
    Watermark.Size = 16
    Watermark.Color = Color3.fromHex("#A855F7")
    Watermark.Position = Vector2.new(15, 15)
    Watermark.Visible = false
    Watermark.Outline = true

    local fpsCounter = 0
    local wmConnection = RunService.RenderStepped:Connect(function()
        if not wmRunning then return end
        if not WatermarkEnabled then Watermark.Visible = false return end
        Watermark.Visible = true
        fpsCounter = fpsCounter + 1
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        local txt = "Arceus X | Fust"
        if ShowFPS then txt = txt .. " | FPS: " .. fpsCounter end
        if ShowPing then txt = txt .. " | Ping: " .. ping .. "ms" end
        Watermark.Text = txt
    end)

    task.spawn(function()
        while wmRunning do task.wait(1); fpsCounter = 0 end
    end)

    -- 7. Settings Tab
    local Settings = Window:Tab({ Title = "Settings", Icon = "settings" })
    local uiSec = Settings:Section({ Title = "UI Settings", Opened = true })
    local configSec = Settings:Section({ Title = "Configs", Opened = true })
    local dangerSec = Settings:Section({ Title = "Danger Zone", Opened = true })
    
    if not isfolder("ArceusX") then makefolder("ArceusX") end
    if not isfolder("ArceusX/Configs") then makefolder("ArceusX/Configs") end

    -- WindUI Native Keybind (No more toggle bug!)
    uiSec:Keybind({ 
        Title = "Menu Toggle Key", 
        Value = Enum.KeyCode.RightShift, 
        Callback = function(key) 
            Window:SetToggleKey(key)
        end 
    })
    
    uiSec:Toggle({ Title = "Watermark", Value = false, Callback = function(bool) WatermarkEnabled = bool end })
    uiSec:Toggle({ Title = "Show FPS", Value = true, Callback = function(bool) ShowFPS = bool end })
    uiSec:Toggle({ Title = "Show Ping", Value = true, Callback = function(bool) ShowPing = bool end })

    -- Configs
    local configList = configSec:Dropdown({ Title = "Select Config", Values = {}, Callback = function() end })
    
    local function refreshConfigs()
        local list = {}
        if listfiles then
            for _, file in pairs(listfiles("ArceusX/Configs")) do
                table.insert(list, file:gsub(".cfg", ""))
            end
        end
        configList:Refresh(list)
    end
    refreshConfigs()

    configSec:Input({ Title = "Config Name", Value = "", Callback = function(txt) end })
    
    configSec:Button({ Title = "Create", Callback = function()
        local name = configSec.Elements[2].Value
        if name == "" then return end
        writefile("ArceusX/Configs/" .. name .. ".cfg", WindUI:GetConfig())
        refreshConfigs()
    end})

    configSec:Button({ Title = "Save", Callback = function()
        writefile("ArceusX/Configs/" .. configList.Value .. ".cfg", WindUI:GetConfig())
    end})

    configSec:Button({ Title = "Load", Callback = function()
        pcall(function()
            WindUI:LoadConfig(readfile("ArceusX/Configs/" .. configList.Value .. ".cfg"))
        end)
    end})

    configSec:Button({ Title = "Delete", Callback = function()
        delfile("ArceusX/Configs/" .. configList.Value .. ".cfg")
        refreshConfigs()
    end})

    -- 8. Unload Everything
    dangerSec:Button({ Title = "Unload Everything", Callback = function()
        wmRunning = false
        if wmConnection then wmConnection:Disconnect() end
        if Watermark then Watermark:Remove() end

        if unloadGunMods then pcall(unloadGunMods) end
        if unloadBowMods then pcall(unloadBowMods) end
        
        if Window and Window.Destroy then Window:Destroy() end
        
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        
        getgenv().Library = nil
        getgenv().Utility = nil
    end})
end)
