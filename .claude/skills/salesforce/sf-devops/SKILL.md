---
name: sf-devops
description: >
  Salesforce DevOps deployment skill — component discovery, confirmation gate,
  validate/deploy via MCP, test execution, git push, PR creation, and Jira update.
  TRIGGER when: salesforce-devops agent needs to deploy metadata, push to git,
  or create a PR. DO NOT TRIGGER for writing code or creating metadata.
---

# sf-devops: Salesforce Deployment & DevOps

Use this skill for the **end-to-end deployment workflow**: org check, component
discovery, confirmation, validate, deploy, test, git push, PR, and Jira update.

---

## Workflow

### Step 1 — Check Org Connection

Use `mcp__Salesforce__get_org_details` and display:

```
🔗 CONNECTED ORG: [Org Alias / Username]
   Environment:   [Sandbox / Production / Dev]
```

---

### Step 2 — Discover All Components to Deploy

Scan `.md` files only — never use `ls` directory scans.

> ⚠️ `agent-output/execution-summary-<KEY>.md` is NOT available here — it is written
> by the main agent **after** devops completes. Never attempt to read it.

**Scan order (in priority):**

| Priority | File | What to Extract | Available? |
|---|---|---|---|
| 1 ⭐ | `agent-output/component-tracker-<JIRA-KEY>.md` | All rows from 🔵 Admin + 🟡 Developer tables | ✅ Always |
| 2 | `agent-output/design-requirements.md` | Files Impacted table — Create/Modify entries | ✅ Always |
| 3 | `agent-output/code-review-<JIRA-KEY>.md` | File-by-File Summary table | ✅ If review ran |
| ❌ | ~~`agent-output/execution-summary-<KEY>.md`~~ | Not yet written | ❌ Never |

**Extraction rules:**
- Use the `Read` tool — never `cat` or `ls`
- Extract every row from both 🔵 Admin and 🟡 Developer tables in `component-tracker`
- Deduplicate across sources — include a file only once
- Include both the source file (`.cls`, `.html`, `.js`) AND its `-meta.xml` counterpart
- If `component-tracker` is missing → use `design-requirements.md` + ask user to confirm list

**Component type mapping:**

| Path Pattern | Component Type |
|---|---|
| `classes/*.cls` | ApexClass |
| `triggers/*.trigger` | ApexTrigger |
| `lwc/*/` | LightningComponentBundle |
| `objects/*/` | CustomObject / CustomField |
| `flows/*.flow-meta.xml` | Flow |
| `permissionsets/*.permissionset-meta.xml` | PermissionSet |

---

### Step 3 — Mandatory Confirmation Gate (DO NOT SKIP)

Display before ANY deployment:

```
═══════════════════════════════════════════════════════════════════════════════
  🚀 DEPLOYMENT CONFIRMATION REQUIRED
═══════════════════════════════════════════════════════════════════════════════
🎯 TARGET ORG:   [Org Alias / Username]
🌍 ENVIRONMENT:  [Sandbox / Production / Dev]
📄 SOURCE:       agent-output/component-tracker-<KEY>.md
───────────────────────────────────────────────────────────────────────────────
  📦 COMPONENTS TO BE DEPLOYED
───────────────────────────────────────────────────────────────────────────────
  #   Type                     Component Name          Action
 ---  ───────────────────────  ──────────────────────  ────────
  1   CustomObject             Feedback__c             Created
  2   ApexClass                FeedbackService         Created
  ...
Total Components: X
───────────────────────────────────────────────────────────────────────────────
  ⚙️ DEPLOYMENT OPTIONS
───────────────────────────────────────────────────────────────────────────────
  [A] Deploy ALL components listed above
  [P] Deploy PARTIAL — specify component numbers (e.g., "1,2,3,5")
  [C] CANCEL deployment
───────────────────────────────────────────────────────────────────────────────
Your choice (A/P/C):
═══════════════════════════════════════════════════════════════════════════════
```

**STOP and wait for user response before proceeding.**

---

### Step 4 — Process User Response

