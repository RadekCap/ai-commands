---
name: implement-issue
description: Use when implementing a focused fix for one GitHub issue or Jira ticket and preparing its pull request.
---

# Implement Issue

Usage: `/implement-issue <github-number|JIRA-KEY>`

## Workflow

1. Validate the identifier. Fetch the issue with the appropriate authenticated CLI or API, following repository instructions. Summarize requirements, acceptance criteria, status, and relevant links; do not echo the complete issue unless needed.

2. Read applicable repository instructions. Use targeted searches to inspect only relevant code and tests. For ambiguous or non-trivial work, state a concise implementation and verification plan and obtain any confirmation required by repository policy.

3. Follow the repository's worktree and branch policy. Preserve unrelated local changes. Implement the smallest change that satisfies the issue, follows local conventions, and includes tests when appropriate.

4. Run the narrowest relevant formatter and verification commands. Diagnose failures from evidence. Stop and ask before repeating a failure without a new hypothesis or expanding the test scope.

5. Report the changed files and actual verification results. Obtain explicit approval before Jira mutations, including status changes, remote-link changes, description edits, or comments. Approval to commit, push, or create a PR does not automatically approve Jira mutations.

6. When approved, create a focused commit and pull request. Reference the issue, use the repository PR template, derive AI attribution from the active runtime, and stage explicit files only; never use `git add .`.

## Jira Workflow

For Jira-backed issues, use this sequence:

1. Start implementation: after the user approves implementation, obtain
   separate approval for the Jira status change, then transition the issue to
   `In Progress` and verify it before changing code.
2. After creating the PR: re-read the issue's current status, description,
   formal remote links, and visibility. For every PR, ensure it appears in both
   places:
   - Add a formal Jira web link if that PR URL is not already present.
   - Add a clickable PR link to a `Pull requests` section in the issue
     description if it is not already present. Preserve the existing
     description and update that section idempotently; use the Jira v3
     description format rather than replacing the description with plain text.
3. Re-read the issue and verify every PR appears as both a formal web link and
   in the description. A Jira comment may supplement these links when requested
   or required by repository instructions, but a comment never substitutes for
   either destination.
4. After both link destinations are verified, re-read the issue status. If it
   is not already `Review`, transition it to `Review`; verify the final status.

Before post-PR Jira mutations, show the exact PR URLs and the planned
description, web-link, comment, and status changes, then obtain explicit
approval. One approval may cover the listed mutations. Approval to commit,
push, or create a PR does not automatically approve Jira mutations. Check the
issue's existing description and links before updating them to prevent
duplicates. Preserve the issue's visibility for every mutation. Do not show a
finished/completion banner while an approved Jira action is pending; report it
as pending and obtain explicit approval, or record that the user declined it.

## Quality and efficiency

- Read before editing and follow existing patterns.
- Keep the change limited to the issue; do not claim checks that were not run.
- Prefer targeted searches, concise progress updates, and summaries over full command output or logs.
- Repository instructions are authoritative for Jira authentication, visibility, mutations, status changes, and PR or issue interactions.
