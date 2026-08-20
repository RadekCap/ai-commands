# CLAUDE.md

Global preferences for Claude Code across all projects.

## Communication preferences

- Never start responses with flattering or sycophantic phrases like "Great question!", "That's a fantastic idea!", "Absolutely!", "Nice idea!", etc. Just answer directly.
- Help me articulate technical issues clearly when I describe them
- Ask clarifying questions when my descriptions are ambiguous
- When I describe something, rephrase it back in clearer words so I can learn from the improved expression
- Pause before executing when clarification would help, and explain how I could express it more precisely next time
- Provide this kind of feedback regularly - it's welcomed and appreciated

<!--
## English and expression coaching (ALWAYS ACTIVE)

These instructions are mandatory in every session. Do not skip them.

### 1. Welcome message
At the very start of every conversation, before doing anything else, print:

---
**English & Expression coaching is active.**
I will help you improve your English and articulation throughout this session.
---

### 2. Mid-session feedback
Throughout the session, when the user writes a message:
- Rephrase unclear or awkward sentences into clearer English
- Point out spelling, grammar, or word choice improvements
- Format corrections as a short banner:

---
**Let's improve your English:**
You wrote: "[original]"
Better: "[improved version]"
Why: [brief explanation]
---

### 3. Tips during longer operations
When running longer operations (builds, tests, git workflows, multi-step tasks), use the waiting time to print an English improvement tip based on something the user said earlier in the session. Format as:

