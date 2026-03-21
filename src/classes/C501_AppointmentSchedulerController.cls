public with sharing class C501_AppointmentSchedulerController {

    public Integer step { get; set; }

    public String lastName { get; set; }
    public Date birthDate { get; set; }

    public Contact searchContact { get; set; }

    public Contact contactRec { get; set; }
    public String email { get; set; }

    public Date day1Date { get; set; }
    public Date day2Date { get; set; }
    public Date day3Date { get; set; }

    public String birthDateText {
        get { return formatDateForInput(birthDate); }
        set { birthDate = parseDateFromInput(value); }
    }

    public String searchBirthDateText {
        get {
            if (searchContact == null) {
                searchContact = new Contact();
            }
            return formatDateForInput(searchContact.Birthdate);
        }
        set {
            if (searchContact == null) {
                searchContact = new Contact();
            }
            searchContact.Birthdate = parseDateFromInput(value);
        }
    }

    public String day1DateText {
        get { return formatDateForInput(day1Date); }
        set { day1Date = parseDateFromInput(value); }
    }

    public String day2DateText {
        get { return formatDateForInput(day2Date); }
        set { day2Date = parseDateFromInput(value); }
    }

    public String day3DateText {
        get { return formatDateForInput(day3Date); }
        set { day3Date = parseDateFromInput(value); }
    }

    public String day1AppointmentId { get; set; }
    public String day2AppointmentId { get; set; }
    public String day3AppointmentId { get; set; }

    public Boolean showDay2 { get; set; }
    public Boolean showDay3 { get; set; }

    public List<SelectOption> day1TimeOptions { get; set; }
    public List<SelectOption> day2TimeOptions { get; set; }
    public List<SelectOption> day3TimeOptions { get; set; }

    public List<String> confirmationLines { get; set; }

    public C501_AppointmentSchedulerController() {
        step = 1;
        showDay2 = false;
        showDay3 = false;

        searchContact = new Contact();

        day1TimeOptions = new List<SelectOption>();
        day2TimeOptions = new List<SelectOption>();
        day3TimeOptions = new List<SelectOption>();
        confirmationLines = new List<String>();

        tryLoadIncomingContact();
    }

    private void tryLoadIncomingContact() {
        String idParam = ApexPages.currentPage() == null ? null : ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(idParam)) {
            return;
        }

        List<Contact> found = [
            SELECT Id, FirstName, LastName, Name, Birthdate, Email, AccountId
            FROM Contact
            WHERE Id = :idParam
            LIMIT 1
        ];

        if (!found.isEmpty()) {
            contactRec = found[0];
            email = contactRec.Email;

            if (searchContact == null) {
                searchContact = new Contact();
            }
            searchContact.LastName = contactRec.LastName;
            searchContact.Birthdate = contactRec.Birthdate;

            step = 3;
        }
    }

    public PageReference startLookup() {
        step = 2;
        return null;
    }

    public Boolean getIsStep1() {
        return step == 1;
    }

    public Boolean getIsStep2() {
        return step == 2;
    }

    public Boolean getIsStep3() {
        return step == 3;
    }

    public Boolean getIsStep4() {
        return step == 4;
    }

    public String getTodayIso() {
        Date d = Date.today();
        return String.valueOf(d.year()) + '-' +
            twoDigit(d.month()) + '-' +
            twoDigit(d.day());
    }

    public PageReference goBack() {
        if (step > 1) {
            step--;
        }
        return null;
    }

    public String searchLastNameText {
        get {
            if (searchContact == null) {
                searchContact = new Contact();
            }
            return searchContact.LastName;
        }
        set {
            if (searchContact == null) {
                searchContact = new Contact();
            }
            searchContact.LastName = value;
        }
    }
        
    public PageReference findContact() {
        if (searchContact == null) {
            searchContact = new Contact();
        }

        if (String.isBlank(searchContact.LastName) || searchContact.Birthdate == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Last Name and Birthdate are required.'
            ));
            return null;
        }

        List<Contact> matches = [
            SELECT Id, FirstName, LastName, Name, Birthdate, Email, AccountId
            FROM Contact
            WHERE LastName = :searchContact.LastName
              AND Birthdate = :searchContact.Birthdate
            LIMIT 2
        ];

        if (matches.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'No matching contact found.'
            ));
            return null;
        }

        if (matches.size() > 1) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Multiple contacts matched that Last Name and Birthdate.'
            ));
            return null;
        }

        contactRec = matches[0];
        email = contactRec.Email;
        step = 3;

        return null;
    }

    public PageReference loadDay1Times() {
        day1TimeOptions = getTimes(day1Date);
        day1AppointmentId = null;
        return null;
    }

    public PageReference loadDay2Times() {
        day2TimeOptions = getTimes(day2Date);
        day2AppointmentId = null;
        return null;
    }

    public PageReference loadDay3Times() {
        day3TimeOptions = getTimes(day3Date);
        day3AppointmentId = null;
        return null;
    }

    public PageReference toggleDay2() {
        if (showDay2 == null) {
            showDay2 = false;
        }

        if (!showDay2) {
            showDay3 = false;
            day2Date = null;
            day2AppointmentId = null;
            day2TimeOptions = new List<SelectOption>();

            day3Date = null;
            day3AppointmentId = null;
            day3TimeOptions = new List<SelectOption>();
        }

        return null;
    }

    public PageReference toggleDay3() {
        if (showDay3 == null) {
            showDay3 = false;
        }

        if (!showDay3) {
            day3Date = null;
            day3AppointmentId = null;
            day3TimeOptions = new List<SelectOption>();
        }

        return null;
    }

    private List<SelectOption> getTimes(Date selectedDate) {
        List<SelectOption> opts = new List<SelectOption>();

        if (selectedDate == null) {
            return opts;
        }

        for (C501_Appointment__c a : [
            SELECT Id, Name, Date__c, Time__c, Summary__c, Available_Time__c, Appointments_Full__c
            FROM C501_Appointment__c
            WHERE Date__c = :selectedDate
              AND Enable__c = true
              AND Appointments_Full__c = false
            ORDER BY Available_Time__c, Name
        ]) {
            String label = String.isBlank(a.Summary__c)
                ? (String.isBlank(a.Time__c) ? a.Name : a.Time__c)
                : a.Summary__c;
            opts.add(new SelectOption(a.Id, label));
        }

        return opts;
    }

    public PageReference schedule() {
        if (contactRec == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please find the contact first.'
            ));
            step = 2;
            return null;
        }

        if (day1Date == null || String.isBlank(day1AppointmentId)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Day 1 date and time are required.'
            ));
            return null;
        }

        if (showDay2) {
            if (day2Date == null || String.isBlank(day2AppointmentId)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Day 2 date and time are required.'
                ));
                return null;
            }
            if (day2Date == day1Date) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Day 2 must be a different date than Day 1.'
                ));
                return null;
            }
        }

        if (showDay3) {
            if (!showDay2) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Select Day 2 before selecting Day 3.'
                ));
                return null;
            }
            if (day3Date == null || String.isBlank(day3AppointmentId)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Day 3 date and time are required.'
                ));
                return null;
            }
            if (day3Date == day1Date || day3Date == day2Date) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Day 3 must be a different date than Day 1 and Day 2.'
                ));
                return null;
            }
        }

        Set<String> appointmentIds = new Set<String>{ day1AppointmentId };
        if (showDay2) {
            if (appointmentIds.contains(day2AppointmentId)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Day 2 must use a different appointment time.'
                ));
                return null;
            }
            appointmentIds.add(day2AppointmentId);
        }
        if (showDay3) {
            if (appointmentIds.contains(day3AppointmentId)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Day 3 must use a different appointment time.'
                ));
                return null;
            }
            appointmentIds.add(day3AppointmentId);
        }

        Map<Id, C501_Appointment__c> apptById = new Map<Id, C501_Appointment__c>([
            SELECT Id, Name, Date__c, Time__c, Summary__c, Appointments_Full__c
            FROM C501_Appointment__c
            WHERE Id IN :appointmentIds
        ]);

        if (!validateAppointmentChoice(apptById, day1AppointmentId, day1Date, 'Day 1')) {
            return null;
        }
        if (showDay2 && !validateAppointmentChoice(apptById, day2AppointmentId, day2Date, 'Day 2')) {
            return null;
        }
        if (showDay3 && !validateAppointmentChoice(apptById, day3AppointmentId, day3Date, 'Day 3')) {
            return null;
        }

        List<Appointment_Scheduled_Request__c> toInsert = new List<Appointment_Scheduled_Request__c>();
        confirmationLines = new List<String>();

        addRow(toInsert, apptById.get((Id) day1AppointmentId), 'Day 1');
        if (showDay2) {
            addRow(toInsert, apptById.get((Id) day2AppointmentId), 'Day 2');
        }
        if (showDay3) {
            addRow(toInsert, apptById.get((Id) day3AppointmentId), 'Day 3');
        }

        insert toInsert;
        step = 4;
        return null;
    }

    private Boolean validateAppointmentChoice(
        Map<Id, C501_Appointment__c> apptById,
        String apptId,
        Date expectedDate,
        String dayLabel
    ) {
        if (String.isBlank(apptId) || !apptById.containsKey((Id) apptId)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                dayLabel + ' appointment could not be found.'
            ));
            return false;
        }

        C501_Appointment__c appt = apptById.get((Id) apptId);
        if (appt.Date__c != expectedDate) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                dayLabel + ' appointment does not match the selected date.'
            ));
            return false;
        }

        if (appt.Appointments_Full__c == true) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                dayLabel + ' appointment is no longer available.'
            ));
            return false;
        }

        return true;
    }

    private void addRow(List<Appointment_Scheduled_Request__c> rows, C501_Appointment__c appt, String dayLabel) {
    
        rows.add(new Appointment_Scheduled_Request__c(
            Name = contactRec.Name + ' ' + dayLabel,
            Contact_Id__c = contactRec.Id,
            Account_Id__c = contactRec.AccountId,
            Appointment_Id__c = appt.Id,
            Email__c = email
        ));

        String label = String.isBlank(appt.Summary__c)
            ? (String.isBlank(appt.Time__c) ? appt.Name : appt.Time__c)
            : appt.Summary__c;
        confirmationLines.add(dayLabel + ': ' + String.valueOf(appt.Date__c) + ' - ' + label);
    }

    private Date parseDateFromInput(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        String v = value.trim();

        if (v.contains('-')) {
            return Date.valueOf(v);
        }

        if (v.contains('/')) {
            List<String> parts = v.split('/');
            if (parts.size() == 3) {
                Integer monthVal = Integer.valueOf(parts[0]);
                Integer dayVal = Integer.valueOf(parts[1]);
                Integer yearVal = Integer.valueOf(parts[2]);
                return Date.newInstance(yearVal, monthVal, dayVal);
            }
        }

        return Date.valueOf(v);
    }

    private String formatDateForInput(Date d) {
        if (d == null) {
            return null;
        }

        return String.valueOf(d.year()) + '-' +
            twoDigit(d.month()) + '-' +
            twoDigit(d.day());
    }

    private String twoDigit(Integer n) {
        return n < 10 ? '0' + String.valueOf(n) : String.valueOf(n);
    }
}
