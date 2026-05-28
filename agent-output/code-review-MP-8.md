# Code Review — MP-8: Support Cases — Product Information Section

| Field | Value |
|---|---|
| Jira Key | MP-8 |
| Reviewer | salesforce-code-review |
| Date | 2026-05-28 |
| **Verdict** | **APPROVED WITH WARNINGS** |

No critical security or governor-limit violations found. All code is deployable. Three Warning-level and several Minor issues should be reviewed before deployment — particularly Finding 4.3 (missing `RecordTypeId` in save payload) which is a functional correctness issue.

---

## File 1: `CaseCreateController.cls`

**Overall: Well-structured. `with sharing`, `USER_MODE`, and bind variables used correctly throughout.**

| # | Severity | Finding |
|---|---|---|
| 1.1 | Minor | Line 116: Raw DML error message exposed in `AuraHandledException` — reveals internal field/rule names. Fix: log internally, surface generic UI message. |
| 1.2 | Minor | Lines 119–125: Extra SOQL re-query for `Status` after insert — `Status` already known from `caseRecord.Status`. Only `CaseNumber` needs re-querying. |
| 1.3 | Info | `cacheable=true` on `findAssetBySerial` and `getPartDescription` — correct, no action needed. |
| 1.4 | Info | `with sharing` enforcement — correct. |

---

## File 2: `CaseCreateControllerTest.cls`

**Overall: Excellent. 12 test methods, proper `@TestSetup`, all assertions include descriptive messages.**

| # | Severity | Finding |
|---|---|---|
| 2.1 | Info | `@isTest(testFor=CaseCreateController.class)` — used correctly (API 65.0+). |
| 2.2 | Minor | Lines 347–355: Vacuous assertion due to `\|\|` short-circuit (`e.getMessage().contains(...) \|\| e.getMessage() != null` is always true). Fix: use `Assert.isNotNull(e.getMessage(), ...)` only. |
| 2.3 | Info | Line 258: `getRecordTypeInfosByDeveloperName().get('Parts_Technical')` may NPE if RecordType absent. Consider a null guard for better test failure messages. |
| 2.4 | Info | `SeeAllData=false` is default — omission is not a defect, but explicit annotation documents intent. |

---

## File 3: `caseCreate.html`

**Overall: Clean, no `innerHTML`, no `eval`. Accessibility partially addressed.**

| # | Severity | Finding |
|---|---|---|
| 3.1 | Warning | Lines 38–40, 309–325: Stub buttons (Add Favorite, Copy, Print to PDF, Submit, Resolve, Cancel) have no `onclick` handlers — UX gap. Add `disabled` attribute or placeholder comment marking them as future-story scope. |
| 3.2 | Warning | Lines 59, 134: `aria-expanded="true"` hardcoded on non-functional collapsible section buttons — accessibility defect. Fix: wire up toggle or remove `aria-expanded` and change `<button>` to non-interactive `<span>`. |
| 3.3 | Minor | Line 254: Custom `<label for="partNumberPicker">` does not resolve to the `lightning-record-picker`'s internal input — screen readers cannot associate. Fix: remove outer `<label>`, use `variant="label-stacked"` on `lightning-record-picker`. |
| 3.4 | Info | `if:true` / `if:false` directives are functional but older syntax. `lwc:if` / `lwc:else` (API 59.0+) is preferred for new components. |

---

## File 4: `caseCreate.js`

**Overall: Clean, reactive, properly structured. No `@track` overuse, no event listener leaks, error handling present in all `.catch` blocks.**

| # | Severity | Finding |
|---|---|---|
| 4.1 | Warning | Line 84: Deprecated `event.keyCode` fallback included alongside `event.key`. Fix: use `event.key` exclusively (`if (event.key === 'Enter' \|\| event.key === 'Tab')`). |
| 4.2 | Minor | Line 14: `@track` imported but never applied — dead import. Fix: remove `track` from the import. |
| 4.3 | Minor | Lines 143–155: `RecordTypeId` not included in `caseRecord` payload — Case may be saved under the wrong record type. Fix: resolve `Parts_Technical` RecordTypeId via `getObjectInfo` wire adapter at component load, include in `caseRecord`. |
| 4.4 | Minor | Lines 179–204: No loading guard during async asset fetch — race condition possible if Save is clicked before `_fetchAsset` resolves. Fix: add `isLoadingAsset = true/false` flag; disable Save while fetch is in flight. |

---

## File 5: `caseCreate.css`

**Overall: Clean, no critical issues.**

| # | Severity | Finding |
|---|---|---|
| 5.1 | Info | Line 199: `.slds-form-element__label` override is scoped to shadow DOM — no leak risk, but overrides SLDS tokens for all native `<label>` elements in the component. |
| 5.2 | Info | Line 80: Hidden `lightning-button-icon` (`display: none`) still in DOM — may be announced by screen readers. Fix: remove from template if not shown. |

---

## File 6: `caseCreate.js-meta.xml`

| # | Severity | Finding |
|---|---|---|
| 6.1 | Warning | `lightning__RecordPage` target allows placement on any object's record page by admins. Fix: restrict to `lightning__AppPage` only unless record-page placement is a confirmed requirement. |

---

## Summary Table

| # | File | Severity | Finding |
|---|---|---|---|
| 1.1 | `CaseCreateController.cls` | Minor | Raw DML error exposed in AuraHandledException |
| 1.2 | `CaseCreateController.cls` | Minor | Redundant SOQL re-query for Status after insert |
| 2.2 | `CaseCreateControllerTest.cls` | Minor | Vacuous assertion due to `\|\|` short-circuit |
| 3.1 | `caseCreate.html` | **Warning** | Stub buttons with no handlers — UX gap |
| 3.2 | `caseCreate.html` | **Warning** | `aria-expanded` on non-functional buttons — accessibility defect |
| 3.3 | `caseCreate.html` | Minor | Custom `<label for>` won't bind to record-picker input — accessibility gap |
| 4.1 | `caseCreate.js` | **Warning** | Deprecated `event.keyCode` fallback |
| 4.2 | `caseCreate.js` | Minor | `@track` imported but unused |
| 4.3 | `caseCreate.js` | Minor | `RecordTypeId` missing from save payload — functional correctness issue |
| 4.4 | `caseCreate.js` | Minor | No loading guard during async asset fetch — race condition risk |
| 6.1 | `caseCreate.js-meta.xml` | **Warning** | `lightning__RecordPage` target too broad |

---

## Recommended Fixes Before Deploy

1. **Finding 4.3** — Add `RecordTypeId` to the Case payload in `handleSave`. This is a functional defect.
2. **Finding 3.2** — Remove `aria-expanded` from non-functional buttons or wire the collapse toggle.
3. **Finding 3.3** — Switch `lightning-record-picker` to `variant="label-stacked"`, remove manual `<label>`.
4. **Finding 6.1** — Restrict `js-meta.xml` targets to `lightning__AppPage` only.

## Can Be Addressed in Follow-up

5. Finding 4.2 — Remove unused `track` import.
6. Finding 4.1 — Replace `event.keyCode` with `event.key`.
7. Finding 2.2 — Simplify vacuous test assertion.
8. Finding 1.1 — Surface generic DML error message to UI.
9. Finding 4.4 — Add `isLoadingAsset` guard to prevent save race condition.

---

**Final Verdict: APPROVED WITH WARNINGS**
