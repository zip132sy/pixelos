local GUI = require("GUI")
local screen = require("Screen")
local system = require("System")
local filesystem = require("Filesystem")
local internet = require("Internet")
local text = require("Text")

local localization = system.getLocalization()

local window = GUI.addBackgroundContainer(workspace, true, true)
window.width, window.height = 100, 35
window.x, window.y = math.floor(screen.getWidth() / 2 - window.width / 2), math.floor(screen.getHeight() / 2 - window.height / 2)

local title = window:addChild(GUI.text(1, 2, 0xFFFFFF, localization.webBrowser))
title.width = window.width

local urlBar = window:addChild(GUI.input(2, 4, window.width - 4, 0x1E1E1E, 0xFFFFFF, 0x000000, localization.url))
urlBar.placeholder = "https://example.com"

local contentArea = window:addChild(GUI.object(2, 6, window.width - 4, window.height - 12))
contentArea.content = ""
contentArea.scrollPosition = 1
contentArea.visibleLines = window.height - 12
contentArea.currentWordIndex = 1
contentArea.words = {}
contentArea.isReading = false
contentArea.readingSpeed = 3
contentArea.lastReadTime = 0

contentArea.draw = function()
	if contentArea.content == "" then
		screen.drawText(
			contentArea.x + 2,
			contentArea.y + 2,
			0x888888,
			"Enter a URL to start browsing"
		)
	else
		local lines = text.wrap(contentArea.content, contentArea.width - 4)
		local displayLines = {}
		
		for i = contentArea.scrollPosition, math.min(contentArea.scrollPosition + contentArea.visibleLines - 1, #lines) do
			table.insert(displayLines, lines[i])
		end
		
		for i, line in ipairs(displayLines) do
			local textColor = 0xFFFFFF
			if contentArea.isReading then
				local wordStart = 1
				for j, word in ipairs(contentArea.words) do
					local wordEnd = wordStart + unicode.len(word) - 1
					if j == contentArea.currentWordIndex then
						textColor = 0x00FF00
					elseif j < contentArea.currentWordIndex then
						textColor = 0x888888
					end
					
					if wordEnd <= unicode.len(line) then
						screen.drawText(
							contentArea.x + 2 + wordStart - 1,
							contentArea.y + i,
							textColor,
							string.sub(line, wordStart, wordEnd)
						)
						wordStart = wordEnd + 1
					end
				end
			else
				screen.drawText(
					contentArea.x + 2,
					contentArea.y + i,
					textColor,
					line
				)
			end
		end
		
		local scrollInfo = string.format("Line %d/%d", 
			contentArea.scrollPosition, 
			#lines
		)
		screen.drawText(
			contentArea.x + contentArea.width - unicode.len(scrollInfo) - 2,
			contentArea.y + contentArea.visibleLines,
			0x888888,
			scrollInfo
		)
		
		if contentArea.isReading then
			local readingInfo = string.format("%s %d/%d", 
				localization.reading, 
				contentArea.currentWordIndex, 
				#contentArea.words
			)
			screen.drawText(
				contentArea.x + 2,
				contentArea.y + contentArea.visibleLines + 1,
				0x00FF00,
				readingInfo
			)
		end
	end
end

local controlPanel = window:addChild(GUI.panel(2, window.height - 5, window.width - 4, 4, 0x2D2D2D, 0.9))

local goButton = controlPanel:addChild(GUI.button(2, 2, 8, 3, 0x00FF00, 0xFFFFFF, 0x00AA00, 0xFFFFFF, localization.go))
goButton.onTouch = function()
	loadPage(urlBar.text)
end

local backButton = controlPanel:addChild(GUI.button(12, 2, 8, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.back))
backButton.onTouch = function()
	if #history > 0 and historyPosition > 1 then
		historyPosition = historyPosition - 1
		urlBar.text = history[historyPosition]
		loadPage(urlBar.text)
	end
end

local reloadButton = controlPanel:addChild(GUI.button(22, 2, 8, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.reload))
reloadButton.onTouch = function()
	if urlBar.text ~= "" then
		loadPage(urlBar.text)
	end
end

local scrollUpButton = controlPanel:addChild(GUI.button(32, 2, 12, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.scrollUp))
scrollUpButton.onTouch = function()
	if contentArea.scrollPosition > 1 then
		contentArea.scrollPosition = contentArea.scrollPosition - 1
		workspace:draw()
	end
end

local scrollDownButton = controlPanel:addChild(GUI.button(46, 2, 12, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.scrollDown))
scrollDownButton.onTouch = function()
	local lines = text.wrap(contentArea.content, contentArea.width - 4)
	if contentArea.scrollPosition < #lines - contentArea.visibleLines + 1 then
		contentArea.scrollPosition = contentArea.scrollPosition + 1
		workspace:draw()
	end
end

local readAloudButton = controlPanel:addChild(GUI.button(60, 2, 12, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.readAloud))
readAloudButton.onTouch = function()
	if contentArea.isReading then
		stopReading()
	else
		startReading()
	end
end

local bookmarkButton = controlPanel:addChild(GUI.button(74, 2, 12, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.bookmarks))
bookmarkButton.onTouch = function()
	showBookmarks()
end

local closeButton = window:addChild(GUI.button(window.width - 18, window.height - 5, 16, 3, 0xFF5555, 0xFFFFFF, 0xAA5555, 0xFFFFFF, localization.close))
closeButton.onTouch = function()
	stopReading()
	window:remove()
	workspace:draw()
end

local history = {}
local historyPosition = 0
local bookmarks = {}

local function loadBookmarks()
	local bookmarkFile = filesystem.path(system.getCurrentScript()) .. "bookmarks.txt"
	if filesystem.exists(bookmarkFile) then
		local file = io.open(bookmarkFile, "r")
		if file then
			local content = file:read("*all")
			file:close()
			for url in content:gmatch("[^\r\n]+") do
				if url ~= "" then
					table.insert(bookmarks, url)
				end
			end
		end
	end
end

local function saveBookmarks()
	local bookmarkFile = filesystem.path(system.getCurrentScript()) .. "bookmarks.txt"
	local content = table.concat(bookmarks, "\n")
	local file = io.open(bookmarkFile, "w")
	if file then
		file:write(content)
		file:close()
	end
end

local function showBookmarks()
	local container = GUI.addBackgroundContainer(workspace, true, true, localization.bookmarks)
	container.panel.eventHandler = nil
	container.layout:setSpacing(1, 1, 2)
	
	local bookmarkList = container.layout:addChild(GUI.object(1, 1, 50, 15))
	bookmarkList.selectedIndex = 0
	bookmarkList.items = bookmarks
	
	bookmarkList.draw = function()
		for i, bookmark in ipairs(bookmarks) do
			local textColor = 0xFFFFFF
			if i == bookmarkList.selectedIndex then
				textColor = 0x00FF00
			end
			
			local displayText = string.format("%d. %s", i, bookmark)
			if unicode.len(displayText) > 48 then
				displayText = text.limit(displayText, 48, "...")
			end
			
			screen.drawText(
				bookmarkList.x + 1,
				bookmarkList.y + i,
				textColor,
				displayText
			)
		end
		
		if #bookmarks == 0 then
			screen.drawText(
				bookmarkList.x + 1,
				bookmarkList.y + 1,
				0x888888,
				"No bookmarks"
			)
		end
	end
	
	bookmarkList.eventHandler = function(_, _, e1, e2, e3, e4, e5)
		if e1 == "touch" then
			local y = e3 - bookmarkList.y
			if y >= 1 and y <= #bookmarks then
				bookmarkList.selectedIndex = y
				workspace:draw()
			end
		elseif e1 == "double_touch" and bookmarkList.selectedIndex > 0 then
			container:remove()
			urlBar.text = bookmarks[bookmarkList.selectedIndex]
			loadPage(urlBar.text)
		end
	end
	
	local buttonsLay = container.layout:addChild(GUI.layout(1, 1, 50, 3, 1, 1))
	
	buttonsLay:addChild(GUI.button(1, 1, 15, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.open)).onTouch = function()
		if bookmarkList.selectedIndex > 0 then
			container:remove()
			urlBar.text = bookmarks[bookmarkList.selectedIndex]
			loadPage(urlBar.text)
		end
	end
	
	buttonsLay:addChild(GUI.button(17, 1, 15, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.remove)).onTouch = function()
		if bookmarkList.selectedIndex > 0 then
			table.remove(bookmarks, bookmarkList.selectedIndex)
			bookmarkList.selectedIndex = 0
			saveBookmarks()
			workspace:draw()
		end
	end
	
	buttonsLay:addChild(GUI.button(33, 1, 15, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.close)).onTouch = function()
		container:remove()
	end
	
	workspace:draw()
end

local function startReading()
	if contentArea.content == "" or #contentArea.content == 0 then
		GUI.alert("No content to read")
		return
	end
	
	contentArea.words = {}
	for word in contentArea.content:gmatch("%S+") do
		if word ~= "" then
			table.insert(contentArea.words, word)
		end
	end
	
	if #contentArea.words == 0 then
		GUI.alert("No words to read")
		return
	end
	
	contentArea.currentWordIndex = 1
	contentArea.isReading = true
	contentArea.lastReadTime = computer.uptime()
	readAloudButton.text = localization.stopReading
	
	workspace:draw()
end

local function stopReading()
	contentArea.isReading = false
	contentArea.currentWordIndex = 1
	readAloudButton.text = localization.readAloud
	
	workspace:draw()
end

local function loadPage(url)
	if url == "" then
		GUI.alert(localization.invalidURL)
		return
	end
	
	if not url:match("^https?://") and not url:match("^file://") then
		url = "https://" .. url
	end
	
	contentArea.content = localization.loading
	contentArea.scrollPosition = 1
	stopReading()
	workspace:draw()
	
	local success, result = pcall(function()
		local response = internet.request(url, "GET")
		
		if response and response.code == 200 then
			contentArea.content = result.data
			contentArea.scrollPosition = 1
			
			table.insert(history, url)
			historyPosition = #history
		else
			contentArea.content = localization.connectionFailed
		end
	end)
	
	if not success then
		contentArea.content = localization.error .. ": " .. result
	end
	
	workspace:draw()
end

window.eventHandler = function(window, object, e1, e2, e3, e4, e5)
	if e1 == "timer" and contentArea.isReading and #contentArea.words > 0 then
		local currentTime = computer.uptime()
		local wordDelay = 0.5 / contentArea.readingSpeed
		
		if currentTime - contentArea.lastReadTime >= wordDelay then
			contentArea.currentWordIndex = contentArea.currentWordIndex + 1
			
			if contentArea.currentWordIndex > #contentArea.words then
				contentArea.currentWordIndex = 1
			end
			
			contentArea.lastReadTime = currentTime
			
			local currentWord = contentArea.words[contentArea.currentWordIndex]
			if currentWord and unicode.len(currentWord) > 0 then
				local wordLength = math.min(unicode.len(currentWord), 10)
				local beepDuration = wordLength * 0.05
				computer.beep(800, beepDuration)
			end
			
			workspace:draw()
		end
	elseif e1 == "key_down" then
		if e4 == 200 then
			if contentArea.scrollPosition > 1 then
				contentArea.scrollPosition = contentArea.scrollPosition - 1
				workspace:draw()
			end
		elseif e4 == 208 then
			local lines = text.wrap(contentArea.content, contentArea.width - 4)
			if contentArea.scrollPosition < #lines - contentArea.visibleLines + 1 then
				contentArea.scrollPosition = contentArea.scrollPosition + 1
				workspace:draw()
			end
		elseif e4 == 28 then
			if #history > 0 and historyPosition > 1 then
				historyPosition = historyPosition - 1
				urlBar.text = history[historyPosition]
				loadPage(urlBar.text)
			end
		elseif e4 == 13 then
			loadPage(urlBar.text)
		elseif e4 == 32 then
			if contentArea.isReading then
				stopReading()
			else
				startReading()
			end
		end
	end
end

loadBookmarks()
workspace:draw()
