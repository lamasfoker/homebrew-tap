# homebrew-tap

lamasfoker's Homebrew tap. The formulas are unofficial.

| Formula | What it installs |
| --- | --- |
| `intelephense` | [Intelephense](https://intelephense.com), the PHP language server |
| `trail-code` | [Trail-Code](https://github.com/trailhq/Trail-Code), the context layer for coding agents (the `trail` command) |
| `scrapling` | [Scrapling](https://github.com/D4Vinci/Scrapling), the web scraping framework and its `scrapling` CLI |

Each formula is installed with a **private, vendored runtime**: Node.js for `intelephense` and `trail-code`,
Python for `scrapling`. It never touches any Node.js or Python you have on `PATH` (system, nvm, volta, pyenv,
etc). `brew uninstall` removes it all cleanly, except the `scrapling` browsers (see below).

## Install

```sh
brew tap lamasfoker/tap
brew install intelephense
brew install trail-code
brew install scrapling
```

### Coming from `lamasfoker/intelephense`

This repo used to be the `lamasfoker/intelephense` tap. Remove the old tap first, then add the new one.
If you keep both, Homebrew has the same repo twice and every formula name is ambiguous.

```sh
brew untap lamasfoker/intelephense
brew tap lamasfoker/tap
```

## intelephense

`intelephense` is a language server, not an interactive CLI. Point your editor's LSP client at
it; it runs over stdio, node-ipc, a socket, or a named pipe:

```sh
intelephense --stdio
intelephense --node-ipc
intelephense --socket=<port>
intelephense --pipe=<name>
```

See [intelephense-docs](https://github.com/bmewburn/intelephense-docs) for editor-specific setup
and configuration options.

## trail-code

```sh
trail init   # in a repo, to wire trail into your agents
```

- The install compiles native tree-sitter modules, so the Xcode Command Line Tools must be installed.
- `brew install` sends no install telemetry (`DO_NOT_TRACK=1` during the install). To change
  telemetry at runtime, use `trail telemetry`.
- Upgrade with `brew upgrade trail-code`. `trail upgrade` runs `npm install -g` and would install a
  second copy.
- The `trail` command runs on the vendored Node.js. The agent hooks that `trail init` writes are
  run by the agent with the `node` on your `PATH`, so you need a Node.js >= 20 for them.

## scrapling

```sh
scrapling install   # once: downloads the browsers for the browser fetchers
scrapling extract get 'https://example.com' page.md --ai-targeted
```

- The install builds a private Python venv from a hashed lock (`Formula/scrapling-requirements.lock`).
  It never touches the Python on your `PATH`. The venv is built in `post_install`, so run
  `brew postinstall scrapling` if that step failed.
- The browsers are stored in `$(brew --prefix)/var/scrapling/browsers` (about 570 MB). `brew uninstall`
  does not remove them; delete that folder by hand.

## Updates

Three workflows check npm or PyPI, rebuild and test the formula, and open a self-merging PR when the build
passes. Each also keeps its own vendored runtime pinned (Node.js LTS, or Python 3.13 and uv for `scrapling`).

| Workflow | Formula | Schedule | Run manually |
| --- | --- | --- | --- |
| `.github/workflows/update-intelephense.yml` | `intelephense` | weekly | `gh workflow run update-intelephense.yml` |
| `.github/workflows/update-trail-code.yml` | `trail-code` | daily | `gh workflow run update-trail-code.yml` |
| `.github/workflows/update-scrapling.yml` | `scrapling` | daily | `gh workflow run update-scrapling.yml` |
