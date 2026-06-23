-- PixelOS
---------------------------------------- System initialization ----------------------------------------

-- Obtaining boot filesystem component proxy
local bootFilesystemProxy
local bootOk, bootErr = pcall(function()
    local eepromAddr = component.list("eeprom")()
    if not eepromAddr then
        error("EEPROM component not found")
    end
    local bootAddr = component.invoke(eepromAddr, "getData")
    if not bootAddr or bootAddr == "" then
        error("EEPROM has no boot address configured")
    end
    -- bootAddr is the address of the filesystem component (e.g., "5d8e7c0a-...")
    return component.proxy(bootAddr)
end)
if bootOk then
    bootFilesystemProxy = bootErr
else
    bootFilesystemProxy = nil
end

-- Executes file from boot HDD during OS initialization (will be overriden in filesystem library later)
function dofile(path)
	if not bootFilesystemProxy then
		error("boot filesystem proxy not available")
	end
	local stream, reason = bootFilesystemProxy.open(path, "r")

	if stream then
		local data, chunk = ""

		while true do
			chunk = bootFilesystemProxy.read(stream, math.huge)

			if chunk then
				data = data .. chunk
			else
				break
			end
		end

		bootFilesystemProxy.close(stream)

		local result, reason = load(data, "=" .. path)

		if result then
			return result()
		else
			error(reason)
		end
	else
		error(reason)
	end
end

-- Initializing global package system
package = {
	paths = {
		["/Libraries/"] = true
	},
	loaded = {},
	loading = {}
}

-- Checks existense of specified path. It will be overriden after filesystem library initialization
local requireExists = bootFilesystemProxy.exists

-- Works the similar way as native Lua require() function
function require(module)
	-- For non-case-sensitive filesystems
	local lowerModule = unicode.lower(module)

	if package.loaded[lowerModule] then
		return package.loaded[lowerModule]
	elseif package.loading[lowerModule] then
		error("recursive require() call found: library \"" .. module .. "\" is trying to require another library that requires it\n" .. debug.traceback())
	else
		local errors = {}

		local function checkVariant(variant)
			if requireExists(variant) then
				return variant
			else
				table.insert(errors, "  variant \"" .. variant .. "\" not exists")
			end
		end

		local function checkVariants(path, module)
			return
				checkVariant(path .. module .. ".lua") or
				checkVariant(path .. module) or
				checkVariant(module)
		end

		local modulePath
		for path in pairs(package.paths) do
			modulePath =
				checkVariants(path, module) or
				checkVariants(path, unicode.upper(unicode.sub(module, 1, 1)) .. unicode.sub(module, 2, -1))
			
			if modulePath then
				package.loading[lowerModule] = true
				local result = dofile(modulePath)
				package.loaded[lowerModule] = result or true
				package.loading[lowerModule] = nil
				
				return result
			end
		end

		error("unable to locate library \"" .. module .. "\":\n" .. table.concat(errors, "\n"))
	end
end

local GPUAddress = component.list("gpu")()
local screenWidth, screenHeight = component.invoke(GPUAddress, "getResolution")

-- Displays title and currently required library when booting OS
local UIRequireTotal, UIRequireCounter = 14, 1

