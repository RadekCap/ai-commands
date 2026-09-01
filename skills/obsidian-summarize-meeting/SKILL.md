---
name: obsidian-summarize-meeting
description: Summarize a meeting and export it as an Obsidian note with diary cross-link
---

# Obsidian Summarize Meeting

Capture meeting notes from the current conversation and save as an Obsidian note with a diary cross-link.

## Usage

```
/obsidian-summarize-meeting
```

## Configuration

- **Inbox path**: Use the `$OBSIDIAN_INBOX` environment variable (required) — path to the Obsidian vault Inbox folder

## Steps

1. **Resolve paths**
   ```bash
   echo "$OBSIDIAN_INBOX"
   ```
   - If `$OBSIDIAN_INBOX` is not set, stop and tell the user to set it
   - Verify the directory exists
   - Derive the vault root: `VAULT="$(dirname "$OBSIDIAN_INBOX")"`
   - Determine the current date: `YYYY-MM-DD`
   - Capture the current time: `HH:MM` (24-hour format) — this is the **export timestamp**

2. **Gather meeting details**
   - Scan the conversation history for meeting-related content
   - If insufficient context, ask the user for:
     - Meeting topic / title
     - Attendees (list of names)
     - Location: `online` | `in-person` | `<room name>` — default: `online`
     - Meeting type: `standup` | `planning` | `retro` | `1-on-1` | `general` — default: `general`
     - Discussion points
     - Decisions made
     - Action items with owners
   - Omit any section that has no content (e.g., skip Action Items if there were none)

3. **Write the note**
   - Filename: `<YYYY-MM-DD> <HH-MM> Meeting - <short description>.md` (use `-` in time for filename safety)
   - Derive the short description from the main meeting topic
   - Use this structure:

   ```markdown
   ---
   date: <YYYY-MM-DD>
   type: meeting
   meeting-type: <standup | planning | retro | 1-on-1 | general>
   attendees:
     - Name1
     - Name2
   location: <online | in-person | room name>
   ---
   # <YYYY-MM-DD> <HH:MM> Meeting — <Short Description>

   ## Attendees
   - Name1
   - Name2

   ## Discussion Points
   ### 1. <Topic>
   - <key points discussed>

   ## Decisions Made
   - <decision with brief reasoning>

   ## Action Items
   - [ ] <task description> — @Owner
   - [ ] <task description> — @Owner

   ## Key Takeaways
   - <important context or insights>
   ```

   - Use Obsidian-flavored markdown
   - Be concise but capture all decisions and action items completely

4. **Add diary cross-link**
   - Open or create `$VAULT/Diary/<YYYY-MM-DD>.md`
   - If the file has no `## Meetings` section, append it
   - Add a wikilink entry under that section with a time prefix:
     ```markdown
     - <HH:MM> [[<YYYY-MM-DD> <HH-MM> Meeting - <short description>|<short description>]]
     ```
   - **Sort entries chronologically**: after adding the new link, sort all entries under `## Meetings` by their `HH:MM` prefix (oldest first)

5. **Auto-commit and push to the Obsidian repo**
   After writing the files, run the following git workflow in the Obsidian repo directory (`$VAULT`):
   - `git checkout -b feature/obsidian-meeting-<date>`
   - `git add` the new meeting file and the diary file
   - `git commit -m "Add meeting summary: <date>"` with `Assisted-by: <current AI tool and model>`
   - `git push -u origin <branch>`
   - `gh pr create --title "Add meeting summary: <date>" --body "## Summary\n- Meeting summary exported from Claude Code"`
   - `gh pr merge --squash`
   - `git checkout main && git pull && git branch -d <branch>`

6. **Confirm completion**
   - Print the file path
   - Print the merged PR URL
