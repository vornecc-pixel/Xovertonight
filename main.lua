-- main.lua
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local dim2 = UDim2.new 

-- 1. Define the hacker typing checks
local checks = { 
    "Verifying Environment...", 
    "Bypassing Metatables...", 
    "Injecting Drawing API...", 
    "Cloaking Memory...", 
    "Ready." 
}

-- 2. Load the Cinematic Splash Screen
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

-- 3. Play the splash. When finished, run the callback.
showLoading(checks, function()
    
    -- 4. Load the Obelus UI Library
    local library, notifications = loadstring(game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Obelus/Library.lua"))()
    
    -- 5. Apply Arceus X Theme (Purple Accent)
    library:updateTheme("accent", Color3.fromHex("#A855F7"))
    
    -- 6. Create Main Window
    local window = library:window({
        name = 'Arceus X | <font color="rgb(168,85,247)">Fust</font>',
        size = dim2(0, 550, 0, 600)
    })
    
    -- 7. Load Mods from GitHub
    local loadGunMods = loadstring(game:HttpGet(repoBase .. "GunMods.lua"))()
    local loadBowMods = loadstring(game:HttpGet(repoBase .. "BowMods.lua"))()
    
    loadGunMods(window, library)
    loadBowMods(window, library)

    -- 8. Configs / Unload Tab
    local Settings = window:tab({name = "Settings"})
    local column = Settings:column({fill = true})
    
    local general = column:section({name = "Configs"})
    general:addButton({name = "Unload Everything", callback = function()
        -- Unload Menu
        library:unloadMenu()
        
        -- Cleanup Globals (Anti-Cheat evasion)
        getgenv().Library = nil
        getgenv().Utility = nil
        
        -- Optional: Re-enable mouse if it was disabled
        game:GetService("UserInputService").MouseIconEnabled = true
        
        notifications:create_notification({name = "Successfully Unloaded."})
    end})
    
    -- Optional: Menu Toggle Keybind
    local enabled = true
    general:addLabel({name = "Menu Bind"}):addKeyBind({callback = function() 
        if window.is_closing_menu == false then 
            enabled = not enabled
        end
        window.toggle_menu(enabled)
    end})
    
    -- Success Notification
    notifications:create_notification({name = "Arceus X Loaded Successfully."})
end)
