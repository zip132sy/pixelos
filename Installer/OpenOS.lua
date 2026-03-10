local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

if gpu then
	local screenAvailable = component.isAvailable("screen")
	if not screenAvailable then
		for address in component.list("screen") do
			local ok, err = pcall(gpu.bind, address, true)
			if ok then break end
		end
	end
end

do
	local potatoes = {}

	local ok1, depth = pcall(gpu.getDepth)
	local ok2, resolution = pcall(gpu.maxResolution)
	if not ok1 or not depth or depth < 8 then
		table.insert(potatoes, "Tier 3 graphics card");
	end
	if not ok2 or not resolution or resolution < 160 then
		table.insert(potatoes, "Tier 3 screen");
	end

	local ok, totalMem = pcall(computer.totalMemory)
	if not ok or not totalMem or totalMem < 2 * 1024 * 1024 then
		table.insert(potatoes, "2x tier 3.5 RAM");
	end

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

	if not component.isAvailable("internet") then
		table.insert(potatoes, "Internet card");
	end

	if not component.isAvailable("eeprom") then
		table.insert(potatoes, "EEPROM");
	end

	if #potatoes > 0 then
		print("PixelOS requirements not met:")
		for i = 1, #potatoes do
			print("  - " .. potatoes[i])
		end
		return
	end
end

do
	local success, result = pcall(component.internet.request, "https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")

	if not success then
		if result then
			if result:match("PKIX") then
				print("SSL certificate rejected. Update Java or install certificate manually")
			else
				print("Server unavailable: " .. tostring(result))
			end
		else
			print("Server unavailable for unknown reasons")
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
		print("Server unavailable. Check if gitee.com is not blocked")
		return
	end
end

component.eeprom.set([[
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

computer.shutdown(true)
