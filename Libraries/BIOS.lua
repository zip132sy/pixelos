-- BIOS System Module for PixelOS
-- This is a SYSTEM component, NOT an application

local component = require("component")
local computer = require("computer")
local event = require("event")
local keyboard = require("keyboard")
local unicode = require("unicode")

local BIOS = {
    VERSION = "1.0",
    BOOT_TIMEOUT = 5,
    PASSWORD_MIN_LENGTH = 4,
    PASSWORD_MAX_LENGTH = 32,
}

-- BIOS configuration path
local BIOS_CONFIG_PATH = "/System/BIOS/config.cfg"

local workspace, window
local config = {
    bootEntries = {
        {name = "PixelOS", path = "/OS.lua", enabled = true},
        {name = "Recovery", path = "/System/Recovery/main.lua", enabled = false},
    },
    bootTimeout = 5,
    fastBoot = false,
    passwordHash = nil,
    encryptedDrives = {},
    language = "English",  -- Default language
}

-- Localization strings
local i18n = {
    English = {
        title = "PixelOS BIOS Setup Utility",
        bootTab = "Boot",
        securityTab = "Security",
        toolsTab = "Tools",
        languageTab = "Language",
        bootPriority = "Boot Priority Order",
        controls = {
            enableDisable = "[+/-] Enable/Disable",
            edit = "[E]dit",
            delete = "[D]elete",
            moveUp = "[U]p",
            moveDown = "[J]own",
            add = "[A]dd"
        },
        security = {
            biosPassword = "BIOS Password",
            enabled = "Enabled",
            disabled = "Disabled",
            setPassword = "Set Password",
            clearPassword = "Clear Password",
            encryptDrive = "Encrypt Drive",
            decryptDrive = "Decrypt Drive",
            encryptedDrives = "Encrypted Drives",
            noEncryptedDrives = "No encrypted drives",
            passwordSet = "Password set successfully",
            passwordCleared = "Password cleared",
            driveEncrypted = "Drive encrypted successfully",
            invalidPassword = "Invalid password",
            enterPassword = "Enter Password",
            confirmPassword = "Confirm Password",
            passwordMismatch = "Passwords do not match",
            passwordTooShort = "Password too short (min 4 chars)",
        },
        tools = {
            systemInfo = "System Information",
            resetDefaults = "Reset to Defaults",
            clearAllData = "Clear All Data",
            computerAddress = "Computer Address",
            totalMemory = "Total Memory",
            biosVersion = "BIOS Version",
            bootTimeout = "Boot Timeout",
            bootEntries = "Boot Entries"
        },
        dialogs = {
            addBootEntry = "Add Boot Entry",
            entryName = "Entry Name",
            entryPath = "Entry Path",
            cancel = "Cancel",
            ok = "OK",
            warning = "Warning",
            confirmClear = "Are you sure you want to clear all data?",
            yes = "Yes",
            no = "No"
        },
        messages = {
            saved = "Settings saved successfully",
            exitWithoutSave = "Exit without saving?",
            noChanges = "No changes to save"
        },
        language = {
            selectLanguage = "Select Language",
            currentLanguage = "Current Language",
            english = "English",
            chinese = "Chinese"
        }
    },
    Chinese = {
        title = "PixelOS BIOS 设置工具",
        bootTab = "启动",
        securityTab = "安全",
        toolsTab = "工具",
        languageTab = "语言",
        bootPriority = "启动优先级顺序",
        controls = {
            enableDisable = "[+/-] 启用/禁用",
            edit = "[E]编辑",
            delete = "[D]删除",
            moveUp = "[U]上移",
            moveDown = "[J]下移",
            add = "[A]添加"
        },
        security = {
            biosPassword = "BIOS密码",
            enabled = "已启用",
            disabled = "已禁用",
            setPassword = "设置密码",
            clearPassword = "清除密码",
            encryptDrive = "加密硬盘",
            decryptDrive = "解密硬盘",
            encryptedDrives = "已加密硬盘",
            noEncryptedDrives = "无已加密硬盘",
            passwordSet = "密码设置成功",
            passwordCleared = "密码已清除",
            driveEncrypted = "硬盘加密成功",
            invalidPassword = "密码无效",
            enterPassword = "请输入密码",
            confirmPassword = "确认密码",
            passwordMismatch = "密码不匹配",
            passwordTooShort = "密码太短（最少4个字符）",
        },
        tools = {
            systemInfo = "系统信息",
            resetDefaults = "恢复默认设置",
            clearAllData = "清除所有数据",
            computerAddress = "计算机地址",
            totalMemory = "总内存",
            biosVersion = "BIOS版本",
            bootTimeout = "启动超时",
            bootEntries = "启动项数量"
        },
        dialogs = {
            addBootEntry = "添加启动项",
            entryName = "启动项名称",
            entryPath = "启动项路径",
            cancel = "取消",
            ok = "确定",
            warning = "警告",
            confirmClear = "确定要清除所有数据吗？",
            yes = "是",
            no = "否"
        },
        messages = {
            saved = "设置保存成功",
            exitWithoutSave = "退出不保存？",
            noChanges = "没有需要保存的更改"
        },
        language = {
            selectLanguage = "选择语言",
            currentLanguage = "当前语言",
            english = "英语",
            chinese = "中文"
        }
    }
}

