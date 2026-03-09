local function changeSource()
	contentContainer:removeChildren()
	
	local layout = contentContainer:addChild(GUI.layout(1, 1, contentContainer.width, contentContainer.height, 1, 1))
	
	layout:addChild(GUI.label(1, 1, 36, 1, 0x0, localization.changeSource or "App Sources")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
	layout:addChild(GUI.textBox(1, 1, 36, 2, nil, 0xA5A5A5, {localization.sourceInfo or "Manage app market sources. Select a source to use or add custom sources."}, 1, 0, 0, true, true))
	
	-- Sources list
	local sourcesList = layout:addChild(GUI.list(1, 1, 36, 10, 3, 0, nil, 0x787878, nil, 0x787878, 0x2D2D2D, 0xE1E1E1, false))
	
	-- Populate sources list
	for i, source in ipairs(config.sources) do
		local item = sourcesList:addItem(source.name)
		item.source = source
		if source.url == config.currentSource then
			sourcesList.selectedItem = i
		end
	end
	
	-- Add source button
	local addButton = layout:addChild(GUI.button(1, 1, 36, 3, 0x66DB80, 0xFFFFFF, 0x3366CC, 0xFFFFFF, localization.add or "Add Source"))
	addButton.onTouch = function()
		local container = GUI.addBackgroundContainer(workspace, true, true, localization.addSource or "Add New Source")
		local addLayout = container.layout:addChild(GUI.layout(1, 1, 40, 1, 1, 1))
		
		local nameInput = addLayout:addChild(GUI.input(1, 1, 36, 3, 0xFFFFFF, 0x696969, 0xB4B4B4, 0xFFFFFF, 0x2D2D2D, "", localization.sourceName or "Source Name"))
		local urlInput = addLayout:addChild(GUI.input(1, 1, 36, 3, 0xFFFFFF, 0x696969, 0xB4B4B4, 0xFFFFFF, 0x2D2D2D, "", localization.sourceURL or "Source URL"))
		
		local buttonsLayout = addLayout:addChild(GUI.layout(1, 1, 36, 1, 1, 1))
		buttonsLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
		buttonsLayout:setSpacing(1, 1, 2)
		
		buttonsLayout:addChild(GUI.adaptiveRoundedButton(1, 1, 2, 0, 0x66DB80, 0xFFFFFF, 0x3366CC, 0xFFFFFF, localization.add or "Add")).onTouch = function()
			if #nameInput.text > 0 and #urlInput.text > 0 then
				local newSource = {
					name = nameInput.text,
					url = urlInput.text,
					default = false
				}
				table.insert(config.sources, newSource)
				saveConfig(config)
				container:remove()
				changeSource()
			end
		end
		
		buttonsLayout:addChild(GUI.adaptiveRoundedButton(1, 1, 2, 0, 0xA5A5A5, 0xFFFFFF, 0x696969, 0xFFFFFF, localization.cancel or "Cancel")).onTouch = function()
			container:remove()
		end
	end
	
	-- Remove source button
	local removeButton = layout:addChild(GUI.button(1, 1, 36, 3, 0xF04747, 0xFFFFFF, 0xCC3333, 0xFFFFFF, localization.remove or "Remove Source"))
	removeButton.onTouch = function()
		local selectedItem = sourcesList:getItem(sourcesList.selectedItem)
		if selectedItem and not selectedItem.source.default then
			local container = GUI.addBackgroundContainer(workspace, true, true, localization.areYouSure or "Are you sure?")
			local buttonsLayout = container.layout:addChild(GUI.layout(1, 1, 36, 1, 1, 1))
			buttonsLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
			buttonsLayout:setSpacing(1, 1, 2)
			
			buttonsLayout:addChild(GUI.adaptiveRoundedButton(1, 1, 2, 0, 0xF04747, 0xFFFFFF, 0xCC3333, 0xFFFFFF, localization.yes or "Yes")).onTouch = function()
				if selectedItem.source.url == config.currentSource then
					config.currentSource = "https://gitee.com/zip132sy/pixelos/raw/master/AppMarket/"
					host = config.currentSource
				end
				for i, source in ipairs(config.sources) do
					if source.url == selectedItem.source.url then
						table.remove(config.sources, i)
						break
					end
				end
				saveConfig(config)
				container:remove()
				changeSource()
			end
			
			buttonsLayout:addChild(GUI.adaptiveRoundedButton(1, 1, 2, 0, 0xA5A5A5, 0xFFFFFF, 0x696969, 0xFFFFFF, localization.no or "No")).onTouch = function()
				container:remove()
			end
		end
	end
	
	-- Use selected source button
	local useButton = layout:addChild(GUI.button(1, 1, 36, 3, 0x66DB80, 0xFFFFFF, 0x3366CC, 0xFFFFFF, localization.useSelected or "Use Selected"))
	useButton.onTouch = function()
		local selectedItem = sourcesList:getItem(sourcesList.selectedItem)
		if selectedItem then
			config.currentSource = selectedItem.source.url
			host = selectedItem.source.url
			saveConfig(config)
			
			local messageBox = GUI.messageBox(localization.success or "Success", localization.sourceChanged or "App source has been changed. Please restart the app market.", 0x3366CC, 0xFFFFFF)
			workspace:addChild(messageBox)
			messageBox:onAppear()
		end
	end
	
	-- Back button
	layout:addChild(GUI.button(1, 1, 36, 3, 0xA5A5A5, 0xFFFFFF, 0x696969, 0xFFFFFF, localization.back or "Back")).onTouch = settings
end