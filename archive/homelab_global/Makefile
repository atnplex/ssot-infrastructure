SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

.RECIPEPREFIX := >
.SILENT:

.PHONY: help qa qa-check fmt lint fmt-shell lint-shell strip-citations scan-secrets diff-status inventory intake intake-cloudflared-unraid protect-main promote

help:
> printf '%s\n' \
> "Targets:" \
> "  make qa                          Run full quality gate (strip citations -> fmt -> lint -> diff)." \
> "  make qa-check                    Run checks only (lint -> diff)." \
> "  make fmt                         Apply safe auto-formatters (currently shfmt)." \
> "  make lint                        Run linters (shellcheck + gitleaks if available)." \
> "  make inventory                   Export repo inventory via GitHub API (requires GITHUB_TOKEN)." \
> "  make intake REPO=owner/name      Intake repo into docs/reviews (tracked file snapshot)." \
> "  make promote SLUG=.. SRC=.. DST=.. CAT=.. [NOTES=..]  Promote reviewed candidate into SSOT."

qa: strip-citations fmt lint diff-status
qa-check: lint diff-status
fmt: fmt-shell
lint: lint-shell scan-secrets

fmt-shell:
> files="$$(git ls-files '*.sh' 2>/dev/null || true)"; \
> if [[ -z "$$files" ]]; then echo "[fmt-shell] no .sh files; skipping"; exit 0; fi; \
> shfmt -w -i 2 -ci -sr $$files

lint-shell:
> files="$$(git ls-files '*.sh' 2>/dev/null || true)"; \
> if [[ -z "$$files" ]]; then echo "[lint-shell] no .sh files; skipping"; exit 0; fi; \
> shellcheck $$files

strip-citations:
> ./scripts/qa/strip_citations.sh

scan-secrets:
> ./scripts/qa/scan_secrets.sh

diff-status:
> git status --porcelain=v1 || true
> git diff --stat || true

inventory:
> ./scripts/inventory/export_repos.sh

intake:
> : "$${REPO:?Usage: make intake REPO=owner/name}"
> ./scripts/intake/intake_repo.sh "$${REPO}"

intake-cloudflared-unraid:
> ./scripts/intake/intake_repo.sh atnplex/cloudflared-unraid

protect-main:
> ./scripts/github/protect_main.sh

promote:
> : "$${SLUG:?Usage: make promote SLUG=repo_slug SRC=rel DST=rel CAT=category [NOTES=...]}"
> : "$${SRC:?Usage: make promote SLUG=repo_slug SRC=rel DST=rel CAT=category [NOTES=...]}"
> : "$${DST:?Usage: make promote SLUG=repo_slug SRC=rel DST=rel CAT=category [NOTES=...]}"
> : "$${CAT:?Usage: make promote SLUG=repo_slug SRC=rel DST=rel CAT=category [NOTES=...]}"
> ./scripts/review/promote.sh "$${SLUG}" "$${SRC}" "$${DST}" "$${CAT}" "$${NOTES-}"

.PHONY: fmt-check fmt-fix

fmt-check:
> @./scripts/qa/check-whitespace.sh
> @./scripts/qa/check-no-tool-citations.sh

fmt-fix:
> @./scripts/qa/fix-whitespace.sh
> @$(MAKE) fmt-check
