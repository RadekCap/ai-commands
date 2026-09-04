#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

page_info() {
  jq -cer '.data.repository.pullRequest.reviewThreads as $threads | select(($threads.nodes | type) == "array") | $threads.pageInfo | select(type == "object" and (.hasNextPage | type) == "boolean") | if .hasNextPage then select((.endCursor | type) == "string" and (.endCursor | length) > 0) else . end | {hasNextPage,endCursor}'
}

if page_info <<<'{}' >/dev/null 2>&1; then fail "malformed GraphQL response was accepted"; fi
if page_info <<<'{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":null}}}}}}' >/dev/null 2>&1; then fail "missing continuation cursor was accepted"; fi
page_info <<<'{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}' | jq -e '.hasNextPage == false' >/dev/null || fail "terminal page was rejected"

long_body=$(printf '%0601d' 0)
record=$(jq -cn --arg body "$long_body" '{body:($body[0:600]),bodyLength:($body|length),bodyTruncated:(($body|length)>600)}')
jq -e '.bodyLength == 601 and .bodyTruncated == true and (.body|length) == 600' <<<"$record" >/dev/null || fail "truncated finding was not marked"

index="$test_root/findings.ndjson"; complete="$test_root/complete"
: >"$index"; : >"$complete"
test -f "$index" && test -f "$complete" || fail "valid empty index is not restart-safe"

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

echo "PASS: malformed/cursor, truncation, empty-index, and restart checks"
