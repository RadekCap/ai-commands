---
name: ai-review
description: Full pipeline - self-review, security review, wait for AI reviewers (CodeRabbit, Qodo), process all findings with individual commits
---

# AI Review Pipeline

Full pipeline command that runs AI self-review, security review, waits for AI code reviewers (CodeRabbit and Qodo), and processes all findings - accepting or denying each one with individual commits per fix. Every finding gets a reply and is resolved.

Supersedes the former `/coderabbit-review` command.

## Usage

```
/ai-review [pr-number-or-url]
```

- **PR URL** (any repo): `/ai-review https://github.com/stolostron/azure-service-operator/pull/379`
- **PR number** (current repo): `/ai-review 42`
- **No argument**: auto-detect PR for the current branch

Renames this chat session to `#<number> · <PR title>` (truncated to 200 characters) before starting the pipeline.

**Examples**: `/ai-review 42`, `/ai-review https://github.com/org/repo/pull/123`, or `/ai-review`

## Instructions

**Scope for all steps:** After Step 1, `OWNER`, `REPO`, `PR_NUMBER`, and `PR_REF` are set. Export `GH_REPO="${OWNER}/${REPO}"` so every `gh pr …` and `gh api repos/$OWNER/$REPO/…` command targets the PR's repository (required when the workspace checkout is a different repo).

### Step 1: Determine PR and Repository Context

1. **Parse input** (`PR_INPUT` = trimmed arguments supplied with the skill invocation):
   - **GitHub PR URL** — matches `https://github.com/<owner>/<repo>/pull/<number>` (optional trailing slash or fragment):
     ```bash
     PR_REF="$PR_INPUT"
     PR_META=$(gh pr view "$PR_REF" --json number,title,state,baseRepository)
     PR_NUMBER=$(echo "$PR_META" | jq -r '.number')
     PR_TITLE=$(echo "$PR_META" | jq -r '.title')
     OWNER=$(echo "$PR_META" | jq -r '.baseRepository.owner.login')
     REPO=$(echo "$PR_META" | jq -r '.baseRepository.name')
     export GH_REPO="${OWNER}/${REPO}"
     ```
   - **PR number only** (digits) — use the current repository:
     ```bash
     REPO_INFO=$(gh repo view --json owner,name)
     OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
     REPO=$(echo "$REPO_INFO" | jq -r '.name')
     export GH_REPO="${OWNER}/${REPO}"
     PR_NUMBER="$PR_INPUT"
     PR_REF="$PR_NUMBER"
     PR_TITLE=$(gh pr view "$PR_REF" --json title -q '.title')
     ```
   - **No argument** — auto-detect from the current branch in the current repo:
     ```bash
     REPO_INFO=$(gh repo view --json owner,name)
     OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
     REPO=$(echo "$REPO_INFO" | jq -r '.name')
     export GH_REPO="${OWNER}/${REPO}"
     PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null) || true
     ```
     If `PR_NUMBER` is empty, ask the user:
     - Option 1: Create a new PR (follow `.github/PULL_REQUEST_TEMPLATE.md`)
     - Option 2: Provide a PR number or URL manually
     - Option 3: Cancel
     If creating a PR, push the current branch first if needed, then create the PR.
     Once `PR_NUMBER` is known: `PR_REF="$PR_NUMBER"` and `PR_TITLE=$(gh pr view "$PR_REF" --json title -q '.title')`.

2. **Rename this chat session** (Cursor / Agents Window with app control):
   - Build title: `#${PR_NUMBER} · ${PR_TITLE}`
   - Truncate to **200 characters** (rename limit).
   - Call the rename-chat action on the **current conversation** with that title.
   - If rename is unavailable (e.g. cloud automation run without IDE control), log the intended title and continue.

3. **Verify PR exists and is open:**
   ```bash
   PR_STATE=$(gh pr view "$PR_REF" --json state -q '.state')
   ```
   - If not OPEN, warn and ask if user wants to proceed

4. **Display context:**
   ```
   Repository: $OWNER/$REPO
   Pull Request: #$PR_NUMBER
   Title: $PR_TITLE
   Branch: <current branch if applicable>
   ```

### Step 2: Self-Review

Before external AI reviews, run Claude Code's own code review to catch issues early.

1. **Get the PR diff**:
   ```bash
   gh pr diff "$PR_NUMBER"
   ```

2. **Run self-review** using the `pr-review-toolkit:code-reviewer` agent:
   - Use the Agent tool to launch the `pr-review-toolkit:code-reviewer` agent
   - Provide the diff context for review
   - The agent checks for: code quality, security, pattern compliance (CLAUDE.md), test coverage

