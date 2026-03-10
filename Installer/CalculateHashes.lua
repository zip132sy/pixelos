-- Calculate SHA-256 hashes for PixelOS files
-- Run this script to generate FileHashes.lua

local filesystem = require("filesystem")
local sha256 = require("SHA-256")

local function calculateFileHash(filePath)
    local file = io.open(filePath, "rb")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return sha256(content)
end

local function scanDirectory(dir, files)
    for file in filesystem.list(dir) do
        local path = dir .. "/" .. file
        if filesystem.isDirectory(path) then
            scanDirectory(path, files)
        elseif file:match("%.lua$") or file:match("%.cfg$") then
            local hash = calculateFileHash(path)
            if hash then
                local relativePath = path:gsub("^%./", "")
                files[relativePath] = hash
                print(relativePath .. " = " .. hash)
            end
        end
    end
end

print("Calculating file hashes...")
local files = {}

-- Scan Libraries
if filesystem.exists("Libraries") then
    scanDirectory("Libraries", files)
end

-- Scan Installer
if filesystem.exists("Installer") then
    scanDirectory("Installer", files)
end

-- Scan EFI
if filesystem.exists("EFI") then
    scanDirectory("EFI", files)
end

-- Scan root files
for _, file in ipairs({"OS.lua"}) do
    if filesystem.exists(file) then
        local hash = calculateFileHash(file)
        if hash then
            files[file] = hash
            print(file .. " = " .. hash)
        end
    end
end

-- Write FileHashes.lua
local outputFile = io.open("Installer/FileHashes.lua", "w")
if outputFile then
    outputFile:write("-- File verification data for PixelOS installer\n")
    outputFile:write("-- SHA-256 hashes for essential files (installation + basic system)\n\n")
    outputFile:write("return {\n")
    
    local sortedFiles = {}
    for path, hash in pairs(files) do
        table.insert(sortedFiles, {path = path, hash = hash})
    end
    table.sort(sortedFiles, function(a, b) return a.path < b.path end)
    
    for _, item in ipairs(sortedFiles) do
        outputFile:write('\t["' .. item.path .. '"] = "' .. item.hash .. '",\n')
    end
    
    outputFile:write("}\n")
    outputFile:close()
    
    print("\nFileHashes.lua updated successfully!")
    print("Total files: " .. #sortedFiles)
else
    print("Error: Could not write FileHashes.lua")
end
