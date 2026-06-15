local component = require("component")
local computer = require("computer")
local os = require("os")

-- Safe helper: get first component address of given type, or nil
local function getComponentAddress(type)
	local ok, iter = pcall(component.list, type)
	if not ok then return nil end
	if type(iter) == "function" then
		return iter()
	elseif type(iter) == "table" then
		for addr in pairs(iter) do return addr end
	end
	return nil
end

-- Safe helper: get proxy for first component of given type, or nil
local function getComponentProxy(type)
	local addr = getComponentAddress(type)
	if addr then
		local ok, proxy = pcall(component.proxy, addr)
		if ok then return proxy end
	end
	return nil
end

-- Checking if computer is tough enough for PixelOS
do
	local potatoes = {}

	-- GPU/screen
	local gpu = getComponentProxy("gpu")
	if not gpu then
		table.insert(potatoes, "Tier 3 graphics card and screen");
	elseif gpu.getDepth() < 8 or gpu.maxResolution() < 160 then
		table.insert(potatoes, "Tier 3 graphics card and screen");
	end

	-- RAM
	if computer.totalMemory() < 2 * 1024 * 1024 then
		table.insert(potatoes, "At least 2x tier 3.5 RAM modules");
	end

	-- HDD
	do
		local filesystemFound = false

		for address in component.list("filesystem") do
			if component.invoke(address, "spaceTotal") >= 2 * 1024 * 1024 then
				filesystemFound = true
				break
			end
		end

		if not filesystemFound then
			table.insert(potatoes, "At least tier 2 hard disk drive");
		end	
	end

	-- Internet
	if not getComponentAddress("internet") then
		table.insert(potatoes, "Internet card");
	end

	-- EEPROM
	if not getComponentAddress("eeprom") then
		table.insert(potatoes, "EEPROM");
	end

	-- SORRY BRO NOT TODAY
	if #potatoes > 0 then
		print("Your computer does not meet the minimum system requirements:")

		for i = 1, #potatoes do
			print("  x " .. potatoes[i])
		end

		return
	end
end

-- Checking if installer can be downloaded from Gitee
do
	local internet = getComponentProxy("internet")
	if not internet then
		print("Internet card not available")
		return
	end

	local success, result = pcall(internet.request, "https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")

	if not success then
		if result then
			if result:match("PKIX") then
				print("Download server SSL certificate was rejected")
			else
				print("Download server is unavailable: " .. tostring(result))
			end
		else
			print("Download server is unavailable for unknown reasons")
		end

		return
	end

	local deadline = computer.uptime() + 5
	local message

	while computer.uptime() < deadline do
		success, message = result.finishConnect()

		if success then
			break
		else
			if message then
				break
			else
				os.sleep(0.1)
			end
		end
	end

	result.close()

	if not success then
		print("Download server is unavailable. Check if gitee.com is not blocked")
		return
	end
end

-- Flashing EEPROM with tiny script that will run installer itself after reboot.
-- It's necessary, because we need clean computer without OpenOS hooks to computer.pullSignal()
local eeprom = getComponentProxy("eeprom")
if eeprom then
	eeprom.set([[
	local connection, data, chunk = component.proxy(component.list("internet")()).request("https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua"), ""
	
	while true do
		chunk = connection.read(math.huge)
		
		if chunk then
			data = data .. chunk
		else
			break
		end
	end
	
	connection.close()
	
	load(data)()
]])
end

computer.shutdown(true)
