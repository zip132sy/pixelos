
-- BIOS Manager Tool for PixelOS
local GUI = require("GUI")
local system = require("System")
local component = require("Component")

---------------------------------------------------------------------------------

local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 60, 20, 0xE1E1E1))
window.title = "BIOS Manager"

-- Get localization table
local localization = system.getCurrentScriptLocalization()

-- Create layout
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))

-- Title
layout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.title or "BIOS 管理器"))
layout:addChild(GUI.text(1, 1, 0x696969, localization.description or "查看和管理系统 BIOS 信息"))

-- BIOS Information Section
layout:addChild(GUI.text(1, 1, 0x2D2D2D, ""))
layout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.biosInfo or "BIOS 信息:"))

-- Get EEPROM component
local eeprom = component.list("eeprom")()
local biosLabel = "未知"
local biosData = "不可用"

if eeprom then
    local success, label = pcall(component.invoke, eeprom, "getLabel")
    if success and label then
        biosLabel = label
    end
    
    local success, data = pcall(component.invoke, eeprom, "get")
    if success and data then
        biosData = string.format(localization.dataSize or "数据大小：%d 字节", #data)
    end
end

local labelDisplay = layout:addChild(GUI.textBox(1, 1, 40, 1, nil, 0xA5A5A5, {
    localization.currentLabel or "当前标签：" .. biosLabel,
    biosData
}, 1, 0, 0, true, true))

-- Actions Section
layout:addChild(GUI.text(1, 1, 0x2D2D2D, ""))
layout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.actions or "操作:"))

-- Refresh Button
local refreshBtn = layout:addChild(GUI.button(1, 1, 15, 3, nil, 0x2D2D2D, nil, 0xFFFFFF, localization.refresh or "刷新"))
refreshBtn.onTouch = function()
    local eeprom = component.list("eeprom")()
    if eeprom then
        local success, label = pcall(component.invoke, eeprom, "getLabel")
        if success and label then
            biosLabel = label
        end
        
        local success, data = pcall(component.invoke, eeprom, "get")
        if success and data then
            biosData = string.format(localization.dataSize or "数据大小：%d 字节", #data)
        end
    end
    
    labelDisplay.items = {
        localization.currentLabel or "当前标签：" .. biosLabel,
        biosData
    }
    
    workspace:draw()
end

-- Close Button
local closeBtn = layout:addChild(GUI.button(1, 1, 15, 3, nil, 0x696969, nil, 0xFFFFFF, localization.close or "关闭"))
closeBtn.onTouch = function()
    window:remove()
end

-- Window resize handler
window.onResize = function(newWidth, newHeight)
    window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
    layout.width, layout.height = newWidth, newHeight
end

---------------------------------------------------------------------------------

workspace:draw()
