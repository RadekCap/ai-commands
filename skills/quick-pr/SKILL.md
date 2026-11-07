---
name: quick-pr
description: Commit, push, merge, and sync all pending local work in the current repository.
---

Automate the full commit-to-merge workflow for pending local work in the current checkout. Pending work includes uncommitted changes and commits on the current branch that are not yet merged into the remote base branch.

Steps to perform:

1. Inspect `git status`, staged and unstaged diffs, the current branch and its upstream, and commits on the current branch that are not in the remote base branch. If the current branch has an open PR, inspect its state too. When the branch has no upstream, use the repository's remote base branch (normally `origin/main`) for comparison.
2. Stop with "Already synced with GitHub." only when the working tree is clean, there are no current-branch commits pending merge, there is no open PR to finish, and local `main` is synced with `origin/main`. A clean working tree alone is not a reason to stop.
3. Reuse the current branch if it already contains pending work. If pending commits are on `main`, create a `feature/<short-description>` branch at the current HEAD so they can go through a PR. If uncommitted work is on `main`, create a feature branch before committing. Derive the short description from the diff or commit messages. If there is no pending work and local `main` is only behind `origin/main`, fast-forward `main` and skip the PR steps.
4. Stage and commit only when there are uncommitted changes. Include all intended modified and added files, use a descriptive commit message, and include `Assisted-by: <current AI tool and model>`. If the work is already committed, do not create a duplicate commit.
5. Push the feature branch to origin with `-u`. If the branch already has an open PR, continue with that PR rather than creating a duplicate.
6. If no PR exists for the branch, create one using `gh pr create` with a concise title and a body containing only a `## Summary` section with bullet points. Do not include a Test plan section.
7. Merge the PR using `gh pr merge --rebase`.
8. After merging (or fast-forwarding a behind-only `main`), switch to `main`, pull the latest remote changes with rebase, and delete the local feature branch after the merge.
9. Verify the working tree is clean and local `main` matches `origin/main`. Print the merged PR URL and confirm completion.

If any step fails, stop and report the error to the user.
