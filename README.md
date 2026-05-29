# Governance DevOps Demo

This repository is a local, self-contained DevOps and API governance demo. It shows how an organization can enforce API design rules early in the delivery process by combining:

- a local Git server, powered by Gitea;
- a local CI runner, powered by Gitea Actions `act_runner`;
- an OpenAPI-first workflow;
- a Spectral ruleset that encodes REST API governance rules;
- sample OpenAPI documents that demonstrate passing and failing API contracts.

The goal is not to deploy a production service. The goal is to simulate the control points around API delivery: source control, pull requests, automated quality gates, and policy-as-code validation.

## What This Simulates

This repository models a small internal platform where teams design APIs through pull requests.

The simulated environment includes:

- **Source control**: Gitea acts as the organization's Git hosting platform.
- **Pull request review**: changes to API contracts are proposed through PRs into `main`.
- **CI execution**: Gitea Actions runs validation jobs on pull requests.
- **API governance**: Spectral checks OpenAPI files against a project-specific ruleset.
- **Policy as code**: governance rules live in `spectral-ruleset.yaml` and custom JavaScript functions under `spectral-functions/`.
- **Runtime isolation**: Gitea data and runner data are stored locally, ignored by Git, and treated as disposable runtime state.

The demo is useful for showing how an API platform team can move guidelines from a document into automated checks that run before an API contract is merged.

## Repository Contents

Key files and directories:

- `.gitea/workflows/openapi-spectral.yml` defines the Gitea Actions workflow that runs Spectral on OpenAPI files during pull requests to `main`.
- `docker-compose.yml` starts the local Gitea server and the local Actions runner.
- `spectral-ruleset.yaml` contains the OpenAPI governance rules.
- `spectral-functions/` contains custom Spectral JavaScript functions used by the ruleset.
- `api-guidelines.md` documents the API design guidelines that the Spectral rules encode.
- `examples/openapi-valid.yaml` is a sample API contract intended to pass the ruleset.
- `examples/openapi-invalid.yaml` is a sample API contract intended to violate several rules.
- `gitea-data/` is local Gitea runtime state and is ignored by Git.
- `runner-data/` is local runner runtime state and is ignored by Git.

## Prerequisites

You need:

- Docker Desktop with Docker Compose support.
- Git.
- A shell that can run Docker commands. On Windows, use PowerShell from the repository root.
- Node.js/npm only if you want to run Spectral locally outside the CI runner.

The compose setup exposes:

- Gitea HTTP UI on `http://localhost:3000`.
- Gitea SSH on local port `2222`.
- A Docker network named `gitea-network`.

## Local Runtime Files

This repository intentionally does not track local runtime state.

Ignored local directories include:

- `gitea-data/`
- `runner-data/`
- `gitea-data.backup-*/`
- `gitea-reset-backups/`

This matters because Gitea continuously changes its database, sessions, queues, repositories, hooks, and indexes. Those files should remain local machine state, not project source code.

## First-Time Setup

Run all commands from the repository root.

### 1. Create `.env`

Create a local `.env` file. It is ignored by Git and should contain the Gitea secrets plus the runner registration token once you have one.

You can generate Gitea secrets with the Gitea container image:

```powershell
docker run --rm gitea/gitea:latest gitea generate secret SECRET_KEY
docker run --rm gitea/gitea:latest gitea generate secret INTERNAL_TOKEN
docker run --rm gitea/gitea:latest gitea generate secret JWT_SECRET
docker run --rm gitea/gitea:latest gitea generate secret JWT_SECRET
```

Then create `.env`:

```dotenv
GITEA_SECRET_KEY=<generated-secret-key>
GITEA_INTERNAL_TOKEN=<generated-internal-token>
GITEA_LFS_JWT_SECRET=<generated-jwt-secret>
GITEA_OAUTH2_JWT_SECRET=<generated-jwt-secret>

# Add this later after creating a runner registration token in Gitea.
GITEA_RUNNER_REGISTRATION_TOKEN=
```

Do not commit `.env`.

### 2. Create `runner-config.yaml`

The compose file mounts `runner-config.yaml` into the runner container. This local file tells job containers to join the same Docker network as Gitea, so checkout steps can reach `http://gitea:3000/` from inside CI jobs.

Create this file in the repository root:

```yaml
container:
  network: gitea-network
```

If the runner needs more advanced settings later, generate a full `act_runner` config and keep the `container.network` setting aligned with `gitea-network`.

### 3. Validate Compose

```powershell
docker compose config
```

This checks that Docker Compose can render the final configuration and that required environment variables are present.

### 4. Start Gitea

```powershell
docker compose up -d gitea
```

Open:

```text
http://localhost:3000
```

Complete the first-run Gitea setup in the browser. For a local demo, SQLite is already configured by `docker-compose.yml`.

### 5. Create or Mirror the Repository in Gitea

Create a user and a repository in Gitea, for example:

```text
andrzej/governance-demo
```

Then point this local repository at the local Gitea remote:

```powershell
git remote add gitea http://localhost:3000/andrzej/governance-demo.git
git push -u gitea main
```

If the `gitea` remote already exists, check it with:

```powershell
git remote -v
```

### 6. Register the Actions Runner

In Gitea, create a runner registration token. Depending on the Gitea version and UI, this is usually under site administration, user settings, organization settings, or repository actions runner settings.

Add the token to `.env`:

```dotenv
GITEA_RUNNER_REGISTRATION_TOKEN=<token-from-gitea>
```

Start the runner:

```powershell
docker compose up -d gitea-runner
```

Check the containers:

```powershell
docker compose ps
```

The runner should appear in Gitea as available with the label:

```text
ubuntu-latest
```

The workflow uses that label in `.gitea/workflows/openapi-spectral.yml`.

## Running the Demo

The main demo flow is:

1. Start Gitea and the runner.
2. Push this repository to the local Gitea remote.
3. Create a feature branch.
4. Modify or add an OpenAPI file.
5. Push the branch to Gitea.
6. Open a pull request into `main`.
7. Watch Gitea Actions run the Spectral validation workflow.

Example:

```powershell
git checkout -b demo/openapi-change
git push -u gitea demo/openapi-change
```

Open Gitea at `http://localhost:3000`, create a pull request from the branch into `main`, and inspect the Actions result.

## Local Spectral Validation

You can run the same kind of validation locally without Gitea.

Run Spectral on the valid example:

```powershell
npx -y @stoplight/spectral-cli lint -r spectral-ruleset.yaml examples/openapi-valid.yaml
```

Run Spectral on the invalid example:

```powershell
npx -y @stoplight/spectral-cli lint -r spectral-ruleset.yaml examples/openapi-invalid.yaml
```

The invalid example intentionally violates rules such as:

- OpenAPI version recommendation.
- API title casing and suffix.
- semantic version format.
- HTTPS requirement.
- URI and path parameter naming conventions.
- Problem Detail response format.
- nullable boolean restrictions.

To validate every tracked OpenAPI file locally:

```powershell
git ls-files '*openapi*.yml' '*openapi*.yaml' | ForEach-Object {
  npx -y @stoplight/spectral-cli lint -r spectral-ruleset.yaml $_
}
```

## Governance Rules

The ruleset extends Spectral's built-in OpenAPI rules and adds organization-specific checks. The custom rules are based on the API guidance in `api-guidelines.md`.

Examples of enforced or recommended practices:

- OpenAPI documents must use OpenAPI 3.x.y and should use 3.1.y.
- `info.title` must be Title Case and end with `API`.
- `info.version` must use semantic versioning.
- JSON property names should use camelCase.
- schema object names should use PascalCase.
- boolean fields must not allow `null`.
- arrays and objects must not be nullable.
- array property names should be plural.
- paths must use kebab-case and must not end with `/`.
- URI template variables must comply with RFC 6570.
- headers must use Hyphenated-Pascal-Case.
- APIs must use HTTPS server URLs.
- error responses must use `application/problem+json`.
- Problem Detail schemas must define required fields such as `type`, `title`, and `detail`.

Rules use severities:

- `error` for mandatory governance requirements.
- `warn` for recommended practices.
- `info` for optional guidance.

## CI Workflow

The Gitea Actions workflow is stored at:

```text
.gitea/workflows/openapi-spectral.yml
```

It runs on pull requests targeting `main`.

The job:

1. Checks out the PR branch.
2. Shows Node.js and npm versions.
3. Installs `@stoplight/spectral-cli`.
4. Finds tracked files matching `*openapi*.yml` and `*openapi*.yaml`.
5. Runs Spectral with `spectral-ruleset.yaml`.

This simulates a real governance gate where API contracts are checked automatically before merge.

## Operational Notes

### Gitea Persistence

Gitea data is stored in:

```text
gitea-data/
```

The runner cache and runtime data are stored in:

```text
runner-data/
```

Both directories are intentionally local and ignored by Git.

### Docker Socket

The runner mounts:

```text
/var/run/docker.sock
```

This lets Gitea Actions start job containers through Docker. This is convenient for a local demo, but it gives the runner broad control over the local Docker daemon. Treat it as a local development setup, not as a hardened production pattern.

### Runner Network

The runner uses `runner-config.yaml` so CI job containers join `gitea-network`. Without this, a job container may not be able to reach the Gitea server at `http://gitea:3000/` during checkout.

### Docker API Version

`DOCKER_API_VERSION=1.44` is set for the runner to avoid compatibility problems with Docker Desktop versions where the client may try a newer API than the daemon supports.

## Stopping and Resetting

Stop containers:

```powershell
docker compose down
```

Stop containers and remove local Gitea/runner state:

```powershell
docker compose down
Remove-Item -Recurse -Force .\gitea-data, .\runner-data
```

Only remove those directories if you are comfortable losing local Gitea users, repositories, sessions, Actions data, and runner state.

## Common Troubleshooting

### `docker compose config` Reports Empty Variables

Make sure `.env` exists and includes:

```dotenv
GITEA_SECRET_KEY=...
GITEA_INTERNAL_TOKEN=...
GITEA_LFS_JWT_SECRET=...
GITEA_OAUTH2_JWT_SECRET=...
```

The runner token is only required when starting `gitea-runner`.

### Runner Cannot Checkout the Repository

Check that:

- `runner-config.yaml` exists.
- it contains `container.network: gitea-network`.
- Gitea is running.
- the runner is running.
- the workflow uses `runs-on: ubuntu-latest`.
- the runner label includes `ubuntu-latest:docker://node:20-bullseye`.

### `git status` Shows `gitea-data/`

It should not, because `gitea-data/` is ignored and should not be tracked. If it appears as untracked, confirm `.gitignore` contains:

```gitignore
gitea-data/
```

If files were accidentally tracked again, untrack them without deleting local data:

```powershell
git rm -r --cached gitea-data/
```

Then commit the cleanup.

## Current Remote

The local Gitea remote commonly used by this demo is:

```text
http://localhost:3000/andrzej/governance-demo.git
```

You can verify your configured remotes with:

```powershell
git remote -v
```

