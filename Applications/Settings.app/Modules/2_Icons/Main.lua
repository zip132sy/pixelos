
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

	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.appearanceSize))

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

		window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.statusBarSettings or "Status Bar Settings"))

		local statusBarSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.enableStatusBar or "Enable Status Bar" .. ":", userSettings.interfaceStatusBarEnabled ~= false)).switch
		local batterySwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.showBattery or "Show Battery" .. ":", userSettings.interfaceStatusBarShowBattery ~= false)).switch
		local ramSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.showRAM or "Show RAM" .. ":", userSettings.interfaceStatusBarShowRAM ~= false)).switch
		local cpuSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.showCPU or "Show CPU" .. ":", userSettings.interfaceStatusBarShowCPU ~= false)).switch
		local diskSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.showDisk or "Show Disk" .. ":", userSettings.interfaceStatusBarShowDisk ~= false)).switch
		local archSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.showArchitecture or "Show Architecture" .. ":", userSettings.interfaceStatusBarShowArchitecture ~= false)).switch

		window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.diskDisplaySettings or "Disk Display Settings"))

		local diskTogglesLayout = window.contentLayout:addChild(GUI.layout(1, 1, window.contentLayout.width, 1, 1, 1))
		diskTogglesLayout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
		diskTogglesLayout:setSpacing(1, 1, 2)

		if not userSettings.interfaceStatusBarDiskDisplays then
			userSettings.interfaceStatusBarDiskDisplays = {}
		end

		local diskSwitches = {}
		for address in component.list("filesystem") do
			local proxy = component.proxy(address)
			local label = proxy.getLabel() or address:sub(1, 8)
			local diskKey = address:sub(1, 8)
			local isShown = userSettings.interfaceStatusBarDiskDisplays[diskKey] ~= false
			local diskSw = diskTogglesLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, label .. ": ", isShown))
			diskSwitches[diskKey] = diskSw
		end

		diskTogglesLayout.height = math.max(1, #diskTogglesLayout.children * 2)

		local function saveStatusBarSettings()
			userSettings.interfaceStatusBarEnabled = statusBarSwitch.state
			userSettings.interfaceStatusBarShowBattery = batterySwitch.state
			userSettings.interfaceStatusBarShowRAM = ramSwitch.state
			userSettings.interfaceStatusBarShowCPU = cpuSwitch.state
			userSettings.interfaceStatusBarShowDisk = diskSwitch.state
			userSettings.interfaceStatusBarShowArchitecture = archSwitch.state

			for diskKey, sw in pairs(diskSwitches) do
				userSettings.interfaceStatusBarDiskDisplays[diskKey] = sw.switch.state
			end

			system.saveUserSettings()
			system.updateMenuWidgets()
			workspace:draw()

			local message = GUI.messageBox(workspace, localization.success or "Success", localization.settingsSaved or "Settings saved", localization.ok or "OK", nil, "info")
			message:show()
		end

		statusBarSwitch.onStateChanged = saveStatusBarSettings
		batterySwitch.onStateChanged = saveStatusBarSettings
		ramSwitch.onStateChanged = saveStatusBarSettings
		cpuSwitch.onStateChanged = saveStatusBarSettings
		diskSwitch.onStateChanged = saveStatusBarSettings
		archSwitch.onStateChanged = saveStatusBarSettings

		for _, sw in pairs(diskSwitches) do
			sw.switch.onStateChanged = saveStatusBarSettings
		end

	end

	--------------------------------------------------------------------------------

	return module

