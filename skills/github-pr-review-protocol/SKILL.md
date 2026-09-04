---
name: github-pr-review-protocol
description: Use when reviewing a GitHub pull request, reviewer findings, or a named PR branch, especially from a fork or when the change set is large.
---

# GitHub PR review protocol

Use this protocol before a PR review skill reads a diff or edits code. Its output is a reproducible local review bundle; never use an unrelated checkout as the PR source.

## 1. Create the manifest and pinned checkout

Resolve the argument (URL, number, or current branch) to `OWNER`, `REPO`, and `PR_NUMBER`, then export `GH_REPO="$OWNER/$REPO"`. Fetch this minimum immutable manifest and save it as `manifest.json`:

```bash
if ! PR=$(gh pr view "$PR_NUMBER" --repo "$GH_REPO" --json number,title,state,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,headRepository,headRepositoryOwner,files,additions,deletions,body); then
  echo "Failed to fetch PR manifest." >&2; exit 1
fi
if ! BASE_PR=$(gh api "repos/$GH_REPO/pulls/$PR_NUMBER"); then
  echo "Failed to fetch base repository from pull-request endpoint." >&2; exit 1
fi
if ! PR_STATE=$(jq -er '.state | strings | select(length > 0)' <<<"$PR") ||
   ! PR_IS_DRAFT=$(jq -er '.isDraft | booleans' <<<"$PR") ||
   ! HEAD_SHA=$(jq -er '.headRefOid | strings | select(length > 0)' <<<"$PR") ||
   ! BASE_SHA=$(jq -er '.baseRefOid | strings | select(length > 0)' <<<"$PR"); then
  echo "Invalid PR manifest: missing state, draft status, base SHA, or head SHA." >&2; exit 1
fi
if ! PR=$(jq -ce --arg repo "$GH_REPO" --argjson number "$PR_NUMBER" --arg base "$BASE_SHA" --arg head "$HEAD_SHA" --argjson base_pr "$BASE_PR" '
  . as $manifest | if ($manifest.number == $number and $manifest.baseRefOid == $base and $manifest.headRefOid == $head and
      ($base_pr | type == "object" and .number == $number and
       (.base | type == "object" and .ref == $manifest.baseRefName and .sha == $base and
        (.repo | type == "object" and (.full_name | ascii_downcase) == ($repo | ascii_downcase) and (.html_url | type == "string" and length > 0))) and
       (.head | type == "object" and .ref == $manifest.headRefName and .sha == $head and
        (.label == ($manifest.headRepositoryOwner.login + ":" + $manifest.headRefName)) and
        (.repo | type == "object" and
          (.full_name as $full_name | ($full_name | type == "string" and length > 0 and (split("/") | length == 2) and (split("/")[0] | ascii_downcase == ($manifest.headRepositoryOwner.login | ascii_downcase)))) and
          (.owner | type == "object" and (.login | type == "string" and ascii_downcase == ($manifest.headRepositoryOwner.login | ascii_downcase))) and
          ((.clone_url // .ssh_url) | type == "string" and length > 0)))))
  then $manifest + {baseRepository:{url:$base_pr.base.repo.html_url},headRepository:($manifest.headRepository + {url:($base_pr.head.repo.clone_url // $base_pr.head.repo.ssh_url),fullName:$base_pr.head.repo.full_name})} else error("base pull-request response does not match PR manifest") end' <<<"$PR"); then
  echo "Invalid or inconsistent base pull-request response." >&2; exit 1
fi
if { [ "$PR_STATE" != OPEN ] || [ "$PR_IS_DRAFT" = true ]; } && [ "${REVIEW_NON_OPEN_PR:-}" != 1 ]; then
  echo "Refusing to review PR state $PR_STATE (draft=$PR_IS_DRAFT); explicit user authorization is required." >&2; exit 1
fi
REVIEW_DATA_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pr-review/${OWNER}-${REPO}-${PR_NUMBER}-${BASE_SHA}-${HEAD_SHA}"
if ! install -d -m 700 "$REVIEW_DATA_DIR"; then echo "Failed to create review-data directory." >&2; exit 1; fi
MANIFEST="$REVIEW_DATA_DIR/manifest.json"
if [ -e "$MANIFEST" ]; then
  jq -e --arg base "$BASE_SHA" --arg head "$HEAD_SHA" \
    '.baseRefOid == $base and .headRefOid == $head' "$MANIFEST" >/dev/null || {
      echo "Integrity error: existing manifest does not match the requested base/head SHA." >&2; exit 1; }
else
  printf '%s\n' "$PR" >"$MANIFEST"
fi
```

