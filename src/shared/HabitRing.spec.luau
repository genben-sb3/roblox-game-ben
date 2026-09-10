--!strict
local HabitRing = require("./HabitRing")
type Habit = HabitRing.Habit

-- The table from ADR 0002, written out by hand. The module derives these ten
-- pairs from the ring; this spec is the independent copy that catches a ring
-- rotated the wrong way round.
local EXPECTED: { { attack: Habit, defense: Habit, counter: Habit } } = {
	{ attack = "Vine", defense = "Thorn", counter = "Root" },
	{ attack = "Bloom", defense = "Vine", counter = "Thorn" },
	{ attack = "Spore", defense = "Bloom", counter = "Vine" },
	{ attack = "Root", defense = "Spore", counter = "Bloom" },
	{ attack = "Thorn", defense = "Root", counter = "Spore" },
}

return {
	["the ring holds the five habits in the order from ADR 0002"] = function()
		local order = table.concat(HabitRing.RING, " ")
		assert(order == "Vine Bloom Spore Root Thorn", `unexpected ring order: {order}`)
	end,

	["the defense to an attack is the habit before it in the ring"] = function()
		for _, row in EXPECTED do
			local defense = HabitRing.defenseTo(row.attack)
			assert(
				defense == row.defense,
				`the defense to {row.attack} should be {row.defense}, got {defense}`
			)
		end
	end,

	["the counter to an attack is the habit two before it in the ring"] = function()
		for _, row in EXPECTED do
			local counter = HabitRing.counterTo(row.attack)
			assert(
				counter == row.counter,
				`the counter to {row.attack} should be {row.counter}, got {counter}`
			)
		end
	end,

	["a habit never answers itself"] = function()
		for _, habit in HabitRing.RING do
			assert(HabitRing.defenseTo(habit) ~= habit, `{habit} defends itself`)
			assert(HabitRing.counterTo(habit) ~= habit, `{habit} counters itself`)
		end
	end,

	["every habit both defends one attack and counters another, so no ability is dead"] = function()
		local defends: { [Habit]: Habit } = {}
		local counters: { [Habit]: Habit } = {}
		for _, attack in HabitRing.RING do
			local defense, counter = HabitRing.defenseTo(attack), HabitRing.counterTo(attack)
			assert(
				defends[defense] == nil,
				`{defense} defends both {defends[defense]} and {attack}`
			)
			assert(
				counters[counter] == nil,
				`{counter} counters both {counters[counter]} and {attack}`
			)
			defends[defense] = attack
			counters[counter] = attack
		end
		for _, habit in HabitRing.RING do
			assert(defends[habit] ~= nil, `{habit} defends nothing`)
			assert(counters[habit] ~= nil, `{habit} counters nothing`)
		end
	end,

	["answerKind names the safe and the greedy answer"] = function()
		for _, row in EXPECTED do
			local defense = HabitRing.answerKind(row.attack, row.defense)
			assert(
				defense == "Defense",
				`{row.defense} against {row.attack} should be a Defense, got {defense}`
			)
			local counter = HabitRing.answerKind(row.attack, row.counter)
			assert(
				counter == "Counter",
				`{row.counter} against {row.attack} should be a Counter, got {counter}`
			)
		end
	end,

	["answerKind is nil for a habit that does not answer the attack"] = function()
		for _, row in EXPECTED do
			for _, habit in HabitRing.RING do
				if habit == row.defense or habit == row.counter then
					continue
				end
				local kind = HabitRing.answerKind(row.attack, habit)
				assert(kind == nil, `{habit} should not answer {row.attack}, got {kind}`)
			end
		end
	end,

	["every attack has exactly two answers, so a loadout of three can hold a hole"] = function()
		for _, attack in HabitRing.RING do
			local answers = 0
			for _, habit in HabitRing.RING do
				if HabitRing.answerKind(attack, habit) ~= nil then
					answers += 1
				end
			end
			assert(answers == 2, `{attack} has {answers} answers, expected 2`)
		end
	end,
}
