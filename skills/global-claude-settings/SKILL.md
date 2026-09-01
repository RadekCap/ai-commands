---
name: global-claude-settings
description: Explain and maintain the shared global Claude Code settings.
---

# Global Claude Code Settings

Copy this file to `~/.claude/CLAUDE.md` on each machine to apply these settings globally.

```bash
# Quick install
cp global-claude-settings.md ~/.claude/CLAUDE.md
```

---

# CLAUDE.md

Global preferences for Claude Code across all projects.

## Communication preferences

- Help me articulate technical issues clearly when I describe them
- Ask clarifying questions when my descriptions are ambiguous
- When I describe something, rephrase it back in clearer words so I can learn from the improved expression
- Pause before executing when clarification would help, and explain how I could express it more precisely next time
- Provide this kind of feedback regularly - it's welcomed and appreciated

## Git workflow

- Always create a feature branch and open a pull request for changes
- Never commit directly to main or master branches

## Destructive actions

- Never delete Azure resources without explicit confirmation
- When asked to "list", "check", or "show" resources, only report findings - do not take action
- Always ask before: deleting, force-deleting, removing, or cleaning up resources
- When listing resources that might need cleanup, present findings and wait for user instruction
