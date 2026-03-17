-- System Encryption Module for PixelOS
-- Provides disk encryption functionality using Vigenère cipher with XOR

local encryption = {}

-- XOR encryption function
local function xorEncrypt(data, key)
    local result = {}
    local keyLen = #key
    for i = 1, #data do
        local dataByte = data:byte(i)
        local keyByte = key:byte((i - 1) % keyLen + 1)
        table.insert(result, string.char(bit32.bxor(dataByte, keyByte)))
    end
    return table.concat(result)
end

-- Vigenère cipher with XOR for stronger encryption
local function generateKeyStream(key, length)
    local keyStream = {}
    local keyLen = #key
    for i = 1, length do
        keyStream[i] = key:byte((i - 1) % keyLen + 1)
    end
    return keyStream
end

-- Enhanced encryption using Vigenère + XOR + byte rotation
local function encrypt(data, key)
    local result = {}
    local keyStream = generateKeyStream(key, #data)
    local prevByte = 0
    
    for i = 1, #data do
        local byte = data:byte(i)
        local keyByte = keyStream[i]
        
        -- Apply multiple transformations
        local encrypted = bit32.bxor(byte, keyByte)
        encrypted = bit32.bxor(encrypted, prevByte)  -- CBC-like mode
        encrypted = bit32.rol(encrypted, 3)  -- Rotate left by 3 bits
        
        table.insert(result, string.char(encrypted))
        prevByte = encrypted
    end
    return table.concat(result)
end

-- Decryption (reverse of encryption)
local function decrypt(data, key)
    local result = {}
    local keyStream = generateKeyStream(key, #data)
    local prevByte = 0
    
    for i = 1, #data do
        local byte = data:byte(i)
        local keyByte = keyStream[i]
        
        -- Reverse transformations
        local decrypted = bit32.ror(byte, 3)  -- Rotate right by 3 bits
        decrypted = bit32.bxor(decrypted, prevByte)
        decrypted = bit32.bxor(decrypted, keyByte)
        
        table.insert(result, string.char(decrypted))
        prevByte = byte
    end
    return table.concat(result)
end

-- Check if disk is encrypted
function encryption.isEncrypted(filesystemProxy)
    return filesystemProxy.exists("/.encrypted")
end

-- Encrypt a file
function encryption.encryptFile(filesystemProxy, path, password)
    if not filesystemProxy.exists(path) then
        return false, "File not found"
    end
    
    local handle = filesystemProxy.open(path, "rb")
    local data = ""
    local chunk
    repeat
        chunk = filesystemProxy.read(handle, math.huge)
        data = data .. (chunk or "")
    until not chunk
    filesystemProxy.close(handle)
    
    local encrypted = encrypt(data, password)
    
    local encHandle = filesystemProxy.open(path .. ".enc", "wb")
    filesystemProxy.write(encHandle, encrypted)
    filesystemProxy.close(encHandle)
    
    filesystemProxy.remove(path)
    
    return true
end

-- Decrypt a file
function encryption.decryptFile(filesystemProxy, path, password)
    if not filesystemProxy.exists(path) then
        return false, "File not found"
    end
    
    local handle = filesystemProxy.open(path, "rb")
    local data = ""
    local chunk
    repeat
        chunk = filesystemProxy.read(handle, math.huge)
        data = data .. (chunk or "")
    until not chunk
    filesystemProxy.close(handle)
    
    local decrypted = decrypt(data, password)
    
    local decHandle = filesystemProxy.open(path:sub(1, -5), "wb") -- Remove .enc extension
    filesystemProxy.write(decHandle, decrypted)
    filesystemProxy.close(decHandle)
    
    filesystemProxy.remove(path)
    
    return true
end

-- Set encryption password
function encryption.setPassword(filesystemProxy, password)
    local hash = xorEncrypt(password, "salt")
    local handle = filesystemProxy.open("/.encryption_config", "wb")
    filesystemProxy.write(handle, hash)
    filesystemProxy.close(handle)
    
    local flagHandle = filesystemProxy.open("/.encrypted", "wb")
    filesystemProxy.write(flagHandle, "encrypted")
    filesystemProxy.close(flagHandle)
    
    return true
end

-- Verify password
function encryption.verifyPassword(filesystemProxy, password)
    if not filesystemProxy.exists("/.encryption_config") then
        return false
    end
    
    local handle = filesystemProxy.open("/.encryption_config", "rb")
    local storedHash = filesystemProxy.read(handle, math.huge)
    filesystemProxy.close(handle)
    
    local inputHash = xorEncrypt(password, "salt")
    
    return inputHash == storedHash
end

-- Remove encryption
function encryption.removeEncryption(filesystemProxy)
    if filesystemProxy.exists("/.encryption_config") then
        filesystemProxy.remove("/.encryption_config")
    end
    if filesystemProxy.exists("/.encrypted") then
        filesystemProxy.remove("/.encrypted")
    end
    return true
end

return encryption
