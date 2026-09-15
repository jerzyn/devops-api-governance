# Agent Working Rules

Instructions for Claude (or any agent) working in this repo. Read this before
making changes.

## What this repo is

A self-contained demo of API governance across the delivery loop (Gitea +
Actions, Spectral, Microcks, Backstage, oasdiff) — see `README.md` for the
full architecture and demo flow. It backs a conference talk.

`presentation/` holds the talk deck as reference (`.pdf` + `.txt` transcript):
*"DevOps-Driven API Governance"*. Use it to understand the *narrative* the
repo is meant to support (why each gate exists, what story each demo topic
tells), but treat `README.md` and the code itself as the source of truth for
what is actually implemented — the deck may describe aspirational or
future-roadmap items (e.g. an MCP mock server) that aren't built yet. If you
add a feature the deck already claims exists, check the deck's wording isn't
now technically inaccurate, but never edit the deck to match code without
being asked.

## Branching

- Never commit directly to `main`. Before touching anything, create a branch:
  `git checkout -b <type>/<short-description>` (e.g. `fix/`, `feat/`, `chore/`).
- `main` is also the pristine template `gitea-seed` pushes into the demo's
  Gitea instance — keep it stable and always in a working state.

## Commit discipline

- Commit early, commit often. Prefer several small, working commits over one
  large one — each commit should leave the tree in a state that builds/lints.
- Stage what you actually changed for that step; check `git status`/`git diff`
  before committing rather than blindly staging everything.
- Commit message explains *why*, not just *what* (the diff already shows what).

## TDD

- Default workflow: write a failing test first, write the minimal code to
  make it pass, then refactor. Applies especially to:
  - `governance/spectral/spectral-functions/*.js` (custom Spectral functions)
  - `example/sample-backend/server.js` behavior
  - any new CI logic in `example/.gitea/workflows/pr-governance.yml`
- If a piece has no practical unit-test seam (e.g. Docker Compose wiring),
  say so and fall back to a manual/documented verification step instead of
  skipping verification silently.

## End-to-end tests last

- Full end-to-end verification (bringing up the whole `docker compose` stack,
  running the PR-driven scenarios in `tests/pr-governance.feature.md`) is
  slow and heavy (Gitea, Microcks, Backstage). Treat it as the *final* check
  once unit-level and lint-level tests are already green — not the main
  feedback loop while iterating.

## Known gaps (from a repo review, not yet fixed — pick these up as separate tasks)

- `docs/` is referenced by `README.md` and `tests/pr-governance.feature.md`
  (`demo-isolation.md`, `ci-test-path.md`, `ci-fixes-scope.md`) but does not
  exist — broken links.
- `governance/spectral/spectral-functions/disallowedNullInTypeArrayAndObjects.js`:
  the `properties` branch resets `result = []` after its loop, so the rule
  never actually fires on nested objects. Needs a fix + a regression test.
- `governance/spectral/spectral-functions/logAndHelp.js`: registered in the
  ruleset's `functionsDir` but not used by any rule; leftover debug
  `console.log`. Dead code — remove it (or wire it up if it was meant to be
  used somewhere).
- The ruleset and guidelines reference the real company "PZU" (rule IDs like
  `pzu:rest1:...`, links to `api-guidelines.app.pzu.pl`). Confirm this is
  intentional before this repo is shared/presented publicly.
