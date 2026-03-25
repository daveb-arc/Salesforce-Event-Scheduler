@isTest
private class C501_AppointmentSchedulerControllerTest {

    @testSetup
    static void setupData() {
        Account acct = new Account(Name = 'Test Household');
        insert acct;

        insert new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Birthdate = Date.newInstance(2000, 1, 1),
            AccountId = acct.Id,
            Email = 'testuser@example.com'
        );

        insert new List<Contact>{
            new Contact(
                FirstName = 'Dup1',
                LastName = 'Duplicate',
                Birthdate = Date.newInstance(1999, 2, 2),
                AccountId = acct.Id,
                Email = 'dup1@example.com'
            ),
            new Contact(
                FirstName = 'Dup2',
                LastName = 'Duplicate',
                Birthdate = Date.newInstance(1999, 2, 2),
                AccountId = acct.Id,
                Email = 'dup2@example.com'
            )
        };

        C501_Appointment_Schedule__c sched = new C501_Appointment_Schedule__c(
            Name = 'Test Schedule',
            Scheduled_Start_Date_Time__c = DateTime.now(),
            Scheduled_End_Time__c = DateTime.now().addHours(1).time(),
            Number_Appointments_per_15_min_interval__c = 4,
            Enable__c = false,
            Number_Appointments_per_Month__c = 10
        );
        insert sched;

        // Stable non-Thursday dates for general tests
        Date d1 = nextDateNotThursday(Date.today().addDays(1));
        Date d2 = nextDateNotThursday(d1.addDays(1));
        Date d3 = nextDateNotThursday(d2.addDays(1));

        // Explicit Thursday appointments for Thursday logic tests
        Date thursday = nextIsoWeekday(Date.today(), 4); // ISO Thursday = 4

