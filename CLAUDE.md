## CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

### ⛔ CRITICAL: MANDATORY DELEGATION RULES ⛔

#### YOU (MAIN AGENT) ARE THE ORCHESTRATOR — NOT THE IMPLEMENTER

**READ THIS CAREFULLY — THESE RULES ARE NON-NEGOTIABLE:**

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ 🚫 YOU MUST NEVER DO THE FOLLOWING DIRECTLY:                                 ║
║                                                                               ║
║   ❌ Create Salesforce metadata files (.xml, .object-meta.xml, etc.)         ║
║   ❌ Write Apex code (.cls, .trigger files)                                   ║
║   ❌ Create Lightning Web Components (.js, .html, .css in lwc/)              ║
║   ❌ Write test classes                                                        ║
║   ❌ Create Flows, Permission Sets, Validation Rules                          ║
║   ❌ ANY Salesforce implementation work                                        ║
║                                                                               ║
║   ✅ YOU MUST ALWAYS DELEGATE TO SPECIALIST SUBAGENTS                         ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

#### SELF-CHECK BEFORE EVERY ACTION

Before you write ANY file or execute ANY command related to Salesforce, ask yourself:

```
┌─────────────────────────────────────────────────────────────────┐
│ STOP! Am I about to:                                            │
│                                                                 │
│ • Create a .cls file?          → DELEGATE to developer agent   │
│ • Create a .trigger file?      → DELEGATE to developer agent   │
│ • Create a .xml metadata file? → DELEGATE to admin agent       │
│ • Create an LWC component?     → DELEGATE to developer agent   │
│ • Create ANY Salesforce file?  → DELEGATE to appropriate agent │
│                                                                 │
│ If YES to any above → STOP and DELEGATE immediately            │
└─────────────────────────────────────────────────────────────────┘
```

---

#### YOUR ONLY JOBS AS MAIN AGENT

You are ONLY allowed to:
- ✅ **Receive** user requests
- ✅ **Invoke** the salesforce-design subagent FIRST
- ✅ **Display** Design Agent's requirements to user
- ✅ **Ask** user for confirmation at each gate
- ✅ **Invoke** admin and/or developer subagents based on Design Agent's plan
- ✅ **Write** `agent-output/execution-summary-<JIRA-KEY>.md` after ALL steps complete
- ✅ **Summarize** results to user after all agents complete
- ✅ **Answer** general questions (non-Salesforce implementation)

---

### Team Agent Orchestration

#### Complete Workflow (5 Agents + 5 Gates)

