---
name: review-security
description: Use when a user asks the Security Review subagent to review local changes, a named branch, or a GitHub pull request.
---

# Review Security

For a PR URL or number, use **REQUIRED SUB-SKILL: github-pr-review-protocol** first; launch Security Review against its SHA-pinned worktree. For local changes, use the active repository without creating a PR manifest. Default to `branch changes`; use `uncommitted changes` only when explicitly requested.

Launch exactly one foreground `security-review` subagent with `Full Repository Path`, `Diff`, and only an explicit `Base Branch` or `Custom Instructions` when applicable. For a target PR or branch, ensure the target is checked out safely; never stash without user approval. Retry one malformed or failed invocation once.

Do not fix or rerun findings without permission. Report no diff/no issues in one sentence, otherwise use the protocol’s compact finding table.
