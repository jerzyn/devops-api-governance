# Deck plan: "DevOps-Driven API Governance" at FOST London 2026

The plan for the new talk deck. It replaces the Munich deck (`DevOps Driven Governance - London 2026.pdf`) and applies every change in [`deck-changes.md`](deck-changes.md).

## The talk

| | |
|---|---|
| Event | FOST London 2026, Convene Sancroft, St. Paul's |
| Slot | **1 October 2026, 12:45**. 20 min of content, then ~5 min Q&A (not part of the 20 min) |
| Speaker | Andrzej Jarzyna, alone (no Krzysztof slide) |
| Audience | Software architects, business leaders, integration engineers, IT product owners; banking, insurance, IT and more |
| Event theme | The main API consumer is now an autonomous agent ("from Open Banking to Actionable Banking") |
| Setup | Own Linux laptop over HDMI |

**Core message:** governance is about the developer experience of creating and using APIs, and the developer can now be an agent. Put the rules in the pipeline, one gate at a time, and every API becomes easy to find, correct, testable, safely exposed and safe to change, for humans and agents alike.

**The thread:** one API and one partner through the whole talk. The **Orders API**, and a **fintech partner building an AI agent** on it. The partner integrates against the mock in Step 3, and it is the partner Step 5 protects from a breaking change.

## Deliverables

| File | What | Where |
|---|---|---|
| Slides artifact | Main deck, played in the browser, videos embedded | https://claude.ai/artifact/AUkTCc1xev8nuvEcBELiU2 |
| `presentation/FOST London 2026 - DevOps-Driven API Governance.pdf` | Offline fallback: the same deck with the five MP4s embedded in the PDF | git *(pending)* |
| `presentation/run-sheet.md` | One page: slide, clock time, key line | git |
| `presentation/recordings/stage{1..5}-talk.mp4` | The five cut clips | git-ignored, like all recordings |

## Format

- **Primary:** Slides artifact. Runs in any browser, videos play in place, speaker notes, presenter view.
- **Fallback:** PDF with the MP4s embedded as Screen annotations (added with `pikepdf` to the PDF export of the deck). Plays in **Okular** (the default PDF viewer on the laptop), click to play. Evince, Firefox and Chrome show only the still frame.
- **Gate before the full PDF build:** a two-slide test PDF with one video, opened in Okular presentation mode (Ctrl+Shift+P). If a click doesn't play it, fall back to a link annotation that opens the embedded file in the system player.
- **Last resort:** the five `-talk.mp4` files in `mpv`.

## Videos

The recordings have no audio, and Andrzej narrates live. Each stage's "a" clip (install the gate) and "b" clip (the gate catches something) are merged into one clip per step. Key moments play at 1×, and pushes, PR creation and CI waits are sped up (`ffmpeg` `setpts`). Cut points are chosen frame by frame (25 fps), not from the 4 s contact sheets below. The times here are approximate and mark the content, not the exact frames.

Source: `presentation/recordings/stage*-1080.mp4`. Output: `presentation/recordings/stageN-talk.mp4`. The originals stay untouched.

| Clip | Parts (source time → speed) | Target |
|---|---|---|
| **stage1** | `1` whole → 1.25×: merge `catalog-info.yaml`, `orders-api` appears in Backstage, Definition tab | ~35 s |
| **stage2** | `2a` 0:16–0:30 → 1×: PR with the new gate, Backstage API Guidelines docs · `2b` 0:00–0:24 → 2×: diff (`http://`), push, PR · `2b` 0:24–0:44 → 1×: red, `rest17:2025-https-required`, link opens the rule in Backstage · `2b` 0:44–1:20 → 2×: fix, push, green, merge | ~67 s |
| **stage3** | `3a` 0:20–0:28 → 1.5×: PR shows `contract-test` · `3a` 0:44–1:02 → 1×: `curl` the live mock, Microcks UI · `3b` 0:00–0:24 → 2×: diff adds `currency`, push, PR · `3b` 0:24–1:08 → 1×: red, Microcks test detail, `currency' not found`, `curl` mock vs backend · `3b` 1:08–1:56 → 2×: fix, push, green, merge | ~105 s |
| **stage4** | 0:00–0:04 → 1×: `curl` 404 · 0:04–0:44 → 2×: switch, push, PR, Files changed · 0:44–1:04 → 1×: generate `krakend.json`, validate, deploy, contract test through the gateway · 1:04–1:16 → 2×: green, merge · 1:16–1:35 → 1×: `curl` 200 through KrakenD, same body as the backend | ~70 s |
| **stage5** | `5a` 0:20–0:36 → 1×: Files changed, new job in the middle, `needs:` repointed · `5a` 0:40–1:04 → 3×: four gates green · `5b` 0:00–0:20 → 1.5×: diff with required `channel` · `5b` 0:28–1:04 → 1×: breaking-changes red, later gates Skipped, `new-required-request-parameter` · `5b` 1:04–1:40 → 2×: fix (`required: false`), push · `5b` 1:40–2:48 → 3×: all four green, merge | ~115 s |

