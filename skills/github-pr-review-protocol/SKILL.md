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
REVIEW_DATA_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pr-review/${OWNER}-${REPO}-${PR_NUMBER}-${BASE_SHA}-${HEAD_SHA}"
install -d -m 700 "$REVIEW_DATA_DIR"
MANIFEST="$REVIEW_DATA_DIR/manifest.json"
if [ -e "$MANIFEST" ]; then
  jq -e --arg base "$BASE_SHA" --arg head "$HEAD_SHA" \
    '.baseRefOid == $base and .headRefOid == $head' "$MANIFEST" >/dev/null || {
      echo "Integrity error: existing manifest does not match the requested base/head SHA." >&2; exit 1; }
else
  printf '%s\n' "$PR" >"$MANIFEST"
fi
```

Do not continue unless the PR is open, unless the user explicitly authorizes reviewing another state. Store raw API responses in this directory (`threads.json`, `comments.json`, `checks.json`) and derive compact summaries from them; do not paste raw JSON or a whole diff into chat.

With no argument, detect the current branch's PR; if none exists, ask whether to provide a PR or cancel. A URL supplies its own owner/repository; a number uses the active repository. Read applicable repository instructions from the dedicated worktree before reviewing.

Create a dedicated Git repository inside the bundle; do not fetch into the active checkout. This setup is restart-safe: reuse it only when its remotes, base ref, Git common directory, detached `HEAD`, and manifest SHAs all match. A partial or mismatched bundle is an integrity error; do not delete, overwrite, or repair it automatically.

```bash
BASE_URL=$(jq -r '.baseRepository.url' "$MANIFEST")
BASE_REF=$(jq -r '.baseRefName' "$MANIFEST")
HEAD_URL=$(jq -r '.headRepository.url' "$MANIFEST")
REVIEW_REPO="$REVIEW_DATA_DIR/repo"
WORKTREE="$REVIEW_DATA_DIR/worktree"
if [ -e "$REVIEW_REPO" ] || [ -e "$WORKTREE" ]; then
  test -d "$REVIEW_REPO/.git" && test -d "$WORKTREE" &&
    test "$(git -C "$REVIEW_REPO" remote get-url review-base)" = "$BASE_URL" &&
    test "$(git -C "$REVIEW_REPO" remote get-url review-head)" = "$HEAD_URL" &&
    test "$(git -C "$REVIEW_REPO" rev-parse refs/remotes/review/base)" = "$BASE_SHA" &&
    test "$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)" = "$(git -C "$REVIEW_REPO" rev-parse --path-format=absolute --git-dir)" &&
    ! git -C "$WORKTREE" symbolic-ref -q HEAD >/dev/null &&
    test "$(git -C "$WORKTREE" rev-parse HEAD)" = "$HEAD_SHA" || {
      echo "Integrity error: existing review bundle is incomplete or does not match its manifest." >&2; exit 1; }
  echo "Reusing verified review bundle: $REVIEW_DATA_DIR"
else
  git init -q "$REVIEW_REPO"
  git -C "$REVIEW_REPO" remote add review-base "$BASE_URL"
  git -C "$REVIEW_REPO" remote add review-head "$HEAD_URL"
  git -C "$REVIEW_REPO" fetch --no-tags review-base "$BASE_REF:refs/remotes/review/base"
  test "$(git -C "$REVIEW_REPO" rev-parse refs/remotes/review/base)" = "$BASE_SHA"
  git -C "$REVIEW_REPO" fetch --no-tags review-head "$HEAD_SHA"
  test "$(git -C "$REVIEW_REPO" rev-parse FETCH_HEAD)" = "$HEAD_SHA"
  git -C "$REVIEW_REPO" worktree add --detach "$WORKTREE" "$HEAD_SHA"
fi
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

## 4. Collect reviewer data without loading it into context

Save every API response before deriving an index. Never print a response body or `cat` these files. The limits are safety bounds, not truncation: if either limit is reached while `hasNextPage` is true, stop and report an incomplete collection; do not mutate threads based on it.

