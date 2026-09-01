---
name: obsidian-summarize-pr
description: Summarize a pull request and export it as an Obsidian note
---

# Obsidian Summarize PR

Read a pull request, summarize its changes and decisions, and save as an Obsidian note.

## Usage

```
/obsidian-summarize-pr <pr-url-or-number>
```

## Configuration

- **Inbox path**: Use the `$OBSIDIAN_INBOX` environment variable (required)

## Steps

1. **Resolve the Inbox path**
   ```bash
   echo "$OBSIDIAN_INBOX"
   ```
   - If `$OBSIDIAN_INBOX` is not set, stop and tell the user to set it
   - Verify the directory exists

2. **Fetch PR details**
   ```bash
   gh pr view <number-or-url> --json title,number,author,body,additions,deletions,files,comments
   ```
   - Also fetch the diff:
   ```bash
   gh pr diff <number-or-url>
   ```

3. **Write the note**
   - Filename: `PR <number> - <title>.md` in the Inbox path
   - Use this structure:

   ```markdown
   # PR <number> — <title>

   **Author:** <author>
   **Date:** <date>
   **Status:** <merged/open/closed>

   ## Summary
   <2-3 sentence summary of what this PR does and why>

   ## Key Changes
   - <bullet points of significant changes>

   ## Files Changed
   - `path/to/file.go` — <what changed>

   ## Decisions & Notes
   - <any notable decisions, trade-offs, or context from comments>
   ```

   - Use Obsidian-flavored markdown
   - Keep it concise — focus on what matters, not every line changed

4. **Auto-commit and push to the Obsidian repo**
   After writing the file, run the following git workflow in the Obsidian repo directory:
   - `git checkout -b feature/obsidian-pr-<number>`
   - `git add` the new file
   - `git commit -m "Add PR summary: PR <number> - <title>"` with `Assisted-by: <current AI tool and model>`
   - `git push -u origin <branch>`
   - `gh pr create --title "Add PR summary: <title>" --body "## Summary\n- Exported PR <number> summary from AI coding session"`
   - `gh pr merge --squash`
   - `git checkout main && git pull && git branch -d <branch>`

5. **Confirm completion**
   - Print the file path
   - Print the merged PR URL