Total ~6.5 min of video (from 11.8 min). Andrzej reviews the five clips before they go into the deck.

## Design

Same identity as the Munich deck, cleaned up:

- **Colors:** navy `#323a4d` (section and video backgrounds), beige `#ede3da` (closing slides), white content slides. Red and green only for gate results.
- **Type:** Merriweather headings, Roboto body, a monospace font for code and terminal lines at least 2× the old deck's size.
- **Video slides:** video full width on navy, small step label in a corner.
- **Pipeline diagram:** redrawn once as vector graphics and built up step by step. Finished gates solid, the current gate highlighted, future gates faded. Order as in the real `needs:` chain: **Catalog · API Guidelines (Spectral) → Breaking Changes (oasdiff) → Contract Testing + Mocks (Microcks) → API Gateway (KrakenD) → Deploy**.
- **Takeaway slides:** one large key line from the video (readable on a projector, unlike the terminal text in the recording), plus one "for agents" line.
- **No old screenshots** that show `pzu:` rule IDs or PZU URLs (old p18, p20). The repo now uses the "API Peak" brand.

## Slide order and timing

The clock column is where the talk should be at the end of that slide.

| # | Slide | Content | Source | Time | Clock |
|---|---|---|---|---|---|
| **Open** | | | | **3:15** | |
| 1 | Title | DevOps-Driven API Governance · FOST London 2026 · Andrzej Jarzyna, API Peak | p1 | 0:15 | 0:15 |
| 2 | About me | Founder of **API Peak** (API strategy and governance services, community products). Before: 3scale, iWelcome, adidas (API Evangelist, contract repository, CI quality gates), ING (API Governance, Policy as Code), PZU (Chief API Architect: governance from zero, 200+ external APIs, 30+ products, APIs ready for AI agents). Co-author, *RESTful API Design Patterns and Best Practices* (Packt). Mountain photo. | p2 + LinkedIn | 0:30 | 0:45 |
| 3 | Hook | "Your next API consumer is an agent. It can't read your wiki or ask on Slack. It takes your contract literally." | new | 0:30 | 1:15 |
| 4 | Agents and APIs | PZU test: agents on bare OpenAPI ~70–80% accurate → **99.6%** with what governance already requires (descriptions, Problem Details, examples). Multi-step: ~60% → **>90%** with Arazzo. "AI readiness isn't a separate project. It falls out of governance done right." | new (PZU, named) | 0:50 | 2:05 |
| 5 | Why governance | Sprawl image. "Governance is about the developer experience of creating and using APIs, and the developer can now be an agent." Easy to do right, hard to do wrong; good governance is invisible. | p4 + p5 + p6 | 0:50 | 2:55 |
| **Setup** | | | | **1:35** | |
| 6 | Premises | Design-first · the contract is the single source of truth · configuration as code · any CI. **Open source & sovereign:** no vendor lock-in, the right tool for each task instead of customizing one heavy platform; **data and business residency**: you choose where contracts and data are processed and under which jurisdiction, with no access for unwanted actors. | p7 | 0:50 | 3:45 |
| 7 | Meet the Orders API | The thread: Orders API + fintech partner building an agent. Empty pipeline: repo → PR → CI → merge → deploy. | p8 + new | 0:45 | 4:30 |
| **Step 1: Catalog** | | | | **1:45** | |
| 8 | "You can't govern what you can't see" | Org dependency graph; pipeline with Catalog highlighted | p9 + p11 | 0:40 | 5:10 |
| 9 | One file, that's the whole cost | `catalog-info.yaml`, fixed per `deck-changes.md` C (`name: orders-api`, `owner` under `spec`, `lifecycle: experimental`) | p12 | 0:30 | 5:40 |
| 10 | ▶ stage1 | | video | 0:35 | 6:15 |
| **Step 2: Guidelines as code** | | | | **2:37** | |
| 11 | "A guideline nobody enforces is a suggestion" | Pipeline with API Guidelines highlighted. **adidas story** (see below). | p17 + new | 1:00 | 7:15 |
| 12 | ▶ stage2 | | video | 1:07 | 8:22 |
| 13 | Takeaway | `api-peak:rest17:2025-https-required`: rule, file, line and fix in one line. **Feedback in seconds, not weeks.** Same rules for humans and CI, one source of truth. For agents: descriptions and examples are what lift accuracy to 99.6%. | p18 + p20 | 0:30 | 8:52 |
| **Step 3: Mocks and contract testing** | | | | **2:50** | |
| 14 | "A contract is a promise" | Pipeline with Contract Testing + Mocks highlighted. Q1: can the partner integrate before the API exists? Q2: does the code keep the promise? | p23 | 0:35 | 9:27 |
| 15 | ▶ stage3 | | video | 1:45 | 11:12 |
| 16 | Takeaway | One `examples:` block gives both the mock and the test. For agents: build and test the agent against the mock before the API exists. | p27 (no MCP line) | 0:30 | 11:42 |
| **Step 4: API gateway** | | | | **2:15** | |
| 17 | "Expose it, generated from the contract" | Pipeline with API Gateway highlighted. Hand-written gateway config drifts from the catalog. | A1 + A2 | 0:35 | 12:17 |
| 18 | ▶ stage4 | | video | 1:10 | 13:27 |
| 19 | Takeaway | Trimmed generated `krakend.json`; 404 → 200; the same contract test runs through the gateway. For agents: what runs is what the agent read. | A3 + A4 | 0:30 | 13:57 |
| **Step 5: Breaking changes** | | | | **3:00** | |
| 20 | "Now the partner is integrated" | Pipeline with Breaking Changes highlighted, placed before the runtime tests | p29 | 0:30 | 14:27 |
| 21 | ▶ stage5 | | video | 1:55 | 16:22 |
| 22 | Takeaway | `new-required-request-parameter` … `channel`. Blocked before merge, before deploy, before the incident; later gates don't even run. An explicit decision, not an accident: optional now, or a new major version (`rest40`). For agents: a human reads the changelog, an agent just fails, at scale. | p31 + p32, fixed per B | 0:35 | 16:57 |
| **Close** | | | | **1:45** | |
| 23 | The whole pipeline | All five gates, one contract. **"You don't need five gates on day one. Add one at a time, like we just did."** Every change is a PR with recorded gate results: an audit trail for free. Open source and sovereign, in one line. | p33, fixed per B5 | 0:30 | 17:27 |
| 24 | Monday morning | 1. Track all your APIs in one place, even from a monorepo. 2. Turn your top 5 guideline rules into a CI lint, warnings first. 3. Run a breaking-change diff on your most-used API. | new | 0:45 | 18:12 |
| 25 | Thank you | Codeberg repo QR (`codeberg.org/pierogi/devops-api-governance`) · FOST feedback QR · book | p34 + p35 | 0:30 | 18:42 |
| — | Appendix (hidden) | Q&A prep, see below | new | — | — |

