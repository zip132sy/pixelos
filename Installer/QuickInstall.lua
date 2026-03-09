-- PixelOS Quick Install (Minimal)
local c,co,fs=component,computer,require("filesystem")
local BASE="https://gitee.com/zip132sy/pixelos/raw/master"
print("PixelOS v3.0 Quick Install")
if not c.list("gpu")()or not c.list("screen")()or not c.list("internet")()then print("Need GPU,Screen,Internet")return end
local inet=c.proxy(c.list("internet")())
local function dl(u,p)local h=inet.request(u)if not h then return false end local d=""while true do local c=h.read(math.huge)if not c then break end d=d..c end h.close()if #d==0 then return false end local dir=fs.path(p)if dir and dir~=""and not fs.exists(dir)then fs.makeDirectory(dir)end local f=io.open(p,"wb")if not f then return false end f:write(d)f:close()return true end
local files={"OS.lua","Libraries/GUI.lua","Libraries/Filesystem.lua","Libraries/Event.lua","Libraries/Screen.lua","Libraries/System.lua","Libraries/Paths.lua","Libraries/Color.lua","Libraries/Text.lua","Libraries/Number.lua","Libraries/Image.lua","Libraries/Keyboard.lua","Libraries/Bit32.lua","Libraries/Network.lua","Libraries/Component.lua","Libraries/GPU.lua"}
local apps={"Settings.app","FileManager.app","SystemCheck.app","Calculator.app","Terminal.app"}
local ok=0
for _,f in ipairs(files)do io.write(f.."...")if dl(BASE.."/"..f,"/"..f)then print("OK")ok=ok+1 else print("FAIL")end end
for _,a in ipairs(apps)do io.write(a.."...")fs.makeDirectory("/Applications/"..a)if dl(BASE.."/Applications/"..a.."/Main.lua","/Applications/"..a.."/Main.lua")then print("OK")ok=ok+1 else print("FAIL")end end
print("\nDone: "..ok.." files OK")
if ok>5 then print("Run /OS.lua to start")end
