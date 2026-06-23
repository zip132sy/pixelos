
-- Checking for required components
local function getComponentAddress(name)
	return component.list(name)() or error("Required " .. name .. " component is missing")
end

local EEPROMAddress, internetAddress, GPUAddress = 
	getComponentAddress("eeprom"),
	getComponentAddress("internet"),
	getComponentAddress("gpu")

-- Binding GPU to screen in case it's not done yet
component.invoke(GPUAddress, "bind", getComponentAddress("screen"))
local screenWidth, screenHeight = component.invoke(GPUAddress, "getResolution")

local installerURL = "Installer/"
local EFIURL = "EFI/Minified.lua"

local installerPath = "/PixelOS installer/"
local installerPicturesPath = installerPath .. "Installer/Pictures/"
local OSPath = "/"

local temporaryFilesystemProxy, selectedFilesystemProxy

--------------------------------------------------------------------------------

-- Working with components directly before system libraries are downloaded & initialized
local function centrize(width)
	return math.floor(screenWidth / 2 - width / 2)
end

local function centrizedText(y, color, text)
	local textWidth = #text
	local x = math.floor((screenWidth - textWidth) / 2)
	-- Clear the entire line first to prevent overlapping
	component.invoke(GPUAddress, "fill", 1, y, screenWidth, 1, " ")
	component.invoke(GPUAddress, "setForeground", color)
	component.invoke(GPUAddress, "set", x, y, text)
end

local function title()
	local y = math.floor(screenHeight / 2 - 1)
	centrizedText(y, 0x2D2D2D, "PixelOS")

	return y + 2
end

local function filesystemPath(path)
	return path:match("^(.+%/).") or ""
end

local function filesystemName(path)
	return path:match("%/?([^%/]+%/?)$")
end

local function filesystemHideExtension(path)
	return path:match("(.+)%..+") or path
end

-- Multiple repository URLs for fallback
local repositoryURLs = {
	"https://gitee.com/zip132sy/pixelos/raw/master/",
	"https://raw.githubusercontent.com/zip132sy/pixelos/master/"
}

local function getFileSize(url)
	for i, repoURL in ipairs(repositoryURLs) do
		local fullURL = repoURL .. url:gsub("([^%w%-%_%.%~])", function(char)
			return string.format("%%%02X", string.byte(char))
		end)
		
		for attempt = 1, 3 do
			local internetHandle, reason = component.invoke(internetAddress, "request", fullURL)
			if internetHandle then
				local total = 0
				while true do
					local chunk = internetHandle.read(math.huge)
					if chunk then
						total = total + #chunk
					else
						break
					end
				end
				internetHandle.close()
				if total > 0 then return total end
			end
			if attempt < 3 then
				computer.pullSignal(0.5)
			end
		end
	end
	return 0
end

