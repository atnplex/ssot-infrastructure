<!--
file: docs/policy/06-build-and-packaging-patterns.md
repo: homelab_global
owner: alex
created: 2026-01-18
last_reviewed: 2026-01-18
purpose: SSOT patterns for build scripts that download, verify, package, and template artifacts.
tags: [policy, build, packaging, supply-chain, reproducible]
-->

# Build & packaging patterns (SSOT)

## Supply-chain rules
- Never ship a downloaded binary without verification.
- Prefer SHA256 verification; fail hard on mismatch.
- Refuse downloads when expected hash is missing.

## Packaging rules
- Stage a filesystem payload from a dedicated `src/` tree.
- Generate installable artifacts from templates (e.g., `.plg.template` -> `.plg`) by substituting explicit placeholders.
- Write outputs atomically when practical (write temp, then rename).

## Automation rules
- Make builds deterministic where possible (sorted traversal, stable permissions, stable paths).
- Keep build scripts verbose on failure (print stderr/stdout on subprocess failure) but avoid leaking secrets.
