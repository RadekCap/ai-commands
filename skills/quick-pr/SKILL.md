---
name: quick-pr
description: Run the commit, pull request, review, merge, and cleanup workflow for current repository changes.
---

Automate the full commit-to-merge workflow for the current changes in this repository.

Steps to perform:

1. Run `git status` and `git diff` to understand the current changes.
2. If there are no changes (staged or unstaged), tell the user "No changes to commit." and stop.
3. Create a new branch named `feature/<short-description>` based on the changes (derive the short description from the diff).
4. Stage all modified/added files and create a commit with a descriptive message. Include `Assisted-by: <current AI tool and model>` in the commit.
5. Push the branch to origin with `-u`.
6. Create a pull request using `gh pr create` with a concise title and a body containing only a `## Summary` section with bullet points. Do not include a Test plan section.
7. Merge the pull request using `gh pr merge --rebase`.
8. Switch back to main, pull latest, and delete the local feature branch.
9. Print the merged PR URL and confirm completion.

If any step fails, stop and report the error to the user.
