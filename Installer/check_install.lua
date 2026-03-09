-- PixelOS Installation Checker v3.0
-- Based on MineOS installation validation

local component = component
local computer = computer

print("")
print("╔══════════════════════════════════════════════════╗")
print("║     PixelOS Installation Checker            ║")
print("║     by PixelOS Team             ║")
print("╚══════════════════════════════════════════════════╝")
print("")

local checks = {}
local passed = 0
local failed = 0

local function check(name, test)
    io.write("  Checking " .. string.format("%-25s", name) .. " ... ")
    local ok, result = pcall(test)
    if ok and result then
        print("[OK]")
        passed = passed + 1
        return true
    else
        print("[FAIL]" .. (result and (": " .. tostring(result)) or ""))
        failed = failed + 1
        return false
    end
end

print(" HARDWARE COMPONENTS:")
print(" ──────────────────────────────────────────────────")
check("GPU (Graphics Card)", function()
    return component.list("gpu")() ~= nil
end)

check("Screen (Display)", function()
    return component.list("screen")() ~= nil
end)

check("Filesystem (HDD/SSD)", function()
    return component.list("filesystem")() ~= nil
end)

check("EEPROM (BIOS)", function()
    return component.list("eeprom")() ~= nil
end)

print("")
print(" SYSTEM RESOURCES:")
print(" ──────────────────────────────────────────────────")
check("Memory (64KB minimum)", function()
    return computer.totalMemory() >= 64 * 1024
end)

check("Free Memory (32KB minimum)", function()
    return computer.freeMemory() >= 32 * 1024
end)

local eeprom = component.list("eeprom")()
if eeprom then
    check("EEPROM Size (4KB minimum)", function()
        return component.invoke(eeprom, "getSize") >= 4096
    end)
end

print("")
print(" SOFTWARE ENVIRONMENT:")
print(" ──────────────────────────────────────────────────")
check("Lua Version (5.2 or higher)", function()
    local v = _VERSION or ""
    return v:match("5%.[23]") ~= nil
end)

check("Component API", function()
    return type(component) == "table" and type(component.list) == "function"
end)

check("Computer API", function()
    return type(computer) == "table" and type(computer.uptime) == "function"
end)

check("Unicode Support", function()
    return type(unicode) == "table" and type(unicode.len) == "function"
end)

print("")
print(" FILESYSTEM ACCESS:")
print(" ──────────────────────────────────────────────────")
check("Root filesystem access", function()
    local fs = component.proxy(component.list("filesystem")())
    return fs.list("/") ~= nil
end)

check("Write permission", function()
    local fs = component.proxy(component.list("filesystem")())
    local testFile = ".pixelos_test_" .. os.time()
    local h = fs.open(testFile, "w")
    if h then
        fs.close(h)
        fs.remove(testFile)
        return true
    end
    return false
end)

print("")
print("╔══════════════════════════════════════════════════╗")
print(string.format("║  Results: %2d passed, %2d failed                   ║", passed, failed))
print("╚══════════════════════════════════════════════════╝")

if failed == 0 then
    print("")
    print(" ✓ SUCCESS: Your system is fully compatible!")
    print("   You can proceed with PixelOS installation.")
    print("")
    print(" Installation steps:")
    print("   1. Copy all PixelOS files to root directory")
    print("   2. Run OS.lua to start the system")
    print("   3. Or run Installer/Main.lua for guided setup")
    print("")
    return true
else
    print("")
    print(" ✗ WARNING: Some checks failed.")
    print("   PixelOS may not work correctly on this system.")
    print("")
    print(" Missing requirements:")
    if not component.list("gpu")() then print("   • Graphics Card (GPU)") end
    if not component.list("screen")() then print("   • Display (Screen)") end
    if not component.list("filesystem")() then print("   • Hard Disk Drive") end
    if not component.list("eeprom")() then print("   • EEPROM (BIOS)") end
    if computer.totalMemory() < 64 * 1024 then print("   • More RAM (64KB+ required)") end
    print("")
    return false
end
