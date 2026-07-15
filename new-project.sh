#!/usr/bin/env bash
# new-project.sh — Bootstrap a new project from dev-studio-template.
#
# Scope:
#   1. Create a new repo from atilcan65/dev-studio-template (PUBLIC by
#      default, ADR-0016; --private opt-in)
#   2. Clone it locally
#   3. Run scripts/dev-studio-init.sh (placeholder render + PROJECT_TOKEN
#      secret + canary; the canary uses GitHub Actions which is paid on
#      private repos — see ADR-0014 §3.5 + ADR-0016)
#   4. Run scripts/bootstrap-labels.sh (seed 34 labels)
#
# Does NOT:
#   - Run e2e smoke test (caller can run manually after)
#   - Start tmux session (caller runs dev-studio-start.sh when ready)
#   - Open Vision Intake issue (intentionally — human writes vision body)
#
# Usage:
#   ./new-project.sh <project-name> [--owner <owner>] [--dir <parent>] [--public|--private]
#
# Examples:
#   ./new-project.sh AtilCalculator                  # public (default, ADR-0016)
#   ./new-project.sh secret-thing --private          # opt-in private (Actions billing!)
#   ./new-project.sh book-tracker --dir ~/projects
#   ./new-project.sh stock-watcher --owner atilcan65 --dir /tmp
#
# Defaults:
#   --owner       atilcan65
#   --dir         $DEV_STUDIO_HOME or $HOME/projects
#   visibility    public (ADR-0016)
#
# Exit codes:
#   0  success
#   1  bad usage
#   2  preflight failed (gh/git/jq missing or unauthenticated)
#   3  repo already exists
#   4  gh repo create failed
#   5  init script failed
#   6  bootstrap-labels failed

set -euo pipefail

# Sourced-mode guard: when this script is sourced (not executed), define
# constants + functions but skip the main bootstrap flow. Enables d-test
# sourceability per ADR-0044 RED-first TDD (d001 TC2-TC5 source the script
# + call apply_self_hosted_runner_patch directly with FIXTURE_* env vars).
# Sister-pattern: bash idiom from dev-studio-template/scripts/dev-studio-init.sh.
if [[ "${BASH_SOURCE[0]:-}" != "${0}" ]]; then
  SOURCED_MODE=1
fi

# ---------- defaults ----------
TEMPLATE_REPO="atilcan65/dev-studio-template"
DEFAULT_OWNER="atilcan65"

# ---------- Self-hosted runner 4-tuple (S29-013, Issue #1072) ----------
# Generator-side constant for the 4-tuple that .github/workflows/*.yml must use.
# Sister-pattern to S29-001 (template-side 4-tuple in dev-studio-template/.github/workflows/*.yml.tmpl).
# Per architect verdict Q1 (cycle 5934, 2026-07-15T08:14:35Z): launcher constant =
# SSOT for generator. CLAUDE.md.tmpl is agent lore (lane discipline), NOT infra
# config — parsing markdown for 4-tuple is indirect (silent drift surface);
# reading a bash constant is direct. RETRO-005 #26 structural correctness.
RUNNER_4TUPLE_LABEL_PATTERN="[self-hosted, Linux, X64, atilproject]"

# ---------- colors ----------
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'
  C_RED=$'\e[31m'
  C_GREEN=$'\e[32m'
  C_YELLOW=$'\e[33m'
  C_BLUE=$'\e[34m'
  C_BOLD=$'\e[1m'
else
  C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""
fi

step()  { echo -e "${C_BLUE}${C_BOLD}[step]${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}[ ok ]${C_RESET} $*"; }
info()  { echo -e "${C_BLUE}[info]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[warn]${C_RESET} $*"; }
err()   { echo -e "${C_RED}${C_BOLD}[fail]${C_RESET} $*" >&2; }

# ---------- Self-hosted runner patch (S29-013, Issue #1072) ----------
# Per architect verdict Q2 (cycle 5934, 2026-07-15T08:14:35Z):
# - stderr call-out PRIMARY (always emitted when pre-flight returns 0 self-hosted)
# - ::warning:: emit CONDITIONAL only when RUNNER_OS==Linux && GITHUB_ACTIONS==true
#   (::warning:: is GH Actions runtime contract; outside Actions context, echoes
#    verbatim as noise — RETRO-005 #26 structural correctness, context-portable)
#
# Fixture hooks (d001 d-test path):
#   FIXTURE_MODE=1 + FIXTURE_RUNNER_COUNT=N: skip gh api call, return N
#   FIXTURE_REPO_ROOT=/path: use this dir as repo root instead of $CLONE_PATH

