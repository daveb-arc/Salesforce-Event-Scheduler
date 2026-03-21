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

        Date d1 = Date.today().addDays(1);
        Date d2 = Date.today().addDays(2);
        Date d3 = Date.today().addDays(3);

        insert new List<C501_Appointment__c>{
            makeAppointment('Appointment 1', d1, '09:00 AM', sched.Id),
            makeAppointment('Appointment 2', d2, '10:00 AM', sched.Id),
            makeAppointment('Appointment 3', d3, '11:00 AM', sched.Id)
        };
    }

    private static C501_Appointment__c makeAppointment(String name, Date apptDate, String timeText, Id scheduleId) {
        Integer hour24 = 9;
        if (timeText == '10:00 AM') hour24 = 10;
        if (timeText == '11:00 AM') hour24 = 11;
        DateTime availableDt = DateTime.newInstance(apptDate, Time.newInstance(hour24, 0, 0, 0));

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

    private static List<C501_Appointment__c> getTestAppointments() {
        return [
            SELECT Id, Name, Date__c, Time__c, Enable__c, Available_Time__c
            FROM C501_Appointment__c
            ORDER BY Date__c
        ];
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
        List<C501_Appointment__c> appts = getTestAppointments();

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
        List<C501_Appointment__c> appts = getTestAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = new C501_AppointmentSchedulerController();
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
        List<C501_Appointment__c> appts = getTestAppointments();

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
        List<C501_Appointment__c> appts = getTestAppointments();

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
    
        // getter should initialize searchContact and return null
        System.assertEquals(null, ctrl.searchLastNameText);
        System.assertNotEquals(null, ctrl.searchContact);
    
        // setter should populate LastName
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
    static void testScheduleDay3MissingFields() {
        List<C501_Appointment__c> appts = getTestAppointments();

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
        List<C501_Appointment__c> appts = getTestAppointments();

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
        List<C501_Appointment__c> appts = getTestAppointments();

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
        List<C501_Appointment__c> appts = getTestAppointments();

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
        List<C501_Appointment__c> appts = getTestAppointments();

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
        List<C501_Appointment__c> appts = getTestAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
        ctrl.day1Date = appts[0].Date__c;
        ctrl.day1AppointmentId = appts[0].Id;
        ctrl.schedule();
        Test.stopTest();

        System.assertEquals(4, ctrl.step);

        List<Appointment_Scheduled_Request__c> scheduled = [
            SELECT Id, Contact_Id__c, Account_Id__c, Appointment_Id__c, Email__c
            FROM Appointment_Scheduled_Request__c
            WHERE Contact_Id__c = :con.Id
        ];
        System.assertEquals(1, scheduled.size());
        System.assertEquals(appts[0].Id, scheduled[0].Appointment_Id__c);
    }

    @isTest
    static void testScheduleThreeDifferentDays() {
        Contact con = getTestContact();
        List<C501_Appointment__c> appts = getTestAppointments();

        Test.startTest();
        C501_AppointmentSchedulerController ctrl = makeFoundController();
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
            SELECT Id, Contact_Id__c, Appointment_Id__c
            FROM Appointment_Scheduled_Request__c
            WHERE Contact_Id__c = :con.Id
        ];
        System.assertEquals(3, scheduled.size());
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
}