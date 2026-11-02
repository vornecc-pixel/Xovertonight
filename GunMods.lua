-- GunMods.lua
return function(Window, Library)
    local RunService = game:GetService("RunService")
    
    -- ANTI-CHEAT CLOAKING
    local safeGetGC = newcclosure(getgc)
    local safeSetReadonly = newcclosure(setreadonly)
    local safeRawSet = newcclosure(rawset)
    local safeRawGet = newcclosure(rawget)

    -- UI Setup (Obelus)
    local Tab = Window:tab({name = "Gun Mods"})
    local col1 = Tab:column({fill = true})
    local col2 = Tab:column({fill = true})
    
    local MasterSec = col1:section({name = "Master"})
    local TimingSec = col1:section({name = "Timing"})
    local SpreadSec = col1:section({name = "Spread & Rate"})
    
    local RecoilSec = col2:section({name = "Recoil & Bloom"})
    local SwaySec = col2:section({name = "Sway"})
    local KickSec = col2:section({name = "Kick"})
    
    -- Config
    local Mods = {
        Enabled = false, InstantEquip = false, EquipTime = 0.001,
        InstantAds = false, AdsTime = 0.001, NoSpread = false,
        Rate = 0.05, ForceAuto = true, Spread = 0, AdsSpread = 0, MoveSpread = 0,
        NoRecoil = false, VisualBloom = 0, RecoilClimb = 0, ShakeMax = 0,
        NoSway = false, Sway = 0, SwayMax = 0, BobWalk = 0, BobIdle = 0, Lean = 0,
        KickPitch = 0, KickBack = 0
    }
    
    local TIMING_KEYS = { "EQUIP_TIME", "HOLSTER_TIME", "AdsTime", "AdsOutTime", "adsTime" }
    local activeStates, tracked = {}, {}

    -- TOGGLE FIX: Track original values before modifying
    local function track(tbl, key)
        if not tracked[tbl] then tracked[tbl] = {} end
        if tracked[tbl][key] == nil then tracked[tbl][key] = safeRawGet(tbl, key) end
    end
    
    -- TOGGLE FIX: Restore original values when disabled
    local function restoreAll()
        for tbl, keys in pairs(tracked) do
            pcall(safeSetReadonly, tbl, false)
            for k, v in pairs(keys) do pcall(safeRawSet, tbl, k, v) end
        end
        table.clear(tracked)
    end

    -- GC Scanner
    task.spawn(function()
        while task.wait(1) do
            if Mods.Enabled and safeGetGC then
                local found = {}
                for _, tbl in pairs(safeGetGC(true)) do
                    if type(tbl) == "table" then
                        pcall(safeSetReadonly, tbl, false)
                        
                        -- Timing
                        if Mods.InstantEquip or Mods.InstantAds then
                            for _, k in ipairs(TIMING_KEYS) do
                                if safeRawGet(tbl, k) ~= nil then
                                    if k == "AdsTime" or k == "AdsOutTime" or k == "adsTime" then
                                        if Mods.InstantAds then track(tbl, k); safeRawSet(tbl, k, Mods.AdsTime) end
                                    else
                                        if Mods.InstantEquip then track(tbl, k); safeRawSet(tbl, k, Mods.EquipTime) end
                                    end
                                end
                            end
                        end
                        
                        -- Spread
                        if Mods.NoSpread and safeRawGet(tbl, "rate") ~= nil then
                            track(tbl, "rate"); track(tbl, "auto")
                            track(tbl, "spread"); track(tbl, "adsSpread"); track(tbl, "moveSpread")
                            safeRawSet(tbl, "rate", Mods.Rate); safeRawSet(tbl, "auto", Mods.ForceAuto)
                            safeRawSet(tbl, "spread", Mods.Spread); safeRawSet(tbl, "adsSpread", Mods.AdsSpread); safeRawSet(tbl, "moveSpread", Mods.MoveSpread)
                        end
                        
                        -- Recoil
                        if Mods.NoRecoil and safeRawGet(tbl, "VisualBloom") ~= nil then
                            track(tbl, "VisualBloom"); track(tbl, "MOVE_SPREAD"); track(tbl, "AirSpread")
                            track(tbl, "RecoilClimb"); track(tbl, "ShakeMax"); track(tbl, "AdsMoveMult"); track(tbl, "AimRun")
                            safeRawSet(tbl, "VisualBloom", Mods.VisualBloom); safeRawSet(tbl, "MOVE_SPREAD", 0); safeRawSet(tbl, "AirSpread", 0)
                            safeRawSet(tbl, "RecoilClimb", Mods.RecoilClimb); safeRawSet(tbl, "ShakeMax", Mods.ShakeMax)
                            safeRawSet(tbl, "AdsMoveMult", 1); safeRawSet(tbl, "AimRun", 1)
                        end
                        
                        -- Sway
                        if Mods.NoSway and safeRawGet(tbl, "SWAY_MAX") ~= nil then
                            track(tbl, "KICK_PITCH"); track(tbl, "KICK_BACK"); track(tbl, "SWAY")
                            track(tbl, "SWAY_MAX"); track(tbl, "BOB_WALK"); track(tbl, "BOB_IDLE"); track(tbl, "LEAN")
                            safeRawSet(tbl, "KICK_PITCH", Mods.KickPitch); safeRawSet(tbl, "KICK_BACK", Mods.KickBack)
                            safeRawSet(tbl, "SWAY", Mods.Sway); safeRawSet(tbl, "SWAY_MAX", Mods.SwayMax)
                            safeRawSet(tbl, "BOB_WALK", Mods.BobWalk); safeRawSet(tbl, "BOB_IDLE", Mods.BobIdle); safeRawSet(tbl, "LEAN", Mods.Lean)
                        end
                        
                        -- Active Gun State
                        if safeRawGet(tbl, "SpreadPx") ~= nil and safeRawGet(tbl, "equipAt") ~= nil then
                            table.insert(found, tbl)
                        end
                    end
                end
                activeStates = found
            else
                -- If turned off, restore original values
                if next(tracked) then restoreAll() end
            end
        end
    end)

    -- Frame Enforcer
    RunService.RenderStepped:Connect(function()
        if not Mods.Enabled then activeStates = {} return end
        for _, state in ipairs(activeStates) do
            if state.equipAt and state.equipAt ~= -math.huge then state.equipAt = -math.huge end
            state.SpreadPx = 0; state.kick = 0; state.kickV = 0; state.kickPitch = 0; state.kickRoll = 0
            state.recoil = 0; state.recoilYaw = 0; state.RecoilPend = 0; state.RecoilYawPend = 0
            state.shakeUntil = 0; state.shakeStrength = 0
        end
    end)

    -- UI Config
    MasterSec:addToggle({name = "Enable Gun Mods", flag = "G_Enable", callback = function(s) Mods.Enabled = s end})
    
    TimingSec:addToggle({name = "Instant Equip", flag = "G_InstEquip", callback = function(s) Mods.InstantEquip = s end})
    TimingSec:addSlider({name = "Equip Time", min = 0.001, max = 1, default = 0.001, interval = 0.001, flag = "G_EquipTime", callback = function(v) Mods.EquipTime = v end})
    TimingSec:addToggle({name = "Instant ADS", flag = "G_InstAds", callback = function(s) Mods.InstantAds = s end})
    TimingSec:addSlider({name = "ADS Time", min = 0.001, max = 1, default = 0.001, interval = 0.001, flag = "G_AdsTime", callback = function(v) Mods.AdsTime = v end})
    
    SpreadSec:addToggle({name = "No Spread", flag = "G_NoSpread", callback = function(s) Mods.NoSpread = s end})
    SpreadSec:addSlider({name = "Fire Rate", min = 0.01, max = 1, default = 0.05, interval = 0.01, flag = "G_Rate", callback = function(v) Mods.Rate = v end})
    SpreadSec:addToggle({name = "Force Auto", flag = "G_ForceAuto", default = true, callback = function(s) Mods.ForceAuto = s end})
    SpreadSec:addSlider({name = "Spread", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_Spread", callback = function(v) Mods.Spread = v end})
    
    RecoilSec:addToggle({name = "No Recoil", flag = "G_NoRecoil", callback = function(s) Mods.NoRecoil = s end})
    RecoilSec:addSlider({name = "Visual Bloom", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_Bloom", callback = function(v) Mods.VisualBloom = v end})
    RecoilSec:addSlider({name = "Recoil Climb", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_Climb", callback = function(v) Mods.RecoilClimb = v end})
    RecoilSec:addSlider({name = "Shake Max", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_Shake", callback = function(v) Mods.ShakeMax = v end})
    
    SwaySec:addToggle({name = "No Sway", flag = "G_NoSway", callback = function(s) Mods.NoSway = s end})
    SwaySec:addSlider({name = "Sway", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_Sway", callback = function(v) Mods.Sway = v end})
    SwaySec:addSlider({name = "Sway Max", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_SwayMax", callback = function(v) Mods.SwayMax = v end})
    SwaySec:addSlider({name = "Bob Walk", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_BobWalk", callback = function(v) Mods.BobWalk = v end})
    
    KickSec:addSlider({name = "Kick Pitch", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_KickPitch", callback = function(v) Mods.KickPitch = v end})
    KickSec:addSlider({name = "Kick Back", min = 0, max = 1, default = 0, interval = 0.01, flag = "G_KickBack", callback = function(v) Mods.KickBack = v end})
end
