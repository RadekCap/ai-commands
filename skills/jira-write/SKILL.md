---
name: jira-write
description: Use when creating, editing, transitioning, or commenting on any Jira issue. Contains mandatory field values, issue-type selection, description structure, transition IDs, visibility groups, label rules, and duplicate-prevention safety rules for the ARO project.
---

# Jira write operations

These rules apply when creating or modifying **any** Jira issue, regardless of
project, source, or path used to trigger creation.

## Credentials

```bash
CREDS=$(cat ~/.claude/credentials.json)
JIRA_EMAIL=$(echo "$CREDS" | jq -r '.jira.email')
JIRA_TOKEN=$(echo "$CREDS" | jq -r '.jira.token')
JIRA_BASE=$(echo "$CREDS" | jq -r '.jira.api_base')
# Then: curl -sL -u "${JIRA_EMAIL}:${JIRA_TOKEN}" "${JIRA_BASE}/issue/ARO-12345"
```

- API version: **always v3** (`/rest/api/3/`). The base URL already includes it.
- Auth: HTTP Basic with `email:token` from the `.jira` object (NOT top-level keys).
- Search: `${JIRA_BASE}/search/jql?jql=...&fields=summary,status` (v3 requires `/jql`).
- Fetch one: `${JIRA_BASE}/issue/{KEY}?fields=summary,status,resolution,assignee,description`
- URL-encode JQL query parameters. Always use `-L` (the instance redirects).
- Never guess credentials or try alternative auth — if credentials.json is missing, ask.

## Issue type

Use the correct type — never default to Story or Task:
- **Bug** — actual defects in your own code, unexpected behavior in production
- **Story** — planned deliverables with clear acceptance criteria
- **Task** — operational/reactive work: CI failures, security scan failures, CVE dependency updates, housekeeping, post-meeting actions
- **Spike** — time-boxed investigation or research

## Description (mandatory)

- **Always include a description.** Never create a Jira issue with an empty description field.
- If the source is a GitHub issue: fetch the full body (`gh issue view <n> --repo owner/repo --json title,body`) and use it as the description, appending `GitHub Issue: <url>`.
- If the source is a GitHub Actions workflow or URL: include the URL and a brief summary of why the issue is being tracked.
- If the source is a verbal or informal request: write a short description capturing the context before creating.
- If there is genuinely nothing to write: ask the user for content — never silently leave the description empty.

### Structure by issue type

See full guidelines: [How We Use JIRA in ARO HCP](https://docs.google.com/document/d/1jLwHt00p5EyW4hYIUlDleQGh0K96UfZrmcp-BJ3BmaM)

**Epics** — must include all four sections:
- **Overview**: what this Epic is about and why it exists
- **Acceptance Criteria**: what "done" looks like
- **Definition of Done**: technical requirements (tests passing, docs, code rolled out)
- **References**: links to related tickets, PRs, docs

**Stories/Tasks/Bugs** — must include:
- What the work is and why it matters — written for someone who doesn't know you personally
- Link any related PRs or commits in a comment once work starts

## Parent Epic (mandatory for Stories/Tasks/Bugs)

Always set the Epic Link field when creating a Story, Task, or Bug.
Never create standalone tickets without a parent Epic — they become orphans
invisible in the plan view.

## Default field values

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

## Transition IDs

Do NOT guess transition IDs — the numbering is not intuitive. Always use these
exact values for the ARO project:

| ID | Status |
|----|--------|
| 11 | New |
| 21 | Refinement |
| 31 | Backlog |
| 41 | To Do |
| 51 | In Progress |
| 61 | Review |
| 71 | Closed |

If unsure, fetch available transitions first via
`GET /rest/api/3/issue/{KEY}/transitions` before posting.

## Visibility

Always check the issue's visibility before making changes. Use the same
visibility level for comments, sub-tasks, and field updates:

```json
"visibility": {"type": "group", "value": "<group-from-issue>"}
```

Common groups: `"Red Hat Employee"`, `"Red Hat Partner"`.

## Labels

Only two labels are allowed per ARO HCP Jira guidelines:
- `no-qe` — QE assumes testing is needed unless this label is present
- `good-first-issue` — marks items suitable for onboarding

Omit the field entirely for all other cases. Never add custom or ad-hoc labels.

## Progress updates (mandatory when work moves)

When a PR is merged or a significant commit lands related to a Jira ticket:
- Add a comment to the ticket with: PR link + one sentence on what changed
- Do not rely on the PR description alone — Jira and GitHub are separate audiences
- Add a short status comment when something meaningful moves (blocked, unblocked, scope change)

## Safety rules

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
