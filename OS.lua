-- PixelOS
---------------------------------------- System initialization ----------------------------------------

-- BIOS boot logging system (log all boot events to disk, avoid circular dependencies)
local biosLogFile = nil
local biosLogPath = "/BIOS_Boot.log"
local fs = nil  -- Store filesystem reference

-- Most basic error display function (works without filesystem)
local function displayCriticalError(message)
    local gpu = component.list("gpu")()
    local screen = component.list("screen")()
    
    if gpu and screen then
        local gpuProxy = component.proxy(gpu)
        gpuProxy.bind(screen)
        local width, height = gpuProxy.getResolution()
        
        gpuProxy.setBackground(0x000000)
        gpuProxy.fill(1, 1, width, height, " ")
        gpuProxy.setForeground(0xFF0000)
        gpuProxy.set(2, 2, "CRITICAL ERROR")
        gpuProxy.setForeground(0xFFFFFF)
        
        -- Display error message with word wrap
        local maxLen = width - 4
        local lines = {}
        local currentLine = ""
        
        for word in message:gmatch("%S+") do
            if #currentLine + #word + 1 > maxLen then
                table.insert(lines, currentLine)
                currentLine = word
            else
                currentLine = currentLine .. (currentLine == "" and "" or " ") .. word
            end
        end
        if currentLine ~= "" then
            table.insert(lines, currentLine)
        end
        
        local startY = math.floor(height / 2 - #lines / 2)
        for i, line in ipairs(lines) do
            gpuProxy.setForeground(0xFFFFFF)
            gpuProxy.set(2, startY + i - 1, line)
        end
        
        gpuProxy.setForeground(0x878787)
        gpuProxy.set(2, height - 1, "System halted. Press any key to shutdown.")
    end
    
    -- Wait for key press then shutdown
    computer.pullSignal()
    computer.shutdown()
end

-- BIOS boot logging functions
local function logBIOSBoot(message)
    if biosLogFile and fs then
        local timestamp = "unknown"
        if os and os.date then
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        end
        pcall(fs.write, fs, biosLogFile, string.format("[%s] BOOT: %s\n", timestamp, message))
        pcall(fs.flush, fs, biosLogFile)
    end
end

local function logBIOSBootError(message)
    if biosLogFile and fs then
        local timestamp = "unknown"
        if os and os.date then
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        end
        pcall(fs.write, fs, biosLogFile, string.format("[%s] ERROR: %s\n", timestamp, message))
        pcall(fs.flush, fs, biosLogFile)
    end
end

-- Early log function that works before filesystem is available
local function earlyLog(message)
    local success, err = pcall(function()
        -- Try to get filesystem early
        if not fs then
            local fsList = component.list("filesystem")
            if fsList then
                for addr in fsList do
                    local proxySuccess, proxy = pcall(component.proxy, addr)
                    if proxySuccess and proxy then
                        fs = proxy
                        -- Try to open log file
                        local openSuccess, file = pcall(fs.open, fs, biosLogPath, "w")
                        if openSuccess and file then
                            biosLogFile = file
                            -- Write initialization message
                            local timestamp = "unknown"
                            if os and os.date then
                                timestamp = os.date("%Y-%m-%d %H:%M:%S")
                            end
                            pcall(fs.write, fs, biosLogFile, string.format("[%s] BOOT: === PixelOS BIOS Boot Log ===\n", timestamp))
                            pcall(fs.flush, fs, biosLogFile)
                            break
                        end
                    end
                end
            end
        end
        -- Now try to log the message
        if biosLogFile and fs then
            local timestamp = "unknown"
            if os and os.date then
                timestamp = os.date("%Y-%m-%d %H:%M:%S")
            end
            pcall(fs.write, fs, biosLogFile, string.format("[%s] BOOT: %s\n", timestamp, message))
            pcall(fs.flush, fs, biosLogFile)
        end
    end)
    
    -- Don't display error if logging fails, just continue without logging
    -- if not success then
    --     displayCriticalError("Failed to initialize logging: " .. tostring(err))
    -- end
end

-- Execute string with error handling (with recursion protection)
local executeDepth = 0
local function executeString(...) 
    executeDepth = executeDepth + 1
    if executeDepth > 2 then
        -- Try to log error
        if fs then
            logBIOSBootError("启动递归过深，停止启动")
        end
        executeDepth = 0
        return false, "Boot loop detected"
    end
    
    local result, reason = load(...) 
    
    if result then 
        result, reason = xpcall(result, debug.traceback) 
        
        if result then 
            executeDepth = 0
            return true
        end 
    end 
    
    -- Log the error
    if fs then
        logBIOSBootError("启动失败：" .. tostring(reason))
    end
    
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
        if fs then logBIOSBoot("等待用户确认...") end
        computer.pullSignal()
    end
    
    executeDepth = 0
    return false, reason
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
    -- Initialize logging as early as possible
    earlyLog("=== Boot 函数开始执行 ===")
    
    -- Debug: Check component.list behavior
    local testIter = component.list("filesystem")
    earlyLog("component.list('filesystem') 返回类型: " .. type(testIter))
    
    local firstAddr = testIter()
    earlyLog("第一个文件系统地址: " .. tostring(firstAddr) .. " (类型: " .. type(firstAddr) .. ")")
    
    local selectedBootAddress = checkAndSelectBootSystem()
    
    earlyLog("checkAndSelectBootSystem 返回值: " .. tostring(selectedBootAddress) .. " (类型: " .. type(selectedBootAddress) .. ")")
    
    -- Debug: If it's a table, print its contents
    if type(selectedBootAddress) == "table" then
        local tableInfo = "Table contents: "
        for k, v in pairs(selectedBootAddress) do
            tableInfo = tableInfo .. k .. "=" .. tostring(v) .. ", "
        end
        earlyLog(tableInfo)
    end
    
    if not selectedBootAddress then
        -- No bootable filesystem found
        earlyLog("未找到可启动的文件系统")
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
    
    earlyLog("已选择启动设备：" .. tostring(selectedBootAddress))

    -- Ensure selectedBootAddress is a string
    if type(selectedBootAddress) ~= "string" then
        -- Try to get the first filesystem address directly
        local fsIter = component.list("filesystem")
        local fsAddr = fsIter()
        earlyLog("尝试直接获取文件系统地址: " .. tostring(fsAddr))
        
        if fsAddr then
            selectedBootAddress = fsAddr
            earlyLog("已使用直接获取的地址: " .. selectedBootAddress)
        else
            displayCriticalError("Invalid boot address: " .. tostring(selectedBootAddress) .. " (类型: " .. type(selectedBootAddress) .. ")")
        end
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
    local UIRequireTotal = 14
    local UIRequireCounter = 1
    
    local function UIRequire(module)
	if GPUAddress then
		local gpuProxy = component.proxy(GPUAddress)
		local function centrize(width)
			return math.floor(screenWidth / 2 - width / 2)
		end
		
		local title, width = "PixelOS", 26
		local x, y = centrize(width), math.floor(screenHeight / 2 - 1)
		local part = math.ceil(width * UIRequireCounter / UIRequireTotal)
		
		-- Title
		gpuProxy.setForeground(0x2D2D2D)
		gpuProxy.set(centrize(#title), y, title)

		-- Progressbar
		gpuProxy.setForeground(0x878787)
		gpuProxy.set(x, y + 2, string.rep("-", part))

		gpuProxy.setForeground(0xC3C3C3)
		gpuProxy.set(x + part, y + 2, string.rep("-", width - part))
		
		UIRequireCounter = UIRequireCounter + 1
	end
    
    -- Log which module is being loaded
    logBIOSBoot("加载模块：" .. module .. " (" .. UIRequireCounter-1 .. "/" .. UIRequireTotal .. ")")

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
    logBIOSBoot("开始加载：" .. module)
    local success, result = pcall(UIRequire, module)
    if not success then
        logBIOSBootError("加载失败：" .. module .. " - " .. tostring(result))
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
    logBIOSBoot("成功加载：" .. module)
    return result
end

bit32 = bit32 or safeUIRequire("Bit32")
logBIOSBoot("Bit32 加载完成")
local paths = safeUIRequire("Paths")
logBIOSBoot("Paths 加载完成")
local event = safeUIRequire("Event")
logBIOSBoot("Event 加载完成")
safeUIRequire("Component")
logBIOSBoot("Component 加载完成")

-- Loading filesystem library after component
local filesystem = safeUIRequire("Filesystem")
logBIOSBoot("Filesystem 加载完成")

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
logBIOSBoot("Keyboard 加载完成")
local color = safeUIRequire("Color")
logBIOSBoot("Color 加载完成")
local text = safeUIRequire("Text")
logBIOSBoot("Text 加载完成")
local number = safeUIRequire("Number")
logBIOSBoot("Number 加载完成")
local image = safeUIRequire("Image")
logBIOSBoot("Image 加载完成")
local screen = safeUIRequire("Screen")
logBIOSBoot("Screen 加载完成")

-- Setting currently chosen GPU component as screen buffer main one
if GPUAddress and screen then
    screen.setGPUAddress(GPUAddress)
end

local GUI = safeUIRequire("GUI")
logBIOSBoot("GUI 加载完成")
local system = safeUIRequire("System")
logBIOSBoot("System 加载完成")
safeUIRequire("Network")
logBIOSBoot("Network 加载完成")
logBIOSBoot("所有库加载完成，开始初始化...")

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

    -- Initialize BIOS log at the very beginning (after filesystem is available)
    local filesystem = require("Filesystem")
    logBIOSBoot("PixelOS 启动初始化...")
    logBIOSBoot("系统版本：" .. (system and system.version() or "未知"))
    
    -- Logging in
    logBIOSBoot("开始系统授权...")
    system.authorize()
    logBIOSBoot("系统授权完成")

    -- Main loop with UI regeneration after errors 
    logBIOSBoot("开始主事件循环...")
    while true do
        logBIOSBoot("进入事件循环迭代...")
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
local success, err = pcall(function()
    -- Basic system check before boot
    earlyLog("系统启动检查...")
    
    if not component then
        displayCriticalError("Component API is not available!")
    end
    
    if not component.list("gpu")() then
        displayCriticalError("No GPU found! Cannot continue without graphics.")
    end
    
    if not component.list("screen")() then
        displayCriticalError("No screen found! Cannot continue without display.")
    end
    
    local fsCount = 0
    for addr in component.list("filesystem") do
        fsCount = fsCount + 1
    end
    
    if fsCount == 0 then
        displayCriticalError("No filesystem found! Cannot boot without storage.")
    end
    
    earlyLog("系统检查通过，开始启动...")
    earlyLog("找到 " .. fsCount .. " 个文件系统")
    
    -- Test component.proxy with a known string to see if that's the issue
    local testAddr = component.list("filesystem")()
    earlyLog("测试 component.proxy 与地址: " .. tostring(testAddr) .. " (类型: " .. type(testAddr) .. ")")
    
    if testAddr then
        local testProxy = component.proxy(testAddr)
        earlyLog("测试 component.proxy 成功: " .. tostring(testProxy))
    end
    
    -- Now call boot function
    boot()
end)

if not success then
    -- Display critical error
    displayCriticalError("Boot failed: " .. tostring(err) .. "\n\nCheck /BIOS_Boot.log for details.")
end
