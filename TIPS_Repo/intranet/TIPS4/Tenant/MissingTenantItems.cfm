<!----------------------------------------------------------------------------------------------
| DESCRIPTION  :                                                                               |
|----------------------------------------------------------------------------------------------|
|   Displays the missing items of the residents according to project 20125 hard halts as a     |
|movein process to notify the AR analyst for the missing items of the already moved-in residents|
|----------------------------------------------------------------------------------------------|
| STORED PROCEDURES                                                                            |
|----------------------------------------------------------------------------------------------|
|  none                                                                                        |
|----------------------------------------------------------------------------------------------|
| INCLUDES                                                                                     |
|----------------------------------------------------------------------------------------------|
|   none                                                                                       |
|----------------------------------------------------------------------------------------------|
| HISTORY                                                                                      |
|----------------------------------------------------------------------------------------------|
| Author     | Date       | Description                                                        |
|------------|------------|--------------------------------------------------------------------|
| ssanipina  | 06/12/2008 | Added Flower box                                                   |
|Ssanipina     11/07/2008 | Did modification as per project 30178		                       |							
|sathya      | 09/09/2010 | Project 60038 sathya modified it for contract management which     |
|                           was renamed as Care management later                               |
|sfarmer     | 09/28/2015 | replaced care management with Move-In Summary                      |
|M Shah 	 | 07/25/2016 | commented for missing item as bond paperwork                       |
----------------------------------------------------------------------------------------------->
	<cfquery  name="qHouse" datasource="#application.DataSource#">
		select  *
		from House H 
		join HouseLog HL  on (H.iHouse_ID = HL.iHouse_ID and HL.dtRowDeleted is null and H.dtRowDeleted is null)
		where H.iHouse_ID = #url.HouseID#
	</cfquery>

	<cfscript>
		CalcHouse = qhouse.cNumber - 1800;
		if (Len(CalcHouse) eq 2) { HouseNumber = '0' & CalcHouse; }
		else if (Len(CalcHouse) eq 1) { HouseNumber = '0' & '0' & CalcHouse; }
		else { HouseNumber = '#CalcHouse#'; }

   		session.qSelectedHouse = qHouse;
		session.HouseName = qhouse.cName;
		session.HouseNumber = '#HouseNumber#';
		session.nHouse = qhouse.cNumber;
		session.TIPSMonth = qhouse.dtCurrentTipsMonth;
		session.cSLevelTypeSet = qhouse.cSLevelTypeSet;
		session.HouseClosed	= qhouse.bIsPDclosed;
		session.cDepositTypeSet	= qHouse.cDepositTypeSet;
		session.cBillingType = trim(qHouse.cBillingType);

		//renew user session variables to renew timeout period.
		if (isDefined("session.userid")) {session.userid=session.userid;}
		if (isDefined("session.fullname")) {session.fullname=session.fullname;}
	</cfscript>


<cfquery name="qResidentTenants" datasource="#application.datasource#" >
	select CASE LEN(ad.cAptNumber) 
				WHEN 1 THEN ('00' + ad.cAptNumber)
				WHEN 2 THEN ('0' + ad.cAptNumber) 
				ELSE ad.cAptNumber
			END as cAptNumber,
			t.iTenant_ID ,t.cFirstName ,t.cLastName,
			TPS.Cdescription as Promotions
	from AptAddress AD 
	join TenantState ts  on ad.iAptAddress_ID = ts.iAptAddress_ID 
		  and (ts.iTenantStateCode_ID is null or ts.iTenantStateCode_ID = 2 and ts.dtRowDeleted is null)
	join Tenant t  on (t.iTenant_ID = ts.iTenant_ID)
	left join TenantPromotionSet TPS on (ts.cTenantPromotion = TPS.iPromotion_ID)
	where	ad.dtRowDeleted is null
	and ad.iHouse_ID = #session.qSelectedHouse.ihouse_id#
	and t.dtRowDeleted is null
	order by len(ad.cAptNumber),ad.cAptNumber 
</cfquery>

<Table width="100%" align="center">
	<tr>
		<td style="color:red; font:20">
		<cfoutput>
			<a href="../MainMenu.cfm?SelectedHouse_ID=#session.qSelectedHouse.ihouse_id#">Click for TIPS Summary Screen
		</cfoutput>
		</td>
	</tr>
