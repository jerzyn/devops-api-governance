---
title: DevOps-Driven API Governance
sub_title: API Days Munich 2026
authors:
  - Andrzej Jarzyna
  - Krzysztof Madeński
theme:
  path: theme.yaml
options:
  implicit_slide_ends: true
  h1_slide_titles: true
---

# About Andrzej Jarzyna

- Role / title — TBD
- Organization — TBD
- Focus: API governance, DevOps, platform engineering

# About Krzysztof Madeński

- Role / title — TBD
- Organization — TBD
- Focus: API design, delivery automation

# Why automating governance

- Manual reviews don't scale across many teams and APIs
- Shift-left: catch issues before merge, not in production
- Consistent policy applied on every pull request
- Documented → discovered → delivered

# The CI pipeline — build the app and deploy

- Gitea as local Git server + pull requests
- Gitea Actions (`act_runner`) runs governance gates on every PR
- Consumer repo (`example/`) is the product unit under test
- Governance rules are linked at CI time, not vendored

# Start cataloging your APIs

- Add `catalog-info.yaml` to your API repo
- Backstage discovers entities from the Gitea org
- APIs appear with their OpenAPI document and links
- Single place to find who owns what

# Ensure good-enough design

- Spectral lints PR-changed OpenAPI files
- Central ruleset in `governance/spectral/`
- Custom functions encode organization guidelines
- Fails the gate on error-severity findings

# Avoid the risk of API drift

- Microcks contract-tests the running provider
- Contract imported from the PR branch
- Implementation tested against the spec in CI
- Catches drift between code and contract

# Ensure updates don't break your clients

- oasdiff diffs modified OpenAPI against the base branch
- Fails on ERR-severity breaking changes
- Blocks new required params, removed fields, removed operations
- Consumers stay safe without manual diff review

# The full image

<!-- include: diagrams/governance-pipeline.md -->

# Next steps

- Run the local demo: `docker compose --profile contract --profile catalog up -d`
- Walk through the PR governance loop (`tests/pr-governance.feature.md`)
- Refine this deck — bios, visuals, speaker notes
