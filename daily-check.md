---
description: Quick daily priority check — shows your weekly priorities and today's planned actions (Tue–Thu)
---

# Daily Priority Check

Lightweight 5-minute check-in. Run at 9:00 before opening Slack or email.

## Usage

```
/daily-check
```

## Steps

### 1. Find and read the weekly plan

```bash
WEEK=$(date +%Y-W%V)
PLAN_FILE="$OBSIDIAN_VAULT/Diary/Weekly/${WEEK}-plan.md"
```

If the plan file doesn't exist:
```
⚠ No weekly plan found for $WEEK.
Run /weekly-review open to create one.
```

### 2. Determine today

```bash
DAY_NAME=$(date +%A)
```

If today is Monday or Friday, suggest the full review instead:
```
Today is $DAY_NAME — time for your full weekly review.
Run /weekly-review open (Monday) or /weekly-review close (Friday).
```

### 3. CAPZ Status

Run `/morning-capz-status-check` inline — executes the full CAPZ status check and saves results to today's Obsidian daily note.

Ask: "Any red flags to address before starting your day?"

### 4. Priority Status Check

Read and display the priority status check page:
```bash
cat "$OBSIDIAN_VAULT/Priority Status Check.md"
```

Show the checklist and ask: "Any items to update or mark as done?"

### 5. Show priorities

Print:
```
━━━ Weekly Priorities ━━━━━━━━━━━━━━━━━━━━━━━━━

📋 This week's priorities:
  1. ARO-XXXXX — <description>
  2. ARO-YYYYY — <description>
```

Read the priorities from the `## Priorities` section of the plan file.

### 6. Show today's actions

Read the `## Daily Plan` section and find today's subsection (### Tuesday, ### Wednesday, ### Thursday).

```
📌 Today ($DAY_NAME):
  - [ ] <action 1>
  - [ ] <action 2>
```

If today has no planned actions:
```
📌 No specific actions planned for $DAY_NAME.
    Focus on moving your priorities forward.
```

### 7. Ask for focus

Ask: "What will you focus on first?"

After the user responds, print:
```
━━━ ✔ Go. Priorities first, inbox later. ━━━━━━
```
