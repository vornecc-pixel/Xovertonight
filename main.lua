-- main.lua
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local dim2 = UDim2.new 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

local checks = { 
    "Verifying Environment...", 
    "Bypassing Metatables...", 
    "Injecting Drawing API...", 
    "Cloaking Memory...", 
    "Ready." 
}

local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

showLoading(checks, function()
    -- 1. Load Obelus UI
    local library, notifications = loadstring(game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Obelus/Library.lua"))()
    
    library:updateTheme("accent", Color3.fromHex("#A855F7"))
    
    local window = library:window({
        name = 'Arceus X | <font color="rgb(168,85,247)">Fust</font>',
        size = dim2(0, 550, 0, 600)
    })
    
    -- Force UI over Roblox HUD
    task.spawn(function()
        task.wait(0.5)
        local gui = (gethui and gethui() or game:GetService("CoreGui"))
        for _, v in pairs(gui:GetDescendants()) do
            if v:IsA("ScreenGui") and string.find(v.Name, "Obelus") then
                v.DisplayOrder = 999999
                pcall(function() v.Parent = gui end)
            end
        end
    end)

    -- Mouse & Menu Toggle
    local menuOpen = true
    local original_toggle = window.toggle_menu
    window.toggle_menu = function(self, state)
        if state == nil then state = not menuOpen end
        if self.is_closing_menu then return end
        menuOpen = state
        
        if state == true then
            UserInputService.MouseIconEnabled = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        else
            UserInputService.MouseIconEnabled = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
        return original_toggle(self, state)
    end
    
    UserInputService.MouseIconEnabled = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    -- 2. Load Mods
    local loadGunMods = loadstring(game:HttpGet(repoBase .. "GunMods.lua"))()
    local loadBowMods = loadstring(game:HttpGet(repoBase .. "BowMods.lua"))()
    
    local unloadGunMods = loadGunMods(window, library)
    local unloadBowMods = loadBowMods(window, library)

    -- 3. Watermark System
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
        while wmRunning do
            task.wait(1)
            fpsCounter = 0
        end
    end)

    -- 4. Settings Tab
    local Settings = window:tab({name = "Settings"})
    local col1 = Settings:column({fill = true})
    local col2 = Settings:column({fill = true})
    
    local configSec = col1:section({name = "Configs"})
    local uiSec = col2:section({name = "UI Settings"})
    local dangerSec = col2:section({name = "Danger Zone"})
    
    if not isfolder("ArceusX") then makefolder("ArceusX") end
    if not isfolder("ArceusX/Configs") then makefolder("ArceusX/Configs") end

    local config_holder = configSec:addList({name = "Configs", flag = "config_name_list", scale = 100})
    configSec:addTextBox({name = "Config Name", default = "", flag = "config_name_text_box"})
    
    configSec:addButton({name = "Create", callback = function()
        if flags["config_name_text_box"] == "" then return end 
        writefile("ArceusX/Configs/" .. flags["config_name_text_box"] .. ".cfg", library:getConfig())
        library:configListUpdate()
        notifications:create_notification({name = "Config Created."})
    end})

    configSec:addButton({name = "Delete", callback = function()
        delfile("ArceusX/Configs/" .. flags["config_name_list"] .. ".cfg")
        library:configListUpdate()
        notifications:create_notification({name = "Config Deleted."})
    end})

    configSec:addButton({name = "Load", callback = function()
        pcall(function()
            library:loadConfig(readfile("ArceusX/Configs/" .. flags["config_name_list"] .. ".cfg"))
            notifications:create_notification({name = "Config Loaded."})
        end)
    end})
    
    configSec:addButton({name = "Save", callback = function()
        writefile("ArceusX/Configs/" .. flags["config_name_list"] .. ".cfg", library:getConfig())
        notifications:create_notification({name = "Config Saved."})
    end})

    configSec:addButton({name = "Refresh Configs", callback = function()
        library:configListUpdate()
    end}); library:configListUpdate()

    uiSec:addLabel({name = "Menu Toggle Keybind"}):addKeyBind({
        flag = "UI_Toggle_Bind",
        callback = function() window:toggle_menu(not menuOpen) end
    })
    
    uiSec:addToggle({name = "Watermark", flag = "UI_Watermark", callback = function(bool) WatermarkEnabled = bool end})
    uiSec:addToggle({name = "Show FPS", default = true, flag = "UI_FPS", callback = function(bool) ShowFPS = bool end})
    uiSec:addToggle({name = "Show Ping", default = true, flag = "UI_Ping", callback = function(bool) ShowPing = bool end})

    -- ============================================================
    -- 6. BULLETPROOF UNLOAD EVERYTHING
    -- ============================================================
    dangerSec:addButton({name = "Unload Everything", callback = function()
        -- 1. Stop Watermark Loops
        wmRunning = false
        if wmConnection then wmConnection:Disconnect() end
        if Watermark then Watermark:Remove() end

        -- 2. Unload Mods (Breaks loops & reverts memory)
        if unloadGunMods then pcall(unloadGunMods) end
        if unloadBowMods then pcall(unloadBowMods) end
        
        -- 3. Unload UI Library
        pcall(function() library:unloadMenu() end)
        
        -- 4. Force Delete Remaining UI Elements
        local gui = (gethui and gethui() or game:GetService("CoreGui"))
        for _, v in pairs(gui:GetDescendants()) do
            if v:IsA("ScreenGui") and (string.find(v.Name, "Obelus") or v.Name == "ObelusUI") then
                pcall(function() v:Destroy() end)
            end
        end
        
        -- 5. Restore Mouse
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        
        -- 6. Clear Globals
        getgenv().Library = nil
        getgenv().Utility = nil
        
        notifications:create_notification({name = "Successfully Unloaded Everything."})
    end})

    notifications:create_notification({name = "Arceus X Loaded Successfully."})
end)
