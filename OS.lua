-- PixelOS
---------------------------------------- System initialization ----------------------------------------

-- BIOS boot logging system (only log errors to disk)
local biosLogFile = nil
local biosLogPath = "/BIOS_Boot.log"

local function initBIOSLog()
	if not biosLogFile then
		local filesystem = require("Filesystem")
		biosLogFile = filesystem.open(biosLogPath, "w")
	end
end

local function logBIOSBoot(message)
	if biosLogFile then
		local filesystem = require("Filesystem")
		local timestamp = os and os.date("%Y-%m-%d %H:%M:%S") or "unknown"
		filesystem.write(biosLogFile, string.format("[%s] BOOT: %s\n", timestamp, message))
		filesystem.flush(biosLogFile)
	end
end

local function logBIOSBootError(message)
	if biosLogFile then
		local filesystem = require("Filesystem")
		local timestamp = os and os.date("%Y-%m-%d %H:%M:%S") or "unknown"
		filesystem.write(biosLogFile, string.format("[%s] ERROR: %s\n", timestamp, message))
		filesystem.flush(biosLogFile)
	end
end

local function closeBIOSLog()
	if biosLogFile then
		local filesystem = require("Filesystem")
		filesystem.close(biosLogFile)
		biosLogFile = nil
	end
end

-- Execute string with error handling
local function executeString(...) 
    local result, reason = load(...) 
    
    if result then 
        result, reason = xpcall(result, debug.traceback) 
        
        if result then 
            return 
        end 
    end 
    
    -- Log the error
    logBIOSBootError("启动失败：" .. tostring(reason))
    
    -- Try to display error if GPU is available
    local gpu = component.list("gpu")()
    local screen = component.list("screen")()
    
    if gpu and screen then
        local gpuProxy = component.proxy(gpu)
        gpuProxy.bind(screen)
        local width, height = gpuProxy.getResolution()
        
        gpuProxy.setBackground(0x2D2D2D)
        gpuProxy.fill(1, 1, width, height, " ")
        gpuProxy.setForeground(0xFF0000)
        gpuProxy.set(2, 3, "Error: " .. tostring(reason))
        gpuProxy.setForeground(0xFFFFFF)
        gpuProxy.set(2, 5, "Press any key to continue...")
        logBIOSBoot("等待用户确认...")
        computer.pullSignal()
    end
    
    -- If all else fails, try to boot from any filesystem
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy.exists("/OS.lua") then
            local handle, data, chunk = proxy.open("/OS.lua", "rb"), ""
            if handle then
                repeat
                    chunk = proxy.read(handle, math.huge)
                    data = data .. (chunk or "")
                until not chunk
                proxy.close(handle)
                
                logBIOSBoot("尝试从文件系统启动：" .. tostring(address))
                executeString(data, "=/OS.lua")
                break
            end
        end
    end
end

