#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

page_info() {
  jq -cer '
    def no_errors: (has("errors") | not) or (.errors | type == "array" and length == 0);
    def root_comment:
      type == "object" and (.id | type == "string" and length > 0) and
      (.databaseId | type == "number") and (.body | type == "string") and
      (.author | type == "object" and (.login | type == "string" and length > 0)) and
      (.path | type == "string") and
      ((.line == null) or (.line | type == "number")) and
      ((.startLine == null) or (.startLine | type == "number"));
    if no_errors and
    (.data.repository.pullRequest.reviewThreads as $threads |
      ($threads.nodes | type == "array") and
      (all($threads.nodes[]; type == "object" and (.id | type == "string" and length > 0) and
        (.isResolved | type == "boolean") and (.comments | type == "object") and
        (.comments.nodes | type == "array" and length == 1 and (.comments.nodes[0] | root_comment)))) and
      ($threads.pageInfo | type == "object" and (.hasNextPage | type == "boolean") and
        (if .hasNextPage then (.endCursor | type == "string" and length > 0) else true end)))
    then .data.repository.pullRequest.reviewThreads.pageInfo | {hasNextPage,endCursor}
    else error("invalid review-thread response") end'
}

pr_is_reviewable() {
  local state=$1 draft=$2 override=${3:-}
  { [ "$state" = OPEN ] && [ "$draft" = false ]; } || [ "$override" = 1 ]
}

validate_qodo_comment_page() {
  jq -e 'type == "array" and all(.[]; type == "object" and (.id | type == "number") and (.body | type == "string") and (.user | type == "object" and (.login | type == "string" and length > 0)) and (.html_url | type == "string" and length > 0))' >/dev/null
}

validate_qodo_checks_page() {
  jq -e 'type == "object" and (.total_count | type == "number" and . >= 0) and (.check_runs | type == "array") and all(.check_runs[]; type == "object" and (.id | type == "number") and (.name | type == "string" and length > 0) and (.status | type == "string" and length > 0) and ((.conclusion == null) or (.conclusion | type == "string")) and (.html_url | type == "string" and length > 0))' >/dev/null
}

qodo_comment_page_is_terminal() {
  jq -er 'length < 100' >/dev/null
}

qodo_checks_page_is_terminal() {
  local page=$1
  jq -er --argjson page "$page" '($page * 100) >= .total_count' >/dev/null
}

qodo_page_is_within_limit() {
  local page=$1 limit=$2
  [ "$page" -le "$limit" ]
}

qodo_checks_are_terminal() {
  jq -e 'all(.check_runs[]; ((.name | ascii_downcase | contains("qodo")) | not) or .status == "completed")' >/dev/null
}

index_records() {
  jq -c '.data.repository.pullRequest.reviewThreads.nodes[]? | .comments.nodes[0] as $c | {threadId:.id,commentId:$c.databaseId}'
}

capture_manifest_valid() {
  local dir=$1 prefix=$2 scope=$3 page_count n actual manifest
  manifest="$dir/manifest.json"
  page_count=$(jq -er --arg scope "$scope" 'if .scope == $scope and (.pageCount | type == "number" and . >= 1) and (.pages == [range(1; .pageCount + 1)]) then .pageCount else error("invalid capture manifest") end' "$manifest") || return 1
  actual=$(find "$dir" -maxdepth 1 -type f -name "$prefix-*.json" | wc -l) || return 1
  [ "$actual" -eq "$page_count" ] || return 1
  for ((n = 1; n <= page_count; n++)); do test -f "$(printf '%s/%s-%04d.json' "$dir" "$prefix" "$n")" || return 1; done
}

if page_info <<<'{}' >/dev/null 2>&1; then fail "malformed GraphQL response was accepted"; fi
if page_info <<<'{"errors":[{"message":"partial failure"}],"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}' >/dev/null 2>&1; then fail "GraphQL top-level errors were accepted"; fi
if page_info <<<'{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":null}}}}}}' >/dev/null 2>&1; then fail "missing continuation cursor was accepted"; fi
page_info <<<'{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}' | jq -e '.hasNextPage == false' >/dev/null || fail "terminal page was rejected"
empty_records=$(index_records <<<'{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}')
[ -z "$empty_records" ] || fail "empty review-thread page produced unexpected index records"
if page_info <<<'{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"thread","isResolved":false,"comments":{"nodes":[]}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}' >/dev/null 2>&1; then fail "partial root-comment node was accepted"; fi

pr_is_reviewable OPEN false || fail "open non-draft PR was rejected"
if pr_is_reviewable CLOSED false; then fail "closed PR was accepted without authorization"; fi
if pr_is_reviewable MERGED false; then fail "merged PR was accepted without authorization"; fi
if pr_is_reviewable OPEN true; then fail "draft PR was accepted without authorization"; fi
pr_is_reviewable CLOSED false 1 || fail "explicit non-open authorization was rejected"
pr_is_reviewable OPEN true 1 || fail "explicit draft authorization was rejected"