# count_self_hosted_runners <owner> <project>
# Echoes the count of self-hosted runners registered for the repo.
# Uses gh api repos/<owner>/<project>/actions/runners. In fixture mode, returns
# FIXTURE_RUNNER_COUNT directly (d001 d-test isolation).
count_self_hosted_runners() {
  local owner="$1" project="$2"
  if [[ "${FIXTURE_MODE:-0}" == "1" ]]; then
    echo "${FIXTURE_RUNNER_COUNT:-3}"
    return 0
  fi
  if [[ "${owner:-}" == "" || "${project:-}" == "" ]]; then
    echo "0"
    return 0
  fi
  # gh api returns JSON with .total_count field. Suppress errors (count=0 on failure).
  local count
  count="$(gh api "repos/${owner}/${project}/actions/runners" --jq '.total_count' 2>/dev/null || echo "0")"
  echo "${count:-0}"
}

# apply_self_hosted_runner_patch
# Transforms `runs-on: ubuntu-latest` → `runs-on: [self-hosted, Linux, X64, atilproject]`
# in .github/workflows/*.yml of $CLONE_PATH (or FIXTURE_REPO_ROOT for d-test).
# Idempotent: only matches the unpatched pattern, never modifies already-patched
# workflows (per AC2). Per AC1 regex correctness.
apply_self_hosted_runner_patch() {
  local repo_root="${FIXTURE_REPO_ROOT:-${CLONE_PATH:-}}"
  if [[ -z "${repo_root}" || ! -d "${repo_root}/.github/workflows" ]]; then
    warn "no .github/workflows directory in '${repo_root:-<unset>}' — skipping self-hosted patch"
    return 0
  fi
  local workflows_dir="${repo_root}/.github/workflows"
  local patched=0
  local wf
  for wf in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
    [[ -f "$wf" ]] || continue
    # Idempotent: only patch lines matching the EXACT unpatched pattern.
    # `    runs-on: ubuntu-latest` (4-space indent, end-of-line) → 4-tuple line.
    if grep -qE "^    runs-on: ubuntu-latest$" "$wf"; then
      sed -i.bak -E "s|^    runs-on: ubuntu-latest\$|    runs-on: ${RUNNER_4TUPLE_LABEL_PATTERN}|" "$wf"
      rm -f "$wf.bak"
      patched=$((patched + 1))
    fi
  done
  if [[ "$patched" -gt 0 ]]; then
    ok "patched ${patched} workflow(s) to self-hosted 4-tuple [${RUNNER_4TUPLE_LABEL_PATTERN}]"
  else
    info "no ubuntu-latest workflows to patch (already self-hosted or empty)"
  fi
  return 0
}

# warn_no_self_hosted_runners <owner> <project>
# Stderr call-out PRIMARY (always when called) + ::warning:: CONDITIONAL on Actions
# context per architect verdict Q2. Emitted when count_self_hosted_runners returns 0.
warn_no_self_hosted_runners() {
  local owner="$1" project="$2"
  err "WARNING [S29-013]: no self-hosted runners match 4-tuple in \`${owner}/${project}\`. Falling back to ubuntu-latest. See docs/sprints/sprint-29/S29-013.md §AC3."
  if [[ "${RUNNER_OS:-}" == "Linux" && "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::warning file=new-project.sh::no self-hosted runners match 4-tuple in \`${owner}/${project}\`"
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <project-name> [--owner <owner>] [--dir <parent-dir>] [--public|--private]

Creates a new GitHub repo from the dev-studio-template, clones it,
runs the init script, and seeds labels.

Arguments:
  <project-name>     Repository name (kebab-case or PascalCase). Required.

Options:
  --owner <owner>    GitHub owner/org. Default: ${DEFAULT_OWNER}
  --dir <parent>     Parent directory for the clone.
                     Default (in priority order):
                       1. \$DEV_STUDIO_HOME (if set)
                       2. \$HOME/projects (auto-created if missing)
                     Override with --dir to use any other location.
  --public           Create repo as public (DEFAULT, ADR-0016).
  --private          Create repo as private. Note: PROJECT_TOKEN canary
                     runs on GitHub Actions, which is paid on private
                     repos. Ensure your spending limit is configured
                     before using --private, or the init will fail with
                     'job not started'. See ADR-0014 §3.5 + ADR-0016.
  -h, --help         Show this help.

Environment:
  DEV_STUDIO_HOME    Override the default parent directory for all
                     projects created by this launcher. Useful for keeping
                     dev-studio projects under a custom namespace, e.g.
                     export DEV_STUDIO_HOME="\$HOME/work/studio".

Examples:
  $(basename "$0") AtilCalculator                  # public (default, ADR-0016)
  $(basename "$0") secret-thing --private          # opt-in private (Actions billing!)
  $(basename "$0") book-tracker --dir .            # → \$PWD/book-tracker (legacy v0.1)
  DEV_STUDIO_HOME=~/work $(basename "$0") foo      # → ~/work/foo
EOF
}

# Sourced-mode early-return: when sourced (d001 d-test path), define all
# constants + helpers + colors + usage but skip arg parse + validation +
# preflight + bootstrap. Caller invokes apply_self_hosted_runner_patch
# directly with FIXTURE_* env vars set. Per ADR-0044 RED-first TDD —
# d-test sources the script + calls functions in isolation.
# `return` is used for sourced context; `exit` covers direct exec.
if [[ "${SOURCED_MODE:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

# ---------- arg parse ----------
PROJECT_NAME=""
OWNER="$DEFAULT_OWNER"
# Default parent directory: $DEV_STUDIO_HOME (if set), else ~/projects.
# Override per-call with --dir.
PARENT_DIR="${DEV_STUDIO_HOME:-$HOME/projects}"
PARENT_DIR_EXPLICIT=0
# Default visibility: public (ADR-0016). Override with --private.
VISIBILITY_FLAG="--public"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --owner) OWNER="${2:-}"; shift 2 ;;
    --dir)   PARENT_DIR="${2:-}"; PARENT_DIR_EXPLICIT=1; shift 2 ;;
    --public)  VISIBILITY_FLAG="--public";  shift ;;
    --private) VISIBILITY_FLAG="--private"; shift ;;
    --source-mode)        SOURCED_MODE=1; shift ;;
    --fixture-runner-count) FIXTURE_MODE=1; FIXTURE_RUNNER_COUNT="${2:-}"; shift 2 ;;
    --fixture-repo-root)  FIXTURE_REPO_ROOT="${2:-}"; shift 2 ;;
    --*) err "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME="$1"; shift
      else
        err "Unexpected argument: $1"; usage; exit 1
      fi
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  err "project-name is required"
  usage
  exit 1
