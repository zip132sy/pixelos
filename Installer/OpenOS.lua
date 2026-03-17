local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

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
		print("Your computer does not meet the minimum system requirements:")

		for i = 1, #potatoes do
			print("  ⨯ " .. potatoes[i])
		end

		return
	end
end

do
	local success, result = pcall(component.internet.request, "https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")

	if not success then
		if result then
			if result:match("PKIX") then
				print("Download server SSL certificate was rejected. Update Java or install certificate manually")
			else
				print("Download server unavailable: " .. tostring(result))
			end
		else
			print("Download server unavailable for unknown reasons")
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
		print("Download server unavailable. Check if gitee.com is not blocked")
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
	
	local internetAddr = getComponentAddress("internet")
	if not internetAddr then
		print("No internet component found")
		return
	end
	
	local internet = component.proxy(internetAddr)
	if not internet then
		print("Failed to get internet proxy")
		return
	end
	
	local connection, data, chunk = internet.request("https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua"), ""
	
	if not connection then
		print("Failed to connect to server")
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
		print("Failed to load installer: " .. tostring(err))
	end
]])

computer.shutdown(true)
