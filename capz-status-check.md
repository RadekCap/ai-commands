---
description: Full status report for all four CAPZ stolostron repos — GHA workflows, issues, PRs, security alerts
---

# CAPZ Status Check

Full status report across `stolostron/capi-tests`, `stolostron/cluster-api-provider-azure`, `stolostron/azure-service-operator`, and `stolostron/cluster-api-installer`.

## Usage

```
/capz-status-check
```

## Steps

### 1. GHA Workflow Status

Print:
```
━━━ ▶ Running /capz-status-check ━━━━━━━━━━━━━━
```

```
━━━ GHA Workflow Status ━━━━━━━━━━━━━━━━━━━━━━━
```

Provide links for manual check (non-GHA):
```
  - [ ] OpenShift CI:  https://prow.ci.openshift.org/?job=periodic-ci-stolostron-capi-tests-*
  - [ ] ACM Jenkins:   https://jenkins-csb-rhacm-tests.dno.corp.redhat.com/job/CI-Jobs/job/capz_tests/
```

Fetch the latest GHA workflow runs programmatically for all watched workflows.

**stolostron/capi-tests:**
```bash
gh run list --repo stolostron/capi-tests --workflow "management-cluster-aro.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "workload-cluster-aro.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "workload-cluster-aro-backplane-2.11.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "workload-cluster-aro-backplane-2.17.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "workload-cluster-aro-backplane-5.0.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "workload-cluster-aro-backplane-5.1.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "stale-resources.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-nancy.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-govulncheck.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-trivy.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-gosec.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-codeql.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-dependency-review.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-scorecard.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/capi-tests --workflow "security-fuzz.yml" --limit 1 --json status,conclusion,createdAt,name
```

Also check Dependabot update job results (dynamic workflow, not queryable via `gh run list`):
```bash
gh api "repos/stolostron/capi-tests/actions/runs?per_page=10&event=dynamic" \
  --jq '[.workflow_runs[] | select(.name | startswith("docker"))] | first | {name, conclusion, created_at}'
```
Show result as `Dependabot Updates (docker)` row in the table. A `failure` conclusion means the Docker updater failed (e.g. private registry auth error).

Note: Copilot code review and Dependency Graph are dynamic workflows with no programmatic access — check via GitHub UI:
```
  - [ ] https://github.com/stolostron/capi-tests/actions
```

**stolostron/cluster-api-provider-azure:**
```bash
gh run list --repo stolostron/cluster-api-provider-azure --workflow "codeql.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "cover.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "dependabot-code-gen.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "dependency-review.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "ffwd-branch.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "lint-docs.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "pr-capi-tests.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "pr-golangci-lint.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "renovate.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "scorecards.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "upstream-sync.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-provider-azure --workflow "weekly-security-scan.yaml" --limit 1 --json status,conclusion,createdAt,name
```

Note: Dependency Graph is a dynamic workflow — check via GitHub UI:
```
  - [ ] https://github.com/stolostron/cluster-api-provider-azure/actions
```

**stolostron/azure-service-operator:**
```bash
gh run list --repo stolostron/azure-service-operator --workflow "codeql.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "ffwd-branch.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "pr-capi-tests.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "pr-validation-fork.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "pr-validation.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "renovate.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "scan-controller-image.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "scorecards.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/azure-service-operator --workflow "weekly-security-scan.yaml" --limit 1 --json status,conclusion,createdAt,name
```

Also check Dependabot update job results:
```bash
gh api "repos/stolostron/azure-service-operator/actions/runs?per_page=10&event=dynamic" \
  --jq '[.workflow_runs[] | select(.name | startswith("docker"))] | first | {name, conclusion, created_at}'
```
Show result as `Dependabot Updates (docker)` row in the table.

Note: Dependency Graph and dynamic CodeQL are dynamic workflows with no programmatic access — check via GitHub UI:
```
  - [ ] https://github.com/stolostron/azure-service-operator/actions
```

**stolostron/cluster-api-installer:**
```bash
gh run list --repo stolostron/cluster-api-installer --workflow "chart-tests-minikube.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-installer --workflow "ci-mce-capi-webhook-config.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-installer --workflow "crons.yml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-installer --workflow "ffwd-branch.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-installer --workflow "sync-providers.yaml" --limit 1 --json status,conclusion,createdAt,name
gh run list --repo stolostron/cluster-api-installer --workflow "test-helm-capi-capa-kind.yaml" --limit 1 --json status,conclusion,createdAt,name
```

Also check Dependabot update job results:
```bash
gh api "repos/stolostron/cluster-api-installer/actions/runs?per_page=10&event=dynamic" \
  --jq '[.workflow_runs[] | select(.name | startswith("Dependabot"))] | first | {name, conclusion, created_at}'
```
Show result as `Dependabot Updates` row in the table.

Note: Dependency Graph and dynamic CodeQL are dynamic workflows with no programmatic access — check via GitHub UI:
```
  - [ ] https://github.com/stolostron/cluster-api-installer/actions
```

Print results grouped by repo as a table: ✅ passing / ❌ failing / ⏳ running / ⚪ no runs for each.

### 2. Repo Status

Print:
```
━━━ Repo Status ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

For each of the three repos, check and print:

#### Issues

```bash
gh issue list --repo stolostron/capi-tests --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
gh issue list --repo stolostron/cluster-api-provider-azure --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
gh issue list --repo stolostron/azure-service-operator --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
gh issue list --repo stolostron/cluster-api-installer --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
```

If no open issues for a repo, print: `  (none)`

#### Pull Requests

```bash
gh pr list --repo stolostron/capi-tests --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
gh pr list --repo stolostron/cluster-api-provider-azure --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
gh pr list --repo stolostron/azure-service-operator --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
gh pr list --repo stolostron/cluster-api-installer --state open --json number,title,url --jq '.[] | "  - #\(.number) \(.title) — \(.url)"'
```

If no open PRs for a repo, print: `  (none)`

#### Security & Code Scanning Alerts

```bash
gh api repos/stolostron/capi-tests/code-scanning/alerts?state=open --jq '.[] | "  - \(.rule.description // .rule.id) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
gh api repos/stolostron/cluster-api-provider-azure/code-scanning/alerts?state=open --jq '.[] | "  - \(.rule.description // .rule.id) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
gh api repos/stolostron/azure-service-operator/code-scanning/alerts?state=open --jq '.[] | "  - \(.rule.description // .rule.id) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
gh api repos/stolostron/cluster-api-installer/code-scanning/alerts?state=open --jq '.[] | "  - \(.rule.description // .rule.id) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
```

Also check Dependabot alerts:
```bash
gh api repos/stolostron/capi-tests/dependabot/alerts?state=open --jq '.[] | "  - \(.security_advisory.summary) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
gh api repos/stolostron/cluster-api-provider-azure/dependabot/alerts?state=open --jq '.[] | "  - \(.security_advisory.summary) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
gh api repos/stolostron/azure-service-operator/dependabot/alerts?state=open --jq '.[] | "  - \(.security_advisory.summary) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
gh api repos/stolostron/cluster-api-installer/dependabot/alerts?state=open --jq '.[] | "  - \(.security_advisory.summary) — \(.html_url)"' 2>/dev/null || echo "  (no access or none)"
```

Print format per repo:
```
📦 stolostron/capi-tests
  Issues:
    - #123 Title — https://...
  PRs:
    - #456 Title — https://...
  Security:
    - Alert description — https://...
```

If all three categories are empty for a repo, print: `  ✅ All clear`

### 3. Finish

Print:
```
━━━ ✔ Finished /capz-status-check ━━━━━━━━━━━━━
```
