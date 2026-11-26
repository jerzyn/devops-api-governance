# Events: notes for presenters

The event API now goes through the demo **in the same pull requests as the REST API**: every step is one PR in the orders repo that governs both. The current steps, commands and branch names are in [`../cue-card.md`](../cue-card.md), and the `demo` command is described in [`../README.md`](../README.md). To install and start the stack, see the [main README](../../README.md).

## What is here

| File | What it is |
|------|------------|
| [`acl-animation.html`](acl-animation.html) | The broker policy, animated for the slides: what the contract allows passes the broker, the rest is denied. Open it in a browser; Space or → steps, `A` autoplays, `K` switches between MQTT and Kafka (`?protocol=kafka&autoplay` in the URL does the same). Works offline. |
| `acl-*.png` | Stills of the animation. |

## The event half of each step

1. **Catalog**: the merge puts the Order Events API in Backstage next to the Orders API, with its producer, consumer and broker.
2. **Lint**: `paid_at` breaks the property naming rule; the error links to the guideline in Backstage.
3. **Contract test**: Microcks listens on the broker and catches a required field the backend never sends.
4. **Broker policy**: the policy is generated from the contract and the catalog; `demo deny` shows the broker refusing the rest.
5. **Breaking changes**: removing `isPaid` fails the registry's FORWARD check; deprecating it passes.
6. **Kafka** (after step 5, its own repo): its catalog entry and an optional field pass all four gates, and the Kafka API joins the catalog; removing `isPaid` is red there too.
