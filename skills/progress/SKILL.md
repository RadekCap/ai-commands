---
name: progress
description: Show learning progress from the active plan file with a visual tracker
---

# Progress

Display the current learning progress from the most recent plan file in `~/.claude/plans/`.

## Workflow

1. Find the most recent `.md` file in `~/.claude/plans/`
2. Read the file
3. Count completed (`- [x]`) and pending (`- [ ]`) items
4. Print a formatted progress view

## Output Format

Print the progress as a visual tracker. Use this exact format:

```
━━━ Learning Progress ━━━━━━━━━━━━━━━━━━━━━━━━━

[Plan title from first heading]

  ✅ Completed item 1
  ✅ Completed item 2
  ▶  Current item (first unchecked)       ← YOU ARE HERE
  ○  Upcoming item 4
  ○  Upcoming item 5

Progress: [3/9] ▓▓▓░░░░░░░ 33%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Rules:
- Use ✅ for `- [x]` items
- Use ▶ for the first `- [ ]` item (current), append `← YOU ARE HERE`
- Use ○ for remaining `- [ ]` items
- Strip markdown formatting (bold markers `**`) from item names
- Show the progress bar with percentage at the bottom
- If no plan file exists, say "No active plan found. Use plan mode to create one."
