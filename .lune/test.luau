--!strict
--[[
	Runs every `*.spec.luau` under `src/` on Lune.

	This is how we test game rules without opening Studio. A spec module returns
	a table of test names to functions; a test fails by throwing, which is what
	`assert(condition, message)` does.

		return {
			["defense beats attack"] = function()
				assert(Matchup.beats("Defense", "Attack"), "Defense should beat Attack")
			end,
		}

	Only modules with no dependency on Roblox services can be tested here, which
	is the point: the rules live in `src/shared` as pure Luau, and the Roblox
	layer around them stays thin.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOT = "src"

local function findSpecs(dir: string): { string }
	local found = {}
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			for _, nested in findSpecs(path) do
				table.insert(found, nested)
			end
		elseif string.match(entry, "%.spec%.luau$") then
			table.insert(found, path)
		end
	end
	table.sort(found)
	return found
end

local specPaths = findSpecs(ROOT)
if #specPaths == 0 then
	print(`No *.spec.luau files found under {ROOT}/`)
	process.exit(1)
end

local passed = 0
local failures: { string } = {}

for _, specPath in specPaths do
	-- `require` here resolves relative to this file, which lives in `.lune/`.
	local suite = require(`../{string.gsub(specPath, "%.luau$", "")}`) :: { [string]: () -> () }

	local names = {}
	for name in suite do
		table.insert(names, name)
	end
	table.sort(names)

	print(specPath)
	for _, name in names do
		local ok, err = pcall(suite[name])
		if ok then
			passed += 1
			print(`  PASS  {name}`)
		else
			print(`  FAIL  {name}`)
			print(`        {err}`)
			table.insert(failures, `{specPath} :: {name}`)
		end
	end
end

print("")
if #failures == 0 then
	print(`All {passed} tests passed.`)
else
	print(`{passed} passed, {#failures} failed:`)
	for _, failure in failures do
		print(`  {failure}`)
	end
	process.exit(1)
end
