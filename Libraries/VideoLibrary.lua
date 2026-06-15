local VideoLibrary = {}

function VideoLibrary.createPlayer(width, height)
	local player = {}
	player.width = width or 80
	player.height = height or 25
	player.frames = {}
	player.currentFrame = 1
	player.isPlaying = false
	player.fps = 10
	player.lastFrameTime = 0
	player.loop = true
	player.onFrameChange = nil
	player.onPlay = nil
	player.onPause = nil
	player.onStop = nil
	player.onEnd = nil
	
	return player
end

function VideoLibrary.loadFrames(player, path)
	local filesystem = require("Filesystem")
	local image = require("Image")
	
	if not filesystem.exists(path) then
		return false, "Path does not exist"
	end
	
	if not filesystem.isDirectory(path) then
		return false, "Path is not a directory"
	end
	
	local files = filesystem.list(path)
	local frameFiles = {}
	
	for i, filename in ipairs(files) do
		if filename:match("%.pic$") or filename:match("%.png$") or filename:match("%.tga$") then
			table.insert(frameFiles, filename)
		end
	end
	
	table.sort(frameFiles)
	
	for i, filename in ipairs(frameFiles) do
		local framePath = path .. "/" .. filename
		local success, img = pcall(image.load, framePath)
		if success and img then
			table.insert(player.frames, img)
		end
	end
	
	if #player.frames == 0 then
		return false, "No valid frames found"
	end
	
	return true, #player.frames
end

function VideoLibrary.play(player)
	if #player.frames == 0 then
		return false, "No frames loaded"
	end
	
	if not player.isPlaying then
		player.isPlaying = true
		player.lastFrameTime = computer.uptime()
		
		if player.onPlay then
			player.onPlay(player)
		end
		
		return true
	end
	
	return false, "Already playing"
end

function VideoLibrary.pause(player)
	if player.isPlaying then
		player.isPlaying = false
		
		if player.onPause then
			player.onPause(player)
		end
		
		return true
	end
	
	return false, "Not playing"
end

function VideoLibrary.stop(player)
	if player.isPlaying or player.currentFrame ~= 1 then
		player.isPlaying = false
		player.currentFrame = 1
		
		if player.onStop then
			player.onStop(player)
		end
		
		return true
	end
	
	return false, "Already stopped"
end

function VideoLibrary.nextFrame(player)
	if #player.frames == 0 then
		return false, "No frames loaded"
	end
	
	local previousFrame = player.currentFrame
	player.currentFrame = player.currentFrame + 1
	
	if player.currentFrame > #player.frames then
		if player.loop then
			player.currentFrame = 1
		else
			player.currentFrame = #player.frames
			player.isPlaying = false
			
			if player.onEnd then
				player.onEnd(player)
			end
		end
	end
	
	if player.onFrameChange then
		player.onFrameChange(player, previousFrame, player.currentFrame)
	end
	
	return true
end

function VideoLibrary.previousFrame(player)
	if #player.frames == 0 then
		return false, "No frames loaded"
	end
	
	local previousFrame = player.currentFrame
	player.currentFrame = player.currentFrame - 1
	
	if player.currentFrame < 1 then
		player.currentFrame = player.loop and #player.frames or 1
	end
	
	if player.onFrameChange then
		player.onFrameChange(player, previousFrame, player.currentFrame)
	end
	
	return true
end

function VideoLibrary.setFrame(player, frameNumber)
	if #player.frames == 0 then
		return false, "No frames loaded"
	end
	
	if frameNumber < 1 or frameNumber > #player.frames then
		return false, "Invalid frame number"
	end
	
	local previousFrame = player.currentFrame
	player.currentFrame = frameNumber
	
	if player.onFrameChange then
		player.onFrameChange(player, previousFrame, player.currentFrame)
	end
	
	return true
end

function VideoLibrary.setFPS(player, fps)
	if fps < 1 or fps > 60 then
		return false, "FPS must be between 1 and 60"
	end
	
	player.fps = fps
	return true
end

function VideoLibrary.setLoop(player, loop)
	player.loop = loop
	return true
end

function VideoLibrary.getCurrentFrame(player)
	if #player.frames == 0 then
		return nil
	end
	
	return player.frames[player.currentFrame]
end

function VideoLibrary.getTotalFrames(player)
	return #player.frames
end

function VideoLibrary.getCurrentFrameNumber(player)
	return player.currentFrame
end

function VideoLibrary.isPlaying(player)
	return player.isPlaying
end

