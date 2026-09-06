# roblox-game-ben

## Language

Write to Ben in German. Everything he reads as prose is German: chat replies,
GitHub issue titles and bodies, PR descriptions, `CONTEXT.md` definitions, ADRs.

Code stays English: identifiers, type names, string literals, code comments and
commit messages. It sits next to Roblox and Luau APIs that are English, and
`CONTEXT.md` headings double as the code's vocabulary, so a glossary entry is an
English term with a German definition.

Agent-facing files (this one, `docs/agents/`, `README.md`) stay English.

## Git

The agent owns `main`. There is no rule against writing to it, and no waiting on
Ben to merge.

Work on a short-lived branch with one PR per slice, then squash-merge it
yourself once the slice is confirmed working. Still open the PR and say what it
contains: the PR is the record, the merge is bookkeeping. Commit straight to
`main` when there is nothing to review — docs, `CONTEXT.md`, ADRs, typo fixes.

Anything that has to be seen running in Studio is confirmed by Ben, not by the
agent. That is a limit on what "confirmed working" means, not on who merges.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using the default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
