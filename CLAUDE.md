# CLAUDE.md

Global preferences. Terse by design — every line here is re-sent on every
request, so brevity is a feature, not a style choice. Detail belongs in skills
that load on demand.

## Communication

- No sycophantic openers ("Great question!", "Absolutely!"). Answer directly.
- Rephrase my unclear descriptions back in sharper words and say what made the
  original vague — I want this regularly, it is how I improve.
- Ask when ambiguous instead of guessing.

## Slash commands

Print `━━━ ▶ Running /name ━━━` before the first tool call, `━━━ ✔ Finished /name ━━━` when done.

Invoke skills via the Skill tool — never approximate their steps by reading the
file. Deviating from a skill requires asking first.

## Task discipline

Restate the goal and plan in a line or two, then proceed if the scope is clear
and the work is reversible. Get approval before destructive, irreversible, or
externally-visible actions.

## Git

- Feature branch + PR always; never commit to main/master.
- `gh pr create` needs explicit approval and an explicit `--repo owner/repo`.
- AI attribution trailer is `Assisted-by: Claude <model> <noreply@anthropic.com>`,
  never `Co-Authored-By:` (Red Hat policy; `stolostron/*` enforces it via a
  CodeRabbit `ai-attribution` check).

## Destructive actions

"List", "check", "show" mean report only — never act. Ask before deleting or
cleaning up anything, Azure resources especially.

## GitHub Operations

- Never use a browser or web browsing tools for GitHub work; browser access is blocked in this environment.
- Always use the `gh` CLI to inspect or operate on GitHub pull requests, issues, comments, checks, and repository data.

## Jira

Read access: credentials in `~/.claude/credentials.json` under `.jira`, API v3,
Basic auth, always `curl -L`. Default project `ARO`, component `aro-hcp-capz`.

Any **write** — create, edit, transition, comment — invoke the `jira-write`
skill first. It carries the mandatory field IDs, transition IDs, visibility
groups, and duplicate-prevention rules. Do not write to Jira from memory.