-- First, check for multiple bootable systems and show selection if needed
local function checkAndSelectBootSystem()
    local systems = {}
    local eeprom = component.list("eeprom")()
    local currentBootAddress = eeprom and component.invoke(eeprom, "getData")
    
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        local label = proxy.getLabel() or "Unlabeled Drive"
        
        if proxy.exists("/OS.lua") then
            table.insert(systems, {
                address = address,
                label = label,
                proxy = proxy,
                isCurrent = (address == currentBootAddress)
            })
        end
    end
    
    if #systems <= 1 then
        return systems[1] and systems[1].address or component.list("filesystem")()
    end
    
    local gpu = component.list("gpu")()
    local screen = component.list("screen")()
    
    if not gpu or not screen then
        return systems[1] and systems[1].address or component.list("filesystem")()
    end
    
    local gpuProxy = component.proxy(gpu)
    gpuProxy.bind(screen)
    local width, height = gpuProxy.getResolution()
    
    local selectedIndex = 1
    for i, sys in ipairs(systems) do
        if sys.isCurrent then
            selectedIndex = i
            break
        end
    end
    
    local function drawSelector()
        gpuProxy.setBackground(0x1E1E1E)
        gpuProxy.fill(1, 1, width, height, " ")
        
        local title = "PixelOS Boot Manager"
        local titleX = math.floor((width - #title) / 2)
        gpuProxy.setForeground(0x3366CC)
        gpuProxy.set(titleX, 3, title)
        
        local separator = string.rep("=", width - 4)
        gpuProxy.setForeground(0x787878)
        gpuProxy.set(2, 5, separator)
        
        local startY = 7
        for i, system in ipairs(systems) do
            local isSelected = (i == selectedIndex)
            local marker = isSelected and "> " or "  "
            local currentMarker = system.isCurrent and " [CURRENT]" or ""
            local text = marker .. system.label .. " (" .. system.address:sub(1, 8) .. "..." .. currentMarker .. ")"
            
            gpuProxy.setForeground(isSelected and 0xFFFFFF or 0xC3C3C3)
            gpuProxy.set(3, startY + i - 1, text)
        end
        
        local helpText = "Use UP/DOWN to select, Enter to boot, Esc to boot current"
        local helpX = math.floor((width - #helpText) / 2)
        gpuProxy.setForeground(0x696969)
        gpuProxy.set(helpX, height - 2, helpText)
    end
    
    drawSelector()
    
    while true do
        local signalType, _, _, key, _, _ = computer.pullSignal()
        
        if signalType == "key_down" then
            if key == 200 then
                selectedIndex = math.max(1, selectedIndex - 1)
                drawSelector()
            elseif key == 208 then
                selectedIndex = math.min(#systems, selectedIndex + 1)
                drawSelector()
            elseif key == 28 then
                return systems[selectedIndex].address
            elseif key == 1 then
                return currentBootAddress
            end
        end
    end
end

-- Main boot function
local function boot()
    local selectedBootAddress = checkAndSelectBootSystem()
    
    if not selectedBootAddress then
        -- No bootable filesystem found
        local gpu = component.list("gpu")()
        local screen = component.list("screen")()
        
        if gpu and screen then
            local gpuProxy = component.proxy(gpu)
            gpuProxy.bind(screen)
            local width, height = gpuProxy.getResolution()
            
            gpuProxy.setBackground(0x2D2D2D)
            gpuProxy.fill(1, 1, width, height, " ")
            gpuProxy.setForeground(0xFF0000)
            gpuProxy.set(2, 3, "No bootable filesystem found")
            gpuProxy.setForeground(0xFFFFFF)
            gpuProxy.set(2, 5, "Please connect a disk with PixelOS")
            gpuProxy.set(2, 7, "Press any key to restart...")
            computer.pullSignal()
        end
        computer.shutdown(true)
    end

    -- Obtaining boot filesystem component proxy
    local bootFilesystemProxy = component.proxy(selectedBootAddress)

    -- Executes file from boot HDD during OS initialization (will be overriden in filesystem library later)
    function dofile(path)
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

    -- Filling package.loaded with default global variables for OpenOS bitches
    package.loaded.bit32 = bit32
    package.loaded.computer = computer
    package.loaded.component = component

    -- Ensure unicode is available
    if not unicode then
        -- Basic unicode implementation for boot process
        unicode = {
            lower = string.lower,
            upper = string.upper,
            sub = string.sub,
            len = string.len
        }
    end

    package.loaded.unicode = unicode

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
    local screenWidth, screenHeight = 80, 25
    
    if GPUAddress then
        local gpuProxy = component.proxy(GPUAddress)
        local screenAddress = component.list("screen")()
        if screenAddress then
            gpuProxy.bind(screenAddress)
            screenWidth, screenHeight = gpuProxy.getResolution()
        end
    end

    -- Displays title and currently required library when booting OS
    local UIRequireTotal, UIRequireCounter = 14, 1

    local function UIRequire(module)
	if GPUAddress then
		local gpuProxy = component.proxy(GPUAddress)
		local function centrize(width)
			return math.floor(screenWidth / 2 - width / 2)
		end
		
		local title, width, total = "PixelOS", 26, 14
		local x, y, part = centrize(width), math.floor(screenHeight / 2 - 1), math.ceil(width * UIRequireCounter / UIRequireTotal)
		UIRequireCounter = UIRequireCounter + 1
		
		-- Title
		gpuProxy.setForeground(0x2D2D2D)
		gpuProxy.set(centrize(#title), y, title)

		-- Progressbar
		gpuProxy.setForeground(0x878787)
		gpuProxy.set(x, y + 2, string.rep("-", part))

		gpuProxy.setForeground(0xC3C3C3)
		gpuProxy.set(x + part, y + 2, string.rep("-", width - part))
	end

	return require(module)
    end

    -- Preparing screen for loading libraries
    if GPUAddress then
        local gpuProxy = component.proxy(GPUAddress)
        gpuProxy.setBackground(0xE1E1E1)
        gpuProxy.fill(1, 1, screenWidth, screenHeight, " ")
    end

    -- Loading libraries with error handling
local function safeUIRequire(module)
    local success, result = pcall(UIRequire, module)
    if not success then
        -- Try to display error if possible
        local gpu = component.list("gpu")()
        local screen = component.list("screen")()
        
        if gpu and screen then
            local gpuProxy = component.proxy(gpu)
            gpuProxy.bind(screen)
            local width, height = gpuProxy.getResolution()
            
            gpuProxy.setBackground(0x2D2D2D)
            gpuProxy.fill(1, 1, width, height, " ")
            gpuProxy.setForeground(0xFF0000)
            gpuProxy.set(2, 3, "Error loading " .. module .. ": " .. tostring(result))
            gpuProxy.setForeground(0xFFFFFF)
            gpuProxy.set(2, 5, "Press any key to continue...")
            computer.pullSignal()
        end
        return nil
    end
    return result
end

bit32 = bit32 or safeUIRequire("Bit32")
local paths = safeUIRequire("Paths")
local event = safeUIRequire("Event")
safeUIRequire("Component")

-- Loading filesystem library after component
local filesystem = safeUIRequire("Filesystem")

-- Setting main filesystem proxy to what are we booting from
if filesystem then
    filesystem.setProxy(bootFilesystemProxy)
    
    -- Replacing requireExists function after filesystem library initialization
    requireExists = filesystem.exists
else
    -- Fallback if filesystem library fails to load
    requireExists = function() return false end
end

-- Loading other libraries
local keyboard = safeUIRequire("Keyboard")
local color = safeUIRequire("Color")
local text = safeUIRequire("Text")
local number = safeUIRequire("Number")
local image = safeUIRequire("Image")
local screen = safeUIRequire("Screen")

-- Setting currently chosen GPU component as screen buffer main one
if GPUAddress and screen then
    screen.setGPUAddress(GPUAddress)
end

local GUI = safeUIRequire("GUI")
local system = safeUIRequire("System")
safeUIRequire("Network")

---------------------------------------- Main loop ----------------------------------------

-- Check if required libraries are available
if not GUI or not system or not event then
    -- Try to display error if possible
    local gpu = component.list("gpu")()
    local screen = component.list("screen")()
    
    if gpu and screen then
        local gpuProxy = component.proxy(gpu)
        gpuProxy.bind(screen)
        local width, height = gpuProxy.getResolution()
        
        gpuProxy.setBackground(0x2D2D2D)
        gpuProxy.fill(1, 1, width, height, " ")
        gpuProxy.setForeground(0xFF0000)
        gpuProxy.set(2, 3, "Critical error: Required libraries failed to load")
        gpuProxy.setForeground(0xFFFFFF)
        gpuProxy.set(2, 5, "Please check your installation")
        gpuProxy.set(2, 7, "Press any key to shutdown...")
        computer.pullSignal()
    end
    computer.shutdown(true)
    return
end

-- Check if tablet mode is enabled and screen is small
local useTabletMode = false

-- Try to read user configuration for tablet mode preference
local userSettingsPath = "/Settings/UserSettings.cfg"
local fs = component.list("filesystem")()
if fs then
    local proxy = component.proxy(fs)
    if proxy.exists(userSettingsPath) then
        local handle = proxy.open(userSettingsPath, "rb")
        if handle then
            local config = {}
            local success, result = pcall(function()
                local data = ""
                local chunk
                repeat
                    chunk = proxy.read(handle, math.huge)
                    data = data .. (chunk or "")
                until not chunk
                config = load("return " .. data)()
            end)
            proxy.close(handle)
            
            if success and config.tabletMode ~= nil then
                useTabletMode = config.tabletMode
            else
                -- Default: check screen size
                if GPUAddress and screen then
                    local gpuProxy = component.proxy(GPUAddress)
                    gpuProxy.bind(screen)
                    local screenWidth, screenHeight = gpuProxy.getResolution()
                    useTabletMode = (screenWidth <= 60 or screenHeight <= 20)
                end
            end
        end
    else
        -- No config file, use screen size detection
        if GPUAddress and screen then
            local gpuProxy = component.proxy(GPUAddress)
            gpuProxy.bind(screen)
            local screenWidth, screenHeight = gpuProxy.getResolution()
            useTabletMode = (screenWidth <= 60 or screenHeight <= 20)
        end
    end
end

-- Creating OS workspace, which contains every window/menu/etc.
if not useTabletMode then
    -- Traditional desktop mode
    local workspace = GUI.workspace()
    if workspace then
        system.setWorkspace(workspace)
    end

    -- "double_touch" event handler
    local doubleTouchInterval = 0.3
    local doubleTouchX, doubleTouchY, doubleTouchButton, doubleTouchUptime, doubleTouchcomponentAddress
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
    if screen then
        event.addHandler(
            function(signalType, componentAddress, componentType)
                if (signalType == "component_added" or signalType == "component_removed") and componentType == "screen" then
                    local GPUAddress = screen.getGPUAddress()

                    local function bindScreen(address)
                        screen.setScreenAddress(address, false)
                        screen.setColorDepth(screen.getMaxColorDepth())

                        if workspace then
                            workspace:draw()
                        end
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
    end

    -- Initialize BIOS log at the very beginning
    initBIOSLog()
    logBIOSBoot("PixelOS 启动初始化...")
    logBIOSBoot("系统版本：" .. (system and system.version() or "未知"))
    
    -- Logging in
    system.authorize()
    logBIOSBoot("系统授权完成")

    -- Main loop with UI regeneration after errors 
    while true do
        logBIOSBoot("进入主事件循环...")
        local success, path, line, traceback = system.call(workspace.start, workspace, 0)
        
        if success then
            logBIOSBoot("主事件循环正常退出")
            break
        else
            logBIOSBootError("主循环错误：" .. tostring(path) .. " 行 " .. tostring(line))
            system.updateWorkspace()
            system.updateDesktop()
            workspace:draw()
            
            system.error(path, line, traceback)
            workspace:draw()
        end
    end
else
    -- Tablet mode - use simplified desktop
    local workspace = GUI.workspace()
    if workspace then
        system.setWorkspace(workspace)
    end
    system.authorize()
    
    while true do
        local success, path, line, traceback = system.call(workspace.start, workspace, 0)
        if success then
            break
        end
    end
end
end

-- Run with error handling
local success, err = pcall(boot)
if not success then
    -- Display error using GPU directly with multi-line support
    local gpu = component.gpu
    if gpu then
        gpu.setForeground(0xFF0000)
        gpu.setBackground(0x000000)
        gpu.fill(1, 1, gpu.getResolution())
        
        local screenWidth, screenHeight = gpu.getResolution()
        local errorMsg = "Critical error during boot: " .. tostring(err)
        
        -- Split error message into multiple lines (max 60 chars per line)
        local maxLineLength = math.floor(screenWidth * 0.8)
        local lines = {}
        
        for i = 1, math.ceil(#errorMsg / maxLineLength) do
            local startIdx = (i - 1) * maxLineLength + 1
            local endIdx = math.min(i * maxLineLength, #errorMsg)
            table.insert(lines, errorMsg:sub(startIdx, endIdx))
        end
        
        -- Display title
        local title = "Boot Error"
        local titleX = math.floor(screenWidth / 2 - #title / 2)
        gpu.set(titleX, 2, 0xFFFFFF, title)
        
        -- Display error lines (centered)
        local startY = math.floor(screenHeight / 2 - #lines / 2)
        for i, line in ipairs(lines) do
            local x = math.floor(screenWidth / 2 - #line / 2)
            gpu.set(x, startY + i, 0xFF0000, line)
        end
        
        -- Display scroll instructions if needed
        if #lines > screenHeight - 10 then
            local instruction = "Press any key to continue"
            local instX = math.floor(screenWidth / 2 - #instruction / 2)
            gpu.set(instX, screenHeight - 2, 0x878787, instruction)
        end
    end
    
    -- Wait for user input before continuing
    computer.pullSignal()
    
    -- Try to boot from any available filesystem
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy.exists("/OS.lua") then
            local handle, data, chunk = proxy.open("/OS.lua", "rb"), ""
            if handle then
                repeat
                    chunk = proxy.read(handle, math.huge)
                    data = data .. (chunk or "")
                until not chunk
                proxy.close(handle)
                
                executeString(data, "=/OS.lua")
                break
            end
        end
    end
end
