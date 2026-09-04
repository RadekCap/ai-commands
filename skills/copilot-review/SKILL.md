---
name: copilot-review
description: Use when processing GitHub Copilot review findings on a pull request and replying to or resolving each finding.
---

# Copilot review

Use **REQUIRED SUB-SKILL: github-pr-review-protocol** first. It resolves any PR URL or number, creates the SHA-pinned worktree, and stores the paginated thread response locally.

If no PR argument was supplied, ask the user for the PR number before invoking the protocol.

Filter unresolved root review threads whose original author is Copilot. For each finding, inspect only the comment and its targeted excerpt, then accept or deny it using the protocol transaction. Accepted findings get a focused implementation, relevant test, one commit, push, direct reply, and verified thread resolution. Denied findings get a specific direct reply and verified resolution. Preserve the existing rule: security fixes should normally be accepted unless a concrete constraint makes them invalid.

End with the compact findings table and counts for accepted, denied, already-resolved, reply failures, and resolution failures. Do not use general PR review comments when a direct thread reply is available, and do not modify code or rerun review unless the user asked to process the findings.