validate_qodo_comment_page <<<'[]' || fail "empty Qodo comment terminal page was rejected"
qodo_comment_page_is_terminal <<<'[]' || fail "empty Qodo comment page did not terminate capture"
validate_qodo_comment_page <<<'[{"id":1,"body":"finding","user":{"login":"qodo"},"html_url":"https://example.invalid/comment/1"}]' || fail "valid Qodo comment page was rejected"
hundred_comments=$(jq -cn '[range(0; 100) | {id: ., body: "finding", user: {login: "qodo"}, html_url: "https://example.invalid/comment"}]')
if qodo_comment_page_is_terminal <<<"$hundred_comments"; then fail "full Qodo comment page terminated multi-page capture"; fi
qodo_page_is_within_limit 100 100 || fail "last permitted Qodo page was rejected"
if qodo_page_is_within_limit 101 100; then fail "Qodo page cap was not enforced"; fi
if validate_qodo_comment_page <<<'[{"id":1,"body":"finding","user":null,"html_url":"https://example.invalid/comment/1"}]'; then fail "malformed Qodo comment page was accepted"; fi
if validate_qodo_comment_page <<<'{"message":"API rate limit exceeded"}'; then fail "Qodo issue-comment API error was accepted"; fi
validate_qodo_checks_page <<<'{"total_count":101,"check_runs":[{"id":1,"name":"Qodo","status":"completed","conclusion":"success","html_url":"https://example.invalid/check/1"}]}' || fail "valid Qodo checks page was rejected"
if qodo_checks_page_is_terminal 1 <<<'{"total_count":101,"check_runs":[]}'; then fail "first Qodo checks page terminated multi-page capture"; fi
qodo_checks_page_is_terminal 2 <<<'{"total_count":101,"check_runs":[]}' || fail "last Qodo checks page did not terminate capture"
qodo_checks_are_terminal <<<'{"check_runs":[{"name":"Qodo","status":"completed"}]}' || fail "terminal Qodo check was rejected"
if qodo_checks_are_terminal <<<'{"check_runs":[{"name":"Qodo","status":"in_progress"}]}'; then fail "non-terminal Qodo check was accepted as clean"; fi
if validate_qodo_checks_page <<<'{"total_count":1,"check_runs":[{"id":1,"name":"Qodo","status":null,"conclusion":"success","html_url":"https://example.invalid/check/1"}]}'; then fail "malformed Qodo checks page was accepted"; fi
if validate_qodo_checks_page <<<'{"message":"API rate limit exceeded"}'; then fail "Qodo checks API error was accepted"; fi

long_body=$(printf '%0601d' 0)
record=$(jq -cn --arg body "$long_body" '{body:($body[0:600]),bodyLength:($body|length),bodyTruncated:(($body|length)>600)}')
jq -e '.bodyLength == 601 and .bodyTruncated == true and (.body|length) == 600' <<<"$record" >/dev/null || fail "truncated finding was not marked"

index="$test_root/findings.ndjson"; complete="$test_root/complete"
: >"$index"; : >"$complete"
test -f "$index" && test -f "$complete" || fail "valid empty index is not restart-safe"

collection="$test_root/collection"; mkdir "$collection"
printf '{"scope":"threads:test","pageCount":2,"pages":[1,2]}\n' >"$collection/manifest.json"
printf '[]\n' >"$collection/page-0001.json"
printf '[]\n' >"$collection/page-0002.json"
capture_manifest_valid "$collection" page threads:test || fail "complete numbered page set was rejected"
rm "$collection/page-0001.json"
if capture_manifest_valid "$collection" page threads:test; then fail "missing first page was accepted for reuse"; fi
printf '[]\n' >"$collection/page-0001.json"
printf '[]\n' >"$collection/page-0003.json"
if capture_manifest_valid "$collection" page threads:test; then fail "orphan later page was accepted for reuse"; fi

git init -q -b main "$test_root/base"
git -C "$test_root/base" config user.email test@example.invalid
git -C "$test_root/base" config user.name test
git -C "$test_root/base" commit --allow-empty -qm base
base_sha=$(git -C "$test_root/base" rev-parse HEAD)
git clone -q "$test_root/base" "$test_root/fork"
git -C "$test_root/fork" config user.email test@example.invalid
git -C "$test_root/fork" config user.name test
printf 'head\n' >"$test_root/fork/changed.txt"
git -C "$test_root/fork" add changed.txt
git -C "$test_root/fork" commit -qm head
head_sha=$(git -C "$test_root/fork" rev-parse HEAD)
repo="$test_root/repo"; worktree="$test_root/worktree"
git init -q "$repo"
git -C "$repo" remote add review-base "$test_root/base"
git -C "$repo" remote add review-head "$test_root/fork"
git -C "$repo" fetch --no-tags review-base main:refs/remotes/review/base >/dev/null
git -C "$repo" fetch --no-tags review-head "$head_sha" >/dev/null
git -C "$repo" worktree add --detach "$worktree" "$head_sha" >/dev/null
verify_reuse() {
  test "$(git -C "$repo" remote get-url review-base)" = "$test_root/base" &&
    test "$(git -C "$repo" remote get-url review-head)" = "$test_root/fork" &&
    test "$(git -C "$repo" rev-parse refs/remotes/review/base)" = "$base_sha" &&
    test "$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)" = "$(git -C "$repo" rev-parse --path-format=absolute --git-dir)" &&
    ! git -C "$worktree" symbolic-ref -q HEAD >/dev/null &&
    test "$(git -C "$worktree" rev-parse HEAD)" = "$head_sha"
}
verify_reuse || fail "matching worktree was not reusable"
git -C "$worktree" reset --hard "$base_sha" >/dev/null
if verify_reuse; then fail "mismatched worktree was reusable"; fi

echo "PASS: state, malformed/cursor, Qodo pagination schemas, truncation, empty-index, and restart checks"
