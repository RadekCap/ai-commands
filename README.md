# AI Commands

Shared Agent Skills, hooks, and settings for Claude Code, Codex, and Gemini across repositories and machines.

## TL;DR

### A. New computer

```bash
git clone git@github.com:RadekCap/ai-commands.git ~/git/ai-commands
cd ~/git/ai-commands
./setup.sh
```

### B. Already set up, just need to update

Nothing to do — updates are pulled automatically at the start of every Claude Code session.

---

## What you get

| What | How it works |
|---|---|
| Shared Agent Skills | Canonical workflows under `skills/<name>/SKILL.md` |
| Claude commands (`/cleanup`, `/sync-main`, etc.) | Skills linked into `~/.claude/skills/`; legacy command links remain compatible |
| Codex skills (`$cleanup`, `$sync-main`, etc.) | Skills linked into `~/.agents/skills/` |
| Global instructions (coaching, git rules) | `~/.claude/CLAUDE.md` symlinked to this repo |
| Hooks (PR confirmation, session resume, auto-sync) | Paths in `~/.claude/settings.json` |
| Status line (model, dir, branch, cost) | `~/.claude/statusline.sh` |

## Included commands

| Command | What it does |
|---|---|
| `/sync-main` | Sync main with remote, optionally create feature branch |
| `/cleanup` | Update main, delete all other local branches |
| `/implement-issue <number>` | Analyze a GitHub issue and create a PR |
| `/prepare-worktree <number>` | Create isolated git worktree for an issue |
| `/close-worktree <number>` | Clean up worktree after PR merge |
| `/copilot-review <pr>` | Process GitHub Copilot review findings |
| `/context` | Show current directory, branch, and todos |
| `/obsidian-summarize-session` | Summarize Claude Code session as an Obsidian note |
| `/obsidian-summarize-meeting` | Capture meeting notes as an Obsidian note with diary link |
| `/obsidian-summarize-pr` | Summarize a GitHub PR as an Obsidian note |
| `/obsidian-export` | Export a topic/brainstorm to an Obsidian note |
| `/obsidian-search` | Search Obsidian vault and summarize findings |

## Included hooks

| Hook | Trigger | What it does |
|---|---|---|
| `require-confirmation-before-pr.sh` | Before `gh pr create` | Forces Claude to show PR description and ask for approval |
| `obsidian-auto-approve.sh` | Before Bash/Write/Edit | Auto-approves operations scoped to `$OBSIDIAN_VAULT` (no-op if unset) |
| `on-resume.sh` | Session resume | Shows directory and branch context |
| `sync-shared-commands.sh` | Every session start | Auto-pulls this repo from GitHub |

## Adding a new shared skill

1. Create `skills/your-skill/SKILL.md` using the Agent Skills format.
2. Optionally add a root `your-skill.md` symlink for older Claude Code installations.
3. Run `./setup.sh` once on each machine to create the Claude and Codex links.
4. Commit and push. Subsequent content updates flow through the symlinks.

## How auto-sync works

Every Claude Code session runs `git pull --ff-only` on this repo. If you pushed changes from another machine, they're picked up automatically. If offline, it silently skips.
