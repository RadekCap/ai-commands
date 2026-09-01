---
name: weekly-review
description: Guided weekly review — Monday opening (plan the week) or Friday closing (review and groom)
---

# Weekly Review

Guided weekly review session. Run at the start of your Monday or Friday review block.

## Usage

```
/weekly-review open    — Monday opening review (8:00–12:00)
/weekly-review close   — Friday closing review (14:00–18:00)
```

If no argument is provided, ask: "Is this your Monday opening review or Friday closing review?"

## Jira Credentials

Read from `~/.claude/credentials.json`:
```bash
EMAIL=$(python3 -c "import json; d=json.load(open('$HOME/.claude/credentials.json')); print(d['jira']['email'])")
TOKEN=$(python3 -c "import json; d=json.load(open('$HOME/.claude/credentials.json')); print(d['jira']['token'])")
```

## Vault Path

Use the `$OBSIDIAN_VAULT` environment variable. If not set, stop and tell the user to set it.

## Weekly Plan File

The plan file lives at `$OBSIDIAN_VAULT/Diary/Weekly/YYYY-WNN-plan.md` where WNN is the ISO week number. Calculate with:
```bash
WEEK=$(date +%Y-W%V)
PLAN_FILE="$OBSIDIAN_VAULT/Diary/Weekly/${WEEK}-plan.md"
```

---

## Mode: `open` (Monday 8:00–12:00)

Print a banner:
```
━━━ ▶ Weekly Review — Opening ━━━━━━━━━━━━━━━━━
```

### Step 1: Inbox to Zero (time-box: 1.5 hours max)

**Goal:** Peace of mind — everything is captured and classified.

1. Show the Nirvana inbox count using the `next_inbox_item` MCP tool.
2. Print: "**Inbox processing** — Let's clear your inbox. I'll show items one at a time."
3. For each inbox item (use `next_inbox_item` repeatedly):
   - Show the item name and notes
   - Ask: "What should we do with this?"
     - **Next** — move to Next action list (update_task with state: next)
     - **Someday** — move to Someday/Maybe (update_task with state: someday)
     - **Project** — assign to a project (list_projects to show options, then update_task with project_id)
     - **Trash** — delete it (trash_task)
     - **Schedule** — set a start date and move to scheduled (update_task with state: scheduled, startdate)
     - **Waiting** — waiting for someone (update_task with state: waiting, waitingfor)
   - After each item, show remaining count
4. Check the Obsidian inbox (`$OBSIDIAN_VAULT/050 Inbox/`):
   - List files in the directory
   - For each file, ask: "Process, skip, or move to wiki?"
   - Skip meeting notes that have already been ingested

Print: "**Inbox complete.** Moving to horizon scan."

### Step 2: Horizon Scan (30 minutes)

**Goal:** Quick overview of where things stand.

1. Read the CAPZ roadmap (high-level workstream overview):
   ```bash
   cat "$OBSIDIAN_VAULT/Knowledge/wiki/capz-roadmap.md" 2>/dev/null
   ```
   Walk through each workstream's key question. Flag anything that needs attention this week.

2. Read the ARO-HCP readiness timeline (detailed phases):
   ```bash
   cat "$OBSIDIAN_VAULT/Knowledge/wiki/capz-aro-hcp-public-preview-readiness.md" 2>/dev/null
   ```

3. Check the personal growth plan (if it exists):
   ```bash
   cat "$OBSIDIAN_VAULT/Knowledge/wiki/personal-growth-plan.md" 2>/dev/null || echo "No personal growth plan found"
   ```

