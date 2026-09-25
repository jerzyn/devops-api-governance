# Screenplay: DevOps API Governance — Iterative Build-Up Demo

Five short recordings, one per pipeline maturity stage. Each stage adds one gate and shows it working. The recordings are played back during the talk, not run live.

Two parts happen in every stage:
- **Terminal:** git commands in your clone of the Gitea repo.
- **Browser:** Gitea (PR, changed files, CI logs), Backstage, Microcks. Every browser step below is a click-path, so you can do the whole demo solo and record it in one go.

Between steps there is one off-camera command, always the same: `scripts/demo/prep-stage.sh next`.

**While recording, use `cue-card.md`**: the same steps on one page (commands to paste, clicks, one line to say). This file explains them.

Every step below was run end to end by `scripts/demo/rehearse.sh`: every command from this page in a throwaway clone, real PRs, real CI, every red/fix loop and every `goto` target. Durations are measured from that run.

## Run of show

| Stage | Adds | Key shot (what the audience should remember) |
|---|---|---|
| 1 | Catalog | Merge a `catalog-info.yaml`, and `orders-api` appears in Backstage by itself. No CI yet. |
| 2 | Spectral | Red check with exactly one finding, `api-peak:rest17:2025-https-required`, whose link opens the rule in the API catalog: the guidelines live in Backstage. One-line fix turns it green. |
| 3 | Mocks + contract test (Microcks) | The pushed contract is a live mock at once; then the mock returns a `currency` the running backend doesn't, and contract-test catches it (`currency' not found`). |
| 4 | API gateway (KrakenD) | `curl` through the gateway goes from 404 (no routes yet) to 200 after the merge, with the generated `krakend.json` in the CI log. |
| 5 | Backwards compatibility (oasdiff) | `new-required-request-parameter` goes red, and downstream gates show as skipped (grey). Making it optional turns everything green. |

## How every stage works

Stages 2, 3 and 5 have two parts. **Part 1** installs the new gate. **Part 2** is the real shot: the gate catches a bad change (red, one-line fix, green). Stages 1 and 4 have a single part.

1. **Prep (off camera):** `scripts/demo/prep-stage.sh next`. It looks at Gitea `main`, works out which step comes next and creates that step's branch **in your demo clone**, committed but **not pushed**. It first brings the clone's `main` up to Gitea `main`, and it doesn't touch what your terminal has checked out, so you can run it while the recording terminal sits in the clone. Nothing is typed from scratch on camera, and the red states are red every time. Run it after the previous PR is merged (it tells you if you are too early). After a `goto`, the next branch is already there.
2. **Terminal, show and push:** `git switch <branch>`, show the change, then `git push -u origin <branch>`.
   - Contract changes are a few lines: show them in the terminal with `git diff main -- contracts/`.
   - Workflow changes are 40–60 lines of YAML: in the terminal only `git diff --stat main`, and show the change itself in the browser (**Files changed** tab of the PR), where it is readable.
   - The push is the developer handing the change over: normal local work, no `git fetch`, no branches appearing from the server.
3. **Browser, PR and checks:** open the PR (`compare/main...<branch>` → **New Pull Request** → **Create Pull Request**). Let the checks run and open a check's **Details** for the one log line that matters (each stage names it). The gate's verdict is the payload of the recording.
4. **Terminal, fix (red demos only):** one `sed` edits the contract, then `git commit -am` and `git push`. The push updates the same PR, so the checks re-run by themselves and go from red to green in the browser.
5. **Browser, merge:** **Create merge commit**. `main` now contains this step, and the next step starts from that. (Stage 1 has a PR too, but no checks run on it: no gate exists yet.)

**Part 1 is short on purpose.** A PR that only adds a workflow has nothing for the new gate to find (Spectral logs "skipping", oasdiff has nothing to compare), so its green check says little. Show what is added (**Files changed**), let the checks start, cut the wait in editing, merge. Spend the time on part 2.

Three things to keep in mind:
- Keep the same clone (`~/demo/orders-api`) for the whole walk-through. `next` adds each branch to it. `goto` replaces it with a fresh one.
- A `git push` does not open a PR in Gitea (the "Create a new pull request" line it prints is only a hint). PRs are always opened in the browser.
- `git diff main` is right because `next` updates your local `main` to Gitea `main` just before creating the branch. No `git fetch` or `origin/main` on camera.

If a take goes wrong, don't redo the earlier stages: use `prep-stage.sh goto <target>` (see "Retakes").

---

## Before recording

1. **Stack up** (see appendix).
2. **For the final recording only: `scripts/demo/fresh-gitea.sh`.** It wipes the demo Gitea (all PRs, CI runs and branches from rehearsals), brings the stack up again and runs `goto 1`. PR numbers then start at #1 and the Actions tab is empty. It asks before deleting anything. For a dry run, `scripts/demo/prep-stage.sh goto 1` is enough.
3. `scripts/demo/prep-stage.sh goto 1` (if you didn't run `fresh-gitea.sh`): Gitea `main` goes back to the Stage 1 starting state, open PRs are closed, all `feat/*` branches on Gitea are deleted, the governance repo is synced, the Backstage catalog is cleared, the gateway has no routes, and a **fresh demo clone** is made at `~/demo/orders-api` with the Stage 1 branch in it (not pushed).
4. In the browser, **sign in to Gitea** at `http://localhost:3000/user/login` as `demo` / `demo12345`. Without a login the PR page shows "Sign in to…" and has no create or merge buttons.
5. In the recording terminal: `source ~/projekty/devops-api-governance/scripts/demo/demo-shell.sh`. It `cd`s into the clone, sets a short prompt that shows the current branch (`orders-api (main) $`), makes long output page only when it doesn't fit, and clears the screen.
6. Check: `scripts/demo/prep-stage.sh preflight`. It checks the stack, the runner and CI image, Gitea (state, no open PRs), Backstage, the gateway, the Microcks mock, the guidelines page and the demo clone, and ends with `READY: record …` or a list of problems with the command that fixes each. It works at any stage, so run it before every take.

The Gitea repo has the same name as this project (`devops-api-governance`), so never clone it under that name or inside the project directory: a clone in `~/projekty` collides with the project, and a `rm -rf` of that name would delete it. `~/demo/orders-api` can't be confused with it. `goto` only ever deletes a folder that is a clone of the demo repo, and refuses otherwise.

## Screen layout and windows

Have everything below open **before** you press record, so no recording starts with a blank browser or a login screen.

- **Screen:** terminal on the left, browser on the right, both inside the recorded area. Terminal font ~18–20 pt and browser zoom ~125–150% (`Ctrl` `+`), so it is readable on a projector.
- **Terminal 1 (recorded):** `demo-shell.sh` sourced, in `~/demo/orders-api`. Only git commands and the stage-4 `curl` run here. `clear` before each step.
- **Terminal 2 (NOT recorded):** `~/projekty/devops-api-governance`, only for `scripts/demo/prep-stage.sh next`. Keep it outside the recorded area (another workspace, or minimised). If you record every part as its own take, one terminal is enough: stop recording, run `next` there, start again.
- **Browser:** one window with a few prepared tabs (listed per stage below). Signed in to Gitea as `demo`. Bookmarks bar hidden. If Backstage shows a sign-in page, sign in as guest once beforehand.
- **Tabs only for what a stage shows:** Backstage in Stages 1 and 2 (the catalog, then the guidelines in it), Microcks at most in Stage 3. Close them in the other stages so nothing distracts.
- **Not running / not visible:** the older `devops-driven-governance` stack (same container names and ports), desktop notifications, other windows.

## Retakes: roll back to any stage

`scripts/demo/prep-stage.sh goto <target>` puts Gitea `main`, the Backstage catalog and the KrakenD gateway in the state right **before** that step is recorded (the gateway has no routes until Stage 4 is merged). It replays every earlier stage's changes onto `main` (including the merged fixes), closes open PRs, deletes all `feat/*` branches on Gitea, loads the state's contract into Microcks (so the mock matches), builds the guidelines page in Backstage (so it never shows "building" on camera), makes a fresh demo clone and prepares the branch of the step you are about to record in it (local, not pushed). No CI needed, ~10 s. If the aborted take's CI is still running, `goto` first waits for it to finish (a late job would redeploy the gateway or reload the mock after the reset); that can add a minute or two.

| Target | State: what is already merged | Branch prepared in the clone |
|---|---|---|
| `goto 1` | nothing | `feat/add-catalog-entry` |
| `goto 2` | stage 1 (catalog entry; the API is in Backstage) | `feat/add-spectral-gate` |
| `goto 2-red` | + spectral gate | `feat/orders-server-url` |
| `goto 3` | + stage 2 fix (server URL is now `https://orders.api-peak.com`) | `feat/add-contract-test-gate` |
| `goto 3-red` | + contract-test gate | `feat/orders-currency` |
| `goto 4` | + stage 3 fix (`currency` exists, optional) | `feat/add-gateway-gate` |
| `goto 5` | + gateway gate | `feat/add-backwards-compat-gate` |
| `goto 5-red` | + backwards-compat gate (all four gates) | `feat/orders-require-channel` |
| `goto end` | everything, incl. optional `channel` | (nothing left) |

After a `goto`, `cd ~/demo/orders-api` again if your terminal was inside the old clone (or re-source `demo-shell.sh`), then record. `prep-stage.sh status` tells you where you are at any time.

If `git switch` says `fatal: invalid reference: feat/...`, the branch isn't prepared yet: run `prep-stage.sh next`.

## Browser cheat sheet

Repo: `http://localhost:3000/governance-demo/devops-api-governance`

- **Open a PR:** `<repo>/compare/main...<branch>` → **New Pull Request** → **Create Pull Request**. The title is prefilled from the branch's commit.
- **Show the change:** the PR's **Files changed** tab (coloured diff, easier to read than a terminal).
- **Watch the checks:** listed on the PR's **Conversation** tab. The list updates by itself; reload if it looks stuck.
- **Read a job's log:** **Details** next to a check, then click a step row (e.g. "Run Spectral (fail on errors)") to expand it.
- **Merge:** when all checks are green, **Create merge commit** at the bottom of the Conversation tab, then confirm.
- **Backstage:** `http://localhost:7007`. Left menu **APIs**, then the API's name.
- **API guidelines in the catalog:** `http://localhost:7007/docs/default/component/api-guidelines` (Backstage → **Docs** → **API Guidelines**). Every Spectral error links to its rule on this page.
- **Mock:** `http://localhost:8080/rest/Orders+API/1.0.0/orders/123` returns the contract's example.
- **Microcks:** `http://localhost:8080`. Test results are linked from the CI log (`Details: http://localhost:8080/#/tests/…`).

---

## Stage 1 — Catalog (the contract already exists)

**Narrative:** "The team already has an API contract, but you can't govern what you can't see. One `catalog-info.yaml` makes the API visible to the whole org."

**Starting state:** Gitea `main` has `backend/` and the OpenAPI contract `contracts/orders-openapi.yaml` (plus `README.md`, `.gitignore`). No `catalog-info.yaml`, no workflow. Backstage lists no APIs.

**Prep:** `goto 1` has already created `feat/add-catalog-entry` in your clone. It adds `catalog-info.yaml` and updates the README to mention it.

**On screen at the start:**
- Terminal 1: `orders-api (main) $`, screen cleared.
- Browser tab 1 (visible first): Gitea repo home. The file list shows `contracts/`, `backend/`, `README.md`, `.gitignore`, and the README below says the same: contract and backend, no catalog entry, no checks. This is the "before".
- Browser tab 2: Backstage, **APIs**. The list is empty: the other "before".

**Terminal:**
```bash
ls                                               # contracts/ and backend/, no catalog-info.yaml
git switch feat/add-catalog-entry                # local branch, already committed
cat catalog-info.yaml                            # show what gets registered
git push -u origin feat/add-catalog-entry        # hand the change over: the branch goes to Gitea
```

**Browser:**
1. Open the PR (`compare/main...feat/add-catalog-entry`). There are no checks, so it is mergeable at once. Merge.
2. Switch to the Backstage tab and reload **APIs**. `orders-api` appears by itself within ~10 s (8 s measured; Backstage rescans Gitea every 10 s). Reload once more if it isn't there yet.
3. Open `orders-api`: show the **Definition** tab (the rendered contract that was already in the repo) and the owner.

**Duration:** ~30–40 s.

---

## Stage 2 — Spectral (guidelines as code)

**Narrative:** "A guideline nobody enforces is just a suggestion."

**Part 1: install the gate.** Branch `feat/add-spectral-gate` adds `.gitea/workflows/pr-governance.yml` with only the `spectral-openapi-check` job.

**On screen at the start:**
- Terminal 1: same clone, screen cleared.
- Browser tab 1: Gitea repo home. It now lists `contracts/` and `catalog-info.yaml` (stage 1 is merged), and the README describes them. No `.gitea/` folder yet.
- Browser tab 2: Backstage, left open from Stage 1 (it is needed again in part 2). Microcks tab closed.
- Terminal 2 (off camera): `next` already run.

**Terminal:**
```bash
git switch feat/add-spectral-gate
git diff --stat main                             # one new file: the workflow
git push -u origin feat/add-spectral-gate        # hand the change over: the branch goes to Gitea
```

**Browser:**
1. Open the PR (`compare/main...feat/add-spectral-gate`). Show **Files changed**: the one gate, running on every PR.
2. Back on **Conversation**, `spectral-openapi-check` runs and goes green (no contract changed, so it only confirms the gate works). Cut the wait in editing. Merge.

**Part 2: the gate catches something.** Run `next` (off camera). Branch `feat/orders-server-url` moves the server URL to `http://orders.api-peak.com`.

**Terminal:**
```bash
git switch feat/orders-server-url
git diff main -- contracts/                      # https://api.api-peak.com -> http://orders.api-peak.com
git push -u origin feat/orders-server-url        # hand the change over: the branch goes to Gitea
```

**Browser:**
1. Open the PR (`compare/main...feat/orders-server-url`). `spectral-openapi-check` goes **red**.
2. **Details** → expand **Run Spectral (fail on errors)**. The contract is otherwise clean, so this is the only finding:
   `error api-peak:rest17:2025-https-required server.url MUST use HTTPS.` and `✖ 1 problem (1 error, 0 warnings, 0 infos, 0 hints)`.
3. **Guidelines live in the catalog.** The line under the error is the rule's link, `http://localhost:7007/docs/default/component/api-guidelines/#https-api-peakrest172025-https`. Open it (click it, or copy it into the Backstage tab): Backstage opens the **API Guidelines** page at the HTTPS rule. Say: "same rule for humans and for CI, one source of truth, and the CI error points right at it."

**Terminal (fix):**
```bash
sed -i 's#http://orders.api-peak.com#https://orders.api-peak.com#' contracts/orders-openapi.yaml
git commit -am "Use HTTPS server URL"
git push
```

**Browser:** back on the PR, the check re-runs and goes green (the log now says "No results with a severity of 'error' found!"). Merge.

**Duration:** ~16 s per CI run; the whole red → fix → green loop ~50 s.

---

## Stage 3 — Mocks & contract testing (Microcks)

**Narrative:** "A contract is a promise. Push it, and partners get a live mock at once. Then CI proves the running code keeps it."

**Part 1: install the gate.** Branch `feat/add-contract-test-gate` adds the `contract-test` job (`needs: spectral-openapi-check`).

**On screen at the start:**
- Terminal 1: same clone, screen cleared.
- Browser tab 1: Gitea repo home, now with the `.gitea/` folder (spectral gate merged); the README lists one gate.
- Browser tab 2 (optional): Microcks `localhost:8080`, to show the mocked service in part 1 and the test detail page in part 2.
- Backstage tab: closed.
- Terminal 2 (off camera): `next` already run.

**Terminal:**
```bash
git switch feat/add-contract-test-gate
git diff --stat main                             # the workflow grows (and the README)
git push -u origin feat/add-contract-test-gate   # hand the change over: the branch goes to Gitea
```

**Browser:**
1. Open the PR (`compare/main...feat/add-contract-test-gate`). **Files changed**: the new `contract-test` job, after spectral. It first imports the contract into Microcks, then tests the running backend against it.
2. spectral and contract-test go green. Cut the wait. Merge.

**Terminal (Q1: integrate before it exists?):** the contract is also a live mock. Partners can call it today.
```bash
# the mock Microcks serves from the contract's example
curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123
```
`{"orderId":"123","isPaid":true}`. Optional: in the Microcks tab, open **APIs | Services** → **Orders API 1.0.0** to show the same operation and its example.

**Part 2: the contract promises more than the code delivers.** Run `next`. Branch `feat/orders-currency` adds a **required** `currency` field to the order response. The running backend doesn't return it.

**Terminal:**
```bash
git switch feat/orders-currency
git diff main -- contracts/                      # new required field: currency
git push -u origin feat/orders-currency          # hand the change over: the branch goes to Gitea
```

**Browser:**
1. Open the PR (`compare/main...feat/orders-currency`). spectral goes green (the contract is valid), then **contract-test goes red**.
2. **Details** on contract-test → expand **Run contract test**. Microcks reports `currency' not found`: the running backend doesn't keep the promise.
3. Optional: open the `Details: http://localhost:8080/#/tests/…` link from that log to show the test in Microcks.

**Terminal (Q2: does the code match the contract?):** the CI job loaded the PR's contract into Microcks, so the mock already speaks the new version. The real backend doesn't.
```bash
# the mock, from the PR's contract: has currency
curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123
# the running backend: no currency
curl -s http://localhost:8081/orders/123
```
`{"orderId":"123","isPaid":true,"currency":"PLN"}` next to `{"orderId":"123","isPaid":true}`: that difference is exactly what the red check says.

**Terminal (fix):** say it out loud: "Contract first: we don't promise what the code doesn't deliver yet. We keep `currency` in the contract but optional; once the backend returns it, we make it required."
```bash
sed -i 's/required: \[orderId, isPaid, currency\]/required: [orderId, isPaid]/' contracts/orders-openapi.yaml
git commit -am "Don't promise currency until the backend returns it"
git push
```

**Browser:** back on the PR, contract-test goes green. Merge.

**Duration:** ~35 s per CI run (spectral ~16 s, then contract-test ~17 s); the red → fix → green loop ~1.5 min.

---

## Stage 4 — API gateway (KrakenD)

**Narrative:** "Now expose it for real, and prove the gateway didn't change anything."

Branch `feat/add-gateway-gate` adds the `gateway-deploy-check` job (`needs: contract-test`).

**On screen at the start:**
- Terminal 1: same clone, screen cleared. It also runs the `curl` commands (before the PR and at the end).
- Browser tab 1: Gitea repo home.
- Terminal 2 (off camera): `next` already run.
- The KrakenD container runs with **no routes**: `curl -i http://localhost:8090/orders/123` returns `404`. This is the "before" of the stage.

**Terminal:**
```bash
curl -i http://localhost:8090/orders/123         # before: the gateway has no routes, 404
git switch feat/add-gateway-gate
git diff --stat main                             # the workflow grows (and the README)
git push -u origin feat/add-gateway-gate         # hand the change over: the branch goes to Gitea
```

**Browser:**
1. Open the PR (`compare/main...feat/add-gateway-gate`). **Files changed**: the new `gateway-deploy-check` job. **Three** gates now: spectral, contract-test, gateway-deploy-check.
2. **Details** on gateway-deploy-check. Expand **Generate krakend.json from the PR contract** (the generated config), then **Deploy to the running gateway**, then **Run contract test through the gateway**.
3. Wait for green. Merge.

**Terminal (proof it's live):**
```bash
curl -i http://localhost:8090/orders/123         # after: 200, through KrakenD
curl -s http://localhost:8081/orders/123         # straight to the backend: identical body
```

**Duration:** ~55 s for the CI run (spectral ~16 s, contract-test ~17 s, gateway ~22 s).

---

## Stage 5 — Backwards compatibility (new API version)

**Narrative:** "A partner is integrated now. An innocent-looking change would break them."

**Part 1: install the gate.** Branch `feat/add-backwards-compat-gate` inserts `breaking-changes-check` **between** spectral and contract-test, and repoints contract-test's `needs:` to it. This is the project's real, current pipeline.

**On screen at the start:**
- Terminal 1: same clone, screen cleared.
- Browser tab 1: Gitea repo home. Keep the window wide: the PR page lists four checks with long names.
- Terminal 2 (off camera): `next` already run.

**Terminal:**
```bash
git switch feat/add-backwards-compat-gate
git diff --stat main                             # the workflow grows (and the README)
git push -u origin feat/add-backwards-compat-gate  # hand the change over
```

**Browser:**
1. Open the PR (`compare/main...feat/add-backwards-compat-gate`). **Files changed**: the new job in the middle and the repointed `needs:`.
2. All four gates go green. Cut the wait. Merge.

Say this out loud: "We insert this gate right after lint and before the runtime tests. A change that passes linting but breaks clients shouldn't even reach contract testing."

**Part 2: the gate catches a breaking change.** Run `next`. Branch `feat/orders-require-channel` adds a new **required** query parameter `channel` to `GET /orders/{orderId}`.

**Terminal:**
```bash
git switch feat/orders-require-channel
git diff main -- contracts/                      # new required param
git push -u origin feat/orders-require-channel   # hand the change over: the branch goes to Gitea
```

**Browser:**
1. Open the PR (`compare/main...feat/orders-require-channel`). spectral goes green, then **breaking-changes-check goes red**.
2. contract-test and gateway-deploy-check show as **skipped (grey)**, because their `needs:` isn't satisfied. For a few seconds after the red result they read "Blocked by required conditions" and only then "Skipped": wait for it, then point at it.
3. **Details** on breaking-changes-check → expand **Run oasdiff breaking (fail on breaking changes)**. Zoom on:
   `error [new-required-request-parameter] … added the new required query request parameter channel`

**Terminal (fix):**
```bash
sed -i '/name: channel/,/required:/ s/required: true/required: false/' contracts/orders-openapi.yaml
git commit -am "Make channel optional (non-breaking)"
git push
```

**Browser:** back on the PR, all four gates run and go green. Merge. This is the climax: keep it at full speed.

**Duration:** the red run takes ~35 s (spectral ~16 s, then the BC check ~15 s); the final four-gate run ~70 s; the whole red → fix → green loop ~2 min.

---

## Overall timing

About **8 minutes** of raw footage (the rehearsal's walk-through took 8.5 min, including 10 CI runs). With part 1 of stages 2, 3 and 5 kept short and CI waits cut, the edited demo is ~5–6 minutes. Keep Stage 5's final green run at full speed.

---

## Post-production

`scripts/demo/video.sh` (ffmpeg) covers the usual edits:

```bash
scripts/demo/video.sh cards ~/demo/cards                       # card1.mp4 .. card5.mp4, 3 s each
scripts/demo/video.sh trim stage2.mp4 00:00:12 00:01:40 s2.mp4  # keep a range
scripts/demo/video.sh speed ci-wait.mp4 4 ci-wait-4x.mp4        # CI waiting at 4x
scripts/demo/video.sh concat demo.mp4 ~/demo/cards/card1.mp4 s1.mp4 ~/demo/cards/card2.mp4 s2.mp4 ...
```

- **Title cards** open each stage: the stage name, what it adds, and the pipeline so far ("Pipeline: Spectral → Contract test → Gateway"), so the audience always knows where they are.
- **concat** normalises everything to 1920×1080 @ 30 fps. If a clip has no audio, the whole result is silent (it says so).
- Typical cut: trim each recording into pieces, `speed` the CI waiting pieces, `concat` cards and pieces.

---

## Appendix — operator notes (off camera)

**Stack:** from the project directory (`~/projekty/devops-api-governance`, check with `pwd`; the older `devops-driven-governance` project uses the same container names and ports and cannot run at the same time):
`podman-compose --profile contract --profile catalog --profile gateway up -d`. On this machine it's the hyphenated `podman-compose` binary. Endpoints:
- Gitea `localhost:3000` (demo/demo12345)
- Microcks `:8080`
- Backstage `:7007`
- backend `:8081`
- KrakenD `:8090`

**Run `prep-stage.sh goto 1` after every `podman-compose up`.** Anything that depends on the one-shot `gitea-seed` service re-runs it, and the seed force-pushes the full repo onto Gitea `main`, wiping the stage state (`status` then says "matches no demo state"). `backstage` and `gitea-runner` depend on it. Never run it mid-demo, and never `podman start`/`restart` those two either.

**CI runs offline.** Jobs run in `localhost/devops-api-governance-ci:latest` (`ci-image/Dockerfile`, built by the `ci-image` compose service), which has Spectral, oasdiff, the KrakenD CLI and js-yaml preinstalled, and the checkout is plain `git` against Gitea. Only building that image the first time needs the internet. The install steps in the workflow remain as a fallback: on a plain `node:20` runner they download the tools.

**Backstage** rescans Gitea every 10 s (`app-config.yaml`, a demo setting). `prep-stage.sh refresh-catalog` still forces an immediate rescan through the catalog's scheduler endpoint, without touching any container.

**backend can't be recreated while `krakend` runs** (podman: "has dependent containers"). That's why Stage 3's red demo changes the contract instead of toggling the backend's `DRIFT` mode, which is only read at startup.

**Before the recording day:** `scripts/demo/rehearse.sh` (~9 min) runs the whole screenplay against the stack and prints PASS/FAIL per check. It leaves the demo at `end`: run `goto 1` (or `fresh-gitea.sh`) afterwards.

**Recording:** Spectacle, one continuous recording per stage (or of the whole demo) with terminal and browser side by side. Wayland asks once for screen-capture permission.
