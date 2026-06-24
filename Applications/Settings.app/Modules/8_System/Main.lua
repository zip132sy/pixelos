local GUI = require("GUI")
local paths = require("Paths")
local system = require("System")
local filesystem = require("Filesystem")
local component = require("Component")
local computer = require("Computer")
local screen = require("Screen")
local image = require("Image")
local text = require("Text")

local module = {}

local workspace, window, localization = table.unpack({...})
local userSettings = system.getUserSettings()

--------------------------------------------------------------------------------

local function formatSize(bytes)
	if bytes < 1024 then
		return bytes .. " B"
	elseif bytes < 1048576 then
		return string.format("%.1f KB", bytes / 1024)
	else
		return string.format("%.1f MB", bytes / 1048576)
	end
end

local function parseFilePathFromURL(url)
	local patterns = {
		"raw/master/(.+)",
		"raw/main/(.+)",
		"blob/master/(.+)",
		"blob/main/(.+)",
		"master/(.+)",
		"main/(.+)",
	}
	
	for _, pattern in ipairs(patterns) do
		local path = url:match(pattern)
		if path then
			return path
		end
	end
	
	local filename = url:match("/([^/]+)$")
	if filename then
		return filename
	end
	
	return nil
end

local function showPasswordDialog(callback)
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 40
	local height = 9
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, localization.devToolsPasswordTitle or "开发者工具"))
	
	local input = dialogWorkspace:addChild(GUI.input(x + 2, 4, width - 4, 1, 0x2D2D2D, 0xE1E1E1, 0xA5A5A5, 0x2D2D2D, 0xE1E1E1, "", localization.devToolsPasswordPlaceholder or "输入密码", true, "*"))
	
	local errorLabel = dialogWorkspace:addChild(GUI.label(x + 2, 5, width - 4, 1, 0xCC0000, ""))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "取消"))
	local confirmButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, localization.apply or "确定"))
	
	cancelButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
		if callback then callback(false) end
	end
	
	confirmButton.onTouch = function()
		if input.text == "4321" then
			dialogWorkspace:stop()
			screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
			screen.update()
			if callback then callback(true) end
		else
			errorLabel.text = localization.devToolsWrongPassword or "密码错误"
			input.text = ""
			input.colors.default.text = 0xCC0000
			dialogWorkspace:draw()
			computer.pullSignal(1)
			errorLabel.text = ""
			input.colors.default.text = 0xE1E1E1
			dialogWorkspace:draw()
		end
	end
	
	dialogWorkspace.eventHandler = function(ws, object, e1, e2, e3, e4, ...)
		if e1 == "key_down" and e4 == 28 then
			confirmButton:press(ws, object, e1, e2, e3, e4, ...)
		end
	end
	
	dialogWorkspace:draw()
	dialogWorkspace:start()
end

local function showPathDialog(url, filePath, callback)
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 50
	local height = 12
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dirPath = filesystem.path(filePath) or ""
	local fileName = filesystem.name(filePath) or ""
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, localization.devToolsSavePath or "保存位置"))
	
	dialogWorkspace:addChild(GUI.label(x + 2, 3, width - 4, 1, 0xA5A5A5, localization.devToolsFolder or "文件夹:"))
	local dirInput = dialogWorkspace:addChild(GUI.input(x + 2, 4, width - 4, 1, 0x2D2D2D, 0xE1E1E1, 0xA5A5A5, 0x2D2D2D, 0xE1E1E1, dirPath, "", false))
	
	dialogWorkspace:addChild(GUI.label(x + 2, 6, width - 4, 1, 0xA5A5A5, localization.devToolsFileName or "文件名:"))
	local fileInput = dialogWorkspace:addChild(GUI.input(x + 2, 7, width - 4, 1, 0x2D2D2D, 0xE1E1E1, 0xA5A5A5, 0x2D2D2D, 0xE1E1E1, fileName, "", false))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "取消"))
	local confirmButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, localization.apply or "确定"))
	
	cancelButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
	end
	
	confirmButton.onTouch = function()
		local newDir = dirInput.text or ""
		local newFile = fileInput.text or ""
		
		if newFile == "" then
			GUI.alert("请输入文件名")
			return
		end
		
		local newPath = newDir .. newFile
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
		if callback then callback(url, newPath) end
	end
	
	dialogWorkspace.eventHandler = function(ws, object, e1, e2, e3, e4, ...)
		if e1 == "key_down" and e4 == 28 then
			confirmButton:press(ws, object, e1, e2, e3, e4, ...)
		end
	end
	
	dialogWorkspace:draw()
	dialogWorkspace:start()
