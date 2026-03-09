-- File verification data for PixelOS installer
-- Note: File verification is optional and will be enhanced in future versions

return {
	-- For now, verification is handled by the installer's retry mechanism
	-- If download fails, the system will automatically retry
	
	verify = function(path, data)
		-- Accept all files for now
		-- Future: Add SHA-256 verification
		return true
	end,
}
