local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")
local internet = require("Internet")
local localization = require("Localization")

local application = {}
application.name = localization.AppSystemUpdate or "System Update"

-- 当前版本
local CURRENT_VERSION = "3.1"
local GITEE_REPO = "https://gitee.com/zip132sy/pixelos"
local OFFICIAL_SOURCE = "https://gitee.com/zip132sy/pixelos/raw/master"

-- 检查网络连接
local function checkInternetConnection()
    local success, reason = pcall(function()
        local handle = internet.open(GITEE_REPO)
        if handle then
            handle:close()
            return true
        end
        return false
    end)
    return success
end

-- 获取远程版本信息
local function getRemoteVersion()
    local success, version = pcall(function()
        -- 尝试从 Gitee 获取版本文件
        local url = OFFICIAL_SOURCE .. "/VERSION"
        local handle = internet.open(url)
        if handle then
            local content = handle:read(math.huge)
            handle:close()
            return content:gsub("%s+", "")  -- 去除空白字符
        end
        return nil
    end)
    
    if not success then
        return nil
    end
    return version
end

-- 比较版本号
local function compareVersions(current, remote)
    local curParts = {}
    local remParts = {}
    
    for part in string.gmatch(current, "[^.]+") do
        table.insert(curParts, tonumber(part) or 0)
    end
    
    for part in string.gmatch(remote, "[^.]+") do
        table.insert(remParts, tonumber(part) or 0)
    end
    
    for i = 1, math.max(#curParts, #remParts) do
        local cur = curParts[i] or 0
        local rem = remParts[i] or 0
        
        if cur < rem then
            return -1  -- 有新版本
        elseif cur > rem then
            return 1   -- 当前版本更新
        end
    end
    
    return 0  -- 版本相同
end

-- 下载更新
local function downloadUpdate(onProgress)
    local success, result = pcall(function()
        -- 下载更新脚本
        local url = OFFICIAL_SOURCE .. "/Updater.lua"
        local handle = internet.open(url)
        
        if not handle then
            return false, "Failed to download updater"
        end
        
        local content = handle:read(math.huge)
        handle:close()
        
        -- 保存到临时文件
        local tempFile = "/tmp/updater.lua"
        filesystem.makeDirectory("/tmp")
        local f = filesystem.open(tempFile, "w")
        f:write(content)
        f:close()
        
        return true, tempFile
    end)
    
    if not success then
        return false, "Download error: " .. tostring(result)
    end
    
    return result, result
end

function application.main()
    local workspace = system.getWorkspace()
    local windowWidth, windowHeight = 50, 20
    local windowX = math.floor((workspace.width - windowWidth) / 2)
    local windowY = math.floor((workspace.height - windowHeight) / 2)
    
    local window = GUI.window(windowX, windowY, windowWidth, windowHeight)
    window.title = "系统更新"
    window.colors.title = 0x3366CC
    
    -- 版本信息
    window:addChild(GUI.label(windowX + 2, windowY + 2, 46, 1, "当前版本：" .. CURRENT_VERSION))
    
    -- 状态区域
    local statusLabel = GUI.label(windowX + 2, windowY + 5, 46, 1, "正在检查更新...")
    window:addChild(statusLabel)
    
    -- 进度条
    local progressBar = GUI.progressBar(windowX + 2, windowY + 8, 46, 1, 0x3366CC, 0xD2D2D2, 0xA5A5A5, 0, false, false)
    window:addChild(progressBar)
    
    -- 详细信息
    local detailsLabel = GUI.label(windowX + 2, windowY + 10, 46, 3, "")
    detailsLabel.colors.text = 0x696969
    window:addChild(detailsLabel)
    
    -- 操作按钮容器
    local buttonContainer = GUI.container(windowX + 2, windowY + 14, 46, 4)
    window:addChild(buttonContainer)
    
    workspace:addChild(window)
    
    -- 检查更新
    local function checkForUpdates()
        -- 检查网络
        if not checkInternetConnection() then
            statusLabel.text = "✗ 无网络连接"
            statusLabel.colors.text = 0xFF0000
            detailsLabel.text = "请连接网络后重试。\n\n错误：网络不可达"
            return
        end
        
        -- 获取远程版本
        local remoteVersion = getRemoteVersion()
        
        if not remoteVersion then
            statusLabel.text = "✗ 检查更新失败"
            statusLabel.colors.text = 0xFF9900
            detailsLabel.text = "无法从服务器获取版本信息。\n\n请稍后重试。"
            return
        end
        
        -- 比较版本
        local comparison = compareVersions(CURRENT_VERSION, remoteVersion)
        
        if comparison < 0 then
            -- 有新版本
            statusLabel.text = "✓ 发现新版本：v" .. remoteVersion
            statusLabel.colors.text = 0x00AA00
            detailsLabel.text = "新版本 " .. remoteVersion .. " 可用！\n当前版本：" .. CURRENT_VERSION .. "\n\n点击'下载并安装'进行更新。"
            
            -- 下载按钮
            local downloadBtn = GUI.button(0, 0, 20, 3, "下载并安装")
            downloadBtn.onTouch = function()
                progressBar.value = 20
                progressBar.maximumValue = 100
                workspace:draw()
                
                statusLabel.text = "正在下载..."
                detailsLabel.text = "请稍候..."
                
                local success, result = downloadUpdate()
                
                if success then
                    progressBar.value = 100
                    workspace:draw()
                    statusLabel.text = "✓ 下载完成"
                    detailsLabel.text = "更新下载成功！\n\n文件：" .. result .. "\n\n运行此文件以安装更新。"
                else
                    progressBar.value = 0
                    workspace:draw()
                    statusLabel.text = "✗ 下载失败"
                    detailsLabel.text = result
                end
            end
            buttonContainer:addChild(downloadBtn)
            
        elseif comparison == 0 then
            -- 已是最新版本
            statusLabel.text = "✓ 已是最新版本"
            statusLabel.colors.text = 0x00AA00
            detailsLabel.text = "当前版本：" .. CURRENT_VERSION .. "\n\n您的系统已是最新！"
            
        else
            -- 当前版本更新（开发版）
            statusLabel.text = "ℹ 您使用的是开发版本"
            statusLabel.colors.text = 0x3366CC
            detailsLabel.text = "当前版本：" .. CURRENT_VERSION .. "\n最新稳定版：" .. remoteVersion .. "\n\n您使用的是较新的开发版本。"
        end
    end
    
    -- 刷新按钮
    local refreshBtn = GUI.button(22, 0, 12, 3, "刷新")
    refreshBtn.onTouch = function()
        buttonContainer:removeChildren()
        statusLabel.text = "正在检查..."
        detailsLabel.text = ""
        progressBar.value = 0
        checkForUpdates()
    end
    buttonContainer:addChild(refreshBtn)
    
    -- 关闭按钮
    local closeBtn = GUI.button(36, 0, 10, 3, "关闭")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    buttonContainer:addChild(closeBtn)
    
    -- 开始检查
    checkForUpdates()
    
    return window
end

return application
