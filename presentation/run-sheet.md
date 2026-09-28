# Run sheet: FOST London, 1 October 2026, 12:45

DevOps-Driven API Governance · 20 minutes · Q&A after (~5 min) · [deck](https://claude.ai/artifact/AUkTCc1xev8nuvEcBELiU2)

| # | Slide | Done by | Key line |
|---|---|---|---|
| 1 | Title | 0:15 | "One gate at a time, in a real, working repo." |
| 2 | About me | 0:35 | API Peak; adidas, ING, PZU |
| 3 | The book | 0:45 | Cover + Amazon QR, ten seconds |
| 4 | Hook | 1:15 | "Your next API consumer is an agent. It takes your contract literally." |
| 5 | Agents (PZU) | 2:05 | 70–80% → **99.6%**; ~60% → **>90%** with Arazzo |
| 6 | Why governance | 2:55 | "The developer can now be an agent." |
| 7 | Premises | 3:45 | Open source & sovereign: residency, no lock-in |
| 8 | One API, one partner | **4:30** ✔ | Orders API + fintech agent; empty pipeline |
| 9 | Step 1: can't see | 5:10 | "You can't govern what you can't see." |
| 10 | One file | 5:40 | `catalog-info.yaml`, that's the cost |
| 11 | ▶ Catalog (35 s) | 6:15 | Merge → `orders-api` appears |
| 12 | Step 2 + adidas story | 7:15 | "A guideline nobody enforces is a suggestion." |
| 13 | ▶ Spectral (68 s) | 8:25 (+3 s) | `rest17` red → link to the rule → fix → green |
| 14 | Takeaway 2 | **8:52** ✔ | Feedback in seconds, not weeks |
| 15 | Step 3: a promise | 9:27 | Integrate before it exists? Code keeps the promise? |
| 16 | ▶ Microcks (100 s) | 11:07 (−5 s) | Live mock; `currency' not found` |
| 17 | Takeaway 3 | 11:42 | One example: mock + test |
| 18 | Step 4: gateway | 12:17 | Generated from the contract |
| 19 | ▶ KrakenD (70 s) | 13:27 | 404 → 200 through the gateway |
| 20 | Takeaway 4 | **13:57** ✔ | Generated, deployed, proven |
| 21 | Step 5: partner live | 14:27 | Innocent change |
| 22 | ▶ oasdiff (74 s) | 15:41 | `new-required-request-parameter`; later gates skipped |
| 23 | Takeaway 5 | 16:16 | Explicit decision, not an accident |
| 24 | Whole pipeline | 16:46 | "You don't need five gates on day one." Audit trail. |
| 25 | Monday morning | 17:31 | Track all APIs · top 5 rules as lint · diff your top API |
| 26 | Thank you | **18:01** ✔ | Codeberg repo QR |
| 27 | Feedback | Q&A | FOST feedback QR: leave it up during questions |

**Checkpoints** ✔: 4:30 · 8:52 · 13:57 · 18:01. About 2:00 of buffer.

**Behind? Skip in this order:** slide 10 (say it in one sentence on slide 9) · talk over the Microcks UI part of clip 3 without pausing · slide 20's code (say "404 to 200").

**Videos:** click the video to start it. They are silent and loop: move on at the merge.

**Backup (no internet):** `DevOps-Driven API Governance — FOST London 2026.html` in a browser (F11, click a video to play), or the `.pdf` in Okular (Ctrl+Shift+P), or the `.pptx` in LibreOffice.
