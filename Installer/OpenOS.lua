local component = require("component")
local computer = require("computer")
local os = require("os")

local gpu = component.gpu

if gpu then
	local screenAvailable = component.isAvailable("screen")
	if not screenAvailable then
		for address in component.list("screen") do
			local ok, err = pcall(gpu.bind, address, true)
			if ok then break end
		end
	end
end

do
	local potatoes = {}

	local ok1, depth = pcall(gpu.getDepth)
	local ok2, resolution = pcall(gpu.maxResolution)
	if not ok1 or not depth or depth < 8 then
		table.insert(potatoes, "Tier 3 graphics card");
	end
	if not ok2 or not resolution or resolution < 160 then
		table.insert(potatoes, "Tier 3 screen");
	end

	local ok, totalMem = pcall(computer.totalMemory)
	if not ok or not totalMem or totalMem < 2 * 1024 * 1024 then
		table.insert(potatoes, "2x tier 3.5 RAM");
	end

	local filesystemFound = false
	for address in component.list("filesystem") do
		local ok, space = pcall(component.invoke, address, "spaceTotal")
		if ok and space and space >= 2 * 1024 * 1024 then
			filesystemFound = true
			break
		end
	end
	if not filesystemFound then
		table.insert(potatoes, "Tier 2 hard drive");
	end

	if not component.isAvailable("internet") then
		table.insert(potatoes, "Internet card");
	end

	if not component.isAvailable("eeprom") then
		table.insert(potatoes, "EEPROM");
	end

	if #potatoes > 0 then
		print("PixelOS requirements not met:")
		for i = 1, #potatoes do
			print("  - " .. potatoes[i])
		end
		return
	end
end

print("")
print("Downloading PixelOS installer...")

local internetAddress = component.list("internet")()
if not internetAddress then
	print("Error: No internet card found")
	return
end

local internet = component.proxy(internetAddress)

local urls = {
	"https://gitee.com/zip132sy/pixelos/raw/master/Installer/Main.lua",
	"https://raw.githubusercontent.com/zip132sy/pixelos/master/Installer/Main.lua"
}

local data
for i, url in ipairs(urls) do
	print("Trying: " .. url)
	local success, conn = pcall(internet.request, url)
	if success and conn then
		data = ""
		local chunk
		repeat
			chunk = conn.read(math.huge)
			if chunk then
				data = data .. chunk
			end
		until not chunk
		conn.close()
		
		if data and #data > 1000 then
			print("Download successful from: " .. url)
			break
		end
	end
end

if not data or #data < 1000 then
	print("Error: Failed to download installer from all sources")
	return
end

print("Starting PixelOS installer...")
print("")

local func, err = load(data, "=installer")
if func then
	setfenv(func, _G)
	local ok, err = pcall(func)
	if not ok then
		print("Installer error: " .. tostring(err))
	end
else
	print("Error loading installer: " .. tostring(err))
end