3. **Implement self-review fixes**:
   - For each issue found:
     - Read the affected file and understand the context
     - Implement the fix
     - Stage specific files: `git add <file1> <file2>`
     - Commit with descriptive message:
       ```bash
       git commit -m "$(cat <<'EOF'
       fix: <description of self-review fix>

       Self-review finding addressed before external review.

       Assisted-by: <current AI tool and model>
       EOF
       )"
       ```
   - Push all self-review fixes:
     ```bash
     git push
     ```

4. **If no issues found**, skip to Step 2b:
   ```
   Self-review: No issues found. Proceeding to security review.
   ```

### Step 2b: Security Review

After self-review fixes are committed and pushed, run a security-focused review to catch vulnerabilities before external AI reviewers see the code.

1. **Invoke the `/security-review` skill**:
   - Use the Skill tool to invoke `security-review`
   - This performs a comprehensive security review of the pending changes on the current branch
   - It checks for: command injection, credential exposure, path traversal, insecure defaults, OWASP top 10 issues, and other security vulnerabilities

2. **Implement security fixes**:
   - For each security issue found:
     - Read the affected file and understand the vulnerability
     - Implement the fix
     - Stage specific files: `git add <file1> <file2>`
     - Commit with descriptive message:
       ```bash
       git commit -m "$(cat <<'EOF'
       fix: address security finding - <description of fix>

       Security review finding addressed before external review.

       Assisted-by: <current AI tool and model>
       EOF
       )"
       ```
   - Push all security fixes:
     ```bash
     git push
     ```

3. **If no security issues found**, skip to Step 3:
   ```
   Security review: No issues found. Proceeding to wait for AI reviewers.
   ```

### Steps 3-6: CodeRabbit Review Loop

Steps 3 through 6 run in a **repeat loop**. Each time fixes are pushed (accepted findings), CodeRabbit may re-review and find new issues. The loop continues until CodeRabbit has zero new unresolved findings.

**Loop variables**:
- `ROUND=1` - current iteration number
- `MAX_ROUNDS=5` - safety limit to prevent infinite loops
- `ANY_ACCEPTED=false` - tracks if any findings were accepted in the current round

### Step 3: Wait for CodeRabbit Review

After pushing changes, CodeRabbit automatically triggers a review. Poll until it completes.

**On round 1**: Poll for CodeRabbit's initial review (may take longer).
**On round 2+**: Poll for CodeRabbit's incremental re-review (triggered by pushed fixes).

**IMPORTANT**: CodeRabbit posts in stages — first an "in progress" placeholder, then the completed summary, then inline review threads asynchronously. You must wait for ALL stages to finish before fetching findings.

1. **Poll for CodeRabbit's COMPLETED review** (not just any comment):

   ```bash
   MAX_ATTEMPTS=30
   POLL_INTERVAL=30
   ATTEMPT=0

   while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
     ATTEMPT=$((ATTEMPT + 1))
     echo "Polling for completed CodeRabbit review... (attempt $ATTEMPT/$MAX_ATTEMPTS)"

     # Fetch the latest CodeRabbit comment body
     CR_BODY=$(gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
       --jq '[.[] | select(.user.login == "coderabbitai[bot]" or .user.login == "coderabbitai")] | .[-1].body // ""')

     # Check for COMPLETED review markers (not just "in progress" placeholder)
     # A completed review contains "Walkthrough" or "actionable comments" or "No issues found"
     if echo "$CR_BODY" | grep -qE "Walkthrough|actionable comments|No issues found|Files ignored|Changes approved"; then
       echo "CodeRabbit review completed!"
       break
     fi

     if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
       echo "WARNING: CodeRabbit review not completed after $((MAX_ATTEMPTS * POLL_INTERVAL / 60)) minutes."
       echo "Proceeding to check for any existing review threads anyway."
       break
     fi

     echo "Review not yet completed. Waiting ${POLL_INTERVAL}s..."
     sleep $POLL_INTERVAL
   done
   ```

