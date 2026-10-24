-- Song wheel tech notation
local player = ...
local pn = ToEnumShortString(player)

local function Draw(self, song, steps)
	if not GAMESTATE:IsHumanPlayer(player) then return end

	local scoreOnRight = MusicWheelScoreOnRight() or (not SLMusicWheelScoreEnabled() and IsItlSong(song, player))
	self:x(_screen.w / WideScale(2.15, 2.14) - (scoreOnRight and 60 or 10))
	if GAMESTATE:GetNumSidesJoined() == 2 then
		self:y(player == PLAYER_1 and -6 or 6)
	else
		self:y(0)
	end

	self:settext(SLTechNotation_Format(steps, pn, ThemePrefs.Get("MusicWheelTechNotation")))
	self:visible(true)
end

return MusicWheelItem(player, Def.BitmapText {
	Font = "Common Normal",
	Text = "",
	InitCommand = function(self)
		self:visible(false):horizalign(right):zoom(0.6)
		if DarkUI() then self:diffuse(0, 0, 0, 1) end
	end,
	Draw = Draw,
})
