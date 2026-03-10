local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

-- Checking if computer is tough enough for PixelOS
do
	local potatoes = {}

	-- GPU/screen
	if gpu.getDepth() < 8 or gpu.maxResolution() < 160 then
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
	if not component.isAvailable("internet") then
		table.insert(potatoes, "Internet card");
	end

	-- EEPROM
	if not component.isAvailable("eeprom") then
		table.insert(potatoes, "EEPROM");
	end

	-- SORRY BRO NOT TODAY
	if #potatoes > 0 then
		print("Your computer does not meet the minimum system requirements:")

		for i = 1, #potatoes do
			print("  - " .. potatoes[i])
		end

		return
	end
end

-- Checking if installer can be downloaded (test multiple URLs)
local workingURL = nil
local testURLs = {
	"https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua",
	"https://raw.githubusercontent.com/zip132sy/pixelos/master/Installer/Main.lua"
}

for i, url in ipairs(testURLs) do
	print("Testing connection: " .. url)
	local success, result = pcall(component.internet.request, url)

	if success and result then
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

		if success then
			print("Connection successful!")
			workingURL = url
			break
		else
			print("Connection failed: " .. tostring(message))
		end
	else
		print("Failed to create connection: " .. tostring(result))
	end
end

if not workingURL then
	print("Error: All download servers are unavailable")
	print("Please check your internet connection and try again")
	return
end

-- Flashing EEPROM with tiny script that will run installer itself after reboot.
-- It's necessary, because we need clean computer without OpenOS hooks to computer.pullSignal()
print("Flashing EEPROM...")
component.eeprom.set(string.format([[
	local connection, data, chunk = component.proxy(component.list("internet")()).request("%s"), ""
	
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
]], workingURL))

component.eeprom.setLabel("PixelOS Installer")

print("EEPROM flashed successfully")
print("Rebooting to start installation...")

computer.shutdown(true)
