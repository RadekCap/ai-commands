---
name: prow-start
description: Check Prow-related branches for stale local state before beginning work on another computer.
---

Run when STARTING work on Prow CI branches from a new computer. Fetch remotes and check if local branches are behind remote.

Check these branches across two repositories:

1. **capi-tests** worktrees (check `~/git/capi-tests-configure-prow` and `~/git/capi-tests-configure-prow-mgmt`):
   - `configure-prow` — worktree at `~/git/capi-tests-configure-prow`, tracks `upstream`
   - `configure-prow-mgmt` — worktree at `~/git/capi-tests-configure-prow-mgmt`, tracks `upstream`

2. **openshift/release** repo (find it - check `~/git/release` or `~/git/github/openshift/release`):
   - `stolostron-capi-tests-ci`
   - `stolostron-capi-tests-ci-mgmt`

For capi-tests worktrees: `cd` into each worktree directory, run `git fetch upstream`, then compare against `upstream/<branch>`.
For openshift/release: run `git fetch origin`, then compare against `origin/<branch>`.

For each branch/worktree that exists:
- Compare local vs remote using `git rev-list --count HEAD..<remote>/<branch>`
- If the local branch is BEHIND remote: report it as a problem - "X commits behind, pull first!"
- If the local branch is ahead of remote: that's fine, just note it
- If they match: report OK

At the end:
- If any branches are behind remote, warn: "Pull stale branches before making changes!"
- If all OK: "All branches up to date. Safe to start."

Skip any repos, worktrees, or branches that don't exist on this machine.
