local GUI = require("GUI")
local screen = require("Screen")
local system = require("System")
local filesystem = require("Filesystem")
local internet = require("Internet")
local VideoLibrary = require("VideoLibrary")
local text = require("Text")

local localization = system.getLocalization()

local window = GUI.addBackgroundContainer(workspace, true, true)
window.width, window.height = 80, 30
window.x, window.y = math.floor(screen.getWidth() / 2 - window.width / 2), math.floor(screen.getHeight() / 2 - window.height / 2)

local title = window:addChild(GUI.text(1, 2, 0xFFFFFF, localization.videoPlayer))
title.width = window.width

local videoPlayer = VideoLibrary.createPlayer(76, 18)

local videoDisplay = window:addChild(GUI.object(2, 4, 76, 18))
videoDisplay.player = videoPlayer

videoDisplay.draw = function()
	local currentFrame = VideoLibrary.getCurrentFrame(videoPlayer)
	
	if currentFrame then
		local halfX = videoDisplay.x + videoDisplay.width / 2
		local halfY = videoDisplay.y + videoDisplay.height / 2
		
		VideoLibrary.render(videoPlayer, screen, halfX, halfY)
	else
		screen.drawText(
			math.floor(videoDisplay.x + videoDisplay.width / 2 - unicode.len(localization.noVideo) / 2),
			math.floor(videoDisplay.y + videoDisplay.height / 2),
			0x888888,
			localization.noVideo
		)
	end
	
	local info = VideoLibrary.getInfo(videoPlayer)
	if info.totalFrames > 0 then
		local frameInfo = string.format("%s: %d/%d | %s: %d", 
			localization.currentFrame, 
			info.currentFrame, 
			info.totalFrames,
			localization.fps,
			info.fps
		)
		screen.drawText(videoDisplay.x, videoDisplay.y + videoDisplay.height + 1, 0xFFFFFF, frameInfo)
	end
end

local controlPanel = window:addChild(GUI.panel(2, window.height - 6, 76, 5, 0x2D2D2D, 0.9))

local playButton = controlPanel:addChild(GUI.button(2, 2, 8, 3, 0x00FF00, 0xFFFFFF, 0x00AA00, 0xFFFFFF, localization.play))
playButton.onTouch = function()
	if VideoLibrary.getTotalFrames(videoPlayer) > 0 then
		VideoLibrary.play(videoPlayer)
		playButton.text = localization.pause
	else
		GUI.alert(localization.noVideo)
	end
end

local pauseButton = controlPanel:addChild(GUI.button(12, 2, 8, 3, 0xFFFF00, 0xFFFFFF, 0xAAAA00, 0xFFFFFF, localization.pause))
pauseButton.onTouch = function()
	VideoLibrary.pause(videoPlayer)
	playButton.text = localization.play
end

local stopButton = controlPanel:addChild(GUI.button(22, 2, 8, 3, 0xFF0000, 0xFFFFFF, 0xAA0000, 0xFFFFFF, localization.stop))
stopButton.onTouch = function()
	VideoLibrary.stop(videoPlayer)
	playButton.text = localization.play
	workspace:draw()
end

local prevFrameButton = controlPanel:addChild(GUI.button(32, 2, 10, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.previousFrame))
prevFrameButton.onTouch = function()
	VideoLibrary.previousFrame(videoPlayer)
	workspace:draw()
end

local nextFrameButton = controlPanel:addChild(GUI.button(44, 2, 10, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.nextFrame))
nextFrameButton.onTouch = function()
	VideoLibrary.nextFrame(videoPlayer)
	workspace:draw()
end

local speedSlider = controlPanel:addChild(GUI.slider(56, 2, 20, 0x66DB80, 0x0, 0xFFFFFF, 0xFFFFFF, 1, 60, 10, true, localization.fps))
speedSlider.roundValues = true
speedSlider.onValueChanged = function()
	VideoLibrary.setFPS(videoPlayer, speedSlider.value)
end

