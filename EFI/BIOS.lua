local c=component or{}
local co=computer or{}
local g,w,h=nil,80,25
local gl=function(t)local i=c.list(t)return i or function()end end
local ga,sa=gl("gpu")(),gl("screen")()
if ga and sa then g=c.proxy(ga)g.bind(sa)w,h=g.getResolution()end
local function dt(x,y,t,f,b)if g then if f then g.setForeground(f)end if b then g.setBackground(b)end g.set(x,y,t)end end
local function clr()if g then g.setBackground(0x2D2D2D)g.fill(1,1,w,h," ")end end
local function ds()if g then g.setBackground(0x1E1E1E)g.fill(1,1,w,1," ")dt(2,1,"PixelOS BIOS",0xFFFFFF,0x1E1E1E)end end
local function det(p)
 local h=p.exists("/OS.lua")and p.open("/OS.lua","rb")
 if h then local d=p.read(h,200)or""p.close(h)if d:find("PixelOS")then return"PixelOS"end if d:find("MineOS")or d:find("Pizda")then return"MineOS"end return"OS.lua"end
 if p.exists("/init.lua")then return"OpenOS"end return"?"
end
local function gd()
 local e=gl("eeprom")()local b=e and c.invoke(e,"getData")or""local d={}
 for a in gl("filesystem")do local p=c.proxy(a)if p and p.exists and(p.exists("/OS.lua")or p.exists("/init.lua"))then table.insert(d,{a=a,p=p,t=det(p),l=p.getLabel()or"?"})end end
 table.sort(d,function(x,y)if x.a==b then return true end if y.a==b then return false end return x.l<y.l end)return d
end
local function bt(d)
 local fn=d.p.exists("/OS.lua")and"/OS.lua"or"/init.lua"local h=d.p.open(fn,"rb")
 if not h then return false end
 local data=""local ch repeat ch=d.p.read(h,math.huge)data=data..(ch or"")until not ch d.p.close(h)
 local e=gl("eeprom")()if e then c.invoke(e,"setData",d.a)end
 local f=load(data,"="..fn)if f then pcall(f)return true end return false
end
local function lm()
 for a in gl("filesystem")do local p=c.proxy(a)if p then
  if p.exists("/BIOS/Manager.lua")then
   local h=p.open("/BIOS/Manager.lua","rb")
   if h then
    local data=""local ch repeat ch=p.read(h,math.huge)data=data..(ch or"")until not ch p.close(h)
    local f=load(data,"=/BIOS/Manager.lua")
    if f then pcall(f)while true do co.pullSignal()end end
   end
  end
 end end
 clr()ds()
 dt(2,h-2,"Press any key to continue...",0x696969,0x2D2D2D)
 dt(math.floor(w/2)-9,math.floor(h/2),"Mgr not found",0xFF0000,0x2D2D2D)
 dt(math.floor(w/2)-12,math.floor(h/2)+1,"F12: Retry",0xFFDB80,0x2D2D2D)
 local e={co.pullSignal()}
end
local function qb()
 local d=gd()local tmo=10
 while tmo>=0 do
  clr()ds()
  dt(2,1,"PixelOS BIOS",0xFFFFFF,0x1E1E1E)
  dt(2,h,"F12: BIOS Manager",0x878787,0x1E1E1E)
  local lp=d[1]and d[1].l or"none"
  local cd="Auto boot in "..tmo.."s... Last: "..lp
  dt(math.floor(w/2)-math.floor(#cd/2),math.floor(h/2),cd,0xFFDB80,0x2D2D2D)
  for i=1,20 do
   local e={co.pullSignal(0.05)}
   if e and e[1]=="key_down"then
    if e[4]==87 or e[4]==88 then lm()return end
   end
  end
  tmo=tmo-1
 end
 if #d>0 then bt(d[1])end
end
pcall(qb)