Do not continue unless `PR_STATE` is `OPEN` and `PR_IS_DRAFT=false`. To review a closed, merged, or draft PR, the user must explicitly authorize that exact exception in the request; only then set `REVIEW_NON_OPEN_PR=1` for that invocation and record the authorization, state, and draft status in the review header. Never set this override by inference or for a later mutation. Store raw API responses in this directory and derive compact summaries from them; do not paste raw JSON or a whole diff into chat.

With no argument, detect the current branch's PR; if none exists, ask whether to provide a PR or cancel. A URL supplies its own owner/repository; a number uses the active repository. Read applicable repository instructions from the dedicated worktree before reviewing.

Create a dedicated Git repository inside the bundle; do not fetch into the active checkout. This setup is restart-safe: reuse it only when its remotes, pinned base commit, Git common directory, detached `HEAD`, and manifest SHAs all match. `BASE_REF` identifies the PR target branch in manifest metadata; it is not an integrity invariant because that branch may advance after the manifest was recorded. A partial or mismatched bundle is an integrity error; do not delete, overwrite, or repair it automatically.

```bash
if ! BASE_URL=$(jq -er '.baseRepository.url | strings | select(length > 0)' "$MANIFEST") ||
   ! BASE_REF=$(jq -er '.baseRefName | strings | select(length > 0)' "$MANIFEST") ||
   ! HEAD_URL=$(jq -er '.headRepository.url | strings | select(length > 0)' "$MANIFEST"); then
  echo "Invalid manifest: missing repository URL or base ref." >&2; exit 1
fi
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
  if ! git init -q "$REVIEW_REPO"; then echo "Failed to initialize review repository." >&2; exit 1; fi
  if ! git -C "$REVIEW_REPO" remote add review-base "$BASE_URL"; then echo "Failed to add base remote." >&2; exit 1; fi
  if ! git -C "$REVIEW_REPO" remote add review-head "$HEAD_URL"; then echo "Failed to add head remote." >&2; exit 1; fi
  if ! git -C "$REVIEW_REPO" fetch --no-tags review-base "$BASE_SHA:refs/remotes/review/base"; then echo "Failed to fetch manifest-pinned base SHA." >&2; exit 1; fi
  if ! test "$(git -C "$REVIEW_REPO" rev-parse refs/remotes/review/base)" = "$BASE_SHA"; then echo "Fetched base SHA does not match manifest." >&2; exit 1; fi
  if ! git -C "$REVIEW_REPO" fetch --no-tags review-head "$HEAD_SHA"; then echo "Failed to fetch head SHA." >&2; exit 1; fi
  if ! test "$(git -C "$REVIEW_REPO" rev-parse FETCH_HEAD)" = "$HEAD_SHA"; then echo "Fetched head SHA does not match manifest." >&2; exit 1; fi
  if ! git -C "$REVIEW_REPO" worktree add --detach "$WORKTREE" "$HEAD_SHA"; then echo "Failed to create detached review worktree." >&2; exit 1; fi
  if ! test "$(git -C "$REVIEW_REPO" remote get-url review-base)" = "$BASE_URL" ||
     ! test "$(git -C "$REVIEW_REPO" remote get-url review-head)" = "$HEAD_URL" ||
     ! test "$(git -C "$REVIEW_REPO" rev-parse refs/remotes/review/base)" = "$BASE_SHA" ||
     ! test "$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)" = "$(git -C "$REVIEW_REPO" rev-parse --path-format=absolute --git-dir)" ||
     git -C "$WORKTREE" symbolic-ref -q HEAD >/dev/null ||
     ! test "$(git -C "$WORKTREE" rev-parse HEAD)" = "$HEAD_SHA"; then
    echo "Integrity error: fresh review bundle failed final invariant verification." >&2; exit 1
  fi
fi
if ! git -C "$WORKTREE" diff --no-ext-diff "$BASE_SHA...$HEAD_SHA" --stat >"$REVIEW_DATA_DIR/stat.txt"; then echo "Failed to capture diff statistics." >&2; exit 1; fi
if ! git -C "$WORKTREE" diff --no-ext-diff "$BASE_SHA...$HEAD_SHA" --name-status >"$REVIEW_DATA_DIR/files.txt"; then echo "Failed to capture changed-file list." >&2; exit 1; fi
```

