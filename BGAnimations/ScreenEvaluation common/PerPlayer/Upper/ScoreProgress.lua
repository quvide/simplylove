if SL.Global.GameMode == "Casual" or GAMESTATE:IsCourseMode() then return end

-- copied from EventProgress.lua
local chatModule = FILEMAN:DoesFileExist(THEME:GetCurrentThemeDirectory() .. "Modules/TwitchChat.lua")
if not IsUsingWideScreen() and (chatModule or #GAMESTATE:GetHumanPlayers() ~= 1) then return end

local player = ...
local pn = ToEnumShortString(player)

if not PROFILEMAN:IsPersistentProfile(player) then return end

local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps(player)
if not (song and steps) then return end

local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
local score_type = SL[pn].ActiveModifiers.ShowExScore and CacheType.EX or CacheType.ITG
local LampColors = SL.JudgmentColors["FA+"]

-- ---------------------------------------------------------------------------
-- data

local function CurrentScore()
	if score_type == CacheType.EX then return CalculateExScore(player) end
	return pss:GetPercentDancePoints() * 100
end

local function CurrentLamp()
	local stats = SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1]
	local faPlus = stats and stats.ex_counts and stats.ex_counts.W0_total or 0
	local whites = pss:GetTapNoteScores("TapNoteScore_W1") - faPlus
	return LampIndex(pss:GetGrade(), pss:GetPercentDancePoints(), whites, pss:GetStageAward())
end

-- Previous best score and best lamp at 1.0x or faster, excluding this play.
-- Searched from score cache + local scores
local function PreviousBest()
	local best_score, best_lamp

	local function Consider(value, lamp)
		if value and (not best_score or value > best_score) then best_score = value end
		if lamp and LampRank[lamp] and (not best_lamp or LampRank[lamp] > LampRank[best_lamp]) then best_lamp = lamp end
	end

	local name = PROFILEMAN:GetPlayerName(player)
	local hash = steps:GetGrooveStatsHash()
	local function ConsiderCached(source)
		local cached, cached_lamp = CacheGet(name, hash, score_type, source)
		local lamp = ParseLamp(cached_lamp)
		-- Failed plays don't count as a best
		if cached and lamp ~= 6 then
			Consider(tonumber((cached:gsub("[^%d%.]", ""))), lamp)
		end
	end
	ConsiderCached(CacheSource.Local)
	if SL[pn].ArrowCloudApiKey ~= "" then ConsiderCached(CacheSource.ArrowCloud) end
	if ThemePrefs.Get("EnableGrooveStats") then ConsiderCached(CacheSource.GrooveStats) end

	local current = pss:GetHighScore()
	for hs in ivalues(PROFILEMAN:GetProfile(player):GetHighScoreList(song, steps):GetHighScores()) do
		local isThisPlay = hs:GetDate() == current:GetDate() and hs:GetPercentDP() == current:GetPercentDP()
		if not isThisPlay and hs:GetGrade() ~= "Grade_Failed" and HighScoreMusicRate(hs) >= 1 then
			local value = score_type == CacheType.EX and HighScoreExScore(hs, steps, player) or hs:GetPercentDP() * 100
			Consider(value, HighScoreLampIndex(hs))
		end
	end

	return best_score, best_lamp
end

-- ---------------------------------------------------------------------------
-- layout, copied from EventProgress.lua

local posX = 381 * (player == PLAYER_1 and 1 or -1)
local posY = 109

local paneWidth = 156
local paneHeight = 144
local borderWidth = 2

local RowHeight = 25

