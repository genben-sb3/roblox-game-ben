--!strict
local Matchup = require("./Matchup")
type Move = Matchup.Move

return {
	["defense beats attack"] = function()
		assert(Matchup.beats("Defense", "Attack"), "Defense should beat Attack")
	end,

	["counter beats defense"] = function()
		assert(Matchup.beats("Counter", "Defense"), "Counter should beat Defense")
	end,

	["attack beats counter"] = function()
		assert(Matchup.beats("Attack", "Counter"), "Attack should beat Counter")
	end,

	["the counter to attack is defense"] = function()
		assert(
			Matchup.counterTo("Attack") == "Defense",
			`the counter to Attack should be Defense, got {Matchup.counterTo("Attack")}`
		)
	end,

	["every move has exactly one counter, so no move is unanswerable"] = function()
		assert(#Matchup.MOVES == 3, `expected 3 moves, got {#Matchup.MOVES}`)
		for _, move in Matchup.MOVES do
			local counter = Matchup.counterTo(move)
			assert(counter ~= nil, `{move} has no counter`)
			assert(counter ~= move, `{move} counters itself`)
			assert(Matchup.beats(counter :: Move, move), `{counter} should beat {move}`)
		end
	end,

	["a move never beats itself"] = function()
		for _, move in Matchup.MOVES do
			assert(not Matchup.beats(move, move), `{move} should not beat itself`)
		end
	end,
}