fi

# Validate name: alphanumeric + hyphen + underscore, 1-64 chars
if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
  err "Invalid project name: '$PROJECT_NAME'"
  err "Must start with alphanumeric; only letters, digits, '.', '-', '_' allowed; max 64 chars."
  exit 1
fi

# Validate owner
if [[ ! "$OWNER" =~ ^[A-Za-z0-9-]{1,39}$ ]]; then
  err "Invalid owner: '$OWNER'"
  exit 1
fi

# Resolve parent dir.
# - If --dir was explicit and missing: hard error (user intent was specific).
# - If default path is missing: auto-create it (one-time bootstrap of ~/projects).
if [[ ! -d "$PARENT_DIR" ]]; then
  if [[ "$PARENT_DIR_EXPLICIT" -eq 1 ]]; then
    err "Parent directory does not exist: $PARENT_DIR"
    err "Create it first or omit --dir to use the default location."
    exit 1
  fi
  info "Creating default parent directory: $PARENT_DIR"
  mkdir -p "$PARENT_DIR" || { err "Failed to create: $PARENT_DIR"; exit 1; }
fi
PARENT_DIR="$(cd "$PARENT_DIR" && pwd)"
CLONE_PATH="$PARENT_DIR/$PROJECT_NAME"

# ---------- preflight ----------
step "preflight checks"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not found: $1"
    exit 2
  fi
}
need_cmd gh
need_cmd git
need_cmd jq

if ! gh auth status >/dev/null 2>&1; then
  err "gh is not authenticated. Run: gh auth login"
  exit 2
fi

GIT_USER_NAME="$(git config --global user.name 2>/dev/null || true)"
GIT_USER_EMAIL="$(git config --global user.email 2>/dev/null || true)"
if [[ -z "$GIT_USER_NAME" || -z "$GIT_USER_EMAIL" ]]; then
  err "git global user.name and user.email must be set."
  err "Run:"
  err "  git config --global user.name '<your name>'"
  err "  git config --global user.email '<your@email>'"
  exit 2
fi

# Repo already exists?
if gh repo view "$OWNER/$PROJECT_NAME" >/dev/null 2>&1; then
  err "Repo already exists on GitHub: $OWNER/$PROJECT_NAME"
  err "Either pick another name, or delete it first:"
  err "  gh repo delete $OWNER/$PROJECT_NAME --yes"
  exit 3
fi

# Local clone path already exists?
if [[ -e "$CLONE_PATH" ]]; then
  err "Local path already exists: $CLONE_PATH"
  err "Remove or rename it, then re-run."
  exit 3
fi

# Template exists + accessible?
if ! gh repo view "$TEMPLATE_REPO" >/dev/null 2>&1; then
  err "Template repo not accessible: $TEMPLATE_REPO"
  err "Check your gh auth + access to that repo."
  exit 2