| Response | Action |
|---|---|
| A / All / Yes / Deploy all | Proceed to Step 5 with all components |
| P / Partial + numbers | Proceed to Step 5 with selected components only |
| C / Cancel / No / Stop | STOP — do not deploy anything |
| Unclear | Ask for clarification |

---

### Step 5 — Validate Deployment (Dry Run)

Run validation via `mcp__Salesforce__deploy_metadata`:

```json
{
  "operation": "validate",
  "checkOnly": true,
  "testLevel": "RunLocalTests",
  "sourcePath": "force-app/main/default"
}
```

Fix any validation errors before proceeding to Step 6.

---

### Step 6 — Execute Deployment

Deploy in **dependency order** via `mcp__Salesforce__deploy_metadata`:

```json
{
  "operation": "deploy",
  "checkOnly": false,
  "testLevel": "RunLocalTests",
  "sourcePath": "force-app/main/default"
}
```

**Dependency order:**
1. Custom Objects (`.object-meta.xml`)
2. Custom Fields (`fields/*.field-meta.xml`)
3. Validation Rules
4. Apex Classes (non-test)
5. Apex Triggers (`*.trigger`)
6. Test Classes (`*Test.cls`)
7. LWC Components (`lwc/*/`)
8. Flows (`flows/*.flow-meta.xml`)
9. Permission Sets

---

### Step 7 — Run Tests & Verify

Run tests via `mcp__Salesforce__run_apex_tests`:

```json
{ "testLevel": "RunLocalTests" }
```

Get coverage via `mcp__Salesforce__get_code_coverage`:

```json
{ "type": "all" }
```

---

### Step 8 — Deployment Report

```
═══════════════════════════════════════════════════════════════════════════════
  🚀 DEPLOYMENT REPORT
═══════════════════════════════════════════════════════════════════════════════
🔧 DEPLOYMENT METHOD: mcp__Salesforce__deploy_metadata
🎯 TARGET ORG:        [Org Alias / Username]
📅 TIMESTAMP:         [DateTime]
👤 CONFIRMED BY:      User
───────────────────────────────────────────────────────────────────────────────
  ✅ DEPLOYMENT STATUS
───────────────────────────────────────────────────────────────────────────────
Status:              SUCCESS / FAILED
Components Deployed: X of Y confirmed
Errors:              X
───────────────────────────────────────────────────────────────────────────────
  📦 COMPONENTS DEPLOYED
───────────────────────────────────────────────────────────────────────────────
  Type              Component           Status
  ───────────────── ─────────────────── ────────
  CustomObject      Feedback__c         ✅ Deployed
  ApexClass         FeedbackService     ✅ Deployed
  ...
Total: X components deployed successfully
───────────────────────────────────────────────────────────────────────────────
  🧪 TEST RESULTS
───────────────────────────────────────────────────────────────────────────────
Tests Run:     X  |  Passed: X  |  Failed: X  |  Coverage: XX%
───────────────────────────────────────────────────────────────────────────────
  📝 DEPLOYMENT LOG
───────────────────────────────────────────────────────────────────────────────
• [Step 1]: mcp__Salesforce__get_org_details          — Connected to [Org]
• [Step 2]: Discovered X components from component-tracker-<KEY>.md
• [Step 3]: User confirmed deployment
• [Step 4]: mcp__Salesforce__deploy_metadata (checkOnly: true)  — Validation passed
• [Step 5]: mcp__Salesforce__deploy_metadata (checkOnly: false) — Deployed
• [Step 6]: mcp__Salesforce__run_apex_tests  — X passed, X failed
• [Step 7]: mcp__Salesforce__get_code_coverage — XX% coverage
═══════════════════════════════════════════════════════════════════════════════
```

---

### Step 9 — Git Push Gate (after successful deployment ONLY)

#### 9a — Ask Before Pushing

```
✅ Deployment succeeded.
Would you like to push the changes to a feature branch on GitHub?
  [Y] Yes — create/push feature branch
  [N] No  — skip git push
Your choice (Y/N):
```

**STOP and wait. Never auto-push.**

#### 9b — Determine Branch Name

Read `agent-output/design-requirements.md` to extract the Jira issue key.

