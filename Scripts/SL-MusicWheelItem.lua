-- Shared pieces for the per-player actors in Graphics/MusicWheelItem Song NormalPart.

-- The chart a wheel item shows for a song: the selected chart on the current song,
-- otherwise the one matching the player's difficulty and steps type (like the grade).
function ResolveWheelSteps(song, player)
	local currentSteps = GAMESTATE:GetCurrentSteps(player)
	local steps = SongUtil.GetPlayableSteps(song)

	-- While 2P song change is in progress, P2 currentsteps may not belong to the song
	if song == GAMESTATE:GetCurrentSong() and currentSteps then
		for s in ivalues(steps) do
			if s == currentSteps then return currentSteps end
		end
	end

	if #steps == 1 then return steps[1] end

	local difficulty = currentSteps and currentSteps:GetDifficulty() or GAMESTATE:GetPreferredDifficulty(player)
	local stepsType = currentSteps and currentSteps:GetStepsType() or GAMESTATE:GetCurrentStyle():GetStepsType()
	for s in ivalues(steps) do
		if s:GetStepsType() == stepsType and s:GetDifficulty() == difficulty then return s end
	end
	return nil
end

-- When score should be at the right edge
function MusicWheelScoreOnRight()
	return PlayerMusicWheelScore(PLAYER_1) == PlayerMusicWheelScore_Yes
		or PlayerMusicWheelScore(PLAYER_2) == PlayerMusicWheelScore_Yes
end


-- Actor def extension with a chart cache mechanism
function MusicWheelItem(player, def)
	local Draw = def.Draw
	def.Draw = nil

	def.SetCommand = function(self, params)
		local song = params and params.Song
		if not song then return end
		self.LatestSong = song

		local currentSteps = GAMESTATE:GetCurrentSteps(player)
		local key = song == GAMESTATE:GetCurrentSong() and currentSteps
			or (currentSteps and currentSteps:GetDifficulty() or GAMESTATE:GetPreferredDifficulty(player))
		if self.Song == song and self.Key == key then return end

		self.Song, self.Key = nil, nil
		self:visible(false)
		local steps = ResolveWheelSteps(song, player)
		if steps then Draw(self, song, steps) end
		self.Song, self.Key = song, key
	end

	def.RefreshCommand = function(self)
		self.Song = nil
		if self.LatestSong then self:playcommand("Set", { Song = self.LatestSong }) end
	end
	def.PlayerJoinedMessageCommand = function(self) self:queuecommand("Refresh") end
	def.PlayerUnjoinedMessageCommand = function(self) self:queuecommand("Refresh") end
	def.PlayerProfileSetMessageCommand = function(self) self:queuecommand("Refresh") end

	return def
end
