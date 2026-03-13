
local GUI = require("GUI")
local screen = require("Screen")
local component = require("Component")
local filesystem = require("Filesystem")
local system = require("System")

local module = {}

local workspace, window, localization = table.unpack({...})
local userSettings = system.getUserSettings()

--------------------------------------------------------------------------------

module.name = localization.security or "安全"
module.margin = 3

module.onTouch = function()
	-- BIOS Manager Section
	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.biosManager or "BIOS 管理器"))
	
	-- Get current BIOS info
	local eeprom = component.list("eeprom")()
	local biosInfo = "未知"
	local isBiosManager = false
	
	if eeprom then
		local success, data = pcall(component.invoke, eeprom, "getLabel")
		if success and data then
			biosInfo = data
			isBiosManager = (data == "PixelOS Bios Manager")
		end
	end
	
	local biosLabel = window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {localization.currentBios or "当前 BIOS: " .. biosInfo}, 1, 0, 0, true, true))
	
	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.biosManagerDesc or "启用后将安装 PixelOS BIOS 管理器，提供更友好的启动界面"))
	
	-- BIOS Manager Switch
	local biosManagerSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.enableBiosManager or "启用 BIOS 管理器:", isBiosManager)).switch
	
	biosManagerSwitch.onStateChanged = function()
		local confirmMessage = GUI.messageBox(
			workspace,
			biosManagerSwitch.state and (localization.confirmEnable or "确认启用") or (localization.confirmDisable or "确认禁用"),
			biosManagerSwitch.state and (localization.enableBiosManagerConfirm or "启用后将刷入 PixelOS BIOS 管理器，需要重启才能生效。确定继续？") or (localization.disableBiosManagerConfirm or "禁用后将恢复原始 BIOS，需要重启才能生效。确定继续？"),
			localization.confirm or "确认",
			localization.cancel or "取消",
			"question"
		)
		
		confirmMessage:show()
		
		if confirmMessage.canceled then
			biosManagerSwitch.state = not biosManagerSwitch.state
			workspace:draw()
			return
		end
		
		-- Flash BIOS
		local flashContainer = GUI.addBackgroundContainer(workspace, true, false, localization.flashingBios or "刷写 BIOS...")
		flashContainer.layout:addChild(GUI.label(1, 1, flashContainer.layout.width, 1, 0x2D2D2D, biosManagerSwitch.state and (localization.installingBiosManager or "正在安装 BIOS 管理器...") or (localization.restoringBios or "正在恢复原始 BIOS..."))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
		workspace:draw()
		
		local internet = component.list("internet")()
		if not internet then
			local errorMessage = GUI.messageBox(workspace, localization.error or "错误", localization.noInternet or "未找到互联网组件", localization.ok or "确定", nil, "error")
			errorMessage:show()
			flashContainer:remove()
			biosManagerSwitch.state = not biosManagerSwitch.state
			workspace:draw()
			return
		end
		
		local success, result = pcall(function()
			local biosURL = biosManagerSwitch.state and "EFI/BootManager.lua" or "EFI/BIOS.lua"
			local handle = component.invoke(internet, "request", "https://gitee.com/zip132sy/pixelos/raw/master/" .. biosURL)
			if not handle then
				handle = component.invoke(internet, "request", "https://raw.githubusercontent.com/zip132sy/pixelos/master/" .. biosURL)
			end
			
			if handle then
				local biosData = ""
				while true do
					local chunk = handle.read(math.huge)
					if not chunk then break end
					biosData = biosData .. chunk
				end
				handle:close()
				
				component.invoke(eeprom, "set", biosData)
				component.invoke(eeprom, "setLabel", biosManagerSwitch.state and "PixelOS Bios Manager" or "PixelOS Install Bios")
				component.invoke(eeprom, "setData", filesystem.getProxy().address)
			end
		end)
		
		flashContainer:remove()
		
		if success then
			local message = GUI.messageBox(
				workspace,
				localization.success or "成功",
				biosManagerSwitch.state and (localization.biosManagerInstalled or "BIOS 管理器已安装，请重启系统") or (localization.biosRestored or "原始 BIOS 已恢复，请重启系统"),
				localization.ok or "确定",
				nil,
				"info"
			)
			message:show()
			
			-- Save to user settings
			userSettings.biosManagerEnabled = biosManagerSwitch.state
			system.saveUserSettings()
		else
			local message = GUI.messageBox(
				workspace,
				localization.error or "错误",
				localization.biosFlashFailed or "BIOS 刷写失败：" .. tostring(result),
				localization.ok or "确定",
				nil,
				"error"
			)
			message:show()
			
			biosManagerSwitch.state = not biosManagerSwitch.state
			workspace:draw()
		end
	end
	
	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.biosManagerNote or "注意：刷写 BIOS 后需要重启系统才能生效"))
	
	-- Add separator
	window.contentLayout:addChild(GUI.object(1, 1, 1, 2))
	window.contentLayout:addChild(GUI.line(1, 1, 36, 0xA5A5A5))
	window.contentLayout:addChild(GUI.object(1, 1, 1, 2))
	
	-- Encryption Section
	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.encryption or "加密"))
	window.contentLayout:addChild(GUI.textBox(1, 1, 36, 2, nil, 0xA5A5A5, {localization.encryptionDesc or "加密功能正在开发中...", localization.encryptionNote or "此功能将在未来版本中推出"}, 1, 0, 0, true, true))
end

return module
