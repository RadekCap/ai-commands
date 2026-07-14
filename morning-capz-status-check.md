---
description: Run CAPZ status check and save results to today's Obsidian daily note
---

# Morning CAPZ Status Check

Wrapper around `/capz-status-check` that writes results directly into today's Obsidian daily note.

## Usage

```
/morning-capz-status-check
```

No arguments, no prompts — just run it and it saves.

## Steps

### 1. Run /capz-status-check

Run the full `/capz-status-check` inline — execute all steps from that skill (GHA workflows, issues, PRs, security alerts). Display results in the terminal as usual.

### 2. Write to Obsidian daily note

After the terminal output, write the results to today's Obsidian daily note.

**Daily note path:**
```bash
DATE=$(date +%Y-%m-%d)
DAILY_NOTE="$OBSIDIAN_VAULT/Diary/${DATE}.md"
```

If `$OBSIDIAN_VAULT` is not set, show `⚠ $OBSIDIAN_VAULT not set. Cannot save to Obsidian.` and stop.

**Find and replace** the `### Morning CAPZ Status` section in the daily note. The section starts at `### Morning CAPZ Status` and ends just before the next heading (`##` or `###`) or end of file.

Replace that section with formatted markdown:

```markdown
### Morning CAPZ Status

#### GHA Workflows

**stolostron/capi-tests**

| Workflow | Status |
|----------|--------|
| [Management Cluster (ARO)](https://github.com/stolostron/capi-tests/actions/workflows/management-cluster-aro.yml) | ✅ |
| [Full Cluster Deployment (ARO)(main)](https://github.com/stolostron/capi-tests/actions/workflows/workload-cluster-aro.yml) | ❌ |
| ... | ... |

**stolostron/cluster-api-provider-azure**

| Workflow | Status |
|----------|--------|
| ... | ... |

**stolostron/azure-service-operator**

| Workflow | Status |
|----------|--------|
| ... | ... |

**stolostron/cluster-api-installer**

| Workflow | Status |
|----------|--------|
| ... | ... |

Manual checks:
- [ ] [OpenShift CI](https://prow.ci.openshift.org/?job=periodic-ci-stolostron-capi-tests-*)
- [ ] [ACM Jenkins](https://jenkins-csb-rhacm-tests.dno.corp.redhat.com/job/CI-Jobs/job/capz_tests/)

#### Repo Status

**stolostron/capi-tests**
- Issues:
  - [#123 Title](https://github.com/stolostron/capi-tests/issues/123)
- PRs:
  - [#456 Title](https://github.com/stolostron/capi-tests/pull/456)
- Security: (none)

**stolostron/cluster-api-provider-azure**
- ✅ All clear

**stolostron/azure-service-operator**
- ✅ All clear

**stolostron/cluster-api-installer**
- ✅ All clear
```

**Formatting rules:**
- Use markdown tables for GHA workflow status (renders nicely in Obsidian)
- Use `✅ ❌ ⏳ ⚪` emoji for status indicators
- **Workflow names must be clickable links** to their GHA page: `[Workflow Name](https://github.com/<owner>/<repo>/actions/workflows/<filename>)`
- Use `[Title](URL)` links for issues, PRs, and security alerts (clickable in Obsidian)
- Use `[Name](URL)` links for manual check items
- If all categories are empty for a repo, print `✅ All clear`
- If the `### Morning CAPZ Status` section is not found in the daily note, append it before the `## AI Sessions` section (or at the end if that section doesn't exist either)

### 3. Commit and push

```bash
cd "$OBSIDIAN_VAULT"
git add "Diary/${DATE}.md"
git commit -m "Update morning CAPZ status: ${DATE}"
git push
```

### 4. Finish

Print:
```
━━━ ✔ Finished /morning-capz-status-check ━━━━━
```
