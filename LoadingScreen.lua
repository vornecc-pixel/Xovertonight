-- LoadingScreen.lua (64-Bit Pixel Swarm)
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local C = {
    bg = Color3.fromHex("#0A0710"),
    purple = Color3.fromHex("#8B5CF6"),
    cyan = Color3.fromHex("#06B6D4"),
    text = Color3.fromHex("#F5F3FF"),
}

-- 8x8 grid = 64 bits
local GRID_SIZE = 8
local BITS = GRID_SIZE * GRID_SIZE

local function getTargetXPosition(gridX, gridY)
    -- Creates a chunky "X" shape on an 8x8 grid
    local isMainDiagonal = math.abs(gridX - gridY) <= 1
    local isAntiDiagonal = math.abs(gridX - (7 - gridY)) <= 1
    return isMainDiagonal or isAntiDiagonal
end

local function showLoading(checks, targetFrame, onDone)
    local parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "AX_Loading"; sg.IgnoreGuiInset = true; sg.ResetOnSpawn = false; sg.DisplayOrder = 999
    sg.Parent = parent

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C.bg; bg.BorderSizePixel = 0; bg.Parent = sg
    
    local stage = Instance.new("Frame")
    stage.Size = UDim2.fromOffset(1, 1); stage.Position = UDim2.fromScale(0.5, 0.5); stage.BackgroundTransparency = 1; stage.Parent = sg

    -- Create the 64 bits
    local bits = {}
    for i = 1, BITS do
        local bit = Instance.new("Frame")
        bit.Size = UDim2.fromOffset(8, 8); bit.AnchorPoint = Vector2.new(0.5, 0.5)
        bit.BackgroundColor3 = (i % 2 == 0) and C.purple or C.cyan
        bit.BorderSizePixel = 0
        bit.Parent = stage
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 2); c.Parent = bit
        table.insert(bits, bit)
    end

    -- Brand text
    local brand = Instance.new("TextLabel")
    brand.Size = UDim2.new(1, 0, 0, 40); brand.Position = UDim2.new(0, 0, 0.5, 80); brand.AnchorPoint = Vector2.new(0.5, 0.5)
    brand.BackgroundTransparency = 1; brand.Text = "ARCEUS X"; brand.Font = Enum.Font.GothamBold; brand.TextSize = 34; brand.TextColor3 = C.text; brand.TextTransparency = 1
    brand.Parent = stage

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.fromOffset(260, 3); barBg.Position = UDim2.new(0, 0, 0.5, 120); barBg.AnchorPoint = Vector2.new(0.5, 0.5)
    barBg.BackgroundColor3 = Color3.fromHex("#1E1730"); barBg.BorderSizePixel = 0; barBg.Parent = stage
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(1, 0); bc.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.fromScale(0, 1); barFill.BorderSizePixel = 0; barFill.Parent = barBg
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = barFill
    local fg = Instance.new("UIGradient"); fg.Color = ColorSequence.new(C.purple, C.cyan); fg.Parent = barFill

    TweenService:Create(brand, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

    -- Animation Loop
    local alive = true
    local phase = "orbit" -- "orbit" -> "morph" -> "fly"
    local orbitAngle = 0
    
    task.spawn(function()
        while alive do
            RunService.RenderStepped:Wait()
            orbitAngle += 0.05
            
            for i, bit in ipairs(bits) do
                if phase == "orbit" then
                    -- Circle the bits
                    local angle = (i / BITS) * math.pi * 2 + orbitAngle
                    local radius = 60 + math.sin(orbitAngle * 2) * 10
                    local x = math.cos(angle) * radius
                    local y = math.sin(angle) * radius
                    bit.Position = UDim2.new(0.5, x, 0.5, y)
                    bit.Rotation = math.deg(angle)
                end
            end
        end
    end)

    -- Reveal process
    task.spawn(function()
        task.wait(1)
        phase = "morph" -- Stop orbiting, morph into X
        
        for i, bit in ipairs(bits) do
            local gx = (i - 1) % GRID_SIZE
            local gy = math.floor((i - 1) / GRID_SIZE)
            
            -- Center the grid
            local targetX = (gx - 3.5) * 12
            local targetY = (gy - 3.5) * 12
            
            local isX = getTargetXPosition(gx, gy)
            
            if isX then
                TweenService:Create(bit, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0.5, targetX, 0.5, targetY),
                    Size = UDim2.fromOffset(10, 10),
                    Rotation = 0,
                    BackgroundColor3 = C.purple
                }):Play()
            else
                TweenService:Create(bit, TweenInfo.new(0.2), {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(0, 0)
                }):Play()
            end
        end

        -- Run the checks
        for i = 1, #checks do
            task.wait(0.2)
            TweenService:Create(barFill, TweenInfo.new(0.2), {Size = UDim2.fromScale(i / #checks, 1)}):Play()
        end

        task.wait(0.5)
        phase = "fly" -- Stop the loop
        
        -- Calculate the flight target (Top-Left of the UI)
        local targetPos = UDim2.new(0.5, 0, 0.5, 0)
        if targetFrame and targetFrame.Parent then
            -- Map the ScreenGui position to the target frame
            local cam = workspace.CurrentCamera
            local absPos = targetFrame.AbsolutePosition
            local absSize = targetFrame.AbsoluteSize
            
            -- WindUI logo is usually around 20px in
            targetPos = UDim2.fromOffset(absPos.X + 20, absPos.Y + 20)
        end

        -- Fade out UI, fly the X
        TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        TweenService:Create(brand, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(barBg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()

        local flyTween = TweenService:Create(stage, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
            Position = targetPos,
            Size = UDim2.fromOffset(20, 20) -- Shrink to logo size
        })
        flyTween:Play()
        flyTween.Completed:Wait()

        -- Cleanup and turn on the UI
        sg:Destroy()
        if onDone then onDone() end
    end)
end

return showLoading
