## General guidelines

- **TDD-first**: Always write or update tests *before* generating or changing any application code or configuration that affects behavior.
- **Test before commit**: Always run the relevant test or validation command (e.g. `docker compose config`, automated tests, linting) and ensure it passes before committing.
- **Fine-grained commits**: Commit to Git every single step and sub-step so that each commit represents one small, reviewable change.
- **Single Docker context**: Prefer running `docker` and `docker compose` commands from Windows PowerShell against Docker Desktop, using this repository’s `docker-compose.yml` directly.
- **Explicit WSL usage**: When WSL is required, always specify the distro explicitly (e.g. `wsl -d Ubuntu-24.04 -- ...`) and avoid mixing host and WSL paths in the same command.
- **Secrets handling**: Never commit real secrets; use `.env` files or environment variables for values like `GITEA_RUNNER_REGISTRATION_TOKEN`, and document the required variables here instead.
- **Document every step**: For each significant change (new services, workflows, scripts), add a short description and “how to run” notes to this file so the demo remains reproducible.

## Step 1: Local Gitea and Actions runner

- **Goal**: Provide a self-contained Git + CI environment for demos, entirely on the local machine.
- **Implementation**:
  - Added `docker-compose.yml` defining:
    - `gitea`: Gitea server using SQLite for simplicity, exposing HTTP on port 3000 and SSH on 2222.
    - `gitea-runner`: Gitea `act_runner` service connected to the Gitea instance and host Docker via `/var/run/docker.sock`.
  - Configured Gitea with Actions explicitly enabled and an internal URL `http://gitea:3000/` for the runner.
- **How to run**:
  - Ensure Docker is available inside WSL2 Ubuntu.
  - From the project root (this directory), run:
    - `docker compose config` to validate the configuration.
    - `docker compose up -d gitea` to start Gitea.
  - After creating a registration token in the Gitea UI, set `GITEA_RUNNER_REGISTRATION_TOKEN` (e.g. via `.env`) and run:
    - `docker compose up -d gitea-runner` to start the Actions runner.

