local GUI = require("GUI")
local screen = require("Screen")
local system = require("System")
local paths = require("Paths")
local filesystem = require("Filesystem")
local internet = require("Internet")
local text = require("Text")
local color = require("Color")

local currentScriptDirectory = filesystem.path(system.getCurrentScript())
local localization = system.getLocalization()

local repoURL = "https://gitee.com/zip132sy/pixelos/raw/master/"
local localPath = "c:\\Users\\Administrator\\Documents\\pixelos-update\\PixelOS\\"

local window = GUI.addBackgroundContainer(workspace, true, true)
window.width, window.height = 60, 25
window.x, window.y = math.floor(screen.getWidth() / 2 - window.width / 2), math.floor(screen.getHeight() / 2 - window.height / 2)
window.panel.localX = true
window.panel.localY = true

local title = window:addChild(GUI.text(1, 2, 0xFFFFFF, localization.updates))
title.width = window.width

local statusText = window:addChild(GUI.text(2, 4, 0xBBBBBB, localization.downloading))
statusText.width = window.width - 4

local fileList = window:addChild(GUI.object(2, 6, window.width - 4, 15))
fileList.draw = function()
	local y = 0
	for i, file in ipairs(fileList.files) do
		local statusColor = 0x00FF00
		local statusText = ""
		
		if file.status == "added" then
			statusColor = 0x00FF00
			statusText = "[+]"
		elseif file.status == "modified" then
			statusColor = 0xFFFF00
			statusText = "[~]"
		elseif file.status == "deleted" then
			statusColor = 0xFF0000
			statusText = "[-]"
		end
		
		screen.drawText(fileList.x + 1, fileList.y + y + 1, statusColor, statusText)
		screen.drawText(fileList.x + 5, fileList.y + y + 1, 0xFFFFFF, text.limit(file.name, fileList.width - 10, "…"))
		screen.drawText(fileList.x + fileList.width - 4, fileList.y + y + 1, 0x888888, file.status)
		
		y = y + 1
	end
end

fileList.eventHandler = function(workspace, object, e1, e2, e3, e4)
	if e1 == "touch" then
		local y = e3 - fileList.y - 1
		if y >= 0 and y < #fileList.files then
			local file = fileList.files[y + 1]
			GUI.alert(file.name .. "\n" .. localization.path .. ": " .. file.path .. "\n" .. localization.status .. ": " .. file.status)
		end
	end
end

local updateButton = window:addChild(GUI.button(2, window.height - 3, 16, 3, 0x2D2D2D, 0xFFFFFF, 0xAAAAAA, 0xFFFFFF, localization.update))
updateButton.onTouch = function()
	statusText.text = localization.uploading .. "..."
	
	local success, result = system.updateFromRepo(repoURL, localPath)
	
	if success then
		statusText.text = localization.success
		GUI.alert(localization.settingsSaved)
	else
		statusText.text = localization.operationFailed
		GUI.alert(result)
	end
	
	workspace:draw()
end

local closeButton = window:addChild(GUI.button(window.width - 18, window.height - 3, 16, 3, 0xFF5555, 0xFFFFFF, 0xAAAAAA, 0xFFFFFF, localization.close))
closeButton.onTouch = function()
	window:remove()
	workspace:draw()
end

local function compareFiles()
	statusText.text = localization.updatingFileList .. "..."
	workspace:draw()
	
	fileList.files = {}
	
	local localFiles = filesystem.list(localPath, true)
	
	for i, file in ipairs(localFiles) do
		if not file.isDirectory then
			local repoFileURL = repoURL .. file.name
			local status = "unknown"
			
			fileList.files[#fileList.files + 1] = {
				name = file.name,
				path = file.path,
				status = status,
				url = repoFileURL
			}
		end
	end
	
	table.sort(fileList.files, function(a, b) return a.name < b.name end)
	
	statusText.text = string.format(localization.uploadingSuccess, #fileList.files)
	workspace:draw()
end

compareFiles()

workspace:draw()
