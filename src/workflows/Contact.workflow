<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>Admin_Setup_Appointments_Alert</fullName>
        <description>Admin Setup - Appointments Alert</description>
        <protected>false</protected>
        <recipients>
            <recipient>db.wc@501commons.org</recipient>
            <type>user</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>Salesforce_Event_Scheduler/Admin_Setup_Appointments_Template</template>
    </alerts>
</Workflow>
