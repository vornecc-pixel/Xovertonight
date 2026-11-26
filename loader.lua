-- ============================================================
-- OVX / noname.hack loader
-- Paste this file (or the one-liner below) into your executor.
-- ============================================================
local url = "https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/refs/heads/arena/0ab86f62-xovertonight/main.lua"

local ok, err = pcall(function()
	local source = game:HttpGet(url)
	local chunk = assert(loadstring(source), "[OVX] failed to compile main.lua")
	chunk()
end)

if not ok then
	warn("[OVX] loader failed: " .. tostring(err))
end

-- One-liner:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/vornecc-pixel/Xovertonight/refs/heads/arena/0ab86f62-xovertonight/main.lua"))()
