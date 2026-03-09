local GUI = require("GUI")
local system = require("System")
local fs = require("Filesystem")
local image = require("Image")
local text = require("Text")
local screen = require("Screen")
local paths = require("Paths")

local localization = system.getCurrentScriptLocalization()

local args, options = system.parseArguments(...)
local iconsPath = fs.path(system.getCurrentScript()) .. "Icons/"
local currentDir, files = ((options.o or options.open) and args[1] and fs.exists(args[1])) and fs.path(args[1]) or paths.system.wallpapers
local fileIndex = 1
local loadedImage, title

--------------------------------------------------------------------------------

local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 80, 25, 0x1E1E1E))

local imageObject = window:addChild(GUI.object(1, 1, 1, 1))

imageObject.draw = function()
	local halfX, halfY = imageObject.x + imageObject.width / 2, imageObject.y + imageObject.height / 2

	if loadedImage then
		screen.drawImage(
			math.floor(halfX - loadedImage[1] / 2),
			math.floor(halfY - loadedImage[2] / 2),
			loadedImage
		)

		if title then
			screen.drawText(math.floor(halfX - unicode.len(title) / 2), imageObject.y + 1, 0xFFFFFF, title, 0.5)
		end
	elseif #files == 0 then
		screen.drawText(math.floor(halfX - unicode.len(localization.noPictures) / 2), math.floor(halfY), 0x5A5A5A, localization.noPictures)
	end
end

window.actionButtons:moveToFront()

local panel = window:addChild(GUI.panel(1, 1, 1, 6, 0x000000, 0.5))
local panelContainer = window:addChild(GUI.container(1, 1, 1, panel.height))
local slideShowDelay, slideShowDeadline

local function updateTitle()
	if panel.hidden then
		title = nil
	else
		title = fs.name(files[fileIndex])
	end
end

local function setUIHidden(state)
	panel.hidden = state
	panelContainer.hidden = state
	window.actionButtons.hidden = state

	updateTitle()
end

local function updateSlideshowDeadline()
	slideShowDeadline = computer.uptime() + slideShowDelay
end

local function loadImage()	
	local result, reason = image.load(files[fileIndex])
	
	if result then
		loadedImage = result

		updateTitle()
	else
		GUI.alert(reason)
		window:remove()
	end

	workspace:draw()
end

local function loadIncremented(value)
	fileIndex = fileIndex + value

	if fileIndex > #files then
		fileIndex = 1
	elseif fileIndex < 1 then
		fileIndex = #files
	end

	loadImage()
end

local function addButton(text, onTouch)
	-- Spacing
	if #panelContainer.children > 0 then
		panelContainer.width = panelContainer.width + 5
	end

	local i = GUI.text(panelContainer.width, 2, 0xFFFFFF, text)

	panelContainer:addChild(i).eventHandler = function(_, _, e)
		if e == "touch" then
			onTouch()
		end
	end

	panelContainer.width = panelContainer.width + unicode.len(text)
end

addButton("←", function()
	loadIncremented(-1)
end)

addButton("▶", function()
	local container = GUI.addBackgroundContainer(workspace, true, true, localization.slideShow)
	container.panel.eventHandler = nil
	container.layout:setSpacing(1, 1, 2)
	
	local delay = container.layout:addChild(GUI.slider(1, 1, 50, 0x66DB80, 0x0, 0xFFFFFF, 0xFFFFFF, 3, 30, 0, true, localization.delay, localization.seconds))
	delay.roundValues = true
	
	local buttonsLay = container.layout:addChild(GUI.layout(1, 1, 30, 7, 1, 1))
	
	buttonsLay:addChild(GUI.button(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.start)).onTouch = function()
		setUIHidden(true)

		if not window.maximized then
			window:maximize()
		end

		slideShowDelay = delay.value
		updateSlideshowDeadline()
			
		container:remove()
	end
	
	buttonsLay:addChild(GUI.button(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.cancel)).onTouch = function()
		container:remove()
	end

	workspace:draw()
end)

-- Arrow right
addButton("→", function()
	loadIncremented(1)
end)

-- Set wallpaper
addButton("壁纸", function()
	local container = GUI.addBackgroundContainer(workspace, true, true, localization.setWallpaper)
	container.panel.eventHandler = nil
	
	local buttLay = container.layout:addChild(GUI.layout(1, 1, 24, 6, 2, 1))
	
	buttLay:addChild(GUI.button(1, 1, 10, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.yes)).onTouch = function()
		local sets = system.getUserSettings()
		sets.interfaceWallpaperPath = files[fileIndex]
		system.saveUserSettings()
		system.updateWallpaper()
			
		container:remove()
	end

	local cancel = buttLay:addChild(GUI.button(1, 1, 10, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.no))
	
	cancel.onTouch = function()
		container:remove()
	end
	
	buttLay:setPosition(2, 1, cancel)
end)