4. Pull active Jira epics:
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+labels=CAPZ+AND+assignee=5fabb5fdecdae600685b01d6+AND+statusCategory+!=+Done+ORDER+BY+priority+DESC&maxResults=15&fields=key,summary,status,priority"
   ```

5. Present a summary table:
   ```
   JIRA          Status          Summary
   ARO-XXXXX     In Progress     <title>
   ARO-YYYYY     To Do           <title>
   ```

6. Ask: "Anything surprising here? Any blockers to flag?"

### Step 2.5: Target State Gap Analysis (15 minutes)

**Goal:** Compare the target state with reality — gaps become weekly priorities.

1. Read the CAPZ target state page:
   ```bash
   cat "$OBSIDIAN_VAULT/Knowledge/wiki/capz-target-state.md" 2>/dev/null
   ```
2. For each dimension, ask: "Is current state matching the target?"
3. List the gaps — these feed directly into Step 3.
4. Ask: "Which gaps are the most urgent this week?"

### Step 3: Set 1–2 Weekly Priorities (30 minutes)

**Goal:** Leave the review with clear focus. Priorities come from the target state gaps above.

1. Print:
   ```
   ━━━ This is the most important step ━━━━━━━━━━━━━
   Your Q2 goal: ARO-HCP CAPZ test integration as a gating feature.
   Deadline: end of Q2 2026.

   Based on the target state gaps above,
   what are your 1–2 priorities for this week?
   Each must map to a Jira ticket.
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

2. After the user states priorities, validate:
   - Does each priority have a Jira ticket?
   - Is the Jira ticket status correct? (fetch and show current status)
   - If no Jira ticket exists, ask: "Should we create one, or is this not really a priority?"

3. Confirm the final 1–2 priorities with the user.

### Step 4: Create Daily Plan (30 minutes)

**Goal:** Break priorities into concrete daily actions for Tue–Thu.

1. Ask the user how they want to distribute the work across the week.
2. Create the weekly plan file at `$OBSIDIAN_VAULT/Diary/Weekly/YYYY-WNN-plan.md`:

   ```markdown
   ---
   title: "Weekly Plan: WNN (Mon Date – Fri Date, YYYY)"
   type: weekly-plan
   week: YYYY-WNN
   priorities-jira: [ARO-XXXXX, ARO-YYYYY]
   ---

   ## Priorities

   - [ ] ARO-XXXXX — <priority 1 description>
   - [ ] ARO-YYYYY — <priority 2 description>

   ## Daily Plan

   ### Tuesday
   - [ ] <concrete action>

   ### Wednesday
   - [ ] <concrete action>

   ### Thursday
   - [ ] <concrete action>

   ## Disruptions
   <!-- Filled during the week when something pulls you off track -->

   ## Friday Review
   <!-- Filled during closing review -->
   ```

3. Print the plan file content for the user to review.

Print:
```
━━━ ✔ Weekly Review — Opening complete ━━━━━━━━━
Plan saved to: Diary/Weekly/YYYY-WNN-plan.md

Your priorities this week:
  1. ARO-XXXXX — <description>
  2. ARO-YYYYY — <description>

Tomorrow, run /daily-check to see your Tuesday actions.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Mode: `close` (Friday 14:00–18:00)

Print a banner:
```
━━━ ▶ Weekly Review — Closing ━━━━━━━━━━━━━━━━━
```

### Step 1: Backlog Grooming (1.5 hours)

**Goal:** Slowly reduce the "Next" list and keep the Jira backlog healthy.

#### Part A: Nirvana "Next" list

1. Fetch the Nirvana "Next" list using `list_tasks` with state: next.
2. Print the total count: "**Backlog: N items in Next.** Let's groom."
3. Show items in batches of 10. For each batch, ask:
   - Which items are **done**? (complete_task)
   - Which items are **no longer relevant**? (trash_task)
   - Which items should move to **Someday**? (update_task with state: someday)
   - Which items need a **due date** or **project assignment**?
4. After each batch, show the updated count.
5. After 1 hour or when the user says "enough", move to Part B.

#### Part B: Jira backlog review

1. Pull all assigned Jira tickets (not just active — include To Do):
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+labels=CAPZ+AND+assignee=5fabb5fdecdae600685b01d6+AND+statusCategory+!=+Done+ORDER+BY+updated+ASC&maxResults=30&fields=key,summary,status,priority,updated"
   ```
2. Show tickets sorted by last updated (oldest first).
3. For each ticket, ask:
   - Still relevant? (keep / close / reassign)
   - Priority correct?
   - Any that should be broken down or merged?
4. Flag tickets not updated in 30+ days as candidates for closure.

### Step 2: Week in Review (1 hour)

**Goal:** Compare planned vs actual. Feed the Tuesday manager report.

1. Read the weekly plan file:
   ```bash
   WEEK=$(date +%Y-W%V)
   cat "$OBSIDIAN_VAULT/Diary/Weekly/${WEEK}-plan.md"
   ```

