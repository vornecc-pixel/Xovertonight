-- main.lua
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local dim2 = UDim2.new 

local checks = { 
    "Verifying Environment...", 
    "Bypassing Metatables...", 
    "Injecting Drawing API...", 
    "Cloaking Memory...", 
    "Ready." 
}

-- 1. Load the cinematic hacker screen
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

-- 2. Play splash, then load the UI and Mods
showLoading(checks, function()
    -- Load Obelus UI
    local library, notifications = loadstring(game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Obelus/Library.lua"))()
    
    -- Apply Arceus X Purple Theme
    library:updateTheme("accent", Color3.fromHex("#A855F7"))
    
    -- Create Window
    local window = library:window({
        name = 'Arceus X | <font color="rgb(168,85,247)">Fust</font>',
        size = dim2(0, 550, 0, 600)
    })
    
    -- Load the Mods and pass the Window to them
    local loadGunMods = loadstring(game:HttpGet(repoBase .. "GunMods.lua"))()
    local loadBowMods = loadstring(game:HttpGet(repoBase .. "BowMods.lua"))()
    
    loadGunMods(window, library)
    loadBowMods(window, library)

    -- Settings Tab
    local Settings = window:tab({name = "Settings"})
    local column = Settings:column({fill = true})
    local general = column:section({name = "Configs"})
    
    general:addButton({name = "Unload Everything", callback = function()
        library:unloadMenu()
        getgenv().Library = nil
        getgenv().Utility = nil
        game:GetService("UserInputService").MouseIconEnabled = true
        notifications:create_notification({name = "Successfully Unloaded."})
    end})
    
    notifications:create_notification({name = "Arceus X Loaded Successfully."})
end)
