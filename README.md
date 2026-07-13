# dev-studio-launcher

> Bootstrap new projects from [`atilproject/dev-studio-template`](https://github.com/atilproject/dev-studio-template) with one command.

## What

A tiny shell script (`new-project.sh`) that automates the first 3 steps of starting a new multi-agent dev studio project:

1. Create a new public GitHub repo from `dev-studio-template` (default; use `--private` to opt-in to private — see [ADR-0016](https://github.com/atilproject/dev-studio-template/blob/main/docs/decisions/ADR-0016-public-by-default.md))
2. Clone it locally
3. Run `dev-studio-init.sh` (render templates) + `bootstrap-labels.sh` (seed labels)
4. Commit + push the rendered template changes

What it intentionally **does not** do (kept manual by design):

- Run the e2e smoke test (run it yourself when you want to validate)
- Start the tmux session / Claude Code agents (start when you're ready)
- Open the Vision Intake issue (write your vision thoughtfully, not in haste)

This is the **A1 + B1 + C2** decision: minimal automation, positional arg, separate launcher repo.

## Why a separate repo?

Putting the launcher inside `dev-studio-template` creates a chicken-and-egg problem: you need to clone something to launch a new project from the template. Keeping the launcher in its own repo means:

- One-time setup: clone this repo to a stable path (e.g. `~/dev-studio-launcher`)
- Symlink the script into `~/bin/` for global access
- Versioned independently; template fixes don't force launcher updates

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| `gh` CLI | Authenticated GitHub operations | `sudo apt install gh` + `gh auth login` |
| `git` | Clone + commit + push | `sudo apt install git` |
| `jq` | Used by template scripts | `sudo apt install jq` |
| `tmux` | For `dev-studio-start.sh` later | `sudo apt install tmux` |

And `git config --global user.name` + `user.email` must be set.

## Setup (one-time)

```bash
# Clone this repo somewhere stable
git clone https://github.com/atilproject/dev-studio-launcher.git ~/dev-studio-launcher

# Symlink for global access
mkdir -p ~/bin
ln -sf ~/dev-studio-launcher/new-project.sh ~/bin/new-project.sh
# Ensure ~/bin is on $PATH (most distros already do this)
```

## Usage

```bash
new-project.sh <project-name> [--owner <owner>] [--dir <parent-dir>] [--public|--private]
```

### Default visibility

As of v0.3.0, repos are created **public** by default. Rationale: the
template's `dev-studio-init.sh` runs an end-to-end PROJECT_TOKEN canary on
GitHub Actions ([ADR-0014 §3.5](https://github.com/atilproject/dev-studio-template/blob/main/docs/decisions/ADR-0014-project-token-secret.md));
private repos pay for Actions minutes and may fail the canary with `"job
not started"` if a spending limit isn't configured. Public repos are free
on Actions and never hit this wall.

Use `--private` only if you've configured your GitHub spending limit
and intentionally want a private project. See [ADR-0016](https://github.com/atilproject/dev-studio-template/blob/main/docs/decisions/ADR-0016-public-by-default.md)
for the full reasoning + alternatives considered.

### Default location

As of v0.2.0, projects are created under **`~/projects/<name>`** by default. The directory is auto-created on first use.

Override priority (highest first):

1. `--dir <path>` CLI option
2. `$DEV_STUDIO_HOME` environment variable
3. Built-in default: `$HOME/projects`

### Examples

```bash
# Default location: ~/projects/AtilCalculator (auto-created)
new-project.sh AtilCalculator

# Override the parent dir for one project
new-project.sh book-tracker --dir /tmp

# Use a different owner
new-project.sh stock-watcher --owner my-org

# Keep all dev-studio projects under a custom namespace (set once)
export DEV_STUDIO_HOME="$HOME/work/studio"
new-project.sh foo            # → ~/work/studio/foo
new-project.sh bar            # → ~/work/studio/bar

# Legacy v0.1 behaviour (create in current dir):
new-project.sh baz --dir .
```

### What happens

```
[step] preflight checks
[ ok ] preflight passed
[step] creating repo from template
[ ok ] repo created and cloned
[step] running dev-studio-init.sh
[ ok ] init complete
[step] running bootstrap-labels.sh
[ ok ] labels seeded
[step] checking for rendered template changes to commit
[ ok ] rendered changes pushed to main

========================================
  ✓ Project ready: atilproject/AtilCalculator
========================================
```

Takes about 30-60 seconds depending on network.

## What's next (after the launcher finishes)

```bash
cd <project-name>

# Validate (recommended, ~2 min):
./scripts/tests/e2e-pilot.sh    # expect 29/29 PASS

# When ready to work:
./scripts/dev-studio-start.sh   # opens tmux session
gh issue create --template vision-intake.yml   # kick off the agents
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Bad usage / invalid args |
| 2 | Preflight failed (missing tool, unauthenticated, etc.) |
| 3 | Repo or local path already exists |
| 4 | `gh repo create` failed |
| 5 | `dev-studio-init.sh` failed |
| 6 | `bootstrap-labels.sh` failed |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Required command not found: gh` | `sudo apt install gh` |
| `gh is not authenticated` | `gh auth login` |
| `Repo already exists on GitHub` | Delete first: `gh repo delete <owner>/<name> --yes` |
| `Local path already exists` | Remove or rename the local dir, re-run |
| Init fails mid-way | Inspect `dev-studio-init.sh` output; the partial clone is at the dir |
| Labels skipped | Re-run manually: `cd <project> && ./scripts/bootstrap-labels.sh` |

## Versioning

Stays in sync with `dev-studio-template`. When the template adds breaking changes to its init script API, this launcher gets a matching version bump.

| Launcher version | Template commit | Notes |
|---|---|---|
| 0.1.0 | `00a7101` (P3 + P7b) | Initial launcher; A1 scope |
| 0.2.0 | `32ea9e5` (PM Bash fix) | Default parent dir = `~/projects` (auto-created); `$DEV_STUDIO_HOME` override |
| 0.3.0 | ADR-0016                 | Default repo visibility flipped to **public** (`--public`); `--private` is opt-in (Actions billing implication). See ADR-0016. |

## License

MIT.
