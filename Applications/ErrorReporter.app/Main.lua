local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")

local application = {}

local localization = system.getCurrentScriptLocalization()

local errorFiles = {}
local selectedError = nil

local function loadErrors()
    errorFiles = {}
    local path = "System/OS/Errors.log"
    if filesystem.exists(path) then
        -- For simplicity, treat the whole log as one entry
        table.insert(errorFiles, {
            name = "System Errors",
            path = path,
            time = os.time()
        })
    end

    -- Also check error reports directory
    if filesystem.exists("System/OS/") then
        local list = filesystem.list("System/OS/")
        if list then
            for _, name in ipairs(list) do
                if name:match("%.log$") and name ~= "Errors.log" then
                    table.insert(errorFiles, {
                        name = name:gsub("%.log$", ""),
                        path = "System/OS/" .. name,
                        time = os.time()
                    })
                end
            end
        end
    end
end

local function readError(file)
    local handle = filesystem.open(file.path, "r")
    if handle then
        local data = filesystem.read(handle, math.huge)
        filesystem.close(handle)
        return data or "No data"
    end
    return "Failed to read"
end

local function clearErrors()
    local path = "System/OS/Errors.log"
    if filesystem.exists(path) then
        filesystem.remove(path)
    end
    loadErrors()
end

function application.main()
    loadErrors()

    local workspace = system.getWorkspace()
    local windowWidth, windowHeight = 60, 25
    local windowX = math.floor((workspace.width - windowWidth) / 2)
    local windowY = math.floor((workspace.height - windowHeight) / 2)

    local window = GUI.window(windowX, windowY, windowWidth, windowHeight)
    window.title = localization.appTitle

    -- Stats
    local statsLabel = GUI.label(windowX + 2, windowY + 4, 30, 1, localization.totalErrors .. " " .. #errorFiles)
    window:addChild(statsLabel)

    -- Error list
    local listLabels = {}
    local startY = windowY + 6
    for i = 1, 10 do
        local label = GUI.label(windowX + 2, startY + i - 1, 25, 1, "")
        label.colors.background = GUI.WINDOW_BACKGROUND_COLOR
        window:addChild(label)
        table.insert(listLabels, label)
    end

    -- Error content
    local contentLabel = GUI.label(windowX + 30, startY, 28, 10, "")
    contentLabel.colors.background = GUI.WINDOW_BACKGROUND_COLOR
    window:addChild(contentLabel)

    -- Update function
    local function update()
        statsLabel.text = localization.totalErrors .. " " .. #errorFiles

        for i, label in ipairs(listLabels) do
            local err = errorFiles[i]
            if err then
                local marker = (err == selectedError) and "> " or "  "
                label.text = marker .. err.name:sub(1, 20)
            else
                label.text = ""
            end
        end

        if selectedError then
            local content = readError(selectedError)
            -- Truncate for display
            if #content > 200 then
                content = content:sub(1, 200) .. "..."
            end
            content = content:gsub("\n", " ")
            contentLabel.text = content
        else
            contentLabel.text = localization.selectError
            contentLabel.colors.text = 0x666666
        end
    end

    -- Click handler
    window.eventHandler = function(self, eventName, componentAddress, x, y, button, player)
        if eventName == "touch" then
            for i, label in ipairs(listLabels) do
                if y == label.y and x >= windowX + 2 and x <= windowX + 27 then
                    selectedError = errorFiles[i]
                    update()
                    return true
                end
            end
        end
        return false
    end

    -- Buttons
    local refreshBtn = GUI.button(windowX + 2, windowY + windowHeight - 6, 10, 3, localization.refresh)
    refreshBtn.onTouch = function()
        loadErrors()
        update()
    end
    window:addChild(refreshBtn)

    local clearBtn = GUI.button(windowX + 14, windowY + windowHeight - 6, 10, 3, localization.clear)
    clearBtn.onTouch = function()
        clearErrors()
        selectedError = nil
        update()
    end
    window:addChild(clearBtn)

    local closeBtn = GUI.button(windowX + windowWidth - 10, windowY + windowHeight - 3, 8, 3, localization.close)
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    workspace:addChild(window)
    update()

    return window
end

return application
