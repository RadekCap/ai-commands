---
name: daily-summary
description: Generate an end-of-day summary of work across all tracked projects and Jira, formatted for terminal review, then optionally save to Obsidian daily note
---

# Daily Summary

Generate a daily work summary by gathering activity from GitHub (PRs, issues, reviews, commits) and Jira across all tracked projects. Display it in the terminal grouped by project area for review, then offer to save it to the Obsidian daily note with proper links.

## Usage

```
/daily-summary
```

A date can be passed as argument to skip the interactive prompt:
```
/daily-summary 2026-04-03
```

## Step 0: Date Selection

If no date argument is provided, prompt the user interactively:

```
Which day would you like to summarize?
  1. Today (2026-04-05, Saturday)
  2. Yesterday (2026-04-04, Friday)
  3. Enter a custom date

Choose [1/2/3]:
```

- **Option 1**: Use today's date
- **Option 2**: Use yesterday's date
- **Option 3**: Ask for a date in `YYYY-MM-DD` format, validate it

If a date argument was passed (e.g., `/daily-summary 2026-04-03`), skip this prompt and use it directly.

Calculate the day-of-week for the header:
```bash
date -j -f '%Y-%m-%d' '$DATE' '+%A'   # macOS
```

## Tracked Projects

These are the project areas to report on. Each maps to one or more GitHub repos:

| Area | Repos | Description |
|------|-------|-------------|
| CAPI Tests | `RadekCap/capi-tests` | CAPZ/ROSA end-to-end test suite |
| OpenShift CI | `openshift/release` | Prow job definitions, CI config |
| Sippy | `openshift/sippy` | Test reporting and analysis |
| ASO | `stolostron/azure-service-operator` | Azure Service Operator (downstream) |
| CAPZ | `stolostron/cluster-api-provider-azure` | Cluster API Provider Azure (downstream) |
| Cluster API Installer | `stolostron/cluster-api-installer` | CAPI installer tooling |

**Evolving this list**: The user may add or remove areas over time. When they mention a new repo area, suggest updating this table.

### Jira-to-Area Mapping

Jira tickets are assigned to project areas using **keyword matching** on the ticket summary. Match against these keywords (case-insensitive):

| Area | Keywords |
|------|----------|
| CAPI Tests | `capi-tests`, `capi tests`, `test suite`, `e2e test` |
| OpenShift CI | `openshift ci`, `prow`, `ci step`, `ci wrapper`, `openshift/release` |
| Sippy | `sippy` |
| ASO | `aso`, `azure-service-operator`, `azure service operator` |
| CAPZ | `capz`, `cluster-api-provider-azure` |
| Cluster API Installer | `cluster-api-installer`, `capi installer` |
| ACM Train | `sprint`, `acm`, `train`, `post-upgrade`, `pre-upgrade` |

**Rules**:
- A ticket can match **multiple areas** if its summary contains keywords from more than one (e.g., "Add Dependency Review to capi-tests, ASO" → appears under both **CAPI Tests** and **ASO**)
- Tickets that match **no area** go into an **"Other"** section at the bottom
- The keyword list evolves — when a ticket falls into "Other" and clearly belongs to an area, suggest adding a keyword

**Evolving this list**: When tickets consistently land in "Other" but belong to a known area, suggest adding keywords to this table.

## Data Sources

### GitHub — Per Repo

For each tracked repo, gather the following. Run all repos in parallel for speed.

**IMPORTANT**: Use `--repo owner/repo` to query without changing directory.

1. **PRs created or updated on that day** (authored by the user):
   ```bash
   gh pr list --repo $REPO --author @me --state all --search "updated:>=$DATE" --json number,title,url,state,updatedAt --limit 20
   ```

2. **PRs merged on that day**:
   ```bash
   gh pr list --repo $REPO --author @me --state merged --search "merged:>=$DATE" --json number,title,url,mergedAt --limit 10
   ```

3. **Issues updated on that day** (assigned to user):
   ```bash
   gh issue list --repo $REPO --assignee @me --state all --search "updated:>=$DATE" --json number,title,url,state --limit 10
   ```

