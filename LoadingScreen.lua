-- LoadingScreen.lua
return function(checks, callback)
    local RunService = game:GetService("RunService")
    local Camera = workspace.CurrentCamera
    local Center = Camera.ViewportSize / 2
    
    -- YOUR GITHUB RAW LINK
    local PrimaryImageURL = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/main/ArceusLogo.png" 

    -- Track everything for cleanup
    local cleanupList = {}

    -- Deep Black Background
    local Bg = Drawing.new("Square")
    Bg.Size = Vector2.new(Camera.ViewportSize.X, Camera.ViewportSize.Y)
    Bg.Color = Color3.fromHex("#050505")
    Bg.Filled = true
    Bg.ZIndex = 50
    table.insert(cleanupList, Bg)

    -- Scrolling Hacker Code
    local CodeText = Drawing.new("Text")
    CodeText.Font = Drawing.Fonts.Code
    CodeText.Size = 12
    CodeText.Color = Color3.fromHex("#00FF00")
    CodeText.Text = ""
    CodeText.Position = Vector2.new(Center.X - 200, Center.Y - 200)
    CodeText.Center = false
    CodeText.ZIndex = 51
    table.insert(cleanupList, CodeText)
    
    -- Top Logo
    local ImageSize = Vector2.new(100, 100)
    local Image = Drawing.new("Image")
    Image.Size = ImageSize
    Image.Position = Vector2.new(Center.X - 50, Center.Y - 140)
    Image.ZIndex = 52
    table.insert(cleanupList, Image)

    -- Safely attempt to load the image
    task.spawn(function()
        task.wait(0.1)
        local success = pcall(function()
            Image.Data = PrimaryImageURL
        end)
        
        -- If the image fails, draw a giant purple "A" as a fallback
        if not success then
            Image.Visible = false
            local FallbackLogo = Drawing.new("Text")
            FallbackLogo.Font = Drawing.Fonts.Plex
            FallbackLogo.Size = 80
            FallbackLogo.Color = Color3.fromHex("#8A2BE2")
            FallbackLogo.Text = "A"
            FallbackLogo.Position = Vector2.new(Center.X, Center.Y - 120)
            FallbackLogo.Center = true
            FallbackLogo.Outline = true
            FallbackLogo.OutlineColor = Color3.fromHex("#FFFFFF")
            FallbackLogo.ZIndex = 52
            table.insert(cleanupList, FallbackLogo)
        end
    end)

    -- Title & Subtitle
    local Title = Drawing.new("Text")
    Title.Font = Drawing.Fonts.Plex
    Title.Size = 36
    Title.Color = Color3.fromHex("#FFFFFF")
    Title.Text = "ARCEUS X"
    Title.Position = Vector2.new(Center.X, Center.Y + 10)
    Title.Center = true
    Title.ZIndex = 52
    table.insert(cleanupList, Title)

    local Sub = Drawing.new("Text")
    Sub.Font = Drawing.Fonts.Plex
    Sub.Size = 14
    Sub.Color = Color3.fromHex("#8888A0")
    Sub.Text = "UNDETECTED · UNDISPUTED"
    Sub.Position = Vector2.new(Center.X, Center.Y + 55)
    Sub.Center = true
    Sub.ZIndex = 52
    table.insert(cleanupList, Sub)

    -- Side Lines
    local LeftLine = Drawing.new("Square")
    LeftLine.Size = Vector2.new(80, 1)
    LeftLine.Position = Vector2.new(Center.X - 200, Center.Y + 70)
    LeftLine.Color = Color3.fromHex("#333333")
    LeftLine.Filled = true
    LeftLine.ZIndex = 52
    table.insert(cleanupList, LeftLine)

    local RightLine = Drawing.new("Square")
    RightLine.Size = Vector2.new(80, 1)
    RightLine.Position = Vector2.new(Center.X + 120, Center.Y + 70)
    RightLine.Color = Color3.fromHex("#333333")
    RightLine.Filled = true
    RightLine.ZIndex = 52
    table.insert(cleanupList, RightLine)

    -- Loading Bar & Percentage
    local BarBg = Drawing.new("Square")
    BarBg.Size = Vector2.new(300, 2)
    BarBg.Position = Vector2.new(Center.X - 150, Center.Y + 120)
    BarBg.Color = Color3.fromHex("#222222")
    BarBg.Filled = true
    BarBg.ZIndex = 52
    table.insert(cleanupList, BarBg)

    local BarFill = Drawing.new("Square")
    BarFill.Size = Vector2.new(0, 2)
    BarFill.Position = Vector2.new(Center.X - 150, Center.Y + 120)
    BarFill.Color = Color3.fromHex("#FFFFFF")
    BarFill.Filled = true
    BarFill.ZIndex = 53
    table.insert(cleanupList, BarFill)

    local PercentText = Drawing.new("Text")
    PercentText.Font = Drawing.Fonts.Plex
    PercentText.Size = 12
    PercentText.Color = Color3.fromHex("#FFFFFF")
    PercentText.Text = "0%"
    PercentText.Position = Vector2.new(Center.X, Center.Y + 135)
    PercentText.Center = true
    PercentText.ZIndex = 52
    table.insert(cleanupList, PercentText)

    local StatusText = Drawing.new("Text")
    StatusText.Font = Drawing.Fonts.Plex
    StatusText.Size = 12
    StatusText.Color = Color3.fromHex("#8888A0")
    StatusText.Text = "Initializing..."
    StatusText.Position = Vector2.new(Center.X, Center.Y + 100)
    StatusText.Center = true
    StatusText.ZIndex = 52
    table.insert(cleanupList, StatusText)

    -- ACCESS GRANTED
    local AccessGranted = Drawing.new("Text")
    AccessGranted.Font = Drawing.Fonts.Plex
    AccessGranted.Size = 40
    AccessGranted.Color = Color3.fromHex("#8A2BE2")
    AccessGranted.Text = "ACCESS GRANTED"
    AccessGranted.Position = Vector2.new(Center.X, Center.Y + 40)
    AccessGranted.Center = true
    AccessGranted.Outline = true
    AccessGranted.OutlineColor = Color3.fromHex("#FFFFFF")
    AccessGranted.Transparency = 0
    AccessGranted.ZIndex = 60
    table.insert(cleanupList, AccessGranted)

    -- Fade In sequence
    local elements = {Image, Title, Sub, LeftLine, RightLine, BarBg, BarFill, PercentText, StatusText}
    for _, obj in pairs(elements) do obj.Transparency = 1 end
    CodeText.Transparency = 1
    
    for i = 1, 0, -0.05 do
        for _, obj in pairs(elements) do obj.Transparency = i end
        CodeText.Transparency = i * 0.7
        task.wait(0.01)
    end

    -- Scrolling Code Animation
    local codeSnippet = [[
    int i;
    unsigned int count = group_info->ngroups;
    for (i = 0; i < group_info->nblocks; i++) {
        unsigned int cp_count = min(NGROUPS_PER_BLOCK, count);
        unsigned int len = cp_count * sizeof(*grouplist);
        if (copy_from_user(group_info->blocks[i], grouplist, len))
            return -EFAULT;
        grouplist += NGROUPS_PER_BLOCK;
        count -= cp_count;
    }
    return 0;
    /* Env Verification */
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
        CodeText.Position = Vector2.new(Center.X - 200, Center.Y - 250 + scrollY)
    end)

    -- Run Progress Checks
    task.spawn(function()
        for i, check in ipairs(checks) do
            StatusText.Text = check
            local targetWidth = (i / #checks) * 300
            for step = 1, 20 do
                local currentWidth = BarFill.Size.X
                local newWidth = currentWidth + ((targetWidth - currentWidth) / 3)
                BarFill.Size = Vector2.new(newWidth, 2)
                PercentText.Text = tostring(math.floor((newWidth / 300) * 100)) .. "%"
                task.wait(0.03)
            end
            task.wait(0.2)
        end

        StatusText.Text = "Environment Secure."
        task.wait(0.5)
        
        -- Fade out standard UI
        for _, obj in pairs(elements) do 
            task.spawn(function()
                for i = 0, 1, 0.1 do
                    pcall(function() obj.Transparency = i end)
                    task.wait(0.02)
                end
            end)
        end
        
        if renderConn then renderConn:Disconnect() end
        CodeText:Remove()
        
        -- Pop "ACCESS GRANTED"
        AccessGranted.Transparency = 0
        AccessGranted.Size = 30
        for i = 30, 40, 2 do
            AccessGranted.Size = i
            task.wait(0.01)
        end
        task.wait(0.8)

        -- Fade out "ACCESS GRANTED"
        for i = 0, 1, 0.05 do
            AccessGranted.Transparency = i
            task.wait(0.02)
        end

        -- Final Cleanup
        for _, obj in pairs(cleanupList) do
            pcall(function() obj:Remove() end)
        end

        -- Trigger the UI
        if callback then callback() end
    end)
end
