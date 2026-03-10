-- Based on MineOS by IgorTimofeev
-- Modified for PixelOS

-- Ensure basic modules are loaded early
-- In OpenComputers, these should be available as global variables
local component = component
local computer = computer
local internet = component and component.internet
local event = event

-- Checking for required components
local function getComponentAddress(name)
	if not component then return nil end
	return component.list(name)()
end

local EEPROMAddress, internetAddress, GPUAddress
local success, errorMessage = pcall(function()
	EEPROMAddress, internetAddress, GPUAddress = 
		getComponentAddress("eeprom"),
		getComponentAddress("internet"),
		getComponentAddress("gpu")
end)

if not success then
	if print then
		print("Warning: Some components may be missing, installation will continue: " .. tostring(errorMessage))
	end
end

-- Binding GPU to screen in case it's not done yet
local screenWidth, screenHeight
if GPUAddress then
	local screenAddress = getComponentAddress("screen")
	if screenAddress then
		pcall(component.invoke, GPUAddress, "bind", screenAddress)
		local success, w, h = pcall(component.invoke, GPUAddress, "getResolution")
		if success then
			screenWidth, screenHeight = w, h
		end
	end
end

-- Repository URLs
local repositoryURLs = {
	{name = "Gitee (推荐)", url = "https://gitee.com/zip132sy/pixelos/raw/master/"},
	{name = "GitHub", url = "https://raw.githubusercontent.com/zip132sy/pixelos/master/"}
}
local repositoryURL = repositoryURLs[1].url
local installerURL = "Installer/"
local EFIURL = "EFI/Minified.lua"

local installerPath = "/PixelOS installer/"
local installerPicturesPath = installerPath .. "Installer/Pictures/"
local OSPath = "/"

local temporaryFilesystemProxy, selectedFilesystemProxy
local localization

--------------------------------------------------------------------------------

-- Working with components directly before system libraries are downloaded & initialized
local outputLines = {}
local logFilePath = "/tmp-install-log.txt"

local function log(message)
	local fullMessage = "[Main] " .. message
	if print then
		print(fullMessage)
	end
	table.insert(outputLines, fullMessage)
	
	-- Real-time save to log file
	if logFilePath and selectedFilesystemProxy and temporaryFilesystemProxy then
		local ok, err = pcall(function()
			local content = table.concat(outputLines, "\n")
			-- Try to save to both temp and selected filesystem
			local proxy = temporaryFilesystemProxy or selectedFilesystemProxy
			local fileHandle = proxy.open(logFilePath, "w")
			if fileHandle then
				proxy.write(fileHandle, content)
				proxy.close(fileHandle)
			end
		end)
	end
end

local function centrize(width)
	if not screenWidth then return 1 end
	return math.floor(screenWidth / 2 - width / 2)
end

