-- main.lua
local repoBase = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer

local checks = { "Verifying Environment...", "Bypassing Metatables...", "Injecting API...", "Cloaking Memory...", "Ready." }
local showLoading = loadstring(game:HttpGet(repoBase .. "LoadingScreen.lua"))()

showLoading(checks, function()
    -- 1. Load WindUI & Theme
    local success, WindUI = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)
    if not success or not WindUI then return warn("WindUI failed.") end
    
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
        Title = "Arceus X | Fust", Author = "Private", Folder = "ArceusX",
        Size = UDim2.fromOffset(580, 500), Theme = "ArceusX", Transparent = true,
    })
    
    local ESPTab = Window:Tab({ Title = "ESP", Icon = "eye" })
    local MiscTab = Window:Tab({ Title = "Misc", Icon = "settings" })
    local Settings = Window:Tab({ Title = "Settings", Icon = "settings" })

    -- ============================================================
    -- EXTRACTED ESP & HITLOG (From your old file)
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
    UIS.InputChanged:Connect(function(input)
        if draggingHitLog and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStartHitLog
            HitLogFrame.Position = UDim2.new(startPosHitLog.X.Scale, startPosHitLog.X.Offset + d.X, startPosHitLog.Y.Scale, startPosHitLog.Y.Offset + d.Y)
        end
    end)

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

    local HitSound = { Enabled = false, Id = "rbxassetid://112396157430651", SoundObject = nil }
    do
        local s = Instance.new("Sound")
        s.SoundId = HitSound.Id; s.Volume = 2; s.Parent = SoundService
        HitSound.SoundObject = s
    end

    local lastHealth = {}
    local function trackDamage(plr)
        local char = plr.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        lastHealth[plr] = hum.Health
        hum:GetPropertyChangedSignal("Health"):Connect(function()
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
        end)
    end
    for _, p in ipairs(Players:GetPlayers()) do trackDamage(p) p.CharacterAdded:Connect(function() task.wait(1) trackDamage(p) end) end
    Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(1) trackDamage(p) end) end)

    local ESP = { Enabled = false, Color = Color3.fromRGB(255, 60, 60), ShowName = true, ShowDistance = true, ShowHealth = true, MaxDistance = 2000 }
    local espObjects = {}

    local function clearESP(plr)
        local o = espObjects[plr]
        if not o then return end
        for _, d in pairs(o) do if typeof(d) == "userdata" and d.Remove then pcall(d.Remove, d) end end
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
        bb.Size = UDim2.fromOffset(200, 40); bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.AlwaysOnTop = true; bb.Parent = head

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0, 14); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11; nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255); nameLbl.TextStrokeTransparency = 0; nameLbl.Parent = bb

        local distLbl = Instance.new("TextLabel")
        distLbl.Size = UDim2.new(1, 0, 0, 12); distLbl.Position = UDim2.new(0, 0, 0, 14); distLbl.BackgroundTransparency = 1
        distLbl.Font = Enum.Font.GothamMedium; distLbl.TextSize = 11; distLbl.TextColor3 = Color3.fromRGB(200, 200, 200); distLbl.TextStrokeTransparency = 0; distLbl.Parent = bb

        local hl = Instance.new("Highlight")
        hl.Adornee = char; hl.FillTransparency = 0.3; hl.OutlineTransparency = 1; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = char

        local lines = { top = Drawing.new("Line"), bottom = Drawing.new("Line"), left = Drawing.new("Line"), right = Drawing.new("Line"), hpBg = Drawing.new("Line"), hpFill = Drawing.new("Line") }
        for _, l in pairs(lines) do l.Thickness = 1; l.Visible = false end
        lines.hpBg.Thickness = 2; lines.hpFill.Thickness = 2

        espObjects[plr] = { bb = bb, nameLbl = nameLbl, distLbl = distLbl, highlight = hl, lines = lines }
    end

    local function refreshESP()
        local cam = workspace.CurrentCamera
        for plr, o in pairs(espObjects) do
            local char, hum = plr.Character, plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            local hrp, head = char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChild("Head")
            if not (char and hum and hum.Health > 0 and hrp and head) then clearESP(plr) else
                local dist = 0
                if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then dist = (LP.Character.HumanoidRootPart.Position - hrp.Position).Magnitude end
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
                        local height = math.abs(headPos.Y - legPos.Y); local width  = height / 2
                        local x, y = hrpPos.X - width / 2, headPos.Y
                        o.lines.top.From = Vector2.new(x, y); o.lines.top.To = Vector2.new(x + width, y)
                        o.lines.bottom.From = Vector2.new(x, y + height); o.lines.bottom.To = Vector2.new(x + width, y + height)
                        o.lines.left.From = Vector2.new(x, y); o.lines.left.To = Vector2.new(x, y + height)
                        o.lines.right.From = Vector2.new(x + width, y); o.lines.right.To = Vector2.new(x + width, y + height)
                        for _, l in pairs({o.lines.top, o.lines.bottom, o.lines.left, o.lines.right}) do l.Color = ESP.Color; l.Visible = true end
                        if ESP.ShowHealth then
                            local hx = x - 4; local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            o.lines.hpBg.From = Vector2.new(hx, y); o.lines.hpBg.To = Vector2.new(hx, y + height); o.lines.hpBg.Color = Color3.fromRGB(20, 20, 20); o.lines.hpBg.Visible = true
                            o.lines.hpFill.From = Vector2.new(hx, y + (height - height * ratio)); o.lines.hpFill.To = Vector2.new(hx, y + height)
                            o.lines.hpFill.Color = ratio > 0.5 and Color3.fromRGB(60, 255, 100) or Color3.fromRGB(255, 220, 60):Lerp(Color3.fromRGB(255, 60, 60), 1 - ratio * 2)
                            o.lines.hpFill.Visible = true
                        else o.lines.hpBg.Visible = false; o.lines.hpFill.Visible = false end
                    else for _, l in pairs(o.lines) do l.Visible = false end end
                end
            end
        end
    end

    local function enableESP() ESP.Enabled = true; for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end end
    local function disableESP() ESP.Enabled = false; for plr in pairs(espObjects) do clearESP(plr) end end

    Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(0.5); if ESP.Enabled then buildESP(p) end end) end)
    Players.PlayerRemoving:Connect(function(p) clearESP(p) end)
    RunService.RenderStepped:Connect(function()
        if not ESP.Enabled then return end
        for plr in pairs(espObjects) do if not plr.Parent then clearESP(plr) end end
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and not espObjects[p] then buildESP(p) end end
        refreshESP()
    end)

    -- ESP & Misc Tabs
    ESPTab:Section({ Title = "ESP Settings", Opened = true })
    ESPTab:Toggle({ Title = "Enable ESP", Value = false, Callback = function(s) if s then enableESP() else disableESP() end end })
    ESPTab:Toggle({ Title = "Names", Value = true, Callback = function(s) ESP.ShowName = s end })
    ESPTab:Toggle({ Title = "Distance", Value = true, Callback = function(s) ESP.ShowDistance = s end })
    ESPTab:Toggle({ Title = "Health Bar", Value = true, Callback = function(s) ESP.ShowHealth = s end })
    ESPTab:Colorpicker({ Title = "ESP Color", Default = Color3.fromRGB(255, 60, 60), Callback = function(c) ESP.Color = c end })
    ESPTab:Slider({ Title = "ESP Max Distance", Value = { Min = 500, Max = 5000, Default = 2000 }, Step = 100, Callback = function(v) ESP.MaxDistance = v end })

    MiscTab:Section({ Title = "Hit Sound", Opened = true })
    MiscTab:Toggle({ Title = "Enable Hit Sound", Value = false, Callback = function(s) HitSound.Enabled = s end })

    -- ============================================================
    -- WATERMARK & SETTINGS
    -- ============================================================
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

    local uiSec = Settings:Section({ Title = "UI Settings", Opened = true })
    local dangerSec = Settings:Section({ Title = "Danger Zone", Opened = true })

    -- WindUI Native Keybind & Mouse Lock
    uiSec:Keybind({ Title = "Menu Toggle Key", Value = Enum.KeyCode.RightShift, Callback = function(key) Window:SetToggleKey(key) end })
    uiSec:Toggle({ Title = "Watermark", Value = false, Callback = function(bool) WatermarkEnabled = bool end })
    uiSec:Toggle({ Title = "Show FPS", Value = true, Callback = function(bool) ShowFPS = bool end })
    uiSec:Toggle({ Title = "Show Ping", Value = true, Callback = function(bool) ShowPing = bool end })

    -- ============================================================
    -- LOAD NEW MODS FROM GITHUB
    -- ============================================================
    local loadGunMods = loadstring(game:HttpGet(repoBase .. "GunMods.lua"))()
    local loadBowMods = loadstring(game:HttpGet(repoBase .. "BowMods.lua"))()
    
    local unloadGunMods = loadGunMods(Window, WindUI)
    local unloadBowMods = loadBowMods(Window, WindUI)

    -- Unload Everything
    dangerSec:Button({ Title = "Unload Everything", Callback = function()
        wmRunning = false
        if wmConnection then wmConnection:Disconnect() end
        if Watermark then Watermark:Remove() end
        if HitLogGui then HitLogGui:Destroy() end
        if ESP.Enabled then disableESP() end

        if unloadGunMods then pcall(unloadGunMods) end
        if unloadBowMods then pcall(unloadBowMods) end
        
        if Window and Window.Destroy then Window:Destroy() end
        UIS.MouseIconEnabled = true
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        getgenv().Library = nil
        getgenv().Utility = nil
    end})
end)