4. **PR reviews submitted on that day** (reviewing others' PRs):
   ```bash
   gh api "search/issues?q=type:pr+reviewed-by:RadekCap+repo:$REPO+updated:>=$DATE&per_page=10" --jq '.items[] | {number, title, html_url}'
   ```
   Note: This shows PRs where the user submitted a review. Skip repos where the user is the sole contributor.

5. **Commits pushed on that day** (to any branch):
   ```bash
   gh api "repos/$REPO/commits?author=RadekCap&since=${DATE}T00:00:00Z&until=${DATE}T23:59:59Z&per_page=20" --jq '.[] | {sha: .sha[0:7], message: .commit.message | split("\n")[0], branch: .commit.tree.sha[0:7]}'
   ```

### Jira

Read credentials from `credentials.json` in the ai-commands repo root (`/Users/radoslavcap/git/ai-commands/credentials.json`):
```bash
EMAIL=$(python3 -c "import json; d=json.load(open('/Users/radoslavcap/git/ai-commands/credentials.json')); print(d['jira']['email'])")
TOKEN=$(python3 -c "import json; d=json.load(open('/Users/radoslavcap/git/ai-commands/credentials.json')); print(d['jira']['token'])")
```

**Fallback**: If not found, try the capi-tests repo:
```bash
# /Users/radoslavcap/git/capi-tests/.jira-credentials format: JIRA_EMAIL=... JIRA_API_TOKEN=...
source /Users/radoslavcap/git/capi-tests/.jira-credentials
EMAIL=$JIRA_EMAIL
TOKEN=$JIRA_API_TOKEN
```

**IMPORTANT**: Use the v3 search API — v2 search has been removed by Atlassian.

**DATE RANGE PITFALL**: Jira dates are midnight-based. `updated <= "2026-04-01"` means "before April 1st started" — it excludes the entire day. Always use `updated >= "$DATE" AND updated < "$NEXT_DAY"` where `$NEXT_DAY` is the day after `$DATE`. Calculate it with:
```bash
NEXT_DAY=$(date -j -v+1d -f '%Y-%m-%d' "$DATE" '+%Y-%m-%d')   # macOS
```

1. **Issues updated on that day** (assigned to user, any status change):
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+labels=CAPZ+AND+assignee=currentUser()+AND+updated+%3E%3D+%22$DATE%22+AND+updated+%3C+%22$NEXT_DAY%22+ORDER+BY+updated+DESC&maxResults=30&fields=key,summary,status,updated"
   ```

2. **Issues resolved on that day**:
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+labels=CAPZ+AND+assignee=currentUser()+AND+resolved+%3E%3D+%22$DATE%22+AND+resolved+%3C+%22$NEXT_DAY%22+ORDER+BY+resolved+DESC&maxResults=20&fields=key,summary,status,resolution"
   ```

3. **Issues transitioned on that day** (status changed):
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+labels=CAPZ+AND+assignee=currentUser()+AND+status+CHANGED+DURING+(%22$DATE%22%2C+%22$NEXT_DAY%22)+ORDER+BY+updated+DESC&maxResults=20&fields=key,summary,status"
   ```

## Phase 1: Terminal Output

Format for **terminal readability** — clean, scannable, with box-drawing characters:

```
══════════════════════════════════════════════════
 DAILY SUMMARY — 2026-04-01 (Wednesday)
══════════════════════════════════════════════════

── CAPI Tests ───────────────────────────────────

  Merged PRs:
    #631 — Add ROSA provider support

  Jira (closed):
    ARO-25504 — Tier 1: Add Dependency Review and
                Harden Runner to capi-tests, ASO

  Jira (updated):
    ARO-25505 — Tier 2: Add CodeQL to capi-tests
                and Scorecard to capi-tests, ASO

── ASO (stolostron/azure-service-operator) ──────

  Open PRs (updated):
    #89 — Add ARO-HCP team members to CODEOWNERS

  Reviews submitted:
    #88 — Fix kubeconfig secret creation delay

  Jira (closed):
    ARO-25504 — Tier 1: Add Dependency Review and
                Harden Runner to capi-tests, ASO

── CAPZ (stolostron/cluster-api-provider-azure) ──

  Merged PRs:
    #144 — Add ARO-HCP team members to OWNERS

── OpenShift CI ─────────────────────────────────

  Jira (updated):
    ARO-25780 — Simplify OpenShift CI step wrapper
                by passing data via .deployment-state.json

── ACM Train ────────────────────────────────────

  Jira (closed):
    ARO-25650 — Sprint 1 - Post-Upgrade on AWS OCP
                4.20.z with ACM 2.17.0

── Other ────────────────────────────────────────

  Jira (updated):
    ARO-25686 — Log MCE details used for testing

══════════════════════════════════════════════════
 2 PRs · 0 issues · 5 JIRAs · 1 review
══════════════════════════════════════════════════
```

Note: Jira tickets that match multiple areas (e.g., ARO-25504 mentions both "capi-tests" and "ASO") appear under **each matching area**. The footer counts each ticket only once.

### Terminal Formatting Rules

1. **Terminal-first** — use Unicode box-drawing characters, not Slack/markdown formatting
2. **Skip empty sections** — if a project area has no activity for the day, omit it entirely
3. **Skip empty sub-sections** — if a project has PRs but no issues, only show the PR section
4. **Deduplicate** — a PR that was both created and merged shows only in "Merged PRs", not also in "Open PRs"
5. **Short titles** — truncate PR/issue titles at 70 characters if needed
6. **Summary footer** — show total counts of PRs, issues, JIRAs, and reviews
7. **Day of week** — include the day name in the header for quick orientation

## Phase 2: Obsidian Daily Note

After displaying the terminal output, ask the user:
```
Save to Obsidian daily note? (y/n)
```

If yes, write the summary to the Obsidian daily note with proper links.

### Obsidian Configuration

- **Vault path**: `$OBSIDIAN_VAULT` environment variable (required)
- **Daily note path**: `$OBSIDIAN_VAULT/Diary/<YYYY-MM-DD>.md`

If `$OBSIDIAN_VAULT` is not set, show: "⚠ $OBSIDIAN_VAULT not set. Cannot save to Obsidian."

### Obsidian Output Format

The summary is inserted at the **top** of the daily note file (after any existing frontmatter). If the file doesn't exist, create it. If it already has a `## Daily Summary` section, replace it.

Use markdown with clickable links:

```markdown
## Daily Summary

### CAPI Tests
- **Merged**: [#631](https://github.com/RadekCap/capi-tests/pull/631) — Add ROSA provider support
- **Jira closed**: [ARO-25504](https://redhat.atlassian.net/browse/ARO-25504) — Tier 1: Add Dependency Review and Harden Runner to capi-tests, ASO
- **Jira updated**: [ARO-25505](https://redhat.atlassian.net/browse/ARO-25505) — Tier 2: Add CodeQL to capi-tests and Scorecard

### ASO
- **Open**: [#89](https://github.com/stolostron/azure-service-operator/pull/89) — Add ARO-HCP team members to CODEOWNERS
- **Reviewed**: [#88](https://github.com/stolostron/azure-service-operator/pull/88) — Fix kubeconfig secret creation delay
- **Jira closed**: [ARO-25504](https://redhat.atlassian.net/browse/ARO-25504) — Tier 1: Add Dependency Review and Harden Runner to capi-tests, ASO

### CAPZ
- **Merged**: [#144](https://github.com/stolostron/cluster-api-provider-azure/pull/144) — Add ARO-HCP team members to OWNERS

### OpenShift CI
- **Jira updated**: [ARO-25780](https://redhat.atlassian.net/browse/ARO-25780) — Simplify OpenShift CI step wrapper

### ACM Train
- **Jira closed**: [ARO-25650](https://redhat.atlassian.net/browse/ARO-25650) — Sprint 1 - Post-Upgrade on AWS OCP 4.20.z with ACM 2.17.0

### Other
- **Jira updated**: [ARO-25686](https://redhat.atlassian.net/browse/ARO-25686) — Log MCE details used for testing

---
```

Note: Jira tickets matching multiple areas appear under each matching area. In Obsidian, each instance is a clickable link to the same ticket.

### Obsidian Link Format

- **GitHub PRs**: `[#N](https://github.com/owner/repo/pull/N)` — renders as clickable in Obsidian
- **GitHub Issues**: `[#N](https://github.com/owner/repo/issues/N)`
- **Jira tickets**: `[ARO-XXXXX](https://redhat.atlassian.net/browse/ARO-XXXXX)`
- **Bold prefixes**: `**Merged**:`, `**Open**:`, `**Reviewed**:`, `**Resolved**:`, `**In Progress**:`, `**→ Status**:`
- **Commits**: `` `sha1234` `` in inline code

### Obsidian Insertion Rules

1. **Insert at top** — the `## Daily Summary` section goes at the top of the file, right after frontmatter (if any)
2. **Preserve existing content** — do not remove or modify other sections in the daily note
3. **Replace if exists** — if `## Daily Summary` already exists in the file, replace it entirely (the user is re-running the command)
4. **End with `---`** — add a horizontal rule after the summary to visually separate it from other content
5. **Skip empty areas** — same as terminal: omit project areas with no activity

### Obsidian Git Workflow

After writing to the daily note, commit and push:

```bash
cd "$OBSIDIAN_VAULT"
git add "Diary/<YYYY-MM-DD>.md"
git commit -m "Add daily summary: <YYYY-MM-DD>"
# Include Co-Authored-By
git push
```

Note: Unlike other Obsidian commands, the daily summary uses a direct push to main (not a PR), since it's a small, routine addition to a personal vault.

**IMPORTANT**: Ask the user before pushing. They may want to review the note first.

## Steps

1. **Determine date** (Step 0: Date Selection above)
   - If argument provided, use it directly
   - Otherwise, show interactive prompt: Today / Yesterday / Custom
   - Validate the date format
   - Calculate day-of-week for display

2. **Gather GitHub data** (all repos in parallel)
   - For each tracked repo, fetch PRs, issues, reviews, and commits
   - Use `gh` CLI with `--repo` flag
   - Run all repo queries concurrently (use parallel Bash tool calls)

3. **Gather Jira data**
   - Read credentials (try ai-commands/credentials.json first, then capi-tests/.jira-credentials)
   - Fetch updated, resolved, and transitioned issues via v3 search API
   - Run all three Jira queries in parallel

4. **Assemble and display terminal report** (Phase 1)
   - **Map Jira tickets to areas**: For each Jira ticket, scan its summary against the keyword table (case-insensitive). Assign it to every matching area. Tickets matching no area go into "Other".
   - Group all activity (GitHub + mapped Jira) by project area
   - Within each area, sub-group by activity type (merged PRs, open PRs, commits, issues, reviews, then Jira by status)
   - A Jira ticket matching multiple areas appears under each one; the footer counts it only once
   - Skip areas and sub-sections with no activity
   - Deduplicate GitHub entries that appear in multiple queries (e.g., merged + updated)
   - Print to terminal and wait for user review

5. **Offer Obsidian save** (Phase 2)
   - Ask: "Save to Obsidian daily note? (y/n)"
   - If yes:
     - Transform the data to markdown with links (GitHub URLs, Jira URLs)
     - Read existing daily note (or create new one)
     - Insert `## Daily Summary` at top (after frontmatter)
     - Write the file
     - Ask before committing and pushing

6. **Offer /quick-pr** (Phase 3 — always at the end)
   - After Phase 2 completes (whether the user saved to Obsidian or not), offer to run `/quick-pr` for any repos that have uncommitted changes from this session
   - Typical repos with changes: `ai-commands` (if the command definition was updated), `obsidian-rh-acm` (if daily note was saved)
   - Ask: "Run /quick-pr for changed repos? (y/n)"
   - If yes, run the quick-pr workflow for each repo with changes

## Error Handling

- If `gh` is not authenticated, show: "⚠ GitHub CLI not authenticated. Run `gh auth login` first."
- If Jira credentials are missing, show: "⚠ Jira credentials not found. Skipping Jira section."
- If a specific repo returns no results or errors (e.g., no access), silently skip it
- If ALL sources return empty, show: "No activity found for $DATE. Either it was a quiet day or check your auth."
- If `$OBSIDIAN_VAULT` is not set when saving, show: "⚠ $OBSIDIAN_VAULT not set. Cannot save to Obsidian."

## Tips

- Run this at end-of-day to review what you accomplished before signing off
- Yesterday is handy for morning catch-ups or when you forgot to run it the evening before
- If a new repo area becomes relevant, ask the user if they want to add it to the tracked list
- Commits without PRs ("not yet in PR") highlight work-in-progress that might need a PR
- PR reviews show collaboration work that's easy to forget when summarizing your day