2. **Wait for thread posting to stabilize** (CodeRabbit posts inline threads AFTER the summary):

   CodeRabbit posts its summary comment first, then creates individual review threads asynchronously. A static wait is unreliable. Instead, poll until the thread count stabilizes.

   ```bash
   echo "Waiting for CodeRabbit to finish posting review threads..."
   PREV_THREAD_COUNT=-1
   STABLE_CHECKS=0
   REQUIRED_STABLE=2

   for i in $(seq 1 10); do
     sleep 10

     # Count current CodeRabbit review threads
     CURRENT_THREAD_COUNT=$(gh api graphql -f query="<thread query>" \
       -F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER" \
       | <filter for CodeRabbit threads> | <count>)

     if [ "$CURRENT_THREAD_COUNT" -eq "$PREV_THREAD_COUNT" ]; then
       STABLE_CHECKS=$((STABLE_CHECKS + 1))
       echo "Thread count stable at $CURRENT_THREAD_COUNT ($STABLE_CHECKS/$REQUIRED_STABLE)"
       if [ "$STABLE_CHECKS" -ge "$REQUIRED_STABLE" ]; then
         echo "Thread count stabilized. Proceeding."
         break
       fi
     else
       STABLE_CHECKS=0
       echo "Thread count changed: $PREV_THREAD_COUNT -> $CURRENT_THREAD_COUNT"
     fi

     PREV_THREAD_COUNT=$CURRENT_THREAD_COUNT
   done
   ```

   **Why this works**: Instead of guessing with a fixed sleep, we check the thread count every 10 seconds. When it stays the same for 2 consecutive checks (20 seconds of stability), we know CodeRabbit is done posting. This handles both fast reviews (0 threads, stabilizes immediately) and large reviews (many threads, waits as long as needed).

### Step 4: Fetch and Filter CodeRabbit Findings

1. **Fetch all review threads** via GraphQL:
   ```bash
   THREADS_JSON=$(gh api graphql -f query='
     query($owner: String!, $repo: String!, $pr: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $pr) {
           reviewThreads(first: 100) {
             nodes {
               id
               isResolved
               comments(first: 50) {
                 nodes {
                   id
                   databaseId
                   body
                   author { login }
                   path
                   line
                   startLine
                 }
                 pageInfo {
                   hasNextPage
                   endCursor
                 }
               }
             }
             pageInfo {
               hasNextPage
               endCursor
             }
           }
         }
       }
     }
   ' -F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER")
   ```

   **Note**: The `startLine` field is included for multi-line suggestion support.

2. **Check pagination warnings**:
   ```bash
   THREADS_HAS_NEXT=$(echo "$THREADS_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
   if [ "$THREADS_HAS_NEXT" = "true" ]; then
     echo "WARNING: More than 100 review threads exist. Only the first 100 were fetched."
   fi

   COMMENTS_OVER_LIMIT=$(echo "$THREADS_JSON" | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.pageInfo.hasNextPage == true)] | length')
   if [ "$COMMENTS_OVER_LIMIT" -gt 0 ]; then
     echo "WARNING: One or more threads have more than 50 comments. Some findings may be missing."
   fi
   ```

3. **Filter for CodeRabbit threads only**:
   ```bash
   CR_THREADS=$(echo "$THREADS_JSON" | jq '[
     .data.repository.pullRequest.reviewThreads.nodes[] |
     select(.comments.nodes | length > 0) |
     select((.comments.nodes[0].author.login // "") | test("coderabbitai"; "i"))
   ]')
   ```

4. **Exclude walkthrough/summary threads** (not actionable findings):
   ```bash
   CR_FINDINGS=$(echo "$CR_THREADS" | jq '[
     .[] |
     select(
       (.comments.nodes[0].body | test("^## Walkthrough"; "m") | not) and
       (.comments.nodes[0].body | test("^## Summary"; "m") | not)
     )
   ]')
   ```

5. **Filter to unresolved findings only** (skip threads resolved in prior rounds):
   ```bash
   CR_UNRESOLVED=$(echo "$CR_FINDINGS" | jq '[.[] | select(.isResolved == false)]')
   TOTAL_FINDINGS=$(echo "$CR_UNRESOLVED" | jq 'length')
   echo "Round $ROUND: Found $TOTAL_FINDINGS unresolved CodeRabbit findings"
   ```

6. **If zero unresolved findings**: CodeRabbit has no more issues - proceed to Step 4b to check pre-merge checks, then to Step 7 (summary).

### Step 4b: Check Pre-merge Checks

CodeRabbit posts pre-merge check results (e.g., "Linked Issues", "Description Check", "Title check") in its main PR comment body. Failed checks are marked with `❌` and are NOT captured by the review thread query in Step 4. This step parses those checks separately.

1. **Fetch CodeRabbit's main PR comment body**:
   ```bash
   CR_COMMENT_BODY=$(gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
     --jq '[.[] | select(.user.login == "coderabbitai[bot]" or .user.login == "coderabbitai")] | .[0].body // ""')
   ```

2. **Check for failed pre-merge checks** (`❌` marker):
   ```bash
   FAILED_CHECKS=$(echo "$CR_COMMENT_BODY" | grep -c '❌' || true)
   echo "Pre-merge checks with failures: $FAILED_CHECKS"
   ```

3. **If zero failed checks**: Skip to Step 5 (or Step 7 if no unresolved thread findings either).

