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

		local archSwitch = content:addChild(GUI.switchAndLabel(1, 1, 20, 6, 0x66DB80, 0x2D2D2D, (localization.showArchitecture or "Show Architecture") .. ":", userSettings.interfaceStatusBarShowArchitecture ~= false))

		-- Per-disk display toggles
		content:addChild(GUI.text(1, 1, 0x2D2D2D, (localization.diskDisplaySettings or "Disk Display Settings") .. ":"))

		local diskTogglesLayout = content:addChild(GUI.layout(1, 1, window.contentLayout.width, 1, 1, 1))
		diskTogglesLayout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
		diskTogglesLayout:setSpacing(1, 1, 2)

		-- Initialize disk display settings if not exists
		if not userSettings.interfaceStatusBarDiskDisplays then
			userSettings.interfaceStatusBarDiskDisplays = {}
		end

		local diskSwitches = {}
		for address in component.list("filesystem") do
			local proxy = component.proxy(address)
			local label = proxy.getLabel() or address:sub(1, 8)
			local diskKey = address:sub(1, 8)
			local isShown = userSettings.interfaceStatusBarDiskDisplays[diskKey] ~= false
			local diskSw = diskTogglesLayout:addChild(GUI.switchAndLabel(1, 1, 36, 6, 0x66DB80, 0x2D2D2D, label .. ": ", isShown))
			diskSwitches[diskKey] = diskSw
		end

		diskTogglesLayout.height = math.max(1, #diskTogglesLayout.children * 2)

		local applyButton = content:addChild(GUI.button(1, 1, 20, 3, 0x666666, 0xFFFFFF, 0x333333, 0xFFFFFF, localization.apply or "Apply"))
		applyButton.onTouch = function()
			userSettings.interfaceStatusBarEnabled = statusBarSwitch.switch.state
			userSettings.interfaceStatusBarShowBattery = batterySwitch.switch.state
			userSettings.interfaceStatusBarShowRAM = ramSwitch.switch.state
			userSettings.interfaceStatusBarShowCPU = cpuSwitch.switch.state
			userSettings.interfaceStatusBarShowDisk = diskSwitch.switch.state
			userSettings.interfaceStatusBarShowArchitecture = archSwitch.switch.state

			-- Save per-disk display settings
			for diskKey, sw in pairs(diskSwitches) do
				userSettings.interfaceStatusBarDiskDisplays[diskKey] = sw.switch.state
			end

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
			archSwitch.switch.state = true
			for diskKey, sw in pairs(diskSwitches) do
				sw.switch.state = true
			end

			workspace:draw()
		end

		workspace:draw()
	end
}
