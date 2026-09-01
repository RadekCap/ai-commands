---
name: close-worktree
description: Clean up a git worktree after a GitHub issue PR has been merged
---

# Close Worktree

Clean up a git worktree created with the shared `prepare-worktree` skill after the associated pull request has been merged.

## Usage

```
Claude Code: /close-worktree <issue-number>
Codex:      $close-worktree <issue-number>
```

**Example**: `/close-worktree 263` in Claude Code or `$close-worktree 263` in Codex

## Workflow

1. **Validate issue number argument**
   - If no issue number is provided, ask the user for one using the current tool's supported interaction method
   - If issue number is not a valid integer, show error and exit

2. **Find the worktree for this issue**
   ```bash
   git worktree list
   ```
   - Look for worktree path containing `issue-<number>` pattern
   - If no matching worktree found, show available worktrees and exit

3. **Verify changes have been accepted (PR merged)**

   This is a critical safety check to prevent losing work.

   ```bash
   # Check if there's a merged PR for this issue
   gh pr list --search "issue-<number> in:title" --state merged --json number,title,mergedAt
   ```

   **If PR is merged**:
   - Display: "PR #<number> was merged on <date>"
   - Proceed with cleanup

   **If PR is NOT merged**:
   - Check if PR exists but is still open:
     ```bash
     gh pr list --search "issue-<number> in:title" --state open --json number,title,url
     ```
   - Display warning:
     ```
     Warning: Changes have NOT been accepted yet!

     Open PR: #<pr-number> - <title>
     URL: <pr-url>

     Deleting this worktree will NOT lose committed changes (they're in the branch),
     but you won't be able to continue working on them easily.
     ```
   - Ask user:
     - Option 1: "Cancel - I'll close the worktree after PR is merged"
     - Option 2: "Continue anyway - I understand the PR is not merged"

   **If NO PR found at all**:
   - Display warning:
     ```
     Warning: No PR found for issue #<number>!

     This could mean:
     - The work was never pushed/PR was never created
     - The PR was closed without merging
     - The PR title doesn't contain the issue number
     ```
   - Ask user:
     - Option 1: "Cancel - let me check the worktree first"
     - Option 2: "Continue anyway - I want to discard this work"

4. **Check for uncommitted changes in worktree**
   ```bash
   git -C <worktree-path> status --porcelain
   ```
   - If there are uncommitted changes:
     ```
     Warning: Worktree has uncommitted changes that will be LOST:

       M  file1.go
       ?? file2.go
     ```
   - Ask user:
     - Option 1: "Cancel - let me commit or stash these changes first"
     - Option 2: "Continue - discard uncommitted changes"

5. **Check for unpushed commits**
   ```bash
   git -C <worktree-path> log @{u}..HEAD --oneline 2>/dev/null
   ```
   - If there are unpushed commits:
     ```
     Warning: Branch has unpushed commits:

       abc1234 Fix edge case in validation
       def5678 Add additional test
     ```
   - Ask user:
     - Option 1: "Cancel - let me push these commits first"
     - Option 2: "Continue - these commits will remain in local branch"

6. **Remove the worktree**
   ```bash
   git worktree remove <worktree-path>
   ```
   - If removal fails due to dirty state, ask about force:
     ```bash
     git worktree remove --force <worktree-path>
     ```

7. **Delete the branch (if merged)**
   ```bash
   git branch -d <branch-name>
   ```
   - `-d` only succeeds if branch is fully merged
   - If deletion fails (branch not merged), keep the branch:
     ```
     Note: Branch '<branch-name>' kept (not fully merged to main).
     To delete later: git branch -D <branch-name>
     ```

8. **Prune stale worktree references**
   ```bash
   git worktree prune
   ```

9. **Display summary**
   ```
   ================================================
   Worktree closed successfully!
   ================================================

   Removed worktree: <worktree-path>
   Deleted branch:   <branch-name>
   PR #<number> was merged

   Remaining worktrees:
     /path/to/repo  main

   ================================================
   ```

## Safety Checks Summary

The command performs these checks in order to prevent losing work:

| Check | What it prevents |
|-------|------------------|
| PR merged? | Closing before work is accepted |
| Uncommitted changes? | Losing local edits |
| Unpushed commits? | Losing commits not on remote |
| Branch merged? | Deleting branch with unmerged work |

## Related Commands

- `prepare-worktree` — create a worktree (Claude: `/prepare-worktree`; Codex: `$prepare-worktree`; Gemini: load the shared skill by name)
- `implement-issue` — implement the fix in the worktree (Claude: `/implement-issue`; Codex: `$implement-issue`; Gemini: load the shared skill by name)

## Complete Workflow

```bash
# Instance 1: Prepare worktree using the current provider's invocation syntax
<prepare-worktree invocation> 263
# Copies command to clipboard

# Instance 2: Start the current provider's CLI in the worktree
cd /path/to/repo-issue-263-... && <provider-cli>
<implement-issue invocation> 263
# Creates PR, gets merged

# Instance 1: Clean up after PR is merged using the current provider's syntax
<close-worktree invocation> 263
# Verifies PR merged, then removes worktree and branch
```

Use `claude` and `/skill-name` in Claude Code, `codex` and `$skill-name` in Codex, or the equivalent shared-skill invocation in Gemini. If no provider CLI is known, enter the worktree with `cd` and display the next instruction without inventing a command.
