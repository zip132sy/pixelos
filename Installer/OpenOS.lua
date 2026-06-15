local component = require("component")
local computer = require("computer")
local os = require("os")

-- Safe helper: get first component address of given type, or nil
local function getComponentAddress(type)
	if not component.list then return nil end
	local ok, iter = pcall(component.list, type)
	if not ok or not iter then return nil end
	if type(iter) == "function" then
		local ok2, addr = pcall(iter)
		if ok2 then return addr end
	elseif type(iter) == "table" then
		for addr in pairs(iter) do return addr end
	end
	return nil
end

-- Safe helper: get proxy for first component of given type, or nil
local function getComponentProxy(type)
	local addr = getComponentAddress(type)
	if not addr then return nil end
	local ok, proxy = pcall(component.proxy, addr)
	if ok then return proxy end
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

		local ok, iter = pcall(component.list, "filesystem")
		if ok and iter then
			if type(iter) == "function" then
				for addr in iter do
					if component.invoke(addr, "spaceTotal") >= 2 * 1024 * 1024 then
						filesystemFound = true
						break
					end
				end
			elseif type(iter) == "table" then
				for addr in pairs(iter) do
					if component.invoke(addr, "spaceTotal") >= 2 * 1024 * 1024 then
						filesystemFound = true
						break
					end
				end
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
	local internetAddr = nil
	local list = component.list("internet")
	if type(list) == "function" then
		internetAddr = list()
	elseif type(list) == "table" then
		for addr in pairs(list) do internetAddr = addr break end
	end
	if not internetAddr then
		local gpu = component.list("gpu")()
		if gpu then
			local g = component.proxy(gpu)
			local screen = component.list("screen")()
			if screen then
				local s = component.proxy(screen)
				g.bind(s.address, true)
				local w, h = g.getResolution()
				g.setBackground(0x000000)
				g.fill(1, 1, w, h, " ")
				g.setForeground(0xFFFFFF)
				g.set(math.floor(w/2 - 18), math.floor(h/2), "No internet card found!")
			end
		end
		while true do end
	end
	local internet = component.proxy(internetAddr)
	local connection, data, chunk = internet.request("https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua"), ""
	
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
