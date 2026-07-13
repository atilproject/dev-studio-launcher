# scripts/tests/ — d-test INDEX (dev-studio-launcher)

> Sister-pattern: `atilproject/AtilCalculator/scripts/tests/INDEX.md` (master d-test registry, ADR-0049 framework + ADR-0055 §1 Cadence Rule 1 atomic).
> Sister-pattern: `atilproject/dev-studio-template/scripts/tests/INDEX.md` (forthcoming, depends on template d-test scaffold landing).

## Purpose

`new-project.sh` is a small launcher script — no unit tests, no e2e suite. But it
ships with strong **hygiene invariants** (URLs, default-owner policy, ADR-0016
visibility) that, if drifted, would break the discoverability of the
template/launcher on GitHub.

d-tests are **regression guards** that run on demand. They are NOT a substitute
for e2e (the launcher has no e2e — `dev-studio-template` owns that).

## Layout

```
scripts/tests/
├── INDEX.md                  ← this file
└── s29-003-url-hygiene.sh    ← STORY-S29-003 (atilcan65 → atilproject URL hygiene)
```

## How to run

```bash
bash scripts/tests/<d-test>.sh          # run a single d-test
bash scripts/tests/<d-test>.sh --self-test  # self-test (some d-tests only)
```

d-tests exit 0 (GREEN) or 1 (RED). RED means a regression slipped in; fix the
underlying doc/code so the d-test returns to GREEN.

## Index

| d-test | Story | Sister-pattern | TCs | Owner | Added |
|---|---|---|---|---|---|
| `s29-003-url-hygiene.sh` | [STORY-S29-003 (atilcan65/AtilCalculator#1015)](https://github.com/atilcan65/AtilCalculator/issues/1015) | [d095 (atilcan65 → atilproject migration guard, AtilCalculator)](https://github.com/atilcan65/AtilCalculator/blob/main/scripts/tests/d095-post-org-migration-clone-urls.sh) | 6 | developer | 2026-07-13 |

## Why this directory exists now (Sprint 29 genesis)

Sprint 29 cross-repo workstream pattern (Issue #1020 Option A, RESOLVED
2026-07-13T09:00:16Z) established that the launcher's URL hygiene is the
**first** concrete d-test living in this repo. Sister-pattern lineage:

- `atilproject/AtilCalculator/scripts/tests/d095-post-org-migration-clone-urls.sh`
  — AtilCalculator's atilcan65 → atilproject hygiene guard (Sprint 22 PIVOT Faz 2.4).
- `atilproject/AtilCalculator/scripts/tests/d096-soul-files-template.sh`
  — soul-file template coverage (S21-006).
- `atilproject/AtilCalculator/scripts/tests/d097-self-hosted-runner-migration.sh`
  — self-hosted runner migration guard.

When `dev-studio-template` adds its own `scripts/tests/` (forthcoming, depends
on `STORY-S29-007` — test ports — landing in W2), this file should be referenced
from the template's INDEX as a sister-pattern.

## Adding a new d-test

1. Write the d-test with ≥3 TCs (ADR-0049 minimum, ≥5 recommended).
2. Update this INDEX.md in the **same commit** (ADR-0055 §1 Cadence Rule 1 atomic).
3. Commit + PR per project workflow.

— @developer, 2026-07-13 (Sprint 29 W1, STORY-S29-003 genesis).