4. **For each failed check** (extract lines containing `❌`):
   ```bash
   echo "$CR_COMMENT_BODY" | grep '❌' | while IFS= read -r CHECK_LINE; do
     CHECK_NAME=$(echo "$CHECK_LINE" | sed 's/.*❌[[:space:]]*//' | sed 's/[[:space:]]*$//')
     echo ""
     echo "========================================"
     echo "Failed Pre-merge Check: $CHECK_NAME"
     echo "========================================"
   done
   ```

5. **For each failed check, analyze validity**:
   - Read the PR diff (`gh pr diff "$PR_NUMBER"`) and affected files
   - Determine if the check failure is **valid** (a real issue that should be fixed) or a **false positive** (the check is wrong or not applicable)
   - Consider the check type:
     - **Linked Issues**: Does the PR reference an issue? Check PR body for `Fixes #`, `Closes #`, issue URLs, or JIRA references
     - **Description Check**: Is the PR description adequate?
     - **Title Check**: Does the PR title follow conventions?
     - **Out of Scope Changes**: Are all changes relevant to the PR's stated purpose?
     - **Docstring Coverage**: Are new functions/types documented?

6. **If valid**: Implement the fix:
   - Make the necessary changes (e.g., add issue link to PR body, update title, add docstrings)
   - For PR metadata fixes (title, body), use `gh pr edit`:
     ```bash
     # Update PR body to add issue link
     gh pr edit "$PR_NUMBER" --body "$(updated body content)"
     # Update PR title
     gh pr edit "$PR_NUMBER" --title "new title"
     ```
   - For code fixes (e.g., missing docstrings), edit files, commit, and push:
     ```bash
     git add <files>
     git commit -m "$(cat <<'EOF'
     fix: address CodeRabbit pre-merge check - <check name>

     CodeRabbit pre-merge check for PR #<pr-number>:
     - Check: <check name>
     - <description of what was changed>

     Assisted-by: <current AI tool and model>
     EOF
     )"
     git push
     ```
   - Post a PR comment acknowledging the fix:
     ```bash
     gh pr comment "$PR_NUMBER" --body "$(cat <<'EOF'
     **Pre-merge Check Fixed**: <check name>

     **Action**: <description of what was done>
     EOF
     )"
     ```

7. **If false positive**: Post a PR comment explaining why:
   ```bash
   gh pr comment "$PR_NUMBER" --body "$(cat <<'EOF'
   **Pre-merge Check - False Positive**: <check name>

   **Rationale**: <explanation of why this check failure is not applicable>

   **Details**:
   - <specific reason 1>
   - <specific reason 2>
   EOF
   )"
   ```

8. **Track results** for the Step 7 summary:
   - Count total failed pre-merge checks
   - Count fixed vs false positives

### Step 5: Process Each Finding

For EACH finding (iterate through CR_UNRESOLVED by index `$i`, 0-based):

#### 5a. Extract Finding Details

```bash
FINDING_DATA=$(echo "$CR_UNRESOLVED" | jq ".[$i]")
THREAD_ID=$(echo "$FINDING_DATA" | jq -r '.id')
IS_RESOLVED=$(echo "$FINDING_DATA" | jq -r '.isResolved')
COMMENT=$(echo "$FINDING_DATA" | jq '.comments.nodes[0]')
COMMENT_BODY=$(echo "$COMMENT" | jq -r '.body')
COMMENT_DB_ID=$(echo "$COMMENT" | jq -r '.databaseId')
FILE_PATH=$(echo "$COMMENT" | jq -r '.path')
LINE=$(echo "$COMMENT" | jq -r '.line')
START_LINE=$(echo "$COMMENT" | jq -r '.startLine // .line')

echo ""
echo "========================================"
echo "Finding #$((i+1))/$TOTAL_FINDINGS"
echo "========================================"
echo "Thread ID: $THREAD_ID"
echo "File: $FILE_PATH:$LINE"
echo "Resolved: $IS_RESOLVED"
```

**Skip if already resolved**:
```bash
if [ "$IS_RESOLVED" = "true" ]; then
  echo "Thread already resolved, skipping"
  # continue to next finding
fi
```

#### 5b. Check for Suggestion Block