If the fetch or SHA verification fails, stop and report the exact blocker. Never silently review a similarly named local branch.

## 2. Classify before reading

Classify from manifest totals and `files.txt`: **small** (at most 25 files and 800 changed lines), **medium** (at most 100 files and 4,000 lines), or **large** (everything else). Also identify generated, lock, vendored, formatting-only, and repeated mechanical groups. Report their count and rationale; inspect their generator or source change rather than sampling arbitrary output.

For medium and large PRs, prioritize security/authentication, public APIs, schema or persistence, workflows/CI, concurrency/error handling, and corresponding tests. Review a representative mechanical sample only after confirming the group is uniform. Run targeted checks first; run the full suite only when project guidance or risk justifies it.

## 3. Read targeted excerpts and report compactly

For each evidence-complete finding or risk target, read the reviewer metadata plus a narrow excerpt, normally 15 context lines:

```bash
git -C "$WORKTREE" diff --no-ext-diff --unified=15 "$BASE_SHA...$HEAD_SHA" -- "$FILE"
sed -n "$((START>15?START-15:1)),$((END+15))p" "$WORKTREE/$FILE"
```

Re-read current code immediately before implementing a finding. Findings must be actionable and introduced by the PR. Use exactly this shape, sorted by severity:

| Severity | Location | Finding | Impact | Disposition |
|---|---|---|---|---|

The review header is one line: `PR #N · base <short-sha> · head <short-sha> · <size> · reviewed/excluded: <counts>`. Follow it with checks run and residual risk only when relevant. Do not repeat reviewer prose, full diffs, raw API output, or generic praise.

## 4. Collect reviewer data without loading it into context

Save every API response before deriving an index. Never print a response body or `cat` these files. The limits are safety bounds, not truncation: if either limit is reached while `hasNextPage` is true, stop and report an incomplete collection; do not mutate threads based on it. Every GitHub call and JSON parse below is guarded: an API, schema, cursor, write, or index failure exits nonzero before the relevant page is persisted or a completion marker is created.

