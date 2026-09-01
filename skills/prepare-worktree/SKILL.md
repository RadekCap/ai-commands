---
name: prepare-worktree
description: Create a git worktree for implementing a GitHub issue in an isolated directory
---

# Prepare Worktree

Create a git worktree for a GitHub issue, allowing you to implement the fix in an isolated directory while keeping your current work untouched.

## Usage

```
Claude Code: /prepare-worktree <issue-number>
Codex:      $prepare-worktree <issue-number>
```

**Example**: `/prepare-worktree 263` in Claude Code or `$prepare-worktree 263` in Codex

## Workflow

1. **Validate issue number argument**
   - If no issue number is provided, ask the user for one using the current tool's supported interaction method
   - If issue number is not a valid integer, show error and exit

2. **Fetch issue details from GitHub**
   ```bash
   gh issue view <issue-number>
   ```
   - If issue doesn't exist, show error and exit
   - Extract issue title for branch naming

3. **Get repository name for worktree directory**
   ```bash
   REPO_NAME=$(basename $(git rev-parse --show-toplevel))
   ```

4. **Generate branch and worktree names**
   - Create a slug from the issue title:
     - Convert to lowercase
     - Replace spaces and special characters with hyphens
     - Remove consecutive hyphens
     - Truncate to keep total branch name under 50 chars
   - Branch name format: `issue-<number>-<slug>`
   - Worktree directory: `../${REPO_NAME}-issue-<number>-<slug>`

   **Example**:
   - Issue #263: "Add non-interactive mode for make clean"
   - Branch: `issue-263-add-non-interactive-mode`
   - Worktree: `../MyProject-issue-263-add-non-interactive-mode`

5. **Check for existing worktree or branch**
   ```bash
   git worktree list
   git branch --list <branch-name>
   ```
   - If worktree already exists, inform user and provide the cd command
   - If branch exists but no worktree, ask user:
     - Option 1: Create worktree from existing branch
     - Option 2: Delete branch and start fresh
     - Option 3: Cancel

6. **Ensure main branch is up to date**
   ```bash
   git fetch origin main
   ```

7. **Create the worktree with new branch**
   ```bash
   git worktree add <worktree-path> -b <branch-name> origin/main
   ```
   - This creates the worktree AND the branch in one command
   - Branch is based on latest origin/main

8. **Initialize submodules in the worktree**
   ```bash
   git -C <worktree-path> submodule update --init
   ```
   - Worktrees don't automatically initialize submodules
   - This initializes all repository submodules required by the worktree; shared global skills do not depend on a repository-local Claude commands path

9. **Prepare and optionally copy the session command**
   - Select the CLI from the current runtime: `claude` for Claude Code, `codex` for Codex, or `gemini` for Gemini
   - If the runtime or matching CLI cannot be determined, use only `cd <full-worktree-path>`
   - Build the command as `cd <full-worktree-path> && <provider-cli>` when a CLI is known
   - Copy it with an available clipboard utility: `xclip -selection clipboard` on X11, `wl-copy` on Wayland, or `pbcopy` on macOS
   - If no clipboard utility is available, display the command and continue without treating this as an error

10. **Display next steps**
   Print clear instructions:
   ```
   ================================================
   Worktree created successfully!
   ================================================

   Issue:     #<number> - <title>
   Branch:    <branch-name>
   Directory: <worktree-path>

   ------------------------------------------------
   Next steps (copied to clipboard):
   ------------------------------------------------

   <provider-specific session command>

   ------------------------------------------------
   Then run:
   ------------------------------------------------

   Claude Code: /implement-issue <issue-number>
   Codex:      $implement-issue <issue-number>
   Gemini:     load the shared implement-issue skill by name

   ================================================
   ```

## Error Handling

### Issue Not Found
```
Error: Issue #<number> not found
Please check the issue number and try again
```

### Worktree Already Exists
```
Worktree for issue #<number> already exists at:
  <worktree-path>

To use it, run:
  <provider-specific session command>
  <provider-specific implement-issue invocation>

To remove and recreate:
  git worktree remove <worktree-path>
  <provider-specific prepare-worktree invocation>
```

### Branch Already Exists (No Worktree)
Ask user how to proceed:
- Option 1: Create worktree from existing branch
- Option 2: Delete branch and start fresh
- Option 3: Cancel

### Git Worktree Command Fails
- Show the error message
- Common issues:
  - Uncommitted changes in target branch
  - Branch already checked out elsewhere
- Provide resolution steps

## Cleanup

After the PR is merged, clean up the worktree:

```bash
# Remove the worktree
git worktree remove ../<repo>-issue-<number>-<slug>

# Or if you also want to delete the branch
git worktree remove ../<repo>-issue-<number>-<slug>
git branch -d issue-<number>-<slug>

# Clean up stale worktree references
git worktree prune
```

**Tip**: Use the shared `close-worktree` skill to clean up worktrees (`/close-worktree` in Claude Code or `$close-worktree` in Codex).

## Integration with implement-issue

This skill is designed to work seamlessly with the shared `implement-issue` skill:

1. Invoke `prepare-worktree` using the current provider's syntax to create the isolated environment
2. Open new terminal, paste command from clipboard
3. Invoke `implement-issue` using the current provider's syntax to implement the fix

The `implement-issue` skill will detect that it is in a worktree and skip branch creation because the branch already exists.

## Tips

1. **Use for parallel work**: Create multiple worktrees for different issues
2. **Keep main clean**: Your main worktree stays on main branch
3. **List worktrees**: `git worktree list` shows all active worktrees
4. **Clean up regularly**: Remove worktrees after PRs are merged
5. **Naming convention**: Worktree directories are siblings to your main repo
