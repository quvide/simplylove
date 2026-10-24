-- SL-Helpers-ArrowCloud.lua lifecycle calls
return Def.Actor{
	OnCommand = function(self) ArrowCloudScores.Flush() end,
	CurrentSongChangedMessageCommand = function(self) ArrowCloudScores.Flush() end,
	OffCommand = function(self) ArrowCloudScores.Cancel() end,
	CancelCommand = function(self) ArrowCloudScores.Cancel() end,

	ChartParsedMessageCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if GAMESTATE:IsCourseMode() or not song then return end
		for player in ivalues(GAMESTATE:GetHumanPlayers()) do
			local steps = GAMESTATE:GetCurrentSteps(player)
			if steps then ArrowCloudScores.Request(player, song, steps) end
		end
		ArrowCloudScores.Flush()
	end,
}
