<!--
file: docs/inbox/ai-intake-queue.md
repo: homelab_global
owner: alex
created: 2026-01-17
last_reviewed: 2026-01-17
purpose: Ordered queue of consolidation tasks to feed to AI in deterministic order.
tags: [ai, intake, queue, consolidation]
-->

# AI intake queue (ordered)

## Rule
AI must follow `docs/policy/02-ai-task-order.md` for every item.

## Queue (edit this list as you go)
1) Sanitize and paste repo lists into `docs/inventory/01-repos-raw.md` (NO TOKENS).
2) Classify repos in `docs/inventory/02-repos-classified.csv`.
3) Move your ATN prompt canon into `docs/inbox/ai-canon-intake.md` (sanitized).
4) Normalize prompts into:
   - `.github/instructions/`
   - `.github/prompts/`
   - `templates/scripts/`
   - `docs/policy/`
5) Add CI workflows (ShellCheck/gitleaks) after local gate is stable.
