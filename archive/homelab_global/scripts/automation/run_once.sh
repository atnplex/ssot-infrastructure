#!/usr/bin/env bash
# file: scripts/automation/run_once.sh
# purpose: Create an isolated worktree run, execute local formatters, then run the AI iterator, and push results.

set -euo pipefail

# Imports (strict mode first by policy)
# shellcheck disable=SC1091
source scripts/lib/env_manager.sh
# shellcheck disable=SC1091
source scripts/lib/init_workspace.sh
# shellcheck disable=SC1091
source scripts/lib/dependency_manager.sh

cleanup() {
	local rc=$?
	set +e

	if [[ -n "${DASH_PID:-}" ]]; then
		kill "$DASH_PID" 2>/dev/null
		wait "$DASH_PID" 2>/dev/null
	fi

	tput cnorm 2>/dev/null || true

	if [[ -n "${REPO:-}" ]]; then
		cd "$REPO" 2>/dev/null || true
	fi

	if [[ -n "${WT_DIR:-}" ]]; then
		git worktree remove "$WT_DIR" --force >/dev/null 2>&1 || true
	fi

	if [[ -n "${LOCKDIR:-}" ]]; then
		rmdir "$LOCKDIR" 2>/dev/null || true
	fi

	exit "$rc"
}
trap cleanup EXIT INT TERM

clear
echo "⚙️  Initializing Environment..."

# Workspace init (explicit; init_workspace.sh is side-effect free on source)
init_ram_disk

if [[ -z "${ATN_WORK_DIR:-}" ]]; then
	echo "❌ Workspace error"
	exit 1
fi

check_and_fix_environment || {
	echo "❌ Failed to install dependencies."
	exit 1
}
load_secrets || exit 1

# Clean stale worktree admin data (safe)
git worktree prune -v >/dev/null 2>&1 || true

# Snapshot/tag backup (idempotent)
if ! git tag --points-at HEAD | grep -q "^snapshot-"; then
	SHA_SHORT="$(git rev-parse --short HEAD)"
	TAG_NAME="snapshot-$(date +%F-%H%M%S)-${SHA_SHORT}"
	echo "📸 Creating snapshot tag: $TAG_NAME"
	git tag -a "$TAG_NAME" -m "Automated snapshot before run"
	git push origin "$TAG_NAME" >/dev/null 2>&1 || true
else
	echo "✅ Snapshot tag already exists for current HEAD."
fi

# Model
# shellcheck disable=SC1091
source scripts/lib/model_negotiator.sh fast >/dev/null 2>&1
if [[ -z "${GEMINI_MODEL:-}" ]]; then
	echo "❌ Model negotiation failed"
	exit 1
fi

# Config
REPO="${REPO:-$(git rev-parse --show-toplevel)}"
TS="$(date +%F-%H%M%S)"
BRANCH_NAME="auto/refactor-$TS"

export RUN_BASE="${ATN_WORK_DIR}/runs/homelab_global"
export RUN_DIR="$RUN_BASE/$TS"
export WT_DIR="$RUN_DIR/worktree"
export LOG_DIR="$RUN_DIR/logs"

LOCKDIR="${ATN_WORK_DIR}/homelab_global.lock"
STATUS_FILE="status.txt"

mkdir -p "$RUN_DIR" "$LOG_DIR"

if ! mkdir "$LOCKDIR" 2>/dev/null; then
	echo "🔒 Locked"
	exit 0
fi

# --- DASHBOARD ---
dashboard() {
	local start_time
	start_time="$(date +%s)"

	tput civis 2>/dev/null || true

	while true; do
		local elapsed task
		elapsed=$(($(date +%s) - start_time))
		task="Initializing..."
		[[ -f "$STATUS_FILE" ]] && task="$(cat "$STATUS_FILE")"

		tput cup 0 0 2>/dev/null || true

		echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
		echo -e "${BLUE}║                 AUTOMATION DASHBOARD                       ║${NC}"
		echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
		printf "${BLUE}║${NC} %-12s : %-32s ${BLUE}║${NC}\n" "Run ID" "$TS"
		printf "${BLUE}║${NC} %-12s : %-32s ${BLUE}║${NC}\n" "Model" "$GEMINI_MODEL"
		printf "${BLUE}║${NC} %-12s : %-32s ${BLUE}║${NC}\n" "Elapsed" "${elapsed}s"
		echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"

		tput el 2>/dev/null || true
		echo -e "${YELLOW}▶ Current Action:${NC} $task"
		echo ""

		echo -e "${BLUE}--- Recent Logs ---${NC}"
		if [[ -f "$LOG_DIR/iterator.log" ]]; then
			tail -n 5 "$LOG_DIR/iterator.log" | while IFS= read -r line; do
				tput el 2>/dev/null || true
				echo "  $line"
			done
		else
			echo "  (Waiting for logs...)"
		fi

		tput el 2>/dev/null || true
		sleep 1
	done
}

# --- EXECUTION ---
git -C "$REPO" worktree add -B "$BRANCH_NAME" "$WT_DIR" HEAD >/dev/null 2>&1
cd "$WT_DIR"

mkdir -p scripts/automation scripts/lib docs/policy
cp -r "$REPO/scripts/automation/"* scripts/automation/ 2>/dev/null || true
cp -r "$REPO/scripts/lib/"* scripts/lib/ 2>/dev/null || true
cp -r "$REPO/docs/policy/"* docs/policy/ 2>/dev/null || true

dashboard &
DASH_PID=$!

echo "Running formatters..." >"$STATUS_FILE"
if ! make fmt-fix >"$LOG_DIR/fmt.log" 2>&1; then
	echo "⚠️ Formatters failed. Proceeding to AI..." >>"$LOG_DIR/system.log"
else
	echo "✅ Formatters passed." >>"$LOG_DIR/system.log"
fi

echo "Starting AI Iterator..." >"$STATUS_FILE"
set +e
./scripts/automation/refactor_iterator.sh "scripts/qa/*.sh" >"$LOG_DIR/iterator_debug.log" 2>&1
ITER_RC=$?
set -e

if [[ $ITER_RC -eq 0 ]]; then
	echo "✅ Complete."
	if [[ -n "$(git status --porcelain)" ]]; then
		echo "📤 Pushing changes..."
		git add -A
		git commit -m "refactor: auto-fixes ($TS)" >/dev/null
		git push origin "$BRANCH_NAME" >/dev/null 2>&1
		echo "🔗 Branch pushed: $BRANCH_NAME"

		if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
			if ! gh pr view "$BRANCH_NAME" >/dev/null 2>&1; then
				gh pr create \
					--base main \
					--head "$BRANCH_NAME" \
					--title "auto: refactor run ($TS)" \
					--body "Automated run.\n\n- Model: $GEMINI_MODEL\n- Logs: $LOG_DIR\n- Iterator rc: $ITER_RC" >/dev/null 2>&1 || true
			fi
		fi
	else
		echo "✨ No changes needed."
	fi
else
	echo "❌ Iterator failed (rc=$ITER_RC). Check logs: $LOG_DIR"
	exit "$ITER_RC"
fi
