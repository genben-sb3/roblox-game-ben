--!strict
--[[
	Proves the sync works, end to end.

	Rojo pushes this file from the claudebox to Studio, Studio runs it on the
	server, and the Output window shows a rule that was tested on Lune before
	Studio ever saw it. That is the whole pipeline in one script.

	Delete this once the duel has real gameplay to look at.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HabitRing = require(ReplicatedStorage.Shared.HabitRing)

print("[HabitRing] Every attack and its two answers:")
for _, attack in HabitRing.RING do
	local defense, counter = HabitRing.defenseTo(attack), HabitRing.counterTo(attack)
	print(`[HabitRing]   {attack} is defended by {defense} and countered by {counter}`)
end
