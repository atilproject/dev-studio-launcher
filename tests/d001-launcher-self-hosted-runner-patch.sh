#!/usr/bin/env bash
# d001-launcher-self-hosted-runner-patch.sh — RED-first d-test for S29-013
#
# Per Issue #1072 (S29-013 Launcher auto-applies self-hosted 4-tuple on bootstrap
# per owner directive #5) + Issue #414 §Dispatch Discipline + ADR-0044 RED-first
# TDD + ADR-0049 d-test framework (≥5 TCs baseline).
#
# **Acıl path context (architect verdict 2026-07-15T08:14:35Z, cycle 5934):**
#   - Q1 = launcher constant `RUNNER_4TUPLE_LABEL_PATTERN="[self-hosted, Linux, X64, atilproject]"`
#   - Q1.1 = keep S29-013 on atilcan65/dev-studio-launcher this sprint; orchestrator files
#     follow-up Issue "S29-013-FU — Port new-project.sh to atilproject/dev-studio-template
#     per S29-001 sister-pattern" (port is separate scope per RETRO-023 cross-repo codifier)
#   - Q2 = stderr call-out PRIMARY + ::warning:: conditional emit ONLY when
#     `RUNNER_OS==Linux && GITHUB_ACTIONS==true` (::warning:: is GH Actions runtime
#     contract, silent broken outside Actions context)
#
# Test cases (7 total — exceeds ADR-0049 ≥5 baseline by 2; covers architect-named
# 3 + idempotency/regex/hygiene/docs baseline):
#
#   TC1: RED — new-project.sh exports `RUNNER_4TUPLE_LABEL_PATTERN` constant
#        matching the 4-tuple `[self-hosted, Linux, X64, atilproject]` exactly
#        (architect verdict Q1; verified against .github/workflows/*.yml on
#        AtilCalculator side, 10+ matches)
#
#   TC2: RED — apply_self_hosted_runner_patch() emits WARNING to stderr (per
#        architect Q2 emit shape: `>&2 echo "WARNING [S29-013]: no self-hosted
#        runners match 4-tuple in \`<owner>/<repo>\`. Falling back to ubuntu-latest.
#        See docs/sprints/sprint-29/S29-013.md §AC3."`) when pre-flight returns
#        0 self-hosted runners. Patch does NOT modify workflow file in this case
#        (fallback to ubuntu-latest preserved).
#
#   TC3: RED — `::warning::` conditional emit ONLY when RUNNER_OS==Linux AND
#        GITHUB_ACTIONS==true. Outside Actions context (local dev / self-hosted
#        CI bootstrap), only stderr call-out fires (no `::warning::` literal —
#        would echo verbatim as noise). Pre-fix: function emits `::warning::`
#        unconditionally (or emits it never). Post-fix: env-gated.
#
#   TC4: RED (idempotency, AC2) — patch function is idempotent: re-running on
#        an already-patched workflow (one with `runs-on: [self-hosted, Linux,
#        X64, atilproject]`) is a no-op. Workflow file content unchanged after
#        second patch call.
#
#   TC5: RED (regex correctness, AC1) — patch transforms
#        `runs-on: ubuntu-latest` → `runs-on: [self-hosted, Linux, X64, atilproject]`
#        using a regex that matches ONLY the unpatched state. Pre-fix: no patch
#        function exists, or patch matches too broadly (corrupts custom self-hosted
#        configs).
#
#   TC6: RED (hygiene, ≥3 baseline) — bash -n syntactic self-check on new-project.sh.
#        Pre-fix RED: this d-test file references the impl; the d-test RED baseline
#        must verify the script doesn't break syntax (independent of impl correctness).
#
#   TC7: RED (docs, Cadence Rule 1 atomic attestation, sister-pattern d1025 TC7 +
#        d-retro-024 TC6) — `tests/INDEX.md` has a row for d001. Cadence Rule 1
#        atomic (ADR-0055 §1) requires d-test file + INDEX.md row land same commit.
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# TDD status: RED-first verified — this d-test is written BEFORE the impl lands.
# Apply fix → all 7 GREEN. d097 (AtilCalculator self-hosted-runner-migration)
# + d100 (AtilCalculator self-hosted-perf-budgets) are sister-patterns for
# verification shape (TCs reference real AtilCalculator self-hosted workflows).
#
# Run standalone: bash tests/d001-launcher-self-hosted-runner-patch.sh

set -uo pipefail

# Resolve launcher root regardless of where the d-test is invoked from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NEW_PROJECT_SH="$LAUNCHER_ROOT/new-project.sh"
INDEX_MD="$SCRIPT_DIR/INDEX.md"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

PASS=0
FAIL=0
TESTS=0

run_tc() {
  local tc_id="$1"; local desc="$2"; local body="$3"
  TESTS=$((TESTS + 1))
  local result
  if result="$(eval "$body" 2>&1)"; then
    if [ "$result" = "PASS" ]; then
      PASS=$((PASS + 1))
      printf "${GREEN}✅ %s${NC} %s\n" "$tc_id" "$desc"
    else
      FAIL=$((FAIL + 1))
      printf "${RED}❌ %s${NC} %s\n  result: %s\n" "$tc_id" "$desc" "$result"
    fi
  else
    FAIL=$((FAIL + 1))
    printf "${RED}❌ %s${NC} %s\n  error: %s\n" "$tc_id" "$desc" "$result"
  fi
}

