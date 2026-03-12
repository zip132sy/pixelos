
-- Video Player for PixelOS
local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")
local paths = require("Paths")

---------------------------------------------------------------------------------

local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 70, 25, 0x1E1E1E))
window.title = "Video Player"

-- Get localization table
local localization = system.getCurrentScriptLocalization()

-- Dark theme colors
local bgColor = 0x1E1E1E
local textColor = 0xE1E1E1
local accentColor = 0xFF9240

-- Create main layout
local mainLayout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))

-- Title
mainLayout:addChild(GUI.text(1, 1, textColor, localization.title or "视频播放器"))
mainLayout:addChild(GUI.text(1, 1, 0x696969, localization.subtitle or "播放视频文件"))

-- Video display area
local videoPanel = mainLayout:addChild(GUI.panel(1, 1, window.width - 2, 12, 0x000000))
videoPanel.y = 5

-- Video info
local videoInfo = mainLayout:addChild(GUI.textBox(1, 1, videoPanel.width, 3, nil, 0x2D2D2D, {
    localization.noVideo or "未播放视频",
    localization.selectVideo or "请选择一个视频文件"
}, 1, 0, 0, true, true))
videoInfo.y = videoPanel.y + videoPanel.height + 1

-- Controls layout
local controlsLayout = mainLayout:addChild(GUI.layout(1, 1, window.width, 5, 1, 3))
controlsLayout.y = videoInfo.y + videoInfo.height + 1

-- Open button
local openBtn = controlsLayout:addChild(GUI.button(1, 1, 15, 3, nil, accentColor, nil, 0xFFFFFF, localization.open or "打开"))
openBtn.onTouch = function()
    -- File picker would go here
    local pathsList = filesystem.list(paths.user)
    local videos = {}
    
    for _, file in ipairs(pathsList or {}) do
        if file:match("%.mp4$") or file:match("%.avi$") or file:match("%.mkv$") then
            table.insert(videos, file)
        end
    end
    
    if #videos > 0 then
        videoInfo.items = {
            localization.availableVideos or "可用视频:",
        }
        for i, video in ipairs(videos) do
            table.insert(videoInfo.items, "  " .. video)
            if i >= 5 then break end
        end
        workspace:draw()
    else
        videoInfo.items = {
            localization.noVideosFound or "未找到视频文件",
            localization.videoFormats or "支持的格式：.mp4, .avi, .mkv"
        }
        workspace:draw()
    end
end

-- Play button
local playBtn = controlsLayout:addChild(GUI.button(1, 1, 12, 3, nil, accentColor, nil, 0xFFFFFF, localization.play or "播放"))
playBtn.onTouch = function()
    GUI.alert(localization.notImplemented or "播放功能尚未实现")
end

-- Pause button
local pauseBtn = controlsLayout:addChild(GUI.button(1, 1, 12, 3, nil, accentColor, nil, 0xFFFFFF, localization.pause or "暂停"))
pauseBtn.onTouch = function()
    GUI.alert(localization.notImplemented or "暂停功能尚未实现")
end

-- Stop button
local stopBtn = controlsLayout:addChild(GUI.button(1, 1, 12, 3, nil, 0x696969, nil, 0xFFFFFF, localization.stop or "停止"))
stopBtn.onTouch = function()
    videoInfo.items = {
        localization.stopped or "已停止",
        localization.noVideo or "未播放视频"
    }
    workspace:draw()
end

-- Volume slider
local volumeLabel = controlsLayout:addChild(GUI.label(1, 1, 15, 1, textColor, localization.volume or "音量:"))
local volumeSlider = controlsLayout:addChild(GUI.slider(1, 1, 20, 1, 0x696969, 0x2D2D2D, 0xE1E1E1, 0xFFFFFF, 0xFF9240, 50, 1, 100, 50, "%d%%"))
volumeSlider.y = volumeLabel.y + 1

-- Close button
local closeBtn = controlsLayout:addChild(GUI.button(1, 1, 12, 3, nil, 0x696969, nil, 0xFFFFFF, localization.close or "关闭"))
closeBtn.onTouch = function()
    window:remove()
end

-- Window resize handler
window.onResize = function(newWidth, newHeight)
    window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
    mainLayout.width, mainLayout.height = newWidth, newHeight
    videoPanel.width = newWidth - 2
    videoInfo.width = newWidth - 2
end

-- Menu
local contextMenu = menu:addContextMenuItem(localization.file or "文件")
contextMenu:addItem(localization.open or "打开").onTouch = openBtn.onTouch
contextMenu:addSeparator()
contextMenu:addItem(localization.close or "关闭").onTouch = function()
    window:remove()
end

---------------------------------------------------------------------------------

workspace:draw()
