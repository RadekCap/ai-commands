---
name: github-pr-review-protocol
description: Use when reviewing a GitHub pull request, reviewer findings, or a named PR branch, especially from a fork or when the change set is large.
---

# GitHub PR review protocol

Use this protocol before a PR review skill reads a diff or edits code. Its output is a reproducible local review bundle; never use an unrelated checkout as the PR source.

## 1. Create the manifest and pinned checkout

Resolve the argument (URL, number, or current branch) to `OWNER`, `REPO`, and `PR_NUMBER`, then export `GH_REPO="$OWNER/$REPO"`. Fetch this minimum immutable manifest and save it as `manifest.json`:

```bash
PR=$(gh pr view "$PR_NUMBER" --repo "$GH_REPO" --json number,title,state,baseRefName,baseRefOid,baseRepository,headRefName,headRefOid,headRepository,headRepositoryOwner,files,additions,deletions,body)
HEAD_SHA=$(jq -r .headRefOid <<<"$PR"); BASE_SHA=$(jq -r .baseRefOid <<<"$PR")
REVIEW_DATA_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pr-review/${OWNER}-${REPO}-${PR_NUMBER}-${HEAD_SHA}"
install -d -m 700 "$REVIEW_DATA_DIR"
printf '%s\n' "$PR" >"$REVIEW_DATA_DIR/manifest.json"
```

Do not continue unless the PR is open, unless the user explicitly authorizes reviewing another state. Store raw API responses in this directory (`threads.json`, `comments.json`, `checks.json`) and derive compact summaries from them; do not paste raw JSON or a whole diff into chat.

With no argument, detect the current branch's PR; if none exists, ask whether to provide a PR or cancel. A URL supplies its own owner/repository; a number uses the active repository. Read applicable repository instructions from the dedicated worktree before reviewing.

Create a dedicated Git repository inside the bundle; do not fetch into the active checkout. Fetch the base ref and the head SHA from their declared repositories, verify both SHAs, then use an isolated detached worktree:

```bash
BASE_URL=$(jq -r '.baseRepository.url' "$REVIEW_DATA_DIR/manifest.json")
BASE_REF=$(jq -r '.baseRefName' "$REVIEW_DATA_DIR/manifest.json")
HEAD_URL=$(jq -r '.headRepository.url' "$REVIEW_DATA_DIR/manifest.json")
REVIEW_REPO="$REVIEW_DATA_DIR/repo"
git init -q "$REVIEW_REPO"
git -C "$REVIEW_REPO" fetch --no-tags "$BASE_URL" "$BASE_REF:refs/remotes/review/base"
test "$(git -C "$REVIEW_REPO" rev-parse refs/remotes/review/base)" = "$BASE_SHA"
git -C "$REVIEW_REPO" fetch --no-tags "$HEAD_URL" "$HEAD_SHA"
test "$(git -C "$REVIEW_REPO" rev-parse FETCH_HEAD)" = "$HEAD_SHA"
WORKTREE="$REVIEW_DATA_DIR/worktree"
git -C "$REVIEW_REPO" worktree add --detach "$WORKTREE" "$HEAD_SHA"
git -C "$WORKTREE" diff --no-ext-diff "$BASE_SHA...$HEAD_SHA" --stat >"$REVIEW_DATA_DIR/stat.txt"
git -C "$WORKTREE" diff --no-ext-diff "$BASE_SHA...$HEAD_SHA" --name-status >"$REVIEW_DATA_DIR/files.txt"
```

If the fetch or SHA verification fails, stop and report the exact blocker. Never silently review a similarly named local branch.

## 2. Classify before reading

Classify from manifest totals and `files.txt`: **small** (at most 25 files and 800 changed lines), **medium** (at most 100 files and 4,000 lines), or **large** (everything else). Also identify generated, lock, vendored, formatting-only, and repeated mechanical groups. Report their count and rationale; inspect their generator or source change rather than sampling arbitrary output.

For medium and large PRs, prioritize security/authentication, public APIs, schema or persistence, workflows/CI, concurrency/error handling, and corresponding tests. Review a representative mechanical sample only after confirming the group is uniform. Run targeted checks first; run the full suite only when project guidance or risk justifies it.

## 3. Read targeted excerpts and report compactly

For each finding or risk target, read the reviewer comment plus a narrow excerpt, normally 15 context lines:

```bash
git -C "$WORKTREE" diff --no-ext-diff --unified=15 "$BASE_SHA...$HEAD_SHA" -- "$FILE"
sed -n "$((START>15?START-15:1)),$((END+15))p" "$WORKTREE/$FILE"
```

Re-read current code immediately before implementing a finding. Findings must be actionable and introduced by the PR. Use exactly this shape, sorted by severity:

| Severity | Location | Finding | Impact | Disposition |
|---|---|---|---|---|

The review header is one line: `PR #N · base <short-sha> · head <short-sha> · <size> · reviewed/excluded: <counts>`. Follow it with checks run and residual risk only when relevant. Do not repeat reviewer prose, full diffs, raw API output, or generic praise.

## 4. Reviewer-thread transaction

Fetch all review threads with pagination and store the raw response. Filter unresolved root comments by reviewer. For every finding: inspect its targeted excerpt; accept, deny, or mark duplicate; reply directly to the original comment when possible; resolve the GraphQL thread when that reviewer supports it; verify the mutation result. If accepted, test, make one focused commit, and push before replying. If a reply or resolution fails, record it and continue; do not claim it succeeded.

For CodeRabbit, poll its summary every 30 seconds for up to 30 attempts, then wait until the inline-thread count is unchanged for two 10-second checks. A timeout is a warning, not a clean result. Treat walkthrough and summary comments as non-findings. Qodo may publish only a summary; when its Bugs, Rule violations, and Requirement gaps are all zero, record a clean Qodo result.

Use concise replies: `Implemented in <short-sha>: <change and why>.` or `Not implementing: <specific reason>.` A duplicate reply names the commit that addressed it. Never auto-fix or rerun a review-only skill unless the user asks.

## Legacy source-command mirrors

`source-command-*` skills are generated compatibility artifacts, not sources of truth. Do not edit or invoke them. Use the canonical skill named in the request; after installation/restart, remove obsolete generated mirrors and regenerate only if the hosting product requires them.