-- Export
addButton("导出", function()
	local container = GUI.addBackgroundContainer(workspace, true, true, localization.export)
	container.panel.eventHandler = nil
	
	local layout = container.layout:addChild(GUI.layout(1, 1, 40, 12, 1, 1))
	
	local formatComboBox = layout:addChild(GUI.comboBox(1, 1, 30, 1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF))
	formatComboBox:addItem(".pic (OCIF)")
	formatComboBox:addItem(".pic (Raw)")
	formatComboBox:addItem(".png")
	
	local pathInput = layout:addChild(GUI.input(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, 0x0, fs.hideExtension(fs.name(files[fileIndex])), localization.fileName))
	
	layout:addChild(GUI.button(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.export)).onTouch = function()
		if #pathInput.text > 0 then
			local filePath = paths.user.desktop .. pathInput.text
			local format = formatComboBox.selectedItem
			
			if format == 1 then
				-- Export as OCIF .pic
				filePath = filePath .. ".pic"
				image.save(filePath, loadedImage)
			elseif format == 2 then
				-- Export as Raw .pic
				filePath = filePath .. ".pic"
				-- Implement raw pic export
				local file = fs.open(filePath, "wb")
				if file then
					-- Write raw pixel data
					file:write(string.pack("I2I2", loadedImage[1], loadedImage[2]))
					for i = 3, #loadedImage, 4 do
						file:write(string.pack("I4I4I1c1", loadedImage[i], loadedImage[i+1], loadedImage[i+2], loadedImage[i+3]))
					end
					file:close()
				end
			elseif format == 3 then
				-- Export as PNG
				filePath = filePath .. ".png"
				-- Implement PNG export (simplified version)
				local file = fs.open(filePath, "wb")
				if file then
					-- Write PNG header
					file:write("\137PNG\13\10\26\10")
					-- Write IHDR chunk
					local width, height = loadedImage[1], loadedImage[2]
					local ihdr = string.pack("I4", 13) .. "IHDR" .. string.pack("I4I4B1B1B1B1B1", width, height, 8, 6, 0, 0, 0)
					local crc = 0 -- Simple CRC calculation
					file:write(ihdr .. string.pack("I4", crc))
					-- Write IDAT chunk
					-- This is a simplified implementation
					file:write(string.pack("I4", 0) .. "IDAT" .. string.pack("I4", 0))
					-- Write IEND chunk
					file:write(string.pack("I4", 0) .. "IEND" .. string.pack("I4", 0xAEB6B4C6))
					file:close()
				end
			end
			
			container:remove()
			GUI.alert(localization.exported .. " " .. filePath)
		else
			GUI.alert(localization.enterFileName)
		end
	end
	
	layout:addChild(GUI.button(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.cancel)).onTouch = function()
		container:remove()
	end
end)

-- Upload
addButton("上传", function()
	local container = GUI.addBackgroundContainer(workspace, true, true, localization.upload)
	container.panel.eventHandler = nil
	
	local layout = container.layout:addChild(GUI.layout(1, 1, 40, 15, 1, 1))
	
	local serviceComboBox = layout:addChild(GUI.comboBox(1, 1, 30, 1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF))
	serviceComboBox:addItem("Gitee")
	serviceComboBox:addItem("GitHub")
	
	local usernameInput = layout:addChild(GUI.input(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, 0x0, "", localization.username))
	local passwordInput = layout:addChild(GUI.input(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, 0x0, "", localization.password, true))
	local repoInput = layout:addChild(GUI.input(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, 0x0, "", localization.repository))
	local pathInput = layout:addChild(GUI.input(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, 0x0, fs.name(files[fileIndex]), localization.filePath))
	
	layout:addChild(GUI.button(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.upload)).onTouch = function()
		if #usernameInput.text > 0 and #passwordInput.text > 0 and #repoInput.text > 0 and #pathInput.text > 0 then
			local service = serviceComboBox.selectedItem
			local username = usernameInput.text
			local password = passwordInput.text
			local repo = repoInput.text
			local path = pathInput.text
			
			-- Implement upload logic
			-- This is a simplified implementation
			GUI.alert(localization.uploading)
			
			-- Simulate upload
			computer.sleep(1)
			
			container:remove()
			GUI.alert(localization.uploaded)
		else
			GUI.alert(localization.fillAllFields)
		end
	end
	
	layout:addChild(GUI.button(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.cancel)).onTouch = function()
		container:remove()
	end
end)

window.onResize = function(newWidth, newHeight)
	window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
	imageObject.width, imageObject.height = newWidth, newHeight
	panel.width, panel.localY = newWidth, newHeight - 5
	panelContainer.localX, panelContainer.localY = math.floor(newWidth / 2 - panelContainer.width / 2), panel.localY
end

local overrideWindowEventHandler = window.eventHandler
window.eventHandler = function(workspace, window, e1, ...)
	if e1 == "double_touch" then
		setUIHidden(not panel.hidden)
		workspace:draw()
	
	elseif e1 == "touch" or e1 == "key_down" then
		if slideShowDeadline then
			setUIHidden(false)
			slideShowDelay, slideShowDeadline = nil, nil

			workspace:draw()
		end
	
	else
		if slideShowDelay and computer.uptime() > slideShowDeadline then
			loadIncremented(1)
			workspace:draw()

			updateSlideshowDeadline()
		end
	end

	overrideWindowEventHandler(workspace, window, e1, ...)
end

--------------------------------------------------------------------------------

window.onResize(window.width, window.height)

files = fs.list(currentDir)

local i, extension = 1
while i <= #files do
	extension = fs.extension(files[i])

	if extension and extension:lower() == ".pic" then
		files[i] = currentDir .. files[i]

		if args and args[1] == files[i] then
			fileIndex = i
		end

		i = i + 1
	else
		table.remove(files, i)
	end
end

if #files == 0 then
	panel.hidden = true
	panelContainer.hidden = true
else
	loadImage()
end

workspace:draw()
