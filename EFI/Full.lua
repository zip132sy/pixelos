
local
	stringsPixelOSEFI,
	stringsChangeLabel,
	stringsKeyDown,
	stringsComponentAdded,
	stringsFilesystem,
	stringsURLBoot,
	
	componentProxy,
	componentList,
	pullSignal,
	uptime,
	tableInsert,
	mathMax,
	mathMin,
	mathHuge,
	mathFloor,

	colorsTitle,
	colorsBackground,
	colorsText,
	colorsSelectionBackground,
	colorsSelectionText,

	OSList,
	bindGPUToScreen,
	drawRectangle,
	drawText,
	newMenuElement,
	drawCentrizedText,
	drawTitle,
	status,
	executeString,
	boot,
	newMenuBackElement,
	menu,
	input,
	internetExecute =

	"PixelOS EFI",
	"Change label",
	"key_down",
	"component_added",
	"filesystem",
	"URL boot",

	component.proxy,
	component.list,
	computer.pullSignal,
	computer.uptime,
	table.insert,
	math.max,
	math.min,
	math.huge,
	math.floor,

	0x2D2D2D,
	0xE1E1E1,
	0x878787,
	0x878787,
	0xE1E1E1

local
	eeprom,
	gpu,
	internetAddress =

	componentProxy(componentList("eeprom")()),
	componentProxy(componentList("gpu")()),
	componentList("internet")()

local
	gpuSet,
	gpuSetBackground,
	gpuFill,
	eepromSetData,
	eepromGetData,
	screenWidth,
	screenHeight =

	gpu and gpu.set,
	gpu and gpu.setBackground,
	gpu and gpu.fill,
	eeprom and eeprom.setData,
	eeprom and eeprom.getData,
	80, 25

OSList,
bindGPUToScreen,
drawRectangle,
drawText,
newMenuElement,
drawCentrizedText,
drawTitle,
status,
executeString,
boot,
newMenuBackElement,
menu,
input,
internetExecute =

{
	{
		"/OS.lua"
	},
	{
		"/init.lua",
		function()
			computer.getBootAddress, computer.setBootAddress = eepromGetData, eepromSetData
		end
	}
},

function()
	local screenAddress = componentList("screen")()
	
	if screenAddress and gpu then
		gpu.bind(screenAddress, true)
		screenWidth, screenHeight = gpu.getResolution()
	end
end,

function(x, y, width, height, color)
	if gpuSetBackground and gpuFill then
		gpuSetBackground(color)
		gpuFill(x, y, width, height, " ")
	end
end,

function(x, y, foreground, text)
	if gpu and gpuSet then
		gpu.setForeground(foreground)
		gpuSet(x, y, text)
	end
end,

function(text, callback, breakLoop)
	return {
		s = text,
		c = callback,
		b = breakLoop
	}
end,

