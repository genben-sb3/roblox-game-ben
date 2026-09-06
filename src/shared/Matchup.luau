--!strict
--[[
	The matchup triangle at the heart of a duel.

	Every move is answered by exactly one other move, so no move is stronger
	than another: you win the exchange by reading your opponent, not by having
	bigger numbers. This module is pure Luau with no Roblox services, so it can
	be tested on Lune without opening Studio.
]]

export type Move = "Attack" | "Defense" | "Counter"

local Matchup = {}

-- Every move a player can commit to in an exchange.
local MOVES: { Move } = table.freeze({ "Attack", "Defense", "Counter" })
Matchup.MOVES = MOVES

-- Read as: the key beats the value.
local BEATS: { [Move]: Move } = {
	Defense = "Attack",
	Counter = "Defense",
	Attack = "Counter",
}

--[[
	Whether `move` wins the exchange against `other`. A move never beats itself.
]]
function Matchup.beats(move: Move, other: Move): boolean
	return BEATS[move] == other
end

--[[
	The one move that beats `move`.

	This is the question a duel asks when a player commits: what answers this?
]]
function Matchup.counterTo(move: Move): Move?
	for candidate, loser in BEATS do
		if loser == move then
			return candidate
		end
	end
	return nil
end

return Matchup
