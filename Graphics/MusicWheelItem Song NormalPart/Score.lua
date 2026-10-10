-- Song wheel score: the best of the local, ArrowCloud and GrooveStats scores.
local player = ...
local pn = ToEnumShortString(player)
local white = color("#ffffff")

-- Best local score as a formatted string plus lamp index.
local function LocalScore(song, steps, score_type)
	local name = PROFILEMAN:GetPlayerName(player)
	local hash = steps:GetGrooveStatsHash()
	local cached, cached_idx = CacheGet(name, hash, score_type, CacheSource.Local)
	if cached and song ~= GAMESTATE:GetCurrentSong() then return cached, tonumber(cached_idx) end

	local best_hs, best_value
	for hs in ivalues(PROFILEMAN:GetProfile(pn):GetHighScoreList(song, steps):GetHighScores()) do
		if HighScoreMusicRate(hs) >= 1 then
			local value = score_type == CacheType.EX and HighScoreExScore(hs, steps, pn) or hs:GetPercentDP() * 100
			if value and (not best_value or value > best_value) then
				best_hs, best_value = hs, value
			end
		end
	end

	if not best_hs then
		if cached then CacheDelete(name, hash, score_type, CacheSource.Local) end
		return nil, nil
	end

	local live = ("%05.2f"):format(best_value)
	local idx = ("%d"):format(HighScoreLampIndex(best_hs))
	if live ~= cached or idx ~= cached_idx then
		CacheSet(name, hash, score_type, CacheSource.Local, live, idx)
	end
	return live, tonumber(idx)
end

local function Layout(self)
	local two = GAMESTATE:GetNumSidesJoined() == 2
	local mode = PlayerMusicWheelScore(player)
	local other = PlayerMusicWheelScore(player == PLAYER_1 and PLAYER_2 or PLAYER_1)

	if two and mode == other then
		self:y(player == PLAYER_1 and -11 or 4)
	else
		self:y(-4)
	end

	if mode ~= PlayerMusicWheelScore_ReplaceGrade then
		self:x(_screen.w / WideScale(2.15, 2.14) - 35)
	elseif two and other ~= PlayerMusicWheelScore_ReplaceGrade then
		-- the other player's grade is drawn next to us
		if player == PLAYER_1 then self:x(20):maxwidth(160) else self:x(50):maxwidth(0) end
	else
		self:x(32):maxwidth(0)
	end
end

local function Draw(self, song, steps)
	if PlayerMusicWheelScore(player) == PlayerMusicWheelScore_No or not PROFILEMAN:IsPersistentProfile(player) then return end
	Layout(self)

	local score_type = SL[pn].ActiveModifiers.ShowExScore and CacheType.EX or CacheType.ITG
	local name = PROFILEMAN:GetPlayerName(player)
	local hash = steps:GetGrooveStatsHash()

	local best, best_color
	local function Consider(score, idx)
		if score and (not best or tonumber(score) > tonumber(best)) then
			best = score
			best_color = idx and SL.JudgmentColors["FA+"][tonumber(idx)] or white
		end
	end
	Consider(LocalScore(song, steps, score_type))
	if SL[pn].ArrowCloudApiKey ~= "" then
		ArrowCloudScores.Request(player, song)
		Consider(CacheGet(name, hash, score_type, CacheSource.ArrowCloud))
	end
	if ThemePrefs.Get("EnableGrooveStats") then
		Consider(CacheGet(name, hash, score_type, CacheSource.GrooveStats))
	end

	if best then self:settext(best):diffuse(best_color):visible(true) end
end

return MusicWheelItem(player, Def.BitmapText {
	Font = "Wendy/_wendy monospace numbers",
	Text = "",
	InitCommand = function(self) self:visible(false):zoom(0.2) end,
	Draw = Draw,

	CacheUpdatedGSMessageCommand = function(self, params)
		if params.Song == self.Song then
			self:queuecommand("Refresh")
		end
	end,

	ArrowCloudScoresUpdatedMessageCommand = function(self)
		self:queuecommand("Refresh")
	end,
})