local function rawRequest(url, chunkHandler)
	for i, repoURL in ipairs(repositoryURLs) do
		local fullURL = repoURL .. url:gsub("([^%w%-%_%.%~])", function(char)
			return string.format("%%%02X", string.byte(char))
		end)
		
		for attempt = 1, 3 do
			local internetHandle, reason = component.invoke(internetAddress, "request", fullURL)
			
			if internetHandle then
				local chunk, readReason
				local success = true
				while true do
					chunk, readReason = internetHandle.read(math.huge)	
					
					if chunk then
						chunkHandler(chunk, #chunk)
					else
						if readReason then
							success = false
							reason = readReason
						end
						break
					end
				end
				
				internetHandle.close()
				if success then
					return true
				end
			end
			
			if attempt < 3 then
				computer.pullSignal(0.5)
			end
		end
	end
	return false
end

local function request(url)
	local data = ""
	
	local success = rawRequest(url, function(chunk)
		data = data .. chunk
	end)

	return success and data or nil
end

local function download(url, path)
	selectedFilesystemProxy.makeDirectory(filesystemPath(path))

	local fileHandle, reason = selectedFilesystemProxy.open(path, "wb")
	if fileHandle then	
		local success = rawRequest(url, function(chunk)
			selectedFilesystemProxy.write(fileHandle, chunk)
		end)

		selectedFilesystemProxy.close(fileHandle)
		return success
	else
		error("File opening failed: " .. tostring(reason))
	end
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
component.invoke(GPUAddress, "setBackground", 0xE1E1E1)
component.invoke(GPUAddress, "fill", 1, 1, screenWidth, screenHeight, " ")

-- Checking minimum system requirements
do
	local function warning(text)
		centrizedText(title(), 0x878787, text)

		local signal
		repeat
			signal = computer.pullSignal()
		until signal == "key_down" or signal == "touch"

		computer.shutdown()
	end

	if component.invoke(GPUAddress, "getDepth") ~= 8 then
		warning("Tier 3 GPU and screen are required")
	end

	if computer.totalMemory() < 1024 * 1024 * 2 then
		warning("At least 2x Tier 3.5 RAM modules are required")
	end

	-- Searching for appropriate temporary filesystem for storing libraries, images, etc
	for address in component.list("filesystem") do
		local proxy = component.proxy(address)
		if proxy.spaceTotal() >= 2 * 1024 * 1024 then
			temporaryFilesystemProxy, selectedFilesystemProxy = proxy, proxy
			break
		end
	end

	-- If there's no suitable HDDs found - then meow
	if not temporaryFilesystemProxy then
		warning("At least Tier 2 HDD is required")
	end
end

-- Network connectivity check
local function checkNetwork()
	-- Try to connect to the project repository to test network
	local testHandle = component.invoke(internetAddress, "request", "https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua")
	if testHandle then
		testHandle.close()
		return true
	end
	return false
end

-- Format size short (for download progress)
local function formatSizeShort(bytes)
	if bytes < 0 then
		return "0 B"
	elseif bytes < 1024 then
		return math.floor(bytes) .. " B"
	elseif bytes < 1048576 then
		local kb = bytes / 1024
		if kb < 10 then
			return string.format("%.1f KB", kb)
		else
			return string.format("%.0f KB", kb)
		end
	else
		local mb = bytes / 1048576
		if mb < 10 then
			return string.format("%.1f MB", mb)
		else
			return string.format("%.0f MB", mb)
		end
	end
end

-- Display download progress with filename (text only, for loading phase)
local function downloadWithProgress(url, path, current, total, fileSize)
	selectedFilesystemProxy.makeDirectory(filesystemPath(path))
	
	local fileHandle, reason = selectedFilesystemProxy.open(path, "wb")
	if fileHandle then
		-- Show full path where file will be installed
		local displayPath = path
		if #displayPath > 50 then
			displayPath = "..." .. displayPath:sub(#displayPath - 46)
		end
		
		-- Speed tracking variables
		local downloadStartTime = computer.uptime()
		local totalBytes = 0
		
		-- Show initial progress
		if fileSize and fileSize > 0 then
			centrizedText(title(), 0x2D2D2D, string.format("Loading: %s (%d/%d)", displayPath, current, total))
			centrizedText(title() + 1, 0x878787, string.format("0 B / %s", formatSizeShort(fileSize)))
		else
			centrizedText(title(), 0x2D2D2D, string.format("Loading: %s (%d/%d)", displayPath, current, total))
			centrizedText(title() + 1, 0x878787, "0 B")
		end
		
		-- Wrapper for chunk handler to track speed
		local function chunkHandler(chunk, chunkSize)
			selectedFilesystemProxy.write(fileHandle, chunk)
			totalBytes = totalBytes + chunkSize
			
			-- Update speed display
			local elapsed = computer.uptime() - downloadStartTime
			if elapsed > 0 then
				local speed = math.floor(totalBytes / elapsed)
				local speedStr
				if speed < 1024 then
					speedStr = speed .. " B/s"
				elseif speed < 1048576 then
					speedStr = string.format("%.1f KB/s", speed / 1024)
				else
					speedStr = string.format("%.1f MB/s", speed / 1048576)
				end
				centrizedText(title(), 0x2D2D2D, string.format("Loading: %s (%d/%d) @ %s", displayPath, current, total, speedStr))
				if fileSize and fileSize > 0 then
					centrizedText(title() + 1, 0x878787, string.format("%s / %s", formatSizeShort(totalBytes), formatSizeShort(fileSize)))
				else
					centrizedText(title() + 1, 0x878787, formatSizeShort(totalBytes))
				end
			end
		end
		
		local success = rawRequest(url, chunkHandler)
		
		selectedFilesystemProxy.close(fileHandle)
		if success then
			return totalBytes
		else
			return nil
		end
	else
		error("File opening failed: " .. tostring(reason))
	end
end

-- Download with GUI label updates (for installation phase)
local function downloadWithGUIProgress(url, path, current, total, fileSize, nameLabel, sizeLabel, drawCallback)
	selectedFilesystemProxy.makeDirectory(filesystemPath(path))
	
	local fileHandle, reason = selectedFilesystemProxy.open(path, "wb")
	if fileHandle then
		-- Speed tracking variables
		local downloadStartTime = computer.uptime()
		local totalBytes = 0
		local scrollOffset = 0
		local scrollCounter = 0
		
		-- Update GUI labels
		local function updateLabels(speedStr)
			local suffix = string.format(" (%d/%d)", current, total)
			if speedStr then
				suffix = suffix .. " @ " .. speedStr
			end
			
			local prefix = "Installing: "
			local maxDisplayLen = nameLabel.width
			local maxPathLen = maxDisplayLen - #prefix - #suffix
			local displayPath = path
			local isLong = #displayPath > maxPathLen
			
			if isLong then
				scrollCounter = scrollCounter + 1
				if scrollCounter >= 5 then
					scrollCounter = 0
					scrollOffset = scrollOffset + 1
				end
				
				local maxScroll = #path - maxPathLen
				if maxScroll < 0 then maxScroll = 0 end
				
				scrollOffset = scrollOffset % (maxScroll + 8)
				local visibleStart = scrollOffset
				if visibleStart > maxScroll then
					visibleStart = maxScroll
				end
				
				displayPath = path:sub(visibleStart + 1, visibleStart + maxPathLen)
			else
				scrollOffset = 0
				scrollCounter = 0
			end
			
			local fullText = prefix .. displayPath .. suffix
			
			if not isLong then
				local padding = math.floor((maxDisplayLen - #fullText) / 2)
				if padding > 0 then
					fullText = string.rep(" ", padding) .. fullText
				end
			end
			
			nameLabel.text = fullText
			if fileSize and fileSize > 0 then
				sizeLabel.text = string.format("%s / %s", formatSizeShort(totalBytes), formatSizeShort(fileSize))
			else
				sizeLabel.text = formatSizeShort(totalBytes)
			end
			if drawCallback then drawCallback() end
		end
		
		updateLabels()
		
		-- Wrapper for chunk handler to track speed
		local function chunkHandler(chunk, chunkSize)
			selectedFilesystemProxy.write(fileHandle, chunk)
			totalBytes = totalBytes + chunkSize
			
			-- Update GUI display
			local elapsed = computer.uptime() - downloadStartTime
			if elapsed > 0 then
				local speed = math.floor(totalBytes / elapsed)
				local speedStr
				if speed < 1024 then
					speedStr = speed .. " B/s"
				elseif speed < 1048576 then
					speedStr = string.format("%.1f KB/s", speed / 1024)
				else
					speedStr = string.format("%.1f MB/s", speed / 1048576)
				end
				updateLabels(speedStr)
			end
		end
		
		local success = rawRequest(url, chunkHandler)
		
		selectedFilesystemProxy.close(fileHandle)
		if success then
			return totalBytes
		else
			return nil
		end
	else
		error("File opening failed: " .. tostring(reason))
	end
end

-- First, we need a big ass file list with localizations, applications, wallpapers
centrizedText(title(), 0x2D2D2D, "Checking network...")
if not checkNetwork() then
	error("Network connection failed. Please check your internet card and try again.")
end
local filesData = request(installerURL .. "Files.cfg")
if not filesData then
	error("Failed to download file list. Please check your network connection and try again.")
end
local files = deserialize(filesData)

-- After that we could download required libraries for installer from it
for i = 1, #files.installerFiles do
	local path = files.installerFiles[i]
	local fileSize = 0
	local size = getFileSize(path)
	if size > 0 then
		fileSize = size
	else
		centrizedText(title(), 0x2D2D2D, "Skipping missing file: " .. path)
		computer.pullSignal(0.1)
		goto continue
	end
	local downloadedBytes = downloadWithProgress(path, installerPath .. path, i, #files.installerFiles, fileSize)
	if downloadedBytes == nil then
		centrizedText(title(), 0xCC0000, "Download failed: " .. path)
		computer.pullSignal(0.5)
	end
	::continue::
end

-- Initializing simple package system for loading system libraries
package = {loading = {}, loaded = {}}

function require(module)
	if package.loaded[module] then
		return package.loaded[module]
	elseif package.loading[module] then
		error("already loading " .. module .. ": " .. debug.traceback())
	else
		package.loading[module] = true

		local handle, reason = temporaryFilesystemProxy.open(installerPath .. "Libraries/" .. module .. ".lua", "rb")
		if handle then
			local data, chunk = ""
			repeat
				chunk = temporaryFilesystemProxy.read(handle, math.huge)
				data = data .. (chunk or "")
			until not chunk

			temporaryFilesystemProxy.close(handle)
			
			local result, reason = load(data, "=" .. module)
			if result then
				package.loaded[module] = result() or true
			else
				error(reason)
			end
		else
			error("File opening failed: " .. tostring(reason))
		end

		package.loading[module] = nil

		return package.loaded[module]
	end
end

-- Initializing system libraries
local filesystem = require("Filesystem")
filesystem.setProxy(temporaryFilesystemProxy)

bit32 = bit32 or require("Bit32")
local image = require("Image")
local text = require("Text")
local number = require("Number")

local screen = require("Screen")
screen.setGPUAddress(GPUAddress)

local GUI = require("GUI")
local system = require("System")
local paths = require("Paths")

--------------------------------------------------------------------------------

-- Creating main UI workspace
local workspace = GUI.workspace()
workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, 0x1E1E1E))

-- Main installer window
local window = workspace:addChild(GUI.window(1, 1, 80, 24))
window.localX, window.localY = math.ceil(workspace.width / 2 - window.width / 2), math.ceil(workspace.height / 2 - window.height / 2)
window:addChild(GUI.panel(1, 1, window.width, window.height, 0xE1E1E1))

-- Top menu
local menu = workspace:addChild(GUI.menu(1, 1, workspace.width, 0xF0F0F0, 0x787878, 0x3366CC, 0xE1E1E1))
local installerMenu = menu:addContextMenuItem("PixelOS", 0x2D2D2D)

installerMenu:addItem("🗘", "Reboot").onTouch = function()
	computer.shutdown(true)
end

installerMenu:addItem("⏻", "Shutdown").onTouch = function()
	computer.shutdown()
end

-- Main vertical layout
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height - 2, 1, 1))

local stageButtonsLayout = window:addChild(GUI.layout(1, window.height - 1, window.width, 1, 1, 1))
stageButtonsLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
stageButtonsLayout:setSpacing(1, 1, 3)

local function loadImage(name)
	return image.load(installerPicturesPath .. name .. ".pic")
end

local function newInput(width, ...)
	return GUI.input(1, 1, width, 1, 0xF0F0F0, 0x787878, 0xC3C3C3, 0xF0F0F0, 0x878787, "", ...)
end

local function newSwitchAndLabel(width, color, text, state)
	return GUI.switchAndLabel(1, 1, width, 6, color, 0xD2D2D2, 0xF0F0F0, 0xA5A5A5, text .. ":", state)
end

local function addTitle(color, text)
	return layout:addChild(GUI.text(1, 1, color, text))
end

local function addImage(before, after, name)
	if before > 0 then
		layout:addChild(GUI.object(1, 1, 1, before))
	end

	local picture = layout:addChild(GUI.image(1, 1, loadImage(name)))
	picture.height = picture.height + after

	return picture
end

local function addStageButton(text)
	local button = stageButtonsLayout:addChild(GUI.adaptiveRoundedButton(1, 1, 2, 0, 0xC3C3C3, 0x878787, 0xA5A5A5, 0x696969, text))
	button.colors.disabled.background = 0xD2D2D2
	button.colors.disabled.text = 0xB4B4B4

	return button
end

local prevButton = addStageButton("<")
local nextButton = addStageButton(">")

local localization
local stage = 1
local stages = {}

local usernameInput = newInput(30, "")
local passwordInput = newInput(30, "", false, "•")
local passwordSubmitInput = newInput(30, "", false, "•")
local usernamePasswordText = GUI.text(1, 1, 0xCC0040, "")
local withoutPasswordSwitchAndLabel = newSwitchAndLabel(30, 0x66DB80, "", false)

local wallpapersSwitchAndLabel = newSwitchAndLabel(30, 0xFF4980, "", true)
local applicationsSwitchAndLabel = newSwitchAndLabel(30, 0x33DB80, "", true)
local localizationsSwitchAndLabel = newSwitchAndLabel(30, 0x33B6FF, "", true)
local biosManagerSwitchAndLabel = newSwitchAndLabel(30, 0xFFDB80, "", true)

local acceptSwitchAndLabel = newSwitchAndLabel(30, 0x9949FF, "", false)

local localizationComboBox = GUI.comboBox(1, 1, 26, 1, 0xF0F0F0, 0x969696, 0xD2D2D2, 0xB4B4B4)
for i = 1, #files.localizations do
	localizationComboBox:addItem(filesystemHideExtension(filesystemName(files.localizations[i]))).onTouch = function()
		-- Obtaining localization table
		local locData = request(installerURL .. files.localizations[i])
		if locData then
			localization = deserialize(locData)
		else
			centrizedText(title(), 0xCC0000, "Failed to load localization")
			computer.pullSignal(1)
			return
		end

		-- Filling widgets with selected localization data
		usernameInput.placeholderText = localization.username
		passwordInput.placeholderText = localization.password
		passwordSubmitInput.placeholderText = localization.submitPassword
		withoutPasswordSwitchAndLabel.label.text = localization.withoutPassword
		wallpapersSwitchAndLabel.label.text = localization.wallpapers
		applicationsSwitchAndLabel.label.text = localization.applications
		localizationsSwitchAndLabel.label.text = localization.languages
		biosManagerSwitchAndLabel.label.text = localization.biosManager or "BIOS Manager"
		acceptSwitchAndLabel.label.text = localization.accept
	end
end

local function addStage(onTouch)
	table.insert(stages, function()
		layout:removeChildren()
		onTouch()
		workspace:draw()
	end)
end

local function loadStage()
	if stage < 1 then
		stage = 1
	elseif stage > #stages then
		stage = #stages
	end

	stages[stage]()
end

local function checkUserInputs()
	local nameEmpty = #usernameInput.text == 0
	local nameVaild = usernameInput.text:match("^%w[%w%s_]+$")
	local passValid = withoutPasswordSwitchAndLabel.switch.state or (#passwordInput.text > 0 and #passwordSubmitInput.text > 0 and passwordInput.text == passwordSubmitInput.text)

	if (nameEmpty or nameVaild) and passValid then
		usernamePasswordText.hidden = true
		nextButton.disabled = nameEmpty or not nameVaild or not passValid
	else
		usernamePasswordText.hidden = false
		nextButton.disabled = true

		if nameVaild then
			usernamePasswordText.text = localization.passwordsArentEqual
		else
			usernamePasswordText.text = localization.usernameInvalid
		end
	end
end

local function checkLicense()
	nextButton.disabled = not acceptSwitchAndLabel.switch.state
end

prevButton.onTouch = function()
	stage = stage - 1
	loadStage()
end

nextButton.onTouch = function(_, _, _, _, _, _, _, username)
	nextButton.lastTouchUsername = username

	stage = stage + 1
	loadStage()
end

acceptSwitchAndLabel.switch.onStateChanged = function()
	checkLicense()
	workspace:draw()
end

withoutPasswordSwitchAndLabel.switch.onStateChanged = function()
	passwordInput.hidden = withoutPasswordSwitchAndLabel.switch.state
	passwordSubmitInput.hidden = withoutPasswordSwitchAndLabel.switch.state
	checkUserInputs()

	workspace:draw()
end

usernameInput.onInputFinished = function()
	checkUserInputs()
	workspace:draw()
end

passwordInput.onInputFinished = usernameInput.onInputFinished
passwordSubmitInput.onInputFinished = usernameInput.onInputFinished

-- Localization selection stage
addStage(function()
	prevButton.disabled = true

	addImage(0, 1, "Languages")
	layout:addChild(localizationComboBox)

	workspace:draw()
	-- Default to Chinese (item 13), fallback to English if not found
	local defaultIndex = 1
	for i = 1, #files.localizations do
		if files.localizations[i]:match("Chinese") then
			defaultIndex = i
			break
		end
	end
	-- Set comboBox selection to Chinese by default
	localizationComboBox.selectedItem = defaultIndex
	workspace:draw()
	localizationComboBox:getItem(defaultIndex).onTouch()
end)

-- Filesystem selection stage
addStage(function()
	prevButton.disabled = false
	nextButton.disabled = false

	layout:addChild(GUI.object(1, 1, 1, 1))
	addTitle(0x696969, localization.select)
	
	local diskLayout = layout:addChild(GUI.layout(1, 1, layout.width, 11, 1, 1))
	diskLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
	diskLayout:setSpacing(1, 1, 1)

	local HDDImage = loadImage("HDD")

	local function select(proxy)
		selectedFilesystemProxy = proxy

		for i = 1, #diskLayout.children do
			diskLayout.children[i].children[1].hidden = diskLayout.children[i].proxy ~= selectedFilesystemProxy
		end
	end

	local function updateDisks()
		local function diskEventHandler(workspace, disk, e1)
			if e1 == "touch" then
				select(disk.proxy)
				workspace:draw()
			end
		end

		local function addDisk(proxy, picture, disabled)
			local disk = diskLayout:addChild(GUI.container(1, 1, 14, diskLayout.height))
			disk.blockScreenEvents = true

			disk:addChild(GUI.panel(1, 1, disk.width, disk.height, 0xD2D2D2))

			disk:addChild(GUI.button(1, disk.height, disk.width, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.erase)).onTouch = function()
				local list, path = proxy.list("/")
				for i = 1, #list do
					path = "/" .. list[i]

					if proxy.address ~= temporaryFilesystemProxy.address or path ~= installerPath then
						proxy.remove(path)
					end
				end

				updateDisks()
			end

			if disabled then
				picture = image.blend(picture, 0xFFFFFF, 0.4)
				disk.disabled = true
			end

			disk:addChild(GUI.image(4, 2, picture))
			disk:addChild(GUI.label(2, 7, disk.width - 2, 1, disabled and 0x969696 or 0x696969, text.limit(proxy.getLabel() or proxy.address, disk.width - 2))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
			disk:addChild(GUI.progressBar(2, 8, disk.width - 2, disabled and 0xCCDBFF or 0x66B6FF, disabled and 0xD2D2D2 or 0xC3C3C3, disabled and 0xC3C3C3 or 0xA5A5A5, math.floor(proxy.spaceUsed() / proxy.spaceTotal() * 100), true, true, "", "% " .. localization.used))

			disk.eventHandler = diskEventHandler
			disk.proxy = proxy
		end

		diskLayout:removeChildren()
		
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

-- User profile setup stage
addStage(function()
	checkUserInputs()

	addImage(0, 0, "User")
	addTitle(0x696969, localization.setup)

	usernameInput.text = nextButton.lastTouchUsername
	layout:addChild(usernameInput)
	layout:addChild(passwordInput)
	layout:addChild(passwordSubmitInput)
	layout:addChild(usernamePasswordText)
	layout:addChild(withoutPasswordSwitchAndLabel)
	
	checkUserInputs()
end)

-- Downloads customization stage
addStage(function()
	nextButton.disabled = false

	addImage(0, 0, "Settings")
	addTitle(0x696969, localization.customize)

	layout:addChild(wallpapersSwitchAndLabel)
	layout:addChild(applicationsSwitchAndLabel)
	layout:addChild(localizationsSwitchAndLabel)
	layout:addChild(biosManagerSwitchAndLabel)

	-- Add estimated size display
	local function formatSize(bytes)
		if bytes < 1024 then
			return bytes .. " B"
		elseif bytes < 1048576 then
			return string.format("%.1f KB", bytes / 1024)
		else
			return string.format("%.1f MB", bytes / 1048576)
		end
	end

	local function calculateEstimatedSize()
		-- Rough estimate: libraries ~500KB, apps ~100KB each, wallpapers ~50KB each
		local baseSize = 500 * 1024
		local appsSize = applicationsSwitchAndLabel.switch.state and (12 * 100 * 1024) or 0
		local localizationsSize = localizationsSwitchAndLabel.switch.state and (21 * 30 * 1024) or (2 * 30 * 1024)
		local wallpapersSize = wallpapersSwitchAndLabel.switch.state and (8 * 50 * 1024) or 0
		local biosSize = biosManagerSwitchAndLabel.switch.state and (20 * 1024) or 0
		return baseSize + appsSize + localizationsSize + wallpapersSize + biosSize
	end

	local estimatedSize = calculateEstimatedSize()
	local sizeLabel = layout:addChild(GUI.label(1, 1, layout.width, 1, 0x696969, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	sizeLabel.text = "Estimated size: " .. formatSize(estimatedSize)

	-- Update size when switches change
	local function updateSize()
		estimatedSize = calculateEstimatedSize()
		sizeLabel.text = "Estimated size: " .. formatSize(estimatedSize)
		workspace:draw()
	end

	wallpapersSwitchAndLabel.switch.onStateChanged = updateSize
	applicationsSwitchAndLabel.switch.onStateChanged = updateSize
	localizationsSwitchAndLabel.switch.onStateChanged = updateSize
	biosManagerSwitchAndLabel.switch.onStateChanged = updateSize
end)

-- License acception stage
addStage(function()
	checkLicense()

	-- Get the current language
	local currentLang = localizationComboBox:getItem(localizationComboBox.selectedItem).text
	local licenseFile = "LICENSE_en_US"
	if currentLang == "Chinese" or currentLang == "中文" then
		licenseFile = "LICENSE_zh_CN"
	end

	local licenseData = request("Installer/Licenses/" .. licenseFile) or "License file not available."
	local lines = text.wrap({licenseData}, layout.width - 2)
	local textBox = layout:addChild(GUI.textBox(1, 1, layout.width, layout.height - 5, 0xF0F0F0, 0x696969, lines, 1, 1, 1))

	-- Add MineOS License button
	local mineOSLicenseButton = layout:addChild(GUI.button(1, layout.height - 3, 20, 1, 0xD2D2D2, 0x696969, 0xF0F0F0, 0x696969, localization.showOriginalLicense))
	mineOSLicenseButton.onTouch = function()
		-- Create a modal window for original license with background panel and only close button
		local modalWindow = workspace:addChild(GUI.filledWindow(math.floor(workspace.width / 2 - 40 / 2), math.floor(workspace.height / 2 - 18 / 2), 40, 18, GUI.WINDOW_BACKGROUND_PANEL_COLOR))
		
		-- Hide minimize and maximize buttons, keep only close button (red dot in top-left corner)
		modalWindow.actionButtons.minimize.hidden = true
		modalWindow.actionButtons.maximize.hidden = true
		
		-- Set close button handler
		modalWindow.actionButtons.close.onTouch = function()
			modalWindow:remove()
			workspace:draw()
		end
		
		-- Add scrollable text box (content starts below title bar)
		local mineOSLicenseData = request("Installer/Licenses/MineOS_Original_LICENSE") or "License file not available."
		local scrollableTextBox = modalWindow:addChild(GUI.textBox(3, 3, modalWindow.width - 4, modalWindow.height - 4, 0xF0F0F0, 0x696969, text.wrap({mineOSLicenseData}, modalWindow.width - 4), 1, 0, 0, true, true))
		
		workspace:draw()
	end

	layout:addChild(acceptSwitchAndLabel)
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
		selectedFilesystemProxy.setLabel("PixelOS HDD")
	end

	local function switchProxy(runnable)
		filesystem.setProxy(selectedFilesystemProxy)
		runnable()
		filesystem.setProxy(temporaryFilesystemProxy)
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
	end)

	-- Downloading files
	layout:removeChildren()
	addImage(1, 1, "Downloading")
	addTitle(0x969696, localization.installing or "Installing")

	-- Set BIOS to installation mode
	component.invoke(EEPROMAddress, "setLabel", "PixelOS Install")

	local container = layout:addChild(GUI.container(1, 1, layout.width - 20, 5))
	local progressBar = container:addChild(GUI.progressBar(1, 1, container.width, 0x66B6FF, 0xD2D2D2, 0xA5A5A5, 0, true, false))
	local fileNameLabel = container:addChild(GUI.label(1, 2, container.width, 1, 0x969696, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
	local fileSizeLabel = container:addChild(GUI.label(1, 3, container.width, 1, 0x696969, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	local statsLabel = container:addChild(GUI.label(1, 5, container.width, 1, 0x696969, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

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

	-- Add BIOS files
	if biosManagerSwitchAndLabel.switch.state then
		-- Custom BIOS with Manager
		table.insert(downloadList, "EFI/BIOS.lua")
		table.insert(downloadList, "BIOS/Manager.lua")
		table.insert(downloadList, "Libraries/Encryption.lua")
	else
		-- Original Minified EFI
		table.insert(downloadList, "EFI/Minified.lua")
	end

	-- Calculate total files
	local totalFiles = #downloadList
	local totalDownloadedBytes = 0
	local downloadedSize = 0
	local totalSize = 0  -- Will be calculated during download

	-- Localization strings (with fallbacks to prevent nil errors)
	local installingText = localization.installing or "Installing"
	local downloadingText = localization.downloading or "Downloading"
	local fileSizeText = localization.fileSize or "File size"
	local totalProgressText = localization.totalProgress or "Total"

	-- Format size function
	local function formatSize(bytes)
		if bytes < 1024 then
			return bytes .. " B"
		elseif bytes < 1048576 then
			return string.format("%.1f KB", bytes / 1024)
		else
			return string.format("%.1f MB", bytes / 1048576)
		end
	end

	-- Download loop
	local versions = {}
	local startTime = computer.uptime()
	local downloadedSize = 0
	for i = 1, #downloadList do
		path, id, version, shortcut = getData(downloadList[i])

		-- Get file size first
		local fileSize = 0
		local size = getFileSize(path)
		if size > 0 then
			fileSize = size
		else
			fileNameLabel.text = "Skipping missing file: " .. path
			workspace:draw()
			computer.pullSignal(0.1)
			goto continue
		end

		-- Download file with progress and get actual size
		local downloadedBytes = downloadWithGUIProgress(path, OSPath .. path, i, totalFiles, fileSize, fileNameLabel, fileSizeLabel, function() workspace:draw() end)
		if downloadedBytes == nil then
			fileNameLabel.text = "Download failed: " .. path
			workspace:draw()
			computer.pullSignal(0.5)
			goto continue
		end
		if fileSize == 0 then
			fileSize = downloadedBytes
		end

		-- Update stats
		downloadedSize = downloadedSize + fileSize
		totalDownloadedBytes = downloadedSize
		totalSize = totalSize + fileSize
		local elapsedTime = computer.uptime() - startTime
		local filesRemaining = totalFiles - i
		local avgTimePerFile = elapsedTime / i
		local remainingTime = avgTimePerFile * filesRemaining
		
		-- Calculate download speed
		local speed = math.floor(downloadedSize / elapsedTime)
		local speedStr
		if speed < 1024 then
			speedStr = speed .. " B/s"
		elseif speed < 1048576 then
			speedStr = string.format("%.1f KB/s", speed / 1024)
		else
			speedStr = string.format("%.1f MB/s", speed / 1048576)
		end

		-- Update final stats label
		local function formatTime(seconds)
			if seconds < 60 then
				return math.floor(seconds) .. "s"
			elseif seconds < 3600 then
				return math.floor(seconds / 60) .. "m " .. math.floor(seconds % 60) .. "s"
			else
				return math.floor(seconds / 3600) .. "h " .. math.floor((seconds % 3600) / 60) .. "m"
			end
		end

		-- Get remaining disk space
		local diskSpaceRemaining = selectedFilesystemProxy.spaceTotal() - selectedFilesystemProxy.spaceUsed()

		statsLabel.text = string.format("%s remaining | %s left | Free: %s",
			formatTime(remainingTime),
			filesRemaining .. " files",
			formatSize(diskSpaceRemaining)
		)
		workspace:draw()

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

		progressBar.value = math.floor(i / #downloadList * 100)
		workspace:draw()
		::continue::
	end

	-- Flashing EEPROM
	layout:removeChildren()
	addImage(1, 1, "EEPROM")
	addTitle(0x969696, localization.flashing)
	
	local progressBar = GUI.progressBar(1, 1, layout.width - 2, 1, 0x00FF00, 0xFFFFFF)
	progressBar.value = 0
	layout:addChild(progressBar)
	
	local statusLabel = GUI.label(1, 1, layout.width, 1, 0x969696, "0%")
	statusLabel:setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	layout:addChild(statusLabel)
	
	workspace:draw()
	
	local function flashWithProgress(code, label)
		local totalSteps = 20
		for step = 1, totalSteps do
			progressBar.value = step / totalSteps
			statusLabel.text = string.format("%d%%", math.floor(step / totalSteps * 100))
			workspace:draw()
			computer.pullSignal(0.05)
		end
		
		component.invoke(EEPROMAddress, "set", code)
		component.invoke(EEPROMAddress, "setLabel", label)
		
		progressBar.value = 1
		statusLabel.text = "100%"
		workspace:draw()
		computer.pullSignal(0.2)
	end
	
	-- Only flash BIOS if Manager is enabled
	-- IMPORTANT: Save boot address first, then flash BIOS, then restore boot address
	-- because flashing BIOS with component.invoke(EEPROMAddress, "set", code) may overwrite
	-- the boot address stored at the beginning of EEPROM
	local savedBootData = component.invoke(EEPROMAddress, "getData") or ""

	if biosManagerSwitchAndLabel.switch.state then
		local biosCode = request("EFI/BIOS.lua")
		if biosCode and #biosCode > 0 then
			flashWithProgress(biosCode, "PixelOS BIOS")
		end
	else
		local minifiedCode = request("EFI/Minified.lua")
		if minifiedCode and #minifiedCode > 0 then
			flashWithProgress(minifiedCode, "PixelOS EFI")
		end
	end

	-- Restore boot address (first 36 chars of EEPROM) while keeping the rest of BIOS code intact
	-- BIOS code may have appended data after the first 36 chars
	local currentData = component.invoke(EEPROMAddress, "getData") or ""
	local bootAddr = selectedFilesystemProxy.address or ""
	if #bootAddr == 36 then
		-- Construct new EEPROM data: first 36 chars = boot address, rest = current BIOS data
		local newData = bootAddr .. string.sub(currentData, 37)
		component.invoke(EEPROMAddress, "setData", newData)
	end
	
	-- Installing BIOS Manager (if enabled)
	if biosManagerSwitchAndLabel.switch.state then
		layout:removeChildren()
		addImage(1, 1, "EEPROM")
		addTitle(0x00FF00, localization.biosManager or "BIOS Manager")
		layout:addChild(GUI.label(1, 1, layout.width, 1, 0x969696, localization.installing or "Installing")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
		workspace:draw()
		computer.pullSignal(1)
	end


	-- Saving system versions
	switchProxy(function()
		filesystem.writeTable(paths.system.versions, versions, true)
	end)

	-- Done info
	layout:removeChildren()
	addImage(1, 1, "Done")
	addTitle(0x969696, localization.installed)
	addStageButton(localization.reboot).onTouch = function()
		computer.shutdown(true)
	end
	workspace:draw()

	local function removeDirectory(proxy, path)
		local list, itemPath = proxy.list(path)
		for i = 1, #list do
			itemPath = path .. list[i]
			local isDir = proxy.exists(itemPath .. "/")
			if isDir then
				removeDirectory(proxy, itemPath .. "/")
			else
				proxy.remove(itemPath)
			end
		end
		proxy.remove(path)
	end

	removeDirectory(temporaryFilesystemProxy, installerPath)
end)

--------------------------------------------------------------------------------

loadStage()
workspace:start()
