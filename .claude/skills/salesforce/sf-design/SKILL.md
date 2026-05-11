---
name: sf-design
description: >
  Salesforce requirements analysis and solution design skill.
  TRIGGER when: salesforce-design agent needs to analyze a request, check
  existing metadata, produce structured requirements, or classify Admin vs Dev work.
  DO NOT TRIGGER when: writing code, creating metadata, or deploying.
---

# sf-design: Salesforce Requirements Analysis & Design

Use this skill to **analyze, clarify, and structure** Salesforce requirements
before any implementation begins.

---

## Workflow

### Step 1 — Analyze the Request

Identify from the user's request:
1. What is explicitly requested?
2. What information is missing or unclear?
3. What is Admin work vs Development work?

### Step 2 — Check Existing Metadata

Scan the codebase before assessing whether information is sufficient:

- `tdd/` — Technical Design Documents for the story (searched in Step 2b-i)
- `force-app/main/default/objects/` — existing custom objects and fields
- `force-app/main/default/lwc/` — existing LWC components serving the same purpose
- `force-app/main/default/classes/` — existing Apex classes and triggers
- `force-app/main/default/flows/` — existing flows
- `CLAUDE.md` — documented custom objects, standard objects, and integrations

**Record findings:**
- If a requested field/object/component **already exists** → flag to admin/developer to modify, not recreate
- If existing metadata will be **impacted** by the change → flag the dependency explicitly

### Step 2a — Download Jira Attachments (ALWAYS for Jira-driven stories)

> ⚠️ **MANDATORY — run before Step 2b, regardless of whether a TDD is found later.**
> Do NOT use `mcp__mcp-atlassian__jira_download_attachments` — it writes to a temporary path. Use `curl` via `Bash` instead.

**Steps:**

1. Fetch attachment metadata:
   ```
   mcp__mcp-atlassian__jira_get_issue(issue_key=<KEY>, fields="attachment")
   ```
   This returns each attachment's `filename`, `url`, and `content_type`.

2. Read Jira credentials from `.claude/settings.local.json` → `env` block (`JIRA_USERNAME`, `JIRA_API_TOKEN`).

3. Create the local attachments folder using `Bash`:
   ```bash
   mkdir -p "agent-output/jira-cache/<KEY>/attachments"
   ```

4. For **each attachment**, download using `Bash` + curl:
   ```bash
   curl -L -s \
     -u "<JIRA_USERNAME>:<JIRA_API_TOKEN>" \
     "<attachment.url>" \
     -o "agent-output/jira-cache/<KEY>/attachments/<filename>"
   ```
   Use `-L` to follow redirects (required for Atlassian CDN). Quote the output path if it contains spaces.

5. Verify each download succeeded:
   ```bash
   ls -lh "agent-output/jira-cache/<KEY>/attachments/"
   ```
   If any file is 0 bytes or missing, retry once. If it still fails, log the failure in the requirements output and continue.

6. For image files (PNG, JPG), use the `Read` tool to view the mockup inline. **This applies even when a TDD is found — the TDD skip rule (Step 2b-i) applies only to solution documents (DOCX/PDF), never to image mockups.**

---

### Step 2b — Read Solution Documents (TDD Folder First, then Direct Provision)

#### Step 2b-i — TDD Folder (ALWAYS check first for Jira-driven stories)

Use `Glob` with pattern `TDD/**/*<ISSUE-KEY>*` (case-insensitive) to find a Technical Design Document. File names vary; the only guarantee is that the issue key appears somewhere in the name (e.g. `MP-7-Product-Information-Section.md`, `MP7_Solution_v2.md`).

- If a matching TDD file is found:
  - Read it **fully** before producing requirements
  - Treat it as the **sole authoritative design solution** for this story
  - Skip the solution document (DOCX/PDF) attached to the Jira issue — do not read it
  - **Do NOT skip image mockups (PNG/JPG)** — they must be downloaded and read per Step 2a regardless
- If no TDD file is found → proceed to Step 2b-ii

