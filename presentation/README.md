# Presentation

Terminal slide deck for **DevOps-Driven API Governance** (API Days Munich 2026),
built with [presenterm](https://github.com/mfontanini/presenterm).

## Install presenterm

Pick one:

- **Release binary** — download for your platform from
  [GitHub releases](https://github.com/mfontanini/presenterm/releases)
- **Cargo** — `cargo install --locked presenterm`
- **Arch Linux** — `pacman -S presenterm`

See the [presenterm install guide](https://mfontanini.github.io/presenterm/install.html)
for other distros and package managers.

## Run

From the repo root:

```bash
presenterm --config-file presentation/config.yaml presentation/slides.md
```

- **Present mode** (no hot reload): add `-p`
- **Hot reload** (default in dev mode): edit `slides.md`, save — the terminal updates
- **Slide index**: press `Ctrl+P` while presenting

## Export (optional)

```bash
presenterm --config-file presentation/config.yaml --export pdf presentation/slides.md
```

Exported PDF/HTML files are git-ignored.

## Files

| File | Purpose |
|------|---------|
| `slides.md` | Slide content (markdown) |
| `config.yaml` | Project-local presenterm defaults |
