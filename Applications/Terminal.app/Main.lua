local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")
local component = component
local computer = computer

local application = {}

function application.main()
    local workspace = system.getWorkspace()
    local windowWidth, windowHeight = 70, 25
    local windowX = math.floor((workspace.width - windowWidth) / 2)
    local windowY = math.floor((workspace.height - windowHeight) / 2)

    local window = GUI.window(windowX, windowY, windowWidth, windowHeight)
    window.title = "Terminal"
    window.colors.background = 0x000000

    -- Terminal state
    local lines = {}
    local currentLine = ""
    local cursorX = 1
    local scrollOffset = 0

    -- Commands
    local commands = {}

    commands.help = function()
        addLine("Available commands:")
        addLine("  help       - Show this help")
        addLine("  clear      - Clear screen")
        addLine("  ls [path]  - List files")
        addLine("  cd <path>  - Change directory")
        addLine("  cat <file> - Show file contents")
        addLine("  mkdir <dir>- Create directory")
        addLine("  rm <file>  - Remove file")
        addLine("  reboot     - Reboot computer")
        addLine("  shutdown   - Shutdown computer")
        addLine("  version    - Show version")
    end

    commands.clear = function()
        lines = {}
        scrollOffset = 0
    end

    commands.ls = function(args)
        local path = args[2] or "/"
        local list = filesystem.list(path)
        if list then
            for _, name in ipairs(list) do
                addLine(name)
            end
        else
            addLine("Cannot access: " .. path)
        end
    end

    commands.version = function()
        addLine("PixelOS Terminal v3.0")
        addLine("Based on MineOS")
    end

    commands.reboot = function()
        computer.shutdown(true)
    end

    commands.shutdown = function()
        computer.shutdown()
    end

    local function executeCommand(line)
        addLine("> " .. line)

        local parts = {}
        for part in line:gmatch("%S+") do
            table.insert(parts, part)
        end

        if #parts == 0 then return end

        local cmd = parts[1]:lower()
        if commands[cmd] then
            local ok, err = pcall(commands[cmd], parts)
            if not ok then
                addLine("Error: " .. tostring(err))
            end
        else
            addLine("Unknown command: " .. cmd)
        end
    end

    local function addLine(text)
        table.insert(lines, text)
        -- Keep only last 100 lines
        while #lines > 100 do
            table.remove(lines, 1)
        end
    end

    -- Initial message
    addLine("PixelOS Terminal v3.0")
    addLine("Type 'help' for available commands")
    addLine("")

    -- Custom draw for terminal
    window.drawContent = function(self)
        local contentY = self.y + 3
        local contentHeight = self.height - 4
        local contentWidth = self.width - 2

        -- Clear content area
        for i = 1, contentHeight do
            for j = 1, contentWidth do
                -- Using screen directly would be better, but using set for now
            end
        end

        -- Draw lines
        local visibleLines = contentHeight - 1
        local startIdx = math.max(1, #lines - visibleLines + 1)

        for i = startIdx, #lines do
            local line = lines[i]
            local y = contentY + (i - startIdx)
            if y < self.y + self.height - 1 then
                -- Draw line text (truncated)
                if #line > contentWidth then
                    line = line:sub(1, contentWidth - 3) .. "..."
                end
                -- Would need direct screen access for proper terminal
            end
        end

        -- Draw prompt
        local promptY = self.y + self.height - 2
        local prompt = "> " .. currentLine
        if #prompt > contentWidth then
            prompt = prompt:sub(-contentWidth)
        end
    end

    -- Event handler
    window.eventHandler = function(self, eventName, ...)
        if eventName == "key_down" then
            local key = select(2, ...)
            if key == 28 then -- Enter
                executeCommand(currentLine)
                currentLine = ""
                cursorX = 1
            elseif key == 14 then -- Backspace
                if cursorX > 1 then
                    currentLine = currentLine:sub(1, cursorX - 2) .. currentLine:sub(cursorX)
                    cursorX = cursorX - 1
                end
            elseif key == 211 then -- Delete
                currentLine = ""
                cursorX = 1
            else
                local char = select(3, ...)
                if char >= 32 and char <= 126 then
                    currentLine = currentLine .. string.char(char)
                    cursorX = cursorX + 1
                end
            end
            return true
        end
        return false
    end

    -- Close button
    local closeBtn = GUI.button(windowX + windowWidth - 10, windowY + windowHeight - 3, 8, 3, "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    workspace:addChild(window)
    return window
end

return application
