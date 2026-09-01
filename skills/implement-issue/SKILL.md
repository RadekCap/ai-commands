---
name: implement-issue
description: Analyze a GitHub issue or JIRA ticket and create a pull request that implements the fix
---

# Implement Issue

Automatically analyze a GitHub issue or JIRA ticket, implement the required changes, and create a pull request with the fix.

## Usage

```
/implement-issue <issue-number-or-jira-key>
```

**Examples**:
- `/implement-issue 72` (GitHub issue)
- `/implement-issue ACM-12345` (JIRA ticket)

## Workflow

1. **Validate input and detect type**
   - If no argument provided, prompt user: "Please provide a GitHub issue number or JIRA key: /implement-issue <number-or-key>"
   - Detect input type:
     - **GitHub issue**: input is a plain integer (e.g., `72`)
     - **JIRA ticket**: input matches pattern `[A-Z]+-[0-9]+` (e.g., `ACM-12345`, `OCPBUGS-999`)
   - If input matches neither pattern, show error and exit

2a. **[GitHub] Fetch issue details from GitHub**
    - Only when input is a GitHub issue number
    ```bash
    gh issue view <issue-number>
    ```
    - If issue doesn't exist, show error and exit
    - If issue is closed, ask user if they still want to proceed
    - Display issue title, description, and labels for context

2b. **[JIRA] Fetch ticket details from JIRA**
    - Only when input is a JIRA key
    - Read `credentials.json` from the repo root for the Bearer token (field: `jira.token`)
    - Fetch ticket details:
      ```bash
      TOKEN=$(cat credentials.json | jq -r '.jira.token')
      curl -s -H "Authorization: Bearer $TOKEN" \
        "https://issues.redhat.com/rest/api/2/issue/$KEY?fields=summary,description,status,issuetype,priority,labels,components"
      ```
    - If credentials.json is missing or token is empty, show error: "Missing JIRA credentials. Ensure credentials.json exists at repo root with jira.token set."
    - If fetch fails (non-200 response), show error and exit
    - Display ticket summary, description, status, type, and priority for context

3. **Analyze the issue**
   - Read the issue description carefully
   - Identify what type of change is needed:
     - Bug fix
     - New feature
     - Test addition
     - Documentation update
     - Workflow/CI fix
     - Refactoring
   - Determine affected files by:
     - Reading issue description for file/path mentions
     - Searching codebase for relevant code patterns
     - Using Grep/Glob tools to find related files
   - Check CLAUDE.md for repository-specific patterns and guidelines
   - Create a mental implementation plan

4. **Check current git status**
   ```bash
   git status
   ```
   - If there are uncommitted changes, ask user:
     - "You have uncommitted changes. What would you like to do?"
       - Option 1: Stash changes and continue
       - Option 2: Commit changes first
       - Option 3: Cancel operation
   - Handle user's choice before proceeding

5. **Ensure main branch is up to date**
   ```bash
   git checkout main
   git pull origin main
   ```
   - If pull fails, explain error and exit

6. **Create feature branch**
   - Generate branch name from issue:
     - **GitHub**: Format: `fix-issue-<number>-<brief-description>` (e.g., `fix-issue-72-add-logging-function`)
     - **JIRA**: Format: `<JIRA-KEY>-<brief-description>` (e.g., `ACM-12345-fix-auth-timeout`). Keep the JIRA key as-is (uppercase), lowercase the description part.
     - Keep description under 50 chars, use kebab-case
   - Create and checkout branch:
     ```bash
     git checkout -b <branch-name>
     ```

7. **Use TodoWrite tool to create implementation plan**
   - Break down the implementation into specific tasks
   - Examples:
     - "Read current implementation of X"
     - "Create new function Y in file Z"
     - "Add tests for feature X"
     - "Update documentation"
     - "Run tests to verify changes"
     - "Commit changes"
     - "Create pull request"
   - Mark first task as in_progress

8. **Implement the fix**
   - Follow repository patterns from CLAUDE.md
   - Read existing code before making changes
   - Implement changes step-by-step, updating TodoWrite as you progress
   - For code changes:
     - Use Read tool to understand existing code
     - Use Edit/Write tools to make changes
     - Follow existing code style and patterns
     - Add comments where logic isn't self-evident