**Total ~18:45, ~1:15 buffer.** 25 slides (Munich deck: 35).

**Dropped from the Munich deck:** Krzysztof slide (p3), empty slide, p10, p13–p15, p19, p21, p24–p26, p30 (the videos show them); the six separate pipeline diagrams (one diagram now builds up); the "generic MCP mock" line (not built).

### The adidas story (slide 11)

Told as the bridge from Step 1 to Step 2, in about 40 s:

- adidas had API guidelines. They existed and people knew them, but they were followed closely only when a team came to the API team for help with the design.
- Then an API contract repository was introduced, and it also checked how APIs followed the rules. For the first time the real picture was visible, and it was quite incomplete. (That is Step 1: you can't govern what you can't see.)
- The change came only when Spectral and contract testing moved from the guidelines into the CI pipelines.
- "A guideline nobody enforces is a suggestion."

## Beyond the slides

- **Speaker notes on every slide:** 2–4 talking points (not a script), the target clock time, and the transition sentence to the next slide.
- **Video cue lists:** in each video slide's notes, timed to the cut clip, e.g. "0:12 red check, say: one finding, and the link opens the rule".
- **Checkpoints:** 4:30 (end of Setup), 8:52 (end of Step 2), 13:57 (end of Step 4), 18:42 (end). The notes say what to skip if you are behind (in order: slide 9, the 3a Microcks UI part, slide 19's code block).
- **Run sheet:** one page: slide, clock time, key line.
- **Q&A appendix (hidden slides after Thank you):** short answers for likely questions:
  - Backstage is heavy; what is lighter? (Any catalog that reads files from repos; the point is "track all your APIs".)
  - How do you ship a breaking change you truly need? (`rest40`: new major version or new resource, run both, deprecate.)
  - Does this work with Kong, Apigee or Azure APIM? (Yes: the gateway config is generated from the contract; only the generator changes.)
  - How did PZU get 30+ product teams to adopt it? (Federated governance team, minimal but mandatory standards, start minimal and nudge.)
  - Warnings or errors from day one? (Warnings first, promote rules to errors once teams are clean.)
  - What about AsyncAPI and events? (Same gates exist: lint, diff, catalog.)
  - Where do agents fit, MCP? (Well-governed OpenAPI plus Arazzo gets most of the way; the MCP mock is roadmap, not built.)
  - How do you know which guidelines are really enforced? (Completeness Verification: ask an AI which style-guide rules could be lint checks, compare with CI.)
- **Backup:** no internet → the PDF in Okular. Okular problem → the five `-talk.mp4` files in `mpv`.

## Schedule

| When | What |
|---|---|
| Sun 27 Sep | Cut the five clips (review) → Slides artifact v1 → first rehearsal at home |
| Mon 28 Sep | Fixes from rehearsal → Okular test PDF → full PDF with videos → run sheet → second rehearsal |
| Tue 29 – Wed 30 Sep | Polish; final PDF committed; test HDMI output with the laptop |
| Thu 1 Oct, 12:45 | Talk. Rehearse once before. |