local function getText(key)
    local lang = config.language or "English"
    local text = i18n[lang]
    -- Split key by "." manually (Lua strings don't have split method)
    for k in key:gmatch("[^%.]+") do
        if text then
            text = text[k]
        else
            return key
        end
    end
    return text or key
end

-- Load configuration
local function loadConfig()
    local filesystem = require("Filesystem")
    if filesystem.exists(BIOS_CONFIG_PATH) then
        local success, data = pcall(function()
            return filesystem.readTable(BIOS_CONFIG_PATH)
        end)
        if success and data then
            config = data
            if not config.language then
                config.language = "English"
            end
        end
    end
end

-- Save configuration
local function saveConfig()
    local filesystem = require("Filesystem")
    filesystem.makeDirectory("/System/BIOS")
    filesystem.writeTable(BIOS_CONFIG_PATH, config, true)
    isModified = false
end

-- Password management
local function sha256(data)
    local Encryption = require("Encryption")
    return Encryption.hashPassword(data)
end

local function verifyPassword(password)
    if not config.passwordHash then return true end
    return sha256(password) == config.passwordHash
end

local function setPassword(password)
    if #password < BIOS.PASSWORD_MIN_LENGTH then
        return false, getText("security.passwordTooShort")
    end
    if #password > BIOS.PASSWORD_MAX_LENGTH then
        return false, "Password too long"
    end
    config.passwordHash = sha256(password)
    saveConfig()
    return true, getText("security.passwordSet")
end

local function clearPassword()
    config.passwordHash = nil
    saveConfig()
    return true, getText("security.passwordCleared")
end

-- Drawing functions
local function draw()
    local GUI = require("GUI")
    
    workspace:removeChildren()
    
    -- Background
    workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, 0x1E1E1E))
    
    -- Title bar
    workspace:addChild(GUI.panel(1, 1, workspace.width, 3, 0x3366CC))
    workspace:addChild(GUI.label(1, 1, workspace.width, 1, 0xFFFFFF, getText("title"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    workspace:addChild(GUI.label(1, 2, workspace.width, 1, 0xCCCCCC, "v" .. BIOS.VERSION)):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    
    -- Tabs
    local tabs = {getText("bootTab"), getText("securityTab"), getText("toolsTab"), getText("languageTab")}
    for i, tabName in ipairs(tabs) do
        local x = 3 + (i - 1) * 15
        local bgColor = currentTab == i and 0x3366CC or 0x2D2D2D
        workspace:addChild(GUI.button(x, 4, 13, 3, bgColor, 0xFFFFFF, 0x3366CC, 0xFFFFFF, tabName)).onTouch = function()
            currentTab = i
            selectedEntry = 1
            draw()
        end
    end
    
    if currentTab == 1 then
        drawBootTab()
    elseif currentTab == 2 then
        drawSecurityTab()
    elseif currentTab == 3 then
        drawToolsTab()
    elseif currentTab == 4 then
        drawLanguageTab()
    end
    
    -- Bottom info bar
    workspace:addChild(GUI.panel(1, workspace.height - 1, workspace.width, 1, 0x2D2D2D))
    workspace:addChild(GUI.label(3, workspace.height, workspace.width - 6, 1, 0xAAAAAA, "ESC: " .. getText("dialogs.cancel") .. " | F10: Save & Exit | F5: Refresh")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
    
    workspace:draw()
end

-- Boot tab
function drawBootTab()
    local GUI = require("GUI")
    local y = 8
    
    workspace:addChild(GUI.label(3, y, 30, 1, 0xFFFFFF, getText("bootPriority")))
    y = y + 2
    
    for i, entry in ipairs(config.bootEntries) do
        local bgColor = selectedEntry == i and 0x3366CC or (i % 2 == 0 and 0x2D2D2D or 0x252525)
        local textColor = entry.enabled and 0xFFFFFF or 0x888888
        
        local container = workspace:addChild(GUI.container(3, y, workspace.width - 6, 3))
        container:addChild(GUI.panel(1, 1, container.width, container.height, bgColor))
        
        container:addChild(GUI.label(2, 2, 5, 1, textColor, i .. "."))
        container:addChild(GUI.label(7, 2, 25, 1, textColor, entry.name))
        container:addChild(GUI.label(33, 2, 30, 1, 0x888888, entry.path))
        
        local statusIcon = entry.enabled and "[X]" or "[ ]"
        local statusColor = entry.enabled and 0x66DB80 or 0xCC4940
        container:addChild(GUI.label(70, 2, 5, 1, statusColor, statusIcon))
        
        container.eventHandler = function(ws, ctrl, e1)
            if e1 == "touch" then
                selectedEntry = i
                draw()
            end
        end
        
        y = y + 3
    end
    
    y = y + 2
    workspace:addChild(GUI.label(3, y, 60, 1, 0xAAAAAA, 
        getText("controls.enableDisable") .. " | " .. 
        getText("controls.edit") .. " | " .. 
        getText("controls.delete") .. " | " .. 
        getText("controls.add")))
end

-- Security tab
function drawSecurityTab()
    local GUI = require("GUI")
    local y = 8
    
    workspace:addChild(GUI.label(3, y, 30, 1, 0xFFFFFF, getText("security.biosPassword")))
    y = y + 2
    
    local passwordStatus = config.passwordHash and getText("security.enabled") or getText("security.disabled")
    local passwordColor = config.passwordHash and 0x66DB80 or 0xCC4940
    workspace:addChild(GUI.label(5, y, 30, 1, passwordColor, passwordStatus))
    y = y + 3
    
    workspace:addChild(GUI.button(5, y, 20, 3, 0x2D2D2D, 0xFFFFFF, 0x3366CC, 0xFFFFFF, getText("security.setPassword"))).onTouch = function()
        passwordDialog("set")
    end
    
    if config.passwordHash then
        workspace:addChild(GUI.button(27, y, 20, 3, 0x2D2D2D, 0xFFFFFF, 0x3366CC, 0xFFFFFF, getText("security.clearPassword"))).onTouch = function()
            passwordDialog("verifyClear")
        end
    end
    y = y + 4
    
    workspace:addChild(GUI.label(3, y, 30, 1, 0xFFFFFF, getText("security.encryptedDrives")))
    y = y + 2
    
    local encryptedCount = 0
    for drive, info in pairs(config.encryptedDrives) do
        encryptedCount = encryptedCount + 1
        workspace:addChild(GUI.label(5, y, 40, 1, 0x66DB80, drive:sub(1, 8) .. "..."))
        y = y + 2
    end
    
    if encryptedCount == 0 then
        workspace:addChild(GUI.label(5, y, 40, 1, 0x888888, getText("security.noEncryptedDrives")))
        y = y + 2
    end
end

-- Tools tab
function drawToolsTab()
    local GUI = require("GUI")
    local y = 8
    
    workspace:addChild(GUI.label(3, y, 30, 1, 0xFFFFFF, getText("tools.systemInfo")))
    y = y + 2
    
    local textBox = workspace:addChild(GUI.textBox(5, y, 50, 10, 0x2D2D2D, 0xFFFFFF, {
        getText("tools.computerAddress") .. ": " .. computer.address():sub(1, 16) .. "...",
        getText("tools.totalMemory") .. ": " .. math.floor(computer.totalMemory() / 1024) .. " KB",
        getText("tools.biosVersion") .. ": " .. BIOS.VERSION,
        getText("tools.bootTimeout") .. ": " .. config.bootTimeout .. "s",
        getText("tools.bootEntries") .. ": " .. #config.bootEntries,
    }, 1, 1, 1))
    y = y + 12
    
    workspace:addChild(GUI.button(5, y, 20, 3, 0x2D2D2D, 0xFFFFFF, 0x3366CC, 0xFFFFFF, getText("tools.resetDefaults"))).onTouch = function()
        resetToDefaults()
    end
end

-- Language tab
function drawLanguageTab()
    local GUI = require("GUI")
    local y = 8
    
    workspace:addChild(GUI.label(3, y, 30, 1, 0xFFFFFF, getText("language.selectLanguage")))
    y = y + 3
    
    workspace:addChild(GUI.label(5, y, 30, 1, 0xCCCCCC, getText("language.currentLanguage") .. ": " .. config.language))
    y = y + 3
    
    -- English button
    local englishBtn = workspace:addChild(GUI.button(5, y, 20, 3, 
        config.language == "English" and 0x3366CC or 0x2D2D2D, 
        0xFFFFFF, 0x3366CC, 0xFFFFFF, 
        getText("language.english")))
    englishBtn.onTouch = function()
        config.language = "English"
        saveConfig()
        draw()
    end
    y = y + 4
    
    -- Chinese button
    local chineseBtn = workspace:addChild(GUI.button(5, y, 20, 3, 
        config.language == "Chinese" and 0x3366CC or 0x2D2D2D, 
        0xFFFFFF, 0x3366CC, 0xFFFFFF, 
        getText("language.chinese")))
    chineseBtn.onTouch = function()
        config.language = "Chinese"
        saveConfig()
        draw()
    end
end

function passwordDialog(mode)
    local GUI = require("GUI")
    
    local dialog = workspace:addChild(GUI.window(20, 8, 50, 12))
    dialog.localX = math.floor(workspace.width / 2 - 25)
    dialog:addChild(GUI.panel(1, 1, dialog.width, dialog.height, 0xE1E1E1))
    
    local titles = {
        set = getText("security.setPassword"),
        verify = getText("security.enterPassword"),
        verifyClear = getText("security.clearPassword"),
    }
    
    dialog:addChild(GUI.label(2, 2, dialog.width - 4, 1, 0x2D2D2D, titles[mode] or mode)):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    
    local input = dialog:addChild(GUI.input(5, 5, 40, 1, 0xF0F0F0, 0x696969, 0x3366CC, 0xE1E1E1, getText("security.enterPassword"), "", false))
    
    dialog:addChild(GUI.button(5, 8, 15, 3, 0x3366CC, 0xFFFFFF, 0x3366CC, 0xFFFFFF, getText("dialogs.ok"))).onTouch = function()
        local result = input.text
        dialog:remove()
        draw()
        
        if mode == "set" then
            local ok, msg = setPassword(result)
            showMessage(ok and "Success" or "Error", msg, ok and 0x66DB80 or 0xCC4940)
        elseif mode == "verifyClear" then
            if verifyPassword(result) then
                clearPassword()
                showMessage("Success", getText("security.passwordCleared"), 0x66DB80)
            else
                showMessage("Error", getText("security.invalidPassword"), 0xCC4940)
            end
        end
    end
    
    dialog:addChild(GUI.button(30, 8, 15, 3, 0xCC4940, 0xFFFFFF, 0xCC4940, 0xFFFFFF, getText("dialogs.cancel"))).onTouch = function()
        dialog:remove()
        draw()
    end
    
    workspace:draw()
end

function showMessage(title, text, color)
    local GUI = require("GUI")
    
    local dialog = workspace:addChild(GUI.window(20, 10, 50, 8))
    dialog.localX = math.floor(workspace.width / 2 - 25)
    dialog:addChild(GUI.panel(1, 1, dialog.width, dialog.height, 0xE1E1E1))
    
    dialog:addChild(GUI.label(2, 2, dialog.width - 4, 1, color or 0x2D2D2D, title)):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    dialog:addChild(GUI.label(2, 4, dialog.width - 4, 1, 0x696969, text)):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    
    dialog:addChild(GUI.button(18, 6, 14, 3, 0x3366CC, 0xFFFFFF, 0x3366CC, 0xFFFFFF, getText("dialogs.ok"))).onTouch = function()
        dialog:remove()
        draw()
    end
    
    workspace:draw()
end

function resetToDefaults()
    config = {
        bootEntries = {
            {name = "PixelOS", path = "/OS.lua", enabled = true},
        },
        bootTimeout = 5,
        fastBoot = false,
        passwordHash = nil,
        encryptedDrives = {},
        language = config.language or "English",
    }
    saveConfig()
    draw()
end

-- Event handlers
local function handleKeyPress(keyboardEvent)
    local key = keyboardEvent[4]
    
    if key == keyboard.F5 then
        loadConfig()
        draw()
    elseif key == keyboard.F10 then
        saveConfig()
        return true
    elseif currentTab == 1 then
        if key == string.byte('+') or key == string.byte('=') then
            config.bootEntries[selectedEntry].enabled = not config.bootEntries[selectedEntry].enabled
            isModified = true
            draw()
        elseif key == string.byte('-') then
            config.bootEntries[selectedEntry].enabled = not config.bootEntries[selectedEntry].enabled
            isModified = true
            draw()
        elseif key == string.byte('D') or key == string.byte('d') then
            if #config.bootEntries > 1 then
                table.remove(config.bootEntries, selectedEntry)
                selectedEntry = math.max(1, selectedEntry - 1)
                isModified = true
                draw()
            end
        elseif key == string.byte('A') or key == string.byte('a') then
            addBootEntryDialog()
        elseif key == string.byte('U') then
            if selectedEntry > 1 then
                config.bootEntries[selectedEntry], config.bootEntries[selectedEntry - 1] = 
                    config.bootEntries[selectedEntry - 1], config.bootEntries[selectedEntry]
                selectedEntry = selectedEntry - 1
                isModified = true
                draw()
            end
        elseif key == string.byte('J') then
            if selectedEntry < #config.bootEntries then
                config.bootEntries[selectedEntry], config.bootEntries[selectedEntry + 1] = 
                    config.bootEntries[selectedEntry + 1], config.bootEntries[selectedEntry]
                selectedEntry = selectedEntry + 1
                isModified = true
                draw()
            end
        end
    elseif currentTab == 2 then
        if key == string.byte('S') or key == string.byte('s') then
            passwordDialog("set")
        end
    end
    
    return false
end

function addBootEntryDialog()
    local GUI = require("GUI")
    
    local dialog = workspace:addChild(GUI.window(15, 8, 60, 12))
    dialog.localX = math.floor(workspace.width / 2 - 30)
    dialog:addChild(GUI.panel(1, 1, dialog.width, dialog.height, 0xE1E1E1))
    
    dialog:addChild(GUI.label(2, 2, dialog.width - 4, 1, 0x2D2D2D, getText("dialogs.addBootEntry"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    
    local nameInput = dialog:addChild(GUI.input(5, 5, 50, 1, 0xF0F0F0, 0x696969, 0x3366CC, 0xE1E1E1, getText("dialogs.entryName"), "", false))
    local pathInput = dialog:addChild(GUI.input(5, 7, 50, 1, 0xF0F0F0, 0x696969, 0x3366CC, 0xE1E1E1, getText("dialogs.entryPath"), "", false))
    
    dialog:addChild(GUI.button(5, 9, 15, 3, 0x3366CC, 0xFFFFFF, 0x3366CC, 0xFFFFFF, getText("dialogs.ok"))).onTouch = function()
        local name = nameInput.text
        local path = pathInput.text
        if #name > 0 and #path > 0 then
            table.insert(config.bootEntries, {
                name = name,
                path = path,
                enabled = true
            })
            isModified = true
            dialog:remove()
            draw()
        end
    end
    
    dialog:addChild(GUI.button(25, 9, 15, 3, 0xCC4940, 0xFFFFFF, 0xCC4940, 0xFFFFFF, getText("dialogs.cancel"))).onTouch = function()
        dialog:remove()
        draw()
    end
    
    workspace:draw()
end

-- Main function
local currentTab = 1
local selectedEntry = 1
local isModified = false
local passwordVerified = false

function BIOS.start()
    if config.passwordHash and not passwordVerified then
        passwordDialog("verify")
        os.sleep(0.1)
        if not verifyPassword then
            return false
        end
    end
    
    loadConfig()
    workspace = GUI.workspace()
    draw()
    
    while true do
        local eventData = {event.pull()}
        local signal = eventData[1]
        
        if signal == "key_down" then
            local key = eventData[4]
            if key == keyboard.ESCAPE then
                break
            elseif handleKeyPress(eventData) then
                break
            end
        elseif signal == "touch" then
            workspace:handleEvent(signal, table.unpack(eventData, 2))
        elseif signal == "scroll" then
            workspace:handleEvent(signal, table.unpack(eventData, 2))
        elseif signal == "interrupted" then
            break
        end
    end
    
    return true
end

-- Boot prompt functions
function BIOS.showBootPrompt()
    local gpu = component.list("gpu")()
    local screenAddr = component.list("screen")()
    
    if gpu and screenAddr then
        component.invoke(gpu, "bind", screenAddr)
        local width, height = component.invoke(gpu, "getResolution")
        
        component.invoke(gpu, "setBackground", 0x000000)
        component.invoke(gpu, "setForeground", 0x00FF00)
        component.invoke(gpu, "fill", 1, 1, width, height, " ")
        
        local lang = config.language or "English"
        local title = lang == "Chinese" and "PixelOS 启动加载器" or "PixelOS Boot Loader"
        local prompt = lang == "Chinese" and "按 F12 进入 BIOS 设置" or "Press F12 for BIOS Setup"
        local hint = lang == "Chinese" and "按 ESC 跳过 | 按 DEL 显示启动菜单" or "Press ESC to skip | DEL for Boot Menu"
        
        component.invoke(gpu, "set", math.floor((width - #title) / 2), math.floor(height / 2) - 2, title)
        component.invoke(gpu, "set", math.floor((width - #prompt) / 2), math.floor(height / 2), prompt)
        component.invoke(gpu, "setForeground", 0x888888)
        component.invoke(gpu, "set", math.floor((width - #hint) / 2), math.floor(height / 2) + 3, hint)
        
        local startTime = computer.uptime()
        while computer.uptime() - startTime < BIOS.BOOT_TIMEOUT do
            local signal = {event.pull(0.1)}
            if signal[1] == "key_down" then
                local key = signal[4]
                if key == keyboard.F12 or key == keyboard.DELETE then
                    return true
                elseif key == keyboard.ESCAPE then
                    return false
                end
            end
        end
        return false
    end
    return false
end

function BIOS.showBootMenu()
    local gpu = component.list("gpu")()
    local screenAddr = component.list("screen")()
    
    if not (gpu and screenAddr) then return "/OS.lua" end
    
    component.invoke(gpu, "bind", screenAddr)
    local width, height = component.invoke(gpu, "getResolution")
    
    component.invoke(gpu, "setBackground", 0x1E1E1E)
    component.invoke(gpu, "setForeground", 0xFFFFFF)
    component.invoke(gpu, "fill", 1, 1, width, height, " ")
    
    local lang = config.language or "English"
    local title = lang == "Chinese" and "PixelOS 启动管理器" or "PixelOS Boot Manager"
    
    component.invoke(gpu, "setForeground", 0x3366CC)
    component.invoke(gpu, "set", math.floor((width - #title) / 2), 2, title)
    
    local startY = math.floor(height / 2) - math.floor(#config.bootEntries / 2)
    local selected = 1
    
    local function draw()
        component.invoke(gpu, "setBackground", 0x1E1E1E)
        component.invoke(gpu, "fill", 1, 1, width, height, " ")
        component.invoke(gpu, "setForeground", 0x3366CC)
        component.invoke(gpu, "set", math.floor((width - #title) / 2), 2, title)
        
        for i, entry in ipairs(config.bootEntries) do
            local y = startY + (i - 1) * 2
            if entry.enabled then
                if i == selected then
                    component.invoke(gpu, "setBackground", 0x3366CC)
                    component.invoke(gpu, "setForeground", 0xFFFFFF)
                    component.invoke(gpu, "set", math.floor(width / 2) - 10, y, "  " .. entry.name .. "  ")
                else
                    component.invoke(gpu, "setBackground", 0x1E1E1E)
                    component.invoke(gpu, "setForeground", 0xFFFFFF)
                    component.invoke(gpu, "set", math.floor(width / 2) - 10, y, "  " .. entry.name .. "  ")
                end
            end
        end
        
        local hint = lang == "Chinese" and "↑↓ 选择 | 回车启动 | F12 BIOS设置" or "↑↓ Select | Enter Boot | F12 BIOS"
        component.invoke(gpu, "setForeground", 0x888888)
        component.invoke(gpu, "set", math.floor((width - #hint) / 2), height - 2, hint)
    end
    
    draw()
    
    while true do
        local signal = {event.pull()}
        if signal[1] == "key_down" then
            local key = signal[4]
            if key == keyboard.UP then
                selected = math.max(1, selected - 1)
                draw()
            elseif key == keyboard.DOWN then
                selected = math.min(#config.bootEntries, selected + 1)
                draw()
            elseif key == keyboard.ENTER then
                return config.bootEntries[selected].path
            elseif key == keyboard.F12 then
                return "BIOS"
            elseif key == keyboard.ESCAPE then
                return "/OS.lua"
            end
        end
    end
end

-- Export public API
return BIOS