end

local function showURLDialog(callback)
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 50
	local height = 10
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, localization.devToolsDownloadTitle or "下载文件"))
	
	dialogWorkspace:addChild(GUI.label(x + 2, 3, width - 4, 1, 0xA5A5A5, localization.devToolsURLLabel or "文件URL:"))
	local input = dialogWorkspace:addChild(GUI.input(x + 2, 4, width - 4, 1, 0x2D2D2D, 0xE1E1E1, 0xA5A5A5, 0x2D2D2D, 0xE1E1E1, "", "https://gitee.com/zip132sy/pixelos/raw/master/...", false))
	
	dialogWorkspace:addChild(GUI.label(x + 2, 6, width - 4, 1, 0xA5A5A5, localization.devToolsPathLabel or "解析路径:"))
	local pathText = dialogWorkspace:addChild(GUI.label(x + 2, 7, width - 4, 1, 0x66B6FF, ""))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "取消"))
	local downloadButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, localization.devToolsDownload or "下载"))
	
	local function updatePathPreview()
		local url = input.text
		if url and #url > 0 then
			local filePath = parseFilePathFromURL(url)
			if filePath then
				pathText.text = filePath
				pathText.colors.text = 0x66B6FF
			else
				pathText.text = "无法解析路径"
				pathText.colors.text = 0xCC0000
			end
		else
			pathText.text = ""
		end
		dialogWorkspace:draw()
	end
	
	input.onInputFinished = updatePathPreview
	
	cancelButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
		if callback then callback() end
	end
	
	downloadButton.onTouch = function()
		local url = input.text
		if url and #url > 0 then
			local filePath = parseFilePathFromURL(url)
			if filePath then
				dialogWorkspace:stop()
				screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
				screen.update()
				showPathDialog(url, filePath, showDownloadProgress)
			else
				GUI.alert("无效的URL")
			end
		else
			GUI.alert("请输入URL")
		end
	end
	
	dialogWorkspace:draw()
	dialogWorkspace:start()
end

