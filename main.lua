-- ============================================================
-- Arceus X | Fust (Full Source - WindUI + New Mods)
-- ============================================================
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Stats        = game:GetService("Stats")
local LP           = Players.LocalPlayer

-- 1. LOADING SCREEN
local checks = { "Verifying Environment...", "Bypassing Metatables...", "Injecting API...", "Cloaking Memory...", "Ready." }
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

showLoading(checks, function()
    -- 2. LOAD WINDUI
    local success, WindUI = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)
    if not success or not WindUI then return warn("[TWKS] WindUI load failed.") end

    -- 3. CREATE WINDOW (Arceus Theme)
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

    local Window = WindUI:CreateWindow({
        Title     = "anti-externa.wtf",
        Subtitle  = "anti-externa.wtf",
        Icon      = "crosshair",
        Author    = "TWKS",
        Folder    = "anti-externa.wtf",
        Size      = UDim2.fromOffset(580, 490),
        Theme     = "ArceusX",
        OpenButton = {
            Title           = "anti-externa.wtf",
            Enabled         = true,
            OnlyMobile      = false,
            CornerRadius    = UDim.new(1, 0),
            StrokeThickness = 2,
            Image           = "rbxassetid://75808871796479",
        },
    })

    local ESPTab     = Window:Tab({ Title = "ESP",      Icon = "eye" })
    local GunModsTab = Window:Tab({ Title = "Gun Mods", Icon = "crosshair" })
    local MiscTab    = Window:Tab({ Title = "Misc",     Icon = "settings" })

    -- AC METATABLE PROTECTION
    local safeGetGC = newcclosure(getgc)
    local safeSetReadonly = newcclosure(setreadonly)
    local safeRawSet = newcclosure(rawset)
    local safeRawGet = newcclosure(rawget)

    local isRunning = true
    local connections = {}

    -- ============================================================
    -- HITLOG MINI GUI
    -- ============================================================
    local HitLogGui = Instance.new("ScreenGui")
    HitLogGui.Name = "HitLogMini"
    HitLogGui.ResetOnSpawn = false
    HitLogGui.IgnoreGuiInset = true
    HitLogGui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")

    local HitLogFrame = Instance.new("Frame")
    HitLogFrame.Size = UDim2.fromOffset(220, 150)
    HitLogFrame.Position = UDim2.fromOffset(10, 10)
    HitLogFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    HitLogFrame.BackgroundTransparency = 0.3
    HitLogFrame.BorderSizePixel = 0
    HitLogFrame.Active = true
    HitLogFrame.Parent = HitLogGui
    Instance.new("UICorner", HitLogFrame).CornerRadius = UDim.new(0, 4)
    local stroke = Instance.new("UIStroke", HitLogFrame)
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1

    local HitLogTitle = Instance.new("TextLabel")
    HitLogTitle.Size = UDim2.new(1, 0, 0, 20)
    HitLogTitle.BackgroundTransparency = 1
    HitLogTitle.Text = "HIT LOG (Drag me)"
    HitLogTitle.Font = Enum.Font.GothamBold
    HitLogTitle.TextSize = 11
    HitLogTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    HitLogTitle.Parent = HitLogFrame

    local HitLogContainer = Instance.new("ScrollingFrame")
    HitLogContainer.Size = UDim2.new(1, -8, 1, -24)
    HitLogContainer.Position = UDim2.fromOffset(4, 22)
    HitLogContainer.BackgroundTransparency = 1
    HitLogContainer.BorderSizePixel = 0
    HitLogContainer.ScrollBarThickness = 2
    HitLogContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    HitLogContainer.CanvasSize = UDim2.new()
    HitLogContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    HitLogContainer.Parent = HitLogFrame
    local listLayout = Instance.new("UIListLayout", HitLogContainer)
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local draggingHitLog, dragStartHitLog, startPosHitLog = false, nil, nil
    HitLogTitle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingHitLog = true; dragStartHitLog = input.Position; startPosHitLog = HitLogFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then draggingHitLog = false end
            end)
        end
    end)
    table.insert(connections, UIS.InputChanged:Connect(function(input)
        if draggingHitLog and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStartHitLog
            HitLogFrame.Position = UDim2.new(startPosHitLog.X.Scale, startPosHitLog.X.Offset + d.X, startPosHitLog.Y.Scale, startPosHitLog.Y.Offset + d.Y)
        end
    end))

    local function AddLog(text, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 14)
        l.BackgroundTransparency = 1
        l.Text = text
        l.Font = Enum.Font.GothamMedium
        l.TextSize = 10
        l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = HitLogContainer
        task.delay(5, function() if l and l.Parent then l:Destroy() end end)
    end

    -- ============================================================
    -- HIT SOUND
    -- ============================================================
    local HitSound = { Enabled = false, Id = "rbxassetid://112396157430651", SoundObject = nil }
    do
        local s = Instance.new("Sound")
        s.SoundId  = HitSound.Id
        s.Volume   = 2
        s.Parent   = SoundService
        HitSound.SoundObject = s
    end

    -- ============================================================
    -- DAMAGE TRACKER
    -- ============================================================
    local lastHealth = {}

    local function trackDamage(plr)
        local char = plr.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        lastHealth[plr] = hum.Health
        table.insert(connections, hum:GetPropertyChangedSignal("Health"):Connect(function()
            local old = lastHealth[plr] or hum.Health
            local new = hum.Health
            local dmg = math.floor(old - new)
            if dmg <= 0 then lastHealth[plr] = new; return end
            local dist = 0
            if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("HumanoidRootPart") then
                dist = math.floor((LP.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude)
            end
            if plr == LP then
                AddLog(string.format("[ME] -%d HP (%d/%d)", dmg, math.floor(new), math.floor(hum.MaxHealth)), Color3.fromRGB(60, 255, 100))
            else
                AddLog(string.format("%s [%dm] -%d HP (%d/%d)", plr.Name, dist, dmg, math.floor(new), math.floor(hum.MaxHealth)), Color3.fromRGB(255, 60, 60))
                if HitSound.Enabled and HitSound.SoundObject then HitSound.SoundObject:Play() end
            end
            lastHealth[plr] = new
        end))
    end

    for _, p in ipairs(Players:GetPlayers()) do
        trackDamage(p)
        table.insert(connections, p.CharacterAdded:Connect(function() task.wait(1) trackDamage(p) end))
    end
    table.insert(connections, Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function() task.wait(1) trackDamage(p) end)
    end))

    -- ============================================================
    -- ESP
    -- ============================================================
    local ESP = {
        Enabled = false, Color = Color3.fromRGB(255, 60, 60),
        ShowName = true, ShowDistance = true, ShowHealth = true, MaxDistance = 2000,
    }
    local espObjects = {}

    local function clearESP(plr)
        local o = espObjects[plr]
        if not o then return end
        for _, d in pairs(o) do
            if typeof(d) == "userdata" and d.Remove then pcall(d.Remove, d) end
        end
        if o.bb then o.bb:Destroy() end
        if o.highlight then o.highlight:Destroy() end
        espObjects[plr] = nil
    end

    local function buildESP(plr)
        if plr == LP then return end
        local char = plr.Character
        if not char then return end
        local hrp, head = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not head or not hum or hum.Health <= 0 then return end
        clearESP(plr)

        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromOffset(200, 40)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0, 14)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextStrokeTransparency = 0
        nameLbl.Parent = bb

        local distLbl = Instance.new("TextLabel")
        distLbl.Size = UDim2.new(1, 0, 0, 12)
        distLbl.Position = UDim2.new(0, 0, 0, 14)
        distLbl.BackgroundTransparency = 1
        distLbl.Font = Enum.Font.GothamMedium
        distLbl.TextSize = 11
        distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        distLbl.TextStrokeTransparency = 0
        distLbl.Parent = bb

        local hl = Instance.new("Highlight")
        hl.Adornee = char
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 1
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char

        local lines = {
            top = Drawing.new("Line"), bottom = Drawing.new("Line"), left = Drawing.new("Line"), right = Drawing.new("Line"), hpBg = Drawing.new("Line"), hpFill = Drawing.new("Line"),
        }
        for _, l in pairs(lines) do l.Thickness = 1; l.Visible = false end
        lines.hpBg.Thickness = 2; lines.hpFill.Thickness = 2

        espObjects[plr] = { bb = bb, nameLbl = nameLbl, distLbl = distLbl, highlight = hl, lines = lines }
    end

    local function refreshESP()
        local cam = workspace.CurrentCamera
        for plr, o in pairs(espObjects) do
            local char, hum = plr.Character, plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            local hrp, head = char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChild("Head")
            if not (char and hum and hum.Health > 0 and hrp and head) then
                clearESP(plr)
            else
                local dist = 0
                if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                    dist = (LP.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                end

                if dist > ESP.MaxDistance then
                    o.bb.Enabled = false; o.highlight.Enabled = false
                    for _, l in pairs(o.lines) do l.Visible = false end
                else
                    o.bb.Enabled = true; o.highlight.Enabled = true; o.highlight.FillColor = ESP.Color
                    o.nameLbl.Visible = ESP.ShowName; o.nameLbl.Text = plr.Name
                    if ESP.ShowDistance then o.distLbl.Visible = true; o.distLbl.Text = string.format("[%dm]", math.floor(dist)) else o.distLbl.Visible = false end

                    local hrpPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos  = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

                    if onScreen then
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width  = height / 2
                        local x, y = hrpPos.X - width / 2, headPos.Y
                        o.lines.top.From = Vector2.new(x, y); o.lines.top.To = Vector2.new(x + width, y)
                        o.lines.bottom.From = Vector2.new(x, y + height); o.lines.bottom.To = Vector2.new(x + width, y + height)
                        o.lines.left.From = Vector2.new(x, y); o.lines.left.To = Vector2.new(x, y + height)
                        o.lines.right.From = Vector2.new(x + width, y); o.lines.right.To = Vector2.new(x + width, y + height)
                        for _, l in pairs({o.lines.top, o.lines.bottom, o.lines.left, o.lines.right}) do
                            l.Color = ESP.Color; l.Visible = true
                        end

                        if ESP.ShowHealth then
                            local hx = x - 4
                            local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            o.lines.hpBg.From = Vector2.new(hx, y); o.lines.hpBg.To = Vector2.new(hx, y + height); o.lines.hpBg.Color = Color3.fromRGB(20, 20, 20); o.lines.hpBg.Visible = true
                            o.lines.hpFill.From = Vector2.new(hx, y + (height - height * ratio)); o.lines.hpFill.To = Vector2.new(hx, y + height)
                            o.lines.hpFill.Color = ratio > 0.5 and Color3.fromRGB(60, 255, 100) or Color3.fromRGB(255, 220, 60):Lerp(Color3.fromRGB(255, 60, 60), 1 - ratio * 2)
                            o.lines.hpFill.Visible = true
                        else
                            o.lines.hpBg.Visible = false; o.lines.hpFill.Visible = false
                        end
                    else
                        for _, l in pairs(o.lines) do l.Visible = false end
                    end
                end
            end
        end
    end

    local function enableESP()
        ESP.Enabled = true
        for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end
    end
    local function disableESP()
        ESP.Enabled = false
        for plr in pairs(espObjects) do clearESP(plr) end
    end

    table.insert(connections, Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function() task.wait(0.5); if ESP.Enabled then buildESP(p) end end)
    end))
    table.insert(connections, Players.PlayerRemoving:Connect(function(p) clearESP(p) end))
    table.insert(connections, RunService.RenderStepped:Connect(function()
        if not ESP.Enabled then return end
        for plr in pairs(espObjects) do if not plr.Parent then clearESP(plr) end end
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and not espObjects[p] then buildESP(p) end end
        refreshESP()
    end))

    -- ============================================================
    -- NEW GUN MODS (LAG-FREE + REVERT FIX + AC SAFE)
    -- ============================================================
    local GunMasterSec = GunModsTab:Section({ Title = "Master", Opened = true })
    local GunTimingSec = GunModsTab:Section({ Title = "Timing", Opened = false })
    local GunSpreadSec = GunModsTab:Section({ Title = "Spread & Rate", Opened = false })
    local GunRecoilSec = GunModsTab:Section({ Title = "Recoil & Bloom", Opened = false })
    local GunSwaySec = GunModsTab:Section({ Title = "Sway", Opened = false })
    local GunKickSec = GunModsTab:Section({ Title = "Kick", Opened = false })
    
    local GunMods = {
        Enabled = false, InstantEquip = false, EquipTime = 0.001,
        InstantAds = false, AdsTime = 0.001, NoSpread = false,
        Rate = 0.05, ForceAuto = true, Spread = 0, AdsSpread = 0, MoveSpread = 0,
        NoRecoil = false, VisualBloom = 0, RecoilClimb = 0, ShakeMax = 0,
        NoSway = false, Sway = 0, SwayMax = 0, BobWalk = 0, BobIdle = 0, Lean = 0,
        KickPitch = 0, KickBack = 0
    }
    
    local activeGunStates, trackedGuns = {}, {}
    local gunToggles = {}

    local spreadProps = {"rate", "auto", "spread", "adsSpread", "moveSpread"}
    local recoilProps = {"VisualBloom", "MOVE_SPREAD", "AirSpread", "RecoilClimb", "ShakeMax", "AdsMoveMult", "AimRun"}
    local swayProps = {"KICK_PITCH", "KICK_BACK", "SWAY", "SWAY_MAX", "BOB_WALK", "BOB_IDLE", "LEAN"}
    local timingProps = {"EQUIP_TIME", "HOLSTER_TIME", "AdsTime", "AdsOutTime", "adsTime"}
    local allGunProps = {}

    for _, list in ipairs({spreadProps, recoilProps, swayProps, timingProps}) do
        for _, p in ipairs(list) do table.insert(allGunProps, p) end
    end

    local function trackGun(tbl, key)
        if not trackedGuns[tbl] then trackedGuns[tbl] = {} end
        if trackedGuns[tbl][key] == nil then trackedGuns[tbl][key] = safeRawGet(tbl, key) end
    end
    
    local function revertGunProps(props)
        local toRemove = {}
        for tbl, keys in pairs(trackedGuns) do
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
        for _, tbl in ipairs(toRemove) do trackedGuns[tbl] = nil end
    end

    task.spawn(function()
        while isRunning do
            task.wait(2)
            if isRunning and GunMods.Enabled and safeGetGC then
                local found = {}
                local count = 0
                for _, tbl in pairs(safeGetGC(true)) do
                    if type(tbl) == "table" then
                        count = count + 1
                        if count % 1000 == 0 then task.wait() end 
                        
                        if safeRawGet(tbl, "SpreadPx") ~= nil and safeRawGet(tbl, "equipAt") ~= nil then
                            table.insert(found, tbl)
                        end

                        if GunMods.InstantEquip or GunMods.InstantAds then
                            for _, k in ipairs(timingProps) do
                                if safeRawGet(tbl, k) ~= nil then
                                    pcall(safeSetReadonly, tbl, false)
                                    if k == "AdsTime" or k == "AdsOutTime" or k == "adsTime" then
                                        if GunMods.InstantAds then trackGun(tbl, k); safeRawSet(tbl, k, GunMods.AdsTime) end
                                    else
                                        if GunMods.InstantEquip then trackGun(tbl, k); safeRawSet(tbl, k, GunMods.EquipTime) end
                                    end
                                end
                            end
                        end
                        
                        if GunMods.NoSpread and safeRawGet(tbl, "rate") ~= nil then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(spreadProps) do trackGun(tbl, p) end
                            safeRawSet(tbl, "rate", GunMods.Rate); safeRawSet(tbl, "auto", GunMods.ForceAuto)
                            safeRawSet(tbl, "spread", GunMods.Spread); safeRawSet(tbl, "adsSpread", GunMods.AdsSpread); safeRawSet(tbl, "moveSpread", GunMods.MoveSpread)
                        end
                        
                        if GunMods.NoRecoil and safeRawGet(tbl, "VisualBloom") ~= nil then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(recoilProps) do trackGun(tbl, p) end
                            safeRawSet(tbl, "VisualBloom", GunMods.VisualBloom); safeRawSet(tbl, "MOVE_SPREAD", 0); safeRawSet(tbl, "AirSpread", 0)
                            safeRawSet(tbl, "RecoilClimb", GunMods.RecoilClimb); safeRawSet(tbl, "ShakeMax", GunMods.ShakeMax)
                            safeRawSet(tbl, "AdsMoveMult", 1); safeRawSet(tbl, "AimRun", 1)
                        end
                        
                        if GunMods.NoSway and safeRawGet(tbl, "SWAY_MAX") ~= nil then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(swayProps) do trackGun(tbl, p) end
                            safeRawSet(tbl, "KICK_PITCH", GunMods.KickPitch); safeRawSet(tbl, "KICK_BACK", GunMods.KickBack)
                            safeRawSet(tbl, "SWAY", GunMods.Sway); safeRawSet(tbl, "SWAY_MAX", GunMods.SwayMax)
                            safeRawSet(tbl, "BOB_WALK", GunMods.BobWalk); safeRawSet(tbl, "BOB_IDLE", GunMods.BobIdle); safeRawSet(tbl, "LEAN", GunMods.Lean)
                        end
                    end
                end
                activeGunStates = found
            end
        end
    end)

    table.insert(connections, RunService.RenderStepped:Connect(function()
        if not isRunning or not GunMods.Enabled then activeGunStates = {} return end
        for _, state in ipairs(activeGunStates) do
            if state.equipAt and state.equipAt ~= -math.huge then state.equipAt = -math.huge end
            state.SpreadPx = 0; state.kick = 0; state.kickV = 0; state.kickPitch = 0; state.kickRoll = 0
            state.recoil = 0; state.recoilYaw = 0; state.RecoilPend = 0; state.RecoilYawPend = 0
            state.shakeUntil = 0; state.shakeStrength = 0
        end
    end))

    -- ============================================================
    -- NEW BOW MODS (LAG-FREE + REVERT FIX + AC SAFE)
    -- ============================================================
    local BowMasterSec = GunModsTab:Section({ Title = "Bow Mods", Opened = false })
    
    local BowMods = { Enabled = false, InstantDraw = false, InstantReload = false, NoCooldown = false, NoRecoil = false, NoDrop = false }
    local Universal = { InfiniteAmmo = false, NoAirBlock = false }

    local activeBows, activeCrossbows, activeAmmo = {}, {}, {}
    local trackedBows = {}
    local bowToggles = {}
    local u16Table, u16Blocked, u16Patched = nil, nil, false
    local bowSpecTable, originalBowSpec = nil, nil

    local cooldownProps = {"SHOT_GAP", "REDRAW_GAP", "MIN_DRAW"}
    local trembleProps = {"TREMBLE_MAX", "TREMBLE_AFTER", "SWAY", "SWAY_MAX"}
    local allBowProps = {}
    for _, list in ipairs({cooldownProps, trembleProps}) do
        for _, p in ipairs(list) do table.insert(allBowProps, p) end
    end

    local function trackBow(tbl, key)
        if not trackedBows[tbl] then trackedBows[tbl] = {} end
        if trackedBows[tbl][key] == nil then trackedBows[tbl][key] = safeRawGet(tbl, key) end
    end
    
    local function revertBowProps(props)
        local toRemove = {}
        for tbl, keys in pairs(trackedBows) do
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
        for _, tbl in ipairs(toRemove) do trackedBows[tbl] = nil end
    end

    task.spawn(function()
        while isRunning do
            task.wait(2)
            local need = BowMods.Enabled or Universal.InfiniteAmmo or Universal.NoAirBlock
            if isRunning and need and safeGetGC then
                local foundBows, foundXBows, foundAmmo = {}, {}, {}
                local count = 0
                
                for _, tbl in pairs(safeGetGC(true)) do
                    if type(tbl) == "table" then
                        count = count + 1
                        if count % 1000 == 0 then task.wait() end
                        
                        if BowMods.Enabled and safeRawGet(tbl, "DRAW_TIME") and safeRawGet(tbl, "SHOT_GAP") then
                            if BowMods.NoCooldown then
                                pcall(safeSetReadonly, tbl, false)
                                for _, p in ipairs(cooldownProps) do trackBow(tbl, p) end
                                safeRawSet(tbl, "SHOT_GAP", 0); safeRawSet(tbl, "REDRAW_GAP", 0); safeRawSet(tbl, "MIN_DRAW", 0)
                            end
                        end
                        
                        if BowMods.Enabled and safeRawGet(tbl, "drawStart") and safeRawGet(tbl, "lastShot") then
                            table.insert(foundBows, tbl)
                        end
                        
                        if BowMods.Enabled and safeRawGet(tbl, "reloadLen") and safeRawGet(tbl, "xbow") then
                            table.insert(foundXBows, tbl)
                        end
                        
                        if BowMods.Enabled and BowMods.NoRecoil and safeRawGet(tbl, "TREMBLE_MAX") then
                            pcall(safeSetReadonly, tbl, false)
                            for _, p in ipairs(trembleProps) do trackBow(tbl, p) end
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
                            if BowMods.Enabled and BowMods.NoDrop and type(spec) == "table" then
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
        if not isRunning or not BowMods.Enabled then activeBows, activeCrossbows = {}, {} return end
        for _, s in ipairs(activeBows) do
            if BowMods.InstantDraw then s.drawStart = os.clock() - 10 end
            if BowMods.NoCooldown then s.lastShot = -math.huge end
            if BowMods.NoRecoil then s.shakeUntil = 0; s.shakeStrength = 0 end
        end
        for _, cb in ipairs(activeCrossbows) do
            if BowMods.InstantReload then cb.loaded = true; cb.reloadAt = nil end
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

    -- ============================================================
    -- UI: ESP & MODS TABS
    -- ============================================================
    ESPTab:Section({ Title = "ESP Settings", Opened = true })
    ESPTab:Toggle({ Title = "Enable ESP", Value = false, Callback = function(s) if s then enableESP() else disableESP() end end })
    ESPTab:Toggle({ Title = "Names", Value = true, Callback = function(s) ESP.ShowName = s end })
    ESPTab:Toggle({ Title = "Distance", Value = true, Callback = function(s) ESP.ShowDistance = s end })
    ESPTab:Toggle({ Title = "Health Bar", Value = true, Callback = function(s) ESP.ShowHealth = s end })
    ESPTab:Colorpicker({ Title = "ESP Color", Default = Color3.fromRGB(255, 60, 60), Callback = function(c) ESP.Color = c end })
    ESPTab:Slider({ Title = "ESP Max Distance", Value = { Min = 500, Max = 5000, Default = 2000 }, Step = 100, Callback = function(v) ESP.MaxDistance = v end })

    gunToggles.Master = GunMasterSec:Toggle({ Title = "Enable Gun Mods", Value = false, Callback = function(s) 
        GunMods.Enabled = s
        if not s then
            GunMods.NoSpread = false; GunMods.NoRecoil = false; GunMods.NoSway = false; GunMods.InstantEquip = false; GunMods.InstantAds = false
            if gunToggles.Spread then gunToggles.Spread:Set(false) end
            if gunToggles.Recoil then gunToggles.Recoil:Set(false) end
            if gunToggles.Sway then gunToggles.Sway:Set(false) end
            if gunToggles.InstEq then gunToggles.InstEq:Set(false) end
            if gunToggles.InstAds then gunToggles.InstAds:Set(false) end
            revertGunProps(allGunProps)
        end
    end})
    
    gunToggles.InstEq = GunTimingSec:Toggle({ Title = "Instant Equip", Value = false, Callback = function(s) GunMods.InstantEquip = s; if not s then revertGunProps({"EQUIP_TIME", "HOLSTER_TIME"}) end end})
    GunTimingSec:Slider({ Title = "Equip Time", Value = { Min = 0.001, Max = 1, Default = 0.001 }, Step = 0.001, Callback = function(v) GunMods.EquipTime = v end})
    gunToggles.InstAds = GunTimingSec:Toggle({ Title = "Instant ADS", Value = false, Callback = function(s) GunMods.InstantAds = s; if not s then revertGunProps({"AdsTime", "AdsOutTime", "adsTime"}) end end})
    GunTimingSec:Slider({ Title = "ADS Time", Value = { Min = 0.001, Max = 1, Default = 0.001 }, Step = 0.001, Callback = function(v) GunMods.AdsTime = v end})
    
    gunToggles.Spread = GunSpreadSec:Toggle({ Title = "No Spread", Value = false, Callback = function(s) GunMods.NoSpread = s; if not s then revertGunProps(spreadProps) end end})
    GunSpreadSec:Slider({ Title = "Fire Rate", Value = { Min = 0.01, Max = 1, Default = 0.05 }, Step = 0.01, Callback = function(v) GunMods.Rate = v end})
    GunSpreadSec:Toggle({ Title = "Force Auto", Value = true, Callback = function(s) GunMods.ForceAuto = s end})
    GunSpreadSec:Slider({ Title = "Spread", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.Spread = v end})
    
    gunToggles.Recoil = GunRecoilSec:Toggle({ Title = "No Recoil", Value = false, Callback = function(s) GunMods.NoRecoil = s; if not s then revertGunProps(recoilProps) end end})
    GunRecoilSec:Slider({ Title = "Visual Bloom", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.VisualBloom = v end})
    GunRecoilSec:Slider({ Title = "Recoil Climb", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.RecoilClimb = v end})
    GunRecoilSec:Slider({ Title = "Shake Max", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.ShakeMax = v end})
    
    gunToggles.Sway = GunSwaySec:Toggle({ Title = "No Sway", Value = false, Callback = function(s) GunMods.NoSway = s; if not s then revertGunProps(swayProps) end end})
    GunSwaySec:Slider({ Title = "Sway", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.Sway = v end})
    GunSwaySec:Slider({ Title = "Sway Max", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.SwayMax = v end})
    GunSwaySec:Slider({ Title = "Bob Walk", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.BobWalk = v end})
    
    GunKickSec:Slider({ Title = "Kick Pitch", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.KickPitch = v end})
    GunKickSec:Slider({ Title = "Kick Back", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.01, Callback = function(v) GunMods.KickBack = v end})

    bowToggles.Master = BowMasterSec:Toggle({ Title = "Enable Bow Mods", Value = false, Callback = function(s) 
        BowMods.Enabled = s
        if not s then
            BowMods.InstantDraw = false; BowMods.InstantReload = false; BowMods.NoCooldown = false; BowMods.NoRecoil = false; BowMods.NoDrop = false
            if bowToggles.Draw then bowToggles.Draw:Set(false) end
            if bowToggles.Reload then bowToggles.Reload:Set(false) end
            if bowToggles.Cooldown then bowToggles.Cooldown:Set(false) end
            if bowToggles.Recoil then bowToggles.Recoil:Set(false) end
            if bowToggles.Drop then bowToggles.Drop:Set(false) end
            revertBowProps(allBowProps)
        end
    end})
    
    bowToggles.Draw = BowMasterSec:Toggle({ Title = "Instant Draw", Value = false, Callback = function(s) BowMods.InstantDraw = s end})
    bowToggles.Reload = BowMasterSec:Toggle({ Title = "Instant Reload", Value = false, Callback = function(s) BowMods.InstantReload = s end})
    bowToggles.Cooldown = BowMasterSec:Toggle({ Title = "No Shot Cooldown", Value = false, Callback = function(s) BowMods.NoCooldown = s; if not s then revertBowProps(cooldownProps) end end})
    bowToggles.Recoil = BowMasterSec:Toggle({ Title = "No Recoil / Tremble", Value = false, Callback = function(s) BowMods.NoRecoil = s; if not s then revertBowProps(trembleProps) end end})
    bowToggles.Drop = BowMasterSec:Toggle({ Title = "No Drop", Value = false, Callback = function(s) BowMods.NoDrop = s end})
    
    BowMasterSec:Toggle({ Title = "Infinite Ammo", Value = false, Callback = function(s) Universal.InfiniteAmmo = s end})
    BowMasterSec:Toggle({ Title = "No Air Block", Value = false, Callback = function(s) Universal.NoAirBlock = s end})

    -- ============================================================
    -- MISC TAB & WATERMARK
    -- ============================================================
    MiscTab:Section({ Title = "Hit Sound", Opened = true })
    MiscTab:Toggle({ Title = "Enable Hit Sound", Value = false, Callback = function(s) HitSound.Enabled = s end })
    
    local WatermarkEnabled = false
    local ShowFPS = true
    local ShowPing = true
    local wmRunning = true
    local Watermark = Drawing.new("Text")
    Watermark.Font = Drawing.Fonts.Plex; Watermark.Size = 16; Watermark.Color = Color3.fromHex("#A855F7")
    Watermark.Position = Vector2.new(15, 15); Watermark.Visible = false; Watermark.Outline = true

    local fpsCounter = 0
    local wmConnection = RunService.RenderStepped:Connect(function()
        if not wmRunning then return end
        if not WatermarkEnabled then Watermark.Visible = false return end
        Watermark.Visible = true; fpsCounter = fpsCounter + 1
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        local txt = "Arceus X | Fust"
        if ShowFPS then txt = txt .. " | FPS: " .. fpsCounter end
        if ShowPing then txt = txt .. " | Ping: " .. ping .. "ms" end
        Watermark.Text = txt
    end)
    task.spawn(function() while wmRunning do task.wait(1); fpsCounter = 0 end end)

    MiscTab:Section({ Title = "UI Settings", Opened = true })
    MiscTab:Keybind({ Title = "Menu Toggle Key", Value = Enum.KeyCode.RightShift, Callback = function(key) Window:SetToggleKey(key) end })
    MiscTab:Toggle({ Title = "Watermark", Value = false, Callback = function(bool) WatermarkEnabled = bool end })
    MiscTab:Toggle({ Title = "Show FPS", Value = true, Callback = function(bool) ShowFPS = bool end })
    MiscTab:Toggle({ Title = "Show Ping", Value = true, Callback = function(bool) ShowPing = bool end })

    -- ============================================================
    -- UNLOAD EVERYTHING
    -- ============================================================
    MiscTab:Section({ Title = "Danger Zone", Opened = true })
    MiscTab:Button({ Title = "Unload Everything", Callback = function()
        isRunning = false
        wmRunning = false
        
        if wmConnection then wmConnection:Disconnect() end
        if Watermark then Watermark:Remove() end
        if HitLogGui then HitLogGui:Destroy() end
        if ESP.Enabled then disableESP() end

        revertGunProps(allGunProps)
        revertBowProps(allBowProps)
        
        if bowSpecTable and originalBowSpec then
            pcall(safeSetReadonly, bowSpecTable, false)
            pcall(safeRawSet, bowSpecTable, "BowSpec", originalBowSpec)
        end
        if u16Table and u16Blocked then
            pcall(safeSetReadonly, u16Table, false)
            pcall(safeRawSet, u16Table, "blocked", u16Blocked)
        end
        
        for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
        
        if Window and Window.Destroy then Window:Destroy() end
        UIS.MouseIconEnabled = true
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        getgenv().Library = nil
        getgenv().Utility = nil
    end})
end)
