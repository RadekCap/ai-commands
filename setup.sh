#!/bin/bash
# Setup script for ai-commands
# Configures shared skills for Claude Code and Codex, plus Claude-specific hooks,
# statusline, global instructions, and settings.
#
# Usage:
#   git clone git@github.com:RadekCap/ai-commands.git ~/git/ai-commands
#   cd ~/git/ai-commands
#   ./setup.sh
#
# What it does:
#   1. Keeps the legacy ~/.claude/commands/ link for existing installations
#   2. Links every skill into ~/.claude/skills/ and ~/.agents/skills/
#   3. Symlinks ~/.claude/CLAUDE.md → this repo's CLAUDE.md (global instructions)
#   4. Symlinks statusline.sh and patches Claude settings and hooks
#
# Safe to re-run: skips steps that are already done.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CODEX_SKILLS_DIR="$HOME/.agents/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "=== Claude Commands Setup ==="
echo "Source: $SCRIPT_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Step 1: Create ~/.claude if needed
mkdir -p "$CLAUDE_DIR"

# Step 2: Symlink commands directory
# Uses a directory symlink so new commands are available immediately
if [ -L "$CLAUDE_DIR/commands" ]; then
    CURRENT_TARGET="$(readlink "$CLAUDE_DIR/commands")"
    if [ "$CURRENT_TARGET" = "$SCRIPT_DIR" ]; then
        echo "[OK] Commands symlink already correct"
    else
        echo "[UPDATE] Commands symlink points to $CURRENT_TARGET, updating..."
        rm "$CLAUDE_DIR/commands"
        ln -s "$SCRIPT_DIR" "$CLAUDE_DIR/commands"
        echo "[OK] Commands symlink updated"
    fi
