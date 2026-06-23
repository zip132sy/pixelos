local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

-- Checking if computer is tough enough for such a S T Y L I S H product as MineOS
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
			print("  x " .. potatoes[i])
		end

		return
	end
end

-- Checking if installer can be downloaded from Gitee
do
	local success, result = pcall(component.internet.request, "https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")

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
				computer.pullSignal(0.1)
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
component.eeprom.set([[
    local c = component
    local ok, internetAddr = pcall(function() return c.list("internet")() end)
    if not ok or not internetAddr then
        error("No internet card found")
    end
    local ok2, proxy = pcall(c.proxy, internetAddr)
    if not ok2 or not proxy then
        error("Failed to get internet proxy")
    end
    local ok3, connection = pcall(proxy.request, "https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")
    if not ok3 or not connection then
        error("Failed to connect")
    end
    local deadline = computer.uptime() + 10
    while computer.uptime() < deadline do
        local ok4, err = pcall(connection.finishConnect)
        if ok4 then
            break
        else
            if err then
                break
            else
                computer.pullSignal(0.1)
            end
        end
    end
    local data, chunk = ""
    while true do
        local ok5, cch = pcall(connection.read, math.huge)
        chunk = ok5 and cch or nil
        if chunk then
            data = data .. chunk
        else
            break
        end
    end
    pcall(connection.close)
    if #data > 0 then
        local ok6, fn = pcall(load, data)
        if ok6 and fn then
            pcall(fn)
        else
            error("Failed to load installer: " .. tostring(fn))
        end
    else
        error("Download failed, empty data")
    end
]])

computer.shutdown(true)
