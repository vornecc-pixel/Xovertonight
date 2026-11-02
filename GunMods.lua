-- GunMods.lua
return function(Window, WindUI)
    local RunService = game:GetService("RunService")
    
    -- AC METATABLE PROTECTION
    local safeGetGC = newcclosure(getgc)
    local safeSetReadonly = newcclosure(setreadonly)
    local safeRawSet = newcclosure(rawset)
    local safeRawGet = newcclosure(rawget)

    local Tab = Window:Tab({ Title = "Gun Mods", Icon = "crosshair" })
    local MasterSec = Tab:Section({ Title = "Master", Opened = true })
    local TimingSec = Tab:Section({ Title = "Timing", Opened = false })
    local SpreadSec = Tab:Section({ Title = "Spread & Rate", Opened = false })
    local RecoilSec = Tab:Section({ Title = "Recoil & Bloom", Opened = false })
    local SwaySec = Tab:Section({ Title = "Sway", Opened = false })
    
    local Mods = {
        Enabled = false, InstantEquip = false, EquipTime = 0.001,
        InstantAds = false, AdsTime = 0.001, NoSpread = false,
        Rate = 0.05, ForceAuto = true, Spread = 0, AdsSpread = 0, MoveSpread = 0,
        NoRecoil = false, VisualBloom = 0, RecoilClimb = 0, ShakeMax = 0,
        NoSway = false, Sway = 0, SwayMax = 0, BobWalk = 0, BobIdle = 0, Lean = 0
    }
    
    local activeStates, tracked = {}, {}
    local uiToggles = {}
    local isRunning = true
    local connections = {}

    local spreadProps = {"rate", "auto", "spread", "adsSpread", "moveSpread"}
    local recoilProps = {"VisualBloom", "MOVE_SPREAD", "AirSpread", "RecoilClimb", "ShakeMax", "AdsMoveMult", "AimRun"}
    local swayProps = {"KICK_PITCH", "KICK_BACK", "SWAY", "SWAY_MAX", "BOB_WALK", "BOB_IDLE", "LEAN"}
    local timingProps = {"EQUIP_TIME", "HOLSTER_TIME", "AdsTime", "AdsOutTime", "adsTime"}
    local allProps = {}

    for _, list in ipairs({spreadProps, recoilProps, swayProps, timingProps}) do
        for _, p in ipairs(list) do table.insert(allProps, p) end
    end

    local function track(tbl, key)
        if not tracked[tbl] then tracked[tbl] = {} end
        if tracked[tbl][key] == nil then tracked[tbl][key] = safeRawGet(tbl, key) end
    end
    
    local function revertProperties(props)
        local toRemove = {}
        for tbl, keys in pairs(tracked) do
            local empty = true
            pcall(safeSetReadonly, tbl, false)
            for _, prop in ipairs(props) do
                if keys[prop] ~= nil then
                    pcall(safeRawSet, tbl, prop, keys[prop])
                    keys[prop] = nil
                end
            end
            for _ in pairs(keys) do empty = false break end
            if empty then table.insert(toRemove, tbl) end
        end
        for _, tbl in ipairs(toRemove) do tracked[tbl] = nil end
    end

    task.spawn(function()
        while isRunning do
            task.wait(2)
            if isRunning and Mods.Enabled and safeGetGC then
                local found = {}
                local count = 0
                for _, tbl in pairs(safeGetGC(true)) do
                    if type(tbl) == "table" then
                        count = count + 1
                        if count % 1000 == 0 then task.wait() end 
                        
                        if safeRawGet(tbl, "SpreadPx") ~= nil and safeRawGet(tbl, "equipAt") ~= nil then
                            table.insert(found, tbl)
                        end

                        if Mods.InstantEquip or Mods.InstantAds then
                            for _, k in ipairs(timingProps) do
                                if safeRawGet(tbl, k) ~= nil then
                                    pcall(safeSetReadonly, tbl, false)
                                    if k == "AdsTime" or k == "AdsOutTime" or k == "adsTime" then
                                        if Mods.InstantAds then track(tbl, k); safeRawSet(tbl, k, Mods.AdsTime) end
                                    else
                                        if Mods.InstantEquip then track(tbl, k); safeRawSet(tbl, k, Mods.EquipTime) end
                                    end
                                end
                            end
                        end
                        
                        if Mods.NoSpread and safeRawGet(tbl, "rate") ~= nil then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(spreadProps) do track(tbl, p) end
                            safeRawSet(tbl, "rate", Mods.Rate); safeRawSet(tbl, "auto", Mods.ForceAuto)
                            safeRawSet(tbl, "spread", Mods.Spread); safeRawSet(tbl, "adsSpread", Mods.AdsSpread); safeRawSet(tbl, "moveSpread", Mods.MoveSpread)
                        end
                        
                        if Mods.NoRecoil and safeRawGet(tbl, "VisualBloom") ~= nil then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(recoilProps) do track(tbl, p) end
                            safeRawSet(tbl, "VisualBloom", Mods.VisualBloom); safeRawSet(tbl, "MOVE_SPREAD", 0); safeRawSet(tbl, "AirSpread", 0)
                            safeRawSet(tbl, "RecoilClimb", Mods.RecoilClimb); safeRawSet(tbl, "ShakeMax", Mods.ShakeMax)
                            safeRawSet(tbl, "AdsMoveMult", 1); safeRawSet(tbl, "AimRun", 1)
                        end
                        
                        if Mods.NoSway and safeRawGet(tbl, "SWAY_MAX") ~= nil then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(swayProps) do track(tbl, p) end
                            safeRawSet(tbl, "KICK_PITCH", Mods.KickPitch or 0); safeRawSet(tbl, "KICK_BACK", Mods.KickBack or 0)
                            safeRawSet(tbl, "SWAY", Mods.Sway); safeRawSet(tbl, "SWAY_MAX", Mods.SwayMax)
                            safeRawSet(tbl, "BOB_WALK", Mods.BobWalk); safeRawSet(tbl, "BOB_IDLE", Mods.BobIdle); safeRawSet(tbl, "LEAN", Mods.Lean)
                        end
                    end
                end
                activeStates = found
            end
        end
    end)

    table.insert(connections, RunService.RenderStepped:Connect(function()
        if not isRunning or not Mods.Enabled then activeStates = {} return end
        for _, state in ipairs(activeStates) do
            if state.equipAt and state.equipAt ~= -math.huge then state.equipAt = -math.huge end
            state.SpreadPx = 0; state.kick = 0; state.kickV = 0; state.kickPitch = 0; state.kickRoll = 0
            state.recoil = 0; state.recoilYaw = 0; state.RecoilPend = 0; state.RecoilYawPend = 0
            state.shakeUntil = 0; state.shakeStrength = 0
        end
    end))

    -- WindUI Syntax
    uiToggles.Master = MasterSec:Toggle({ Title = "Enable Gun Mods", Value = false, Callback = function(s) 
        Mods.Enabled = s
        if not s then
            Mods.NoSpread = false; Mods.NoRecoil = false; Mods.NoSway = false; Mods.InstantEquip = false; Mods.InstantAds = false
            if uiToggles.Spread then uiToggles.Spread:Set(false) end
            if uiToggles.Recoil then uiToggles.Recoil:Set(false) end
            if uiToggles.Sway then uiToggles.Sway:Set(false) end
            if uiToggles.InstEq then uiToggles.InstEq:Set(false) end
            if uiToggles.InstAds then uiToggles.InstAds:Set(false) end
            revertProperties(allProps)
        end
    end})
    
    uiToggles.InstEq = TimingSec:Toggle({ Title = "Instant Equip", Value = false, Callback = function(s) Mods.InstantEquip = s; if not s then revertProperties({"EQUIP_TIME", "HOLSTER_TIME"}) end end})
    TimingSec:Slider({ Title = "Equip Time", Value = { Min = 0.001, Max = 1, Default = 0.001 }, Step = 0.001, Callback = function(v) Mods.EquipTime = v end})
    
    uiToggles.InstAds = TimingSec:Toggle({ Title = "Instant ADS", Value = false, Callback = function(s) Mods.InstantAds = s; if not s then revertProperties({"AdsTime", "AdsOutTime", "adsTime"}) end end})
    TimingSec:Slider({ Title = "ADS Time", Value = { Min = 0.001, Max = 1, Default = 0.001 }, Step = 0.001, Callback = function(v) Mods.AdsTime = v end})
    
    uiToggles.Spread = SpreadSec:Toggle({ Title = "No Spread", Value = false, Callback = function(s) Mods.NoSpread = s; if not s then revertProperties(spreadProps) end end})
    SpreadSec:Slider({ Title = "Fire Rate", Value = { Min = 0.01, Max = 1, Default = 0.05 }, Step = 0.01, Callback = function(v) Mods.Rate = v end})
    SpreadSec:Toggle({ Title = "Force Auto", Value = true, Callback = function(s) Mods.ForceAuto = s end})
    SpreadSec:Slider({ Title = "Spread", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) Mods.Spread = v end})
    
    uiToggles.Recoil = RecoilSec:Toggle({ Title = "No Recoil", Value = false, Callback = function(s) Mods.NoRecoil = s; if not s then revertProperties(recoilProps) end end})
    RecoilSec:Slider({ Title = "Visual Bloom", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) Mods.VisualBloom = v end})
    RecoilSec:Slider({ Title = "Recoil Climb", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) Mods.RecoilClimb = v end})
    RecoilSec:Slider({ Title = "Shake Max", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) Mods.ShakeMax = v end})
    
    uiToggles.Sway = SwaySec:Toggle({ Title = "No Sway", Value = false, Callback = function(s) Mods.NoSway = s; if not s then revertProperties(swayProps) end end})
    SwaySec:Slider({ Title = "Sway", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) Mods.Sway = v end})
    SwaySec:Slider({ Title = "Sway Max", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) Mods.SwayMax = v end})
    SwaySec:Slider({ Title = "Bob Walk", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) Mods.BobWalk = v end})

    return function()
        isRunning = false
        for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
        revertProperties(allProps)
    end
end