local openButton = window:addChild(GUI.button(2, window.height - 10, 15, 3, 0x2D2D2D, 0xFFFFFF, 0x555555, 0xFFFFFF, localization.openVideo))
openButton.onTouch = function()
	local container = GUI.addBackgroundContainer(workspace, true, true, localization.openVideo)
	container.panel.eventHandler = nil
	container.layout:setSpacing(1, 1, 2)
	
	local pathInput = container.layout:addChild(GUI.input(1, 1, 40, 0x1E1E1E, 0xFFFFFF, 0x000000, "Path"))
	pathInput.placeholder = "C:\\Path\\To\\Video\\"
	
	local buttonsLay = container.layout:addChild(GUI.layout(1, 1, 40, 3, 1, 1))
	
	buttonsLay:addChild(GUI.button(1, 1, 18, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.openVideo)).onTouch = function()
		local success, result = VideoLibrary.loadFrames(videoPlayer, pathInput.text)
		if success then
			container:remove()
			workspace:draw()
		else
			GUI.alert(result)
		end
	end
	
	buttonsLay:addChild(GUI.button(20, 1, 18, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.cancel)).onTouch = function()
		container:remove()
	end
	
	workspace:draw()
end

local downloadButton = window:addChild(GUI.button(19, window.height - 10, 15, 3, 0x00FF00, 0xFFFFFF, 0x00AA00, 0xFFFFFF, localization.downloadVideo))
downloadButton.onTouch = function()
	downloadVideo()
end

local closeButton = window:addChild(GUI.button(window.width - 18, window.height - 10, 16, 3, 0xFF5555, 0xFFFFFF, 0xAA5555, 0xFFFFFF, localization.close))
closeButton.onTouch = function()
	VideoLibrary.stop(videoPlayer)
	window:remove()
	workspace:draw()
end

local function downloadVideo()
	local container = GUI.addBackgroundContainer(workspace, true, true, localization.downloadVideo)
	container.panel.eventHandler = nil
	container.layout:setSpacing(1, 1, 2)
	
	local urlInput = container.layout:addChild(GUI.input(1, 1, 50, 0x1E1E1E, 0xFFFFFF, 0x000000, localization.url))
	urlInput.placeholder = "https://example.com/video/"
	
	local pathInput = container.layout:addChild(GUI.input(1, 1, 50, 0x1E1E1E, 0xFFFFFF, 0x000000, "Path"))
	pathInput.placeholder = "C:\\Path\\To\\Save\\Video\\"
	
	local statusText = container.layout:addChild(GUI.text(1, 1, 0xBBBBBB, ""))
	
	local buttonsLay = container.layout:addChild(GUI.layout(1, 1, 50, 3, 1, 1))
	
	buttonsLay:addChild(GUI.button(1, 1, 23, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.downloadVideo)).onTouch = function()
		local url = urlInput.text
		local savePath = pathInput.text
		
		if url == "" or savePath == "" then
			GUI.alert("Please fill all fields")
			return
		end
		
		statusText.text = localization.downloading .. "..."
		
		local success, result = pcall(function()
			local frameCount, frames = VideoLibrary.downloadVideo(url, savePath, {
				onProgress = function(frame, framePath)
					statusText.text = localization.downloading .. ": " .. frame
					workspace:draw()
				end,
				onComplete = function(totalFrames, downloadedFrames)
					statusText.text = "Downloaded " .. totalFrames .. " frames"
					VideoLibrary.loadFrames(videoPlayer, savePath)
					workspace:draw()
				end
			})
			
			return frameCount
		end)
		
		if not success then
			statusText.text = localization.downloadFailed .. ": " .. result
		end
		
		workspace:draw()
	end
	
	buttonsLay:addChild(GUI.button(25, 1, 23, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.cancel)).onTouch = function()
		container:remove()
	end
	
	workspace:draw()
end

window.eventHandler = function(window, object, e1, e2, e3, e4, e5)
	if e1 == "timer" then
		if VideoLibrary.update(videoPlayer) then
			workspace:draw()
		end
	end
end

workspace:draw()
