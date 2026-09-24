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
  - `example/backend/server.js` behavior
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

- ~~`docs/` referenced by `README.md` and `tests/pr-governance.feature.md` but
  missing~~ — resolved: added `docs/demo-isolation.md`, `docs/ci-test-path.md`,
  `docs/ci-fixes-scope.md`, all short and drawing only on material already in
  the repo (README's own two-repo section, the workflow's inline comments) -
  not invented. `ci-test-path.md` deliberately doesn't duplicate
  `tests/pr-governance.feature.md`'s scripted scenarios, just narrates the
  same path at a higher level and points there for detail. Also fixed a gate
  order bug found along the way: README's bullet list under "The demo loop"
  described Spectral → Microcks → Backwards-compatibility, but the workflow's
  real `needs:` chain is Spectral → Backwards-compatibility → Microcks.
- ~~`governance/spectral/spectral-functions/disallowedNullInTypeArrayAndObjects.js`
  never fired on nested properties~~ — resolved: was overwriting `result`
  instead of accumulating (own-type/items/properties checks each clobbered
  the previous one, and the `properties` branch reset it to `[]` after its
  loop besides). Fixed to accumulate into an array. TDD: reproduced with a
  fixture (0 findings before, 1 after); regression-checked against both
  `governance/spectral/examples/*` fixtures and the real
  `example/contracts/orders-openapi.yaml` (no new errors there —
  `openapi-invalid.yaml` correctly gained one finding it always should have
  had, that's the fix working, not a regression).
- ~~`governance/spectral/spectral-functions/logAndHelp.js` leftover debug
  `console.log`~~ — resolved: commented out (kept, not deleted, per request)
  rather than removed. Function stays registered in the ruleset's
  `functionsDir`, still unused by any rule, still dead code — just silent now.
- ~~The ruleset and guidelines referenced the real company "PZU"~~ — resolved:
  rebranded to the fictional "API Peak" (rule ID prefix `api-peak:*`, guideline
  links now `api-guidelines.api-peak.com`) across the ruleset, guidelines docs,
  catalog-info, and the test scenarios that quote rule IDs.
- ~~`governance/api-guidelines/docs/index.md` rule-number inconsistencies~~ —
  resolved. Turned out to be two distinct bugs, both fixed:
  1. Four rule numbers (not three — found a fourth while fixing) were each
     duplicated onto two unrelated headings: `rest18`, `rest20`, `rest31`,
     `rest37`.
  2. "Metody zapytań" (request methods) had no rule-number tag at all, even
     though it's exactly the topic `rest19:request-methods` enforces — this
     gap is what pushed everything after it out of alignment.
  Fixed by renumbering every doc heading from `rest19` onward sequentially
  (doc now runs 1-42, not 1-37) and syncing the three `spectral-ruleset.yaml`
  rule IDs that had drifted from their doc topic (`separation-of-concerns`
  rest23→18, `status-codes` rest23→20, `problem-detail*` rest25→22).
  Verified with a before/after Spectral lint diff on both example files:
  identical findings/lines/severities/exit codes, purely a relabeling.
