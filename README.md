# roblox-game-ben

Collect plants and crystals, mix them at your house into abilities, duel 1v1.

## How the two machines fit together

The code lives on **claudebox** (headless Linux, no Studio). **Studio runs on
Ben's Windows PC.** Rojo is the bridge: claudebox serves the files, Studio
connects over the LAN, and every save shows up in Studio live.

Game rules live in `src/shared` as plain Luau with **no Roblox services**, so
they can be tested on claudebox with Lune. The Roblox-facing code in
`src/server` and `src/client` is a thin layer that calls into those rules. That
split is deliberate: it is what makes the rules testable without Studio.

## Setup

Both machines need [Rokit](https://github.com/rojo-rbx/rokit), which installs
the exact tool versions pinned in `rokit.toml`:

```sh
rokit install    # rojo, wally, stylua, selene, lune
wally install    # third-party packages, into Packages/
```

`wally install` is a no-op until we actually depend on something, but run it
after any change to `wally.toml`. `Packages/` is generated and gitignored;
`wally.lock` is committed so both machines resolve identical versions.

## Commands

| Command | What it does |
| --- | --- |
| `lune run test` | Runs every `*.spec.luau` under `src/`. No Studio needed. |
| `lune run lint` | Formats with StyLua, lints with selene. |
| `lune run lint -- --check` | The same checks, but fails instead of rewriting. |
| `rojo serve --address 0.0.0.0` | Serves the project to Studio over the LAN. |
| `rojo build --output game.rbxl` | Builds a place file without Studio. |

## Connecting Studio

1. Install the Rojo **Studio plugin** on the Windows PC. Either open the
   [Rojo plugin page](https://create.roblox.com/store/asset/6415005344/Rojo)
   while logged in and click **Install**, or run `rojo plugin install` and
   restart Studio. (**Plugins → Manage Plugins** only lists plugins you
   already have; it will not find Rojo.)
2. On claudebox, run `rojo serve --address 0.0.0.0`.
3. In Studio, open the Rojo plugin, set the address to the claudebox IP and
   port `34872`, and click **Connect**. The serve API is unauthenticated, so
   anyone on the home network can read and change the source while it runs.
4. Press **Play**. The Output window shows the matchup triangle.

## Writing a test

A spec is a table of names to functions. A test fails by throwing, which is
what `assert(condition, message)` does.

```lua
local Matchup = require("./Matchup")

return {
	["defense beats attack"] = function()
		assert(Matchup.beats("Defense", "Attack"), "Defense should beat Attack")
	end,
}
```

Specs never reach Studio: `default.project.json` ignores `*.spec.luau`.