```bash
THREAD_DIR="$REVIEW_DATA_DIR/threads"; COMMENT_DIR="$REVIEW_DATA_DIR/comments"
if ! install -d -m 700 "$THREAD_DIR" "$COMMENT_DIR"; then echo "Failed to create reviewer-data directories." >&2; exit 1; fi
capture_manifest_valid() {
  local dir=$1 prefix=$2 scope=$3 index=${4:-} page_count n actual manifest index_hash index_count
  manifest="$dir/manifest.json"
  page_count=$(jq -er --arg scope "$scope" 'if .scope == $scope and (.pageCount | type == "number" and . >= 1) and (.pages == [range(1; .pageCount + 1)]) then .pageCount else error("invalid capture manifest") end' "$manifest") || return 1
  actual=$(find "$dir" -maxdepth 1 -type f -name "$prefix-*.json" | wc -l) || return 1
  [ "$actual" -eq "$page_count" ] || return 1
  for ((n = 1; n <= page_count; n++)); do test -f "$(printf '%s/%s-%04d.json' "$dir" "$prefix" "$n")" || return 1; done
  [ -z "$index" ] && return 0
  index_hash=$(sha256sum "$index" | awk '{print $1}') && index_count=$(wc -l <"$index") || return 1
  jq -e --arg hash "$index_hash" --argjson count "$index_count" '.indexSha256 == $hash and .indexRecordCount == $count' "$manifest" >/dev/null
}
write_capture_manifest() {
  local dir=$1 scope=$2 page_count=$3 index=${4:-} manifest index_hash index_count
  manifest="$dir/manifest.json"
  if [ -n "$index" ]; then
    index_hash=$(sha256sum "$index" | awk '{print $1}') && index_count=$(wc -l <"$index") || return 1
    jq -cn --arg scope "$scope" --argjson pageCount "$page_count" --arg hash "$index_hash" --argjson count "$index_count" '{scope:$scope,pageCount:$pageCount,pages:[range(1; $pageCount + 1)],indexSha256:$hash,indexRecordCount:$count}' >"$manifest" || return 1
  else
    jq -cn --arg scope "$scope" --argjson pageCount "$page_count" '{scope:$scope,pageCount:$pageCount,pages:[range(1; $pageCount + 1)]}' >"$manifest" || return 1
  fi
}
INDEX="$REVIEW_DATA_DIR/findings.ndjson"; COMPLETE="$THREAD_DIR/complete"
THREAD_SCOPE="threads:$OWNER/$REPO#$PR_NUMBER@$BASE_SHA:$HEAD_SHA"
if [ -e "$INDEX" ] || [ -e "$THREAD_DIR/page-0001.json" ] || [ -e "$THREAD_DIR/manifest.json" ] || [ -e "$COMPLETE" ]; then
  test -f "$COMPLETE" && test -f "$INDEX" && capture_manifest_valid "$THREAD_DIR" page "$THREAD_SCOPE" "$INDEX" || {
    echo "Integrity error: existing thread collection is incomplete; refusing to overwrite it." >&2; exit 1; }
  REBUILT_INDEX=$(mktemp "$THREAD_DIR/.findings-rebuilt.XXXXXX") || { echo "Failed to create thread-index verification file." >&2; exit 1; }
  CANONICAL_INDEX=$(mktemp "$THREAD_DIR/.findings-canonical.XXXXXX") || { echo "Failed to create canonical-index verification file." >&2; exit 1; }
  if ! { for ((VERIFY_PAGE = 1; VERIFY_PAGE <= $(jq -er '.pageCount' "$THREAD_DIR/manifest.json"); VERIFY_PAGE++)); do jq -c '.data.repository.pullRequest.reviewThreads.nodes[]? | .comments.nodes[0] as $c | {threadId:.id,resolved:.isResolved,commentId:$c.databaseId,author:$c.author.login,path:$c.path,line:$c.line,startLine:($c.startLine // $c.line),body:($c.body[0:600]),bodyLength:($c.body | length),bodyTruncated:(($c.body | length) > 600)}' "$(printf '%s/page-%04d.json' "$THREAD_DIR" "$VERIFY_PAGE")"; done; } >"$REBUILT_INDEX" || ! jq -c . "$INDEX" >"$CANONICAL_INDEX" || ! cmp -s "$REBUILT_INDEX" "$CANONICAL_INDEX"; then
    rm -f "$REBUILT_INDEX" "$CANONICAL_INDEX"
    echo "Integrity error: findings index does not match verified raw thread pages." >&2; exit 1
  fi
  rm -f "$REBUILT_INDEX" "$CANONICAL_INDEX" || { echo "Failed to remove thread-index verification files." >&2; exit 1; }
  echo "Reusing verified thread index: $INDEX"
else
  : >"$INDEX" || { echo "Failed to create finding index." >&2; exit 1; }
  CURSOR=; PAGE=0; MAX_THREAD_PAGES=100
  while :; do
    PAGE=$((PAGE + 1)); [ "$PAGE" -le "$MAX_THREAD_PAGES" ] || {
      echo "Incomplete collection: thread-page limit reached." >&2; exit 1; }
    ARGS=(-F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER")
    [ -z "$CURSOR" ] || ARGS+=(-F after="$CURSOR")
    if ! RESPONSE=$(gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100,after:$after){nodes{id isResolved comments(first:1){nodes{id databaseId body author{login} path line startLine}}} pageInfo{hasNextPage endCursor}}}}}}' "${ARGS[@]}"); then
      echo "Failed to fetch review-thread page $PAGE." >&2; exit 1
    fi
    if ! PAGE_INFO=$(jq -cer '
      def no_errors: (has("errors") | not) or (.errors | type == "array" and length == 0);
      def root_comment: type == "object" and (.id | type == "string" and length > 0) and (.databaseId | type == "number") and (.body | type == "string") and (.author | type == "object" and (.login | type == "string" and length > 0)) and (.path | type == "string") and ((.line == null) or (.line | type == "number")) and ((.startLine == null) or (.startLine | type == "number"));
      if no_errors and (.data.repository.pullRequest.reviewThreads as $threads | ($threads.nodes | type == "array") and (all($threads.nodes[]; type == "object" and (.id | type == "string" and length > 0) and (.isResolved | type == "boolean") and (.comments | type == "object") and (.comments.nodes | type == "array" and length == 1 and (.comments.nodes[0] | root_comment)))) and ($threads.pageInfo | type == "object" and (.hasNextPage | type == "boolean") and (if .hasNextPage then (.endCursor | type == "string" and length > 0) else true end))) then .data.repository.pullRequest.reviewThreads.pageInfo | {hasNextPage,endCursor} else error("invalid review-thread response") end' <<<"$RESPONSE") ||
       ! INDEX_RECORDS=$(jq -c '.data.repository.pullRequest.reviewThreads.nodes[]? | .comments.nodes[0] as $c | {threadId:.id,resolved:.isResolved,commentId:$c.databaseId,author:$c.author.login,path:$c.path,line:$c.line,startLine:($c.startLine // $c.line),body:($c.body[0:600]),bodyLength:($c.body | length),bodyTruncated:(($c.body | length) > 600)}' <<<"$RESPONSE"); then
      echo "Invalid review-thread response on page $PAGE." >&2; exit 1
    fi
    PAGE_FILE=$(printf '%s/page-%04d.json' "$THREAD_DIR" "$PAGE")
    printf '%s\n' "$RESPONSE" >"$PAGE_FILE" || { echo "Failed to save thread page $PAGE." >&2; exit 1; }
    printf '%s\n' "$INDEX_RECORDS" >>"$INDEX" || { echo "Failed to update finding index." >&2; exit 1; }
    HAS_NEXT=$(jq -er '.hasNextPage' <<<"$PAGE_INFO") || { echo "Invalid thread page state." >&2; exit 1; }
    [ "$HAS_NEXT" = true ] || break
    CURSOR=$(jq -er '.endCursor | strings | select(length > 0)' <<<"$PAGE_INFO") || { echo "Missing thread cursor." >&2; exit 1; }
  done
  write_capture_manifest "$THREAD_DIR" "$THREAD_SCOPE" "$PAGE" "$INDEX" || { echo "Failed to write thread collection manifest." >&2; exit 1; }
  touch "$COMPLETE" || { echo "Failed to mark thread collection complete." >&2; exit 1; }
fi
```