---
**English tip while we wait:**
[A specific tip about grammar, vocabulary, pronunciation, or expression based on the user's recent messages]
---

This is especially valuable because the user has time to read and reflect while waiting.

## Explanation skills coaching (ALWAYS ACTIVE)

These instructions are mandatory in every session. Do not skip them.

### 1. Welcome message
Include in the session welcome message:

---
**Explanation skills coaching is active.**
I will help you describe technical concepts more clearly and structure your thoughts better.
---

### 2. Mid-session feedback
When the user explains something (a bug, a requirement, a design decision) in a vague or unstructured way:
- Rephrase it back in a clearer, more structured form
- Show how to break complex ideas into logical steps
- Format as a banner:

---
**Let's sharpen your explanation:**
You said: "[original explanation]"
Clearer version: "[restructured explanation]"
Tip: [what made the original unclear and how the improved version fixes it — e.g., "Lead with the problem before describing the solution", "Be specific about what changed vs. what you expected"]
---

### 3. Tips during longer operations
When running longer operations, alternate between English tips and explanation tips. Format explanation tips as:

---
**Explanation tip while we wait:**
[A specific tip about structuring technical explanations, describing bugs, writing clear requirements, or communicating decisions — based on the user's recent messages]
---
-->

## Slash command progress banners

When executing a slash command (skill), print clear banners so the user can quickly see the state when scrolling:

- **At the start**, before any tool calls:
  ```
  ━━━ ▶ Running /command-name ━━━━━━━━━━━━━━━━━
  ```
- **At the end**, after all steps are complete:
  ```
  ━━━ ✔ Finished /command-name ━━━━━━━━━━━━━━━━
  ```

## Task execution discipline

Before executing any multi-step task or workflow:

1. **Restate understanding**: Briefly explain how you understood the user's instructions
2. **State your plan**: List what you're going to do (steps, tools, target repos)
3. **Stop and wait**: Do NOT make any tool calls, edits, or commands. End your message after steps 1–2 and wait for the user to explicitly confirm (e.g., "go", "yes", "proceed"). Silence or a new user message is not confirmation.

This applies to:
- Slash commands and skills (e.g., `/implement-issue`, `/prepare-worktree`)
- Any task involving multiple tools, git operations, or external API calls
- Work that spans multiple repositories or branches

**Skill invocation rule**: When the user references a skill or slash command by name, **always invoke it via the Skill tool**. Never read the skill file and manually approximate its steps — the skill exists precisely to ensure consistent execution. If you need to deviate from a skill's steps, explain why and get confirmation first.

## Git workflow

- Always create a feature branch and open a pull request for changes
- Never commit directly to main or master branches
- Before running `gh pr create`, always explicitly state which repo the PR will target — never rely on `gh` CLI defaults. Use `--repo owner/repo` every time.
- Never create a PR without explicit user approval. Always confirm the target repo and that the user wants the PR created before running `gh pr create`.

### Commit attribution (AI tools)

Red Hat's attribution policy records AI assistance with an `Assisted-by:` (or
`Generated-by:`) trailer — **not** `Co-Authored-By:`, which is flagged for AI
tools. This overrides Claude Code's built-in default of appending
`Co-Authored-By: Claude ...`.

- End AI-assisted commit messages with an attribution trailer of the form:
  `Assisted-by: Claude <model> <noreply@anthropic.com>`
  (e.g. `Assisted-by: Claude Opus 4.8 <noreply@anthropic.com>` — update the
  model name to whichever model produced the change).
- Do **not** use `Co-Authored-By:` for AI tools in any repository.
- Some repos enforce this automatically (e.g. `stolostron/*` via a CodeRabbit
  `ai-attribution` check in `.coderabbit.yaml`).

## Jira API access

Credentials are stored in `~/.claude/credentials.json` under the `jira` key. **Always** use this exact pattern:

```bash
CREDS=$(cat ~/.claude/credentials.json)
JIRA_EMAIL=$(echo "$CREDS" | jq -r '.jira.email')
JIRA_TOKEN=$(echo "$CREDS" | jq -r '.jira.token')
JIRA_BASE=$(echo "$CREDS" | jq -r '.jira.api_base')
# Then use: curl -s -u "${JIRA_EMAIL}:${JIRA_TOKEN}" "${JIRA_BASE}/issue/ARO-12345"
```

Rules:
- API version: **always v3** (`/rest/api/3/`). The base URL in credentials.json already includes this.
- Auth: HTTP Basic with `email:token` from the `.jira` object (NOT top-level keys).
- Search endpoint: `${JIRA_BASE}/search/jql?jql=...&fields=summary,status` (v3 search requires the `/jql` suffix).
- Fetch a single issue: `${JIRA_BASE}/issue/{KEY}?fields=summary,status,resolution,assignee,description`
- Default project: `ARO`, default component: `aro-hcp-capz`
- URL-encode JQL query parameters.
- Never guess credentials or try alternative auth methods — if credentials.json is missing, ask the user.
- Always add `-L` to curl commands (the instance may redirect).

## Jira issue creation rules

These rules apply when creating **any** Jira issue, regardless of project, source, or path used to trigger creation.

### Issue type

Use the correct type — never default to Story or Task:
- **Bug** — actual defects in your own code, unexpected behavior in production
- **Story** — planned deliverables with clear acceptance criteria
- **Task** — operational/reactive work: CI failures, security scan failures, CVE dependency updates, housekeeping, post-meeting actions
- **Spike** — time-boxed investigation or research

### Description (mandatory)

- **Always include a description.** Never create a Jira issue with an empty description field.
- If the source is a GitHub issue: fetch the full body (`gh issue view <n> --repo owner/repo --json title,body`) and use it as the description, appending `GitHub Issue: <url>`.
- If the source is a GitHub Actions workflow or URL: include the URL and a brief summary of why the issue is being tracked.
- If the source is a verbal or informal request: write a short description capturing the context before creating.
- If there is genuinely nothing to write: ask the user for content — never silently leave the description empty.

### Description structure (by issue type)

See full guidelines: [How We Use JIRA in ARO HCP](https://docs.google.com/document/d/1jLwHt00p5EyW4hYIUlDleQGh0K96UfZrmcp-BJ3BmaM)

**Epics** — must include all four sections:
- **Overview**: what this Epic is about and why it exists
- **Acceptance Criteria**: what "done" looks like
- **Definition of Done**: technical requirements (tests passing, docs, code rolled out)
- **References**: links to related tickets, PRs, docs

**Stories/Tasks/Bugs** — must include:
- What the work is and why it matters — written for someone who doesn't know you personally
- Link any related PRs or commits in a comment once work starts

### Progress updates (mandatory when work moves)

When a PR is merged or a significant commit lands related to a Jira ticket:
- Add a comment to the ticket with: PR link + one sentence on what changed
- Do not rely on the PR description alone — Jira and GitHub are separate audiences
- Add a short status comment when something meaningful moves (blocked, unblocked, scope change)

### Parent Epic (mandatory for Stories/Tasks/Bugs)

Always set the Epic Link field when creating a Story, Task, or Bug.
Never create standalone tickets without a parent Epic — they become orphans invisible in the plan view.
See full guidelines: [How We Use JIRA in ARO HCP](https://docs.google.com/document/d/1jLwHt00p5EyW4hYIUlDleQGh0K96UfZrmcp-BJ3BmaM)

### Default field values

Always set these fields on every new Jira issue. Never leave them unset.

| Field | Value | Notes |
|-------|-------|-------|
| Project | `ARO` | Azure Red Hat OpenShift |
| Components | `37592` | aro-hcp-capz |
| Security | `10034` | Red Hat Employee |
| Assignee | `5fabb5fdecdae600685b01d6` | rcap@redhat.com |
| Activity Type (`customfield_10464`) | `10608` | Quality / Stability / Reliability |
| Fix Version | `105810` | CAPZ-2026-Q3 — update when quarter changes |

JSON snippet for every `fields` block:
```json
"components": [{"id": "37592"}],
"security": {"id": "10034"},
"assignee": {"accountId": "5fabb5fdecdae600685b01d6"},
"customfield_10464": {"id": "10608"},
"fixVersions": [{"id": "105810"}]
```

### Safety rules

**Duplicate prevention (CRITICAL):**
- Before every write operation, review the conversation history to check if the same action was already performed (comments, labels, issue creation, field updates).
- When in doubt, ask the user rather than risk creating duplicates — duplicates in Jira are hard to clean up.
- If a POST call appears to fail, search for the resource before retrying to avoid duplicates.
- Never blindly retry a write operation — verify current state first.

**Write operations:**
- Always use `curl -s -w "\n%{http_code}"` with Basic auth for Jira write calls — never pipe through formatters like `python3 -m json.tool` that can mask the HTTP status code.

**Destructive actions:**
- NEVER delete Jira issues — use close or `/handle-jira-duplicates` instead.
- Never modify Jira issues without explicit user confirmation.
- When the user reports a problem (duplicates, wrong data), report findings and suggest actions — do not autonomously fix.
- Applies to all mutations: comments, status transitions, field updates.

**Subtask limitations:**
- Jira REST API does NOT support re-parenting subtasks via PUT (returns 204 but silently ignores the change).
- Jira REST API does NOT support converting subtasks to tasks (requires UI: Actions > Convert to Issue).
- To move subtasks: create new ones under the target parent, then clean up old ones.

### Visibility

Always check the issue's visibility before making changes. Use the same visibility level for comments, sub-tasks, and field updates. For API calls, include:

```json
"visibility": {"type": "group", "value": "<group-from-issue>"}
```

Common groups: `"Red Hat Employee"`, `"Red Hat Partner"`.

### Labels

Only two labels are allowed per ARO HCP Jira guidelines:
- `no-qe` — QE assumes testing is needed unless this label is present
- `good-first-issue` — marks items suitable for onboarding

Omit the field entirely for all other cases. Never add custom or ad-hoc labels.

### Transition IDs

Do NOT guess transition IDs — the numbering is not intuitive. Always use these exact values for the ARO project:

| ID | Status |
|----|--------|
| 11 | New |
| 21 | Refinement |
| 31 | Backlog |
| 41 | To Do |
| 51 | In Progress |
| 61 | Review |
| 71 | Closed |

If unsure, fetch available transitions first via `GET /rest/api/3/issue/{KEY}/transitions` before posting.

### Jira URL handling

When the user shares a Jira URL (`https://redhat.atlassian.net/browse/ARO-XXXXX`), always fetch it via the Jira REST API using credentials from `credentials.json`. Never use WebFetch for Jira URLs — it cannot authenticate and will fail.

## Destructive actions

- Never delete Azure resources without explicit confirmation
- When asked to "list", "check", or "show" resources, only report findings - do not take action
- Always ask before: deleting, force-deleting, removing, or cleaning up resources
- When listing resources that might need cleanup, present findings and wait for user instruction
