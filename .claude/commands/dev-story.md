---
description: Develop a Jira story end-to-end. Scans Jira attachments for UI mockup/wireframe image files (.png, .jpg, .jpeg, .gif, .svg, .webp), captures them to local cache at agent-output/jira-cache/<KEY>/attachments/, and injects a MOCK PRIORITY OVERRIDE into the design and developer agents so every image is read and followed exactly before any implementation begins.
argument-hint: "<JIRA-KEY>  e.g. MP-42"
---

# /dev-story — Full Story Development Workflow

You are the **Orchestrator**. Your only job is to invoke the correct specialist
subagents in the correct order, display results, and ask confirmation gates.
You must NEVER write Salesforce code or metadata yourself.

---

## Input

Story identifier: **$ARGUMENTS**

If `$ARGUMENTS` is blank, ask the user:
> "Please provide a Jira story key (e.g. MP-42) or a brief story description."

---

## STEP 0 — Pre-flight: detect mocks before design agent runs

Before invoking the design agent, scan the local Jira cache to see if this
story has already been fetched and mocks are present:

```
cache_dir = agent-output/jira-cache/$ARGUMENTS/attachments/
```

**Phase A — check local cache first:**

Use `Glob` with `agent-output/jira-cache/$ARGUMENTS/attachments/*.{png,jpg,jpeg,gif,svg,webp}`
(case-insensitive).

Set an internal flag `HAS_MOCK=true` if any image file is found, `false` otherwise.

**Phase B — if `HAS_MOCK=false`, fetch from Jira:**

If no local images were found:

1. Use `mcp__mcp-atlassian__jira_get_issue` with `fields="attachment"` to fetch
   the issue's attachment list.
2. For every attachment whose filename ends in `.png`, `.jpg`, `.jpeg`, `.gif`,
   `.svg`, or `.webp` (case-insensitive), collect its `url` and `filename`.
3. Read the Jira credentials from `.claude/settings.local.json`:
   - `JIRA_USERNAME` and `JIRA_API_TOKEN`
4. For each image attachment, run a **PowerShell** command to download it directly
   to `agent-output/jira-cache/$ARGUMENTS/attachments/<filename>`:

```powershell
$username = "<JIRA_USERNAME>"
$token    = "<JIRA_API_TOKEN>"
$bytes    = [System.Text.Encoding]::ASCII.GetBytes("${username}:${token}")
$base64   = [Convert]::ToBase64String($bytes)
$headers  = @{ Authorization = "Basic $base64" }
$outDir   = "agent-output/jira-cache/$ARGUMENTS/attachments"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Invoke-WebRequest -Uri "<attachment_url>" -Headers $headers -OutFile "$outDir/<filename>"
```

   > **Why PowerShell, not MCP download:** `mcp__mcp-atlassian__jira_download_attachments`
   > returns image files as inline base64 content shown in the conversation window —
   > it does NOT write PNG/JPG files to disk. PowerShell `Invoke-WebRequest` with
   > Basic auth is the only reliable way to persist images to the local cache.

5. After all downloads complete, re-run the `Glob` scan above.
6. If images are now present, set `HAS_MOCK=true`.

If the issue has no image attachments (or the Jira fetch returns none), leave
`HAS_MOCK=false` and continue.

**Phase C — inject override if mocks are present:**

If `HAS_MOCK=true`, prepend the following to the design agent prompt (Step 1):
> ⚡ **MOCK PRIORITY OVERRIDE**: UI mockup images were detected in the Jira
> attachments. You MUST read every image file using the `Read` tool before
> producing requirements. The mockup is the **highest-priority design input**
> and must be followed exactly. All LWC/UI specifications must reflect what
> the mockup shows — no assumptions, no deviations.

---

## STEP 1 — 🟠 Design Agent (ALWAYS FIRST)

Invoke **salesforce-design** subagent with:

- The Jira story key: `$ARGUMENTS`
- The mock priority override (if `HAS_MOCK=true`, include the override block above)
- Instruction to check the `tdd/` folder for a TDD document
- Instruction to download ALL Jira attachments to local cache
- Instruction to read every image attachment with the `Read` tool (regardless of TDD presence)
- Instruction to write `agent-output/design-requirements.md`

### 🚦 DESIGN GATE

Display the contents of `agent-output/design-requirements.md` to the user.

Ask:
> **Does the design plan look correct? (yes / no / request changes)**
>
> _Type "yes" to proceed, "no" to cancel, or describe changes you want._

- If "yes" → continue to Step 2
- If "no" → stop and inform user
- If changes requested → pass feedback to salesforce-design agent and repeat Step 1

---

## STEP 2 — 🔵 Admin + 🟢 Developer (based on design plan)

Read `agent-output/design-requirements.md` to determine what work is needed:

| Design plan says | Action |
|-----------------|--------|
| Admin work only | Invoke **salesforce-admin** only |
| Dev work only   | Invoke **salesforce-developer** only |
| Both            | Invoke **salesforce-admin** FIRST, then **salesforce-developer** |
| Neither         | Inform user: "No implementation work identified in the design plan" |

### Mock injection for developer agent

If the design requirements reference any image/mockup files (look for local
file paths in the `agent-output/jira-cache/` directory), inject this into
the developer agent prompt:

> ⚡ **MOCK PRIORITY**: Local mockup files are available at
> `agent-output/jira-cache/$ARGUMENTS/attachments/`. You MUST read every
> image file with the `Read` tool before writing any LWC code. Your
> implementation MUST match the mockup pixel-for-pixel in layout, structure,
> and component hierarchy. SLDS components must be used wherever applicable.

---

## STEP 3 — 🚦 Unit Test Gate

After the developer agent completes (if Apex was written):

Ask:
> **Would you like test classes created? (yes / no)**

- If "yes" → invoke **salesforce-developer** to write test classes (≥80% coverage)
- If "no" → skip

---

## STEP 4 — 🚦 Code Review Gate

Ask:
> **Would you like a code review? (yes / no)**

- If "yes" → invoke **salesforce-code-review** agent
  - It writes `agent-output/code-review-$ARGUMENTS.md`
  - Display the verdict: APPROVED / WARNINGS / CHANGES REQUIRED
- If "no" → skip

---

## STEP 5 — 🚦 Deployment Gate

Ask:
> **Ready to deploy to org? (yes / no)**

- If "yes" → invoke **salesforce-devops** agent to:
  1. Show all components + ask final confirmation
  2. Dry-run validation
  3. Deploy via `mcp__Salesforce__deploy_metadata`
  4. Run Apex tests and report coverage
- If "no" → skip

---

## STEP 6 — 🚦 Git Push Gate (handled by devops agent after deploy)

After deployment:
> **Push changes to a feature branch? (yes / no)**

- If "yes" → devops agent:
  1. Creates `feature/$ARGUMENTS-<short-description>` branch
  2. Stages only story files
  3. Commits with `feat($ARGUMENTS): <description>`
  4. Pushes to origin
  5. Asks: "Create a PR? (yes / no)"
     - If yes → creates PR via `mcp__github__create_pull_request`, records URL
  6. AUTO: posts Jira comment with branch + PR link
- If "no" → skip

---

## FINAL — Execution Summary (MANDATORY — no gate)

After ALL steps complete, write `agent-output/execution-summary-$ARGUMENTS.md`
following the template at `.claude/skills/salesforce/references/execution-summary-template.md`.

Then summarize results to the user in 3–5 bullet points:
- What was built
- Mock priority status (detected / not detected)
- Code review verdict (if run)
- Deployment status
- PR link (if created)
