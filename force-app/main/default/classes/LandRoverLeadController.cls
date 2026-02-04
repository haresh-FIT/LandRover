public class LandRoverLeadController {
    
    public Lead lead { get; set; }
    public Boolean showSuccess { get; set; }
    
    public LandRoverLeadController() {
        lead = new Lead();
        lead.Company = 'Individual';
        showSuccess = false;
    }
    
    public PageReference saveLead() {
        try {
            // Validate required fields
            if (String.isBlank(lead.LastName) || String.isBlank(lead.Phone)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Please fill in all required fields marked with *'
                ));
                return null;
            }
            
            // Validate email if provided
            if (String.isNotBlank(lead.Email) && !isValidEmail(lead.Email)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Please enter a valid email address'
                ));
                return null;
            }
            
            // Set additional fields
            lead.LeadSource = 'Web';
            lead.Status = 'New';
            
            // Insert lead
            insert lead;
            
            // Show success message via JavaScript
            showSuccess = true;
            
            // Clear any existing messages
            ApexPages.getMessages().clear();
            
        } catch (DmlException e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'An error occurred while saving your information. Please try again.'
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'An unexpected error occurred. Please try again.'
            ));
        }
        
        return null;
    }
    
    private Boolean isValidEmail(String email) {
        String emailRegex = '^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$';
        Pattern emailPattern = Pattern.compile(emailRegex);
        Matcher emailMatcher = emailPattern.matcher(email);
        return emailMatcher.matches();
    }
}