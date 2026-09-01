---
name: fix-issue
description: Full lifecycle - create worktree, implement issue, create PR, switch back - all in one session
---

# Fix Issue

End-to-end workflow: create an isolated worktree, implement a GitHub issue or JIRA ticket, create a pull request, and return to the original directory. All within a single AI coding session.

## Usage

```
/fix-issue <issue-number-or-jira-key-or-url>
```

**Examples**:
- `/fix-issue 72` (GitHub issue)
- `/fix-issue ARO-27154` (JIRA ticket)
- `/fix-issue https://redhat.atlassian.net/browse/ARO-27154` (JIRA URL)
- `/fix-issue https://issues.redhat.com/browse/ACM-12345` (JIRA URL, legacy)
- `/fix-issue https://github.com/org/repo/issues/72` (GitHub URL)

## Workflow

### Phase 1: Parse Input

1. **Validate and parse argument**
   - If no argument provided, prompt user: "Please provide a GitHub issue number, JIRA key, or URL: /fix-issue <input>"
   - Parse input type:
     - **URL with `/browse/`**: extract JIRA key from last path segment (e.g., `https://redhat.atlassian.net/browse/ARO-27154` → `ARO-27154`)
     - **URL with `/issues/`**: extract GitHub issue number from last path segment (e.g., `https://github.com/org/repo/issues/72` → `72`)
     - **Pattern `[A-Z]+-[0-9]+`**: JIRA key (e.g., `ARO-27154`)
     - **Plain integer**: GitHub issue number (e.g., `72`)
   - If input matches none of these patterns, show error and exit

### Phase 2: Fetch Issue Details

2a. **[GitHub] Fetch issue details**
    - Only when input resolved to a GitHub issue number
    ```bash
    gh issue view <issue-number>
    ```
    - If issue doesn't exist, show error and exit
    - If issue is closed, ask user if they still want to proceed
    - Extract issue title for branch naming

2b. **[JIRA] Fetch ticket details**
    - Only when input resolved to a JIRA key
    - Read credentials from `~/.claude/credentials.json` (fields: `jira.email`, `jira.token`)
    - Fetch ticket details using Basic auth (`-u email:token`):
      ```bash
      EMAIL=$(cat ~/.claude/credentials.json | jq -r '.jira.email')
      TOKEN=$(cat ~/.claude/credentials.json | jq -r '.jira.token')
      curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
        "https://redhat.atlassian.net/rest/api/3/issue/$KEY?fields=summary,description,status,issuetype,priority,labels,components"
      ```
    - If credentials.json is missing or token is empty, show error and exit
    - If fetch fails, show error and exit
    - Extract ticket summary for branch naming

### Phase 3: Create Worktree

3. **Get repository name**
   ```bash
   REPO_NAME=$(basename $(git rev-parse --show-toplevel))
   ```

4. **Generate branch and worktree names**
   - Create a slug from the issue/ticket title:
     - Convert to lowercase
     - Replace spaces and special characters with hyphens
     - Remove consecutive hyphens
     - Truncate to keep total branch name under 50 chars
   - **GitHub**: Branch `issue-<number>-<slug>`, worktree `../${REPO_NAME}-issue-<number>-<slug>`
   - **JIRA**: Branch `<JIRA-KEY>-<slug>` (key uppercase), worktree `../${REPO_NAME}-<JIRA-KEY>-<slug>`

5. **Check for existing worktree or branch**
   ```bash
   git worktree list
   git branch --list <branch-name>
   ```
   - If worktree already exists, ask user:
     - Option 1: Enter existing worktree and continue implementation
     - Option 2: Remove and recreate from scratch
     - Option 3: Cancel
   - If branch exists but no worktree, ask user:
     - Option 1: Create worktree from existing branch
     - Option 2: Delete branch and start fresh
     - Option 3: Cancel

6. **Ensure main branch is up to date**
   ```bash
   git fetch origin main
   ```

