
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

-- Feature: Multiple repository URLs with fallback
local repositoryURLs = {
	"https://gitee.com/zip132sy/pixelos/raw/master/",
	"https://raw.githubusercontent.com/zip132sy/pixelos/master/"
}
local repositoryURL = repositoryURLs[1]
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
	component.invoke(GPUAddress, "fill", 1, y, screenWidth, 1, " ")
	component.invoke(GPUAddress, "setForeground", color)
	component.invoke(GPUAddress, "set", centrize(#text), y, text)
end

local function title()
	local y = math.floor(screenHeight / 2 - 1)
	centrizedText(y, 0x2D2D2D, "PixelOS")

	return y + 2
end

-- Feature #1 & #3: Progress with time estimation
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
			while true do
				chunk, err = internetHandle.read(math.huge)	
				
				if chunk then
					chunkHandler(chunk)
				else
					if err then
						lastError = err
						break
					end
					internetHandle.close()
					return true
				end
			end
			internetHandle.close()
		else
			lastError = reason
		end
	end
	
	error("Connection failed for all URLs: " .. tostring(lastError))
end

-- Load SHA-256 library for file verification
local sha256
pcall(function()
	sha256 = require("SHA-256")
end)

-- Load file hashes for verification
local fileHashes
pcall(function()
	fileHashes = dofile(installerPath .. "FileHashes.lua")
end)

-- Cache directory for downloaded files
local cacheDir = "/PixelOS cache/"

-- Function to verify file hash
local function verifyHash(data, expectedHash)
	if not sha256 or not expectedHash then
		return true
	end
	local actualHash = sha256(data)
	return actualHash == expectedHash
end

-- Function to check if cached file exists and is valid
local function getCachedFile(url)
	if not temporaryFilesystemProxy then
		return nil
	end
	
	local cachePath = cacheDir .. url:gsub("/", "_")
	
	if not temporaryFilesystemProxy.exists(cachePath) then
		return nil
	end
	
	local fileHandle = temporaryFilesystemProxy.open(cachePath, "rb")
	if not fileHandle then
		return nil
	end
	
	local data = ""
	local chunk
	repeat
		chunk = temporaryFilesystemProxy.read(fileHandle, math.huge)
		data = data .. (chunk or "")
	until not chunk
	
	temporaryFilesystemProxy.close(fileHandle)
	
	-- Verify hash if available
	local expectedHash = fileHashes and fileHashes[url]
	if expectedHash and not verifyHash(data, expectedHash) then
		-- Hash mismatch, remove invalid cache
		temporaryFilesystemProxy.remove(cachePath)
		return nil
	end
	
	return data
end

-- Function to save file to cache
local function saveToCache(url, data)
	if not temporaryFilesystemProxy then
		return
	end
	
	temporaryFilesystemProxy.makeDirectory(cacheDir)
	
	local cachePath = cacheDir .. url:gsub("/", "_")
	local fileHandle = temporaryFilesystemProxy.open(cachePath, "wb")
	
	if fileHandle then
		temporaryFilesystemProxy.write(fileHandle, data)
		temporaryFilesystemProxy.close(fileHandle)
	end
end

local function request(url)
	-- Check cache first
	local cachedData = getCachedFile(url)
	if cachedData then
		return cachedData
	end
	
	-- Download from network
	local data = ""
	
	rawRequest(url, function(chunk)
		data = data .. chunk
	end)

	-- Save to cache
	saveToCache(url, data)

	return data
end

local function download(url, path)
	-- Check if file already exists and is valid
	if selectedFilesystemProxy.exists(path) then
		local fileHandle = selectedFilesystemProxy.open(path, "rb")
		if fileHandle then
			local data = ""
			local chunk
			repeat
				chunk = selectedFilesystemProxy.read(fileHandle, math.huge)
				data = data .. (chunk or "")
			until not chunk
			selectedFilesystemProxy.close(fileHandle)
			
			-- Verify hash if available
			local expectedHash = fileHashes and fileHashes[url]
			if expectedHash and verifyHash(data, expectedHash) then
				-- File exists and is valid, skip download
				return
			end
		end
	end
	
	-- Download file
	selectedFilesystemProxy.makeDirectory(filesystemPath(path))

	local fileHandle, reason = selectedFilesystemProxy.open(path, "wb")
	if fileHandle then	
		rawRequest(url, function(chunk)
			selectedFilesystemProxy.write(fileHandle, chunk)
		end)

		selectedFilesystemProxy.close(fileHandle)
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

-- Feature #1: Download installer files with progress and time estimation
local files = deserialize(request(installerURL .. "Files.cfg"))
local totalInstallerFiles = #files.installerFiles
local installerStartTime = computer.uptime()

for i = 1, totalInstallerFiles do
	-- Calculate ETA
	local elapsed = computer.uptime() - installerStartTime
	local remaining = totalInstallerFiles - i
	local eta = (elapsed / i) * remaining
	
	local timeText
	if eta < 60 then
		timeText = string.format("~%ds", math.floor(eta))
	else
		timeText = string.format("~%dm", math.floor(eta / 60))
	end
	
	local progressText = string.format("%d/%d | %s", i, totalInstallerFiles, timeText)
	progress(i / totalInstallerFiles, progressText)
	
	download(files.installerFiles[i], installerPath .. files.installerFiles[i])
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
			local data = ""
			local chunk
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

local statusMenuItem

local function updateStatusMenuItem()
	if statusMenuItem and localization then
		local battery = getBatteryInfo() or 0
		local powerText = localization.power or "Power"
		local timeStr = formatTime()
		statusMenuItem.text = " " .. timeStr .. " | " .. battery .. "% " .. powerText
	end
end

local function getBatteryInfo()
	local ok, energy = pcall(computer.energy)
	local ok2, maxEnergy = pcall(computer.maxEnergy)
	if ok and ok2 and maxEnergy and maxEnergy > 0 then
		local percent = math.floor((energy / maxEnergy) * 100)
		return percent
	end
	return nil
end

local function formatTime()
	local zone = 8
	if localization and localization.settings_timeZone then
		zone = tonumber(localization.settings_timeZone) or 8
	end
	local localTime = os.time() + zone * 3600
	return os.date("%H:%M", localTime)
end

statusMenuItem = installerMenu:addItem("")
statusMenuItem.onTouch = function()
	updateStatusMenuItem()
	workspace:draw()
end

installerMenu:addItem("Reboot").onTouch = function()
	computer.shutdown(true)
end

installerMenu:addItem("Shutdown").onTouch = function()
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

-- Feature #2: Load ChineseSimplified localization by default BEFORE creating UI
local localization
local defaultLocalizationIndex = 1
for i = 1, #files.localizations do
	if filesystemHideExtension(filesystemName(files.localizations[i])) == "ChineseSimplified" then
		defaultLocalizationIndex = i
		break
	end
end
-- Load default localization immediately
localization = deserialize(request(installerURL .. files.localizations[defaultLocalizationIndex]))
updateStatusMenuItem()

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

local acceptSwitchAndLabel = newSwitchAndLabel(30, 0x9949FF, "", false)

-- Feature #4: License file mapping
local function getLicenseFile(localizationName)
	local licenseMap = {
		ChineseSimplified = "LICENSE_zh_CN",
		ChineseTraditional = "LICENSE_zh_TW",
		Russian = "LICENSE_ru_RU",
		German = "LICENSE_de_DE",
		French = "LICENSE_fr_FR",
		Spanish = "LICENSE_es_ES",
		Japanese = "LICENSE_ja_JP",
		Korean = "LICENSE_ko_KR",
		Italian = "LICENSE_it_IT",
		Finnish = "LICENSE_fi_FI",
		Dutch = "LICENSE_nl_NL",
		Ukrainian = "LICENSE_uk_UA",
		Belarusian = "LICENSE_be_BY",
		Bulgarian = "LICENSE_bg_BG",
		Slovak = "LICENSE_sk_SK",
		Arabic = "LICENSE_ar_SA",
		Bengali = "LICENSE_bn_BD",
		Hindi = "LICENSE_hi_IN",
		Portuguese = "LICENSE_pt_PT",
		Polish = "LICENSE_pl_PL",
	}
	return licenseMap[localizationName] or "LICENSE_en_US"
end

local localizationComboBox = GUI.comboBox(1, 1, 26, 1, 0xF0F0F0, 0x969696, 0xD2D2D2, 0xB4B4B4)
for i = 1, #files.localizations do
	localizationComboBox:addItem(filesystemHideExtension(filesystemName(files.localizations[i]))).onTouch = function()
		-- Obtaining localization table
		localization = deserialize(request(installerURL .. files.localizations[i]))
		updateStatusMenuItem()

		-- Filling widgets with selected localization data
		usernameInput.placeholderText = localization.username
		passwordInput.placeholderText = localization.password
		passwordSubmitInput.placeholderText = localization.submitPassword
		withoutPasswordSwitchAndLabel.label.text = localization.withoutPassword
		wallpapersSwitchAndLabel.label.text = localization.wallpapers
		applicationsSwitchAndLabel.label.text = localization.applications
		localizationsSwitchAndLabel.label.text = localization.languages
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

-- Feature #2: Localization selection stage with ChineseSimplified default
addStage(function()
	prevButton.disabled = true

	addImage(0, 1, "Languages")
	layout:addChild(localizationComboBox)

	workspace:draw()
	
	-- Set default to ChineseSimplified
	local defaultIndex = 1
	for i = 1, #files.localizations do
		if filesystemHideExtension(filesystemName(files.localizations[i])) == "ChineseSimplified" then
			defaultIndex = i
			break
		end
	end
	localizationComboBox.selectedItem = defaultIndex
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

			disk:addChild(GUI.roundedButton(1, disk.height, disk.width, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.erase)).onTouch = function()
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
end)

-- Feature #4: License acception stage with localized license
addStage(function()
	checkLicense()

	-- Get localized license file
	local selectedLocalization = localizationComboBox:getItem(localizationComboBox.selectedItem).text
	local licenseFile = getLicenseFile(selectedLocalization)
	local lines = text.wrap({request("Licenses/" .. licenseFile)}, layout.width - 2)
	local textBox = layout:addChild(GUI.textBox(1, 1, layout.width, layout.height - 3, 0xF0F0F0, 0x696969, lines, 1, 1, 1))

	layout:addChild(acceptSwitchAndLabel)
end)

-- Feature #3: Downloading stage with time estimation
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
	addImage(3, 2, "Downloading")

	local container = layout:addChild(GUI.container(1, 1, layout.width - 20, 3))
	local progressBar = container:addChild(GUI.progressBar(1, 1, container.width, 0x66B6FF, 0xD2D2D2, 0xA5A5A5, 0, true, false))
	local currentFileLabel = container:addChild(GUI.label(1, 2, container.width, 1, 0x969696, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	local progressInfoLabel = container:addChild(GUI.label(1, 3, container.width, 1, 0x666666, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

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
			local selectedItem = localizationComboBox:getItem(localizationComboBox.selectedItem)
			local selectedLocalization, path, localizationName
			if selectedItem and selectedItem.text then
				selectedLocalization = selectedItem.text
			end
			
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

	-- Feature #3: Downloading files with time estimation
	local versions, path, id, version, shortcut = {}
	local downloadStartTime = computer.uptime()
	
	for i = 1, #downloadList do
		path, id, version, shortcut = getData(downloadList[i])

		-- Calculate ETA
		local elapsed = computer.uptime() - downloadStartTime
		local remaining = #downloadList - i
		local eta = (elapsed / i) * remaining
		
		local timeText
		if eta < 60 then
			timeText = string.format("~%ds", math.floor(eta))
		else
			timeText = string.format("~%dm", math.floor(eta / 60))
		end
		
		currentFileLabel.text = text.limit(localization.installing .. " \"" .. path .. "\"", container.width, "center")
		progressInfoLabel.text = string.format("%d/%d | %s", i, #downloadList, timeText)
		workspace:draw()

		-- Download file
		download(path, OSPath .. path)

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
	end

	-- Flashing EEPROM
	layout:removeChildren()
	addImage(1, 1, "EEPROM")
	addTitle(0x969696, localization.flashing)
	workspace:draw()
	
	component.invoke(EEPROMAddress, "set", request(EFIURL))
	component.invoke(EEPROMAddress, "setLabel", "PixelOS EFI")
	component.invoke(EEPROMAddress, "setData", selectedFilesystemProxy.address)

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

	-- Removing temporary installer directory
	temporaryFilesystemProxy.remove(installerPath)
end)

--------------------------------------------------------------------------------

loadStage()

local function statusUpdateLoop()
	while true do
		os.sleep(1)
		if workspace.running then
			updateStatusMenuItem()
			workspace:draw()
		else
			break
		end
	end
end

local statusThread = require("thread")
statusThread.start(statusUpdateLoop)

workspace:start()
