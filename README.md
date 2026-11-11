# homebrew-tap

lamasfoker's Homebrew tap. The formulas are unofficial.

| Formula | What it installs |
| --- | --- |
| `intelephense` | [Intelephense](https://intelephense.com), the PHP language server |
| `trail-code` | [Trail-Code](https://github.com/trailhq/Trail-Code), the context layer for coding agents (the `trail` command) |
| `lighthouse` | [Lighthouse](https://github.com/GoogleChrome/lighthouse), the Google web page auditor |

Each formula is installed with a **private, vendored Node.js runtime**. It never touches any Node.js you
have on `PATH` (system, nvm, volta, etc). `brew uninstall` removes it all cleanly.

## Install

```sh
brew tap lamasfoker/tap
brew install intelephense
brew install trail-code
brew install lamasfoker/tap/lighthouse
```

`lighthouse` needs the full name. homebrew-core has another formula called `lighthouse` (the Ethereum
client), so `brew install lighthouse` installs that one.

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

## lighthouse

```sh
lighthouse https://example.com --view
```

- Lighthouse needs Google Chrome (or Chromium) installed. The formula does not install it.
- Only the `lighthouse` command is installed. The `smokehouse` and `chrome-debug` dev tools are not.

## Updates

Three workflows check npm, rebuild and test the formula, and open a self-merging PR when the build
passes. Each also keeps its own vendored Node.js runtime pinned to the current LTS release.

| Workflow | Formula | Schedule | Run manually |
| --- | --- | --- | --- |
| `.github/workflows/update-intelephense.yml` | `intelephense` | weekly | `gh workflow run update-intelephense.yml` |
| `.github/workflows/update-trail-code.yml` | `trail-code` | daily | `gh workflow run update-trail-code.yml` |
| `.github/workflows/update-lighthouse.yml` | `lighthouse` | weekly | `gh workflow run update-lighthouse.yml` |