#### Step 2b-ii — User-Provided or Jira-Attached Document (only if NO TDD found)

If the user provides a solution document directly (PDF, DOCX, XLSX, MD), or a solution document is attached to the Jira issue:

- Read it **fully** before producing requirements — never skim
- Treat it as **authoritative requirements** — reflect its content exactly
- Do **not contradict** any specification in the document
- If it conflicts with a UI mockup → **ask the user** which takes precedence before finalizing

- Include a `📄 Solution Document Summary` in the requirements output (note the source: TDD or Jira/user-provided)
- The plan is **NOT finalized** until all document content is incorporated and conflicts resolved

**Solution Document Checklist (run before Step 3):**
- [ ] Were ALL Jira attachments downloaded to `agent-output/jira-cache/<KEY>/attachments/`? (Step 2a)
- [ ] Were ALL image files (PNG/JPG) viewed with the `Read` tool?
- [ ] Was `tdd/` searched for a TDD matching the Jira issue key?
- [ ] If TDD found — has it been fully read? (DOCX/PDF skipped; images still required)
- [ ] If no TDD — has the user-provided or Jira-attached document been fully read?
- [ ] Are ALL requirements from the document captured in Admin and Dev sections?
- [ ] Do any document specs conflict with the mockup? (if yes → ask user)
- [ ] Has a `📄 Solution Document Summary` been added to the requirements output?

### Step 3 — Check if Information is Sufficient

**For Custom Fields:**
- [ ] Does the field already exist? (check `objects/` folder)
- [ ] Field name specified?
- [ ] Field type specified? (Text, Number, Picklist, Lookup, etc.)
- [ ] If Picklist — values specified?
- [ ] If Lookup — target object specified?
- [ ] If Text — length specified? (or accept default 255)

**For Triggers / Apex:**
- [ ] Does a trigger/class already exist for this object?
- [ ] Which object?
- [ ] What events? (before/after insert/update/delete)
- [ ] What should it do? (clear logic)
- [ ] What fields are involved?

**For LWC Components:**
- [ ] Does an LWC component already exist for this purpose?
- [ ] Is a mockup or design image attached?
- [ ] What should it display?
- [ ] What user interactions?
- [ ] Where should it appear? (Record page, App page, etc.)

**If ANY critical information is missing → ASK before proceeding.**

### Step 4 — Ask Clarifying Questions (If Needed)

If information is insufficient:

```
I need some clarifications before I can structure this request:

1. [Specific question about missing info]
2. [Specific question about missing info]

Please provide these details so I can create accurate requirements.
```

**STOP and wait for user response. Do not proceed with assumptions.**

### Step 5 — Produce Structured Requirements (Only When Confident)

Use this exact format:

```
═══════════════════════════════════════════════════════════════════════════════
                    📋 DESIGN REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════════

🎯 WHAT USER REQUESTED:
[Exactly what the user asked for — no additions]

📄 SOLUTION DOCUMENT SUMMARY (include only if a document was provided):
[Key requirements extracted from the solution document]
[Note any conflicts with mockup and how they were resolved]
[Or write: "No solution document provided"]

───────────────────────────────────────────────────────────────────────────────
                    🔵 ADMIN WORK (salesforce-admin)
───────────────────────────────────────────────────────────────────────────────

[Only items explicitly requested that are Admin work]

• [Item 1]: [Exact specifications from user request]
• [Item 2]: [Exact specifications from user request]

(If none: "No admin work required for this request")

───────────────────────────────────────────────────────────────────────────────
                    🟢 DEVELOPMENT WORK (salesforce-developer)
───────────────────────────────────────────────────────────────────────────────

[Only items explicitly requested that are Development work]

• [Item 1]: [Exact specifications from user request]
• [Item 2]: [Exact specifications from user request]

(If none: "No development work required for this request")

───────────────────────────────────────────────────────────────────────────────
                    🔗 EXECUTION ORDER
───────────────────────────────────────────────────────────────────────────────

[Only if there are dependencies between tasks]

1. [First task] — because [dependency reason]
2. [Second task] — depends on step 1

───────────────────────────────────────────────────────────────────────────────
                    📝 PROMPTS FOR SPECIALIST AGENTS
───────────────────────────────────────────────────────────────────────────────

🔵 PROMPT FOR salesforce-admin:
"""
[Only what user requested — no extras]
[Use project conventions from CLAUDE.md]
[Do not deploy — just create metadata files]
"""

🟢 PROMPT FOR salesforce-developer:
"""
[Only what user requested — no extras]
[Use project conventions, follow existing trigger handler pattern]
[Include test class only if user requested it]
"""

═══════════════════════════════════════════════════════════════════════════════
```