7. **Create the worktree**
   ```bash
   git worktree add <worktree-path> -b <branch-name> origin/main
   ```

8. **Initialize submodules in the worktree**
   ```bash
   git -C <worktree-path> submodule update --init
   ```

### Phase 4: Switch Into Worktree

9. **Enter the worktree using EnterWorktree tool**
   - Use the `EnterWorktree` tool with the `path` parameter set to the worktree path
   - This switches the current AI coding session into the worktree directory
   - All subsequent file operations will happen in the worktree

10. **Display progress banner**
    ```
    ================================================
    Entered worktree for implementation
    ================================================

    Issue:     <identifier> - <title>
    Branch:    <branch-name>
    Directory: <worktree-path>

    Starting implementation...
    ================================================
    ```

### Phase 5: Implement the Fix

11. **Analyze the issue**
    - Read the issue description carefully
    - Identify what type of change is needed (bug fix, feature, test, CI, docs, refactoring)
    - Determine affected files by:
      - Reading issue description for file/path mentions
      - Searching codebase for relevant code patterns
      - Using Grep/Glob tools to find related files
    - Check CLAUDE.md for repository-specific patterns and guidelines

12. **Create implementation plan using TaskCreate**
    - Break down the implementation into specific tasks
    - Mark first task as in_progress

13. **Implement changes**
    - Follow repository patterns from CLAUDE.md
    - Read existing code before making changes
    - Implement step-by-step, updating tasks as you progress
    - Follow existing code style and patterns

14. **Run relevant tests**
    - Check CLAUDE.md for test commands
    - Check Makefile targets, package.json scripts, or equivalent
    - Run project-specific test/lint/build commands
    - If tests fail: analyze, fix, re-run until passing

15. **Format code**
    - Run project-specific formatting command if available

### Phase 6: Commit, Push, and Create PR

16. **Commit changes**
    - **GitHub** commit message format:
      ```
      <Brief summary> (fixes #<issue-number>)

      <Detailed description>

      Fixes #<issue-number>

      Generated with [Claude Code](https://claude.com/claude-code)

      Assisted-by: <current AI tool and model>
      ```
    - **JIRA** commit message format:
      ```
      <Brief summary> (<JIRA-KEY>)

      <Detailed description>

      Ref: <JIRA-KEY>

      Generated with [Claude Code](https://claude.com/claude-code)

      Assisted-by: <current AI tool and model>
      ```
    - Stage and commit:
      ```bash
      git add .
      git commit -m "$(cat <<'EOF'
      <commit message here>
      EOF
      )"
      ```

17. **Push branch**
    ```bash
    git push -u origin <branch-name>
    ```

18. **Create pull request**
    - **GitHub**:
      ```bash
      gh pr create --title "<Brief summary> (fixes #<issue-number>)" --body "$(cat <<'EOF'
      ## Summary
      <description>

      ## Problem
      <from issue>

      ## Solution
      <approach>

      ## Changes
      - <change 1>
      - <change 2>

      ## Testing
      - [x] Tests pass
      - [x] Code formatted

      Fixes #<issue-number>

      Generated with [Claude Code](https://claude.com/claude-code)
      EOF
      )"
      ```
    - **JIRA**:
      ```bash
      gh pr create --title "<Brief summary> (<JIRA-KEY>)" --body "$(cat <<'EOF'
      ## Summary
      <description>

      JIRA: https://issues.redhat.com/browse/<JIRA-KEY>

      ## Problem
      <from ticket>

      ## Solution
      <approach>

      ## Changes
      - <change 1>
      - <change 2>

      ## Testing
      - [x] Tests pass
      - [x] Code formatted

      Ref: <JIRA-KEY>

      Generated with [Claude Code](https://claude.com/claude-code)
      EOF
      )"
      ```

