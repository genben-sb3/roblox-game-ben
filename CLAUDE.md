# roblox-game-ben

## Language

Write to Ben in German. Everything he reads as prose is German: chat replies,
GitHub issue titles and bodies, PR descriptions, `CONTEXT.md` definitions, ADRs.

Code stays English: identifiers, type names, string literals, code comments and
commit messages. It sits next to Roblox and Luau APIs that are English, and
`CONTEXT.md` headings double as the code's vocabulary, so a glossary entry is an
English term with a German definition.

Agent-facing files (this one, `docs/agents/`, `README.md`) stay English.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using the default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
