local GUI = require("GUI")
local system = require("System")
local component = component
local computer = computer
local filesystem = require("Filesystem")

local application = {}

local checks = {}
local results = {}
local isChecking = false

local function addCheck(name, testFunc)
    table.insert(checks, {name = name, test = testFunc})
end

local function runChecks()
    results = {}
    isChecking = true

    for _, check in ipairs(checks) do
        local ok, result = pcall(check.test)
        table.insert(results, {
            name = check.name,
            passed = ok and result,
            error = not ok and result or nil
        })
        os.sleep(0.1) -- Allow UI updates
    end

    isChecking = false
end

function application.main()
    -- Setup checks
    checks = {}

    -- Hardware checks
    addCheck("GPU Component", function() return component.list("gpu")() ~= nil end)
    addCheck("Screen Component", function() return component.list("screen")() ~= nil end)
    addCheck("Filesystem", function() return component.list("filesystem")() ~= nil end)
    addCheck("EEPROM", function() return component.list("eeprom")() ~= nil end)

    -- Library checks
    addCheck("Event Library", function() return require("Event") ~= nil end)
    addCheck("Filesystem Library", function() return require("Filesystem") ~= nil end)
    addCheck("GUI Library", function() return require("GUI") ~= nil end)
    addCheck("Screen Library", function() return require("Screen") ~= nil end)

    -- System checks
    addCheck("System Directory", function() return filesystem.exists("System/OS/") end)
    addCheck("Applications Directory", function() return filesystem.exists("Applications/") end)
    addCheck("Libraries Directory", function() return filesystem.exists("Libraries/") end)

    -- Memory check
    addCheck("Memory (32KB+)", function() return computer.totalMemory() >= 32 * 1024 end)

    -- Start checks in background
    local checkThread = coroutine.create(runChecks)
    coroutine.resume(checkThread)

    -- Create window
    local workspace = system.getWorkspace()
    local windowWidth, windowHeight = 50, 25
    local windowX = math.floor((workspace.width - windowWidth) / 2)
    local windowY = math.floor((workspace.height - windowHeight) / 2)

    local window = GUI.window(windowX, windowY, windowWidth, windowHeight)
    window.title = "System Check"

    -- Status label
    local statusLabel = GUI.label(windowX + 2, windowY + 4, windowWidth - 4, 1, "Running system checks...")
    window:addChild(statusLabel)

    -- Progress bar
    local progressBar = GUI.progressBar(windowX + 2, windowY + 6, windowWidth - 4, 1, 0, #checks, 0x3366CC)
    window:addChild(progressBar)

    -- Results area
    local resultLabels = {}
    local startY = windowY + 9
    for i = 1, 12 do
        local label = GUI.label(windowX + 2, startY + i - 1, windowWidth - 4, 1, "")
        window:addChild(label)
        table.insert(resultLabels, label)
    end

    -- Summary label
    local summaryLabel = GUI.label(windowX + 2, windowY + windowHeight - 6, windowWidth - 4, 1, "")
    window:addChild(summaryLabel)

    -- Update function
    local function update()
        progressBar.value = #results

        if #results == 0 then
            statusLabel.text = "Initializing..."
        elseif isChecking then
            statusLabel.text = "Checking: " .. checks[#results + 1].name .. "..."
        else
            statusLabel.text = "Check complete"

            local passed = 0
            for _, r in ipairs(results) do
                if r.passed then passed = passed + 1 end
            end

            if passed == #results then
                summaryLabel.text = "All checks passed! System is healthy."
                summaryLabel.colors.text = 0x00AA00
            else
                summaryLabel.text = passed .. "/" .. #results .. " checks passed. Some issues found."
                summaryLabel.colors.text = 0xFFAA00
            end
        end

        -- Display results
        for i, label in ipairs(resultLabels) do
            local result = results[i]
            if result then
                local status = result.passed and "[OK]" or "[FAIL]"
                label.text = status .. " " .. result.name
                label.colors.text = result.passed and 0x00AA00 or 0xFF0000
            else
                label.text = ""
            end
        end

        -- Continue checking
        if isChecking and coroutine.status(checkThread) ~= "dead" then
            coroutine.resume(checkThread)
        end
    end

    -- Close button
    local closeBtn = GUI.button(windowX + windowWidth - 10, windowY + windowHeight - 3, 8, 3, "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    -- Retest button
    local retestBtn = GUI.button(windowX + 2, windowY + windowHeight - 3, 10, 3, "Retest")
    retestBtn.onTouch = function()
        results = {}
        checkThread = coroutine.create(runChecks)
        coroutine.resume(checkThread)
    end
    window:addChild(retestBtn)

    workspace:addChild(window)

    -- Main loop for this window
    local running = true
    window.eventHandler = function(self, ...)
        update()
        return false
    end

    return window
end

return application
