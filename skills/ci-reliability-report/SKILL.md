---
name: ci-reliability-report
description: Weekly CI reliability report — Prow (ARO-HCP environments) + GHA (capi-tests, CAPZ, ASO) + Security scans. Prints output and saves to Obsidian Inbox.
---

# CI Reliability Report

Generates the weekly CI reliability report across all tracked environments and repos.
Prints the report in the terminal and saves it to `$OBSIDIAN_VAULT/050 Inbox/`.

## Usage

```
/ci-reliability-report
```

## Data Sources

### 1. OpenShift CI (Prow) — Sippy API

Fetch current and previous pass rates for each Prow job:

```bash
# DEV (US)
curl -s "https://sippy.dptools.openshift.org/api/jobs?release=capi-qe&filter=%7B%22items%22%3A%5B%7B%22columnField%22%3A%22name%22%2C%22operatorValue%22%3A%22equals%22%2C%22value%22%3A%22periodic-ci-stolostron-capi-tests-configure-prow-mgmt-periodics-capz-e2e%22%7D%5D%7D"

# Production
curl -s "https://sippy.dptools.openshift.org/api/jobs?release=aro-production&filter=%7B%22items%22%3A%5B%7B%22columnField%22%3A%22name%22%2C%22operatorValue%22%3A%22equals%22%2C%22value%22%3A%22periodic-ci-Azure-ARO-HCP-main-capz-e2e-production%22%7D%5D%7D"
```

Extract: `current_pass_percentage`, `current_runs`, `current_passes`, `current_fails`, `last_pass`.

### 2. GHA — stolostron/capi-tests

```bash
gh api "repos/stolostron/capi-tests/actions/runs?per_page=100&created=>$(date -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --jq '[.workflow_runs[] | select(.status == "completed")] |
  group_by(.name) |
  map({name: .[0].name, total: length,
    success: map(select(.conclusion == "success")) | length,
    failure: map(select(.conclusion == "failure")) | length})'
```

Report these workflows:
- `Full Cluster Deployment (ARO)(main)` — Developer CI
- `Full Cluster Deployment (ARO)(backplane-2.11)` — Developer CI
- `Full Cluster Deployment (ARO)(backplane-2.17)` — Developer CI
- `Full Cluster Deployment (ARO)(backplane-5.0)` — Developer CI
- `Full Cluster Deployment (ARO)(backplane-5.1)` — Developer CI
- `Security Gosec`, `Security Govulncheck`, `Security Nancy`, `Security Trivy`, `Security Fuzz`, `Security CodeQL`, `Security Scorecard`, `Security Dependency Review` — Security

### 3. GHA — stolostron/cluster-api-provider-azure

```bash
gh api "repos/stolostron/cluster-api-provider-azure/actions/runs?per_page=100&created=>$(date -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --jq '[.workflow_runs[] | select(.status == "completed")] |
  group_by(.name) |
  map({name: .[0].name, total: length,
    success: map(select(.conclusion == "success")) | length,
    failure: map(select(.conclusion == "failure")) | length})'
```

Report these workflows:
- `PR capi-tests` — Developer CI
- `CodeQL`, `Scorecard supply-chain security`, `Dependency Review`, `Weekly security scan` — Security

### 4. GHA — Azure/azure-service-operator

```bash
gh api "repos/Azure/azure-service-operator/actions/runs?per_page=100&created=>$(date -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --jq '[.workflow_runs[] | select(.status == "completed")] |
  group_by(.name) |
  map({name: .[0].name, total: length,
    success: map(select(.conclusion == "success")) | length,
    failure: map(select(.conclusion == "failure")) | length})'
```

Report these workflows:
- `Validate Pull Request` — Developer CI
- `Live Azure Validation` — Developer CI (note if < 5 runs: "small sample")
- `CodeQL`, `Scan controller image` — Security

## Output Format

Print the following report (fill in real numbers from the API calls above).
Use ✅ if reliability ≥ 90%, ⚠️ if 70–89%, ❌ if < 70%, 🚧 if not deployed/blocked.

```
━━━ CI Reliability Report — Week YYYY-WNN (Mon DD – Fri DD) ━━━━━━━━━━━━━━━━

### OpenShift CI (Prow) — ARO-HCP Environments
Target: >90% | Production-grade signal

| Environment | Job                            | Reliability     | Runs |
|-------------|--------------------------------|-----------------|------|
| US (DEV)    | …-capz-e2e                     | 100% (5/5) ✅   | 5    |
| Production  | …-capz-e2e-production          | 80% (4/5) ⚠️   | 5    |
| Staging     | —                              | 🚧 Capacity     | —    |
| Integration | —                              | 🚧 Capacity     | —    |

### GHA — Developer CI
Developer failures expected. Flag if main branch < 90%.

| Repo                          | Workflow                               | Reliability       | Runs |
|-------------------------------|----------------------------------------|-------------------|------|
| capi-tests                    | Full Cluster Deployment (main)         | 95% (20/21) ✅    | 21   |
| capi-tests                    | Full Cluster Deployment (bp-2.11)      | 60% (3/5) ❌      | 5    |
| capi-tests                    | Full Cluster Deployment (bp-2.17)      | 40% (2/5) ❌      | 5    |
| capi-tests                    | Full Cluster Deployment (bp-5.0)       | 60% (3/5) ❌      | 5    |
| capi-tests                    | Full Cluster Deployment (bp-5.1)       | 60% (3/5) ❌      | 5    |
| cluster-api-provider-azure    | PR capi-tests                          | 85% (11/13) ⚠️   | 13   |
| azure-service-operator        | Validate Pull Request                  | 92% (22/24) ✅    | 24   |
| azure-service-operator        | Live Azure Validation                  | 0% (0/1) ❌ ⚠small | 1  |

### GHA — Security Scans
All green = expected baseline. Flag any failure immediately.

| Repo                          | Scan                                   | Reliability | Runs |
|-------------------------------|----------------------------------------|-------------|------|
| capi-tests                    | Gosec / Govulncheck / Nancy / Trivy    | 100% each   | 9    |
| capi-tests                    | Fuzz / CodeQL / Scorecard / Dep Review | 100% each   | 2–5  |
| cluster-api-provider-azure    | CodeQL / Scorecard / Dep Review        | 100% each   | 4–17 |
| azure-service-operator        | CodeQL / Scan controller image         | 100% each   | 1–18 |

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Save to Obsidian Inbox

After printing the report, save it as a new page in Obsidian Inbox:

```bash
WEEK=$(date +%Y-W%V)
MON=$(date -d 'last monday' +%b\ %-d 2>/dev/null || date -v-monday +%b\ %-d)
FRI=$(date -d 'last monday + 4 days' +%b\ %-d 2>/dev/null || date -v+4d -v-monday +%b\ %-d)
OUTFILE="$OBSIDIAN_VAULT/050 Inbox/ci-reliability-${WEEK}.md"
```

Write the file with this frontmatter:

```markdown
---
title: "CI Reliability Report: WEEK (Mon – Fri)"
type: ci-report
week: YYYY-WNN
created: YYYY-MM-DD
---

[report content here]
```

Print: `Saved to: 050 Inbox/ci-reliability-YYYY-WNN.md`

## Notes

- Sippy "current" window = last 7 days; "previous" = 7 days before that
- GHA date filter uses `created` from 7 days ago — adjust if run on non-Monday
- Staging and Integration rows: update status from blocked to actual numbers once capacity is available
- Backplane branch failures: investigate only if > 2 consecutive weeks at < 70%
- `Live Azure Validation` (ASO): flag "small sample" if < 5 runs; treat as signal once ≥ 10 runs/week