Paginate comments for each thread with the same capture-only rule. Existing incomplete files are an integrity error; a completion marker makes the collection reusable:

```bash
if ! jq -e 'type == "object" and (.threadId | type == "string" and length > 0) and (.resolved | type == "boolean") and (.commentId | type == "number") and (.author | type == "string" and length > 0) and (.path | type == "string") and ((.line == null) or (.line | type == "number")) and ((.startLine == null) or (.startLine | type == "number")) and (.body | type == "string" and length <= 600) and (.bodyLength | type) == "number" and .bodyLength >= (.body | length) and (.bodyTruncated | type) == "boolean" and .bodyTruncated == (.bodyLength > (.body | length))' "$INDEX" >/dev/null; then
  echo "Integrity error: findings index is malformed; refusing to collect comments." >&2; exit 1
fi
THREAD_IDS_FILE="$THREAD_DIR/thread-ids"
if ! jq -r '.threadId' "$INDEX" >"$THREAD_IDS_FILE"; then echo "Failed to parse findings index." >&2; exit 1; fi
THREAD_N=0
while IFS= read -r THREAD_ID; do
  THREAD_N=$((THREAD_N + 1)); COMMENT_COMPLETE=$(printf '%s/comment-%04d.complete' "$COMMENT_DIR" "$THREAD_N")
  FIRST_COMMENT_PAGE=$(printf '%s/comment-%04d-page-0001.json' "$COMMENT_DIR" "$THREAD_N")
  COMMENT_SCOPE="comments:$THREAD_ID@$HEAD_SHA"; COMMENT_MANIFEST=$(printf '%s/comment-%04d.manifest.json' "$COMMENT_DIR" "$THREAD_N")
  if [ -e "$FIRST_COMMENT_PAGE" ] || [ -e "$COMMENT_MANIFEST" ] || [ -e "$COMMENT_COMPLETE" ]; then
    test -f "$COMMENT_COMPLETE" && test -f "$COMMENT_MANIFEST" && jq -e --arg scope "$COMMENT_SCOPE" '.scope == $scope and (.pageCount | type == "number" and . >= 1) and (.pages == [range(1; .pageCount + 1)])' "$COMMENT_MANIFEST" >/dev/null || { echo "Integrity error: incomplete comment collection." >&2; exit 1; }
    COMMENT_COUNT=$(jq -er '.pageCount' "$COMMENT_MANIFEST") || { echo "Integrity error: invalid comment collection manifest." >&2; exit 1; }
    COMMENT_FILES=$(find "$COMMENT_DIR" -maxdepth 1 -type f -name "comment-$(printf '%04d' "$THREAD_N")-page-*.json" | wc -l) || { echo "Integrity error: cannot inspect comment pages." >&2; exit 1; }
    [ "$COMMENT_FILES" -eq "$COMMENT_COUNT" ] || { echo "Integrity error: comment page set is incomplete or mixed." >&2; exit 1; }
    for ((COMMENT_N = 1; COMMENT_N <= COMMENT_COUNT; COMMENT_N++)); do test -f "$(printf '%s/comment-%04d-page-%04d.json' "$COMMENT_DIR" "$THREAD_N" "$COMMENT_N")" || { echo "Integrity error: comment page set is incomplete or mixed." >&2; exit 1; }; done
    continue
  fi
  COMMENT_CURSOR=; COMMENT_PAGE=0; MAX_COMMENT_PAGES=20
  while :; do
    COMMENT_PAGE=$((COMMENT_PAGE + 1)); [ "$COMMENT_PAGE" -le "$MAX_COMMENT_PAGES" ] || {
      echo "Incomplete collection: comment-page limit reached for thread $THREAD_N." >&2; exit 1; }
    COMMENT_ARGS=(-F threadId="$THREAD_ID")
    [ -z "$COMMENT_CURSOR" ] || COMMENT_ARGS+=(-F after="$COMMENT_CURSOR")
    if ! COMMENT_RESPONSE=$(gh api graphql -f query='query($threadId:ID!,$after:String){node(id:$threadId){... on PullRequestReviewThread{comments(first:100,after:$after){nodes{id databaseId body author{login} path line startLine} pageInfo{hasNextPage endCursor}}}}}' "${COMMENT_ARGS[@]}"); then
      echo "Failed to fetch comment page $COMMENT_PAGE for thread $THREAD_N." >&2; exit 1
    fi
    if ! COMMENT_PAGE_INFO=$(jq -cer 'def no_errors: (has("errors") | not) or (.errors | type == "array" and length == 0); def comment: type == "object" and (.id | type == "string" and length > 0) and (.databaseId | type == "number") and (.body | type == "string") and (.author | type == "object" and (.login | type == "string" and length > 0)) and (.path | type == "string") and ((.line == null) or (.line | type == "number")) and ((.startLine == null) or (.startLine | type == "number")); if no_errors and (.data.node.comments as $comments | ($comments.nodes | type == "array") and (all($comments.nodes[]; comment)) and ($comments.pageInfo | type == "object" and (.hasNextPage | type == "boolean") and (if .hasNextPage then (.endCursor | type == "string" and length > 0) else true end))) then .data.node.comments.pageInfo | {hasNextPage,endCursor} else error("invalid comment response") end' <<<"$COMMENT_RESPONSE"); then
      echo "Invalid comment response for thread $THREAD_N page $COMMENT_PAGE." >&2; exit 1
    fi
    COMMENT_FILE=$(printf '%s/comment-%04d-page-%04d.json' "$COMMENT_DIR" "$THREAD_N" "$COMMENT_PAGE")
    printf '%s\n' "$COMMENT_RESPONSE" >"$COMMENT_FILE" || { echo "Failed to save comment page." >&2; exit 1; }
    COMMENT_HAS_NEXT=$(jq -er '.hasNextPage' <<<"$COMMENT_PAGE_INFO") || { echo "Invalid comment page state." >&2; exit 1; }
    [ "$COMMENT_HAS_NEXT" = true ] || break
    COMMENT_CURSOR=$(jq -er '.endCursor | strings | select(length > 0)' <<<"$COMMENT_PAGE_INFO") || { echo "Missing comment cursor." >&2; exit 1; }
  done
  jq -cn --arg scope "$COMMENT_SCOPE" --argjson pageCount "$COMMENT_PAGE" '{scope:$scope,pageCount:$pageCount,pages:[range(1; $pageCount + 1)]}' >"$COMMENT_MANIFEST" || { echo "Failed to write comment collection manifest." >&2; exit 1; }
  touch "$COMMENT_COMPLETE" || { echo "Failed to mark comment collection complete." >&2; exit 1; }
done <"$THREAD_IDS_FILE"
```

