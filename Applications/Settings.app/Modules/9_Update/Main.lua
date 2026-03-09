local GUI = require("GUI")
local system = require("System")

local module = {}

module.name = "System Update"
module.icon = "Icons/applications.png"  -- 使用通用应用图标
module.category = "System"

function module.open(parentX, parentY, parentWidth, parentHeight)
    -- 启动系统更新应用
    local updateApp = require("Applications/SystemUpdate.app/Main")
    if updateApp and updateApp.main then
        updateApp.main()
    end
end

return module
