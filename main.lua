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
			.. "        if self.sshit then\n            for _, other_tab in pairs(self.tabs) do\n                if other_tab ~= self.sshit then other_tab:Hide() end\n            end\n        end\n\n"
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

	local chunk = assert(loadstring(src), "[OVX] noname.hack UI failed to compile")
	local a, b = chunk()
	library, utility = a, b
	if type(library) ~= "table" then error("[OVX] noname.hack UI failed to load") end
end

local flags = library.flags
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

local function keyName(value)
	if typeof(value) == "EnumItem" then return value.Name end
	if type(value) == "string" and value ~= "" then return value end
	return "unset"
end

local function keybindInfo(info)
	info = info or {}
	local out = copyTable(info)
	local mode = string.lower(tostring(info.mode or "toggle"))
	if mode ~= "hold" then mode = "toggle" end
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
	local mode = string.lower(tostring(info.mode or "toggle"))
	if mode ~= "hold" then mode = "toggle" end
	local boundKey = keyName(info.def or info.key or info.default)

	rebindPointer(keybind, pointer)
	keybind.name = info.name or keybind.name
	if section and section.name then keybind.sname = section.name end
	if keybind.Set then pcall(keybind.Set, keybind, { boundKey, mode }) end
	if flag then library.flags[flag] = { active = false, mode = mode, key = boundKey } end

	local active = false
	local function setActive(state)
		state = state and true or false
		if active == state then return end
		active = state
		if flag and type(library.flags[flag]) == "table" then library.flags[flag].active = state end
		if callback then pcall(callback, state) end
	end

	function keybind:set(value)
		if type(value) == "table" and value.active ~= nil then value = value.active end
		local desired = value == true or value == 1 or value == "true"
		local index = contains(nativeWindow.kbds, pointer)
		if desired and not index then
			table.insert(nativeWindow.kbds, pointer)
		elseif not desired and index then
			table.remove(nativeWindow.kbds, index)
		end
		if nativeWindow.kblist then pcall(nativeWindow.kblist.Update, nativeWindow.kblist) end
		setActive(desired)
	end

	function keybind:colorpicker(cpInfo)
		return self
	end

	local heartbeat = game:GetService("RunService").Heartbeat
	utility:Connect(heartbeat, function()
		local isActive = contains(nativeWindow.kbds, pointer) ~= nil
		if isActive ~= active then setActive(isActive) end
	end)

	if flag then
		registerFlagSetter(flag, function(value) keybind:set(value) end)
	end
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

	function section:label()
		return self
	end

	function section:list()
		return self
	end

	function section:textbox()
		return self
	end

	return section
end