local function centrizedText(y, color, text)
	if not GPUAddress or not screenWidth or not component then return end
	pcall(component.invoke, GPUAddress, "fill", 1, y, screenWidth, 1, " ")
	pcall(component.invoke, GPUAddress, "setForeground", color)
	pcall(component.invoke, GPUAddress, "set", centrize(#text), y, text)
end

local function title()
	if not screenHeight then return 1 end
	local y = math.floor(screenHeight / 2 - 1)
	local systemName = localization and localization.systemName or "PixelOS"
	centrizedText(y, 0x2D2D2D, systemName)

	return y + 2
end

local function progress(value, text)
	if not GPUAddress or not component then return end
	local width = 26
	local x, y, part = centrize(width), title(), math.ceil(width * value)
	
	pcall(component.invoke, GPUAddress, "setForeground", 0x878787)
	pcall(component.invoke, GPUAddress, "set", x, y, string.rep("─", part))
	pcall(component.invoke, GPUAddress, "setForeground", 0xC3C3C3)
	pcall(component.invoke, GPUAddress, "set", x + part, y, string.rep("─", width - part))
	
	-- Show progress text if provided
	if text then
		pcall(component.invoke, GPUAddress, "setForeground", 0x666666)
		pcall(component.invoke, GPUAddress, "set", centrize(#text), y + 1, text)
	end
end

local function filesystemPath(path)
	return path:match("^(.+%/).*") or ""
end

local function filesystemName(path)
	return path:match("%/?([^%/]+%/?)$")
end

local function filesystemHideExtension(path)
	return path:match("(.+)%..+") or path
end

local urlCache = {}
local fileHashes = {}
local sha256

-- Try to load SHA-256 library for verification (optional)
local function initSha256()
	if not sha256 then
		pcall(function()
			sha256 = require("SHA-256")
		end)
	end
end

local internetConnections = {}

local function rawRequest(url, chunkHandler)
	-- Try each repository URL until one works
	log("=== Starting rawRequest for: " .. url .. " ===")
	
	-- Check if internet component is available
	if not internetAddress then
		log("ERROR: Internet component is not available")
		return false, "Internet component is not available"
	end
	
	-- Small delay to avoid "too many open connections" error from server
	os.sleep(0.5)
	
	for urlIndex, repo in ipairs(repositoryURLs) do
		::nextUrl::
		local baseRepoUrl = repo.url
		-- Don't encode / and : as they are valid in URLs
		local fullUrl = baseRepoUrl .. url:gsub("([^%w%-%_%.%~/:])", function(char)
			return string.format("%%%02X", string.byte(char))
		end)
		
		log("Trying URL " .. urlIndex .. ": " .. fullUrl)
		log("Internet address: " .. tostring(internetAddress))
		
		-- Create NEW connection
		log("Creating new connection for: " .. fullUrl)
		local internetHandle, reason = component.invoke(internetAddress, "request", fullUrl)
		log("internet.request returned: handle=" .. tostring(internetHandle) .. ", reason=" .. tostring(reason))
		if not internetHandle then
			log("FAILED to establish connection! reason=" .. tostring(reason))
			-- Try next URL
			log("Moving to next URL...")
			-- Add delay between URLs to avoid rate limiting
			os.sleep(0.5)
			goto continue
		end
		
		log("Connection established successfully, reading data...")
		local chunk, reason
		while true do
			chunk, reason = internetHandle.read(math.huge) 
			log("read() returned: chunk=" .. tostring(chunk ~= nil) .. ", reason=" .. tostring(reason))
			
			if chunk then
				chunkHandler(chunk)
			else
				if reason then
					log("Download FAILED: " .. tostring(reason))
					-- Close this connection and try next URL
					internetHandle.close()
					log("Moving to next URL...")
					-- Add delay between URLs to avoid rate limiting
					os.sleep(0.5)
					goto continue
				else
					log("Download completed successfully!")
					-- Close connection after successful download
					internetHandle.close()
					return true, nil
				end
				
				break
			end
		end
		::continue::
	end
	
	-- All URLs failed
	log("=== rawRequest FAILED for all URLs ===")
	return false, "Connection failed for all repository URLs"
end

local function request(url)
	-- Check cache first
	if urlCache[url] then
		log("Cache hit for: " .. url)
		return urlCache[url]
	end

	log("Requesting: " .. url)

	-- Try to read from multiple sources in order of priority
	local sources = {}
	
	-- 1. Current filesystem (where the installer is running from)
	local currentDir
	if component then
		currentDir = component.list("filesystem")()
	end
	if currentDir and component then
		local currentFilesystemProxy = component.proxy(currentDir)
		table.insert(sources, {proxy = currentFilesystemProxy, name = "Current Filesystem"})
		log("Added current filesystem to sources: " .. currentDir)
	end
	
	-- 2. Selected filesystem (where OS will be installed)
	if selectedFilesystemProxy then
		table.insert(sources, {proxy = selectedFilesystemProxy, name = "Selected Filesystem"})
		log("Added selected filesystem to sources: " .. selectedFilesystemProxy.address)
	end
	
	-- 3. Temporary filesystem (for installer files)
	if temporaryFilesystemProxy and temporaryFilesystemProxy.address then
		table.insert(sources, {proxy = temporaryFilesystemProxy, name = "Temporary Filesystem"})
		log("Added temporary filesystem to sources: " .. temporaryFilesystemProxy.address)
	end
	
	-- Try each source
	for _, source in ipairs(sources) do
		local proxy = source.proxy
		local sourceName = source.name
		
		log("Checking source: " .. sourceName)
		
		-- Check the exact path
		if proxy and proxy.exists(url) then
			log("Found file at exact path: " .. url)
			local fileHandle = proxy.open(url, "rb")
			if fileHandle then
				log("Opened file successfully: " .. url)
				local data = proxy.read(fileHandle)
				proxy.close(fileHandle)
				-- Verify file integrity (skip for first download, verify on retry)
				if urlCache[url .. "_verified"] then
					log("Verifying file integrity for: " .. url)
					initSha256()
					if sha256 then
						local hash = sha256(data)
						local expectedHash = fileHashes[url]
						if expectedHash and hash ~= expectedHash then
							log("File hash mismatch for: " .. url .. " (got: " .. hash .. ", expected: " .. expectedHash .. ")")
							log("Will re-download: " .. url)
							-- Continue to download
						else
							log("File hash verified for: " .. url)
							urlCache[url] = data
							return data
						end
					else
						log("SHA-256 library not available, skipping verification")
						urlCache[url] = data
						return data
					end
				else
					-- First time, cache and return
					urlCache[url] = data
					urlCache[url .. "_verified"] = true
					log("Read file successfully: " .. url)
					return data
				end
			else
				log("Failed to open file: " .. url)
			end
		else
			log("File not found at exact path: " .. url)
		end
		
		-- Check in PixelOS directory
		local pixelOSPath = "/PixelOS/" .. url
		if proxy and proxy.exists(pixelOSPath) then
			log("Found file in PixelOS directory: " .. pixelOSPath)
			local fileHandle = proxy.open(pixelOSPath, "rb")
			if fileHandle then
				log("Opened file successfully: " .. pixelOSPath)
				local data = proxy.read(fileHandle)
				proxy.close(fileHandle)
				-- Cache the result
				urlCache[url] = data
				log("Read file successfully: " .. pixelOSPath)
				return data
			else
				log("Failed to open file: " .. pixelOSPath)
			end
		else
			log("File not found in PixelOS directory: " .. pixelOSPath)
		end
		
		-- Check in current directory (for relative paths)
		local currentPath = url
		if proxy and proxy.exists(currentPath) then
			log("Found file in current directory: " .. currentPath)
			local fileHandle = proxy.open(currentPath, "rb")
			if fileHandle then
				log("Opened file successfully: " .. currentPath)
				local data = proxy.read(fileHandle)
				proxy.close(fileHandle)
				-- Cache the result
				urlCache[url] = data
				log("Read file successfully: " .. currentPath)
				return data
			else
				log("Failed to open file: " .. currentPath)
			end
		else
			log("File not found in current directory: " .. currentPath)
		end
	end

	-- Fallback to network request if local file doesn't exist
	log("Falling back to network request for: " .. url)
	local data = ""
	local success, errorMessage = rawRequest(url, function(chunk)
		data = data .. chunk
	end)

	if success then
		-- Cache the result
		urlCache[url] = data
		log("Network request completed for: " .. url)
		return data
	else
		log("Network request failed, using empty data: " .. errorMessage)
		-- Return empty data instead of throwing error
		urlCache[url] = data
		return data
	end
end

local downloadedFilesCache = {}
local directoryCache = {}

local function download(url, path)
	-- Check cache first
	if downloadedFilesCache[path] then
		log("Cache hit for download: " .. path)
		return
	end

	log("Downloading: " .. url .. " to " .. path)

	-- Always use selectedFilesystemProxy for all files
	local targetProxy = selectedFilesystemProxy
	if not targetProxy then
		log("No selected filesystem, using temporary filesystem")
		targetProxy = temporaryFilesystemProxy
	end
	
	if not targetProxy then
		log("No filesystem available, skipping download")
		-- Don't throw error, just skip this file
		downloadedFilesCache[path] = true
		return
	end

	log("Using filesystem: " .. targetProxy.address)

	-- Create directory if not cached
	local dirPath = filesystemPath(path)
	if not directoryCache[dirPath] then
		log("Creating directory: " .. dirPath)
		local success, errorMsg = pcall(targetProxy.makeDirectory, dirPath)
		if success then
			directoryCache[dirPath] = true
		else
			log("Warning: Failed to create directory: " .. tostring(errorMsg))
		end
	end

	-- Check if file exists
	local fileExists = targetProxy.exists(path)
	
	if fileExists then
		-- Delete existing file to ensure clean download
		log("Deleting existing file: " .. path)
		pcall(targetProxy.remove, path)
	end

	-- Try to read from local filesystem first (if available)
	local localPath = path:gsub(installerPath, "")
	log("Trying local file: " .. localPath)
	
	-- Check if the file exists in the current directory
	local currentDir
	if component then
		currentDir = component.list("filesystem")()
	end
	if currentDir and component then
		local currentFilesystemProxy = component.proxy(currentDir)
		log("Current filesystem: " .. currentDir)
		
		-- Check the exact path first
		if currentFilesystemProxy and currentFilesystemProxy.exists(localPath) then
			log("Found local file at exact path: " .. localPath)
			local sourceHandle = currentFilesystemProxy.open(localPath, "rb")
			if sourceHandle then
				log("Opened local file: " .. localPath)
				local fileHandle = targetProxy.open(path, "wb")
				if fileHandle then
					log("Opened target file: " .. path)
					local chunk
					repeat
						chunk = currentFilesystemProxy.read(sourceHandle, math.huge)
						if chunk then
							targetProxy.write(fileHandle, chunk)
						end
					until not chunk
					currentFilesystemProxy.close(sourceHandle)
					targetProxy.close(fileHandle)
					downloadedFilesCache[path] = true
					log("Copied local file: " .. localPath .. " to " .. path)
					return
				else
					log("Failed to open target file: " .. path)
				end
				currentFilesystemProxy.close(sourceHandle)
			else
				log("Failed to open local file: " .. localPath)
			end
		else
			log("Local file not found at exact path: " .. localPath)
		end
		
		-- Check in PixelOS directory
		local pixelOSPath = "/PixelOS/" .. localPath
		if currentFilesystemProxy and currentFilesystemProxy.exists(pixelOSPath) then
			log("Found local file in PixelOS directory: " .. pixelOSPath)
			local sourceHandle = currentFilesystemProxy.open(pixelOSPath, "rb")
			if sourceHandle then
				log("Opened local file: " .. pixelOSPath)
				local fileHandle = targetProxy.open(path, "wb")
				if fileHandle then
					log("Opened target file: " .. path)
					local chunk
					repeat
						chunk = currentFilesystemProxy.read(sourceHandle, math.huge)
						if chunk then
							targetProxy.write(fileHandle, chunk)
						end
					until not chunk
					currentFilesystemProxy.close(sourceHandle)
					targetProxy.close(fileHandle)
					downloadedFilesCache[path] = true
					log("Copied local file: " .. pixelOSPath .. " to " .. path)
					return
				else
					log("Failed to open target file: " .. path)
				end
				currentFilesystemProxy.close(sourceHandle)
			else
				log("Failed to open local file: " .. pixelOSPath)
			end
		else
			log("Local file not found in PixelOS directory: " .. pixelOSPath)
		end
		
		-- Check in current directory
		local currentPath = localPath
		if currentFilesystemProxy and currentFilesystemProxy.exists(currentPath) then
			log("Found local file in current directory: " .. currentPath)
			local sourceHandle = currentFilesystemProxy.open(currentPath, "rb")
			if sourceHandle then
				log("Opened local file: " .. currentPath)
				local fileHandle = targetProxy.open(path, "wb")
				if fileHandle then
					log("Opened target file: " .. path)
					local chunk
					repeat
						chunk = currentFilesystemProxy.read(sourceHandle, math.huge)
						if chunk then
							targetProxy.write(fileHandle, chunk)
						end
					until not chunk
					currentFilesystemProxy.close(sourceHandle)
					targetProxy.close(fileHandle)
					downloadedFilesCache[path] = true
					log("Copied local file: " .. currentPath .. " to " .. path)
					return
				else
					log("Failed to open target file: " .. path)
				end
				currentFilesystemProxy.close(sourceHandle)
			else
				log("Failed to open local file: " .. currentPath)
			end
		else
			log("Local file not found in current directory: " .. currentPath)
		end
	else
		log("No filesystem component found")
	end

	-- Fallback to network request if local file doesn't exist
	log("Falling back to network request for: " .. url)
	
	-- Try each repository URL until one works
	local downloadSuccess = false
	local lastError = nil
	local tempPath = path .. ".downloading"
	
	for repoIndex, repo in ipairs(repositoryURLs) do
		local baseRepoUrl = repo.url
		-- Don't encode / and : as they are valid in URLs
		local fullUrl = baseRepoUrl .. url:gsub("([^%w%-%_%.%~/:])", function(char)
			return string.format("%%%02X", string.byte(char))
		end)
		log("Trying repository " .. repoIndex .. ": " .. fullUrl)
		
		-- Download to temporary file first
		local fileHandle, reason = targetProxy.open(tempPath, "wb")
		if fileHandle then
			log("Opened temp file for writing: " .. tempPath)
			local success, errorMessage = rawRequest(url, function(chunk)
				targetProxy.write(fileHandle, chunk)
			end)

			targetProxy.close(fileHandle)
			if success then
				-- Download successful, move temp file to target
				log("Download completed, moving temp file to target...")
				pcall(targetProxy.remove, path) -- Remove old file if exists
				local renameSuccess, renameError = pcall(targetProxy.rename, tempPath, path)
				if renameSuccess then
					downloadedFilesCache[path] = true
					log("Network download completed: " .. url)
					downloadSuccess = true
					break
				else
					log("Warning: Failed to rename temp file: " .. tostring(renameError))
					lastError = renameError
					-- Clean up temp file on failure
					pcall(targetProxy.remove, tempPath)
				end
			else
				log("Repository " .. repoIndex .. " failed: " .. tostring(errorMessage))
				lastError = errorMessage
				-- Clean up temp file on failure
				pcall(targetProxy.remove, tempPath)
			end
		else
			log("Failed to open temp file: " .. tostring(reason))
			lastError = reason
		end
	end
	
	if not downloadSuccess then
		-- Log error but don't stop installation
		log("Download failed: " .. url .. " - " .. tostring(lastError))
		-- Return false to indicate failure
		return false, "Download failed: " .. url .. " - " .. tostring(lastError)
	end
	-- Return true to indicate success
	return true
end

local function deserialize(text)
	local result, reason = load("return " .. text, "=string")
	if result then
		return result()
	else
		error(reason)
	end
end

-- Clearing screen
if GPUAddress and screenWidth and screenHeight and component then
	pcall(component.invoke, GPUAddress, "setBackground", 0xE1E1E1)
	pcall(component.invoke, GPUAddress, "fill", 1, 1, screenWidth, screenHeight, " ")
end

-- Checking minimum system requirements
do
	local function warning(text)
		centrizedText(title(), 0x878787, text)

		local signal
		if computer then
			repeat
				signal = computer.pullSignal()
			until signal == "key_down" or signal == "touch"

			computer.shutdown()
		else
			-- If no computer component, just wait a bit and exit gracefully
			os.sleep(2)
			-- Instead of error, just return to allow program to continue
			log("Warning: " .. text)
			return
		end
	end

	if GPUAddress and component then
		local success, depth = pcall(component.invoke, GPUAddress, "getDepth")
		if success and depth ~= 8 then
			warning("Tier 3 GPU and screen are required")
		end
	end

	if computer then
		local success, totalMemory = pcall(computer.totalMemory)
		if success and totalMemory < 1024 * 1024 * 2 then
			warning("At least 2x Tier 3.5 RAM modules are required")
		end
	end

	-- Searching for appropriate temporary filesystem for storing libraries, images, etc
	if component then
		for address in component.list("filesystem") do
			local proxy = component.proxy(address)
			if proxy.spaceTotal() >= 2 * 1024 * 1024 then
				temporaryFilesystemProxy, selectedFilesystemProxy = proxy, proxy
				break
			end
		end
	end

	-- If there's no suitable HDDs found - then meow
	if not temporaryFilesystemProxy then
		warning("At least Tier 2 HDD is required")
	end
end

-- First, we need a big ass file list with localizations, applications, wallpapers
progress(0)
local files = deserialize(request(installerURL .. "Files.cfg"))

-- Load default localization (ChineseSimplified) for system name display
localization = deserialize(request(installerURL .. "Localizations/ChineseSimplified.lang"))

-- Calculate total size and prepare progress tracking
local totalFiles = #files.installerFiles
local downloadedFiles = 0
local startTime = computer and computer.uptime() or os.time()

-- After that we could download required libraries for installer from it
for i = 1, #files.installerFiles do
	downloadedFiles = i
	local currentTime = computer and computer.uptime() or os.time()
	local elapsed = currentTime - startTime
	local remaining = totalFiles - i
	local estimatedTotal = (elapsed / i) * totalFiles
	local eta = math.max(0, estimatedTotal - elapsed)
	
	-- Use seconds if less than 1 minute, otherwise use minutes
	local timeText
	if eta < 60 then
		local etaSeconds = math.floor(eta)
		timeText = string.format("~%d %s", etaSeconds, localization.seconds or "sec")
	else
		local etaMinutes = math.floor(eta / 60)
		timeText = string.format("~%d %s", etaMinutes, localization.minutes or "min")
	end
	
	-- Update progress with detailed info
	local progressText = string.format("%s: %d/%d | %s: %s", 
		localization.remainingFiles, i, totalFiles,
		localization.estimatedTime, timeText)
	
	progress(i / totalFiles, progressText)
	
	download(files.installerFiles[i], installerPath .. files.installerFiles[i])
end

-- Initializing simple package system for loading system libraries
package = package or {loading = {}, loaded = {}}

function require(module)
	if package.loaded[module] then
		return package.loaded[module]
	elseif package.loading[module] then
		-- Return a placeholder to break circular dependencies
		package.loaded[module] = true
		return package.loaded[module]
	else
		package.loading[module] = true

		local handle, reason
		local data = nil
		
		-- Try to load from selected filesystem first
		if selectedFilesystemProxy then
			handle, reason = selectedFilesystemProxy.open(installerPath .. "Libraries/" .. module .. ".lua", "rb")
			if handle then
				data, chunk = ""
				repeat
					chunk = selectedFilesystemProxy.read(handle, math.huge)
					data = data .. (chunk or "")
				until not chunk
				selectedFilesystemProxy.close(handle)
			end
		end
		
		-- Try to load from temporary filesystem if selected not available
		if not data and temporaryFilesystemProxy then
			handle, reason = temporaryFilesystemProxy.open(installerPath .. "Libraries/" .. module .. ".lua", "rb")
			if handle then
				data, chunk = ""
				repeat
					chunk = temporaryFilesystemProxy.read(handle, math.huge)
					data = data .. (chunk or "")
				until not chunk
				temporaryFilesystemProxy.close(handle)
			end
		end
		
		-- Fallback to network request if file not found locally
		if not data then
			log("File not found locally, trying network: " .. module)
			data = request("Libraries/" .. module .. ".lua")
		end
		
		if data and #data > 0 then
			local result, reason = load(data, "=" .. module)
			if result then
				local moduleResult = result()
				if moduleResult then
					package.loaded[module] = moduleResult
				else
					-- Module returned nil, use true as placeholder
					package.loaded[module] = true
					log("Warning: Module returned nil: " .. module)
				end
			else
				-- Loading failed, use true as placeholder
				package.loaded[module] = true
				log("Warning: Failed to load module: " .. module .. ": " .. tostring(reason))
			end
		else
			-- No data available, use true as placeholder
			package.loaded[module] = true
			log("Warning: No data available for module: " .. module)
		end

		package.loading[module] = nil

		return package.loaded[module]
	end
end

-- Initializing system libraries with error handling
local paths, event, filesystem, bit32, image, text, number, screen, GUI, system

-- Load libraries with error handling
local function loadLibrary(name)
	local success, result = pcall(require, name)
	if success then
		return result
	else
		log("Warning: Failed to load library " .. name .. ": " .. tostring(result))
		return true -- Return placeholder
	end
end

paths = loadLibrary("Paths")
event = loadLibrary("Event")
filesystem = loadLibrary("Filesystem")

if filesystem and type(filesystem) == "table" and filesystem.setProxy and temporaryFilesystemProxy then
	filesystem.setProxy(temporaryFilesystemProxy)
end

bit32 = bit32 or loadLibrary("Bit32")
image = loadLibrary("Image")
text = loadLibrary("Text")
number = loadLibrary("Number")

screen = loadLibrary("Screen")
if screen and type(screen) == "table" and screen.setGPUAddress and GPUAddress then
	screen.setGPUAddress(GPUAddress)
end

GUI = loadLibrary("GUI")
system = loadLibrary("System")

--------------------------------------------------------------------------------

-- Creating main UI workspace with error handling
local workspace, window, menu, installerMenu

if GUI and type(GUI) == "table" and GUI.workspace then
	pcall(function()
		workspace = GUI.workspace()
		workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, 0x1E1E1E))

		-- Main installer window
		window = workspace:addChild(GUI.window(1, 1, 80, 24))
		window.localX, window.localY = math.ceil(workspace.width / 2 - window.width / 2), math.ceil(workspace.height / 2 - window.height / 2)
		window:addChild(GUI.panel(1, 1, window.width, window.height, 0xE1E1E1))

		-- Top menu
		menu = workspace:addChild(GUI.menu(1, 1, workspace.width, 0xF0F0F0, 0x787878, 0x3366CC, 0xE1E1E1))
		installerMenu = menu:addContextMenuItem(localization.systemName or "PixelOS", 0x2D2D2D)
	end)
end

-- Add menu items with localization support
if installerMenu then
	pcall(function()
		local rebootItem = installerMenu:addItem("🗘", localization.reboot or "Reboot")
		rebootItem.onTouch = function()
			if computer then
				computer.shutdown(true)
			end
		end

		local shutdownItem = installerMenu:addItem("⏻", localization.shutdown or "Shutdown")
		shutdownItem.onTouch = function()
			if computer then
				computer.shutdown()
			end
		end

		-- Add battery display
		if GUI and type(GUI) == "table" and screen then
			local batteryWidget = GUI.object(1, 1, 15, 1)
			batteryWidget.draw = function()
				pcall(function()
					local energy = computer.energy()
					local maxEnergy = computer.maxEnergy()
					if energy and maxEnergy and maxEnergy > 0 then
						local batteryPercent = math.min(math.floor((energy / maxEnergy) * 100), 100)
						local powerText = localization and localization.power or "电量"
						local batteryText = string.format("%s: %d%%", powerText, batteryPercent)
						screen.drawText(batteryWidget.x, batteryWidget.y, 0x787878, batteryText)
					end
				end)
			end
			menu:addChild(batteryWidget)

			-- Add time display to the far right
			local timeWidget = GUI.object(1, 1, 5, 1)
			local realTime = nil
			local lastTimeUpdate = 0
			local timeUpdateInterval = 300 -- Update every 5 minutes instead of every minute

			-- Function to get real time using OpenComputers internet API
			local function getRealTime()
				-- Only get real time once during installation to avoid network overhead
				if realTime then
					return realTime
				end
				
				if not component or not internetAddress then
					return nil
				end
				
				local connection, reason = component.invoke(internetAddress, "request", "http://worldtimeapi.org/api/ip")
				if connection then
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
						
					-- Parse JSON response
					local success, result = pcall(load("return " .. data:gsub("true", "true"):gsub("false", "false"):gsub("null", "nil")))
					if success and result and result.datetime then
						-- Parse ISO datetime string
						local year, month, day, hour, minute, second = result.datetime:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
						if year then
							-- Calculate timestamp
							local timestamp = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=second})
							return timestamp
						end
					end
				end
				return nil
			end

			timeWidget.draw = function()
				pcall(function()
					-- Update real time only once during installation
					if not realTime then
						realTime = getRealTime()
						lastTimeUpdate = computer.uptime()
					end
					
					-- Use real time if available, otherwise fallback to game time
					local timeText
					if realTime then
						-- Use real time with timezone support (default to UTC+8)
						local timezoneOffset = 8
						if localization and localization.timezoneOffset then
							timezoneOffset = localization.timezoneOffset
						end
						-- Calculate current time based on initial real time and uptime
						local currentTime = realTime + (computer.uptime() - lastTimeUpdate) + timezoneOffset * 3600
						timeText = os.date("%H:%M", currentTime)
					else
						-- Fallback to game time
						timeText = os.date("%H:%M")
					end
					
					screen.drawText(timeWidget.x, timeWidget.y, 0x787878, timeText)
				end)
			end
			menu:addChild(timeWidget)
		end
	end)