fi

ok "preflight passed"
echo "  owner:     $OWNER"
echo "  project:   $PROJECT_NAME"
echo "  template:  $TEMPLATE_REPO"
echo "  clone to:  $CLONE_PATH"
echo ""

# ---------- 1) Create + clone ----------
step "creating repo from template"
cd "$PARENT_DIR"

if ! gh repo create "$OWNER/$PROJECT_NAME" \
      --template "$TEMPLATE_REPO" \
      "$VISIBILITY_FLAG" \
      --clone; then
  err "gh repo create failed (visibility=$VISIBILITY_FLAG)"
  exit 4
fi
ok "repo created and cloned (visibility=$VISIBILITY_FLAG, ADR-0016)"
if [[ "$VISIBILITY_FLAG" == "--private" ]]; then
  warn "Created PRIVATE. PROJECT_TOKEN canary uses GitHub Actions,"
  warn "which is paid on private repos. If init fails with 'job not"
  warn "started', configure your spending limit or rerun with --public."
  warn "See ADR-0014 §3.5 + ADR-0016."
fi

cd "$CLONE_PATH"

# ---------- 2) Init (placeholder render) ----------
step "running dev-studio-init.sh"
if [[ ! -x "scripts/dev-studio-init.sh" ]]; then
  err "scripts/dev-studio-init.sh missing or not executable"
  err "Template may be broken or this repo wasn't created from the right template."
  exit 5
fi

if ! ./scripts/dev-studio-init.sh; then
  err "dev-studio-init.sh failed"
  err "Inspect output above. Repo is at: $CLONE_PATH"
  exit 5
fi
ok "init complete"

# ---------- 3) Bootstrap labels ----------
step "running bootstrap-labels.sh"
if [[ ! -x "scripts/bootstrap-labels.sh" ]]; then
  err "scripts/bootstrap-labels.sh missing or not executable"
  exit 6
fi

if ! ./scripts/bootstrap-labels.sh; then
  err "bootstrap-labels.sh failed"
  err "Re-run manually: ./scripts/bootstrap-labels.sh"
  exit 6
fi
ok "labels seeded"

# ---------- 3.5) Self-hosted runner 4-tuple patch (S29-013, Issue #1072) ----------
# Per AC1+AC2+AC3: pre-flight count self-hosted runners; patch ubuntu-latest →
# [self-hosted, Linux, X64, atilproject]; emit stderr WARNING primary +
# ::warning:: conditional on Actions context when 0 runners match.
step "applying self-hosted runner 4-tuple patch (S29-013)"
RUNNER_COUNT="$(count_self_hosted_runners "$OWNER" "$PROJECT_NAME")"
if [[ "${RUNNER_COUNT}" == "0" ]]; then
  warn_no_self_hosted_runners "$OWNER" "$PROJECT_NAME"
fi
apply_self_hosted_runner_patch
ok "self-hosted runner patch complete (runners=$RUNNER_COUNT)"

# ---------- 4) Commit rendered templates ----------
step "checking for rendered template changes to commit"
cd "$CLONE_PATH"
if ! git diff --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  git add -A
  git commit -m "chore: render templates and bootstrap project

Run by new-project.sh launcher:
  - dev-studio-init.sh resolved placeholders (12 templates)
  - bootstrap-labels.sh seeded labels on remote

Project: $OWNER/$PROJECT_NAME"
  if git push origin HEAD; then
    ok "rendered changes pushed to main"
  else
    warn "git push failed — commit is local. Push manually:"
    warn "  cd $CLONE_PATH && git push origin HEAD"
  fi
else
  ok "no rendered changes to commit (already clean)"
fi

# ---------- Summary ----------
echo ""
echo "${C_GREEN}${C_BOLD}========================================${C_RESET}"
echo "${C_GREEN}${C_BOLD}  ✓ Project ready: $OWNER/$PROJECT_NAME${C_RESET}"
echo "${C_GREEN}${C_BOLD}========================================${C_RESET}"
echo ""
echo "Repo:    https://github.com/$OWNER/$PROJECT_NAME"
echo "Local:   $CLONE_PATH"
echo ""
echo "${C_BOLD}Next steps:${C_RESET}"
echo "  cd $CLONE_PATH"
echo ""
echo "  # (recommended) Validate the install:"
echo "  ./scripts/tests/e2e-pilot.sh         # expect 29/29 PASS"
echo ""
echo "  # When ready to start agents:"
echo "  ./scripts/dev-studio-start.sh        # opens tmux session"
echo ""
echo "  # Open the Vision Intake issue:"
echo "  gh issue create --template vision-intake.yml"
echo ""
