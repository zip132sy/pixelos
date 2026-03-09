local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

-- Checking if computer is tough enough for such a S T Y L I S H product as PixelOS
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
			print("  ⨯ " .. potatoes[i])
		end

		return
	end
end

-- Checking if installer can be downloaded from Gitee, because of PKIX errors, server blacklists, etc
do
	-- Try multiple URLs in case one fails
	local urls = {
		"https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua",
		"https://raw.gitee.com/zip132sy/pixelos/master/Installer/Main.lua"
	}
	
	local success, result, url
	local selectedUrl = nil
	
	for i, testUrl in ipairs(urls) do
		print("Trying URL " .. i .. ": " .. testUrl)
		success, result = pcall(component.internet.request, testUrl)
		
		if success then
			local deadline = computer.uptime() + 5
			local message
			
			while computer.uptime() < deadline do
				success, message = result.finishConnect()
				if success then
					selectedUrl = testUrl
					print("Success with URL " .. i .. "!")
					break
				else
					if message then
						result.close()
						break
					else
						os.sleep(0.1)
					end
				end
			end
			
			if selectedUrl then
				break
			end
		else
			print("Failed to create request: " .. tostring(result))
		end
	end
	
	if not selectedUrl then
		print("")
		print("========================================")
		print("DOWNLOAD FAILED")
		print("========================================")
		print("Could not connect to any Gitee URL.")
		print("")
		print("Please check:")
		print("  1. OpenComputers.cfg: internet.enabled=true")
		print("  2. internet.http.enabled=true")
		print("  3. Gitee.com is accessible from your network")
		print("  4. Try using a different Minecraft version")
		print("")
		print("If the problem persists, you may need to:")
		print("  - Download files manually and install offline")
		print("  - Use a different hosting service")
		print("========================================")
		return
	end
end

-- Flashing EEPROM with tiny script that will run installer itself after reboot.
-- It's necessary, because we need clean computer without OpenOS hooks to computer.pullSignal()
-- After installation, this will load the BootManager
component.eeprom.set([[
	local internet = component.proxy(component.list("internet")())
	if not internet then
		print("No internet card!")
		return
	end
	
	local connection = internet.request("https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")
	if not connection then
		print("Failed to connect!")
		return
	end
	
	local data = ""
	local chunk
	
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

-- Set EEPROM label to "PixelOS Install BIOS"
component.eeprom.setLabel("PixelOS Install BIOS")

computer.shutdown(true)
