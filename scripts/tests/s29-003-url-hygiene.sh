#!/usr/bin/env bash
# s29-003-url-hygiene.sh — STORY-S29-003 regression guard.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT (Issue #708) Faz 2.1 completed: `atilcan65/dev-studio-launcher`
# transferred to the `atilproject` org. Sprint 29 (cross-repo workstream pattern,
# per Issue #1020 Option A resolution 2026-07-13T09:00:16Z) requires updating
# the launcher's hardcoded `atilcan65/{repo}` references in functional code
# (new-project.sh L44/L45) + docstrings (L5/L25/L28) + README.md (6 URLs).
#
# This d-test guards against:
#   TC1: new-project.sh contains any `atilcan65` reference (regression)
#   TC2: README.md contains any `atilcan65` reference (regression)
#   TC3: new-project.sh TEMPLATE_REPO starts with `atilproject/` (negative pattern)
#   TC4: new-project.sh DEFAULT_OWNER is `atilproject` (negative pattern)
#   TC5: --help output mentions `atilproject` (negative pattern, AC2)
#   TC6: README.md ADR-0016 link uses `atilproject/...` URL (AC4)
#
# Pre-impl RED state (current main, pre-S29-003):
#   TC1: 6 occurrences of atilcan65 in new-project.sh → FAIL
#   TC2: 6 occurrences of atilcan65 in README.md → FAIL
#   TC3: TEMPLATE_REPO = atilcan65/dev-studio-template → FAIL
#   TC4: DEFAULT_OWNER = atilcan65 → FAIL
#   TC5: --help output contains atilcan65 → FAIL
#   TC6: ADR-0016 link uses atilcan65 URL → FAIL
#   → 6/6 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (after S29-003 PR squash):
#   TC1: 0 occurrences of atilcan65 in new-project.sh ✅
#   TC2: 0 occurrences of atilcan65 in README.md ✅
#   TC3: TEMPLATE_REPO starts with atilproject/ ✅
#   TC4: DEFAULT_OWNER is atilproject ✅
#   TC5: --help output contains atilproject (and no atilcan65) ✅
#   TC6: ADR-0016 link uses atilproject/... URL ✅
#   → 6/6 TCs PASS = GREEN.
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d095 (Sprint 22 PIVOT Faz 2.4, AtilCalculator's atilcan65→atilproject
#     migration guard) — direct sister (same hygiene pattern, different repo)
#   - d069 (workflow-file scope parameterization, WORKFLOW_FILES array pattern)
#   - d070 (init-prompt-ux regression guard)
#   - d070b (init-prompt-ux sister)
#   - d091 (work-stream awareness regression guard)
#   - d093 (TEMPLATE-README.md polish regression guard)
#   - d094 (self-hosted runner migration regression guard)
#   - d096 (soul files template coverage)
#   - d097 (self-hosted runner migration sister)
#   - **s29-003 (this file) — Sprint 29 S29-003 URL hygiene guard (launcher repo)**
#
# Sprint 29 cross-repo workstream refs:
#   - Issue #1015 (S29-003 tracker in AtilCalculator, agent:developer)
#   - Issue #1020 (cross-repo scope Q, RESOLVED 2026-07-13T09:00:16Z Option A)
#   - docs/sprints/sprint-29/00-plan.md §S29-003
#   - docs/sprints/sprint-28/02-template-launcher-audit-2026-07-13.md §7.2 (Q5)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern, ≥3 TCs minimum; this file: 6)
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#
# Usage:
#   bash scripts/tests/s29-003-url-hygiene.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — S29-003 migration complete)
#   1 — at least one FAIL (RED state — migration incomplete)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NEW_PROJECT_SH="${REPO_ROOT}/new-project.sh"
README_MD="${REPO_ROOT}/README.md"

# --- preflight ---
if [[ ! -f "$NEW_PROJECT_SH" ]]; then
  echo "ERROR: preflight fail — new-project.sh not found at $NEW_PROJECT_SH" >&2
  exit 2
fi
if [[ ! -f "$README_MD" ]]; then
  echo "ERROR: preflight fail — README.md not found at $README_MD" >&2
  exit 2
fi
if ! command -v grep >/dev/null 2>&1; then
  echo "ERROR: preflight fail — grep not available" >&2
  exit 2
fi

# --- TCs ---

# TC1: new-project.sh contains NO `atilcan65` reference
tc1_fail_count=$(grep -c "atilcan65" "$NEW_PROJECT_SH" || true)
if [[ "$tc1_fail_count" -eq 0 ]]; then
  echo "TC1 PASS: new-project.sh has 0 atilcan65 references"
  tc1_status="PASS"
else
  echo "TC1 FAIL: new-project.sh has $tc1_fail_count atilcan65 references (expected 0)"
  tc1_status="FAIL"
fi

# TC2: README.md contains NO `atilcan65` reference
tc2_fail_count=$(grep -c "atilcan65" "$README_MD" || true)
if [[ "$tc2_fail_count" -eq 0 ]]; then
  echo "TC2 PASS: README.md has 0 atilcan65 references"
  tc2_status="PASS"
else
  echo "TC2 FAIL: README.md has $tc2_fail_count atilcan65 references (expected 0)"
  tc2_status="FAIL"
fi

# TC3: TEMPLATE_REPO starts with `atilproject/`
if grep -qE '^TEMPLATE_REPO="atilproject/' "$NEW_PROJECT_SH"; then
  echo "TC3 PASS: TEMPLATE_REPO starts with atilproject/"
  tc3_status="PASS"
else
  tc3_actual=$(grep -E '^TEMPLATE_REPO=' "$NEW_PROJECT_SH" || echo "NOT FOUND")
  echo "TC3 FAIL: TEMPLATE_REPO does not start with atilproject/ (actual: $tc3_actual)"
  tc3_status="FAIL"
fi

# TC4: DEFAULT_OWNER is `atilproject`
if grep -qE '^DEFAULT_OWNER="atilproject"$' "$NEW_PROJECT_SH"; then
  echo "TC4 PASS: DEFAULT_OWNER is atilproject"
  tc4_status="PASS"
else
  tc4_actual=$(grep -E '^DEFAULT_OWNER=' "$NEW_PROJECT_SH" || echo "NOT FOUND")
  echo "TC4 FAIL: DEFAULT_OWNER is not atilproject (actual: $tc4_actual)"
  tc4_status="FAIL"
fi

# TC5: --help output mentions `atilproject` (AC2)
# Run the script with --help and check the output
help_output=$(bash "$NEW_PROJECT_SH" --help 2>&1 || true)
if echo "$help_output" | grep -q "atilproject"; then
  if echo "$help_output" | grep -q "atilcan65"; then
    echo "TC5 FAIL: --help output mentions atilproject BUT also still mentions atilcan65"
    tc5_status="FAIL"
  else
    echo "TC5 PASS: --help output mentions atilproject (and no atilcan65)"
    tc5_status="PASS"
  fi
else
  echo "TC5 FAIL: --help output does not mention atilproject"
  tc5_status="FAIL"
fi

# TC6: README.md ADR-0016 link uses atilproject/... URL (AC4)
if grep -qE 'ADR-0016.*atilproject/(dev-studio-template|dev-studio-launcher)' "$README_MD"; then
  echo "TC6 PASS: README.md ADR-0016 link uses atilproject/... URL"
  tc6_status="PASS"
else
  echo "TC6 FAIL: README.md ADR-0016 link does not use atilproject/... URL"
  tc6_status="FAIL"
fi

# --- summary ---
total=6
fail_count=0
for s in "$tc1_status" "$tc2_status" "$tc3_status" "$tc4_status" "$tc5_status" "$tc6_status"; do
  if [[ "$s" == "FAIL" ]]; then
    fail_count=$((fail_count + 1))
  fi
done
pass_count=$((total - fail_count))

echo "---"
echo "s29-003-url-hygiene: $pass_count/$total PASS, $fail_count/$total FAIL"

if [[ "$fail_count" -gt 0 ]]; then
  echo "RESULT: RED (at least one TC failed — migration incomplete)"
  exit 1
else
  echo "RESULT: GREEN (all TCs pass — S29-003 migration complete)"
  exit 0
fi
