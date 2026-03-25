public without sharing class C501_AppointmentSchedulerController {

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
        get { return formatDateForDisplay(day1Date); }
        set { day1Date = parseDateFromInput(value); }
    }
    
    public String day2DateText {
        get { return formatDateForDisplay(day2Date); }
        set { day2Date = parseDateFromInput(value); }
    }
    
    public String day3DateText {
        get { return formatDateForDisplay(day3Date); }
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

        if (UserInfo.getUserType() != 'Guest') {
            day1Date = Date.today();
            day1DateText = day1Date.format();
        }
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
        day1AppointmentId = null;
    
        if (!validateSelectedDateForContact(day1Date, 'Day 1')) {
            day1TimeOptions = new List<SelectOption>();
            return null;
        }
    
        day1TimeOptions = buildTimeOptionsForDate(day1Date, 'Day 1');
        return null;
    }
    
    public PageReference loadDay2Times() {
        day2AppointmentId = null;
    
        if (!validateSelectedDateForContact(day2Date, 'Day 2')) {
            day2TimeOptions = new List<SelectOption>();
            return null;
        }
    
        day2TimeOptions = buildTimeOptionsForDate(day2Date, 'Day 2');
        return null;
    }
    
    public PageReference loadDay3Times() {
        day3AppointmentId = null;
    
        if (!validateSelectedDateForContact(day3Date, 'Day 3')) {
            day3TimeOptions = new List<SelectOption>();
            return null;
        }
    
        day3TimeOptions = buildTimeOptionsForDate(day3Date, 'Day 3');
        return null;
    }

    private List<SelectOption> buildTimeOptionsForDate(Date selectedDate, String dayLabel) {
        List<SelectOption> opts = new List<SelectOption>();

        if (selectedDate == null) {
            return opts;
        }

        Date birthdate = null;
        if (contactRec != null) {
            birthdate = contactRec.Birthdate;
        } else if (searchContact != null) {
            birthdate = searchContact.Birthdate;
        }

        Boolean isSenior = isSixtyOrOlder(birthdate);
        Boolean isThursday =
            Integer.valueOf(DateTime.newInstance(selectedDate, Time.newInstance(12, 0, 0, 0)).format('u')) == 4;

        List<C501_Appointment__c> appts = [
            SELECT Id, Name, Date__c, Time__c, Available_Time__c,
                Appointments_Full__c, Maximum_Scheduled_Appointments__c
            FROM C501_Appointment__c
            WHERE Date__c = :selectedDate
            AND Enable__c = true
            ORDER BY Available_Time__c, Time__c, Name
        ];

        for (C501_Appointment__c appt : appts) {
            if (appt.Appointments_Full__c == true) {
                continue;
            }

            if (isThursday && !isSenior && isThursdaySeniorOnlyTime(appt.Time__c)) {
                continue;
            }

            String label = appt.Time__c;
            if (appt.Maximum_Scheduled_Appointments__c != null) {
                label += ' (' + String.valueOf(appt.Maximum_Scheduled_Appointments__c) + ' Remaining)';
            }

            opts.add(new SelectOption(appt.Id, label));
        }

        return opts;
    }

    private Boolean isSixtyOrOlder(Date birthdate) {
        if (birthdate == null) {
            return false;
        }
        Integer age = birthdate.daysBetween(Date.today()) / 365;
        return age >= 60;
    }

    private Boolean isThursdaySeniorOnlyTime(String timeText) {
        if (String.isBlank(timeText)) {
            return false;
        }
    
        Integer mins = parseTimeTextToMinutes(timeText);
    
        // 10:00 AM up to but not including 12:15 PM
        return mins >= (10 * 60) && mins < (12 * 60 + 15);
    }
    
    private Integer parseTimeTextToMinutes(String timeText) {
        String t = timeText.trim().toUpperCase();
        Boolean isPm = t.endsWith('PM');
        Boolean isAm = t.endsWith('AM');
    
        t = t.replace('AM', '').replace('PM', '').trim();
        List<String> parts = t.split(':');
    
        Integer hourVal = Integer.valueOf(parts[0]);
        Integer minuteVal = Integer.valueOf(parts[1]);
    
        if (isPm && hourVal != 12) {
            hourVal += 12;
        }
        if (isAm && hourVal == 12) {
            hourVal = 0;
        }
    
        return (hourVal * 60) + minuteVal;
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
        }
    
        // Prevent same day on screen selections
        if (showDay2 && day2Date != null && day2Date == day1Date) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You cannot have more than 1 appointment on the same day.'
            ));
            clearSelectedDay('Day 2');
            return null;
        }
    
        if (showDay3 && day3Date != null && day3Date == day1Date) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You cannot have more than 1 appointment on the same day.'
            ));
            clearSelectedDay('Day 3');
            return null;
        }
    
        if (showDay2 && showDay3 && day2Date != null && day3Date != null && day3Date == day2Date) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You cannot have more than 1 appointment on the same day.'
            ));
            clearSelectedDay('Day 3');
            return null;
        }
    
        // Re-run per-day validation as a final safety check
        if (!validateSelectedDateForContact(day1Date, 'Day 1')) {
            return null;
        }
        if (showDay2 && !validateSelectedDateForContact(day2Date, 'Day 2')) {
            return null;
        }
        if (showDay3 && !validateSelectedDateForContact(day3Date, 'Day 3')) {
            return null;
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
     
        if (!validateMonthlyLimitWithPendingSelections()) {
            return null;
        }
    
        Map<Id, C501_Appointment__c> apptById = new Map<Id, C501_Appointment__c>([
            SELECT Id, Name, Date__c, Time__c, Summary__c, Appointments_Full__c, Maximum_Scheduled_Appointments__c
            FROM C501_Appointment__c
            WHERE Id IN :appointmentIds
            FOR UPDATE
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
    
        if (!validateAppointmentStillAvailable(apptById, day1AppointmentId, day1Date, 'Day 1')) {
            return null;
        }
        if (showDay2 && !validateAppointmentStillAvailable(apptById, day2AppointmentId, day2Date, 'Day 2')) {
            return null;
        }
        if (showDay3 && !validateAppointmentStillAvailable(apptById, day3AppointmentId, day3Date, 'Day 3')) {
            return null;
        }
    
        List<Appointment_Scheduled_Request__c> toInsert = new List<Appointment_Scheduled_Request__c>();
        confirmationLines = new List<String>();
    
        addRow(toInsert, apptById.get((Id)day1AppointmentId), 'Day 1');
    
        if (showDay2) {
            addRow(toInsert, apptById.get((Id)day2AppointmentId), 'Day 2');
        }
    
        if (showDay3) {
            addRow(toInsert, apptById.get((Id)day3AppointmentId), 'Day 3');
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

    private Boolean validateAppointmentStillAvailable(
        Map<Id, C501_Appointment__c> apptById,
        String apptId,
        Date expectedDate,
        String dayLabel
    ) {
        if (String.isBlank(apptId)) {
            return true;
        }
    
        if (!apptById.containsKey((Id)apptId)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                dayLabel + ' is no longer available. Please select a different appointment.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        C501_Appointment__c appt = apptById.get((Id)apptId);
    
        if (appt.Date__c != expectedDate) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                dayLabel + ' is no longer available for the selected date. Please choose another date/time.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        Integer existingCount = [
            SELECT COUNT()
            FROM Appointment_Scheduled_Request__c
            WHERE Appointment__c = :appt.Id
        ];
    
        Integer maxAllowed = appt.Maximum_Scheduled_Appointments__c == null
            ? 0
            : Integer.valueOf(appt.Maximum_Scheduled_Appointments__c);
    
        if ((appt.Appointments_Full__c == true) ||
            (maxAllowed > 0 && existingCount >= maxAllowed)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                dayLabel + ' is full. Please select a different appointment time.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        return true;
    }

    private Integer getAgeOnDate(Date birthDate, Date asOfDate) {
        if (birthDate == null || asOfDate == null) {
            return null;
        }

        Integer age = asOfDate.year() - birthDate.year();

        if (asOfDate.month() < birthDate.month() ||
            (asOfDate.month() == birthDate.month() && asOfDate.day() < birthDate.day())) {
            age--;
        }

        return age;
    }

    private Boolean isThursday(Date d) {
        if (d == null) {
            return false;
        }

        // Sunday=1, Monday=2, Tuesday=3, Wednesday=4, Thursday=5, Friday=6, Saturday=7
        Integer dayOfWeek = Integer.valueOf(
            DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('u')
        );

        // format('u') is ISO weekday: Monday=1 ... Sunday=7
        // Thursday = 4
        return dayOfWeek == 4;
    }

    private void addRow(List<Appointment_Scheduled_Request__c> rows, C501_Appointment__c appt, String dayLabel) {
    
        // Remove when want to enable in production - this triggers the flow to create C501_Appointment_Scheduled__c record
        Boolean createAppointment = Test.isRunningTest();

        rows.add(new Appointment_Scheduled_Request__c(
            Name = contactRec.Name + ' ' + dayLabel,
            Contact__c = contactRec.Id,
            Account__c = contactRec.AccountId,
            Appointment__c = appt.Id,
            Appointment_Id__c = appt.Id,
            Appointment_Date__c = appt.Date__c,
            Create_Appointment__c = createAppointment,
            Email__c = email
        ));

        String label = String.isBlank(appt.Summary__c)
            ? (String.isBlank(appt.Time__c) ? appt.Name : appt.Time__c)
            : appt.Summary__c;
        confirmationLines.add(dayLabel + ': ' + String.valueOf(appt.Date__c) + ' - ' + label);
    }

    private Boolean validateMonthlyLimitWithPendingSelections() {
        if (contactRec == null) {
            return true;
        }
    
        List<Date> selectedDates = new List<Date>();
        if (day1Date != null) selectedDates.add(day1Date);
        if (showDay2 && day2Date != null) selectedDates.add(day2Date);
        if (showDay3 && day3Date != null) selectedDates.add(day3Date);
    
        if (selectedDates.isEmpty()) {
            return true;
        }
    
        Id contactId = contactRec.Id;
    
        Map<String, Integer> selectedPerMonth = new Map<String, Integer>();
        for (Date d : selectedDates) {
            String monthKey = String.valueOf(d.year()) + '-' + String.valueOf(d.month());
            Integer currentCount = selectedPerMonth.containsKey(monthKey) ? selectedPerMonth.get(monthKey) : 0;
            selectedPerMonth.put(monthKey, currentCount + 1);
        }
    
        for (String monthKey : selectedPerMonth.keySet()) {
            List<String> parts = monthKey.split('-');
            Integer y = Integer.valueOf(parts[0]);
            Integer m = Integer.valueOf(parts[1]);
    
            Date firstOfMonth = Date.newInstance(y, m, 1);
            Date firstOfNextMonth = firstOfMonth.addMonths(1);
    
            Integer existingCount = [
                SELECT COUNT()
                FROM Appointment_Scheduled_Request__c
                WHERE Contact__c = :contactId
                  AND Appointment_Date__c >= :firstOfMonth
                  AND Appointment_Date__c < :firstOfNextMonth
            ];
    
            Integer pendingCount = selectedPerMonth.get(monthKey);
    
            if (existingCount + pendingCount > 3) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'You already have appointments in this month. You can only have a maximum of 3 appointments scheduled per month.'
                ));
                return false;
            }
        }
    
        return true;
    }

    private Boolean validateSelectedDateForContact(Date selectedDate, String dayLabel) {
        if (contactRec == null || selectedDate == null) {
            return true;
        }
    
        Id contactId = contactRec.Id;
    
        // Rule 0: same day already selected on screen
        if (dayLabel != 'Day 1' && day1Date != null && day1Date == selectedDate) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You cannot have more than 1 appointment on the same day.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        if (dayLabel != 'Day 2' && day2Date != null && day2Date == selectedDate) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You cannot have more than 1 appointment on the same day.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        if (dayLabel != 'Day 3' && day3Date != null && day3Date == selectedDate) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You cannot have more than 1 appointment on the same day.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        // Rule 1: already has appointment on same day in database
        Integer sameDayCount = [
            SELECT COUNT()
            FROM Appointment_Scheduled_Request__c
            WHERE Contact__c = :contactId
              AND Appointment_Date__c = :selectedDate
        ];
    
        if (sameDayCount > 0) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You already have an appointment on that day.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        // Rule 2: max 3 appointments in same month
        Date firstOfMonth = Date.newInstance(selectedDate.year(), selectedDate.month(), 1);
        Date firstOfNextMonth = firstOfMonth.addMonths(1);
    
        Integer dbMonthCount = [
            SELECT COUNT()
            FROM Appointment_Scheduled_Request__c
            WHERE Contact__c = :contactId
              AND Appointment_Date__c >= :firstOfMonth
              AND Appointment_Date__c < :firstOfNextMonth
        ];
    
        Integer selectedMonthCount = 0;
    
        if (dayLabel != 'Day 1' && day1Date != null &&
            day1Date.year() == selectedDate.year() &&
            day1Date.month() == selectedDate.month()) {
            selectedMonthCount++;
        }
    
        if (dayLabel != 'Day 2' && day2Date != null &&
            day2Date.year() == selectedDate.year() &&
            day2Date.month() == selectedDate.month()) {
            selectedMonthCount++;
        }
    
        if (dayLabel != 'Day 3' && day3Date != null &&
            day3Date.year() == selectedDate.year() &&
            day3Date.month() == selectedDate.month()) {
            selectedMonthCount++;
        }
    
        Integer totalMonthCount = dbMonthCount + selectedMonthCount + 1;
    
        if (totalMonthCount > 3) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'You already have appointments in that month. You can only have a maximum of 3 appointments scheduled in the same month.'
            ));
            clearSelectedDay(dayLabel);
            return false;
        }
    
        return true;
    }
        
    private void clearSelectedDay(String dayLabel) {
        if (dayLabel == 'Day 1') {
            day1Date = null;
            day1AppointmentId = null;
            day1TimeOptions = new List<SelectOption>();
        } else if (dayLabel == 'Day 2') {
            day2Date = null;
            day2AppointmentId = null;
            day2TimeOptions = new List<SelectOption>();
        } else if (dayLabel == 'Day 3') {
            day3Date = null;
            day3AppointmentId = null;
            day3TimeOptions = new List<SelectOption>();
        }
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

    private String formatDateForDisplay(Date d) {
        if (d == null) {
            return null;
        }
    
        return twoDigit(d.month()) + '/' +
               twoDigit(d.day()) + '/' +
               String.valueOf(d.year());
    }    
}
