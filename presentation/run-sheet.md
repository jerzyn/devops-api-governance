# Run sheet: FOST London, 1 October 2026, 12:45

DevOps-Driven API Governance · 20 minutes · Q&A after (~5 min) · [deck](https://claude.ai/artifact/AUkTCc1xev8nuvEcBELiU2)

| # | Slide | Done by | Key line |
|---|---|---|---|
| 1 | Title | 0:15 | "One gate at a time, in a real, working repo." |
| 2 | About me | 0:45 | API Peak; adidas, ING, PZU; the book |
| 3 | Hook | 1:15 | "Your next API consumer is an agent. It takes your contract literally." |
| 4 | Agents (PZU) | 2:05 | 70–80% → **99.6%**; ~60% → **>90%** with Arazzo |
| 5 | Why governance | 2:55 | "The developer can now be an agent." |
| 6 | Premises | 3:45 | Open source & sovereign: residency, no lock-in |
| 7 | One API, one partner | **4:30** ✔ | Orders API + fintech agent; empty pipeline |
| 8 | Step 1: can't see | 5:10 | "You can't govern what you can't see." |
| 9 | One file | 5:40 | `catalog-info.yaml`, that's the cost |
| 10 | ▶ Catalog (35 s) | 6:15 | Merge → `orders-api` appears |
| 11 | Step 2 + adidas story | 7:15 | "A guideline nobody enforces is a suggestion." |
| 12 | ▶ Spectral (65 s) | 8:22 | `rest17` red → link to the rule → fix → green |
| 13 | Takeaway 2 | **8:52** ✔ | Feedback in seconds, not weeks |
| 14 | Step 3: a promise | 9:27 | Integrate before it exists? Code keeps the promise? |
| 15 | ▶ Microcks (107 s) | 11:12 | Live mock; `currency' not found` |
| 16 | Takeaway 3 | 11:42 | One example: mock + test |
| 17 | Step 4: gateway | 12:17 | Generated from the contract |
| 18 | ▶ KrakenD (70 s) | 13:27 | 404 → 200 through the gateway |
| 19 | Takeaway 4 | **13:57** ✔ | Generated, deployed, proven |
| 20 | Step 5: partner live | 14:27 | Innocent change |
| 21 | ▶ oasdiff (104 s) | 16:22 | `new-required-request-parameter`; later gates skipped |
| 22 | Takeaway 5 | 16:57 | Explicit decision, not an accident |
| 23 | Whole pipeline | 17:27 | "You don't need five gates on day one." Audit trail. |
| 24 | Monday morning | 18:12 | Track all APIs · top 5 rules as lint · diff your top API |
| 25 | Thank you | **18:42** ✔ | Codeberg QR · FOST feedback QR |

**Checkpoints** ✔: 4:30 · 8:52 · 13:57 · 18:42. About 1:15 of buffer.

**Behind? Skip in this order:** slide 9 (say it in one sentence on slide 8) · talk over the Microcks UI part of clip 3 without pausing · slide 19's code (say "404 to 200").

**Videos:** click the video to start it. They are silent and loop: move on at the merge.

**Backup:** no internet → `FOST London 2026 - DevOps-Driven API Governance.pdf` in Okular (Ctrl+Shift+P), click a video page to play.
