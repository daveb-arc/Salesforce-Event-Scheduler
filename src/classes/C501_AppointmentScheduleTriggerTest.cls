@isTest
public with sharing class C501_AppointmentScheduleTriggerTest {

	@isTest
	private static void testUpdateAppointmentScheduleTrigger() {

		// Trigger Insert
		C501_Appointment_Schedule__c appointmentSchedule = new C501_Appointment_Schedule__c(
			Name = 'C501_Appointment_Schedule__c.Name',
			Scheduled_Start_Date_Time__c = DateTime.now(),
			Scheduled_End_Time__c = DateTime.now().addHours(1).time(),
			Number_Appointments_per_15_min_interval__c = 4,
			Enable__c = false,
			Number_Appointments_per_Month__c = 10
		);
		insert appointmentSchedule;

		C501_Appointment__c appointment = new C501_Appointment__c(
			Name = 'C501_Appointment__c.Name',
			Available_Time__c = DateTime.now(),
			Date__c = system.today(),
			Time__c = '10:00 AM',
			Enable__c = true,
			Maximum_Scheduled_Appointments__c = 1,
			Appointment_Schedule__c = appointmentSchedule.Id
		);
		insert appointment;

		// Trigger Update
		appointmentSchedule.Enable__c = true;
		update appointmentSchedule;

		// Trigger Delete
		delete appointmentSchedule;
	}
}