local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

-- Try to bind GPU to screen if needed
if gpu then
	local screenAvailable = component.isAvailable("screen")
	if not screenAvailable then
		for address in component.list("screen") do
			local ok, err = pcall(gpu.bind, address, true)
			if ok then break end
		end
	end
end

-- Checking if computer is tough enough for PixelOS
do
	local potatoes = {}

	-- GPU/screen
	local ok1, depth = pcall(gpu.getDepth)
	local ok2, resolution = pcall(gpu.maxResolution)
	if not ok1 or not depth or depth < 8 then
		table.insert(potatoes, "Tier 3 graphics card");
	end
	if not ok2 or not resolution or resolution < 160 then
		table.insert(potatoes, "Tier 3 screen");
	end

	-- RAM
	local ok, totalMem = pcall(computer.totalMemory)
	if not ok or not totalMem or totalMem < 2 * 1024 * 1024 then
		table.insert(potatoes, "2x tier 3.5 RAM");
	end

	-- HDD
	local filesystemFound = false
	for address in component.list("filesystem") do
		local ok, space = pcall(component.invoke, address, "spaceTotal")
		if ok and space and space >= 2 * 1024 * 1024 then
			filesystemFound = true
			break
		end
	end
	if not filesystemFound then
		table.insert(potatoes, "Tier 2 hard drive");
	end

	-- Internet
	if not component.isAvailable("internet") then
		table.insert(potatoes, "Internet card");
	end

	-- EEPROM
	if not component.isAvailable("eeprom") then
		table.insert(potatoes, "EEPROM");
	end

	-- Show error and return if requirements not met
	if #potatoes > 0 then
		print("PixelOS requirements not met:")
		for i = 1, #potatoes do
			print("  - " .. potatoes[i])
		end
		return
	end
end

-- Flash EEPROM with robust boot script
local eeprom = component.eeprom
local bootScript = [[
-- EEPROM boot script for PixelOS installer

-- Get screen and GPU for output if available
local screenAddress = component.list("screen")()
local gpuAddress = component.list("gpu")()
local gpu

if screenAddress and gpuAddress then
	gpu = component.proxy(gpuAddress)
	if gpu then
		gpu.bind(screenAddress, true)
		gpu.setBackground(0x000000)
		gpu.setForeground(0xFFFFFF)
		gpu.fill(1, 1, 80, 25, " ")
	end
end

-- Simple print function that uses GPU if available
local function print(text)
	if gpu then
		local y = 1
		local lines = {}
		local start = 1
		while start <= #text do
			local pos = text:find("\n", start)
			if pos then
				lines[#lines+1] = text:sub(start, pos-1)
				start = pos + 1
			else
				lines[#lines+1] = text:sub(start)
				break
			end
		end
		for i, line in ipairs(lines) do
			gpu.set(1, i, line)
			if i >= 25 then break end
		end
	end
end

-- Main boot process
print("PixelOS Installer Booting...")

-- Check if component is available
if not component then
	return
end

-- Get internet component
print("Checking internet...")
local internetAddress = component.list("internet")()
if not internetAddress then
	return
end

local internet = component.proxy(internetAddress)
if not internet or not internet.request then
	return
end

-- Download URLs
print("Downloading installer...")
local urls = {
	"https://raw.githubusercontent.com/zip132sy/pixelos/master/Installer/Main.lua",
	"https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua"
}

local data
for i, url in ipairs(urls) do
	print("Trying: " .. url)
	local conn = internet.request(url)
	if conn and conn.read and conn.close then
		local chunk
		data = ""
		while true do
			chunk = conn.read(8192)
			if chunk then
				data = data .. chunk
			else
				break
			end
		end
		conn.close()
		if data and #data > 1000 then
			print("Download successful!")
			break
		end
	end
end

if not data or #data < 1000 then
	return
end

-- Execute installer
print("Starting installer...")
local success, err = pcall(load, data)
if success then
	local func = load(data)
	if func then
		pcall(func)
	end
end
]]

eeprom.set(bootScript)
eeprom.setLabel("PixelOS Installer")
print("Flashed EEPROM with boot script")
computer.shutdown(true)