local function attachTab(tab)
	tab._compatColumnCount = 0

	function tab:column()
		tab._compatColumnCount = tab._compatColumnCount + 1
		local side = (tab._compatColumnCount % 2 == 1) and "left" or "right"
		local column = {}
		function column:section(info)
			info = info or {}
			local section = tab:Section({ name = info.name or "Section", side = side })
			attachSection(section, tab)
			refreshSection(section)
			return section
		end
		return column
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

	-- noname.hack does not bind a menu key by itself. Keep Insert / RightShift
	-- as show-hide shortcuts and register the connection with the library so
	-- window:unload() disconnects it.
	nativeWindow.menu_key = Enum.KeyCode.Insert
	local uis = game:GetService("UserInputService")
	utility:Connect(uis.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift then
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
		local frame = nativeWindow.frame
		if frame.Visible ~= state and nativeWindow.Fade then
			pcall(nativeWindow.Fade, nativeWindow)
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
			local shown = frame.Visible and true or false
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
	if nativeWindow and nativeWindow.Init then
		local ok, err = pcall(nativeWindow.Init, nativeWindow)
		if not ok then warn("[OVX] noname.hack Init failed: " .. tostring(err)) end
	end
	pcall(function()
		if nativeWindow and nativeWindow.Update then nativeWindow:Update() end
	end)
	task.delay(0.3, function()
		pcall(function()
			if nativeWindow and nativeWindow.Update then nativeWindow:Update() end
			if nativeWindow and nativeWindow.sshit and nativeWindow.SelectTab then
				nativeWindow:SelectTab(nativeWindow.sshit.name)
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
-- // PLAYER ESP
-- ================================================================
do

local espPlayers = {}
local camera = Workspace.CurrentCamera

local COLOR_BLACK = c3(0, 0, 0)
local HEALTH_SEGMENTS = 8  -- gradient bar resolution

-- corner box: 8 short lines, defined as {originX, originY, dirX, dirY}
local CORNER_DEFS = {
	{ 0, 0,  1, 0 }, { 0, 0, 0,  1 },
	{ 1, 0, -1, 0 }, { 1, 0, 0,  1 },
	{ 0, 1,  1, 0 }, { 0, 1, 0, -1 },
	{ 1, 1, -1, 0 }, { 1, 1, 0, -1 },
}

local function NewDrawing(dtype, props)
	local d = Drawingnew(dtype)
	if props then for k, v in next, props do d[k] = v end end
	return d
end

local function NewCham(props)
	local h = Instance.new("Highlight")
	h.Parent = CoreGui
	if props then for k, v in next, props do h[k] = v end end
	return h
end

local function allocatePlayer(player)
	if espPlayers[player] then return end
	local entry = {
		name       = NewDrawing("Text",   { Color = c3(255,255,255), Outline = true, Center = true, Size = 13, Font = 2 }),
		filledbox  = NewDrawing("Square", { Color = c3(255,255,255), Thickness = 1, Filled = true }),
		boxOutline = NewDrawing("Square", { Color = COLOR_BLACK, Thickness = 3 }),
		box        = NewDrawing("Square", { Color = c3(255,255,255), Thickness = 1 }),
		corners    = {},
		cornersOut = {},
		healthOutline = NewDrawing("Line", { Color = COLOR_BLACK, Thickness = 4, Visible = false }),
		healthGrad = {},
		healthText = NewDrawing("Text",   { Color = c3(255,255,255), Outline = true, Center = true, Size = 13, Font = 2 }),
		distance   = NewDrawing("Text",   { Color = c3(255,255,255), Outline = true, Center = true, Size = 13, Font = 2 }),
		weapon     = NewDrawing("Text",   { Color = c3(255,255,255), Outline = true, Center = true, Size = 13, Font = 2 }),
		viewAngle  = NewDrawing("Line",   { Color = c3(255,255,255), Thickness = 1 }),
		tracer     = NewDrawing("Line",   { Color = c3(255,255,255), Thickness = 1 }),
		cham       = NewCham({ FillColor = c3(255,255,255), OutlineColor = COLOR_BLACK, FillTransparency = 0.5, OutlineTransparency = 0.5, Enabled = false }),
		_hidden    = true,
	}
	for i = 1, 8 do
		entry.corners[i]    = NewDrawing("Line", { Thickness = 2, Visible = false })
		entry.cornersOut[i] = NewDrawing("Line", { Thickness = 4, Visible = false, Color = COLOR_BLACK })
	end
	for i = 1, HEALTH_SEGMENTS do
		entry.healthGrad[i] = NewDrawing("Line", { Thickness = 3, Visible = false })
	end
	espPlayers[player] = entry
end

local function hideAll(entry)
	if entry._hidden then return end
	entry._hidden = true
	entry.name.Visible = false
	entry.filledbox.Visible = false
	entry.boxOutline.Visible = false
	entry.box.Visible = false
	entry.healthOutline.Visible = false
	entry.healthText.Visible = false
	entry.distance.Visible = false
	entry.weapon.Visible = false
	entry.viewAngle.Visible = false
	entry.tracer.Visible = false
	entry.cham.Enabled = false
	for i = 1, 8 do entry.corners[i].Visible = false; entry.cornersOut[i].Visible = false end
	for i = 1, HEALTH_SEGMENTS do entry.healthGrad[i].Visible = false end
end

local function removeAll(entry)
	for _, v in pairs(entry) do
		if type(v) == "table" then
			for _, sub in ipairs(v) do pcall(function() sub:Remove() end) end
		elseif typeof(v) == "Instance" then
			pcall(function() v:Destroy() end)
		elseif type(v) ~= "boolean" then
			pcall(function() v:Remove() end)
		end
	end
end

local function releasePlayer(player)
	local entry = espPlayers[player]
	if not entry then return end
	espPlayers[player] = nil
	removeAll(entry)
end

local function drawCorners(entry, bx, by, bw, bh, color)
	local len = bw * 0.28
	for i = 1, 8 do
		local d = CORNER_DEFS[i]
		local px, py = bx + d[1] * bw, by + d[2] * bh
		local ex, ey = px + d[3] * len, py + d[4] * len
		entry.cornersOut[i].From = v2new(px, py); entry.cornersOut[i].To = v2new(ex, ey); entry.cornersOut[i].Visible = true
		entry.corners[i].From = v2new(px, py); entry.corners[i].To = v2new(ex, ey); entry.corners[i].Color = color; entry.corners[i].Visible = true
	end
end

-- init existing + future players
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= lp then allocatePlayer(p) end
end
bind(Players.PlayerAdded:Connect(function(p)
	if p ~= lp then allocatePlayer(p) end
end))
bind(Players.PlayerRemoving:Connect(releasePlayer))
bind(lp.CharacterRemoving:Connect(function()
	for _, entry in pairs(espPlayers) do hideAll(entry) end
end))

-- ——— RENDER ———
bind(RunService.RenderStepped:Connect(function()
	camera = Workspace.CurrentCamera
	if not camera then return end

	local fEnabled = flags["Enabled"]
	if not fEnabled then
		for _, entry in pairs(espPlayers) do hideAll(entry) end
		return
	end

	-- local position: HRP when present, else model pivot (self is always
	-- streamed in, but stay robust)
	local char = lp.Character
	local localPos
	if char then
		local lhrp = char:FindFirstChild("HumanoidRootPart")
		if lhrp then
			localPos = lhrp.Position
		else
			local ok, p = pcall(function() return char:GetPivot().Position end)
			if ok then localPos = p end
		end
	end

	-- cache every flag read once per frame
	local fTeamCheck  = flags["esp_team_check"]
	local fMaxDist    = flags["esp_max_dist"] or 0
	local fBoxes      = flags["Boxes"]
	local fBoxType    = flags["Box_Type"] or "Full"
	local fFilledBox  = flags["esp_filled_box"]
	local fNames      = flags["Names"]
	local fDisplayN   = flags["esp_display_names"]
	local fHealthbar  = flags["Healthbar"]
	local fHealthText = flags["esp_health_text"]
	local fDistance   = flags["Distance"]
	local fWeapon     = flags["Weapon"]
	local fViewAngle  = flags["esp_view_angle"]
	local fTracers    = flags["esp_tracers"]
	local fChams      = flags["esp_chams"]
	local fTracerFrom = flags["esp_tracer_origin"] or "Bottom"

	local cName    = resolveColor("Name_Color", c3(255,255,255))
	local cBox     = resolveColor("Box_Color", c3(255,255,255))
	local cDist    = resolveColor("Distance_Color", c3(200,200,200))
	local cWeapon  = resolveColor("Weapon_Color", c3(255,255,255))
	local cFilled  = resolveColor("esp_filled_color", COLOR_BLACK)
	local cTracer  = resolveColor("esp_tracer_color", c3(255,255,255))
	local cView    = resolveColor("esp_viewangle_color", c3(255,255,255))
	local cHpHigh  = resolveColor("Health_High", c3(0,255,0))
	local cHpLow   = resolveColor("Health_Low", c3(255,0,0))
	local cChamF   = resolveColor("esp_cham_fill_color", c3(255,255,255))
	local cChamO   = resolveColor("esp_cham_outline_color", COLOR_BLACK)

	local filledTransp  = (flags["esp_filled_transparency"] or 5) / 10
	local chamFTransp   = (flags["esp_cham_fill_transparency"] or 5) / 10
	local chamOTransp   = (flags["esp_cham_outline_transparency"] or 5) / 10
	local viewSize      = flags["esp_viewangle_size"] or 10
	local vpSize        = camera.ViewportSize

	for _, player in ipairs(Players:GetPlayers()) do
		if player == lp then continue end
		local entry = espPlayers[player]
		if not entry then allocatePlayer(player); entry = espPlayers[player] end

		local model = player.Character
		local hum   = model and model:FindFirstChildOfClass("Humanoid")
		local head  = model and model:FindFirstChild("Head")

		-- renderable gate (NOTE: this game uses StreamingEnabled, so far players
		-- have NO body parts — fall back to the model pivot for their position)
		if not (model and hum and hum.Health > 0 and localPos)
			or (fTeamCheck and sameTeam(player)) then
			hideAll(entry); continue
		end

		-- position source: HumanoidRootPart when streamed in (live), else the
		-- model pivot (streamed-out players — last-known position)
		local pos
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if hrp then
			pos = hrp.Position
		else
			local ok, piv = pcall(function() return model:GetPivot().Position end)
			if not (ok and piv) then hideAll(entry); continue end
			pos = piv
		end

		local dist = (pos - localPos).Magnitude
		if fMaxDist > 0 and dist > fMaxDist then hideAll(entry); continue end

		local root, onScreen = camera:WorldToViewportPoint(pos)
		if not onScreen or root.Z < 0 then hideAll(entry); continue end
		entry._hidden = false

		-- perspective-correct box (identical math to the Walls ESP)
		local topY = camera:WorldToViewportPoint(pos + v3new(0, 2.6, 0)).Y
		local botY = camera:WorldToViewportPoint(pos - v3new(0, 3, 0)).Y
		local Size = (botY - topY) / 2
		local BoxSize = v2new(floor(Size * 1.5), floor(Size * 1.9))
		local BoxPos  = v2new(floor(root.X - Size * 1.5 / 2), floor(root.Y - Size * 1.6 / 2))
		local bottomStack = BoxPos.Y + BoxSize.Y + 1

		-- chams
		if fChams then
			entry.cham.Adornee = model
			entry.cham.FillColor = cChamF
			entry.cham.OutlineColor = cChamO
			entry.cham.FillTransparency = chamFTransp
			entry.cham.OutlineTransparency = chamOTransp
			entry.cham.Enabled = true
		else
			entry.cham.Enabled = false
		end

		-- filled box (behind the outline)
		if fFilledBox then
			entry.filledbox.Size = BoxSize + v2new(-2, -2)
			entry.filledbox.Position = BoxPos + v2new(1, 1)
			entry.filledbox.Color = cFilled
			entry.filledbox.Transparency = filledTransp
			entry.filledbox.Visible = true
		else
			entry.filledbox.Visible = false
		end

		-- box (corner or full)
		if fBoxes then
			if fBoxType == "Corner" then
				entry.boxOutline.Visible = false
				entry.box.Visible = false
				drawCorners(entry, BoxPos.X, BoxPos.Y, BoxSize.X, BoxSize.Y, cBox)
			else
				for i = 1, 8 do entry.corners[i].Visible = false; entry.cornersOut[i].Visible = false end
				entry.boxOutline.Size = BoxSize; entry.boxOutline.Position = BoxPos; entry.boxOutline.Visible = true
				entry.box.Size = BoxSize; entry.box.Position = BoxPos; entry.box.Color = cBox; entry.box.Visible = true
			end
		else
			entry.boxOutline.Visible = false
			entry.box.Visible = false
			for i = 1, 8 do entry.corners[i].Visible = false; entry.cornersOut[i].Visible = false end
		end

		-- gradient healthbar (Low at the bottom -> High at the top, filled by HP%)
		if fHealthbar then
			local ratio = clamp(hum.Health / (hum.MaxHealth > 0 and hum.MaxHealth or 1), 0, 1)
			local barX    = BoxPos.X - 5
			local bottomY = BoxPos.Y + BoxSize.Y
			local fullH   = BoxSize.Y
			local fillTopY = bottomY - ratio * fullH

			entry.healthOutline.From = v2new(barX, bottomY + 1)
			entry.healthOutline.To   = v2new(barX, BoxPos.Y - 1)
			entry.healthOutline.Visible = true

			local segH = fullH / HEALTH_SEGMENTS
			for i = 1, HEALTH_SEGMENTS do
				local seg = entry.healthGrad[i]
				local segBottomY = bottomY - (i - 1) * segH
				local segTopY    = bottomY - i * segH
				if segBottomY <= fillTopY + 0.5 then
					seg.Visible = false
				else
					if segTopY < fillTopY then segTopY = fillTopY end
					seg.From = v2new(barX, segBottomY)
					seg.To   = v2new(barX, segTopY)
					seg.Color = cHpLow:Lerp(cHpHigh, (i - 0.5) / HEALTH_SEGMENTS)
					seg.Visible = true
				end
			end
		else
			entry.healthOutline.Visible = false
			for i = 1, HEALTH_SEGMENTS do entry.healthGrad[i].Visible = false end
		end

		-- name (top center)
		if fNames then
			entry.name.Text = fDisplayN and player.DisplayName or player.Name
			entry.name.Position = v2new(BoxPos.X + BoxSize.X / 2, BoxPos.Y - 16)
			entry.name.Color = cName
			entry.name.Visible = true
		else
			entry.name.Visible = false
		end

		-- health % text (left of the bar)
		if fHealthText then
			entry.healthText.Text = tostring(floor((hum.Health / (hum.MaxHealth > 0 and hum.MaxHealth or 1)) * 100 + 0.5))
			entry.healthText.Position = v2new(BoxPos.X - 14, BoxPos.Y - 2)
			entry.healthText.Visible = true
		else
			entry.healthText.Visible = false
		end

		-- distance (stacks under the box)
		if fDistance then
			entry.distance.Text = "[" .. floor(dist) .. "m]"
			entry.distance.Position = v2new(BoxPos.X + BoxSize.X / 2, bottomStack)
			entry.distance.Color = cDist
			entry.distance.Visible = true
			bottomStack = bottomStack + 15
		else
			entry.distance.Visible = false
		end

		-- held item (tools / guns / anything)
		if fWeapon then
			entry.weapon.Text = heldLabelOf(model)
			entry.weapon.Position = v2new(BoxPos.X + BoxSize.X / 2, bottomStack)
			entry.weapon.Color = cWeapon
			entry.weapon.Visible = true
			bottomStack = bottomStack + 15
		else
			entry.weapon.Visible = false
		end

		-- view angle
		if fViewAngle and head then
			local hp = camera:WorldToViewportPoint(head.Position)
			local lv = camera:WorldToViewportPoint((head.CFrame + head.CFrame.LookVector * viewSize).Position)
			entry.viewAngle.From = v2new(hp.X, hp.Y)
			entry.viewAngle.To = v2new(lv.X, lv.Y)
			entry.viewAngle.Color = cView
			entry.viewAngle.Visible = true
		else
			entry.viewAngle.Visible = false
		end

		-- tracer
		if fTracers then
			local fromY = (fTracerFrom == "Top" and 0) or (fTracerFrom == "Center" and vpSize.Y / 2) or vpSize.Y
			entry.tracer.From = v2new(vpSize.X / 2, fromY)
			entry.tracer.To = v2new(root.X, root.Y)
			entry.tracer.Color = cTracer
			entry.tracer.Visible = true
		else
			entry.tracer.Visible = false
		end
	end
end))

-- cleanup hook for the top-level unload
espUnload = function()
	for _, entry in pairs(espPlayers) do removeAll(entry) end
	table.clear(espPlayers)
end

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

	local function pickBone(model, bone, crosshair, camera)
		if bone == "Head" then
			return model:FindFirstChild("Head")
		elseif bone == "Torso / HRP" then
			return model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
		else -- Closest part to the crosshair
			local best, bestD
			for _, p in ipairs(model:GetChildren()) do
				if p:IsA("BasePart") then
					local sp, on = camera:WorldToViewportPoint(p.Position)
					if on and sp.Z > 0 then
						local d = (v2new(sp.X, sp.Y) - crosshair).Magnitude
						if not bestD or d < bestD then bestD = d; best = p end
					end
				end
			end
			return best
		end
	end
	OVX.pickBone = pickBone

	local NPC_FOLDERS = { "Sleepers", "Scientists", "Animals" }
	local function getTarget()
		local camera = Workspace.CurrentCamera
		if not camera then return nil end
		local m = UIS:GetMouseLocation()
		local crosshair = v2new(m.X, m.Y)
		local fov      = flags["sa_fov"] or 120
		local maxd     = flags["sa_max_dist"] or 0
		local teamChk  = flags["sa_team_check"]
		local bone     = flags["sa_bone"] or "Head"
		local lchar = lp.Character
		local lhrp  = lchar and lchar:FindFirstChild("HumanoidRootPart")
		local best, bestD = nil, fov
		local function consider(model)
			if not model then return end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not (hum and hum.Health > 0) then return end
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if maxd > 0 and lhrp and hrp and (hrp.Position - lhrp.Position).Magnitude > maxd then return end
			local part = pickBone(model, bone, crosshair, camera)
			if not part then return end
			local sp, on = camera:WorldToViewportPoint(part.Position)
			if on and sp.Z > 0 then
				local d = (v2new(sp.X, sp.Y) - crosshair).Magnitude
				if d <= bestD then bestD = d; best = { part = part, point = part.Position, model = model } end
			end
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= lp and not (teamChk and sameTeam(pl)) then consider(pl.Character) end
		end
		if flags["sa_target_npc"] ~= false then
			for _, fname in ipairs(NPC_FOLDERS) do
				local folder = Workspace:FindFirstChild(fname)
				if folder then for _, mdl in ipairs(folder:GetChildren()) do consider(mdl) end end
			end
			local gr = Workspace:FindFirstChild("GunRange")
			local dum = gr and gr:FindFirstChild("Dummies")
			if dum then for _, mdl in ipairs(dum:GetChildren()) do consider(mdl) end end
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
		if not (saActive and flags and flags["sa_enabled"]) then
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
	local saFrame = 0
	bind(RunService.RenderStepped:Connect(function()
		local on = saActive and flags["sa_enabled"]
		if on then
			refreshBowRemotes()
			fovCircle.Visible = flags["sa_show_fov"] and true or false
			local m = UIS:GetMouseLocation()
			fovCircle.Position = v2new(m.X, m.Y)
			fovCircle.Radius = flags["sa_fov"] or 120
			-- target scan every other frame: the NPC folder scan + bone pick
			-- (WorldToViewportPoint per part) is wasted work at full frame rate
			saFrame = saFrame + 1
			OVX.saScanAt = os.clock()
			if saFrame % 2 == 1 then
				local okG, res = pcall(getTarget)
				if okG then
					_saTarget = res
				else
					OVX.saErr = tostring(res)
					_saTarget = nil
				end
			end
			OVX.saTarget = _saTarget
			-- snapline + target crosshair: green = clear eye→target ray,
			-- red = covered (the same check that triggers the gun peek)
			local tgt = _saTarget
			local cam = Workspace.CurrentCamera
			if cam and (flags["sa_snapline"] or flags["sa_cross"]) and tgt
				and tgt.part and tgt.part.Parent then
				local sp, onScreen = cam:WorldToViewportPoint(tgt.part.Position)
				if onScreen and sp.Z > 0 then
					local covered = not rayClear(cam.CFrame.Position, tgt.part.Position, tgt.model)
					local col = covered and c3(255, 60, 60) or c3(60, 255, 60)
					local tp = v2new(sp.X, sp.Y)
					if flags["sa_snapline"] then
						snapLine.From = v2new(m.X, m.Y)
						snapLine.To = tp
						snapLine.Color = col
						snapLine.Visible = true
					else
						snapLine.Visible = false
					end
					if flags["sa_cross"] then
						crossV.From = v2new(tp.X, tp.Y - 6); crossV.To = v2new(tp.X, tp.Y + 6)
						crossH.From = v2new(tp.X - 6, tp.Y); crossH.To = v2new(tp.X + 6, tp.Y)
						crossV.Color = col; crossH.Color = col
						crossV.Visible = true; crossH.Visible = true
					else
						crossV.Visible = false; crossH.Visible = false
					end
				else
					snapLine.Visible = false; crossV.Visible = false; crossH.Visible = false
				end
			else
				snapLine.Visible = false; crossV.Visible = false; crossH.Visible = false
			end
		else
			fovCircle.Visible = false
			snapLine.Visible = false; crossV.Visible = false; crossH.Visible = false
			_saTarget = nil
			OVX.saTarget = nil
		end
	end))

	-- install the redirect hook (firearms SA + bow SA share one __namecall hook)
	if FireRemote and HitRemote
		and hookmetamethod and newcclosure and getnamecallmethod then
		local firingOwn  = false  -- guard: our own Hit claim (firearms)
		local pendingId  = nil    -- seed suppression (firearms)
		local hasCheckcaller = type(checkcaller) == "function"

		-- ── single shared hook (guns + bows) ────────────────────────────────────
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			if firingOwn then return old(self, ...) end
			local notOurs = not (hasCheckcaller and checkcaller())
			if notOurs then
				local method = getnamecallmethod()
				if method == "FireServer" then
					-- ── FIREARMS SA ──────────────────────────────────────────────
					-- Guns are instant-hit; just redirect the direction vector
					-- and claim the hit with the packet's own claim id.
					if self == FireRemote and saActive and flags and flags["sa_enabled"] then
						local a = { ... }
						local tgt = _saTarget
						if tgt and typeof(a[1]) == "Vector3" then
							-- read live position from the part so stale scan pos doesn't miss
							local livePoint = (tgt.part and tgt.part.Parent and tgt.part.Position) or tgt.point
							-- client-claim grading: Fire a[4] = { id = claimCount, t } —
							-- claims must quote THAT id; the seed (a[3]) is not one
							local claim = a[4]
							local claimId = typeof(claim) == "table" and type(claim.id) == "number" and claim.id or nil
							-- GUN PEEK: origin untouched (the server validates it against
							-- the real muzzle). Covered target → sidestep the character
							-- so the muzzle clears cover; this shot still goes out
							-- naturally from the old spot, the next ones fire from
							-- around cover, legally. Uncovered → plain SA redirect.
							if flags["bp_enabled"] and typeof(livePoint) == "Vector3"
								and not rayClear(a[1], livePoint, tgt.model) then
								gunPeekStart(tgt, a[1])
								return old(self, ...)
							end
							local aimPart, aimPoint = tgt.part, livePoint
							a[2] = (aimPoint - a[1]).Unit
							-- the game's own claim follows the ORIGINAL ray (cover/wall
							-- behind the target) — suppress every pellet of this shot id
							pendingId = claimId
							OVX.saRedirectAt = os.clock()
							local ret = old(self, unpack(a))
							local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
							local speed = (tool and tonumber(tool:GetAttribute("BulletSpeed"))) or 1e4
							local travel = (aimPoint - a[1]).Magnitude / math.max(speed, 1)
							-- fire debug stamp (read via the bridge): what this shot did
							OVX.saFireDebug = {
								t = os.clock(), tool = tool and tool.Name or "?",
								peek = bpHome ~= nil, claim = claimId,
								dist = math.floor((aimPoint - a[1]).Magnitude + 0.5)
							}
							if claimId then
								task.delay(travel, function()
									firingOwn = true
									pcall(function() HitRemote:FireServer(claimId, 1, aimPart, aimPoint, workspace:GetServerTimeNow()) end)
									firingOwn = false
								end)
							end
							return ret
						end

					-- ── BOW SA (gun-style: redirect the launch, let the server's
					-- own flight claim land on the target) ────────────────────────
					-- Fire:   a[1]=direction, a[4]=claimInfo{t, o=muzzle origin}
					-- Launch: a[1]=direction, a[2]=claimInfo{t, o=muzzle origin}
					-- BowHit[1] is a server-generated flight id (not a seed). The
					-- client already claims on real arrow collision, so rewriting
					-- Hit would forge a claim the server can reject. Fix the FLIGHT
					-- instead: arc-solve from the packet's true launch origin.
					elseif self == BowFire or self == BowLaunch then
						OVX.bowFireCount = (OVX.bowFireCount or 0) + 1
						-- direction is already aimed via shared.HeldViewCFrame;
						-- do NOT rewrite the packet or the client/server sims split
						return old(self, ...)

					-- ── HIT suppression: firearms ─────────────────────────────────
					elseif self == HitRemote then
						local a = { ... }
						if not firingOwn and pendingId ~= nil and a[1] == pendingId then
							pendingId = nil
							return
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
	local NPC_FOLDERS = { "Sleepers", "Scientists", "Animals" }
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
		local fov = flags["sa_fov"] or 120 -- single FOV source: Silent Aim
		local maxd = flags["tb_max_dist"] or flags["sa_max_dist"] or 0
		local bone = flags["sa_bone"] or "Head"
		local teamChk = flags["sa_team_check"]
		local lhrp = char and char:FindFirstChild("HumanoidRootPart")
		local best, bestD = nil, fov
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
			for _, fname in ipairs(NPC_FOLDERS) do
				local folder = Workspace:FindFirstChild(fname)
				if folder then for _, mdl in ipairs(folder:GetChildren()) do consider(mdl) end end
			end
			local gr = Workspace:FindFirstChild("GunRange")
			local dum = gr and gr:FindFirstChild("Dummies")
			if dum then for _, mdl in ipairs(dum:GetChildren()) do consider(mdl) end end
		end
		return best
	end
	-- OVX menu / game UI holds the cursor away from center: never fire then
	local function menuUp()
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
	local TXT = c3(220, 220, 232)
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
		r.BackgroundColor3 = c3(30, 30, 36)
		r.BackgroundTransparency = 0.2
		r.BorderSizePixel = 0
		r.Size = UDim2.new(1, 0, 0, 26)
		r.LayoutOrder = order
		r.Parent = parent
		Instance.new("UICorner", r).CornerRadius = UDim.new(0, 5)
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.Size = UDim2.fromOffset(20, 20)
		ic.Position = UDim2.new(0, 3, 0.5, -10)
		ic.Parent = r
		local st = Instance.new("TextLabel")
		st.BackgroundTransparency = 1
		st.Font = Enum.Font.Gotham
		st.TextSize = 11
		st.TextColor3 = c3(225, 225, 235)
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
	tiRoot.Size = UDim2.fromOffset(300, 74)
	tiRoot.BackgroundColor3 = c3(10, 10, 12)
	tiRoot.BackgroundTransparency = 0.45
	tiRoot.BorderSizePixel = 0
	tiRoot.Parent = tiGui
	Instance.new("UICorner", tiRoot).CornerRadius = UDim.new(0, 8)
	local tiStroke = Instance.new("UIStroke", tiRoot)
	tiStroke.Thickness = 1
	tiStroke.Color = c3(96, 120, 190)
	tiStroke.Transparency = 0.25
	local tiText = Instance.new("TextLabel")
	tiText.BackgroundTransparency = 1
	tiText.Font = Enum.Font.Gotham
	tiText.TextSize = 12
	tiText.TextColor3 = c3(235, 235, 245)
	tiText.TextXAlignment = Enum.TextXAlignment.Left
	tiText.TextYAlignment = Enum.TextYAlignment.Center
	tiText.TextWrapped = true
	tiText.Position = UDim2.new(0, 10, 0, 0)
	tiText.Size = UDim2.new(1, -20, 1, 0)
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
	invRoot.BackgroundColor3 = c3(14, 14, 16)
	invRoot.BackgroundTransparency = 0.25
	invRoot.BorderSizePixel = 0
	invRoot.Parent = invGui
	Instance.new("UICorner", invRoot).CornerRadius = UDim.new(0, 8)
	local invStroke = Instance.new("UIStroke", invRoot)
	invStroke.Thickness = 1
	invStroke.Color = c3(70, 70, 82)
	invStroke.Transparency = 0.3
	local invTitle = Instance.new("TextLabel")
	invTitle.BackgroundTransparency = 1
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 12
	invTitle.TextColor3 = c3(235, 235, 245)
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.TextTruncate = Enum.TextTruncate.AtEnd
	invTitle.Position = UDim2.new(0, 10, 0, 0)
	invTitle.Size = UDim2.new(1, -40, 0, 26)
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
		h.TextSize = 11
		h.TextColor3 = c3(150, 170, 255)
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Size = UDim2.new(1, 0, 0, 16)
		h.LayoutOrder = order
		h.Parent = invBody
		h.Text = txt
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
	staffRoot.BackgroundColor3 = c3(14, 14, 16)
	staffRoot.BackgroundTransparency = 0.25
	staffRoot.BorderSizePixel = 0
	staffRoot.Parent = staffGui
	Instance.new("UICorner", staffRoot).CornerRadius = UDim.new(0, 8)
	local staffStroke = Instance.new("UIStroke", staffRoot)
	staffStroke.Thickness = 1
	staffStroke.Color = c3(70, 70, 82)
	staffStroke.Transparency = 0.3
	local staffTitle = Instance.new("TextLabel")
	staffTitle.BackgroundTransparency = 1
	staffTitle.Font = Enum.Font.GothamBold
	staffTitle.TextSize = 12
	staffTitle.TextColor3 = c3(255, 215, 0)
	staffTitle.TextXAlignment = Enum.TextXAlignment.Left
	staffTitle.Position = UDim2.new(0, 10, 0, 0)
	staffTitle.Size = UDim2.new(1, -40, 0, 26)
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
	staffText.TextColor3 = TXT
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
		local tiOn = flags["hud_targetinfo"] ~= false
		local invOn = flags["invwin_enabled"] == true
		tiRoot.Visible = tiOn
		invRoot.Visible = invOn
		staffRoot.Visible = flags["staffwin_enabled"] == true
		if not (tiOn or invOn) and flags["staffwin_enabled"] ~= true then return end

		-- target info + inventory at 4 Hz
		if (tiOn or invOn) and now - hudAt > 0.25 then
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
				invTitle.Text = ("TARGET — %s (AI)"):format(tgt.model.Name)
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
					tiText.Text = ("LOCK %s  %.0fm  %s"):format(tgt.model.Name, bd or 0, hpTxt)
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
				tiText.Text = "no player nearby"
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
				invTitle.Text = ("INVENTORY — %s"):format(best.Name)
				local hotN = 0
				local function hotRow(name, equipped)
					hotN += 1
					if hotN > MAX_HOT_ROWS then return end
					local r = ensure(hotRows, hotHolder, hotN)
					if r.lastName ~= name or r.lastEq ~= equipped then
						r.lastName, r.lastEq = name, equipped
						r.text.Text = (equipped and "[E] " or "") .. name
						r.frame.BackgroundColor3 = equipped and c3(110, 80, 20) or c3(30, 30, 36)
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
							r.frame.BackgroundColor3 = c3(30, 30, 36)
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
					tiText.Text = ("%s %s  %.0fm  %s\nGUN: %s\nARMOR: %s\nRES: %s"):format(
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
			staffTitle.Text = ("STAFF IN SERVER (%d)"):format(#names)
			staffRoot.Size = UDim2.fromOffset(250, 40 + math.max(#names, 1) * 16)
		end
	end))
end

-- ================================================================
-- // UI
-- ================================================================
local window = library:window({ name = os.date("Vault | %b %d %Y") })

-- preview re-parent hook (bound to every preview-relevant toggle/colorpicker)
local esp
local function update_elements()
	if esp and esp.refresh_elements then esp.refresh_elements() end
end

-- ——— COMBAT (empty template) ———
local combatTab = window:tab({ name = "Combat" })
do
	local column = combatTab:column()
	local sa = column:section({ name = "Silent Aim" })
	sa:toggle({ name = "Enabled", flag = "sa_enabled", default = true })
		:keybind({ name = "Silent Aim", flag = "sa_bind", callback = function(v)
			local fn = library.config_flags and library.config_flags["sa_enabled"]
			if fn then fn(v) end
		end })
	sa:toggle({ name = "Team Check", flag = "sa_team_check", default = true })
	sa:toggle({ name = "Target NPCs", flag = "sa_target_npc", default = true, tooltip = "Also lock Sleepers / Scientists / Animals / dummies" })
	sa:toggle({ name = "Show FOV", flag = "sa_show_fov", default = true })
	sa:toggle({ name = "Snapline", flag = "sa_snapline", default = true, tooltip = "Line from your crosshair to the silent-aim target — green when it's visible, red when covered" })
	sa:toggle({ name = "Target Crosshair", flag = "sa_cross", default = true, tooltip = "Draws a cross on the silent-aim target — green when it's visible, red when covered" })
	sa:dropdown({ name = "Aim Bone", flag = "sa_bone", items = { "Head", "Torso / HRP", "Closest" }, default = "Head" })
	sa:slider({ name = "FOV Radius", min = 20, max = 500, default = 120, interval = 1, flag = "sa_fov" })
	sa:slider({ name = "Bow Lead", min = 0, max = 1.5, default = 1, interval = 0.05, flag = "sa_bow_lead" })
	sa:slider({ name = "Max Distance", min = 0, max = 5000, default = 0, interval = 10, suffix = "m", flag = "sa_max_dist" })

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
	tb:toggle({ name = "Target NPCs", flag = "tb_npc", default = true, tooltip = "Also fire on Sleepers / Scientists / Animals (range dummies always count)" })
	tb:toggle({ name = "Visible Only (Snapline)", flag = "tb_visible", default = true, tooltip = "Fire only when the target is inside Silent Aim's FOV and the snapline is green (clear line of sight). Turn off to ignore cover." })
	tb:toggle({ name = "Skip While Holding", flag = "tb_skip_holding", default = true, tooltip = "Pause while your own left button is down so it never fights manual fire" })

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

	local bm = column2:section({ name = "Bullet Manipulation" })
	bm:toggle({ name = "Gun Peek", flag = "bp_enabled", tooltip = "Covered target: sidesteps your character so the muzzle itself clears the cover and fires legally — camera holds on the target while peeked, then snaps back" })
	bm:toggle({ name = "Desync Peek", flag = "bp_desync", tooltip = "EXPERIMENTAL: peeks by moving the server copy of your character instead of teleporting your real body. Off = real teleport sidestep (reliable damage). On = no teleport, but shots may not register if the spoofed position doesn't reach the server" })
	bm:slider({ name = "Peek Distance", min = 2, max = 20, default = 8, interval = 1, suffix = " studs", flag = "bp_max_offset", tooltip = "How far the character sidesteps around cover to find a clear firing spot" })
	bm:toggle({ name = "No Spread (packet)", flag = "pkt_nospread", tooltip = "Recenters Fire.direction on the held view server-side. Auto-skipped while Silent Aim is redirecting." })
	bm:toggle({ name = "Trajectory Arc", flag = "traj_arc", tooltip = "Draws the silent-aim shot's arc with a green (hit) / red (miss) impact marker" })
end

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

	section:toggle({ name = "Enabled", flag = "Enabled", callback = update_elements })
	section:toggle({ name = "Team Check", flag = "esp_team_check" })
	section:slider({ name = "Max Distance", min = 0, max = 2000, default = 0, interval = 10, suffix = "m", flag = "esp_max_dist" })

	section:toggle({ name = "Boxes", flag = "Boxes", callback = update_elements })
		:colorpicker({ name = "Box Color", flag = "Box_Color", color = c3(255,255,255), callback = update_elements })
	section:dropdown({ name = "Box Type", flag = "Box_Type", items = { "Full", "Corner" }, default = "Full", callback = update_elements })

	section:toggle({ name = "Filled Box", flag = "esp_filled_box" })
		:colorpicker({ name = "Fill Color", flag = "esp_filled_color", color = c3(0,0,0) })
	section:slider({ name = "Fill Transparency", min = 1, max = 9, default = 5, interval = 1, suffix = "/10", flag = "esp_filled_transparency" })

	section:toggle({ name = "Names", flag = "Names", callback = update_elements })
		:colorpicker({ name = "Name Color", flag = "Name_Color", color = c3(255,255,255), callback = update_elements })
	section:toggle({ name = "Display Names", flag = "esp_display_names" })

	section:toggle({ name = "Healthbar", flag = "Healthbar", callback = update_elements })
		:colorpicker({ name = "High HP Color", flag = "Health_High", color = c3(0,255,0), callback = update_elements })
		:colorpicker({ name = "Low HP Color", flag = "Health_Low", color = c3(255,0,0), callback = update_elements })
	section:toggle({ name = "Health Text", flag = "esp_health_text" })

	section:toggle({ name = "Distance", flag = "Distance", callback = update_elements })
		:colorpicker({ name = "Distance Color", flag = "Distance_Color", color = c3(200,200,200), callback = update_elements })

	section:toggle({ name = "Weapon", flag = "Weapon", callback = update_elements })
		:colorpicker({ name = "Weapon Color", flag = "Weapon_Color", color = c3(255,255,255), callback = update_elements })

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
	extra:slider({ name = "Cham Fill Transp", min = 0, max = 10, default = 5, interval = 1, suffix = "/10", flag = "esp_cham_fill_transparency" })
	extra:slider({ name = "Cham Out Transp", min = 0, max = 10, default = 5, interval = 1, suffix = "/10", flag = "esp_cham_outline_transparency" })

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

-- ——— ESP PREVIEW ———
-- noname.hack has no 3D character preview; the compatibility layer draws a
-- compact 2D panel from the same flags/colors as the live ESP.
pcall(function()
	esp = window.esp_section:esp_preview({})
	if esp and esp.refresh_elements then esp.refresh_elements() end
end)

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
getgenv().Vault = {
	library = library,
	flags = flags,
	window = window,
	unload = fullUnload,
	set = function(flag, value)
		local fn = library.config_flags and library.config_flags[flag]
		if fn then fn(value) else flags[flag] = value end
	end,
}

-- noname.hack is Drawing-based, so there is no ScreenGui/TextButton
-- "Unload Menu" tree to traverse. window:unload() handles library teardown.

pcall(function() window.set_menu_visibility(true) end)

print("[OVX] loaded — silent aim + triggerbot + gun peek/desync + snapline/crosshair + ESP/world + speed/phase/spider/freecam + kill aura + autofarm + hitsounds + trajectory arc + desync + inventory viewer + crosshair info + staff panel")

-- external state bridge (for console/state analysis + remote toggling)
getgenv().__ovx = { flags = flags, library = library, setf = library.config_flags, window = window, state = OVX }