Check if the comment contains a ` ```suggestion ` code block:
```bash
HAS_SUGGESTION=$(echo "$COMMENT_BODY" | grep -c '```suggestion' || true)
```

- If `HAS_SUGGESTION > 0`: the comment contains an exact code suggestion. Extract the content between ` ```suggestion ` and the closing ` ``` `. The suggestion replaces lines `START_LINE` through `LINE` in `FILE_PATH`.
- If `HAS_SUGGESTION == 0`: this is a general recommendation. Claude Code must read the code, understand the recommendation, and implement manually.

#### 5c. Analyze the Finding

- Read the code context at `$FILE_PATH` around lines `$START_LINE` to `$LINE` using the Read tool
- Understand the suggestion in `$COMMENT_BODY`
- Evaluate against:
  - Repository patterns (check CLAUDE.md)
  - Code quality and correctness
  - Security implications
  - Test impact and idempotency
  - Whether the suggestion is actually beneficial

#### 5d. Decision: ACCEPT

If the finding is valid and should be implemented:

1. **Apply the fix**:
   - If suggestion block exists: parse the suggestion content, replace lines `START_LINE` through `LINE` in `FILE_PATH` with the suggestion content using the Edit tool
   - If general recommendation: implement the change manually using Edit tool
   - If the file was modified by a prior fix (lines shifted), re-read the file and find the correct location

2. **Format code** (if applicable):
   ```bash
   make fmt 2>/dev/null || true
   ```

3. **Commit the individual fix** (ONE COMMIT PER FINDING):
   ```bash
   git add "$FILE_PATH"
   git commit -m "$(cat <<'EOF'
   fix: address CodeRabbit finding - <brief description>

   CodeRabbit finding #N for PR #<pr-number>:
   - File: <file>:<line>
   - <description of what was changed>

   Assisted-by: <current AI tool and model>
   EOF
   )"
   ```

4. **Push the commit**:
   ```bash
   git push
   ```

5. **Post reply to the thread**:
   ```bash
   gh api -X POST "repos/$OWNER/$REPO/pulls/comments/$COMMENT_DB_ID/replies" \
     -f body="$(cat <<'EOF'
   **Implemented** - Finding #N

   **Change Made**: <description of implementation>

   **Commit**: <short SHA>

   **Details**:
   - <specific change 1>
   - <specific change 2>
   EOF
   )"
   ```

   **Fallback** (if thread reply API fails):
   ```bash
   gh pr review $PR_NUMBER --comment --body "Implemented Finding #N: <description>"
   ```

6. **Resolve the thread**:
   ```bash
   echo "Resolving thread $THREAD_ID..."
   RESOLVE_RESULT=$(gh api graphql -f query='
     mutation($threadId: ID!) {
       resolveReviewThread(input: {threadId: $threadId}) {
         thread {
           id
           isResolved
         }
       }
     }
   ' -F threadId="$THREAD_ID" 2>&1)

   if echo "$RESOLVE_RESULT" | jq -e '.data.resolveReviewThread.thread.isResolved == true' > /dev/null 2>&1; then
     echo "Thread $THREAD_ID resolved successfully"
   else
     echo "Warning: Failed to resolve thread $THREAD_ID"
     echo "Error: $RESOLVE_RESULT"
     echo "You can resolve manually in GitHub UI if needed"
   fi

   sleep 0.5
   ```

#### 5e. Decision: DENY

If the finding is not valid or not applicable:

1. **Post reply with rationale**:
   ```bash
   gh api -X POST "repos/$OWNER/$REPO/pulls/comments/$COMMENT_DB_ID/replies" \
     -f body="$(cat <<'EOF'
   **Not Implementing** - Finding #N

   **Rationale**: <clear explanation of why this doesn't fit>

   **Reasoning**:
   - <specific reason 1>
   - <specific reason 2>

   <any additional context>
   EOF
   )"
   ```

   **Fallback** (if thread reply API fails):
   ```bash
   gh pr review $PR_NUMBER --comment --body "Not implementing Finding #N: <rationale>"
   ```

2. **Resolve the thread** (same GraphQL mutation as ACCEPT):
   ```bash
   echo "Resolving thread $THREAD_ID..."
   RESOLVE_RESULT=$(gh api graphql -f query='
     mutation($threadId: ID!) {
       resolveReviewThread(input: {threadId: $threadId}) {
         thread {
           id
           isResolved
         }
       }
     }
   ' -F threadId="$THREAD_ID" 2>&1)

   if echo "$RESOLVE_RESULT" | jq -e '.data.resolveReviewThread.thread.isResolved == true' > /dev/null 2>&1; then
     echo "Thread $THREAD_ID resolved successfully"
   else
     echo "Warning: Failed to resolve thread $THREAD_ID"
     echo "Error: $RESOLVE_RESULT"
     echo "You can resolve manually in GitHub UI if needed"
   fi

   sleep 0.5
   ```

### Step 6: Dismiss Stale CodeRabbit Review

After processing all findings, if CodeRabbit submitted a "Changes Requested" review, dismiss it:

```bash
CR_REVIEW_ID=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" \
  --jq '[.[] | select(.user.login == "coderabbitai[bot]" and .state == "CHANGES_REQUESTED")] | .[0].id // empty')

if [ -n "$CR_REVIEW_ID" ]; then
  echo "Dismissing stale CodeRabbit 'Changes Requested' review..."
  gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews/$CR_REVIEW_ID/dismissals" \
    -X PUT -f message="All CodeRabbit findings have been addressed by Claude Code." -f event="DISMISS"
  echo "Review dismissed."
else
  echo "No stale 'Changes Requested' review to dismiss."
fi
```

### Loop Back Decision

After processing all findings in the current round:

1. **Check if any findings were accepted** (commits pushed) in this round
2. **If yes**: Increment `ROUND`, check against `MAX_ROUNDS` safety limit (default: 5)
   - If under limit: **Go back to Step 3** (wait for CodeRabbit's incremental re-review)
   - If at limit: Log warning and exit loop:
     ```
     WARNING: Reached maximum review rounds (5). Some new CodeRabbit findings may remain.
     Run `/ai-review` again to continue processing.
     ```
3. **If no findings were accepted** (all denied or already resolved): **Exit the loop** - no new code was pushed, so CodeRabbit won't re-review. Proceed to Step 7.

This ensures the pipeline iterates until CodeRabbit is satisfied (zero new unresolved findings) or the safety limit is reached.

### Step 6b: Process Qodo Findings

After the CodeRabbit loop exits, process Qodo review findings. Qodo runs after CodeRabbit because many findings overlap — processing CodeRabbit first allows us to dismiss Qodo duplicates automatically.

**Track a list of already-fixed files and lines** from CodeRabbit commits (collected during Steps 5d/5e) to detect duplicates.

#### 6b.1. Fetch Qodo inline review comments

```bash
QODO_COMMENTS=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
  --jq '[.[] | select(.user.login == "qodo-code-review[bot]" or .user.login == "qodo-code-review") | {id: .id, path: .path, line: (.line // .original_line), body: .body, in_reply_to_id: .in_reply_to_id}]')
