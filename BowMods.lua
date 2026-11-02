-- BowMods.lua
return function(Window, Library)
    local RunService = game:GetService("RunService")
    local newcclosure = (type(newcclosure) == "function") and newcclosure or function(f) return f end

    local safeGetGC = newcclosure(getgc)
    local safeSetReadonly = newcclosure(setreadonly)
    local safeRawSet = newcclosure(rawset)
    local safeRawGet = newcclosure(rawget)

    local Tab = Window:tab({name = "Bow Mods"})
    local col1 = Tab:column({fill = true})
    local col2 = Tab:column({fill = true})
    
    local MasterSec = col1:section({name = "Master"})
    local BowSec = col1:section({name = "Bow Tweaks"})
    local UniversalSec = col2:section({name = "Universal Bypass"})

    local Mods = { Enabled = false, InstantDraw = false, InstantReload = false, NoCooldown = false, NoRecoil = false, NoDrop = false }
    local Universal = { InfiniteAmmo = false, NoAirBlock = false }

    local activeBows, activeCrossbows, activeAmmo = {}, {}, {}
    local tracked = {}
    local uiToggles = {}
    local isRunning = true
    local connections = {}

    local u16Table, u16Blocked, u16Patched = nil, nil, false
    local bowSpecTable, originalBowSpec = nil, nil

    local cooldownProps = {"SHOT_GAP", "REDRAW_GAP", "MIN_DRAW"}
    local trembleProps = {"TREMBLE_MAX", "TREMBLE_AFTER", "SWAY", "SWAY_MAX"}
    local allProps = {}
    for _, list in ipairs({cooldownProps, trembleProps}) do
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
            local need = Mods.Enabled or Universal.InfiniteAmmo or Universal.NoAirBlock
            if isRunning and need and safeGetGC then
                local foundBows, foundXBows, foundAmmo = {}, {}, {}
                local count = 0
                
                for _, tbl in pairs(safeGetGC(true)) do
                    if type(tbl) == "table" then
                        count = count + 1
                        if count % 1000 == 0 then task.wait() end
                        
                        if Mods.Enabled and safeRawGet(tbl, "DRAW_TIME") and safeRawGet(tbl, "SHOT_GAP") then
                            if Mods.NoCooldown then
                                pcall(safeSetReadonly, tbl, false)
                                for _, p in ipairs(cooldownProps) do track(tbl, p) end
                                safeRawSet(tbl, "SHOT_GAP", 0); safeRawSet(tbl, "REDRAW_GAP", 0); safeRawSet(tbl, "MIN_DRAW", 0)
                            end
                        end
                        
                        if Mods.Enabled and safeRawGet(tbl, "drawStart") and safeRawGet(tbl, "lastShot") then
                            table.insert(foundBows, tbl)
                        end
                        
                        if Mods.Enabled and safeRawGet(tbl, "reloadLen") and safeRawGet(tbl, "xbow") then
                            table.insert(foundXBows, tbl)
                        end
                        
                        if Mods.Enabled and Mods.NoRecoil and safeRawGet(tbl, "TREMBLE_MAX") then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(trembleProps) do track(tbl, p) end
                            safeRawSet(tbl, "TREMBLE_MAX", 0); safeRawSet(tbl, "TREMBLE_AFTER", 9999); safeRawSet(tbl, "SWAY", 0); safeRawSet(tbl, "SWAY_MAX", 0)
                        end
                        
                        if Universal.InfiniteAmmo and safeRawGet(tbl, "counts") and safeRawGet(tbl, "pendingSpent") then
                            table.insert(foundAmmo, tbl)
                        end
                        
                        if Universal.NoAirBlock and type(safeRawGet(tbl, "blocked")) == "function" and safeRawGet(tbl, "gc") ~= nil then
                            u16Table = u16Table or tbl
                        end
                    end
                end

                if Universal.NoAirBlock and not u16Patched then
                    for _, fn in pairs(safeGetGC(true)) do
                        if type(fn) == "function" then
                            local ok, info = pcall(debug.getinfo, fn)
                            if ok and info.nups > 0 then
                                for i = 1, info.nups do
                                    local n, val = debug.getupvalue(fn, i)
                                    if n == "u16" and type(val) == "table" and safeRawGet(val, "blocked") == fn then
                                        u16Table = val; u16Blocked = fn; break
                                    end
                                end
                            end
                            if u16Table then break end
                        end
                    end
                    if u16Table and u16Blocked then
                        safeRawSet(u16Table, "blocked", newcclosure(function(now)
                            if Universal.NoAirBlock then return false end
                            return u16Blocked(now)
                        end))
                        u16Patched = true
                    end
                end

                activeBows, activeCrossbows, activeAmmo = foundBows, foundXBows, foundAmmo
            end
        end
    end)

    task.spawn(function()
        while isRunning do
            task.wait(2)
            if isRunning and not bowSpecTable and safeGetGC then
                for _, v in pairs(safeGetGC(true)) do
                    if type(v) == "table" and safeRawGet(v, "BowSpec") and safeRawGet(v, "Get") then
                        pcall(safeSetReadonly, v, false)
                        bowSpecTable = v
                        originalBowSpec = safeRawGet(v, "BowSpec")
                        safeRawSet(v, "BowSpec", function(def)
                            local spec = originalBowSpec(def)
                            if Mods.Enabled and Mods.NoDrop and type(spec) == "table" then
                                safeRawSet(spec, "gravity", 0)
                                safeRawSet(spec, "speedBase", 600)
                                safeRawSet(spec, "speedCharge", 600)
                            end
                            return spec
                        end)
                        break
                    end
                end
            end
        end
    end)

    table.insert(connections, RunService.RenderStepped:Connect(function()
        if not isRunning or not Mods.Enabled then activeBows, activeCrossbows = {}, {} return end
        for _, s in ipairs(activeBows) do
            if Mods.InstantDraw then s.drawStart = os.clock() - 10 end
            if Mods.NoCooldown then s.lastShot = -math.huge end
            if Mods.NoRecoil then s.shakeUntil = 0; s.shakeStrength = 0 end
        end
        for _, cb in ipairs(activeCrossbows) do
            if Mods.InstantReload then cb.loaded = true; cb.reloadAt = nil end
        end
    end))

    table.insert(connections, RunService.RenderStepped:Connect(function()
        if not isRunning or not Universal.InfiniteAmmo then activeAmmo = {} return end
        for _, s in ipairs(activeAmmo) do
            s.pendingSpent = 0
            local c = s.counts
            if type(c) == "table" then
                for k in pairs(c) do c[k] = 9999 end
                if type(s.bowDef) == "table" and type(s.bowDef.ammo) == "string" then
                    c[s.bowDef.ammo] = 9999
                end
            end
        end
    end))

    uiToggles.Master = MasterSec:addToggle({name = "Enable Bow Mods", flag = "B_Enable", callback = function(s) 
        Mods.Enabled = s
        if not s then
            Mods.InstantDraw = false; Mods.InstantReload = false; Mods.NoCooldown = false; Mods.NoRecoil = false; Mods.NoDrop = false
            if uiToggles.Draw and uiToggles.Draw.Set then uiToggles.Draw:Set(false) end
            if uiToggles.Reload and uiToggles.Reload.Set then uiToggles.Reload:Set(false) end
            if uiToggles.Cooldown and uiToggles.Cooldown.Set then uiToggles.Cooldown:Set(false) end
            if uiToggles.Recoil and uiToggles.Recoil.Set then uiToggles.Recoil:Set(false) end
            if uiToggles.Drop and uiToggles.Drop.Set then uiToggles.Drop:Set(false) end
            revertProperties(allProps)
        end
    end})
    
    uiToggles.Draw = BowSec:addToggle({name = "Instant Draw", flag = "B_InstantDraw", callback = function(s) Mods.InstantDraw = s end})
    uiToggles.Reload = BowSec:addToggle({name = "Instant Reload", flag = "B_InstantReload", callback = function(s) Mods.InstantReload = s end})
    uiToggles.Cooldown = BowSec:addToggle({name = "No Shot Cooldown", flag = "B_NoCooldown", callback = function(s) Mods.NoCooldown = s; if not s then revertProperties(cooldownProps) end end})
    uiToggles.Recoil = BowSec:addToggle({name = "No Recoil / Tremble", flag = "B_NoRecoil", callback = function(s) Mods.NoRecoil = s; if not s then revertProperties(trembleProps) end end})
    uiToggles.Drop = BowSec:addToggle({name = "No Drop", flag = "B_NoDrop", callback = function(s) Mods.NoDrop = s end})
    
    UniversalSec:addToggle({name = "Infinite Ammo", flag = "U_InfAmmo", callback = function(s) Universal.InfiniteAmmo = s end})
    UniversalSec:addToggle({name = "No Air Block", flag = "U_NoAirBlock", callback = function(s) Universal.NoAirBlock = s end})

    return function()
        isRunning = false
        for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
        revertProperties(allProps)
        if bowSpecTable and originalBowSpec then
            pcall(safeSetReadonly, bowSpecTable, false)
            pcall(safeRawSet, bowSpecTable, "BowSpec", originalBowSpec)
        end
        if u16Table and u16Blocked then
            pcall(safeSetReadonly, u16Table, false)
            pcall(safeRawSet, u16Table, "blocked", u16Blocked)
        end
    end
end
