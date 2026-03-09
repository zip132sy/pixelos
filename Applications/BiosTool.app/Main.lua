local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")
local component = component
local localization = require("Localization")

local application = {}
application.name = localization.AppBiosTool or "BIOS Tool"

local biosData = nil
local biosLabel = nil
local biosSize = 0
local statusText = "Ready"

local function readBIOS()
    local eeprom = component.list("eeprom")()
    if not eeprom then
        statusText = "Error: No EEPROM found"
        return false
    end

    biosData = component.invoke(eeprom, "get")
    biosLabel = component.invoke(eeprom, "getLabel") or "Unlabeled"
    biosSize = #biosData
    statusText = "BIOS read successfully (" .. biosSize .. " bytes)"
    return true
end

local function saveToFile()
    if not biosData then
        statusText = "Error: No BIOS data"
        return false
    end

    local filename = "BIOS_backup_" .. os.time() .. ".lua"
    local handle = filesystem.open(filename, "w")
    if handle then
        filesystem.write(handle, biosData)
        filesystem.close(handle)
        statusText = "Saved to " .. filename
        return true
    end
    statusText = "Error: Failed to save"
    return false
end

local function setLabel(newLabel)
    local eeprom = component.list("eeprom")()
    if not eeprom then
        statusText = "Error: No EEPROM"
        return false
    end

    component.invoke(eeprom, "setLabel", newLabel)
    biosLabel = newLabel
    statusText = "Label updated"
    return true
end

function application.main()
    -- Try to read BIOS on start
    readBIOS()

    local workspace = system.getWorkspace()
    local windowWidth, windowHeight = 50, 25
    local windowX = math.floor((workspace.width - windowWidth) / 2)
    local windowY = math.floor((workspace.height - windowHeight) / 2)

    local window = GUI.window(windowX, windowY, windowWidth, windowHeight)
    window.title = "BIOS Tool"

    -- Info labels
    local y = windowY + 4

    local labelLabel = GUI.label(windowX + 2, y, 20, 1, "BIOS Label:")
    window:addChild(labelLabel)

    local labelValue = GUI.label(windowX + 15, y, 30, 1, biosLabel or "Unknown")
    labelValue.colors.text = 0x3366CC
    window:addChild(labelValue)

    y = y + 2

    local sizeLabel = GUI.label(windowX + 2, y, 20, 1, "Size:")
    window:addChild(sizeLabel)

    local sizeValue = GUI.label(windowX + 15, y, 30, 1, tostring(biosSize) .. " bytes")
    sizeValue.colors.text = 0x3366CC
    window:addChild(sizeValue)

    y = y + 2

    local eeprom = component.list("eeprom")()
    if eeprom then
        local totalSize = component.invoke(eeprom, "getSize")
        local dataSize = component.invoke(eeprom, "getDataSize")

        window:addChild(GUI.label(windowX + 2, y, 20, 1, "EEPROM Total:"))
        window:addChild(GUI.label(windowX + 15, y, 30, 1, totalSize .. " bytes"))
        y = y + 2

        window:addChild(GUI.label(windowX + 2, y, 20, 1, "Data Storage:"))
        window:addChild(GUI.label(windowX + 15, y, 30, 1, dataSize .. " bytes"))
        y = y + 2
    end

    -- Buttons
    local btnY = windowY + 14

    local readBtn = GUI.button(windowX + 2, btnY, 12, 3, "Read BIOS")
    readBtn.onTouch = function()
        readBIOS()
        labelValue.text = biosLabel or "Unknown"
        sizeValue.text = tostring(biosSize) .. " bytes"
    end
    window:addChild(readBtn)

    local saveBtn = GUI.button(windowX + 16, btnY, 12, 3, "Save to File")
    saveBtn.onTouch = function()
        saveToFile()
    end
    window:addChild(saveBtn)

    local labelBtn = GUI.button(windowX + 30, btnY, 14, 3, "Set Label")
    labelBtn.onTouch = function()
        -- Would show input dialog
        if biosLabel then
            setLabel(biosLabel)
        end
    end
    window:addChild(labelBtn)

    -- Status
    local statusLabel = GUI.label(windowX + 2, windowY + windowHeight - 6, windowWidth - 4, 1, statusText)
    statusLabel.colors.text = 0x666666
    window:addChild(statusLabel)

    -- Close button
    local closeBtn = GUI.button(windowX + windowWidth - 10, windowY + windowHeight - 3, 8, 3, "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    workspace:addChild(window)

    -- Update status periodically
    window.eventHandler = function(self, ...)
        statusLabel.text = statusText
        return false
    end

    return window
end

return application
