---
name: prepare-worktree
description: Create a git worktree for implementing a GitHub issue in an isolated directory
---

# Prepare Worktree

Create a git worktree for a GitHub issue, allowing you to implement the fix in an isolated directory while keeping your current work untouched.

## Usage

```
/prepare-worktree <issue-number>
```

**Example**: `/prepare-worktree 263`

## Workflow

1. **Validate issue number argument**
   - If no issue number provided, prompt user: "Please provide an issue number: /prepare-worktree <number>"
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
   - This ensures `.claude/commands` and other submodules are available

9. **Copy command to clipboard**
   - Linux (X11): `echo "cd <full-worktree-path> && claude" | xclip -selection clipboard`
   - Linux (Wayland): `echo "cd <full-worktree-path> && claude" | wl-copy`
   - macOS: `echo "cd <full-worktree-path> && claude" | pbcopy`

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

   cd <full-worktree-path> && claude

   ------------------------------------------------
   Then run:
   ------------------------------------------------

   /implement-issue <issue-number>

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
  cd <full-worktree-path> && claude
  /implement-issue <number>

To remove and recreate:
  git worktree remove <worktree-path>
  /prepare-worktree <number>
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

**Tip**: Use `/close-worktree` command to interactively clean up worktrees.

## Integration with /implement-issue

This command is designed to work seamlessly with `/implement-issue`:

1. `/prepare-worktree <number>` - Creates isolated environment
2. Open new terminal, paste command from clipboard
3. `/implement-issue <number>` - Implements the fix

The `/implement-issue` command will detect it's in a worktree and skip the branch creation step since the branch already exists.

## Tips

1. **Use for parallel work**: Create multiple worktrees for different issues
2. **Keep main clean**: Your main worktree stays on main branch
3. **List worktrees**: `git worktree list` shows all active worktrees
4. **Clean up regularly**: Remove worktrees after PRs are merged
5. **Naming convention**: Worktree directories are siblings to your main repo
