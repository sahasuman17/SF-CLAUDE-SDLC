# Design Requirements — MP-8: Support Cases — Product Information Section

| Field        | Value                                                  |
|--------------|--------------------------------------------------------|
| Jira Key     | MP-8                                                   |
| Title        | Support Cases: Product Information Section             |
| Status       | To Do                                                  |
| Case Type    | Parts Technical Help                                   |
| Design Owner | salesforce-design                                      |
| Source Docs  | `TDD/MP-8-Product-Information-Section.md` (authoritative), `agent-output/jira-cache/MP-8/issue.json`, `agent-output/jira-cache/MP-8/attachments/MP-8 Mockup.png` |

> A TDD document exists for this story and is the **authoritative design solution**. The Jira description and mockup are aligned with the TDD. This plan is derived from the TDD.

---

## 1. Story Summary

When a user creates a **Parts Technical Help** support case, the Product Information section must auto-populate equipment and product fields from the related Asset record once a valid Serial Number is provided. The user can optionally select a Part Number (lookup to `Part__c`), which auto-populates the Part Description. On Save, only Product Information fields are persisted to the Case with Status = `Draft`, and the returned Case Number is displayed in the header under the record type label.

---

## 3. Admin Tasks

**None required.** All declarative artifacts already exist in the codebase.

---

## 4. Developer Tasks

### 4.1 Apex — `CaseCreateController.cls` (CREATE)

Thin service-layer controller exposing three `@AuraEnabled` methods: `findAssetBySerial`, `getPartDescription`, `saveCaseAsDraft`.

### 4.2 LWC — `caseCreate` (CREATE)

Four files: `caseCreate.js`, `caseCreate.html`, `caseCreate.css`, `caseCreate.js-meta.xml`.

---

## 5. Component Breakdown

| Layer | Name                       | Type   | Action  | Path |
|-------|----------------------------|--------|---------|------|
| Apex  | `CaseCreateController`     | Class  | Create  | `force-app/main/default/classes/CaseCreateController.cls` (+ `.cls-meta.xml`) |
| LWC   | `caseCreate`               | Bundle | Create  | `force-app/main/default/lwc/caseCreate/` (`.js`, `.html`, `.css`, `.js-meta.xml`) |

---

**Plan complete.**