```bash
THREAD_DIR="$REVIEW_DATA_DIR/threads"; COMMENT_DIR="$REVIEW_DATA_DIR/comments"
install -d -m 700 "$THREAD_DIR" "$COMMENT_DIR"
INDEX="$REVIEW_DATA_DIR/findings.ndjson"; COMPLETE="$THREAD_DIR/complete"
if [ -e "$INDEX" ] || [ -e "$THREAD_DIR/page-0001.json" ]; then
  test -f "$COMPLETE" && test -s "$INDEX" || {
    echo "Integrity error: existing thread collection is incomplete; refusing to overwrite it." >&2; exit 1; }
  echo "Reusing verified thread index: $INDEX"
else
  CURSOR=; PAGE=0; MAX_THREAD_PAGES=100
  while :; do
    PAGE=$((PAGE + 1)); [ "$PAGE" -le "$MAX_THREAD_PAGES" ] || {
      echo "Incomplete collection: thread-page limit reached." >&2; exit 1; }
    ARGS=(-F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER")
    [ -z "$CURSOR" ] || ARGS+=(-F after="$CURSOR")
    RESPONSE=$(gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100,after:$after){nodes{id isResolved comments(first:1){nodes{id databaseId body author{login} path line startLine}}} pageInfo{hasNextPage endCursor}}}}}' "${ARGS[@]}")
    PAGE_FILE=$(printf '%s/page-%04d.json' "$THREAD_DIR" "$PAGE")
    printf '%s\n' "$RESPONSE" >"$PAGE_FILE"
    jq -c '.data.repository.pullRequest.reviewThreads.nodes[] | .comments.nodes[0] as $c | select($c != null) | {threadId:.id,resolved:.isResolved,commentId:$c.databaseId,author:$c.author.login,path:$c.path,line:$c.line,startLine:($c.startLine // $c.line),body:($c.body[0:600])}' "$PAGE_FILE" >>"$INDEX"
    HAS_NEXT=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' "$PAGE_FILE")
    [ "$HAS_NEXT" = true ] || break
    CURSOR=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor' "$PAGE_FILE")
  done
  touch "$COMPLETE"
fi
```

Paginate comments for each thread with the same capture-only rule. Existing incomplete files are an integrity error; a completion marker makes the collection reusable:

```bash
THREAD_N=0
while IFS= read -r THREAD_ID; do
  THREAD_N=$((THREAD_N + 1)); COMMENT_COMPLETE=$(printf '%s/comment-%04d.complete' "$COMMENT_DIR" "$THREAD_N")
  FIRST_COMMENT_PAGE=$(printf '%s/comment-%04d-page-0001.json' "$COMMENT_DIR" "$THREAD_N")
  if [ -e "$FIRST_COMMENT_PAGE" ]; then
    test -f "$COMMENT_COMPLETE" || { echo "Integrity error: incomplete comment collection." >&2; exit 1; }
    continue
  fi
  COMMENT_CURSOR=; COMMENT_PAGE=0; MAX_COMMENT_PAGES=20
  while :; do
    COMMENT_PAGE=$((COMMENT_PAGE + 1)); [ "$COMMENT_PAGE" -le "$MAX_COMMENT_PAGES" ] || {
      echo "Incomplete collection: comment-page limit reached for thread $THREAD_N." >&2; exit 1; }
    COMMENT_ARGS=(-F threadId="$THREAD_ID")
    [ -z "$COMMENT_CURSOR" ] || COMMENT_ARGS+=(-F after="$COMMENT_CURSOR")
    COMMENT_RESPONSE=$(gh api graphql -f query='query($threadId:ID!,$after:String){node(id:$threadId){... on PullRequestReviewThread{comments(first:100,after:$after){nodes{id databaseId body author{login} path line startLine} pageInfo{hasNextPage endCursor}}}}' "${COMMENT_ARGS[@]}")
    COMMENT_FILE=$(printf '%s/comment-%04d-page-%04d.json' "$COMMENT_DIR" "$THREAD_N" "$COMMENT_PAGE")
    printf '%s\n' "$COMMENT_RESPONSE" >"$COMMENT_FILE"
    COMMENT_HAS_NEXT=$(jq -r '.data.node.comments.pageInfo.hasNextPage' "$COMMENT_FILE")
    [ "$COMMENT_HAS_NEXT" = true ] || break
    COMMENT_CURSOR=$(jq -r '.data.node.comments.pageInfo.endCursor' "$COMMENT_FILE")
  done
  touch "$COMMENT_COMPLETE"
done < <(jq -r '.threadId' "$INDEX")
```

Do not expose comment bodies to the model. The model receives only one index record (body capped at 600 characters), its reviewer/source label, and the targeted code excerpt from section 3. Fetch issue comments, checks, and bot summaries into `comments.json` or `checks.json` with the same capture-then-summarize rule.

## 5. Reviewer-thread transaction

Filter unresolved root comments by reviewer from `findings.ndjson`. For every finding: inspect its capped metadata and targeted excerpt; accept, deny, or mark duplicate; reply directly to the original comment when possible; resolve the GraphQL thread when that reviewer supports it; verify the mutation result. If accepted, test, make one focused commit, and push before replying. If a reply or resolution fails, record it and continue; do not claim it succeeded.

For CodeRabbit, poll its summary every 30 seconds for up to 30 attempts, then wait until the inline-thread count is unchanged for two 10-second checks. A timeout is a warning, not a clean result. Treat walkthrough and summary comments as non-findings. Qodo may publish only a summary; when its Bugs, Rule violations, and Requirement gaps are all zero, record a clean Qodo result.

Use concise replies: `Implemented in <short-sha>: <change and why>.` or `Not implementing: <specific reason>.` A duplicate reply names the commit that addressed it. Never auto-fix or rerun a review-only skill unless the user asks.

## Legacy source-command mirrors

`source-command-*` skills are generated compatibility artifacts, not sources of truth. Do not edit or invoke them. Use the canonical skill named in the request; after installation/restart, remove obsolete generated mirrors and regenerate only if the hosting product requires them.
