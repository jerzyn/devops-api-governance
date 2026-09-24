# Sample Orders API — consumer repo

This is the **product/consumer repository**: the API contract, its catalog
entry, and the backend implementation. It is the unit a product team owns and
opens pull requests against.

## Contents

| Path | Purpose |
|------|---------|
| `contracts/orders-openapi.yaml` | The OpenAPI contract (source of truth for the API). |
| `catalog-info.yaml` | Backstage entities (API + Component + Group), discovered from Gitea. |
| `sample-backend/` | The provider implementation. |

## Catalog

Backstage discovers `catalog-info.yaml` from Gitea, so the API is visible to
the whole organisation. Merging a change to it updates the API's catalog entry.

## PR loop

1. Branch, edit `contracts/orders-openapi.yaml` and/or `sample-backend/`.
2. Push, open a PR into `main` in Gitea (`http://localhost:3000`, `demo` / `demo12345`).
3. Merge. There are no automated checks yet.
4. Backstage re-discovers `catalog-info.yaml` and updates the API entity.
