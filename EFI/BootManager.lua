local comp,gpu=component,comp.proxy(comp.list("gpu")())
local screen=comp.list("screen")()
gpu.bind(screen)
local sw,sh=gpu.getResolution()
local cp="/System/OS/bios.cfg"
local cfg={bd=3,bi={},df=nil}
local fs=comp.proxy(comp.list("filesystem")())

local function lc()
  if fs.exists(cp)then local f=fs.open(cp,"r")if f then local d=fs.read(f)fs.close(f)local fn=load("return "..d)if fn then cfg=fn()end end end
end

local function sc()
  local s="{"
  for k,v in pairs(cfg)do
    if type(v)~="function"then
      s=s..("%q"):format(k).."="
      if type(v)=="table"then s=s.."{},"
      else s=s..("%q"):format(v).."," end
    end
  end
  s=s.."}"
  local f=fs.open(cp,"w")if f then fs.write(f,s)fs.close(f)end
end

local function cls(c)gpu.fill(1,1,sw,sh,c or 0x2D2D2D," ")end
local function txt(x,y,s,c)gpu.setForeground(c or 0xFFFFFF)gpu.set(1,1,x,y,s)end
local function btn(x,y,w,h,s,c)gpu.fill(x,y,w,h,c or 0x3366CC,true)gpu.set(1,1,x+(w-#s)//2,y+h//2,s)return{x=x,y=y,w=w,h=h}end
local function inBtn(b,x,y)return x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h end
local function scan()local t={}for a in comp.list("filesystem")do local p=comp.proxy(a)if p.exists("/OS.lua")or p.exists("/init.lua")then table.insert(t,{name=p.getLabel()or"Disk",path=a})end end;return t end

local function menu(sel)
  cls(0x2D2D2D)txt(2,2,"PixelOS Boot Manager",0x3366CC)
  for i,item in ipairs(cfg.bi)do local y=4+i;if y>sh-6 then break end
    local isDef=cfg.df and cfg.df==i
    gpu.fill(2,y,sw-4,1,(i==sel)and 0x3366CC or 0x2D2D2D,true)
    txt(3,y,(i==sel and"▶ "or"  ")..(isDef and"★ "or"  ")..item.name,(i==sel)and 0xFFFFFF or 0xCCCCCC)
  end
  return{b=btn(2,sh-3,7,3,"B"),s=btn(11,sh-3,6,3,"S"),r=btn(sw-8,sh-3,6,3,"R")}
end

local function main()
  lc()
  local f12=false t=comp.uptime()
  while comp.uptime()-t<cfg.bd do local e={comp.pullSignal(0.1)}if e[1]=="key_down"and e[4]==88 then f12=true break end end
  if not f12 then
    cls(0x2D2D2D)txt(2,2,"Booting...",0xFFFFFF)
    for i=cfg.bd,1,-1 do txt(2,4,"Auto "..i.."s (F12)",0x878787)comp.sleep(1)local e={comp.pullSignal(0.1)}if e[1]=="key_down"and e[4]==88 then f12=true break end end
    if not f12 then
      local def=cfg.df and cfg.bi[cfg.df]
      if def then comp.invoke(comp.list("eeprom")(),"setData",def.path)
      elseif#cfg.bi>0 then comp.invoke(comp.list("eeprom")(),"setData",cfg.bi[1].path)
      else comp.invoke(comp.list("eeprom")(),"setData","")end
      comp.shutdown(true)return
    end
  end
  if#cfg.bi==0 then local d=scan()for i,v in ipairs(d)do table.insert(cfg.bi,{name=v.name,path=v.path})end;sc()end
  local sel=1
  while true do
    local m=menu(sel)e={comp.pullSignal()}
    if e[1]=="touch"then x,y=e[3],e[4]
      for i,item in ipairs(cfg.bi)do if y==4+i and x>=3 then sel=i;m=menu(sel)end end
      if inBtn(m.b,x,y)and cfg.bi[sel]then cls()txt(2,sh-2,"Booting "..cfg.bi[sel].name)comp.invoke(comp.list("eeprom")(),"setData",cfg.bi[sel].path)comp.shutdown(true)end
      if inBtn(m.s,x,y)and cfg.bi[sel]then cfg.df=sel;sc();m=menu(sel)end
      if inBtn(m.r,x,y)then comp.shutdown(true)end
    elseif e[1]=="key_down"then
      if e[4]==200 and sel>1 then sel=sel-1 elseif e[4]==208 and sel<#cfg.bi then sel=sel+1
      elseif e[4]==28 and cfg.bi[sel]then cls()txt(2,sh-2,"Booting "..cfg.bi[sel].name)comp.invoke(comp.list("eeprom")(),"setData",cfg.bi[sel].path)comp.shutdown(true)
      elseif e[4]==30 then local d=scan()if#d>0 then table.insert(cfg.bi,{name=d[1].name,path=d[1].path})sc();m=menu(sel)end
      elseif e[4]==32 and#cfg.bi>0 then table.remove(cfg.bi,sel)if cfg.df==sel then cfg.df=nil end;sel=sel>#cfg.bi and math.max(1,#cfg.bi)or sel;sc();m=menu(sel)end
      elseif e[4]==19 then comp.shutdown(true)
      elseif e[4]==31 and cfg.bi[sel]then cfg.df=sel;sc();m=menu(sel)end
      m=menu(sel)
    end
  end
end

pcall(function()gpu.setBackground(0x2D2D2D)main()end)
for a in comp.list("filesystem")do local p=comp.proxy(a)if p.exists("/OS.lua")then comp.invoke(comp.list("eeprom")(),"setData",a)comp.shutdown(true)end end