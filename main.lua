-- main.lua
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- 1. Load the Cinematic Splash
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

-- 2. Define the checks (This simulates the hacker typing)
local checks = { 
    "Verifying Environment...", 
    "Bypassing Metatables...", 
    "Injecting Drawing API...", 
    "Cloaking Memory...", 
    "Ready." 
}

-- 3. Play the splash
showLoading(checks, function()
    
    -- 4. Load Abyss UI
    local Library = loadstring(game:HttpGet("https://abyss.best/assets/files/gayasf.ui2?key=5y1lxXSfWKhlQkSqhUuFyB8kPp8hsCau"))()
    
    -- 5. Apply Arceus X Theme
    Library:UpdateTheme({
        Accent = Color3.fromHex("#8A2BE2"),
        Outline = Color3.fromHex("#000000"),
        Inline = Color3.fromHex("#101018"),
        LightContrast = Color3.fromHex("#202030"),
        DarkContrast = Color3.fromHex("#080810"),
        Text = Color3.fromHex("#FFFFFF"),
        TextInactive = Color3.fromHex("#8888A0")
    })
    Library.Theme.Logo = Utility.AddImage("Abyss/Assets/UI/Arceus.png", "https://i.imgur.com/AGsU7mR.png")
    
    -- 6. Create Main Window
    local Window = Library.Window("Arceus X | Fust", Vector2.new(650, 600))
    Window.Watermark("Arceus X | Private")
    
    -- 7. Load Mods (Pass Window to them)
    local loadGunMods = loadstring(game:HttpGet(repoBase .. "GunMods.lua"))()
    local loadBowMods = loadstring(game:HttpGet(repoBase .. "BowMods.lua"))()
    loadGunMods(Window)
    loadBowMods(Window)

    -- 8. Configs / Unload Tab
    local ConfigTab = Window:Tab("Configurations")
    local DangerSec = ConfigTab:Section("Danger Zone", "Right")

    DangerSec:Button({
        Title = "Unload Everything",
        Callback = function()
            -- Smooth Fade Out
            for _, val in pairs(Library.Drawings) do
                if val[1] then
                    task.spawn(function()
                        for i = 0, 1, 0.1 do
                            pcall(function() val[1].Transparency = i end)
                            task.wait(0.02)
                        end
                    end)
                end
            end
            
            task.wait(0.8) -- Wait for fade
            
            -- Cleanup Globals
            getgenv().Library = nil
            getgenv().Utility = nil
            
            Library:SelfDestruct()
        end
    })
end)
