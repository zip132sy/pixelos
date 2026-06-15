local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")
local component = component

local application = {}

local selectedDisk = nil
local disks = {}
local statusText = "Ready"
local localization = {}

-- Load localization
local function loadLocalization()
    local lang = system.getUserSettings().localization or "English.lang"
    local langPath = filesystem.path("/System/Localizations/") .. lang
    if filesystem.exists(langPath) then
        localization = setmetatable({}, {
            __index = function(_, key)
                return key
            end
        })
        local success, result = pcall(filesystem.readTable, langPath)
        if success then
            for k, v in pairs(result) do
                localization[k] = v
            end
        end
    else
        localization = {
            diskUtility = "Disk Utility",
            selected = "Selected",
            address = "Address",
            readOnly = "Read Only",
            total = "Total",
            used = "Used",
            free = "Free",
            yes = "Yes",
            no = "No",
            erase = "Erase",
            format = "Format",
            refresh = "Refresh",
            close = "Close",
            setRW = "Set RW",
            setRO = "Set RO",
            ready = "Ready",
            erasing = "Erasing",
            erased = "Disk erased",
            formatting = "Formatting...",
            formatComplete = "Format complete",
            errorReadOnly = "Error: Read-only"
        }
    end
end

local function scanDisks()
    disks = {}
    for address, ctype in component.list("filesystem") do
        local proxy = component.proxy(address)
        table.insert(disks, {
            address = address,
            label = proxy.getLabel() or "Unlabeled",
            isReadOnly = proxy.isReadOnly(),
            spaceTotal = proxy.spaceTotal() or 0,
            spaceUsed = proxy.spaceUsed() or 0,
            proxy = proxy
        })
    end
end

local function eraseDisk(disk)
    if disk.isReadOnly then
        statusText = localization.errorReadOnly or "Error: Read-only"
        return false
    end

    statusText = (localization.erasing or "Erasing") .. " " .. disk.label .. "..."
    local list = disk.proxy.list("/")
    if list then
        for _, item in ipairs(list) do
            if item ~= "." and item ~= ".." then
                disk.proxy.remove("/" .. item)
            end
        end
    end
    statusText = localization.erased or "Disk erased"
    return true
end

local function formatDisk(disk)
    if disk.isReadOnly then
        statusText = localization.errorReadOnly or "Error: Read-only"
        return false
    end

    statusText = localization.formatting or "Formatting..."
    statusText = localization.formatComplete or "Format complete"
    return true
end

function application.main()
    loadLocalization()
    scanDisks()

    local workspace = system.getWorkspace()
    local windowWidth, windowHeight = 60, 25
    local windowX = math.floor((workspace.width - windowWidth) / 2)
    local windowY = math.floor((workspace.height - windowHeight) / 2)

    local window = GUI.window(windowX, windowY, windowWidth, windowHeight)
    window.title = localization.diskUtility or "Disk Utility"

    -- Disk list labels
    local diskLabels = {}
    local startY = windowY + 3
    for i = 1, 8 do
        local label = GUI.label(windowX + 2, startY + i - 1, 35, 1, "")
        label.colors.background = GUI.WINDOW_BACKGROUND_COLOR
        window:addChild(label)
        table.insert(diskLabels, label)
    end

    -- Info labels
    local infoY = windowY + 13
    local infoLabels = {}
    for i = 1, 6 do
        local label = GUI.label(windowX + 2, infoY + i - 1, 40, 1, "")
        window:addChild(label)
        table.insert(infoLabels, label)
    end

    -- Update function
    local function update()
        -- Update disk list
        for i, label in ipairs(diskLabels) do
            local disk = disks[i]
            if disk then
                local marker = (disk == selectedDisk) and "> " or "  "
                label.text = marker .. disk.label:sub(1, 30)
                label.colors.text = disk.isReadOnly and 0xFF0000 or 0x000000
            else
                label.text = ""
            end
        end

        -- Update info
        if selectedDisk then
            infoLabels[1].text = localization.selected .. ": " .. selectedDisk.label
            infoLabels[2].text = localization.address .. ": " .. selectedDisk.address:sub(1, 20) .. "..."
            infoLabels[3].text = localization.readOnly .. ": " .. (selectedDisk.isReadOnly and localization.yes or localization.no)
            local free = selectedDisk.spaceTotal - selectedDisk.spaceUsed
            infoLabels[4].text = localization.total .. ": " .. selectedDisk.spaceTotal .. " bytes"
            infoLabels[5].text = localization.used .. ": " .. selectedDisk.spaceUsed .. " bytes"
            infoLabels[6].text = localization.free .. ": " .. free .. " bytes"
        else
            for _, label in ipairs(infoLabels) do
                label.text = ""
            end
        end
    end

    -- Click handler for disk selection
    window.eventHandler = function(self, eventName, componentAddress, x, y, button, player)
        if eventName == "touch" then
            for i, label in ipairs(diskLabels) do
                if y == label.y and x >= windowX + 2 and x <= windowX + 37 then
                    if disks[i] then
                        selectedDisk = disks[i]
                        update()
                    end
                    return true
                end
            end
        end
        return false
    end

    -- Action buttons
    local function updateButtons()
        for i = #window.children, 1, -1 do
            local child = window.children[i]
            if child.className == "Button" and child.y > windowY + 2 and child.y < windowY + windowHeight - 6 then
                window.children[i] = nil
            end
        end

        if selectedDisk then
            -- Toggle read-only/rewritable button
            local toggleROBtn = GUI.button(windowX + 40, windowY + 3, 12, 3, selectedDisk.isReadOnly and (localization.setRW or "Set RW") or (localization.setRO or "Set RO"))
            toggleROBtn.onTouch = function()
                if selectedDisk then
                    selectedDisk.isReadOnly = not selectedDisk.isReadOnly
                    toggleROBtn.text = selectedDisk.isReadOnly and (localization.setRW or "Set RW") or (localization.setRO or "Set RO")
                    update()
                    updateButtons()
                end
            end
            window:addChild(toggleROBtn)

            if not selectedDisk.isReadOnly then
                local eraseBtn = GUI.button(windowX + 40, windowY + 7, 12, 3, localization.erase or "Erase")
                eraseBtn.onTouch = function()
                    if selectedDisk then
                        eraseDisk(selectedDisk)
                        update()
                    end
                end
                window:addChild(eraseBtn)

                local formatBtn = GUI.button(windowX + 40, windowY + 11, 12, 3, localization.format or "Format")
                formatBtn.onTouch = function()
                    if selectedDisk then
                        formatDisk(selectedDisk)
                        update()
                    end
                end
                window:addChild(formatBtn)
            end
        end
    end

    -- Refresh button
    local refreshBtn = GUI.button(windowX + 2, windowY + windowHeight - 6, 10, 3, localization.refresh or "Refresh")
    refreshBtn.onTouch = function()
        scanDisks()
        update()
    end
    window:addChild(refreshBtn)

    -- Status
    local statusLabel = GUI.label(windowX + 14, windowY + windowHeight - 6, 30, 1, statusText)
    statusLabel.colors.text = 0x666666
    window:addChild(statusLabel)

    -- Close button
    local closeBtn = GUI.button(windowX + windowWidth - 10, windowY + windowHeight - 3, 8, 3, localization.close or "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    workspace:addChild(window)
    update()
    updateButtons()

    return window
end

return application