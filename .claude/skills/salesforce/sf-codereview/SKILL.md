---
name: sf-codereview
description: >
  Salesforce code review skill — workflow, checklists, severity classification,
  and output format for reviewing Apex, Triggers, Test Classes, and LWC.
  TRIGGER when: salesforce-code-review agent needs to review code produced by
  salesforce-developer. DO NOT TRIGGER for writing or deploying code.
---

# sf-codereview: Salesforce Code Review

Use this skill when the agent needs to **review** Apex classes, triggers, test
classes, and LWC components before deployment.

---

## Workflow

### Step 1 — Identify Code to Review

Read the design requirements and locate all created files:

```bash
cat agent-output/design-requirements.md
ls -la force-app/main/default/classes/*.cls
ls -la force-app/main/default/triggers/*.trigger
ls -la force-app/main/default/lwc/
```

### Step 2 — Review Each File

Apply the checklists below to every file. Classify each finding by severity.

### Step 3 — Produce Report

Write `agent-output/code-review-<JIRA-KEY>.md` (see Output Format below).
Also print the console summary.

### Step 4 — Deliver Verdict

| Verdict | Condition | Next Step |
|---|---|---|
| ✅ **APPROVED** | Zero critical, zero warnings | Hand off to salesforce-devops |
| ⚠️ **APPROVED WITH WARNINGS** | Zero critical, warnings present | Ask user: deploy now or fix first? |
| ❌ **CHANGES REQUIRED** | One or more critical issues | Return to salesforce-developer |

---

## Severity Classification

| Severity | Definition | Block Deploy? |
|---|---|---|
| 🔴 **Critical** | Security risk, governor limit violation, data loss risk | Yes — mandatory fix |
| 🟡 **Warning** | Best practice deviation, potential issue under load | Recommended fix |
| 🟢 **Suggestion** | Code quality / readability improvement | Optional |
| ✅ **Passed** | No issues found | — |

---

## Review Checklists

### Apex Code

#### 🔴 Critical (Must Fix)

| Check | What to Look For |
|---|---|
| SOQL in Loops | Any SOQL query inside a for/while loop |
| DML in Loops | Any insert/update/delete inside a loop |
| Hardcoded IDs | 15 or 18 character Salesforce IDs |
| No Bulkification | Processing `Trigger.new[0]` instead of full list |
| Missing Null Checks | Accessing object properties without null guard |
| No Error Handling | Missing try-catch for DML/callouts |
| Security Violations | Missing `with sharing` or `WITH USER_MODE` |
| Recursive Triggers | No recursion prevention mechanism |

#### 🟡 Warning (Should Fix)

| Check | What to Look For |
|---|---|
| System.debug() | Debug statements in production code |
| Magic Numbers | Hardcoded numbers without constants |
| Large Methods | Methods > 50 lines |
| Missing ApexDocs | No ApexDocs on public methods |
| Poor Naming | Unclear variable/method names |
| No Test Coverage | Classes without a corresponding test class |

#### 🟢 Suggestion (Nice to Have)

| Check | What to Look For |
|---|---|
| Code Duplication | Similar logic repeated across methods |
| Complex Conditions | Nested if statements > 3 levels deep |
| Missing Constants | Repeated string literals |
| Pattern Opportunities | Where design patterns could improve the code |

---

### Trigger

| Check | Pass Criteria |
|---|---|
| One Trigger Per Object | Only one trigger file per SObject |
| Handler Pattern | Trigger delegates to a handler class |
| No Logic in Trigger | All logic in handler/service classes |
| All Events Handled | Covers required insert/update/delete events |
| Recursion Prevention | Static flag to prevent re-entry |
| Bulkified | Processes all records in `Trigger.new` |

---

### Test Class

| Check | Pass Criteria |
|---|---|
| No @SeeAllData | `@SeeAllData=true` not used |
| @TestSetup Used | Test data created in setup method |
| Positive Tests | Happy path scenarios covered |
| Negative Tests | Error scenarios covered |
| Bulk Tests | 200+ record scenarios for triggers |
| Assertions Present | Meaningful `Assert` statements with messages |
| Test Isolation | Tests don't depend on each other |

---

### LWC

| Check | Pass Criteria |
|---|---|
| Error Handling | try-catch around imperative Apex calls |
| Loading States | Spinner/loading indicator during async ops |
| Wire Error Handling | Error property handled in wire adapters |
| SLDS Used | Lightning Design System classes used |
| Accessibility | ARIA labels, semantic HTML present |
| No console.log | No debug statements in JS |
| LDS-First | GraphQL/LDS adapters used before Apex |

---

### Security

| Check | Pass Criteria |
|---|---|
| Sharing Declared | `with sharing` on all classes |
| CRUD/FLS Checked | Field accessibility verified before access |
| USER_MODE Used | SOQL uses `WITH USER_MODE` |
| No SOQL Injection | Dynamic SOQL uses bind variables |
| Input Validation | User inputs sanitized |

