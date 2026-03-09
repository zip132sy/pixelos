-- Calculate SHA-256 hashes for all files
package.path = package.path .. ";c:/Users/Administrator/Documents/pixelos-update/PixelOS/?.lua"
local sha256 = dofile("c:/Users/Administrator/Documents/pixelos-update/PixelOS/Libraries/SHA-256.lua")

local files = {
	"Libraries/SHA-256.lua",
	"Libraries/Event.lua",
	"Libraries/Keyboard.lua",
	"Libraries/Filesystem.lua",
	"Libraries/Bit32.lua",
	"Libraries/Color.lua",
	"Libraries/Image.lua",
	"Libraries/Screen.lua",
	"Libraries/Text.lua",
	"Libraries/Number.lua",
	"Libraries/Paths.lua",
	"Libraries/GUI.lua",
	"Libraries/System.lua",
	"Libraries/Network.lua",
	"Libraries/JSON.lua",
	"Installer/Main.lua",
	"Installer/OpenOS.lua",
	"Installer/check_install.lua",
	"OS.lua",
	"EFI/Full.lua",
	"EFI/Minified.lua",
}

local hashes = {}

for _, file in ipairs(files) do
	local f = io.open("c:/Users/Administrator/Documents/pixelos-update/PixelOS/" .. file, "rb")
	if f then
		local data = f:read("*all")
		f:close()
		local hash = sha256.hash(data)
		hashes[file] = hash
		print(file .. "|" .. hash .. "|" .. #data)
	else
		print("NOT FOUND|" .. file)
	end
end
