/**
 * @description Controller for Test Drive Booking Visualforce Page
 * @author Land Rover Team
 * @date 2026
 */
public with sharing class TestDriveBookingController {
    
    /**
     * @description Search for Leads based on search term
     * @param searchTerm The search string entered by user
     * @return List of matching leads
     */
    @RemoteAction
    public static List<LeadSearchResult> searchLeads(String searchTerm) {
        List<LeadSearchResult> results = new List<LeadSearchResult>();
        
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return results;
        }
        
        String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        
        try {
            List<Lead> leads = [
                SELECT Id, Name, Email, Phone, Company, Status, LeadSource, 
                       MobilePhone, Title, City, State, Country
                FROM Lead 
                WHERE (Name LIKE :searchPattern 
                       OR Email LIKE :searchPattern 
                       OR Phone LIKE :searchPattern 
                       OR MobilePhone LIKE :searchPattern
                       OR Company LIKE :searchPattern)
                AND IsConverted = false
                ORDER BY LastModifiedDate DESC
                LIMIT 20
            ];
            
            for (Lead l : leads) {
                LeadSearchResult result = new LeadSearchResult();
                result.leadId = l.Id;
                result.name = l.Name;
                result.email = l.Email != null ? l.Email : '';
                result.phone = l.Phone != null ? l.Phone : (l.MobilePhone != null ? l.MobilePhone : '');
                result.company = l.Company != null ? l.Company : '';
                result.status = l.Status != null ? l.Status : '';
                result.title = l.Title != null ? l.Title : '';
                result.location = buildLocation(l.City, l.State, l.Country);
                results.add(result);
            }
        } catch (Exception e) {
            System.debug('Error searching leads: ' + e.getMessage());
        }
        
        return results;
    }
    
    /**
     * @description Get available vehicles based on search criteria
     * @param model Vehicle model
     * @param variant Vehicle variant
     * @param branch Preferred branch
     * @param testDate Appointment date
     * @return List of available vehicles with slots
     */
    @RemoteAction
    public static List<VehicleAvailability> getVehicleAvailability(
        String model, String variant, String branch, String testDate
    ) {
        List<VehicleAvailability> availabilityList = new List<VehicleAvailability>();
        
        try {
            String query = 'SELECT Id, Name, Model__c, Variant__c, Branch__c, ' +
                           'Color__c, Registration_Number__c, Year__c, Fuel_Type__c, ' +
                           'Transmission__c, Engine__c, Seating_Capacity__c, ' +
                           'Mileage__c, VIN__c, Status__c ' +
                           'FROM Vehicle__c ' +
                           'WHERE Status__c = \'Available\' ';
            
            if (String.isNotBlank(model)) {
                query += 'AND Model__c = :model ';
            }
            
            if (String.isNotBlank(variant)) {
                query += 'AND Variant__c = :variant ';
            }
            
            if (String.isNotBlank(branch)) {
                query += 'AND Branch__c = :branch ';
            }
            
            query += 'ORDER BY Model__c, Variant__c LIMIT 50';
            
            List<Vehicle__c> vehicles = Database.query(query);
            
            for (Vehicle__c vehicle : vehicles) {
                VehicleAvailability va = new VehicleAvailability();
                va.vehicleId = vehicle.Id;
                va.vehicleName = vehicle.Name != null ? vehicle.Name : '';
                va.model = vehicle.Model__c != null ? vehicle.Model__c : '';
                va.variant = vehicle.Variant__c != null ? vehicle.Variant__c : '';
                va.branch = vehicle.Branch__c != null ? vehicle.Branch__c : '';
                va.color = vehicle.Color__c != null ? vehicle.Color__c : '';
                va.registrationNo = vehicle.Registration_Number__c != null ? vehicle.Registration_Number__c : '';
                va.year = vehicle.Year__c != null ? String.valueOf(vehicle.Year__c) : '';
                va.fuelType = vehicle.Fuel_Type__c != null ? vehicle.Fuel_Type__c : '';
                va.transmission = vehicle.Transmission__c != null ? vehicle.Transmission__c : '';
                va.engine = vehicle.Engine__c != null ? vehicle.Engine__c : '';
                va.seating = vehicle.Seating_Capacity__c != null ? String.valueOf(vehicle.Seating_Capacity__c) : '';
                va.mileage = vehicle.Mileage__c != null ? String.valueOf(vehicle.Mileage__c) : '';
                va.vin = vehicle.VIN__c != null ? vehicle.VIN__c : '';
                
                va.slots = getAvailableSlots(vehicle.Id, testDate);
                
                availabilityList.add(va);
            }
        } catch (Exception e) {
            System.debug('Error getting vehicle availability: ' + e.getMessage());
        }
        
        return availabilityList;
    }
    
    /**
     * @description Get available time slots for a vehicle on a specific date
     * @param vehicleId The vehicle Id
     * @param testDate The appointment date
     * @return List of time slots with availability status
     */
    private static List<TimeSlot> getAvailableSlots(Id vehicleId, String testDate) {
        List<TimeSlot> slots = new List<TimeSlot>();
        
        List<String> slotTimes = new List<String>{
            '09:00 AM - 10:30 AM',
            '11:00 AM - 12:30 PM',
            '01:00 PM - 02:30 PM',
            '03:00 PM - 04:30 PM',
            '05:00 PM - 06:30 PM'
        };
        
        try {
            Date appointmentDate = Date.valueOf(testDate);
            
            List<Test_Drive_Appointment__c> existingAppointments = [
                SELECT Id, Time_Slot__c
                FROM Test_Drive_Appointment__c
                WHERE Vehicle__c = :vehicleId
                AND Appointment_Date__c = :appointmentDate
                AND Status__c != 'Cancelled'
            ];
            
            Set<String> bookedSlots = new Set<String>();
            for (Test_Drive_Appointment__c appointment : existingAppointments) {
                if (appointment.Time_Slot__c != null) {
                    bookedSlots.add(appointment.Time_Slot__c);
                }
            }
            
            for (String slotTime : slotTimes) {
                TimeSlot slot = new TimeSlot();
                slot.timeVal = slotTime;
                slot.available = !bookedSlots.contains(slotTime);
                slots.add(slot);
            }
        } catch (Exception e) {
            System.debug('Error getting available slots: ' + e.getMessage());
        }
        
        return slots;
    }
    
    /**
     * @description Create a test drive appointment
     * @param leadId The lead Id
     * @param vehicleId The vehicle Id
     * @param appointmentDate The appointment date
     * @param timeSlot The selected time slot
     * @return Appointment creation result
     */
    @RemoteAction
    public static AppointmentResult createAppointment(
        Id leadId, Id vehicleId, String appointmentDate, String timeSlot
    ) {
        AppointmentResult result = new AppointmentResult();
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Validate inputs
            if (leadId == null || vehicleId == null || 
                String.isBlank(appointmentDate) || String.isBlank(timeSlot)) {
                result.success = false;
                result.message = 'Missing required information.';
                return result;
            }
            
            // Get lead details
            Lead lead = [
                SELECT Id, Name, Email, Phone, Status 
                FROM Lead 
                WHERE Id = :leadId 
                LIMIT 1
            ];
            
            // Get vehicle details
            Vehicle__c vehicle = [
                SELECT Id, Name, Model__c, Variant__c, Branch__c, Status__c 
                FROM Vehicle__c 
                WHERE Id = :vehicleId 
                LIMIT 1
            ];
            
            // Check if vehicle is available
            if (vehicle.Status__c != 'Available') {
                result.success = false;
                result.message = 'Vehicle is not available for test drive.';
                return result;
            }
            
            // Check if slot is still available
            Date apptDate = Date.valueOf(appointmentDate);
            List<Test_Drive_Appointment__c> existingAppt = [
                SELECT Id 
                FROM Test_Drive_Appointment__c
                WHERE Vehicle__c = :vehicleId
                AND Appointment_Date__c = :apptDate
                AND Time_Slot__c = :timeSlot
                AND Status__c != 'Cancelled'
                LIMIT 1
            ];
            
            if (!existingAppt.isEmpty()) {
                result.success = false;
                result.message = 'This slot has already been booked. Please select another slot.';
                return result;
            }
            
            // Create appointment
            Test_Drive_Appointment__c appointment = new Test_Drive_Appointment__c();
            appointment.Lead__c = leadId;
            appointment.Vehicle__c = vehicleId;
            appointment.Appointment_Date__c = apptDate;
            appointment.Time_Slot__c = timeSlot;
            appointment.Status__c = 'Scheduled';
            appointment.Booked_By__c = UserInfo.getUserId();
            appointment.Booked_Date__c = System.today();
            
            insert appointment;
            
            // Update Lead Status
            lead.Status = 'Test Drive Scheduled';
            update lead;
            
            result.success = true;
            result.message = 'Appointment successfully created!';
            result.appointmentId = appointment.Id;
            result.leadName = lead.Name;
            result.vehicleName = vehicle.Name + ' - ' + vehicle.Model__c + ' ' + vehicle.Variant__c;
            result.branch = vehicle.Branch__c;
            result.appointmentDate = appointmentDate;
            result.timeSlot = timeSlot;
            
        } catch (DmlException e) {
            Database.rollback(sp);
            result.success = false;
            result.message = 'Error creating appointment: ' + e.getDmlMessage(0);
            System.debug('DML Error: ' + e.getMessage());
        } catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.message = 'Error creating appointment: ' + e.getMessage();
            System.debug('Error: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Build location string from city, state, country
     */
    private static String buildLocation(String city, String state, String country) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(city)) parts.add(city);
        if (String.isNotBlank(state)) parts.add(state);
        if (String.isNotBlank(country)) parts.add(country);
        return String.join(parts, ', ');
    }
    
    // ========== WRAPPER CLASSES ==========
    
    public class LeadSearchResult {
        public Id leadId { get; set; }
        public String name { get; set; }
        public String email { get; set; }
        public String phone { get; set; }
        public String company { get; set; }
        public String status { get; set; }
        public String title { get; set; }
        public String location { get; set; }
    }
    
    public class VehicleAvailability {
        public Id vehicleId { get; set; }
        public String vehicleName { get; set; }
        public String model { get; set; }
        public String variant { get; set; }
        public String branch { get; set; }
        public String color { get; set; }
        public String registrationNo { get; set; }
        public String year { get; set; }
        public String fuelType { get; set; }
        public String transmission { get; set; }
        public String engine { get; set; }
        public String seating { get; set; }
        public String mileage { get; set; }
        public String vin { get; set; }
        public List<TimeSlot> slots { get; set; }
    }
    
    public class TimeSlot {
        public String timeVal { get; set; }
        public Boolean available { get; set; }
    }
    
    public class AppointmentResult {
        public Boolean success { get; set; }
        public String message { get; set; }
        public Id appointmentId { get; set; }
        public String leadName { get; set; }
        public String vehicleName { get; set; }
        public String branch { get; set; }
        public String appointmentDate { get; set; }
        public String timeSlot { get; set; }
    }
}