---
name: my-context
description: Show current AI coding session context including directory, branch, worktree state, and available tasks
---

# Context

Display the current session context to help you quickly orient yourself when switching between AI coding sessions.

## Usage

```
Claude Code: /my-context
Codex:      $my-context
```

In Gemini or another tool, load the shared `my-context` skill by name.

## What It Shows

1. **Current Directory**
   - Full path and directory name
   - Whether it's a git worktree

2. **Git Status**
   - Current branch name
   - Commits ahead/behind remote
   - Uncommitted changes summary

3. **Active Tasks**
   - List tasks from the current AI tool's planning or task-tracking capability when available
   - Highlight in-progress items
   - If the runtime does not expose session tasks, state that task data is unavailable and continue with the remaining context

4. **Recent Activity** (optional)
   - Last few git commits on current branch
   - Recently modified files

## Workflow

1. **Get directory info**
   ```bash
   pwd
   basename "$PWD"
   ```

2. **Check if in a worktree**
   ```bash
   git worktree list 2>/dev/null | grep "$PWD"
   ```

3. **Get git status**
   ```bash
   git branch --show-current
   git status --short
   git rev-list --count HEAD..@{u} 2>/dev/null  # behind
   git rev-list --count @{u}..HEAD 2>/dev/null  # ahead
   ```

4. **Display available tasks**
   - Use the current AI tool's planning or task-tracking capability when it exposes session tasks
   - Format:
     ```
     Todos:
       [x] Completed task
       [>] In progress task  <-- CURRENT
       [ ] Pending task
     ```

5. **Show recent commits** (last 3)
   ```bash
   git log --oneline -3
   ```

## Output Format

```
================================================
SESSION CONTEXT
================================================

Directory:  /path/to/project-issue-123-feature
Worktree:   Yes (main repo: /path/to/project)
Branch:     issue-123-add-feature
Status:     2 commits ahead, 0 behind
Changes:    2 modified, 1 untracked

------------------------------------------------
CURRENT TASK
------------------------------------------------

[>] Implementing the validation function

------------------------------------------------
ALL TODOS
------------------------------------------------

[x] Read existing code
[x] Create test file
[>] Implementing the validation function
[ ] Run tests
[ ] Commit changes
[ ] Create PR

------------------------------------------------
RECENT COMMITS
------------------------------------------------

abc1234 Add test scaffolding
def5678 Initial implementation

================================================
```

## Tips

- Run this skill whenever you switch to another AI coding session
- Use with GNOME Terminal tab titles for quick identification
- Use the current tool's native planning or task view for more detailed tracking when available
