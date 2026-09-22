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

5. Report the changed files and actual verification results. Obtain separate approval before Jira status changes or remote-link mutations; approval to commit, push, or create a PR does not automatically approve Jira mutations.

6. When approved, create a focused commit and pull request. Reference the issue, use the repository PR template, derive AI attribution from the active runtime, and stage explicit files only; never use `git add .`.

## Jira Workflow

For Jira-backed issues, use this sequence:

1. Start implementation: after the user approves implementation, transition
   the issue to `In Progress` and verify the transition before changing code.
2. After creating the PR: re-read the issue's current status and formal remote
   links. If the PR is not already linked, add it as a formal Jira web link.
3. After the PR link is added, transition the issue to `Review` and verify the
   final status.

Request explicit approval for the relevant Jira mutations. Approval to commit,
push, or create a PR does not automatically approve Jira mutations. Check the
issue's existing links before adding the PR to prevent duplicates. Do not show
a finished/completion banner while an approved Jira action is pending; report
it as pending and obtain explicit approval, or record that the user declined it.

## Quality and efficiency

- Read before editing and follow existing patterns.
- Keep the change limited to the issue; do not claim checks that were not run.
- Prefer targeted searches, concise progress updates, and summaries over full command output or logs.
- Repository instructions are authoritative for Jira authentication, visibility, mutations, status changes, and PR or issue interactions.
