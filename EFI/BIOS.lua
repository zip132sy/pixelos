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
 clr()ds()dt(math.floor(w/2)-9,math.floor(h/2),d.t,0x00FF00,0x2D2D2D)dt(math.floor(w/2)-12,math.floor(h/2)+1,"Boot: "..d.l,0xFFFFFF,0x2D2D2D)
 local fn=d.p.exists("/OS.lua")and"/OS.lua"or"/init.lua"local h=d.p.open(fn,"rb")
 if not h then dt(math.floor(w/2)-6,math.floor(h/2)+3,"Cannot open",0xFF0000,0x2D2D2D)co.sleep(2)co.shutdown(true)return end
 local data=""local ch repeat ch=d.p.read(h,math.huge)data=data..(ch or"")until not ch d.p.close(h)
 local e=gl("eeprom")()if e then c.invoke(e,"setData",d.a)end
 local f=load(data,"="..fn)if not f then dt(math.floor(w/2)-6,math.floor(h/2)+3,"Load fail",0xFF0000,0x2D2D2D)co.sleep(2)co.shutdown(true)return end
 local ok,err=pcall(f)if not ok then clr()ds()dt(math.floor(w/2)-8,math.floor(h/2),"Boot fail",0xFF0000,0x2D2D2D)dt(math.floor(w/2)-13,math.floor(h/2)+2,"Press any key",0x878787,0x2D2D2D)co.pullSignal()else while true do co.pullSignal()end end
end
local function lm()
 for a in gl("filesystem")do local p=c.proxy(a)if p and p.exists and p.exists("/BIOS/Manager.lua")then local h=p.open("/BIOS/Manager.lua","rb")
  if h then local data=""local ch repeat ch=p.read(h,math.huge)data=data..(ch or"")until not ch p.close(h)local f=load(data,"=/BIOS/Manager.lua")if f then pcall(f)while true do co.pullSignal()end end end
 end end
 dt(math.floor(w/2)-9,math.floor(h/2),"Mgr not found",0xFF0000,0x2D2D2D)co.sleep(2)
end
local function mn()
 local d=gd()local si=1 local t=#d+2
 while true do
  clr()ds()dt(2,1,"PixelOS BIOS - Boot Menu",0xFFFFFF,0x1E1E1E)dt(2,h,"Up/Down Enter F12",0x878787,0x1E1E1E)
  for i,v in ipairs(d)do local y=3+i if y<h-1 then local s=i==si if s then g.setBackground(0x007ACC)g.fill(2,y,w-2,1," ")end
   dt(4,y,(s and">"or" ")..v.l,s and 0xFFFFFF or 0xCCCCCC,s and 0x007ACC or 0x2D2D2D)dt(w-#v.t-2,y,"["..v.t.."]",s and 0xAADDFF or 0x888888,s and 0x007ACC or 0x2D2D2D)end end
  local r=3+#d+1 if r<h then local s=si==#d+1 if s then g.setBackground(0x007ACC)g.fill(2,r,w-2,1," ")end dt(4,r,(s and">"or" ").."Reboot",s and 0xFFFFFF or 0xCCCCCC,s and 0x007ACC or 0x2D2D2D)end
  local s=3+#d+2 if s<h then local x=si==#d+2 if x then g.setBackground(0x007ACC)g.fill(2,s,w-2,1," ")end dt(4,s,(x and">"or" ").."Shutdown",x and 0xFFFFFF or 0xCCCCCC,x and 0x007ACC or 0x2D2D2D)end
  local e={co.pullSignal()}if e and e[1]=="key_down"then
   if e[4]==200 and si>1 then si=si-1 elseif e[4]==208 and si<t then si=si+1 elseif e[4]==88 then lm()return
   elseif e[4]==28 then if si<=#d then bt(d[si])return elseif si==#d+1 then co.shutdown(false)else co.shutdown(true)end end
  end
 end
end
pcall(mn)
