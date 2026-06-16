local c=component or {}
local co=computer or {}
local g,w,h=nil,80,25
local gl=function(t)local i=c.list(t)return i or function()end end
local ga,sa=gl("gpu")(),gl("screen")()
if ga and sa then g=c.proxy(ga)g.bind(sa)w,h=g.getResolution()end
local function dt(x,y,t,f,b)if g then if f then g.setForeground(f)end if b then g.setBackground(b)end g.set(x,y,t)end end
local function clr()if g then g.setBackground(0x2D2D2D)g.fill(1,1,w,h," ")end end
local function ds()if g then g.setBackground(0x1E1E1E)g.fill(1,1,w,1," ")dt(2,1,"PixelOS",0xFFFFFF,0x1E1E1E)end end
local function detectOS(px)
 local hasOS=px.exists("/OS.lua")
 local hasInit=px.exists("/init.lua")
 if hasOS then
  local h=px.open("/OS.lua","rb")
  if h then
   local data=px.read(h,100)or""
   px.close(h)
   if data:find("PixelOS")then return"PixelOS"end
   if data:find("MineOS")then return"MineOS"end
   return"OS.lua"
  end
 elseif hasInit then
  return"OpenOS"
 end
 return"?"
end
local function autoBoot()
 clr()ds()
 local ep=gl("eeprom")()
 local ba=ep and c.invoke(ep,"getData")or""
 local d={}
 for addr in gl("filesystem")do
  local px=c.proxy(addr)
  if px and px.exists then
   if px.exists("/OS.lua")or px.exists("/init.lua")then
    table.insert(d,{a=addr,p=px,t=detectOS(px)})
   end
  end
 end
 if #d==0 then
  dt(math.floor(w/2)-7,math.floor(h/2),"未找到可启动设备",0xFF0000,0x2D2D2D)
  dt(math.floor(w/2)-5,math.floor(h/2)+2,"按任意键关机",0x878787,0x2D2D2D)
  co.pullSignal()
  co.shutdown(true)
  return
 end
 local sel=d[1]
 local selType=d[1].t
 for i,v in ipairs(d)do
  if v.a==ba then sel=v selType=v.t break end
 end
 dt(math.floor(w/2)-9,math.floor(h/2),selType,0x00FF00,0x2D2D2D)
 dt(math.floor(w/2)-12,math.floor(h/2)+1,"正在启动: "..(sel.p.getLabel()or"Unnamed"),0xFFFFFF,0x2D2D2D)
 local px=sel.p
 local fn=px.exists("/OS.lua")and"/OS.lua"or"/init.lua"
 local h=px.open(fn,"rb")
 if not h then
  dt(math.floor(w/2)-6,math.floor(h/2)+3,"无法打开启动文件",0xFF0000,0x2D2D2D)
  co.sleep(2)
  co.shutdown(true)
  return
 end
 local data=""local ch repeat ch=px.read(h,math.huge)data=data..(ch or"")until not ch px.close(h)
 if ep then c.invoke(ep,"setData",sel.a)end
 local fn,err=load(data,"="..fn)
 if not fn then
  dt(math.floor(w/2)-6,math.floor(h/2)+3,"启动文件加载失败",0xFF0000,0x2D2D2D)
  co.sleep(2)
  co.shutdown(true)
  return
 end
 local ok,err=pcall(fn)
 if not ok then
  clr()ds()
  dt(math.floor(w/2)-8,math.floor(h/2),"启动失败",0xFF0000,0x2D2D2D)
  dt(math.floor(w/2)-15,math.floor(h/2)+2,"按任意键返回 BIOS",0x878787,0x2D2D2D)
  co.pullSignal()
 else
  while true do co.pullSignal()end
 end
end
local function loadMgr()
 for addr in gl("filesystem")do
  local px=c.proxy(addr)
  if px and px.exists and px.exists("/BIOS/Manager.lua")then
   local h=px.open("/BIOS/Manager.lua","rb")
   if h then
    local data=""local ch repeat ch=px.read(h,math.huge)data=data..(ch or"")until not ch px.close(h)
    local fn,err=load(data,"=/BIOS/Manager.lua")
    if fn then pcall(fn)while true do co.pullSignal()end end
   end
  end
 end
 dt(math.floor(w/2)-9,math.floor(h/2),"BIOS管理器未找到",0xFF0000,0x2D2D2D)
 co.sleep(2)
end
clr()ds()
dt(math.floor(w/2)-11,math.floor(h/2)-2,"按 F12 进入 PixelOS BIOS",0xFFFFFF,0x2D2D2D)
local tmo=5
while tmo>0 do
 dt(math.floor(w/2)-1,math.floor(h/2),tmo.."s",0x00FF00,0x2D2D2D)
 dt(math.floor(w/2)-6,math.floor(h/2)+1,"Enter-启动",0x878787,0x2D2D2D)
 for i=1,20 do
  local e={co.pullSignal()}
  if e and e[1]=="key_down"then
   if e[4]==88 then loadMgr()return
   elseif e[4]==28 then autoBoot()return end
  end
 end
 tmo=tmo-1
end
autoBoot()