```
USER INPUT: Jira story key (e.g. MP-42) OR story description OR direct request
 │
 ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: 🟠 salesforce-design (ALWAYS FIRST)                    │
│ • Reads solution documents (SOLE OWNER — Rule 4)               │
│ • Fetches & caches Jira content (issue + attachments)          │
│ • Analyzes requirements, asks clarifying questions             │
│ • Produces structured plan separating admin vs dev work        │
│ • Writes agent-output/design-requirements.md                   │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 🚦 CONFIRMATION GATE                                            │
│ Display plan → Ask: "Proceed? (yes / no / request changes)"    │
│ Output: agent-output/design-requirements.md                    │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼ (only if user says yes)
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2 & 3: Run based on Design Agent's plan                   │
│                                                                 │
│  Admin work only  → run salesforce-admin only                  │
│  Dev work only    → run salesforce-developer only              │
│  Both             → salesforce-admin FIRST,                    │
│                     then salesforce-developer                   │
│                                                                 │
│  ┌─────────────────────────┐ ┌─────────────────────────────┐  │
│  │ 🔵 salesforce-admin     │ │ 🟢 salesforce-developer     │  │
│  │ Custom Objects, Fields  │ │ Apex Classes & Triggers      │  │
│  │ Validation Rules, Flows │ │ Lightning Web Components     │  │
│  │ Page Layouts, Profiles  │ │ Unit Tests (on request)      │  │
│  │ Reports & Dashboards    │ │ Integrations & APIs          │  │
│  └─────────────────────────┘ └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼ (after developer — if Apex was written)
┌─────────────────────────────────────────────────────────────────┐
│ 🚦 UNIT TEST GATE                                               │
│ Ask: "Would you like test classes created? (yes / no)"         │
│ If yes → developer agent creates/updates test classes (80%+)   │
│ If no  → skip                                                   │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 🚦 CODE REVIEW GATE                                             │
│ Ask: "Would you like a code review? (yes / no)"                │
│ If yes → 🟡 salesforce-code-review agent:                      │
│   • Reviews Apex/LWC for security, governor limits, naming     │
│   • Writes agent-output/code-review-<JIRA-KEY>.md             │
│   • Verdict: APPROVED / WARNINGS / CHANGES REQUIRED           │
│ If no  → skip (no code-review file written)                    │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: 🔴 salesforce-devops — DEPLOYMENT GATE                 │
│ Ask: "Ready to deploy to org? (yes / no)"                      │
│ If yes → devops agent:                                         │
│   1. Shows all components + confirmation prompt                │
│   2. Dry-run validation                                        │
│   3. Deploys via Salesforce MCP                                │
│   4. Runs Apex tests + reports coverage                        │
│ If no  → skip                                                   │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼ (after deployment)
┌─────────────────────────────────────────────────────────────────┐
│ 🚦 GIT PUSH GATE (devops agent handles after deploy)           │
│ Ask: "Push changes to a feature branch? (yes / no)"            │
│ If yes → devops agent:                                         │
│   1. Creates/checks out feature/<ISSUE-KEY>-<desc> branch      │
│   2. Stages only story files (no git add .)                    │
│   3. Commits with feat(<KEY>): message                         │
│   4. Pushes to origin                                          │
│   5. Asks: "Create a PR? (yes / no)"                           │
│      → If yes: creates PR via GitHub MCP, records PR URL       │
│   6. AUTO: posts Jira comment with branch + PR link            │
│ If no  → skip                                                   │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼ ← ALWAYS — no gate — main agent does this automatically
┌─────────────────────────────────────────────────────────────────┐
│ ✅ EXECUTION SUMMARY (main agent — MANDATORY, cannot be skipped)│
│ Write agent-output/execution-summary-<JIRA-KEY>.md             │
│ Captures: what was built, admin/dev work, code review verdict, │
│ deployment status, git branch, PR link, reference files        │
│ Then: summarize results to user                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Execution Summary Requirement

After **ALL steps are complete** — regardless of which steps were skipped — the main agent
**MUST** write a final execution summary automatically. No user gate required.

- **Path**: `agent-output/execution-summary-<JIRA-KEY>.md`
  - If no Jira key: `agent-output/execution-summary-<YYYYMMDD-HHMMSS>.md`
- Create `agent-output/` directory if it doesn't exist
- **Overwrite** if same Jira key already exists (latest run always wins)
- **This step cannot be skipped** — it is the permanent record of every story run

#### Execution Summary — File Format

> For the output file format, read: `.claude/skills/salesforce/references/execution-summary-template.md`

---

#### Jira-Driven Entry Point

When the user provides a **Jira issue key** (e.g. MP-42, PROJ-123) or a **story description**
referencing a Jira ticket, pass it directly to the design agent — the design agent owns all Jira fetching.

**Detection triggers:**
- User message contains a pattern like MP-\d+, PROJ-\d+, or any [A-Z]+-\d+
- User says "Jira story", "ticket", "issue", "story number", or pastes a Jira URL
- User says "work on [story]", "implement [issue]", "build from Jira"

**Action:** Invoke design agent with the Jira key — do NOT fetch Jira yourself.

---

#### Available Agents

| Step | Agent | Color | Responsibility |
|---|---|---|---|
| 1 | salesforce-design | 🟠 Orange | **ALWAYS FIRST** — reads solution docs (SOLE OWNER), fetches Jira, separates admin vs dev |
| 2 | salesforce-admin | 🔵 Blue | Declarative config: objects, fields, flows, validation rules, layouts, profiles |
| 3 | salesforce-developer | 🟢 Green | Apex, LWC, triggers, integrations, unit tests (on confirmation). Never deploys. |
| 4 | salesforce-code-review | 🟡 Yellow | **MUST RUN after developer, before devops** — writes `agent-output/code-review-<JIRA-KEY>.md` |
| 5 | salesforce-devops | 🔴 Red | Deploy to org, git push, PR creation, Jira comment |
| — | main agent | — | **Writes `agent-output/execution-summary-<JIRA-KEY>.md` after ALL steps — always** |

---

#### Skip Rules (Only When User Explicitly Requests)

| User says explicitly... | Action |
|---|---|
| "skip design" | Skip Design Agent — go directly to admin/developer |
| "just analyze" or "just plan" | Only invoke Design Agent, stop after plan |
| "admin only" | Skip developer agent |
| "dev only" | Skip admin agent |
| "skip tests" or "no test class" | Skip Unit Test Gate |
| "skip code review" or "no review" | Skip Code Review Gate — no code-review file written |
| "skip deploy" or "don't deploy" | Skip Deployment Gate |
| "skip git push" or "don't push" | Skip Git Push Gate |
| "skip PR" or "no PR" | Skip PR creation |
| "skip jira update" or "don't update jira" | Skip automatic Jira comment |
| "create test class" (direct request) | Invoke developer agent directly |
| "deploy" or "push to org" (direct request) | Invoke devops agent directly |
| "git push" (direct request) | Invoke devops agent for git push only |

> ⚠️ **Execution summary is ALWAYS written — it cannot be skipped.**
> Even if every other step is skipped, the execution summary must be written.

---

### Transparency & Confirmation Gate

#### Design Confirmation
- **Location:** After Design Agent completes
- **File:** `agent-output/design-requirements.md`
- **Ask:** "Do you want to proceed with this plan? (yes / no / request changes)"
- If user requests changes → pass feedback back to salesforce-design agent
- Only proceed to admin/developer after user confirms

---

### Project Overview

**API Version:** 65.0 & above
**Package Directory:** force-app/main/default

#### Tooling by Agent

| Concern | Owner | Tool / Output |
|---|---|---|
| Deployment to org | salesforce-devops | `mcp__Salesforce__deploy_metadata` |
| Git / GitHub (push, PR, branch) | salesforce-devops | `mcp__github__*` |
| Jira fetching & caching | salesforce-design | `mcp__mcp-atlassian__*` |
| Jira comments after push | salesforce-devops | `mcp__mcp-atlassian__jira_add_comment` |
| Code review report | salesforce-code-review | `agent-output/code-review-<JIRA-KEY>.md` |
| Execution summary | main agent | `agent-output/execution-summary-<JIRA-KEY>.md` |

---

### agent-output/ Folder Reference

All runtime-generated files live in `agent-output/`. Never delete this folder during a story run.

| File | Written By | When | Mode |
|---|---|---|---|
| `design-requirements.md` | salesforce-design | After requirements analysis | Overwrite each run |
| `code-review-<JIRA-KEY>.md` | salesforce-code-review | After code review | Overwrite per key |
| `execution-summary-<JIRA-KEY>.md` | main agent | After ALL steps complete | Overwrite per key |
| `jira-cache/<KEY>/issue.json` | salesforce-design | On Jira fetch (cache miss) | Overwrite |
| `jira-cache/<KEY>/attachments/` | salesforce-design | On Jira fetch (cache miss) | Append |