elif [ -d "$CLAUDE_DIR/commands" ]; then
    # Check if it's a directory with individual symlinks (old setup)
    echo "[MIGRATE] Converting individual command symlinks to directory symlink..."
    # Back up any non-symlink files (custom commands not from this repo)
    CUSTOM_CMDS=()
    for f in "$CLAUDE_DIR/commands/"*.md; do
        [ -e "$f" ] || continue
        if [ ! -L "$f" ]; then
            CUSTOM_CMDS+=("$(basename "$f")")
            cp "$f" "/tmp/claude-cmd-backup-$(basename "$f")"
        fi
    done
    rm -rf "$CLAUDE_DIR/commands"
    ln -s "$SCRIPT_DIR" "$CLAUDE_DIR/commands"
    echo "[OK] Commands directory symlinked"
    if [ ${#CUSTOM_CMDS[@]} -gt 0 ]; then
        echo "[WARN] Custom commands backed up to /tmp/:"
        for c in "${CUSTOM_CMDS[@]}"; do
            echo "       /tmp/claude-cmd-backup-$c"
        done
        echo "       Move these into your project's .claude/commands/ instead"
    fi
else
    ln -s "$SCRIPT_DIR" "$CLAUDE_DIR/commands"
    echo "[OK] Commands symlinked"
fi

# Link canonical Agent Skills without replacing unrelated personal skills.
# Root-level *.md command symlinks remain for older Claude Code installations.
link_skills() {
    local target_dir="$1"
    local product="$2"

    mkdir -p "$target_dir"
    for skill_dir in "$SCRIPT_DIR/skills/"*; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        local name
        local target
        name="$(basename "$skill_dir")"
        target="$target_dir/$name"

        if [ -L "$target" ]; then
            if [ "$(readlink "$target")" = "$skill_dir" ]; then
                echo "[OK] $product skill $name already symlinked"
            else
                echo "[UPDATE] $product skill $name points elsewhere, updating..."
                rm "$target"
                ln -s "$skill_dir" "$target"
            fi
        elif [ -e "$target" ]; then
            echo "[WARN] $product skill $name already exists and was preserved: $target"
        else
            ln -s "$skill_dir" "$target"
            echo "[OK] $product skill $name symlinked"
        fi
    done
}

link_skills "$CLAUDE_SKILLS_DIR" "Claude Code"
link_skills "$CODEX_SKILLS_DIR" "Codex"

# Step 3: Symlink CLAUDE.md (global instructions)
if [ -L "$CLAUDE_DIR/CLAUDE.md" ]; then
    CURRENT_TARGET="$(readlink "$CLAUDE_DIR/CLAUDE.md")"
    if [ "$CURRENT_TARGET" = "$SCRIPT_DIR/CLAUDE.md" ]; then
        echo "[OK] CLAUDE.md symlink already correct"
    else
        echo "[UPDATE] CLAUDE.md symlink points to $CURRENT_TARGET, updating..."
        rm "$CLAUDE_DIR/CLAUDE.md"
        ln -s "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
        echo "[OK] CLAUDE.md symlink updated"
    fi
elif [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    echo "[MIGRATE] Replacing CLAUDE.md copy with symlink..."
    mv "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
    ln -s "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "[OK] CLAUDE.md symlinked (backup at CLAUDE.md.backup)"
else
    ln -s "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "[OK] CLAUDE.md symlinked"
fi

# Step 4: Symlink statusline
if [ -L "$CLAUDE_DIR/statusline.sh" ]; then
    CURRENT_TARGET="$(readlink "$CLAUDE_DIR/statusline.sh")"
    if [ "$CURRENT_TARGET" = "$SCRIPT_DIR/statusline.sh" ]; then
        echo "[OK] Statusline symlink already correct"
    else
        echo "[UPDATE] Statusline symlink points to $CURRENT_TARGET, updating..."
        rm "$CLAUDE_DIR/statusline.sh"
        ln -s "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
        echo "[OK] Statusline symlink updated"
    fi
elif [ -f "$CLAUDE_DIR/statusline.sh" ]; then
    echo "[MIGRATE] Replacing statusline copy with symlink..."
    rm "$CLAUDE_DIR/statusline.sh"
    ln -s "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
    echo "[OK] Statusline symlinked (replaced copy)"
else
    ln -s "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
    echo "[OK] Statusline symlinked"
fi

# Step 5: Ensure hooks are executable
chmod +x "$SCRIPT_DIR/hooks/"*.sh
echo "[OK] Hooks are executable"

# Step 6: Patch settings.json
if ! command -v jq &> /dev/null; then
    echo ""
    echo "[ERROR] jq is required to patch settings.json"
    echo "        Install with: brew install jq (macOS) or sudo apt install jq (Linux)"
    exit 1
fi

# Build the full config
SHARED_CONFIG=$(jq -n \
    --arg statusline "$CLAUDE_DIR/statusline.sh" \
    --arg pr_hook "$SCRIPT_DIR/hooks/require-confirmation-before-pr.sh" \
    --arg resume_hook "$SCRIPT_DIR/hooks/on-resume.sh" \
    --arg sync_hook "$SCRIPT_DIR/hooks/sync-shared-commands.sh" \
    --arg obsidian_hook "$SCRIPT_DIR/hooks/obsidian-auto-approve.sh" \
    '{
        statusLine: {
            type: "command",
            command: $statusline
        },
        hooks: {
            PreToolUse: [
                {
                    matcher: "Bash",
                    hooks: [
                        {
                            type: "command",
                            command: $pr_hook
                        }
                    ]
                },
                {
                    matcher: "Bash|Write|Edit",
                    hooks: [
                        {
                            type: "command",
                            command: $obsidian_hook,
                            timeout: 5
                        }
                    ]
                }
            ],
            SessionStart: [
                {
                    matcher: "resume",
                    hooks: [
                        {
                            type: "command",
                            command: $resume_hook
                        }
                    ]
                },
                {
                    matcher: "*",
                    hooks: [
                        {
                            type: "command",
                            command: $sync_hook
                        }
                    ]
                }
            ]
        }
    }')

if [ -f "$SETTINGS_FILE" ]; then
    # If settings.json is a symlink, replace it with a real file
    if [ -L "$SETTINGS_FILE" ]; then
        REAL_SETTINGS=$(cat "$SETTINGS_FILE")
        rm "$SETTINGS_FILE"
        echo "$REAL_SETTINGS" > "$SETTINGS_FILE"
        echo "[MIGRATE] Converted settings.json from symlink to file"
    fi
    # Merge: shared config provides the base, existing settings override non-hook fields
    # For hooks, we replace entirely (shared config is the source of truth)
    EXISTING=$(cat "$SETTINGS_FILE")
    MERGED=$(echo "$EXISTING" | jq --argjson shared "$SHARED_CONFIG" '
        # Keep all existing fields except hooks/statusLine (those come from shared)
        . * $shared
    ')
    echo "$MERGED" > "$SETTINGS_FILE"
    echo "[OK] Settings updated (merged with existing)"
else
    echo "$SHARED_CONFIG" > "$SETTINGS_FILE"
    echo "[OK] Settings created"
fi

# Step 7: Symlink bin scripts to ~/bin
mkdir -p "$HOME/bin"
for script in "$SCRIPT_DIR/bin/"*; do
    [ -f "$script" ] || continue
    name="$(basename "$script")"
    target="$HOME/bin/$name"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$script" ]; then
        echo "[OK] ~/bin/$name already symlinked"
    else
        ln -sf "$script" "$target"
        echo "[OK] ~/bin/$name symlinked"
    fi
done

# Step 8: Configure Antigravity / Gemini CLI (~/.gemini/config)
GEMINI_CONFIG_DIR="$HOME/.gemini/config"
GEMINI_RULES_DIR="$GEMINI_CONFIG_DIR/rules"
mkdir -p "$GEMINI_RULES_DIR"

if [ -L "$GEMINI_CONFIG_DIR/GEMINI.md" ]; then
    CURRENT_TARGET="$(readlink "$GEMINI_CONFIG_DIR/GEMINI.md")"
    if [ "$CURRENT_TARGET" = "$SCRIPT_DIR/GEMINI.md" ]; then
        echo "[OK] Antigravity GEMINI.md symlink already correct"
    else
        echo "[UPDATE] Antigravity GEMINI.md symlink points to $CURRENT_TARGET, updating..."
        rm "$GEMINI_CONFIG_DIR/GEMINI.md"
        ln -s "$SCRIPT_DIR/GEMINI.md" "$GEMINI_CONFIG_DIR/GEMINI.md"
        echo "[OK] Antigravity GEMINI.md symlink updated"
    fi
elif [ -f "$GEMINI_CONFIG_DIR/GEMINI.md" ]; then
    echo "[MIGRATE] Replacing Antigravity GEMINI.md with symlink..."
    mv "$GEMINI_CONFIG_DIR/GEMINI.md" "$GEMINI_CONFIG_DIR/GEMINI.md.backup"
    ln -s "$SCRIPT_DIR/GEMINI.md" "$GEMINI_CONFIG_DIR/GEMINI.md"
    echo "[OK] Antigravity GEMINI.md symlinked (backup at GEMINI.md.backup)"
else
    ln -s "$SCRIPT_DIR/GEMINI.md" "$GEMINI_CONFIG_DIR/GEMINI.md"
    echo "[OK] Antigravity GEMINI.md symlinked"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Installed for Claude Code:"
echo "  - Commands:   $CLAUDE_DIR/commands/ -> $SCRIPT_DIR/"
echo "  - Skills:     $CLAUDE_SKILLS_DIR/* -> $SCRIPT_DIR/skills/*"
echo "  - CLAUDE.md:  $CLAUDE_DIR/CLAUDE.md -> $SCRIPT_DIR/CLAUDE.md"
echo "  - Statusline: $CLAUDE_DIR/statusline.sh -> $SCRIPT_DIR/statusline.sh"
echo "  - Hooks:"
echo "    - PreToolUse:   Block gh pr create (require confirmation)"
echo "    - PreToolUse:   Auto-approve Obsidian vault operations (needs \$OBSIDIAN_VAULT)"
echo "    - SessionStart: Show context on resume"
echo "    - SessionStart: Auto-sync shared commands from GitHub"
echo ""
echo "Installed for Codex:"
echo "  - Skills:     $CODEX_SKILLS_DIR/* -> $SCRIPT_DIR/skills/*"
echo ""
echo "Installed for Antigravity / Gemini CLI:"
echo "  - GEMINI.md:  $GEMINI_CONFIG_DIR/GEMINI.md -> $SCRIPT_DIR/GEMINI.md"
echo ""
echo "Auto-sync: Every new session will pull latest changes"
echo "           from the ai-commands repo automatically."
echo ""
echo "Restart Claude Code, Codex, or Antigravity if new skills do not appear."
