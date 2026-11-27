-- // Vault — ESP template (clean rebuild)
-- // base: demo_universal_esp  |  UI: noname.hack (Drawing library)
-- //
-- // What this is:
-- //   * Combat tab  -> pure psilent + weapon mods + kill aura + bullet
-- //                    manipulation (gun peek / packet no spread /
-- //                    trajectory arc)
-- //   * Visuals tab -> full player ESP + working esp_preview + target viewer
-- //                    (vertical crosshair-aware hotbar + armor rail)
-- //   * World tab   -> world ESP + auto farm nodes
-- //   * Misc tab    -> speed/phase/spider/freecam + desync + overlay windows
-- //   * Sounds tab  -> hitsounds (head/body/kill) on the server's HitMarker
-- //
-- // ESP features: corner/full box, filled box, gradient healthbar, name,
-- //   health text, distance, held-item (tools/guns/anything), view angle,
-- //   tracers, chams. Optimised render loop (cached flag reads, hide-once,
-- //   pooled drawings, zero per-frame allocation).
-- //
-- // The player-ESP flag names (Enabled / Names / Name_Color / Boxes /
-- //   Box_Type / Box_Color / Healthbar / Health_High / Health_Low /
-- //   Distance / Distance_Color / Weapon / Weapon_Color) drive both the real
-- //   ESP and the 2D preview panel in the compatibility layer. The preview
-- //   accepts Color3 values directly as well as Atlanta's { Color = Color3 }
-- //   tables, so existing color flags keep working unchanged.

-- ================================================================
-- // EXECUTOR SHIMS
-- //   the library calls getgenv() + file fns at build time; provide safe
-- //   fallbacks so window() never throws on a thin executor
-- ================================================================



--[[
    WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
do
	local shared = (type(getgenv) == "function" and getgenv()) or _G or getfenv()
	if type(getgenv)   ~= "function" then getgenv   = function() return shared end end
	if type(readfile)  ~= "function" then readfile  = function() return "{}" end end
	if type(writefile) ~= "function" then writefile = function() end end
	if type(isfile)    ~= "function" then isfile    = function() return false end end
	if type(listfiles) ~= "function" then listfiles = function() return {} end end
	if type(isfolder)  ~= "function" then isfolder  = function() return false end end
	if type(makefolder)~= "function" then makefolder= function() end end
	if type(getupvalue) ~= "function" then
		getupvalue = function(func, index)
			if type(debug) == "table" and type(debug.getupvalue) == "function" then
				local _, value = debug.getupvalue(func, index)
				return value
			end
			return nil
		end
	end
end

-- tear down a previous run so a re-execute never stacks a second menu/ESP
if getgenv().VaultUnload then pcall(getgenv().VaultUnload) end

-- ================================================================
-- // LOAD UI LIBRARY (noname.hack) + ATLANTA-STYLE COMPAT LAYER
-- //   The rest of this file was written against Atlanta's lowercase,
-- //   instance-based API. noname.hack is a Drawing-based library with
-- //   PascalCase constructors, separate flag/pointer tables, no config
-- //   setters and no 3D esp_preview. This shim preserves every existing
-- //   flag/callback while exposing the old call sites to the new library.
-- ================================================================
local NONAME_UI_URL = "https://raw.githubusercontent.com/bouibot/noname.hack/refs/heads/main/lib.lua"
local library, utility, themes, nativeWindow
do
	local src = game:HttpGet(NONAME_UI_URL)

	-- The tooltip loop indexes an upvalue from toggle.Update. Guard it so a
	-- thin executor without getupvalue cannot throw on mouse movement.
	local needle = "local toggle_frame = getupvalue(v.Update, 1)"
	local i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. 'local toggle_frame = type(getupvalue) == "function" and getupvalue(v.Update, 1) or nil'
			.. src:sub(j + 1)
	end
	needle = 'if v.tt ~= "" and utility:MouseOverPosition'
	i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. 'if toggle_frame and v.tt ~= "" and utility:MouseOverPosition'
			.. src:sub(j + 1)
	end

	-- Sections created while their tab is inactive must be hidden immediately,
	-- otherwise their drawings become visible as soon as library.loaded flips.
	needle = "            return section\n        end\n\n        if self.sshit == nil then"
	i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. "            if not self.on then\n                section:Hide()\n            end\n            self:Update()\n\n"
			.. src:sub(i)
	end

	-- Re-hide non-selected tabs after a fade; Fade only includes the active
	-- tab's sections, but a stale visible section can otherwise leak through.
	needle = "        self:Update()\n\n        self:HideUseless"
	i, j = src:find(needle, 1, true)
	if i then
		local at = i + #"        self:Update()\n\n"
		src = src:sub(1, at - 1)
			.. "        if self.sshit then\n            for _, other_tab in ipairs(self.tabs) do\n                if other_tab ~= self.sshit then other_tab:Hide() end\n            end\n        end\n        if self.sshit and self.sshit._compatApplyScroll then\n            pcall(self.sshit._compatApplyScroll, self.sshit)\n        end\n\n"
			.. src:sub(at)
	end

	-- toggle.Update must ignore the compatibility layer's metatable method
	-- named "keybind" and only use a raw attached keybind object.
	needle = "                    if self.keybind then\n                        self.keybind:SetOffset"
	i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. "                    if rawget(self, \"keybind\") then\n                        rawget(self, \"keybind\"):SetOffset"
			.. src:sub(j + 1)
	end

	-- utility:Combine() must preserve array order. Some runtimes iterate
	-- pairs() on an array in a non-ascending order, which would make
	-- section.instances[1] stop being the section frame and break layout.
	needle = "    function utility:Combine(t1, t2)\n        local t3 = {}\n        for i, v in pairs(t1) do\n            table.insert(t3, v)\n        end\n        for i, v in pairs(t2) do\n            table.insert(t3, v)\n        end\n        return t3\n    end"
	i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. "    function utility:Combine(t1, t2)\n        local t3 = {}\n        for i = 1, #t1 do\n            table.insert(t3, t1[i])\n        end\n        for i = 1, #t2 do\n            table.insert(t3, t2[i])\n        end\n        return t3\n    end"
			.. src:sub(j + 1)
	end


	-- Deterministic section order: pairs() on an array is not guaranteed to
	-- emit ascending indexes on every executor, which breaks scroll offsets.
	needle = "            for sn, side in pairs(self.sides) do\n\n                -- // every section in it\n\n                for i, v in pairs(side) do"
	i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. "            for sn, side in ipairs(self.sides) do\n\n                -- // every section in it\n\n                for i, v in ipairs(side) do"
			.. src:sub(j + 1)
	end

	-- OVX owns cursor state from the explicit menu-visible callback. The
	-- upstream Fade assignments would immediately undo it (false on show).
	needle = "            uis.MouseIconEnabled = true"
	i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. "            -- OVX restores the saved cursor state on hide"
			.. src:sub(j + 1)
	end
	needle = "            uis.MouseIconEnabled = false"
	i, j = src:find(needle, 1, true)
	if i then
		src = src:sub(1, i - 1)
			.. "            -- OVX keeps the cursor free on show"
			.. src:sub(j + 1)
	end

	-- Compatibility patches for noname.hack: Always On keybinds, modal cleanup,
	-- and a color picker that works even when Imgur image data is unavailable.
	local function patchOnce(oldText, newText)
		local i, j = src:find(oldText, 1, true)
		if i then src = src:sub(1, i - 1) .. newText .. src:sub(j + 1) end
	end
	local function patchAll(oldText, newText)
		local at = 1
		while true do
			local i, j = src:find(oldText, at, true)
			if not i then break end
			src = src:sub(1, i - 1) .. newText .. src:sub(j + 1)
			at = i + #newText
		end
	end

	patchOnce([==[    function utility:Connect(connection, func)
]==], [==[    function utility:OVXSetHue(parent, hue)
        if not parent or type(parent._ovxSvStrips) ~= "table" then return end
        for _, strip in ipairs(parent._ovxSvStrips) do
            strip.Color = c3hsv(hue, strip._s, strip._v)
        end
    end

    function utility:OVXMakeSVGradient(parent, hue)
        if not parent then return {} end
        pcall(function() parent.Transparency = 0 end)
        local strips = {}
        for row = 0, 19 do
            for col = 0, 19 do
                local sat, val = col / 19, 1 - row / 19
                local strip = utility:Draw("Square", v2new(col * 5, row * 5), {
                    Size = v2new(5, 5), Color = c3hsv(hue, sat, val),
                    Filled = true, Thickness = 0, Transparency = 1,
                    ZIndex = 10^4 - 1, Parent = parent,
                })
                strip._s, strip._v = sat, val
                strips[#strips + 1] = strip
            end
        end
        parent._ovxSvStrips = strips
        return strips
    end

    function utility:OVXMakeBarGradient(parent, trans)
        if not parent then return {} end
        local strips = {}
        for i = 0, 19 do
            local t = i / 19
            local color = trans and c3rgb(math.floor(255 * (1 - t)), math.floor(255 * (1 - t)), math.floor(255 * (1 - t))) or c3hsv(t, 1, 1)
            local strip = utility:Draw("Square", v2new(1, 1 + i * 5), {
                Size = v2new(5, 5), Color = color,
                Filled = true, Thickness = 0, Transparency = 1,
                ZIndex = 10^4 - 1, Parent = parent,
            })
            strips[#strips + 1] = strip
        end
        parent._ovxBarStrips = strips
        return strips
    end

    function utility:Connect(connection, func)
]==])

	patchOnce([==[    function utility:Image(object, link, name)
        local data = library.preloaded_images[link]

        if not data then
            data = game:HttpGet(link)
        end

        if library.preloaded_images[link] == nil then
            library.preloaded_images[link] = data
        end
        object.Data = data
    end
]==], [==[    function utility:Image(object, link, name)
        if not object then return end
        local data = library.preloaded_images[link]
        if not data then
            local ok, response = pcall(function() return game:HttpGet(link) end)
            if ok and type(response) == "string" then
                data = response
                library.preloaded_images[link] = data
            end
        end
        local png = string.char(137) .. "PNG" .. string.char(13) .. string.char(10) .. string.char(26) .. string.char(10)
        local jpeg = string.char(255) .. string.char(216)
        local valid = type(data) == "string" and #data > 16 and (
            data:sub(1, 8) == png or data:sub(1, 2) == jpeg or
            data:sub(1, 4) == "GIF8" or data:sub(1, 4) == "<svg" or
            data:sub(1, 5) == "<?xml" or data:sub(1, 5) == "data:"
        )
        if valid then
            local ok = pcall(function() object.Data = data end)
            if ok then object.Visible = true; return end
        end
        object.Visible = false
    end
]==])

	patchOnce([==[    function window.HideUselessDumbassFuckingShitStopPastingMyCodePleaseYouAreSkidAndImGayILikeBigBlackManOkNoProblemThisIsASexcretFuncteiotieitns4epoivi2n45obvi6j45bv74gvho4hgv487(self)
        if self.shit.dropdown then
            self.shit.dropdown:Close()
        elseif self.shit.textbox then
            self.shit.textbox:Stop()
        elseif self.shit.keybind then
            self.shit.keybind:Close()
        elseif self.shit.colorpicker then
            self.shit.colorpicker:Close()
        end
    end
]==], [==[    function window:OVXCloseTransients(except)
        local s = self.shit or {}
        local function closeOne(key, method)
            local entry = s[key]
            if entry and entry ~= except and type(entry[method]) == "function" then
                pcall(entry[method], entry)
            end
            if s[key] ~= except then s[key] = nil end
        end
        closeOne("dropdown", "Close")
        closeOne("textbox", "Stop")
        closeOne("keybind", "Close")
        closeOne("colorpicker", "Close")
    end

    function window.HideUselessDumbassFuckingShitStopPastingMyCodePleaseYouAreSkidAndImGayILikeBigBlackManOkNoProblemThisIsASexcretFuncteiotieitns4epoivi2n45obvi6j45bv74gvho4hgv487(self)
        self:OVXCloseTransients(nil)
        local function closeAgain()
            self:OVXCloseTransients(nil)
        end
        if type(task) == "table" and type(task.defer) == "function" then
            pcall(task.defer, closeAgain)
        elseif type(task) == "table" and type(task.delay) == "function" then
            pcall(task.delay, 0, closeAgain)
        else
            closeAgain()
        end
    end
]==])

	-- One transient control at a time. Every Open/Start clears the others first,
	-- Close/Stop only clears its own pointer, and tab/menu changes close everything.
	patchAll('window:HideUselessDumbassFuckingShitStopPastingMyCodePleaseYouAreSkidAndImGayILikeBigBlackManOkNoProblemThisIsASexcretFuncteiotieitns4epoivi2n45obvi6j45bv74gvho4hgv487()',
		'window:OVXCloseTransients(self)')
	patchAll('self:HideUselessDumbassFuckingShitStopPastingMyCodePleaseYouAreSkidAndImGayILikeBigBlackManOkNoProblemThisIsASexcretFuncteiotieitns4epoivi2n45obvi6j45bv74gvho4hgv487()',
		'self:OVXCloseTransients(nil)')
	patchAll('window.shit.dropdown = nil', 'if window.shit.dropdown == self then window.shit.dropdown = nil end')
	patchAll('window.shit.textbox = nil', 'if window.shit.textbox == self then window.shit.textbox = nil end')
	patchAll('window.shit.keybind = nil', 'if window.shit.keybind == self then window.shit.keybind = nil end')
	patchOnce('function dropdown.Open(self)\n', 'function dropdown.Open(self)\n                    if self.Close then pcall(self.Close, self) end\n                    window:OVXCloseTransients(self)\n')
	patchOnce('function keybind.Open(self)\n', 'function keybind.Open(self)\n                    if self.Close then pcall(self.Close, self) end\n')
	patchOnce('function colorpicker.Open(self)\n', 'function colorpicker.Open(self)\n                    if self.Close then pcall(self.Close, self) end\n')
	patchOnce('function textbox.Start(self)\n', 'function textbox.Start(self)\n                    window:OVXCloseTransients(self)\n')
	patchOnce('function window.SelectTab(self, name)\n\n        if self.fading then return end\n',
		'function window.SelectTab(self, name)\n\n        if self.fading then return end\n        self:OVXCloseTransients(nil)\n')

	patchOnce('                    keybind_value.Text = utility.short_keybind_names[self.value] or self.value:upper()',
		[==[                    if self.mode == "always" then
                        keybind_value.Text = "ON"
                    else
                        keybind_value.Text = utility.short_keybind_names[self.value] or self.value:upper()
                    end]==])
	patchOnce([==[                function keybind.Set(self, value)
                    self.value = value[1]
                    self.mode = value[2]

                    self:Update()
                end
]==], [==[                function keybind.Set(self, value)
                    self.value = value[1] or "unset"
                    self.mode = value[2] or "toggle"
                    if self.mode == "always" and not table.find(window.kbds, self.pointer) then
                        table.insert(window.kbds, self.pointer)
                        if window.kblist then window.kblist:Update() end
                    end
                    self:Update()
                end
]==])
	patchOnce([==[                function keybind.AddToTable(self, input_name)
                    if keybind.value == input_name then
]==], [==[                function keybind.AddToTable(self, input_name)
                    if keybind.mode == "always" then
                        if not table.find(window.kbds, keybind.pointer) then
                            table.insert(window.kbds, keybind.pointer)
                            if window.kblist then window.kblist:Update() end
                        end
                        return
                    end
                    if keybind.value == input_name then
]==])
	patchOnce('                        Size = v2new(48, 5 + 26),', '                        Size = v2new(62, 5 + 40),')
	patchOnce('                    for i, v in pairs({"Toggle", "Hold"}) do', '                    for i, v in ipairs({"Toggle", "Hold", "Always On"}) do')
	patchOnce([==[                                        if offset >= 22 then
                                            keybind.mode = "hold"
                                        else
                                            keybind.mode = "toggle"
                                        end

                                        for i, v in pairs({keybind.minst[3], keybind.minst[4]}) do
                                            v.Color = keybind.mode == v.Text:lower() and window.theme.accent or c3rgb(255, 255, 255)
                                        end
]==], [==[                                        local modeIndex = offset >= 30 and 3 or (offset >= 16 and 2 or 1)
                                        keybind.mode = ({"toggle", "hold", "always"})[modeIndex]
                                        for i = 3, 5 do
                                            local v = keybind.minst[i]
                                            if v then v.Color = (i - 2 == modeIndex) and window.theme.accent or c3rgb(255, 255, 255) end
                                        end
                                        if keybind.mode == "always" and not table.find(window.kbds, keybind.pointer) then
                                            table.insert(window.kbds, keybind.pointer)
                                            if window.kblist then window.kblist:Update() end
                                        end
]==])

	patchOnce([==[                    utility:Image(cpdropframe_color_image, "https://i.imgur.com/wpDRqVH.png")
                    utility:Image(cpdropframe_hue_image, "https://i.imgur.com/iEOsHFv.png")
                    utility:Image(cpdropframe_trans_image, "https://i.imgur.com/GeMU2Ke.png")
]==], [==[                    utility:Image(cpdropframe_color_image, "https://i.imgur.com/wpDRqVH.png")
                    utility:Image(cpdropframe_hue_image, "https://i.imgur.com/iEOsHFv.png")
                    utility:Image(cpdropframe_trans_image, "https://i.imgur.com/GeMU2Ke.png")
                    cpdropframe_color_image.Visible = false
                    cpdropframe_hue_image.Visible = false
                    cpdropframe_trans_image.Visible = false
                    utility:OVXMakeSVGradient(cpdropframe_color, self.dvalues[1])
                    utility:OVXMakeBarGradient(cpdropframe_hue, false)
                    utility:OVXMakeBarGradient(cpdropframe_trans, true)
]==])
	patchOnce([==[                    if not self.trans then
                        cpdropframe_trans.Visible = false
                        cpdropframe_trans_image.Visible = false
                        cpdropframe_trans_picker.Visible = false
                        cpdropframe_trans_picker_outline.Visible = false
                    end
]==], [==[                    if not self.trans then
                        cpdropframe_trans.Visible = false
                        cpdropframe_trans_image.Visible = false
                        cpdropframe_trans_picker.Visible = false
                        cpdropframe_trans_picker_outline.Visible = false
                        for _, strip in ipairs(cpdropframe_trans._ovxBarStrips or {}) do strip.Visible = false end
                    end
]==])
	patchOnce([==[                    self.instances = {cpdropframe, cpdropframe_outline, cpdropframe_accent, cpdropframe_color, cpdropframe_color_outline, cpdropframe_color_image,
                        cpdropframe_color_cursor, cpdropframe_color_cursor_outline, cpdropframe_hue, cpdropframe_hue_image, cpdropframe_hue_picker, cpdropframe_hue_picker_outline,
                        cpdropframe_trans, cpdropframe_trans_image, cpdropframe_trans_picker, cpdropframe_trans_picker_outline
                    }
]==], [==[                    self.instances = {cpdropframe, cpdropframe_outline, cpdropframe_accent, cpdropframe_color, cpdropframe_color_outline, cpdropframe_color_image,
                        cpdropframe_color_cursor, cpdropframe_color_cursor_outline, cpdropframe_hue, cpdropframe_hue_image, cpdropframe_hue_picker, cpdropframe_hue_picker_outline,
                        cpdropframe_trans, cpdropframe_trans_image, cpdropframe_trans_picker, cpdropframe_trans_picker_outline
                    }
                    for _, stripList in ipairs({cpdropframe_color._ovxSvStrips or {}, cpdropframe_hue._ovxBarStrips or {}, cpdropframe_trans._ovxBarStrips or {}}) do
                        for _, strip in ipairs(stripList) do self.instances[#self.instances + 1] = strip end
                    end
                    self._ovxStripRoots = {cpdropframe_color, cpdropframe_hue, cpdropframe_trans}
]==])
	patchOnce([==[                function colorpicker.Close(self)
                    if #self.instances > 0 then
                        for i, v in pairs(self.instances) do
                            v.Remove()
                        end

                        self.instances = {}

                        window.shit.colorpicker = nil
                    end
                end
]==], [==[                function colorpicker.Close(self)
                    for _, v in pairs(self.instances or {}) do
                        pcall(function() v.Remove() end)
                    end
                    for _, root in ipairs(self._ovxStripRoots or {}) do
                        root._ovxSvStrips = nil
                        root._ovxBarStrips = nil
                    end
                    self._ovxStripRoots = nil
                    self.instances = {}
                    if window.shit.colorpicker == self then window.shit.colorpicker = nil end
                    local function closeOthers()
                        if window.OVXCloseTransients then pcall(window.OVXCloseTransients, window, self) end
                    end
                    if type(task) == "table" and type(task.defer) == "function" then
                        pcall(task.defer, closeOthers)
                    elseif type(task) == "table" and type(task.delay) == "function" then
                        pcall(task.delay, 0, closeOthers)
                    else
                        closeOthers()
                    end
                end
]==])

	patchAll('colorpicker.instances[4].Color = c3hsv(py, 1, 1)',
		'colorpicker.instances[4].Color = c3hsv(py, 1, 1); utility:OVXSetHue(colorpicker.instances[4], py)')

	local chunk = assert(loadstring(src), "[OVX] noname.hack UI failed to compile")
	local a, b = chunk()
	library, utility = a, b
	if type(library) ~= "table" then error("[OVX] noname.hack UI failed to load") end
end

local flags = library.flags
local function setDefaultFlag(name, value)
	if library.flags[name] == nil then library.flags[name] = value end
end
setDefaultFlag("sa_enabled", true)
setDefaultFlag("sa_force_head", false)
setDefaultFlag("sa_instant_hit", true)
setDefaultFlag("sa_remote_jack", true)
setDefaultFlag("sa_bow_enabled", true)
setDefaultFlag("sa_target_npc", true)
setDefaultFlag("sa_snapline_npc", true)
setDefaultFlag("tb_npc", true)
setDefaultFlag("sa_scan_hz", 12)
setDefaultFlag("ui_free_mouse", true)
setDefaultFlag("ui_hud_hz", 4)
setDefaultFlag("Enabled", true)
setDefaultFlag("esp_team_check", false)
setDefaultFlag("esp_max_dist", 0)
setDefaultFlag("Boxes", true)
setDefaultFlag("Box_Type", "Full")
setDefaultFlag("Box_Color", Color3.fromRGB(255, 255, 255))
setDefaultFlag("esp_box_thickness", 1)
setDefaultFlag("esp_box_outline", true)
setDefaultFlag("esp_filled_box", false)
setDefaultFlag("esp_filled_color", Color3.fromRGB(255, 255, 255))
setDefaultFlag("esp_filled_transparency", 6)
setDefaultFlag("Names", true)
setDefaultFlag("esp_display_names", true)
setDefaultFlag("Name_Color", Color3.fromRGB(255, 255, 255))
setDefaultFlag("Healthbar", true)
setDefaultFlag("esp_health_outline", true)
setDefaultFlag("esp_health_position", "Left")
setDefaultFlag("Health_High", Color3.fromRGB(0, 255, 0))
setDefaultFlag("Health_Low", Color3.fromRGB(255, 0, 0))
setDefaultFlag("esp_health_text", false)
setDefaultFlag("esp_health_text_color", Color3.fromRGB(255, 255, 255))
setDefaultFlag("esp_health_text_gradient", false)
setDefaultFlag("Distance", true)
setDefaultFlag("Distance_Color", Color3.fromRGB(200, 200, 200))
setDefaultFlag("Weapon", false)
setDefaultFlag("Weapon_Color", Color3.fromRGB(255, 220, 80))
setDefaultFlag("esp_view_angle", false)
setDefaultFlag("esp_viewangle_color", Color3.fromRGB(255, 255, 255))
setDefaultFlag("esp_viewangle_size", 10)
setDefaultFlag("esp_chams", false)
setDefaultFlag("esp_cham_vis_check", false)
setDefaultFlag("esp_cham_fill_color", Color3.fromRGB(255, 255, 255))
setDefaultFlag("esp_cham_outline_color", Color3.fromRGB(0, 0, 0))
setDefaultFlag("esp_cham_fill_transparency", 4)
setDefaultFlag("esp_cham_outline_transparency", 0)
setDefaultFlag("esp_cham_vis_color", Color3.fromRGB(0, 255, 0))
setDefaultFlag("esp_cham_invis_color", Color3.fromRGB(255, 0, 0))
setDefaultFlag("esp_font_size", 13)
setDefaultFlag("esp_font", "Plex")
setDefaultFlag("esp_tracers", false)
setDefaultFlag("esp_tracer_color", Color3.fromRGB(255, 255, 255))
setDefaultFlag("esp_tracer_origin", "Bottom")
setDefaultFlag("sf_hands_enabled", false)
setDefaultFlag("sf_gun_enabled", false)
setDefaultFlag("sf_protect_muzzle", true)
setDefaultFlag("sf_double_gun_fix", true)
setDefaultFlag("sf_vmodel_refresh_hz", 5)
setDefaultFlag("sf_hand_material", "ForceField")
setDefaultFlag("sf_hand_preset", "Cyan")
setDefaultFlag("sf_hand_use_preset", true)
setDefaultFlag("sf_hand_color", Color3.fromRGB(0, 255, 255))
setDefaultFlag("sf_hand_transparency", 0)
setDefaultFlag("sf_hand_reflectance", 2)
setDefaultFlag("sf_gun_material", "ForceField")
setDefaultFlag("sf_gun_preset", "Cyan")
setDefaultFlag("sf_gun_use_preset", true)
setDefaultFlag("sf_gun_color", Color3.fromRGB(0, 255, 255))
setDefaultFlag("sf_gun_transparency", 0)
setDefaultFlag("sf_gun_reflectance", 2)
setDefaultFlag("sf_tracers_enabled", false)
setDefaultFlag("sf_tracer_use_preset", true)
setDefaultFlag("sf_tracer_preset", "Cyan")
setDefaultFlag("sf_tracer_color", Color3.fromRGB(0, 255, 255))
setDefaultFlag("sf_tracer_impact_enabled", true)
setDefaultFlag("sf_tracer_impact_color", Color3.fromRGB(0, 255, 255))
setDefaultFlag("sf_tracer_impact_size", 0.3)
setDefaultFlag("sf_tracer_width", 0.2)
setDefaultFlag("sf_tracer_lifetime", 0.25)
setDefaultFlag("sf_tracer_segments", 1)
setDefaultFlag("sf_tracer_glow", 5)
setDefaultFlag("sf_tracer_light_influence", 0)
setDefaultFlag("sf_tracer_face_camera", true)
setDefaultFlag("sf_tracer_max", 24)
setDefaultFlag("sf_tracer_range", 1000)
setDefaultFlag("sf_tracer_use_muzzle", true)
setDefaultFlag("sf_tracer_follow_sa", true)
setDefaultFlag("sf_tracer_raycast", true)
setDefaultFlag("sf_tracer_include_bow", true)
setDefaultFlag("sf_tracer_double_gun", true)
setDefaultFlag("skin_enabled", true)
setDefaultFlag("skin_apply_mode", "Selected Gun")
setDefaultFlag("skin_weapon", "Assault Rifle")
setDefaultFlag("skin_weapon_custom", "")
setDefaultFlag("skin_skin", "Tempered")
setDefaultFlag("skin_skin_custom", "")
setDefaultFlag("skin_auto_reapply", true)
setDefaultFlag("skin_delay", 0.05)
setDefaultFlag("skin_discover_assets", true)
setDefaultFlag("skin_asset_limit", 1200)
setDefaultFlag("skin_asset_depth", 5)
setDefaultFlag("skin_fallback_material", "ForceField")
setDefaultFlag("skin_fallback_color", Color3.fromRGB(255, 180, 80))
setDefaultFlag("skin_fallback_transparency", 0)
setDefaultFlag("skin_fallback_reflectance", 2)
setDefaultFlag("skin_debug", false)
setDefaultFlag("ds_ox", 0)
setDefaultFlag("ds_oy", -2.4)
setDefaultFlag("ds_oz", 0)
setDefaultFlag("ds_rx", 90)
setDefaultFlag("ds_ry", 0)
setDefaultFlag("ds_rz", 0)
setDefaultFlag("tb_max_dist", 0)
setDefaultFlag("rb_enabled", false)
setDefaultFlag("rb_enabled_quick", false)
setDefaultFlag("rb_fov_radius", 10000)
setDefaultFlag("rb_max_dist", 0)
setDefaultFlag("esp_preview_2d", true)
setDefaultFlag("esp_self_preview_3d", true)
setDefaultFlag("esp_self_preview_hz", 10)
setDefaultFlag("cfg_name", "Default")
setDefaultFlag("cfg_selected", "Default")
setDefaultFlag("cfg_auto_load", false)
setDefaultFlag("ui_modal_guard", true)
setDefaultFlag("ui_menu_key", { active = false, mode = "toggle", key = "Insert" })
setDefaultFlag("ui_jump_combat", "Silent Aim")
setDefaultFlag("ui_jump_visuals", "Player ESP")
setDefaultFlag("ui_jump_settings", "Configs")
setDefaultFlag("ui_accent", Color3.fromRGB(155, 105, 230))
setDefaultFlag("ui_background", Color3.fromRGB(20, 20, 27))
setDefaultFlag("ui_outline", Color3.fromRGB(58, 58, 72))
local compatTheme = {
	accent   = Color3.fromRGB(155, 105, 230),
	dcont    = Color3.fromRGB(12, 12, 17),
	lcont    = Color3.fromRGB(26, 26, 34),
	cont     = Color3.fromRGB(20, 20, 27),
	outline  = Color3.fromRGB(0, 0, 0),
	outline2 = Color3.fromRGB(58, 58, 72),
}
themes = { preset = {
	accent = compatTheme.accent, dcont = compatTheme.dcont, lcont = compatTheme.lcont,
	cont = compatTheme.cont, outline = compatTheme.outline, outline2 = compatTheme.outline2,
} }

library.flags          = library.flags or {}
library.pointers       = library.pointers or {}
library.groups         = library.groups or {}
library.connections    = library.connections or {}
library.fade_instances = library.fade_instances or {}
library.guis           = {}
library.instances      = {}

local configSetters = {}
library.config_flags = setmetatable(configSetters, {
	__index = function(_, flag)
		return function(value)
			library.flags[flag] = value
		end
	end,
})

local pointerSeq = 0
local function nextPointer(prefix)
	pointerSeq = pointerSeq + 1
	return "ovx_" .. tostring(prefix or "element") .. "_" .. tostring(pointerSeq)
end

local function rebindPointer(object, pointer)
	if not object then return end
	local old = object.pointer
	if old and library.pointers[old] == object then library.pointers[old] = nil end
	object.pointer = pointer
	library.pointers[pointer] = object
end

local function copyTable(tbl)
	local out = {}
	for k, v in pairs(tbl or {}) do out[k] = v end
	return out
end

local function contains(tbl, value)
	for index, item in ipairs(tbl or {}) do
		if item == value then return index end
	end
	return nil
end

local function toColor3(value)
	if typeof(value) == "Color3" then return value end
	if type(value) == "table" then
		if typeof(value.Color) == "Color3" then return value.Color end
		if type(value[1]) == "table" and type(value[1][1]) == "number"
			and type(value[1][2]) == "number" and type(value[1][3]) == "number" then
			return Color3.fromHSV(value[1][1], value[1][2], value[1][3])
		end
		if type(value[1]) == "number" and type(value[2]) == "number" and type(value[3]) == "number" then
			return Color3.fromHSV(value[1], value[2], value[3])
		end
		if type(value.R) == "number" and type(value.G) == "number" and type(value.B) == "number" then
			return Color3.new(value.R, value.G, value.B)
		end
	end
	if type(value) == "string" and type(Color3.fromHex) == "function" then
		local ok, color = pcall(Color3.fromHex, value)
		if ok and typeof(color) == "Color3" then return color end
	end
	return nil
end

local function getFlagColor(flag, fallback)
	return toColor3(library.flags[flag]) or fallback
end

local function getFlagBool(flag, fallback)
	local value = library.flags[flag]
	if value == nil then return fallback end
	if type(value) == "boolean" then return value end
	if type(value) == "number" then return value ~= 0 end
	return false
end

local function registerFlagSetter(flag, setter)
	if flag then configSetters[flag] = setter end
end

-- Reassigned by the Ragebot module. It keeps locked Silent Aim controls from
-- being switched off through a toggle, keybind, config load or console setter.
local enforceRagebotFlag = function(_, value) return value end

local function setCompatFlag(flag, value, force)
	if not force then value = enforceRagebotFlag(flag, value) end
	local setter = configSetters[flag]
	if setter then pcall(setter, value) else library.flags[flag] = value end
end
registerFlagSetter("force_head", function(value) setCompatFlag("sa_force_head", value) end)
registerFlagSetter("instant_hit", function(value) setCompatFlag("sa_instant_hit", value) end)
registerFlagSetter("remote_jack", function(value) setCompatFlag("sa_remote_jack", value) end)
registerFlagSetter("sa_npc", function(value) setCompatFlag("sa_target_npc", value) end)

local function keyName(value)
	if typeof(value) == "EnumItem" then return value.Name end
	if type(value) == "string" and value ~= "" then return value end
	return "unset"
end

local function normalizeKeybindMode(value)
	local mode = string.lower(tostring(value or "toggle"))
	mode = mode:gsub("[%s_%-]+", "")
	if mode == "always" or mode == "alwayson" or mode == "on" then return "always" end
	if mode == "hold" then return "hold" end
	return "toggle"
end

local function keybindInfo(info)
	info = info or {}
	local out = copyTable(info)
	local mode = normalizeKeybindMode(info.mode)
	out.def = keyName(info.def or info.key or info.default)
	out.mode = mode
	out.flag = info.flag
	return out
end

local function colorpickerInfo(info)
	info = info or {}
	local out = copyTable(info)
	local def = toColor3(info.def or info.color or info.default) or Color3.fromRGB(255, 0, 0)
	out.def = def
	out.color = nil
	out.trans = info.trans or info.transparency
	out.deftrans = info.deftrans or info.defaultrans or 0
	out.flag = info.flag
	out.callback = info.callback or function() end
	return out
end

local function sliderInfo(info)
	info = info or {}
	local out = copyTable(info)
	out.def = info.default
	if out.def == nil then out.def = info.min or 1 end
	local interval = tonumber(info.interval) or 1
	if interval <= 0 then interval = 1 end
	out.dec = 1 / interval
	out.suf = info.suffix or ""
	out.flag = info.flag or ""
	out.pointer = nextPointer(info.flag or "slider")
	return out
end

local function dropdownInfo(info)
	info = info or {}
	local out = copyTable(info)
	out.options = info.items or info.options or { "first", "second", "third" }
	out.multi = info.multi == true
	out.scrollable = info.scrolling or info.scrollable or false
	out.flag = info.flag or ""
	out.pointer = nextPointer(info.flag or "dropdown")
	return out
end

local function toggleInfo(info)
	info = info or {}
	local out = copyTable(info)
	out.default = info.default
	if out.default == nil then out.default = false end
	out.def = out.default
	out.flag = info.flag
	out.pointer = nextPointer(info.flag or "toggle")
	return out
end

local function refreshSection(section)
	local tab = section and section._compatTab
	if not tab then return end
	if section.Update then pcall(section.Update, section) end
	if tab.Update then pcall(tab.Update, tab) end
	if nativeWindow and nativeWindow.Update then pcall(nativeWindow.Update, nativeWindow) end
	if not tab.on and section.Hide then pcall(section.Hide, section) end
end

	local function attachKeybind(keybind, info, section)
		info = info or {}
		local flag = info.flag
		local callback = info.callback
		local pointer = nextPointer(flag or "keybind")
		local mode = normalizeKeybindMode(info.mode)
		local boundKey = keyName(info.def or info.key or info.default)

		rebindPointer(keybind, pointer)
		keybind.name = info.name or keybind.name
		if section and section.name then keybind.sname = section.name end
		if keybind.Set then pcall(keybind.Set, keybind, { boundKey, mode }) end
		pcall(function() keybind.mode = mode end)
		if flag then library.flags[flag] = { active = false, mode = mode, key = boundKey } end

		local active = false
		local function setActive(state)
			state = state and true or false
			if active == state then return end
			active = state
			if flag and type(library.flags[flag]) == "table" then library.flags[flag].active = state end
			if callback then pcall(callback, state) end
		end

		local function syncAlways(kbMode)
			if kbMode ~= "always" then return false end
			if not contains(nativeWindow.kbds, pointer) then
				table.insert(nativeWindow.kbds, pointer)
				if nativeWindow.kblist then pcall(nativeWindow.kblist.Update, nativeWindow.kblist) end
			end
			setActive(true)
			return true
		end

		function keybind:set(value)
			local desired
			if type(value) == "table" then
				desired = value.active
				if desired == nil then desired = value[1] == true or value[1] == 1 or value[1] == "true" end
				local incomingMode = normalizeKeybindMode(value.mode or value[2] or mode)
				local incomingKey = keyName(value.key or value[1] or boundKey)
				if incomingMode ~= mode or incomingKey ~= boundKey then
					mode, boundKey = incomingMode, incomingKey
					if keybind.Set then pcall(keybind.Set, keybind, { boundKey, mode }) end
				end
				pcall(function() keybind.mode = mode end)
				if flag and type(library.flags[flag]) == "table" then
					library.flags[flag].mode = mode
					library.flags[flag].key = boundKey
				end
			else
				desired = value == true or value == 1 or value == "true"
			end
			if mode == "always" then desired = true end
			local index = contains(nativeWindow.kbds, pointer)
			if desired and not index then
				table.insert(nativeWindow.kbds, pointer)
			elseif not desired and index then
				table.remove(nativeWindow.kbds, index)
			end
			if nativeWindow.kblist then pcall(nativeWindow.kblist.Update, nativeWindow.kblist) end
			setActive(desired == true)
		end

		function keybind:colorpicker(cpInfo)
			return self
		end

		local heartbeat = game:GetService("RunService").Heartbeat
		utility:Connect(heartbeat, function()
			local kbMode = normalizeKeybindMode(keybind.mode or mode)
			if kbMode ~= mode then
				mode = kbMode
				if flag and type(library.flags[flag]) == "table" then library.flags[flag].mode = mode end
			end
			if syncAlways(kbMode) then return end
			local isActive = contains(nativeWindow.kbds, pointer) ~= nil
			if isActive ~= active then setActive(isActive) end
		end)

		if flag then registerFlagSetter(flag, function(value) keybind:set(value) end) end
		refreshSection(section)
		return keybind
	end

local function attachColorpicker(colorpicker, info, section)
	info = info or {}
	local flag = info.flag
	rebindPointer(colorpicker, nextPointer(flag or "colorpicker"))

	local function setColor(value)
		local color = toColor3(value)
		if not color then return end
		local h, s, v = color:ToHSV()
		return colorpicker:Set({ h, s, v })
	end

	function colorpicker:set(value)
		return setColor(value)
	end

	function colorpicker:colorpicker(nextInfo)
		return section:colorpicker(nextInfo)
	end

	function colorpicker:keybind(nextInfo)
		return section:keybind(nextInfo)
	end

	if flag then registerFlagSetter(flag, setColor) end
	refreshSection(section)
	return colorpicker
end

local function attachValue(object, info, section, kind)
	info = info or {}
	local flag = info.flag
	rebindPointer(object, nextPointer(flag or kind or "value"))
	local nativeSet = object.Set
	if type(nativeSet) == "function" then
		function object.Set(self, value)
			return nativeSet(self, enforceRagebotFlag(flag, value))
		end
	end

	function object:set(value)
		return self:Set(value)
	end

	function object:keybind(nextInfo)
		return section:keybind(nextInfo)
	end

	function object:colorpicker(nextInfo)
		return section:colorpicker(nextInfo)
	end

	if flag then
		registerFlagSetter(flag, function(value) return object:Set(value) end)
	end
	refreshSection(section)
	return object
end

local function attachToggle(toggle, info, section)
	info = info or {}
	local flag = info.flag
	rebindPointer(toggle, nextPointer(flag or "toggle"))
	local nativeSet = toggle.Set
	if type(nativeSet) == "function" then
		function toggle.Set(self, value)
			return nativeSet(self, enforceRagebotFlag(flag, value))
		end
	end

	function toggle:set(value)
		if type(value) ~= "boolean" then value = value == true or value == 1 or value == "true" end
		return self:Set(value)
	end

	-- Old Atlanta call sites use toggle:keybind()/toggle:colorpicker(), but the
	-- native library stores an attached keybind in toggle.keybind. Resolving
	-- the compat methods through a metatable keeps that raw field free; the
	-- loader patches toggle.Update to use rawget() for the native object.
	local function compatKeybind(self, nextInfo)
		local kbInfo = keybindInfo(nextInfo)
		local keybind = self:Keybind(kbInfo)
		return attachKeybind(keybind, nextInfo, section)
	end

	local function compatColorpicker(self, nextInfo)
		local cpInfo = colorpickerInfo(nextInfo)
		local colorpicker = self:Colorpicker(cpInfo)
		return attachColorpicker(colorpicker, nextInfo, section)
	end

	local meta = getmetatable(toggle) or {}
	local oldIndex = meta.__index
	meta.__index = function(self, key)
		if key == "keybind" and rawget(self, "keybind") == nil then
			return compatKeybind
		end
		if key == "colorpicker" and rawget(self, "colorpicker") == nil then
			return compatColorpicker
		end
		if type(oldIndex) == "function" then return oldIndex(self, key) end
		if type(oldIndex) == "table" then return oldIndex[key] end
		return rawget(self, key)
	end
	setmetatable(toggle, meta)

	if flag then
		registerFlagSetter(flag, function(value) return toggle:set(value) end)
	end
	refreshSection(section)
	return toggle
end

local function attachSection(section, tab)
	section._compatTab = tab

	function section:button_holder()
		return self
	end

	function section:button(info)
		info = info or {}
		self:Button({ name = info.name or "Button", callback = info.callback or function() end })
		refreshSection(self)
		return self
	end

	function section:toggle(info)
		return attachToggle(self:Toggle(toggleInfo(info)), info, self)
	end

	function section:slider(info)
		return attachValue(self:Slider(sliderInfo(info)), info, self, "slider")
	end

	function section:dropdown(info)
		return attachValue(self:Dropdown(dropdownInfo(info)), info, self, "dropdown")
	end

	function section:keybind(info)
		local kbInfo = keybindInfo(info)
		return attachKeybind(self:Keybind(kbInfo), info, self)
	end

	function section:colorpicker(info)
		local cpInfo = colorpickerInfo(info)
		return attachColorpicker(self:Colorpicker(cpInfo), info, self)
	end

	function section:label(info)
		local text = type(info) == "table" and tostring(info.name or info.text or "") or tostring(info or "")
		if text == "" then return self end
		local y = tonumber(self:NextObjectPosition()) or 10
		local label = utility:Draw("Text", Vector2.new(8, y), {
			Text = text, Size = 11, Font = Drawing.Fonts.Plex,
			Color = Color3.fromRGB(190, 165, 235), Outline = true,
			Transparency = 1, Parent = self.instances[1],
		})
		table.insert(self.instances, label)
		self:UpdateScale(14)
		refreshSection(self)
		return self
	end

	function section:list()
		return self
	end

	function section:textbox(info)
		info = info or {}
		local nativeInfo = {
			name = info.name or "Textbox",
			default = tostring(info.default or info.def or ""),
			flag = info.flag,
		}
		local textbox = self:Textbox(nativeInfo)
		local nativeSet = textbox.Set
		local callback = info.callback
		function textbox:Set(value)
			value = tostring(value or "")
			nativeSet(self, value)
			if callback then pcall(callback, value) end
		end
		return attachValue(textbox, info, self, "textbox")
	end

	return section
end

local function attachTab(tab)
	tab._compatColumnCount = 0
	tab._compatColumns = { {}, {} }
	tab._compatScroll = 0
	local sectionCounter = 0

	function tab:column()
		tab._compatColumnCount = tab._compatColumnCount + 1
		local columnIndex = tab._compatColumnCount
		local side = (tab._compatColumnCount % 2 == 1) and "left" or "right"
		local column = {}
		function column:section(info)
			info = info or {}
			local section = tab:Section({ name = info.name or "Section", side = side })
			sectionCounter = sectionCounter + 1
			section._compatColumnIndex = columnIndex
			section._compatOrder = sectionCounter
			attachSection(section, tab)
			refreshSection(section)
			return section
		end
		return column
	end

	function tab:_compatApplyScroll(scroll)
		if not nativeWindow or not self._compatScrollable then return end
		local frame = nativeWindow.frame
		local maxH = math.max(120, (frame and frame.Size and frame.Size.Y or 620) - 55 - 24)
		local cols = self._compatColumns or { {}, {} }
		self._compatColumns = cols
		local longest = math.max(#(cols[1] or {}), #(cols[2] or {}))
		local maxScroll = math.max(0, longest - 1)
		self._compatScroll = math.clamp(tonumber(scroll) or self._compatScroll or 0, 0, maxScroll)
		local visible = { {}, {} }
		for sn = 1, 2 do
			local list = cols[sn] or {}
			local count = #list
			if count > 0 then
				local start = math.max(1, math.min(self._compatScroll + 1, count))
				local used = 0
				for offset = 0, count - 1 do
					local idx = ((start - 1 + offset) % count) + 1
					local item = list[idx]
					if not item or not item.section then break end
					local h = tonumber(item.h) or 40
					if #visible[sn] > 0 and used + h > maxH then break end
					visible[sn][#visible[sn] + 1] = item.section
					used = used + h
					item.section.side = sn == 1 and "left" or "right"
				end
			end
		end
		self.sides[1], self.sides[2] = visible[1], visible[2]
		if self.Update then pcall(self.Update, self) end
		for _, section in ipairs(self.sections or {}) do
			if section.Hide then pcall(section.Hide, section) end
		end
		if self.on and frame and frame.Visible then
			for sn = 1, 2 do
				for _, section in ipairs(self.sides[sn]) do
					if section.Show then pcall(section.Show, section) end
				end
			end
		end
	end

	function tab:_compatFocusSection(name)
		local cols = self._compatColumns or { {}, {} }
		local longest = math.max(#(cols[1] or {}), #(cols[2] or {}))
		local target
		for sn = 1, 2 do
			for idx, item in ipairs(cols[sn] or {}) do
				if item.section and item.section.name == name then
					target = math.min(target or idx, idx)
				end
			end
		end
		if not target then return false end
		self._compatScroll = math.clamp(target - 1, 0, math.max(0, longest - 1))
		self:_compatApplyScroll(self._compatScroll)
		return true
	end

	local nativeShow = tab.Show
	function tab.Show(self, ...)
		local result = nativeShow(self, ...)
		if self._compatApplyScroll then self:_compatApplyScroll(self._compatScroll or 0) end
		return result
	end

	function tab.open_tab()
		if nativeWindow and nativeWindow.SelectTab then
			pcall(nativeWindow.SelectTab, nativeWindow, tab.name)
			if nativeWindow.Update then pcall(nativeWindow.Update, nativeWindow) end
		end
	end

	return tab
end

local function isArray(value)
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" then return false end
		count = count + 1
	end
	for index = 1, count do
		if value[index] == nil then return false end
	end
	return count > 0
end

local function serializeValue(value, seen)
	if typeof(value) == "Color3" then
		return { __type = "Color3", r = value.R, g = value.G, b = value.B }
	end
	if type(value) == "table" then
		if seen[value] then return { __type = "cycle" } end
		seen[value] = true
		local out = {}
		if isArray(value) then
			for index = 1, #value do out[index] = serializeValue(value[index], seen) end
		else
			for k, v in pairs(value) do out[tostring(k)] = serializeValue(v, seen) end
		end
		seen[value] = nil
		return out
	end
	if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
		return value
	end
	return tostring(value)
end

local function deserializeValue(value)
	if type(value) == "table" then
		if value.__type == "Color3" then
			return Color3.new(tonumber(value.r) or 0, tonumber(value.g) or 0, tonumber(value.b) or 0)
		end
		local out = {}
		for k, v in pairs(value) do out[k] = deserializeValue(v) end
		return out
	end
	return value
end

local function availableColumnHeight()
	local frame = nativeWindow and nativeWindow.frame
	local h = frame and frame.Size and frame.Size.Y or 620
	return math.max(120, h - 55 - 24)
end

local function sectionHeight(section)
	if section.Update then pcall(section.Update, section) end
	local inst = section.instances and section.instances[1]
	local raw = inst and inst.Size and tonumber(inst.Size.Y)
		or tonumber(section.scale) or 10
	return math.max(24, raw) + 20
end

local function rebalanceAllTabs()
	if not (nativeWindow and nativeWindow.tabs) then return end
	local maxH = availableColumnHeight()
	for _, tab in ipairs(nativeWindow.tabs) do
		-- Tabs built with the normal two columns keep their authored layout.
		-- Only tabs that called column() more than twice (Misc, World, Exploit)
		-- get height-aware packing + wheel scrolling.
		tab._compatScrollable = (tonumber(tab._compatColumnCount) or 0) > 2
		if tab._compatScrollable then
			local groups, byColumn = {}, {}
			for index, section in ipairs(tab.sections or {}) do
				if not section.rna then
					local item = { i = index, h = sectionHeight(section), section = section }
					local key = section._compatColumnIndex or 0
					local group = byColumn[key]
					if not group then
						group = { i = index, h = 0, items = {} }
						byColumn[key] = group
						groups[#groups + 1] = group
					end
					group.h = group.h + item.h
					group.items[#group.items + 1] = item
				end
			end
			table.sort(groups, function(a, b) return a.i < b.i end)
			-- Pack whole authored columns, never splitting two adjacent
			-- sections such as Hand Chams / Gun Chams into different sides.
			local columns, heights = { {}, {} }, { 0, 0 }
			for _, group in ipairs(groups) do
				local sn = heights[1] <= heights[2] and 1 or 2
				local other = sn == 1 and 2 or 1
				if heights[sn] + group.h > maxH and heights[other] + group.h <= maxH then
					sn = other
				end
				for _, item in ipairs(group.items) do
					columns[sn][#columns[sn] + 1] = item
					heights[sn] = heights[sn] + item.h
					item.section.side = sn == 1 and "left" or "right"
				end
			end
			for sn = 1, 2 do
				table.sort(columns[sn], function(a, b) return a.i < b.i end)
			end
			tab._compatColumns = columns
			if tab._compatApplyScroll then tab:_compatApplyScroll(tab._compatScroll or 0) end
		elseif tab.Update then
			pcall(tab.Update, tab)
		end
		if not tab.on and tab.Hide then pcall(tab.Hide, tab) end
	end
	if nativeWindow.Update then pcall(nativeWindow.Update, nativeWindow) end
	if nativeWindow.sshit and nativeWindow.SelectTab then
		pcall(nativeWindow.SelectTab, nativeWindow, nativeWindow.sshit.name)
	end
end

function library:focus_section(tabName, sectionName)
	if not nativeWindow then return false end
	local target
	for _, tab in ipairs(nativeWindow.tabs or {}) do
		if tab.name == tabName then target = tab; break end
	end
	if not target then return false end
	if nativeWindow.SelectTab then pcall(nativeWindow.SelectTab, nativeWindow, tabName) end
	if target._compatFocusSection then return target:_compatFocusSection(sectionName) end
	return true
end

local initialized = false
function library:window(info)
	info = info or {}
	local screen = utility:ScreenSize()
	local size = Vector2.new(
		math.clamp(screen.X - 260, 500, 860),
		math.clamp(screen.Y - 100, 420, 680)
	)
	nativeWindow = library:New({ name = info.name or "OVX", size = size }, compatTheme)
	nativeWindow.frame.Position = utility:RoundVector(screen / 2 - size / 2)
	nativeWindow:Resize(size)

	local frame = nativeWindow.frame
	local uis = game:GetService("UserInputService")
	if flags["ui_width"] == nil then flags["ui_width"] = size.X end
	if flags["ui_height"] == nil then flags["ui_height"] = size.Y end
	nativeWindow._compatRebalance = rebalanceAllTabs

	local resizeHandle = utility:Draw("Square", Vector2.new(size.X - 14, size.Y - 14), {
		Size = Vector2.new(10, 10), Color = compatTheme.accent,
		Group = "accent", Filled = true, Parent = frame, ZIndex = 10^6,
	})
	table.insert(library.fade_instances, resizeHandle)
	nativeWindow._compatResizeHandle = resizeHandle

	function nativeWindow:resize(width, height)
		if self._compatResizing then return frame.Size end
		self._compatResizing = true
		local ok, result = pcall(function()
			local current = utility:ScreenSize()
			local maxW = math.max(500, current.X - 80)
			local maxH = math.max(420, current.Y - 80)
			local w = math.floor(math.clamp(tonumber(width) or frame.Size.X, 500, maxW))
			local h = math.floor(math.clamp(tonumber(height) or frame.Size.Y, 420, maxH))
			local newSize = Vector2.new(w, h)
			self:Resize(newSize)
			if resizeHandle then resizeHandle.SetOffset(Vector2.new(w - 14, h - 14)) end
			flags["ui_width"], flags["ui_height"] = w, h
			if library._compatPreview and library._compatPreview.reposition then
				pcall(library._compatPreview.reposition)
			end
			local setW, setH = library.config_flags["ui_width"], library.config_flags["ui_height"]
			if setW then pcall(setW, w) end
			if setH then pcall(setH, h) end
			if self._compatRebalance then pcall(self._compatRebalance) end
			if self.Update then pcall(self.Update, self) end
			return newSize
		end)
		self._compatResizing = false
		if ok then return result end
		warn("[OVX] resize failed: " .. tostring(result))
		return frame.Size
	end

	library.menu_visible = false
	nativeWindow._compatMenuVisible = false
	local savedMouseIcon, savedMouseBehavior
	local mouseFreeAt, mouseWasFreed = 0, false
	local function captureMouseState()
		pcall(function()
			savedMouseIcon = uis.MouseIconEnabled
			savedMouseBehavior = uis.MouseBehavior
		end)
	end
	local function setMouseFree()
		pcall(function()
			uis.MouseIconEnabled = true
			if Enum.MouseBehavior and Enum.MouseBehavior.Default then
				uis.MouseBehavior = Enum.MouseBehavior.Default
			end
		end)
		mouseWasFreed = true
	end
	local function setMouseGame()
		pcall(function()
			uis.MouseIconEnabled = savedMouseIcon == nil and false or savedMouseIcon
			if savedMouseBehavior ~= nil then
				uis.MouseBehavior = savedMouseBehavior
			elseif Enum.MouseBehavior and Enum.MouseBehavior.LockCenter then
				uis.MouseBehavior = Enum.MouseBehavior.LockCenter
			end
		end)
		mouseWasFreed = false
	end
	local function setMenuVisible(state, freeMouse)
		state = state and true or false
		if state and not library.menu_visible then captureMouseState() end
		library.menu_visible = state
		nativeWindow._compatMenuVisible = state
		if state then
			if freeMouse ~= false then setMouseFree() else setMouseGame() end
		else
			setMouseGame()
		end
	end
	nativeWindow._compatSetMouseFree = setMouseFree
	nativeWindow._compatSetMenuVisible = setMenuVisible
	nativeWindow:Connect({ con = "fade", callback = function(showing)
		setMenuVisible(showing, flags["ui_free_mouse"] ~= false)
	end })
	local function deferModal(fn)
		if type(task) == "table" and type(task.defer) == "function" then
			pcall(task.defer, fn)
		elseif type(task) == "table" and type(task.delay) == "function" then
			pcall(task.delay, 0, fn)
		else
			pcall(fn)
		end
	end
	function nativeWindow:_compatCloseTransients(includeKeybind)
		local function closeNow()
			if self.OVXCloseTransients then pcall(self.OVXCloseTransients, self, nil) end
			local s = self.shit or {}
			pcall(function() if s.dropdown and s.dropdown.Close then s.dropdown:Close() end end)
			pcall(function() if s.textbox and s.textbox.Stop then s.textbox:Stop() end end)
			pcall(function() if s.colorpicker and s.colorpicker.Close then s.colorpicker:Close() end end)
			if includeKeybind ~= false then
				pcall(function() if s.keybind and s.keybind.Close then s.keybind:Close() end end)
			end
		end
		closeNow()
		deferModal(closeNow)
	end
	utility:Connect(uis.InputBegan, function(input)
		if not frame.Visible or flags["ui_modal_guard"] == false then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			deferModal(function()
				local s = nativeWindow.shit or {}
				pcall(function() if s.colorpicker and s.colorpicker.Close then s.colorpicker:Close() end end)
				pcall(function() if s.dropdown and s.dropdown.Close then s.dropdown:Close() end end)
				pcall(function() if s.textbox and s.textbox.Stop then s.textbox:Stop() end end)
				pcall(function()
					if s.keybind and s.keybind.minst and #s.keybind.minst > 0 then
						local over = false
						pcall(function() over = utility:MouseOverDrawing(s.keybind.minst[1]) end)
						if not over and s.keybind.Close then s.keybind:Close() end
					end
				end)
			end)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			pcall(nativeWindow._compatCloseTransients, nativeWindow, true)
		end
	end)
	captureMouseState()
	utility:Connect(game:GetService("RunService").Heartbeat, function()
		if not library.menu_visible or not frame.Visible then return end
		if flags["ui_free_mouse"] == false then
			if mouseWasFreed then setMouseGame() end
			return
		end
		local now = os.clock()
		if now - mouseFreeAt < 0.2 then return end
		mouseFreeAt = now
		setMouseFree()
	end)

	local resizing, resizeStartMouse, resizeStartSize = false, nil, nil
	utility:Connect(uis.InputBegan, function(input)
		if frame.Visible and input.UserInputType == Enum.UserInputType.MouseButton1
			and utility:MouseOverDrawing(resizeHandle) then
			resizing = true
			resizeStartMouse = uis:GetMouseLocation()
			resizeStartSize = frame.Size
		end
	end)
	utility:Connect(uis.InputChanged, function(input)
		if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = uis:GetMouseLocation() - resizeStartMouse
			nativeWindow:resize(resizeStartSize.X + delta.X, resizeStartSize.Y + delta.Y)
		end
	end)
	utility:Connect(uis.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
	end)

	-- Long tabs (Misc/Exploit) are scrollable instead of drawing below the frame.
	utility:Connect(uis.InputChanged, function(input)
		if not frame.Visible or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		if not utility:MouseOverDrawing(frame) then return end
		local tab = nativeWindow.sshit
		if not (tab and tab._compatScrollable and tab._compatApplyScroll) then return end
		local delta = 0
		pcall(function() delta = input.Position.Z or 0 end)
		local step = delta > 0 and -1 or (delta < 0 and 1 or 0)
		if step ~= 0 then tab:_compatApplyScroll((tab._compatScroll or 0) + step) end
	end)

	-- noname.hack does not bind a menu key by itself. Keep Insert / RightShift
	-- as show-hide shortcuts and register the connection with the library so
	-- window:unload() disconnects it.
	local function currentMenuKey()
		local cfg = flags["ui_menu_key"]
		local name = type(cfg) == "table" and cfg.key or nil
		if type(name) ~= "string" or name == "" or name == "unset" then name = "Insert" end
		local key
		pcall(function() key = Enum.KeyCode[name] end)
		return key or Enum.KeyCode.Insert
	end
	nativeWindow.menu_key = currentMenuKey()
	nativeWindow._compatCurrentMenuKey = currentMenuKey
	utility:Connect(uis.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == currentMenuKey() then
			if nativeWindow.Fade then pcall(nativeWindow.Fade, nativeWindow) end
		end
	end)

	function nativeWindow:tab(tabInfo)
		tabInfo = tabInfo or {}
		local tab = self:Tab({ name = tabInfo.name or "Tab" })
		return attachTab(tab)
	end

	function nativeWindow:unload()
		if self.Unload then return self:Unload() end
	end

	function nativeWindow.set_menu_visibility(a, b)
		local state = b
		if state == nil then state = a end
		if state == nil or state == nativeWindow then state = true end
		if frame.Visible ~= state and nativeWindow.Fade then
			pcall(nativeWindow.Fade, nativeWindow)
		end
		if nativeWindow._compatSetMenuVisible then
			pcall(nativeWindow._compatSetMenuVisible, state, flags["ui_free_mouse"] ~= false)
		elseif state and nativeWindow._compatSetMouseFree then
			pcall(nativeWindow._compatSetMouseFree)
		end
	end

	nativeWindow:Connect({ con = "unload", callback = function()
		if library.unload_callback then pcall(library.unload_callback) end
	end })

	-- noname.hack has no 3D esp_preview. Build a compact 2D preview panel
	-- from the same Drawing primitives as the library and keep it in sync
	-- with the ESP flags/colorpickers.
	nativeWindow.esp_section = {}
	function nativeWindow.esp_section:esp_preview()
		local frame = nativeWindow.frame
		local panelW, panelH = 210, 280
		local draws = {}
		local function draw(class, offset, props)
			local object = utility:Draw(class, offset, props)
			table.insert(draws, object)
			table.insert(library.fade_instances, object)
			return object
		end

		local bg = draw("Square", Vector2.new(frame.Size.X + 12, 22), {
			Size = Vector2.new(panelW, panelH), Color = compatTheme.dcont,
			Group = "dcont", Filled = true, Parent = frame,
		})
		local outline = draw("Square", Vector2.new(-1, -1), {
			Size = Vector2.new(panelW + 2, panelH + 2), Color = compatTheme.outline,
			Group = "outline", Filled = false, Parent = bg,
		})
		local title = draw("Text", Vector2.new(panelW / 2, 8), {
			Font = Drawing.Fonts.Plex, Size = 13, Text = "ESP PREVIEW",
			Color = Color3.fromRGB(255, 255, 255), Outline = true,
			Center = true, Parent = bg,
		})

		local boxX, boxY, boxW, boxH = 70, 58, 70, 132
		local fullBox = draw("Square", Vector2.new(boxX, boxY), {
			Size = Vector2.new(boxW, boxH), Color = Color3.fromRGB(255, 255, 255),
			Filled = false, Thickness = 2, Parent = bg,
		})
		local filledBox = draw("Square", Vector2.new(boxX, boxY), {
			Size = Vector2.new(boxW, boxH), Color = Color3.fromRGB(0, 0, 0),
			Transparency = 0.5, Filled = true, Parent = bg,
		})
		local corners = {}
		local cornerSpecs = {
			{ boxX, boxY, 14, 2 }, { boxX, boxY, 2, 14 },
			{ boxX + boxW - 14, boxY, 14, 2 }, { boxX + boxW - 2, boxY, 2, 14 },
			{ boxX, boxY + boxH - 2, 14, 2 }, { boxX, boxY + boxH - 14, 2, 14 },
			{ boxX + boxW - 14, boxY + boxH - 2, 14, 2 },
			{ boxX + boxW - 2, boxY + boxH - 14, 2, 14 },
		}
		for i, spec in ipairs(cornerSpecs) do
			corners[i] = draw("Square", Vector2.new(spec[1], spec[2]), {
				Size = Vector2.new(spec[3], spec[4]), Color = Color3.fromRGB(255, 255, 255),
				Filled = true, Parent = bg,
			})
		end

		local nameText = draw("Text", Vector2.new(panelW / 2, boxY - 17), {
			Font = Drawing.Fonts.Plex, Size = 13, Text = "Player",
			Color = Color3.fromRGB(255, 255, 255), Outline = true,
			Center = true, Parent = bg,
		})
		local healthBg = draw("Square", Vector2.new(boxX, boxY + boxH + 8), {
			Size = Vector2.new(boxW, 6), Color = Color3.fromRGB(45, 45, 55),
			Filled = true, Parent = bg,
		})
		local healthFill = draw("Square", Vector2.new(boxX, boxY + boxH + 8), {
			Size = Vector2.new(boxW * 0.72, 6), Color = Color3.fromRGB(0, 255, 0),
			Filled = true, Parent = bg,
		})
		local healthText = draw("Text", Vector2.new(panelW / 2, boxY + boxH + 17), {
			Font = Drawing.Fonts.Plex, Size = 13, Text = "72 HP",
			Color = Color3.fromRGB(255, 255, 255), Outline = true,
			Center = true, Parent = bg,
		})
		local distanceText = draw("Text", Vector2.new(panelW / 2, boxY + boxH + 36), {
			Font = Drawing.Fonts.Plex, Size = 13, Text = "42m",
			Color = Color3.fromRGB(200, 200, 200), Outline = true,
			Center = true, Parent = bg,
		})
		local weaponText = draw("Text", Vector2.new(panelW / 2, boxY + boxH + 55), {
			Font = Drawing.Fonts.Plex, Size = 13, Text = "AK-47",
			Color = Color3.fromRGB(255, 255, 255), Outline = true,
			Center = true, Parent = bg,
		})

		local preview = {}
		function preview.refresh_elements()
			local shown = frame.Visible and getFlagBool("esp_preview_2d", true) and true or false
			local function setVisible(object, state)
				object.Visible = shown and state
			end

			setVisible(bg, true)
			setVisible(outline, true)
			setVisible(title, true)

			local enabled = getFlagBool("Enabled", false)
			local boxes = getFlagBool("Boxes", false)
			local cornerMode = (library.flags["Box_Type"] or "Full") == "Corner"
			local boxColor = getFlagColor("Box_Color", Color3.fromRGB(255, 255, 255))
			fullBox.Color = boxColor
			for _, corner in ipairs(corners) do corner.Color = boxColor end
			setVisible(fullBox, enabled and boxes and not cornerMode)
			for _, corner in ipairs(corners) do
				setVisible(corner, enabled and boxes and cornerMode)
			end

			filledBox.Color = getFlagColor("esp_filled_color", Color3.fromRGB(0, 0, 0))
			local fillTransparency = tonumber(library.flags["esp_filled_transparency"]) or 5
			filledBox.Transparency = math.clamp(fillTransparency / 10, 0, 1)
			setVisible(filledBox, enabled and boxes and getFlagBool("esp_filled_box", false))

			nameText.Color = getFlagColor("Name_Color", Color3.fromRGB(255, 255, 255))
			setVisible(nameText, enabled and getFlagBool("Names", false))

			local hpHigh = getFlagColor("Health_High", Color3.fromRGB(0, 255, 0))
			local hpLow = getFlagColor("Health_Low", Color3.fromRGB(255, 0, 0))
			healthFill.Color = hpLow:Lerp(hpHigh, 0.72)
			setVisible(healthBg, enabled and getFlagBool("Healthbar", false))
			setVisible(healthFill, enabled and getFlagBool("Healthbar", false))
			setVisible(healthText, enabled and getFlagBool("esp_health_text", false))

			distanceText.Color = getFlagColor("Distance_Color", Color3.fromRGB(200, 200, 200))
			setVisible(distanceText, enabled and getFlagBool("Distance", false))
			weaponText.Color = getFlagColor("Weapon_Color", Color3.fromRGB(255, 255, 255))
			setVisible(weaponText, enabled and getFlagBool("Weapon", false))
		end

		function preview.reposition()
			bg.SetOffset(Vector2.new(frame.Size.X + 12, 22))
			pcall(preview.refresh_elements)
		end
		function preview.set_enabled(state)
			library.flags["esp_preview_2d"] = state == true
			pcall(preview.refresh_elements)
		end
		function preview.destroy()
			for _, object in ipairs(draws) do pcall(function() object:Remove() end) end
			if library._compatPreview == preview then library._compatPreview = nil end
		end

		preview.refresh_elements()
		library._compatPreview = preview
		nativeWindow:Connect({ con = "fade", callback = function()
			task.delay(0.25, function() pcall(preview.refresh_elements) end)
		end })
		return preview
	end

	return nativeWindow
end

function library:notification(info)
	info = info or {}
	local text = tostring(info.text or "notification")
	local holder = nativeWindow and nativeWindow.ntiflist
	if holder and holder.new then
		pcall(function()
			holder:new({
				text = text,
				dur = tonumber(info.time or info.duration) or 3,
				pulse = info.pulse,
				pc = info.pulse_color,
				th = info.text_highlight,
			})
		end)
	else
		print("[OVX] " .. text)
	end
end

local themeAlias = {
	outline = "outline", inline = "outline2", accent = "accent",
	high_contrast = "dcont", low_contrast = "cont", text = "accent",
	text_outline = "outline", glow = "accent", dcont = "dcont",
	lcont = "lcont", cont = "cont", outline2 = "outline2",
}
function library:update_theme(index, value)
	if type(index) ~= "string" or typeof(value) ~= "Color3" then return end
	local key = themeAlias[index] or index
	compatTheme[key] = value
	library.groups[key] = library.groups[key] or {}
	if nativeWindow and nativeWindow.NewTheme then
		for group in pairs(compatTheme) do library.groups[group] = library.groups[group] or {} end
		pcall(nativeWindow.NewTheme, nativeWindow, compatTheme)
	end
end

function library:get_config()
	local data = {}
	for key, value in pairs(library.flags) do data[key] = serializeValue(value, {}) end
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(data)
	end)
	return ok and encoded or "{}"
end

function library:load_config(configJson)
	local ok, decoded = pcall(function()
		return game:GetService("HttpService"):JSONDecode(configJson)
	end)
	if not ok or type(decoded) ~= "table" then return false end
	for key, value in pairs(decoded) do
		local setter = library.config_flags[key]
		if setter then pcall(setter, deserializeValue(value)) end
	end
	return true
end

function library:config_list_update()
	if initialized then return end
	initialized = true
	if nativeWindow and nativeWindow._compatRebalance then
		pcall(nativeWindow._compatRebalance)
	end
	if nativeWindow and nativeWindow.Init then
		local ok, err = pcall(nativeWindow.Init, nativeWindow)
		if not ok then warn("[OVX] noname.hack Init failed: " .. tostring(err)) end
	end
	if nativeWindow and nativeWindow._compatSetMenuVisible then
		pcall(nativeWindow._compatSetMenuVisible, true, flags["ui_free_mouse"] ~= false)
	elseif nativeWindow and nativeWindow._compatSetMouseFree then
		pcall(nativeWindow._compatSetMouseFree)
	end
	pcall(function()
		if nativeWindow and nativeWindow.Update then nativeWindow:Update() end
	end)
	task.delay(0.3, function()
		pcall(function()
			if nativeWindow and nativeWindow._compatRebalance then pcall(nativeWindow._compatRebalance) end
			if nativeWindow and nativeWindow.Update then nativeWindow:Update() end
			if nativeWindow and nativeWindow.sshit and nativeWindow.SelectTab then
				nativeWindow:SelectTab(nativeWindow.sshit.name)
			end
			if flags["ui_width"] and flags["ui_height"] and nativeWindow.resize then
				nativeWindow:resize(flags["ui_width"], flags["ui_height"])
			end
		end)
		local preview = library._compatPreview
		if preview and preview.refresh_elements then pcall(preview.refresh_elements) end
	end)
end

-- ================================================================
-- // SERVICES + SHORTCUTS
-- ================================================================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local CoreGui    = game:GetService("CoreGui")
local UIS        = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")

local lp         = Players.LocalPlayer
local unpack     = table.unpack

local Drawingnew = Drawing.new
local c3         = Color3.fromRGB
local v2new      = Vector2.new
local v3new      = Vector3.new
local floor      = math.floor
local clamp      = math.clamp
local huge       = math.huge

-- ================================================================
-- // CONNECTION / OBJECT TRACKING (for a clean unload)
-- ================================================================
local _connections = {}
local function bind(conn) _connections[#_connections + 1] = conn; return conn end
local espUnload = nil  -- assigned inside the ESP block, called by cleanup()


-- ================================================================
-- // HELD-ITEM RESOLVER (universal)
-- //   1. an equipped Tool inside the character (standard tools/guns/melee)
-- //   2. a replicated attribute some custom-inventory games use instead
-- //   3. "Hands" when nothing is held
-- //   Add your game's attribute name to HELD_ATTRS if it uses one.
-- ================================================================
local HELD_ATTRS = { "Held", "Equipped", "EquippedItem", "CurrentTool", "Weapon", "Item" }

local heldCache = setmetatable({}, { __mode = "k" })  -- model -> { tool, label, t }
local function heldLabelOf(model)
	if not model then return "Hands" end
	local tool = model:FindFirstChildOfClass("Tool")
	local c = heldCache[model]
	-- hit when the held tool is unchanged (re-check attr fallbacks at most 1/s)
	if c and c.tool == tool and (tool or os.clock() - c.t < 1) then return c.label end
	local label
	if tool then
		label = tool.Name
	else
		for _, attr in ipairs(HELD_ATTRS) do
			local ok, v = pcall(model.GetAttribute, model, attr)
			if ok and type(v) == "string" and v ~= "" then
				label = (v:gsub("_", " "))
				break
			end
		end
		label = label or "Hands"
	end
	heldCache[model] = { tool = tool, label = label, t = os.clock() }
	return label
end

-- ================================================================
-- // TEAM CHECK (generic)
-- //   compares Player.Team when teams exist; in a teamless game it hides
-- //   nobody (returns false) instead of folding everyone onto one team
-- ================================================================
local function sameTeam(player)
	if player == lp then return true end
	local mine, theirs = lp.Team, player.Team
	if mine ~= nil and theirs ~= nil then return mine == theirs end
	return false
end

-- colorpickers may store Color3 directly or { Color = Color3 } in flags
local function resolveColor(flag, fallback)
	local v = flags[flag]
	if typeof(v) == "table" and v.Color then return v.Color end
	if typeof(v) == "Color3" then return v end
	return fallback
end

-- ================================================================
-- // WORLD ESP CATEGORIES (shared by the module + the World tab UI)
-- //   sec = UI section, label = toggle text, flag/dist = flag names,
-- //   dd = default distance, cont = Workspace folders to scan,
-- //   match(name) = optional name filter, useName = show model name,
-- //   static = position cached once (world objects) vs re-read (mobs/vehicles)
-- ================================================================
local WORLD_CATS = {
	-- Nodes (real instance names: Rocks folder holds StoneRock / MetalOre / SulfurOre)
	{ sec = "Nodes", label = "Trees",        flag = "w_trees",    dist = "w_trees_d",    dd = 150, cont = { "Trees" } },
	{ sec = "Nodes", label = "Stone",        flag = "w_stone",    dist = "w_stone_d",    dd = 200, cont = { "Rocks" }, match = function(n) return n == "StoneRock" end },
	{ sec = "Nodes", label = "Metal",        flag = "w_metal",    dist = "w_metal_d",    dd = 250, cont = { "Rocks" }, match = function(n) return n == "MetalOre" end },
	{ sec = "Nodes", label = "Sulfur",       flag = "w_sulfur",   dist = "w_sulfur_d",   dd = 250, cont = { "Rocks" }, match = function(n) return n == "SulfurOre" end },
	-- Pickups
	{ sec = "Pickups", label = "Hemp",       flag = "w_hemp",   dist = "w_hemp_d",   dd = 200, cont = { "WorldLoot", "WildPlants" }, match = function(n) return n == "Hemp" end },
	{ sec = "Pickups", label = "Wild Plants",flag = "w_plants", dist = "w_plants_d", dd = 200, cont = { "WildPlants" } },
	{ sec = "Pickups", label = "Wild Crops", flag = "w_crops",  dist = "w_crops_d",  dd = 200, cont = { "WildCrops" } },
	-- Loot
	{ sec = "Loot", label = "Barrels",       flag = "w_barrels",  dist = "w_barrels_d",  dd = 250, cont = { "WorldLoot" }, match = function(n) return n:find("Barrel") ~= nil end },
	{ sec = "Loot", label = "Crates",        flag = "w_crates",   dist = "w_crates_d",   dd = 300, cont = { "WorldLoot" }, match = function(n) return n:find("Crate") ~= nil and n ~= "MilitaryCrate" and n ~= "EliteCrate" and n ~= "LockedCrate" end },
	{ sec = "Loot", label = "Military Crate",flag = "w_military", dist = "w_military_d", dd = 500, cont = { "WorldLoot" }, match = function(n) return n == "MilitaryCrate" end },
	{ sec = "Loot", label = "Elite Crate",   flag = "w_elite",    dist = "w_elite_d",    dd = 600, cont = { "WorldLoot" }, match = function(n) return n == "EliteCrate" end },
	{ sec = "Loot", label = "Locked Crate",  flag = "w_locked",   dist = "w_locked_d",   dd = 700, cont = { "WorldLoot" }, match = function(n) return n == "LockedCrate" end },
	{ sec = "Loot", label = "Toolbox",       flag = "w_toolbox",  dist = "w_toolbox_d",  dd = 300, cont = { "WorldLoot" }, match = function(n) return n == "ToolBox" end },
	{ sec = "Loot", label = "Metal Ore",     flag = "w_ore",      dist = "w_ore_d",      dd = 250, cont = { "WorldLoot" }, match = function(n) return n:find("Ore") ~= nil end },
	-- Mobs
	{ sec = "Mobs", label = "Scientists",    flag = "w_sci",      dist = "w_sci_d",      dd = 600, cont = { "Scientists" }, useName = true, static = false },
	{ sec = "Mobs", label = "Animals",       flag = "w_animals",  dist = "w_animals_d",  dd = 400, cont = { "Animals" },    useName = true, static = false, deep = true },
	{ sec = "Mobs", label = "Sleepers",      flag = "w_sleepers", dist = "w_sleepers_d", dd = 500, cont = { "Sleepers" },   useName = true },
	-- World Items
	{ sec = "World Items", label = "Dropped Items",   flag = "w_drops",     dist = "w_drops_d",     dd = 200, cont = { "DroppedItems" }, match = function(n) return n == "Drop" end },
	{ sec = "World Items", label = "Death Backpacks", flag = "w_backpacks", dist = "w_backpacks_d", dd = 300, cont = { "DroppedItems" }, match = function(n) return n == "DeathBackpack" end },
	-- Vehicles
	{ sec = "Vehicles", label = "Vehicles",  flag = "w_vehicles", dist = "w_vehicles_d", dd = 800, cont = { "Vehicles", "Minicopters", "Boats", "Drones" }, useName = true, static = false },
	-- Events
	{ sec = "Events", label = "Airdrop",     flag = "w_airdrop",  dist = "w_airdrop_d",  dd = 3000, cont = { "Airdrops" }, static = false },
	{ sec = "Events", label = "Patrol Heli", flag = "w_heli",     dist = "w_heli_d",     dd = 3000, cont = { "PatrolHeli" }, static = false },
	{ sec = "Events", label = "Bradley",     flag = "w_bradley",  dist = "w_bradley_d",  dd = 2000, cont = { "BradleyAPC" }, static = false },
}
local WORLD_SEC_COLOR = {
	Nodes = c3(120, 200, 120), Pickups = c3(170, 230, 120), Loot = c3(255, 180, 80),
	Mobs = c3(255, 100, 100), ["World Items"] = c3(120, 200, 255), Vehicles = c3(200, 160, 255),
	Events = c3(255, 220, 100),
}

-- ================================================================
-- // OVX SHARED (cross-module state + KI v2.1 helpers)
-- //   OVX.saTarget            <- Silent Aim publishes its lock every scan
-- //   OVX.saRedirectAt        <- stamped when SA rewrites a Fire direction
-- //   OVX.saRedirectAt        <- stamped when Silent Aim rewrites a Fire
-- //   OVX.arrowSpeed/-Gravity <- captured live from BowRemotes.Flight
-- ================================================================
local OVX = { saTarget = nil, saRedirectAt = nil, arrowSpeed = nil, arrowGravity = 18 }
-- ================================================================
-- // RAGEBOT STATE
-- //   The master toggle is reversible. While it is on, every Silent Aim
-- //   toggle is forced ON and cannot be switched off from a control,
-- //   keybind, config load or console setter.
-- ================================================================
do
	local ragebotRequired = {
		sa_enabled = true,
		sa_team_check = true,
		sa_target_npc = true,
		sa_show_fov = true,
		sa_snapline = true,
		sa_snapline_npc = true,
		sa_cross = true,
		sa_force_head = true,
		sa_instant_hit = true,
		sa_remote_jack = true,
		sa_bone = "Head",
		sa_bow_enabled = false,
		wm_norecoil = true,
		wm_nospread = true,
		wm_nosway = true,
		wm_instantads = true,
		wm_autofire = true,
		wm_rapidfire = true,
		wm_rpm = 1200,
		wm_instantcharge = true,
		wm_fastcycle = true,
		wm_range = true,
		tb_enabled = true,
		tb_npc = true,
		tb_visible = false,
		tb_skip_holding = false,
		tb_max_dist = 0,
	}
	OVX.ragebotLocked = ragebotRequired
	OVX.ragebotRestore = nil

	enforceRagebotFlag = function(flag, value)
		if flags["rb_enabled"] ~= true then return value end
		local required = ragebotRequired[flag]
		if required == nil then return value end
		local candidate = value
		if type(required) == "boolean" then
			candidate = value == true or value == 1 or value == "true" or value == "on"
		end
		if candidate ~= required then return required end
		return candidate
	end

	function OVX.ragebotSync()
		for flag, value in pairs(ragebotRequired) do
			setCompatFlag(flag, value, true)
		end
		if OVX.ragebotQuickSync then pcall(OVX.ragebotQuickSync, true) end
	end

	function OVX.ragebotApply(on)
		on = on == true
		if on and not OVX.ragebotRestore then
			OVX.ragebotRestore = {}
			for flag in pairs(ragebotRequired) do
				OVX.ragebotRestore[flag] = flags[flag]
			end
		end
		flags["rb_enabled"] = on
		if OVX.ragebotQuickSync then pcall(OVX.ragebotQuickSync, on) end
		if on then
			OVX.ragebotSync()
		elseif OVX.ragebotRestore then
			local saved = OVX.ragebotRestore
			OVX.ragebotRestore = nil
			for flag, value in pairs(saved) do
				setCompatFlag(flag, value, true)
			end
		end
		return on
	end

	function OVX.saFov()
		if flags["rb_enabled"] == true then
			local radius = tonumber(flags["rb_fov_radius"]) or 10000
			return math.max(1000, math.min(50000, radius))
		end
		return tonumber(flags["sa_fov"]) or 120
	end

	function OVX.ragebotTargetScore(part, camera, crosshair, fov)
		if not part or not camera then return nil end
		local ok, score = pcall(function()
			local sp, on = camera:WorldToViewportPoint(part.Position)
			local inFront = on and sp.Z > 0
			local screenD = inFront and (v2new(sp.X, sp.Y) - crosshair).Magnitude or fov
			if inFront and screenD > fov then return nil end
			local worldD = (part.Position - camera.CFrame.Position).Magnitude
			return worldD + screenD / 100000
		end)
		return ok and score or nil
	end

	function OVX.saMaxDist()
		if flags["rb_enabled"] == true then
			return tonumber(flags["rb_max_dist"]) or 0
		end
		return tonumber(flags["sa_max_dist"]) or 0
	end

	local lastSync = 0
	bind(RunService.Heartbeat:Connect(function()
		if flags["rb_enabled"] ~= true then return end
		local now = os.clock()
		if now - lastSync < 0.25 then return end
		lastSync = now
		pcall(OVX.ragebotSync)
	end))
end
do
	function OVX.notify(text)
		print("[OVX] " .. tostring(text))
		pcall(function()
			if library.notification then
				library:notification({ text = tostring(text), time = 4 })
			end
		end)
	end

	-- relations (ally/enemy from clan/team attributes)
	function OVX.relation(plr)
		if plr == lp then return "self" end
		local myTeam = lp:GetAttribute("TeamId")
		if myTeam ~= nil and myTeam ~= 0 and plr:GetAttribute("TeamId") == myTeam then return "team" end
		local mates = lp:GetAttribute("TeamMates")
		if type(mates) == "string" and string.find(mates, "," .. plr.UserId .. ",", 1, true) then return "team" end
		local myClan, theirClan = lp:GetAttribute("ClanId"), plr:GetAttribute("ClanId")
		if myClan ~= nil and theirClan ~= nil and myClan ~= theirClan then
			local wars = lp:GetAttribute("ClanWars")
			if type(wars) == "string" and string.find(wars, "," .. theirClan .. ",", 1, true) then return "enemy" end
			local allies = lp:GetAttribute("ClanAllies")
			if type(allies) == "string" and string.find(allies, "," .. theirClan .. ",", 1, true) then return "ally" end
		end
		return "neutral"
	end

	-- melee resolver: held tool must carry SwingTime/Reach (guns don't)
	function OVX.meleeTool()
		local char = lp.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if not tool then return nil end
		if tonumber(tool:GetAttribute("SwingTime")) == nil then return nil end
		return tool
	end

	-- staff tells (StaffTag decompile) + inventory-attribute filters
	local OWNER_NAMES = { shot5675 = true, captain08 = true, knightsinteractive = true }
	local INV_SKIP = {
		Admin = true, ModPanel = true, SurvivorPlus = true, AdminFly = true, AdminGhost = true,
		AdminMasterOff = true, TeamId = true, TeamMates = true, ClanId = true, ClanTag = true,
		ClanColor = true, ClanWars = true, ClanAllies = true, BaseFov = true, CrosshairColor = true,
		CrosshairOn = true, CrosshairSize = true, DetailDist = true, Device = true, ButtonSize = true,
		InventoryOpen = true, OverlayPanel = true, LoadingScreen = true, InvLoaded = true,
		Sprinting = true, Crouching = true, Asleep = true, Dead = true, Spawning = true,
		VolumeGuns = true, VolumeMaster = true, TourSeen = true,
		AimAssist = true, AimLookSpeed = true, AutoSprint = true, TiltAim = true,
		ShakeScale = true, ViewmodelFov = true, ShowFps = true, Vibrate = true,
		HandOutlines = true, WakeScreen = true, DBUXReady = true, TextSize = true,
		TvTextSize = true, HudBarsTop = true, HudRowHeight = true, HudStackTop = true,
		HudWarn = true, ShieldStamina = true, ShieldStaminaAt = true, SleeperSince = true,
		BeltTop = true, FirstSteps = true, SaveApplied = true, SaveLoaded = true,
		SaveSpawnAt = true, SaveSpawnForce = true, FS_Done = true, FS_State = true,
		FS_Density = true, MatThrust = true, Matrix = true, Visuals = true,
		ButtonLayout = true, ControlsSeen = true,
	}
	local function invSkipPrefix(k)
		return string.find(k, "^FS_") ~= nil or string.find(k, "^FSquare") ~= nil
			or string.find(k, "^Gfx") ~= nil or string.find(k, "^Hud") ~= nil
			or string.find(k, "^Save") ~= nil or string.find(k, "^Uv") ~= nil
			or string.find(k, "^MatThrust") ~= nil or string.find(k, "^Matrix") ~= nil
			or string.find(k, "^Volume") ~= nil or string.find(k, "^Fragments") ~= nil
	end
	function OVX.invSkip(k) return INV_SKIP[k] ~= nil or invSkipPrefix(k) end

	function OVX.staffReason(p)
		if p:GetAttribute("Admin") then return "Admin" end
		if p:GetAttribute("ModPanel") then return "Mod" end
		if p:GetAttribute("AdminFly") or p:GetAttribute("AdminGhost") then return "AdminPower" end
		if OWNER_NAMES[string.lower(p.Name)] then return "Owner" end
		local c = p.Character
		if c and c:GetAttribute("AntiCheatFrozen") then return "Frozen(ac)" end
		return nil
	end

	-- gathering swing helpers (GatheringRemotes.Swing + ChopMark weakspot X)
	local swingRemote = nil
	function OVX.swingRemote()
		if swingRemote and swingRemote.Parent then return swingRemote end
		local f = RepStorage:FindFirstChild("GatheringRemotes")
		swingRemote = f and f:FindFirstChild("Swing") or nil
		return swingRemote
	end
	local function markValid(node)
		local cf = node:GetAttribute("MarkCF")
		if typeof(cf) ~= "CFrame" then return nil end
		local r = node:GetAttribute("MarkR")
		if typeof(r) ~= "number" or typeof(node:GetAttribute("MarkSeed")) ~= "number"
			or typeof(node:GetAttribute("MarkW")) ~= "number" or r <= 0 then return nil end
		return cf
	end
	OVX.markValid = markValid
	local function claimPartFor(node, pos)
		local best, bestD, fallback, fbD
		for _, p in ipairs(node:GetDescendants()) do
			if p:IsA("BasePart") then
				local d = (p.Position - pos).Magnitude
				-- prefer the real harvest hitbox; ChopMark canvases are
				-- CanQuery=false visuals, but usable as a last resort
				local visual = p:FindFirstAncestor("ChopMark") ~= nil
				if not visual and p.CanQuery ~= false then
					if not bestD or d < bestD then best, bestD = p, d end
				elseif not fbD or d < fbD then
					fallback, fbD = p, d
				end
			end
		end
		return best or fallback
	end
	OVX.claimPartFor = claimPartFor

	-- flesh claim: the same Swing packet a manual player hit sends
	function OVX.swingClaimFlesh(part)
		local remote = OVX.swingRemote()
		if not (remote and typeof(part) == "Instance" and part.Parent) then return false end
		local gr = RepStorage:FindFirstChild("GatheringRemotes")
		local st = (gr and gr:GetAttribute("ClientHits") == true) and workspace:GetServerTimeNow() or nil
		pcall(remote.FireServer, remote, part, part.Position, st, true)
		return true
	end

	-- node claim: strike at the weakspot X mark when one exists
	function OVX.swingNodeClaim(node)
		local remote = OVX.swingRemote()
		if not (remote and node and node.Parent) then return false end
		local aimPos
		local mark = markValid(node)
		if mark then
			aimPos = mark.Position
		else
			local okP, cf = pcall(function() return node:GetPivot().Position end)
			aimPos = okP and typeof(cf) == "Vector3" and cf or nil
		end
		if not aimPos then return false end
		local part = claimPartFor(node, aimPos)
		if not part then return false end
		OVX.afClaims = (OVX.afClaims or 0) + 1
		OVX.afLastClaim = {
			node = node.Name, marked = mark ~= nil, aim = aimPos,
			part = part.Name, t = os.clock(),
		}
		local gr = RepStorage:FindFirstChild("GatheringRemotes")
		local st = (gr and gr:GetAttribute("ClientHits") == true) and workspace:GetServerTimeNow() or nil
		pcall(remote.FireServer, remote, part, aimPos, st, false)
		return true
	end
end

-- ================================================================
-- // SHARED VIEWMODEL CACHE + PROPERTY RESTORE
-- //   One shallow camera-side cache powers hand chams, gun chams,
-- //   tracers and the skin changer. Original properties are stored
-- //   once so toggling or unloading never leaves a modified part.
-- ================================================================
do
	local vmOriginals = {}
	OVX.vmOriginals = vmOriginals
	OVX.vmPropertyNames = { "Material", "Color", "Transparency", "Reflectance", "MeshId", "TextureId" }
	local viewRoots, viewParts = {}, {}
	OVX.viewModels, OVX.viewModelParts = viewRoots, viewParts
	local viewRefreshLock = false
	local pendingViewRefresh = false
	local viewRefreshScheduled = false
	local lastViewFlush = 0
	OVX.viewmodelUnloaded = false

	local function lower(value) return string.lower(tostring(value or "")) end
	OVX.lowerName = lower

	local function saveOriginal(part)
		if not part or vmOriginals[part] then return end
		local data = {}
		pcall(function()
			data.Material = part.Material
			data.Color = part.Color
			data.Transparency = part.Transparency
			data.Reflectance = part.Reflectance
			data.MeshId = part.MeshId
			data.TextureId = part.TextureId
		end)
		vmOriginals[part] = data
	end

	local function restoreOriginal(part)
		local data = part and vmOriginals[part]
		if not data then return end
		pcall(function()
			if data.Material ~= nil then part.Material = data.Material end
			if data.Color ~= nil then part.Color = data.Color end
			if data.Transparency ~= nil then part.Transparency = data.Transparency end
			if data.Reflectance ~= nil then part.Reflectance = data.Reflectance end
			if data.MeshId ~= nil then part.MeshId = data.MeshId end
			if data.TextureId ~= nil then part.TextureId = data.TextureId end
		end)
	end

	function OVX.saveVmOriginal(part) saveOriginal(part) end
	function OVX.restoreVmOriginal(part) restoreOriginal(part) end
	function OVX.restoreAllVmOriginals(clear)
		for part in pairs(vmOriginals) do restoreOriginal(part) end
		if clear then table.clear(vmOriginals) end
	end

	local HAND_WORDS = { "hand", "arm", "sleeve", "glove", "wrist", "forearm" }
	local PROTECTED_WORDS = { "muzzle", "flash", "smoke", "particle", "beam", "tracer", "bullet", "light" }
	local function nameMatches(part, words)
		local obj, depth = part, 0
		while obj and depth < 5 do
			local name = ""
			pcall(function() name = lower(obj.Name) end)
			for _, word in ipairs(words) do
				if string.find(name, word, 1, true) then return true end
			end
			obj = obj.Parent
			depth = depth + 1
		end
		return false
	end
	function OVX.isHandViewPart(part) return nameMatches(part, HAND_WORDS) end
	function OVX.isProtectedViewPart(part) return nameMatches(part, PROTECTED_WORDS) end

	local function collectViewParts(root, out, depth, maxDepth)
		out = out or {}
		depth = depth or 0
		maxDepth = maxDepth or 6
		if not root or depth >= maxDepth or #out >= 400 then return out end
		local children
		local ok = pcall(function() children = root:GetChildren() end)
		if not ok or type(children) ~= "table" then return out end
		for _, child in ipairs(children) do
			local isPart = false
			pcall(function() isPart = child:IsA("BasePart") end)
			if isPart and #out < 400 then out[#out + 1] = child end
			if #out < 400 then collectViewParts(child, out, depth + 1, maxDepth) end
		end
		return out
	end
	OVX.collectViewParts = collectViewParts

	local function looksLikeViewRoot(obj)
		if not obj then return false end
		local name = ""
		pcall(function() name = lower(obj.Name) end)
		local words = { "viewmodel", "view model", "arm", "hand", "weapon", "gun", "tool", "bow" }
		for _, word in ipairs(words) do
			if string.find(name, word, 1, true) then return true end
		end
		local parts = collectViewParts(obj, {}, 0, 3)
		for _, part in ipairs(parts) do
			local partName = ""
			pcall(function() partName = lower(part.Name) end)
			if string.find(partName, "muzzle", 1, true) or string.find(partName, "flash", 1, true)
				or string.find(partName, "hand", 1, true) or string.find(partName, "arm", 1, true) then
				return true
			end
		end
		return false
	end

	function OVX.refreshViewModels(force)
		if OVX.viewmodelUnloaded then return end
		if viewRefreshLock and force ~= true then return end
		table.clear(viewRoots)
		table.clear(viewParts)
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local seen = {}
		local function consider(obj)
			if not obj or seen[obj] then return end
			local candidate = false
			pcall(function()
				candidate = obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("Tool")
					or obj:IsA("Accessory") or obj:IsA("BasePart")
			end)
			if candidate and looksLikeViewRoot(obj) then
				seen[obj] = true
				viewRoots[#viewRoots + 1] = obj
			end
		end
		local function scanLayer(list, depth)
			if type(list) ~= "table" then return end
			for _, obj in ipairs(list) do
				consider(obj)
				if depth < 2 then
					local kids
					pcall(function() kids = obj:GetChildren() end)
					if type(kids) == "table" then scanLayer(kids, depth + 1) end
				end
			end
		end
		local top
		pcall(function() top = cam:GetChildren() end)
		scanLayer(top or {}, 0)
		for _, root in ipairs(viewRoots) do collectViewParts(root, viewParts, 0, 6) end
	end

	local flushViewRefresh
	local function scheduleViewRefresh(delay)
		if OVX.viewmodelUnloaded or viewRefreshScheduled then return end
		viewRefreshScheduled = true
		delay = clamp(tonumber(delay) or 0.06, 0, 0.5)
		local function run()
			viewRefreshScheduled = false
			pendingViewRefresh = true
			flushViewRefresh()
		end
		local scheduled = false
		if type(task) == "table" and type(task.delay) == "function" then
			scheduled = pcall(task.delay, delay, run)
		end
		if not scheduled then run() end
	end
	flushViewRefresh = function()
		if OVX.viewmodelUnloaded or viewRefreshLock or not pendingViewRefresh then return end
		local hz = clamp(tonumber(flags["sf_vmodel_refresh_hz"]) or 5, 1, 20)
		local minInterval = 1 / hz
		local now = os.clock()
		local forceNow = OVX._forceViewFlush == true
		if not forceNow and now - lastViewFlush < minInterval then
			viewRefreshScheduled = false
			scheduleViewRefresh(minInterval - (now - lastViewFlush))
			return
		end
		OVX._forceViewFlush = false
		pendingViewRefresh = false
		viewRefreshScheduled = false
		lastViewFlush = now
		viewRefreshLock = true
		local ok = pcall(function()
			OVX.refreshViewModels(true)
			if OVX.sciFiApply then pcall(OVX.sciFiApply, true) end
			if OVX.skinReapply then pcall(OVX.skinReapply) end
		end)
		viewRefreshLock = false
		if not ok then pendingViewRefresh = false end
	end
	function OVX.queueViewRefresh(force)
		if OVX.viewmodelUnloaded then return end
		pendingViewRefresh = true
		if force then OVX._forceViewFlush = true end
		scheduleViewRefresh(force and 0 or 0.06)
	end
	OVX.flushViewRefresh = flushViewRefresh
	OVX.scheduleViewRefresh = scheduleViewRefresh

	local cameraEvents = {}
	local function bindCameraEvents()
		for _, conn in ipairs(cameraEvents) do pcall(function() conn:Disconnect() end) end
		table.clear(cameraEvents)
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local function watch(event)
			if event and event.Connect then
				cameraEvents[#cameraEvents + 1] = event:Connect(function() OVX.queueViewRefresh() end)
			end
		end
		watch(cam.ChildAdded)
		watch(cam.ChildRemoved)
		watch(cam.DescendantAdded)
		watch(cam.DescendantRemoving)
	end
	bindCameraEvents()
	bind(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindCameraEvents()
		OVX.queueViewRefresh()
	end))
	OVX.refreshViewModels(true)

	function OVX.finalizeViewmodelCleanup()
		OVX.viewmodelUnloaded = true
		pendingViewRefresh = false
		viewRefreshScheduled = false
		OVX.restoreAllVmOriginals(true)
		table.clear(viewRoots)
		table.clear(viewParts)
		for _, conn in ipairs(cameraEvents) do pcall(function() conn:Disconnect() end) end
		table.clear(cameraEvents)
	end
end

-- ================================================================
-- // SCI-FI V2: HAND / GUN CHAMS + MUZZLE-TO-IMPACT BULLET TRACERS
-- //   No second menu. Every material, preset, tracer and protection
-- //   switch is driven by the Vault UI flags below.
-- ================================================================
do
	local env = getgenv()
	local previousSciFi = env.SciFiChams
	local previousSciFiUnload = env.SciFiChamsUnload
	local previousFireTest = env.fireTestTracer
	if type(previousSciFiUnload) == "function" then pcall(previousSciFiUnload) end

	local MATERIALS = {
		"ForceField", "Neon", "Glass", "Glacier", "Foil", "DiamondPlate",
		"CorrodedMetal", "Metal", "CrackedLava", "Ice", "Basalt", "Slate",
		"Granite", "Pebble", "SmoothPlastic", "Marble", "Cobblestone",
	}
	local PRESETS = {
		Cyan    = c3(0, 255, 255),
		Magenta = c3(255, 0, 255),
		Green   = c3(0, 255, 120),
		Purple  = c3(155, 105, 230),
		Gold    = c3(255, 205, 70),
		Red     = c3(255, 60, 60),
		White   = c3(255, 255, 255),
		Dark    = c3(35, 35, 45),
	}
	local PRESET_NAMES = { "Cyan", "Magenta", "Green", "Purple", "Gold", "Red", "White", "Dark" }
	OVX.sciFiMaterials = MATERIALS
	OVX.sciFiPresets = PRESETS
	OVX.sciFiPresetNames = PRESET_NAMES

	local function presetColor(name, fallback)
		return PRESETS[tostring(name or "")] or fallback or PRESETS.Cyan
	end
	local function resolveMaterial(name)
		local ok, material = pcall(function() return Enum.Material[tostring(name or "ForceField")] end)
		if ok and material then return material end
		return Enum.Material.ForceField
	end
	local function partColor(prefix)
		if flags[prefix .. "_use_preset"] ~= false then
			return presetColor(flags[prefix .. "_preset"], PRESETS.Cyan)
		end
		return resolveColor(prefix .. "_color", PRESETS.Cyan)
	end
	local function tracerColor()
		if flags["sf_tracer_use_preset"] ~= false then
			return presetColor(flags["sf_tracer_preset"], PRESETS.Cyan)
		end
		return resolveColor("sf_tracer_color", PRESETS.Cyan)
	end
	local function impactColor()
		return resolveColor("sf_tracer_impact_color", tracerColor())
	end

	local tracerRecords = {}
	local sciFiAppliedParts = {}
	local function destroyRecord(record)
		if not record or record.destroyed then return end
		record.destroyed = true
		for _, instance in ipairs(record.instances or {}) do
			pcall(function() instance:Destroy() end)
		end
	end
	local function trimTracers()
		local maxCount = clamp(tonumber(flags["sf_tracer_max"]) or 24, 1, 80)
		while #tracerRecords > maxCount do
			local old = table.remove(tracerRecords, 1)
			destroyRecord(old)
		end
	end
	local function trackRecord(record)
		tracerRecords[#tracerRecords + 1] = record
		trimTracers()
	end
	function OVX.clearSciFiTracers()
		for _, record in ipairs(tracerRecords) do destroyRecord(record) end
		table.clear(tracerRecords)
	end

	local function tracerParent()
		return Workspace.Terrain or Workspace
	end
	local function tracerNumber(flag, fallback, low, high)
		return clamp(tonumber(flags[flag]) or fallback, low, high)
	end
	local function create3DTracer(startPos, endPos, color)
		if typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then return end
		local parent = tracerParent()
		local a0, a1, beam = Instance.new("Attachment"), Instance.new("Attachment"), Instance.new("Beam")
		local width = tracerNumber("sf_tracer_width", 0.2, 0.02, 3)
		local segments = math.floor(tracerNumber("sf_tracer_segments", 1, 1, 20) + 0.5)
		local lifetime = tracerNumber("sf_tracer_lifetime", 0.25, 0.03, 3)
		pcall(function()
			a0.Parent = parent
			a1.Parent = parent
			a0.WorldPosition = startPos
			a1.WorldPosition = endPos
			beam.Parent = parent
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Width0 = width
			beam.Width1 = width
			beam.Segments = segments
			beam.LightEmission = tracerNumber("sf_tracer_glow", 5, 0, 10) / 10
			beam.LightInfluence = tracerNumber("sf_tracer_light_influence", 0, 0, 10) / 10
			beam.FaceCamera = flags["sf_tracer_face_camera"] ~= false
			beam.Enabled = true
		end)
		pcall(function()
			beam.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, color),
				ColorSequenceKeypoint.new(1, color),
			})
		end)
		local record = { instances = { a0, a1, beam } }
		trackRecord(record)
		if type(task) == "table" and type(task.delay) == "function" then
			task.delay(lifetime, function() destroyRecord(record) end)
		end
	end
	local function createImpact(position, color)
		if flags["sf_tracer_impact_enabled"] == false or typeof(position) ~= "Vector3" then return end
		local size = tracerNumber("sf_tracer_impact_size", 0.3, 0.05, 3)
		local lifetime = tracerNumber("sf_tracer_lifetime", 0.25, 0.03, 3)
		local part = Instance.new("Part")
		pcall(function()
			part.Name = "OVXSciFiImpact"
			part.Size = v3new(size, size, size)
			part.Shape = Enum.PartType.Ball
			part.Material = Enum.Material.Neon
			part.Color = color
			part.Transparency = 0.2
			part.CanCollide = false
			part.Anchored = true
			part.CFrame = CFrame.new(position)
			part.Parent = tracerParent()
		end)
		local record = { instances = { part } }
		trackRecord(record)
		if type(task) == "table" and type(task.delay) == "function" then
			task.delay(lifetime, function() destroyRecord(record) end)
		end
	end
	function OVX.fireTracer(startPos, endPos, color)
		color = color or tracerColor()
		create3DTracer(startPos, endPos, color)
		createImpact(endPos, impactColor())
	end

	local function findMuzzles()
		local out = {}
		for _, part in ipairs(OVX.viewModelParts or {}) do
			local name = OVX.lowerName(part.Name)
			if string.find(name, "muzzle", 1, true) or string.find(name, "flash", 1, true) then
				pcall(function() out[#out + 1] = part.Position end)
			end
		end
		if #out == 0 then
			local cam = Workspace.CurrentCamera
			if cam then
				pcall(function() out[1] = cam.CFrame.Position + cam.CFrame.LookVector * 2 end)
			end
		end
		if #out == 0 then out[1] = v3new(0, 0, 0) end
		return out
	end
	local function raycastImpact(start, direction, range)
		if flags["sf_tracer_follow_sa"] ~= false then
			local target = OVX.saTarget
			if target then
				if typeof(target.point) == "Vector3" then return target.point end
				if target.part and target.part.Parent then
					local point
					pcall(function() point = target.part.Position end)
					if typeof(point) == "Vector3" then return point end
				end
			end
		end
		if flags["sf_tracer_raycast"] == false then return start + direction * range end
		local params = RaycastParams.new()
		pcall(function()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local filter = { lp.Character }
			for _, root in ipairs(OVX.viewModels or {}) do filter[#filter + 1] = root end
			params.FilterDescendantsInstances = filter
		end)
		local hit
		pcall(function() hit = Workspace:Raycast(start, direction * range, params) end)
		if hit and typeof(hit.Position) == "Vector3" then return hit.Position end
		return start + direction * range
	end
	local function shotFromArgs(...)
		local args = { ... }
		local claimOrigin
		for _, value in ipairs(args) do
			if type(value) == "table" then
				pcall(function()
					if typeof(value.o) == "Vector3" then claimOrigin = value.o end
					if typeof(value.origin) == "Vector3" then claimOrigin = value.origin end
				end)
			end
		end
		local v1 = typeof(args[1]) == "Vector3" and args[1] or nil
		local v2 = typeof(args[2]) == "Vector3" and args[2] or nil
		local start, direction
		if v1 and v2 then
			local m1, m2 = v1.Magnitude, v2.Magnitude
			if m2 > 0.001 and math.abs(m2 - 1) < 0.25 then
				start, direction = v1, v2
			elseif claimOrigin and m1 > 0.001 and math.abs(m1 - 1) < 0.25 then
				start, direction = claimOrigin, v1
			elseif m1 > 0.001 then
				start, direction = v1, v2.Unit
			end
		elseif v1 then
			if claimOrigin then
				start = claimOrigin
				direction = v1.Magnitude > 0.001 and v1.Unit or nil
			else
				start = v1
			end
		end
		local cam = Workspace.CurrentCamera
		if typeof(start) ~= "Vector3" then
			start = cam and (cam.CFrame.Position + cam.CFrame.LookVector * 2) or v3new(0, 0, 0)
		end
		if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.001 then
			direction = cam and cam.CFrame.LookVector or v3new(0, 0, -1)
		end
		if math.abs(direction.Magnitude - 1) > 0.25 then direction = direction.Unit end
		return start, direction
	end
	local function isShotRemote(remote)
		if remote == nil then return true end
		local name, path = "", ""
		pcall(function() name = OVX.lowerName(remote.Name) end)
		pcall(function() path = OVX.lowerName(remote:GetFullName()) end)
		return string.find(name, "fire", 1, true) or string.find(name, "launch", 1, true)
			or string.find(path, "fire", 1, true) or string.find(path, "bowremotes", 1, true)
	end
	function OVX.sciFiTracer(remote, ...)
		if flags["sf_tracers_enabled"] == false or not isShotRemote(remote) then return end
		if flags["sf_tracer_include_bow"] == false then
			local name, path = "", ""
			pcall(function() name = OVX.lowerName(remote and remote.Name) end)
			pcall(function() path = OVX.lowerName(remote and remote:GetFullName()) end)
			if string.find(name, "bow", 1, true) or string.find(path, "bow", 1, true) then return end
		end
		local start, direction = shotFromArgs(...)
		local muzzles = findMuzzles()
		if flags["sf_tracer_use_muzzle"] ~= false then start = muzzles[1] or start end
		local range = clamp(tonumber(flags["sf_tracer_range"]) or 1000, 50, 5000)
		local finish = raycastImpact(start, direction, range)
		local color = tracerColor()
		OVX.fireTracer(start, finish, color)
		if flags["sf_tracer_double_gun"] ~= false and #muzzles > 1 then
			OVX.fireTracer(muzzles[2], finish, color)
		end
	end
	function OVX.fireTestTracer()
		local muzzles = findMuzzles()
		local cam = Workspace.CurrentCamera
		local start = muzzles[1] or (cam and (cam.CFrame.Position + cam.CFrame.LookVector * 2) or v3new())
		local direction = cam and cam.CFrame.LookVector or v3new(0, 0, -1)
		local range = clamp(tonumber(flags["sf_tracer_range"]) or 1000, 50, 5000)
		local finish = raycastImpact(start, direction, range)
		local color = tracerColor()
		OVX.fireTracer(start, finish, color)
		if flags["sf_tracer_double_gun"] ~= false and #muzzles > 1 then
			OVX.fireTracer(muzzles[2], finish, color)
		end
		return true
	end

	local function applyPart(part)
		local ok, isPart = pcall(function() return part:IsA("BasePart") end)
		if not ok or not isPart then return end
		if flags["sf_protect_muzzle"] ~= false and OVX.isProtectedViewPart(part) then return end
		local hand = OVX.isHandViewPart(part)
		local enabled = (hand and flags["sf_hands_enabled"] == true)
			or (not hand and flags["sf_gun_enabled"] == true)
		if not enabled then
			if sciFiAppliedParts[part] then
				OVX.restoreVmOriginal(part)
				sciFiAppliedParts[part] = nil
			end
			return
		end
		OVX.saveVmOriginal(part)
		sciFiAppliedParts[part] = true
		local prefix = hand and "sf_hand" or "sf_gun"
		local material = resolveMaterial(flags[prefix .. "_material"])
		local color = partColor(prefix)
		local transparency = clamp((tonumber(flags[prefix .. "_transparency"]) or 0) / 10, 0, 1)
		local reflectance = clamp((tonumber(flags[prefix .. "_reflectance"]) or 2) / 10, 0, 1)
		pcall(function()
			part.Material = material
			part.Color = color
			part.Transparency = transparency
			part.Reflectance = reflectance
		end)
	end
	function OVX.sciFiApply(skipRefresh)
		if skipRefresh ~= true then OVX.refreshViewModels(true) end
		local roots = OVX.viewModels or {}
		local limit = flags["sf_double_gun_fix"] ~= false and #roots or math.min(1, #roots)
		local parts = {}
		for index = 1, limit do
			table.clear(parts)
			OVX.collectViewParts(roots[index], parts, 0, 6)
			for _, part in ipairs(parts) do applyPart(part) end
		end
	end
	function OVX.sciFiRestore(reapplySkin)
		OVX.refreshViewModels(true)
		for part in pairs(sciFiAppliedParts) do OVX.restoreVmOriginal(part) end
		table.clear(sciFiAppliedParts)
		if reapplySkin ~= false and OVX.skinReapply then pcall(OVX.skinReapply) end
	end

	local sciFiKeys = {
		"sf_hands_enabled", "sf_gun_enabled", "sf_protect_muzzle", "sf_double_gun_fix",
		"sf_hand_material", "sf_hand_preset", "sf_hand_use_preset", "sf_hand_color",
		"sf_hand_transparency", "sf_hand_reflectance", "sf_gun_material", "sf_gun_preset",
		"sf_gun_use_preset", "sf_gun_color", "sf_gun_transparency", "sf_gun_reflectance",
	}
	local function sciFiHash()
		local rows = {}
		for index, key in ipairs(sciFiKeys) do rows[index] = tostring(flags[key]) end
		return table.concat(rows, "|")
	end
	local lastHash, lastRefresh = sciFiHash(), 0
	bind(RunService.Heartbeat:Connect(function()
		local hz = clamp(tonumber(flags["sf_vmodel_refresh_hz"]) or 5, 1, 20)
		local now = os.clock()
		if now - lastRefresh < 1 / hz then return end
		lastRefresh = now
		local hash = sciFiHash()
		if hash ~= lastHash or flags["sf_hands_enabled"] or flags["sf_gun_enabled"] then
			lastHash = hash
			pcall(OVX.queueViewRefresh)
		end
	end))

	local sciFiUnloaded = false
	local sciFiObject
	function OVX.sciFiUnload()
		if sciFiUnloaded then return end
		sciFiUnloaded = true
		OVX.clearSciFiTracers()
		pcall(OVX.sciFiRestore, false)
		if env.SciFiChams == sciFiObject then env.SciFiChams = previousSciFi or nil end
		if env.SciFiChamsUnload == OVX.sciFiUnload then env.SciFiChamsUnload = previousSciFiUnload or nil end
		if env.fireTestTracer == OVX.fireTestTracer then env.fireTestTracer = previousFireTest or nil end
		OVX.sciFiUnload = nil
	end
	sciFiObject = {
		Settings = flags, Config = flags, Materials = MATERIALS, Presets = PRESETS,
		PresetNames = PRESET_NAMES, Apply = OVX.sciFiApply, Restore = OVX.sciFiRestore,
		FireTestTracer = OVX.fireTestTracer, fireTestTracer = OVX.fireTestTracer,
		ClearTracers = OVX.clearSciFiTracers, Unload = OVX.sciFiUnload,
	}
	env.SciFiChams = sciFiObject
	env.SciFiChamsUnload = OVX.sciFiUnload
	env.fireTestTracer = OVX.fireTestTracer
	bind({ Disconnect = function() if OVX.sciFiUnload then pcall(OVX.sciFiUnload) end end })
end

-- ================================================================
-- // SKIN CHANGER — GLOBAL API + PER-GUN / ALL-GUN VISUALS
-- //   getgenv().SetSkin("Assault Rifle", "Tempered")
-- //   getgenv().SetAllSkins("Banana")
-- //   getgenv().ResetSkins()
-- //   getgenv().selectWeapon("Python Revolver")
-- ================================================================
do
	local env = getgenv()
	local previousSkinChanger = env.SkinChanger
	local previousSkinUnload = env.SkinChangerUnload
	local previousSetSkin = env.SetSkin
	local previousSetAllSkins = env.SetAllSkins
	local previousResetSkins = env.ResetSkins
	local previousSelectWeapon = env.selectWeapon
	if type(previousSkinUnload) == "function" then pcall(previousSkinUnload) end
	if type(previousSkinChanger) == "table" and type(previousSkinChanger.Unload) == "function" then
		pcall(previousSkinChanger.Unload)
	end

	local WEAPONS = {
		"Assault Rifle", "Bolt Action Rifle", "Python Revolver", "Semi-Automatic Pistol",
		"Pump Shotgun", "Thompson", "Custom SMG", "MP5A4", "M249",
		"LR-300 Assault Rifle", "M92 Pistol", "Revolver", "Semi-Automatic Rifle",
		"Double Barrel Shotgun", "Waterpipe Shotgun", "Eoka Pistol", "Nailgun",
	}
	local SKINS = { "Default", "Forgefire", "Tempered", "Banana", "CrystalHeart", "WinterHunter" }
	local SKIN_FALLBACK = {
		forgefire   = { material = "CrackedLava", color = c3(255, 95, 35) },
		tempered    = { material = "Metal", color = c3(170, 180, 195) },
		banana      = { material = "SmoothPlastic", color = c3(255, 225, 55) },
		crystalheart= { material = "Glass", color = c3(255, 90, 210) },
		winterhunter= { material = "Ice", color = c3(145, 220, 255) },
	}
	OVX.skinWeaponNames = WEAPONS
	OVX.skinKnownNames = SKINS

	local config, assetsByName = {}, {}
	local discoveredWeapons, discoveredSkins, skinClones, touchedParts = {}, {}, {}, {}
	local charConns = {}
	OVX.skinConfig = config

	local function normalize(value) return string.lower(tostring(value or "")) end
	local function addUnique(list, value)
		if type(value) ~= "string" or value == "" then return end
		local key = normalize(value)
		for _, existing in ipairs(list) do
			if normalize(existing) == key then return end
		end
		list[#list + 1] = value
	end
	local function mergedList(base, discovered)
		local out, seen = {}, {}
		local function addList(list)
			for _, value in ipairs(list) do
				local key = normalize(value)
				if not seen[key] then seen[key] = true; out[#out + 1] = value end
			end
		end
		addList(base)
		addList(discovered)
		table.sort(out)
		return out
	end
	local function getWeapons() return mergedList(WEAPONS, discoveredWeapons) end
	local function getSkins() return mergedList(SKINS, discoveredSkins) end

	local assetCount = 0
	local function indexAsset(obj)
		if not obj or flags["skin_discover_assets"] == false then return end
		local limit = clamp(tonumber(flags["skin_asset_limit"]) or 1200, 100, 5000)
		if assetCount >= limit then return end
		local name
		pcall(function() name = obj.Name end)
		if type(name) ~= "string" or name == "" then return end
		local key, parentName = normalize(name), ""
		pcall(function() if obj.Parent then parentName = normalize(obj.Parent.Name) end end)
		local bucket = assetsByName[key]
		if not bucket then bucket = {}; assetsByName[key] = bucket end
		bucket[#bucket + 1] = obj
		assetCount = assetCount + 1
		local isSkin = string.find(key, "skin", 1, true) or string.find(parentName, "skin", 1, true)
			or string.find(key, "forgefire", 1, true) or string.find(key, "crystalheart", 1, true)
			or string.find(key, "winterhunter", 1, true)
		local isWeapon = string.find(key, "rifle", 1, true) or string.find(key, "pistol", 1, true)
			or string.find(key, "shotgun", 1, true) or string.find(key, "revolver", 1, true)
			or string.find(key, "smg", 1, true) or string.find(key, "bow", 1, true)
			or string.find(key, "gun", 1, true) or string.find(parentName, "weapon", 1, true)
			or string.find(parentName, "viewmodel", 1, true)
		if isSkin and #name <= 40 then addUnique(discoveredSkins, name) end
		if isWeapon and #name <= 50 then addUnique(discoveredWeapons, name) end
	end
	local function scanRoot(root)
		if not root or flags["skin_discover_assets"] == false then return end
		local descendants
		local ok = pcall(function() descendants = root:GetDescendants() end)
		if not ok or type(descendants) ~= "table" then return end
		for index = 1, math.min(#descendants, clamp(tonumber(flags["skin_asset_limit"]) or 1200, 100, 5000)) do
			indexAsset(descendants[index])
		end
	end
	local function findAsset(name, kind)
		if flags["skin_discover_assets"] == false then return nil, nil end
		local key = normalize(name)
		if key == "" then return nil, nil end
		local maxDepth = clamp(tonumber(flags["skin_asset_depth"]) or 5, 2, 8)
		local function bucketParts(bucket)
			if type(bucket) ~= "table" then return nil end
			for index = #bucket, 1, -1 do
				local parts = OVX.collectViewParts(bucket[index], {}, 0, maxDepth)
				if #parts > 0 then return bucket[index], parts end
			end
			return nil
		end
		local asset, parts = bucketParts(assetsByName[key])
		if asset then return asset, parts end
		for assetKey, bucket in pairs(assetsByName) do
			if string.find(assetKey, key, 1, true) or string.find(key, assetKey, 1, true) then
				asset, parts = bucketParts(bucket)
				if asset then return asset, parts end
			end
		end
		return nil, nil
	end
	local function skinMaterial(name)
		local ok, material = pcall(function() return Enum.Material[tostring(name or "ForceField")] end)
		if ok and material then return material end
		return Enum.Material.ForceField
	end
	local function applyFallback(part, skinName)
		local fallback = SKIN_FALLBACK[normalize(skinName)]
		local material = fallback and fallback.material or flags["skin_fallback_material"] or "ForceField"
		local color = fallback and fallback.color or resolveColor("skin_fallback_color", c3(255, 180, 80))
		local transparency = clamp((tonumber(flags["skin_fallback_transparency"]) or 0) / 10, 0, 1)
		local reflectance = clamp((tonumber(flags["skin_fallback_reflectance"]) or 2) / 10, 0, 1)
		pcall(function()
			part.Material = skinMaterial(material)
			part.Color = color
			part.Transparency = transparency
			part.Reflectance = reflectance
		end)
	end
	local function copyPartProperties(source, target)
		for _, property in ipairs(OVX.vmPropertyNames or {}) do
			pcall(function()
				local value = source[property]
				if value ~= nil then target[property] = value end
			end)
		end
		local appearance
		pcall(function() appearance = source:FindFirstChildOfClass("SurfaceAppearance") end)
		if appearance then
			pcall(function()
				local clone = appearance:Clone()
				clone.Parent = target
				skinClones[#skinClones + 1] = clone
			end)
		end
	end
	local function currentWeaponName()
		local character = lp.Character
		local tool
		pcall(function() tool = character and character:FindFirstChildOfClass("Tool") end)
		if tool then return tool.Name end
		for _, root in ipairs(OVX.viewModels or {}) do
			local name = ""
			pcall(function() name = root.Name or "" end)
			if name ~= "" then return name end
		end
		return nil
	end
	local function applySkinVisual(weaponName, skinName)
		if flags["skin_enabled"] == false then return false end
		local current = currentWeaponName()
		local wanted = normalize(weaponName)
		if current and normalize(current) ~= wanted
			and not string.find(normalize(current), wanted, 1, true)
			and not string.find(wanted, normalize(current), 1, true) then
			return false
		end
		OVX.refreshViewModels(true)
		local asset, assetParts = findAsset(skinName, "skin")
		local parts = {}
		local maxDepth = clamp(tonumber(flags["skin_asset_depth"]) or 5, 2, 8)
		for _, root in ipairs(OVX.viewModels or {}) do
			OVX.collectViewParts(root, parts, 0, maxDepth)
		end
		if #parts == 0 then parts = OVX.viewModelParts or {} end
		local sourceByName = {}
		if assetParts then
			for _, part in ipairs(assetParts) do
				pcall(function() sourceByName[normalize(part.Name)] = part end)
			end
		end
		for _, part in ipairs(parts) do
			local hand = OVX.isHandViewPart(part)
			local protected = flags["sf_protect_muzzle"] ~= false and OVX.isProtectedViewPart(part)
			if not hand and not protected then
				OVX.saveVmOriginal(part)
				touchedParts[part] = true
				local source = nil
				pcall(function() source = sourceByName[normalize(part.Name)] end)
				source = source or (assetParts and assetParts[1])
				if source then copyPartProperties(source, part) else applyFallback(part, skinName) end
			end
		end
		if flags["sf_hands_enabled"] or flags["sf_gun_enabled"] then
			if OVX.sciFiApply then pcall(OVX.sciFiApply) end
		end
		return asset ~= nil
	end
	local function restoreVisuals(reapplySciFi)
		for _, clone in ipairs(skinClones) do pcall(function() clone:Destroy() end) end
		table.clear(skinClones)
		for part in pairs(touchedParts) do OVX.restoreVmOriginal(part) end
		table.clear(touchedParts)
		if reapplySciFi ~= false and OVX.sciFiApply then pcall(OVX.sciFiApply) end
	end
	local function restoreSkinLayers()
		pcall(restoreVisuals, false)
		if OVX.sciFiRestore then pcall(OVX.sciFiRestore, false) end
		if OVX.sciFiApply then pcall(OVX.sciFiApply) end
	end
	local reapplyCurrent
	local skinPending, skinTimer = false, false
	local skinUiPending, skinUiTimer = false, false
	local function deferSkin()
		if OVX.viewmodelUnloaded then return end
		skinPending = true
		if skinTimer then return end
		skinTimer = true
		local delay = clamp(tonumber(flags["skin_delay"]) or 0.05, 0.03, 0.3)
		local function run()
			skinTimer = false
			if not skinPending or OVX.viewmodelUnloaded then return end
			skinPending = false
			pcall(reapplyCurrent)
		end
		local scheduled = false
		if type(task) == "table" and type(task.delay) == "function" then
			scheduled = pcall(task.delay, delay, run)
		end
		if not scheduled then run() end
	end
	reapplyCurrent = function()
		if flags["skin_enabled"] == false or flags["skin_auto_reapply"] == false then return end
		local weapon = currentWeaponName()
		if not weapon then return end
		local skin = config[weapon]
		if not skin then
			for name, value in pairs(config) do
				if normalize(weapon) == normalize(name)
					or string.find(normalize(weapon), normalize(name), 1, true) then
					skin = value
					break
				end
			end
		end
		if skin then applySkinVisual(weapon, skin) end
	end
	OVX.skinReapply = reapplyCurrent
	local function refreshSkinUI()
		if OVX.skinRefreshUI then pcall(OVX.skinRefreshUI) end
	end
	local function scheduleSkinUI()
		if OVX.viewmodelUnloaded then return end
		skinUiPending = true
		if skinUiTimer then return end
		skinUiTimer = true
		local function run()
			skinUiTimer = false
			if not skinUiPending or OVX.viewmodelUnloaded then return end
			skinUiPending = false
			pcall(refreshSkinUI)
		end
		local scheduled = false
		if type(task) == "table" and type(task.delay) == "function" then
			scheduled = pcall(task.delay, 0.2, run)
		end
		if not scheduled then run() end
	end
	local function setSkinInternal(weaponName, skinName, callExternal)
		weaponName = tostring(weaponName or "")
		skinName = tostring(skinName or "Default")
		if weaponName == "" then return false end
		local key = normalize(skinName)
		local isReset = skinName == "" or key == "default" or key == "reset" or key == "none"
		if isReset then
			config[weaponName] = nil
			if callExternal and type(previousSetSkin) == "function" then
				pcall(previousSetSkin, weaponName, "Default")
			end
			restoreSkinLayers()
			if flags["skin_auto_reapply"] ~= false then deferSkin() end
		else
			config[weaponName] = skinName
			if callExternal and type(previousSetSkin) == "function" then
				pcall(previousSetSkin, weaponName, skinName)
			end
			restoreSkinLayers()
			applySkinVisual(weaponName, skinName)
		end
		if flags["skin_debug"] then print("[OVX] skin " .. weaponName .. " -> " .. skinName) end
		refreshSkinUI()
		return true
	end
	local function setAllSkins(skinName)
		skinName = tostring(skinName or "Default")
		if type(previousSetAllSkins) == "function" then pcall(previousSetAllSkins, skinName) end
		restoreSkinLayers()
		local key = normalize(skinName)
		local isReset = skinName == "" or key == "default" or key == "reset" or key == "none"
		if isReset then
			table.clear(config)
		else
			for _, weapon in ipairs(getWeapons()) do config[weapon] = skinName end
			deferSkin()
		end
		if flags["skin_debug"] then print("[OVX] all skins -> " .. skinName) end
		refreshSkinUI()
		return true
	end
	local function resetSkins()
		if type(previousResetSkins) == "function" then pcall(previousResetSkins) end
		table.clear(config)
		restoreSkinLayers()
		if flags["skin_debug"] then print("[OVX] skins reset") end
		refreshSkinUI()
		return true
	end
	local function selectWeapon(name)
		name = tostring(name or WEAPONS[1])
		if type(previousSelectWeapon) == "function" then pcall(previousSelectWeapon, name) end
		local setter = library.config_flags["skin_weapon"]
		if setter then pcall(setter, name) else flags["skin_weapon"] = name end
		local customSetter = library.config_flags["skin_weapon_custom"]
		if customSetter then pcall(customSetter, "") else flags["skin_weapon_custom"] = "" end
		if flags["skin_debug"] then print("[OVX] selected weapon " .. name) end
		return name
	end
	function OVX.skinSelectedWeapon()
		local custom = flags["skin_weapon_custom"]
		if type(custom) == "string" and custom ~= "" then return custom end
		return flags["skin_weapon"] or WEAPONS[1]
	end
	function OVX.skinSelectedSkin()
		local custom = flags["skin_skin_custom"]
		if type(custom) == "string" and custom ~= "" then return custom end
		return flags["skin_skin"] or "Tempered"
	end
	function OVX.skinApplyMode()
		if flags["skin_apply_mode"] == "All Guns" then
			return setAllSkins(OVX.skinSelectedSkin())
		end
		return setSkinInternal(OVX.skinSelectedWeapon(), OVX.skinSelectedSkin(), true)
	end
	function OVX.skinApplyAll()
		return setAllSkins(OVX.skinSelectedSkin())
	end
	function OVX.skinResetWeapon()
		return setSkinInternal(OVX.skinSelectedWeapon(), "Default", true)
	end
	function OVX.skinResetAll()
		return resetSkins()
	end
	function OVX.skinPrintConfig()
		local rows = {}
		for weapon, skin in pairs(config) do rows[#rows + 1] = weapon .. "=" .. skin end
		table.sort(rows)
		print("[OVX] skin map: " .. (#rows > 0 and table.concat(rows, ", ") or "empty"))
		return #rows
	end
	OVX.skinSelectWeapon = selectWeapon
	OVX.skinGetWeapons = getWeapons
	OVX.skinGetSkins = getSkins

	local function bindCharacter(character)
		for _, conn in ipairs(charConns) do pcall(function() conn:Disconnect() end) end
		table.clear(charConns)
		if not character then return end
		local function watch(event)
			if event and event.Connect then
				charConns[#charConns + 1] = event:Connect(function() deferSkin() end)
			end
		end
		watch(character.ChildAdded)
		watch(character.ChildRemoved)
		watch(character.DescendantAdded)
		deferSkin()
	end
	bind(lp.CharacterAdded:Connect(bindCharacter))
	bind(lp.CharacterRemoving:Connect(function()
		for _, conn in ipairs(charConns) do pcall(function() conn:Disconnect() end) end
		table.clear(charConns)
	end))
	bindCharacter(lp.Character)

	local assetRoots = {
		RepStorage, game:GetService("ReplicatedFirst"), lp,
		Workspace.CurrentCamera, game:GetService("Lighting"),
		game:GetService("StarterPack"), CoreGui,
	}
	for _, root in ipairs(assetRoots) do
		scanRoot(root)
		if root and root.DescendantAdded then
			bind(root.DescendantAdded:Connect(function(obj)
				indexAsset(obj)
				scheduleSkinUI()
				deferSkin()
			end))
		end
	end

	local ourSetSkin = function(weapon, skin) return setSkinInternal(weapon, skin, true) end
	local ourSetAllSkins = setAllSkins
	local ourResetSkins = resetSkins
	local ourSelectWeapon = selectWeapon
	local skinObject = {
		Config = config, Settings = flags, SetSkin = ourSetSkin,
		SetAll = ourSetAllSkins, SetAllSkins = ourSetAllSkins,
		Reset = ourResetSkins, ResetSkins = ourResetSkins,
		SetWeapon = selectWeapon, SelectWeapon = selectWeapon,
		GetWeapons = getWeapons, GetSkins = getSkins,
		Reapply = reapplyCurrent, PrintConfig = OVX.skinPrintConfig,
	}
	local skinUnloaded = false
	function OVX.skinUnload()
		if skinUnloaded then return end
		skinUnloaded = true
		for _, conn in ipairs(charConns) do pcall(function() conn:Disconnect() end) end
		table.clear(charConns)
		restoreVisuals(false)
		table.clear(config)
		table.clear(assetsByName)
		table.clear(discoveredWeapons)
		table.clear(discoveredSkins)
		table.clear(skinClones)
		if type(env.SkinChangerUnload) == "function" and env.SkinChangerUnload ~= OVX.skinUnload then
			pcall(env.SkinChangerUnload)
		end
		if type(env.SkinChanger) == "table" and env.SkinChanger ~= skinObject
			and type(env.SkinChanger.Unload) == "function" then
			pcall(env.SkinChanger.Unload)
		end
		if env.SkinChanger == skinObject then env.SkinChanger = previousSkinChanger or nil end
		if env.SetSkin == ourSetSkin then env.SetSkin = previousSetSkin or nil end
		if env.SetAllSkins == ourSetAllSkins then env.SetAllSkins = previousSetAllSkins or nil end
		if env.ResetSkins == ourResetSkins then env.ResetSkins = previousResetSkins or nil end
		if env.selectWeapon == ourSelectWeapon then env.selectWeapon = previousSelectWeapon or nil end
		if env.SkinChangerUnload == OVX.skinUnload then env.SkinChangerUnload = previousSkinUnload or nil end
		OVX.skinUnload = nil
	end
	skinObject.Unload = OVX.skinUnload
	env.SkinChanger = skinObject
	env.SetSkin = ourSetSkin
	env.SetAllSkins = ourSetAllSkins
	env.ResetSkins = ourResetSkins
	env.selectWeapon = ourSelectWeapon
	env.SkinChangerUnload = OVX.skinUnload
	bind({ Disconnect = function() if OVX.skinUnload then pcall(OVX.skinUnload) end end })
end

-- ================================================================
-- // PLAYER ESP — attached v5 custom-gradient engine, optimised
-- //   Cached player list/connections, precomputed HSV gradient, 20 pooled
-- //   health slices, staggered hide/draw frames, pooled LOS raycasts and
-- //   a combined distance/weapon text. All settings come from Vault flags.
-- ================================================================
do
	local env = getgenv()
	if type(env.__vaultEspUnload) == "function" then pcall(env.__vaultEspUnload) end

	local espConns, teardownDrawings, teardownInstances = {}, {}, {}
	local pool, playerList = {}, {}
	local frame = 0
	local camera = Workspace.CurrentCamera
	local colorFromHSV, colorToHSV = Color3.fromHSV, Color3.toHSV
	local COLOR_BLACK = c3(0, 0, 0)
	local HEALTH_SLICES = 20
	local CORNER_DEFS = {
		{ 0, 0, 1, 0 }, { 0, 0, 0, 1 },
		{ 1, 0, -1, 0 }, { 1, 0, 0, 1 },
		{ 0, 1, 1, 0 }, { 0, 1, 0, -1 },
		{ 1, 1, -1, 0 }, { 1, 1, 0, -1 },
	}
	local FONT_MAP = { UI = 0, System = 1, Plex = 2, Monospace = 3 }

	local function bindConn(conn)
		bind(conn)
		espConns[#espConns + 1] = conn
		return conn
	end
	local function newDrawing(class, props)
		local object = Drawingnew(class)
		for key, value in pairs(props or {}) do object[key] = value end
		teardownDrawings[#teardownDrawings + 1] = object
		return object
	end
	local function newCham(props)
		local object = Instance.new("Highlight")
		pcall(function() object.Parent = CoreGui end)
		for key, value in pairs(props or {}) do object[key] = value end
		teardownInstances[#teardownInstances + 1] = object
		return object
	end
	local function lerpGradColor(t, colorA, colorB)
		local h1, s1, v1 = colorToHSV(colorA)
		local h2, s2, v2 = colorToHSV(colorB)
		local dh = h2 - h1
		if dh > 0.5 then dh = dh - 1 end
		if dh < -0.5 then dh = dh + 1 end
		local h = (h1 + dh * t) % 1
		local s = s1 + (s2 - s1) * t
		local v = v1 + (v2 - v1) * t
		return colorFromHSV(h, s, v)
	end

	local espSettings = {
		enabled = true, maxDist = 0, fontSize = 13, font = 2,
		box = { enabled = true, type = "Normal", color = c3(255,255,255), thickness = 1, outline = true },
		filledBox = { enabled = false, color = c3(255,255,255), transparency = 0.6 },
		healthBar = { enabled = true, outline = true, position = "Left", colorLow = c3(255,0,0), colorHigh = c3(0,255,0) },
		healthText = { enabled = false, color = c3(255,255,255), matchGradient = false },
		name = { enabled = true, displayName = true, color = c3(255,255,255) },
		distance = { enabled = true, color = c3(200,200,200) },
		weapon = { enabled = false, color = c3(255,220,80) },
		viewAngle = { enabled = false, color = c3(255,255,255), length = 10 },
		chams = {
			enabled = false, visCheck = false, fillColor = c3(255,255,255), outlineColor = COLOR_BLACK,
			fillTransparency = 0.4, outlineTransparency = 0,
			visColor = c3(0,255,0), invisColor = c3(255,0,0),
		},
		tracer = { enabled = false, color = c3(255,255,255), origin = "Bottom" },
	}
	local function defaultIsEnemy(player)
		if not getFlagBool("esp_team_check", false) then return true end
		local relation = OVX.relation(player)
		return relation ~= "team" and relation ~= "ally" and not sameTeam(player)
	end
	espSettings.isEnemy = defaultIsEnemy
	local function syncEspSettings()
		espSettings.enabled = getFlagBool("Enabled", true)
		espSettings.maxDist = tonumber(flags["esp_max_dist"]) or 0
		espSettings.fontSize = clamp(tonumber(flags["esp_font_size"]) or 13, 8, 24)
		espSettings.font = FONT_MAP[flags["esp_font"] or "Plex"] or tonumber(flags["esp_font"]) or 2

		espSettings.box.enabled = getFlagBool("Boxes", true)
		espSettings.box.type = flags["Box_Type"] == "Corner" and "Corner" or "Normal"
		espSettings.box.color = getFlagColor("Box_Color", c3(255,255,255))
		espSettings.box.thickness = clamp(tonumber(flags["esp_box_thickness"]) or 1, 1, 6)
		espSettings.box.outline = getFlagBool("esp_box_outline", true)

		espSettings.filledBox.enabled = getFlagBool("esp_filled_box", false)
		espSettings.filledBox.color = getFlagColor("esp_filled_color", c3(255,255,255))
		espSettings.filledBox.transparency = clamp((tonumber(flags["esp_filled_transparency"]) or 6) / 10, 0, 1)

		espSettings.healthBar.enabled = getFlagBool("Healthbar", true)
		espSettings.healthBar.outline = getFlagBool("esp_health_outline", true)
		espSettings.healthBar.position = flags["esp_health_position"] == "Top" and "Top" or "Left"
		espSettings.healthBar.colorLow = getFlagColor("Health_Low", c3(255,0,0))
		espSettings.healthBar.colorHigh = getFlagColor("Health_High", c3(0,255,0))

		espSettings.healthText.enabled = getFlagBool("esp_health_text", false)
		espSettings.healthText.color = getFlagColor("esp_health_text_color", c3(255,255,255))
		espSettings.healthText.matchGradient = getFlagBool("esp_health_text_gradient", false)

		espSettings.name.enabled = getFlagBool("Names", true)
		espSettings.name.displayName = getFlagBool("esp_display_names", true)
		espSettings.name.color = getFlagColor("Name_Color", c3(255,255,255))
		espSettings.distance.enabled = getFlagBool("Distance", true)
		espSettings.distance.color = getFlagColor("Distance_Color", c3(200,200,200))
		espSettings.weapon.enabled = getFlagBool("Weapon", false)
		espSettings.weapon.color = getFlagColor("Weapon_Color", c3(255,220,80))

		espSettings.viewAngle.enabled = getFlagBool("esp_view_angle", false)
		espSettings.viewAngle.color = getFlagColor("esp_viewangle_color", c3(255,255,255))
		espSettings.viewAngle.length = clamp(tonumber(flags["esp_viewangle_size"]) or 10, 3, 30)

		espSettings.chams.enabled = getFlagBool("esp_chams", false)
		espSettings.chams.visCheck = getFlagBool("esp_cham_vis_check", false)
		espSettings.chams.fillColor = getFlagColor("esp_cham_fill_color", c3(255,255,255))
		espSettings.chams.outlineColor = getFlagColor("esp_cham_outline_color", COLOR_BLACK)
		espSettings.chams.fillTransparency = clamp((tonumber(flags["esp_cham_fill_transparency"]) or 4) / 10, 0, 1)
		espSettings.chams.outlineTransparency = clamp((tonumber(flags["esp_cham_outline_transparency"]) or 0) / 10, 0, 1)
		espSettings.chams.visColor = getFlagColor("esp_cham_vis_color", c3(0,255,0))
		espSettings.chams.invisColor = getFlagColor("esp_cham_invis_color", c3(255,0,0))

		espSettings.tracer.enabled = getFlagBool("esp_tracers", false)
		espSettings.tracer.color = getFlagColor("esp_tracer_color", c3(255,255,255))
		espSettings.tracer.origin = flags["esp_tracer_origin"] or "Bottom"

	end

	local gradientKey, gradientColors = "", {}
	local function ensureGradient(low, high)
		local key = string.format("%.4f,%.4f,%.4f|%.4f,%.4f,%.4f",
			low.R, low.G, low.B, high.R, high.G, high.B)
		if key == gradientKey then return end
		gradientKey = key
		for index = 1, HEALTH_SLICES do
			gradientColors[index] = lerpGradColor((index - 0.5) / HEALTH_SLICES, low, high)
		end
	end

	local visCache = {}
	local losParams = RaycastParams.new()
	local losFilter = { nil, nil }
	pcall(function() losParams.FilterType = Enum.RaycastFilterType.Exclude end)
	local function checkLOS(cam, model)
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end
		losFilter[1], losFilter[2] = lp.Character, model
		pcall(function() losParams.FilterDescendantsInstances = losFilter end)
		local direction = hrp.Position - cam.CFrame.Position
		local hit
		pcall(function() hit = Workspace:Raycast(cam.CFrame.Position, direction, losParams) end)
		return hit == nil
	end
	local function getVisible(player, cam, model)
		local cached = visCache[player]
		if cached ~= nil then return cached end
		local visible = checkLOS(cam, model)
		visCache[player] = visible
		return visible
	end

	local function allocate(player)
		if pool[player] then return end
		local entry = {
			boxOutline = newDrawing("Square", { Thickness = 3, Visible = false, Color = COLOR_BLACK }),
			box = newDrawing("Square", { Thickness = 1, Visible = false }),
			filledBox = newDrawing("Square", { Filled = true, Visible = false }),
			corners = {}, healthGradient = {},
			healthOutline = newDrawing("Line", { Thickness = 4, Visible = false, Color = COLOR_BLACK }),
			name = newDrawing("Text", { Size = 13, Font = 2, Center = true, Outline = true, Visible = false }),
			healthText = newDrawing("Text", { Size = 13, Font = 2, Center = true, Outline = true, Visible = false }),
			infoText = newDrawing("Text", { Size = 13, Font = 2, Center = true, Outline = true, Visible = false }),
			viewAngle = newDrawing("Line", { Thickness = 1, Visible = false }),
			tracer = newDrawing("Line", { Thickness = 1, Visible = false }),
			cham = newCham({ Enabled = false }),
			_hidden = false, _fontSize = 13, _font = 2, _toolName = nil, _toolAt = 0,
		}
		for index = 1, 8 do
			entry.corners[index] = newDrawing("Line", { Thickness = 2, Visible = false })
		end
		for index = 1, HEALTH_SLICES do
			entry.healthGradient[index] = newDrawing("Line", { Thickness = 2, Visible = false })
		end
		pool[player] = entry
	end
	local function hideCorners(entry)
		for index = 1, 8 do entry.corners[index].Visible = false end
	end
	local function hideGradient(entry)
		for index = 1, HEALTH_SLICES do entry.healthGradient[index].Visible = false end
	end
	local function hideEntry(entry)
		if entry._hidden then return end
		entry._hidden = true
		entry.boxOutline.Visible = false
		entry.box.Visible = false
		entry.filledBox.Visible = false
		entry.healthOutline.Visible = false
		entry.name.Visible = false
		entry.healthText.Visible = false
		entry.infoText.Visible = false
		entry.viewAngle.Visible = false
		entry.tracer.Visible = false
		entry.cham.Enabled = false
		hideCorners(entry)
		hideGradient(entry)
	end
	local function release(player)
		local entry = pool[player]
		if not entry then return end
		pool[player] = nil
		if entry.charConn then pcall(function() entry.charConn:Disconnect() end) end
		local singles = { "boxOutline", "box", "filledBox", "healthOutline", "name", "healthText", "infoText", "viewAngle", "tracer" }
		for _, key in ipairs(singles) do pcall(function() entry[key]:Remove() end) end
		for _, drawing in ipairs(entry.corners) do pcall(function() drawing:Remove() end) end
		for _, drawing in ipairs(entry.healthGradient) do pcall(function() drawing:Remove() end) end
		pcall(function() entry.cham:Destroy() end)
		for index = #playerList, 1, -1 do
			if playerList[index] == player then table.remove(playerList, index); break end
		end
	end
	local function drawCorners(entry, boxX, boxY, boxW, boxH, color)
		local length = boxW * 0.28
		for index = 1, 8 do
			local definition = CORNER_DEFS[index]
			local px, py = boxX + definition[1] * boxW, boxY + definition[2] * boxH
			local line = entry.corners[index]
			line.From = v2new(px, py)
			line.To = v2new(px + definition[3] * length, py + definition[4] * length)
			line.Color = color
			line.Visible = true
		end
	end
	local function watchPlayer(player)
		if player == lp or pool[player] then return end
		allocate(player)
		playerList[#playerList + 1] = player
		local entry = pool[player]
		entry.charConn = player.CharacterAdded:Connect(function() allocate(player) end)
	end

	syncEspSettings()
	ensureGradient(espSettings.healthBar.colorLow, espSettings.healthBar.colorHigh)
	for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
	bindConn(Players.PlayerAdded:Connect(watchPlayer))
	bindConn(Players.PlayerRemoving:Connect(release))
	bindConn(lp.CharacterRemoving:Connect(function()
		for player in pairs(pool) do hideEntry(pool[player]) end
	end))
	bindConn(RunService.Heartbeat:Connect(function() frame = frame + 1 end))

	bindConn(RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		camera = cam
		local isRenderFrame = frame % 2 == 0
		local vpX, vpY, heightScale = cam.ViewportSize.X, cam.ViewportSize.Y, 1
		if isRenderFrame then
			syncEspSettings()
			table.clear(visCache)
			ensureGradient(espSettings.healthBar.colorLow, espSettings.healthBar.colorHigh)
			heightScale = vpY / (2 * math.tan(math.rad(cam.FieldOfView / 2)))
		end
		local character = lp.Character
		local localRoot = character and character:FindFirstChild("HumanoidRootPart")
		for index = 1, #playerList do
			local player = playerList[index]
			if player ~= lp then
				local entry = pool[player]
				if not entry then allocate(player); entry = pool[player] end
				if entry then
					local model = player.Character
					local humanoid = model and model:FindFirstChildOfClass("Humanoid")
					local hrp = model and model:FindFirstChild("HumanoidRootPart")
					local renderable, distance = false, 0
					if espSettings.enabled and model and humanoid and humanoid.Health > 0 and hrp and localRoot
						and espSettings.isEnemy(player) then
						distance = (hrp.Position - localRoot.Position).Magnitude
						renderable = espSettings.maxDist <= 0 or distance <= espSettings.maxDist
					end
					if not renderable then
						hideEntry(entry)
					elseif isRenderFrame then
						local center, onScreen = cam:WorldToViewportPoint(hrp.Position)
						if not onScreen or center.Z < 0 then
							hideEntry(entry)
						else
							entry._hidden = false
							local fontSize = espSettings.fontSize
							if entry._fontSize ~= fontSize or entry._font ~= espSettings.font then
								entry._fontSize, entry._font = fontSize, espSettings.font
								entry.name.Size, entry.healthText.Size, entry.infoText.Size = fontSize, fontSize, fontSize
								entry.name.Font, entry.healthText.Font, entry.infoText.Font = espSettings.font, espSettings.font, espSettings.font
							end
							local boxH = math.max(6 * heightScale / center.Z * 0.92, 10)
							local boxW = floor(boxH * 0.72)
							local boxX, boxY = floor(center.X - boxW / 2), floor(center.Y - boxH / 2)
							local botY = boxY + boxH + 1
							local ratio = clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
							local gradColor = lerpGradColor(ratio,
								espSettings.healthBar.colorLow, espSettings.healthBar.colorHigh)

							local sBox, sFilled = espSettings.box, espSettings.filledBox
							local sHealth, sHealthText = espSettings.healthBar, espSettings.healthText
							local sName, sDist, sWeapon = espSettings.name, espSettings.distance, espSettings.weapon
							local sView, sChams = espSettings.viewAngle, espSettings.chams
							local sTracer = espSettings.tracer

							if sChams.enabled then
								entry.cham.Adornee = model
								if sChams.visCheck then
									local visible = getVisible(player, cam, model)
									entry.cham.FillColor = visible and sChams.visColor or sChams.invisColor
									entry.cham.OutlineColor = visible and sChams.visColor or sChams.invisColor
								else
									entry.cham.FillColor = sChams.fillColor
									entry.cham.OutlineColor = sChams.outlineColor
								end
								entry.cham.FillTransparency = sChams.fillTransparency
								entry.cham.OutlineTransparency = sChams.outlineTransparency
								entry.cham.Enabled = true
							else
								entry.cham.Enabled = false
							end

							if sFilled.enabled then
								entry.filledBox.Size = v2new(boxW - 2, boxH - 2)
								entry.filledBox.Position = v2new(boxX + 1, boxY + 1)
								entry.filledBox.Color = sFilled.color
								entry.filledBox.Transparency = sFilled.transparency
								entry.filledBox.Visible = true
							else
								entry.filledBox.Visible = false
							end

							if sBox.enabled then
								if sBox.type == "Corner" then
									entry.boxOutline.Visible = false
									entry.box.Visible = false
									drawCorners(entry, boxX, boxY, boxW, boxH, sBox.color)
								else
									hideCorners(entry)
									entry.boxOutline.Size = v2new(boxW, boxH)
									entry.boxOutline.Position = v2new(boxX, boxY)
									entry.boxOutline.Visible = sBox.outline
									entry.box.Size = v2new(boxW, boxH)
									entry.box.Position = v2new(boxX, boxY)
									entry.box.Color = sBox.color
									entry.box.Thickness = sBox.thickness
									entry.box.Visible = true
								end
							else
								entry.boxOutline.Visible = false
								entry.box.Visible = false
								hideCorners(entry)
							end

							if sHealth.enabled then
								local gradient = entry.healthGradient
								if sHealth.position == "Top" then
									local barY, barLeft = boxY - 6, boxX
									local fullW, fillW = boxW, ratio * boxW
									entry.healthOutline.Thickness = 6
									entry.healthOutline.From = v2new(barLeft - 1, barY)
									entry.healthOutline.To = v2new(barLeft + fullW + 1, barY)
									entry.healthOutline.Visible = sHealth.outline
									local sliceW = fillW / HEALTH_SLICES
									for slice = 1, HEALTH_SLICES do
										local segment = gradient[slice]
										if fillW < 1 then
											segment.Visible = false
										else
											segment.From = v2new(barLeft + (slice - 1) * sliceW, barY)
											segment.To = v2new(barLeft + slice * sliceW, barY)
											segment.Color = gradientColors[slice] or gradColor
											segment.Visible = true
										end
									end
								else
									local barX, barBot, barTop = boxX - 6, boxY + boxH, boxY
									local fullH, fillH = barBot - barTop, ratio * (barBot - barTop)
									entry.healthOutline.Thickness = 4
									entry.healthOutline.From = v2new(barX, barBot + 1)
									entry.healthOutline.To = v2new(barX, barTop - 1)
									entry.healthOutline.Visible = sHealth.outline
									local sliceH = fillH / HEALTH_SLICES
									for slice = 1, HEALTH_SLICES do
										local segment = gradient[slice]
										if fillH < 1 then
											segment.Visible = false
										else
											segment.From = v2new(barX, barBot - (slice - 1) * sliceH)
											segment.To = v2new(barX, barBot - slice * sliceH)
											segment.Color = gradientColors[slice] or gradColor
											segment.Visible = true
										end
									end
								end
							else
								entry.healthOutline.Visible = false
								hideGradient(entry)
							end

							if sHealthText.enabled then
								entry.healthText.Text = floor(ratio * 100 + 0.5) .. "%"
								entry.healthText.Position = (sHealth.enabled and sHealth.position == "Top")
									and v2new(boxX - 24, boxY - 7) or v2new(boxX - 24, boxY)
								entry.healthText.Color = sHealthText.matchGradient and gradColor or sHealthText.color
								entry.healthText.Visible = true
							else
								entry.healthText.Visible = false
							end

							if sName.enabled then
								local nameY = (sHealth.enabled and sHealth.position == "Top")
									and (boxY - 6 - fontSize - 2) or (boxY - fontSize - 3)
								entry.name.Text = sName.displayName and (player.DisplayName or player.Name) or player.Name
								entry.name.Position = v2new(center.X, nameY)
								entry.name.Color = sName.color
								entry.name.Visible = true
							else
								entry.name.Visible = false
							end

							local infoString
							local distanceValue = sDist.enabled and floor(distance) or nil
							local toolName
							if sWeapon.enabled then
								if entry._toolName == nil or frame - entry._toolAt >= 15 then
									entry._toolName = heldLabelOf(model)
									entry._toolAt = frame
								end
								toolName = entry._toolName
							end
							if distanceValue and toolName then
								infoString = "[" .. distanceValue .. "m]\n" .. toolName
							elseif distanceValue then
								infoString = "[" .. distanceValue .. "m]"
							elseif toolName then
								infoString = toolName
							end
							if infoString then
								entry.infoText.Text = infoString
								entry.infoText.Position = v2new(center.X, botY)
								entry.infoText.Color = (not sDist.enabled and sWeapon.enabled) and sWeapon.color or sDist.color
								entry.infoText.Visible = true
							else
								entry.infoText.Visible = false
							end

							local head = model:FindFirstChild("Head")
							if sView.enabled and head then
								local headCF = head.CFrame
								local lookWorld = (headCF + headCF.LookVector * sView.length).Position
								local lookPoint = cam:WorldToViewportPoint(lookWorld)
								entry.viewAngle.From = v2new(center.X, center.Y)
								entry.viewAngle.To = v2new(lookPoint.X, lookPoint.Y)
								entry.viewAngle.Color = sView.color
								entry.viewAngle.Visible = true
							else
								entry.viewAngle.Visible = false
							end

							if sTracer.enabled then
								local fromY = sTracer.origin == "Top" and 0
									or (sTracer.origin == "Center" and vpY / 2 or vpY)
								entry.tracer.From = v2new(vpX / 2, fromY)
								entry.tracer.To = v2new(center.X, center.Y)
								entry.tracer.Color = sTracer.color
								entry.tracer.Visible = true
							else
								entry.tracer.Visible = false
							end
						end
					end
				end
			end
		end
	end))

	local vaultEsp = {
		settings = espSettings, Settings = espSettings,
		isEnemy = espSettings.isEnemy, Sync = syncEspSettings,
		Refresh = syncEspSettings, refresh_elements = syncEspSettings,
	}
	local espUnloaded = false
	local function unloadEsp()
		if espUnloaded then return end
		espUnloaded = true
		for _, connection in ipairs(espConns) do pcall(function() connection:Disconnect() end) end
		table.clear(espConns)
		for _, drawing in ipairs(teardownDrawings) do pcall(function() drawing:Remove() end) end
		for _, instance in ipairs(teardownInstances) do pcall(function() instance:Destroy() end) end
		for index = #playerList, 1, -1 do release(playerList[index]) end
		table.clear(pool)
		table.clear(playerList)
		table.clear(teardownDrawings)
		table.clear(teardownInstances)
		table.clear(visCache)
		if env.__vaultEspUnload == unloadEsp then env.__vaultEspUnload = nil end
		if env.esp == vaultEsp then env.esp = nil end
	end
	vaultEsp.Unload = unloadEsp
	espUnload = unloadEsp
	env.esp = vaultEsp
	env.__vaultEspUnload = unloadEsp
end -- ESP block

-- ================================================================
-- // WORLD ESP  (nodes, loot, mobs, sleepers, vehicles, events)
-- //   Text ESP (name + distance) for world objects. A throttled gather builds
-- //   a near-object list (distance-culled); static objects' positions are cached
-- //   once and maintained via ChildAdded/Removed so the huge containers (Trees
-- //   3773, Rocks, Boulders…) aren't re-pivoted every frame. Drawings are pooled
-- //   and only visible objects consume a slot.
-- ================================================================
do
	local pool = {}
	local function slot(i)
		local s = pool[i]
		if not s then
			s = {
				name = Drawingnew("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
				dist = Drawingnew("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
			}
			pool[i] = s
		end
		return s
	end
	local function hideFrom(n)
		for i = n, #pool do pool[i].name.Visible = false; pool[i].dist.Visible = false end
	end

	local function objPos(m)
		if m:IsA("BasePart") then return m.Position end
		if m.PrimaryPart then return m.PrimaryPart.Position end
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp then return hrp.Position end
		local ok, cf = pcall(function() return m:GetPivot() end)
		if ok then return cf.Position end
	end

	-- position cache for static containers; rebuilds if the folder instance is
	-- replaced (respawn / map reload), so a stale cache can't persist
	local posCache = {}    -- container name -> (model -> pos)
	local cacheFolder = {} -- container name -> folder instance it was built from
	local function ensureCache(cn)
		local folder = Workspace:FindFirstChild(cn)
		if not folder then posCache[cn] = nil; cacheFolder[cn] = nil; return nil end
		if posCache[cn] and cacheFolder[cn] == folder then return posCache[cn] end
		local map = {}
		for _, m in ipairs(folder:GetChildren()) do local p = objPos(m); if p then map[m] = p end end
		posCache[cn] = map
		cacheFolder[cn] = folder
		bind(folder.ChildAdded:Connect(function(m)
			task.defer(function() if cacheFolder[cn] == folder then local p = objPos(m); if p then map[m] = p end end end)
		end))
		bind(folder.ChildRemoved:Connect(function(m) map[m] = nil end))
		return map
	end

	local lastGather = 0
	local lastRender = 0
	-- draw budget: only the nearest N objects get drawings (sorted each gather).
	-- Projecting and updating hundreds of Text drawings every frame is what
	-- tanks FPS with trees/rocks enabled.
	local MAX_SLOTS = 60

	-- reusable gather entries (no per-object table allocation -> no GC spikes)
	local gpool, gcount, lastCount = {}, 0, 0
	local function gpush(pos, label, color, d)
		gcount = gcount + 1
		local e = gpool[gcount]
		if not e then e = {}; gpool[gcount] = e end
		e.pos, e.label, e.color, e.d = pos, label, color, d
	end

	bind(RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam or not flags["w_enabled"] then hideFrom(1); return end

		local now = os.clock()
		if now - lastGather > 0.1 then
			lastGather = now
			gcount = 0
			gpool[1] = nil
			local char = lp.Character
			local lpos
			if char then
				local lhrp = char:FindFirstChild("HumanoidRootPart")
				if lhrp then lpos = lhrp.Position else local ok, p = pcall(function() return char:GetPivot().Position end); if ok then lpos = p end end
			end
			if lpos then
				for _, cat in ipairs(WORLD_CATS) do
					if flags[cat.flag] then
						local dd = flags[cat.dist] or cat.dd
						local col = WORLD_SEC_COLOR[cat.sec] or c3(255, 255, 255)
						local isStatic = cat.static ~= false
						for _, cn in ipairs(cat.cont) do
							if isStatic then
								local map = ensureCache(cn)
								if map then
									for m, pos in pairs(map) do
										if m.Parent and ((not cat.match) or cat.match(m.Name)) then
											local d = (pos - lpos).Magnitude
											if d <= dd then
												gpush(pos, cat.useName and m.Name or cat.label, col, d)
											end
										end
									end
								end
							else
								local folder = Workspace:FindFirstChild(cn)
								if folder then
									local kids = cat.deep and folder:GetDescendants() or folder:GetChildren()
									for _, m in ipairs(kids) do
										-- deep scan: only Models (animals spawn as whole models)
										if (not cat.deep or m:IsA("Model")) and ((not cat.match) or cat.match(m.Name)) then
											local pos = objPos(m)
											if pos then
												local d = (pos - lpos).Magnitude
												if d <= dd then
													gpush(pos, cat.useName and m.Name or cat.label, col, d)
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
			-- trim stale tail from the previous gather, sort nearest-first,
			-- then cap: only the closest objects get drawings
			for i = gcount + 1, lastCount do gpool[i] = nil end
			lastCount = gcount
			table.sort(gpool, function(a, b) return a.d < b.d end)
			if gcount > MAX_SLOTS then
				gcount = MAX_SLOTS
				gpool[gcount + 1] = nil
			end
		end

		-- render at most ~30 Hz: the projection loop + drawing updates don't
		-- need to run at full frame rate, and halving it directly halves the
		-- cost (FPS gained in the 3D scene)
		local now = os.clock()
		if now - lastRender < 1 / 30 then return end
		lastRender = now

		local fontSize = flags["w_font"] or 13
		local n = 0
		for i = 1, gcount do
			local g = gpool[i]
			local sp, on = cam:WorldToViewportPoint(g.pos)
			if on and sp.Z > 0 then
				n = n + 1
				local s = slot(n)
				-- skip the drawing updates when nothing changed (camera still,
				-- same slot): property writes on Text drawings are the bulk of
				-- the render cost
				if s.lx ~= sp.X or s.ly ~= sp.Y or s.ls ~= fontSize
					or s.lt ~= g.label or s.ld ~= g.d or s.lc ~= g.color then
					s.lx, s.ly, s.ls, s.lt, s.ld, s.lc = sp.X, sp.Y, fontSize, g.label, g.d, g.color
					s.name.Text = g.label; s.name.Size = fontSize; s.name.Color = g.color
					s.name.Position = v2new(sp.X, sp.Y - fontSize); s.name.Visible = true
					s.dist.Text = "[" .. floor(g.d) .. "m]"; s.dist.Size = fontSize; s.dist.Color = g.color
					s.dist.Position = v2new(sp.X, sp.Y + 1); s.dist.Visible = true
				end
			end
		end
		hideFrom(n + 1)
	end))

	bind({ Disconnect = function()
		for _, s in ipairs(pool) do pcall(function() s.name:Remove(); s.dist:Remove() end) end
		table.clear(pool)
	end })
end

-- ================================================================
-- // SILENT AIM (firearms) — validated hits
-- //   The server pairs FirearmsRemotes.Hit.id to Fire.seedNo and checks the
-- //   hit Position sits on a real part consistent with Fire origin+direction.
-- //   So we: rewrite Fire.direction toward the locked target (keeping
-- //   origin/seedNo/claim), then send our OWN Hit(seedNo,1,targetPart,point,t)
-- //   and drop the game's duplicate Hit for that seedNo. PSilent: camera never
-- //   moves. Works on streamed-in targets only (streamed-out players have no
-- //   part to send as Hit.part).
-- ================================================================
local saActive = true  -- unload flips this false so the namecall hook goes inert
local namecallOrig = nil -- original __namecall, restored on unload to avoid stacking
do
	local FirearmsRemotes = RepStorage:WaitForChild("FirearmsRemotes", 10)
	local FireRemote = FirearmsRemotes and FirearmsRemotes:WaitForChild("Fire", 10)
	local HitRemote  = FirearmsRemotes and FirearmsRemotes:FindFirstChild("Hit")

	-- Bow remotes (resolved lazily — may not exist until a bow loads)
	local BowRemotes, BowFire, BowLaunch, BowHit
	local arrowSpeed, arrowGravity, arrowDrag = nil, 18, 0

	local SA_NPC_FOLDERS = { "Sleepers", "Scientists", "Animals" }
	local SA = {
		fireRemotes = {}, hitRemotes = {}, bowRemotes = {},
		flightRemote = nil, flightConn = nil, flightHookedRemote = nil,
		pendingId = nil, pendingAt = 0,
		npcList = {}, npcSet = {}, npcAt = 0,
	}
	local function addNpcModel(model)
		if not (model and model:IsA("Model")) then return end
		if model == lp.Character then return end
		if not model:FindFirstChildOfClass("Humanoid") then return end
		if Players:GetPlayerFromCharacter(model) then return end
		if SA.npcSet[model] then return end
		SA.npcSet[model] = true
		SA.npcList[#SA.npcList + 1] = model
	end
	local function removeNpcModel(model)
		if not SA.npcSet[model] then return end
		SA.npcSet[model] = nil
		for i = #SA.npcList, 1, -1 do
			if SA.npcList[i] == model then table.remove(SA.npcList, i); break end
		end
	end
	local function scanNpcRoots()
		-- O(1) top-level + two shallow levels. New models arrive through
		-- DescendantAdded; no Workspace:GetDescendants() sweep is ever used.
		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj:IsA("Model") then
				addNpcModel(obj)
			elseif obj:IsA("Folder") or obj:IsA("Configuration") then
				for _, child in ipairs(obj:GetChildren()) do
					addNpcModel(child)
					if child:IsA("Folder") or child:IsA("Configuration") then
						for _, grand in ipairs(child:GetChildren()) do addNpcModel(grand) end
					end
				end
			end
		end
	end
	function SA.refreshNpcs(force)
		local now = os.clock()
		if not force and now - SA.npcAt < 5 then return end
		SA.npcAt = now
		table.clear(SA.npcList)
		table.clear(SA.npcSet)
		for _, fname in ipairs(SA_NPC_FOLDERS) do
			local folder = Workspace:FindFirstChild(fname)
			if folder then
				for _, mdl in ipairs(folder:GetChildren()) do addNpcModel(mdl) end
			end
		end
		local gr = Workspace:FindFirstChild("GunRange")
		local dum = gr and gr:FindFirstChild("Dummies")
		if dum then
			for _, mdl in ipairs(dum:GetChildren()) do addNpcModel(mdl) end
		end
		scanNpcRoots()
	end

	local function hookFlight()
		if SA.flightHookedRemote == SA.flightRemote then return end
		if SA.flightConn then pcall(SA.flightConn.Disconnect, SA.flightConn) end
		SA.flightHookedRemote = SA.flightRemote
		SA.flightConn = nil
		if not SA.flightRemote then return end
		SA.flightConn = bind(SA.flightRemote.OnClientEvent:Connect(function(...)
			for _, v in ipairs({ ... }) do
				if typeof(v) == "Vector3" and v.Magnitude > 20 then
					arrowSpeed = v.Magnitude
				elseif type(v) == "table" then
					if type(v.speed) == "number" then arrowSpeed = v.speed end
					if type(v.gravity) == "number" then arrowGravity = v.gravity end
					if type(v.drag) == "number" then arrowDrag = v.drag end
				end
			end
			OVX.arrowSpeed, OVX.arrowGravity, OVX.arrowDrag = arrowSpeed, arrowGravity, arrowDrag
		end))
	end
	local function classifyRemote(desc)
		if not (desc:IsA("RemoteEvent") or desc:IsA("UnreliableRemoteEvent")) then return end
		local n = string.lower(desc.Name)
		local path = ""
		pcall(function() path = string.lower(desc:GetFullName()) end)
		local isBow = string.find(n, "bow", 1, true)
			or string.find(path, "bowremotes", 1, true)
			or string.find(path, "bow", 1, true)
		if n == "fire" or string.find(n, "fire", 1, true) then
			if isBow then
				SA.bowRemotes[desc] = true
				SA.fireRemotes[desc] = nil
			else
				SA.fireRemotes[desc] = true
			end
		elseif n == "hit" or string.find(n, "hit", 1, true) or string.find(n, "damage", 1, true) then
			SA.hitRemotes[desc] = true
		elseif string.find(n, "launch", 1, true) and isBow then
			SA.bowRemotes[desc] = true
			SA.fireRemotes[desc] = nil
		elseif n == "flight" then
			SA.flightRemote = desc
			hookFlight()
		end
	end
	local function removeRemote(desc)
		SA.fireRemotes[desc], SA.hitRemotes[desc], SA.bowRemotes[desc] = nil, nil, nil
		if SA.flightRemote == desc then
			SA.flightRemote = nil
			hookFlight()
		end
	end
	local function registerRemoteBuckets()
		table.clear(SA.fireRemotes)
		table.clear(SA.hitRemotes)
		table.clear(SA.bowRemotes)
		SA.flightRemote = nil
		SA.pendingId, SA.pendingAt = nil, 0
		local containers = { RepStorage }
		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj:IsA("Folder") or obj:IsA("Configuration") then
				containers[#containers + 1] = obj
			end
		end
		-- One-time / on-demand bucket build; subsequent remotes are classified
		-- incrementally by DescendantAdded, not by a periodic descendant sweep.
		for _, root in ipairs(containers) do
			for _, desc in ipairs(root:GetDescendants()) do classifyRemote(desc) end
		end
		if FireRemote then SA.fireRemotes[FireRemote] = true end
		if HitRemote then SA.hitRemotes[HitRemote] = true end
		if BowFire then SA.bowRemotes[BowFire] = true; SA.fireRemotes[BowFire] = nil end
		if BowLaunch then SA.bowRemotes[BowLaunch] = true; SA.fireRemotes[BowLaunch] = nil end
		if BowHit then SA.hitRemotes[BowHit] = true end
		hookFlight()
	end
	function SA.rescan()
		registerRemoteBuckets()
		SA.refreshNpcs(true)
	end
	OVX.saRescan = SA.rescan
	OVX.saNpcList = SA.npcList
	OVX.saRefreshNpcs = SA.refreshNpcs
	bind(RepStorage.DescendantAdded:Connect(function(obj) classifyRemote(obj) end))
	bind(RepStorage.DescendantRemoving:Connect(function(obj) removeRemote(obj) end))
	bind(Workspace.DescendantAdded:Connect(function(obj)
		addNpcModel(obj)
		classifyRemote(obj)
	end))
	bind(Workspace.DescendantRemoving:Connect(function(obj)
		removeNpcModel(obj)
		removeRemote(obj)
	end))
	SA.refreshNpcs(true)
	registerRemoteBuckets()
	local bowFlightHooked = false
	local function refreshBowRemotes()
		if not (BowFire and BowLaunch and BowHit) then
			BowRemotes = RepStorage:FindFirstChild("BowRemotes")
			BowFire   = BowRemotes and BowRemotes:FindFirstChild("Fire")
			BowLaunch = BowRemotes and BowRemotes:FindFirstChild("Launch")
			BowHit    = BowRemotes and BowRemotes:FindFirstChild("Hit")
		end
		-- capture live arrow speed/gravity from the Flight event (server-authoritative)
		if BowRemotes and not bowFlightHooked then
			local flight = BowRemotes:FindFirstChild("Flight")
			if flight then
				bowFlightHooked = true
				bind(flight.OnClientEvent:Connect(function(...)
					local args = { ... }
					local rows = {}
					if type(args[1]) == "table" and type(args[1][1]) == "table" then
						-- batch: { {id, payload}, ... }
						for _, row in ipairs(args[1]) do
							if type(row) == "table" then rows[#rows + 1] = { id = row[1], data = row[2] } end
						end
					else
						rows[#rows + 1] = { id = args[1], data = args[2] }
						for i = 3, #args do
							if type(args[i]) == "table" then rows[#rows + 1] = { data = args[i] } end
						end
					end
					for _, row in ipairs(rows) do
						local d = row.data
						if type(d) == "table" then
							local v2 = d.vel or d.v0 or d.velocity
							if typeof(v2) == "Vector3" and v2.Magnitude > 1 then arrowSpeed = v2.Magnitude end
							local g2 = d.gravity or d.g
							if type(g2) == "number" and g2 > 0 then arrowGravity = g2 end
							local k2 = d.drag or d.k
							if type(k2) == "number" and k2 >= 0 then arrowDrag = k2 end
							if typeof(row.id) == "number" and d.shooter == lp.UserId then
								-- server-generated flight id: bow claims quote this, not a seed
								OVX.bowLastFlight = {
									id = row.id, pos = d.pos, vel = d.vel, t0 = d.t0,
									gravity = d.gravity or d.g, drag = d.drag or d.k
								}
							end
						end
					end
					OVX.arrowSpeed, OVX.arrowGravity, OVX.arrowDrag = arrowSpeed, arrowGravity, arrowDrag
				end))
			end
		end
	end
	refreshBowRemotes()

	-- Low-arc ballistic solve: returns unit dir + flight time so a projectile
	-- (speed s, gravity g) fired from eye hits target. nil if out of range.
	local function solveArc(eye, target, s, g)
		local disp = target - eye
		local flat = v3new(disp.X, 0, disp.Z)
		local dh = flat.Magnitude
		if dh < 1e-3 then return (disp.Magnitude > 1e-3 and disp.Unit) or nil, nil end
		local dy = disp.Y
		local s2 = s * s
		local root = s2 * s2 - g * (g * dh * dh + 2 * dy * s2)
		if root < 0 then return nil, nil end
		local angle = math.atan((s2 - math.sqrt(root)) / (g * dh))
		local dir = (flat.Unit * math.cos(angle) + v3new(0, 1, 0) * math.sin(angle)).Unit
		local flightTime = dh / (s * math.cos(angle))
		return dir, flightTime
	end


	-- Rolling velocity sampler: 4-sample average of HRP world position deltas.
	-- Returns smoothed velocity Vector3, or zero if not enough samples yet.
	local _velBuf = {}   -- keyed by player UserId: { samples = {}, last = pos }
	local function sampleVelocity(player)
		local char = player and player.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return v3new(0, 0, 0) end
		local uid = player.UserId
		if not _velBuf[uid] then _velBuf[uid] = { samples = {}, lastPos = hrp.Position, lastT = os.clock() } end
		local buf = _velBuf[uid]
		local now = os.clock()
		local dt  = now - buf.lastT
		if dt > 0.005 then
			local vel = (hrp.Position - buf.lastPos) / dt
			table.insert(buf.samples, v3new(vel.X, vel.Y, vel.Z))
			if #buf.samples > 4 then table.remove(buf.samples, 1) end
			buf.lastPos = hrp.Position
			buf.lastT   = now
		end
		if #buf.samples == 0 then return v3new(0, 0, 0) end
		local sum = v3new(0, 0, 0)
		for _, v in ipairs(buf.samples) do sum = sum + v end
		return sum / #buf.samples
	end

	-- Predict target's lateral position after flightTime seconds.
	-- Y is zeroed — gravity is already handled by solveArc, not here.
	local function predictPosition(player, tgtPoint, flightTime)
		local vel = sampleVelocity(player)
		return v3new(
			tgtPoint.X + vel.X * flightTime,
			tgtPoint.Y,
			tgtPoint.Z + vel.Z * flightTime
		)
	end

	-- BULLET PEEK: ray helpers. Exclude our camera/character only — the TARGET
	-- stays in the filter so cover genuinely blocks the ray (a ray that ends on
	-- the target's own body counts as clear).
	local bpRay = RaycastParams.new()
	bpRay.FilterType = Enum.RaycastFilterType.Exclude
	bpRay.IgnoreWater = true
	local function rayClear(from, to, model)
		local filt = { lp.Character }
		local cam = Workspace.CurrentCamera
		if cam then filt[#filt + 1] = cam end
		bpRay.FilterDescendantsInstances = filt
		local hit = Workspace:Raycast(from, to - from, bpRay)
		if not hit then return true end
		if model and hit.Instance and hit.Instance:IsDescendantOf(model) then return true end
		return false
	end
	-- Shared with Triggerbot: this is the exact eye→target test that colours
	-- the snapline green (clear) / red (covered).
	OVX.rayClear = rayClear
	-- GUN PEEK: sidestep so the muzzle itself clears cover. Two modes:
	-- desync (default): the SERVER copy of your character moves to the peek
	-- spot while the real body never leaves home — no teleport jank; the
	-- camera carries the viewmodel to the peeked eye so the Fire origin
	-- matches the spoofed position the server sees. Teleport mode moves the
	-- real HRP like before. Both fire legally — no packet forgery.
	local bpHome, bpPeekPos, bpPeekUntil = nil, nil, 0
	local bpPeekEye, bpDesync = nil, false
	local function gunPeekStop()
		if not bpHome then return end
		if bpDesync then
			if OVX.desyncPeekClear then pcall(OVX.desyncPeekClear) end
		else
			local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			if hrp then pcall(function() hrp.CFrame = bpHome end) end
		end
		bpHome, bpPeekPos, bpPeekEye, bpDesync = nil, nil, nil, false
	end
	-- sidestep candidate with a clear line from the future eye to the aim point
	local function gunPeekFind(tgt, eye)
		local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return nil end
		local aimPoint = (tgt.part and tgt.part.Parent and tgt.part.Position) or tgt.point
		local eyeUp = eye.Y - hrp.Position.Y
		local maxBend = tonumber(flags["bp_max_offset"]) or 8
		local r = 2
		while r <= maxBend do
			for i = 0, 11 do
				local ang = (i / 12) * math.pi * 2
				local cand = hrp.Position + v3new(math.cos(ang) * r, 0, math.sin(ang) * r)
				if rayClear(cand + v3new(0, eyeUp, 0), aimPoint, tgt.model) then return cand end
			end
			r = r + 2
		end
		return nil
	end
	local function gunPeekStart(tgt, eye)
		if bpHome then
			-- already peeked: extend the window
			bpPeekUntil = os.clock() + 0.3
			return
		end
		local cand = gunPeekFind(tgt, eye)
		if not cand then return end
		local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local eyeUp = eye.Y - hrp.Position.Y
		bpHome = hrp.CFrame
		bpPeekPos = cand
		bpPeekEye = cand + v3new(0, eyeUp, 0)
		bpPeekUntil = os.clock() + 0.3
		-- desync mode arms on the NEXT Heartbeat, after this frame's natural
		-- shot (fired from home) is already in the send queue. Off by default:
		-- in this game the spoofed position may never reach the server, and
		-- peek shots sent from an origin the server can't match get rejected
		bpDesync = flags["bp_desync"] == true and type(OVX.desyncPeekSet) == "function"
		if not bpDesync then
			hrp.CFrame = CFrame.new(cand) * bpHome.Rotation
		end
	end
	-- hold the peek until the window lapses or the lock drops
	bind(RunService.Heartbeat:Connect(function()
		if not bpHome then return end
		local tgt = OVX.saTarget
		if os.clock() > bpPeekUntil or not (tgt and tgt.part and tgt.part.Parent) then
			gunPeekStop()
			return
		end
		if bpDesync then
			-- glue the spoof to the peek spot every Heartbeat (the desync
			-- block rewrites the server copy; the local body stays home)
			if OVX.desyncPeekSet then pcall(OVX.desyncPeekSet, CFrame.new(bpPeekPos) * bpHome.Rotation) end
			return
		end
		local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			gunPeekStop()
			return
		end
		hrp.CFrame = CFrame.new(bpPeekPos) * bpHome.Rotation
	end))
	bind({ Disconnect = gunPeekStop })
	-- camera holds the crosshair on the locked target while peeked (desync:
	-- it also carries the eye to the peek spot so the origin matches)
	-- drop any binding left by a previous copy before installing our own
	pcall(function() RunService:UnbindFromRenderStep("OVXGunPeekCam") end)
	RunService:BindToRenderStep("OVXGunPeekCam", Enum.RenderPriority.Camera.Value + 1, function()
		if not bpHome then return end
		local tgt = OVX.saTarget
		local cam = Workspace.CurrentCamera
		if cam and tgt and tgt.part and tgt.part.Parent then
			if bpDesync and bpPeekEye then
				cam.CFrame = CFrame.lookAt(bpPeekEye, tgt.part.Position)
			else
				cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tgt.part.Position)
			end
		end
	end)
	bind({ Disconnect = function()
		pcall(function() RunService:UnbindFromRenderStep("OVXGunPeekCam") end)
	end })

	-- FOV circle (follows the cursor, PSilent origin)
	local fovCircle = Drawingnew("Circle")
	fovCircle.Thickness = 1; fovCircle.NumSides = 64; fovCircle.Filled = false
	fovCircle.Color = c3(255, 255, 255); fovCircle.Transparency = 0.7; fovCircle.Visible = false

	-- snapline + target crosshair (green = clear view, red = covered)
	local snapLine = Drawingnew("Line")
	snapLine.Thickness = 1; snapLine.Visible = false
	local crossV = Drawingnew("Line")
	crossV.Thickness = 1; crossV.Visible = false
	local crossH = Drawingnew("Line")
	crossH.Thickness = 1; crossH.Visible = false

	local randomBoneCache = setmetatable({}, { __mode = "k" })
	math.randomseed(math.floor(os.clock() * 1000) + 42)
	local function pickRandomBone(model)
		local now = os.clock()
		local cached = randomBoneCache[model]
		if cached and cached.part and cached.part.Parent and now < cached.expires then
			return cached.part
		end
		local parts = {}
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then parts[#parts + 1] = child end
		end
		if #parts == 0 then
			return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
		end
		local part = parts[math.random(1, #parts)]
		randomBoneCache[model] = { part = part, expires = now + 0.35 }
		return part
	end
	local function closestToCrosshair(model, camera, crosshair)
		local best, bestD
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				local sp, on = camera:WorldToViewportPoint(child.Position)
				local d
				if on and sp.Z > 0 then
					d = (v2new(sp.X, sp.Y) - crosshair).Magnitude
				else
					d = (child.Position - camera.CFrame.Position).Magnitude * 1000
				end
				if not bestD or d < bestD then bestD, best = d, child end
			end
		end
		return best or model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	end
	local function pickBone(model, bone, crosshair, camera)
		if bone == "Head" then
			return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
		elseif bone == "Torso / HRP" then
			return model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
		elseif bone == "RANDOM" then
			return pickRandomBone(model)
		elseif bone == "Closest To CrossHair" or bone == "Closest" then
			return closestToCrosshair(model, camera, crosshair)
		end
		return closestToCrosshair(model, camera, crosshair)
	end
	OVX.pickBone = pickBone

	local function getTarget()
		SA.refreshNpcs(false)
		local camera = Workspace.CurrentCamera
		if not camera or not flags["sa_enabled"] then return nil end
		local m = UIS:GetMouseLocation()
		local crosshair = v2new(m.X, m.Y)
		local fov      = OVX.saFov()
		local maxd     = OVX.saMaxDist()
		local teamChk  = flags["sa_team_check"]
		local bone     = flags["sa_force_head"] ~= false and "Head" or (flags["sa_bone"] or "Head")
		local lchar = lp.Character
		local lhrp  = lchar and lchar:FindFirstChild("HumanoidRootPart")
		local best, bestD = nil, fov
		local bestScore = math.huge
		local rageScan = flags["rb_enabled"] == true
		local function consider(model, isNpc)
			if not model or model == lchar or not model.Parent then return end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not (hum and hum.Health > 0) then return end
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if maxd > 0 and lhrp and hrp and (hrp.Position - lhrp.Position).Magnitude > maxd then return end
			local part = pickBone(model, bone, crosshair, camera)
			if not part then return end
			if rageScan then
				local score = OVX.ragebotTargetScore(part, camera, crosshair, fov)
				if not score or score >= bestScore then return end
				local isDummy = model:GetAttribute("RangeDummy") ~= nil
					or (model.Parent and model.Parent.Name == "Dummies")
				bestScore = score
				best = {
					part = part, point = part.Position, model = model,
					isNpc = isNpc and not isDummy, isDummy = isDummy and true or false,
				}
				return
			end
			local sp, on = camera:WorldToViewportPoint(part.Position)
			if on and sp.Z > 0 then
				local d = (v2new(sp.X, sp.Y) - crosshair).Magnitude
				if d <= bestD then
					local isDummy = model:GetAttribute("RangeDummy") ~= nil
						or (model.Parent and model.Parent.Name == "Dummies")
					bestD = d
					best = {
						part = part, point = part.Position, model = model,
						isNpc = isNpc and not isDummy, isDummy = isDummy and true or false,
					}
				end
			end
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= lp and not (teamChk and sameTeam(pl)) then consider(pl.Character, false) end
		end
		if flags["sa_target_npc"] ~= false then
			for _, mdl in ipairs(SA.npcList) do
				if mdl.Parent then consider(mdl, true) end
			end
		end
		return best
	end

	local _saTarget = nil

	-- ── BOW AIM VIA shared.HeldViewCFrame ───────────────────────────────────
	-- BowClient builds BOTH the Fire packet direction and its own local arrow
	-- simulation from shared.HeldViewCFrame. Bending only the Fire packet made
	-- the client sim and the server re-sim disagree, so every claim was
	-- rejected. Bend the held view instead: packet + sim + server all agree.
	local bowOrigHV, bowHVTarget = nil, nil
	local bowHvDone = false
	local function bowHeldView(cf)
		local orig = bowOrigHV
		if not (saActive and flags and flags["sa_enabled"] and flags["sa_bow_enabled"] ~= false) then
			return orig and orig(cf) or nil
		end
		local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
		local isBow = tool and (tool:GetAttribute("BowStyle") ~= nil
			or tool.Name == "Hunting Bow" or tool.Name == "Compound Bow"
			or tool.Name == "Mini Crossbow" or tool.Name == "Blowpipe")
		local tgt = _saTarget
		if not (tgt and tgt.part and tgt.part.Parent) then return orig and orig(cf) or nil end
		local base = orig and orig(cf) or cf
		if typeof(base) ~= "CFrame" then base = cf end
		local livePoint = tgt.part.Position
		local aimPoint = livePoint
		local dir, flight = solveArc(base.Position, livePoint, arrowSpeed or 175, arrowGravity or 18)
		if not dir then return base end
		local lead = tonumber(flags["sa_bow_lead"]) or 1
		if lead > 0 and flight and flight > 0 then
			local plr = tgt.model and Players:GetPlayerFromCharacter(tgt.model) or nil
			local vel = plr and sampleVelocity(plr) or v3new(0, 0, 0)
			if vel.Magnitude < 0.05 then
				local root = tgt.model and (tgt.model:FindFirstChild("HumanoidRootPart") or tgt.model.PrimaryPart)
				if root then vel = root.AssemblyLinearVelocity or vel end
			end
			if vel.Magnitude > 0.1 then
				-- converge: the lead point changes the flight time, which changes
				-- the lead. Two passes is enough for a moving target.
				for _ = 1, 2 do
					aimPoint = livePoint + v3new(vel.X * flight * lead, 0, vel.Z * flight * lead)
					local nd, nf = solveArc(base.Position, aimPoint, arrowSpeed or 175, arrowGravity or 18)
					if not nd then break end
					dir, flight = nd, nf
				end
				OVX.bowLeadVel = vel
			end
		end
		OVX.bowAimAt = aimPoint
		OVX.bowFlight = flight
		return CFrame.lookAt(base.Position, base.Position + dir)
	end
	local function installBowHeldView()
		if bowHvDone then return true end
		if type(hookfunction) ~= "function" or type(newcclosure) ~= "function" then return false end
		local sh = getrenv and getrenv().shared or shared
		if not sh then return false end
		local cur = sh.HeldViewCFrame
		if type(cur) ~= "function" then return false end
		local ok, orig = pcall(function() return hookfunction(cur, newcclosure(bowHeldView, "OVXBowAim")) end)
		if ok and type(orig) == "function" then
			bowOrigHV, bowHVTarget, bowHvDone = orig, cur, true
			OVX.bowHVInstalls = (OVX.bowHVInstalls or 0) + 1
			return true
		end
		return false
	end
	installBowHeldView()
	bind({ Disconnect = function()
		if bowHVTarget and bowOrigHV and type(restorefunction) == "function" then
			pcall(restorefunction, bowOrigHV, bowHVTarget)
		end
		bowOrigHV, bowHVTarget, bowHvDone = nil, nil, false
	end })
	local _saColor = c3(60, 255, 60)
	local lastScanAt, lastBowAt = 0, 0
	bind(RunService.Heartbeat:Connect(function()
		if not (saActive and flags["sa_enabled"]) then
			_saTarget = nil
			OVX.saTarget = nil
			return
		end
		local now = os.clock()
		local hz = math.clamp(tonumber(flags["sa_scan_hz"]) or 12, 4, 30)
		if now - lastScanAt >= 1 / hz then
			lastScanAt = now
			local okG, res = pcall(getTarget)
			if okG then _saTarget = res else OVX.saErr = tostring(res); _saTarget = nil end
			OVX.saTarget = _saTarget
			OVX.saScanAt = now
			if _saTarget and _saTarget.part and _saTarget.part.Parent then
				local cam = Workspace.CurrentCamera
				local covered = cam and not rayClear(cam.CFrame.Position, _saTarget.part.Position, _saTarget.model)
				_saColor = covered and c3(255, 60, 60) or c3(60, 255, 60)
			end
		end
		if now - lastBowAt >= 1 then
			lastBowAt = now
			pcall(refreshBowRemotes)
		end
	end))
	bind(RunService.RenderStepped:Connect(function()
		local on = saActive and flags["sa_enabled"]
		if not on then
			fovCircle.Visible = false
			snapLine.Visible = false; crossV.Visible = false; crossH.Visible = false
			return
		end
		local m = UIS:GetMouseLocation()
		local radius = OVX.saFov()
		fovCircle.Visible = flags["sa_show_fov"] == true
		fovCircle.Position = v2new(m.X, m.Y)
		if fovCircle.Visible then fovCircle.Radius = math.max(1, math.min(radius, 5000)) end
		local tgt = _saTarget
		local allowNpc = flags["sa_snapline_npc"] ~= false
		local canDraw = (flags["sa_snapline"] or flags["sa_cross"]) and tgt
			and tgt.part and tgt.part.Parent and (allowNpc or not tgt.isNpc)
		if not canDraw then
			snapLine.Visible = false; crossV.Visible = false; crossH.Visible = false
			return
		end
		local cam = Workspace.CurrentCamera
		if not cam then
			snapLine.Visible = false; crossV.Visible = false; crossH.Visible = false
			return
		end
		local sp, onScreen = cam:WorldToViewportPoint(tgt.part.Position)
		if not (onScreen and sp.Z > 0) then
			snapLine.Visible = false; crossV.Visible = false; crossH.Visible = false
			return
		end
		local tp = v2new(sp.X, sp.Y)
		if flags["sa_snapline"] then
			snapLine.From = v2new(m.X, m.Y); snapLine.To = tp
			snapLine.Color = _saColor; snapLine.Visible = true
		else
			snapLine.Visible = false
		end
		if flags["sa_cross"] then
			crossV.From = v2new(tp.X, tp.Y - 6); crossV.To = v2new(tp.X, tp.Y + 6)
			crossH.From = v2new(tp.X - 6, tp.Y); crossH.To = v2new(tp.X + 6, tp.Y)
			crossV.Color = _saColor; crossH.Color = _saColor
			crossV.Visible = true; crossH.Visible = true
		else
			crossV.Visible = false; crossH.Visible = false
		end
	end))

	-- Integrated remote jack: the original game-specific Fire/Hit path plus
	-- the attached script's multi-method fire/hit/damage remote buckets.
	if (FireRemote or next(SA.fireRemotes) ~= nil or next(SA.hitRemotes) ~= nil or next(SA.bowRemotes) ~= nil)
		and hookmetamethod and newcclosure and getnamecallmethod then
		local firingOwn = false
		local hasCheckcaller = type(checkcaller) == "function"
		local function dispatchInstantHits(claimId, part, hitPoint)
			if flags["sa_instant_hit"] == false or claimId == nil or not (part and part.Parent) then return end
			local serverTime = Workspace:GetServerTimeNow()
			for remote in pairs(SA.hitRemotes) do
				pcall(function() remote:FireServer(claimId, 1, part, hitPoint, serverTime) end)
			end
		end
		local function sendClaims(claimId, part, hitPoint)
			firingOwn = true
			pcall(dispatchInstantHits, claimId, part, hitPoint)
			firingOwn = false
		end
		local function sendDelayedClaim(claimId, part, hitPoint)
			if not HitRemote then return end
			firingOwn = true
			pcall(function() HitRemote:FireServer(claimId, 1, part, hitPoint, Workspace:GetServerTimeNow()) end)
			firingOwn = false
		end
		local function rememberClaim(claimId)
			if claimId == nil then return end
			SA.pendingId, SA.pendingAt = claimId, os.clock()
		end
		local function rewriteFireArgs(args, tgt)
			if SA.pendingId and os.clock() - SA.pendingAt > 1.5 then SA.pendingId = nil end
			local livePoint = tgt.part.Position
			local origin
			for i, v in ipairs(args) do
				if typeof(v) == "Vector3" and v.Magnitude > 0.001 then
					if origin == nil and i == 1 then
						origin = v
					elseif origin ~= nil and i == 2 then
						args[i] = (livePoint - origin).Unit
					elseif math.abs(v.Magnitude - 1) < 0.05 and origin ~= nil then
						args[i] = (livePoint - origin).Unit
					end
				elseif type(v) == "table" and v.id ~= nil then
					rememberClaim(v.id)
				end
			end
			if SA.pendingId == nil and args[3] ~= nil then rememberClaim(args[3]) end
			return args, livePoint
		end
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			if firingOwn or not saActive then return old(self, ...) end
			local notOurs = not (hasCheckcaller and checkcaller())
			if notOurs then
				local method = getnamecallmethod()
				if method == "FireServer" then
					if flags["sf_tracers_enabled"] and OVX.sciFiTracer then
						pcall(OVX.sciFiTracer, self, ...)
					end
					if flags["sa_enabled"] and flags["sa_remote_jack"] ~= false then
					-- FirearmsRemotes.Fire: known packet shape + gun peek.
					if self == FireRemote then
						local a = { ... }
						local tgt = _saTarget
						if tgt and typeof(a[1]) == "Vector3" then
							local livePoint = (tgt.part and tgt.part.Parent and tgt.part.Position) or tgt.point
							local claim = a[4]
							local claimId = typeof(claim) == "table" and type(claim.id) == "number" and claim.id or nil
							if flags["bp_enabled"] and typeof(livePoint) == "Vector3"
								and not rayClear(a[1], livePoint, tgt.model) then
								gunPeekStart(tgt, a[1])
								return old(self, ...)
							end
							local aimPart, aimPoint = tgt.part, livePoint
							a[2] = (aimPoint - a[1]).Unit
							if claimId then rememberClaim(claimId) end
							OVX.saRedirectAt = os.clock()
							local ret = old(self, unpack(a))
							local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
							local speed = (tool and tonumber(tool:GetAttribute("BulletSpeed"))) or 1e4
							local travel = (aimPoint - a[1]).Magnitude / math.max(speed, 1)
							OVX.saFireDebug = {
								t = os.clock(), tool = tool and tool.Name or "?",
								peek = bpHome ~= nil, claim = claimId,
								dist = math.floor((aimPoint - a[1]).Magnitude + 0.5),
							}
							if claimId then
								if flags["sa_instant_hit"] ~= false then
									sendClaims(claimId, aimPart, aimPoint)
								else
									task.delay(travel, function() sendDelayedClaim(claimId, aimPart, aimPoint) end)
								end
							end
							return ret
						end
					end
					-- Generic fire/damage remotes discovered by the bucket scan.
					if SA.fireRemotes[self] and not SA.bowRemotes[self] and self ~= FireRemote then
						local tgt = _saTarget
						if tgt and tgt.part and tgt.part.Parent then
							local args = { ... }
							local rewritten, livePoint = rewriteFireArgs(args, tgt)
							local ret = old(self, unpack(rewritten))
							sendClaims(SA.pendingId, tgt.part, livePoint)
							return ret
						end
					end
					-- Bow/launch remotes: held view already bends the shot.
					if self == BowFire or self == BowLaunch or SA.bowRemotes[self] then
						OVX.bowFireCount = (OVX.bowFireCount or 0) + 1
						if flags["sa_bow_enabled"] ~= false then
							local tgt = _saTarget
							local a = { ... }
							local claim = a[4]
							local claimId = type(claim) == "table" and type(claim.id) == "number" and claim.id or a[3]
							if tgt and tgt.part and tgt.part.Parent and claimId then
								rememberClaim(claimId)
								sendClaims(claimId, tgt.part, tgt.part.Position)
							end
						end
						return old(self, ...)
					end
					-- Suppress the game's stale original claim for this shot id.
					if (SA.hitRemotes[self] or self == HitRemote) and SA.pendingId ~= nil
						and os.clock() - SA.pendingAt < 1.5 then
						local a = { ... }
						if a[1] == SA.pendingId then
							SA.pendingId = nil
							return
						end
					end
				end
				end
			end
			return old(self, ...)
		end))
		namecallOrig = old
	end

	-- unload: make the hook inert and drop the FOV circle + overlays
	bind({ Disconnect = function()
		saActive = false
		if namecallOrig then
			pcall(function() hookmetamethod(game, "__namecall", namecallOrig) end)
		end
		pcall(function() fovCircle:Remove() end)
		pcall(function() snapLine:Remove() end)
		pcall(function() crossV:Remove() end)
		pcall(function() crossH:Remove() end)
	end })
end

-- ================================================================
-- // TRIGGERBOT (input-level, guns + bows)
-- //   Fires the held gun when a valid target sits inside the FOV and
-- //   is VISIBLE: with Silent Aim on it reuses SA's lock, so a green
-- //   snapline means "this will fire" (red/covered = hold fire). With
-- //   SA off it runs its own FOV scan + the same eye→target ray check.
-- //   Real OS clicks (mouse1press/release) follow the gun's RPM, or the
-- //   Weapon Mods > Rapid Fire RPM when that mod is on. Ammo, reload, bolt
-- //   cycle and striker mechanics all stay vanilla, and Silent Aim keeps
-- //   redirecting the shots it produces. ONE FOV source: Silent Aim's.
-- //   Skips while the OVX menu holds the cursor, while you hold the
-- //   real fire button (optional), while reloading, or on empty mags.
-- ================================================================
do
	local hasInput = type(mouse1press) == "function" and type(mouse1release) == "function"
	local lastClick, clicking = 0, false
	local BOW_NAMES = {
		["Hunting Bow"] = true, ["Compound Bow"] = true, ["Mini Crossbow"] = true,
		["Blow Pipe"] = true, Speargun = true,
	}
	local function fireClick(hold)
		if clicking then return end
		clicking = true
		task.spawn(function()
			pcall(mouse1press)
			task.wait(hold or 0.045)
			pcall(mouse1release)
			clicking = false
		end)
	end
	-- FOV + visibility acquisition. There is ONE FOV source: Silent Aim's
	-- "sa_fov". With SA on we reuse its published lock, so the green/red
	-- snapline is exactly the triggerbot's target + visibility test. With
	-- SA off we run the same scan locally against that same sa_fov value.
	local function visibleTarget(char)
		local cam = Workspace.CurrentCamera
		if not cam then return nil end
		local saTgt = OVX.saTarget
		if saTgt and saTgt.part and saTgt.part.Parent then
			if flags["tb_visible"] ~= false and type(OVX.rayClear) == "function"
				and not OVX.rayClear(cam.CFrame.Position, saTgt.part.Position, saTgt.model) then
				return nil -- red snapline: covered, hold fire
			end
			return saTgt
		end
		local m = UIS:GetMouseLocation()
		local crosshair = v2new(m.X, m.Y)
		local fov = OVX.saFov() -- single FOV source: Silent Aim / Ragebot INF
		local maxd = tonumber(flags["tb_max_dist"]) or 0
		if maxd <= 0 and flags["rb_enabled"] == true then
			maxd = OVX.saMaxDist()
		elseif maxd <= 0 then
			maxd = tonumber(flags["sa_max_dist"]) or 0
		end
		local bone = flags["sa_force_head"] ~= false and "Head" or (flags["sa_bone"] or "Head")
		local teamChk = flags["sa_team_check"]
		local lhrp = char and char:FindFirstChild("HumanoidRootPart")
		local best, bestD = nil, fov
		local bestScore = math.huge
		local rageScan = flags["rb_enabled"] == true
		local function consider(model)
			if not model or model == char then return end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not (hum and hum.Health > 0) then return end
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if maxd > 0 and lhrp and hrp and (hrp.Position - lhrp.Position).Magnitude > maxd then return end
			local part = type(OVX.pickBone) == "function"
				and OVX.pickBone(model, bone, crosshair, cam)
				or model:FindFirstChild("Head")
			if not part then return end
			if rageScan then
				local score = OVX.ragebotTargetScore(part, cam, crosshair, fov)
				if not score or score >= bestScore then return end
				bestScore, best = score, { part = part, point = part.Position, model = model }
				return
			end
			local sp, on = cam:WorldToViewportPoint(part.Position)
			if not (on and sp.Z > 0) then return end
			local d = (v2new(sp.X, sp.Y) - crosshair).Magnitude
			if d > bestD then return end
			if flags["tb_visible"] ~= false and type(OVX.rayClear) == "function"
				and not OVX.rayClear(cam.CFrame.Position, part.Position, model) then return end
			bestD, best = d, { part = part, point = part.Position, model = model }
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= lp and not (teamChk and sameTeam(pl)) then consider(pl.Character) end
		end
		if flags["tb_npc"] ~= false then
			for _, mdl in ipairs(OVX.saNpcList or {}) do
				if mdl.Parent then consider(mdl) end
			end
		end
		return best
	end
	-- OVX menu / game UI holds the cursor away from center: never fire then
	local function menuUp()
		if flags["rb_enabled"] == true then return false end
		if library.menu_visible == true or (nativeWindow and nativeWindow._compatMenuVisible) then return true end
		local ok, mb = pcall(function() return UIS.MouseBehavior end)
		if ok and mb == Enum.MouseBehavior.LockCenter then return false end
		local cam = Workspace.CurrentCamera
		if not cam then return true end
		local m = UIS:GetMouseLocation()
		local vs = cam.ViewportSize
		local dx, dy = m.X - vs.X * 0.5, m.Y - vs.Y * 0.5
		return dx * dx + dy * dy > 14400 -- 120 px
	end
	bind(RunService.Heartbeat:Connect(function()
		if not (hasInput and flags["tb_enabled"]) then return end
		if menuUp() then return end
		if isrbxactive and not isrbxactive() then return end
		local char = lp.Character
		if not char or char:GetAttribute("Downed") then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) then return end
		local tool = char:FindFirstChildOfClass("Tool")
		if not tool then return end
		local isGun = tool:GetAttribute("GunId") ~= nil
		local isBow = not isGun and (tool:GetAttribute("BowStyle") ~= nil or BOW_NAMES[tool.Name] == true)
		if not (isGun or isBow) then return end
		if tool:GetAttribute("Reloading") == true then return end
		if isGun and (tonumber(tool:GetAttribute("Ammo")) or 0) <= 0 then return end
		if isBow and (tonumber(tool:GetAttribute("Loaded") or 1) <= 0) then return end
		if flags["tb_skip_holding"] ~= false
			and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end
		-- Rapid Fire owns the cadence when it's on; otherwise use the gun's RPM
		-- (bows have no RPM attribute, so fall back to one shot every 0.5s)
		local rpm = tonumber(tool:GetAttribute("RPM")) or (isBow and 120 or 250)
		if flags["wm_rapidfire"] then rpm = tonumber(flags["wm_rpm"]) or 600 end
		local interval = 60 / math.max(rpm, 1)
		local now = os.clock()
		if now - lastClick < interval then return end
		local tgt = visibleTarget(char)
		if not tgt then return end
		local mdl = tgt.model or (tgt.part and tgt.part:FindFirstAncestorOfClass("Model"))
		if not (mdl and mdl ~= char) then return end
		local h = mdl:FindFirstChildOfClass("Humanoid")
		if not (h and h.Health > 0) then return end
		local plr = Players:GetPlayerFromCharacter(mdl)
		if plr then
			if plr == lp or sameTeam(plr) then return end
		elseif flags["tb_npc"] == false and not mdl:GetAttribute("RangeDummy") then
			return -- NPCs/dummies still count even when "Target NPCs" is off
		end
		lastClick = now
		-- debug stamps for live validation (read via the bridge)
		OVX.tbFireAt = now
		OVX.tbTarget = mdl.Name
		OVX.tbRpm = rpm
		-- bows need a real draw before release unless Instant Charge is on
		local hold = math.min(0.05, interval * 0.5)
		if isBow then hold = flags["wm_instantcharge"] and 0.15 or 0.7 end
		fireClick(hold)
	end))
	bind({ Disconnect = function()
		if clicking then pcall(mouse1release) end
		clicking = false
	end })
end

-- (bow SA merged into the firearms SA hook above — single __namecall hook)

-- ================================================================
-- // WEAPON MODS (bow SA stub removed — kept for search anchor only)
-- //   NOTE: the line below is not real code, just a section separator
-- ================================================================
--[[ BOW SILENT AIM merged — search "BOW SA" in the firearms hook above ]]

-- (bow SA merged into the firearms SA hook above — no second hook needed)

-- ================================================================
-- // WEAPON MODS (firearms + bow) — edits the live def/state tables
-- //   (ported from vault-esp_22: filtergc locates the weapon def/state
-- //   tables; modded values are rewritten each frame with originals
-- //   snapshotted so toggling off / unloading restores them)
-- // RANGE OVERRIDE — attribute-based, kept as before
-- ================================================================
local wmActive = true
local wmTickAt = 0
do
	local V2Z = Vector2.new(0, 0)
	local V3Z = Vector3.new(0, 0, 0)
	local CFZ = CFrame.new()

	local hasFilter = type(filtergc) == "function"
	local defs, states, bows = {}, {}, {}
	local origDef = setmetatable({}, { __mode = "k" })
	local origMover = setmetatable({}, { __mode = "k" })
	local rangeOrig = setmetatable({}, { __mode = "k" })
	local bowDefs = {}
	local origBow = setmetatable({}, { __mode = "k" })
	local lastBowFind = 0

	local function scan(keys)
		if not hasFilter then return {} end
		local ok, res = pcall(filtergc, "table", { Keys = keys }, false)
		if ok and type(res) == "table" then return res end
		return {}
	end
	local BOW_FIELDS = { "DrawTime", "ShakeAfter", "HoldMax", "ShotTime", "EquipTime", "ReloadTime", "MagSize", "Zoom" }
	local function refindBow()
		if not hasFilter then return end
		local ok, res = pcall(filtergc, "table", { Keys = { "DrawTime", "ShakeAfter", "Kind", "Title" } }, false)
		if not (ok and type(res) == "table") then return end
		bowDefs = {}
		for _, t in ipairs(res) do
			if type(t) == "table" and type(t.Title) == "string" and type(t.Kind) == "string" then
				bowDefs[#bowDefs + 1] = t
			end
		end
	end
	local function snapshotBow(def)
		if origBow[def] then return end
		local o = {}
		for _, k in ipairs(BOW_FIELDS) do o[k] = def[k] end
		origBow[def] = o
	end
	local function restoreBow(def)
		local o = origBow[def]; if not o then return end
		for k, v in pairs(o) do pcall(function() def[k] = v end) end
	end
	local function refind()
		defs   = scan({ "recoilPitch", "recoilYaw", "hipSpread" })
		states = scan({ "recoilQueue", "aimSwayCF", "sway" })
		bows   = scan({ "draw", "drawSound" })
	end

	local DEF_FIELDS = {
		"recoilPitch","recoilYaw","recoilMult","kick","kickBack","kickSide","kickTilt",
		"adsKick","adsRecoil","moveRecoil","hipSpread","adsSpread","pelletSpread",
		"bloomMax","bloomPerShot","bloomRecovery","aimSway","auto","rpm",
		"strikeInterval","boltRoll",
	}
	local function snapshot(def)
		if origDef[def] then return end
		local o = {}
		for _, k in ipairs(DEF_FIELDS) do o[k] = def[k] end
		origDef[def] = o
	end
	local function restore(def)
		local o = origDef[def]; if not o then return end
		for k, v in pairs(o) do pcall(function() def[k] = v end) end
		local m = origMover[def]
		if m and type(def.moverInfo) == "table" then
			for k, v in pairs(m) do pcall(function() def.moverInfo[k] = v end) end
			origMover[def] = nil
		end
	end

	refind()
	local lastFind = os.clock()

	bind(RunService.Heartbeat:Connect(function()
		if not wmActive then return end
		-- def/state tables don't change at frame rate; 10 Hz is plenty
		local wmNow = os.clock()
		if wmNow - wmTickAt < 0.1 then return end
		wmTickAt = wmNow
		local noRec   = flags["wm_norecoil"]
		local noSpr   = flags["wm_nospread"]
		local noSway  = flags["wm_nosway"]
		local iAds    = flags["wm_instantads"]
		local autoF   = flags["wm_autofire"]
		local rapid   = flags["wm_rapidfire"]
		local rpmV    = flags["wm_rpm"] or 0
		local iCharge = flags["wm_instantcharge"]
		local fastCycle = flags["wm_fastcycle"]
		local active = noRec or noSpr or noSway or iAds or autoF or rapid or iCharge or fastCycle

		if active then
			-- re-scan for new def/state tables only while a mod is enabled
			local now = os.clock()
			-- filtergc is expensive: only rescan when we have nothing cached,
			-- otherwise let the cached def/state tables do the work.
			if now - lastFind > 5 and (#defs == 0 or #states == 0 or #bows == 0) then
				lastFind = now; pcall(refind)
			end

			-- weapon defs (stats)
			for _, def in ipairs(defs) do
			if type(def) == "table" and rawget(def, "recoilPitch") ~= nil then
				snapshot(def)
				local o = origDef[def]
				pcall(function()
					-- recoil
					if noRec then
						def.recoilPitch = V2Z; def.recoilYaw = V2Z; def.recoilMult = 0
						def.kick = 0; def.kickBack = 0; def.kickSide = 0; def.kickTilt = 0
						def.adsKick = 0; def.adsRecoil = 0; def.moveRecoil = 0
					else
						def.recoilPitch = o.recoilPitch; def.recoilYaw = o.recoilYaw; def.recoilMult = o.recoilMult
						def.kick = o.kick; def.kickBack = o.kickBack; def.kickSide = o.kickSide; def.kickTilt = o.kickTilt
						def.adsKick = o.adsKick; def.adsRecoil = o.adsRecoil; def.moveRecoil = o.moveRecoil
					end
					-- spread
					if noSpr then
						def.hipSpread = 0; def.adsSpread = 0; def.pelletSpread = 0
						def.bloomMax = 0; def.bloomPerShot = 0
					else
						def.hipSpread = o.hipSpread; def.adsSpread = o.adsSpread; def.pelletSpread = o.pelletSpread
						def.bloomMax = o.bloomMax; def.bloomPerShot = o.bloomPerShot
					end
					-- bloom recovery: instant settle so the client cone never widens
					def.bloomRecovery = noSpr and 1e6 or o.bloomRecovery
					-- fast cycle: strip bolt/pump/strike delays from the viewmodel
					if fastCycle then
						def.strikeInterval = 0.001
						def.boltRoll = 0
						if type(def.moverInfo) == "table" then
							if origMover[def] == nil then
								origMover[def] = {
									travel = def.moverInfo.travel, boltAction = def.moverInfo.boltAction,
									boltLoad = def.moverInfo.boltLoad, pumpAction = def.moverInfo.pumpAction,
									slideLock = def.moverInfo.slideLock, rackUnder = def.moverInfo.rackUnder,
								}
							end
							local mi = def.moverInfo
							mi.travel = 0.01; mi.boltAction = false; mi.boltLoad = false
							mi.pumpAction = false; mi.slideLock = false; mi.rackUnder = false
						end
					else
						def.strikeInterval = o.strikeInterval
						def.boltRoll = o.boltRoll
						local m = origMover[def]
						if m and type(def.moverInfo) == "table" then
							for k, v in pairs(m) do def.moverInfo[k] = v end
							origMover[def] = nil
						end
					end
					-- sway
					def.aimSway = noSway and 0 or o.aimSway
					-- auto fire
					def.auto = autoF and true or o.auto
					-- rapid fire
					def.rpm = (rapid and rpmV > 0) and math.max(o.rpm or 0, rpmV) or o.rpm
				end)
			end
		end

			-- weapon state (per-frame kick / sway / ads)
			for _, st in ipairs(states) do
				if type(st) == "table" and rawget(st, "recoilQueue") ~= nil then
					pcall(function()
						if noRec then
							if type(st.recoilQueue) == "table" then table.clear(st.recoilQueue) end
							st.recPos = V3Z; st.recPosVel = V3Z; st.recRot = V3Z; st.recRotVel = V3Z
							if rawget(st, "camKickPitch") ~= nil then st.camKickPitch = 0 end
							if rawget(st, "camKickYaw") ~= nil then st.camKickYaw = 0 end
							if rawget(st, "kickBack") ~= nil then st.kickBack = 0 end
							if rawget(st, "kickPitch") ~= nil then st.kickPitch = 0 end
							if rawget(st, "fovPunch") ~= nil then st.fovPunch = 0 end
						end
						if noSpr and rawget(st, "bloom") ~= nil then st.bloom = 0 end
						if noSway then
							st.sway = V2Z; st.swayVel = V2Z; st.aimSwayCF = CFZ
							if rawget(st, "swaySettle") ~= nil then st.swaySettle = 0 end
						end
						if iAds and st.adsHeld and rawget(st, "ads") ~= nil then st.ads = 1 end
					end)
				end
			end

			-- bow mods: instant draw, no shake/sway, rapid follow-ups
			local bowModNow = iCharge or noRec or noSway or rapid
			if bowModNow then
				local bt = os.clock()
				if #bowDefs == 0 and bt - lastBowFind > 5 then lastBowFind = bt; refindBow() end
				for _, def in ipairs(bowDefs) do
					snapshotBow(def)
					local o = origBow[def]
					pcall(function()
						if iCharge then
							def.DrawTime = 0.01
							if o.HoldMax ~= nil then def.HoldMax = o.HoldMax end -- keep real hold window
						else
							def.DrawTime = o.DrawTime
							if o.HoldMax ~= nil then def.HoldMax = o.HoldMax end
						end
						if noRec then def.ShakeAfter = 1e6 else def.ShakeAfter = o.ShakeAfter end
					end)
				end
				for _, bs in ipairs(bows) do
					if type(bs) == "table" then
						pcall(function()
							-- do NOT force bs.draw = 1: the game's fire gate needs a real draw transition
							if (noRec or noSway) and rawget(bs, "shake") ~= nil then bs.shake = 0 end
							if rapid and rawget(bs, "shotAt") ~= nil then bs.shotAt = 0 end
						end)
					end
				end
			end
		else
			-- idle: nothing enabled — restore once, then stop touching the tables
			if next(origDef) then
				for def in pairs(origDef) do pcall(restore, def) end
			end
			if next(origBow) then
				for def in pairs(origBow) do pcall(restoreBow, def) end
			end
		end

		-- range override (attribute-based, unchanged)
		local char = lp.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if tool then
			if flags["wm_range"] then
				if rangeOrig[tool] == nil then rangeOrig[tool] = tool:GetAttribute("Range") or false end
				if tool:GetAttribute("Range") ~= nil then pcall(function() tool:SetAttribute("Range", 100000) end) end
			else
				local ro = rangeOrig[tool]
				if ro ~= nil then if ro then pcall(function() tool:SetAttribute("Range", ro) end) end; rangeOrig[tool] = nil end
			end
		end
	end))

	-- unload: stop and restore every def we touched
	bind({ Disconnect = function()
		wmActive = false
		for def in pairs(origDef) do pcall(restore, def) end
		for def in pairs(origBow) do pcall(restoreBow, def) end
	end })
end

-- ================================================================
-- // KI v2.1 FEATURES (ported): kill aura / autofarm nodes / hitsounds /
-- //   trajectory arc / gun packet hook (packet no spread)
-- //   Everything reads library flags directly; connections + drawings ride
-- //   bind() so the top-level unload tears them all down.
-- ================================================================
do
	local featureConns = {}

	-- ——— KILL AURA ———
	-- Auto-swings the held melee tool at the nearest player/NPC in reach.
	-- Claims are the same Swing packet a manual hit sends (flesh=true); the
	-- server grades every claim, so cadence = tool SwingTime / speed slider.
	local kaLastAt, kaTickAt = 0, 0
	OVX.kaSwings = OVX.kaSwings or 0
	bind(RunService.Heartbeat:Connect(function()
		if not flags["ka_enabled"] then return end
		local kaNow = os.clock()
		if kaNow - kaTickAt < 0.1 then return end
		kaTickAt = kaNow
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) then return end
		local tool = OVX.meleeTool()
		if not tool then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local swingTime = tonumber(tool:GetAttribute("SwingTime")) or 0.9
		-- server keeps the original SwingTime; don't spam past its cooldown
		local cadence = math.max(swingTime, 0.85)
		local interval = math.clamp(cadence / math.max((tonumber(flags["ka_speed"]) or 10) / 10, 0.1), 0.2, math.huge)
		local reach = tonumber(tool:GetAttribute("Reach")) or 9
		local maxRange = math.min(tonumber(flags["ka_range"]) or 8, reach + 2.5)
		local now = os.clock()
		if now - kaLastAt < interval then return end
		local best, bestD = nil, huge
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= lp then
				local rel = OVX.relation(plr)
				local skip = flags["ka_team_check"] ~= false and (rel == "team" or rel == "ally")
				if not skip then
					local c = plr.Character
					local h2 = c and c:FindFirstChildOfClass("Humanoid")
					local r2 = c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
					if h2 and r2 and h2.Health > 0 and not c:GetAttribute("Downed") then
						local d = (r2.Position - root.Position).Magnitude
						if d <= maxRange and d < bestD then best, bestD = r2, d end
					end
				end
			end
		end
		if flags["ka_npc"] ~= false then
			for _, fname in ipairs({ "Sleepers", "Scientists", "Animals" }) do
				local folder = Workspace:FindFirstChild(fname)
				if folder then
					for _, mdl in ipairs(folder:GetDescendants()) do
						if mdl:IsA("Model") and mdl.Parent then
							local h2 = mdl:FindFirstChildOfClass("Humanoid")
							if h2 and h2.Health > 0 and not mdl:GetAttribute("Downed") then
								local p2 = mdl:FindFirstChild("HumanoidRootPart") or mdl.PrimaryPart or mdl:FindFirstChild("Head")
								if p2 then
									local d = (p2.Position - root.Position).Magnitude
									if d <= maxRange and d < bestD then best, bestD = p2, d end
								end
							end
						end
					end
				end
			end
			local gr = Workspace:FindFirstChild("GunRange")
			local dum = gr and gr:FindFirstChild("Dummies")
			if dum then
				for _, mdl in ipairs(dum:GetChildren()) do
					local h2 = mdl and mdl:FindFirstChildOfClass("Humanoid")
					if h2 and h2.Health > 0 then
						local p2 = mdl:FindFirstChild("HumanoidRootPart") or mdl.PrimaryPart or mdl:FindFirstChild("Head")
						if p2 then
							local d = (p2.Position - root.Position).Magnitude
							if d <= maxRange and d < bestD then best, bestD = p2, d end
						end
					end
				end
			end
		end
		if best and OVX.swingClaimFlesh(best) then
			kaLastAt = now
			OVX.kaSwings = OVX.kaSwings + 1
		end
	end))

	-- ——— AUTO FARM NODES (cheap overlap-query scan) ———
	-- No big Lua loops, no cached 8000-node tables. One engine overlap query
	-- finds nearby harvest parts; ChopMark weakspot nodes are checked first.
	local afCS = game:GetService("CollectionService")
	local AF_NODE_NAMES = {
		Tree = "Trees", StoneRock = "Stone", MetalOre = "Metal", SulfurOre = "Sulfur",
		Boulder = "Boulders", Hemp = "Hemp",
	}
	local AF_INSTANT_TIME = 0.3
	local afLastAt, afScanAt, afEquipAt, afTickAt = 0, 0, 0, 0
	local afTarget = nil
	local afOrigSwing = setmetatable({}, { __mode = "k" })
	local afOverlap = OverlapParams.new()
	afOverlap.FilterType = Enum.RaycastFilterType.Exclude
	OVX.afSwings = OVX.afSwings or 0
	OVX.afTarget = nil
	OVX.afClaims = OVX.afClaims or 0
	OVX.afHitMarkers = OVX.afHitMarkers or 0
	OVX.afGained = OVX.afGained or 0
	-- count server confirmations so we can tell rejected claims from real ones
	local afGr = RepStorage:FindFirstChild("GatheringRemotes")
	if afGr then
		local hm = afGr:FindFirstChild("HitMarker")
		if hm and hm:IsA("RemoteEvent") then
			bind(hm.OnClientEvent:Connect(function() OVX.afHitMarkers = OVX.afHitMarkers + 1 end))
		end
		local gn = afGr:FindFirstChild("Gained")
		if gn and gn:IsA("RemoteEvent") then
			bind(gn.OnClientEvent:Connect(function() OVX.afGained = OVX.afGained + 1 end))
		end
	end
	task.defer(function()
		local fn = library.config_flags and library.config_flags["af_nodes"]
		local all = { "Trees", "Stone", "Metal", "Sulfur", "Boulders", "Hemp", "Crops" }
		if fn then pcall(fn, all) else flags["af_nodes"] = all end
		local ff = library.config_flags and library.config_flags["af_filter"]
		if ff then pcall(ff, "All") else flags["af_filter"] = "All" end
	end)
	local function afFilter()
		local f = flags["af_filter"]
		if type(f) == "string" and f ~= "" then return f end
		return "All"
	end
	local function nodeMatchesFilter(kind, filter)
		if not filter or filter == "All" then return true end
		if filter == "Ore" then return kind == "Stone" or kind == "Metal" or kind == "Sulfur" end
		return kind == filter
	end
	local function afKindOf(node)
		return AF_NODE_NAMES[node.Name] or "Crops"
	end
	local function isMeleeTool(t)
		return t and t:IsA("Tool") and tonumber(t:GetAttribute("SwingTime")) ~= nil
	end
	local function preferredToolName(kind)
		if kind == "Trees" or kind == "Crops" or kind == "Hemp" then return "Hatchet" end
		return "Pickaxe"
	end
	local function ensureMelee(kind)
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return nil end
		local tool = char:FindFirstChildOfClass("Tool")
		local want = kind and preferredToolName(kind) or nil
		if isMeleeTool(tool) and (not want or string.find(tool.Name, want, 1, true)) then return tool end
		if flags["af_autoequip"] == false then return isMeleeTool(tool) and tool or nil end
		local now = os.clock()
		if now - afEquipAt < 0.8 then return isMeleeTool(tool) and tool or nil end
		afEquipAt = now
		local bp = lp:FindFirstChild("Backpack")
		if not bp then return isMeleeTool(tool) and tool or nil end
		local chosen = want and bp:FindFirstChild(want) or nil
		if not isMeleeTool(chosen) then
			for _, t in ipairs(bp:GetChildren()) do
				if isMeleeTool(t) then chosen = t; break end
			end
		end
		if isMeleeTool(chosen) then
			pcall(function() hum:EquipTool(chosen) end)
			return char:FindFirstChildOfClass("Tool") or chosen
		end
		return isMeleeTool(tool) and tool or nil
	end
	local function applyInstantSwing(tool)
		if not flags["af_instant"] or not tool then return end
		local st = tonumber(tool:GetAttribute("SwingTime"))
		if not st then return end
		if afOrigSwing[tool] == nil and st > AF_INSTANT_TIME then afOrigSwing[tool] = st end
		if st > AF_INSTANT_TIME then
			pcall(function() tool:SetAttribute("SwingTime", AF_INSTANT_TIME) end)
		end
	end
	local function findTarget(maxRange, filter)
		local char = lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return nil end
		local rp = root.Position
		local best, bestD2 = nil, huge
		-- 1) active weakspots (only a handful exist at a time)
		for _, node in ipairs(afCS:GetTagged("ChopMark")) do
			if node.Parent and not node:GetAttribute("Felled") then
				local mark = OVX.markValid(node)
				if mark and nodeMatchesFilter(afKindOf(node), filter) then
					local d2 = (mark.Position - rp).Magnitude
					if d2 <= maxRange and d2 < bestD2 then best, bestD2 = node, d2 end
				end
			end
		end
		if best then return best end
		-- 2) one engine-side overlap query instead of scanning every node
		afOverlap.FilterDescendantsInstances = { char, workspace.CurrentCamera }
		local ok, parts = pcall(function()
			return workspace:GetPartBoundsInRadius(rp, maxRange, afOverlap)
		end)
		if not ok or type(parts) ~= "table" then return nil end
		for i = 1, #parts do
			local part = parts[i]
			local model = part:FindFirstAncestorOfClass("Model") or part.Parent
			if model and model.Parent and AF_NODE_NAMES[model.Name]
				and not model:GetAttribute("Felled")
				and nodeMatchesFilter(afKindOf(model), filter) then
				local d2 = (part.Position - rp).Magnitude
				if d2 <= maxRange and d2 < bestD2 then best, bestD2 = model, d2 end
			end
		end
		return best
	end
	bind(RunService.Heartbeat:Connect(function()
		if not flags["af_enabled"] then return end
		-- swing cadence is ~1/s; 10 Hz is plenty and avoids per-frame API cost
		local now = os.clock()
		if now - afTickAt < 0.1 then return end
		afTickAt = now
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) or char:GetAttribute("Downed") then return end
		local wantedRange = tonumber(flags["af_range"]) or 12
		if now - afScanAt > 0.25 or not (afTarget and afTarget.Parent) then
			afScanAt = now
			afTarget = findTarget(wantedRange + 2, afFilter())
			OVX.afTarget = afTarget
			OVX.afTargetMarked = afTarget and afTarget:GetAttribute("MarkCF") ~= nil or false
		end
		local target = afTarget
		if not target then return end
		local tool = ensureMelee(afKindOf(target))
		if not tool then return end
		applyInstantSwing(tool)
		local reach = tonumber(tool:GetAttribute("Reach")) or 9
		local maxRange = math.min(wantedRange, reach + 1.5)
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local okP, pos = pcall(function() return target:GetPivot().Position end)
		if not okP or (pos - root.Position).Magnitude > maxRange then
			afTarget = nil
			OVX.afTarget = nil
			OVX.afTargetMarked = false
			return
		end
		local swingTime = tonumber(tool:GetAttribute("SwingTime")) or 0.9
		-- client SetAttribute does NOT replicate: the server still grades claims
		-- against the ORIGINAL SwingTime, so cadence must use the snapshot.
		local cadenceBase = afOrigSwing[tool] or math.max(swingTime, 0.85)
		local interval = math.clamp(cadenceBase / math.max((tonumber(flags["af_speed"]) or 10) / 10, 0.1), 0.2, math.huge)
		if now - afLastAt < interval then return end
		if OVX.swingNodeClaim(target) then
			afLastAt = now
			OVX.afSwings = OVX.afSwings + 1
		end
	end))
	bind({ Disconnect = function()
		for t, v in pairs(afOrigSwing) do
			pcall(function() t:SetAttribute("SwingTime", v) end)
		end
		table.clear(afOrigSwing)
		afTarget = nil
		OVX.afTarget = nil
	end })

	-- ——— HITSOUNDS ———
	-- Downloads .mp3 assets once, caches them via getcustomasset, plays on the
	-- server's HitMarker confirmations for all three weapon families.
	local hitsound = {
		loaded = false, loading = false, assets = {},
		names = {
			"Amongus", "Ara", "Cod", "Coin", "Csgo", "Fatality", "Gamesense", "Landing",
			"Neverlose", "Noname", "Parry", "Rifk7", "Rust", "Snap", "Uwu",
		},
	}
	task.spawn(function()
		if hitsound.loading then return end
		hitsound.loading = true
		local baseUrl = "https://raw.githubusercontent.com/crisnigh7-wq/test1234/main/hitsounds/"
		local dir = "vault_hitsounds"
		pcall(function()
			if type(isfolder) == "function" and not isfolder(dir) then makefolder(dir) end
		end)
		local loaded = 0
		for _, name in ipairs(hitsound.names) do
			local filePath = dir .. "/" .. name:lower() .. ".mp3"
			local ok, asset = pcall(function()
				if type(isfile) == "function" and not isfile(filePath) then
					local data = game:HttpGet(baseUrl .. name:lower() .. ".mp3")
					if data and #data > 0 then writefile(filePath, data) end
					task.wait(0.1)
				end
				return getcustomasset(filePath)
			end)
			if ok and asset then
				hitsound.assets[name] = asset
				loaded += 1
			end
		end
		hitsound.loaded = true
		hitsound.loading = false
		print("[OVX] hitsounds loaded: " .. loaded .. "/" .. #hitsound.names)
	end)
	local function playHitsound(category)
		if not hitsound.loaded then return end
		if flags["hs_" .. category .. "_enabled"] ~= true then return end
		local asset = hitsound.assets[flags["hs_" .. category .. "_sound"]]
		if not asset then return end
		pcall(function()
			local snd = Instance.new("Sound")
			snd.SoundId = asset
			snd.Volume = (tonumber(flags["hs_" .. category .. "_volume"]) or 10) / 10
			snd.PlaybackSpeed = (tonumber(flags["hs_" .. category .. "_pitch"]) or 10) / 10
			snd.Parent = workspace.CurrentCamera
			snd:Play()
			snd.Ended:Once(function() snd:Destroy() end)
		end)
	end
	OVX.hsPreview = function(soundName, volume, pitch)
		if not hitsound.loaded then return end
		local asset = hitsound.assets[soundName]
		if not asset then return end
		pcall(function()
			local snd = Instance.new("Sound")
			snd.SoundId = asset
			snd.Volume = tonumber(volume) or 1
			snd.PlaybackSpeed = tonumber(pitch) or 1
			snd.Parent = workspace.CurrentCamera
			snd:Play()
			snd.Ended:Once(function() snd:Destroy() end)
		end)
	end
	-- HitMarker triggers: all three families send a STRING zone ("head"/"body")
	-- — the decomp shows the client ignores anything else
	local killWindowUntil = 0
	task.spawn(function()
		for _ = 1, 30 do
			local ready = true
			for _, fname in ipairs({ "GatheringRemotes", "BowRemotes", "FirearmsRemotes" }) do
				local f = RepStorage:FindFirstChild(fname)
				if not (f and f:FindFirstChild("HitMarker")) then ready = false break end
			end
			if ready then break end
			task.wait(1)
		end
		for _, fname in ipairs({ "GatheringRemotes", "BowRemotes", "FirearmsRemotes" }) do
			local f = RepStorage:FindFirstChild(fname)
			local r = f and f:FindFirstChild("HitMarker")
			if r and r:IsA("RemoteEvent") then
				table.insert(featureConns, r.OnClientEvent:Connect(function(a1)
					-- SA diagnostic: a HitMarker means the server ACCEPTED a claim
					OVX.saHitMarkerAt = os.clock()
					if typeof(a1) == "string" then
						playHitsound(a1 == "head" and "head" or "body")
						-- a confirmed hit arms the kill window: if the locked
						-- target dies inside it, the kill sound plays
						killWindowUntil = os.clock() + 1.5
					else
						playHitsound("body")
					end
				end))
			end
		end
		print("[OVX] hitsound triggers on (HitMarker x3 families)")
	end)
	-- kill watch: rebinds Humanoid.Died onto whatever the silent aim is locked
	-- on; a death inside the armed window = the shot killed it
	local killWatchModel, killWatchConn = nil, nil
	table.insert(featureConns, RunService.Heartbeat:Connect(function()
		local tgt = OVX.saTarget
		local m = tgt and tgt.model
		if m == killWatchModel then return end
		killWatchModel = m
		if killWatchConn then pcall(function() killWatchConn:Disconnect() end) killWatchConn = nil end
		if not (typeof(m) == "Instance" and m.Parent) then return end
		local hum = m:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		killWatchConn = hum.Died:Connect(function()
			if os.clock() < killWindowUntil then playHitsound("kill") end
		end)
	end))

	-- ——— TRAJECTORY ARC ———
	-- Draws the silent-aim shot's arc with the SAME ballistic solve the SA
	-- commit uses, marched with the server's sim p = p0 + v0*t - 0.5*g*t^2.
	-- Green impact marker = lands on target, red = miss.
	local ARC_SEGS = 28
	local arcSegs = {}
	for i = 1, ARC_SEGS do
		local l = Drawingnew("Line")
		l.Thickness = 2
		l.Transparency = 0.75
		l.Visible = false
		arcSegs[i] = l
	end
	local arcImpact = Drawingnew("Circle")
	arcImpact.Thickness = 2
	arcImpact.NumSides = 12
	arcImpact.Radius = 6
	arcImpact.Filled = false
	arcImpact.Visible = false
	local ARC_ON = c3(0, 255, 0)
	local ARC_MISS = c3(255, 0, 0)
	local function arcHide()
		for i = 1, ARC_SEGS do arcSegs[i].Visible = false end
		arcImpact.Visible = false
	end
	local function shotPhysics()
		local char = lp.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if not tool then return nil, nil end
		local speed = tonumber(tool:GetAttribute("BulletSpeed"))
		local g = tonumber(tool:GetAttribute("BulletGravity"))
		if speed then return speed, g or 35 end
		-- bow: use the live arrow speed captured from BowRemotes.Flight
		if tool:FindFirstChild("BowClient") or tool:GetAttribute("NockTime") then
			return OVX.arrowSpeed or 80, OVX.arrowGravity or 18
		end
		return nil, nil -- melee/hands: nothing to preview
	end
	bind(RunService.RenderStepped:Connect(function()
		if not flags["traj_arc"] then arcHide() return end
		local tgt = OVX.saTarget
		local cam = Workspace.CurrentCamera
		if not (tgt and tgt.model and tgt.model.Parent and cam and tgt.part and tgt.part.Parent) then arcHide() return end
		local speed, g = shotPhysics()
		if not speed then arcHide() return end
		local base = cam.CFrame.Position
		local part = tgt.part
		local vel = part.AssemblyLinearVelocity or v3new(0, 0, 0)
		local aim = part.Position
		for _ = 1, 3 do
			local t = (aim - base).Magnitude / math.max(speed, 1)
			aim = part.Position + vel * t
		end
		-- low-arc ballistic solve
		local disp = aim - base
		local flat = v3new(disp.X, 0, disp.Z)
		local dir
		if flat.Magnitude < 2 or (g or 0) <= 0 then
			dir = disp.Magnitude > 0.1 and disp.Unit or nil
		else
			local d = flat.Magnitude
			local s2 = speed * speed
			local disc = s2 * s2 - g * (g * d * d + 2 * disp.Y * s2)
			if disc < 0 then
				dir = disp.Unit
			else
				local theta = math.atan2(s2 - math.sqrt(disc), g * d)
				local h = flat / d
				dir = v3new(h.X * math.cos(theta), math.sin(theta), h.Z * math.cos(theta))
			end
		end
		if not dir then arcHide() return end
		local v0 = dir * speed
		local step_dt = 1 / 30
		local pts = { base + dir * 0.5 }
		local prevD = (aim - pts[1]).Magnitude
		for step = 1, 90 do
			local t = step * step_dt
			if t > 3 then break end
			local np = base + v0 * t - v3new(0, 0.5 * g * t * t, 0)
			local nd = (aim - np).Magnitude
			pts[#pts + 1] = np
			if nd < 1 then break end
			if step > 3 and nd > prevD + 0.5 then break end
			prevD = nd
		end
		local impact = pts[#pts]
		local col = (impact - aim).Magnitude < 4 and ARC_ON or ARC_MISS
		local n = #pts
		local stride = math.max(1, floor((n - 1) / ARC_SEGS))
		local seg, lastPt = 0, nil
		local i = 1
		while i <= n and seg < ARC_SEGS do
			local sp = cam:WorldToViewportPoint(pts[i])
			if sp.Z > 0 then
				local cur = v2new(sp.X, sp.Y)
				if lastPt then
					seg += 1
					local line = arcSegs[seg]
					line.From = lastPt
					line.To = cur
					line.Color = col
					line.Visible = true
				end
				lastPt = cur
			else
				lastPt = nil
			end
			i += stride
		end
		for j = seg + 1, ARC_SEGS do arcSegs[j].Visible = false end
		local ip = cam:WorldToViewportPoint(impact)
		if ip.Z > 0 then
			arcImpact.Position = v2new(ip.X, ip.Y)
			arcImpact.Color = col
			arcImpact.Visible = true
		else
			arcImpact.Visible = false
		end
	end))
	bind({ Disconnect = function()
		for i = 1, ARC_SEGS do pcall(function() arcSegs[i]:Remove() end) end
		pcall(function() arcImpact:Remove() end)
	end })

	-- ——— GUN PACKET HOOK ———
	-- Separate hook on FirearmsRemotes.Fire.FireServer (a DIFFERENT closure
	-- from the SA namecall hook — never stacked). Packet no spread: recenters
	-- the packet direction on the held view (skipped while Silent Aim is
	-- redirecting).
	local pktHooked, pktOrig = nil, nil
	local genvPkt = getgenv().__ovxPkt
	if not genvPkt then genvPkt = {}; getgenv().__ovxPkt = genvPkt end
	local function heldViewBase()
		local cam = Workspace.CurrentCamera
		if not cam then return nil end
		local base = cam.CFrame
		pcall(function()
			local sh = getrenv and getrenv().shared
			if sh and type(sh.HeldViewCFrame) == "function" then
				local ok, r = pcall(sh.HeldViewCFrame, base)
				if ok and typeof(r) == "CFrame" then base = r end
			end
		end)
		return base
	end
	local function pktBody(self, origin, dir, ...)
		if typeof(origin) ~= "Vector3" then return pktOrig(self, origin, dir, ...) end
		local rest = { ... }
		-- Fire(origin, direction, seedNo, claim{ id, t }): after self/origin/dir,
		-- rest[1] = seedNo and rest[2] = the claim table
		-- packet no spread: recenter the direction on the held view; skipped
		-- when Silent Aim just rewrote it (SA wins)
		if flags["pkt_nospread"] and typeof(dir) == "Vector3"
			and not (OVX.saRedirectAt and os.clock() - OVX.saRedirectAt < 0.5) then
			local base = heldViewBase()
			if base then
				return pktOrig(self, origin, base.LookVector, unpack(rest, 1, 2))
			end
		end
		return pktOrig(self, origin, dir, unpack(rest, 1, math.max(#rest, 0)))
	end
	local function pktUnhook()
		if pktHooked and pktOrig then
			if type(restorefunction) == "function" then
				pcall(restorefunction, pktOrig, pktHooked)
			end
			pktHooked, pktOrig = nil, nil
			genvPkt.hooked, genvPkt.orig = nil, nil
		end
	end
	local function pktHook()
		if pktHooked and pktOrig then return true end
		if type(hookfunction) ~= "function" or type(newcclosure) ~= "function" then return false end
		local fr = RepStorage:FindFirstChild("FirearmsRemotes")
		local remote = fr and fr:FindFirstChild("Fire")
		local target = remote and remote.FireServer
		if type(target) ~= "function" then return false end
		if genvPkt.hooked == target and genvPkt.orig then
			-- previous session's hook is still live on this closure: adopt it
			pktOrig = genvPkt.orig
			pktHooked = target
			return true
		end
		local okH, orig = pcall(hookfunction, target, newcclosure(pktBody, "OVXPkt"))
		if okH and type(orig) == "function" then
			pktOrig = orig
			pktHooked = target
			genvPkt.hooked, genvPkt.orig = target, orig
			print("[OVX] gun packet hook on Firearms.Fire (no spread)")
			return true
		end
		return false
	end
	bind({ Disconnect = pktUnhook })
	task.spawn(function()
		for _ = 1, 20 do
			if pktHook() then return end
			task.wait(0.5)
		end
		if not (pktHooked and pktOrig) then
			print("[OVX] gun packet hook: FirearmsRemotes never replicated")
		end
	end)

	-- consolidated teardown for the featureConns family
	bind({ Disconnect = function()
		for _, c in ipairs(featureConns) do pcall(function() c:Disconnect() end) end
		table.clear(featureConns)
	end })
end

-- ================================================================
-- // DESYNC (v2.1 port): fake body to the server, real body stays local
-- //   The server's snapshot of you carries the offset/rotation (Heartbeat
-- //   writes it after physics), while a First-priority RenderStep puts the
-- //   REAL cframe back before the next physics step. Camera, aim, mining and
-- //   movement all run on the real body, so shooting and gathering work
-- //   exactly as they do with desync off.
-- ================================================================
do
	local dsRealCF, dsRealVel, dsRealAng = nil, nil, nil
	local dsSpoofed, dsVelSpoofed = false, false
	local dsDummy, dsAnimTrack, dsAnimChar = nil, nil, nil

	local function dsParts()
		local c = lp.Character
		return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	end
	local function dsClearDummy()
		if dsDummy then pcall(function() dsDummy:Destroy() end) dsDummy = nil end
	end
	local function dsSetupDummy()
		dsClearDummy()
		local c = lp.Character
		if not c then return end
		local okC, clone = pcall(function()
			c.Archivable = true
			local cl = c:Clone()
			c.Archivable = false
			return cl
		end)
		if not (okC and clone) then return end
		clone.Name = "DesyncCharVis"
		local dHum = clone:FindFirstChildOfClass("Humanoid")
		if dHum then
			pcall(function() dHum.PlatformStand = true end)
			pcall(function() dHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
			for _, st in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
				pcall(function() dHum:SetStateEnabled(st, false) end)
			end
		end
		for _, v in ipairs(clone:GetDescendants()) do
			if v:IsA("Script") or v:IsA("LocalScript") then
				v:Destroy()
			elseif v:IsA("BasePart") then
				v.CanCollide = false
				v.CanTouch = false
				v.CanQuery = false
				v.Massless = true
				v.Material = Enum.Material.ForceField
				v.Color = c3(150, 0, 255)
				v.Transparency = (v.Name == "HumanoidRootPart") and 1 or 0.2
			elseif v:IsA("Decal") or v:IsA("Texture") then
				v:Destroy()
			end
		end
		local dHrp = clone:FindFirstChild("HumanoidRootPart")
		if dHrp then dHrp.Anchored = true end
		clone.Parent = Workspace.CurrentCamera
		dsDummy = clone
	end
	local function dsFakeCF(hrp)
		local fake = hrp.CFrame
		if flags["ds_pos"] ~= false then
			fake = fake + v3new(tonumber(flags["ds_ox"]) or 0, tonumber(flags["ds_oy"]) or -2.4, tonumber(flags["ds_oz"]) or 0)
		end
		if flags["ds_rot"] ~= false then
			fake = fake * CFrame.Angles(math.rad(tonumber(flags["ds_rx"]) or 90), math.rad(tonumber(flags["ds_ry"]) or 0), math.rad(tonumber(flags["ds_rz"]) or 0))
		end
		return fake
	end
	local function dsAnim(on, char)
		if dsAnimTrack then
			pcall(function() dsAnimTrack:Stop() end)
			pcall(function() dsAnimTrack:Destroy() end)
			dsAnimTrack, dsAnimChar = nil, nil
		end
		if not on then return end
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if not animator then return end
		pcall(function()
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://616119360"
			dsAnimTrack = animator:LoadAnimation(anim)
			dsAnimTrack.Priority = Enum.AnimationPriority.Action4
			dsAnimTrack.Looped = true
			dsAnimTrack:Play()
			dsAnimChar = char
			if flags["ds_animfreeze"] then dsAnimTrack:AdjustSpeed(0) end
		end)
	end

	-- gun-peek desync: while set, the spoof carries the SERVER copy of the
	-- character to the gun-peek spot (driven by the SA block) — independent
	-- of ds_enabled, and the ds_pos/ds_rot presets are bypassed while peeking
	local dsPeekCF = nil
	function OVX.desyncPeekSet(cf) dsPeekCF = cf end
	function OVX.desyncPeekClear() dsPeekCF = nil end

	bind(RunService.Heartbeat:Connect(function()
		local char, hrp, hum = dsParts()
		local canSpoof = (dsPeekCF ~= nil or (flags["ds_enabled"]
			and (flags["ds_pos"] ~= false or flags["ds_rot"] ~= false)))
			and hrp and hum and hum.Health > 0 and not hum.SeatPart
			and not (char and char:GetAttribute("Downed"))
		if canSpoof then
			dsRealCF = hrp.CFrame
			dsRealVel = hrp.AssemblyLinearVelocity
			dsRealAng = hrp.AssemblyAngularVelocity
			hrp.CFrame = dsPeekCF or dsFakeCF(hrp)
			dsSpoofed = true
			-- optional velocity poison (rubberbandy — OFF by default; never
			-- while gun-peek desync is holding the server copy in place)
			if flags["ds_velocity"] and not dsPeekCF then
				local vt = flags["ds_veltype"] or "low"
				local sv
				if vt == "high y" then
					sv = v3new(0, 16384, 0)
				elseif vt == "limit" then
					sv = v3new(math.random(-2147483648, 2147483647),
						math.random(-2147483648, 2147483647), math.random(-2147483648, 2147483647))
				elseif vt == "high" then
					sv = v3new(math.random(1, 2) == 1 and -16384 or 16384,
						math.random(1, 2) == 1 and -14384 or 16384, math.random(1, 2) == 1 and -16384 or 16384)
				else
					sv = v3new(math.random(1, 2) == 1 and -300 or 300,
						math.random(1, 2) == 1 and -300 or 300, math.random(1, 2) == 1 and -300 or 300)
				end
				hrp.AssemblyLinearVelocity = sv
				dsVelSpoofed = true
			end
		else
			dsSpoofed = false
		end
	end))

	local function dsRender()
		local char, hrp = dsParts()
		-- restore the REAL body before the character controller runs: the
		-- server already got the fake snapshot, local physics never sees it
		if dsSpoofed and hrp and dsRealCF then
			hrp.CFrame = dsRealCF
			hrp.AssemblyLinearVelocity = dsRealVel or hrp.AssemblyLinearVelocity
			if dsVelSpoofed then
				hrp.AssemblyAngularVelocity = dsRealAng or hrp.AssemblyAngularVelocity
				dsVelSpoofed = false
			end
			dsSpoofed = false
		end
		-- dummy visualizer: lazily (re)built — the camera is recreated on respawn
		if flags["ds_enabled"] and flags["ds_vis"] then
			local cam = Workspace.CurrentCamera
			if not dsDummy or not cam or dsDummy.Parent ~= cam then dsSetupDummy() end
			if dsDummy and char and hrp then
				local dHrp = dsDummy:FindFirstChild("HumanoidRootPart")
				if dHrp then dHrp.CFrame = dsFakeCF(hrp) end
				for _, motor in ipairs(char:GetDescendants()) do
					if motor:IsA("Motor6D") then
						local dm = dsDummy and dsDummy:FindFirstChild(motor.Name, true)
						if dm and dm:IsA("Motor6D") then dm.Transform = motor.Transform end
					end
				end
			end
		elseif dsDummy then
			dsClearDummy()
		end
		-- fake anim: lazy start/stop, restarts after respawn (tracks die with the rig)
		if flags["ds_enabled"] and flags["ds_anim"] and char and char ~= dsAnimChar then
			dsAnim(true, char)
		elseif not (flags["ds_enabled"] and flags["ds_anim"]) and dsAnimTrack then
			dsAnim(false)
		end
		if flags["ds_enabled"] and flags["ds_anim"] and dsAnimTrack and flags["ds_animfreeze"] then
			pcall(function() dsAnimTrack.TimePosition = 0 end)
		end
	end
	pcall(function() RunService:UnbindFromRenderStep("OVXDesync") end)
	RunService:BindToRenderStep("OVXDesync", Enum.RenderPriority.First.Value, dsRender)

	-- presets: tuned so the fake body stays shallow enough to never fight the
	-- server's floor checks (no rubberband) while still hiding the real hitbox
	function OVX.desyncPreset(name)
		local function setF(f, v)
			local fn = library.config_flags and library.config_flags[f]
			if fn then pcall(fn, v) else flags[f] = v end
		end
		if name == "Deep underground" then
			setF("ds_oy", -5); setF("ds_rx", 90)
		elseif name == "Rotation only (stealth)" then
			setF("ds_oy", 0); setF("ds_rx", 90)
		else -- "Semi-underground (best)"
			setF("ds_oy", -2.4); setF("ds_rx", 90)
		end
	end

	bind({ Disconnect = function()
		pcall(function() RunService:UnbindFromRenderStep("OVXDesync") end)
		dsAnim(false)
		dsClearDummy()
		local _, hrp = dsParts()
		if hrp and dsRealCF then pcall(function() hrp.CFrame = dsRealCF end) end
	end })
end

-- ================================================================
-- // MISC — SPEED / PHASE / SPIDER / FREECAM  (ported from vape v4)
-- //   Logic copied 1:1 from vape v4 and adapted only where vape used
-- //   its own libraries: entitylib -> direct character access, vape
-- //   options -> library flags. Speed module = Velocity method with
-- //   MoveDirection/Direct move modes + Custom Properties friction.
-- //   Phase = full method set (Part/Character/CFrame/Motor/FFlag).
-- //   Spider = Velocity/Impulse/CFrame/Part modes. Freecam = Classic
-- //   (camera-controller hook) + Roblox (FreeCamera module) modes.
-- ================================================================
local setSpeed, setPhase, setSpider, setFreecam, spiderTruss, guideGui  -- assigned below, used by the UI
do
	local function getChar()
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
		if char and hum and hum.Health > 0 and root then
			return true, char, hum, root
		end
		return false, char, hum, root
	end

	-- vape: motorMove / calculateMoveVector (1:1)
	local function motorMove(target, cf)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Parent = workspace
		local motor = Instance.new("Motor6D")
		motor.Part0 = target
		motor.Part1 = part
		motor.C1 = cf
		motor.Parent = part
		task.delay(0, part.Destroy, part)
	end

	local function calculateMoveVector(vec)
		local c, s
		local camera = Workspace.CurrentCamera
		local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = camera.CFrame:GetComponents()
		if R12 < 1 and R12 > -1 then
			c = R22
			s = R02
		else
			c = R00
			s = -R01 * math.sign(R12)
		end
		vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
		return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
	end

	-- vape: frictionTable / updateVelocity (Custom Properties) (1:1)
	local frictionTable, oldfrict = {}, {}
	local function getTableSize(t)
		local n = 0
		for _ in pairs(t) do n += 1 end
		return n
	end
	local function updateVelocity()
		local alive, char = getChar()
		if getTableSize(frictionTable) > 0 then
			if alive then
				for _, part in ipairs(char:GetChildren()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not oldfrict[part] then
						oldfrict[part] = part.CustomPhysicalProperties or "none"
						part.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
					end
				end
			end
		else
			for part, data in pairs(oldfrict) do
				pcall(function() part.CustomPhysicalProperties = data ~= "none" and data or nil end)
			end
			table.clear(oldfrict)
		end
	end

	-- vape: SpeedMethods (1:1; v4's method list only exposes Velocity)
	local function speedVelocity(value, moveDirection)
		local _, _, _, root = getChar()
		root.AssemblyLinearVelocity = (moveDirection * value) + v3new(0, root.AssemblyLinearVelocity.Y, 0)
	end

	-- shared params
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local overlapCheck = OverlapParams.new()
	local modified = {}
	local fflag = nil
	local teleported = false
	local spiderShift = false
	local active = false  -- spider ray state (vape: Active)
	local truss = nil     -- spider Part mode (vape: Truss)

	local function setFFlag(name, val)
		local f = setfflag or setfastflag
		if type(f) == "function" then pcall(f, name, val) end
	end

	local function grabClosestNormal(ray)
		local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top
		for _, normal in Enum.NormalId:GetEnumItems() do
			local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(ray.Normal)
			if dot > mag then
				mag, closest = dot, normal
			end
		end
		return Vector3.fromNormalId(closest).X ~= 0 and "X" or "Z"
	end

	local function phaseRestore()
		if fflag then
			setFFlag("AssemblyExtentsExpansionStudHundredth", "30")
			fflag = nil
		end
		for part in pairs(modified) do
			pcall(function() part.CanCollide = true end)
		end
		table.clear(modified)
	end

	-- ——— PHASE (vape 1:1: Part / Character / CFrame / Motor / FFlag) ———
	local phaseConn, phaseTpConn = nil, nil
	local function phaseStep(mode)
		local alive, char, hum, root = getChar()
		if not alive then return end
		if mode == "Part" then
			local camera = Workspace.CurrentCamera
			overlapCheck.FilterDescendantsInstances = { camera, char }
			local parts = Workspace:GetPartBoundsInBox(root.CFrame + v3new(0, 1, 0), root.Size + v3new(7, math.max(hum.HipHeight, 2), 7), overlapCheck)
			for _, part in ipairs(parts) do
				if part.CanCollide and (not flags["sp_enabled"] or spiderShift) then
					modified[part] = true
					part.CanCollide = false
				end
			end
			for part in pairs(modified) do
				if not table.find(parts, part) then
					modified[part] = nil
					part.CanCollide = true
				end
			end
		elseif mode == "Character" then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide and (not flags["sp_enabled"] or spiderShift) then
					modified[part] = true
					part.CanCollide = flags["sp_enabled"] and not spiderShift
				end
			end
		elseif mode == "CFrame" or mode == "Motor" then
			local camera = Workspace.CurrentCamera
			local head = char:FindFirstChild("Head") or root
			rayCheck.FilterDescendantsInstances = { camera, char }
			overlapCheck.FilterDescendantsInstances = { camera, char }
			local ray = Workspace:Raycast(head.Position, hum.MoveDirection * 1.1, rayCheck)
			if ray and (not flags["sp_enabled"] or spiderShift) then
				local phaseDirection = grabClosestNormal(ray)
				if ray.Instance.Size[phaseDirection] <= (flags["ph_wall"] or 5) then
					local dest = root.CFrame + (ray.Normal * (-(ray.Instance.Size[phaseDirection]) - (root.Size.X / 1.5)))
					if #Workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
						if mode == "Motor" then
							motorMove(root, dest)
						else
							root.CFrame = dest
						end
					end
				end
			end
		elseif mode == "FFlag" then
			if teleported then return end
			setFFlag("AssemblyExtentsExpansionStudHundredth", "-10000")
			fflag = true
		end
	end

	function setPhase(on)
		if phaseConn then pcall(function() phaseConn:Disconnect() end); phaseConn = nil end
		if phaseTpConn then pcall(function() phaseTpConn:Disconnect() end); phaseTpConn = nil end
		phaseRestore()
		if on then
			local mode = flags["ph_mode"] or "Part"
			phaseConn = RunService.Stepped:Connect(function()
				if flags["ph_enabled"] then phaseStep(flags["ph_mode"] or "Part") end
			end)
			if mode == "FFlag" then
				phaseTpConn = lp.OnTeleport:Connect(function()
					teleported = true
					setFFlag("AssemblyExtentsExpansionStudHundredth", "30")
				end)
			end
		end
	end

	-- ——— SPIDER (vape 1:1: Velocity / Impulse / CFrame / Part) ———
	local spiderConn = nil
	spiderTruss = function(val)
		if truss then
			pcall(function() truss:Destroy() end)
			truss = nil
		end
		if val == "Part" then
			truss = Instance.new("TrussPart")
			truss.Size = v3new(2, 2, 2)
			truss.Transparency = 1
			truss.Anchored = true
			truss.Parent = flags["sp_enabled"] and Workspace.CurrentCamera or nil
		end
	end

	function setSpider(on)
		if spiderConn then pcall(function() spiderConn:Disconnect() end); spiderConn = nil end
		if truss then truss.Parent = on and Workspace.CurrentCamera or nil end
		if on then
			spiderConn = RunService.PreSimulation:Connect(function(dt)
				local alive, char, hum, root = getChar()
				if not alive then return end
				local camera = Workspace.CurrentCamera
				local chars = { camera, char, truss }
				spiderShift = UIS:IsKeyDown(Enum.KeyCode.LeftShift)
				rayCheck.FilterDescendantsInstances = chars
				rayCheck.CollisionGroup = root.CollisionGroup
				local mode = flags["sp_mode"] or "Velocity"
				local hip = math.max(hum.HipHeight, 2)
				if mode ~= "Part" then
					local vec = hum.MoveDirection * 2.5
					local ray = Workspace:Raycast(root.Position - v3new(0, hip - 0.5, 0), vec, rayCheck)
					if active and not ray then
						root.Velocity = v3new(root.Velocity.X, 0, root.Velocity.Z)
					end
					active = ray
					if active and ray.Normal.Y == 0 then
						if not flags["ph_enabled"] or not spiderShift then
							if flags["sp_state"] then
								pcall(function() hum:ChangeState(Enum.HumanoidStateType.Climbing) end)
							end
							root.Velocity *= v3new(1, 0, 1)
							local value = flags["sp_speed"] or 30
							if mode == "CFrame" then
								root.CFrame += v3new(0, value * dt, 0)
							elseif mode == "Impulse" then
								root:ApplyImpulse(v3new(0, value, 0) * root.AssemblyMass)
							else
								root.Velocity += v3new(0, value, 0)
							end
						end
					end
				else
					local ray = Workspace:Raycast(root.Position - v3new(0, hip - 0.5, 0), root.CFrame.LookVector * 2, rayCheck)
					if ray and (not flags["ph_enabled"] or not spiderShift) then
						truss.Position = ray.Position - ray.Normal * 0.9
					else
						truss.Position = Vector3.zero
					end
				end
			end)
		else
			spiderShift = false
			active = false
		end
	end

	-- ——— SPEED (vape 1:1: Velocity + MoveDirection/Direct + Custom Properties) ———
	local speedConn = nil
	local w, s, a, d = 0, 0, 0, 0
	bind(UIS.InputBegan:Connect(function(input)
		if not UIS:GetFocusedTextBox() then
			local k = input.KeyCode
			if k == Enum.KeyCode.W then w = -1
			elseif k == Enum.KeyCode.S then s = 1
			elseif k == Enum.KeyCode.A then a = -1
			elseif k == Enum.KeyCode.D then d = 1 end
		end
	end))
	bind(UIS.InputEnded:Connect(function(input)
		local k = input.KeyCode
		if k == Enum.KeyCode.W then w = 0
		elseif k == Enum.KeyCode.S then s = 0
		elseif k == Enum.KeyCode.A then a = 0
		elseif k == Enum.KeyCode.D then d = 0 end
	end))

	function setSpeed(on)
		if speedConn then pcall(function() speedConn:Disconnect() end); speedConn = nil end
		frictionTable.Speed = on and flags["spd_custom"] or nil
		updateVelocity()
		if on then
			w = UIS:IsKeyDown(Enum.KeyCode.W) and -1 or 0
			s = UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0
			a = UIS:IsKeyDown(Enum.KeyCode.A) and -1 or 0
			d = UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0
			speedConn = RunService.PreSimulation:Connect(function(dt)
				local alive, char, hum = getChar()
				if alive then
					if hum:GetState() == Enum.HumanoidStateType.Climbing then return end
					local movevec = flags["spd_movemode"] == "Direct" and calculateMoveVector(v3new(a + d, 0, w + s)) or hum.MoveDirection
					speedVelocity(flags["spd_value"] or 50, movevec)
				end
			end)
		end
	end

	-- ——— FREECAM (vape 1:1: Classic camera-controller hook + Roblox module) ———
	local ctx     = game:GetService("ContextActionService")
	local httpSvc = game:GetService("HttpService")
	local randomkey = httpSvc:GenerateGUID(false)
	local fcModule, fcOld = nil, nil

	function setFreecam(on)
		-- teardown (both modes)
		pcall(function() ctx:UnbindAction("FreecamKeyboard" .. randomkey) end)
		if fcModule and fcOld then
			pcall(function() fcModule.activeCameraController.GetSubjectPosition = fcOld end)
			fcModule, fcOld = nil, nil
		end
		pcall(function()
			local fcScript = CoreGui.RobloxGui.Modules.Server.FreeCamera.FreeCamera
			fcScript:SetAttribute("FreecamEnabled", false)
		end)
		if on then
			task.spawn(function()
				if (flags["fc_mode"] or "Classic") == "Roblox" then
					pcall(function()
						if not lp.PlayerGui:FindFirstChild("Freecam") then
							local gui = Instance.new("ScreenGui")
							gui.ResetOnSpawn = false
							gui.Name = "Freecam"
							gui.Parent = lp.PlayerGui
						end
						local fcScript = CoreGui.RobloxGui.Modules.Server.FreeCamera.FreeCamera
						getrenv().require(fcScript)
						fcScript:SetAttribute("FreecamEnabled", true)
					end)
					return
				end

				-- Classic: find the camera module through the CameraType listeners
				local camera = Workspace.CurrentCamera
				local module
				if type(getconnections) == "function" then
					repeat
						for _, connection in ipairs(getconnections(camera:GetPropertyChangedSignal("CameraType"))) do
							if connection.Function then
								local ok, m = pcall(debug.getupvalue, connection.Function, 1)
								if ok and type(m) == "table" then module = m end
								if module then break end
							end
						end
						if module or not flags["fc_enabled"] then break end
						task.wait(0.1)
					until module or not flags["fc_enabled"]
				end

				if module and module.activeCameraController and flags["fc_enabled"] then
					fcModule = module
					fcOld = module.activeCameraController.GetSubjectPosition
					local camPos = fcOld(module.activeCameraController) or Vector3.zero
					module.activeCameraController.GetSubjectPosition = function()
						return camPos
					end

					local fcConn
					fcConn = RunService.PreSimulation:Connect(function(dt)
						if not UIS:GetFocusedTextBox() then
							local forward = (UIS:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
							local side = (UIS:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
							local up = (UIS:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (UIS:IsKeyDown(Enum.KeyCode.E) and 1 or 0)
							dt = dt * (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
							camPos = (CFrame.lookAlong(camPos, camera.CFrame.LookVector) * CFrame.new(v3new(side, up, forward) * ((flags["fc_speed"] or 50) * dt))).Position
						end
					end)
					bind(fcConn)

					ctx:BindActionAtPriority("FreecamKeyboard" .. randomkey, function()
						return Enum.ContextActionResult.Sink
					end, false, Enum.ContextActionPriority.High.Value,
						Enum.KeyCode.W,
						Enum.KeyCode.A,
						Enum.KeyCode.S,
						Enum.KeyCode.D,
						Enum.KeyCode.E,
						Enum.KeyCode.Q,
						Enum.KeyCode.Up,
						Enum.KeyCode.Down
					)
				end
			end)
		end
	end

	-- ——— NOCLIP GUIDE UI (custom draggable window, toggled from Misc) ———
	guideGui = Instance.new("ScreenGui")
	guideGui.Name = "VaultNoclipGuide"
	guideGui.ResetOnSpawn = false
	guideGui.DisplayOrder = 999998
	guideGui.Enabled = false
	pcall(function() guideGui.Parent = (gethui and gethui()) or CoreGui end)

	local ACCENT  = Color3.fromRGB(96, 120, 190)
	local OUTLINE = Color3.fromRGB(10, 10, 10)
	local INLINE  = Color3.fromRGB(30, 30, 38)
	local CONTRST = Color3.fromRGB(41, 41, 55)
	local TXT     = Color3.fromRGB(180, 180, 180)

	local main = Instance.new("Frame")
	main.Size = UDim2.fromOffset(330, 280)
	main.Position = UDim2.new(0.5, -165, 0.5, -140)
	main.BackgroundColor3 = OUTLINE
	main.BorderSizePixel = 0
	main.Active = true
	main.Parent = guideGui
	Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", main)
	stroke.Color = ACCENT
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- title bar (drag handle)
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 34)
	titleBar.BackgroundColor3 = CONTRST
	titleBar.BorderSizePixel = 0
	titleBar.Parent = main
	Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
	local titleFix = Instance.new("Frame")  -- square off the bottom corners of the bar
	titleFix.Size = UDim2.new(1, 0, 0, 10)
	titleFix.Position = UDim2.new(0, 0, 1, -10)
	titleFix.BackgroundColor3 = CONTRST
	titleFix.BorderSizePixel = 0
	titleFix.Parent = titleBar

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -40, 1, 0)
	title.Position = UDim2.fromOffset(12, 0)
	title.Font = Enum.Font.GothamBold
	title.Text = "VAULT — NOCLIP GUIDE"
	title.TextColor3 = ACCENT
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(22, 22)
	closeBtn.Position = UDim2.new(1, -27, 0.5, -11)
	closeBtn.BackgroundColor3 = INLINE
	closeBtn.Text = "X"
	closeBtn.TextColor3 = TXT
	closeBtn.TextSize = 12
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = titleBar
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

	-- content
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -20, 1, -58)
	content.Position = UDim2.fromOffset(10, 44)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = ACCENT
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Parent = main

	local layout = Instance.new("UIListLayout", content)
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local intro = Instance.new("TextLabel")
	intro.Size = UDim2.new(1, -8, 0, 0)
	intro.AutomaticSize = Enum.AutomaticSize.Y
	intro.BackgroundTransparency = 1
	intro.Font = Enum.Font.Gotham
	intro.RichText = true
	intro.TextWrapped = true
	intro.TextSize = 12
	intro.TextColor3 = TXT
	intro.Text = "Use <font color=\"#8FA7E8\">Phase (Mode: Part)</font> + <font color=\"#8FA7E8\">Speed</font> to clip inside bases and loot them. Read the steps below — get out by rejoining, looting, then phasing back out."
	intro.Parent = content

	local STEPS = {
		{ "Step 1", "Set Speed to 1 stud (Speed section). A slow, steady push is what makes the clip consistent — higher speeds usually just launch you instead of letting you slip through." },
		{ "Step 2", "Keep Phase on Mode: Part and enable it. Walk into the base wall / corner and keep trying until you successfully noclip inside — it can take a few attempts, stay pressed against the wall while it works." },
		{ "Step 3", "Once you're inside: leave the server and rejoin, then loot the bodies / crates — take everything." },
		{ "Step 4", "Noclip again (Phase, Mode: Part) to get out of the base." },
	}
	for _, st in ipairs(STEPS) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundColor3 = INLINE
		row.BorderSizePixel = 0
		row.Parent = content
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local pad = Instance.new("UIPadding", row)
		pad.PaddingTop = UDim.new(0, 7); pad.PaddingBottom = UDim.new(0, 7)
		pad.PaddingLeft = UDim.new(0, 9); pad.PaddingRight = UDim.new(0, 9)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 0)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.RichText = true
		lbl.TextWrapped = true
		lbl.TextSize = 12
		lbl.TextColor3 = TXT
		lbl.Text = "<font color=\"#8FA7E8\"><b>" .. st[1] .. "</b></font>  " .. st[2]
		lbl.Parent = row
	end

	local function dragify(handle)
		local dragging, dragStart, startPos = false, nil, nil
		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
			end
		end)
		handle.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end)
		bind(UIS.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				main.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + (input.Position.X - dragStart.X),
					startPos.Y.Scale, startPos.Y.Offset + (input.Position.Y - dragStart.Y))
			end
		end))
	end
	dragify(titleBar)

	closeBtn.MouseButton1Click:Connect(function()
		local fn = library.config_flags and library.config_flags["gd_open"]
		if fn then fn(false) else guideGui.Enabled = false end
	end)

	bind({ Disconnect = function() pcall(function() guideGui:Destroy() end) end })

	-- unload: stop everything and restore what we touched
	bind({ Disconnect = function()
		setFreecam(false)
		setSpeed(false)
		setPhase(false)
		setSpider(false)
	end })
end

-- ================================================================
-- // VIEWER WINDOWS
-- //   draggable inventory viewer (HOTBAR + ARMOR, real item icons) ·
-- //   crosshair info panel (NEAR/LOCK summary) · staff panel.
-- //   All flag-gated, all bind()'ed for unload.
-- ================================================================
do
	local guiParent = (gethui and gethui()) or CoreGui
	local function mount(gui)
		pcall(function() gui.Parent = guiParent end)
	end
	local HT = {
		bg       = c3(12, 12, 17),
		panel    = c3(20, 20, 27),
		lpanel   = c3(26, 26, 34),
		outline  = c3(0, 0, 0),
		outline2 = c3(58, 58, 72),
		accent   = c3(155, 105, 230),
		purple   = c3(190, 155, 255),
		equipped = c3(48, 36, 72),
		text     = c3(235, 235, 245),
		muted    = c3(160, 160, 175),
	}
	local TXT = HT.muted
	local function hudPanel(root)
		root.BackgroundColor3 = HT.panel
		root.BackgroundTransparency = 0.04
		root.BorderSizePixel = 0
		local corner = Instance.new("UICorner", root)
		corner.CornerRadius = UDim.new(0, 7)
		local stroke = Instance.new("UIStroke", root)
		stroke.Thickness = 1
		stroke.Color = HT.outline2
		stroke.Transparency = 0.35
		local grad = Instance.new("UIGradient", root)
		grad.Rotation = 90
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, HT.lpanel),
			ColorSequenceKeypoint.new(1, HT.panel),
		})
		local bar = Instance.new("Frame")
		bar.Name = "AccentBar"
		bar.BackgroundColor3 = HT.accent
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(1, 0, 0, 2)
		bar.Position = UDim2.new(0, 0, 0, 0)
		bar.Parent = root
		Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
		local dot = Instance.new("Frame")
		dot.Name = "AccentDot"
		dot.BackgroundColor3 = HT.accent
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(5, 5)
		dot.Position = UDim2.fromOffset(8, 8)
		dot.Parent = root
		Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 3)
	end
	local function playerOfModel(m)
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character == m then return p end
		end
	end

	-- ——— ITEM ICONS (the game's own atlas DB) ———
	-- ReplicatedStorage.ItemIconPhotos: { sheets = {n = rbxassetid...},
	-- icons = { ["I:Name" | "T:Name"] = { s, x, y } }, size = 256 }. An icon
	-- renders as Image = sheets[e.s] cropped to (e.x, e.y, 256, 256) — exactly
	-- how the game's own belt IconPhoto does it.
	local iconDB = nil
	task.spawn(function()
		for _ = 1, 10 do
			local m = RepStorage:FindFirstChild("ItemIconPhotos")
			if m then
				local ok, v = pcall(require, m)
				if ok and type(v) == "table" and type(v.icons) == "table" and type(v.sheets) == "table" then
					iconDB = v
					return
				end
			end
			task.wait(1)
		end
	end)
	local iconApplied = {}
	local function applyIcon(img, itemName)
		if iconDB and iconApplied[img] == itemName then return true end
		local e = iconDB and (iconDB.icons["T:" .. itemName] or iconDB.icons["I:" .. itemName])
		local sheet = e and iconDB.sheets[e.s]
		if not sheet then
			if img.Visible then img.Visible = false end
			iconApplied[img] = iconDB and itemName or nil
			return false
		end
		img.Image = sheet
		img.ImageRectOffset = v2new(e.x, e.y)
		img.ImageRectSize = v2new(iconDB.size or 256, iconDB.size or 256)
		img.ScaleType = Enum.ScaleType.Stretch
		img.Visible = true
		iconApplied[img] = itemName
		return true
	end
	-- shared viewer row: icon + name, 26px tall
	local function makeRow(parent, order)
		local r = Instance.new("Frame")
		r.BackgroundColor3 = HT.lpanel
		r.BackgroundTransparency = 0.08
		r.BorderSizePixel = 0
		r.Size = UDim2.new(1, 0, 0, 26)
		r.LayoutOrder = order
		r.Parent = parent
		Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)
		local rowStroke = Instance.new("UIStroke", r)
		rowStroke.Thickness = 1
		rowStroke.Color = HT.outline2
		rowStroke.Transparency = 0.55
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.Size = UDim2.fromOffset(20, 20)
		ic.Position = UDim2.new(0, 3, 0.5, -10)
		ic.Parent = r
		local st = Instance.new("TextLabel")
		st.BackgroundTransparency = 1
		st.Font = Enum.Font.Gotham
		st.TextSize = 11
		st.TextColor3 = HT.text
		st.TextXAlignment = Enum.TextXAlignment.Left
		st.TextTruncate = Enum.TextTruncate.AtEnd
		st.Position = UDim2.new(0, 27, 0, 0)
		st.Size = UDim2.new(1, -30, 1, 0)
		st.Parent = r
		return { frame = r, icon = ic, text = st }
	end

	-- shared drag: pull a window by its handle (or the frame itself)
	local dragConns = {}
	local function makeDraggable(frame, handle)
		local dragging, dragStart, startPos
		handle.Active = true
		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = frame.Position
			end
		end)
		local conn = UIS.InputChanged:Connect(function(input)
			if dragging and dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
		local rel = UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		dragConns[#dragConns + 1] = conn
		dragConns[#dragConns + 1] = rel
	end
	bind({ Disconnect = function()
		for _, c in ipairs(dragConns) do pcall(function() c:Disconnect() end) end
	end })

	-- ——— target info (small panel under the crosshair) ———
	local tiGui = Instance.new("ScreenGui")
	tiGui.Name = "OVXTarget"
	tiGui.ResetOnSpawn = false
	tiGui.IgnoreGuiInset = true
	tiGui.DisplayOrder = 401
	mount(tiGui)
	bind({ Disconnect = function() pcall(function() tiGui:Destroy() end) end })
	local tiRoot = Instance.new("Frame")
	tiRoot.AnchorPoint = v2new(0.5, 0)
	tiRoot.Position = UDim2.new(0.5, 0, 0.5, 44)
	tiRoot.Size = UDim2.fromOffset(320, 84)
	tiRoot.Parent = tiGui
	hudPanel(tiRoot)
	local tiCaption = Instance.new("TextLabel")
	tiCaption.BackgroundTransparency = 1
	tiCaption.Font = Enum.Font.GothamBold
	tiCaption.TextSize = 10
	tiCaption.TextColor3 = HT.accent
	tiCaption.TextXAlignment = Enum.TextXAlignment.Left
	tiCaption.TextYAlignment = Enum.TextYAlignment.Center
	tiCaption.Position = UDim2.new(0, 18, 0, 2)
	tiCaption.Size = UDim2.new(1, -24, 0, 14)
	tiCaption.Parent = tiRoot
	tiCaption.Text = "TARGET INFO"
	local tiText = Instance.new("TextLabel")
	tiText.BackgroundTransparency = 1
	tiText.Font = Enum.Font.Gotham
	tiText.TextSize = 11
	tiText.TextColor3 = HT.text
	tiText.TextXAlignment = Enum.TextXAlignment.Left
	tiText.TextYAlignment = Enum.TextYAlignment.Top
	tiText.TextWrapped = true
	tiText.Position = UDim2.new(0, 10, 0, 20)
	tiText.Size = UDim2.new(1, -20, 1, -24)
	tiText.Parent = tiRoot
	tiText.Text = ""
	makeDraggable(tiRoot, tiRoot)

	-- ——— inventory viewer (right side, nearest/lock player) ———
	local invGui = Instance.new("ScreenGui")
	invGui.Name = "OVXInv"
	invGui.ResetOnSpawn = false
	invGui.IgnoreGuiInset = true
	invGui.DisplayOrder = 402
	mount(invGui)
	bind({ Disconnect = function() pcall(function() invGui:Destroy() end) end })
	local invRoot = Instance.new("Frame")
	invRoot.AnchorPoint = v2new(1, 0)
	invRoot.Position = UDim2.new(1, -12, 0, 120)
	invRoot.Size = UDim2.fromOffset(252, 88)
	invRoot.Parent = invGui
	hudPanel(invRoot)
	local invTitle = Instance.new("TextLabel")
	invTitle.BackgroundTransparency = 1
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 11
	invTitle.TextColor3 = HT.text
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.TextTruncate = Enum.TextTruncate.AtEnd
	invTitle.Position = UDim2.new(0, 18, 0, 0)
	invTitle.Size = UDim2.new(1, -48, 0, 26)
	invTitle.Parent = invRoot
	invTitle.Text = "INVENTORY"
	makeDraggable(invRoot, invTitle)
	local invBody = Instance.new("Frame")
	invBody.Position = UDim2.new(0, 10, 0, 30)
	invBody.Size = UDim2.new(1, -20, 1, -40)
	invBody.BackgroundTransparency = 1
	invBody.Parent = invRoot
	local invList = Instance.new("UIListLayout", invBody)
	invList.Padding = UDim.new(0, 4)
	invList.SortOrder = Enum.SortOrder.LayoutOrder
	-- separated vertical sections: HOTBAR and ARMOR, with real item icons
	local function sectionHeader(txt, order)
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Font = Enum.Font.GothamBold
		h.TextSize = 10
		h.TextColor3 = HT.purple
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Size = UDim2.new(1, 0, 0, 16)
		h.LayoutOrder = order
		h.Parent = invBody
		h.Text = "◆ " .. txt
		return h
	end
	local hotHeader = sectionHeader("HOTBAR", 1)
	local hotHolder = Instance.new("Frame")
	hotHolder.BackgroundTransparency = 1
	hotHolder.Size = UDim2.new(1, 0, 0, 0)
	hotHolder.LayoutOrder = 2
	hotHolder.Parent = invBody
	local hotList = Instance.new("UIListLayout", hotHolder)
	hotList.Padding = UDim.new(0, 3)
	hotList.SortOrder = Enum.SortOrder.LayoutOrder
	local armHeader = sectionHeader("ARMOR", 3)
	local armHolder = Instance.new("Frame")
	armHolder.BackgroundTransparency = 1
	armHolder.Size = UDim2.new(1, 0, 0, 0)
	armHolder.LayoutOrder = 4
	armHolder.Parent = invBody
	local armList = Instance.new("UIListLayout", armHolder)
	armList.Padding = UDim.new(0, 3)
	armList.SortOrder = Enum.SortOrder.LayoutOrder
	local MAX_HOT_ROWS, MAX_ARM_ROWS = 12, 8
	local hotRows, armRows = {}, {}
	local invH, lastHotH, lastArmH = 88, 0, 0
	local function ensure(pool, holder, i)
		if not pool[i] then pool[i] = makeRow(holder, i) end
		return pool[i]
	end
	local function hideFrom(pool, from, upto)
		for i = from, upto do
			local r = pool[i]
			if r and r.frame.Visible then r.frame.Visible = false end
		end
	end

	-- ——— staff panel (left side) ———
	local staffGui = Instance.new("ScreenGui")
	staffGui.Name = "OVXStaff"
	staffGui.ResetOnSpawn = false
	staffGui.IgnoreGuiInset = true
	staffGui.DisplayOrder = 403
	mount(staffGui)
	bind({ Disconnect = function() pcall(function() staffGui:Destroy() end) end })
	local staffRoot = Instance.new("Frame")
	staffRoot.Position = UDim2.new(0, 12, 0, 120)
	staffRoot.Size = UDim2.fromOffset(250, 26)
	staffRoot.Parent = staffGui
	hudPanel(staffRoot)
	local staffTitle = Instance.new("TextLabel")
	staffTitle.BackgroundTransparency = 1
	staffTitle.Font = Enum.Font.GothamBold
	staffTitle.TextSize = 11
	staffTitle.TextColor3 = HT.accent
	staffTitle.TextXAlignment = Enum.TextXAlignment.Left
	staffTitle.Position = UDim2.new(0, 18, 0, 0)
	staffTitle.Size = UDim2.new(1, -48, 0, 26)
	staffTitle.Parent = staffRoot
	staffTitle.Text = "STAFF IN SERVER"
	local staffBody = Instance.new("Frame")
	staffBody.Position = UDim2.new(0, 10, 0, 30)
	staffBody.Size = UDim2.new(1, -20, 1, -40)
	staffBody.BackgroundTransparency = 1
	staffBody.Parent = staffRoot
	local staffText = Instance.new("TextLabel")
	staffText.BackgroundTransparency = 1
	staffText.Font = Enum.Font.Gotham
	staffText.TextSize = 11
	staffText.TextColor3 = HT.muted
	staffText.TextXAlignment = Enum.TextXAlignment.Left
	staffText.TextYAlignment = Enum.TextYAlignment.Top
	staffText.Size = UDim2.new(1, 0, 1, 0)
	staffText.Parent = staffBody

	-- crosshair-aware pick: the player whose parts sit closest to the cursor
	local function crosshairPlayer()
		local cam = Workspace.CurrentCamera
		if not cam then return nil end
		local m = UIS:GetMouseLocation()
		local cross = v2new(m.X, m.Y)
		local best, bestD
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= lp then
				local rel = OVX.relation(pl)
				if rel == "team" or rel == "ally" then
					-- teammates never picked by the crosshair
				else
					local c = pl.Character
					local hum = c and c:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 and not c:GetAttribute("Downed") then
						local pos
						local hrp = c:FindFirstChild("HumanoidRootPart")
						if hrp then
							pos = hrp.Position
						else
							local ok, piv = pcall(c.GetPivot, c)
							if ok then pos = piv.Position end
						end
						if pos then
							local sp, on = cam:WorldToViewportPoint(pos)
							if on and sp.Z > 0 then
								local d = (v2new(sp.X, sp.Y) - cross).Magnitude
								if d < 260 and (not bestD or d < bestD) then
									bestD = d
									best = pl
								end
							end
						end
					end
				end
			end
		end
		return best
	end

	-- staff cache survives reloads so already-flagged staff don't re-notify
	local known = getgenv().__ovxStaff
	if not known then known = {}; getgenv().__ovxStaff = known end
	local function scanStaff()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then
				local r = OVX.staffReason(p)
				if r and not known[p.Name] then
					known[p.Name] = r
					OVX.notify("STAFF DETECTED: " .. p.Name .. " (" .. r .. ")")
				end
			end
		end
	end

	local hudAt, staffAt = 0, 0
	local sticky
	bind(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local hudInterval = 1 / math.clamp(tonumber(flags["ui_hud_hz"]) or 4, 1, 12)
		local tiOn = flags["hud_targetinfo"] ~= false
		local invOn = flags["invwin_enabled"] == true
		tiRoot.Visible = tiOn
		invRoot.Visible = invOn
		staffRoot.Visible = flags["staffwin_enabled"] == true
		if not (tiOn or invOn) and flags["staffwin_enabled"] ~= true then return end

		-- target info + inventory at 4 Hz
		if (tiOn or invOn) and now - hudAt >= hudInterval then
			hudAt = now
			local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			local myPos = myRoot and myRoot.Position
			local tgt = OVX.saTarget
			local best, bd, locked, isAI
			if tgt and tgt.model and tgt.model.Parent then
				local p = tgt.part or tgt.model:FindFirstChild("HumanoidRootPart") or tgt.model.PrimaryPart
				if p and myPos then
					bd = (p.Position - myPos).Magnitude
					locked = true
					best = playerOfModel(tgt.model)
					if not best then isAI = true end
				end
			end
			if not best and not isAI then
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= lp and plr.Character and myRoot then
						local c = plr.Character
						local pos
						local r = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
						if r then
							pos = r.Position
						else
							local okP, piv = pcall(c.GetPivot, c)
							if okP then pos = piv.Position end
						end
						if pos then
							local d = (pos - myPos).Magnitude
							if not bd or d < bd then best, bd = plr, d end
						end
					end
				end
			end
			-- crosshair-aware: when nothing is locked, a player under the
			-- cursor beats plain distance-to-me, so the panel reads "NEAR"
			-- for whoever is actually on the crosshair
			if not best and not isAI then
				local cp = crosshairPlayer()
				if cp and cp.Character and myPos then
					local c = cp.Character
					local r = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
					local pos = r and r.Position
					if not pos then
						local okP, piv = pcall(c.GetPivot, c)
						if okP then pos = piv.Position end
					end
					if pos then
						best, bd = cp, (pos - myPos).Magnitude
					end
				end
			end
			-- sticky nearest: hold the current pick unless someone is 25%+
			-- closer, so two near-equidistant players can't thrash the viewer
			if best and myPos then
				local keep = sticky
				if keep and keep.Parent and keep.Character then
					local kh = keep.Character:FindFirstChildOfClass("Humanoid")
					if kh and kh.Health > 0 then
						local sr = keep.Character:FindFirstChild("HumanoidRootPart") or keep.Character.PrimaryPart
						if sr then
							local sd = (sr.Position - myPos).Magnitude
							if bd and sd <= bd * 1.25 then best, bd = keep, sd end
						end
					end
				end
			end
			sticky = best
			if isAI then
				local hum = tgt.model:FindFirstChildOfClass("Humanoid")
				local hpTxt = hum and ("HP %d"):format(floor(hum.Health)) or "HP ?"
				invTitle.Text = ("TARGET  •  %s (AI)"):format(tgt.model.Name)
				hideFrom(hotRows, 1, MAX_HOT_ROWS)
				hideFrom(armRows, 1, MAX_ARM_ROWS)
				if invH ~= 88 then
					invH = 88
					invRoot.Size = UDim2.fromOffset(252, 88)
				end
				if lastHotH ~= 0 then
					lastHotH = 0
					hotHolder.Size = UDim2.new(1, 0, 0, 0)
				end
				if lastArmH ~= 0 then
					lastArmH = 0
					armHolder.Size = UDim2.new(1, 0, 0, 0)
				end
				if tiRoot.Visible then
					tiText.Text = ("◈ LOCK %s  %.0fm  %s"):format(tgt.model.Name, bd or 0, hpTxt)
				end
			elseif not best then
				invTitle.Text = "INVENTORY"
				hideFrom(hotRows, 1, MAX_HOT_ROWS)
				hideFrom(armRows, 1, MAX_ARM_ROWS)
				if invH ~= 88 then
					invH = 88
					invRoot.Size = UDim2.fromOffset(252, 88)
				end
				if lastHotH ~= 0 then
					lastHotH = 0
					hotHolder.Size = UDim2.new(1, 0, 0, 0)
				end
				if lastArmH ~= 0 then
					lastArmH = 0
					armHolder.Size = UDim2.new(1, 0, 0, 0)
				end
				tiText.Text = "◈  no player nearby"
			else
				local char = best.Character
				local gun = char and char:FindFirstChildOfClass("Tool")
				local hasParts = char ~= nil and char:FindFirstChildWhichIsA("BasePart", true) ~= nil
				local armorParts = {}
				if char then
					for _, m2 in ipairs(char:GetChildren()) do
						if m2:IsA("Model") and string.sub(m2.Name, 1, 6) == "Armor_" then
							table.insert(armorParts, string.sub(m2.Name, 7))
						end
					end
				end
				local counts = {}
				for k, v in pairs(best:GetAttributes()) do
					if typeof(v) == "number" and v >= 1 and v < 1e6 and v == math.floor(v)
						and not OVX.invSkip(k) and #k <= 20
						and not string.find(k, "[_%.]")
						and not string.find(k, "At$") and not string.find(k, "Until$")
						and not string.find(k, "^ToolCount_") and not string.find(k, "Seen$") then
						table.insert(counts, { k, v })
					end
				end
				table.sort(counts, function(a2, b2) return a2[2] > b2[2] end)
				local resParts = {}
				for i = 1, math.min(4, #counts) do
					local v = counts[i][2]
					resParts[i] = counts[i][1] .. " " .. (v >= 1000 and ("%dk"):format(floor(v / 1000)) or tostring(floor(v)))
				end
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local hpTxt = hum and ("HP %d"):format(floor(hum.Health)) or "HP ?"
				invTitle.Text = ("INVENTORY  •  %s"):format(best.Name)
				local hotN = 0
				local function hotRow(name, equipped)
					hotN += 1
					if hotN > MAX_HOT_ROWS then return end
					local r = ensure(hotRows, hotHolder, hotN)
					if r.lastName ~= name or r.lastEq ~= equipped then
						r.lastName, r.lastEq = name, equipped
						r.text.Text = (equipped and "[E] " or "") .. name
						r.frame.BackgroundColor3 = equipped and HT.equipped or HT.lpanel
					end
					r.frame.Visible = true
					applyIcon(r.icon, name)
				end
				if gun then hotRow(gun.Name, true) end
				local bp = best:FindFirstChildOfClass("Backpack")
				if bp then
					for _, t in ipairs(bp:GetChildren()) do
						if t:IsA("Tool") then hotRow(t.Name, false) end
					end
				end
				hideFrom(hotRows, hotN + 1, MAX_HOT_ROWS)
				local armN = 0
				for _, name in ipairs(armorParts) do
					armN += 1
					if armN <= MAX_ARM_ROWS then
						local r = ensure(armRows, armHolder, armN)
						if r.lastName ~= name then
							r.lastName = name
							r.text.Text = name
							r.frame.BackgroundColor3 = HT.lpanel
						end
						r.frame.Visible = true
						applyIcon(r.icon, name)
					end
				end
				hideFrom(armRows, armN + 1, MAX_ARM_ROWS)
				local hotH = hotN > 0 and hotN * 29 or 0
				local armH = armN > 0 and armN * 29 or 0
				if hotH ~= lastHotH then
					lastHotH = hotH
					hotHolder.Size = UDim2.new(1, 0, 0, hotH)
				end
				if armH ~= lastArmH then
					lastArmH = armH
					armHolder.Size = UDim2.new(1, 0, 0, armH)
				end
				local h = 88 + hotH + armH
				if h ~= invH then
					invH = h
					invRoot.Size = UDim2.fromOffset(252, h)
				end
				if tiRoot.Visible then
					tiText.Text = ("◈ %s %s  %.0fm  %s\nGUN: %s\nARMOR: %s\nRES: %s"):format(
						locked and "LOCK" or "NEAR", best.Name, bd or 0, hpTxt,
						gun and gun.Name or (hasParts and "none" or "far"),
						#armorParts > 0 and table.concat(armorParts, ", ") or (hasParts and "none" or "far"),
						#resParts > 0 and table.concat(resParts, "  ") or "-")
				end
			end
		end

		-- staff scan every 2s
		if flags["staffwin_enabled"] == true and now - staffAt > 2 then
			staffAt = now
			pcall(scanStaff)
			local names = {}
			for name, r in pairs(known) do names[#names + 1] = "• " .. name .. " — " .. r end
			table.sort(names)
			staffText.Text = #names > 0 and table.concat(names, "\n") or "nobody flagged\n(scanning every 2s)"
			staffTitle.Text = ("STAFF IN SERVER  •  %d"):format(#names)
			staffRoot.Size = UDim2.fromOffset(250, 40 + math.max(#names, 1) * 16)
		end
	end))
end


-- ================================================================
-- // 3D SELF ESP PREVIEW
-- //   A live box, highlight and billboard attached to the local character,
-- //   driven by the exact same ESP flags as the real player ESP.
-- ================================================================
do
	local guiParent = CoreGui
	pcall(function()
		if type(gethui) == "function" then guiParent = gethui() or guiParent end
	end)
	local api = {}
	OVX.espSelfPreview = api
	local currentChar = nil
	local lastAt = 0

	local function set(instance, key, value)
		if instance then pcall(function() instance[key] = value end) end
	end
	local function destroy(instance)
		if instance then pcall(function() instance:Destroy() end) end
	end
	local function clear()
		destroy(api.highlight); destroy(api.box); destroy(api.billboard)
		api.highlight, api.box, api.billboard = nil, nil, nil
		api.name, api.health, api.info, api.healthFill, api.healthGradient = nil, nil, nil, nil, nil
		currentChar = nil
	end
	api.destroy = clear
	api.setEnabled = function(state)
		flags["esp_self_preview_3d"] = state == true
		pcall(api.refresh)
	end

	local function makeLabel(parent, name, y, text, color)
		local label = Instance.new("TextLabel")
		set(label, "Name", name)
		set(label, "BackgroundTransparency", 1)
		set(label, "Font", Enum.Font.GothamBold)
		set(label, "TextSize", 12)
		set(label, "TextColor3", color)
		set(label, "Text", text)
		set(label, "Position", UDim2.fromOffset(0, y))
		set(label, "Size", UDim2.fromOffset(220, 16))
		set(label, "TextXAlignment", Enum.TextXAlignment.Center)
		set(label, "Parent", parent)
		return label
	end

	local function build(char)
		clear()
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
		local head = char:FindFirstChild("Head") or root
		if not root then return end
		currentChar = char

		local highlight = Instance.new("Highlight")
		set(highlight, "Name", "OVXSelfPreviewHighlight")
		set(highlight, "Adornee", char)
		set(highlight, "Parent", guiParent)
		api.highlight = highlight

		local box = Instance.new("BoxHandleAdornment")
		set(box, "Name", "OVXSelfPreviewBox")
		set(box, "Adornee", root)
		set(box, "Parent", guiParent)
		api.box = box

		local billboard = Instance.new("BillboardGui")
		set(billboard, "Name", "OVXSelfPreviewInfo")
		set(billboard, "Adornee", head or root)
		set(billboard, "Size", UDim2.fromOffset(220, 86))
		set(billboard, "StudsOffset", v3new(0, 2.8, 0))
		set(billboard, "AlwaysOnTop", true)
		set(billboard, "MaxDistance", 10000)
		set(billboard, "Parent", guiParent)
		api.billboard = billboard
		api.name = makeLabel(billboard, "Name", 0, "YOU  •  3D ESP PREVIEW", c3(255, 255, 255))
		api.health = makeLabel(billboard, "Health", 17, "HP 100%", c3(255, 255, 255))
		api.info = makeLabel(billboard, "Info", 34, "0m  •  Hands", c3(200, 200, 200))

		local hpBg = Instance.new("Frame")
		set(hpBg, "Name", "HealthBackground")
		set(hpBg, "BackgroundColor3", c3(28, 28, 38))
		set(hpBg, "BorderSizePixel", 0)
		set(hpBg, "Position", UDim2.fromOffset(10, 60))
		set(hpBg, "Size", UDim2.fromOffset(200, 9))
		set(hpBg, "Parent", billboard)
		local hpFill = Instance.new("Frame")
		set(hpFill, "Name", "HealthFill")
		set(hpFill, "BackgroundColor3", c3(0, 255, 0))
		set(hpFill, "BorderSizePixel", 0)
		set(hpFill, "Position", UDim2.fromOffset(0, 0))
		set(hpFill, "Size", UDim2.new(1, 0, 1, 0))
		set(hpFill, "Parent", hpBg)
		local gradient = Instance.new("UIGradient", hpFill)
		set(gradient, "Name", "OVXSelfPreviewHealthGradient")
		api.healthFill, api.healthGradient = hpFill, gradient
	end

	function api.refresh()
		local wants = flags["esp_self_preview_3d"] == true and flags["Enabled"] ~= false
		if not wants then clear(); return end
		local char = lp.Character
		if char ~= currentChar or not api.billboard then build(char) end
		if not api.billboard then return end
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local maxHp = math.max(1, tonumber(hum and hum.MaxHealth) or 100)
		local hp = clamp((tonumber(hum and hum.Health) or maxHp) / maxHp, 0, 1)
		local boxColor = getFlagColor("Box_Color", c3(255, 255, 255))
		local nameColor = getFlagColor("Name_Color", c3(255, 255, 255))
		local distColor = getFlagColor("Distance_Color", c3(200, 200, 200))
		local hpHigh = getFlagColor("Health_High", c3(0, 255, 0))
		local hpLow = getFlagColor("Health_Low", c3(255, 0, 0))
		local weapon = heldLabelOf(char) or "Hands"
		local display = tostring(lp.DisplayName or lp.Name or "YOU")

		set(api.box, "Adornee", char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart) or nil)
		set(api.box, "Size", v3new(3.2, 5.2, 1.2))
		set(api.box, "Color3", boxColor)
		set(api.box, "Transparency", 0.82)
		set(api.box, "AlwaysOnTop", true)
		set(api.box, "ZIndex", 3)
		set(api.box, "Visible", getFlagBool("Boxes", false))

		set(api.highlight, "Adornee", char)
		set(api.highlight, "Enabled", getFlagBool("esp_chams", false))
		set(api.highlight, "FillColor", getFlagColor("esp_cham_fill_color", c3(255, 255, 255)))
		set(api.highlight, "OutlineColor", getFlagColor("esp_cham_outline_color", c3(0, 0, 0)))
		set(api.highlight, "FillTransparency", clamp((tonumber(flags["esp_cham_fill_transparency"]) or 4) / 10, 0, 1))
		set(api.highlight, "OutlineTransparency", clamp((tonumber(flags["esp_cham_outline_transparency"]) or 0) / 10, 0, 1))
		pcall(function() api.highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)

		set(api.name, "Text", display .. "  •  3D ESP PREVIEW")
		set(api.name, "TextColor3", nameColor)
		set(api.name, "Visible", getFlagBool("Names", false))
		set(api.health, "Text", ("HP %d%%"):format(floor(hp * 100 + 0.5)))
		set(api.health, "TextColor3", getFlagColor("esp_health_text_color", c3(255, 255, 255)))
		set(api.health, "Visible", getFlagBool("esp_health_text", false))
		set(api.info, "Text", ("0m  •  %s"):format(weapon))
		set(api.info, "TextColor3", distColor)
		set(api.info, "Visible", getFlagBool("Distance", false) or getFlagBool("Weapon", false))
		set(api.healthFill, "Size", UDim2.new(hp, 0, 1, 0))
		set(api.healthGradient, "Color", ColorSequence.new({
			ColorSequenceKeypoint.new(0, hpLow),
			ColorSequenceKeypoint.new(1, hpHigh),
		}))
		set(api.billboard, "Enabled", true)
	end

	bind(lp.CharacterAdded:Connect(function()
		currentChar = nil
		pcall(api.refresh)
	end))
	bind(lp.CharacterRemoving:Connect(clear))
	bind(RunService.Heartbeat:Connect(function()
		if flags["esp_self_preview_3d"] ~= true then return end
		local now = os.clock()
		local hz = clamp(tonumber(flags["esp_self_preview_hz"]) or 10, 2, 20)
		if now - lastAt < 1 / hz then return end
		lastAt = now
		pcall(api.refresh)
	end))
	bind({ Disconnect = clear })
	pcall(api.refresh)
end

-- ================================================================
-- // UI
-- ================================================================
local window = library:window({ name = os.date("Vault | %b %d %Y") })

-- preview re-parent hook (bound to every preview-relevant toggle/colorpicker)
local esp
local function update_elements()
	if esp and esp.refresh_elements then esp.refresh_elements() end
	local liveEsp = getgenv().esp
	if liveEsp and liveEsp ~= esp and liveEsp.refresh_elements then
		pcall(liveEsp.refresh_elements)
	end
	if OVX.espSelfPreview and OVX.espSelfPreview.refresh then
		pcall(OVX.espSelfPreview.refresh)
	end
end

-- ——— COMBAT (empty template) ———
local combatTab = window:tab({ name = "Combat" })
do
	local column = combatTab:column()
	local sa = column:section({ name = "Silent Aim" })
	local ragebotQuickToggle = sa:toggle({ name = "Ragebot (ON / OFF)", flag = "rb_enabled_quick", default = false, tooltip = "Turn Ragebot on from the first Combat page; all Silent Aim toggles are locked ON while active", callback = function(v)
		local fn = library.config_flags and library.config_flags["rb_enabled"]
		if fn then fn(v) else flags["rb_enabled"] = v end
	end })
	OVX.ragebotQuickSync = function(value)
		if not ragebotQuickToggle then return end
		ragebotQuickToggle.state = value == true
		pcall(ragebotQuickToggle.Update, ragebotQuickToggle)
	end
	sa:toggle({ name = "Enabled", flag = "sa_enabled", default = true })
		:keybind({ name = "Silent Aim", flag = "sa_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["sa_enabled"]
			if fn then fn(v) end
		end })
	sa:toggle({ name = "Team Check", flag = "sa_team_check", default = true })
	sa:toggle({ name = "Silent Aim NPCs", flag = "sa_target_npc", default = true, tooltip = "Silent Aim lock includes Sleepers / Scientists / Animals / dummies" })
	sa:toggle({ name = "Show FOV", flag = "sa_show_fov", default = true })
	sa:toggle({ name = "Snapline", flag = "sa_snapline", default = true, tooltip = "Line from your crosshair to the silent-aim target — green when it's visible, red when covered" })
	sa:toggle({ name = "Snapline NPCs", flag = "sa_snapline_npc", default = true, tooltip = "Draw snapline / target crosshair for NPC and dummy locks" })
	sa:toggle({ name = "Target Crosshair", flag = "sa_cross", default = true, tooltip = "Draws a cross on the silent-aim target — green when it's visible, red when covered" })
	sa:dropdown({ name = "Aim Bone", flag = "sa_bone", items = { "Head", "Closest To CrossHair", "RANDOM" }, default = "Head" })
	sa:slider({ name = "FOV Radius", min = 20, max = 500, default = 120, interval = 1, flag = "sa_fov" })
	sa:slider({ name = "Max Distance", min = 0, max = 5000, default = 0, interval = 10, suffix = "m", flag = "sa_max_dist" })
	sa:slider({ name = "Scan Rate", min = 4, max = 30, default = 12, interval = 1, suffix = " Hz", flag = "sa_scan_hz", tooltip = "Lower Hz = less CPU; 12 Hz replaces the old every-other-frame Workspace:GetDescendants() scan" })
	sa:toggle({ name = "Force Head", flag = "sa_force_head", default = false, tooltip = "Ragebot forces Head regardless; leave off to use the Aim Bone dropdown" })
	sa:toggle({ name = "Instant Hit", flag = "sa_instant_hit", default = true, tooltip = "Send the rewritten shot's hit claim immediately" })
	sa:toggle({ name = "Remote Jack", flag = "sa_remote_jack", default = true, tooltip = "Use multi-method Fire/Hit/Damage remote buckets" })
	sa:button({ name = "Re-scan Remotes", callback = function()
		if OVX.saRescan then pcall(OVX.saRescan) end
	end })
	sa:dropdown({ name = "Jump To Section", flag = "ui_jump_combat",
		items = { "Silent Aim", "Weapon Mods", "Triggerbot", "Kill Aura", "Bullet Tracers", "Ragebot", "Tracer Tuning" },
		default = "Silent Aim" })
	sa:button({ name = "Open Section", callback = function()
		pcall(library.focus_section, library, "Combat", flags["ui_jump_combat"] or "Silent Aim")
	end })

	-- Bow SA shares the same "sa_enabled" toggle as firearms above.
	-- No separate bow section needed — single flag covers both.

	local wm = column:section({ name = "Weapon Mods" })
	wm:toggle({ name = "No Recoil", flag = "wm_norecoil", tooltip = "Zeroes gun recoil and bow shake" })
	wm:toggle({ name = "No Spread", flag = "wm_nospread", tooltip = "Zeroes the client spread cone. If hits stop registering, the server re-checks the cone — turn back off." })
	wm:toggle({ name = "No Sway", flag = "wm_nosway" })
	wm:toggle({ name = "Instant ADS", flag = "wm_instantads" })
	wm:toggle({ name = "Auto Fire", flag = "wm_autofire", tooltip = "Makes semi-auto weapons hold-to-fire" })
	wm:toggle({ name = "Rapid Fire", flag = "wm_rapidfire", tooltip = "Raises gun RPM and clears the bow's 0.3s shot cooldown. Server caps the real cadence." })
	wm:slider({ name = "Rapid Fire RPM", min = 100, max = 1200, default = 600, interval = 10, flag = "wm_rpm" })
	wm:toggle({ name = "Instant Charge (Bow)", flag = "wm_instantcharge", default = true, tooltip = "Forces bows to full draw — max speed/damage every shot" })
	wm:toggle({ name = "Fast Cycle", flag = "wm_fastcycle", tooltip = "Removes bolt/pump/strike delays from the viewmodel — faster follow-up shots (server still caps real cadence)" })
		:keybind({ name = "Toggle Fast Cycle", flag = "wm_fastcycle_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["wm_fastcycle"]
			if fn then fn(v) end
		end })
	wm:toggle({ name = "Range Override", flag = "wm_range", tooltip = "Max the weapon Range attribute (server may ignore)" })

	local tb = column:section({ name = "Triggerbot" })
	tb:toggle({ name = "Enabled", flag = "tb_enabled" })
		:keybind({ name = "Triggerbot", flag = "tb_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["tb_enabled"]
			if fn then fn(v) end
		end })
	tb:toggle({ name = "Triggerbot NPCs", flag = "tb_npc", default = true, tooltip = "Triggerbot fires on Sleepers / Scientists / Animals (range dummies always count)" })
	tb:toggle({ name = "Visible Only (Snapline)", flag = "tb_visible", default = true, tooltip = "Fire only when the target is inside Silent Aim's FOV and the snapline is green (clear line of sight). Turn off to ignore cover." })
	tb:toggle({ name = "Skip While Holding", flag = "tb_skip_holding", default = true, tooltip = "Pause while your own left button is down so it never fights manual fire" })
	tb:slider({ name = "Max Distance", min = 0, max = 5000, default = 0, interval = 10, suffix = "m", flag = "tb_max_dist", tooltip = "0 = use Silent Aim range; otherwise cap triggerbot acquisition at this distance" })

	-- second column: kill aura (v2.1 port) + bullet manipulation
	local column2 = combatTab:column()
	local ka = column2:section({ name = "Kill Aura" })
	ka:toggle({ name = "Enabled", flag = "ka_enabled", default = true })
		:keybind({ name = "Kill Aura", flag = "ka_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ka_enabled"]
			if fn then fn(v) end
		end })
	ka:toggle({ name = "Team Check", flag = "ka_team_check", default = true, enabled = true })
	ka:toggle({ name = "Target NPCs", flag = "ka_npc", default = true, enabled = true, tooltip = "Sleepers / Scientists / Animals / range dummies" })
	ka:slider({ name = "Range", min = 3, max = 30, default = 8, interval = 1, suffix = " studs", flag = "ka_range" })
	ka:slider({ name = "Swing Speed", min = 1, max = 20, default = 10, interval = 1, flag = "ka_speed" })


	-- Bullet Tracers now takes the old Bullet Manipulation slot so it is
	-- visible on the first Combat page.
	local bt = column2:section({ name = "Bullet Tracers" })
	bt:toggle({ name = "Enabled", flag = "sf_tracers_enabled", tooltip = "Muzzle-to-impact Sci-Fi beams; independent of Silent Aim and player ESP tracers" })
	bt:toggle({ name = "Use Tracer Preset", flag = "sf_tracer_use_preset", default = true, tooltip = "Use one of the eight Sci-Fi presets instead of the custom tracer color" })
	bt:dropdown({ name = "Tracer Preset", flag = "sf_tracer_preset", items = OVX.sciFiPresetNames, default = "Cyan" })
	bt:colorpicker({ name = "Tracer Color", flag = "sf_tracer_color", color = c3(0,255,255) })
	bt:toggle({ name = "Impact Markers", flag = "sf_tracer_impact_enabled", default = true })
	bt:colorpicker({ name = "Impact Color", flag = "sf_tracer_impact_color", color = c3(0,255,255) })
	bt:slider({ name = "Impact Size", min = 0.05, max = 3, default = 0.3, interval = 0.05, flag = "sf_tracer_impact_size" })
	bt:button({ name = "Test Tracer", callback = function()
		if OVX.fireTestTracer then pcall(OVX.fireTestTracer) end
	end })

	local column3 = combatTab:column()
	local rage = column3:section({ name = "Ragebot" })
	rage:toggle({ name = "Ragebot", flag = "rb_enabled", tooltip = "Locks all Silent Aim toggles ON, forces Head, disables Bow Lead & Arc, and removes the FOV limit", callback = function(v)
		if OVX.ragebotApply then pcall(OVX.ragebotApply, v) end
	end })
	rage:slider({ name = "Hit Distance", min = 0, max = 5000, default = 0, interval = 10, suffix = "m", flag = "rb_max_dist", tooltip = "0 = unlimited; otherwise the maximum Ragebot acquisition distance" })
	rage:slider({ name = "FOV Radius", min = 1000, max = 50000, default = 10000, interval = 100, suffix = " px", flag = "rb_fov_radius", tooltip = "Extended acquisition radius; Ragebot also ranks behind-camera targets by 3D distance" })
	rage:label("FOV: 1000+ px • ALL HEADS • SA + Gun Mods + Triggerbot locked ON")
	rage:label("Max Rapid Fire 1200 RPM • Bow Lead & Arc forced OFF")
	rage:button({ name = "Re-apply Ragebot State", callback = function()
		if flags["rb_enabled"] and OVX.ragebotSync then pcall(OVX.ragebotSync) end
	end })
	rage:button({ name = "Back To Silent Aim", callback = function()
		pcall(library.focus_section, library, "Combat", "Silent Aim")
	end })
	local btTune = column3:section({ name = "Tracer Tuning" })
	btTune:slider({ name = "Beam Width", min = 0.02, max = 3, default = 0.2, interval = 0.02, flag = "sf_tracer_width" })
	btTune:slider({ name = "Beam Lifetime", min = 0.03, max = 3, default = 0.25, interval = 0.01, suffix = "s", flag = "sf_tracer_lifetime" })
	btTune:slider({ name = "Beam Segments", min = 1, max = 20, default = 1, interval = 1, flag = "sf_tracer_segments" })
	btTune:slider({ name = "Beam Glow", min = 0, max = 10, default = 5, interval = 1, suffix = "/10", flag = "sf_tracer_glow" })
	btTune:slider({ name = "Light Influence", min = 0, max = 10, default = 0, interval = 1, suffix = "/10", flag = "sf_tracer_light_influence" })
	btTune:toggle({ name = "Face Camera", flag = "sf_tracer_face_camera", default = true })
	btTune:slider({ name = "Max Active Beams", min = 1, max = 80, default = 24, interval = 1, flag = "sf_tracer_max" })
	btTune:slider({ name = "Tracer Range", min = 50, max = 5000, default = 1000, interval = 50, suffix = "m", flag = "sf_tracer_range" })
	btTune:toggle({ name = "Use Muzzle Position", flag = "sf_tracer_use_muzzle", default = true })
	btTune:toggle({ name = "Follow Silent Aim Target", flag = "sf_tracer_follow_sa", default = true })
	btTune:toggle({ name = "Raycast Impacts", flag = "sf_tracer_raycast", default = true })
	btTune:toggle({ name = "Include Bow Shots", flag = "sf_tracer_include_bow", default = true })
	btTune:toggle({ name = "Double-Gun Tracers", flag = "sf_tracer_double_gun", default = true })
end

	-- Bullet Manipulation was removed from the UI, but its logic and config
	-- flags stay available for configs and console use.
	registerFlagSetter("bp_enabled", function(value) flags["bp_enabled"] = value end)
	registerFlagSetter("bp_desync", function(value) flags["bp_desync"] = value end)
	registerFlagSetter("bp_max_offset", function(value) flags["bp_max_offset"] = value end)
	registerFlagSetter("pkt_nospread", function(value) flags["pkt_nospread"] = value end)
	registerFlagSetter("sa_bow_lead", function(value) flags["sa_bow_lead"] = value end)
	registerFlagSetter("sa_bow_enabled", function(value) flags["sa_bow_enabled"] = enforceRagebotFlag("sa_bow_enabled", value) end)
	registerFlagSetter("traj_arc", function(value) flags["traj_arc"] = value end)

-- ——— SOUNDS (v2.1 port: hitsounds on the server's HitMarker) ———
local soundsTab = window:tab({ name = "Sounds" })
do
	local col = soundsTab:column()
	local HS_NAMES = { "Amongus", "Ara", "Cod", "Coin", "Csgo", "Fatality", "Gamesense", "Landing",
		"Neverlose", "Noname", "Parry", "Rifk7", "Rust", "Snap", "Uwu" }
	for _, cat in ipairs({
		{ id = "head", label = "Head", dflt = "Neverlose" },
		{ id = "body", label = "Body", dflt = "Cod" },
		{ id = "kill", label = "Kill", dflt = "Landing" },
	}) do
		local sec = col:section({ name = cat.label .. " Sound" })
		sec:toggle({ name = "Enabled", flag = "hs_" .. cat.id .. "_enabled" })
		sec:dropdown({ name = "Sound", flag = "hs_" .. cat.id .. "_sound", items = HS_NAMES, default = cat.dflt })
		sec:slider({ name = "Volume", min = 1, max = 10, default = 10, interval = 1, suffix = "/10", flag = "hs_" .. cat.id .. "_volume" })
		sec:slider({ name = "Pitch", min = 1, max = 20, default = 10, interval = 1, suffix = "/10", flag = "hs_" .. cat.id .. "_pitch" })
		sec:button_holder({})
		sec:button({ name = "Preview", callback = function()
			if OVX.hsPreview then
				OVX.hsPreview(flags["hs_" .. cat.id .. "_sound"] or cat.dflt,
					(tonumber(flags["hs_" .. cat.id .. "_volume"]) or 10) / 10,
					(tonumber(flags["hs_" .. cat.id .. "_pitch"]) or 10) / 10)
			end
		end })
	end
end

-- ——— VISUALS (player ESP) ———
local visualsTab = window:tab({ name = "Visuals" })
do
	local column = visualsTab:column()
	local section = column:section({ name = "Player ESP" })

	section:toggle({ name = "Enabled", flag = "Enabled", default = true, callback = update_elements })
	section:toggle({ name = "Team Check", flag = "esp_team_check" })
	section:slider({ name = "Max Distance", min = 0, max = 2000, default = 0, interval = 10, suffix = "m", flag = "esp_max_dist" })
	section:toggle({ name = "Boxes", flag = "Boxes", default = true, callback = update_elements })
		:colorpicker({ name = "Box Color", flag = "Box_Color", color = c3(255,255,255), callback = update_elements })
	section:dropdown({ name = "Box Type", flag = "Box_Type", items = { "Full", "Corner" }, default = "Full", callback = update_elements })

	section:toggle({ name = "Filled Box", flag = "esp_filled_box" })
		:colorpicker({ name = "Fill Color", flag = "esp_filled_color", color = c3(255,255,255) })
	section:slider({ name = "Fill Transparency", min = 1, max = 9, default = 6, interval = 1, suffix = "/10", flag = "esp_filled_transparency" })

	section:toggle({ name = "Names", flag = "Names", default = true, callback = update_elements })
		:colorpicker({ name = "Name Color", flag = "Name_Color", color = c3(255,255,255), callback = update_elements })
	section:toggle({ name = "Display Names", flag = "esp_display_names", default = true })

	section:toggle({ name = "Healthbar", flag = "Healthbar", default = true, callback = update_elements })
		:colorpicker({ name = "High HP Color", flag = "Health_High", color = c3(0,255,0), callback = update_elements })
		:colorpicker({ name = "Low HP Color", flag = "Health_Low", color = c3(255,0,0), callback = update_elements })
	section:toggle({ name = "Health Text", flag = "esp_health_text" })

	section:toggle({ name = "Distance", flag = "Distance", default = true, callback = update_elements })
		:colorpicker({ name = "Distance Color", flag = "Distance_Color", color = c3(200,200,200), callback = update_elements })

	section:toggle({ name = "Weapon", flag = "Weapon", callback = update_elements })
		:colorpicker({ name = "Weapon Color", flag = "Weapon_Color", color = c3(255,220,80), callback = update_elements })
	section:toggle({ name = "2D ESP Preview", flag = "esp_preview_2d", default = true, callback = update_elements, tooltip = "Live Drawing panel beside the Vault window" })
	section:toggle({ name = "3D Preview On Self", flag = "esp_self_preview_3d", default = true, callback = update_elements, tooltip = "Live box, highlight and health/name billboard attached to your own character" })
	section:slider({ name = "3D Preview Rate", min = 2, max = 20, default = 10, interval = 1, suffix = " Hz", flag = "esp_self_preview_hz" })
	section:button({ name = "Refresh ESP Previews", callback = update_elements })
	section:dropdown({ name = "Jump To Section", flag = "ui_jump_visuals",
		items = { "Player ESP", "Extra", "ESP Fine Tuning", "Hand Chams", "Gun Chams", "Viewmodel Shared", "Skin Changer", "Skin Diagnostics" },
		default = "Player ESP" })
	section:button({ name = "Open Section", callback = function()
		pcall(library.focus_section, library, "Visuals", flags["ui_jump_visuals"] or "Player ESP")
	end })

	-- extra ESP controls not mirrored in the preview panel
	local column2 = visualsTab:column()
	local extra = column2:section({ name = "Extra" })

	extra:toggle({ name = "Tracers", flag = "esp_tracers" })
		:colorpicker({ name = "Tracer Color", flag = "esp_tracer_color", color = c3(255,255,255) })
	extra:dropdown({ name = "Tracer Origin", flag = "esp_tracer_origin", items = { "Bottom", "Center", "Top" }, default = "Bottom" })

	extra:toggle({ name = "View Angle", flag = "esp_view_angle" })
		:colorpicker({ name = "VA Color", flag = "esp_viewangle_color", color = c3(255,255,255) })
	extra:slider({ name = "VA Size", min = 3, max = 30, default = 10, interval = 1, flag = "esp_viewangle_size" })

	extra:toggle({ name = "Chams", flag = "esp_chams" })
		:colorpicker({ name = "Cham Fill", flag = "esp_cham_fill_color", color = c3(255,255,255) })
		:colorpicker({ name = "Cham Outline", flag = "esp_cham_outline_color", color = c3(0,0,0) })
	extra:slider({ name = "Cham Fill Transp", min = 0, max = 10, default = 4, interval = 1, suffix = "/10", flag = "esp_cham_fill_transparency" })
	extra:slider({ name = "Cham Out Transp", min = 0, max = 10, default = 0, interval = 1, suffix = "/10", flag = "esp_cham_outline_transparency" })

	local column3 = visualsTab:column()
	local fine = column3:section({ name = "ESP Fine Tuning" })
	fine:toggle({ name = "Box Outline", flag = "esp_box_outline", default = true })
	fine:slider({ name = "Box Thickness", min = 1, max = 6, default = 1, interval = 1, flag = "esp_box_thickness" })
	fine:toggle({ name = "Health Bar Outline", flag = "esp_health_outline", default = true })
	fine:dropdown({ name = "Health Bar Position", flag = "esp_health_position", items = { "Left", "Top" }, default = "Left" })
	fine:toggle({ name = "Health Text Gradient", flag = "esp_health_text_gradient", tooltip = "Color health percentage with the same custom low/high HSV gradient" })
	fine:colorpicker({ name = "Health Text Color", flag = "esp_health_text_color", color = c3(255,255,255) })
	fine:dropdown({ name = "ESP Font", flag = "esp_font", items = { "UI", "System", "Plex", "Monospace" }, default = "Plex" })
	fine:slider({ name = "ESP Font Size", min = 8, max = 24, default = 13, interval = 1, suffix = " px", flag = "esp_font_size" })
	fine:toggle({ name = "Chams Visibility Check", flag = "esp_cham_vis_check", tooltip = "Green/visible and red/covered colors use pooled line-of-sight raycasts" })
	fine:colorpicker({ name = "Visible Cham Color", flag = "esp_cham_vis_color", color = c3(0,255,0) })
	fine:colorpicker({ name = "Covered Cham Color", flag = "esp_cham_invis_color", color = c3(255,0,0) })

	local column4 = visualsTab:column()
	local hands = column4:section({ name = "Hand Chams" })
	hands:toggle({ name = "Hand Chams", flag = "sf_hands_enabled" })
	hands:dropdown({ name = "Hand Material", flag = "sf_hand_material", items = OVX.sciFiMaterials, default = "ForceField" })
	hands:toggle({ name = "Use Hand Preset", flag = "sf_hand_use_preset", default = true })
	hands:dropdown({ name = "Hand Preset", flag = "sf_hand_preset", items = OVX.sciFiPresetNames, default = "Cyan" })
	hands:colorpicker({ name = "Hand Custom Color", flag = "sf_hand_color", color = c3(0,255,255) })
	hands:slider({ name = "Hand Transparency", min = 0, max = 10, default = 0, interval = 1, suffix = "/10", flag = "sf_hand_transparency" })
	hands:slider({ name = "Hand Reflectance", min = 0, max = 10, default = 2, interval = 1, suffix = "/10", flag = "sf_hand_reflectance" })

	local guns = column4:section({ name = "Gun Chams" })
	guns:toggle({ name = "Gun Chams", flag = "sf_gun_enabled" })
	guns:dropdown({ name = "Gun Material", flag = "sf_gun_material", items = OVX.sciFiMaterials, default = "ForceField" })
	guns:toggle({ name = "Use Gun Preset", flag = "sf_gun_use_preset", default = true })
	guns:dropdown({ name = "Gun Preset", flag = "sf_gun_preset", items = OVX.sciFiPresetNames, default = "Cyan" })
	guns:colorpicker({ name = "Gun Custom Color", flag = "sf_gun_color", color = c3(0,255,255) })
	guns:slider({ name = "Gun Transparency", min = 0, max = 10, default = 0, interval = 1, suffix = "/10", flag = "sf_gun_transparency" })
	guns:slider({ name = "Gun Reflectance", min = 0, max = 10, default = 2, interval = 1, suffix = "/10", flag = "sf_gun_reflectance" })

	local column5 = visualsTab:column()
	local shared = column5:section({ name = "Viewmodel Shared" })
	shared:toggle({ name = "Protect Muzzle / Flash", flag = "sf_protect_muzzle", default = true, tooltip = "Never cham muzzle, flash, smoke, beam or particle parts" })
	shared:toggle({ name = "Double-Gun Fix", flag = "sf_double_gun_fix", default = true })
	shared:slider({ name = "Viewmodel Refresh Rate", min = 1, max = 20, default = 5, interval = 1, suffix = " Hz", flag = "sf_vmodel_refresh_hz" })

	local skin = column5:section({ name = "Skin Changer" })
	skin:toggle({ name = "Skin Changer", flag = "skin_enabled", default = true })
	skin:dropdown({ name = "Apply Scope", flag = "skin_apply_mode", items = { "Selected Gun", "All Guns" }, default = "Selected Gun" })
	local skinWeaponDropdown = skin:dropdown({
		name = "Weapon", flag = "skin_weapon", items = OVX.skinGetWeapons(), default = "Assault Rifle",
		callback = function()
			local fn = library.config_flags["skin_weapon_custom"]
			if fn then pcall(fn, "") else flags["skin_weapon_custom"] = "" end
		end,
	})
	local skinSkinDropdown = skin:dropdown({
		name = "Skin", flag = "skin_skin", items = OVX.skinGetSkins(), default = "Tempered",
		callback = function()
			local fn = library.config_flags["skin_skin_custom"]
			if fn then pcall(fn, "") else flags["skin_skin_custom"] = "" end
		end,
	})
	skin:textbox({ name = "Custom Weapon Name", flag = "skin_weapon_custom", default = "", tooltip = "Overrides the weapon dropdown for SetSkin / per-gun apply" })
	skin:textbox({ name = "Custom Skin Name", flag = "skin_skin_custom", default = "", tooltip = "Overrides the skin dropdown; discovered asset names also appear here" })
	skin:button({ name = "Apply Skin", callback = function() if OVX.skinApplyMode then pcall(OVX.skinApplyMode) end end })
	skin:button({ name = "Apply All Guns", callback = function() if OVX.skinApplyAll then pcall(OVX.skinApplyAll) end end })
	skin:button({ name = "Reset Selected Gun", callback = function() if OVX.skinResetWeapon then pcall(OVX.skinResetWeapon) end end })
	skin:button({ name = "Reset All Guns", callback = function() if OVX.skinResetAll then pcall(OVX.skinResetAll) end end })
	skin:button({ name = "Print Skin Map", callback = function() if OVX.skinPrintConfig then pcall(OVX.skinPrintConfig) end end })
	skin:toggle({ name = "Auto Reapply", flag = "skin_auto_reapply", default = true })
	skin:slider({ name = "Reapply Delay", min = 0, max = 1, default = 0.05, interval = 0.05, suffix = "s", flag = "skin_delay" })

	local column6 = visualsTab:column()
	local skinDiag = column6:section({ name = "Skin Diagnostics" })
	skinDiag:toggle({ name = "Discover Asset Names", flag = "skin_discover_assets", default = true })
	skinDiag:slider({ name = "Asset Scan Limit", min = 100, max = 5000, default = 1200, interval = 100, flag = "skin_asset_limit" })
	skinDiag:slider({ name = "Asset Search Depth", min = 2, max = 8, default = 5, interval = 1, flag = "skin_asset_depth" })
	skinDiag:dropdown({ name = "Fallback Material", flag = "skin_fallback_material", items = OVX.sciFiMaterials, default = "ForceField" })
	skinDiag:colorpicker({ name = "Fallback Color", flag = "skin_fallback_color", color = c3(255,180,80) })
	skinDiag:slider({ name = "Fallback Transparency", min = 0, max = 10, default = 0, interval = 1, suffix = "/10", flag = "skin_fallback_transparency" })
	skinDiag:slider({ name = "Fallback Reflectance", min = 0, max = 10, default = 2, interval = 1, suffix = "/10", flag = "skin_fallback_reflectance" })
	skinDiag:toggle({ name = "Debug Prints", flag = "skin_debug", tooltip = "Print every SetSkin / SetAllSkins / ResetSkins call to the executor console" })
	skinDiag:button({ name = "Refresh Skin Lists", callback = function() if OVX.skinRefreshUI then pcall(OVX.skinRefreshUI) end end })
	OVX.skinRefreshUI = function()
		pcall(function()
			skinWeaponDropdown:Refresh(OVX.skinGetWeapons())
			skinWeaponDropdown:Update()
		end)
		pcall(function()
			skinSkinDropdown:Refresh(OVX.skinGetSkins())
			skinSkinDropdown:Update()
		end)
	end

end

-- ——— WORLD (nodes / loot / mobs / vehicles / events) ———
local worldTab = window:tab({ name = "World" })
do
	local SECTION_COL = { General = 1, Nodes = 1, Pickups = 1, Loot = 1, Mobs = 2, ["World Items"] = 2, Vehicles = 2, Events = 3 }
	local cols = { worldTab:column(), worldTab:column(), worldTab:column() }
	local sections = {}
	local function getSection(name)
		if not sections[name] then
			sections[name] = cols[SECTION_COL[name] or 1]:section({ name = name })
		end
		return sections[name]
	end
	-- General: master toggle + keybind + font size
	local gen = getSection("General")
	gen:toggle({ name = "Enabled", flag = "w_enabled" })
		:keybind({ name = "World ESP", flag = "w_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["w_enabled"]
			if fn then fn(v) end
		end })
	gen:slider({ name = "Font Size", min = 8, max = 24, default = 13, interval = 1, flag = "w_font" })
	-- one toggle + distance slider per category
	for _, cat in ipairs(WORLD_CATS) do
		local s = getSection(cat.sec)
		s:toggle({ name = cat.label, flag = cat.flag })
		s:slider({ name = cat.label .. " Dist", min = 0, max = 3000, default = cat.dd, interval = 10, suffix = "m", flag = cat.dist })
	end

	-- auto farm nodes (weakspot-aware): auto-equips a melee tool, strikes active
	-- ChopMark weakspots at their mark position, instant swing on by default
	local afSec = cols[1]:section({ name = "Auto Farm" })
	afSec:toggle({ name = "Enabled", flag = "af_enabled", default = true })
		:keybind({ name = "Auto Farm", flag = "af_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["af_enabled"]
			if fn then fn(v) end
		end })
	afSec:toggle({ name = "Auto Equip Tool", flag = "af_autoequip", default = true, enabled = true })
	afSec:toggle({ name = "Instant Swing", flag = "af_instant", default = true, enabled = true, tooltip = "Lowers held melee SwingTime to 0.3" })
	afSec:dropdown({ name = "Node Filter", flag = "af_filter",
		items = { "All", "Ore", "Trees", "Stone", "Metal", "Sulfur", "Boulders", "Hemp", "Crops" }, default = "All" })
	afSec:dropdown({ name = "Node Types", flag = "af_nodes", multi = true,
		items = { "Trees", "Stone", "Metal", "Sulfur", "Boulders", "Hemp", "Crops" },
		callback = function(sel)
			local list = type(sel) == "table" and sel or (sel and { sel } or {})
			if #list > 0 then
				local fn = library.config_flags and library.config_flags["af_filter"]
				if fn then pcall(fn, "All") else flags["af_filter"] = "All" end
			end
		end })
	afSec:slider({ name = "Range", min = 5, max = 60, default = 12, interval = 1, suffix = " studs", flag = "af_range" })
	afSec:slider({ name = "Swing Speed", min = 1, max = 20, default = 10, interval = 1, flag = "af_speed" })
end

-- ——— MISC (Speed / Phase / Spider / Freecam — vape v4 port) ———
local miscTab = window:tab({ name = "Misc" })
do
	local column = miscTab:column()

	local spSec = column:section({ name = "Speed" })
	spSec:toggle({ name = "Enabled", flag = "spd_enabled", callback = function(v)
		if setSpeed then pcall(setSpeed, v) end
	end })
		:keybind({ name = "Speed", flag = "spd_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["spd_enabled"]
			if fn then fn(v) end
		end })
	spSec:dropdown({ name = "Mode", flag = "spd_mode", items = { "Velocity" }, default = "Velocity", callback = function()
		if flags["spd_enabled"] then setSpeed(false); setSpeed(true) end
	end })
	spSec:dropdown({ name = "Move Mode", flag = "spd_movemode", items = { "MoveDirection", "Direct" }, default = "MoveDirection" })
	spSec:slider({ name = "Speed", min = 1, max = 150, default = 50, interval = 1, suffix = " studs", flag = "spd_value" })
	spSec:toggle({ name = "Custom Properties", flag = "spd_custom", default = true, callback = function()
		if flags["spd_enabled"] then setSpeed(false); setSpeed(true) end
	end })

	local phSec = column:section({ name = "Phase" })
	phSec:toggle({ name = "Enabled", flag = "ph_enabled", tooltip = "Phase/Clip through walls. (Hold Left Shift to use Phase over Spider)", callback = function(v)
		if setPhase then pcall(setPhase, v) end
	end })
		:keybind({ name = "Phase", flag = "ph_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ph_enabled"]
			if fn then fn(v) end
		end })
	phSec:dropdown({ name = "Mode", flag = "ph_mode", items = { "Part", "Character", "CFrame", "Motor", "FFlag" }, default = "Part", callback = function()
		if flags["ph_enabled"] then setPhase(false); setPhase(true) end
	end })
	phSec:slider({ name = "Wall Size", min = 1, max = 20, default = 5, interval = 1, suffix = " studs", flag = "ph_wall" })

	local spSec2 = column:section({ name = "Spider" })
	spSec2:toggle({ name = "Enabled", flag = "sp_enabled", tooltip = "Lets you climb up obstacles. (Hold Left Shift to use Phase over Spider)", callback = function(v)
		if setSpider then pcall(setSpider, v) end
	end })
		:keybind({ name = "Spider", flag = "sp_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["sp_enabled"]
			if fn then fn(v) end
		end })
	spSec2:dropdown({ name = "Mode", flag = "sp_mode", items = { "Velocity", "Impulse", "CFrame", "Part" }, default = "Velocity", callback = function(val)
		spiderTruss(val)
		if flags["sp_enabled"] then setSpider(false); setSpider(true) end
	end })
	spSec2:slider({ name = "Speed", min = 0, max = 100, default = 30, interval = 1, suffix = " studs", flag = "sp_speed" })
	spSec2:toggle({ name = "Climb State", flag = "sp_state", default = true })

	local fcSec = column:section({ name = "Freecam" })
	fcSec:toggle({ name = "Enabled", flag = "fc_enabled", callback = function(v)
		if setFreecam then pcall(setFreecam, v) end
	end })
		:keybind({ name = "Freecam", flag = "fc_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["fc_enabled"]
			if fn then fn(v) end
		end })
	fcSec:dropdown({ name = "Mode", flag = "fc_mode", items = { "Classic", "Roblox" }, default = "Classic", callback = function()
		if flags["fc_enabled"] then setFreecam(false); setFreecam(true) end
	end })
	fcSec:slider({ name = "Speed", min = 1, max = 150, default = 50, interval = 1, suffix = " studs", flag = "fc_speed" })

	-- draggable guide window (toggle to open/close)
	local gdCol = miscTab:column()
	local gd = gdCol:section({ name = "Noclip Guide" })
	gd:toggle({ name = "Guide UI", flag = "gd_open", default = false, callback = function(v)
		guideGui.Enabled = v
	end })

	local uiSec = gdCol:section({ name = "Interface" })
	uiSec:label("Window size, menu key, themes and configs are in Settings.")


	-- desync (v2.1 port) + overlay windows
	local dcol = miscTab:column()
	local dsSec = dcol:section({ name = "Desync" })
	dsSec:toggle({ name = "Enabled", flag = "ds_enabled" })
		:keybind({ name = "Desync", flag = "ds_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ds_enabled"]
			if fn then fn(v) end
		end })
	dsSec:dropdown({ name = "Preset", flag = "ds_preset",
		items = { "Semi-underground (best)", "Deep underground", "Rotation only (stealth)" },
		default = "Semi-underground (best)", callback = function(v)
			if OVX.desyncPreset then pcall(OVX.desyncPreset, v) end
		end })
	dsSec:toggle({ name = "Position Spoof", flag = "ds_pos", default = true, enabled = true })
	dsSec:toggle({ name = "Rotation Spoof", flag = "ds_rot", default = true, enabled = true })
	dsSec:toggle({ name = "Visualizer", flag = "ds_vis", tooltip = "Shows a ghost clone where the server sees you" })
	dsSec:toggle({ name = "Fake Anim", flag = "ds_anim" })
	dsSec:toggle({ name = "Freeze Anim", flag = "ds_animfreeze" })
	dsSec:toggle({ name = "Velocity Poison", flag = "ds_velocity", tooltip = "Rubberband risk — OFF by default" })
	dsSec:dropdown({ name = "Vel Type", flag = "ds_veltype", items = { "low", "high", "high y", "limit" }, default = "low" })
	dsSec:slider({ name = "Offset X", min = -10, max = 10, default = 0, interval = 0.1, flag = "ds_ox" })
	dsSec:slider({ name = "Offset Y", min = -10, max = 10, default = -2.4, interval = 0.1, flag = "ds_oy" })
	dsSec:slider({ name = "Offset Z", min = -10, max = 10, default = 0, interval = 0.1, flag = "ds_oz" })
	dsSec:slider({ name = "Rotation X", min = -180, max = 180, default = 90, interval = 1, suffix = "°", flag = "ds_rx" })
	dsSec:slider({ name = "Rotation Y", min = -180, max = 180, default = 0, interval = 1, suffix = "°", flag = "ds_ry" })
	dsSec:slider({ name = "Rotation Z", min = -180, max = 180, default = 0, interval = 1, suffix = "°", flag = "ds_rz" })

	local ovSec = dcol:section({ name = "Overlays" })
	ovSec:toggle({ name = "Crosshair Info", flag = "hud_targetinfo", default = true, enabled = true })
	ovSec:toggle({ name = "Inventory Viewer", flag = "invwin_enabled" })
	ovSec:toggle({ name = "Staff Panel", flag = "staffwin_enabled", default = true, enabled = true })
end

-- ——— EXPLOIT TAB (all features with self-explanatory keybinds) ———
do
	local exTab = window:tab({ name = "Exploit" })
	local function kb(section, label, flag, target)
		section:keybind({ name = label, flag = flag, callback = function(v)
			if target and v then
				local fn = library.config_flags and library.config_flags[target]
				if fn then fn(v) else flags[target] = v end
			end
		end })
	end
	local surv = exTab:column():section({ name = "Survival" })
	surv:toggle({ name = "Auto Heal", flag = "ex_heal", tooltip = "Uses a med item when HP drops below the threshold" })
		:keybind({ name = "Toggle Auto Heal", flag = "ex_heal_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ex_heal"]
			if fn then fn(v) end
		end })
	surv:slider({ name = "Heal At HP %", min = 10, max = 95, default = 60, interval = 5, suffix = "%", flag = "ex_heal_hp" })
	surv:toggle({ name = "Auto Parachute", flag = "ex_para", tooltip = "Deploys when falling from a high altitude" })
		:keybind({ name = "Toggle Auto Parachute", flag = "ex_para_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ex_para"]
			if fn then fn(v) end
		end })
	surv:slider({ name = "Deploy Altitude", min = 10, max = 200, default = 30, interval = 5, suffix = "m", flag = "ex_para_alt" })
	surv:toggle({ name = "Auto Shield", flag = "ex_shield" })
		:keybind({ name = "Toggle Auto Shield", flag = "ex_shield_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ex_shield"]
			if fn then fn(v) end
		end })

	local farm = exTab:column():section({ name = "Farming" })
	farm:toggle({ name = "Auto Barrel Smash", flag = "ex_barrel", tooltip = "Swings barrels/crates for scrap and loot" })
		:keybind({ name = "Toggle Barrel Smash", flag = "ex_barrel_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ex_barrel"]
			if fn then fn(v) end
		end })
	farm:slider({ name = "Barrel Range", min = 5, max = 30, default = 10, interval = 1, suffix = " studs", flag = "ex_barrel_range" })

	local guns = exTab:column():section({ name = "Guns" })
	guns:toggle({ name = "Auto Reload", flag = "ex_reload" })
		:keybind({ name = "Toggle Auto Reload", flag = "ex_reload_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ex_reload"]
			if fn then fn(v) end
		end })
	guns:keybind({ name = "Switch Ammo", flag = "ex_ammo_bind", callback = function(v)
		if v and OVX.exAmmo then pcall(OVX.exAmmo) end
	end })

	local move = exTab:column():section({ name = "Movement" })
	move:toggle({ name = "Vehicle Boost", flag = "ex_vehicle", tooltip = "Raises SpeedMult / Walk / Jump on the vehicle you sit in" })
		:keybind({ name = "Toggle Vehicle Boost", flag = "ex_vehicle_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ex_vehicle"]
			if fn then fn(v) end
		end })
	move:slider({ name = "Vehicle Multiplier", min = 1, max = 8, default = 2, interval = 0.5, flag = "ex_vehicle_mult" })
	move:slider({ name = "Vehicle Walk", min = 7, max = 60, default = 7, interval = 1, flag = "ex_vehicle_walk" })
	move:slider({ name = "Vehicle Jump", min = 25, max = 120, default = 25, interval = 5, flag = "ex_vehicle_jump" })

	local util = exTab:column():section({ name = "Utility" })
	util:toggle({ name = "Auto Metal Scan", flag = "ex_metal", tooltip = "Keeps the metal detector scanning; signal strength in OVX.metalStrength" })
		:keybind({ name = "Toggle Metal Scan", flag = "ex_metal_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["ex_metal"]
			if fn then fn(v) end
		end })
	util:keybind({ name = "Instant Wake", flag = "ex_wake_bind", callback = function(v)
		if v and OVX.exWake then pcall(OVX.exWake) end
	end })
end


-- ——— SETTINGS (configs, auto load, UI essentials) ———
do
	local settingsTab = window:tab({ name = "Settings" })
	local CFG_FOLDER = "OVX/Configs"
	local CFG_AUTO = "OVX/autoload.json"
	local http = game:GetService("HttpService")

	local function notify(text)
		pcall(function() library:notification({ text = text, time = 2.5 }) end)
	end
	local function cleanName(name)
		name = tostring(name or "Default"):gsub("[^%w%-%_ ]", "_")
		if name == "" then name = "Default" end
		return name
	end
	local function ensureFolder()
		pcall(makefolder, "OVX")
		pcall(makefolder, CFG_FOLDER)
	end
	local function configPath(name)
		return CFG_FOLDER .. "/" .. cleanName(name) .. ".json"
	end
	local function listConfigs()
		local out = {}
		local ok, files = pcall(listfiles, CFG_FOLDER)
		if ok and type(files) == "table" then
			for _, path in ipairs(files) do
				local base = tostring(path):match("([^/\\]+)%.json$")
				if base then out[#out + 1] = base end
			end
		end
		table.sort(out)
		if #out == 0 then out[1] = "Default" end
		return out
	end
	local function readAuto()
		local ok, data = pcall(readfile, CFG_AUTO)
		if not ok or type(data) ~= "string" or data == "" then return nil end
		local decodedOk, decoded = pcall(function() return http:JSONDecode(data) end)
		if decodedOk and type(decoded) == "table" then return decoded end
		return nil
	end
	local function saveAuto(enabled, name)
		ensureFolder()
		local ok, encoded = pcall(function()
			return http:JSONEncode({ enabled = enabled == true, name = cleanName(name) })
		end)
		if not ok then return false end
		pcall(writefile, CFG_AUTO, encoded)
		return true
	end
	local function saveConfig(name)
		name = cleanName(name)
		ensureFolder()
		local json = library:get_config()
		local ok = pcall(writefile, configPath(name), json)
		if not ok then notify("Could not save config: " .. name); return false end
		notify("Saved config: " .. name)
		return true
	end
	local function loadConfig(name)
		name = cleanName(name)
		local ok, data = pcall(readfile, configPath(name))
		if not ok or type(data) ~= "string" or data == "" then
			notify("Config not found: " .. name)
			return false
		end
		local loaded = library:load_config(data)
		if loaded and OVX.refreshAllVisuals then pcall(OVX.refreshAllVisuals) end
		notify(loaded and ("Loaded config: " .. name) or ("Invalid config: " .. name))
		return loaded
	end
	OVX.configList = listConfigs
	OVX.configSave = saveConfig
	OVX.configLoad = loadConfig
	OVX.configReadAuto = readAuto
	OVX.configSaveAuto = saveAuto
	OVX.configPath = configPath

	local col1 = settingsTab:column()
	local configs = col1:section({ name = "Configs" })
	local cfgDropdown
	configs:textbox({ name = "Config Name", flag = "cfg_name", default = "Default", callback = function(value)
		if flags["cfg_auto_load"] == true then saveAuto(true, value) end
	end })
	cfgDropdown = configs:dropdown({ name = "Saved Configs", flag = "cfg_selected", items = listConfigs(), default = "Default" })
	configs:button({ name = "Save Config", callback = function()
		if saveConfig(flags["cfg_name"] or "Default") then
			pcall(function() cfgDropdown:Refresh(listConfigs()); cfgDropdown:Update() end)
		end
	end })
	configs:button({ name = "Load Config", callback = function()
		loadConfig(flags["cfg_selected"] or flags["cfg_name"] or "Default")
	end })
	configs:button({ name = "Use Selected Name", callback = function()
		local name = flags["cfg_selected"] or "Default"
		local setter = library.config_flags["cfg_name"]
		if setter then pcall(setter, name) else flags["cfg_name"] = name end
	end })
	configs:toggle({ name = "Auto Load Config", flag = "cfg_auto_load", tooltip = "Loads the selected config shortly after every execution", callback = function(v)
		saveAuto(v, flags["cfg_name"] or "Default")
	end })
	configs:button({ name = "Refresh Config List", callback = function()
		pcall(function() cfgDropdown:Refresh(listConfigs()); cfgDropdown:Update() end)
	end })
	configs:dropdown({ name = "Jump To Section", flag = "ui_jump_settings", items = { "Configs", "Interface", "UI Essentials" }, default = "Configs" })
	configs:button({ name = "Open Section", callback = function()
		pcall(library.focus_section, library, "Settings", flags["ui_jump_settings"] or "Configs")
	end })
	configs:label("Configs are stored in OVX/Configs as JSON.")

	local col2 = settingsTab:column()
	local interface = col2:section({ name = "Interface" })
	interface:toggle({ name = "Always On: Fix Color Picker", flag = "ui_modal_guard", default = true, tooltip = "Always-on guard closes stuck color pickers, dropdowns, textboxes and keybind mode menus on right-click / Escape" })
	interface:toggle({ name = "Free Mouse", flag = "ui_free_mouse", default = true, tooltip = "Releases the cursor while the Vault menu is open so controls can be clicked", callback = function(v)
		if window._compatSetMenuVisible then
			pcall(window._compatSetMenuVisible, library.menu_visible == true, v ~= false)
		end
	end })
	interface:keybind({ name = "Menu Key", flag = "ui_menu_key", def = "Insert", mode = "toggle", tooltip = "RightShift remains a built-in fallback menu key" })
	local uiScreen = utility:ScreenSize()
	local maxW = math.max(500, math.floor(uiScreen.X - 80))
	local maxH = math.max(420, math.floor(uiScreen.Y - 80))
	local initW = math.floor(window.frame.Size.X)
	local initH = math.floor(window.frame.Size.Y)
	local function applyUiSize()
		local w = tonumber(flags["ui_width"]) or initW
		local h = tonumber(flags["ui_height"]) or initH
		if window.resize then window:resize(w, h) end
	end
	interface:slider({ name = "Window Width", min = 500, max = maxW, default = initW, interval = 10, suffix = " px", flag = "ui_width", callback = applyUiSize })
	interface:slider({ name = "Window Height", min = 420, max = maxH, default = initH, interval = 10, suffix = " px", flag = "ui_height", callback = applyUiSize })
	interface:slider({ name = "HUD Rate", min = 1, max = 12, default = 4, interval = 1, suffix = " Hz", flag = "ui_hud_hz", tooltip = "Target info / inventory / staff overlay refresh rate" })
	interface:colorpicker({ name = "Accent", flag = "ui_accent", color = compatTheme.accent, callback = function(value)
		library:update_theme("accent", toColor3(value) or compatTheme.accent)
	end })
	interface:colorpicker({ name = "Background", flag = "ui_background", color = compatTheme.cont, callback = function(value)
		library:update_theme("cont", toColor3(value) or compatTheme.cont)
	end })
	interface:colorpicker({ name = "Outline", flag = "ui_outline", color = compatTheme.outline2, callback = function(value)
		library:update_theme("outline2", toColor3(value) or compatTheme.outline2)
	end })
	interface:label("Drag the purple grip at the bottom-right to resize.")
	interface:label("Mouse wheel over the menu cycles long-tab sections.")

	local col3 = settingsTab:column()
	local essentials = col3:section({ name = "UI Essentials" })
	essentials:button({ name = "Show Menu", callback = function() pcall(window.set_menu_visibility, true) end })
	essentials:button({ name = "Hide Menu", callback = function() pcall(window.set_menu_visibility, false) end })
	essentials:button({ name = "Rebuild Layout", callback = function()
		if window._compatRebalance then pcall(window._compatRebalance) end
		pcall(update_elements)
	end })
	essentials:button({ name = "Refresh Previews", callback = update_elements })
	essentials:button({ name = "Close Stuck Menus", callback = function()
		if window._compatCloseTransients then pcall(window._compatCloseTransients, window, true) end
	end })
	essentials:button({ name = "Unload Vault", callback = function()
		local handle = getgenv().Vault
		if handle and handle.unload then pcall(handle.unload) end
	end })
	essentials:label("Menu key: custom keybind or RightShift.")
	essentials:label("Escape / right-click clears stuck transient menus.")
end

OVX.refreshAllVisuals = function()
	pcall(update_elements)
	local liveEsp = getgenv().esp
	if liveEsp and liveEsp.Sync then pcall(liveEsp.Sync) end
	if flags["rb_enabled"] == true and OVX.ragebotSync then pcall(OVX.ragebotSync) end
end

-- ——— ESP PREVIEW ———
-- noname.hack has no 3D character preview; the compatibility layer draws a
-- compact 2D panel from the same flags/colors as the live ESP.
pcall(function()
	esp = window.esp_section:esp_preview({})
	if esp and esp.refresh_elements then esp.refresh_elements() end
end)
pcall(OVX.refreshAllVisuals)

-- ================================================================
-- // INIT (library's own example order)
-- ================================================================
pcall(function() visualsTab.open_tab() end)
pcall(function() library:config_list_update() end)
pcall(function()
	for index, value in themes.preset do
		pcall(function() library:update_theme(index, value) end)
	end
end)
task.wait()
pcall(function() library.old_config = library:get_config() end)
task.delay(0.35, function()
	pcall(function()
		local auto = OVX.configReadAuto and OVX.configReadAuto() or nil
		if auto and auto.enabled == true then
			local name = auto.name or "Default"
			local setter = library.config_flags["cfg_auto_load"]
			if setter then pcall(setter, true) else flags["cfg_auto_load"] = true end
			local nameSetter = library.config_flags["cfg_name"]
			if nameSetter then pcall(nameSetter, name) else flags["cfg_name"] = name end
			if OVX.configLoad then pcall(OVX.configLoad, name) end
		end
		if OVX.refreshAllVisuals then pcall(OVX.refreshAllVisuals) end
	end)
end)

-- ================================================================
	-- ================================================================
	-- // EXPLOIT PACK: auto-heal, barrel smash, auto-reload, ammo swap,
	-- // vehicle boost, metal scan, auto-parachute, auto-shield, wake.
	-- // Every call uses a packet the game's own client sends. All loops
	-- // are throttled and everything rides bind() for a clean unload.
	-- ================================================================
	do
		OVX.ex = OVX.ex or { heal = 0, barrels = 0, reload = 0, ammo = 0,
			vehicle = 0, metal = 0, para = 0, shield = 0, wake = 0 }
		local function exRemote(folder, name)
			local f = RepStorage:FindFirstChild(folder)
			local r = f and f:FindFirstChild(name)
			return r and r:IsA("RemoteEvent") and r or nil
		end
		local function exFire(folder, name, ...)
			local r = exRemote(folder, name)
			if not r then return false end
			local args = table.pack(...)
			pcall(function() r:FireServer(table.unpack(args, 1, args.n)) end)
			return true
		end
		-- ── auto heal: InventoryRemotes.Action("use", itemId) ──
		local MED_ITEMS = { "MedSyringe", "LargeMedkit", "Bandage", "HoneyBandage",
			"BasicHealingTea", "AdvancedHealingTea", "PureHealingTea" }
		local lastHeal = 0
		local function autoHeal()
			local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			local maxH = hum.MaxHealth > 0 and hum.MaxHealth or 100
			if hum.Health / maxH > (tonumber(flags["ex_heal_hp"]) or 60) / 100 then return end
			local now = os.clock()
			if now - lastHeal < 1.5 then return end
			for _, name in ipairs(MED_ITEMS) do
				if (tonumber(lp:GetAttribute(name)) or 0) > 0 then
					if exFire("InventoryRemotes", "Action", "use", name) then
						lastHeal = now
						OVX.ex.heal = OVX.ex.heal + 1
						return
					end
				end
			end
		end
		-- ── barrel smash: same Swing claim as gathering nodes ──
		local BARREL_NAMES = { Barrel = true, FoodCrate = true, MilitaryCrate = true,
			EliteCrate = true, LockedCrate = true, WoodenCrate = true }
		local lastBarrel = 0
		local function smashBarrels()
			local char = lp.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then return end
			if not OVX.meleeTool() then return end
			local now = os.clock()
			if now - lastBarrel < 1 then return end
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { char, workspace.CurrentCamera }
			local parts = workspace:GetPartBoundsInRadius(root.Position,
				tonumber(flags["ex_barrel_range"]) or 10, op)
			for i = 1, #parts do
				local part = parts[i]
				local model = part:FindFirstAncestorOfClass("Model")
				if model and BARREL_NAMES[model.Name] then
					local pos = part.Position
					local claim = OVX.claimPartFor and OVX.claimPartFor(model, pos) or part
					local gr = RepStorage:FindFirstChild("GatheringRemotes")
					local st = (gr and gr:GetAttribute("ClientHits") == true) and workspace:GetServerTimeNow() or nil
					local r = OVX.swingRemote()
					if r then
						pcall(function() r:FireServer(claim, pos, st, false) end)
						lastBarrel = now
						OVX.ex.barrels = OVX.ex.barrels + 1
					end
					return
				end
			end
		end
		-- ── auto reload / ammo swap ──
		local lastReload = 0
		local function autoReload()
			local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
			if not (tool and tool:GetAttribute("GunId")) then return end
			if (tonumber(tool:GetAttribute("Ammo")) or 0) > 0 then return end
			if tool:GetAttribute("Reloading") then return end
			local now = os.clock()
			if now - lastReload < 0.3 then return end
			if exFire("FirearmsRemotes", "Reload") then
				lastReload = now
				OVX.ex.reload = OVX.ex.reload + 1
			end
		end
		-- ── vehicle boost (attributes are read by VehiclesClient per frame) ──
		local vehOrig = setmetatable({}, { __mode = "k" })
		local function vehicleBoost()
			local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
			local seat = hum and hum.SeatPart
			local model = seat and seat:FindFirstAncestorOfClass("Model")
			if not model then return end
			local mult = tonumber(flags["ex_vehicle_mult"]) or 2
			pcall(function()
				if vehOrig[model] == nil then vehOrig[model] = {
					speed = model:GetAttribute("SpeedMult"),
					walk = model:GetAttribute("Walk"),
					jump = model:GetAttribute("Jump"),
				} end
				model:SetAttribute("SpeedMult", mult)
				model:SetAttribute("Walk", (tonumber(flags["ex_vehicle_walk"]) or 7) * mult)
				model:SetAttribute("Jump", (tonumber(flags["ex_vehicle_jump"]) or 25) * mult)
			end)
			OVX.ex.vehicle = OVX.ex.vehicle + 1
		end
		-- ── metal detector auto-scan ──
		local lastMetal = 0
		local function autoMetal()
			local now = os.clock()
			if now - lastMetal < 0.25 then return end
			local cam = workspace.CurrentCamera
			if not cam then return end
			local aim = cam.CFrame.Position + cam.CFrame.LookVector * 25
			if exFire("MetalDetectorRemotes", "Scan", true, aim) then
				lastMetal = now
				OVX.ex.metal = OVX.ex.metal + 1
			end
		end
		local sig = exRemote("MetalDetectorRemotes", "Signal")
		if sig then
			bind(sig.OnClientEvent:Connect(function(a, b)
				OVX.metalDistance = tonumber(a) or 0
				OVX.metalStrength = tonumber(b) or 0
			end))
		end
		-- ── auto parachute ──
		local lastPara = 0
		local function autoParachute()
			local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			if (root.AssemblyLinearVelocity.Y or 0) > -20 then return end
			local now = os.clock()
			if now - lastPara < 3 then return end
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -500, 0))
			local alt = hit and hit.Distance or 500
			if alt < (tonumber(flags["ex_para_alt"]) or 30) then return end
			if exFire("ParachuteRemotes", "Deploy") then
				lastPara = now
				OVX.ex.para = OVX.ex.para + 1
			end
		end
		-- ── auto shield ──
		local lastShield = 0
		local function autoShield()
			local now = os.clock()
			if now - lastShield < 1 then return end
			if exFire("ShieldsRemotes", "Raise", true) then
				lastShield = now
				OVX.ex.shield = OVX.ex.shield + 1
			end
		end
		-- exports for keybinds
		function OVX.exWake() if exFire("RespawnRemotes", "WakeUp") then OVX.ex.wake = OVX.ex.wake + 1 end end
		function OVX.exAmmo() if exFire("FirearmsRemotes", "SwitchAmmo") then OVX.ex.ammo = OVX.ex.ammo + 1 end end
		bind(RunService.Heartbeat:Connect(function()
			if flags["ex_heal"] then autoHeal() end
			if flags["ex_barrel"] then smashBarrels() end
			if flags["ex_reload"] then autoReload() end
			if flags["ex_vehicle"] then vehicleBoost() end
			if flags["ex_metal"] then autoMetal() end
			if flags["ex_para"] then autoParachute() end
			if flags["ex_shield"] then autoShield() end
		end))
		bind({ Disconnect = function()
			for model, vals in pairs(vehOrig) do
				pcall(function()
					model:SetAttribute("SpeedMult", vals.speed)
					model:SetAttribute("Walk", vals.walk)
					model:SetAttribute("Jump", vals.jump)
				end)
			end
			table.clear(vehOrig)
		end })
	end

-- // UNLOAD (works for everything: ESP, script connections and noname.hack drawings)
-- ================================================================
local cleanedUp = false
local function cleanup()
	if cleanedUp then return end
	cleanedUp = true
	for _, conn in ipairs(_connections) do pcall(function() conn:Disconnect() end) end
	table.clear(_connections)
	if espUnload then pcall(espUnload) end
	if library._compatPreview and library._compatPreview.destroy then pcall(library._compatPreview.destroy) end
	if OVX.espSelfPreview and OVX.espSelfPreview.destroy then pcall(OVX.espSelfPreview.destroy) end
	if OVX.finalizeViewmodelCleanup then pcall(OVX.finalizeViewmodelCleanup) end
end

-- window:unload() disconnects noname.hack and invokes this callback.
library.unload_callback = cleanup

local function fullUnload()
	pcall(cleanup)
	pcall(function()
		if window and window.unload then window:unload() end
	end)
	getgenv().VaultUnload = nil
	getgenv().VaultCleanup = nil
end
getgenv().VaultCleanup = fullUnload
getgenv().VaultUnload = fullUnload

-- runtime handle (tweak flags live: getgenv().Vault.flags["Enabled"] = true, or
-- getgenv().Vault.set("Enabled", true) to fire the library's own setter)
local vaultHandle
vaultHandle = {
	library = library,
	flags = flags,
	window = window,
	unload = fullUnload,
	focus = function(a, b, c)
		if a == vaultHandle then return library.focus_section(library, b, c) end
		return library.focus_section(library, a, b)
	end,
	config = function(a, b)
		if a == vaultHandle then return OVX.configLoad(b) end
		return OVX.configLoad(a)
	end,
	saveConfig = function(a, b)
		if a == vaultHandle then return OVX.configSave(b) end
		return OVX.configSave(a)
	end,
	ragebot = function(a, b)
		if a == vaultHandle then return OVX.ragebotApply(b) end
		return OVX.ragebotApply(a)
	end,
	selfPreview = OVX.espSelfPreview,
	set = function(a, b, c)
		local flag, value = a, b
		if a == vaultHandle then flag, value = b, c end
		local fn = library.config_flags and library.config_flags[flag]
		if fn then fn(value) else flags[flag] = value end
	end,
}
getgenv().Vault = vaultHandle

-- noname.hack is Drawing-based, so there is no ScreenGui/TextButton
-- "Unload Menu" tree to traverse. window:unload() handles library teardown.

pcall(function() window.set_menu_visibility(true) end)

print("[OVX] loaded — silent aim + Ragebot + triggerbot + bullet tracers + Sci-Fi hand/gun chams + skin changer + v5 gradient ESP + 2D/3D ESP previews + Settings/configs + ESP/world + speed/phase/spider/freecam + kill aura + autofarm + hitsounds + trajectory arc + desync + inventory viewer + crosshair info + staff panel")

-- external state bridge (for console/state analysis + remote toggling)
getgenv().__ovx = { flags = flags, library = library, setf = library.config_flags, window = window, state = OVX }
