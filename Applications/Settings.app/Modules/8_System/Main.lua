
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

-- Helper function to format file size
local function formatSize(bytes)
	if bytes < 1024 then
		return bytes .. " B"
	elseif bytes < 1048576 then
		return string.format("%.1f KB", bytes / 1024)
	else
		return string.format("%.1f MB", bytes / 1048576)
	end
end

-- Helper function to parse URL and extract file path
-- Example: https://gitee.com/zip132sy/pixelos/raw/master/BIOS/Manager.lua -> BIOS/Manager.lua
local function parseFilePathFromURL(url)
	-- Try to extract path after "raw/master/" or similar patterns
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
	
	-- If no pattern matched, try to get the last part of URL as filename
	local filename = url:match("/([^/]+)$")
	if filename then
		return filename
	end
	
	return nil
end

-- Create a dialog for password input
local function showPasswordDialog(callback)
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 40
	local height = 8
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.frame(x, 1, width, height, 0x2D2D2D, 0xE1E1E1, localization.devToolsPasswordTitle or "开发者工具", true))
	
	local input = dialogWorkspace:addChild(GUI.input(x + 2, 4, width - 4, 1, 0x2D2D2D, 0xE1E1E1, 0xA5A5A5, 0x2D2D2D, 0xE1E1E1, "", localization.devToolsPasswordPlaceholder or "输入密码", true, "*"))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "取消"))
	local confirmButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, localization.apply or "确定"))
	
	cancelButton.onTouch = function()
		dialogWorkspace:stop()
		screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
		screen.update()
	end
	
	confirmButton.onTouch = function()
		if input.text == "4321" then
			dialogWorkspace:stop()
			screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
			screen.update()
			callback()
		else
			input.text = ""
			input.colors.default.text = 0xCC0000
			dialogWorkspace:draw()
			computer.pullSignal(0.5)
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

-- Create a dialog for URL input
local function showURLDialog()
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 50
	local height = 10
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.frame(x, 1, width, height, 0x2D2D2D, 0xE1E1E1, localization.devToolsDownloadTitle or "下载文件", true))
	
	dialogWorkspace:addChild(GUI.text(x + 2, 3, 0xA5A5A5, localization.devToolsURLLabel or "文件URL:"))
	local input = dialogWorkspace:addChild(GUI.input(x + 2, 4, width - 4, 1, 0x2D2D2D, 0xE1E1E1, 0xA5A5A5, 0x2D2D2D, 0xE1E1E1, "", "https://gitee.com/zip132sy/pixelos/raw/master/...", false))
	
	dialogWorkspace:addChild(GUI.text(x + 2, 6, 0xA5A5A5, localization.devToolsPathLabel or "保存路径:"))
	local pathText = dialogWorkspace:addChild(GUI.text(x + 2, 7, 0x66B6FF, ""))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "取消"))
	local downloadButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, localization.devToolsDownload or "下载"))
	
	-- Update path preview when input changes
	local function updatePathPreview()
		local url = input.text
		if url and #url > 0 then
			local filePath = parseFilePathFromURL(url)
			if filePath then
				pathText.text = filePath
			else
				pathText.text = localization.devToolsPathUnknown or "无法解析路径"
				pathText.color = 0xCC0000
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
	end
	
	downloadButton.onTouch = function()
		local url = input.text
		if url and #url > 0 then
			local filePath = parseFilePathFromURL(url)
			if filePath then
				dialogWorkspace:stop()
				screen.paste(dialogWorkspace.x, dialogWorkspace.y, oldPixels)
				screen.update()
				showDownloadProgress(url, filePath)
			else
				GUI.alert(localization.devToolsInvalidURL or "无效的URL")
			end
		else
			GUI.alert(localization.devToolsEmptyURL or "请输入URL")
		end
	end
	
	dialogWorkspace:draw()
	dialogWorkspace:start()
end

