--!strict
--[[
	Which Habit answers which, derived from the ring (ADR 0002).

	The five Habits stand in a ring: Vine -> Bloom -> Spore -> Root -> Thorn ->
	Vine. An attack is answered by the Habit directly before it in that ring —
	the safe Defense — and by the one two before it — the greedy Counter. The
	ten pairs fall out of the structure instead of being maintained by hand.

	This module answers whether an Answer fits, and nothing else. What a lost
	exchange costs in HP lives in the balance config (ADR 0004), and when in the
	Commit Window a Counter may be played belongs to the duel loop. Pure Luau
	with no Roblox services, so `lune run test` covers it without Studio.
]]

export type Habit = "Vine" | "Thorn" | "Spore" | "Root" | "Bloom"

-- How an Answer relates to the attack it was played against.
export type AnswerKind = "Defense" | "Counter"

local HabitRing = {}

-- The ring itself. The order carries the rules, so it is not alphabetical and
-- not arbitrary: rotating it would silently rewrite every matchup. Renaming a
-- Habit means re-checking the themes ADR 0002 records for these neighbours.
local RING: { Habit } = table.freeze({ "Vine", "Bloom", "Spore", "Root", "Thorn" })
HabitRing.RING = RING

-- Where each Habit sits in the ring, so answering is a step back, not a search.
local POSITION: { [Habit]: number } = {}
for position, habit in RING do
	POSITION[habit] = position
end
table.freeze(POSITION)

-- How many steps back from an attack each kind of Answer stands.
local STEPS_BACK: { [AnswerKind]: number } = table.freeze({
	Defense = 1,
	Counter = 2,
})

--[[
	The Habit `stepsBack` places before `attack`, wrapping around the ring.
]]
local function habitBefore(attack: Habit, stepsBack: number): Habit
	local position = POSITION[attack]
	return RING[(position - stepsBack - 1) % #RING + 1]
end

--[[
	How `answer` relates to the incoming `attack`, or nil if it does not answer
	it at all.

	This is the question the Commit Window asks the moment the defender
	commits: whether the Answer fits decides the exchange, and it decides it
	alone. Whether a Counter was played early enough is the duel loop's
	question, not this module's.
]]
function HabitRing.answerKind(attack: Habit, answer: Habit): AnswerKind?
	for kind, stepsBack in STEPS_BACK do
		if habitBefore(attack, stepsBack) == answer then
			return kind
		end
	end
	return nil
end

--[[
	The safe Answer to `attack`: it takes no damage, but leaves the attacker
	holding the Initiative.
]]
function HabitRing.defenseTo(attack: Habit): Habit
	return habitBefore(attack, STEPS_BACK.Defense)
end

--[[
	The greedy Answer to `attack`: it deals damage and takes the Initiative, at
	the price of double damage when it misses.
]]
function HabitRing.counterTo(attack: Habit): Habit
	return habitBefore(attack, STEPS_BACK.Counter)
end

return HabitRing
