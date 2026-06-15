local component = require("component")
local computer = require("computer")
local os = require("os")

-- Function to display messages in EEPROM environment
local function displayMessage(message)
	print(message)
end

do
	local potatoes = {}

	local gpuAddr = component.list("gpu")()
	if gpuAddr then
		local gpu = component.proxy(gpuAddr)
		if gpu.getDepth() < 8 or gpu.maxResolution() < 160 then
			table.insert(potatoes, "Tier 3 graphics card and screen");
		end
	else
		table.insert(potatoes, "Graphics card");
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
	displayMessage("Checking download server...")
	
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

	displayMessage("Connecting to server...")
	
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
	
	displayMessage("Server connection successful")
end

-- Display installation started message
displayMessage("Starting PixelOS installation...")

component.eeprom.set([[
	local function print(message)
		local success, gpu = pcall(component.proxy, component.list("gpu")())
		if success then
			local success, screen = pcall(component.proxy, component.list("screen")())
			if success then
				gpu.bind(screen.address, true)
				local w, h = gpu.getResolution()
				gpu.setBackground(0x000000)
				gpu.setForeground(0xFFFFFF)
				gpu.fill(1, 1, w, h, " ")
				local x = math.floor(w / 2 - #message / 2)
				local y = math.floor(h / 2)
				gpu.set(x, y, message)
			end
		end
	end
	
	print("Starting PixelOS installation...")
	
	local internetAddr = component.list("internet")()
	local internet = internetAddr and component.proxy(internetAddr)
	if not internet then
		print("No internet card found")
		computer.shutdown()
	end
	local response, reason = internet.request("https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")
	
	if response then
		print("Downloading installer...")
		local data = ""
		while true do
			local chunk, reason = response.read(math.huge)
			if chunk then
				data = data .. chunk
			else
				response.close()
				break
			end
		end
		
		print("Loading installer...")
		local func, err = load(data)
		if func then
			print("Starting installer...")
			func()
		else
			print("Failed to load installer")
		end
	else
		print("Failed to connect to server")
	end
]])

computer.shutdown(true)