QODO_COUNT=$(echo "$QODO_COMMENTS" | jq 'length')
echo "Found $QODO_COUNT Qodo inline review comments"
```

Filter to **root comments only** (exclude replies — those are follow-ups or our own replies):
```bash
QODO_FINDINGS=$(echo "$QODO_COMMENTS" | jq '[.[] | select(.in_reply_to_id == null)]')
QODO_FINDING_COUNT=$(echo "$QODO_FINDINGS" | jq 'length')
echo "Qodo findings to process: $QODO_FINDING_COUNT"
```

If zero findings, skip to Step 7.

#### 6b.2. Also fetch Qodo issue comments for bug findings

Qodo posts a summary issue comment with categorized findings (Bugs, Rule violations, Requirement gaps). Check if all bugs are `0`:

```bash
QODO_ISSUE_BODY=$(gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
  --jq '[.[] | select(.user.login == "qodo-code-review[bot]")] | .[-1].body // ""')
```

If the body contains `Bugs (0)` and `Rule violations (0)` and `Requirement gaps (0)`, Qodo is clean — note this and skip to Step 7.

#### 6b.3. Check for duplicates with CodeRabbit fixes

For each Qodo finding, check if it targets the same file and line (within ±3 lines) as a CodeRabbit finding that was already accepted and fixed:

```bash
for each QODO finding at file:line:
  if already_fixed_files contains (file, line ±3):
    # This is a duplicate — reply and skip
    mark as DUPLICATE
  else:
    # This is a unique Qodo finding — process it
    mark as UNIQUE
```

#### 6b.4. Process each Qodo finding

For each finding, in order:

**If DUPLICATE**:
```bash
gh api -X POST "repos/$OWNER/$REPO/pulls/comments/$COMMENT_ID/replies" \
  -f body="Already addressed in commit \`<SHA>\` (CodeRabbit finding for the same location)."
```

**If UNIQUE** — same accept/deny flow as CodeRabbit findings (Steps 5c-5e):

1. Present the finding to the user with context
2. Read the code, analyze the suggestion
3. **ACCEPT**: Apply fix, commit, push, reply inline:
   ```bash
   git add "$FILE_PATH"
   git commit -m "$(cat <<'EOF'
   fix: address Qodo finding - <brief description>

   Qodo finding for PR #<pr-number>:
   - File: <file>:<line>
   - <description of what was changed>

   Assisted-by: <current AI tool and model>
   EOF
   )"
   git push

   gh api -X POST "repos/$OWNER/$REPO/pulls/comments/$COMMENT_ID/replies" \
     -f body="**Implemented** — <description>. Commit: \`<SHA>\`"
   ```

4. **DENY**: Reply inline with rationale:
   ```bash
   gh api -X POST "repos/$OWNER/$REPO/pulls/comments/$COMMENT_ID/replies" \
     -f body="**Not implementing** — <rationale>"
   ```

**Note**: Qodo PR review comments cannot be programmatically resolved (no GraphQL thread resolution like CodeRabbit). The inline reply serves as the resolution signal.

#### 6b.5. Track Qodo results for summary

- Count total Qodo findings
- Count duplicates (already addressed by CodeRabbit)
- Count accepted (unique, implemented)
- Count denied (unique, not applicable)

### Step 7: Summary Report

At the end, provide a comprehensive summary:

```
========================================
AI Review Pipeline Summary - PR #<number>
========================================