9. **Run relevant tests**
   - Determine which tests to run based on the project:
     - Check CLAUDE.md for test commands
     - Check package.json scripts, Makefile targets, or equivalent
     - Run project-specific test/lint/build commands
   - If tests fail:
     - Analyze failure
     - Fix implementation
     - Re-run tests
     - Repeat until tests pass

10. **Format code**
    - Run project-specific formatting command if available
    - Check CLAUDE.md for formatting guidelines

11. **Commit changes**
    - Create descriptive commit message:
      - **GitHub** format:
        ```
        <Brief summary> (fixes #<issue-number>)

        <Detailed description of what changed and why>

        Fixes #<issue-number>

        Generated with [Claude Code](https://claude.com/claude-code)

        Assisted-by: <current AI tool and model>
        ```
      - **JIRA** format:
        ```
        <Brief summary> (<JIRA-KEY>)

        <Detailed description of what changed and why>

        Ref: <JIRA-KEY>

        Generated with [Claude Code](https://claude.com/claude-code)

        Assisted-by: <current AI tool and model>
        ```
    - Commit using:
      ```bash
      git add .
      git commit -m "$(cat <<'EOF'
      <commit message here>
      EOF
      )"
      ```

12. **Push branch to remote**
    ```bash
    git push -u origin <branch-name>
    ```

13. **Create pull request**
    - Use `gh pr create` with detailed PR description
    - **GitHub**:
      - PR title: `<Brief summary> (fixes #<issue-number>)`
      - PR body should include:
        - ## Summary
        - ## Problem (reference original issue)
        - ## Solution
        - ## Changes
        - ## Testing
        - Fixes #<issue-number>
        - Generated with Claude Code
      - Example:
        ```bash
        gh pr create --title "Add logging function (fixes #72)" --body "$(cat <<'EOF'
        ## Summary
        Implements logging function as requested in #72

        ## Problem
        <Describe the problem from the issue>

        ## Solution
        <Describe how you fixed it>

        ## Changes
        - <Change 1>
        - <Change 2>

        ## Testing
        - [x] Tests pass
        - [x] Code formatted

        Fixes #72

        Generated with [Claude Code](https://claude.com/claude-code)
        EOF
        )"
        ```
    - **JIRA**:
      - PR title: `<Brief summary> (<JIRA-KEY>)`
      - PR body should include:
        - ## Summary
        - ## Problem (reference JIRA ticket)
        - ## Solution
        - ## Changes
        - ## Testing
        - Link to JIRA ticket
        - Generated with Claude Code
      - Example:
        ```bash
        gh pr create --title "Fix auth timeout (ACM-12345)" --body "$(cat <<'EOF'
        ## Summary
        Fixes authentication timeout as described in ACM-12345

        JIRA: https://redhat.atlassian.net/browse/ACM-12345

        ## Problem
        <Describe the problem from the JIRA ticket>

        ## Solution
        <Describe how you fixed it>

        ## Changes
        - <Change 1>
        - <Change 2>

        ## Testing
        - [x] Tests pass
        - [x] Code formatted

        Ref: ACM-12345

        Generated with [Claude Code](https://claude.com/claude-code)
        EOF
        )"
        ```

14. **[JIRA only] Add PR as web link on JIRA ticket**
    - **Skip this step entirely for GitHub issues**
    - After creating the PR, add it as a remote link (web link) on the JIRA ticket
    - Read credentials from `credentials.json` at the repo root
    - Use the Jira Remote Link API:
      ```bash
      EMAIL=$(jq -r '.jira.email' credentials.json)
      TOKEN=$(jq -r '.jira.token' credentials.json)
      PR_URL="<the PR URL from step 13>"
      PR_TITLE="<the PR title from step 13>"

      curl -s -w "\n%{http_code}" -u "$EMAIL:$TOKEN" \
        -H "Content-Type: application/json" \
        -X POST "https://redhat.atlassian.net/rest/api/2/issue/<JIRA-KEY>/remotelink" \
        -d "$(cat <<LINK_EOF
      {
        "object": {
          "url": "$PR_URL",
          "title": "$PR_TITLE",
          "icon": {
            "url16x16": "https://github.com/favicon.ico",
            "title": "GitHub Pull Request"
          }
        }
      }
      LINK_EOF
      )"
      ```
    - Verify the response (HTTP 201 = success)
    - If credentials are missing or the API call fails, log a warning but do not block the workflow

