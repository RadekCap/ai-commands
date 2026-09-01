---
name: obsidian-search
description: Search your Obsidian vault and summarize what your notes say about a topic
---

# Obsidian Search

Search your Obsidian vault for notes matching a query, read them, and provide a synthesized summary.

## Usage

```
/obsidian-search <query>
```

## Configuration

- **Vault path**: Use the `$OBSIDIAN_INBOX` environment variable to determine the vault root (parent directory of Inbox)

## Steps

1. **Resolve the vault path**
   ```bash
   VAULT="$(dirname "$OBSIDIAN_INBOX")"
   ```
   - If `$OBSIDIAN_INBOX` is not set, stop and tell the user to set it
   - Verify the directory exists

2. **Search for matching notes**
   - Use Grep to search file contents for the query term across the entire vault (`$VAULT/**/*.md`)
   - Use Glob to find files with the query in their filename
   - Exclude `.git/` and `.obsidian/` directories
   - Collect all matching file paths

3. **Read and analyze matches**
   - Read the top 5 most relevant matching files
   - If more than 5 matches, prioritize by:
     - Filename match over content-only match
     - More recent files over older ones

4. **Present results**
   - Print a summary of what your notes say about the topic
   - List the matching files with a one-line description of each
   - Highlight connections between notes if any exist
   - Format:

   ```
   ## Found <N> notes about "<query>"

   ### Summary
   <synthesized summary across all matching notes>

   ### Matching Notes
   1. **<filename>** — <one-line summary>
   2. **<filename>** — <one-line summary>
   ```

   - This command is **read-only** — it does NOT write any files or commit anything
