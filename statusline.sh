#!/bin/bash
# Claude Code status line script
# Shows: [Model] Directory | Branch | Context% | Cost | Learning Progress
#
# active-plan format (one entry per line):
#   planname.md          → looked up in ~/.claude/plans/
#   path:relative/path   → looked up relative to project dir

input=$(cat)

# Extract JSON values
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // "."')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // "0"')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Get directory name
DIR_NAME=$(basename "$PROJECT_DIR" 2>/dev/null || echo "unknown")

# Get git branch if in repo
BRANCH=""
if [ -d "$PROJECT_DIR/.git" ] || git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null)
fi

# Format cost
if [ "$COST" != "0" ] && [ -n "$COST" ]; then
    COST_FMT=$(printf "$%.2f" "$COST")
else
    COST_FMT=""
fi

# Format context usage
CTX_FMT=""
if [ "$CTX_PCT" != "0" ] && [ -n "$CTX_PCT" ]; then
    CTX_FMT="ctx:${CTX_PCT}%"
fi

# Format weekly limit usage
WEEKLY_PCT=$(echo "$input" | jq -r '
  (
    .rate_limits.seven_day.used_percentage //
    (.rate_limits.seven_day.utilization | if . != null then . * 100 else empty end) //
    .rate_limits.weekly.used_percentage //
    (.rate_limits.weekly.utilization | if . != null then . * 100 else empty end) //
    .rate_limits.seven_day_opus.used_percentage //
    .rate_limits.seven_day_sonnet.used_percentage //
    empty
  )' 2>/dev/null | cut -d. -f1)

WEEKLY_FMT=""
if [ -n "$WEEKLY_PCT" ] && [ "$WEEKLY_PCT" != "null" ]; then
    WEEKLY_FMT="7d:${WEEKLY_PCT}%"
fi

# Learning progress — supports multiple plans
LEARN_FMT=""
ACTIVE_PLAN_MARKER="$PROJECT_DIR/.claude/active-plan"
if [ -f "$ACTIVE_PLAN_MARKER" ]; then
    LEARN_PARTS=()
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | tr -d '[:space:]')
        [ -z "$line" ] && continue

        # Resolve plan file path
        if [[ "$line" == path:* ]]; then
            PLAN_FILE="$PROJECT_DIR/${line#path:}"
        else
            PLAN_FILE="$HOME/.claude/plans/$line"
        fi
        [ ! -f "$PLAN_FILE" ] && continue

        DONE=$(grep -c '^ *- \[x\]' "$PLAN_FILE" 2>/dev/null)
        [ -z "$DONE" ] && DONE=0
        TODO=$(grep -c '^ *- \[ \]' "$PLAN_FILE" 2>/dev/null)
        [ -z "$TODO" ] && TODO=0
        TOTAL=$((DONE + TODO))
        [ "$TOTAL" -eq 0 ] && continue

        CURRENT=$(grep '^ *- \[ \]' "$PLAN_FILE" 2>/dev/null | head -1 | sed 's/^ *- \[ \] \*\*//' | sed 's/\*\*.*//' | sed 's/^ *- \[ \] //' | cut -c1-20)
        FILLED=$((DONE * 10 / TOTAL))
        BAR=""
        for i in $(seq 1 10); do
            [ "$i" -le "$FILLED" ] && BAR="${BAR}▓" || BAR="${BAR}░"
        done
        LEARN_PARTS+=("[${DONE}/${TOTAL}] ${BAR} ▶ ${CURRENT}")
    done < "$ACTIVE_PLAN_MARKER"

    # Join all plan progress with separator
    for i in "${!LEARN_PARTS[@]}"; do
        if [ "$i" -eq 0 ]; then
            LEARN_FMT="${LEARN_PARTS[$i]}"
        else
            LEARN_FMT="$LEARN_FMT ┊ ${LEARN_PARTS[$i]}"
        fi
    done
fi

# Build output
OUTPUT="[$MODEL] $DIR_NAME"
[ -n "$BRANCH" ] && OUTPUT="$OUTPUT | $BRANCH"
[ -n "$CTX_FMT" ] && OUTPUT="$OUTPUT | $CTX_FMT"
[ -n "$WEEKLY_FMT" ] && OUTPUT="$OUTPUT | $WEEKLY_FMT"
[ -n "$COST_FMT" ] && OUTPUT="$OUTPUT | $COST_FMT"
[ -n "$LEARN_FMT" ] && OUTPUT="$OUTPUT | $LEARN_FMT"

echo "$OUTPUT"