function(y, foreground, text)
	if gpu then
		drawText(mathFloor(screenWidth / 2 - #text / 2), y, foreground, text)
	end
end,

function(y, title)
	if gpu then
		y = mathFloor(screenHeight / 2 - y / 2)
		drawRectangle(1, 1, screenWidth, screenHeight, colorsBackground)
		drawCentrizedText(y, colorsTitle, title)

		return y + 2
	end
	return 1
end,

function(statusText, needWait)
	local lines = {}

	for line in statusText:gmatch("[^\r\n]+") do
		lines[#lines + 1] = line:gsub("\t", "  ")
	end
	
	if gpu then
		local y = drawTitle(#lines, stringsPixelOSEFI)
		
		for i = 1, #lines do
			drawCentrizedText(y, colorsText, lines[i])
			y = y + 1
		end

		if needWait then
			while pullSignal() ~= stringsKeyDown do

			end
		end
	else
		if print then
			print(stringsPixelOSEFI)
			for i = 1, #lines do
				print(lines[i])
			end
			if needWait then
				print("Press any key to continue...")
				while pullSignal() ~= stringsKeyDown do

				end
			end
		end
	end
end,

function(...)
	local result, reason = load(...)

	if result then
		result, reason = xpcall(result, debug.traceback)

		if result then
			return
		end
	end

	status(reason or "Unknown error", 1)
end,

function(proxy)
	local OS

	for i = 1, #OSList do
		OS = OSList[i]

		if proxy and proxy.exists and proxy.exists(OS[1]) then
			status("Booting from " .. (proxy.getLabel and proxy.getLabel() or proxy.address))

			if eepromGetData and eepromSetData then
				local currentAddress = eepromGetData()
				if currentAddress and currentAddress ~= proxy.address then
					eepromSetData(proxy.address)
				end
			end

			if OS[2] then
				OS[2]()
			end

			local handle, data, chunk, success, reason = proxy.open(OS[1], "rb"), ""

			if handle then
				repeat
					chunk = proxy.read(handle, mathHuge)
					data = data .. (chunk or "")
				until not chunk

				proxy.close(handle)

				executeString(data, "=" .. OS[1])

				return 1
			else
				status("Failed to open boot file: " .. OS[1], 1)
			end
		end
	end
end,

function(f)
	return newMenuElement("Back", f, 1)
end,

function(title, items)
	local selectedIndex = 1

	if gpu then
		while 1 do
			local y, x, text, e = drawTitle(#items + 2, title)
			
			for i = 1, #items do
				text = "  " .. items[i].s .. "  "
				x = mathFloor(screenWidth / 2 - #text / 2)
				
				if i == selectedIndex then
					gpuSetBackground(colorsSelectionBackground)
					drawText(x, y, colorsSelectionText, text)
					gpuSetBackground(colorsBackground)
				else
					drawText(x, y, colorsText, text)
				end
				
				y = y + 1
			end

			e = { pullSignal() }

			if e[1] == stringsKeyDown then
				if e[4] == 200 and selectedIndex > 1 then
					selectedIndex = selectedIndex - 1
				
				elseif e[4] == 208 and selectedIndex < #items then
					selectedIndex = selectedIndex + 1
				
				elseif e[4] == 28 then
					if items[selectedIndex].c then
						items[selectedIndex].c()
					end
					
					if items[selectedIndex].b then
						break
					end
				end
			elseif e[1] == stringsComponentAdded and e[3] == "screen" then
				bindGPUToScreen()
			end
		end
	else
		if print then
			while 1 do
				print("\n" .. title)
				for i = 1, #items do
					local prefix = i == selectedIndex and "> " or "  "
					print(prefix .. items[i].s)
				end
				print("Use UP/DOWN to select, Enter to confirm")
				
				local e = { pullSignal() }
				if e[1] == stringsKeyDown then
					if e[4] == 200 and selectedIndex > 1 then
						selectedIndex = selectedIndex - 1
					elseif e[4] == 208 and selectedIndex < #items then
						selectedIndex = selectedIndex + 1
					elseif e[4] == 28 then
						if items[selectedIndex].c then
							items[selectedIndex].c()
						end
						if items[selectedIndex].b then
							break
						end
					end
				end
			end
		end
	end
end,

function(title, prefix)
	local
		y,
		text,
		state,
		prefixedText,
		char,
		e

	if gpu then
		y = drawTitle(2, title)
		text = ""
		state = 1

		while 1 do
			prefixedText = prefix .. text

			if gpuFill then
				gpuFill(1, y, screenWidth, 1, " ")
				drawCentrizedText(y, colorsText, prefixedText .. (state and "_" or ""))
			end

			e = { pullSignal(0.5) }

			if e[1] == stringsKeyDown then
				if e[4] == 28 then
					return text

				elseif e[4] == 14 then
					text = text:sub(1, -2)
				
				else
					char = unicode and unicode.char and unicode.char(e[3]) or string.char(e[3])

					if char:match("^[%w%d%p%s]+") then
						text = text .. char
					end
				end

				state = 1
			
			elseif e[1] == "clipboard" then
				text = text .. e[3]
			
			elseif not e[1] then
				state = not state
			end
		end
	else
		if print then
			print("\n" .. title)
			print(prefix)
			text = ""
			while 1 do
				e = { pullSignal() }
				if e[1] == stringsKeyDown then
					if e[4] == 28 then
						return text
					elseif e[4] == 14 then
						text = text:sub(1, -2)
					else
						char = unicode and unicode.char and unicode.char(e[3]) or string.char(e[3])
						if char:match("^[%w%d%p%s]+") then
							text = text .. char
						end
					end
				end
			end
		end
	end
end,

function(url)
	if internetAddress then
		local
			connection,
			data,
			result,
			reason =

			componentProxy(internetAddress).request(url),
			""

		if connection then
			status("Downloading script")

			while 1 do
				result, reason = connection.read(mathHuge)	
				
				if result then
					data = data .. result
				else
					connection.close()
					
					if reason then
						status(reason, 1)
					else
						executeString(data, "=url")
					end

					break
				end
			end
		else
			status("Failed to establish connection", 1)
		end
	else
		status("No internet connection available", 1)
	end
end

bindGPUToScreen()
status("Hold Alt to show boot options")

local deadline, eventData = uptime() + 1

while uptime() < deadline do
	eventData = { pullSignal(deadline - uptime()) }

	if eventData[1] == stringsKeyDown and eventData[4] == 56 then
		local utilities = {
			newMenuElement("Disk utility", function()
				local
					restrict,
					filesystems =
					
					function(text, limit)
						return (#text < limit and text .. string.rep(" ", limit - #text) or text:sub(1, limit)) .. "   "
					end,
					{ newMenuBackElement() }

				local function updateFilesystems()
					for i = 2, #filesystems do
						table.remove(filesystems, 1)
					end

					for address in componentList(stringsFilesystem) do
						local proxy = componentProxy(address)

						if proxy then
							local
								label,
								isReadOnly =

								proxy.getLabel and proxy.getLabel() or "Unnamed",
								proxy.isReadOnly and proxy.isReadOnly() or false

							tableInsert(filesystems, 1,
								newMenuElement(
									(eepromGetData and address == eepromGetData() and "> " or "  ") ..
									restrict(label, 10) ..
									restrict(proxy.spaceTotal and (proxy.spaceTotal() > 1048575 and "HDD" or proxy.spaceTotal() > 65535 and "FDD" or "SYS") or "SYS", 3) ..
									restrict(isReadOnly and "R  " or "R/W", 3) ..
									restrict(proxy.spaceTotal and proxy.spaceUsed and math.ceil(proxy.spaceUsed() / proxy.spaceTotal() * 100) .. "%" or "0%", 4) ..
									address:sub(1, 8) .. "…",
									
									function()
										local elements = {
											newMenuElement(
												"Set as bootable",
												function()
													if eepromSetData then
														eepromSetData(address)
														updateFilesystems()
													end
												end,
												1
											),

											newMenuBackElement()
										}

										if not isReadOnly then
											tableInsert(elements, 2, newMenuElement(
												stringsChangeLabel,
												function()
													if proxy.setLabel then
														pcall(proxy.setLabel, input(stringsChangeLabel, "New value: "))
														updateFilesystems()
													end
												end,
												1
											))

											tableInsert(elements, 3, newMenuElement(
												"Erase",
												function()
													status("Erasing " .. address)
													proxy.remove("")
													updateFilesystems()
												end,
												1
											))
										end

										menu(label .. " (" .. address .. ")", elements)
									end
								)
							)
						end
					end
				end

				updateFilesystems()
				menu("Select filesystem", filesystems)
			end),

			newMenuBackElement()
		}

		if internetAddress then	
			tableInsert(utilities, 2, newMenuElement("System recovery", function()
				internetExecute("https://tinyurl.com/29urhz7z")
			end))
			
			tableInsert(utilities, 3, newMenuElement(stringsURLBoot, function()
				internetExecute(input(stringsURLBoot, "Address: "))
			end))
		end

		menu(stringsPixelOSEFI, utilities)
	end
end

local bootProxy
if eepromGetData then
	local bootAddress = eepromGetData()
	if bootAddress then
		bootProxy = componentProxy(bootAddress)
	end
end

if not (bootProxy and boot(bootProxy)) then
	local function tryBootFromAny()
		for address in componentList(stringsFilesystem) do
			bootProxy = componentProxy(address)

			if boot(bootProxy) then
				computer.shutdown()
			else
				bootProxy = nil
			end
		end

		if not bootProxy then
			status("No boot sources found")
		end
	end

	tryBootFromAny()

	while 1 do
		if pullSignal() == stringsComponentAdded then
			tryBootFromAny()
		end
	end
end
