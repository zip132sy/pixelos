local GUI = require("GUI")
local screen = require("Screen")
local system = require("System")
local paths = require("Paths")
local filesystem = require("Filesystem")

local workspace, window, localization = ...
local userSettings = system.getUserSettings()

return {
	name = localization.statusBar or "Status Bar",
	margin = 10,

	onTouch = function()
		local content = window.contentLayout:addChild(GUI.layout(1, 1, window.contentLayout.width, 1, 1, 1))
		content:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
		content:setSpacing(1, 1, 3)

		content:addChild(GUI.text(1, 1, 0x2D2D2D, (localization.statusBarSettings or "Status Bar Settings") .. ":"))

		local statusBarSwitch = content:addChild(GUI.switchAndLabel(1, 1, 20, 6, 0x66DB80, 0x2D2D2D, (localization.enableStatusBar or "Enable Status Bar") .. ":", userSettings.interfaceStatusBarEnabled ~= false))

		local batterySwitch = content:addChild(GUI.switchAndLabel(1, 1, 20, 6, 0x66DB80, 0x2D2D2D, (localization.showBattery or "Show Battery") .. ":", userSettings.interfaceStatusBarShowBattery ~= false))

		local ramSwitch = content:addChild(GUI.switchAndLabel(1, 1, 20, 6, 0x66DB80, 0x2D2D2D, (localization.showRAM or "Show RAM") .. ":", userSettings.interfaceStatusBarShowRAM ~= false))

		local cpuSwitch = content:addChild(GUI.switchAndLabel(1, 1, 20, 6, 0x66DB80, 0x2D2D2D, (localization.showCPU or "Show CPU") .. ":", userSettings.interfaceStatusBarShowCPU ~= false))

		local diskSwitch = content:addChild(GUI.switchAndLabel(1, 1, 20, 6, 0x66DB80, 0x2D2D2D, (localization.showDisk or "Show Disk") .. ":", userSettings.interfaceStatusBarShowDisk ~= false))

		local applyButton = content:addChild(GUI.button(1, 1, 20, 3, 0x666666, 0xFFFFFF, 0x333333, 0xFFFFFF, localization.apply or "Apply"))
		applyButton.onTouch = function()
			userSettings.interfaceStatusBarEnabled = statusBarSwitch.switch.state
			userSettings.interfaceStatusBarShowBattery = batterySwitch.switch.state
			userSettings.interfaceStatusBarShowRAM = ramSwitch.switch.state
			userSettings.interfaceStatusBarShowCPU = cpuSwitch.switch.state
			userSettings.interfaceStatusBarShowDisk = diskSwitch.switch.state

			system.saveUserSettings()
			system.updateMenuWidgets()
			workspace:draw()

			local message = GUI.messageBox(workspace, localization.success or "Success", localization.settingsSaved or "Settings saved", localization.ok or "OK", nil, "info")
			message:show()
		end

		local resetButton = content:addChild(GUI.button(1, 1, 20, 3, 0x666666, 0xFFFFFF, 0x333333, 0xFFFFFF, localization.resetToDefault or "Reset"))
		resetButton.onTouch = function()
			statusBarSwitch.switch.state = true
			batterySwitch.switch.state = true
			ramSwitch.switch.state = true
			cpuSwitch.switch.state = true
			diskSwitch.switch.state = true

			workspace:draw()
		end

		workspace:draw()
	end
}