**Output file:** write requirements to `agent-output/design-requirements.md` (overwrite each run; create directory if needed).

**UI/LWC Guidance — When crafting the developer agent prompt:**
When Jira attachments include mockups or the request involves LWC components, include in "PROMPT FOR salesforce-developer":
- Whether a mockup/image exists and what it shows (developer must match it exactly)
- Whether a solution document exists and its relevant requirements summary
- Whether an existing LWC component was found that should be modified (not recreated)
- The **local file path** of the mockup/document — not Jira URLs
- Ask the user about mockup/document ambiguities **before** finalizing the prompt
> Implementation fidelity rules (SLDS, LDS-first, modify-vs-recreate) are owned by the developer agent — do not include in the prompt.

---

## Classification Guide

### Admin Work
- Custom Objects, Custom Fields, Validation Rules
- Page Layouts, Permission Sets
- Flows, Reports, Dashboards

### Development Work
- Apex Classes, Apex Triggers, Test Classes
- Lightning Web Components (LWC), Aura, Visualforce
- REST/SOAP APIs, Integrations

---

## What You MUST NOT Do

| ❌ DON'T | ✅ DO INSTEAD |
|---|---|
| Add validation rules not requested | Only include if user asked |
| Add permission sets not requested | Only include if user asked |
| Assume picklist values | Ask user for values |
| Add error handling details | Only include if user specified |
| Add test scenarios | Only include if user asked for test class |
| Suggest "you might also want…" | Stick to what was requested |
| Add FLS/security unless asked | Only include if user specified |
| Expand "notification" to email templates, etc. | Ask what type of notification |
| Pass raw solution documents to developer agent | Interpret docs and pass finalized plan only |
| Let developer agent read solution documents | Design agent owns ALL document interpretation |

---

## Project Conventions (Apply to All Prompts)

- **Field Prefix**: project-specific prefix defined in `CLAUDE.md`
- **API Version**: as specified in `sfdx-project.json`
- **Trigger Pattern**: follow existing handler pattern discovered in codebase
- **Package Directory**: `force-app/main/default`

---

## Examples

### Example 1 — Sufficient Information

**Request:** "Create two text fields on Account: `Claude_Name__c` and `Gemini_Name__c`, and a trigger that adds 'AI_' prefix on insert and update"

All information present → proceed with structured requirements, no questions.

---

### Example 2 — Insufficient Information

**Request:** "Create a feedback tracking system"

```
I need some clarifications before I can structure this request:

1. What fields should the Feedback object have?
2. What are the field types?
3. Should Feedback relate to another object?
4. Is any automation needed?
5. Is a UI component needed?
```

STOP and wait for user response.

---

### Example 3 — Partial Information

**Request:** "Create a Status field on Account and a trigger to update related Contacts when it changes"

```
I need one clarification:

1. What type should the Status field be?
   - Picklist? (If yes, what values?)
   - Text?
```

---

### Example 4 — Solution Document Provided

**Request:** "Implement MP-7 based on this solution document [MP-7-Product-Information-Section.md]"

1. Read the document fully (never skim)
2. Check existing metadata in codebase
3. Produce requirements with `📄 Solution Document Summary`
4. Resolve any conflicts with mockup — ask user if needed
5. Pass only the finalized plan to developer/admin agents — never the raw document
