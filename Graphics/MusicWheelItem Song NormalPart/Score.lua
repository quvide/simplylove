-- Song wheel score: the best of the local, ArrowCloud and GrooveStats scores.
local player = ...
local pn = ToEnumShortString(player)
local white = color("#ffffff")

local function ExScoreFromHighScore(hs, steps)
	-- the white fantastic count is stored in the score field
	-- https://discord.com/channels/292111865658474496/958039182327029840/1156796786061606972
	local score = hs:GetScore()
	local ex_counts = {
		W0 = hs:GetTapNoteScore("TapNoteScore_W1") - score,
		W1 = score,
		W2 = hs:GetTapNoteScore("TapNoteScore_W2"),
		W3 = hs:GetTapNoteScore("TapNoteScore_W3"),
		W4 = hs:GetTapNoteScore("TapNoteScore_W4"),
		W5 = hs:GetTapNoteScore("TapNoteScore_W5"),
		Miss = hs:GetTapNoteScore("TapNoteScore_Miss"),
		Held = hs:GetHoldNoteScore("HoldNoteScore_Held"),
		LetGo = hs:GetHoldNoteScore("HoldNoteScore_LetGo"),
		HitMine = hs:GetTapNoteScore("TapNoteScore_HitMine"),
	}
	return CalculateExScoreNoGlobalState(steps, pn, false, ex_counts, true)
end

local function MusicRate(hs)
	return tonumber(string.match(hs:GetModifiers(), "([%d%.]+)xMusic")) or 1
end

-- Lamp colour index into SL.JudgmentColors["FA+"]:
-- 1 blue (FFC), 2 white, 3 gold (FEC), 4 green (FC), 5 purple (quint), 6 red (fail)
local AwardMap = {
	StageAward_FullComboW1 = 1,
	StageAward_FullComboW2 = 3,
	StageAward_SingleDigitW2 = 3,
	StageAward_OneW2 = 3,
	StageAward_FullComboW3 = 4,
	StageAward_SingleDigitW3 = 4,
	StageAward_OneW3 = 4,
	StageAward_100PercentW3 = 4,
}

local function LampIndex(hs)
	if hs:GetGrade() == "Grade_Failed" then return 6 end
	if hs:GetGrade() == "Grade_Tier01" and hs:GetPercentDP() == 1.0 and hs:GetScore() == 0 then return 5 end
	return AwardMap[hs:GetStageAward()] or 2
end

-- Best local score as a formatted string plus lamp index.
local function LocalScore(song, steps, score_type)
	local name = PROFILEMAN:GetPlayerName(player)
	local hash = steps:GetGrooveStatsHash()
	local cached, cached_idx = CacheGet(name, hash, score_type, CacheSource.Local)
	if cached and song ~= GAMESTATE:GetCurrentSong() then return cached, tonumber(cached_idx) end

	local best_hs, best_value
	for hs in ivalues(PROFILEMAN:GetProfile(pn):GetHighScoreList(song, steps):GetHighScores()) do
		if MusicRate(hs) >= 1 then
			local value = score_type == CacheType.EX and ExScoreFromHighScore(hs, steps) or hs:GetPercentDP() * 100
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
	local idx = ("%d"):format(LampIndex(best_hs))
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
