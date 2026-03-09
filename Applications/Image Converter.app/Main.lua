local GUI = require("GUI")
local screen = require("Screen")
local system = require("System")
local paths = require("Paths")
local filesystem = require("Filesystem")
local internet = require("Internet")
local image = require("Image")
local text = require("Text")
local color = require("Color")

local currentScriptDirectory = filesystem.path(system.getCurrentScript())
local localization = system.getLocalization()

local originalRepoURL = "https://gitee.com/zip132sy/pixelos/raw/master/"
local localPath = "c:\\Users\\Administrator\\Documents\\pixelos-update\\PixelOS\\"

local window = GUI.addBackgroundContainer(workspace, true, true)
window.width, window.height = 60, 30
window.x, window.y = math.floor(screen.getWidth() / 2 - window.width / 2), math.floor(screen.getHeight() / 2 - window.height / 2)
window.panel.localX = true
window.panel.localY = true

local title = window:addChild(GUI.text(1, 2, 0xFFFFFF, localization.imageConverter))
title.width = window.width

local inputMode = window:addChild(GUI.object(2, 4, 28, 3))
inputMode.selected = 1
inputMode.values = {"OCIF to JSON", "JSON to OCIF"}
inputMode.draw = function()
	local y = 0
	for i, value in ipairs(inputMode.values) do
		local textColor = 0x888888
		if i == inputMode.selected then
			textColor = 0xFFFFFF
		end
		
		screen.drawText(inputMode.x + 1, inputMode.y + y + 1, textColor, value)
		y = y + 1
	end
end

local sourcePath = window:addChild(GUI.input(2, 8, 28, 0x1E1E1E, 0xFFFFFF, 0x000000, localization.sourcePath .. ":"))
sourcePath.placeholder = "C:\\Path\\To\\Source.pic"

local targetPath = window:addChild(GUI.input(2, 11, 28, 0x1E1E1E, 0xFFFFFF, 0x000000, localization.targetPath .. ":"))
targetPath.placeholder = "C:\\Path\\To\\Target.pic"

local convertButton = window:addChild(GUI.button(2, window.height - 4, 28, 3, 0x2D2D2D, 0xFFFFFF, 0xAAAAAA, 0xFFFFFF, localization.convert))
convertButton.onTouch = function()
	local sourceFile = sourcePath.text
	local targetFile = targetPath.text
	
	if sourceFile == "" or targetFile == "" then
		GUI.alert(localization.file .. " " .. localization.notExists)
		return
	end
	
	if not filesystem.exists(sourceFile) then
		GUI.alert(localization.file .. " " .. sourceFile .. " " .. localization.notExists)
		return
	end
	
	local success, result = pcall(function()
		if inputMode.selected == 1 then
			return convertOCIFToJSON(sourceFile, targetFile)
		else
			return convertJSONToOCIF(sourceFile, targetFile)
		end
	end)
	
	if success then
		GUI.alert(localization.success)
	else
		GUI.alert(localization.operationFailed .. "\n" .. result)
	end
	
	workspace:draw()
end

local function convertOCIFToJSON(sourcePath, targetPath)
	local img = image.load(sourcePath)
	if not img then
		return false, "Failed to load source image"
	end
	
	local data = {}
	data.width = img.width
	data.height = img.height
	
	if type(img.data) == "table" then
		data.data = img.data
	else
		data.data = {}
		for y = 1, img.height do
			local row = {}
			for x = 1, img.width do
				local pixel = img.data[(y - 1) * img.width + x] or 0x000000
				row[x] = pixel
			end
			data.data[y] = row
		end
	end

	local file = io.open(targetPath, "w")
	if file then
		file:write(text.serialize(data))
		file:close()
		return true
	else
		return false, "Failed to create target file"
	end
end

local function convertJSONToOCIF(sourcePath, targetPath)
	local file = io.open(sourcePath, "r")
	if not file then
		return false, "Failed to open source file"
	end
	
	local content = file:read("*all")
	file:close()
	
	local success, data = pcall(text.unserialize, content)
	if not success or not data then
		return false, "Failed to parse source file"
	end
	
	if not data.width or not data.height or not data.data then
		return false, "Invalid JSON format"
	end
	
	local imgData = {}
	if type(data.data) == "table" then
		imgData = data.data
	else
		imgData = {}
		for y = 1, data.height do
			local row = {}
			for x = 1, data.width do
				local pixel = data.data[(y - 1) * data.width + x] or 0x000000
				row[x] = pixel
			end
			imgData[y] = row
		end
	end

	local img = image.create(data.width, data.height, imgData)
	if not img then
		return false, "Failed to create image"
	end
	
	local success = image.save(targetPath, img)
	if success then
		return true
	else
		return false, "Failed to save target image"
	end