2. For each priority, ask:
   - "Did you move this forward this week? What got done?"
   - "If not, what pulled you away?" (capture in Disruptions section)

3. Update the plan file's **Friday Review** section with:
   - Priorities completed / not completed (with reasons)
   - Disruptions noted during the week

4. Run `/weekly-report` to generate the manager report for Tuesday.
   - This generates the Slack-formatted status. The user can review and adjust before Tuesday.

### Step 3: Jira Sync (30 minutes)

**Goal:** Jira reflects reality.

1. Pull all assigned Jira tickets:
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+labels=CAPZ+AND+assignee=5fabb5fdecdae600685b01d6+AND+statusCategory+!=+Done+ORDER+BY+priority+DESC&maxResults=30&fields=key,summary,status"
   ```

2. For each ticket, compare with what actually happened this week:
   - Show current status
   - Ask: "Is this status still correct?"
   - If not, note what should change (the user updates Jira manually — we don't have write access)

3. Flag stale tickets: any ticket that hasn't been updated in 14+ days:
   ```bash
   curl -s -u "$EMAIL:$TOKEN" -H "Content-Type: application/json" \
     "https://redhat.atlassian.net/rest/api/3/search/jql?jql=project=ARO+AND+labels=CAPZ+AND+assignee=5fabb5fdecdae600685b01d6+AND+statusCategory+!=+Done+AND+updated+%3C+startOfDay(-14d)+ORDER+BY+updated+ASC&maxResults=15&fields=key,summary,status,updated"
   ```

### Step 4: Reflect (30 minutes)

**Goal:** GTD horizons of focus — am I working on the right things?

Print the horizons and ask one question per level:

```
━━━ GTD Horizons of Focus ━━━━━━━━━━━━━━━━━━━━━

  Ground    — Are your next actions clear and doable?
  10K ft    — Are all projects moving forward?
  20K ft    — Are you covering all your roles (CAPZ, testing, team)?
  30K ft    — Does this week's work serve your Q2 targets?
  40K ft    — Are you building toward where you want to be?
  50K ft    — Is the direction still right?
```

Ask: "Which level feels off this week? Or does everything feel aligned?"

#### Career Satisfaction Check

1. Read the career satisfaction reflection page:
   ```bash
   cat "$OBSIDIAN_VAULT/Knowledge/wiki/career-satisfaction-reflection.md" 2>/dev/null
   ```
2. Walk through each dimension briefly:
   - Role satisfaction — how did this week feel?
   - Compensation — any new info or concerns?
   - Career track — any movement on DEV/QE or promotion?
   - Team & environment — any friction or highlights?
   - Long-term alignment — still on track?
3. Ask: "Overall satisfaction this week, 1–5? Any notes to log?"
4. If the user provides a rating, append a row to the Reflection Log table in the wiki page.

### Step 5: Inbox Sweep (30 minutes)

1. Check Nirvana inbox for anything that arrived during the week.
2. Process the same way as Monday Step 1 (but expect fewer items).

### Step 5.5: Process "For Weekly Review" Project

1. Fetch all tasks in the "For weekly review" Nirvana project (ID: 92E8F633-6E80-4AA2-84F2-45BE91CF1EBA) using `list_tasks`.
2. For each task, show the item and ask:
   - **Done** — complete it
   - **Discuss** — talk through it now
   - **Keep** — leave it for a future review
   - **Trash** — no longer relevant
3. This project is the holding area for topics and questions that surfaced during the week and need dedicated review time.

Print:
```
━━━ ✔ Weekly Review — Closing complete ━━━━━━━━━
Weekly report is ready for your Tuesday meeting.
Next Monday, run /weekly-review open to plan the next week.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Git Workflow

After creating or updating the weekly plan file, commit and push:

```bash
cd "$OBSIDIAN_VAULT"
git add "Diary/Weekly/${WEEK}-plan.md"
git commit -m "Add weekly plan: ${WEEK}"
git push
```

Ask the user before pushing. For the closing review, also commit the updated plan with Friday Review section:

```bash
git add "Diary/Weekly/${WEEK}-plan.md"
git commit -m "Update weekly plan with Friday review: ${WEEK}"
git push
```
