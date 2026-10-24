-- Helpers for reading HighScore entries the way Simply Love stores them.

-- Music rate the score was earned at, parsed from the modifier string.
function HighScoreMusicRate(hs)
	return tonumber(string.match(hs:GetModifiers(), "([%d%.]+)xMusic")) or 1
end

-- EX score of a stored high score. The white fantastic count is stashed in the otherwise
-- unused Score field, see ScreenGameplay out.lua.
-- https://discord.com/channels/292111865658474496/958039182327029840/1156796786061606972
function HighScoreExScore(hs, steps, player)
	local whites = hs:GetScore()
	local ex_counts = {
		W0 = hs:GetTapNoteScore("TapNoteScore_W1") - whites,
		W1 = whites,
		W2 = hs:GetTapNoteScore("TapNoteScore_W2"),
		W3 = hs:GetTapNoteScore("TapNoteScore_W3"),
		W4 = hs:GetTapNoteScore("TapNoteScore_W4"),
		W5 = hs:GetTapNoteScore("TapNoteScore_W5"),
		Miss = hs:GetTapNoteScore("TapNoteScore_Miss"),
		Held = hs:GetHoldNoteScore("HoldNoteScore_Held"),
		LetGo = hs:GetHoldNoteScore("HoldNoteScore_LetGo"),
		HitMine = hs:GetTapNoteScore("TapNoteScore_HitMine"),
	}
	return CalculateExScoreNoGlobalState(steps, player, false, ex_counts, true)
end

-- Lamp colour index into SL.JudgmentColors["FA+"]:
-- 1 blue (FFC), 2 white (clear), 3 gold (FEC), 4 green (FC), 5 purple (quint), 6 red (fail)
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

-- whites is the number of fantastics outside the FA+ window
function LampIndex(grade, percent_dp, whites, stage_award)
	if grade == "Grade_Failed" then return 6 end
	if grade == "Grade_Tier01" and percent_dp == 1.0 and whites == 0 then return 5 end
	return AwardMap[stage_award] or 2
end

function HighScoreLampIndex(hs)
	return LampIndex(hs:GetGrade(), hs:GetPercentDP(), hs:GetScore(), hs:GetStageAward())
end

-- Lamp index and the count of what kept it from the next lamp as "idx" or "idx:count"
function LampString(idx, count)
	if not idx then return nil end
	if count and count > 0 then return ("%d:%d"):format(idx, count) end
	return ("%d"):format(idx)
end

function ParseLamp(s)
	if not s then return nil, nil end
	local idx, count = tostring(s):match("^(%d+):?(%d*)$")
	return tonumber(idx), tonumber(count)
end

function HighScoreLampString(hs)
	local idx = HighScoreLampIndex(hs)
	local function tap(w) return hs:GetTapNoteScore("TapNoteScore_" .. w) end
	local counts = {
		[1] = hs:GetScore() + tap("HitMine"),
		[2] = tap("W4") + tap("W5") + tap("Miss") + tap("CheckpointMiss") + hs:GetHoldNoteScore("HoldNoteScore_LetGo"),
		[3] = tap("W2"),
		[4] = tap("W3"),
	}
	return LampString(idx, counts[idx])
end

-- Higher is better
LampRank = { [5] = 6, [1] = 5, [3] = 4, [4] = 3, [2] = 2, [6] = 1 }
LampNames = { "FFC", "Clear", "FEC", "FC", "Quint", "Fail" }
