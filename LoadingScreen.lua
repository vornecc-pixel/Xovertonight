\-- LoadingScreen.lua
return function(checks, callback)
    local RunService = game:GetService("RunService")
    local Camera = workspace.CurrentCamera
    local Center = Camera.ViewportSize / 2
    local cleanupList = {}

    -- Background
    local Bg = Drawing.new("Square")
    Bg.Size = Vector2.new(Camera.ViewportSize.X, Camera.ViewportSize.Y)
    Bg.Color = Color3.fromHex("#050505")
    Bg.Filled = true
    Bg.ZIndex = 50
    table.insert(cleanupList, Bg)

    -- Scrolling Code
    local CodeText = Drawing.new("Text")
    CodeText.Font = Drawing.Fonts.Code
    CodeText.Size = 12
    CodeText.Color = Color3.fromHex("#00FF00")
    CodeText.Position = Vector2.new(Center.X - 150, Center.Y - 200)
    CodeText.ZIndex = 51
    table.insert(cleanupList, CodeText)

    -- 32-BIT PIXEL LOGO
    local pixelSize = 8
    local logoMap = {
        "00111100",
        "01111110",
        "11100111",
        "11000011",
        "11111111",
        "11111111",
        "11000011",
        "11000011"
    }
    local logoPixels = {}
    local startX = Center.X - (#logoMap[1] * pixelSize) / 2
    local startY = Center.Y - 150

    for row = 1, #logoMap do
        local rowStr = logoMap[row]
        for col = 1, #rowStr do
            if rowStr:sub(col, col) == "1" then
                local px = Drawing.new("Square")
                px.Size = Vector2.new(pixelSize, pixelSize)
                px.Position = Vector2.new(startX + (col - 1) * pixelSize, startY + (row - 1) * pixelSize)
                px.Color = Color3.fromHex("#8A2BE2")
                px.Filled = true
                px.ZIndex = 52
                table.insert(logoPixels, px)
            end
        end
    end

    -- Title & Subtitle
    local Title = Drawing.new("Text")
    Title.Font = Drawing.Fonts.Plex
    Title.Size = 30
    Title.Color = Color3.fromHex("#FFFFFF")
    Title.Text = "ARCEUS X"
    Title.Position = Vector2.new(Center.X, Center.Y + 20)
    Title.Center = true
    Title.ZIndex = 52
    table.insert(cleanupList, Title)

    local Sub = Drawing.new("Text")
    Sub.Font = Drawing.Fonts.Plex
    Sub.Size = 14
    Sub.Color = Color3.fromHex("#8888A0")
    Sub.Text = "UNDETECTED · UNDISPUTED"
    Sub.Position = Vector2.new(Center.X, Center.Y + 60)
    Sub.Center = true
    Sub.ZIndex = 52
    table.insert(cleanupList, Sub)

    -- Loading Bar
    local BarBg = Drawing.new("Square")
    BarBg.Size = Vector2.new(300, 2)
    BarBg.Position = Vector2.new(Center.X - 150, Center.Y + 110)
    BarBg.Color = Color3.fromHex("#222222")
    BarBg.Filled = true
    BarBg.ZIndex = 52
    table.insert(cleanupList, BarBg)

    local BarFill = Drawing.new("Square")
    BarFill.Size = Vector2.new(0, 2)
    BarFill.Position = Vector2.new(Center.X - 150, Center.Y + 110)
    BarFill.Color = Color3.fromHex("#A855F7")
    BarFill.Filled = true
    BarFill.ZIndex = 53
    table.insert(cleanupList, BarFill)

    local StatusText = Drawing.new("Text")
    StatusText.Font = Drawing.Fonts.Plex
    StatusText.Size = 12
    StatusText.Color = Color3.fromHex("#8888A0")
    StatusText.Text = "Initializing..."
    StatusText.Position = Vector2.new(Center.X, Center.Y + 90)
    StatusText.Center = true
    StatusText.ZIndex = 52
    table.insert(cleanupList, StatusText)

    -- ACCESS GRANTED
    local AccessGranted = Drawing.new("Text")
    AccessGranted.Font = Drawing.Fonts.Plex
    AccessGranted.Size = 40
    AccessGranted.Color = Color3.fromHex("#A855F7")
    AccessGranted.Text = "ACCESS GRANTED"
    AccessGranted.Position = Vector2.new(Center.X, Center.Y + 40)
    AccessGranted.Center = true
    AccessGranted.Outline = true
    AccessGranted.OutlineColor = Color3.fromHex("#FFFFFF")
    AccessGranted.Transparency = 0
    AccessGranted.ZIndex = 60
    table.insert(cleanupList, AccessGranted)

    local codeSnippet = [[
    bypass_ac.init(0x7FF);
    hook_function(L"ntdll.dll", "NtQueryInformationProcess");
    memory.protect(0xFFFFFFFF, PAGE_EXECUTE_READWRITE);
    status = ACCESS_GRANTED;
    ]]
    
    local scrollY = 0
    local renderConn = RunService.RenderStepped:Connect(function(dt)
        scrollY = scrollY + (dt * 30)
        if scrollY > 20 then scrollY = 0 end
        CodeText.Text = codeSnippet
        CodeText.Position = Vector2.new(Center.X - 150, Center.Y - 250 + scrollY)
    end)

    task.spawn(function()
        for i, check in ipairs(checks) do
            StatusText.Text = check
            local targetWidth = (i / #checks) * 300
            for step = 1, 20 do
                local currentWidth = BarFill.Size.X
                BarFill.Size = Vector2.new(currentWidth + ((targetWidth - currentWidth) / 3), 2)
                task.wait(0.03)
            end
            task.wait(0.2)
        end

        task.wait(0.5)
        
        local elements = {Title, Sub, BarBg, BarFill, StatusText}
        for _, obj in pairs(elements) do
            task.spawn(function()
                for i = 0, 1, 0.1 do
                    pcall(function() obj.Transparency = i end)
                    task.wait(0.02)
                end
            end)
        end
        for _, px in ipairs(logoPixels) do
            task.spawn(function()
                for i = 0, 1, 0.1 do
                    pcall(function() px.Transparency = i end)
                    task.wait(0.02)
                end
            end)
        end
        
        if renderConn then renderConn:Disconnect() end
        CodeText:Remove()
        
        AccessGranted.Transparency = 0
        AccessGranted.Size = 30
        for i = 30, 40, 2 do
            AccessGranted.Size = i
            task.wait(0.01)
        end
        task.wait(0.8)

        for i = 0, 1, 0.05 do
            AccessGranted.Transparency = i
            task.wait(0.02)
        end

        for _, obj in pairs(cleanupList) do pcall(function() obj:Remove() end) end
        for _, px in ipairs(logoPixels) do pcall(function() px:Remove() end) end

        if callback then callback() end
    end)
end