15. **[JIRA only] Mention the PR in the ticket Description with a link**
    - **Skip this step entirely for GitHub issues**
    - After adding the web link, also reference the PR from within the JIRA ticket's **Description** field so the PR is discoverable inline, not only via the remote-links panel
    - Read credentials from `credentials.json` at the repo root
    - Fetch the current description first, then append a PR reference — never overwrite existing content:
      ```bash
      EMAIL=$(jq -r '.jira.email' credentials.json)
      TOKEN=$(jq -r '.jira.token' credentials.json)
      PR_URL="<the PR URL from step 13>"

      # Fetch the current description (may be empty)
      CURRENT=$(curl -s -u "$EMAIL:$TOKEN" \
        "https://redhat.atlassian.net/rest/api/2/issue/<JIRA-KEY>?fields=description" \
        | jq -r '.fields.description // ""')

      # Skip if the PR link is already present (idempotent re-runs)
      if printf '%s' "$CURRENT" | grep -qF "$PR_URL"; then
        echo "PR link already present in description, skipping"
      else
        # Append a PR reference, preserving the existing description
        NEW_DESCRIPTION=$(printf '%s\n\n----\n*Pull Request:* %s' "$CURRENT" "$PR_URL")
        BODY=$(jq -n --arg d "$NEW_DESCRIPTION" '{fields: {description: $d}}')
        curl -s -w "\n%{http_code}" -u "$EMAIL:$TOKEN" \
          -H "Content-Type: application/json" \
          -X PUT "https://redhat.atlassian.net/rest/api/2/issue/<JIRA-KEY>" \
          -d "$BODY"
      fi
      ```
    - Verify the response (HTTP 204 = success)
    - This step **mutates** the JIRA ticket; obtain explicit user confirmation before running it, and preserve the original description content
    - If credentials are missing or the API call fails, log a warning but do not block the workflow