Self-Review:
- Findings found: X
- Fixes committed: Y

Security Review:
- Findings found: X
- Fixes committed: Y

CodeRabbit Review:
- Review Rounds: N
- Total Findings (all rounds): X
- Accepted: Y (with individual commits)
- Denied: Z
- Already Resolved: W
- Stale Review Dismissed: Yes/No

Pre-merge Checks:
- Total Failed: X
- Fixed: Y
- False Positives: Z

Qodo Review:
- Total Findings: X
- Duplicates (already fixed via CodeRabbit): D
- Accepted: Y (with individual commits)
- Denied: Z

Accepted Findings:
1. [CodeRabbit Round N] Finding #N: <brief description> - file:line (commit: <SHA>)
2. [Qodo] Finding #N: <brief description> - file:line (commit: <SHA>)
...

Denied Findings:
1. [CodeRabbit Round N] Finding #N: <brief description> - Rationale: <brief reason>
2. [Qodo] Finding #N: <brief description> - Rationale: <brief reason>
...

All CodeRabbit threads resolved: Yes/No
All Qodo findings replied to: Yes/No
Summary Comment: Posted to PR #<number>
PR Description: Updated / Already current / Skipped (user declined)
```

### Step 7b: Post Summary as PR Comment

After generating the summary report, post it as a comment on the PR so reviewers can see the AI review results directly in the PR timeline.

```bash
gh pr comment "$PR_NUMBER" --body "$(cat <<'EOF'
## AI Review Pipeline Summary

| Category | Details |
|----------|---------|
| **Self-Review** | X findings found, Y commits |
| **Security Review** | X findings |
| **CodeRabbit** | N rounds, Y accepted, Z denied |
| **Pre-merge Checks** | X failures |
| **Qodo** | X findings (D duplicates, Y accepted, Z denied) |

### Accepted Findings

| # | Source | Description | File | Commit |
|---|--------|-------------|------|--------|
| 1 | <source> | <description> | `<file>` | `<SHA>` |

### Denied Findings

| # | Source | Description | Rationale |
|---|--------|-------------|-----------|
| 1 | <source> | <description> | <reason> |

---
All CodeRabbit threads resolved: Yes/No. PR description updated: Yes/No.

🤖 Generated by `/ai-review` pipeline
EOF
)"
```

**Notes**:
- Always post, even if there were zero findings (confirms the review ran)
- Use markdown tables for readability in the GitHub UI
- Omit the "Denied Findings" table header if there are no denied findings
- Omit the "Accepted Findings" table header if there are no accepted findings
- Keep the summary concise — link to individual thread replies for details

### Step 8: Update PR Description

After all findings are processed, update the PR description to accurately reflect the final state of changes. The original description may be stale if the PR accumulated many review-fix commits.

**Skip condition**: If zero findings were accepted across all review rounds (no commits pushed during the pipeline), the PR description has not gone stale. Report `PR Description: Already current (no changes made)` in the Step 7 summary and skip this step.

1. **Read the PR template** (`.github/PULL_REQUEST_TEMPLATE.md`) to know the expected format.

2. **Get the full diff** to understand all changes:
   ```bash
   gh pr diff "$PR_NUMBER"
   ```

3. **Read the current PR description**:
   ```bash
   CURRENT_BODY=$(gh pr view "$PR_NUMBER" --json body -q '.body')
   ```

4. **Regenerate the description** following the PR template format:
   - Preserve any issue links (`Fixes #N`, Jira references) from the current description
   - Summarize all changes from the diff (not just the original intent, but also all review fixes)
   - Update the "Changes Made" section to be comprehensive
   - Update "Configuration Changes" if any env vars were added/modified
   - Keep "Additional Notes" relevant and up to date
   - Preserve the `Generated with Claude Code` footer
   - Do NOT include CodeRabbit's auto-generated summary section — CodeRabbit will regenerate it on the next push

5. **Print the new description** to the terminal for the user to review before applying:
   - If the user approves: proceed to sub-step 6
   - If the user requests changes: incorporate feedback and re-print for approval
   - If the user declines: skip the update and report `PR Description: Skipped (user declined)` in the Step 7 summary

6. **Apply the update**:
   ```bash
   gh pr edit "$PR_NUMBER" --body "$(cat <<'EOF'
   <new description>
   EOF
   )"
   ```