end

-- Set widgets to right alignment (defined before updateMenuLocalization)
local function updateWidgetsPosition()
	pcall(function()
		if workspace and menu and installerMenu then
			-- Get full workspace width for menu
			local menuWidth = workspace.width
			local batteryWidth = 15
			local timeWidth = 5
			local spacing = 3
			
			-- Calculate menu button width based on text
			local menuButtonWidth = (installerMenu.text and #installerMenu.text or 8) + 4
			
			-- Order from left to right: Menu Button -> (large gap) -> Battery -> (small gap) -> Time
			-- Menu button on the left side
			installerMenu.x = 2
			-- Battery to the right with large gap
			if batteryWidget then
				batteryWidget.x = menuWidth - batteryWidth - timeWidth - spacing
				batteryWidget.y = 1
			end
			-- Time at the far right
			if timeWidget then
				timeWidget.x = menuWidth - timeWidth + 1
				timeWidget.y = 1
			end
		end
	end)
end

-- Update widgets position one more time before starting workspace
updateWidgetsPosition()

-- Function to update menu with localization and widget positions
local function updateMenuLocalization()
	pcall(function()
		if installerMenu then
			-- Update the menu text
			installerMenu.text = localization.systemName or "PixelOS"
			if rebootItem then
				rebootItem.text = localization.reboot or "Reboot"
			end
			if shutdownItem then
				shutdownItem.text = localization.shutdown or "Shutdown"
			end
			
			-- Update widget positions after menu text changes
			updateWidgetsPosition()
			
			if workspace then
				workspace:draw()
			end
		end
	end)
end

-- Main vertical layout with error handling
local layout, stageButtonsLayout, prevButton, nextButton

if window and GUI then
	pcall(function()
		layout = window:addChild(GUI.layout(1, 1, window.width, window.height - 2, 1, 1))

		stageButtonsLayout = window:addChild(GUI.layout(1, window.height - 1, window.width, 1, 1, 1))
		stageButtonsLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
		stageButtonsLayout:setSpacing(1, 1, 3)
	end)
end

local function loadImage(name)
	if image and type(image) == "table" and image.load then
		return image.load(installerPicturesPath .. name .. ".pic")
	else
		return nil
	end
end

local function newInput(width, text, placeholder, textMask)
	if GUI and type(GUI) == "table" and GUI.input then
		return GUI.input(1, 1, width, 1, 0xF0F0F0, 0x787878, 0xC3C3C3, 0xF0F0F0, 0x878787, text, placeholder, false, textMask)
	else
		return nil
	end
end

local function newSwitchAndLabel(width, color, text, state)
	if GUI and type(GUI) == "table" and GUI.switchAndLabel then
		return GUI.switchAndLabel(1, 1, width, 6, color, 0xD2D2D2, 0xF0F0F0, 0xA5A5A5, text .. ":", state)
	else
		return nil
	end
end

local function addTitle(color, text)
	if layout and GUI and type(GUI) == "table" and GUI.text then
		return layout:addChild(GUI.text(1, 1, color, text))
	else
		return nil
	end
end

local function addImage(before, after, name)
	if layout and GUI and type(GUI) == "table" then
		if before > 0 then
			layout:addChild(GUI.object(1, 1, 1, before))
		end

		local img = loadImage(name)
		if img and GUI.image then
			local picture = layout:addChild(GUI.image(1, 1, img))
			picture.height = picture.height + after
			return picture
		end
	end
	return nil
end

local function addStageButton(text)
	if stageButtonsLayout and GUI and type(GUI) == "table" and GUI.adaptiveRoundedButton then
		local button = stageButtonsLayout:addChild(GUI.adaptiveRoundedButton(1, 1, 2, 0, 0xC3C3C3, 0x878787, 0xA5A5A5, 0x696969, text))
		button.colors.disabled.background = 0xD2D2D2
		button.colors.disabled.text = 0xB4B4B4
		return button
	else
		return nil
	end
end

if stageButtonsLayout then
	prevButton = addStageButton("<")
	nextButton = addStageButton(">")
end

local stage = 1
local stages = {}

-- Create UI elements with error handling
local usernameInput = newInput(30, "", "", nil)
local passwordInput = newInput(30, "", "", "•")
local passwordSubmitInput = newInput(30, "", "", "•")
local usernamePasswordText
if GUI and type(GUI) == "table" and GUI.text then
	usernamePasswordText = GUI.text(1, 1, 0xCC0040, "")
end
local withoutPasswordSwitchAndLabel = newSwitchAndLabel(30, 0x66DB80, "", false)

local wallpapersSwitchAndLabel = newSwitchAndLabel(30, 0xFF4980, "", true)
local applicationsSwitchAndLabel = newSwitchAndLabel(30, 0x33DB80, "", true)
local localizationsSwitchAndLabel = newSwitchAndLabel(30, 0x33B6FF, "", true)

local acceptSwitchAndLabel = newSwitchAndLabel(30, 0x9949FF, "", false)

local localizationComboBox
if GUI and type(GUI) == "table" and GUI.comboBox then
	localizationComboBox = GUI.comboBox(1, 1, 26, 1, 0xF0F0F0, 0x969696, 0xD2D2D2, 0xB4B4B4)
end

-- Repository selection
local repositoryComboBox
if GUI and type(GUI) == "table" and GUI.comboBox then
	repositoryComboBox = GUI.comboBox(1, 1, 36, 1, 0xF0F0F0, 0x969696, 0xD2D2D2, 0xB4B4B4)
	for i, repo in ipairs(repositoryURLs) do
		repositoryComboBox:addItem(repo.name)
	end
	repositoryComboBox.selectedItem = 1
end

-- Map localization name to license file
local function getLicenseFile(localizationName)
	if localizationName == "ChineseSimplified" then
		return "Installer/Licenses/LICENSE_zh_CN"
	elseif localizationName == "ChineseTraditional" then
		return "Installer/Licenses/LICENSE_zh_TW"
	elseif localizationName == "Russian" then
		return "Installer/Licenses/LICENSE_ru_RU"
	elseif localizationName == "German" then
		return "Installer/Licenses/LICENSE_de_DE"
	elseif localizationName == "French" then
		return "Installer/Licenses/LICENSE_fr_FR"
	elseif localizationName == "Spanish" then
		return "Installer/Licenses/LICENSE_es_ES"
	elseif localizationName == "Japanese" then
		return "Installer/Licenses/LICENSE_ja_JP"
	elseif localizationName == "Korean" then
		return "Installer/Licenses/LICENSE_ko_KR"
	elseif localizationName == "Italian" then
		return "Installer/Licenses/LICENSE_it_IT"
	elseif localizationName == "Finnish" then
		return "Installer/Licenses/LICENSE_fi_FI"
	elseif localizationName == "Dutch" then
		return "Installer/Licenses/LICENSE_nl_NL"
	elseif localizationName == "Ukrainian" then
		return "Installer/Licenses/LICENSE_uk_UA"
	elseif localizationName == "Belarusian" then
		return "Installer/Licenses/LICENSE_be_BY"
	elseif localizationName == "Bulgarian" then
		return "Installer/Licenses/LICENSE_bg_BG"
	elseif localizationName == "Slovak" then
		return "Installer/Licenses/LICENSE_sk_SK"
	elseif localizationName == "Arabic" then
		return "Installer/Licenses/LICENSE_ar_SA"
	elseif localizationName == "Bengali" then
		return "Installer/Licenses/LICENSE_bn_BD"
	elseif localizationName == "Hindi" then
		return "Installer/Licenses/LICENSE_hi_IN"
	elseif localizationName == "Portuguese" then
		return "Installer/Licenses/LICENSE_pt_PT"
	elseif localizationName == "Polish" then
		return "Installer/Licenses/LICENSE_pl_PL"
	elseif localizationName == "Lolcat" then
		return "Installer/Licenses/LICENSE_en_Lolcat"
	else
		-- Default to English
		return "Installer/Licenses/LICENSE_en_US"
	end
end

local selectedLicenseFile = "Installer/Licenses/LICENSE_zh_CN"  -- Default to ChineseSimplified

if localizationComboBox and files and files.localizations then
	for i = 1, #files.localizations do
		local item = localizationComboBox:addItem(filesystemHideExtension(filesystemName(files.localizations[i])))
		if item then
			item.onTouch = function()
				pcall(function()
					-- Store selected localization name
					local selectedLocalization = filesystemHideExtension(filesystemName(files.localizations[i]))
					
					-- Download corresponding LICENSE file
					selectedLicenseFile = getLicenseFile(selectedLocalization)
					-- Extract just the filename from the path
					local licenseFileName = selectedLicenseFile:match("([^/]+)$")
					-- Construct correct path without double "Installer/" prefix
					download("Installer/Licenses/" .. licenseFileName, installerPath .. "Licenses/" .. licenseFileName)
					
					-- Obtaining localization table
					localization = deserialize(request(installerURL .. files.localizations[i]))

					-- Filling widgets with selected localization data
					if usernameInput then
						usernameInput.placeholderText = localization.username
					end
					if passwordInput then
						passwordInput.placeholderText = localization.password
					end
					if passwordSubmitInput then
						passwordSubmitInput.placeholderText = localization.submitPassword
					end
					if withoutPasswordSwitchAndLabel and withoutPasswordSwitchAndLabel.label then
						withoutPasswordSwitchAndLabel.label.text = localization.withoutPassword
					end
					if wallpapersSwitchAndLabel and wallpapersSwitchAndLabel.label then
						wallpapersSwitchAndLabel.label.text = localization.wallpapers
					end
					if applicationsSwitchAndLabel and applicationsSwitchAndLabel.label then
						applicationsSwitchAndLabel.label.text = localization.applications
					end
					if localizationsSwitchAndLabel and localizationsSwitchAndLabel.label then
						localizationsSwitchAndLabel.label.text = localization.languages
					end
					if acceptSwitchAndLabel and acceptSwitchAndLabel.label then
						acceptSwitchAndLabel.label.text = localization.accept
					end

					-- Update menu localization
					updateMenuLocalization()
					
					-- Force workspace redraw to ensure menu changes are visible
					if workspace then
						workspace:draw()
					end
				end)
			end
		end
	end
end

local function addStage(onTouch)
	table.insert(stages, function()
		pcall(function()
			if layout then
				layout:removeChildren()
			end
			onTouch()
			-- Don't draw here, let the caller handle it
		end)
	end)
end

local function loadStage()
	pcall(function()
		if stage < 1 then
			stage = 1
		elseif stage > #stages then
			stage = #stages
		end

		if stages[stage] then
			stages[stage]()
			if workspace then
				workspace:draw()
			end
		end
	end)
end

local function checkUserInputs()
	pcall(function()
		if usernameInput and withoutPasswordSwitchAndLabel and withoutPasswordSwitchAndLabel.switch and passwordInput and passwordSubmitInput and nextButton and usernamePasswordText then
			local nameEmpty = #usernameInput.text == 0
			local nameVaild = usernameInput.text:match("^%w[%w%s_]+")
			local passValid = withoutPasswordSwitchAndLabel.switch.state or (#passwordInput.text > 0 and #passwordSubmitInput.text > 0 and passwordInput.text == passwordSubmitInput.text)

			if (nameEmpty or nameVaild) and passValid then
				usernamePasswordText.hidden = true
				nextButton.disabled = nameEmpty or not nameVaild or not passValid
			else
				usernamePasswordText.hidden = false
				nextButton.disabled = true

				if nameVaild and localization then
					usernamePasswordText.text = localization.passwordsArentEqual
				elseif localization then
					usernamePasswordText.text = localization.usernameInvalid
				end
			end
		end
	end)
end

local function checkLicense()
	pcall(function()
		if acceptSwitchAndLabel and acceptSwitchAndLabel.switch and nextButton then
			nextButton.disabled = not acceptSwitchAndLabel.switch.state
		end
	end)
end

if prevButton then
	prevButton.onTouch = function()
		stage = stage - 1
		loadStage()
	end
end

if nextButton then
	nextButton.onTouch = function(_, _, _, _, _, _, _, username)
		nextButton.lastTouchUsername = username

		stage = stage + 1
		loadStage()
	end
end

if acceptSwitchAndLabel and acceptSwitchAndLabel.switch then
	acceptSwitchAndLabel.switch.onStateChanged = function()
		checkLicense()
		if workspace then
			workspace:draw()
		end
	end
end

if withoutPasswordSwitchAndLabel and withoutPasswordSwitchAndLabel.switch then
	withoutPasswordSwitchAndLabel.switch.onStateChanged = function()
		if passwordInput and passwordSubmitInput then
			passwordInput.hidden = withoutPasswordSwitchAndLabel.switch.state
			passwordSubmitInput.hidden = withoutPasswordSwitchAndLabel.switch.state
		end
		checkUserInputs()

		if workspace then
			workspace:draw()
		end
	end
end

if usernameInput then
	usernameInput.onInputFinished = function()
		checkUserInputs()
		if workspace then
			workspace:draw()
		end
	end

	if passwordInput then
		passwordInput.onInputFinished = usernameInput.onInputFinished
	end
	if passwordSubmitInput then
		passwordSubmitInput.onInputFinished = usernameInput.onInputFinished
	end
end

-- Repository selection stage (first stage)
addStage(function()
	pcall(function()
		if prevButton then
			prevButton.disabled = true
		end

		-- Update repository URL based on selection
		if repositoryComboBox then
			repositoryURL = repositoryURLs[repositoryComboBox.selectedItem].url
			log("Selected repository: " .. repositoryURL)
		end

		addImage(0, 1, "Languages")
		if layout and repositoryComboBox then
			layout:addChild(repositoryComboBox)
		end

		if workspace then
			workspace:draw()
		end
	end)
end)

-- Localization selection stage
addStage(function()
	pcall(function()
		if prevButton then
			prevButton.disabled = true
		end

		addImage(0, 1, "Languages")
		if layout and localizationComboBox then
			layout:addChild(localizationComboBox)
		end

		if workspace then
			workspace:draw()
		end
		-- Set default to ChineseSimplified or first available
		local defaultIndex = 1
		-- Find ChineseSimplified in the list
		if files and files.localizations then
			for i = 1, #files.localizations do
				local name = filesystemHideExtension(filesystemName(files.localizations[i]))
				if name == "ChineseSimplified" then
					defaultIndex = i
					break
				end
			end
		end
		if localizationComboBox and files and files.localizations then
			localizationComboBox.selectedItem = math.min(defaultIndex, #files.localizations)
			local defaultItem = localizationComboBox:getItem(localizationComboBox.selectedItem)
			if defaultItem and defaultItem.onTouch then
				defaultItem.onTouch()
			end
		end
		-- Update menu localization after setting default language
		updateMenuLocalization()
		
		-- Force redraw to ensure localization is applied
		if workspace then
			workspace:draw()
		end
	end)
end)

-- Filesystem selection stage
addStage(function()
	pcall(function()
		if prevButton then
			prevButton.disabled = false
		end
		if nextButton then
			nextButton.disabled = false
		end

		if layout and GUI then
			layout:addChild(GUI.object(1, 1, 1, 1))
		end
		addTitle(0x696969, localization.select)
		
		local diskLayout
		if layout and GUI and type(GUI) == "table" and GUI.layout then
			diskLayout = layout:addChild(GUI.layout(1, 1, layout.width, 11, 1, 1))
			diskLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
			diskLayout:setSpacing(1, 1, 1)
		end

		local HDDImage = loadImage("HDD")
		local dataDiskProxy = nil

		local function select(proxy)
			selectedFilesystemProxy = proxy

			if diskLayout then
				for i = 1, #diskLayout.children do
					if diskLayout.children[i].children[1] then
						diskLayout.children[i].children[1].hidden = diskLayout.children[i].proxy ~= selectedFilesystemProxy
					end
				end
			end
		end

		local function selectDataDisk(proxy)
			dataDiskProxy = proxy
			
			if diskLayout then
				for i = 1, #diskLayout.children do
					local dataDiskIndicator = diskLayout.children[i].children[6]
					if dataDiskIndicator then
						dataDiskIndicator.hidden = diskLayout.children[i].proxy ~= dataDiskProxy
					end
				end
			end
			
			if workspace then
				workspace:draw()
			end
		end

		local function updateDisks()
			local function diskEventHandler(workspace, disk, e1)
				if e1 == "touch" then
					select(disk.proxy)
					if workspace then
						workspace:draw()
					end
				end
			end

			local function addDisk(proxy, picture, disabled)
				if diskLayout and GUI and type(GUI) == "table" and GUI.container then
					local disk = diskLayout:addChild(GUI.container(1, 1, 14, diskLayout.height))
					disk.blockScreenEvents = true

					if GUI.panel then
						disk:addChild(GUI.panel(1, 1, disk.width, disk.height, 0xD2D2D2))
					end

					if GUI.button and localization then
						disk:addChild(GUI.button(1, disk.height, disk.width, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.erase)).onTouch = function()
						pcall(function()
							local list = proxy.list("/")
							for i = 1, #list do
								local path = "/" .. list[i]

								if temporaryFilesystemProxy and temporaryFilesystemProxy.address and (proxy.address ~= temporaryFilesystemProxy.address or path ~= installerPath) then
									proxy.remove(path)
								end
							end

							updateDisks()
						end)
						end
					end

					if disabled and image and image.blend then
						picture = image.blend(picture, 0xFFFFFF, 0.4)
						disk.disabled = true
					end

					if GUI.image then
						disk:addChild(GUI.image(4, 2, picture))
					end
					if GUI.label and text and text.limit then
						local diskLabel = disk:addChild(GUI.label(2, 7, disk.width - 2, 1, disabled and 0x969696 or 0x696969, text.limit(proxy.getLabel() or proxy.address, disk.width - 2)))
						diskLabel:setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
						
						-- Add double-click functionality to rename disk
						diskLabel.eventHandler = function(workspace, label, e1, e2, e3, e4, e5, e6, e7, e8)
							-- Handle both single and double click for compatibility
							if e1 == "touch" then
								if not disabled and temporaryFilesystemProxy and temporaryFilesystemProxy.address and proxy.address ~= temporaryFilesystemProxy.address then
									-- Create input field for renaming
									if GUI.input then
										local input = GUI.input(1, 1, disk.width - 2, 1, 0xF0F0F0, 0x787878, 0xC3C3C3, 0xF0F0F0, 0x878787, proxy.getLabel() or "")
										input.localX = 2
										input.localY = 7
										disk:addChild(input)
										
										input.onInputFinished = function()
											if input.text and #input.text > 0 then
												proxy.setLabel(input.text)
											else
												proxy.setLabel(nil)
											end
											disk:removeChild(input)
											updateDisks()
											if workspace then
												workspace:draw()
											end
										end
										
										if workspace then
											workspace:draw()
										end
										input:startInput()
									end
								end
							end
						end
					end
				end
				
				if GUI.progressBar and localization then
					disk:addChild(GUI.progressBar(2, 8, disk.width - 2, disabled and 0xCCDBFF or 0x66B6FF, disabled and 0xD2D2D2 or 0xC3C3C3, disabled and 0xC3C3C3 or 0xA5A5A5, math.floor(proxy.spaceUsed() / proxy.spaceTotal() * 100), true, true, "", "% " .. localization.used))
				end

				-- Add data disk button if not disabled
				if not disabled and temporaryFilesystemProxy and temporaryFilesystemProxy.address and proxy.address ~= temporaryFilesystemProxy.address then
					if GUI.button then
						local dataDiskButton = disk:addChild(GUI.button(1, 9, disk.width, 1, 0x40CC80, 0xE1E1E1, 0x009940, 0xE1E1E1, "Data Disk"))
						dataDiskButton.onTouch = function()
							selectDataDisk(proxy)
						end
					end
					
					-- Add data disk indicator
					if GUI.label then
						local dataDiskIndicator = disk:addChild(GUI.label(2, 3, disk.width - 2, 1, 0x40CC80, "Data Disk"))
						dataDiskIndicator:setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
						dataDiskIndicator.hidden = true
					end
				end

				disk.eventHandler = diskEventHandler
				disk.proxy = proxy
			end

			if diskLayout then
				diskLayout:removeChildren()
			end
			
			for address in component.list("filesystem") do
				local proxy = component.proxy(address)
				if proxy.spaceTotal() >= 1 * 1024 * 1024 then
					addDisk(
						proxy,
						proxy.spaceTotal() < 1 * 1024 * 1024 and floppyImage or HDDImage,
						proxy.isReadOnly() or proxy.spaceTotal() < 2 * 1024 * 1024
					)
				end
			end

			select(selectedFilesystemProxy)
		end
		
		updateDisks()
	end)
end)

-- User profile setup stage
addStage(function()
	pcall(function()
		checkUserInputs()

		addImage(0, 0, "User")
		addTitle(0x696969, localization.setup)

		if usernameInput and nextButton then
			usernameInput.text = nextButton.lastTouchUsername
		end
		if layout and usernameInput then
			layout:addChild(usernameInput)
		end
		if layout and passwordInput then
			layout:addChild(passwordInput)
		end
		if layout and passwordSubmitInput then
			layout:addChild(passwordSubmitInput)
		end
		if layout and usernamePasswordText then
			layout:addChild(usernamePasswordText)
		end
		if layout and withoutPasswordSwitchAndLabel then
			layout:addChild(withoutPasswordSwitchAndLabel)
		end
		
		checkUserInputs()
	end)
end)

-- Downloads customization stage
addStage(function()
	pcall(function()
		if nextButton then
			nextButton.disabled = false
		end

		addImage(0, 0, "Settings")
		addTitle(0x696969, localization.customize)

		if layout and wallpapersSwitchAndLabel then
			layout:addChild(wallpapersSwitchAndLabel)
		end
		if layout and applicationsSwitchAndLabel then
			layout:addChild(applicationsSwitchAndLabel)
		end
		if layout and localizationsSwitchAndLabel then
			layout:addChild(localizationsSwitchAndLabel)
		end
	end)
end)

-- License acception stage
addStage(function()
	pcall(function()
		checkLicense()

		-- Use pre-downloaded LICENSE file based on selected language
		local lines
		-- Extract just the filename from the path
		local licenseFileName = selectedLicenseFile:match("([^/]+)$")
		-- Construct correct path without double "Installer/" prefix
		local licenseFilePath = installerPath .. "Licenses/" .. licenseFileName
		if temporaryFilesystemProxy then
			local fileHandle, reason = pcall(temporaryFilesystemProxy.open, licenseFilePath, "rb")
			if fileHandle then
				local content = ""
				local chunk
				repeat
					local readSuccess, chunkData = pcall(temporaryFilesystemProxy.read, fileHandle, math.huge)
					if readSuccess and chunkData then
						content = content .. chunkData
					end
				until not chunkData
				pcall(temporaryFilesystemProxy.close, fileHandle)
				if text and text.wrap and layout then
					lines = text.wrap({content}, layout.width - 2)
				end
			else
				-- Fallback to network request if local file not found
				if text and text.wrap then
					lines = text.wrap({request("Installer/Licenses/" .. licenseFileName)}, layout.width - 2)
				end
			end
		end
		if layout and GUI and type(GUI) == "table" and GUI.textBox and lines then
			local textBox = layout:addChild(GUI.textBox(1, 1, layout.width, layout.height - 3, 0xF0F0F0, 0x696969, lines, 1, 1, 1))
		end

		if layout and acceptSwitchAndLabel then
			layout:addChild(acceptSwitchAndLabel)
		end
	end)
end)

-- Downloading stage
addStage(function()
	stageButtonsLayout:removeChildren()
	
	-- Creating user profile
	layout:removeChildren()
	addImage(1, 1, "User")
	addTitle(0x969696, localization.creating)
	workspace:draw()

	-- Renaming if possible
	if not selectedFilesystemProxy.getLabel() then
		selectedFilesystemProxy.setLabel("PixelOS")
	end

	local function switchProxy(runnable)
		if filesystem and type(filesystem) == "table" and filesystem.setProxy then
			filesystem.setProxy(selectedFilesystemProxy)
			runnable()
			if temporaryFilesystemProxy then
				filesystem.setProxy(temporaryFilesystemProxy)
			end
		end
	end

	-- Creating system paths
	local userSettings, userPaths
	switchProxy(function()
		paths.create(paths.system)
		userSettings, userPaths = system.createUser(
			usernameInput.text,
			localizationComboBox:getItem(localizationComboBox.selectedItem).text,
			not withoutPasswordSwitchAndLabel.switch.state and passwordInput.text or nil,
			wallpapersSwitchAndLabel.switch.state
		)
		
		-- If data disk is selected, set data paths to data disk
		if dataDiskProxy then
			-- Create data directories on data disk
			dataDiskProxy.makeDirectory("/Data")
			dataDiskProxy.makeDirectory("/Data/Documents")
			dataDiskProxy.makeDirectory("/Data/Downloads")
			dataDiskProxy.makeDirectory("/Data/Pictures")
			dataDiskProxy.makeDirectory("/Data/Music")
			dataDiskProxy.makeDirectory("/Data/Videos")
			
			-- Update user settings to use data disk for data storage
			userSettings.dataDiskAddress = dataDiskProxy.address
			userSettings.dataPaths = {
				documents = "/Data/Documents",
				downloads = "/Data/Downloads",
				pictures = "/Data/Pictures",
				music = "/Data/Music",
				videos = "/Data/Videos"
			}
		end
	end)

	-- Downloading files
	layout:removeChildren()
	addImage(3, 2, "Downloading")

	local container, progressBar, currentFileLabel, progressInfoLabel
	if GUI and type(GUI) == "table" then
		container = layout:addChild(GUI.container(1, 1, layout.width - 20, 5))
		progressBar = container:addChild(GUI.progressBar(1, 1, container.width, 0x66B6FF, 0xD2D2D2, 0xA5A5A5, 0, true, true, "0%", "%"))
		currentFileLabel = container:addChild(GUI.label(1, 2, container.width, 1, 0x2D2D2D, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
		progressInfoLabel = container:addChild(GUI.label(1, 3, container.width, 1, 0x666666, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	end

	-- Creating final filelist of things to download
	local downloadList = {}

	local function getData(item)
		if type(item) == "table" then
			return item.path, item.id, item.version, item.shortcut
		else
			return item
		end
	end

	local function addToList(state, key)
		if state then
			local selectedLocalization, path, localizationName = localizationComboBox:getItem(localizationComboBox.selectedItem).text
			
			for i = 1, #files[key] do
				path = getData(files[key][i])

				if filesystem.extension(path) == ".lang" then
					localizationName = filesystem.hideExtension(filesystem.name(path))

					if
						-- If ALL loacalizations need to be downloaded
						localizationsSwitchAndLabel.switch.state or
						-- If it's required localization file
						localizationName == selectedLocalization or
						-- Downloading English "just in case" for non-english localizations
						selectedLocalization ~= "English" and localizationName == "English"
					then
						table.insert(downloadList, files[key][i])
					end
				else
					table.insert(downloadList, files[key][i])
				end
			end
		end
	end

	addToList(true, "required")
	addToList(true, "localizations")
	addToList(true, "requiredWallpapers")
	addToList(applicationsSwitchAndLabel.switch.state, "optional")
	addToList(wallpapersSwitchAndLabel.switch.state, "optionalWallpapers")

	-- Downloading files from created list
	local versions, path, id, version, shortcut = {}
	local downloadStartTime = computer and computer.uptime() or os.time()
	local totalDownloadedSize = 0
	local filesToDownload = {}
	local lastDrawTime = 0
	local drawInterval = 0.5 -- Only draw every 0.5 seconds

	-- Filter out already downloaded files
	for i = 1, #downloadList do
		local currentPath = getData(downloadList[i])
		local fullPath = OSPath .. currentPath
		if not filesystem.exists(fullPath) then
			table.insert(filesToDownload, downloadList[i])
		else
			-- File already exists, add to versions if needed
			local p, id, v, s = getData(downloadList[i])
			if id then
				versions[id] = {
					path = OSPath .. p,
					version = v or 1,
				}
			end
			-- Create shortcut if needed
			if s then
				switchProxy(function()
					system.createShortcut(
						userPaths.desktop .. filesystem.hideExtension(filesystem.name(filesystem.path(p))),
						OSPath .. filesystem.path(p)
					)
				end)
			end
		end
	end

	local totalFiles = #filesToDownload
	for i = 1, totalFiles do
		path, id, version, shortcut = getData(filesToDownload[i])

		-- Update current file label
		currentFileLabel.text = text.limit(localization.installing .. " \"" .. path .. "\"", container.width, "center")
		
		-- Calculate ETA
		local currentTime = computer and computer.uptime() or os.time()
		local downloadElapsed = currentTime - downloadStartTime
		local downloadRemaining = totalFiles - i
		local downloadEstimatedTotal = (downloadElapsed / math.max(1, i)) * totalFiles
		local downloadEta = math.max(0, downloadEstimatedTotal - downloadElapsed)
		
		-- Show detailed progress info - use seconds if less than 1 minute, otherwise show minutes and seconds
		local timeText
		local downloadEtaSeconds = math.floor(downloadEta)
		if downloadEta < 60 then
			timeText = string.format("~%d %s", downloadEtaSeconds, localization.seconds or "sec")
		else
			local downloadEtaMinutes = math.floor(downloadEta / 60)
			local remainingSeconds = downloadEtaSeconds % 60
			timeText = string.format("~%d %s %d %s", downloadEtaMinutes, localization.minutes or "min", remainingSeconds, localization.seconds or "sec")
		end
		
		-- Show detailed progress info
		local sizeText = ""
		if totalDownloadedSize >= 1024 * 1024 then
			sizeText = string.format(" | %s: %.1f %s", localization.downloadedSize or "Size", totalDownloadedSize / (1024 * 1024), localization.MB or "MB")
		else
			sizeText = string.format(" | %s: %.0f %s", localization.downloadedSize or "Size", totalDownloadedSize / 1024, localization.KB or "KB")
		end
		
		progressInfoLabel.text = string.format("%s: %d/%d | %s: %s%s",
			localization.remainingFiles or "Remaining", i, totalFiles,
			localization.estimatedTime or "ETA", timeText,
			sizeText)
		
		-- Update progress bar
		progressBar.value = math.floor(i / totalFiles * 100)
		progressBar.prefixText = math.floor(i / totalFiles * 100) .. "%"
		
		-- Draw only if enough time has passed
		local currentTime = computer and computer.uptime() or os.time()
		if currentTime - lastDrawTime >= drawInterval or i == 1 or i == totalFiles then
			workspace:draw()
			lastDrawTime = currentTime
		end

		-- Download file and get size
		download(path, OSPath .. path)
		
		-- Calculate downloaded size (approximate)
		local filePath = OSPath .. path
		if filesystem.exists(filePath) then
			totalDownloadedSize = totalDownloadedSize + filesystem.size(filePath)
		end

		-- Adding system versions data
		if id then
			versions[id] = {
				path = OSPath .. path,
				version = version or 1,
			}
		end

		-- Create shortcut if possible
		if shortcut then
			switchProxy(function()
				system.createShortcut(
					userPaths.desktop .. filesystem.hideExtension(filesystem.name(filesystem.path(path))),
					OSPath .. filesystem.path(path)
				)
			end)
		end
	end

	-- Final draw to show 100% completion
	workspace:draw()

	-- Flashing EEPROM
	layout:removeChildren()
	addImage(1, 1, "EEPROM")
	addTitle(0x969696, localization.flashing)
	workspace:draw()
	
	-- Get BootManager content
	local bootManagerContent
	local bootManagerPath = "EFI/Minified.lua"
	
	-- Try to read from local file first
	if temporaryFilesystemProxy then
		local exists, _ = pcall(temporaryFilesystemProxy.exists, bootManagerPath)
		if exists then
			local fileHandle = temporaryFilesystemProxy.open(bootManagerPath, "rb")
			if fileHandle then
				bootManagerContent = temporaryFilesystemProxy.read(fileHandle)
				temporaryFilesystemProxy.close(fileHandle)
			end
		end
	end
	
	-- Fallback to network request if local file doesn't exist
	if not bootManagerContent then
		bootManagerContent = request(bootManagerPath)
	end
	
	-- Debug: Check bootManagerContent
	if not bootManagerContent then
		log("ERROR: bootManagerContent is nil!")
	else
		log("bootManagerContent length: " .. #bootManagerContent)
		log("bootManagerContent first 100 chars: " .. string.sub(bootManagerContent, 1, 100))
	end

	-- Flash EEPROM with BootManager
	if bootManagerContent and EEPROMAddress then
		local success, errorMsg = pcall(component.invoke, EEPROMAddress, "set", bootManagerContent)
		if success then
			log("EEPROM flashed successfully")
		else
			log("ERROR: Failed to flash EEPROM: " .. tostring(errorMsg))
		end
		-- Set EEPROM label
		pcall(component.invoke, EEPROMAddress, "setLabel", "PixelOS EFI")
		-- Set EEPROM data
		pcall(component.invoke, EEPROMAddress, "setData", selectedFilesystemProxy.address)
	else
		log("ERROR: Failed to flash EEPROM - bootManagerContent is nil or EEPROM address is missing!")
	end


	-- Saving system versions
	switchProxy(function()
		filesystem.writeTable(paths.system.versions, versions, true)
	end)

	-- Done info
	layout:removeChildren()
	addImage(1, 1, "Done")
	addTitle(0x969696, localization.installed)
	
	-- Update EFI label after installation
	if component and EEPROMAddress then
		pcall(component.invoke, EEPROMAddress, "setLabel", "PixelOS EFI")
	end
	
	addStageButton(localization.reboot).onTouch = function()
		if computer then
			computer.shutdown(true)
		end
	end
	workspace:draw()

	-- Removing temporary installer directory
	if temporaryFilesystemProxy then
		pcall(temporaryFilesystemProxy.remove, installerPath)
	end
	
	-- 生成安装日志文件
	local logFileName = "/PixelOS-Install-Log.txt"
	local logFileContent = "PixelOS Installation Log\n"
	logFileContent = logFileContent .. "=============================\n"
	logFileContent = logFileContent .. "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
	logFileContent = logFileContent .. "Installation completed successfully!\n"
	logFileContent = logFileContent .. "\nSystem Information:\n"
	if component and component.computer then
		local success, address = pcall(component.computer.address)
		if success then
			logFileContent = logFileContent .. "- Computer ID: " .. address .. "\n"
		end
		if component.computer.energy and component.computer.maxEnergy then
			local success1, energy = pcall(component.computer.energy)
			local success2, maxEnergy = pcall(component.computer.maxEnergy)
			if success1 and success2 and energy and maxEnergy and maxEnergy > 0 then
				local percentage = (energy / maxEnergy) * 100
				logFileContent = logFileContent .. "- Energy: " .. math.floor(percentage) .. "%\n"
			end
		end
	end
	logFileContent = logFileContent .. "- Selected Filesystem: " .. selectedFilesystemProxy.address .. "\n"
	logFileContent = logFileContent .. "- Username: " .. usernameInput.text .. "\n"
	logFileContent = logFileContent .. "- Language: " .. localizationComboBox:getItem(localizationComboBox.selectedItem).text .. "\n"
	logFileContent = logFileContent .. "\nInstalled Components:\n"
	logFileContent = logFileContent .. "- Wallpapers: " .. (wallpapersSwitchAndLabel.switch.state and "Yes" or "No") .. "\n"
	logFileContent = logFileContent .. "- Applications: " .. (applicationsSwitchAndLabel.switch.state and "Yes" or "No") .. "\n"
	logFileContent = logFileContent .. "- Localizations: " .. (localizationsSwitchAndLabel.switch.state and "Yes" or "No") .. "\n"
	logFileContent = logFileContent .. "\nDetailed Log:\n"
	for i, line in ipairs(outputLines) do
		logFileContent = logFileContent .. line .. "\n"
	end
	
	-- 写入日志文件
	if selectedFilesystemProxy then
		local fileHandle = selectedFilesystemProxy.open(logFileName, "w")
		if fileHandle then
			selectedFilesystemProxy.write(fileHandle, logFileContent)
			selectedFilesystemProxy.close(fileHandle)
			log("Log file generated: " .. logFileName)
			log("Run 'cat " .. logFileName .. "' to view the log")
		else
			log("Failed to create log file: Could not open file")
		end
	else
		log("Failed to create log file: No filesystem available")
	end
end)

--------------------------------------------------------------------------------

-- Update widgets position one more time before starting workspace
updateWidgetsPosition()
loadStage()
if workspace and workspace.start then
	pcall(function() workspace:start() end)
end