# Changelog

All notable changes to this project are recorded here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.1] - 2026-07-23

### Added

- **README "Task-list Persistence" section** ([atilproject/dev-studio-launcher#14](https://github.com/atilproject/dev-studio-launcher/issues/14), S32-XXX-D):
  Short explanation of the per-project `state/tasklists/` directory that
  `scripts/dev-studio-init.sh` (template-side) creates at clone time +
  registers in `.gitignore`. Per [ADR-0073](https://github.com/atilproject/dev-studio-template/blob/main/docs/decisions/ADR-0073-tasklist-persistence-and-watchdog-tuning-revision.md)
  (sister: [ADR-0072](https://github.com/atilcan65/AtilCalculator/blob/main/docs/decisions/ADR-0072-tasklist-persistence-and-watchdog-tuning-revision.md)).

- **`new-project.sh` AC2 verify** ([atilproject/dev-studio-launcher#14](https://github.com/atilproject/dev-studio-launcher/issues/14)):
  Documentation comment block at the `running dev-studio-init.sh` step
  noting template-side responsibility for `state/tasklists/` creation.
  No code action — template clone already handles it per ADR-0073.

### Changed

- **Version bump** v0.4.0 → v0.4.1 (README footer + Versioning table).

### Notes

- Owner directive 2026-07-19: "kod mirror yok (template'den geliyor önerin
  uygun). Launcher agent çalıştırmıyor, template referans yeterli."
  Doc-only sync — no scripts/ files mirrored from template.
- Sister-pattern: tmpl#192 (S32-XXX-B impl canonical) + calc#1173
  (S32-XXX-C forward-port mirror). Both merged 2026-07-19.

## [0.4.0] - 2026-07-18

### Added

- **CI workflow** (`#12`, Issue #8 S32-014 + Issue #10 S32-015):
  `.github/workflows/ci.yml` runs `tests/d001-launcher-self-hosted-runner-patch.sh`
  on push + PR. SHA-pinned actions per ADR-0027 (defense-in-depth per
  tmpl#148 sister-pattern). Detect-step pattern (bash-source existence)
  parity with tmpl#147 Python detection. Conventional Commits gate on
  PR titles. Run via `Lint & Test` + `Conventional Commits` jobs.

- **v0.4.0 = "now CI-tested" milestone** (sister-pattern to tmpl v1.1.0
  S32-019). Before v0.4.0 the launcher had d-test coverage but no CI;
  now every push verifies the self-hosted 4-tuple patch and hygiene.

### Changed

- README footer bumped to v0.4.0 (per AC2 of Issue #11 S32-016).

### Notes

- AC5 trust-but-verify (Issue #972): tag `v0.4.0` cut post-merge.
- Sister-pattern: atilproject/dev-studio-template@`tmpl#147` + `tmpl#148`
  (SHA-pin + Python detect → shell-source detect adaptation).

## [0.3.0] - 2026-07-04

### Added

- Public-by-default visibility, `--private` opt-in (ADR-0016, PR #2).

## [0.2.0] - 2026-06-XX

### Added

- Default parent dir `~/projects` (auto-created) (PR #1).

## [0.1.0] - initial

### Added

- A1 + B1 + C2 decision: minimal `new-project.sh` automation (positional
  arg, separate launcher repo, one-time clone + symlink).
