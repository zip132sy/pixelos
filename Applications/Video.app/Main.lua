-- Video Player Application for PixelOS
-- A simple video player using VideoLibrary

local GUI = require("GUI")
local screen = require("Screen")
local system = require("System")
local filesystem = require("Filesystem")

-- Load localization
local localization = system.getLocalization()

-- Create main window
local window = GUI.addBackgroundContainer(workspace, true, true, localization.videoPlayer or "Video Player")
window.panel.color = 0x2D2D2D
window.panel.alpha = 0.9

-- Title
local title = window.layout:addChild(GUI.text(1, 1, 0xFFFFFF, localization.videoPlayer or "Video Player"))
title:setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

-- Video display area
local videoDisplay = window.layout:addChild(GUI.object(1, 1, 76, 18))
videoDisplay.player = nil
videoDisplay.currentFrame = nil

videoDisplay.draw = function()
    screen.drawText(
        math.floor(videoDisplay.x + videoDisplay.width / 2 - 10),
        math.floor(videoDisplay.y + videoDisplay.height / 2),
        0x888888,
        localization.noVideo or "No video loaded"
    )
end

-- Control panel
local controlPanel = window.layout:addChild(GUI.panel(1, 1, 76, 5, 0x1E1E1E))
controlPanel:setDirection(GUI.DIRECTION_HORIZONTAL)
controlPanel:setSpacing(2, 0)

-- Open button
local openButton = controlPanel:addChild(GUI.button(1, 1, 15, 3, 0x3498DB, 0xFFFFFF, 0x2980B9, 0xFFFFFF, localization.open or "Open"))
openButton.onTouch = function()
    local container = GUI.addBackgroundContainer(workspace, true, true, localization.openVideo or "Open Video")
    container.panel.eventHandler = nil
    
    local pathLabel = container.layout:addChild(GUI.text(1, 1, 0xFFFFFF, localization.path or "Path:"))
    local pathInput = container.layout:addChild(GUI.input(1, 1, 50, 0x1E1E1E, 0xFFFFFF, 0x000000, "/path/to/video/"))
    
    local buttonsLayout = container.layout:addChild(GUI.layout(1, 1, 50, 3, 2, 1))
    
    buttonsLayout:addChild(GUI.button(1, 1, 23, 3, 0x27AE60, 0xFFFFFF, 0x229954, 0xFFFFFF, localization.ok or "OK")).onTouch = function()
        local path = pathInput.text
        if filesystem.exists(path) then
            videoDisplay.player = path
            videoDisplay.currentFrame = 1
            container:remove()
            workspace:draw()
        else
            GUI.alert(localization.fileNotFound or "File not found: " .. path)
        end
    end
    
    buttonsLayout:addChild(GUI.button(2, 1, 23, 3, 0xE74C3C, 0xFFFFFF, 0xC0392B, 0xFFFFFF, localization.cancel or "Cancel")).onTouch = function()
        container:remove()
    end
    
    workspace:draw()
end

-- Play button
local playButton = controlPanel:addChild(GUI.button(1, 1, 10, 3, 0x27AE60, 0xFFFFFF, 0x229954, 0xFFFFFF, localization.play or "Play"))
playButton.onTouch = function()
    if videoDisplay.player then
        GUI.info(localization.playing or "Playing video...")
    else
        GUI.alert(localization.noVideo or "No video loaded")
    end
end

-- Pause button
local pauseButton = controlPanel:addChild(GUI.button(1, 1, 10, 3, 0xF39C12, 0xFFFFFF, 0xD68910, 0xFFFFFF, localization.pause or "Pause"))
pauseButton.onTouch = function()
    if videoDisplay.player then
        GUI.info(localization.paused or "Video paused")
    else
        GUI.alert(localization.noVideo or "No video loaded")
    end
end

-- Stop button
local stopButton = controlPanel:addChild(GUI.button(1, 1, 10, 3, 0xE74C3C, 0xFFFFFF, 0xC0392B, 0xFFFFFF, localization.stop or "Stop"))
stopButton.onTouch = function()
    videoDisplay.player = nil
    videoDisplay.currentFrame = nil
    workspace:draw()
end

-- Info label
local infoLabel = window.layout:addChild(GUI.text(1, 1, 0xBBBBBB, ""))

-- Timer for video playback
local timer = event.timer(0.1, function()
    if videoDisplay.player then
        if videoDisplay.currentFrame then
            videoDisplay.currentFrame = videoDisplay.currentFrame + 1
            infoLabel.text = string.format("Frame: %d", videoDisplay.currentFrame)
            workspace:draw()
        end
    end
end)

workspace:draw()
