-- LoadingScreen.lua
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local C = {
    bg0 = Color3.fromHex("#0A0710"), bg1 = Color3.fromHex("#150F23"),
    purple = Color3.fromHex("#8B5CF6"), purpleDeep = Color3.fromHex("#6D28D9"),
    purpleLight = Color3.fromHex("#A855F7"), purpleSoft = Color3.fromHex("#C4B5FD"),
    cyan = Color3.fromHex("#06B6D4"), text = Color3.fromHex("#F5F3FF"),
}
local function showArceusLoading(checks, onDone)
    checks = checks or {"initializing engine...","verifying signature...","loading modules...","ready."}
    local parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "AX_Loading"; sg.IgnoreGuiInset = true; sg.ResetOnSpawn = false; sg.DisplayOrder = 999
    sg.Parent = parent
    local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C.bg0; bg.BorderSizePixel = 0; bg.Parent = sg
    local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(C.bg1, C.bg0); g.Rotation = 135; g.Parent = bg
    local stage = Instance.new("Frame"); stage.Size = UDim2.fromOffset(320, 480); stage.Position = UDim2.fromScale(0.5, 0.5); stage.AnchorPoint = Vector2.new(0.5, 0.5); stage.BackgroundTransparency = 1; stage.Parent = sg
    local glow = Instance.new("Frame"); glow.Size = UDim2.fromOffset(180, 180); glow.Position = UDim2.fromScale(0.5, 0.32); glow.AnchorPoint = Vector2.new(0.5, 0.5); glow.BackgroundColor3 = C.purple; glow.BackgroundTransparency = 0.85; glow.BorderSizePixel = 0; glow.Parent = stage
    local gc = Instance.new("UICorner"); gc.CornerRadius = UDim.new(1, 0); gc.Parent = glow
    local gg = Instance.new("UIGradient"); gg.Color = ColorSequence.new(C.purple, C.cyan); gg.Rotation = 45; gg.Parent = glow
    local mark = Instance.new("Frame"); mark.Size = UDim2.fromOffset(120, 120); mark.Position = UDim2.fromScale(0.5, 0.32); mark.AnchorPoint = Vector2.new(0.5, 0.5); mark.BackgroundTransparency = 1; mark.Parent = stage
    for _, rot in ipairs({45, -45}) do
        local bar = Instance.new("Frame"); bar.Size = UDim2.fromOffset(16, 110); bar.Position = UDim2.fromScale(0.5, 0.5); bar.AnchorPoint = Vector2.new(0.5, 0.5); bar.Rotation = rot; bar.BorderSizePixel = 0; bar.Parent = mark
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = bar
        local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(C.purpleLight, C.cyan); g.Rotation = 90; g.Parent = bar
    end
    local ring = Instance.new("Frame"); ring.Size = UDim2.fromOffset(160, 160); ring.Position = UDim2.fromScale(0.5, 0.32); ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.BackgroundTransparency = 1; ring.Parent = stage
    local ringStroke; local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(1, 0); rc.Parent = ring
    ringStroke = Instance.new("UIStroke"); ringStroke.Color = C.purple; ringStroke.Thickness = 2; ringStroke.Transparency = 0.4; ringStroke.Parent = ring
    local rg = Instance.new("UIGradient"); rg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.purple), ColorSequenceKeypoint.new(0.5, Color3.new(0, 0, 0)), ColorSequenceKeypoint.new(1, C.cyan)})
    rg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0)}); rg.Parent = ringStroke
    local brand = Instance.new("TextLabel"); brand.Size = UDim2.new(1, 0, 0, 40); brand.Position = UDim2.new(0, 0, 0.58, 0); brand.BackgroundTransparency = 1; brand.Text = "ARCEUS X"; brand.Font = Enum.Font.GothamBold; brand.TextSize = 34; brand.TextColor3 = C.text; brand.TextTransparency = 1; brand.Parent = stage
    local bgrd = Instance.new("UIGradient"); bgrd.Color = ColorSequence.new(C.purpleLight, C.cyan); bgrd.Parent = brand
    local sub = Instance.new("TextLabel"); sub.Size = UDim2.new(1, 0, 0, 20); sub.Position = UDim2.new(0, 0, 0.58, 42); sub.BackgroundTransparency = 1; sub.Text = "INITIALIZING"; sub.Font = Enum.Font.GothamMedium; sub.TextSize = 12; sub.TextColor3 = C.purpleSoft; sub.TextTransparency = 1; sub.Parent = stage
    local list = Instance.new("Frame"); list.Size = UDim2.fromOffset(260, 120); list.Position = UDim2.new(0.5, 0, 0.58, 90); list.AnchorPoint = Vector2.new(0.5, 0); list.BackgroundTransparency = 1; list.Parent = stage
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 6); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list
    local barBg = Instance.new("Frame"); barBg.Size = UDim2.fromOffset(260, 3); barBg.Position = UDim2.new(0.5, 0, 1, -60); barBg.AnchorPoint = Vector2.new(0.5, 0.5); barBg.BackgroundColor3 = C.bg1; barBg.BorderSizePixel = 0; barBg.Parent = stage
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(1, 0); bc.Parent = barBg
    local barFill = Instance.new("Frame"); barFill.Size = UDim2.fromScale(0, 1); barFill.BorderSizePixel = 0; barFill.Parent = barBg
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = barFill
    local fg = Instance.new("UIGradient"); fg.Color = ColorSequence.new(C.purpleDeep, C.cyan); fg.Parent = barFill
    TweenService:Create(brand, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    task.wait(0.2)
    TweenService:Create(sub, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play()
    local alive = true
    task.spawn(function() while alive do mark.Rotation = 0; local t = TweenService:Create(mark, TweenInfo.new(6, Enum.EasingStyle.Linear), {Rotation = 360}); t:Play(); t.Completed:Wait() end end)
    task.spawn(function() while alive do local up = TweenService:Create(glow, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.65, Size = UDim2.fromOffset(230, 230)}); up:Play(); up.Completed:Wait(); if not alive then break end; local down = TweenService:Create(glow, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.85, Size = UDim2.fromOffset(180, 180)}); down:Play(); down.Completed:Wait() end end)
    task.spawn(function() while alive do local a = TweenService:Create(ringStroke, TweenInfo.new(0.5), {Transparency = 0.1}); a:Play(); a.Completed:Wait(); if not alive then break end; local b = TweenService:Create(ringStroke, TweenInfo.new(0.5), {Transparency = 0.4}); b:Play(); b.Completed:Wait() end end)
    for i, text in ipairs(checks) do
        if not alive then break end
        local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 20); row.BackgroundTransparency = 1; row.LayoutOrder = i; row.Parent = list
        local dot = Instance.new("Frame"); dot.Size = UDim2.fromOffset(8, 8); dot.Position = UDim2.new(0, 0, 0.5, 0); dot.AnchorPoint = Vector2.new(0, 0.5); dot.BackgroundColor3 = C.purple; dot.BorderSizePixel = 0; dot.BackgroundTransparency = 1; dot.Parent = row
        local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
        local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, -20, 1, 0); label.Position = UDim2.new(0, 20, 0, 0); label.BackgroundTransparency = 1; label.Text = text; label.Font = Enum.Font.GothamMedium; label.TextSize = 13; label.TextColor3 = C.purpleSoft; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextTransparency = 1; label.Parent = row
        TweenService:Create(dot, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
        TweenService:Create(label, TweenInfo.new(0.2), {TextTransparency = 0.3}):Play()
        TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.fromScale(i / #checks, 1)}):Play()
        task.wait(0.35)
    end
    task.wait(0.4); sub.Text = "READY"; TweenService:Create(sub, TweenInfo.new(0.2), {TextTransparency = 0}):Play(); task.wait(0.35)
    alive = false
    TweenService:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    for _, desc in ipairs(stage:GetDescendants()) do
        if desc:IsA("TextLabel") then TweenService:Create(desc, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        elseif desc:IsA("Frame") then TweenService:Create(desc, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        elseif desc:IsA("UIStroke") then TweenService:Create(desc, TweenInfo.new(0.4), {Transparency = 1}):Play() end
    end
    task.wait(0.5); sg:Destroy(); if onDone then onDone() end
end
return showArceusLoading
