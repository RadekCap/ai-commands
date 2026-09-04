---
name: ai-review
description: Use when a pull request needs the complete self-review, security, CodeRabbit, and Qodo review-and-resolution pipeline.
---

# AI review pipeline

Use **REQUIRED SUB-SKILL: github-pr-review-protocol** first. It owns PR resolution, manifest storage, fork-aware SHA-pinned checkout, size classification, excerpts, and compact findings.

1. Rename the chat to `#<PR_NUMBER> · <title>` when supported, then print the protocol header.
2. Self-review the classified, targeted change set for correctness, regressions, missing tests, and repository-instruction violations. Fix valid findings in separate commits, test, and push.
3. Perform the same targeted pass for injection, authz/authn, secrets, unsafe file access, insecure defaults, dependency risk, and privileged workflow changes. State if a provider-specific security scanner is unavailable; do not silently skip the review. Commit and push valid fixes separately.
4. For at most five rounds, wait for CodeRabbit’s completed summary and stable inline threads. Store the summary and paginated threads locally. Process unresolved actionable CodeRabbit findings via the protocol transaction. Check failed pre-merge checks in the summary too: fix valid failures or post a concise false-positive rationale. If an accepted finding was pushed, wait for the incremental review; otherwise exit the loop. Dismiss a stale CodeRabbit `CHANGES_REQUESTED` review only after every finding is addressed.
5. Use the protocol's bounded Qodo issue-comment and checks captures, then fetch and store Qodo inline root comments and its latest issue summary. Do not call Qodo clean when either capture is incomplete, malformed, capped, or errored. Process Qodo after CodeRabbit; reply that an overlapping finding was already addressed with its commit SHA. Qodo threads cannot be resolved programmatically, so an inline reply is the resolution signal.
6. Post one compact pipeline summary comment, including counts by source, accepted/denied/duplicate findings, unresolved reply failures, and the protocol header. Always post it, including a clean result.
7. If review commits changed the PR, draft an updated PR description from the PR template and current diff, preserve issue links, show it to the user, and edit the PR body only after approval. Finish with an intent-versus-implementation check.

Every finding receives a disposition and a direct reply. Keep one commit per accepted external finding, include the repository-required AI attribution, and stop on push conflicts or manifest/worktree failures.
