---
name: prow-stop
description: Check Prow-related branches for unpushed commits before switching computers.
---

Run when STOPPING work on Prow CI branches before switching computers. Check if any branches have unpushed commits.

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
- Compare local vs remote using `git rev-list --count <remote>/<branch>..HEAD`
- If the local branch is AHEAD of remote: report it as a problem - "X unpushed commit(s)!"
- If no remote tracking branch exists: report as a problem - "no remote tracking"
- If they match: report OK

At the end:
- If any branches have unpushed commits, warn: "Push your changes before switching computers!"
- If all OK: "All branches pushed. Safe to stop."

Skip any repos, worktrees, or branches that don't exist on this machine.
