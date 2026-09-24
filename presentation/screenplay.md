# Screenplay: DevOps API Governance — Iterative Build-Up Demo

Five short recordings, one per pipeline maturity stage. Each stage adds one gate and shows it working. The recordings are played back during the talk, not run live.

Two parts happen in every stage:
- **Terminal:** git commands in your clone of the Gitea repo.
- **Browser:** Gitea (PR + CI logs), Backstage, Microcks. Claude can drive it, but every browser step below is written as a click-path, so you can do the whole demo solo and record it in one go.

Off-camera prep (before each stage) is a single command: `scripts/demo/prep-stage.sh <step>`.

Every step below was run end to end by a script that does exactly what you do: fresh clone, every command from this page, real CI. It covers all five stages, every red/fix loop, and every `goto` target (each one is compared with the state a real walk-through produces). Durations are measured from that run (whole walk-through: ~10 min of wall-clock, including 10 CI runs).

## Run of show

| Stage | Adds | Key shot (what the audience should remember) |
|---|---|---|
| 1 | Catalog | `orders-api` appears in Backstage after a merge. No CI yet. |
| 2 | Spectral | Red check with the exact rule ID `api-peak:rest17:2025-https-required`. One-line fix turns it green. |
| 3 | Contract test (Microcks) | The contract promises a field the running backend doesn't return. contract-test catches it (`currency' not found`). |
| 4 | API gateway (KrakenD) | `curl` through the gateway goes from 404 (no routes yet) to 200 after the merge, with the generated `krakend.json` in the CI log. |
| 5 | Backwards compatibility (oasdiff) | `new-required-request-parameter` goes red, and downstream gates show as skipped (grey). Making it optional turns everything green. |

Every stage follows the same pattern. Stages 2, 3 and 5 run it twice: **part 1** installs the new gate on a change that is fine (the gate goes green), **part 2** shows the gate catching a bad change (red, then a one-line fix, then green). Stages 1 and 4 have a single part.

1. **Prep (off camera):** `scripts/demo/prep-stage.sh <step>` clones Gitea `main`, applies that step's change and pushes it as a branch (e.g. `feat/add-spectral-gate`). Nothing is typed from scratch on camera, and the red states are red every single time. Each stage's branch also updates the repo's `README.md`, so the Gitea repo home always describes the current state and visibly grows with the pipeline. (After a `goto` it is already done for the step you are about to record.) Run it in a second terminal, before you start recording the step, and **only after the previous step's PR is merged**: the branch is cut from Gitea `main` at that moment.
2. **Terminal, show the change:** `git fetch origin`, `git switch <branch>`, then show what it changes: `git diff origin/main -- <path>` (or `cat` for a new file). This is where the audience sees *what is being proposed*, so let it stay on screen for a beat.
3. **Browser, PR and checks:** open the PR (`compare/main...<branch>` → **New Pull Request** → **Create Pull Request**) and let the checks run. Open a check's **Details** to show the one log line that matters (each stage names it). The gate's verdict is the payload of the recording.
4. **Terminal, fix (red demos only):** one command edits the contract (`sed`), then `git commit -am` and `git push`. Pushing updates the same PR, so the checks re-run by themselves and go from red to green in the browser.
5. **Browser, merge:** click **Create merge commit**. `main` now contains this step, and the next step starts from that. (Stage 1 has no PR: it is a plain `git push origin <branch>:main`, because no gate exists yet.)

Three things to keep in mind:
- You can keep the same clone for the whole walk-through (`git fetch` picks up each new branch). Make a new one only after a `goto`.
- A plain `git push` does not open a PR in Gitea. PRs are always opened in the browser. You never push the stage branch yourself: the prep script already did.
- Diff against `origin/main`, not `main`. Your local `main` stays at clone time; `origin/main` moves with every merge (`git fetch` updates it).

If a take goes wrong, don't redo the earlier stages: use `prep-stage.sh goto <target>` (see "Retakes").

---

## Before recording

The environment is ready when: 7 containers run (all from `devops-api-governance`), Gitea `main` is at the Stage 1 starting state, there are no open PRs, Backstage lists no APIs, and `feat/add-catalog-entry` is on the remote. `prep-stage.sh goto 1` produces exactly that (it pushes the Stage 1 branch itself).

Gitea keeps the history of earlier PRs and CI runs, so new PRs on camera are numbered from #33 up (not #1) and the Actions tab lists old runs. The screenplay only ever opens a PR by URL, so this rarely shows.

1. Stack up (see appendix).
2. `scripts/demo/prep-stage.sh goto 1` (run from the project directory; `reset` is an alias): Gitea `main` goes back to the Stage 1 starting state, open PRs are closed, **all** `feat/*` branches are deleted, the governance repo is synced, the Backstage catalog is cleared, and the branch for Stage 1 (`feat/add-catalog-entry`) is pushed. Nothing else to run before the clone.
3. In the browser, **sign in to Gitea** at `http://localhost:3000/user/login` as `demo` / `demo12345`. Without a login the PR page shows "Sign in to…" and has no create or merge buttons.
4. Make a fresh clone *after* the reset, in its own folder and under its own name:
   ```bash
   mkdir -p ~/demo && cd ~/demo
   git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git orders-api
   cd orders-api
   ```
   The Gitea repo has the same name as this project (`devops-api-governance`), so never clone it under that name or inside the project directory: a clone in `~/projekty` collides with the project, and a `rm -rf` of that name would delete the project. `~/demo/orders-api` can't be confused with it, and its prompt on camera reads as the team's Orders API repo.

## Screen layout and windows

Yes, have everything below open **before** you press record, so no recording starts with a blank browser or a login screen.

- **Screen:** terminal on the left, browser on the right, both inside the recorded area. Terminal font ~18–20 pt and browser zoom ~125–150% (`Ctrl` `+`), so it is readable on a projector.
- **Terminal 1 (recorded):** inside the fresh clone (`cd ~/demo/orders-api`), `clear`ed. Only git commands and the stage-4 `curl` run here.
- **Terminal 2 (NOT recorded):** in the project directory `~/projekty/devops-api-governance`, for `prep-stage.sh` only. Keep it outside the recorded area (another workspace, or minimised).
- **One terminal is enough** if you record every part as its own take (stop recording, run the prep, start again): `prep-stage.sh` works from any directory, e.g. `~/projekty/devops-api-governance/scripts/demo/prep-stage.sh stage2` typed inside the clone. **Two are better** for continuous takes, and needed for Stage 1, where `refresh-catalog` has to run right after your push while the recording keeps going. Two terminal *windows*, not two tabs of one window: tabs would show up in the recording.
- **Browser:** one window with a few prepared tabs (listed per stage below). Already signed in to Gitea as `demo`. Bookmarks bar hidden. If Backstage shows a sign-in page, sign in as guest once beforehand.
- **Tabs only for what a stage shows:** Backstage is used in Stage 1 only, Microcks at most in Stage 3. Close them in the other stages so nothing distracts.
- **Not running / not visible:** the older `devops-driven-governance` stack (same container names and ports), desktop notifications, other windows.
- **Always running (not shown):** the 7 containers from the appendix.

## Retakes: roll back to any stage

`scripts/demo/prep-stage.sh goto <target>` puts Gitea `main`, the Backstage catalog and the KrakenD gateway in the state right **before** that step is recorded (the gateway has no routes until Stage 4 is merged). It replays every earlier stage's changes onto `main` (including the merged fixes), closes open PRs, deletes all `feat/*` branches and **pushes the branch of the step you are about to record**. It doesn't need CI and takes ~10s.

Because `goto` deletes every `feat/*` branch, always let it push the branch (it does). If you delete or lose one some other way, re-push it with `prep-stage.sh <step>`; the git error you get otherwise is `fatal: invalid reference: feat/...`.

| Target | State: what is already merged | Branch `goto` pushes (= `prep-stage.sh <step>`) |
|---|---|---|
| `goto 1` | nothing | `stage1` |
| `goto 2` | stage 1 (catalog entry; the API is in Backstage) | `stage2` |
| `goto 2-red` | + spectral gate | `stage2-red` |
| `goto 3` | + stage 2 fix (server URL is now `https://orders.example.com`) | `stage3` |
| `goto 3-red` | + contract-test gate | `stage3-red` |
| `goto 4` | + stage 3 fix (`currency` exists, optional) | `stage4` |
| `goto 5` | + gateway gate | `stage5` |
| `goto 5-red` | + backwards-compat gate (all four gates) | `stage5-red` |
| `goto end` | everything, incl. optional `channel` | (final state) |

After a `goto`:
1. Delete your old clone and make a fresh one (`main` was force-pushed, and your local `feat/*` branches are stale):
   ```bash
   cd ~/demo && rm -rf orders-api
   git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git orders-api
   cd orders-api
   ```
2. Record. The step's branch is already on the remote.

Every retake target was verified: the resulting repo state, plus the real red/green CI result for `3-red` (contract-test fails) and `5-red` (breaking-changes-check fails, the rest skipped).

## Browser cheat sheet

Repo: `http://localhost:3000/governance-demo/devops-api-governance`

- **Open a PR:** go to `<repo>/compare/main...<branch>`, click **New Pull Request**, then **Create Pull Request**. The title is prefilled from the branch's commit.
- **Watch the checks:** they are listed on the PR's Conversation tab. The list updates by itself; reload if it looks stuck.
- **Read a job's log:** click **Details** next to a check. Click a step row (e.g. "Run Spectral (fail on errors)") to expand its log.
- **Merge:** when all checks are green, click **Create merge commit** at the bottom of the Conversation tab, then confirm.
- **Backstage:** `http://localhost:7007`. Sign in as guest if asked. Left menu **APIs**, then the API's name.
- **Microcks:** `http://localhost:8080`. Test results are linked from the CI log (`Details: http://localhost:8080/#/tests/…`).

---

## Stage 1 — Catalog (the contract already exists)

**Narrative:** "The team already has an API contract, but you can't govern what you can't see. One `catalog-info.yaml` makes the API visible to the whole org."

**Starting state:** Gitea `main` has `backend/` and the OpenAPI contract `contracts/orders-openapi.yaml` (plus `README.md`, `.gitignore`). It has no `catalog-info.yaml` and no workflow. Backstage lists no APIs.

**Prep:** `scripts/demo/prep-stage.sh stage1` pushes branch `feat/add-catalog-entry`. It adds `catalog-info.yaml` (and updates the README to mention it).

**On screen at the start:**
- Terminal 1: fresh clone, `git status` clean, screen cleared.
- Browser tab 1 (visible first): Gitea repo home. The file list shows `contracts/`, `backend/`, `README.md`, `.gitignore`, and the README below it says the same: the contract and the backend exist, no catalog entry, no checks. This is the "before".
- Browser tab 2: Backstage, left menu **APIs**. The list is empty, the other "before". Switch to it after the push.
- Terminal 2 (off camera): `prep-stage.sh stage1` already run; `prep-stage.sh refresh-catalog` typed, not yet executed.

**Terminal:**
```bash
ls                                               # contracts/ and backend/, no catalog-info.yaml
git fetch origin
git switch feat/add-catalog-entry
cat catalog-info.yaml                            # show what gets registered
git push origin feat/add-catalog-entry:main      # merge: fast-forward, no gate exists yet
```

**Browser:**
1. Right after the push: `scripts/demo/prep-stage.sh refresh-catalog`. Backstage's Gitea provider only rescans every **30 minutes**, so this triggers a rescan; the API is listed after ~5–7s. Run it from a second terminal (or cut those seconds from the video).
2. Open Backstage → **APIs** → `orders-api`.
3. Show the **Definition** tab (the rendered contract that was already in the repo) and the owner.

**Duration:** ~30s after cutting.

---

## Stage 2 — Spectral (guidelines as code)

**Narrative:** "A guideline nobody enforces is just a suggestion."

**Part 1: install the gate.**

**Prep:** `prep-stage.sh stage2` pushes branch `feat/add-spectral-gate`. It adds `.gitea/workflows/pr-governance.yml` with only the `spectral-openapi-check` job.

**On screen at the start:**
- Terminal 1: same clone, screen cleared.
- Browser tab 1: Gitea repo home. It now lists `contracts/` and `catalog-info.yaml` (stage 1 is merged), and the README describes them. No `.gitea/` folder yet.
- Backstage and Microcks tabs: closed.
- Terminal 2 (off camera): `stage2` already run. `stage2-red` **not yet**: run it after part 1 is merged.

**Terminal:**
```bash
git fetch origin
git switch feat/add-spectral-gate
cat .gitea/workflows/pr-governance.yml           # show the new gate
```

**Browser:**
1. Open the PR (`compare/main...feat/add-spectral-gate`). The check `spectral-openapi-check` goes green.
2. Merge.

This PR doesn't touch any OpenAPI file, so Spectral logs "skipping" and passes. That's expected: this part only installs the gate. The real shot is part 2.

**Part 2: the gate catches something.**

**Prep:** `prep-stage.sh stage2-red` pushes branch `feat/orders-server-url`. It moves the server URL to `http://orders.example.com`. Run it **after** part 1 is merged: it is cut from Gitea `main`, which must already contain the gate, or the PR gets no CI.

**Terminal:**
```bash
git fetch origin
git switch feat/orders-server-url
git diff origin/main -- contracts/               # https://api.example.com -> http://orders.example.com
```

**Browser:**
1. Open the PR (`compare/main...feat/orders-server-url`). `spectral-openapi-check` goes **red**.
2. **Details** → expand **Run Spectral (fail on errors)**. Zoom on:
   `14:10 error api-peak:rest17:2025-https-required server.url MUST use HTTPS.`
   The line below it has a link to the guideline.

**Terminal (fix):**
```bash
sed -i 's#http://orders.example.com#https://orders.example.com#' contracts/orders-openapi.yaml
git commit -am "Use HTTPS server URL"
git push
```

**Browser:** back on the PR, the check re-runs and goes green. Merge.

**Duration:** ~25s per CI run, ~1 min for the whole red → fix → green loop, measured. Most of a run is the `npm install` of spectral-cli, a good candidate to speed up in editing.

---

## Stage 3 — Contract testing (Microcks)

**Narrative:** "A contract is a promise. This proves the running code keeps it."

**Part 1: install the gate.**

**Prep:** `prep-stage.sh stage3` pushes branch `feat/add-contract-test-gate`. It adds the `contract-test` job (`needs: spectral-openapi-check`).

**On screen at the start:**
- Terminal 1: same clone, screen cleared.
- Browser tab 1: Gitea repo home, now with the `.gitea/` folder (spectral gate merged); the README lists one gate.
- Browser tab 2 (optional): Microcks `localhost:8080`, only if you want to show the test detail page in part 2. Otherwise open it from the CI log link at that moment.
- Terminal 2 (off camera): `stage3` already run. `stage3-red` **not yet**: run it after part 1 is merged.

**Terminal:**
```bash
git fetch origin
git switch feat/add-contract-test-gate
git diff origin/main -- .gitea/workflows/        # show the new job
```

**Browser:**
1. Open the PR (`compare/main...feat/add-contract-test-gate`). spectral and contract-test go green.
2. Merge.

**Part 2: the contract promises more than the code delivers.**

**Prep:** `prep-stage.sh stage3-red` pushes branch `feat/orders-currency`. It adds a **required** `currency` field to the order response. The running backend doesn't return it. Run it **after** part 1 is merged (it is cut from Gitea `main`).

**Terminal:**
```bash
git fetch origin
git switch feat/orders-currency
git diff origin/main -- contracts/               # new required field: currency
```

**Browser:**
1. Open the PR (`compare/main...feat/orders-currency`). spectral goes green, then **contract-test goes red**.
2. **Details** on contract-test → expand **Run contract test**. Microcks reports `currency' not found`.
3. Optional: open the `Details: http://localhost:8080/#/tests/…` link from that log to show the test in Microcks.

**Terminal (fix):** don't promise what the backend doesn't deliver yet.
```bash
sed -i 's/required: \[orderId, isPaid, currency\]/required: [orderId, isPaid]/' contracts/orders-openapi.yaml
git commit -am "Don't promise currency until the backend returns it"
git push
```

**Browser:** back on the PR, contract-test goes green. Merge.

**Duration:** ~45s per CI run (spectral ~25s, then contract-test ~20s). The red → fix → green loop takes ~1.5–2 min, measured.

---

## Stage 4 — API gateway (KrakenD)

**Narrative:** "Now expose it for real, and prove the gateway didn't change anything."

**Prep:** `prep-stage.sh stage4` pushes branch `feat/add-gateway-gate`. It adds the `gateway-deploy-check` job (`needs: contract-test`).

**On screen at the start:**
- Terminal 1: same clone, screen cleared. It also runs the `curl` commands (before the PR and at the end).
- Browser tab 1: Gitea repo home. Nothing else is needed.
- Terminal 2 (off camera): `stage4` already run.
- The KrakenD container is running with **no routes**: `curl -i http://localhost:8090/orders/123` returns `404`. `prep-stage.sh goto` (1 to 4) puts it in that state. This is the "before" of the stage.

**Terminal:**
```bash
curl -i http://localhost:8090/orders/123         # before: the gateway has no routes, 404
git fetch origin
git switch feat/add-gateway-gate
git diff origin/main -- .gitea/workflows/        # show the new job
```

**Browser:**
1. Open the PR (`compare/main...feat/add-gateway-gate`). **Three** gates appear: spectral, contract-test, gateway-deploy-check.
2. **Details** on gateway-deploy-check. Expand **Generate krakend.json from the PR contract** (shows the generated config), then **Deploy to the running gateway**, then **Run contract test through the gateway**.
3. Wait for green. Merge.

**Terminal (proof it's live):**
```bash
curl -i http://localhost:8090/orders/123     # after: 200, through KrakenD
curl -s http://localhost:8081/orders/123     # straight to the backend: identical body
```

**Duration:** ~80s for the CI run (spectral ~25s, then contract-test ~20s, then gateway ~30s), measured.

---

## Stage 5 — Backwards compatibility (new API version)

**Narrative:** "A partner is integrated now. An innocent-looking change would break them."

**Part 1: install the gate.**

**Prep:** `prep-stage.sh stage5` pushes branch `feat/add-backwards-compat-gate`. It inserts `breaking-changes-check` **between** spectral and contract-test, and repoints contract-test's `needs:` to it. This branch equals the project's real current pipeline.

**On screen at the start:**
- Terminal 1: same clone, screen cleared.
- Browser tab 1: Gitea repo home. Keep the window wide: the PR page lists four checks with long names.
- Terminal 2 (off camera): `stage5` already run. `stage5-red` **not yet**: run it after part 1 is merged.

**Terminal:**
```bash
git fetch origin
git switch feat/add-backwards-compat-gate
git diff origin/main -- .gitea/workflows/        # new job in the middle + repointed needs:
```

**Browser:**
1. Open the PR (`compare/main...feat/add-backwards-compat-gate`). All four gates go green.
2. Merge.

Say this out loud: "We insert this gate right after lint and before the runtime tests. A change that passes linting but breaks clients shouldn't even reach contract testing."

**Part 2: the gate catches a breaking change.**

**Prep:** `prep-stage.sh stage5-red` pushes branch `feat/orders-require-channel`. It adds a new **required** query parameter `channel` to `GET /orders/{orderId}`. Run it **after** part 1 is merged (it is cut from Gitea `main`).

**Terminal:**
```bash
git fetch origin
git switch feat/orders-require-channel
git diff origin/main -- contracts/               # new required param
```

**Browser:**
1. Open the PR (`compare/main...feat/orders-require-channel`). spectral goes green, then **breaking-changes-check goes red**.
2. contract-test and gateway-deploy-check show as **skipped (grey)**, because their `needs:` isn't satisfied. For the first few seconds after the red result they read "Blocked by required conditions" and only then turn to "Skipped": wait for it, then point at that.
3. **Details** on breaking-changes-check → expand **Run oasdiff breaking (fail on breaking changes)**. Zoom on:
   `error [new-required-request-parameter] … added the new required query request parameter channel`

**Terminal (fix):**
```bash
sed -i '/name: channel/,/required:/ s/required: true/required: false/' contracts/orders-openapi.yaml
git commit -am "Make channel optional (non-breaking)"
git push
```

**Browser:** back on the PR, all four gates run and go green. Merge. This is the climax, so keep it at full speed.

**Duration:** the red run takes ~45s (spectral ~25s, then the BC check ~20s). The final four-gate run takes ~90s. The whole red → fix → green loop is ~2.5 min, measured, the longest of the demo.

---

## Overall timing

About **8–10 minutes** of raw footage. Stages 1–2 are good candidates to speed up or narrate over. Keep Stage 5's final green run at full speed.

---

## Appendix — operator notes (off camera)

**Stack:** from the project directory (`~/projekty/devops-api-governance`, check with `pwd`; the older `devops-driven-governance` project uses the same container names and ports and cannot run at the same time):
`podman-compose --profile contract --profile catalog --profile gateway up -d`. On this machine it's the hyphenated `podman-compose` binary; `podman compose` may not exist. Endpoints:
- Gitea `localhost:3000` (demo/demo12345)
- Microcks `:8080`
- Backstage `:7007`
- backend `:8081`
- KrakenD `:8090`

**Run `prep-stage.sh reset` after every `podman-compose up`.** Anything that depends on the one-shot `gitea-seed` service re-runs it, and the seed force-pushes the full repo onto Gitea `main`, wiping the stage state. `backstage` depends on it. Never run it mid-demo.

**CI needs the internet.** Every job clones `actions/checkout` from github.com, and the jobs download spectral-cli (npm), oasdiff and the KrakenD CLI (GitHub releases). A flaky connection shows up as a check that fails before any step ran (`connection reset by peer` in the log), not as a real red result. Check your connection before recording. If a check fails that way, use the **Re-run** button on the run page, or push an empty commit: `git commit --allow-empty -m retry && git push`.

**Backstage:**
- `prep-stage.sh refresh-catalog` triggers the Gitea provider's scheduled task through the catalog's scheduler endpoint (`/api/catalog/.backstage/scheduler/v1/tasks/gitea-provider:local:refresh/trigger`, guest token). It rescans in a few seconds, without touching any container.
- **Never `podman start` / `podman restart` / `podman-compose up` for `backstage`.** It starts its dependency `gitea-seed`, which force-pushes the full repo over Gitea `main` and wipes the stage state (the full four-gate workflow would suddenly appear on `main` during Stage 1).

**backend can't be recreated while `krakend` runs** (podman: "has dependent containers"). That's why Stage 3's red demo changes the contract instead of toggling the backend's `DRIFT` mode: `DRIFT` is only read at startup.

**Recording format (open item, not solved yet):** clips must be smooth, continuous video, not a slideshow. `gif_creator` is frame-sampled, and converting its GIF to MP4 still looks like a slideshow. This needs a real screen recorder (Spectacle or OBS, both installed) running while the browser is driven. Wayland needs a one-time portal approval. If you record the whole demo solo, one continuous screen recording (terminal and browser side by side) also avoids any merging of separate clips.