Capture Qodo's issue comments and commit checks before deciding whether Qodo is clean. These endpoints are bounded and fail closed: each response is schema-validated and persisted before the terminal decision; an API error, malformed record, or page cap leaves no completion marker. Do not treat an absent Qodo result as clean unless both collections have their completion markers.

```bash
QODO_COMMENT_DIR="$REVIEW_DATA_DIR/qodo-issue-comments"; QODO_CHECK_DIR="$REVIEW_DATA_DIR/qodo-checks"
if ! install -d -m 700 "$QODO_COMMENT_DIR" "$QODO_CHECK_DIR"; then echo "Failed to create Qodo-data directories." >&2; exit 1; fi
QODO_COMMENT_COMPLETE="$QODO_COMMENT_DIR/complete"; QODO_CHECK_COMPLETE="$QODO_CHECK_DIR/complete"
QODO_COMMENT_SCOPE="qodo-issue-comments:$OWNER/$REPO#$PR_NUMBER@$HEAD_SHA"
QODO_CHECK_SCOPE="qodo-checks:$OWNER/$REPO#$PR_NUMBER@$HEAD_SHA"
if [ -e "$QODO_COMMENT_DIR/page-0001.json" ] || [ -e "$QODO_COMMENT_DIR/manifest.json" ] || [ -e "$QODO_COMMENT_COMPLETE" ]; then
  test -f "$QODO_COMMENT_COMPLETE" && capture_manifest_valid "$QODO_COMMENT_DIR" page "$QODO_COMMENT_SCOPE" || { echo "Integrity error: incomplete or mixed Qodo issue-comment collection." >&2; exit 1; }
else
  QODO_PAGE=0; MAX_QODO_COMMENT_PAGES=100
  while :; do
    QODO_PAGE=$((QODO_PAGE + 1)); [ "$QODO_PAGE" -le "$MAX_QODO_COMMENT_PAGES" ] || { echo "Incomplete collection: Qodo issue-comment page limit reached." >&2; exit 1; }
    if ! QODO_RESPONSE=$(gh api "repos/$GH_REPO/issues/$PR_NUMBER/comments?per_page=100&page=$QODO_PAGE"); then echo "Failed to fetch Qodo issue-comment page $QODO_PAGE." >&2; exit 1; fi
    if ! jq -e 'type == "array" and all(.[]; type == "object" and (.id | type == "number") and (.body | type == "string") and (.user | type == "object" and (.login | type == "string" and length > 0)) and (.html_url | type == "string" and length > 0))' <<<"$QODO_RESPONSE" >/dev/null; then echo "Invalid Qodo issue-comment response on page $QODO_PAGE." >&2; exit 1; fi
    QODO_FILE=$(printf '%s/page-%04d.json' "$QODO_COMMENT_DIR" "$QODO_PAGE")
    printf '%s\n' "$QODO_RESPONSE" >"$QODO_FILE" || { echo "Failed to save Qodo issue-comment page." >&2; exit 1; }
    [ "$(jq -er 'length' <<<"$QODO_RESPONSE")" -lt 100 ] || continue
    break
  done
  write_capture_manifest "$QODO_COMMENT_DIR" "$QODO_COMMENT_SCOPE" "$QODO_PAGE" || { echo "Failed to write Qodo issue-comment collection manifest." >&2; exit 1; }
  touch "$QODO_COMMENT_COMPLETE" || { echo "Failed to mark Qodo issue-comment collection complete." >&2; exit 1; }
fi
if [ -e "$QODO_CHECK_DIR/page-0001.json" ] || [ -e "$QODO_CHECK_DIR/manifest.json" ] || [ -e "$QODO_CHECK_COMPLETE" ]; then
  test -f "$QODO_CHECK_COMPLETE" && capture_manifest_valid "$QODO_CHECK_DIR" page "$QODO_CHECK_SCOPE" || { echo "Integrity error: incomplete or mixed Qodo checks collection." >&2; exit 1; }
else
  QODO_PAGE=0; MAX_QODO_CHECK_PAGES=100
  while :; do
    QODO_PAGE=$((QODO_PAGE + 1)); [ "$QODO_PAGE" -le "$MAX_QODO_CHECK_PAGES" ] || { echo "Incomplete collection: Qodo checks page limit reached." >&2; exit 1; }
    if ! QODO_RESPONSE=$(gh api "repos/$GH_REPO/commits/$HEAD_SHA/check-runs?per_page=100&page=$QODO_PAGE"); then echo "Failed to fetch Qodo checks page $QODO_PAGE." >&2; exit 1; fi
    if ! jq -e 'type == "object" and (.total_count | type == "number" and . >= 0) and (.check_runs | type == "array") and all(.check_runs[]; type == "object" and (.id | type == "number") and (.name | type == "string" and length > 0) and (.status | type == "string" and length > 0) and ((.conclusion == null) or (.conclusion | type == "string")) and (.html_url | type == "string" and length > 0))' <<<"$QODO_RESPONSE" >/dev/null; then echo "Invalid Qodo checks response on page $QODO_PAGE." >&2; exit 1; fi
    QODO_FILE=$(printf '%s/page-%04d.json' "$QODO_CHECK_DIR" "$QODO_PAGE")
    printf '%s\n' "$QODO_RESPONSE" >"$QODO_FILE" || { echo "Failed to save Qodo checks page." >&2; exit 1; }
    QODO_TOTAL=$(jq -er '.total_count' <<<"$QODO_RESPONSE") || { echo "Invalid Qodo checks total." >&2; exit 1; }
    [ $((QODO_PAGE * 100)) -lt "$QODO_TOTAL" ] || break
  done
  write_capture_manifest "$QODO_CHECK_DIR" "$QODO_CHECK_SCOPE" "$QODO_PAGE" || { echo "Failed to write Qodo checks collection manifest." >&2; exit 1; }
  touch "$QODO_CHECK_COMPLETE" || { echo "Failed to mark Qodo checks collection complete." >&2; exit 1; }
fi
if ! QODO_NONTERMINAL_CHECKS=$(jq -r 'select(.check_runs != null) | .check_runs[] | select((.name | ascii_downcase | contains("qodo")) and .status != "completed") | .html_url' "$QODO_CHECK_DIR"/page-*.json); then echo "Failed to classify Qodo check status." >&2; exit 1; fi
if [ -n "$QODO_NONTERMINAL_CHECKS" ]; then
  QODO_CHECKS_TERMINAL=false
  echo "Qodo check is not terminal; do not report a clean Qodo result." >&2
else
  QODO_CHECKS_TERMINAL=true
fi
```

