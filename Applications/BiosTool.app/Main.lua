local component = require("component")
local GUI = require("GUI")
local system = require("System")

local workspace = GUI.workspace()
workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, 0x1E1E1E))

local window = workspace:addChild(GUI.window(1, 1, 80, 24))
window:setPosition(3, 2)
window:addChild(GUI.panel(1, 1, window.width, window.height, 0xE1E1E1))
window:addChild(GUI.label(1, 1, window.width, 1, 0x2D2D2D, "Bios Tool"))

local layout = window:addChild(GUI.layout(1, 2, window.width, window.height - 2, 1, 1))

layout:addChild(GUI.label(1, 1, layout.width, 1, 0x696969, "Bios Tool - PixelOS"))
layout:addChild(GUI.object(1, 1, 1, 1))

local function flashBios()
    local eeprom = component.eeprom
    if eeprom then
        local biosCode = [[
            local component = require("component")
            local computer = require("computer")
            
            local function getComponentAddress(componentType)
                local iter = component.list(componentType)
                if type(iter) == "function" then
                    return iter()
                elseif type(iter) == "table" then
                    for _, addr in pairs(iter) do
                        if type(addr) == "string" then
                            return addr
                        end
                    end
                end
                return nil
            end
            
            local function displayMessage(message)
                local gpu = component.list("gpu")()
                if gpu then
                    gpu = component.proxy(gpu)
                    local screen = component.list("screen")()
                    if screen then
                        gpu.bind(screen, true)
                        local w, h = gpu.getResolution()
                        gpu.setBackground(0x000000)
                        gpu.setForeground(0xFFFFFF)
                        gpu.fill(1, 1, w, h, " ")
                        local x = math.floor(w / 2 - #message / 2)
                        local y = math.floor(h / 2)
                        gpu.set(x, y, message)
                    end
                end
                computer.beep(1000, 0.5)
            end
            
            local eepromAddr = getComponentAddress("eeprom")
            if eepromAddr then
                local eepromData = component.invoke(eepromAddr, "getData")
                if eepromData and type(eepromData) == "string" then
                    local bootFilesystemProxy = component.proxy(eepromData)
                    if bootFilesystemProxy then
                        local handle, reason = bootFilesystemProxy.open("/OS.lua", "r")
                        if handle then
                            local data, chunk = ""
                            while true do
                                chunk = bootFilesystemProxy.read(handle, math.huge)
                                if chunk then
                                    data = data .. chunk
                                else
                                    break
                                end
                            end
                            bootFilesystemProxy.close(handle)
                            
                            local result, err = load(data)
                            if result then
                                result()
                            else
                                displayMessage("Failed to load OS: " .. tostring(err))
                            end
                        else
                            displayMessage("Failed to open OS.lua: " .. tostring(reason))
                        end
                    else
                        displayMessage("Failed to get filesystem proxy")
                    end
                else
                    displayMessage("Invalid EEPROM data")
                end
            else
                displayMessage("No EEPROM found")
            end
        ]]
        
        local success, err = pcall(eeprom.set, biosCode)
        if success then
            GUI.alert("Bios flashed successfully!")
        else
            GUI.alert("Failed to flash bios: " .. tostring(err))
        end
    else
        GUI.alert("No EEPROM found")
    end
end

local flashButton = layout:addChild(GUI.button(1, 1, 30, 1, 0x3366CC, 0xFFFFFF, 0x2D4080, 0xFFFFFF, "Flash Bios"))
flashButton.onTouch = flashBios

local infoButton = layout:addChild(GUI.button(1, 1, 30, 1, 0x666666, 0xFFFFFF, 0x404040, 0xFFFFFF, "Info"))
infoButton.onTouch = function()
    GUI.alert("Bios Tool for PixelOS\n\nThis tool allows you to flash the bios with a custom bootloader.")
end

workspace:draw()
workspace:start()
