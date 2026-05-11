/**
 * @description Invocable Apex class for deep cloning Form__c records and their related Question__c records.
 *              This is called from the Form_Version_Manager Screen Flow to create new versions.
 * @author MP-6 Implementation
 * @date 2026-04-20
 */
public with sharing class FormVersionCloneAction {

    /**
     * Input wrapper for the invocable method
     */
    public class Input {
        @InvocableVariable(required=true description='Id of the Form to clone from')
        public Id sourceFormId;
    }

    /**
     * Output wrapper for the invocable method
     */
    public class Output {
        @InvocableVariable(description='Id of the newly created Form version')
        public Id newFormId;
    }

    /**
     * @description Invocable method to clone Form versions. Processes multiple inputs in a single transaction.
     * @param inputs List of Input objects containing source Form Ids
     * @return List of Output objects containing new Form Ids
     */
    @InvocableMethod(label='Clone Form Version'
                     description='Deep clones a Form and its Questions, increments version, links to root')
    public static List<Output> cloneFormVersion(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            results.add(cloneSingle(inp.sourceFormId));
        }
        return results;
    }

    /**
     * @description Performs the actual cloning logic for a single Form record.
     * @param sourceFormId The Id of the Form to clone from
     * @return Output object containing the new Form Id
     */
    private static Output cloneSingle(Id sourceFormId) {
        Output result = new Output();

        // 1. Query source form
        Form__c source = [
            SELECT Id, Form_Title__c, Start_Date__c, End_Date__c,
                   Status__c, Objects__c, Version__c, Parent_Form__c
            FROM Form__c
            WHERE Id = :sourceFormId
            LIMIT 1
        ];

        // 2. Determine root form Id (Version 1)
        // If Parent_Form__c is not null, the parent is the root
        // If Parent_Form__c is null, this form itself is the root
        Id rootFormId = (source.Parent_Form__c != null)
                        ? source.Parent_Form__c
                        : source.Id;

        // 3. Count existing versions in the family
        // This includes the root form and all its children
        Integer versionCount = [
            SELECT COUNT()
            FROM Form__c
            WHERE Id = :rootFormId OR Parent_Form__c = :rootFormId
        ];

        // 4. Clone Form__c
        // clone(preserveId, deepClone) - false = new Id, true = copy all fields
        Form__c newForm = source.clone(false, true);
        newForm.Version__c = versionCount + 1;
        newForm.Parent_Form__c = rootFormId;
        newForm.Status__c = 'Draft';
        insert newForm;

        // 5. Clone related Question__c records
        List<Question__c> sourceQuestions = [
            SELECT Title__c, Comment__c, Option__c
            FROM Question__c
            WHERE Form__c = :sourceFormId
        ];

        List<Question__c> clonedQuestions = new List<Question__c>();
        for (Question__c q : sourceQuestions) {
            Question__c cloned = q.clone(false, true);
            cloned.Form__c = newForm.Id;
            clonedQuestions.add(cloned);
        }
        
        if (!clonedQuestions.isEmpty()) {
            insert clonedQuestions;
        }

        result.newFormId = newForm.Id;
        return result;
    }
}