local function UIRequire(module)
	local function centrize(width)
		return math.floor(screenWidth / 2 - width / 2)
	end
	
	local title, width, total = "PixelOS", 26, 14
	local x, y, part = centrize(width), math.floor(screenHeight / 2 - 1), math.ceil(width * UIRequireCounter / UIRequireTotal)
	UIRequireCounter = UIRequireCounter + 1
	
	-- Title
	component.invoke(GPUAddress, "setForeground", 0x2D2D2D)
	component.invoke(GPUAddress, "set", centrize(#title), y, title)

	-- Progressbar
	component.invoke(GPUAddress, "setForeground", 0x878787)
	component.invoke(GPUAddress, "set", x, y + 2, string.rep("─", part))

	component.invoke(GPUAddress, "setForeground", 0xC3C3C3)
	component.invoke(GPUAddress, "set", x + part, y + 2, string.rep("─", width - part))

	return require(module)
end

-- Preparing screen for loading libraries
component.invoke(GPUAddress, "setBackground", 0xE1E1E1)
component.invoke(GPUAddress, "fill", 1, 1, screenWidth, screenHeight, " ")

-- Loading libraries
bit32 = bit32 or UIRequire("Bit32")
local paths = UIRequire("Paths")
local event = UIRequire("Event")
local filesystem = UIRequire("Filesystem")

-- Setting main filesystem proxy to what are we booting from
filesystem.setProxy(bootFilesystemProxy)

-- Replacing requireExists function after filesystem library initialization
requireExists = filesystem.exists

-- Loading other libraries
UIRequire("Component")
UIRequire("Keyboard")
UIRequire("Color")
UIRequire("Text")
UIRequire("Number")
local image = UIRequire("Image")
local screen = UIRequire("Screen")

-- Setting currently chosen GPU component as screen buffer main one
screen.setGPUAddress(GPUAddress)

local GUI = UIRequire("GUI")
local system = UIRequire("System")
UIRequire("Network")

-- Filling package.loaded with default global variables for OpenOS bitches
package.loaded.bit32 = bit32
package.loaded.computer = computer
package.loaded.component = component
package.loaded.unicode = unicode

-- Boot error display - same format as Minified EFI
local function showBootError(message)
    local gpu = component.list("gpu")()
    local screenAddr = component.list("screen")()
    if gpu and screenAddr then
        component.invoke(gpu, "bind", screenAddr)
        local w, h = component.invoke(gpu, "getResolution")
        component.invoke(gpu, "setBackground", 0x2D2D2D)
        component.invoke(gpu, "fill", 1, 1, w, h, " ")
        component.invoke(gpu, "setForeground", 0xFF0000)
        component.invoke(gpu, "set", math.floor((w - #message) / 2), math.floor(h / 2), message)
        component.invoke(gpu, "setForeground", 0x696969)
        component.invoke(gpu, "set", 2, h - 2, "Press any key...")
    end
    computer.pullSignal()
    computer.shutdown(false)
    computer.pullSignal(0.1)
    computer.start()
end

-- Password Unlock Screen
local function showPasswordUnlock()
    local gpu = component.list("gpu")()
    local screenAddr = component.list("screen")()
    
    if not (gpu and screenAddr) then return false end
    
    component.invoke(gpu, "bind", screenAddr)
    local width, height = component.invoke(gpu, "getResolution")
    
    local keyboard = require("Keyboard")
    local event = require("event")
    local os = os
    
    local password = ""
    local maxLength = 32
    local cursorVisible = true
    local cursorTimer = 0
    
    -- Load BIOS config to check password
    local ok, Encryption = pcall(require, "Encryption")
    local ok2, filesystem = pcall(require, "Filesystem")
    if not ok or not Encryption or not ok2 or not filesystem then
        return false
    end
    
    -- Check if any drive is encrypted
    local encryptedDrives = {}
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy and Encryption.isEncrypted(proxy) then
            table.insert(encryptedDrives, address)
        end
    end
    
    if #encryptedDrives == 0 then
        return false
    end
    
    local passwordHash = nil
    local configPath = "/System/BIOS/config.cfg"
    if filesystem.exists(configPath) then
        local success, config = pcall(function()
            return filesystem.readTable(configPath)
        end)
        if success and config and config.passwordHash then
            passwordHash = config.passwordHash
        end
    end
    
    if not passwordHash then
        return false
    end
    
    local function draw()
        component.invoke(gpu, "setBackground", 0x1E1E1E)
        component.invoke(gpu, "setForeground", 0xFFFFFF)
        component.invoke(gpu, "fill", 1, 1, width, height, " ")
        
        -- Title
        component.invoke(gpu, "setForeground", 0x3366CC)
        component.invoke(gpu, "set", math.floor((width - 18) / 2), math.floor(height / 2) - 10, "PixelOS Unlock")
        
        -- Password input area
        component.invoke(gpu, "setBackground", 0x2D2D2D)
        component.invoke(gpu, "setForeground", 0xFFFFFF)
        component.invoke(gpu, "fill", math.floor(width / 2) - 20, math.floor(height / 2) - 3, 40, 3, " ")
        
        -- Draw password with cursor
        local displayStr = string.rep("*", #password)
        if cursorVisible then
            displayStr = displayStr .. "_"
        end
        component.invoke(gpu, "set", math.floor(width / 2) - 20 + 1, math.floor(height / 2) - 2, displayStr)
        
        -- Status bar background
        component.invoke(gpu, "setBackground", 0x2D2D2D)
        component.invoke(gpu, "fill", 1, height, width, 1, " ")
        
        -- Current time (left side of status bar)
        local timeStr = os.date("%H:%M:%S")
        component.invoke(gpu, "setForeground", 0xCCCCCC)
        component.invoke(gpu, "set", 2, height, timeStr)
        
        -- Battery (right side of status bar)
        local battery = computer.energy() / computer.maxEnergy()
        if battery == math.huge then battery = 1 end
        local batteryStr = string.format("%.1f%%", battery * 100)
        component.invoke(gpu, "set", width - #batteryStr - 1, height, batteryStr)
        
        -- Bottom buttons
        component.invoke(gpu, "setBackground", 0x1E1E1E)
        component.invoke(gpu, "setForeground", 0xCC4940)
        component.invoke(gpu, "set", math.floor(width / 2) - 25, height - 2, "[Shutdown]")
        component.invoke(gpu, "setForeground", 0xFF9800)
        component.invoke(gpu, "set", math.floor(width / 2) + 8, height - 2, "[Reboot]")
        component.invoke(gpu, "setForeground", 0x66DB80)
        component.invoke(gpu, "set", math.floor(width / 2) - 6, height - 2, "[Unlock]")
        
        -- Instructions
        component.invoke(gpu, "setForeground", 0x888888)
        local hint = "Enter 确认输入密码"
        component.invoke(gpu, "set", math.floor((width - #hint) / 2), math.floor(height / 2) + 2, hint)
    end
    
    draw()
    
    while true do
        local signal = {event.pull(0.5)}
        local eventType = signal[1]
        
        -- Update cursor
        cursorTimer = cursorTimer + 0.5
        if cursorTimer >= 0.5 then
            cursorVisible = not cursorVisible
            cursorTimer = 0
            draw()
        end
        
        if eventType == "key_down" then
            local key = signal[4]
            local char = signal[3]
            
            if key == keyboard.ENTER then
                -- Verify password
                local inputHash = Encryption.hashPassword(password)
                if inputHash == passwordHash then
                    return true
                else
                    password = ""
                    draw()
                end
            elseif key == keyboard.BACKSPACE then
                if #password > 0 then
                    password = string.sub(password, 1, -2)
                    draw()
                end
            elseif char and #password < maxLength then
                password = password .. string.char(char)
                draw()
            end
        elseif eventType == "touch" then
            local x, y = signal[3], signal[4]
            
            -- Check shutdown button
            if y == height - 2 and x >= math.floor(width / 2) - 25 and x <= math.floor(width / 2) - 15 then
                computer.shutdown(true)
            end
            
            -- Check reboot button
            if y == height - 2 and x >= math.floor(width / 2) + 8 and x <= math.floor(width / 2) + 15 then
                computer.shutdown(false)
                computer.pullSignal(0.1)
                computer.start()
            end
        end
    end
end

-- Show password unlock screen after boot
local unlocked, err = pcall(showPasswordUnlock)
if not unlocked then
    showBootError("Unlock error: " .. tostring(err))
elseif unlocked == false then
    -- No password protection, continue booting
end

---------------------------------------- Main loop ----------------------------------------

-- Creating OS workspace, which contains every window/menu/etc.
local function main()
    local workspace = GUI.workspace()
    system.setWorkspace(workspace)

    -- "double_touch" event handler
    local doubleTouchInterval, doubleTouchX, doubleTouchY, doubleTouchButton, doubleTouchUptime, doubleTouchcomponentAddress = 0.3
    event.addHandler(
        function(signalType, componentAddress, x, y, button, user)
            if signalType == "touch" then
                local uptime = computer.uptime()
                
                if doubleTouchX == x and doubleTouchY == y and doubleTouchButton == button and doubleTouchcomponentAddress == componentAddress and uptime - doubleTouchUptime <= doubleTouchInterval then
                    computer.pushSignal("double_touch", componentAddress, x, y, button, user)
                    event.skip("touch")
                end

                doubleTouchX, doubleTouchY, doubleTouchButton, doubleTouchUptime, doubleTouchcomponentAddress = x, y, button, uptime, componentAddress
            end
        end
    )

    -- Screen component attaching/detaching event handler
    event.addHandler(
        function(signalType, componentAddress, componentType)
            if (signalType == "component_added" or signalType == "component_removed") and componentType == "screen" then
                local GPUAddress = screen.getGPUAddress()

                local function bindScreen(address)
                    screen.setScreenAddress(address, false)
                    screen.setColorDepth(screen.getMaxColorDepth())

                    workspace:draw()
                end

                if signalType == "component_added" then
                    if not component.invoke(GPUAddress, "getScreen") then
                        bindScreen(componentAddress)
                    end
                else
                    if not component.invoke(GPUAddress, "getScreen") then
                        local address = component.list("screen")()
                        
                        if address then
                            bindScreen(address)
                        end
                    end
                end
            end
        end
    )

    -- Logging in
    system.authorize()

    -- Main loop with UI regeneration after errors 
    while true do
        local success, path, line, traceback = system.call(workspace.start, workspace, 0)
        
        if success then
            break
        else
            system.updateWorkspace()
            system.updateDesktop()
            workspace:draw()
            
            system.error(path, line, traceback)
            workspace:draw()
        end
    end
end

local ok, err = pcall(main)
if not ok then
    showBootError("Main loop error: " .. tostring(err))
end