</table>

<TABLE width="100%" align="center">
    <TR><TH COLSPAN="3" align="center;" style="font:16;"><b> <CFOUTPUT> #qHouse.cname#</CFOUTPUT></b></TH></TR>
	<TR><TH COLSPAN="3" align="center;" style="font:16;"><b>TENANT MISSING ITEMS</b></TH></TR>
	<TR><TH COLSPAN="3" align="center;" style="color:red;font:12;">CLICK ON THE RESIDENT'S NAME TO ENTER MISSING INFORMATION </TH></TR>
</TABLE>

<TABLE border="1" width="100%" align="center">
	<TR><TH>APT NUMBER</TH><TH>RESIDENT</TH><TH>MISSING ITEMS</TH></TR>
	
<cfoutput query="qResidentTenants">
	<cfquery name="MissingItems" datasource="#application.datasource#">
		select distinct
		CASE WHEN len(isnull(t.cssn,1)) < 9 or len(isnull(t.cssn,1)) = 10 or len(isnull(t.cssn,1)) > 11 
			or (len(isnull(t.cssn,1)) = 9 and isnull(t.cssn,1) not LIKE '%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%')
			or (len(isnull(t.cssn,1)) = 11 
			and isnull(t.cssn,1) not LIKE '%[0-9][0-9][0-9][-/ ][0-9][0-9][-/ ][0-9][0-9][0-9][0-9]%')
				THEN 1 ELSE 0 end as SSN,
		CASE WHEN t.dbirthDate is null THEN 1 ELSE 0 end as DOB, 
		CASE WHEN t.cResidenceAgreement is null THEN 1 ELSE 0 end  as Residency_Agreement,			
		CASE WHEN isnull(lt2.bIsPayer,0) = 1 and lt2.bIsGuarantorAgreement is null  THEN 1 ELSE 0 end  Guarantor_Agreement,
		CASE WHEN isnull(ts.bMoveInSummary,0)= 0 THEN 1 ELSE 0 end as MoveIn_Summary
		from tenant t
		left join Tenantstate ts  on ts.iTenant_ID = t.iTenant_ID and ts.dtrowdeleted is null
		left join (select itenant_id,bIsGuarantorAgreement,bIsPayer from  LinkTenantContact 
					where itenant_id = #qResidentTenants.itenant_id# and bIsPayer = 1 and dtrowdeleted is null) lt2 on (lt2.Itenant_id = t.itenant_id ) 
		where t.itenant_id = #qResidentTenants.itenant_id#
		and t.dtrowdeleted is null
	</cfquery>
	
	<cfset DisplayString = ArrayNew(1)>
	<cfif MissingItems.SSN neq 0>
		<cfset temp = ArrayAppend(DisplayString, "SSN")>
	</cfif>
	
	<cfif MissingItems.DOB neq 0>
		<cfset temp = ArrayAppend(DisplayString, " DOB")>
	</cfif>

	<cfif MissingItems.Residency_Agreement neq 0>
		<cfset temp = ArrayAppend(DisplayString, " Residency Agreement")>
	</cfif>		
	<cfif MissingItems.Guarantor_Agreement neq 0>
		<cfset temp = ArrayAppend(DisplayString, " Contact Guarantor Agreement")>
	</cfif>
	<cfif MissingItems.MoveIn_Summary neq 0>
		<cfset temp = ArrayAppend(DisplayString, " Move In Summary")>
	</cfif>
	<cfif ArrayLen(DisplayString) neq 0>
		<cf_cttr colorOne="FFFFFF" colorTwo="EEEEEE">
			<td ALIGN="CENTER" style="font-weight"> #qResidentTenants.cAptNumber# </td>
			<td nowrap style="font-weight: bold;color:red;">
				<cfif qResidentTenants.itenant_id neq "" >
					<a href="TenantEdit.cfm?ID=#qResidentTenants.iTenant_ID#">#qResidentTenants.cLastName#, #qResidentTenants.cFirstName#</a>
				</cfif>
			</td>
			<td><b>#ArrayToList(DisplayString)#</b></td>
		</cf_ctTR>
	</cfif>
</cfoutput>
</TABLE>