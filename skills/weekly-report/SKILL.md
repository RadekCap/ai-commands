---
name: weekly-report
description: Generate a weekly status report from GitHub and Jira activity, formatted for Slack
---

# Weekly Report

Generate a weekly status report by gathering activity from GitHub (PRs, issues) and Jira, then format it for pasting into Slack.

## Usage

```
/weekly-report
```

Optionally provide a date range:
```
/weekly-report 2026-03-24
```

If no start date is provided, default to 7 days ago.

## Data Sources

### GitHub

Search across ALL relevant orgs and repos — not just the current repo. The user's work spans `stolostron/`, `openshift/`, and personal `RadekCap/` repos.

1. **Merged PRs** — Search across all orgs using the GitHub search API:
   ```bash
   # stolostron org
   gh api search/issues --method GET \
     -f "q=author:RadekCap type:pr is:merged merged:>=$START_DATE org:stolostron" \
     --jq '.items[] | {url: .html_url, title: .title, merged_at: .closed_at}'

   # openshift org
   gh api search/issues --method GET \
     -f "q=author:RadekCap type:pr is:merged merged:>=$START_DATE org:openshift" \
     --jq '.items[] | {url: .html_url, title: .title, merged_at: .closed_at}'
   ```
   Run both in parallel. Exclude Obsidian vault session summary PRs from the report.

2. **Open PRs** — Search across all orgs:
   ```bash
   gh search prs --author=RadekCap --state=open \
     --json repository,number,title,url --limit 20
   ```
   Exclude personal forks (RadekCap/capi-tests etc.) unless they have no upstream equivalent.

3. **GHA Workflow Status** — Check deployment workflow results in the capi-tests repo:
   ```bash
   gh run list --repo stolostron/capi-tests --workflow "Full Cluster Deployment (ARO)" --limit 3 --json status,conclusion,createdAt
   gh run list --repo stolostron/capi-tests --workflow "Full Cluster Deployment (ROSA)" --limit 3 --json status,conclusion,createdAt
   ```

### Jira

Read credentials from `credentials.json` in the project root:
```bash
EMAIL=$(python3 -c "import json; d=json.load(open('credentials.json')); print(d['jira']['email'])")
TOKEN=$(python3 -c "import json; d=json.load(open('credentials.json')); print(d['jira']['token'])")
```

**IMPORTANT**: Use the v3 search API — v2 search has been removed by Atlassian:

1. **Resolved JIRAs** — Issues resolved in the date range:
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+component=%22aro-hcp-capz%22+AND+statusCategory=Done+AND+resolved+%3E%3D+%22$START_DATE%22+ORDER+BY+resolved+DESC&maxResults=30&fields=key,summary,status,resolution"
   ```

2. **Open/In-Progress JIRAs** — Active issues:
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+component=%22aro-hcp-capz%22+AND+assignee=5fabb5fdecdae600685b01d6+AND+statusCategory+!=+Done+ORDER+BY+priority+DESC&maxResults=30&fields=key,summary,status"
   ```

Note: Individual issue GET still works on v2 (`/rest/api/2/issue/ARO-XXXXX`). Only JQL search requires v3.

### Weekly Notes (Manual Highlights)

Read `050 Inbox/weekly-notes.md` from the Obsidian vault. This file contains manually added notes — context, achievements, and items that don't appear in GitHub or Jira. These become the **Highlights** section at the top of the report.

After the report is confirmed by the user, clear the `## Notes` section of this file (keep the frontmatter and description intact).

### External PRs

The cross-org GitHub search above covers stolostron and openshift orgs automatically.
If there are additional repos to check (from conversation context or memory), search those explicitly.

## Output Format

Format the output for **Slack copy-paste** — use Slack emoji syntax and full URLs (not markdown links, as those get lost when pasting):

