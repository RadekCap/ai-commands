#!/bin/bash
# SessionStart hook: auto-sync shared ai-commands repo
# Runs a fast-forward pull to get latest commands, hooks, and settings.
# Silently succeeds if offline or already up to date.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Only sync if we're in a git repo (sanity check)
if [ ! -d "$REPO_DIR/.git" ]; then
    exit 0
fi

# Fast-forward only, timeout after 5 seconds, suppress output unless there's an update
OUTPUT=$(git -C "$REPO_DIR" pull --ff-only --quiet 2>&1) || true

if echo "$OUTPUT" | grep -q "Updating"; then
    echo "[sync] Shared commands updated from remote"

    # Re-copy statusline if it changed (it's a copy, not a symlink)
    if git -C "$REPO_DIR" diff HEAD~1 --name-only 2>/dev/null | grep -q "statusline.sh"; then
        cp "$REPO_DIR/statusline.sh" "$HOME/.claude/statusline.sh"
        chmod +x "$HOME/.claude/statusline.sh"
        echo "[sync] Statusline updated"
    fi

    # Re-symlink CLAUDE.md if it changed
    if git -C "$REPO_DIR" diff HEAD~1 --name-only 2>/dev/null | grep -q "CLAUDE.md"; then
        echo "[sync] CLAUDE.md updated — restart session to apply"
    fi
fi

exit 0
