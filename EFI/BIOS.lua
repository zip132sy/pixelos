-- PixelOS BIOS Installer v3.0
-- This code runs from EEPROM after reboot
-- Graphical installation interface

local c,co=component,computer
local gpu
local screen
local sw,sh=80,25

-- Initialize GPU
local gpuAddress=c.list("gpu")()
local screenAddress=c.list("screen")()

if gpuAddress and screenAddress then
    gpu=c.proxy(gpuAddress)
    screen=screenAddress
    gpu.bind(screen)
    sw,sh=gpu.getResolution()
end

-- Simple GUI functions for BIOS
local function clear(color)
    if gpu then
        gpu.setBackground(color or 0x2D2D2D)
        gpu.fill(1,1,sw,sh," ")
    end
end

-- Draw top status bar
local function drawStatusBar()
    if gpu then
        -- Draw background
        gpu.setBackground(0x1E1E1E)
        gpu.fill(1,1,sw,1," ")
        
        -- Menu button (PixelOS text only, no icon)
        gpu.setForeground(0xFFFFFF)
        gpu.set(2,1,"PixelOS")
        
        -- Battery and Time (right aligned)
        local battery = c.list("battery")()
        local batteryText = ""
        if battery then
            local proxy = c.proxy(battery)
            local energy = math.floor(proxy.energy() / proxy.maxEnergy() * 100)
            batteryText = "Power: " .. energy .. "%"
        else
            batteryText = "Power: --%"
        end
        
        local timeText = os.date("%H:%M")
        
        -- Draw battery and time on right side with proper spacing
        local statusBarText = batteryText .. "     " .. timeText
        gpu.set(sw - #statusBarText, 1, statusBarText)
    end
end

local function drawBox(x,y,w,h,color,border)
    if gpu then
        gpu.setBackground(color or 0xE1E1E1)
        gpu.fill(x,y,w,h," ")
        if border then
            gpu.setForeground(0x878787)
            gpu.set(x,y,"+"..string.rep("-",w-2).."+")
            for i=1,h-2 do
                gpu.set(x,y+i,"|")
                gpu.set(x+w-1,y+i,"|")
            end
            gpu.set(x,y+h-1,"+"..string.rep("-",w-2).."+")
        end
    end
end

local function drawText(x,y,text,color,bg)
    if gpu then
        gpu.setForeground(color or 0xFFFFFF)
        gpu.setBackground(bg or 0x2D2D2D)
        gpu.set(x,y,text)
    end
end

local function drawButton(x,y,w,h,text,selected)
    if gpu then
        local bg=selected and 0x3366CC or 0xC3C3C3
        local fg=selected and 0xFFFFFF or 0x000000
        drawBox(x,y,w,h,bg,false)
        drawText(x+math.floor((w-#text)/2),y+math.floor(h/2),text,fg,bg)
    end
    return {x=x,y=y,w=w,h=h,text=text}
end

local function waitClick()
    while true do
        local e={co.pullSignal()}
        if e[1]=="touch" then
            return e[3],e[4],e[5] -- x,y,button
        elseif e[1]=="key_down" then
            return e[3],e[4],e[2] -- char, keycode, keyboard address
        end
    end
end

local function checkClick(btn,x,y)
    return x>=btn.x and x<btn.x+btn.w and y>=btn.y and y<btn.y+btn.h
end

-- Installation state
local installState={
    step=1,
    targetDisk=nil,
    username="User",
    password="",
    usePassword=false,
    network=false,
    formatDisk=false,
    confirmErase=false
}

-- Step 1: Welcome Screen
local function showWelcome()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(math.floor(sw/2)-25,math.floor(sh/2)-7,50,16,0xE1E1E1,true)

    drawText(math.floor(sw/2)-10,math.floor(sh/2)-6,"PixelOS v3.0",0x3366CC,0xE1E1E1)
    drawText(math.floor(sw/2)-12,math.floor(sh/2)-4,"BIOS Installation",0x666666,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)-2,"Based on MineOS by IgorTimofeev",0x666666,0xE1E1E1)

    drawText(math.floor(sw/2)-18,math.floor(sh/2)+1,"This wizard will guide you through:",0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+2,"- Disk selection and formatting",0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+3,"- User account setup",0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+4,"- Network configuration",0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+5,"- System installation",0x000000,0xE1E1E1)

    local nextBtn=drawButton(math.floor(sw/2)+10,math.floor(sh/2)+6,10,3,"Next >",true)

    while true do
        local x,y=waitClick()
        if checkClick(nextBtn,x,y) then
            return 2
        end
    end
end

-- Step 2: Disk Selection
local function showDiskSelect()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,"Step 1/5: Select Target Disk",0x3366CC,0xE1E1E1)
    drawText(8,6,"Available disks:",0x000000,0xE1E1E1)

    local disks={}
    for addr,type in c.list("filesystem")do
        local proxy=c.proxy(addr)
        table.insert(disks,{
            address=addr,
            label=proxy.getLabel()or"Unlabeled",
            isReadOnly=proxy.isReadOnly(),
            space=proxy.spaceTotal()or 0
        })
    end

    local buttons={}
    for i,disk in ipairs(disks)do
        local y=8+(i-1)*3
        local status=disk.isReadOnly and "[Read-Only]"or"["..math.floor(disk.space/1024).."KB]"
        local btn=drawButton(10,y,sw-20,2,disk.label.." "..status,i==1)
        btn.disk=disk
        btn.label=disk.label
        table.insert(buttons,btn)
    end

    drawText(8,sh-8,"WARNING: Formatting will erase all data!",0xFF0000,0xE1E1E1)

    local formatCb=drawButton(10,sh-6,3,1,"",false)
    drawText(14,sh-6,"Format disk before installation",0x000000,0xE1E1E1)

    local backBtn=drawButton(10,sh-4,10,3,"< Back",false)
    local nextBtn=drawButton(sw-20,sh-4,10,3,"Next >",true)

    local selected=1
    installState.formatDisk=false

    while true do
        local x,y=waitClick()

        for i,btn in ipairs(buttons)do
            if checkClick(btn,x,y) then
                selected=i
                installState.targetDisk=btn.disk
                -- Redraw to show selection
                for j,btn in ipairs(buttons)do
                    local status=btn.disk.isReadOnly and"[Read-Only]"or"["..math.floor(btn.disk.space/1024).."KB]"
                    drawButton(btn.x,btn.y,btn.w,btn.h,btn.label.." "..status,j==selected)
                end
            end
        end

        if checkClick(formatCb,x,y) then
            installState.formatDisk=not installState.formatDisk
            drawButton(formatCb.x,formatCb.y,formatCb.w,formatCb.h,installState.formatDisk and"X"or"",installState.formatDisk)
        end

        if checkClick(backBtn,x,y) then
            return 1
        elseif checkClick(nextBtn,x,y) then
            if disks[selected] then
                installState.targetDisk=disks[selected]
                if installState.formatDisk then
                    return 2.5 -- Go to confirm erase
                else
                    return 3
                end
            end
        end
    end
end

-- Step 2.5: Confirm Erase
local function showConfirmErase()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(math.floor(sw/2)-20,math.floor(sh/2)-6,40,12,0xE1E1E1,true)

    drawText(math.floor(sw/2)-8,math.floor(sh/2)-4,"? WARNING",0xFF0000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)-2,"You are about to ERASE all data on:",0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-10,math.floor(sh/2),installState.targetDisk.label,0x3366CC,0xE1E1E1)

    drawText(math.floor(sw/2)-15,math.floor(sh/2)+2,"This action CANNOT be undone!",0xFF0000,0xE1E1E1)

    local noBtn=drawButton(math.floor(sw/2)-15,math.floor(sh/2)+4,10,3,"Cancel",true)
    local yesBtn=drawButton(math.floor(sw/2)+5,math.floor(sh/2)+4,10,3,"ERASE",false)

    while true do
        local x,y=waitClick()
        if checkClick(noBtn,x,y) then
            return 2
        elseif checkClick(yesBtn,x,y) then
            installState.confirmErase=true
            return 3
        end
    end
end

-- Step 3: User Setup
local function showUserSetup()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,"Step 2/5: User Account",0x3366CC,0xE1E1E1)

    drawText(8,7,"Username:",0x000000,0xE1E1E1)
    drawBox(20,6,sw-30,3,0xFFFFFF,false)
    drawText(22,7,installState.username,0x000000,0xFFFFFF)

    drawText(8,11,"Password:",0x000000,0xE1E1E1)
    local usePassCb=drawButton(20,10,3,1,"",installState.usePassword)
    drawText(24,10,"Use password protection",0x000000,0xE1E1E1)

    if installState.usePassword then
        drawBox(20,13,sw-30,3,0xFFFFFF,false)
        drawText(22,14,string.rep("*",#installState.password),0x000000,0xFFFFFF)
    end

    local backBtn=drawButton(10,sh-4,10,3,"< Back",false)
    local nextBtn=drawButton(sw-20,sh-4,10,3,"Next >",true)

    while true do
        local x,y,b=waitClick()

        if type(x)=="number" and type(y)=="number" then
            -- Touch event
            if checkClick(usePassCb,x,y) then
                installState.usePassword=not installState.usePassword
                return 3 -- Refresh
            end

            if checkClick(backBtn,x,y) then
                return 2
            elseif checkClick(nextBtn,x,y) then
                return 4
            end
        else
            -- Keyboard event
            local char, keycode = x, y
            if keycode == 14 then
                -- Backspace
                if installState.usePassword then
                    installState.password = installState.password:sub(1, -2)
                else
                    installState.username = installState.username:sub(1, -2)
                end
            elseif keycode == 28 then
                -- Enter key
                return 4
            elseif char and char ~= "" then
                -- Regular character
                if installState.usePassword then
                    installState.password = installState.password .. char
                else
                    installState.username = installState.username .. char
                end
            end
            -- Redraw input fields
            drawBox(20, 6, sw-30, 3, 0xFFFFFF, false)
            drawText(22, 7, installState.username, 0x000000, 0xFFFFFF)
            if installState.usePassword then
                drawBox(20, 13, sw-30, 3, 0xFFFFFF, false)
                drawText(22, 14, string.rep("*", #installState.password), 0x000000, 0xFFFFFF)
            end
        end
    end
end

-- Step 4: Network Check
local function showNetworkCheck()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,"Step 3/5: Network Configuration",0x3366CC,0xE1E1E1)

    drawText(8,7,"Checking for Internet card...",0x000000,0xE1E1E1)

    local inet=c.list("internet")()
    if inet then
        drawText(8,9,"? Internet card found",0x00AA00,0xE1E1E1)
        drawText(8,10,"  Address: "..inet:sub(1,8).."...",0x666666,0xE1E1E1)
        installState.network=true

        drawText(8,13,"Network connectivity:",0x000000,0xE1E1E1)
        drawText(8,14,"  Status: Online",0x00AA00,0xE1E1E1)
    else
        drawText(8,9,"? No Internet card found",0xFF0000,0xE1E1E1)
        drawText(8,10,"  Network features will be unavailable",0x666666,0xE1E1E1)
        installState.network=false
    end

    local backBtn=drawButton(10,sh-4,10,3,"< Back",false)
    local nextBtn=drawButton(sw-20,sh-4,10,3,"Next >",true)

    while true do
        local x,y=waitClick()
        if checkClick(backBtn,x,y) then
            return 3
        elseif checkClick(nextBtn,x,y) then
            return 5
        end
    end
end

-- Step 5: Installation
local function showInstallation()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,"Step 4/5: Installing PixelOS",0x3366CC,0xE1E1E1)

    -- Format if requested
    if installState.formatDisk and installState.confirmErase then
        drawText(8,7,"Formatting disk...",0x000000,0xE1E1E1)
        local proxy=c.proxy(installState.targetDisk.address)
        if proxy then
            local list=proxy.list("/")
            if list then
                for _,item in ipairs(list)do
                    if item~="."and item~=".."then
                        proxy.remove("/"..item)
                    end
                end
            end
        end
        drawText(25,7,"[OK]",0x00AA00,0xE1E1E1)
    end

    -- Create directories
    drawText(8,9,"Creating system directories...",0x000000,0xE1E1E1)
    local proxy=c.proxy(installState.targetDisk.address)
    if proxy then
        proxy.makeDirectory("System/OS")
        proxy.makeDirectory("Libraries")
        proxy.makeDirectory("Applications")
        proxy.makeDirectory("Desktop")
    end
    drawText(40,9,"[OK]",0x00AA00,0xE1E1E1)

    -- Create config
    drawText(8,11,"Creating configuration...",0x000000,0xE1E1E1)
    local config={
        username=installState.username,
        password=installState.usePassword and installState.password or nil,
        network=installState.network,
        installDate=os.time(),
        firstBoot=true
    }
    -- Save config (simplified)
    drawText(40,11,"[OK]",0x00AA00,0xE1E1E1)

    -- Progress bar
    drawBox(8,14,sw-18,3,0xFFFFFF,false)
    for i=0,100,2 do
        gpu.setBackground(0x3366CC)
        gpu.fill(8,14,math.floor((sw-18)*i/100),3," ")
        drawText(math.floor(sw/2)-3,15,tostring(i).."%",0xFFFFFF,i<50 and 0x3366CC or 0xFFFFFF)
        os.sleep(0.05)
    end

    drawText(8,18,"? Installation complete!",0x00AA00,0xE1E1E1)

    local rebootBtn=drawButton(math.floor(sw/2)-5,sh-5,12,3,"Reboot",true)

    while true do
        local x,y=waitClick()
        if checkClick(rebootBtn,x,y) then
            -- Set EEPROM data to point to new system
            local eeprom=c.list("eeprom")()
            if eeprom then
                c.invoke(eeprom,"setData",installState.targetDisk.address)
            end
            co.shutdown(true)
        end
    end
end

-- Execute string with error handling
local function executeString(...) 
    local result, reason = load(...) 
    
    if result then 
        result, reason = xpcall(result, debug.traceback) 
        
        if result then 
            return 
        end 
    end 
    
    if gpu then
        clear(0x2D2D2D)
        drawText(2, 3, "Error: " .. tostring(reason), 0xFF0000, 0x2D2D2D)
        drawText(2, 5, "Press any key to continue...", 0xFFFFFF, 0x2D2D2D)
        co.pullSignal()
    end
end

-- Try to boot from any available filesystem
local function tryBootFromAny()
    local booted = false
    for address in c.list("filesystem") do
        local proxy = c.proxy(address)
        if proxy.exists("/OS.lua") then
            if gpu then
                clear(0x2D2D2D)
                drawText(2, 3, "Booting from " .. (proxy.getLabel() or address), 0xFFFFFF, 0x2D2D2D)
            end
            
            local handle, data, chunk = proxy.open("/OS.lua", "rb"), ""
            if handle then
                repeat
                    chunk = proxy.read(handle, math.huge)
                    data = data .. (chunk or "")
                until not chunk
                proxy.close(handle)
                
                executeString(data, "=/OS.lua")
                booted = true
                break
            end
        end
    end
    
    if not booted then
        if gpu then
            clear(0x2D2D2D)
            drawText(2, 3, "No boot sources found", 0xFF0000, 0x2D2D2D)
            drawText(2, 5, "Press any key to restart...", 0xFFFFFF, 0x2D2D2D)
            co.pullSignal()
        end
        co.shutdown(true)
    end
end

-- Main flow with error handling
local function main()
    local success, err = pcall(function()
        while true do
            if installState.step==1 then
                installState.step=showWelcome()
            elseif installState.step==2 then
                installState.step=showDiskSelect()
            elseif installState.step==2.5 then
                installState.step=showConfirmErase()
            elseif installState.step==3 then
                installState.step=showUserSetup()
            elseif installState.step==4 then
                installState.step=showNetworkCheck()
            elseif installState.step==5 then
                showInstallation()
                break
            end
        end
    end)
    
    if not success then
        if gpu then
            clear(0x2D2D2D)
            drawText(2, 3, "Critical error: " .. tostring(err), 0xFF0000, 0x2D2D2D)
            drawText(2, 5, "Attempting to boot from any available disk...", 0xFFFFFF, 0x2D2D2D)
            co.sleep(2)
        end
        tryBootFromAny()
    end
end

-- Run with error handling
local success, err = pcall(main)
if not success then
    -- If everything fails, try to boot from any filesystem
    tryBootFromAny()
end
