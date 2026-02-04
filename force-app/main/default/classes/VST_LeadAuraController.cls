public with sharing class VST_LeadAuraController {

    @AuraEnabled
    public static void createLead(Lead leadRec) {
        leadRec.LeadSource = 'Website';
        insert leadRec;
    }
}