Branch naming: `feature/<ISSUE-KEY>-<short-kebab-description>`
If no Jira key: `feature/<short-kebab-description>`

#### 9c — Resolve Repo Details

**MCP-first — fall back to git CLI only when MCP is unavailable or fails:**

**Step 1 (Primary): Parse remote URL via git CLI (local-only query, no MCP equivalent)**

```bash
git remote get-url origin          # parse owner and repo from HTTPS or SSH URL
git rev-parse --abbrev-ref HEAD    # current branch (for reference only)
```

Parse `owner` and `repo` from the remote URL. Both HTTPS (`https://github.com/owner/repo.git`) and SSH (`git@github.com:owner/repo.git`) formats are supported.

**Step 2 (Primary): Verify repo + get default branch via GitHub MCP**

Use `mcp__github__get_repository`:

```
owner : <parsed-owner>
repo  : <parsed-repo>
```

Use the returned `default_branch` to confirm whether `main` or `master` is the base.

**Step 3 (Fallback — only if MCP call fails):**

```bash
git rev-parse origin/main    # get SHA for from_branch
```

Log which path was used: `[Git: MCP resolve]` or `[Git: CLI fallback]`.

If `main` doesn't exist: try `origin/master`. If neither, ask user.

#### 9d — Create Feature Branch from `main` via GitHub MCP

Use `mcp__github__create_branch`:

```
owner       : <owner>
repo        : <repo>
branch      : feature/<ISSUE-KEY>-<description>
from_branch : main   ← ALWAYS main — never the current or another feature branch
```

If branch already exists on remote: warn user and proceed to push without recreating.

#### 9e — Identify Files to Push

Use the component list from `agent-output/component-tracker-<JIRA-KEY>.md` (Step 2).
- Read each file with the `Read` tool
- Skip any file not found on disk — log as "file not found, skipped"
- Push **only story files** — never push `agent-output/`, `.claude/`, secrets

#### 9f — Push Files via GitHub MCP

Use `mcp__github__push_files`:

```
owner   : <owner>
repo    : <repo>
branch  : feature/<ISSUE-KEY>-<description>
message : "feat(<ISSUE-KEY>): <short description>

<one-sentence summary>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

files   : [
  { path: "force-app/main/default/classes/ClassName.cls",          content: "<content>" },
  { path: "force-app/main/default/classes/ClassName.cls-meta.xml", content: "<content>" },
  ...
]
```

#### 9g — Push Report

```
✅ GIT PUSH COMPLETE (via GitHub MCP)
   Branch  : feature/<ISSUE-KEY>-<description>  ← created from main
   Repo    : <owner>/<repo>
   Base    : main
   Files   : X files pushed
   Source  : agent-output/component-tracker-<KEY>.md
   Commit  : feat(<ISSUE-KEY>): <description>
```

---

### Step 10 — Create Pull Request

After successful push:

```
✅ Git push succeeded.
Would you like to create a Pull Request on GitHub?
  [Y] Yes — create PR now
  [N] No  — skip PR creation
Your choice (Y/N):
```

**STOP and wait for user response.**

If Yes — use `mcp__github__create_pull_request`:

```
owner : <owner>
repo  : <repo>
title : "feat(<ISSUE-KEY>): <short description>"
body  : "## Summary
- <bullet points from design-requirements.md>

## Jira
[<ISSUE-KEY>](<jira-issue-url>)

## Test plan
- [ ] Apex tests pass (RunLocalTests)
- [ ] LWC renders correctly in target page

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
head  : feature/<ISSUE-KEY>-<description>
base  : main
draft : false
```

Record the returned PR URL for the Jira update in Step 11.

---

### Step 11 — Update Jira Issue (Automatic after git push)

Extract Jira key from `agent-output/design-requirements.md`.

If found, post via `mcp__mcp-atlassian__jira_add_comment`:

```
issue_key : <ISSUE-KEY>
comment   :
🚀 *Deployment & Push Complete*

*Branch:* [feature/<ISSUE-KEY>-<desc>](https://github.com/<owner>/<repo>/tree/feature/<ISSUE-KEY>-<desc>)
*Base branch:* main
*Pull Request:* [PR #<number> — <title>](<PR-URL>)  _(omit if no PR created)_

*Deployed to:* <Org Alias> (<Sandbox / Production>)
*Deployment status:* ✅ Success
*Deployment tool:* mcp__Salesforce__deploy_metadata

*Components deployed:*
|| Type || Component ||
| <type> | <name> |

*Apex test results:* X passed, X failed — Coverage: XX%
*Committed by:* Claude Sonnet 4.6 (automated)
*Date:* <YYYY-MM-DD>
```

**Rules:**
- Only post if a valid Jira key (`[A-Z]+-\d+`) is found
- If no key, skip silently and note in final report
- Never post duplicate comments — runs once per deployment
- If MCP fails, log error but do not block the workflow

---

## MCP Operations Reference

| Operation | Primary (MCP) | Fallback (git CLI) | Key Parameters |
|---|---|---|---|
| Check org | `mcp__Salesforce__get_org_details` | — | — |
| Validate (dry-run) | `mcp__Salesforce__deploy_metadata` | — | `checkOnly: true`, `testLevel: RunLocalTests` |
| Deploy | `mcp__Salesforce__deploy_metadata` | — | `checkOnly: false`, `testLevel: RunLocalTests` |
| Run Apex tests | `mcp__Salesforce__run_apex_tests` | — | `testLevel: RunLocalTests` |
| Get coverage | `mcp__Salesforce__get_code_coverage` | — | `type: all` |
| Verify repo / default branch | `mcp__github__get_repository` | `git remote get-url origin` | `owner`, `repo` |
| Create feature branch | `mcp__github__create_branch` | `git checkout -b feature/... && git push -u origin feature/...` | `from_branch: main` |
| Push files to branch | `mcp__github__push_files` | `git add <files> && git commit -m "..." && git push` | — |
| Create PR | `mcp__github__create_pull_request` | — (no CLI equivalent — warn user) | `base: main` |
| Jira comment | `mcp__mcp-atlassian__jira_add_comment` | — | — |
| Get remote URL (local-only) | _(no MCP equivalent)_ | `git remote get-url origin` | — |
| Get current branch (local-only) | _(no MCP equivalent)_ | `git rev-parse --abbrev-ref HEAD` | — |

---

## Git / GitHub Rules

| Rule | Detail |
|---|---|
| **GitHub MCP first** | All remote git operations (`create_branch`, `push_files`, `create_pull_request`) use `mcp__github__*` — never raw `git push` to remote |
| **git CLI fallback** | If a GitHub MCP call fails or is unavailable, fall back to `git` CLI commands — log which path was taken: `[Git: MCP]` or `[Git: CLI fallback]` |
| **Local-only queries** | `git remote get-url`, `git rev-parse`, `git status`, `git log` — these are local-only; no MCP equivalent. Run via Bash. Prefer MCP for anything that touches GitHub's API |
| Never auto-push | Always ask user confirmation before any push |
| Feature branches only | Never push directly to `main` or `master` |
| Always branch from main | `from_branch` must always be `main` |
| component-tracker is source | Push only files listed in `component-tracker-<KEY>.md` |
| No force push to main | Warn and refuse |
| No --no-verify | Never skip pre-commit hooks |
| Meaningful commit | `feat(<KEY>): <description>` format with Co-Author trailer |
| Always update Jira | Auto after every git push |

---

## Production Deployment Warning

If deploying to PRODUCTION, add:

```
⚠️⚠️⚠️  PRODUCTION DEPLOYMENT WARNING  ⚠️⚠️⚠️

You are about to deploy to PRODUCTION.
This will modify LIVE metadata and affect REAL users immediately.

Type 'CONFIRM PRODUCTION' to proceed.
```

Only proceed on explicit confirmation.

---

## Error Handling

| Error | Cause | Solution |
|---|---|---|
| `FIELD_INTEGRITY_EXCEPTION` | Missing dependency | Deploy objects first |
| `INVALID_CROSS_REFERENCE_KEY` | Invalid reference | Check dependencies |
| `INSUFFICIENT_ACCESS` | Permission issue | Check user permissions |
| `TEST_FAILURE` | Test failed | Fix test before retry |