19. **Update the source issue/ticket with PR link**

    - **GitHub**: Post a comment on the issue with the PR link
      ```bash
      gh issue comment <issue-number> --body "PR created: <pr-url>

      <brief summary of changes>"
      ```

    - **JIRA**: Post a comment AND add the PR as a web link
      - Read credentials from `~/.claude/credentials.json` (same as Phase 2)
      - Post comment:
        ```bash
        EMAIL=$(cat ~/.claude/credentials.json | jq -r '.jira.email')
        TOKEN=$(cat ~/.claude/credentials.json | jq -r '.jira.token')
        curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
          -X POST "https://redhat.atlassian.net/rest/api/3/issue/<JIRA-KEY>/comment" \
          -d '{
            "body": {
              "type": "doc",
              "version": 1,
              "content": [
                {
                  "type": "paragraph",
                  "content": [
                    {"type": "text", "text": "PR created: "},
                    {"type": "text", "text": "<repo>#<pr-number>", "marks": [{"type": "link", "attrs": {"href": "<pr-url>"}}]}
                  ]
                },
                {
                  "type": "paragraph",
                  "content": [
                    {"type": "text", "text": "<brief summary of changes>"}
                  ]
                }
              ]
            }
          }'
        ```
      - Add PR as web link (remote link):
        ```bash
        curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
          -X POST "https://redhat.atlassian.net/rest/api/3/issue/<JIRA-KEY>/remotelink" \
          -d '{
            "object": {
              "url": "<pr-url>",
              "title": "PR #<number>: <pr-title>",
              "icon": {
                "url16x16": "https://github.com/favicon.ico",
                "title": "GitHub"
              }
            }
          }'
        ```
      - If either call fails, warn but continue (don't block the workflow)

### Phase 7: Switch Back

20. **Exit the worktree using ExitWorktree tool**
    - Use `ExitWorktree` with `action: "keep"`
    - The worktree stays on disk for future reference or follow-up work
    - Session returns to the original directory

21. **Display completion summary**
    ```
    ================================================
    Issue fixed successfully!
    ================================================

    Issue:     <identifier> - <title>
    PR:        <pr-url>
    Branch:    <branch-name>
    Worktree:  <worktree-path> (kept on disk)

    ------------------------------------------------
    After PR is merged, clean up with:
    ------------------------------------------------

    /close-worktree <issue-number>

    ================================================
    ```

## Error Handling

### Issue/Ticket Not Found
```
Error: <identifier> not found
Please check the issue number/key and try again
```

### Invalid URL
```
Error: Could not parse URL: <url>
Expected formats:
  - GitHub: https://github.com/org/repo/issues/<number>
  - JIRA:   https://redhat.atlassian.net/browse/<KEY>
  - JIRA:   https://issues.redhat.com/browse/<KEY>
```

### JIRA Credentials Missing
```
Error: Missing JIRA credentials
Ensure ~/.claude/credentials.json exists with: {"jira": {"email": "...", "token": "..."}}
```

### Worktree Creation Fails
- Show the error message
- Common issues: branch already checked out, dirty state
- Provide resolution steps

### Tests Fail
- Show test output
- Ask user:
  - Option 1: Let me fix the issue
  - Option 2: Skip tests and commit anyway (not recommended)
  - Option 3: Cancel and exit worktree

### PR Creation Fails
- Show the error
- The worktree and branch remain intact
- User can fix manually and push

### Any Unrecoverable Error
- Always exit the worktree before stopping (use `ExitWorktree` with `action: "keep"`)
- Display what was completed and what remains
- The worktree is preserved so no work is lost

## Related Commands

- `/prepare-worktree` — create worktree only (for parallel work or manual flow)
- `/implement-issue` — implement only (when already in the right directory)
- `/close-worktree` — clean up worktree after PR is merged

## Tips

1. **One command**: `/fix-issue` replaces the manual `/prepare-worktree` + new terminal + `/implement-issue` flow
2. **Worktree preserved**: After PR creation, the worktree stays on disk for follow-up
3. **Clean up after merge**: Use `/close-worktree` once the PR is merged
4. **Existing skills still work**: Use `/prepare-worktree` or `/implement-issue` independently when needed
