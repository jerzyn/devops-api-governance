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

## Install d2 (for diagrams)

Diagrams are **pre-rendered to PNG** for sharp display in the terminal (live
`+render` tends to look soft when presenterm scales the bitmap).

Install the [d2 CLI](https://d2lang.com/tour/install/) — it must be on your `PATH`:

**Option A — Go** (if Go is installed):

```bash
go install oss.terrastruct.com/d2@v0.7.1
export PATH="$HOME/go/bin:$PATH"
```

**Option B — release tarball** (from this repo):

```bash
./presentation/install-d2.sh
export PATH="$HOME/.local/bin:$PATH"
```

**Option C — upstream installer:**

```bash
curl -fsSL https://d2lang.com/install.sh | sh -s --
```

After editing `diagrams/*.d2`, re-render (default scale 4; override with `D2_SCALE`):

```bash
./presentation/render-diagrams.sh
```

Verify d2 is available:

```bash
d2 --version
```

If that fails, add the install directory to your shell profile (`~/.bashrc`):

```bash
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
```

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
| `diagrams/` | D2 sources (`.d2`), rendered PNGs, and slide includes |
| `render-diagrams.sh` | Bake `.d2` → `.png` at high scale for sharp slides |