local function showDownloadProgress(url, filePath)
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 50
	local height = 10
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, "正在下载..."))
	
	local displayPath = filePath
	if #displayPath > 40 then
		displayPath = "..." .. displayPath:sub(#displayPath - 37)
	end
	dialogWorkspace:addChild(GUI.label(x + 2, 3, width - 4, 1, 0xA5A5A5, displayPath))
	
	local progressBar = dialogWorkspace:addChild(GUI.progressBar(x + 2, 5, width - 4, 0x66B6FF, 0x2D2D2D, 0x2D2D2D, 0, true, true, "", ""))
	
	local statusText = dialogWorkspace:addChild(GUI.label(x + 2, 7, width - 4, 1, 0x878787, "0 B"))
	local speedText = dialogWorkspace:addChild(GUI.label(x + 2, 8, width - 4, 1, 0x878787, ""))
	
	dialogWorkspace:draw()
	
	local internet = component.get("internet")
	if not internet then
		dialogWorkspace:stop()
		GUI.alert("需要互联网卡")
		return
	end
	
	local pcallSuccess, requestHandle = pcall(internet.request, url)
	if not pcallSuccess or not requestHandle then
		dialogWorkspace:stop()
		GUI.alert("连接失败")
		return
	end
	
	local fileSize = 0
	local responseCode = requestHandle:finish()
	if responseCode and responseCode >= 200 and responseCode < 300 then
		local headers = requestHandle:responseHeaders()
		if headers and headers["Content-Length"] then
			fileSize = tonumber(headers["Content-Length"]) or 0
		end
	end
	
	local fullPath = paths.system.root .. filePath
	filesystem.makeDirectory(filesystem.path(fullPath) or "")
	
	local fileHandle, reason = filesystem.open(fullPath, "w")
	if not fileHandle then
		dialogWorkspace:stop()
		GUI.alert("无法打开文件: " .. tostring(reason))
		return
	end
	
	local totalBytes = 0
	local startTime = computer.uptime()
	local success = false
	local errorReason = nil
	
	pcallSuccess, requestHandle = pcall(internet.request, url)
	if pcallSuccess and requestHandle then
		while true do
			local chunk, reason = requestHandle:read(8192)
			
			if chunk then
				fileHandle:write(chunk)
				totalBytes = totalBytes + #chunk
				
				local elapsed = computer.uptime() - startTime
				if elapsed > 0 then
					local speed = math.floor(totalBytes / elapsed)
					local speedStr = formatSize(speed) .. "/s"
					
					statusText.text = formatSize(totalBytes) .. (fileSize > 0 and " / " .. formatSize(fileSize) or "")
					speedText.text = speedStr
					
					if fileSize > 0 then
						progressBar.value = math.floor(totalBytes / fileSize * 100)
					end
					
					dialogWorkspace:draw()
				end
			else
				requestHandle:close()
				
				if reason then
					errorReason = reason
				else
					success = true
				end
				break
			end
		end
	else
		errorReason = "Connection failed"
	end
	
	fileHandle:close()
	dialogWorkspace:stop()
	
	if success then
		showRestartDialog()
	else
		filesystem.remove(fullPath)
		GUI.alert("下载失败: " .. tostring(errorReason))
	end
end

local function showBIOSFlashDialog()
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 50
	local height = 10
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, "刷写BIOS"))
	
	dialogWorkspace:addChild(GUI.label(x + 2, 3, width - 4, 1, 0xA5A5A5, "BIOS URL:"))
	local input = dialogWorkspace:addChild(GUI.input(x + 2, 4, width - 4, 1, 0x2D2D2D, 0xE1E1E1, 0xA5A5A5, 0x2D2D2D, 0xE1E1E1, "", "https://gitee.com/zip132sy/pixelos/raw/master/EFI/BIOS.lua", false))
	
	dialogWorkspace:addChild(GUI.label(x + 2, 6, width - 4, 1, 0xA5A5A5, "解析文件名:"))
	local nameText = dialogWorkspace:addChild(GUI.label(x + 2, 7, width - 4, 1, 0x66B6FF, ""))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "取消"))
	local flashButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, "刷写"))
	
	local function updateNamePreview()
		local url = input.text
		if url and #url > 0 then
			local filename = url:match("/([^/]+)$")
			if filename then
				nameText.text = filename
				nameText.colors.text = 0x66B6FF
			else
				nameText.text = "无法解析"
				nameText.colors.text = 0xCC0000
			end
		else
			nameText.text = ""
		end
		dialogWorkspace:draw()
	end
	
	input.onInputFinished = updateNamePreview
	
	cancelButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
	end
	
	flashButton.onTouch = function()
		local url = input.text
		if url and #url > 0 then
			local filename = url:match("/([^/]+)$")
			if filename then
				dialogWorkspace:stop()
				screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
				screen.update()
				flashBIOS(url)
			else
				GUI.alert("无效的URL")
			end
		else
			GUI.alert("请输入URL")
		end
	end
	
	dialogWorkspace:draw()
	dialogWorkspace:start()
end