if IsUsingWideScreen() and (chatModule or #GAMESTATE:GetHumanPlayers() > 1) then
	posX = 211 * (player == PLAYER_1 and -1 or 1)
	posY = 274
	paneWidth = 118
	paneHeight = 180
end

-- ---------------------------------------------------------------------------

local current, lamp, best_score, best_lamp

-- Builds the body text plus a list of {start, len, color} byte ranges for the lamp names.
local function BuildBody(rank, total, board, gsRank, gsIsEx)
	local parts, marks, len = {}, {}, 0
	local function append(s, clr)
		if clr then marks[#marks + 1] = { start = len, len = #s, color = clr } end
		parts[#parts + 1] = s
		len = len + #s
	end

	if pss:GetFailed() then
		append("vs Best: --.--%")
	else
		append(("vs Best: %+.2f%%"):format(current - (best_score or 0)))
	end

	-- clear type
	append("\n")
	if best_lamp and LampRank[lamp] > (LampRank[best_lamp] or 0) then
		append(LampNames[best_lamp] or "?", LampColors[best_lamp] or Color.White)
		append(" >>> ")
	end
	append(LampNames[lamp], LampColors[lamp])

	-- ac rank
	if rank then
		append(("\nAC Rank: #%d"):format(rank))
		if total then append((" / %d"):format(total)) end
		if board then append((" (%s)"):format(board)) end
	elseif rank == false then
		-- fetched, but the player has no passing play on the ArrowCloud leaderboard
		append("\nAC Rank: none")
	end

	-- gs rank
	if gsRank then
		append(("\nGS Rank: #%d"):format(gsRank))
		-- the handler falls back to the other board when GrooveStats returned no EX board
		if gsIsEx ~= (score_type == CacheType.EX) then append(gsIsEx and " (EX)" or " (ITG)") end
	end

	return table.concat(parts), marks
end

local af = Def.ActorFrame{
	Name="ScoreProgress"..pn,

	InitCommand=function(self)
		self:xy(posX, posY)
	end,

	OnCommand=function(self)
		current = CurrentScore()
		lamp = CurrentLamp()
		best_score, best_lamp = PreviousBest()
		self:playcommand("Draw")
	end,

	DrawCommand=function(self)
		local text, marks = BuildBody(self.rank, self.total, self.board, self.gsRank, self.gsIsEx)
		local body = self:GetChild("BodyText")
		ScaleAndColorizeBody(body, text, paneHeight - borderWidth, paneWidth - borderWidth, RowHeight, Color.White)
		for mark in ivalues(marks) do
			body:AddAttribute(mark.start, { Length=mark.len, Diffuse=mark.color })
		end
	end,

	SetGrooveStatsRankCommand=function(self, params)
		self.gsRank, self.gsIsEx = tonumber(params.rank), params.isEx
		self:playcommand("Draw")
	end,

	ArrowCloudSubmitResultMessageCommand=function(self, params)
		if not (params and params.ok and params.player == pn) then return end
		if self.request then return end

		local cancelled = false
		self.cancel = function() cancelled = true end
		self.request = ArrowCloudScores.FetchRank(player, steps, score_type, function(rank, total, board)
			if cancelled or rank == nil then return end
			self.rank, self.total, self.board = rank, total, board
			self:playcommand("Draw")
		end)
	end,

	OffCommand=function(self)
		if self.cancel then self.cancel() end
		if self.request then self.request:Cancel() end
	end,

	-- border, background, header and body copied from EventProgress.lua
	Def.Quad {
		InitCommand=function(self)
			self:zoomto(paneWidth, paneHeight)
			self:diffuse(Color.White):diffusealpha(0.1)
		end
	},

	Def.Quad {
		InitCommand=function(self)
			self:zoomto(paneWidth - borderWidth, paneHeight - borderWidth)
			self:diffuse(Color.Black):diffusealpha(0.85)
		end
	},

	LoadFont("Wendy/_wendy small").. {
		Name="Header",
		Text=THEME:GetString("ScreenEvaluation", "ScoreProgressHeader"),
		InitCommand=function(self)
			self:zoom(0.5)
			self:y(-paneHeight/2 + 15)
			self:maxwidth((paneWidth - 6) / 0.5)
		end
	},

	LoadFont("Common Normal").. {
		Name="BodyText",
		Text="",
		InitCommand=function(self)
			self:valign(0)
			self:wrapwidthpixels(paneWidth)
			self:y(-paneHeight/2 + RowHeight * 3/2)
		end,
	},
}

return af
