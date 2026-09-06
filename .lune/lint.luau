--!strict
--[[
	Formats and lints every Luau file we wrote. Run with `lune run lint`.

	Pass `--check` to verify without rewriting anything, which is what a CI job
	or a pre-merge gate wants:

		lune run lint -- --check

	`selene` needs a description of the Roblox API to know which globals exist.
	That file is generated rather than committed, so this regenerates it when
	it is missing — on a fresh clone, or after `git clean`.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

-- Only our own code. Anything Wally installs into `Packages` is not ours to
-- format or lint.
local OURS = { "src", ".lune" }

local checkOnly = table.find(process.args, "--check") ~= nil

local function run(program: string, args: { string })
	print(`$ {program} {table.concat(args, " ")}`)
	local result = process.exec(program, args, { stdio = "inherit" })
	if not result.ok then
		process.exit(result.code)
	end
end

if not fs.isFile("roblox.yml") then
	run("selene", { "generate-roblox-std" })
end

local styluaArgs = table.clone(OURS)
if checkOnly then
	table.insert(styluaArgs, 1, "--check")
end
run("stylua", styluaArgs)

-- Game code, against the Roblox API.
run("selene", { "src" })
-- Specs and these scripts, against plain Luau.
run("selene", { "--config", "selene-lune.toml", "--pattern", "**/*.spec.luau", "--", "src" })
run("selene", { "--config", "selene-lune.toml", ".lune" })

print(if checkOnly then "Formatting and lint checks passed." else "Formatted and linted.")
