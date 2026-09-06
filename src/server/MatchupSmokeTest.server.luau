--!strict
--[[
	Proves the sync works, end to end.

	Rojo pushes this file from the claudebox to Studio, Studio runs it on the
	server, and the Output window shows a rule that was tested on Lune before
	Studio ever saw it. That is the whole pipeline in one script.

	Delete this once the duel has real gameplay to look at.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Matchup = require(ReplicatedStorage.Shared.Matchup)

print("[Matchup] The triangle:")
for _, move in Matchup.MOVES do
	print(`[Matchup]   {move} is beaten by {Matchup.counterTo(move)}`)
end