## Important Guidelines

### Decision Criteria

- **Security findings**: ALWAYS implement security fixes unless there is a very strong reason not to
- **Pattern compliance**: Prioritize fixes that align with CLAUDE.md patterns
- **Test impact**: Consider if changes affect test behavior or idempotency
- **Suggestion blocks**: Prefer applying the reviewer's exact suggestion when it is correct; modify only if the suggestion has a bug
- **Be thorough**: Every finding gets a response and resolution
- **Be respectful**: Provide clear rationale for denials

### Commit Strategy

- **ONE COMMIT PER FINDING** - each accepted finding gets its own commit
- Commit message format: `fix: address <CodeRabbit|Qodo> finding - <description>`
- Push after each commit to keep the PR updated
- Include `Assisted-by: <current AI tool and model>` in every commit

### Thread Reply Strategy

- **Primary method**: `gh api -X POST repos/{owner}/{repo}/pulls/comments/{comment_db_id}/replies` for threaded replies (directly in thread context)
- **Fallback method**: `gh pr review {pr_number} --comment --body "..."` if thread reply API fails
- Always resolve the thread after posting the reply

### Edge Cases

1. **CodeRabbit review never arrives** (timeout): Proceed with warning. Report that CodeRabbit did not review in time and suggest re-running later.

2. **No findings from CodeRabbit**: Report success - CodeRabbit found no issues. Skip to summary.

3. **CodeRabbit re-reviews after pushes**: Each accepted fix triggers a push, which triggers a new incremental review. The command automatically loops back (Steps 3-6) to process new findings. Safety limit of 5 rounds prevents infinite loops.

4. **Push fails** (merge conflicts): Stop processing, inform the user, and provide instructions for manual resolution.

5. **File no longer exists**: If `FILE_PATH` from a finding was deleted by a prior fix, skip the finding and resolve the thread with an explanation.

6. **Line shift from prior fixes**: If lines shifted due to earlier fixes, re-read the current file, find the relevant code at the correct location, and apply the fix there.

7. **Multiple suggestion blocks in one comment**: Apply all suggestion blocks within the same commit for that finding.

8. **Pre-merge check false positives**: CodeRabbit's pre-merge checks (e.g., "Linked Issues") may report failures that are false positives (e.g., issue is linked via JIRA reference instead of GitHub `Fixes #N` syntax). Analyze the actual PR content before deciding. Post a PR comment explaining the false positive rather than making unnecessary changes.

9. **Qodo posts no inline comments**: Qodo sometimes only posts issue comments (summary) without inline findings. If the issue comment shows `Bugs (0)`, there are no findings — skip Qodo processing.

10. **Qodo and CodeRabbit find the same issue**: Process CodeRabbit first (it has better APIs). When processing Qodo, reply to duplicates with "Already addressed in commit `<SHA>`" — this keeps the PR tidy without redundant fixes.

11. **Qodo comments cannot be resolved**: Unlike CodeRabbit threads, Qodo PR review comments have no programmatic "resolve" API. The inline reply serves as the resolution signal. The user can manually collapse them in the GitHub UI.

## Response Format for Each Finding

**Finding #N: [Brief description]**
- **Source**: CodeRabbit / Qodo
- **Location**: `file.go:line`
- **Thread/Comment ID**: `PRRT_...` or `<comment_id>`
- **Suggestion**: [Summary of what was suggested]
- **Has Suggestion Block**: Yes/No
- **Decision**: ACCEPTED / DENIED / DUPLICATE
- **Action**: [What was implemented OR why it was denied OR which commit already addressed it]
- **Commit**: `<SHA>` (if accepted)
- **Reply Posted**: Yes
- **Thread Resolved**: Yes / Failed / N/A (Qodo — no resolve API)

### Step 9: Intent vs Implementation Check

After all automated findings are processed, print this reminder:

```
━━━ Manual check before you're done ━━━━━━━━━━━━━

Intent vs Implementation:
  1. Read the PR description / commit message.
  2. Read the diff — does the code do what was described?
     Common gaps: scope creep, missing edge cases,
     description says X but code does Y.
  3. If they don't match: comment on the PR or ask the author.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Permissions Required

- Repository > Contents: Read and Write
- Repository > Pull Requests: Read and Write
- Ability to dismiss reviews (requires write access)

## Related Commands

- `/copilot-review <pr>` - Process GitHub Copilot code review findings (same thread resolution pattern)
- `/implement-issue <number>` - Implement a GitHub issue end-to-end (includes PR creation)
- `/review-test <file>` - Review test files for pattern compliance
- `/review-open-prs` - Review all open PRs in the repository (batch mode)
