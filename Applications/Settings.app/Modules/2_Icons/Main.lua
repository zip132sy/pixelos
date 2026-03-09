
local GUI = require("GUI")
local paths = require("Paths")
local system = require("System")

local module = {}

local workspace, window, localization = table.unpack({...})
local userSettings = system.getUserSettings()

--------------------------------------------------------------------------------

module.name = localization.appearance
module.margin = 9

module.onTouch = function()
	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.appearanceFiles))

	local showExtensionSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.appearanceExtensions .. ":", userSettings.filesShowExtension)).switch
	local showHiddenFilesSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.appearanceHidden .. ":", userSettings.filesShowHidden)).switch
	local showApplicationIconsSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.appearanceApplications .. ":", userSettings.filesShowApplicationIcon)).switch
	local transparencySwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0xFF4940, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.appearanceTransparencyEnabled .. ":", userSettings.interfaceTransparencyEnabled)).switch
	local blurSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0xFF4940, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.appearanceBlurEnabled .. ":", userSettings.interfaceBlurEnabled)).switch
	
	window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {localization.appearanceTransparencyInfo}, 1, 0, 0, true, true))

	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.statusBar))

	local statusBarEnabledSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.statusBar .. ":", userSettings.interfaceStatusBarEnabled)).switch
	local showBatterySwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.battery .. ":", userSettings.interfaceStatusBarShowBattery)).switch
	local showRAMSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.ram .. ":", userSettings.interfaceStatusBarShowRAM)).switch
	local showDiskSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.disk .. ":", userSettings.interfaceStatusBarShowDisk)).switch
	local showCPUSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.cpu .. ":", userSettings.interfaceStatusBarShowCPU)).switch
	
	-- Disk-specific switches
	if userSettings.interfaceStatusBarShowDisk then
		window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.disk .. " " .. localization.settings))
		
		-- Initialize disk visibility settings if not exists
		if not userSettings.interfaceStatusBarShowDisks then
			userSettings.interfaceStatusBarShowDisks = {}
		end
		
		-- Get all filesystems and create switches
		local component = require("component")
		local diskIndex = 0
		for address, ctype in component.list("filesystem") do
			diskIndex = diskIndex + 1
			local proxy = component.proxy(address)
			local label = proxy.getLabel() or ("Disk " .. diskIndex)
			local diskKey = "disk_" .. diskIndex
			
			-- Initialize visibility if not set
			if userSettings.interfaceStatusBarShowDisks[diskKey] == nil then
				userSettings.interfaceStatusBarShowDisks[diskKey] = true
			end
			
			local diskSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, label .. ":", userSettings.interfaceStatusBarShowDisks[diskKey])).switch
			
			diskSwitch.onStateChanged = function()
				userSettings.interfaceStatusBarShowDisks[diskKey] = diskSwitch.state
				system.saveUserSettings()
			end
		end
	end

	local iconWidthSlider = window.contentLayout:addChild(GUI.slider(1, 1, 36, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, 8, 16, userSettings.iconWidth, false, localization.appearanceHorizontal .. ": ", ""))
	local iconHeightSlider = window.contentLayout:addChild(GUI.slider(1, 1, 36, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, 6, 16, userSettings.iconHeight, false, localization.appearanceVertical .. ": ", ""))
	iconHeightSlider.height = 2

	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.appearanceSpace))

	local iconHorizontalSpaceBetweenSlider = window.contentLayout:addChild(GUI.slider(1, 1, 36, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, 0, 5, userSettings.iconHorizontalSpace, false, localization.appearanceHorizontal .. ": ", ""))
	local iconVerticalSpaceBetweenSlider = window.contentLayout:addChild(GUI.slider(1, 1, 36, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, 0, 5, userSettings.iconVerticalSpace, false, localization.appearanceVertical .. ": ", ""))
	iconVerticalSpaceBetweenSlider.height = 2

	iconHorizontalSpaceBetweenSlider.roundValues, iconVerticalSpaceBetweenSlider.roundValues = true, true
	iconWidthSlider.roundValues, iconHeightSlider.roundValues = true, true

	local function setIconProperties(width, height, horizontalSpace, verticalSpace)
		userSettings.iconWidth, userSettings.iconHeight, userSettings.iconHorizontalSpace, userSettings.iconVerticalSpace = width, height, horizontalSpace, verticalSpace
		system.saveUserSettings()
		
		system.calculateIconProperties()
		system.updateIconProperties()
	end

	iconWidthSlider.onValueChanged = function()
		setIconProperties(math.floor(iconWidthSlider.value), math.floor(iconHeightSlider.value), userSettings.iconHorizontalSpace, userSettings.iconVerticalSpace)
	end
	iconHeightSlider.onValueChanged = iconWidthSlider.onValueChanged

	iconHorizontalSpaceBetweenSlider.onValueChanged = function()
		setIconProperties(userSettings.iconWidth, userSettings.iconHeight, math.floor(iconHorizontalSpaceBetweenSlider.value), math.floor(iconVerticalSpaceBetweenSlider.value))
	end
	iconVerticalSpaceBetweenSlider.onValueChanged = iconHorizontalSpaceBetweenSlider.onValueChanged

	showExtensionSwitch.onStateChanged = function()
		userSettings.filesShowExtension = showExtensionSwitch.state
		userSettings.filesShowHidden = showHiddenFilesSwitch.state
		userSettings.filesShowApplicationIcon = showApplicationIconsSwitch.state
		userSettings.interfaceTransparencyEnabled = transparencySwitch.state
		userSettings.interfaceBlurEnabled = blurSwitch.state
		
		system.updateColorScheme()
		system.saveUserSettings()

		computer.pushSignal("system", "updateFileList")
	end

	showHiddenFilesSwitch.onStateChanged, showApplicationIconsSwitch.onStateChanged, transparencySwitch.onStateChanged, blurSwitch.onStateChanged = showExtensionSwitch.onStateChanged, showExtensionSwitch.onStateChanged, showExtensionSwitch.onStateChanged, showExtensionSwitch.onStateChanged

	statusBarEnabledSwitch.onStateChanged = function()
		userSettings.interfaceStatusBarEnabled = statusBarEnabledSwitch.state
		userSettings.interfaceStatusBarShowBattery = showBatterySwitch.state
		userSettings.interfaceStatusBarShowRAM = showRAMSwitch.state
		userSettings.interfaceStatusBarShowDisk = showDiskSwitch.state
		userSettings.interfaceStatusBarShowCPU = showCPUSwitch.state
		
		system.saveUserSettings()
	end

	showBatterySwitch.onStateChanged, showRAMSwitch.onStateChanged, showDiskSwitch.onStateChanged, showCPUSwitch.onStateChanged = statusBarEnabledSwitch.onStateChanged, statusBarEnabledSwitch.onStateChanged, statusBarEnabledSwitch.onStateChanged, statusBarEnabledSwitch.onStateChanged

end

--------------------------------------------------------------------------------

return module

