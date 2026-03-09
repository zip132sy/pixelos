
local GUI = require("GUI")
local paths = require("Paths")
local system = require("System")

local module = {}

local workspace, window, localization = table.unpack({...})
local userSettings = system.getUserSettings()

--------------------------------------------------------------------------------

module.name = localization.system
module.margin = 3
module.onTouch = function()
	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.systemArchitecture))

	local CPUComboBox = window.contentLayout:addChild(GUI.comboBox(1, 1, 36, 3, 0xE1E1E1, 0x696969, 0xD2D2D2, 0xA5A5A5))
	local architectures, architecture = computer.getArchitectures(), computer.getArchitecture()
	for i = 1, #architectures do
		CPUComboBox:addItem(architectures[i]).onTouch = function()
			computer.setArchitecture(architectures[i])
			computer.shutdown(true)
		end

		if architecture == architectures[i] then
			CPUComboBox.selectedItem = i
		end
	end

	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.systemRAM))

	local RAMComboBox = window.contentLayout:addChild(GUI.comboBox(1, 1, 36, 3, 0xE1E1E1, 0x696969, 0xD2D2D2, 0xA5A5A5))
	RAMComboBox.dropDownMenu.itemHeight = 1

	local function update()
		local libraries = {}
		for key, value in pairs(package.loaded) do
			if _G[key] ~= value then
				table.insert(libraries, key)
			end
		end
		
		table.sort(libraries, function(a, b) return unicode.lower(a) < unicode.lower(b) end)

		RAMComboBox:clear()
		for i = 1, #libraries do
			RAMComboBox:addItem(libraries[i])
		end

		workspace:draw()
	end

	window.contentLayout:addChild(GUI.button(1, 1, 36, 3, 0xE1E1E1, 0x696969, 0x696969, 0xE1E1E1, localization.systemUnload)).onTouch = function()
		package.loaded[RAMComboBox:getItem(RAMComboBox.selectedItem).text] = nil
		update()
	end

	window.contentLayout:addChild(GUI.button(1, 1, 36, 3, 0xE1E1E1, 0x696969, 0x696969, 0xE1E1E1, localization.systemUnloadAll or "Unload All Libraries")).onTouch = function()
		local count = 0
		for key, value in pairs(package.loaded) do
			if _G[key] ~= value then
				package.loaded[key] = nil
				count = count + 1
			end
		end
		update()
		local message = GUI.messageBox(workspace, localization.success or "Success", string.format(localization.unloadedCount or "Unloaded %d libraries", count), localization.ok or "OK", nil, "info")
		message:show()
	end

	local switch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.systemUnloading .. ":", userSettings.packageUnloading)).switch
	switch.onStateChanged = function()
		userSettings.packageUnloading = switch.state
		system.setPackageUnloading(userSettings.packageUnloading)
		system.saveUserSettings()
	end

	window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {localization.systemInfo}, 1, 0, 0, true, true))
	
	window.contentLayout:addChild(GUI.object(1, 1, 1, 1))
	
	window.contentLayout:addChild(GUI.button(1, 1, 36, 3, 0xFF4940, 0xFFFFFF, 0xCC2440, 0xE1E1E1, localization.uninstall or "Uninstall PixelOS")).onTouch = function()
		local container = GUI.addBackgroundContainer(workspace, true, true, localization.uninstall or "Uninstall PixelOS")
		container.layout:addChild(GUI.label(1, 1, container.layout.width, 1, 0x2D2D2D, localization.uninstallConfirm or "Are you sure you want to uninstall PixelOS?")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
		
		local buttonContainer = container.layout:addChild(GUI.layout(1, 1, container.layout.width, 3, 1, 1))
		buttonContainer:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
		buttonContainer:setSpacing(1, 1, 3)
		
		buttonContainer:addChild(GUI.button(1, 1, 15, 3, 0xE1E1E1, 0x696969, 0xC3C3C3, 0x2D2D2D, localization.cancel or "Cancel")).onTouch = function()
			container:remove()
			workspace:draw()
		end
		
		buttonContainer:addChild(GUI.button(1, 1, 15, 3, 0xFF4940, 0xFFFFFF, 0xCC2440, 0xE1E1E1, localization.ok or "OK")).onTouch = function()
			container:remove()
			
			local uninstallContainer = GUI.addBackgroundContainer(workspace, true, false, localization.uninstall or "Uninstall PixelOS")
			uninstallContainer.layout:addChild(GUI.label(1, 1, uninstallContainer.layout.width, 1, 0x2D2D2D, localization.uninstalling or "Uninstalling PixelOS...")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
			workspace:draw()
			
			local filesystem = require("Filesystem")
			local paths = require("Paths")
			
			local function removeDirectory(path)
				if filesystem.exists(path) then
					if filesystem.isDirectory(path) then
						for file in filesystem.list(path) do
							removeDirectory(path .. file)
						end
					end
					filesystem.remove(path)
				end
			end
			
			removeDirectory(paths.system)
			
			uninstallContainer:remove()
			
			local successContainer = GUI.addBackgroundContainer(workspace, true, true, localization.success or "Success")
			successContainer.layout:addChild(GUI.label(1, 1, successContainer.layout.width, 1, 0x2D2D2D, localization.uninstallSuccess or "PixelOS has been uninstalled successfully!")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
			successContainer.layout:addChild(GUI.button(1, 1, 15, 3, 0xE1E1E1, 0x696969, 0xC3C3C3, 0x2D2D2D, localization.ok or "OK")).onTouch = function()
				successContainer:remove()
				workspace:draw()
				computer.shutdown(true)
			end
			workspace:draw()
		end
		workspace:draw()
	end

	update()

	workspace:draw()
end

--------------------------------------------------------------------------------

return module