end

local downloadButton = window:addChild(GUI.button(32, window.height - 4, 16, 3, 0x00FF00, 0xFFFFFF, 0xAAAAAA, 0xFFFFFF, localization.download))
downloadButton.onTouch = function()
	downloadIcons()
end

local closeButton = window:addChild(GUI.button(window.width - 18, window.height - 4, 16, 3, 0xFF5555, 0xFFFFFF, 0xAAAAAA, 0xFFFFFF, localization.close))
closeButton.onTouch = function()
	window:remove()
	workspace:draw()
end

local function downloadIcons()
	local statusText = window:addChild(GUI.text(2, 14, 0xBBBBBB, localization.downloading .. "..."))
	
	local success, result = pcall(function()
		local icons = {
			{path = "Applications/3D Print.app/Icon.pic", name = "3D Print"},
			{path = "Applications/3D Test.app/Icon.pic", name = "3D Test"},
			{path = "Applications/BiosTool.app/Icon.pic", name = "BiosTool"},
			{path = "Applications/Calculator.app/Icon.pic", name = "Calculator"},
			{path = "Applications/Calendar.app/Icon.pic", name = "Calendar"},
			{path = "Applications/Control.app/Icon.pic", name = "Control"},
			{path = "Applications/DiskUtility.app/Icon.pic", name = "DiskUtility"},
			{path = "Applications/ErrorReporter.app/Icon.pic", name = "ErrorReporter"},
			{path = "Applications/Finder.app/Icon.pic", name = "Finder"},
			{path = "Applications/Graph.app/Icon.pic", name = "Graph"},
			{path = "Applications/HEX.app/Icon.pic", name = "HEX"},
			{path = "Applications/HoloClock.app/Icon.pic", name = "HoloClock"},
			{path = "Applications/IC2Reactors.app/Icon.pic", name = "IC2Reactors"},
			{path = "Applications/IRC.app/Icon.pic", name = "IRC"},
			{path = "Applications/Lua.app/Icon.pic", name = "Lua"},
			{path = "Applications/MineCode IDE.app/Icon.pic", name = "MineCode IDE"},
			{path = "Applications/Multiscreen.app/Icon.pic", name = "Multiscreen"},
			{path = "Applications/Nanomachines.app/Icon.pic", name = "Nanomachines"},
			{path = "Applications/Palette.app/Icon.pic", name = "Palette"},
			{path = "Applications/Picture Edit.app/Icon.pic", name = "Picture Edit"},
			{path = "Applications/Picture View.app/Icon.pic", name = "Picture View"},
			{path = "Applications/Pioneer.app/Icon.pic", name = "Pioneer"},
			{path = "Applications/Print Image.app/Icon.pic", name = "Print Image"},
			{path = "Applications/RayWalk.app/Icon.pic", name = "RayWalk"},
			{path = "Applications/Reinstall OS.app/Icon.pic", name = "Reinstall OS"},
			{path = "Applications/Running String.app/Icon.pic", name = "Running String"},
			{path = "Applications/Sample.app/Icon.pic", name = "Sample"},
			{path = "Applications/Settings.app/Icon.pic", name = "Settings"},
			{path = "Applications/System Update.app/Icon.pic", name = "System Update"},
			{path = "Applications/Image Converter.app/Icon.pic", name = "Image Converter"}
		}
	
		for i, icon in ipairs(icons) do
			local url = originalRepoURL .. icon.path
			local localPath = localPath .. "PixelOS\\" .. icon.path
			
			local success, result = internet.request(url, "GET")
			if success and result.code == 200 then
				local dir = filesystem.path(localPath)
				if not filesystem.exists(dir) then
					filesystem.makeDirectory(dir)
				end
				
				local file = io.open(localPath, "w")
				if file then
					file:write(result.data)
					file:close()
				end
			end
		end
		
		statusText.text = string.format(localization.uploadingSuccess, #icons)
	end)
	
	if not success then
		statusText.text = localization.operationFailed .. ": " .. result
	end
	
	workspace:draw()
end

workspace:draw()
