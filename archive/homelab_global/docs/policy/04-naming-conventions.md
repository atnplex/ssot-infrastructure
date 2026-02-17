<!--
file: docs/policy/04-naming-conventions.md
repo: homelab_global
owner: alex
created: 2026-01-18
last_reviewed: 2026-01-18
purpose: Canonical naming rules for SSOT-managed files/dirs and automation outputs.
tags: [policy, naming, ssot, conventions]
-->

# Naming conventions (SSOT)

## Scope
These rules apply to any SSOT-managed paths and files created by automation in this repo:
- `docs/`
- `templates/`
- `scripts/`
- `docs/reviews/*` (directory names and SSOT metadata files)

## Rules (hard)
- Lowercase only for SSOT-managed paths.
- Snake_case preferred for SSOT-managed directory/file names.
- Never allow two underscores consecutively (`__`) in SSOT-managed names.
- Prefer explicit file extensions where practical (e.g., `.md`, `.sh`, `.yml`, `.json`).

## Upstream exception (important)
Candidate snapshots under `docs/reviews/<slug>/candidates/` preserve upstream paths and filenames byte-for-byte.
They are not renamed even if they violate SSOT naming rules, because they represent source-of-truth evidence for review.
