# Cue card

One page per take. Off camera between steps: `demo next`. Before each take: `demo preflight` → `READY`.
Opening a PR: `compare/main...<branch>` → **New Pull Request** → **Create Pull Request**. Merging: **Create merge commit**.

| # | Terminal (recorded) | Browser | Say |
|---|---|---|---|
| 1 | `git switch feat/add-catalog-entry` · `head -40 catalog-info.yaml` · `git push -u origin feat/add-catalog-entry` | PR (no checks) → merge → Backstage → APIs → Order Events API → Definition, Dependencies | "We put the API where people look for APIs." |
| 2 | `git switch feat/add-lint-gate` · `git diff --stat main` · `git push -u origin feat/add-lint-gate` | PR → Files changed → green → merge | "Lint against the guidelines, on every PR." |
| 2-red | `git switch feat/order-paid-at` · `git diff main -- contracts/` · `git push -u origin feat/order-paid-at` | PR → red → Details: `api-peak:async11 ... 'paid_at' MUST be camelCase` → click the link | "The rule links to the guideline." |
| fix | `sed -i 's/^        paid_at:$/        paidAt:/' contracts/order-events-asyncapi.yaml` · `git commit -am "Name it paidAt"` · `git push` | green → merge | |
| 3 | `git switch feat/add-contract-test-gate` · `git diff --stat main` · `git push -u origin feat/add-contract-test-gate` | PR → green → merge | "Microcks listens on the broker." |
| 3-red | `git switch feat/order-currency` · `git diff main -- contracts/` · `git push -u origin feat/order-currency` | PR → red → Details: `required property 'currency' not found` (5 of 5) | "The contract promises what the backend doesn't send." |
| fix | `sed -i 's/required: \[orderId, createdAt, currency\]/required: [orderId, createdAt]/' contracts/order-events-asyncapi.yaml` · `git commit -am "currency is optional"` · `git push` | green → merge | |
| 4 | `git switch feat/add-broker-policy-gate` · `git diff --stat main` · `git push -u origin feat/add-broker-policy-gate` | PR → broker-policy log: the generated policy → green → merge | "The contract decides who may publish and subscribe." |
| deny | `demo deny` | (slides: ACL animation) | "The broker says no." |
| 5 | `git switch feat/add-breaking-changes-gate` · `git diff --stat main` · `git push -u origin feat/add-breaking-changes-gate` | PR → green → merge → Actions: Publish API (main) | "After a merge, the schemas are registered." |
| 5-red | `git switch feat/drop-is-paid` · `git diff main -- contracts/` · `git push -u origin feat/drop-is-paid` | PR → red → Details: `not FORWARD-compatible`; later gates skipped | "Consumers still read isPaid." |
| fix | `git checkout main -- contracts/order-events-asyncapi.yaml` · `sed -i '/^        isPaid:$/{n;s/$/\n          deprecated: true/}' contracts/order-events-asyncapi.yaml` · `git commit -am "Deprecate isPaid"` · `git push` | all green → merge | "Deprecate, don't delete." |
| 6 | `DEMO_SHELL_REPO=kafka demo shell` · `git switch feat/kafka-paid-at` · `git push -u origin feat/kafka-paid-at` | Kafka repo PR → all green → merge | "Same gates on Kafka." |
| 6-red | (`demo next` off camera) `git switch feat/kafka-drop-is-paid` · `git push -u origin feat/kafka-drop-is-paid` | PR → red: `orders.order-paid.v1 ... not FORWARD-compatible` | end |

Retake: `demo goto <1|2|2-red|3|3-red|4|5|5-red|kafka|end>`, then `demo shell`, then `demo preflight`.