# --- preflight: launcher script exists ---
[ -f "$NEW_PROJECT_SH" ] || { echo "ERROR: $NEW_PROJECT_SH not found" >&2; exit 2; }

# --- fixture setup: temporary fake repo with sample workflows ---
# Uses $TMPDIR/d001-fake-repo/ — cleaned up on exit
FIXTURE_ROOT="$(mktemp -d -t d001-launcher-fixture.XXXXXX)"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

mkdir -p "$FIXTURE_ROOT/.github/workflows"
cat > "$FIXTURE_ROOT/.github/workflows/ci.yml" <<'YAML'
name: ci
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
YAML

cat > "$FIXTURE_ROOT/.github/workflows/already-patched.yml" <<'YAML'
name: already-patched
on: [push]
jobs:
  test:
    runs-on: [self-hosted, Linux, X64, atilproject]
    steps:
      - uses: actions/checkout@v4
YAML

# TC1: launcher exports RUNNER_4TUPLE_LABEL_PATTERN constant matching the 4-tuple exactly.
# Source-grep verifies the constant is declared with the exact value
# `[self-hosted, Linux, X64, atilproject]`. Per architect verdict Q1.
run_tc "TC1" "new-project.sh exports RUNNER_4TUPLE_LABEL_PATTERN=\"[self-hosted, Linux, X64, atilproject]\" constant" '
  if grep -qE "^RUNNER_4TUPLE_LABEL_PATTERN=\"\\[self-hosted, Linux, X64, atilproject\\]\"" "'"$NEW_PROJECT_SH"'"; then
    echo "PASS"
  else
    echo "FAIL: constant not found or wrong value — architect verdict Q1 specifies exact pattern [self-hosted, Linux, X64, atilproject]"
  fi
'

