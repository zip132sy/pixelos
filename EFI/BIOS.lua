local c=component or {} local co=computer or {}
local gpu,sw,sh=nil,80,25
local function gl(t)local i=c.list(t)return i or function()end end
local loc={t="PixelOS",sb="选择:",nb="无启动",pr="任意键",bt="启动",pwd="密码:",inv="无效"}
local ga=gl("gpu")() local sa=gl("screen")()
if ga and sa then gpu=c.proxy(ga) gpu.bind(sa) sw,sh=gpu.getResolution()end
local function clr()if gpu then gpu.setBackground(0x2D2D2D)gpu.fill(1,1,sw,sh," ")end end
local function dt(x,y,t,f,b)if gpu then if f then gpu.setForeground(f)end if b then gpu.setBackground(b)end gpu.set(x,y,t)end end
local function ds()if gpu then gpu.setBackground(0x1E1E1E)gpu.fill(1,1,sw,1," ")dt(2,1,loc.t,0xFFFFFF,0x1E1E1E)end end
local function hsh(s)local r=1 for i=1,#s do r=r*7+s:byte(i)end return r end
local function chkEnc(fs)return fs and fs.exists and fs.exists("/.bios_pwd")end
local function getPwd(fs)if not chkEnc(fs)then return nil end local h=fs.open("/.bios_pwd","rb")local d=""local ch repeat ch=fs.read(h,256)if ch then d=d..ch end until not ch fs.close(h)return d end
local function inpPwd()
 clr()ds()dt(math.floor(sw/2)-8,math.floor(sh/2)-2,loc.pwd,0xFFFFFF,0x2D2D2D)
 local p=""
 while true do
 local line=""for i=1,#p do line=line.."*"end
 dt(math.floor(sw/2)-#line/2,math.floor(sh/2),line,0xFFFFFF,0x2D2D2D)
 local e={co.pullSignal()}
 if e[1]=="key_down"then
 if e[4]==28 then return p elseif e[4]==14 then p=p:sub(1,-2)else local ch=string.char(e[3])if ch:match("^[%w%d%p%s]+")then p=p..ch end end
 end
 end
end
local function bd()
 local d={}local ep=gl("eeprom")()local ba=ep and c.invoke(ep,"getData")
 for addr in gl("filesystem")do
 local px=c.proxy(addr)
 if px and px.exists and(px.exists("/OS.lua")or px.exists("/init.lua"))then
 table.insert(d,{a=addr,l=px.getLabel()or"Unnamed",b=addr==ba,o=px.exists("/OS.lua"),p=px})
 end
 end
 table.sort(d,function(x,y)if x.b~=y.b then return x.b end return x.l<y.l end)
 return d
end
local function bt(disk)
 if gpu then clr()ds()dt(math.floor(sw/2)-8,math.floor(sh/2),loc.bt.." "..disk.l,0xFFFFFF,0x2D2D2D)end
 local px=c.proxy(disk.a)if not px then return false end
 local h=px.open(disk.o and"/OS.lua"or"/init.lua","rb")if not h then return false end
 local dt=""local ch repeat ch=px.read(h,math.huge)dt=dt..(ch or"")until not ch px.close(h)
 local ep=gl("eeprom")()if ep and c.invoke(ep,"getData")~=disk.a then c.invoke(ep,"setData",disk.a)end
 local r,e=load(dt)if r then r,e=xpcall(r,function(err)return err end)if r then return true end end
 return false,e
end
local function sm()
 local d=bd()
 if #d==0 then clr()ds()dt(math.floor(sw/2)-6,math.floor(sh/2),loc.nb,0xFF0000,0x2D2D2D)dt(math.floor(sw/2)-7,math.floor(sh/2)+2,loc.pr,0xFFFFFF,0x2D2D2D)while true do if(co.pullSignal())then co.shutdown(true)return end end end
 local fs=d[1].p
 if chkEnc(fs)then
 local stored=getPwd(fs)
 while true do
 local input=inpPwd()
 if hsh(input)==tonumber(stored)then break end
 clr()ds()dt(math.floor(sw/2)-6,math.floor(sh/2),loc.inv,0xFF0000,0x2D2D2D)dt(math.floor(sw/2)-7,math.floor(sh/2)+2,loc.pr,0xFFFFFF,0x2D2D2D)co.pullSignal()
 end
 end
 while true do
 clr()ds()dt(8,3,loc.sb,0xFFFFFF,0x2D2D2D)
 local mi={}for i,v in ipairs(d)do table.insert(mi,{t=(v.b and">"or" ")..v.l,d=v})end
 table.insert(mi,{t=" 关机 [Off]",a="sd"})
 local si=1
 while true do
 for i,v in ipairs(mi)do local y=4+i if i==si then dt(2,y,v.t,0xE1E1E1,0x878787)else dt(2,y,v.t,0x878787,0x2D2D2D)end end
 local e={co.pullSignal()}
 if e[1]=="key_down"then
 if e[4]==200 and si>1 then si=si-1 elseif e[4]==208 and si<#mi then si=si+1 elseif e[4]==28 then
 local s=mi[si]
 if s.a=="sd"then co.shutdown(true)return elseif s.d then bt(s.d)return end
 end
 end
 end
 end
end
pcall(sm)