local function flashBIOS(url)
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 50
	local height = 10
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, "正在刷写BIOS..."))
	
	local progressBar = dialogWorkspace:addChild(GUI.progressBar(x + 2, 4, width - 4, 0x66B6FF, 0x2D2D2D, 0x2D2D2D, 0, true, true, "", ""))
	local statusText = dialogWorkspace:addChild(GUI.label(x + 2, 6, width - 4, 1, 0x878787, "下载中..."))
	
	dialogWorkspace:draw()
	
	local internet = component.get("internet")
	if not internet then
		dialogWorkspace:stop()
		GUI.alert("需要互联网卡")
		return
	end
	
	local pcallSuccess, requestHandle = pcall(internet.request, url)
	if not pcallSuccess or not requestHandle then
		dialogWorkspace:stop()
		GUI.alert("连接失败")
		return
	end
	
	local data = ""
	while true do
		local chunk, reason = requestHandle:read(8192)
		if chunk then
			data = data .. chunk
			progressBar.value = math.min(90, math.floor(#data / 4096 * 90))
			statusText.text = "下载中: " .. #data .. " B"
			dialogWorkspace:draw()
		else
			requestHandle:close()
			if reason then
				dialogWorkspace:stop()
				GUI.alert("下载失败: " .. tostring(reason))
				return
			end
			break
		end
	end
	
	if #data > 4096 then
		dialogWorkspace:stop()
		GUI.alert("BIOS文件超过4KB限制: " .. #data .. " B")
		return
	end
	
	local eeprom = component.get("eeprom")
	if not eeprom then
		dialogWorkspace:stop()
		GUI.alert("找不到EEPROM组件")
		return
	end
	
	pcallSuccess, reason = pcall(eeprom.set, data)
	if not pcallSuccess then
		dialogWorkspace:stop()
		GUI.alert("刷写失败: " .. tostring(reason))
		return
	end
	
	progressBar.value = 100
	statusText.text = "Done!"
	dialogWorkspace:draw()
	computer.pullSignal(2)
	dialogWorkspace:stop()
	
	showRestartDialog()
end

local function showMainMenu()
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 36
	local height = 8
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, "开发者工具"))
	
	local downloadButton = dialogWorkspace:addChild(GUI.button(x + 2, 3, width - 4, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, "下载文件"))
	local biosButton = dialogWorkspace:addChild(GUI.button(x + 2, 5, width - 4, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, "刷写BIOS"))
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, width - 4, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "关闭"))
	
	downloadButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
		showURLDialog(function()
			showMainMenu()
		end)
	end
	
	biosButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
		showBIOSFlashDialog()
	end
	
	cancelButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
	end
	
	dialogWorkspace:draw()
	dialogWorkspace:start()
end

local function showRestartDialog()
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 40
	local height = 6
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.panel(x, 1, width, height, 0x2D2D2D))
	dialogWorkspace:addChild(GUI.label(x, 1, width, 1, 0x00AAFF, "操作完成"))
	
	dialogWorkspace:addChild(GUI.label(x + 2, 3, width - 4, 1, 0xE1E1E1, "需要重启以生效"))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "稍后"))
	local restartButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, "重启"))
	
	cancelButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
	end
	
	restartButton.onTouch = function()
		dialogWorkspace:stop()
		computer.shutdown(true)
	end
	
	dialogWorkspace:draw()
	dialogWorkspace:start()
end

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

	local switch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.systemUnloading .. ":", userSettings.packageUnloading)).switch
	switch.onStateChanged = function()
		userSettings.packageUnloading = switch.state
		system.setPackageUnloading(userSettings.packageUnloading)
		system.saveUserSettings()
	end

	window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {localization.systemInfo}, 1, 0, 0, true, true))

	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.devTools or "开发者工具"))
	
	local devToolsSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.devToolsEnabled .. ":", false)).switch
	devToolsSwitch.onStateChanged = function()
		if devToolsSwitch.state then
			showPasswordDialog(function(success)
				if success then
					showMainMenu()
				else
					devToolsSwitch.state = false
					workspace:draw()
				end
			end)
		end
	end

	window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {"从URL下载文件或刷写BIOS，无需重新安装"}, 1, 0, 0, true, true))

	update()

	workspace:draw()
end

--------------------------------------------------------------------------------

return module