function VideoLibrary.getDuration(player)
	if #player.frames == 0 or player.fps == 0 then
		return 0
	end
	
	return #player.frames / player.fps
end

function VideoLibrary.getCurrentTime(player)
	if #player.frames == 0 or player.fps == 0 then
		return 0
	end
	
	return (player.currentFrame - 1) / player.fps
end

function VideoLibrary.update(player)
	if not player.isPlaying or #player.frames == 0 then
		return false
	end
	
	local currentTime = computer.uptime()
	local frameDelay = 1.0 / player.fps
	
	if currentTime - player.lastFrameTime >= frameDelay then
		local previousFrame = player.currentFrame
		player.currentFrame = player.currentFrame + 1
		
		if player.currentFrame > #player.frames then
			if player.loop then
				player.currentFrame = 1
			else
				player.currentFrame = #player.frames
				player.isPlaying = false
				
				if player.onEnd then
					player.onEnd(player)
				end
				
				return false
			end
		end
		
		player.lastFrameTime = currentTime
		
		if player.onFrameChange then
			player.onFrameChange(player, previousFrame, player.currentFrame)
		end
		
		return true
	end
	
	return false
end

function VideoLibrary.render(player, screen, x, y)
	local currentFrame = VideoLibrary.getCurrentFrame(player)
	
	if not currentFrame then
		return false, "No frame to render"
	end
	
	if type(currentFrame) == "table" then
		local imgWidth = currentFrame[1] or currentFrame.width
		local imgHeight = currentFrame[2] or currentFrame.height
		
		screen.drawImage(
			math.floor(x),
			math.floor(y),
			currentFrame
		)
		
		return true
	elseif type(currentFrame) == "table" and currentFrame.width and currentFrame.height then
		screen.drawImage(
			math.floor(x),
			math.floor(y),
			currentFrame
		)
		
		return true
	end
	
	return false, "Invalid frame format"
end

function VideoLibrary.createVideoFromImages(imageList, fps)
	local video = VideoLibrary.createPlayer()
	video.frames = imageList
	video.fps = fps or 10
	
	return video
end

function VideoLibrary.createAnimatedGIF(path, fps)
	local filesystem = require("Filesystem")
	local image = require("Image")
	
	if not filesystem.exists(path) then
		return nil, "File does not exist"
	end
	
	local success, img = pcall(image.load, path)
	if not success or not img then
		return nil, "Failed to load image"
	end
	
	if type(img) == "table" and #img > 0 then
		local video = VideoLibrary.createPlayer()
		video.frames = img
		video.fps = fps or 10
		
		return video
	elseif type(img) == "table" and img.width and img.height and img.data then
		local video = VideoLibrary.createPlayer()
		
		for y = 1, img.height do
			local row = {}
			for x = 1, img.width do
				row[x] = img.data[y][x]
			end
			table.insert(video.frames, {img.width, img.height, row})
		end
		
		video.fps = fps or 10
		
		return video
	end
	
	return nil, "Unsupported image format"
end

function VideoLibrary.downloadVideo(url, savePath, callback)
	local internet = require("Internet")
	local filesystem = require("Filesystem")
	
	local frameCount = 1
	local success = true
	local downloadedFrames = {}
	
	while success do
		local frameUrl = url .. string.format("frame%03d.pic", frameCount)
		local framePath = savePath .. string.format("/frame%03d.pic", frameCount)
		
		local downloadSuccess, downloadResult = internet.request(frameUrl, "GET")
		
		if downloadSuccess and downloadResult.code == 200 then
			filesystem.makeDirectory(savePath)
			local file = io.open(framePath, "w")
			if file then
				file:write(downloadResult.data)
				file:close()
				table.insert(downloadedFrames, framePath)
				
				if callback and callback.onProgress then
					callback.onProgress(frameCount, framePath)
				end
				
				frameCount = frameCount + 1
			else
				success = false
			end
		else
			success = false
		end
		
		if callback and callback.onFrame then
			callback.onFrame(frameUrl, framePath, downloadSuccess)
		end
	end
	
	if callback and callback.onComplete then
		callback.onComplete(#downloadedFrames, downloadedFrames)
	end
	
	return #downloadedFrames, downloadedFrames
end

function VideoLibrary.getInfo(player)
	return {
		width = player.width,
		height = player.height,
		totalFrames = #player.frames,
		currentFrame = player.currentFrame,
		fps = player.fps,
		duration = VideoLibrary.getDuration(player),
		currentTime = VideoLibrary.getCurrentTime(player),
		isPlaying = player.isPlaying,
		loop = player.loop
	}
end

return VideoLibrary
