---
description: Summarize the current Claude Code session and export it as an Obsidian note
---

# Obsidian Summarize Session

Summarize everything done in the current Claude Code session and save as an Obsidian note.

## Usage

```
/obsidian-summarize-session
```

## Configuration

- **Vault path**: Use the `$OBSIDIAN_VAULT` environment variable (required) — path to the Obsidian vault root

## Steps

1. **Resolve paths**
   ```bash
   echo "$OBSIDIAN_VAULT"
   ```
   - If `$OBSIDIAN_VAULT` is not set, stop and tell the user to set it
   - Verify the directory exists
   - Detect the project name: `basename $(git rev-parse --show-toplevel)`
   - Determine the current date: `YYYY-MM-DD`
   - Capture the current time: `HH:MM` (24-hour format) — this is the **export timestamp**
   - Build output path: `$OBSIDIAN_VAULT/zzArchive/AI Sessions/<project>/<year>/<month>/`
   - Create the directory if it doesn't exist

2. **Review the session**
   - Go through the entire conversation history
   - Identify: topics covered, PRs created/merged, decisions made, key learnings, files created/modified

3. **Write the note**
   - Filename: `<YYYY-MM-DD> <HH-MM> Session - <short description>.md` (use `-` in time for filename safety)
   - Derive the short description from the main theme of the session
   - Use this structure:

   ```markdown
   ---
   project: <project-name>
   date: <YYYY-MM-DD>
   type: session
   ---
   # <YYYY-MM-DD> <HH:MM> Session — <Short Description>

   ## Topics Covered
   ### 1. <Topic>
   - <key points>

   ## PRs Merged
   | PR | Repo | Description |
   |---|---|---|
   | [#N](url) | repo-name | what it did |

   ## Decisions Made
   - <decision with brief reasoning>

   ## Key Learnings
   - <anything new learned during the session>
   ```

   - Use Obsidian-flavored markdown
   - Be concise but complete — this is a reference for future you

4. **Add diary cross-link**
   - Open or create `$OBSIDIAN_VAULT/Diary/<YYYY-MM-DD>.md`
   - If the file has no `## AI Sessions` section, append it
   - Add a wikilink entry under that section with a time prefix. Prefix the **alias** (the part after `|`) with the literal marker `[CC CLI]` so the source of the session is visible at a glance:
     ```markdown
     - <HH:MM> [[<YYYY-MM-DD> <HH-MM> Session - <short description>|[CC CLI]<project>: <short description>]]
     ```
   - **Note on the link target**: only the alias gets the `[CC CLI]` prefix — the wikilink target (the filename before `|`) stays unchanged. The literal brackets `[CC CLI]` render fine inside the alias because they are balanced and Obsidian only treats the closing `]]` as the link terminator.
   - **Sort entries chronologically**: after adding the new link, sort all entries under `## AI Sessions` by their `HH:MM` prefix (oldest first)
   - **Update session count in heading**: count all `- ` entries under the section and update the heading to `## AI Sessions (<count>)`

5. **Auto-commit and push to the Obsidian repo**
   After writing the files, run the following git workflow in the Obsidian repo directory:
   - `git checkout -b feature/obsidian-session-<date>`
   - `git add` the new session file and the diary file
   - `git commit -m "Add session summary: <date>"` with `Co-Authored-By: Claude <noreply@anthropic.com>`
   - `git push -u origin <branch>`
   - `gh pr create --title "Add session summary: <date>" --body "## Summary\n- Session summary exported from Claude Code"`
   - `gh pr merge --squash`
   - `git checkout main && git pull && git branch -d <branch>`

6. **Confirm completion**
   - Print the file path
   - Print the merged PR URL
