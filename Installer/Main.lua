-- Feature: Multiple repository URLs with fallback
local repositoryURLs = {
	"https://gitee.com/zip132sy/pixelos/raw/master/",
	"https://raw.githubusercontent.com/zip132sy/pixelos/master/"
}
local repositoryURL = repositoryURLs[1]
local installerURL = "Installer/"
local EFIURL = "EFI/BIOS.lua"

local installerPath = "/PixelOS installer/"
local installerPicturesPath = installerPath .. "Installer/Pictures/"
local OSPath = "/"

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

local temporaryFilesystemProxy, selectedFilesystemProxy

--------------------------------------------------------------------------------

-- Working with components directly before system libraries are downloaded & initialized
local function centrize(width)
	return math.floor(screenWidth / 2 - width / 2)
end

local function centrizedText(y, color, text)
	component.invoke(GPUAddress, "fill", 1, y, screenWidth, 1, " ")
	component.invoke(GPUAddress, "setForeground", color)
	component.invoke(GPUAddress, "set", centrize(#text), y, text)
end

local function title()
	local y = math.floor(screenHeight / 2 - 1)
	centrizedText(y, 0x2D2D2D, "PixelOS")

	return y + 2
end

local function progress(value, text)
	local width = 26
	local x, y, part = centrize(width), title(), math.ceil(width * value)
	
	component.invoke(GPUAddress, "setForeground", 0x878787)
	component.invoke(GPUAddress, "set", x, y, string.rep("─", part))
	component.invoke(GPUAddress, "setForeground", 0xC3C3C3)
	component.invoke(GPUAddress, "set", x + part, y, string.rep("─", width - part))
	
	if text then
		component.invoke(GPUAddress, "setForeground", 0x666666)
		component.invoke(GPUAddress, "set", centrize(#text), y + 1, text)
	end
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

-- Feature: Multiple repository URL fallback
local function rawRequest(url, chunkHandler)
	local lastError = nil
	
	for i, repoURL in ipairs(repositoryURLs) do
		local fullURL = repoURL .. url:gsub("([^%w%-%_%.%~])", function(char)
			return string.format("%%%02X", string.byte(char))
		end)
		
		local internetHandle, reason = component.invoke(internetAddress, "request", fullURL)
		
		if internetHandle then
			local chunk, err
			local success = true
			while true do
				chunk, err = internetHandle.read(math.huge) 
				if chunk then
					chunkHandler(chunk)
				else
					if err then
						lastError = err
						success = false
					end
					internetHandle.close()
					if success then
						return true
					else
						break
					end
				end
			end
		else
			lastError = reason
		end
	end

	error("Connection failed for all URLs: " .. tostring(lastError))
end

local function request(url)
	local data = ""

	rawRequest(url, function(chunk)
		data = data .. chunk
	end)

	return data
end

local function download(url, path)
	selectedFilesystemProxy.makeDirectory(filesystemPath(path))

	local fileHandle, reason = selectedFilesystemProxy.open(path, "wb")
	if fileHandle then
		local success, err = pcall(function()
			rawRequest(url, function(chunk)
				selectedFilesystemProxy.write(fileHandle, chunk)
			end)
		end)
		
		selectedFilesystemProxy.close(fileHandle)
		
		if not success then
			-- File doesn't exist on server, remove the empty file
			selectedFilesystemProxy.remove(path)
			return false
		end
		return true
	else
		-- Don't error, just skip this file
		return false
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

-- Warning function (global)
local function warning(text)
	centrizedText(title(), 0xFF9900, "Warning: " .. text)
	centrizedText(title() + 1, 0x878787, "Continuing anyway...")
	
	-- Don't shutdown, just continue after a short delay
	computer.pullSignal(1)
end

-- Checking minimum system requirements
do
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

-- Initializing simple package system for loading system libraries
package = {loading = {}, loaded = {}}



local localization
local stage = 1
local stages = {}

-- First, we need a big ass file list with localizations, applications, wallpapers
progress(0)
local files = deserialize(request(installerURL .. "Files.cfg"))

-- After that we could download required libraries for installer from it
-- First, show loading screen with progress bar (MineOS style)

-- Simple formatTime for early loading (before localization is loaded)
local function formatTimeEarly(seconds)
	if not seconds or seconds < 0 then return "0 秒" end
	
	if seconds < 60 then
		return math.floor(seconds) .. " 秒"
	elseif seconds < 3600 then
		local mins = math.floor(seconds / 60)
		local secs = math.floor(seconds % 60)
		return mins .. " 分 " .. secs .. " 秒"
	else
		local hours = math.floor(seconds / 3600)
		local mins = math.floor((seconds % 3600) / 60)
		return hours .. " 小时 " .. mins .. " 分"
	end
end

-- Show simple MineOS-style loading screen with enhanced info
local function progress(value, label, timeText, filesText)
	local width = 40
	local x, y = centrize(width), title() + 2
	
	-- Draw progress bar
	component.invoke(GPUAddress, "setForeground", 0x878787)
	component.invoke(GPUAddress, "set", x, y, string.rep("─", width))
	
	local part = math.ceil(width * value)
	component.invoke(GPUAddress, "setForeground", 0x3366CC)
	component.invoke(GPUAddress, "set", x, y, string.rep("─", part))
	
	-- Draw label above
	if label then
		component.invoke(GPUAddress, "setForeground", 0x666666)
		component.invoke(GPUAddress, "set", centrize(#label), y - 1, label)
	end
	
	-- Draw time and files info below
	if timeText or filesText then
		local infoText = ""
		if filesText then infoText = infoText .. filesText end
		if timeText then 
			if filesText then infoText = infoText .. "  " end
			infoText = infoText .. timeText 
		end
		component.invoke(GPUAddress, "setForeground", 0x878787)
		component.invoke(GPUAddress, "set", centrize(#infoText), y + 1, infoText)
	end
end

-- Clear screen and show title (without loading text)
component.invoke(GPUAddress, "setBackground", 0xE1E1E1)
component.invoke(GPUAddress, "fill", 1, 1, screenWidth, screenHeight, " ")

local installerStartTime = os.time()
local totalFiles = #files.installerFiles

for i = 1, totalFiles do
	local elapsed = os.time() - installerStartTime
	local remaining = (totalFiles - i) * (i > 0 and elapsed / i or 0.5)
	local percent = (i / totalFiles)
	
	local remainingText = formatTimeEarly(remaining)
	local label = "文件 " .. i .. "/" .. totalFiles
	local timeText = "预计：" .. remainingText
	local filesText = "剩余：" .. (totalFiles - i) .. " 个文件"
	
	progress(percent, label, timeText, filesText)
	
	component.invoke(GPUAddress, "setForeground", 0x878787)
	component.invoke(GPUAddress, "set", centrize(40), title() + 3, "下载：" .. files.installerFiles[i])
	
	download(files.installerFiles[i], installerPath .. files.installerFiles[i])
	
	-- Small delay to show progress (use computer API instead of os.sleep)
	computer.pullSignal(0.05)
end

-- Now initialize require function and system libraries
function require(module)
	if package.loaded[module] then
		return package.loaded[module]
	elseif package.loading[module] then
		error("already loading " .. module .. ": " .. debug.traceback())
	else
		package.loading[module] = true

		local filePath = installerPath .. "Libraries/" .. module .. ".lua"
		local handle, reason = temporaryFilesystemProxy.open(filePath, "rb")
		
		if handle then
			local data, chunk = "", nil
			repeat
				chunk = temporaryFilesystemProxy.read(handle, math.huge)
				data = data .. (chunk or "")
			until not chunk

			temporaryFilesystemProxy.close(handle)
			
			local result, loadReason = load(data, "=" .. module)
			if result then
				package.loaded[module] = result() or true
			else
				error("Failed to load " .. module .. ": " .. tostring(loadReason))
			end
		else
			error("Failed to load " .. module .. ": File not found at " .. filePath)
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

rebootMenuItem = installerMenu:addItem("🔄", "重启")
rebootMenuItem.onTouch = function()
	computer.shutdown(true)
end

shutdownMenuItem = installerMenu:addItem("🛑", "关机")
shutdownMenuItem.onTouch = function()
	computer.shutdown()
end

-- Filesystem selection stage
local stages = {}

-- Main vertical layout
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height - 2, 1, 1))

local stageButtonsLayout = window:addChild(GUI.layout(1, window.height - 1, window.width, 1, 1, 1))
stageButtonsLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
stageButtonsLayout:setSpacing(1, 1, 3)

-- Helper functions that depend on GUI and layout
local function loadImage(name)
	return image.load(installerPicturesPath .. name .. ".pic")
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

	if after > 0 then
		layout:addChild(GUI.object(1, 1, 1, after))
	end

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

local function loadImage(name)
	return image.load(installerPicturesPath .. name .. ".pic")
end

local function newInput(width, ...)
	return GUI.input(1, 1, width, 1, 0xF0F0F0, 0x787878, 0xC3C3C3, 0xF0F0F0, 0x878787, "", ...)
end

-- Initialize UI elements that depend on helper functions
local usernameInput = newInput(30, "")
local passwordInput = newInput(30, "", false, "•")
local passwordSubmitInput = newInput(30, "", false, "•")
local usernamePasswordText = GUI.text(1, 1, 0xCC0040, "")
local withoutPasswordSwitchAndLabel = newSwitchAndLabel(30, 0x66DB80, "", false)

local wallpapersSwitchAndLabel = newSwitchAndLabel(30, 0xFF4980, "", true)
local applicationsSwitchAndLabel = newSwitchAndLabel(30, 0x33DB80, "", true)
local localizationsSwitchAndLabel = newSwitchAndLabel(30, 0x33B6FF, "", true)
local tabletModeSwitchAndLabel = newSwitchAndLabel(30, 0xFF9933, "", true)

local acceptSwitchAndLabel = newSwitchAndLabel(30, 0x9949FF, "", false)

-- Initialize GUI elements
local localizationComboBox = GUI.comboBox(1, 1, 26, 1, 0xF0F0F0, 0x969696, 0xD2D2D2, 0xB4B4B4)

local function formatTime(seconds)
	if not seconds or seconds < 0 then return "0 秒" end
	
	local secKey = localization and localization.seconds or "秒"
	local minKey = localization and localization.minutes or "分"
	local hourKey = localization and localization.hours or "小时"
	
	if seconds < 60 then
		return math.floor(seconds) .. " " .. secKey
	elseif seconds < 3600 then
		local mins = math.floor(seconds / 60)
		local secs = math.floor(seconds % 60)
		return mins .. " " .. minKey .. " " .. secs .. " " .. secKey
	else
		local hours = math.floor(seconds / 3600)
		local mins = math.floor((seconds % 3600) / 60)
		return hours .. " " .. hourKey .. " " .. mins .. " " .. minKey
	end
end

local function updateMenuText()
	-- Update reboot and shutdown button text with localization
	if localization and rebootMenuItem and shutdownMenuItem then
		rebootMenuItem.text = localization.reboot or "重启"
		shutdownMenuItem.text = localization.shutdown or "关机"
	end
	-- Ensure "PixelOS" is always shown in menu title
	if installerMenu then
		installerMenu.text = "PixelOS"
	end
end

local function updateStatusBar()
	local batteryText = "电量：--%"
	
	-- Get battery info using correct OpenComputers API with error handling
	local battery = nil
	for address in component.list("battery") do
		battery = address
		break
	end
	if battery then
		local success, proxy = pcall(component.proxy, battery)
		if success and proxy then
			local energy = 0
			-- OpenComputers battery API: getEnergy() and getMaxEnergy()
			if proxy.getEnergy and proxy.getMaxEnergy then
				local current, max
				local success1, cur = pcall(proxy.getEnergy, proxy)
				local success2, mx = pcall(proxy.getMaxEnergy, proxy)
				if success1 and success2 and cur and mx and mx > 0 then
					current = cur
					max = mx
					energy = math.floor((current / max) * 100)
				end
			end
			batteryText = "电量：" .. energy .. "%"
		end
	end
	
	-- Get real time using computer.getTime() or fallback to uptime
	local timeText = "00:00"
	local success, realTime = pcall(computer.getTime)
	if success and realTime then
		-- Use os.date to format the time
		local success2, dateTable = pcall(os.date, "*t", realTime)
		if success2 and dateTable and dateTable.hour and dateTable.min then
			timeText = string.format("%02d:%02d", dateTable.hour, dateTable.min)
		end
	else
		-- Fallback to uptime if getTime fails
		local success3, uptime = pcall(computer.uptime)
		if success3 and uptime then
			local hours = math.floor(uptime / 3600) % 24
			local minutes = math.floor((uptime % 3600) / 60)
			timeText = string.format("%02d:%02d", hours, minutes)
		end
	end
	
	-- Format status bar text: battery on right, time in center
local sw, sh = component.invoke(GPUAddress, "getResolution")
if not sw then sw = 80 end  -- Default width if failed

-- Set BLACK text color for all status bar text
component.invoke(GPUAddress, "setForeground", 0x000000)

-- Draw battery on right (without clearing entire line to avoid covering menu)
component.invoke(GPUAddress, "setBackground", 0xFFFFFF)
local batteryStart = sw - #batteryText + 1
component.invoke(GPUAddress, "fill", batteryStart, 1, #batteryText, 1, " ")
component.invoke(GPUAddress, "set", batteryStart, 1, batteryText)

-- Draw time in center (without clearing entire line)
local timeStart = centrize(#timeText)
component.invoke(GPUAddress, "fill", timeStart, 1, #timeText, 1, " ")
component.invoke(GPUAddress, "set", timeStart, 1, timeText)
end

-- Initialize status bar after function is defined
updateStatusBar()

-- Initialize menu text
updateMenuText()

-- Override workspace:draw to update status bar
local originalDraw = workspace.draw
workspace.draw = function()
	updateStatusBar()
	return originalDraw(workspace)
end

for i = 1, #files.localizations do
	localizationComboBox:addItem(filesystemHideExtension(filesystemName(files.localizations[i]))).onTouch = function()
		-- Obtaining localization table
		localization = deserialize(request(installerURL .. files.localizations[i]))

		-- Filling widgets with selected localization data
		if localization then
			usernameInput.placeholderText = localization.username
			passwordInput.placeholderText = localization.password
			passwordSubmitInput.placeholderText = localization.submitPassword
			withoutPasswordSwitchAndLabel.label.text = localization.withoutPassword
			wallpapersSwitchAndLabel.label.text = localization.wallpapers
			applicationsSwitchAndLabel.label.text = localization.applications
			localizationsSwitchAndLabel.label.text = localization.languages
			tabletModeSwitchAndLabel.label.text = localization.tabletMode or "平板模式"
			acceptSwitchAndLabel.label.text = localization.accept
			updateMenuText()
			updateStatusBar()
		end
	end
end

-- Select Chinese Simplified by default and ensure it loads properly
local function selectDefaultLanguage()
	-- First, try to find ChineseSimplified in the combobox
	for i = 1, 10 do
		local item = localizationComboBox:getItem(i)
		if item then
			if item.text == "ChineseSimplified" then
				localizationComboBox.selectedItem = i
				-- Call the onTouch function to load the localization
				if item.onTouch then
					item.onTouch()
				end
				return true
			end
		else
			break
		end
	end
	return false
end

-- Try to select default language after populating combobox
if not selectDefaultLanguage() then
	-- If Chinese Simplified not found, select first item
	localizationComboBox.selectedItem = 1
	local firstItem = localizationComboBox:getItem(1)
	if firstItem and firstItem.onTouch then
		firstItem.onTouch()
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
	local nameVaild = usernameInput.text:match("^%w[%w%s_]+")
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
end)

-- Filesystem selection stage
addStage(function()
	prevButton.disabled = false
	nextButton.disabled = false

	layout:addChild(GUI.object(1, 1, 1, 1))
	addTitle(0x696969, localization and localization.select or "Select Filesystem")

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

			disk:addChild(GUI.button(1, disk.height, disk.width, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization and localization.erase or "擦除")).onTouch = function()
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
					proxy.spaceTotal() < 1 * 1024 * 1024 and HDDImage or HDDImage,
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
	layout:addChild(tabletModeSwitchAndLabel)
end)

-- License acception stage
addStage(function()
	checkLicense()

	local selectedLang = localizationComboBox:getItem(localizationComboBox.selectedItem).text
	local langCode = "en_US"
	if selectedLang == "ChineseSimplified" then
		langCode = "zh_CN"
	elseif selectedLang == "ChineseTraditional" then
		langCode = "zh_TW"
	elseif selectedLang == "English" then
		langCode = "en_US"
	else
		langCode = selectedLang
	end
	
	local licenseURL = "Installer/Licenses/LICENSE_" .. langCode
	local licenseContent
	local success, err = pcall(function()
		licenseContent = request(licenseURL)
	end)
	
	if not success or not licenseContent or licenseContent == "" then
		-- Try fallback to English if specific language not found
		success, err = pcall(function()
			licenseContent = request("Installer/Licenses/LICENSE_en_US")
		end)
	end
	
	-- If still failed, use a default message
	if not success or not licenseContent or licenseContent == "" then
		licenseContent = "PixelOS License Agreement\n\nBy using this software, you agree to the terms and conditions."
	end
	
	local lines = text.wrap({licenseContent}, layout.width - 2)
	local textBox = layout:addChild(GUI.textBox(1, 1, layout.width, layout.height - 3, 0xF0F0F0, 0x696969, lines, 1, 1, 1))

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
		
		-- Save tablet mode preference
		local config = {
			tabletMode = tabletModeSwitchAndLabel.switch.state
		}
		local handle = selectedFilesystemProxy.open("/Settings/UserSettings.cfg", "wb")
		if handle then
			selectedFilesystemProxy.write(handle, "return " .. text.serialize(config))
			selectedFilesystemProxy.close(handle)
		end
	end)

	-- Downloading files
	layout:removeChildren()
	addImage(3, 2, "Downloading")

	local container = layout:addChild(GUI.container(1, 1, layout.width - 20, 2))
	local progressBar = container:addChild(GUI.progressBar(1, 1, container.width, 0x66B6FF, 0xD2D2D2, 0xA5A5A5, 0, true, false))
	local cyka = container:addChild(GUI.label(1, 2, container.width, 1, 0x969696, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

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

	-- Calculate total size for progress
	local totalFiles = #downloadList
	local function getFileSize(path)
		local size = 0
		local data = ""
		rawRequest(path, function(chunk)
			data = data .. chunk
		end)
		return #data
	end
	
	local startTime = os.time()

	-- Downloading files from created list
	local versions, path, id, version, shortcut = {}
	local downloadedFiles = 0
	local skippedFiles = 0
	
	-- Check total available space once at the beginning
	local totalAvailableSpace = selectedFilesystemProxy.spaceTotal() - selectedFilesystemProxy.spaceUsed()
	local estimatedTotalSize = #downloadList * 50 * 1024  -- Estimate 50KB per file average
	
	if totalAvailableSpace < estimatedTotalSize then
		-- Not enough space, but continue anyway with warning
		cyka.text = text.limit("警告：空间可能不足，但将继续安装", container.width, "center")
		workspace:draw()
		computer.pullSignal(1)  -- Wait 1 second instead of os.sleep
	end
	
	for i = 1, #downloadList do
		path, id, version, shortcut = getData(downloadList[i])

		-- Check available space before downloading (with smaller threshold)
		local availableSpace = selectedFilesystemProxy.spaceTotal() - selectedFilesystemProxy.spaceUsed()
		if availableSpace < 10 * 1024 then  -- Less than 10KB available (in bytes)
			skippedFiles = skippedFiles + 1
			cyka.text = text.limit((localization.notEnoughSpace or "空间不足，跳过:") .. " " .. path, container.width, "center")
			workspace:draw()
			computer.pullSignal(0.5)  -- Wait 0.5 second instead of os.sleep
			-- Update progress to account for skipped files
			progressBar.value = math.floor((downloadedFiles + skippedFiles) / totalFiles * 100)
			goto continue_download
		end

		cyka.text = text.limit(localization.installing .. " \"" .. path .. "\"", container.width, "center")
		workspace:draw()

		-- Download file
		local downloadSuccess = download(path, OSPath .. path)
		
		if downloadSuccess then
			downloadedFiles = downloadedFiles + 1
		else
			skippedFiles = skippedFiles + 1
		end

		-- Adding system versions data
		if id and downloadSuccess then
			versions[id] = {
				path = OSPath .. path,
				version = version or 1,
			}
		end

		-- Create shortcut if possible
		if shortcut and downloadSuccess then
			switchProxy(function()
				system.createShortcut(
					userPaths.desktop .. filesystem.hideExtension(filesystem.name(filesystem.path(path))),
					OSPath .. filesystem.path(path)
				)
			end)
		end

		progressBar.value = math.floor((downloadedFiles + skippedFiles) / totalFiles * 100)
		
		-- Update progress info
		local remainingFiles = totalFiles - downloadedFiles - skippedFiles
		local elapsedTime = os.time() - startTime
		local avgTimePerFile = downloadedFiles > 0 and elapsedTime / downloadedFiles or 0
		local remainingTime = remainingFiles * avgTimePerFile
		
		local sizeUsed = selectedFilesystemProxy.spaceUsed()
		local sizeTotal = selectedFilesystemProxy.spaceTotal()
		
		-- Use localization if available, otherwise use English defaults
		local remainingFilesText = localization and localization.remainingFiles or "Remaining:"
		local remainingTimeText = localization and localization.remainingTime or "Time:"
		local spaceUsedText = localization and localization.spaceUsed or "Space:"
		
		local fileInfo = remainingFilesText .. " " .. remainingFiles .. "  "
		local timeInfo = remainingTimeText .. " " .. formatTime(remainingTime) .. "  "
		local sizeInfo = spaceUsedText .. " " .. math.floor(sizeUsed / 1024) .. "KB / " .. math.floor(sizeTotal / 1024) .. "KB"
		
		cyka.text = text.limit(fileInfo .. timeInfo .. sizeInfo, container.width, "center")
		workspace:draw()
		
		::continue_download::
	end

	-- Flashing EEPROM
	layout:removeChildren()
	addImage(1, 1, "EEPROM")
	addTitle(0x969696, localization.flashing)
	workspace:draw()
	
	component.invoke(EEPROMAddress, "set", request(EFIURL))
	component.invoke(EEPROMAddress, "setLabel", "PixelOS Install Bios")
	component.invoke(EEPROMAddress, "setData", selectedFilesystemProxy.address)

	-- Ask user if they want to install BIOS Manager
	local installBiosManager = false
	local confirmWindow = workspace:addChild(GUI.window(math.floor(workspace.width / 2 - 20), math.floor(workspace.height / 2 - 8), 40, 16))
	confirmWindow:addChild(GUI.panel(1, 1, confirmWindow.width, confirmWindow.height, 0xE1E1E1))
	confirmWindow:addChild(GUI.label(1, 2, confirmWindow.width, 1, 0x2D2D2D, localization.installBiosManager or "安装 BIOS 管理器？")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	confirmWindow:addChild(GUI.label(1, 4, confirmWindow.width - 2, 1, 0x696969, localization.installBiosManagerDesc or "安装 macOS 风格的启动管理器，提供更多功能")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	
	local confirmButton = confirmWindow:addChild(GUI.adaptiveRoundedButton(1, 8, 2, 0, 0x3366CC, 0xFFFFFF, 0x2255AA, 0xFFFFFF, localization.confirm or "确认"))
	local cancelButton = confirmWindow:addChild(GUI.adaptiveRoundedButton(1, 10, 2, 0, 0xC3C3C3, 0x696969, 0xA5A5A5, 0xFFFFFF, localization.cancel or "取消"))
	
	local confirmResult = false
	
	confirmButton.onTouch = function()
		installBiosManager = true
		confirmWindow:remove()
		workspace:draw()
		confirmResult = true
	end
	
	cancelButton.onTouch = function()
		installBiosManager = false
		confirmWindow:remove()
		workspace:draw()
		confirmResult = true
	end
	
	workspace:draw()
	
	while not confirmResult do
		computer.pullSignal(0.1)
	end
	
	if installBiosManager then
		layout:removeChildren()
		addImage(1, 1, "EEPROM")
		addTitle(0x969696, localization.installingBiosManager or "正在安装 BIOS 管理器...")
		workspace:draw()
		
		local bootManagerURL = "EFI/BootManager.lua"
		local bootManagerCode = request(bootManagerURL)
		
		component.invoke(EEPROMAddress, "set", bootManagerCode)
		component.invoke(EEPROMAddress, "setLabel", "PixelOS Bios Manager")
	end


	-- Saving system versions
	switchProxy(function()
		filesystem.writeTable(paths.system.versions, versions, true)
	end)

	-- Done info
	layout:removeChildren()
	addImage(1, 1, "Done")
	addTitle(0x969696, localization.installed or "安装完成")
	addStageButton(localization.reboot or "重启").onTouch = function()
		computer.shutdown(true)
	end
	workspace:draw()

	-- Removing temporary installer directory
	temporaryFilesystemProxy.remove(installerPath)
end)

--------------------------------------------------------------------------------

loadStage()
workspace:start()