        insert new List<C501_Appointment__c>{
            makeAppointment('Appointment 1', d1, '09:00 AM', sched.Id),
            makeAppointment('Appointment 2', d2, '10:00 AM', sched.Id),
            makeAppointment('Appointment 3', d3, '11:00 AM', sched.Id),

            makeAppointment('Thursday Senior Morning', thursday, '10:00 AM', sched.Id),
            makeAppointment('Thursday Senior Late Morning', thursday, '11:00 AM', sched.Id),
            makeAppointment('Thursday All Ages 12:15', thursday, '12:15 PM', sched.Id),
            makeAppointment('Thursday All Ages 12:30', thursday, '12:30 PM', sched.Id)
        };
    }

    private static Date nextIsoWeekday(Date startDate, Integer targetIsoWeekday) {
        Date d = startDate;
        while (Integer.valueOf(DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('u')) != targetIsoWeekday) {
            d = d.addDays(1);
        }
        return d;
    }

    private static Date nextDateNotThursday(Date startDate) {
        Date d = startDate;
        while (Integer.valueOf(DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('u')) == 4) {
            d = d.addDays(1);
        }
        return d;
    }

    private static C501_Appointment__c makeAppointment(String name, Date apptDate, String timeText, Id scheduleId) {
        Integer hour24 = 9;
        Integer minuteVal = 0;

        if (timeText == '10:00 AM') { hour24 = 10; minuteVal = 0; }
        else if (timeText == '11:00 AM') { hour24 = 11; minuteVal = 0; }
        else if (timeText == '12:15 PM') { hour24 = 12; minuteVal = 15; }
        else if (timeText == '12:30 PM') { hour24 = 12; minuteVal = 30; }

        DateTime availableDt = DateTime.newInstance(apptDate, Time.newInstance(hour24, minuteVal, 0, 0));

        return new C501_Appointment__c(
            Name = name,
            Name_Unique__c = name + '_' + String.valueOf(availableDt.getTime()),
            Available_Time__c = availableDt,
            Date__c = apptDate,
            Time__c = timeText,
            Enable__c = true,
            Maximum_Scheduled_Appointments__c = 5,
            Appointment_Schedule__c = scheduleId
        );
    }

    private static Contact getTestContact() {
        return [
            SELECT Id, FirstName, LastName, Birthdate, AccountId, Email, Name
            FROM Contact
            WHERE LastName = 'User'
            LIMIT 1
        ];
    }

    private static Contact createSeniorContact(String lastName) {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Contact senior = new Contact(
            FirstName = 'Senior',
            LastName = lastName,
            Birthdate = Date.newInstance(1950, 1, 1),
            AccountId = acct.Id,
            Email = lastName.toLowerCase() + '@example.com'
        );
        insert senior;
        return senior;
    }

    private static List<C501_Appointment__c> getTestAppointments() {
        return [
            SELECT Id, Name, Date__c, Time__c, Enable__c, Available_Time__c, Maximum_Scheduled_Appointments__c
            FROM C501_Appointment__c
            ORDER BY Date__c, Available_Time__c, Name
        ];
    }

    private static List<C501_Appointment__c> getNonThursdayAppointments() {
        List<C501_Appointment__c> results = new List<C501_Appointment__c>();
        for (C501_Appointment__c a : [
            SELECT Id, Name, Date__c, Time__c, Enable__c, Available_Time__c, Maximum_Scheduled_Appointments__c
            FROM C501_Appointment__c
            ORDER BY Date__c, Available_Time__c, Name
        ]) {
            Integer isoDow = Integer.valueOf(DateTime.newInstance(a.Date__c, Time.newInstance(12, 0, 0, 0)).format('u'));
            if (isoDow != 4) {
                results.add(a);
            }
        }
        return results;
    }

    private static C501_Appointment__c getThursdayMorningAppointment() {
        return [
            SELECT Id, Name, Date__c, Time__c, Enable__c, Available_Time__c, Maximum_Scheduled_Appointments__c
            FROM C501_Appointment__c
            WHERE Time__c = '10:00 AM'
              AND Name = 'Thursday Senior Morning'
            LIMIT 1
        ];
    }

    private static C501_Appointment__c getThursdayAfternoonAppointment() {
        return [
            SELECT Id, Name, Date__c, Time__c, Enable__c, Available_Time__c, Maximum_Scheduled_Appointments__c
            FROM C501_Appointment__c
            WHERE Time__c = '12:15 PM'
              AND Name = 'Thursday All Ages 12:15'
            LIMIT 1
        ];
    }

    private static List<String> getOptionLabels(List<SelectOption> options) {
        List<String> labels = new List<String>();
        if (options == null) return labels;

        for (SelectOption opt : options) {
            labels.add(opt.getLabel());
        }
        return labels;
    }

    private static C501_AppointmentSchedulerController makeFoundController() {
        Contact con = getTestContact();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.startLookup();
        ctrl.searchContact = new Contact();
        ctrl.searchContact.LastName = con.LastName;
        ctrl.searchContact.Birthdate = con.Birthdate;
        ctrl.findContact();
        return ctrl;
    }

    private static C501_AppointmentSchedulerController makeFoundController(Contact con) {
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.startLookup();
        ctrl.searchContact = new Contact();
        ctrl.searchContact.LastName = con.LastName;
        ctrl.searchContact.Birthdate = con.Birthdate;
        ctrl.findContact();
        return ctrl;
    }

    @isTest
    static void testFindContactSuccess() {
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.startLookup();
        ctrl.searchContact = new Contact();
        ctrl.searchContact.LastName = 'User';
        ctrl.searchContact.Birthdate = Date.newInstance(2000, 1, 1);
        ctrl.findContact();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.contactRec);
        System.assertEquals(3, ctrl.step);
        System.assertEquals('testuser@example.com', ctrl.email);
    }

    @isTest
    static void testFindContactMissingInputs() {
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.startLookup();
        ctrl.findContact();
        Test.stopTest();

        System.assertEquals(2, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testFindContactFailure() {
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.startLookup();
        ctrl.searchContact = new Contact();
        ctrl.searchContact.LastName = 'Wrong';
        ctrl.searchContact.Birthdate = Date.newInstance(2000, 1, 1);
        ctrl.findContact();
        Test.stopTest();

        System.assertEquals(null, ctrl.contactRec);
        System.assertEquals(2, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testFindContactDuplicateMatch() {
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.startLookup();
        ctrl.searchContact = new Contact();
        ctrl.searchContact.LastName = 'Duplicate';
        ctrl.searchContact.Birthdate = Date.newInstance(1999, 2, 2);
        ctrl.findContact();
        Test.stopTest();

        System.assertEquals(null, ctrl.contactRec);
        System.assertEquals(2, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testLoadDay1Times() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = 'abc';
        ctrl.loadDay1Times();
        Test.stopTest();

        System.assertEquals(null, ctrl.day1AppointmentId);
        System.assertNotEquals(null, ctrl.day1TimeOptions);
        System.assert(ctrl.day1TimeOptions.size() > 0);
    }

    @isTest
    static void testLoadDay2TimesAndDay3Times() {
        Contact senior = createSeniorContact('Tester');
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.contactRec = senior;
        ctrl.searchContact = new Contact(LastName = senior.LastName, Birthdate = senior.Birthdate);

        ctrl.day2Date = appts[1].Date__c;
        ctrl.day2AppointmentId = 'abc';
        ctrl.loadDay2Times();

        ctrl.day3Date = appts[2].Date__c;
        ctrl.day3AppointmentId = 'xyz';
        ctrl.loadDay3Times();
        Test.stopTest();

        System.assertEquals(null, ctrl.day2AppointmentId);
        System.assertEquals(null, ctrl.day3AppointmentId);
        System.assert(ctrl.day2TimeOptions.size() > 0);
        System.assert(ctrl.day3TimeOptions.size() > 0);
    }

    @isTest
    static void testScheduleRequiresContact() {
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(2, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleRequiresDay1() {
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleDay2MissingFields() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay2 = true;
        ctrl.day2Date = appts[1].Date__c;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleDay2DuplicateDate() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay2 = true;
        ctrl.day2Date = appts[0].Date__c;
        ctrl.day2AppointmentId = appts[1].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testSearchLastNameTextGetterSetter() {
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();

        ctrl.searchContact = null;

        System.assertEquals(null, ctrl.searchLastNameText);
        System.assertNotEquals(null, ctrl.searchContact);

        ctrl.searchLastNameText = 'User';
        System.assertEquals('User', ctrl.searchContact.LastName);
        System.assertEquals('User', ctrl.searchLastNameText);
    }

    @isTest
    static void testSearchBirthDateTextGetterSetter() {
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();

        ctrl.searchContact = null;

        System.assertEquals(null, ctrl.searchBirthDateText);
        System.assertNotEquals(null, ctrl.searchContact);

        ctrl.searchBirthDateText = '2000-01-01';
        System.assertEquals(Date.newInstance(2000, 1, 1), ctrl.searchContact.Birthdate);
        System.assertEquals('2000-01-01', ctrl.searchBirthDateText);
    }

    @isTest
    static void testLoadDay1TimesClearsWhenExistingAppointmentSameDay() {
        Contact con = getTestContact();
        List<C501_Appointment__c> appts = getNonThursdayAppointments();
    
        insert new Appointment_Scheduled_Request__c(
            Name = 'Existing Day 1',
            Contact__c = con.Id,
            Account__c = con.AccountId,
            Appointment__c = appts[0].Id,
            Appointment_Date__c = appts[0].Date__c,
            Email__c = con.Email
        );
    
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.day1TimeOptions = new List<SelectOption>{ new SelectOption('x', 'dummy') };
        ctrl.loadDay1Times();
        Test.stopTest();
    
        System.assertEquals(null, ctrl.day1Date);
        System.assertEquals(null, ctrl.day1AppointmentId);
        System.assertNotEquals(null, ctrl.day1TimeOptions);
        System.assertEquals(0, ctrl.day1TimeOptions.size());
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testLoadDay2TimesClearsWhenMonthAlreadyHasThreeAppointments() {
        Contact con = getTestContact();
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Date targetDate = appts[1].Date__c;
        Date month1 = Date.newInstance(targetDate.year(), targetDate.month(), 5);
        Date month2 = Date.newInstance(targetDate.year(), targetDate.month(), 10);
        Date month3 = Date.newInstance(targetDate.year(), targetDate.month(), 15);

        insert new List<Appointment_Scheduled_Request__c>{
            new Appointment_Scheduled_Request__c(
                Name = 'Month 1',
                Contact__c = con.Id,
                Account__c = con.AccountId,
                Appointment_Id__c = 'A1',
                Appointment_Date__c = month1,
                Email__c = con.Email
            ),
            new Appointment_Scheduled_Request__c(
                Name = 'Month 2',
                Contact__c = con.Id,
                Account__c = con.AccountId,
                Appointment_Id__c = 'A2',
                Appointment_Date__c = month2,
                Email__c = con.Email
            ),
            new Appointment_Scheduled_Request__c(
                Name = 'Month 3',
                Contact__c = con.Id,
                Account__c = con.AccountId,
                Appointment_Id__c = 'A3',
                Appointment_Date__c = month3,
                Email__c = con.Email
            )
        };

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day2Date = targetDate;
        ctrl.day2AppointmentId = appts[1].Id;
        ctrl.day2TimeOptions = new List<SelectOption>{ new SelectOption('x', 'dummy') };
        ctrl.loadDay2Times();
        Test.stopTest();

        System.assertEquals(null, ctrl.day2Date);
        System.assertEquals(null, ctrl.day2AppointmentId);
        System.assertNotEquals(null, ctrl.day2TimeOptions);
        System.assertEquals(0, ctrl.day2TimeOptions.size());
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testLoadDay3TimesLoadsNormallyWhenDateAllowed() {
        Contact senior = createSeniorContact('Allowed');
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.contactRec = senior;
        ctrl.searchContact = new Contact(LastName = senior.LastName, Birthdate = senior.Birthdate);
        ctrl.day3Date = appts[2].Date__c;
        ctrl.loadDay3Times();
        Test.stopTest();

        System.assertEquals(appts[2].Date__c, ctrl.day3Date);
        System.assertEquals(null, ctrl.day3AppointmentId);
        System.assert(ctrl.day3TimeOptions.size() > 0);
    }

    @isTest
    static void testTryLoadIncomingContactFromUrlId() {
        Contact con = getTestContact();

        Test.setCurrentPage(Page.C501_Appointment_Schedule_Bulk);
        ApexPages.currentPage().getParameters().put('id', con.Id);

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.contactRec);
        System.assertEquals(con.Id, ctrl.contactRec.Id);
        System.assertEquals(con.Email, ctrl.email);
        System.assertEquals(3, ctrl.step);
        System.assertEquals(con.LastName, ctrl.searchContact.LastName);
        System.assertEquals(con.Birthdate, ctrl.searchContact.Birthdate);
    }

    @isTest
    static void testScheduleDay3MissingFields() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay2 = true;
        ctrl.day2Date = appts[1].Date__c;
        ctrl.day2AppointmentId = appts[1].Id;
        ctrl.showDay3 = true;
        ctrl.day3Date = appts[2].Date__c;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleDay3DuplicateDate() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay2 = true;
        ctrl.day2Date = appts[1].Date__c;
        ctrl.day2AppointmentId = appts[1].Id;
        ctrl.showDay3 = true;
        ctrl.day3Date = appts[1].Date__c;
        ctrl.day3AppointmentId = appts[2].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleDay3WithoutDay2() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay3 = true;
        ctrl.day3Date = appts[2].Date__c;
        ctrl.day3AppointmentId = appts[2].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleRejectsDuplicateAppointmentIds() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay2 = true;
        ctrl.day2Date = appts[1].Date__c;
        ctrl.day2AppointmentId = appts[0].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleRejectsDuplicateAppointmentIdsOnDay3() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay2 = true;
        ctrl.day2Date = appts[1].Date__c;
        ctrl.day2AppointmentId = appts[1].Id;
        ctrl.showDay3 = true;
        ctrl.day3Date = appts[2].Date__c;
        ctrl.day3AppointmentId = appts[1].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleOneDay() {
        Contact con = getTestContact();
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(4, ctrl.step);

        List<Appointment_Scheduled_Request__c> scheduled = [
            SELECT Id, Contact__c, Account__c, Appointment__c, Appointment_Id__c, Email__c
            FROM Appointment_Scheduled_Request__c
            WHERE Contact__c = :con.Id
        ];
        System.assertEquals(1, scheduled.size());
        System.assertEquals(appts[0].Id, scheduled[0].Appointment_Id__c);
    }

    @isTest
    static void testScheduleThreeDifferentDays() {
        Contact senior = createSeniorContact('Schedule3');
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.startLookup();
        ctrl.contactRec = senior;
        ctrl.searchContact = new Contact(LastName = senior.LastName, Birthdate = senior.Birthdate);
        ctrl.email = senior.Email;
        ctrl.step = 3;

        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.showDay2 = true;
        ctrl.day2Date = appts[1].Date__c;
        ctrl.day2AppointmentId = appts[1].Id;
        ctrl.showDay3 = true;
        ctrl.day3Date = appts[2].Date__c;
        ctrl.day3AppointmentId = appts[2].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(4, ctrl.step);

        List<Appointment_Scheduled_Request__c> scheduled = [
            SELECT Id, Contact__c, Appointment__c, Appointment_Id__c
            FROM Appointment_Scheduled_Request__c
            WHERE Contact__c = :senior.Id
        ];
        System.assertEquals(3, scheduled.size());
    }

    @isTest
    static void testScheduleRejectsAppointmentDateMismatch() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[1].Date__c; // wrong date on purpose
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(appts[1].Date__c, ctrl.day1Date);
        System.assertEquals(appts[0].Id, ctrl.day1AppointmentId);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testLoadDay1Times_ThursdayUnder60_HidesMorningSeniorOnly() {
        C501_Appointment__c morning = getThursdayMorningAppointment();
    
        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController(); // under 60
        ctrl.day1Date = morning.Date__c;
        ctrl.loadDay1Times();
        Test.stopTest();
    
        System.assertEquals(morning.Date__c, ctrl.day1Date);
        System.assertNotEquals(null, ctrl.day1TimeOptions);
        System.assertEquals(false, ApexPages.hasMessages());
    
        System.assertEquals(false, containsLabelStartingWith(ctrl.day1TimeOptions, '10:00 AM'));
        System.assertEquals(false, containsLabelStartingWith(ctrl.day1TimeOptions, '11:00 AM'));
        System.assertEquals(true, containsLabelStartingWith(ctrl.day1TimeOptions, '12:15 PM'));
        System.assertEquals(true, containsLabelStartingWith(ctrl.day1TimeOptions, '12:30 PM'));
    }

    @isTest
    static void testLoadDay1Times_ThursdaySenior_ShowsMorningAndAfternoon() {
        Contact senior = createSeniorContact('ThursdaySenior');
        C501_Appointment__c morning = getThursdayMorningAppointment();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController(senior);
        ctrl.day1Date = morning.Date__c;
        ctrl.loadDay1Times();
        Test.stopTest();

        System.assertEquals(morning.Date__c, ctrl.day1Date);
        System.assertNotEquals(null, ctrl.day1TimeOptions);
        System.assertEquals(false, ApexPages.hasMessages());

        System.assertEquals(true, containsLabelStartingWith(ctrl.day1TimeOptions, '10:00 AM'));
        System.assertEquals(true, containsLabelStartingWith(ctrl.day1TimeOptions, '11:00 AM'));
        System.assertEquals(true, containsLabelStartingWith(ctrl.day1TimeOptions, '12:15 PM'));
        System.assertEquals(true, containsLabelStartingWith(ctrl.day1TimeOptions, '12:30 PM'));
    }

    @isTest
    static void testScheduleOneDay_ThursdayAfternoonAllowedForUnder60() {
        Contact con = getTestContact();
        C501_Appointment__c afternoon = getThursdayAfternoonAppointment();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = afternoon.Date__c;
        ctrl.day1AppointmentId = afternoon.Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(4, ctrl.step);

        List<Appointment_Scheduled_Request__c> scheduled = [
            SELECT Id, Contact__c, Appointment__c, Appointment_Id__c, Appointment_Date__c
            FROM Appointment_Scheduled_Request__c
            WHERE Contact__c = :con.Id
              AND Appointment__c = :afternoon.Id
        ];
        System.assertEquals(1, scheduled.size());
        System.assertEquals(afternoon.Date__c, scheduled[0].Appointment_Date__c);
    }

    @isTest
    static void testScheduleRejectsDeletedAppointmentAndClearsDay1() {
        List<C501_Appointment__c> appts = getNonThursdayAppointments();
        Id deletedApptId = appts[0].Id;
        Date deletedDate = appts[0].Date__c;
        delete appts[0];

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = deletedDate;
        ctrl.day1AppointmentId = String.valueOf(deletedApptId);
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testScheduleRejectsFullAppointment() {
        Contact con = getTestContact();

        C501_Appointment__c appt = [
            SELECT Id, Date__c, Maximum_Scheduled_Appointments__c
            FROM C501_Appointment__c
            WHERE Name = 'Appointment 1'
            LIMIT 1
        ];

        Integer maxAppts = Integer.valueOf(appt.Maximum_Scheduled_Appointments__c);

        List<Appointment_Scheduled_Request__c> requests = new List<Appointment_Scheduled_Request__c>();
        for (Integer i = 0; i < maxAppts; i++) {
            requests.add(new Appointment_Scheduled_Request__c(
                Name = 'Existing Request ' + i,
                Contact__c = con.Id,
                Account__c = con.AccountId,
                Appointment__c = appt.Id,
                Appointment_Date__c = appt.Date__c,
                Email__c = 'existing' + i + '@example.com'
            ));
        }
        insert requests;

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appt.Date__c;
        ctrl.day1AppointmentId = appt.Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(3, ctrl.step);
        System.assertEquals(true, ApexPages.hasMessages());
    }

    @isTest
    static void testToggleDay2ClearsDay2AndDay3() {
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.showDay2 = false;
        ctrl.showDay3 = true;
        ctrl.day2Date = Date.today().addDays(2);
        ctrl.day3Date = Date.today().addDays(3);
        ctrl.day2AppointmentId = 'a';
        ctrl.day3AppointmentId = 'b';
        ctrl.toggleDay2();

        System.assertEquals(false, ctrl.showDay3);
        System.assertEquals(null, ctrl.day2Date);
        System.assertEquals(null, ctrl.day3Date);
        System.assertEquals(null, ctrl.day2AppointmentId);
        System.assertEquals(null, ctrl.day3AppointmentId);
    }

    @isTest
    static void testToggleDay3ClearsDay3() {
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        ctrl.showDay3 = false;
        ctrl.day3Date = Date.today().addDays(3);
        ctrl.day3AppointmentId = 'b';
        ctrl.toggleDay3();

        System.assertEquals(null, ctrl.day3Date);
        System.assertEquals(null, ctrl.day3AppointmentId);
    }

    @isTest
    static void testGoBackAndStepFlags() {
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();

        System.assertEquals(true, ctrl.getIsStep1());
        System.assertEquals(false, ctrl.getIsStep2());
        System.assertEquals(false, ctrl.getIsStep3());
        System.assertEquals(false, ctrl.getIsStep4());

        ctrl.startLookup();
        System.assertEquals(2, ctrl.step);
        System.assertEquals(false, ctrl.getIsStep1());
        System.assertEquals(true, ctrl.getIsStep2());
        System.assertEquals(false, ctrl.getIsStep3());
        System.assertEquals(false, ctrl.getIsStep4());

        ctrl.goBack();
        System.assertEquals(1, ctrl.step);

        ctrl.step = 3;
        System.assertEquals(false, ctrl.getIsStep1());
        System.assertEquals(false, ctrl.getIsStep2());
        System.assertEquals(true, ctrl.getIsStep3());
        System.assertEquals(false, ctrl.getIsStep4());

        ctrl.step = 4;
        System.assertEquals(false, ctrl.getIsStep1());
        System.assertEquals(false, ctrl.getIsStep2());
        System.assertEquals(false, ctrl.getIsStep3());
        System.assertEquals(true, ctrl.getIsStep4());
    }

    @isTest
    static void testTodayIsoFormat() {
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
        String iso = ctrl.getTodayIso();

        System.assertEquals(10, iso.length());
        System.assertEquals('-', iso.substring(4, 5));
        System.assertEquals('-', iso.substring(7, 8));
    }

    private static Boolean containsLabelStartingWith(List<SelectOption> options, String prefix) {
        if (options == null) return false;
    
        for (SelectOption opt : options) {
            if (opt != null && opt.getLabel() != null && opt.getLabel().startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }    
}