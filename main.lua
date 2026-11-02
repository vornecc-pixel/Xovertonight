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
    
    -- Apply Arceus X Purple Theme
    library:updateTheme("accent", Color3.fromHex("#A855F7"))
    
    -- Create Window
    local window = library:window({
        name = 'Arceus X | <font color="rgb(168,85,247)">Fust</font>',
        size = dim2(0, 550, 0, 600)
    })
    
    -- Fix UI Rendering Over Roblox HUD (Inventory/Crafting)
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

    -- ============================================================
    -- MOUSE FREE / LOCK FIX
    -- ============================================================
    -- Save the original toggle function
    local original_toggle = window.toggle_menu
    
    -- Override it to handle the mouse state
    window.toggle_menu = function(self, state)
        if state == true then
            -- Menu is Opening: Free the mouse
            UserInputService.MouseIconEnabled = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        else
            -- Menu is Closing: Lock the mouse to center (so you can aim)
            UserInputService.MouseIconEnabled = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
        -- Call the original function to actually open/close the UI
        return original_toggle(self, state)
    end
    
    -- Set initial state (Menu starts open, so free the mouse)
    UserInputService.MouseIconEnabled = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    -- ============================================================

    -- 2. Load Mods
    local loadGunMods = loadstring(game:HttpGet(repoBase .. "GunMods.lua"))()
    local loadBowMods = loadstring(game:HttpGet(repoBase .. "BowMods.lua"))()
    
    loadGunMods(window, library)
    loadBowMods(window, library)

    -- 3. Watermark / FPS / Ping System (Drawing API)
    local WatermarkEnabled = false
    local ShowFPS = true
    local ShowPing = true
    
    local Watermark = Drawing.new("Text")
    Watermark.Font = Drawing.Fonts.Plex
    Watermark.Size = 16
    Watermark.Color = Color3.fromHex("#A855F7")
    Watermark.Position = Vector2.new(15, 15)
    Watermark.Visible = false
    Watermark.Outline = true

    local fpsCounter = 0
    RunService.RenderStepped:Connect(function()
        if not WatermarkEnabled then 
            Watermark.Visible = false 
            return 
        end
        Watermark.Visible = true
        
        fpsCounter = fpsCounter + 1
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        
        local txt = "Arceus X | Fust"
        if ShowFPS then txt = txt .. " | FPS: " .. fpsCounter end
        if ShowPing then txt = txt .. " | Ping: " .. ping .. "ms" end
        
        Watermark.Text = txt
    end)

    task.spawn(function()
        while task.wait(1) do
            fpsCounter = 0
        end
    end)

    -- 4. Settings Tab & Config System
    local Settings = window:tab({name = "Settings"})
    local col1 = Settings:column({fill = true})
    local col2 = Settings:column({fill = true})
    
    local configSec = col1:section({name = "Configs"})
    local uiSec = col2:section({name = "UI Settings"})
    local dangerSec = col2:section({name = "Danger Zone"})
    
    -- Directory Setup
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

    -- 5. UI Settings
    local enabled = true
    uiSec:addLabel({name = "Menu Toggle Keybind (Default: RightShift)"}):addKeyBind({
        flag = "UI_Toggle_Bind",
        callback = function(bool) 
            if window.is_closing_menu == false then enabled = not enabled end
            window:toggle_menu(enabled) -- We call our patched function here
        end
    })
    
    uiSec:addToggle({name = "Watermark", flag = "UI_Watermark", callback = function(bool)
        WatermarkEnabled = bool
    end})
    
    uiSec:addToggle({name = "Show FPS", default = true, flag = "UI_FPS", callback = function(bool)
        ShowFPS = bool
    end})
    
    uiSec:addToggle({name = "Show Ping", default = true, flag = "UI_Ping", callback = function(bool)
        ShowPing = bool
    end})

    -- 6. Unload Everything
    dangerSec:addButton({name = "Unload Everything", callback = function()
        library:unloadMenu()
        Watermark:Remove()
        getgenv().Library = nil
        getgenv().Utility = nil
        -- Restore mouse to normal when unloading
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        notifications:create_notification({name = "Successfully Unloaded."})
    end})

    notifications:create_notification({name = "Arceus X Loaded Successfully."})
end)