-- Show download progress dialog
local function showDownloadProgress(url, filePath)
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 50
	local height = 10
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.frame(x, 1, width, height, 0x2D2D2D, 0xE1E1E1, localization.devToolsDownloading or "正在下载...", true))
	
	-- Display path
	local displayPath = filePath
	if #displayPath > 40 then
		displayPath = "..." .. displayPath:sub(#displayPath - 37)
	end
	dialogWorkspace:addChild(GUI.text(x + 2, 3, 0xA5A5A5, displayPath))
	
	-- Progress bar
	local progressBar = dialogWorkspace:addChild(GUI.progressBar(x + 2, 5, width - 4, 0x66B6FF, 0x2D2D2D, 0x2D2D2D, 0, true, true, "", ""))
	
	-- Status text (size and speed)
	local statusText = dialogWorkspace:addChild(GUI.text(x + 2, 7, 0x878787, "0 B"))
	local speedText = dialogWorkspace:addChild(GUI.text(x + 2, 8, 0x878787, ""))
	
	dialogWorkspace:draw()
	
	-- Start download
	local internet = component.get("internet")
	if not internet then
		dialogWorkspace:stop()
		GUI.alert(localization.devToolsNoInternet or "需要互联网卡")
		return
	end
	
	-- Get file size first
	local pcallSuccess, requestHandle = pcall(internet.request, url)
	if not pcallSuccess or not requestHandle then
		dialogWorkspace:stop()
		GUI.alert(localization.devToolsConnectionFailed or "连接失败")
		return
	end
	
	-- Read response headers to get file size
	local fileSize = 0
	local responseCode = requestHandle:finish()
	if responseCode and responseCode >= 200 and responseCode < 300 then
		-- Try to get content-length from headers
		local headers = requestHandle:responseHeaders()
		if headers and headers["Content-Length"] then
			fileSize = tonumber(headers["Content-Length"]) or 0
		end
	end
	
	-- Prepare file for writing
	local fullPath = paths.system.root .. filePath
	filesystem.makeDirectory(filesystem.path(fullPath) or "")
	
	local fileHandle, reason = filesystem.open(fullPath, "w")
	if not fileHandle then
		dialogWorkspace:stop()
		GUI.alert(localization.devToolsFileOpenFailed or "无法打开文件: " .. tostring(reason))
		return
	end
	
	-- Download with progress
	local totalBytes = 0
	local startTime = computer.uptime()
	local success = false
	local errorReason = nil
	
	-- Re-open connection for actual download
	pcallSuccess, requestHandle = pcall(internet.request, url)
	if pcallSuccess and requestHandle then
		while true do
			local chunk, reason = requestHandle:read(8192)
			
			if chunk then
				fileHandle:write(chunk)
				totalBytes = totalBytes + #chunk
				
				-- Update progress
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
		GUI.alert(localization.devToolsDownloadFailed or "下载失败: " .. tostring(errorReason))
	end
end

-- Show restart confirmation dialog
local function showRestartDialog()
	local bufferWidth, bufferHeight = screen.getResolution()
	local width = 40
	local height = 6
	local x = math.floor(bufferWidth / 2 - width / 2)
	local y = math.floor(bufferHeight / 2 - height / 2)
	
	local dialogWorkspace = GUI.workspace(1, y, bufferWidth, height + 2)
	local oldPixels = screen.copy(dialogWorkspace.x, dialogWorkspace.y, dialogWorkspace.width, dialogWorkspace.height)
	
	dialogWorkspace:addChild(GUI.panel(1, 1, dialogWorkspace.width, dialogWorkspace.height, 0x1D1D1D))
	dialogWorkspace:addChild(GUI.frame(x, 1, width, height, 0x2D2D2D, 0xE1E1E1, localization.devToolsSuccess or "下载完成", true))
	
	dialogWorkspace:addChild(GUI.text(x + 2, 3, 0xE1E1E1, localization.devToolsRestartPrompt or "文件已下载，需要重启以生效"))
	
	local cancelButton = dialogWorkspace:addChild(GUI.button(x + 2, height, 10, 1, 0xCC4940, 0xE1E1E1, 0x990000, 0xE1E1E1, localization.cancel or "稍后"))
	local restartButton = dialogWorkspace:addChild(GUI.button(x + width - 12, height, 10, 1, 0x3366CC, 0xE1E1E1, 0x3366CC, 0xE1E1E1, localization.devToolsRestart or "重启"))
	
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

	-- Developer Tools section
	window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.devTools or "开发者工具"))
	
	local devToolsSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, localization.devToolsEnabled .. ":", false)).switch
	devToolsSwitch.onStateChanged = function()
		if devToolsSwitch.state then
			-- Need password to enable
			showPasswordDialog(function()
				-- Password correct, show URL dialog
				showURLDialog()
			end)
			-- Reset switch state (user needs to enter password first)
			devToolsSwitch.state = false
			workspace:draw()
		end
	end

	window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {localization.devToolsInfo or "从URL下载单个文件到系统，无需重新安装"}, 1, 0, 0, true, true))

	update()

	workspace:draw()
end

--------------------------------------------------------------------------------

return module