```
*Highlights* :star:
- Item from weekly-notes (context not captured by GitHub/Jira)

*Done* :white_check_mark:

*<Headline achievement>* — brief description

*GHA Deployment Workflows* — Both passing on main
- Full Cluster Deployment (ARO) — :white_check_mark: success
- Full Cluster Deployment (ROSA) — :white_check_mark: success

*Merged PRs*
- <https://github.com/org/repo/pull/NNN|repo#NNN> — title
- <https://github.com/org/repo/pull/NNN|repo#NNN> — title

*Closed JIRAs*
- <https://issues.redhat.com/browse/ARO-XXXXX|ARO-XXXXX> — title
- <https://issues.redhat.com/browse/ARO-XXXXX|ARO-XXXXX> — title

*In progress* :soon:

*<Current focus area>* — brief description

*Open PRs*
- <https://github.com/org/repo/pull/NNN|repo#NNN> — title
- <https://github.com/org/repo/pull/NNN|repo#NNN> — title

*JIRAs In Progress*
- <https://issues.redhat.com/browse/ARO-XXXXX|ARO-XXXXX> — title
- <https://issues.redhat.com/browse/ARO-XXXXX|ARO-XXXXX> — title

*Next* :soon:

- Item 1
- Item 2

*Blockers* :warning:
- None currently
```

## Formatting Rules

1. **Use Slack named links** for PRs — `<https://github.com/org/repo/pull/NNN|repo#NNN>` (e.g., `<https://github.com/stolostron/capi-tests/pull/712|capi-tests#712>`). This renders as a clickable label.
2. **Use Slack named links for JIRAs** — `<https://issues.redhat.com/browse/ARO-XXXXX|ARO-XXXXX>` (renders as clickable "ARO-XXXXX").
3. **Use Slack bold** — `*bold*` not `**bold**`
4. **Use Slack emoji** — `:white_check_mark:`, `:soon:`, `:warning:`
5. **Group dependabot/automated PRs** — list them on one line with all URLs comma-separated
6. **Separate manual PRs** — one per line with description
7. **Keep descriptions short** — one line per item
8. **Highlight key achievements** — lead with the most important accomplishment

## Steps

1. **Determine date range**
   - Use provided start date or default to 7 days ago
   - Calculate: `date -d '7 days ago' +%Y-%m-%d`

2. **Read weekly notes**
   - Read `050 Inbox/weekly-notes.md` from the Obsidian vault (path relative to the vault root)
   - Extract bullet points from the `## Notes` section
   - These become the *Highlights* section at the top of the report
   - If the file is empty or has no notes, skip the Highlights section

3. **Read previous report for dedup**
   - Find the most recent file in `Diary/Weekly/` (sorted by filename)
   - Read its content and extract: Highlights, Done items (PRs, JIRAs), In Progress items
   - Use this to detect duplicates in step 6 — if a highlight, PR, or JIRA already appeared in the previous report, flag it and exclude it from the new report
   - If items from `weekly-notes.md` already appeared in the previous report's Highlights, exclude them and notify the user (e.g., "Excluded duplicate highlight: ...")

4. **Gather GitHub data**
   - Search merged PRs across stolostron and openshift orgs (in parallel)
   - Search open PRs across all orgs
   - Fetch GHA workflow status from stolostron/capi-tests

5. **Gather Jira data**
   - Read credentials from `credentials.json`
   - Fetch resolved and open issues via v3 search API

6. **Check previous status** (from step 3)
   - Compare with previous "Next" items to track continuity
   - Carry forward items that are still in progress

7. **Compose the report**
   - Follow the output format above — lead with Highlights from weekly notes
   - Exclude any items flagged as duplicates in step 3
   - Print the report to the terminal
   - Wait for user confirmation or edits before considering done

8. **Clear weekly notes**
   - After the user confirms the report, clear the `## Notes` section in `050 Inbox/weekly-notes.md`
   - Keep the frontmatter and description header intact

9. **Remind to save report**
   - After the user confirms the report, remind them:
     "Save this report to `Diary/Weekly/YYYY-MM-DD Weekly Summary.md`? (This keeps history for future dedup.)"
   - If the user confirms, save the report as a markdown file with frontmatter:
     ```yaml
     ---
     title: "Weekly Summary: <date range>"
     type: source
     tags: [weekly-summary, capz, capi-tests]
     created: YYYY-MM-DD
     ---
     ```
   - Convert the Slack format to markdown for the saved file (e.g., `*bold*` → `**bold**`, Slack emoji → text equivalents or remove)

## Tips

- If Jira search returns 0 results unexpectedly, check if the API token needs regeneration
- The "Next" section often carries forward between weeks — check memory for previous status
- GHA workflows may show "cancelled" for no-change runs — note this as grey/cancelled, not failure
