---
name: obsidian-export
description: Export a topic analysis or brainstorm from the current conversation into an Obsidian note
---

# Obsidian Export

Export the current topic, brainstorm, or analysis from this conversation into an Obsidian note.

## Usage

```
/obsidian-export <title>
```

The title argument becomes the filename: `<Title>.md`

## Configuration

- **Inbox path**: Use the `$OBSIDIAN_INBOX` environment variable (required)

## Steps

1. **Resolve the Inbox path**
   ```bash
   echo "$OBSIDIAN_INBOX"
   ```
   - If `$OBSIDIAN_INBOX` is not set, stop and tell the user to set it
   - Verify the directory exists
   - If it doesn't exist, stop and tell the user

2. **Gather content from the conversation**
   - Look at the recent discussion context in this session
   - Identify the topic, key points, decisions, and conclusions
   - If the conversation has multiple topics, focus on the most recent one unless the title suggests otherwise

3. **Write the note**
   - Filename: `<Title>.md` in the Inbox path
   - Use Obsidian-flavored markdown:
     - Do NOT add a `# Heading` for the title — Obsidian already shows the filename as the title
     - `[[wikilinks]]` for references to other notes when relevant
     - Standard markdown for everything else
   - Structure the note with clear headings and bullet points
   - Keep it concise — capture the essence, not the entire conversation

4. **Auto-commit and push to the Obsidian repo**
   After writing the file, run the following git workflow in the Obsidian repo directory (parent of the Inbox):
   ```bash
   # Navigate to the repo root
   cd "$(dirname "$OBSIDIAN_INBOX")"
   # Or use the resolved path
   ```
   - `git checkout -b feature/obsidian-export-<short-slug>`
   - `git add` the new file
   - `git commit -m "Add note: <Title>"`  with `Assisted-by: <current AI tool and model>`
   - `git push -u origin <branch>`
   - `gh pr create --title "Add note: <Title>" --body "## Summary\n- Exported from AI-assisted session"`
   - `gh pr merge --squash`
   - `git checkout main && git pull && git branch -d <branch>`

5. **Confirm completion**
   - Print the file path
   - Print the merged PR URL
