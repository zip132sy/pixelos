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

-- Flash EEPROM with small boot script
local eeprom = component.eeprom
local bootScript = [[
local component = require("component")
local computer = require("computer")
local internet = component.proxy(component.list("internet")())

if not internet then
	print("No internet card!")
	return
end

local urls = {
	"https://raw.githubusercontent.com/zip132sy/pixelos/master/Installer/Main.lua",
	"https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua"
}

local data
for i, url in ipairs(urls) do
	local conn = internet.request(url)
	if conn then
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
			break
		end
	end
end

if not data or #data < 1000 then
	print("Failed to download installer")
	return
end

load(data)()
]]

eeprom.set(bootScript)
eeprom.setLabel("PixelOS Installer")
print("Flashed EEPROM with boot script")
computer.shutdown(true)
