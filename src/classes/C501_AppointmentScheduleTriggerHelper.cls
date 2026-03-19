public with sharing class C501_AppointmentScheduleTriggerHelper {

	public class InvalidParameterValueException extends Exception {}

	// only need one instance of this class per transaction
	private static C501_AppointmentScheduleTriggerHelper instance;
	public static C501_AppointmentScheduleTriggerHelper get() {
		if (instance == null) instance = new C501_AppointmentScheduleTriggerHelper();
		return instance;
	}
	
	public void updateAppointmentSchedule( List<C501_Appointment_Schedule__c> appointmentScheduleList, map<id, C501_Appointment_Schedule__c> oldMap, Boolean isBefore) {

		if (appointmentScheduleList == null || appointmentScheduleList.isEmpty()) {
			return;
		}

		if (isBefore) {
			for (C501_Appointment_Schedule__c appointmentSchedule :appointmentScheduleList) {

				System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule - isBefore Scheduled_Start_Date_Time__c (Time): ' + appointmentSchedule.Scheduled_Start_Date_Time__c.time() + ' Scheduled_End_Time__c: ' + appointmentSchedule.Scheduled_End_Time__c);
				if (appointmentSchedule.Scheduled_Start_Date_Time__c.time() >= appointmentSchedule.Scheduled_End_Time__c) {
					System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule - add error');
					appointmentSchedule.AddError('updateAppointmentSchedule::Exception Start Time (' + appointmentSchedule.Scheduled_Start_Date_Time__c.time() + ') must be less than End Time (' + appointmentSchedule.Scheduled_End_Time__c + ')');
					continue;					
				}

				System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule - isBefore Scheduled_Start_Date_Time__c (Date): ' + appointmentSchedule.Scheduled_Start_Date_Time__c.date() + ' Range_Of_Recurrence_End_By__c: ' + appointmentSchedule.Range_Of_Recurrence_End_By__c);
				if (appointmentSchedule.Scheduled_Start_Date_Time__c.date() > appointmentSchedule.Range_Of_Recurrence_End_By__c) {
					System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule - add error');
					appointmentSchedule.AddError('updateAppointmentSchedule::Exception Start Date (' + appointmentSchedule.Scheduled_Start_Date_Time__c.date() + ') must be less or equal to the End Date (' + appointmentSchedule.Range_Of_Recurrence_End_By__c + ')');
					continue;					
				}
			}
		}

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//
		Date dateToday = system.today();
		List<C501_Appointment__c> allAppointments = [
			SELECT Id, Name, Appointment_Schedule__c, Enable__c, Maximum_Scheduled_Appointments__c
			FROM C501_Appointment__c
			WHERE Date__c >= :dateToday];

		// Process all appointments to make sure appointments have the right parent
		List<C501_Appointment_Schedule__c> allAppointmentSchedules = [
			SELECT Id, Name, Enable__c, Scheduled_Start_Date_Time__c, Scheduled_End_Time__c, Range_Of_Recurrence_End_By__c, Days_of_Week__c, Weekly_Occurrence__c,
				Number_Appointments_per_15_min_interval__c, Senior_Only_Appointments_60_and_over__c
			FROM C501_Appointment_Schedule__c
			WHERE Enable__c = true AND isDeleted = false
			ORDER BY LastModifiedDate DESC];

		// Step1: Remove Schedule Id
		Map<String, C501_Appointment__c> allAppointmentsByName = new Map<String, C501_Appointment__c>();
		Map<Id, C501_Appointment__c> updateAppointments = new Map<Id, C501_Appointment__c>();
		for ( C501_Appointment__c appointment:allAppointments) {
			try {
				appointment.Appointment_Schedule__c = null;
				updateAppointments.put(appointment.Id, appointment);

				// Build ByName map for processing later
				allAppointmentsByName.put(appointment.Name, appointment);
			}
			catch (Exception e) {
				appointmentScheduleList[0].AddError('updateAppointmentSchedule::Exception - ' + String.valueOf(e));
				continue;
			}
		}

		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		if (!updateAppointments.isEmpty()) {
			update updateAppointments.values();
		}

		updateAppointments.clear();
		Map<String, C501_Appointment__c> insertAppointments = new Map<String, C501_Appointment__c>();

		// Step2: Update all related Appointments and create new Appointments
		for ( C501_Appointment_Schedule__c appointmentSchedule :allAppointmentSchedules ) {

			if (!appointmentSchedule.Enable__c) {
				continue;
			}

			System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule - appointmentSchedule: ' + appointmentSchedule);

			try {
				DateTime appointmentDateTime = appointmentSchedule.Scheduled_Start_Date_Time__c;

				Set<DateTime> appointmentDays = new Set<DateTime>();
				appointmentDays.add(appointmentDateTime);

				while (appointmentSchedule.Range_Of_Recurrence_End_By__c != null &&
					appointmentDateTime.date() <= appointmentSchedule.Range_Of_Recurrence_End_By__c) {

					// Set appointmentDateTime to first day of the month
					appointmentDateTime = appointmentDateTime.addDays(-1 * (appointmentDateTime.day() - 1));

					for ( Integer weekday = 0; weekday <= 6; weekday++ ) {

						String dayOfWeek = appointmentDateTime.format('E');
						System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule dayOfWeek: ' + dayOfWeek + ' appointmentSchedule.Days_of_Week__c: ' + appointmentSchedule.Days_of_Week__c);

						if (appointmentSchedule.Days_of_Week__c.contains(dayOfWeek)) {
							for ( String weeklyOccurence :appointmentSchedule.Weekly_Occurrence__c.split(';')) {

								Integer weeklyOccuranceFactor = Integer.valueOf(weeklyOccurence.left(1)) - 1;
								DateTime appointmentDayAdd = appointmentDateTime.addDays(7 * weeklyOccuranceFactor);

								System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule weeklyOccurence Loop: weeklyOccurence' + weeklyOccurence + ' weeklyOccuranceFactor: ' + String.valueOf(weeklyOccuranceFactor) + ' appointmentDayAdd: ' + appointmentDayAdd.format());

								System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule ' + appointmentDayAdd + ' >= ' + appointmentSchedule.Scheduled_Start_Date_Time__c);
								System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule ' + appointmentDayAdd.month() + ' == ' + appointmentDateTime.month());

								if (appointmentDayAdd >= appointmentSchedule.Scheduled_Start_Date_Time__c
									&& appointmentDayAdd.month() ==  appointmentDateTime.month()) {

									System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule add appointmentDayAdd: ' + appointmentDays);
									appointmentDays.add(appointmentDayAdd);
								}						
							}
						}

						appointmentDateTime = appointmentDateTime.addDays(1);
					}

					// Set appointmentDateTime to next month
					appointmentDateTime = appointmentDateTime.addMonths(1);
				}

				for (DateTime appointment :appointmentDays) {

					System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule appointment: ' + appointment);

					System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule ' + appointment.date() + ' < ' + dateToday);

					// Skip processing times that are in the past
					if (appointment.date() < dateToday) {
						continue;
					}

					appointmentDateTime = appointment;

					// Salesforce Apex DateTime Rounding Error - make sure starting on same start hour
					appointmentDateTime = appointmentDateTime.addHours(appointmentSchedule.Scheduled_Start_Date_Time__c.hour() - appointmentDateTime.hour());

					System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule while (' + appointmentDateTime.time() + ' < ' + appointmentSchedule.Scheduled_End_Time__c + ')');

					while (appointmentDateTime.time() < appointmentSchedule.Scheduled_End_Time__c) {
						String appointmentName = appointmentDateTime.format('yyyy-MM-dd - hh:mm a');
						String appointmentTimeDisplay = appointmentDateTime.format('hh:mm a');

						System.debug(LoggingLevel.DEBUG, '*****C501_AppointmentScheduleTriggerHelper::updateAppointmentSchedule Check Appointment - appointmentTimeDisplay: ' + appointmentTimeDisplay + ' Name: ' + appointmentName);

						if (allAppointmentsByName.containsKey(appointmentName)) {

							C501_Appointment__c appointmentUpdate = allAppointmentsByName.get(appointmentName);
							if (!updateAppointments.containsKey(appointmentUpdate.Id)) {
								
								appointmentUpdate.Appointment_Schedule__c = appointmentSchedule.Id;
								appointmentUpdate.Available_Time__c = appointmentDateTime;
								appointmentUpdate.Date__c = appointmentDateTime.date();
								appointmentUpdate.Time__c = appointmentTimeDisplay;

								appointmentUpdate.Appointment_Schedule__c = appointmentSchedule.Id;
								appointmentUpdate.Maximum_Scheduled_Appointments__c = appointmentSchedule.Number_Appointments_per_15_min_interval__c;
								appointmentUpdate.Senior_Only_Appointments_60_and_over__c = appointmentSchedule.Senior_Only_Appointments_60_and_over__c;

								updateAppointments.put(appointmentUpdate.Id, appointmentUpdate);
							}
						}
						else {
							C501_Appointment__c appointmentScheduling = new C501_Appointment__c(
								Name = appointmentName,
								Name_Unique__c = appointmentName,
								Appointment_Schedule__c = appointmentSchedule.Id,
								Available_Time__c = appointmentDateTime,
								Date__c = appointmentDateTime.date(),
								Time__c = appointmentTimeDisplay,
								Enable__c = true,
								Maximum_Scheduled_Appointments__c = appointmentSchedule.Number_Appointments_per_15_min_interval__c,
								Senior_Only_Appointments_60_and_over__c = appointmentSchedule.Senior_Only_Appointments_60_and_over__c);

							insertAppointments.put(appointmentName, appointmentScheduling);
						}

						// Increment by 15 minutes
						appointmentDateTime = appointmentDateTime.addMinutes(15);
					}
				}
			}
			catch (Exception e) {
				appointmentScheduleList[0].AddError('updateAppointmentSchedule::Exception - ' + String.valueOf(e));
				continue;
			}
		}

		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		if (!updateAppointments.isEmpty()) {
			update updateAppointments.values();
		}
		if (!insertAppointments.isEmpty()) {
			insert insertAppointments.values();
		}
	}
}