Do not expose comment bodies to the model. The model receives only one index record (body capped at 600 characters), its `bodyLength` and `bodyTruncated` flags, reviewer/source label, and the targeted code excerpt from section 3. A `bodyTruncated: true` finding is evidence-incomplete: do not accept, deny, reply, resolve, commit, push, or otherwise mutate it. First create a bounded decision summary from the locally stored full comment that captures the complete claim, evidence, requested action, and scope; if that cannot be done without bulk output, report the thread as evidence-incomplete and leave it untouched. Derive Qodo's compact summary only from completed Qodo capture directories.

## 5. Reviewer-thread transaction

Filter unresolved, evidence-complete root comments by reviewer from `findings.ndjson`. For every finding: inspect its capped metadata and targeted excerpt; accept, deny, or mark duplicate; reply directly to the original comment when possible; resolve the GraphQL thread when that reviewer supports it; verify the mutation result. If accepted, test, make one focused commit, and push before replying. If a reply or resolution fails, record it and continue; do not claim it succeeded.

For CodeRabbit, poll its summary every 30 seconds for up to 30 attempts, then wait until the inline-thread count is unchanged for two 10-second checks. A timeout is a warning, not a clean result. Treat walkthrough and summary comments as non-findings. Qodo may publish only a summary; after both Qodo captures complete and `QODO_CHECKS_TERMINAL=true`, when its Bugs, Rule violations, and Requirement gaps are all zero, record a clean Qodo result. A capture error, incomplete collection, or Qodo check still in a non-terminal status is a warning, never a clean result.

Use concise replies: `Implemented in <short-sha>: <change and why>.` or `Not implementing: <specific reason>.` A duplicate reply names the commit that addressed it. Never auto-fix or rerun a review-only skill unless the user asks.

## Legacy source-command mirrors

`source-command-*` skills are generated compatibility artifacts, not sources of truth. Do not edit or invoke them. Use the canonical skill named in the request; after installation/restart, remove obsolete generated mirrors and regenerate only if the hosting product requires them.