---

## Output Format

### Report File — `agent-output/code-review-<JIRA-KEY>.md`

- Overwrite if the same key already exists (latest review always wins)
- Create `agent-output/` if it doesn't exist
- If no Jira key: use `agent-output/code-review-<YYYYMMDD-HHMMSS>.md`

```markdown
# 🔍 Code Review Report — [JIRA-KEY or Direct Request]

**Review Date:** YYYY-MM-DD HH:MM
**Jira Story:** [JIRA-KEY or "No Jira Key — Direct Request"]
**Files Reviewed:** X
**Verdict:** ✅ APPROVED / ⚠️ APPROVED WITH WARNINGS / ❌ CHANGES REQUIRED

---

## 📊 Summary

| Severity | Count |
|---|---|
| 🔴 Critical   | X |
| 🟡 Warning    | X |
| 🟢 Suggestion | X |
| ✅ Passed     | X |

---

## 🔴 Critical Issues (Must Fix Before Deploy)

### Issue 1: [Short Title]
- **File:** `force-app/main/default/classes/FileName.cls`
- **Line:** ~XX
- **Problem:** [Clear description]
- **Fix:** [Exact fix or corrected code snippet]

[Or: "✅ No critical issues found"]

---

## 🟡 Warnings (Should Fix)

### Warning 1: [Short Title]
- **File:** `[filename]`
- **Problem:** [Description]
- **Recommendation:** [How to improve]

[Or: "✅ No warnings found"]

---

## 🟢 Suggestions (Nice to Have)

- [Suggestion 1]

[Or: "No suggestions"]

---

## ✅ Good Practices Found

- ✅ [Positive finding 1]

---

## 📋 File-by-File Summary

| File | Status | Critical | Warnings | Suggestions |
|---|---|---|---|---|
| `[filename.cls]` | ✅ / 🟡 / 🔴 | X | X | X |

---

## 🏁 Verdict & Next Steps

**Verdict:** APPROVED / APPROVED WITH WARNINGS / CHANGES REQUIRED

**User Action Required:**
- [Next step — or "No action required — proceed to deployment"]
```

---

### Console Summary Format

```
═══════════════════════════════════════════════════════════════════════════════
 🔍 CODE REVIEW REPORT
═══════════════════════════════════════════════════════════════════════════════
📅 REVIEW DATE: [DateTime]
🔎 FILES REVIEWED: X
📄 REPORT SAVED: agent-output/code-review-<JIRA-KEY>.md
───────────────────────────────────────────────────────────────────────────────
 📊 SUMMARY
───────────────────────────────────────────────────────────────────────────────
 Severity       | Count
 ───────────────|───────
 🔴 CRITICAL    |  X
 🟡 WARNING     |  X
 🟢 SUGGESTION  |  X
 ✅ PASSED      |  X
───────────────────────────────────────────────────────────────────────────────
 🔴 CRITICAL ISSUES (Must Fix)
───────────────────────────────────────────────────────────────────────────────
[issues or "✅ No critical issues found"]
───────────────────────────────────────────────────────────────────────────────
 🟡 WARNINGS (Should Fix)
───────────────────────────────────────────────────────────────────────────────
[warnings or "✅ No warnings found"]
───────────────────────────────────────────────────────────────────────────────
 🟢 SUGGESTIONS (Nice to Have)
───────────────────────────────────────────────────────────────────────────────
[suggestions or "No suggestions"]
───────────────────────────────────────────────────────────────────────────────
 📋 FILE-BY-FILE REVIEW
───────────────────────────────────────────────────────────────────────────────
 File                         | Status | Critical | Warnings | Suggestions
 ─────────────────────────────|────────|──────────|──────────|────────────
 FileName.cls                 |  🟡   |    1     |    2     |     1
───────────────────────────────────────────────────────────────────────────────
 🏁 VERDICT
───────────────────────────────────────────────────────────────────────────────
✅  APPROVED           — Ready for deployment.
⚠️  APPROVED WITH WARNINGS — Can deploy; fix warnings later.
❌  CHANGES REQUIRED   — Fix critical issues before deployment.
───────────────────────────────────────────────────────────────────────────────
 👤 USER ACTION REQUIRED
───────────────────────────────────────────────────────────────────────────────
[APPROVED]  Invoke salesforce-devops agent.
[WARNINGS]  Deploy now [D] or fix warnings first [F]?
[CHANGES]   Send back to salesforce-developer [F] or skip [S]?
═══════════════════════════════════════════════════════════════════════════════
```

---

## Project Standards Reference

Review against conventions in the project's `CLAUDE.md` and `sfdx-project.json`:
- **API Version**: as specified in `sfdx-project.json`
- **Field Prefixes**: as defined in project conventions
- **Trigger Pattern**: one trigger per object, logic in handler class
- **Sharing**: `with sharing` on all service classes
- **SOQL Security**: `WITH USER_MODE`