# TC2: stderr WARNING when pre-flight returns 0 self-hosted runners. We source
# the launcher in a subshell with FIXTURE_MODE=1 + FIXTURE_RUNNER_COUNT=0 env vars
# (sourced-mode auto-detected via BASH_SOURCE check in new-project.sh lines 48-50;
# SOURCED_MODE early-return at lines 202-204 short-circuits before arg parse).
# Then we invoke warn_no_self_hosted_runners directly to verify the emit shape
# per architect verdict Q2 (stderr PRIMARY + fallback phrase).
#
# **Stream capture note**: The outer `2>&1` is REQUIRED — `bash -c "..." 2>&1`
# redirects bash's own stderr to stdout so $() captures both streams. Without
# the outer wrapper, $() captures only stdout (warn_no_self_hosted_runners'
# err() writes to stderr which would leak).
run_tc "TC2" "stderr emits WARNING [S29-013] when 0 self-hosted runners match (architect Q2 emit shape)" '
  STDOUT_ERR=$(env FIXTURE_MODE=1 FIXTURE_RUNNER_COUNT=0 bash -c "
    source '"$NEW_PROJECT_SH"' 2>&1 || true
    warn_no_self_hosted_runners foo bar
  " 2>&1)
  if echo "$STDOUT_ERR" | grep -qF "WARNING [S29-013]: no self-hosted runners match 4-tuple in"; then
    if echo "$STDOUT_ERR" | grep -qF "Falling back to ubuntu-latest"; then
      echo "PASS"
    else
      echo "FAIL: WARNING emitted but fallback phrase missing"
    fi
  else
    echo "FAIL: WARNING [S29-013] line not found in stderr — architect Q2 stderr primary emit shape violated"
  fi
'

# TC3: ::warning:: conditional emit ONLY when RUNNER_OS==Linux AND GITHUB_ACTIONS==true.
# Test in two contexts: (a) unset both → no ::warning::, (b) set both → ::warning:: present.
# Env-var sourcing per architect verdict Q2 — sourced-mode auto-detected via BASH_SOURCE check.
run_tc "TC3" "::warning:: emit gated by RUNNER_OS==Linux && GITHUB_ACTIONS==true (architect Q2 env-gate)" '
  # Case A: env unset — ::warning:: must NOT appear (would echo verbatim outside Actions context)
  OUT_A=$(env -u RUNNER_OS -u GITHUB_ACTIONS FIXTURE_MODE=1 FIXTURE_RUNNER_COUNT=0 bash -c "
    source '"$NEW_PROJECT_SH"' 2>&1 || true
    warn_no_self_hosted_runners foo bar
  " 2>&1)
  HAS_WARNING_A="no"
  if echo "$OUT_A" | grep -qF "::warning"; then HAS_WARNING_A="yes"; fi

  # Case B: env set — ::warning:: MUST appear
  OUT_B=$(env RUNNER_OS=Linux GITHUB_ACTIONS=true FIXTURE_MODE=1 FIXTURE_RUNNER_COUNT=0 bash -c "
    source '"$NEW_PROJECT_SH"' 2>&1 || true
    warn_no_self_hosted_runners foo bar
  " 2>&1)
  HAS_WARNING_B="no"
  if echo "$OUT_B" | grep -qF "::warning"; then HAS_WARNING_B="yes"; fi

  if [ "$HAS_WARNING_A" = "no" ] && [ "$HAS_WARNING_B" = "yes" ]; then
    echo "PASS"
  elif [ "$HAS_WARNING_A" = "yes" ]; then
    echo "FAIL: ::warning:: emitted WITHOUT env-gate (would echo verbatim outside Actions context per RETRO-005 #26)"
  elif [ "$HAS_WARNING_B" = "no" ]; then
    echo "FAIL: ::warning:: NOT emitted even with RUNNER_OS=Linux + GITHUB_ACTIONS=true"
  else
    echo "FAIL: indeterminate state A=$HAS_WARNING_A B=$HAS_WARNING_B"
  fi
'

# TC4: idempotency — patch function is no-op on already-patched workflows.
# Source the launcher with FIXTURE_REPO_ROOT env var (sourced-mode auto-detected),
# run patch twice on already-patched.yml, verify file content unchanged after
# second call. Per AC2.
run_tc "TC4" "patch function idempotent on already-patched workflow (AC2)" '
  BEFORE_HASH=$(sha256sum "'$FIXTURE_ROOT'/.github/workflows/already-patched.yml" | awk "{print \$1}")
  env FIXTURE_MODE=1 FIXTURE_RUNNER_COUNT=3 FIXTURE_REPO_ROOT='"$FIXTURE_ROOT"' bash -c "
    source '"$NEW_PROJECT_SH"' 2>&1 || true
    apply_self_hosted_runner_patch
    apply_self_hosted_runner_patch
  " >/dev/null 2>&1
  AFTER_HASH=$(sha256sum "'$FIXTURE_ROOT'/.github/workflows/already-patched.yml" | awk "{print \$1}")
  if [ "$BEFORE_HASH" = "$AFTER_HASH" ]; then
    echo "PASS"
  else
    echo "FAIL: patch double-applied on already-patched workflow — before=$BEFORE_HASH after=$AFTER_HASH"
  fi
'

# TC5: regex correctness — patch transforms `runs-on: ubuntu-latest` → `runs-on: [self-hosted, Linux, X64, atilproject]`.
# Verify on ci.yml (unpatched state) via env-var sourcing. Per AC1.
run_tc "TC5" "patch transforms runs-on: ubuntu-latest → runs-on: [self-hosted, Linux, X64, atilproject] (AC1 regex correctness)" '
  env FIXTURE_MODE=1 FIXTURE_RUNNER_COUNT=3 FIXTURE_REPO_ROOT='"$FIXTURE_ROOT"' bash -c "
    source '"$NEW_PROJECT_SH"' 2>&1 || true
    apply_self_hosted_runner_patch
  " >/dev/null 2>&1
  PATCHED_LINE=$(grep -E "^\\s+runs-on:" "'$FIXTURE_ROOT'/.github/workflows/ci.yml" || true)
  EXPECTED="    runs-on: [self-hosted, Linux, X64, atilproject]"
  if [ "$PATCHED_LINE" = "$EXPECTED" ]; then
    echo "PASS"
  else
    echo "FAIL: patched line is not exact match — got \"$PATCHED_LINE\" expected \"$EXPECTED\""
  fi
'

# TC6: hygiene baseline — bash -n syntactic self-check on new-project.sh.
# ≥3 TCs hygiene/docs baseline per `docs/sprints/current/plan.md` — d001 covers TC6
# (syntax hygiene) + TC7 (Cadence Rule 1 atomic INDEX.md attestation).
run_tc "TC6" "bash -n syntactic check on new-project.sh (hygiene baseline)" '
  if bash -n "'"$NEW_PROJECT_SH"'" 2>&1; then
    echo "PASS"
  else
    echo "FAIL: new-project.sh has syntax errors — bash -n failed"
  fi
'

# TC7: Cadence Rule 1 atomic attestation — tests/INDEX.md has d001 row. Sister-pattern
# d1025 TC7 + d-retro-024 TC6.
run_tc "TC7" "tests/INDEX.md has d001 row (Cadence Rule 1 atomic attestation)" '
  if [ -f "'"$INDEX_MD"'" ] && grep -qE "d001|launcher-self-hosted-runner-patch" "'"$INDEX_MD"'"; then
    echo "PASS"
  else
    echo "FAIL: tests/INDEX.md missing or no d001 row — Cadence Rule 1 atomic per ADR-0055 §1 violated"
  fi
'

echo
echo "================================================="
if [ "$FAIL" -eq 0 ]; then
  printf "${GREEN}d001-launcher-self-hosted-runner-patch: %d/%d PASS${NC}\n" "$PASS" "$TESTS"
  exit 0
else
  printf "${RED}d001-launcher-self-hosted-runner-patch: %d/%d PASS (%d FAIL)${NC}\n" "$PASS" "$TESTS" "$FAIL"
  exit 1
fi