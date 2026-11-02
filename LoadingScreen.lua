-- LoadingScreen.lua
return function(checks, callback)
    local RunService = game:GetService("RunService")
    local Camera = workspace.CurrentCamera
    local Center = Camera.ViewportSize / 2
    
    -- Replace with your Direct Imgur link
    local ImageURL = "https://i.imgur.com/AGsU7mR.png" 

    -- 1. Deep Black Background
    local Bg = Drawing.new("Square")
    Bg.Size = Vector2.new(Camera.ViewportSize.X, Camera.ViewportSize.Y)
    Bg.Color = Color3.fromHex("#050505")
    Bg.Filled = true
    Bg.ZIndex = 50

    -- 2. Scrolling Hacker Code (Image 2 style)
    local CodeText = Drawing.new("Text")
    CodeText.Font = Drawing.Fonts.Code
    CodeText.Size = 12
    CodeText.Color = Color3.fromHex("#00FF00") -- Terminal Green
    CodeText.Text = ""
    CodeText.Position = Vector2.new(Center.X - 200, Center.Y - 200)
    CodeText.Center = false
    CodeText.ZIndex = 51
    
    -- 3. Top Logo
    local ImageSize = Vector2.new(100, 100)
    local Image = Drawing.new("Image")
    Image.Size = ImageSize
    Image.Position = Vector2.new(Center.X - 50, Center.Y - 140)
    Image.Data = ImageURL
    Image.ZIndex = 52

    -- 4. Title & Subtitle (Like "DUALITY / TWO SIDES. ONE GAME.")
    local Title = Drawing.new("Text")
    Title.Font = Drawing.Fonts.Plex
    Title.Size = 36
    Title.Color = Color3.fromHex("#FFFFFF")
    Title.Text = "ARCEUS X"
    Title.Position = Vector2.new(Center.X, Center.Y + 10)
    Title.Center = true
    Title.ZIndex = 52

    local Sub = Drawing.new("Text")
    Sub.Font = Drawing.Fonts.Plex
    Sub.Size = 14
    Sub.Color = Color3.fromHex("#8888A0")
    Sub.Text = "UNDETECTED · UNDISPUTED"
    Sub.Position = Vector2.new(Center.X, Center.Y + 55)
    Sub.Center = true
    Sub.ZIndex = 52

    -- 5. Side Lines (From Image 1)
    local LeftLine = Drawing.new("Square")
    LeftLine.Size = Vector2.new(80, 1)
    LeftLine.Position = Vector2.new(Center.X - 200, Center.Y + 70)
    LeftLine.Color = Color3.fromHex("#333333")
    LeftLine.Filled = true
    LeftLine.ZIndex = 52

    local RightLine = Drawing.new("Square")
    RightLine.Size = Vector2.new(80, 1)
    RightLine.Position = Vector2.new(Center.X + 120, Center.Y + 70)
    RightLine.Color = Color3.fromHex("#333333")
    RightLine.Filled = true
    RightLine.ZIndex = 52

    -- 6. Loading Bar & Percentage
    local BarBg = Drawing.new("Square")
    BarBg.Size = Vector2.new(300, 2)
    BarBg.Position = Vector2.new(Center.X - 150, Center.Y + 120)
    BarBg.Color = Color3.fromHex("#222222")
    BarBg.Filled = true
    BarBg.ZIndex = 52

    local BarFill = Drawing.new("Square")
    BarFill.Size = Vector2.new(0, 2)
    BarFill.Position = Vector2.new(Center.X - 150, Center.Y + 120)
    BarFill.Color = Color3.fromHex("#FFFFFF") -- White fill like Duality
    BarFill.Filled = true
    BarFill.ZIndex = 53

    local PercentText = Drawing.new("Text")
    PercentText.Font = Drawing.Fonts.Plex
    PercentText.Size = 12
    PercentText.Color = Color3.fromHex("#FFFFFF")
    PercentText.Text = "0%"
    PercentText.Position = Vector2.new(Center.X, Center.Y + 135)
    PercentText.Center = true
    PercentText.ZIndex = 52

    local StatusText = Drawing.new("Text")
    StatusText.Font = Drawing.Fonts.Plex
    StatusText.Size = 12
    StatusText.Color = Color3.fromHex("#8888A0")
    StatusText.Text = "Initializing..."
    StatusText.Position = Vector2.new(Center.X, Center.Y + 100)
    StatusText.Center = true
    StatusText.ZIndex = 52

    -- 7. ACCESS GRANTED Text (Hidden initially)
    local AccessGranted = Drawing.new("Text")
    AccessGranted.Font = Drawing.Fonts.Plex
    AccessGranted.Size = 40
    AccessGranted.Color = Color3.fromHex("#8A2BE2") -- Arceus Purple
    AccessGranted.Text = "ACCESS GRANTED"
    AccessGranted.Position = Vector2.new(Center.X, Center.Y + 40)
    AccessGranted.Center = true
    AccessGranted.Outline = true
    AccessGranted.OutlineColor = Color3.fromHex("#FFFFFF")
    AccessGranted.Transparency = 0
    AccessGranted.ZIndex = 60

    -- Fade-in elements
    local elements = {Image, Title, Sub, LeftLine, RightLine, BarBg, BarFill, PercentText, StatusText}
    for _, obj in pairs(elements) do obj.Transparency = 1 end
    CodeText.Transparency = 1
    
    for i = 1, 0, -0.05 do
        for _, obj in pairs(elements) do obj.Transparency = i end
        CodeText.Transparency = i * 0.7 -- Code is slightly dimmer
        task.wait(0.01)
    end

    -- Animation Loop for scrolling code
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
    local renderConn
    renderConn = RunService.RenderStepped:Connect(function(dt)
        scrollY = scrollY + (dt * 30)
        if scrollY > 20 then scrollY = 0 end
        CodeText.Text = string.rep("\n", 0) .. codeSnippet
        CodeText.Position = Vector2.new(Center.X - 200, Center.Y - 250 + scrollY)
    end)

    -- Run Checks
    task.spawn(function()
        for i, check in ipairs(checks) do
            StatusText.Text = check
            local targetWidth = (i / #checks) * 300
            
            -- Animate Bar
            for step = 1, 20 do
                local currentWidth = BarFill.Size.X
                local newWidth = currentWidth + ((targetWidth - currentWidth) / 3)
                BarFill.Size = Vector2.new(newWidth, 2)
                PercentText.Text = tostring(math.floor((newWidth / 300) * 100)) .. "%"
                task.wait(0.03)
            end
            task.wait(0.2)
        end

        -- SUCCESS SEQUENCE
        StatusText.Text = "Environment Secure."
        task.wait(0.5)
        
        -- Hide standard elements, show ACCESS GRANTED
        for _, obj in pairs(elements) do 
            task.spawn(function()
                for i = 0, 1, 0.1 do
                    obj.Transparency = i
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
        task.wait(0.8) -- Hold "ACCESS GRANTED"

        -- FADE OUT EVERYTHING
        for i = 0, 1, 0.05 do
            AccessGranted.Transparency = i
            task.wait(0.02)
        end

        -- Cleanup
        Bg:Remove(); Image:Remove(); Title:Remove(); Sub:Remove()
        LeftLine:Remove(); RightLine:Remove(); BarBg:Remove(); BarFill:Remove()
        PercentText:Remove(); StatusText:Remove(); AccessGranted:Remove()

        -- Trigger UI
        if callback then callback() end
    end)
end
