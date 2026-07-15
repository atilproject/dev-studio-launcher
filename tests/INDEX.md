# dev-studio-launcher — d-test framework INDEX

Per **ADR-0044 RED-first TDD** + **ADR-0049 d-test framework** (≥5 TCs baseline) + **ADR-0055 §1 Cadence Rule 1 atomic** (d-test file + INDEX.md row + impl land in same commit).

The dev-studio-launcher is a thin bootstrap launcher (`new-project.sh`); d-tests verify the launcher-side self-hosted 4-tuple patch (S29-013, Issue #1072) and any future automation contracts.

Sister-pattern: atilproject/AtilCalculator `scripts/tests/INDEX.md` (calculator-side d-test framework, mirrors the same ≥5 TCs + Cadence Rule 1 atomic doctrine).

## d-tests

| ID | File | AC coverage | Sister-pattern | Commit / PR |
|---|---|---|---|---|
| d001 | `d001-launcher-self-hosted-runner-patch.sh` | AC1 regex correctness + AC2 idempotency + AC3 warning emit (stderr + ::warning:: env-gate) + AC4 ≥5 TCs + AC5 INDEX.md attestation | AtilCalculator `d097-self-hosted-runner-migration.sh` + `d100-self-hosted-perf-budgets.sh` (mirror SSOT 4-tuple) | Issue #1072 (S29-013) impl PR |

## Framework contract (per ADR-0049)

Every d-test:

1. Lives under `tests/dNNN-<slug>.sh`, executable, RED-first verified (written before the impl lands).
2. Has ≥5 TCs (we exceed on `d001` with 7 TCs — covers architect Q1+Q2 + idempotency + regex + hygiene + Cadence Rule 1 attestation).
3. Sources the impl in a subshell with `FIXTURE_*` env vars (sourced-mode auto-detected via BASH_SOURCE check in `new-project.sh` lines 48-50 + early-return at lines 202-204). Direct function calls (no main-flow re-execution).
4. Exits 0 if all pass, 1 if any fail.

## Cadence Rule 1 atomic (ADR-0055 §1)

Each d-test ships with its INDEX.md row in the SAME commit. Adding a d-test file without the INDEX.md row violates Cadence Rule 1 atomic (per RETRO-005 #26). The d-test framework's TC7 (or equivalent) enforces this at test time.

Sister-pattern: AtilCalculator `scripts/tests/INDEX.md` ships the same doctrine.