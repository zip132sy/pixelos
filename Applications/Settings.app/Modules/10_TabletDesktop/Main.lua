local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")

--------------------------------------------------------------------------------

local module = {}

local workspace, window, localization = table.unpack({...})
local userSettings = system.getUserSettings()

module.name = localization.tabletDesktop or "Tablet Desktop"
module.margin = 3

module.onTouch = function()
    window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, localization.tabletDesktop or "Tablet Desktop"))
    
    local currentTabletMode = userSettings.tabletMode or false
    local currentModeType = userSettings.tabletModeType or "auto"
    
    window.contentLayout:addChild(GUI.text(1, 1, 0x696969, "Configure tablet desktop mode settings"))
    
    window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, "Mode Type"))
    window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {"Select how to switch tablet mode"}, 1, 0, 0, true, true))
    
    local modeTypeLayout = window.contentLayout:addChild(GUI.layout(1, 1, 36, 1, 1, 1))
    modeTypeLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
    modeTypeLayout:setSpacing(1, 1, 2)
    
    local autoModeButton = modeTypeLayout:addChild(GUI.button(1, 1, 10, 3, 
        currentModeType == "auto" and 0x3366CC or 0xC3C3C3, 
        0xFFFFFF, 0x2255AA, 0xFFFFFF, "Auto"))
    
    local manualModeButton = modeTypeLayout:addChild(GUI.button(1, 1, 10, 3, 
        currentModeType == "manual" and 0x3366CC or 0xC3C3C3, 
        0xFFFFFF, 0x2255AA, 0xFFFFFF, "Manual"))
    
    autoModeButton.onTouch = function()
        currentModeType = "auto"
        userSettings.tabletModeType = "auto"
        system.saveUserSettings()
        autoModeButton.colors.pressed.background = 0x3366CC
        autoModeButton.colors.disabled.background = 0x3366CC
        manualModeButton.colors.pressed.background = 0xC3C3C3
        manualModeButton.colors.disabled.background = 0xC3C3C3
        workspace:draw()
    end
    
    manualModeButton.onTouch = function()
        currentModeType = "manual"
        userSettings.tabletModeType = "manual"
        system.saveUserSettings()
        manualModeButton.colors.pressed.background = 0x3366CC
        manualModeButton.colors.disabled.background = 0x3366CC
        autoModeButton.colors.pressed.background = 0xC3C3C3
        autoModeButton.colors.disabled.background = 0xC3C3C3
        workspace:draw()
    end
    
    if currentModeType == "auto" then
        autoModeButton.colors.pressed.background = 0x3366CC
        autoModeButton.colors.disabled.background = 0x3366CC
        manualModeButton.colors.pressed.background = 0xC3C3C3
        manualModeButton.colors.disabled.background = 0xC3C3C3
    else
        manualModeButton.colors.pressed.background = 0x3366CC
        manualModeButton.colors.disabled.background = 0x3366CC
        autoModeButton.colors.pressed.background = 0xC3C3C3
        autoModeButton.colors.disabled.background = 0xC3C3C3
    end
    
    window.contentLayout:addChild(GUI.object(1, 1, 1, 1))
    
    if currentModeType == "manual" then
        window.contentLayout:addChild(GUI.text(1, 1, 0x2D2D2D, "Enable Tablet Mode"))
        window.contentLayout:addChild(GUI.textBox(1, 1, 36, 1, nil, 0xA5A5A5, {"Manually enable or disable tablet desktop mode"}, 1, 0, 0, true, true))
        
        local tabletModeSwitch = window.contentLayout:addChild(GUI.switchAndLabel(1, 1, 36, 8, 
            0x66DB80, 0xE1E1E1, 0xFFFFFF, 0xA5A5A5, 
            "Tablet Mode:", currentTabletMode)).switch
        
        tabletModeSwitch.onStateChanged = function()
            userSettings.tabletMode = tabletModeSwitch.state
            system.saveUserSettings()
            
            local message = GUI.messageBox(
                workspace,
                "Success",
                tabletModeSwitch.state and "Tablet mode enabled, will take effect after reboot" or "Tablet mode disabled, will take effect after reboot",
                "OK",
                nil,
                "info"
            )
            message:show()
        end
    end
    
    window.contentLayout:addChild(GUI.object(1, 1, 1, 2))
    window.contentLayout:addChild(GUI.text(1, 1, 0x878787, "Note: Auto mode will automatically switch based on screen size"))
end

return module
