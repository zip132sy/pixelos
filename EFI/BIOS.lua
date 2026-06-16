local c=component or {}
local co=computer or {}
local g,w,h=nil,80,25
local gl=function(t)local i=c.list(t)return i or function()end end
local ga,sa=gl("gpu")(),gl("screen")()
if ga and sa then g=c.proxy(ga)g.bind(sa)w,h=g.getResolution()end
local function dt(x,y,t,f,b)if g then if f then g.setForeground(f)end if b then g.setBackground(b)end g.set(x,y,t)end end
local function clr()if g then g.setBackground(0x2D2D2D)g.fill(1,1,w,h," ")end end
local function ds()if g then g.setBackground(0x1E1E1E)g.fill(1,1,w,1," ")dt(2,1,"PixelOS",0xFFFFFF,0x1E1E1E)end end
local function autoBoot()
 local ep=gl("eeprom")()
 local ba=ep and c.invoke(ep,"getData")or""
 local d={}
 for addr in gl("filesystem")do
  local px=c.proxy(addr)
  if px and px.exists and(px.exists("/OS.lua")or px.exists("/init.lua"))then
   table.insert(d,{a=addr,p=px})
  end
 end
 local sel=d[1]
 for i,v in ipairs(d)do if v.a==ba then sel=v break end end
 if sel then
  local px=sel.p
  local fn=px.exists("/OS.lua")and"/OS.lua"or"/init.lua"
  local h=px.open(fn,"rb")if h then
   local data=""local ch repeat ch=px.read(h,math.huge)data=data..(ch or"")until not ch px.close(h)
   if ep then c.invoke(ep,"setData",sel.a)end
   local fn,err=load(data,"="..fn)if fn then pcall(fn)end
  end
 end
end
local function loadMgr()
 for addr in gl("filesystem")do
  local px=c.proxy(addr)
  if px and px.exists and px.exists("/BIOS/Manager.lua")then
   local h=px.open("/BIOS/Manager.lua","rb")if h then
    local data=""local ch repeat ch=px.read(h,math.huge)data=data..(ch or"")until not ch px.close(h)
    local fn,err=load(data,"=/BIOS/Manager.lua")if fn then pcall(fn)return true end
   end
  end
 end
end
clr()ds()
dt(math.floor(w/2)-9,math.floor(h/2)-2,"按 F12 进入 BIOS 设置",0xFFFFFF,0x2D2D2D)
local tmo=5
while tmo>0 do
 dt(math.floor(w/2)-1,math.floor(h/2),tmo.."s",0x00FF00,0x2D2D2D)
 dt(math.floor(w/2)-8,math.floor(h/2)+1,"Enter-启动 Esc-跳过",0x878787,0x2D2D2D)
 for i=1,20 do
  local e={co.pullSignal()}
  if e and e[1]=="key_down"then
   if e[4]==88 then loadMgr()return
   elseif e[4]==28 then autoBoot()return
   elseif e[4]==27 then tmo=0 break end
  end
 end
 tmo=tmo-1
end
autoBoot()