16. **[JIRA only] Transition ticket to Review**
    - **Skip this step entirely for GitHub issues**
    - After creating the PR and adding the web link, move the JIRA ticket to "Review" status
    - Read credentials from `credentials.json` at the repo root
    - First, fetch available transitions to find the correct transition ID:
      ```bash
      EMAIL=$(jq -r '.jira.email' credentials.json)
      TOKEN=$(jq -r '.jira.token' credentials.json)

      curl -s -u "$EMAIL:$TOKEN" \
        "https://redhat.atlassian.net/rest/api/2/issue/<JIRA-KEY>/transitions" | jq '.transitions[] | {id, name}'
      ```
    - Find the transition whose name contains "Review" (case-insensitive match)
    - Execute the transition:
      ```bash
      TRANSITION_ID="<id from above>"

      curl -s -w "\n%{http_code}" -u "$EMAIL:$TOKEN" \
        -H "Content-Type: application/json" \
        -X POST "https://redhat.atlassian.net/rest/api/2/issue/<JIRA-KEY>/transitions" \
        -d "{\"transition\": {\"id\": \"$TRANSITION_ID\"}}"
      ```
    - Verify the response (HTTP 204 = success)
    - If no "Review" transition is available (ticket may already be in Review, or the workflow doesn't have one), log a warning but do not block the workflow
    - If credentials are missing or the API call fails, log a warning but do not block the workflow

17. **[GitHub only] Post comment on the issue explaining the implementation**
    - **Skip this step entirely for JIRA tickets** (there is no GitHub issue to comment on)
    - After creating the PR, post a comment on the original GitHub issue
    - The comment should explain what was implemented, not just link to the PR
    - Use `gh issue comment <issue-number>` with a comprehensive explanation
    - Format:
      ```bash
      gh issue comment <issue-number> --body "$(cat <<'EOF'
      ## Implementation Complete

      I've implemented a fix for this issue. Here's what was done:

      ### Solution
      <Brief explanation of the approach taken>

      ### Key Changes
      - <Important change 1>
      - <Important change 2>

      ### Files Modified
      - `<file1>` - <what changed>
      - `<file2>` - <what changed>

      ### Testing
      - <Test result 1>
      - <Test result 2>

      ### Pull Request
      The full implementation details are available in PR #<pr-number>

      Automated implementation via [Claude Code](https://claude.com/claude-code)
      EOF
      )"
      ```

18. **Provide summary to user**
    - Display PR URL
    - **GitHub**: Display issue comment confirmation and link to issue
    - **JIRA**: Display link to JIRA ticket (`https://redhat.atlassian.net/browse/<JIRA-KEY>`), confirm web link was added, confirm the PR was referenced in the description, and confirm ticket was moved to Review
    - List files changed
    - Show test results
    - Remind user that CI will run automatically

## Important Guidelines

### Code Quality
- **Read before writing**: Always use Read tool to understand existing code before making changes
- **Follow patterns**: Adhere to CLAUDE.md guidelines and existing code patterns
- **Test coverage**: Add tests for new functionality when appropriate
- **No over-engineering**: Only implement what's requested in the issue
- **Security**: Check for common vulnerabilities (SQL injection, XSS, command injection, etc.)

### Git Best Practices
- **Branch naming**:
  - GitHub: `fix-issue-<number>-<brief-description>` or `feature-issue-<number>-<brief-description>`
  - JIRA: `<JIRA-KEY>-<brief-description>`
- **Commit messages**: Descriptive, reference issue number or JIRA key
- **One issue per PR**: Don't mix multiple unrelated changes

### Testing Requirements
- Run tests before committing (use project-specific commands)
- Ensure all existing tests still pass
- Add new tests for new functionality when appropriate

## Error Handling

### Issue Not Found
```
Error: Issue #<number> not found
Please check the issue number and try again
```

### JIRA Ticket Not Found
```
Error: JIRA ticket <KEY> not found or inaccessible
Check that the key is correct and your credentials.json has a valid jira.token
```

### JIRA Credentials Missing
```
Error: Missing JIRA credentials
Ensure credentials.json exists at the repo root with the structure: {"jira": {"token": "..."}}
```

### Tests Fail
- Show test output
- Ask user: "Tests are failing. Would you like to:"
  - Option 1: Let me fix the issue
  - Option 2: Skip tests and commit anyway (not recommended)
  - Option 3: Cancel operation

### Git Conflicts
- Explain conflict
- Provide resolution commands
- Ask user how to proceed

### Uncommitted Changes
- Detect uncommitted changes before starting
- Offer to stash, commit, or cancel
- Never proceed without handling changes

## Post-Implementation Checklist

After completing implementation, verify:
- [ ] Issue/ticket requirements fully addressed
- [ ] Code follows repository patterns (CLAUDE.md)
- [ ] Tests pass (or explanation if no tests needed)
- [ ] Code formatted per project conventions
- [ ] Commit message references issue number or JIRA key
- [ ] PR description includes "Fixes #<issue-number>" (GitHub) or JIRA link (JIRA)
- [ ] Branch pushed to remote
- [ ] PR created successfully
- [ ] [JIRA only] PR added as web link on JIRA ticket
- [ ] [JIRA only] PR referenced in the ticket Description with a link
- [ ] [JIRA only] Ticket transitioned to Review
- [ ] [GitHub only] Issue comment posted explaining the implementation

## Tips for Success

1. **Read the issue carefully**: Understand exactly what's being asked before starting
2. **Check CLAUDE.md**: Follow project-specific patterns and conventions
3. **Follow existing patterns**: Consistency is key
4. **Test thoroughly**: Don't skip tests
5. **Ask for clarification**: If issue is ambiguous, use AskUserQuestion to clarify with user
6. **Keep it focused**: Only implement what the issue requests, nothing more
