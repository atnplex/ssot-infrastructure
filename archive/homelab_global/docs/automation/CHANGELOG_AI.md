--------------------------------------------------------------------------------
Run: 2026-01-18-021308
Branch: auto/process-2026-01-18-021308
Host: vps
Message: Overnight processing pass: fmt-fix + qa; update changelog entry
Result: fmt-fix=0 qa=0

Diffstat:
 .../instructions/copilot-global-instructions.md    |   4 +-
 README.md                                          |  12 +-
 docs/inventory/00-consolidation-plan.md            |   8 +-
 docs/inventory/01-repos-raw.md                     |   4 +-
 docs/policy/01-settings-scope.md                   |  10 +-
 docs/policy/02-ai-task-order.md                    |   8 +-
 .../cloudflared/scripts/cloudflared-watchdog.sh    | 134 ++++++++++-----------
 .../cloudflared/scripts/cloudflared-watchdog.sh    | 134 ++++++++++-----------
 scripts/automation/run_once.sh                     |   8 +-
 scripts/github/protect_main.sh                     |   7 +-
 scripts/intake/intake_repo.sh                      |  24 ++--
 scripts/inventory/export_repos.sh                  |  35 +++---
 scripts/qa/check-no-tool-citations.sh              |  10 +-
 scripts/qa/check-whitespace.sh                     |   4 +-
 scripts/qa/fix-whitespace.sh                       |   4 +-
 scripts/qa/scan_secrets.sh                         |   4 +-
 scripts/qa/strip_citations.sh                      |   6 +-
 scripts/review/promote.sh                          |  21 +++-
 18 files changed, 228 insertions(+), 209 deletions(-)

--------------------------------------------------------------------------------
Run: 2026-01-18-134845
Branch: auto/process-2026-01-18-134845
Host: vps
Message: Automated run: fmt-fix + make qa; normalize whitespace/CRLF; enforce repo conventions.
Result: fmt-fix=0 qa=0

Diffstat:
 docs/automation/CHANGELOG_AI.md        |  8 ++++++++
 scripts/automation/ai_refactor_loop.sh | 10 +++++-----
 scripts/automation/run_once.sh         | 26 +++++++++++++++++---------
 scripts/qa/strip_citations.sh          |  2 +-
 4 files changed, 31 insertions(+), 15 deletions(-)

