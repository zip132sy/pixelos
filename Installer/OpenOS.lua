local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

-- Function to display messages in EEPROM environment
local function displayMessage(message)
	-- Try to use gpu if available
	if gpu then
		local screen = component.list("screen")()
		if screen then
			gpu.bind(screen, true)
			local w, h = gpu.getResolution()
			gpu.setBackground(0x000000)
			gpu.setForeground(0xFFFFFF)
			gpu.fill(1, 1, w, h, " ")
			local x = math.floor(w / 2 - #message / 2)
			local y = math.floor(h / 2)
			gpu.set(x, y, message)
		end
	end
	-- Also beep to indicate error
	computer.beep(1000, 0.5)
end

do
	local potatoes = {}

	if gpu.getDepth() < 8 or gpu.maxResolution() < 160 then
		table.insert(potatoes, "Tier 3 graphics card and screen");
	end

	if computer.totalMemory() < 2 * 1024 * 1024 then
		table.insert(potatoes, "At least 2x tier 3.5 RAM modules");
	end

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

	if not component.isAvailable("internet") then
		table.insert(potatoes, "Internet card");
	end

	if not component.isAvailable("eeprom") then
		table.insert(potatoes, "EEPROM");
	end

	if #potatoes > 0 then
		displayMessage("Your computer does not meet the minimum system requirements")
		computer.shutdown()
		return
	end
end

do
	local success, result = pcall(component.internet.request, "https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")

	if not success then
		if result then
			if result:match("PKIX") then
				displayMessage("Download server SSL certificate was rejected")
			else
				displayMessage("Download server unavailable")
			end
		else
			displayMessage("Download server unavailable")
		end
		computer.shutdown()
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
		displayMessage("Download server unavailable")
		computer.shutdown()
		return
	end
end

component.eeprom.set([[
	local function getComponentAddress(componentType)
		local iter = component.list(componentType)
		if type(iter) == "function" then
			return iter()
		elseif type(iter) == "table" then
			for _, addr in pairs(iter) do
				if type(addr) == "string" then
					return addr
				end
			end
		end
		return nil
	end
	
	local function displayMessage(message)
		-- Try to use gpu if available
		local gpu = component.list("gpu")()
		if gpu then
			gpu = component.proxy(gpu)
			local screen = component.list("screen")()
			if screen then
				gpu.bind(screen, true)
				local w, h = gpu.getResolution()
				gpu.setBackground(0x000000)
				gpu.setForeground(0xFFFFFF)
				gpu.fill(1, 1, w, h, " ")
				local x = math.floor(w / 2 - #message / 2)
				local y = math.floor(h / 2)
				gpu.set(x, y, message)
			end
		end
		-- Also beep to indicate error
		computer.beep(1000, 0.5)
	end
	
	local internetAddr = getComponentAddress("internet")
	if not internetAddr then
		displayMessage("No internet component found")
		return
	end
	
	local internet
	-- Try different ways to get internet proxy
	if component.proxy then
		internet = component.proxy(internetAddr)
	elseif component.invoke then
		-- Fallback to using component.invoke directly
		internet = {}
		internet.request = function(url)
			return component.invoke(internetAddr, "request", url)
		end
		internet.close = function(connection)
			if connection and connection.close then
				connection.close()
			end
		end
	end
	if not internet then
		displayMessage("Failed to get internet proxy")
		return
	end
	
	local connection, data, chunk = internet.request("https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua"), ""
	
	if not connection then
		displayMessage("Failed to connect to server")
		return
	end
	
	while true do
		chunk = connection.read(math.huge)
		
		if chunk then
			data = data .. chunk
		else
			break
		end
	end
	
	connection.close()
	
	local result, err = load(data)
	if result then
		result()
	else
		displayMessage("Failed to load installer")
	end
]])

computer.shutdown(true)
