<!----------------------------------------------------------------------------------------------
| DESCRIPTION                                                                                  |
|----------------------------------------------------------------------------------------------|
|                                                                                              |
|----------------------------------------------------------------------------------------------|
| STORED PROCEDURES                                                                            |
|----------------------------------------------------------------------------------------------|
|  none                                                                                        |
|----------------------------------------------------------------------------------------------|
| INCLUDES                                                                                     |
|----------------------------------------------------------------------------------------------|
|  none                                                                                        |
|----------------------------------------------------------------------------------------------|
| HISTORY                                                                                      |
|----------------------------------------------------------------------------------------------|
| Author     | Date       | Description                                                        |
|------------|------------|--------------------------------------------------------------------|
| pbuendia   | 02/07/2002 | Original Authorship This header created                            |
| pbuendia   | 03/28/2002 | As per new move in proceedures writing invoice total as solomon    |
|                         | balance plus move in invoice total.                                |
| ranklam    | 01/31/2006 | added flowerbox                                                    |
| ranklam    | 01/31/2006 | changed q_charge query to get by chargeset for all tenants         |
|MLAW        | 08/22/2006 | Make sure the charges are assigned to correct Product Line ID      |
|ssathya     |10/30/2008  | Added the condition to every query to check if the dtrowdeleted    |
|            |            |  was marked as deleted. SO that it doesnt pull the deleted records |
|            |            | as per project 29842                                               |
|rschuette   | 2/2/2010   | Project 35227 - AutoApply MI charges code added                    |
|sfarmer     | 2/22/2012  | Project 75019 - EFT Update/NRF Deferral. added changes for moveins |
|            |            | awaiting approval of NRF discount                                  |
|sfarmer     | 04/24/2012 | move in charges changed to check dtEffectiveEnd date. tckt 89924   |
|sfarmer     | 06/09/2012 | 75019 - NRF/Deferred Installation                                  |
|sfarmer     | 06/09/2012 | 75019 - Adjustments for 2nd opp, respite, Idaho                    | 
|sfarmer     | 04/17/2013 | 102919 - Adjustments discounted NRF approvals                      | 
|Sfarmer     | 09/18/2013 | 102919  - Revise NRF approval process                              |
 - --------------------------------------------------------------------------------------------|
| Sfarmer   | 10/18/2013  |Proj. 102481 removed Walnut db and tables Census & Leadtracking     |
| S Farmer  | 05/20/2014  | 116824 - Move-In update - Allow ED to adjust BSF rate              |
|S Farmer    | 05/20/2014 | 116824 - Phase 2 Allow different move-in and rent-effective dates  |
|            |            | allow respite to adjust BSF rates                                  |
|S Farmer    | 08/20/2014 | 116824 - back-off different move-in rent-effective dates           |
|            |            | allow adjustment of rates by all regions                           |
|S Farmer    | 09/08/2014 | 116824  Allow all houses edit BSF and Community Fee Rates          |
|S Farmer    | 2015-01-12 | 116824   Final Move-in Enhancements                                |
|S Farmer    | 2015-07-17 | Medicaid enhancements                                              |
|S Farmer    | 2015-07-31 | Updates for Pinicon Place with monthly charges                     |
----------------------------------------------------------------------------------------------->
 <cfif isDefined('form.iTenant_ID')>
 	<cfset variables.iTenant_ID = #form.iTenant_ID#>
	<cfset variables.MID  = #form.MID#>
<cfelseif isDefined('url.iTenant_ID')>
	<cfset variables.iTenant_ID = #url.iTenant_ID#>
	<cfset variables.MID  = #url.MID#>
</cfif>

<cfparam name="NrfDiscApprove" default="">
<cfparam name="approveremail" default="">
<cfparam name="name" default="">
<cfparam name="role" default="">
<cfparam name="IsSecondResident" default=""> 
<cfparam name="IsCompanion" default="">
<Cfparam name="IsMonthlyDeferralCharge" default="">
<cfparam name="iquant" default="">
<cfparam name="mamont" default="">
<cfparam name="irecurringID" default="">
<cfparam name="loadcount" default="0">
<cfparam name="RentAdded" default="">
<!--- <cfif IsDefined('Complete')> --->
	<CFQUERY NAME = "TenantInfo" DATASOURCE = "#APPLICATION.datasource#">
		SELECT	 (T.cFirstName + ' ' + T.cLastName) as FullName
			, t.csolomonkey,
			t.bispayer
			,ts.iTenantStateCode_ID
			,ts.iResidencyType_ID
			,ts.cSecDepCommFee,
			h.cName HouseName
			,TS.dtMoveIn
			,ts.dtrenteffective
			,ts.mMedicaidCopay  
			,HMed.MSTATEMEDICAIDAMT_BSF_DAILY
			,HMed.mMedicaidBSF
			,RT.cDescription
			,TS.bNRFPend
			,ts.iMonthsDeferred as PaymentMonths
			,ts.mBaseNrf as NRFBase
			,ts.mAdjNrf as NRFAdj	
			,t.ihouse_id	
			,TS.iAptAddress_ID 
			,t.cchargeset
			,t.itenant_id
			,ts.MADJNRF
			,ts.ispoints
			,ts.MBASENRF 
			,ts.IPRODUCTLINE_ID
			,t.CBILLINGTYPE
			,ts.mBSFDisc 
			,ts.mBSFOrig
			,ts.IMONTHSDEFERRED 
			,ad.IAPTTYPE_ID 
			,ts.MAMTDEFERRED 
		FROM	TENANT	T
		Join TenantState TS on T.itenant_id = TS.itenant_id
		JOIN 	House H on h.ihouse_id = T.ihouse_id
		JOIN 	AptAddress AD ON AD.iAptAddress_ID = TS.iAptAddress_ID
		JOIN 	ResidencyType RT ON RT.iResidencyType_ID = TS.iResidencyType_ID
		left join HouseMedicaid HMed on t.ihouse_id = HMed.ihouse_id
		WHERE	T.iTenant_ID = #variables.iTenant_ID#
	</CFQUERY>	
<!--- <cfoutput> <cfdump var="#TenantInfo#" label="TenantInfo"></cfoutput> --->

<!--- 	
<cfif  ((TenantInfo.mbasenrf is not '') and  (TenantInfo.mbasenrf is not 0) 
				and(TenantInfo.madjnrf lt TenantInfo.mbasenrf) and (TenantInfo.iResidencyType_ID is not 3))>
  ---> 
		<CFQUERY NAME="MovedInState" datasource = "#APPLICATION.datasource#">
			UPDATE	TenantState
				SET	
				  bNRFPend = null  
				,iNRFMid = #form.MID# 
				<!--- ,iTenantStateCode_ID = 2  ---> 
				,dtSPEvaluation = #CreateODBCDateTime(TenantInfo.dtMoveIn)# 
				,iRowStartUser_ID = #SESSION.UserID# 
				,dtRowStart = getdate() 		
				<!--- ,cNRFDiscAppUsername = '#form.Name#' --->	 
			WHERE	iTenant_ID = #variables.iTenant_ID#
		</CFQUERY>
		<!--- approveremail name role --->
<!---  		<cfoutput> 
		<cfif CGI.SERVER_NAME is "vmappprod01dev3" and IsDefined('approveremail') >
			TO: #approveremail# <br />
			From="Move-In@alcco.com"  <br />
			Subject="Move In Requires NRF Discount Approval"  <br />
			#TenantInfo.Fullname# of #TenantInfo.HouseName# requires approval of a discount of New Resident Fee.<br />
			Please approve at #TenantInfo.HouseName# TIPS Main Screen. <br />
			approval by: #approveremail# ,	 #name#,	#role#
			<br />
			<br />
			Thank You<br />
			#session.fullname# <br />  
	
		<cfelseif (SESSION.qSelectedHouse.iopsarea_ID is not 44)>
			<CFIF IsDefined('approveremail') and IsValid("email",approveremail)>
				<cfmail to="#approveremail#"  
					from="Move-In@alcco.com" subject="Move In Requires NRF Discount Approval">
						#TenantInfo.Fullname# of #TenantInfo.HouseName# requires approval of a discount of New Resident Fee.
						Please approve at #TenantInfo.HouseName# TIPS Main Screen.
				  
						Thank You, 
						#session.fullname#
				</cfmail>
			<cfelse>
				<cfmail to="CFDevelopers@alcco.com"  
					from="Move-In@alcco.com" subject="Email Error - Move In Requires NRF Discount Approval">
						Incomplete Email for:  #approveremail# ,	 #name#,	#role#
						Approval was being requested for:
						#TenantInfo.Fullname# of #TenantInfo.HouseName# requires approval of a discount of New Resident Fee.
						Please approve at #TenantInfo.HouseName# TIPS Main Screen.
				  
						Thank You, 
						#session.fullname#
				</cfmail>		
			</CFIF>
		</cfif>
	<cfif IsDefined('approveremail') >	Email has been sent to: #approveremail# <br /></cfif>
		</cfoutput> 
	</cfif>  --->
	<cfif  (IsSecondResident is 'Yes')>
  		<CFQUERY NAME="MovedInState" datasource = "#APPLICATION.datasource#">
			UPDATE	TenantState
				SET	bNRFPend = null 
				 ,cNRFDiscAppUsername = 'Second Resident' 	 
			WHERE	iTenant_ID = #variables.iTenant_ID#
		</CFQUERY>
	</cfif> 
 
	<!--- ==============================================================================
	Set variable for timestamp to record corresponding times for transactions
	=============================================================================== --->
	<CFQUERY NAME="GetDate" DATASOURCE="#APPLICATION.datasource#">
		SELECT getDate() as Stamp
	</CFQUERY>
	<CFSET TimeStamp = TRIM(GetDate.Stamp)>
	 
	
	<!--- ==============================================================================
	Check TipsMonth Correspondence
	=============================================================================== --->
	<CFQUERY NAME="qTipsMonth" DATASOURCE='#APPLICATION.datasource#'>
		select * from houselog where dtrowdeleted is null and ihouse_id = #SESSION.qSelectedHouse.iHouse_id#
	</CFQUERY>
	<CFIF CreateODBCDateTime(qTipsMonth.dtCurrentTipsMonth) NEQ CreateODBCDateTime(SESSION.TipsMonth)>
		<CENTER>
			<STRONG STYLE='color:navy;font-size:medium;'>
				Changes have been detected for this facility.<BR>
				You will be allowed to re-enter this process on the next page.<BR>
				<A HREF='../Registration/Registration.cfm'>Click Here to Continue</A>
			</STRONG>
		</CENTER>
		<CFABORT>
	</CFIF>
<cfif session.tipsmonth is ''>
 <cfset session.tipsmonth = '#houselog.dtCurrentTipsMonth#'>
</cfif>
<!--- ==============================================================================
Retrieve this Tenants Information
=============================================================================== --->




<!--- <CFIF ((TenantInfo.iTenantStateCode_ID EQ 2) and (TenantInfo.bNRFPend is ""))> --->
<CFIF  (TenantInfo.iTenantStateCode_ID EQ 2) >
	<CENTER>
	<STRONG STYLE='font-size: large; color: red;'>
	This tenant is already moved in.<BR>You will be redirected in 10 seconds.
	</STRONG>
	</CENTER>
	<SCRIPT> function redirect() { location.href='../MainMenu.cfm'; } setTimeout('redirect()',10000); </SCRIPT>
	<CFABORT>
</CFIF>


<!--- ==============================================================================
Retrieve the corresponding AREmail
=============================================================================== --->
<CFQUERY NAME="GetEmail" DATASOURCE="#APPLICATION.datasource#">
	SELECT	Du.EMail as AREmail
	FROM	House H
	JOIN 	#Application.AlcWebDBServer#.ALCWEB.dbo.employees DU
		ON H.iAcctUser_ID = DU.Employee_ndx
	WHERE	H.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
</CFQUERY>

<!--- ==============================================================================
Retrieve the Move In Invoice Master ID
=============================================================================== --->
	<CFQUERY NAME="MoveInInvoice" DATASOURCE="#APPLICATION.datasource#">
		SELECT	distinct IM.*
		FROM	invoiceMaster IM
		JOIN 	InvoiceDetail INV	ON (INV.iInvoiceMaster_ID = IM.iInvoiceMaster_ID
		 AND INV.dtRowDeleted IS NULL)
		WHERE	iTenant_ID = #variables.iTenant_ID#
		AND		IM.dtRowDeleted IS NULL
		AND		IM.bMoveInInvoice IS NOT NULL
		<CFIF IsDefined("variables.MID") AND variables.MID NEQ "">AND IM.iInvoiceMaster_ID = #variables.MID#</CFIF>
	</CFQUERY>
<!--- <cfdump var="#MoveInInvoice#"> --->
	<CFSCRIPT>
		if (MoveInInvoice.RecordCount GT 0 OR MoveInInvoice.iInvoiceMaster_ID EQ "")
		 { iInvoiceMaster_ID = MoveInInvoice.iInvoiceMaster_ID; }
	</CFSCRIPT>

	<cfif TenantInfo.iResidencyType_ID EQ 2>
		<cfquery name="qryHouseMedicaid" datasource="#application.datasource#">
			select * from HouseMedicaid where ihouse_id = #tenantinfo.ihouse_id#
		</cfquery>
	</cfif>
	
 
	<CFQUERY NAME='qMIDetails' DATASOURCE='#APPLICATION.datasource#'> 
		select *
		, inv.cdescription
		, inv.cappliestoacctperiod as moveinacctperiod
		,inv.mamount as invdetailamt
		from invoicemaster im
		join invoicedetail inv on inv.iinvoicemaster_id = im.iinvoicemaster_id 
				and inv.dtrowdeleted is null 
				and im.dtrowdeleted is null
		join chargetype ct on ct.ichargetype_id = inv.ichargetype_id 
				and ct.dtrowdeleted is null 
				and ((ct.bisrent is not null ) or (inv.ichargetype_id = 8))<!--- and ct.bisrent is not null ---> 
				and bSLevelType_ID is null
		where im.iinvoicemaster_id = #MoveInInvoice.iinvoicemaster_id#
		and	inv.cappliestoacctperiod = '#DateFormat(TenantInfo.dtRentEffective,"yyyymm")#'
	</CFQUERY>
<!--- <cfoutput><cfdump var="#qMIDetails#" label="qMIDetails"></cfoutput> --->

<!--- check if companion bye room description --->
<cfquery name="qryCompanion" DBTYPE='QUERY'>
	select cdescription from qMIDetails where ichargetype_id in (7,89,1682, 1748)
</cfquery>

<cfif FindNoCase('Companion Studio', qryCompanion.cdescription,1) gt 0>
	<cfset IsCompanion = 'Yes'>
<cfelse>
	<cfset IsCompanion = 'No'>
</cfif>

<cfquery name="qryMoveInAcctPeriod" DBTYPE='QUERY'>
select moveinacctperiod from qMIDetails where ichargetype_id in (7,89,1682,1748)
</cfquery>
<CFTRANSACTION>

<CFQUERY NAME="RoomOccupancyLog" DATASOURCE = "#APPLICATION.datasource#">
	SELECT top 1 itenant_id
	FROM AptLog 
	WHERE iAptAddress_ID = #TenantInfo.iAptAddress_ID# 
	AND dtRowDeleted IS NULL
	order by dtrowstart desc
</CFQUERY>

<cfif RoomOccupancyLog.itenant_id is not ''>
<cfquery name="RoomOccupancy" DATASOURCE = "#APPLICATION.datasource#">
select ts.dtmoveout, ts.dtmovein, ts.itenant_id
 from tenantstate ts
where ts.itenant_id = #RoomOccupancyLog.itenant_id#
</cfquery>
</cfif>

<CFLOOP QUERY='qMIDetails'>
	<CFQUERY NAME='qChargeID' DATASOURCE="#APPLICATION.datasource#">
		select
			*
		from
			charges
		where
			dtrowdeleted is null
		and getdate() between  dteffectivestart and  dteffectiveend	
		and ichargetype_id = #qMIDetails.iChargetype_ID#
		and ihouse_id = #SESSION.qSelectedHouse.iHouse_ID#
	 	<!--- and mamount = #qMIDetails.mAmount#  --->
		and cchargeset 
		<CFIF TenantInfo.cChargeSet NEQ "">
			= '#TenantInfo.cChargeSet#'
		<CFELSE>
			IS NULL
		</CFIF>
		and cdescription like 
			<CFIF listlen(qMIDetails.cDescription,":") gt 1>
				'%#trim(listgetat(qMIDetails.cDescription,2,":"))#%'
			<CFELSE>
				'#qMIDetails.cDescription#'
			</CFIF>
	</CFQUERY>
	<!---  and cdescription = '#qMIDetails.cDescription#' --->
	<!--- <br /><cfoutput><cfdump var="#qChargeID#" label="qChargeID"></cfoutput> --->
	<CFIF qChargeID.recordcount GT 0 AND len(qChargeID.cDescription) GT 0
	 and tenantinfo.iresidencytype_id neq 3>
		Inserting RandB same as house rate<BR>
		<br />
		<cfoutput>
			HERE::	#TenantInfo.iTenant_id# ,#qChargeID.iCharge_ID# 
			,getdate() ,DateAdd("yyyy",10,getdate()) ,1 
			,'#TRIM(qChargeID.cDescription)#' ,#qChargeID.mAmount#,
			'Recurring created at move in' ,#CreateODBCDateTime(SESSION.AcctStamp)# 
			,#SESSION.USERID# ,getdate()
		</cfoutput>
		<br />
 	
 		<cfif  ((qMIDetails.iChargeType_ID is "89") and (qMIDetails.iChargeType_ID is "31")
		and (qMIDetails.iChargeType_ID is "8") and (qMIDetails.iChargeType_ID is "1661")
		and (qMIDetails.iChargeType_ID is "1682"))>
			<br />inside #qMIDetails.iChargeType_ID#<br />
			<cfquery name="qryRoomRate" DATASOURCE='#APPLICATION.datasource#'>
				select inv.mamount from invoicemaster im 
					join invoicedetail inv on im.iInvoiceMaster_ID = inv.iInvoiceMaster_ID
				where csolomonkey  = '#TenantInfo.cSolomonKey#' 
					and im.bMoveInInvoice = 1
					and im.dtrowdeleted is null 
					and inv.dtrowdeleted is null 
					and inv.iChargeType_ID in (31, 89)
			</cfquery>
			  <br />
			  qInsertRecurring:: <cfoutput> #qChargeID.iCharge_ID#  #qryRoomRate.mAmount#</cfoutput>
			  <br />
			<CFQUERY NAME='qInsertRecurring' DATASOURCE='#APPLICATION.datasource#'>
				INSERT INTO RecurringCharge
				( iTenant_ID
				, iCharge_ID
				, dtEffectiveStart
				, dtEffectiveEnd
				, iQuantity
				, cDescription
				, mAmount
				, cComments
				, dtAcctStamp
				, iRowStartUser_ID
				, dtRowStart)
				VALUES
				( #TenantInfo.iTenant_id# 
					,#qChargeID.iCharge_ID# 
					,getdate() 
					,DateAdd("yyyy",10,getdate()) 
					,1 
					,'#TRIM(qChargeID.cDescription)#'
					,<cfif (qChargeID.ichargetype_id is 89)>
						<cfif (TenantInfo.mBSFDisc gte 0) >
							#TenantInfo.mBSFDisc#
						<cfelse>
							#qryRoomRate.mAmount#
						</cfif>
					<cfelseif (qChargeID.ichargetype_id is 31) >
						#qryHouseMedicaid.mMedicaidBSF#
					<cfelseif   (qChargeID.ichargetype_id is 8)> 
						#tenantinfo.mStateMedicaidAmt_BSF_Daily#
					<cfelseif (qChargeID.ichargetype_id is 1661)>
						#tenantinfo.mMedicaidCopay#
					<cfelse>
						#qryRoomRate.mAmount#
					</cfif>
					,'Recurring created at move in' 
					,#CreateODBCDateTime(SESSION.AcctStamp)#
					,#SESSION.USERID# ,getdate() )
			</CFQUERY>
		<cfelse>
			<br />second  
			<cfoutput>
			#qChargeID.iCharge_ID#  #qChargeID.mAmount#
			</cfoutput>
			<br />
			<CFQUERY NAME='qInsertRecurring' DATASOURCE='#APPLICATION.datasource#'>
				INSERT INTO RecurringCharge
				( iTenant_ID
				, iCharge_ID
				, dtEffectiveStart
				, dtEffectiveEnd
				, iQuantity
				, cDescription
				, mAmount
				, cComments
				, dtAcctStamp
				, iRowStartUser_ID
				, dtRowStart)
				VALUES
				( #TenantInfo.iTenant_id# 
				,#qChargeID.iCharge_ID# 
				,getdate() 
				,DateAdd("yyyy",10,getdate()) 
				,1 
				,'#TRIM(qChargeID.cDescription)#' 
				,<cfif ((qChargeID.ichargetype_id is 89) and (tenantinfo.mBSFDisc gte 0))>
					#tenantinfo.mBSFDisc#
					<cfelseif (qChargeID.ichargetype_id is 31) >
						#qryHouseMedicaid.mMedicaidBSF#
					<cfelseif   (qChargeID.ichargetype_id is 8)>
						#tenantinfo.MSTATEMEDICAIDAMT_BSF_DAILY#
					<cfelseif (qChargeID.ichargetype_id is 1661)>
						#tenantinfo.mMedicaidCopay#
				<cfelse>
					#qChargeID.mAmount#
				</cfif>
				,'Recurring created at move in' 
				,#CreateODBCDateTime(SESSION.AcctStamp)# 
				,#SESSION.USERID# ,getdate() )
			</CFQUERY>
		</cfif>
	<cfelse>Not found in charges, going to look for chargetype 89 and description longer than NULL<BR>
		<!--- possibility that there is a recurring charge for R&B but that it differs from the House Rate (found in Charges) because of the new ability to update the R&B rate in the Move In Credits screen. Added by Katie on 11/4/03 --->
		<cfif qMIDetails.iChargeType_ID is "89" AND len(qMIDetails.cDescription) GT 0>
		Inserting BSF - differs from house rate<BR>
<!--- 			<CFQUERY NAME='qChargeID' DATASOURCE="#APPLICATION.datasource#">
				select
					*
				from
					charges
				where
					dtrowdeleted is null
				and
					ichargetype_id = #qMIDetails.iChargetype_ID#
				and
					ihouse_id = #SESSION.qSelectedHouse.iHouse_ID#
				and
					cchargeset <cfif TenantInfo.cChargeSet neq "">= '#TenantInfo.cChargeSet#'<cfelse>is null</cfif>
				and
					cdescription like <cfif listlen(qMIDetails.cDescription,":") gt 1> '%#trim(listgetat(qMIDetails.cDescription,2,":"))#%'
															<cfelse>'#trim(qMIDetails.cDescription)#'</cfif>
			</CFQUERY> --->
<!--- ==============================================================================
Check how many occupants are currently in this room
Which determines occupancy
=============================================================================== --->
<cfif IsDefined('RoomOccupancy.RecordCount')> 
	<cfif ((RoomOccupancy.dtmovein IS NOT '') and (RoomOccupancy.dtmoveout is ''))>
		<cfset IsSecondResident = 'yes'>
		<br />
		<cfoutput>
			RoomOccupancy :: #RoomOccupancy.itenant_id#
			#RoomOccupancy.dtmovein# 
			#RoomOccupancy.dtmoveout# ::
			IsSecondResident: #IsSecondResident#
		</cfoutput>
		<br />
	
		<CFQUERY NAME='qChargeID' DATASOURCE="#APPLICATION.datasource#">			
			select 	t.csolomonkey, t.cfirstname, t.clastname
			, t.itenant_id,	ts.mBSFDisc, ts.mBSFORig 
			, t.ihouse_id
			,aa.captnumber
			, aa.iapttype_id
			, aa.ihouse_id
			,chg.ihouse_id
			, chg.cdescription, chg.mamount
			, chg.iapttype_id, chg.iCharge_ID, chg.ichargetype_id
			from tenant t
			join tenantstate ts on t.itenant_id  = ts.itenant_id
			join dbo.AptAddress aa on ts.iAptAddress_ID = aa.iAptAddress_ID
			join charges chg on chg.ihouse_id = t.ihouse_id
			where
			chg.dtrowdeleted is null
			and 	chg.ichargetype_id = 89
			and 	chg.ihouse_id = t.ihouse_id
			and 	chg.cchargeset = t.cchargeset
			and  	t.csolomonkey =  '#TenantInfo.cSolomonKey#'
			and 	chg.iOccupancyPosition = 2
		</CFQUERY>	
	<cfelse>RoomOccupancy.RecordCount = 1<br />
		<CFQUERY NAME='qChargeID' DATASOURCE="#APPLICATION.datasource#">			
			select 	t.csolomonkey, t.cfirstname, t.clastname
			, t.itenant_id,	ts.mBSFDisc, ts.mBSFORig , t.ihouse_id
			,aa.captnumber, aa.iapttype_id, aa.ihouse_id
			,chg.ihouse_id, chg.cdescription, chg.mamount
			, chg.iapttype_id, chg.iCharge_ID, chg.ichargetype_id
			from tenant t
			join tenantstate ts on t.itenant_id  = ts.itenant_id
			join dbo.AptAddress aa on ts.iAptAddress_ID = aa.iAptAddress_ID
			join charges chg on chg.iAptType_ID = aa.iAptType_ID
			where
			chg.dtrowdeleted is null
			and 	chg.ichargetype_id = 89
			and 	chg.ihouse_id = t.ihouse_id
			and 	chg.cchargeset = t.cchargeset
			and  	t.csolomonkey =  '#TenantInfo.cSolomonKey#'
		</CFQUERY>	
	</cfif>	
<cfelse>
		<CFQUERY NAME='qChargeID' DATASOURCE="#APPLICATION.datasource#">			
			select 	t.csolomonkey, t.cfirstname, t.clastname
			, t.itenant_id,	ts.mBSFDisc, ts.mBSFORig 
			, t.ihouse_id
			,aa.captnumber
			, aa.iapttype_id
			, aa.ihouse_id
			,chg.ihouse_id
			, chg.cdescription, chg.mamount
			, chg.iapttype_id, chg.iCharge_ID, chg.ichargetype_id
			from tenant t
			join tenantstate ts on t.itenant_id  = ts.itenant_id
			join dbo.AptAddress aa on ts.iAptAddress_ID = aa.iAptAddress_ID
			join charges chg on chg.ihouse_id = t.ihouse_id
			where
			chg.dtrowdeleted is null
			and 	chg.ichargetype_id = 89
			and 	chg.ihouse_id = t.ihouse_id
			and 	chg.cchargeset = t.cchargeset
			and  	t.csolomonkey =  '#TenantInfo.cSolomonKey#'
			and 	chg.iOccupancyPosition = 2
		</CFQUERY>	
</cfif>
	
			<br />	third  
			<cfoutput>
				#qChargeID.iCharge_ID#  #qChargeID.mAmount# Disc: #qChargeID.mBSFDisc#
			</cfoutput> 	
			<CFQUERY NAME='qInsertRecurring' DATASOURCE='#APPLICATION.datasource#'>
				INSERT INTO RecurringCharge
				( iTenant_ID
				, iCharge_ID
				, dtEffectiveStart
				, dtEffectiveEnd
				, iQuantity
				, cDescription
				, mAmount
				, cComments
				, dtAcctStamp
				, iRowStartUser_ID
				, dtRowStart)
				VALUES
				( #qMIDetails.iTenant_id# 
					,#qChargeID.iCharge_ID# 
					,getdate() 
					,DateAdd("yyyy",10,getdate()) 
					,1 
					,'#TRIM(qChargeID.cDescription)#' 
					,<cfif ((tenantinfo.mBSFDisc gte 0) and (qChargeID.ichargetype_id is 89))>
						#tenantinfo.mBSFDisc#
					<cfelse> 
						#qChargeID.mAmount#
					</cfif>
					,'Recurring created at move in' 
					,#CreateODBCDateTime(SESSION.AcctStamp)# 
					,#SESSION.USERID# 
					,getdate() )
			</CFQUERY>
		<cfelse>
		none found<br />
		</cfif>
	</CFIF>
	<br />
	<cfoutput>
	Loop: #qMIDetails.iChargetype_ID# :: 
	 #qMIDetails.iinvoicemaster_id# :: 
	  #qMIDetails.iinvoicedetail_id#<br />
	</cfoutput>
</CFLOOP>



<!--- ==============================================================================
Change the Tenant State to Moved In. (dbo.TENANTSTATE)
=============================================================================== --->
<CFQUERY NAME="MovedInState" datasource = "#APPLICATION.datasource#">
	UPDATE	TenantState
	SET		iTenantStateCode_ID = 2,
			dtSPEvaluation = #CreateODBCDateTime(TenantInfo.dtMoveIn)#,
			<CFIF TenantInfo.iTenantStateCode_ID EQ 4> dtMoveOut = NULL, </CFIF>
			iRowStartUser_ID = #SESSION.UserID#,
			dtRowStart = getdate()
<!--- 			<cfif TenantInfo.bNRFPend eq 1>
				,bNRFPend = null
				,cNRFAdjApprovedBy = '#session.username#'
				,dtNRFAdjApproved = getdate()
			</cfif> --->
	WHERE	iTenant_ID = #variables.iTenant_ID#
</CFQUERY>



<!--- ==============================================================================
Create an Apartment Log entry. (dbo.APTLOG)
=============================================================================== --->
<CFQUERY NAME = "AptLogEntry" DATASOURCE = "#APPLICATION.datasource#">
	INSERT INTO	AptLog
	( iTenant_ID
	, iAptAddress_ID
	, cAppliesToAcctPeriod
	, dtActualEffective
	, cComments
	, iRoomOccupancy
	, dtAcctStamp
	  , iRowStartUser_ID
	  , dtRowStart)
	 VALUES
	 ( #TenantInfo.iTenant_ID# 
	 	,#TenantInfo.iAptAddress_ID#
		<CFSET cAppliesToAcctPeriod = Year(SESSION.AcctStamp) & DateFormat(SESSION.AcctStamp, "mm")>
		,'#Variables.cAppliesToAcctPeriod#' 
		,NULL 
		,NULL 
		,<cfif Isdefined('RoomOccupancy.RecordCount')>#RoomOccupancy.RecordCount# <cfelse>1</cfif>
		,#CreateODBCDateTime(SESSION.AcctStamp)#
		 ,#SESSION.UserID#
		 , getdate() )
</CFQUERY>
<CFQUERY NAME = "FindOccupancy" DATASOURCE = "#APPLICATION.datasource#">
	SELECT	T.iTenant_ID, iResidencyType_ID, ST.cDescription as Level, TS.dtMoveIn, TS.dtMoveOut, TS.iSPoints
	FROM	AptAddress AD
	JOIN	TenantState TS	ON (TS.iAptAddress_ID = AD.iAptAddress_ID AND TS.dtRowDeleted IS NULL 
		AND TS.iTenant_ID <> #Tenantinfo.iTenant_ID#)
	JOIN	Tenant T		ON (T.iTenant_ID = TS.iTenant_ID AND T.dtRowDeleted IS NULL 
		AND	TS.iTenantStateCode_ID = 2 AND AD.iAptAddress_ID = TS.iAptAddress_ID)
	JOIN 	SLevelType ST	ON (ST.cSLevelTypeSet = T.cSLevelTypeSet AND TS.iSPoints between ST.iSPointsMin and ST.iSPointsMax)
	WHERE	AD.dtRowDeleted IS NULL
		AND		T.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
		AND		AD.iAptAddress_ID = #TenantInfo.iAptAddress_ID#
</CFQUERY>

<CFIF FindOccupancy.RecordCount GT 0> <CFSET Occupancy = 2> <CFELSE> <CFSET Occupancy = 1> </CFIF>

<!---   ============================================================================== --->
<cfoutput>Create an Activity Log entry (dbo.ACTIVITYLOG) ,#SESSION.UserID#</cfoutput><br />
<!--- ===============================================================================  --->
<CFQUERY NAME="ActivityLogEntry" DATASOURCE="#APPLICATION.datasource#">
	INSERT INTO ActivityLog
		( iActivity_ID
		, dtActualEffective
		, iTenant_ID
		, iHouse_ID
		, iAptAddress_ID
		, iSPoints
		,dtAcctStamp
		, iRowStartUser_ID
		, dtRowStart)
	VALUES
	( 2 
		,#CREATEODBCDateTime(TenantInfo.dtMoveIn)# 
		,#TenantInfo.iTenant_ID# 
		,#TenantInfo.iHouse_ID# 
		,#TenantInfo.iAptAddress_ID#
		,#TenantInfo.iSPoints# 
		,#CreateODBCDateTime(SESSION.AcctStamp)# 
		,#SESSION.UserID# ,getdate() 
	)
</CFQUERY>

<cfoutput>
<br />
Occupancy is #Occupancy#   <br />
tenantinfo.mAdjNrf::  #tenantinfo.mAdjNrf# <br />
tenantinfo.mBaseNrf :: #tenantinfo.mBaseNrf# <br />
IsCompanion :: #IsCompanion# <br />
tenantinfo.cSecDepCommFee is #tenantinfo.cSecDepCommFee#<br />
tenantinfo.iResidencyType_ID:: #tenantinfo.iResidencyType_ID#<br />
IsSecondResident:: #IsSecondResident#
<br />
</cfoutput>
	<cfset IsMonthlyDeferralCharge = 'N'>
<!--- <cfif ((((Occupancy is 1) and (tenantinfo.mAdjNrf gt 0)) 
	or ((Occupancy is 1) and (tenantinfo.mAdjNrf is '') and (tenantinfo.mBaseNrf gt 0) and (tenantinfo.iResidencyType_ID is not 3)) 
	or ((IsCompanion is 'Yes') and (tenantinfo.cSecDepCommFee is 'CF'))
	or (tenantinfo.iResidencyType_ID is not 3))
	and ((tenantinfo.cSecDepCommFee is not '2nd') or ((Occupancy is not 2) and (IsCompanion  is 'No') and (tenantinfo.iResidencyType_ID is 1)))
	)> --->
<cfif tenantinfo.cSecDepCommFee is '2nd' >
	<cfset IsMonthlyDeferralCharge = 'N'>
<cfelseif tenantinfo.iResidencyType_ID is 3 >
	<cfset IsMonthlyDeferralCharge = 'N'>
<cfelseif   (tenantinfo.cSecDepCommFee is 'SC') ><!--- security deposit have no deferral --->
	<cfset IsMonthlyDeferralCharge = 'N'>
<cfelseif ((Occupancy is 1) and (tenantinfo.mAdjNrf gt 0)) >
	<cfset IsMonthlyDeferralCharge = 'Y'>
<cfelseif  ((Occupancy is 1) and (tenantinfo.mAdjNrf is '') and (tenantinfo.mBaseNrf gt 0) and (tenantinfo.iResidencyType_ID is 1)) >
	<cfset IsMonthlyDeferralCharge = 'Y'>
<cfelseif  ((Occupancy is 2) and (IsCompanion is 'Yes') and ((tenantinfo.mAdjNrf gt 0) or (tenantinfo.mBaseNrf gt 0)))>
	<cfset IsMonthlyDeferralCharge = 'Y'>
<cfelseif   (tenantinfo.cSecDepCommFee is 'CF') >
	<cfset IsMonthlyDeferralCharge = 'Y'>
<cfelseif  (tenantinfo.iResidencyType_ID is 1) and  (tenantinfo.cSecDepCommFee is not '2nd') 
			and ((tenantinfo.mAdjNrf gt 0) or (tenantinfo.mBaseNrf gt 0))
			and (tenantinfo.mAdjNrf is not 0) 
			and ((Occupancy is not 2) and (IsCompanion  is 'No'))>
	<cfset IsMonthlyDeferralCharge = 'Y'>
</cfif>
		<cfoutput>
		Community Fee MoveIn Payment 2
		#Occupancy#
		#tenantinfo.cSecDepCommFee#
		#tenantinfo.iResidencyType_ID#
		#IsMonthlyDeferralCharge# 
		#tenantinfo.mAdjNrf#
		#tenantinfo.mBaseNRF#
		#tenantinfo.iResidencyType_ID#
		</cfoutput><br />
<cfoutput><br />IsMonthlyDeferralCharge: #IsMonthlyDeferralCharge#<br /></cfoutput>
 <cfif IsMonthlyDeferralCharge is 'N' >
  1=1
  <cfelseif tenantinfo.cSecDepCommFee is  '2nd'>
  1 = 1
  <cfelseif tenantinfo.iResidencyType_ID is   3>
  1 = 1
<cfelseif ((IsMonthlyDeferralCharge is 'Y') or 	((tenantinfo.mAdjNrf is '') and (tenantinfo.mBaseNRF gt 0))) >
		<CFQUERY NAME="InsertCFPayment" DATASOURCE="#APPLICATION.datasource#">
			INSERT INTO InvoiceDetail
			( iInvoiceMaster_ID 
			,iTenant_ID 
			,iChargeType_ID 
			,cAppliesToAcctPeriod 
			,bIsRentAdj 
			,dtTransaction 
			,iQuantity 
			,cDescription
			,mAmount 
			,cComments  
			,dtAcctStamp 
			,iRowStartUser_ID 
			,dtRowStart
			)
			VALUES(
				#MoveInInvoice.iInvoiceMaster_ID# 
				,#TenantInfo.iTenant_ID# 
				,1741
				,'#qryMoveInAcctPeriod.moveinacctperiod#'
				,	NULL 
				,getdate() 
				,1
				,'Monthly Deferral Charge' 
				,<cfif TenantInfo.iMonthsDeferred gt 1>
					#tenantinfo.mAmtDeferred#
				<cfelseif  tenantinfo.madjnrf gt 0>
					#tenantinfo.mAdjNrf#
				<cfelse>
					#tenantinfo.mBaseNRF#
				</cfif>
				,'Community Fee MoveIn Payment 2'
				,#CreateODBCDateTime(SESSION.AcctStamp)#
				,0 
				,getdate()
			)
		</CFQUERY>

		</cfif>
<CFOUTPUT>
	<!--- ==============================================================================
	Retrieve the total for this move in invoice
	=============================================================================== --->
	<CFQUERY NAME="InvoiceTotal" DATASOURCE="#APPLICATION.datasource#">
		SELECT	SUM(mAmount * iQuantity) as Total
		FROM	InvoiceDetail
		WHERE	iInvoiceMaster_ID = <CFIF MoveInInvoice.iInvoiceMaster_ID NEQ "">
			#MoveInInvoice.iInvoiceMaster_ID#
		 <CFELSEIF IsDefined("variables.MID")>
		  #variables.MID#
		  <CFELSE>
		  #Variables.iInvoiceMaster_ID#
		  </CFIF>
		AND		dtRowDeleted IS NULL
		AND		iTenant_ID = #variables.iTenant_ID#
		and ichargetype_id not in ( 8,69)
	</CFQUERY>

	<CFSCRIPT>
		if (IsDefined("InvoiceTotal.Total") AND InvoiceTotal.Total NEQ ""){ InvoiceTotal = InvoiceTotal.Total; } 
			else {InvoiceTotal = 0.00;}
	</CFSCRIPT>

	<!--- ==============================================================================
	Retrieve finalized invoice total regardless of type
	BY SOLOMONKEY ie for this account (Not for this person)
	=============================================================================== --->
	<CFQUERY NAME="qLastInvoiceTotal" DATASOURCE="#APPLICATION.datasource#">
		SELECT top 1 mLastInvoiceTotal, mInvoiceTotal, dtInvoiceEnd
		FROM InvoiceMaster
		WHERE csolomonkey = '#TenantInfo.cSolomonKey#'
		AND	bFinalized IS NOT NULL
		AND	iInvoiceMaster_ID <> 
			<CFIF MoveInInvoice.iInvoiceMaster_ID NEQ "">
				#MoveInInvoice.iInvoiceMaster_ID# 
			<CFELSEIF IsDefined("variables.MID")>
				 #variables.MID# 
			<CFELSE>
				#Variables.iInvoiceMaster_ID#
			</CFIF>
		<!---10/30/2008 Project 29842 ssathya added a condition to check dtrowdeleted is null --->
		AND dtrowdeleted is null
		ORDER BY 	cAppliesToAcctPeriod desc
	</CFQUERY>

	<!--- ==============================================================================
	get the solomon balance
	=============================================================================== --->
	<CFQUERY NAME="qSolbalance" DATASOURCE="#APPLICATION.datasource#">
		<CFIF SESSION.qSelectedHouse.iHouse_ID EQ 200>
			select -200.00 as bal
		<CFELSE>
			select isNull(SUM(amount),0) as BAL
			from rw.vw_Get_Trx
			where CUSTID = '#TenantInfo.cSolomonKey#' and RLSED = 1 and USER7 <= getdate()
			<cfif isDefined("qLastInvoiceTotal.dtInvoiceEnd") 
			and qLastInvoiceTotal.dtInvoiceEnd neq ''>
				and user7 >= #createodbcdatetime(qLastInvoiceTotal.dtInvoiceEnd)#
			</cfif>
		</CFIF>
	</CFQUERY>

	<!--- ==============================================================================
	If There is a last invoice total or the solomonbalance is existing
	=============================================================================== --->
	<CFSCRIPT>
		if (qLastInvoiceTotal.recordcount GT 0 
		AND qLastInvoiceTotal.mInvoiceTotal NEQ 0
		 AND qLastInvoiceTotal.mInvoiceTotal NEQ "")
		 {LastInvoiceTotal = qLastInvoiceTotal.mInvoiceTotal; } else {LastInvoiceTotal = 0 ; }
		if (isDefined("qSolBalance.recordCount") AND qSolBalance.bal NEQ 0)
			{ SolBal = qSolBalance.bal; } 
		else 
			{ SolBal = 0; }
		CurrentMonthInvoiceTotal = InvoiceTotal + LastInvoiceTotal + SolBal;
	</CFSCRIPT>
</CFOUTPUT>

<!--- ==============================================================================
Finalize the Move In Invoice. (dbo.INVOICE HEADER)
mInvoiceTotal = #InvoiceTotal#,
=============================================================================== --->
<CFQUERY NAME="UpdateInvoiceHeader" DATASOURCE="#APPLICATION.datasource#">
	UPDATE 	InvoiceMaster
	SET		bFinalized = 1,
			<CFIF qLastInvoiceTotal.recordcount GT 0>
				dtInvoiceStart = '#qLastInvoiceTotal.dtInvoiceEnd#',
			</CFIF>
			<cfif TenantInfo.IResidencyType_id neq 3>
				<CFIF IsDefined('RoomOccupancy.RecordCount') and RoomOccupancy.RecordCount GTE 1>
					dtInvoiceEnd = (select 	min(statedtRowStart) as dtStateChange
					 from 	rw.vw_apt_History 
									where iTenant_ID = #variables.iTenant_ID# 
									and tendtRowDeleted is null 
									and statedtRowDeleted is null 
									and iTenantStateCode_ID =2),
				<CFELSEIF qLastInvoiceTotal.recordcount GT 0>
					dtInvoiceEnd = '#qLastInvoiceTotal.dtInvoiceEnd#',
				<CFELSE>
					dtInvoiceEnd = getdate(),
				</CFIF>
			</CFIF>
			mInvoiceTotal = #CurrentMonthInvoiceTotal#,
			iRowStartUser_ID = #SESSION.UserID#,
			dtRowStart = getdate()
	WHERE	cSolomonKey = '#TenantInfo.cSolomonKey#'
	AND		iInvoiceMaster_ID = 
		<CFIF MoveInInvoice.iInvoiceMaster_ID NEQ "">
			#MoveInInvoice.iInvoiceMaster_ID# 
		<CFELSEIF IsDefined("variables.MID")> 
			#variables.MID# 
		<CFELSE>
			#Variables.iInvoiceMaster_ID#
		</CFIF>
	<!---10/30/2008 Project 29842 ssathya added a condition to check dtrowdeleted is null --->
		AND dtrowdeleted is null
</CFQUERY>

<!--- ==============================================================================
Retrieve MoveIn invoice data
=============================================================================== --->
<CFQUERY NAME="MoveInInfo" DATASOURCE="#APPLICATION.datasource#">
	select * from InvoiceMaster
	where iInvoiceMaster_ID = 
		<CFIF MoveInInvoice.iInvoiceMaster_ID NEQ "">
			#MoveInInvoice.iInvoiceMaster_ID#
		<CFELSE>
			#variables.MID#
		</CFIF>
	<!---10/30/2008 Project 29842 ssathya added a condition to check dtrowdeleted is null --->
		AND dtrowdeleted is null
</CFQUERY>

<!--- ==============================================================================
Check InvoiceMaster for Existing NON-Move In Invoice for this cSolomonKey
=============================================================================== --->
<CFQUERY NAME = "InvoiceCheck" DATASOURCE = "#APPLICATION.datasource#">
	select *
	FROM	InvoiceMaster IM
	JOIN	InvoiceDetail INV	ON IM.iInvoiceMaster_ID = INV.iInvoiceMaster_ID
	WHERE	cSolomonKey = '#TenantInfo.cSolomonKey#'
	AND		bMoveOutInvoice IS NULL AND	bMoveInInvoice IS NULL
	AND		bFinalized IS NULL
	AND		IM.dtRowDeleted IS NULL
	AND		INV.dtRowDeleted IS NULL
</CFQUERY>

<CFQUERY NAME='qMonthlyCheck' DATASOURCE='#APPLICATION.datasource#'>
	SELECT  iInvoiceMaster_ID
	FROM 	InvoiceMaster
	WHERE 	dtRowDeleted IS NULL
	AND 	cSolomonKey = '#TenantInfo.cSolomonKey#'
	AND		bMoveInInvoice IS NULL AND bMoveOutInvoice IS NULL AND bFinalized IS NULL
</CFQUERY>

<!--- ==============================================================================
If there no available Monthly invoice.
We get the next number from house number control and update the invoice master table
=============================================================================== --->
<cfif TenantInfo.iresidencyType_id neq 3>
	<br />
	<cfoutput>
		whoa i'm am here GetNextInvoice TenantInfo.iresidencyType_id  #TenantInfo.iresidencyType_id#
	</cfoutput>
	<CFIF InvoiceCheck.RecordCount EQ 0 OR qMonthlyCheck.RecordCount EQ 0>
	
		<CFQUERY NAME = "GetNextInvoice" DATASOURCE = "#APPLICATION.datasource#">
			SELECT	iNextInvoice
			FROM	HouseNumberControl
			WHERE	iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
			AND		dtRowDeleted IS NULL
		</CFQUERY>
	
		<CFSCRIPT>
			HouseNumber = SESSION.HouseNumber;
			iInvoiceNumber = '#Variables.HouseNumber#' & GetNextInvoice.iNextInvoice;
			cAppliesToAcctPeriod = DateFormat(SESSION.TipsMonth,"yyyymm");
			//if (TenantInfo.bNextMonthsRent GT 0) { cAppliesToAcctPeriod = DateFormat(DateAdd("m",1,SESSION.TIPSMonth),"yyyymm"); }
			//else { cAppliesToAcctPeriod = DateFormat(SESSION.TipsMonth,"yyyymm"); }
		</CFSCRIPT>
	
		<!--- ==============================================================================
		Create new Monthly Invoice For this Tenant
		=============================================================================== --->
<!--- /*******************************************************************************************************/ --->
		<CFQUERY NAME = "NewInvoice" DATASOURCE = "#APPLICATION.datasource#">
			Declare @end datetime
			set @end = (Select dtInvoiceEnd FROM InvoiceMaster 
			WHERE iInvoicemaster_ID = #MoveInInfo.iInvoiceMaster_ID#)
			INSERT INTO InvoiceMaster
			( iInvoiceNumber ,cSolomonKey ,bMoveInInvoice ,bFinalized 
			,cAppliesToAcctPeriod ,cComments ,dtInvoiceStart
			 ,mLastInvoiceTotal ,dtAcctStamp ,iRowStartUser_ID ,dtRowStart )
			VALUES
			( '#Variables.iInvoiceNumber#' ,'#TenantInfo.cSolomonKey#' 
			
			,NULL ,NULL ,'#cAppliesToAcctPeriod#' ,NULL
				,<CFIF MoveInInfo.dtInvoiceEnd NEQ "">
					 @end 
				<CFELSE>
				 getdate() 
				</CFIF>
				,#MoveInInfo.mInvoiceTotal# ,#CreateODBCDateTime(SESSION.AcctStamp)# ,-1 ,getdate()
			)
		</CFQUERY>
	
		<CFSET iNewNextInvoice = GetNextInvoice.iNextInvoice + 1>
	
		<CFQUERY NAME = "HouseNumberControl" DATASOURCE = "#APPLICATION.datasource#">
			UPDATE	HouseNumberControl
			SET		iNextInvoice 	= #Variables.iNewNextInvoice#
			WHERE	iHouse_ID 		= #SESSION.qSelectedHouse.iHouse_ID#
			AND		dtRowDeleted IS NULL
		</CFQUERY>
	
		<CFQUERY NAME = "NewMasterID" DATASOURCE = "#APPLICATION.datasource#">
			SELECT	iInvoiceMaster_ID
			FROM	InvoiceMaster
			WHERE	cSolomonKey = '#TenantInfo.cSolomonKey#'
			AND		bMoveInInvoice IS NULL AND bFinalized IS NULL
			<!---10/30/2008 Project 29842 ssathya added a condition to check dtrowdeleted is null --->
			AND dtrowdeleted is null
		</CFQUERY>
	
		<CFSET Variables.iInvoiceMaster_ID = NewMasterID.iInvoiceMaster_ID>
	<cfoutput><br />A. Variables.iInvoiceMaster_ID #Variables.iInvoiceMaster_ID#<br /></cfoutput>
	<CFELSE>
		<br />	
			<cfoutput>otherwise i'm am here GetNextInvoice 
			TenantInfo.iresidencyType_id ::	 #TenantInfo.iresidencyType_id#
			</cfoutput>
		<CFSET iInvoiceMaster_ID = InvoiceCheck.iInvoiceMaster_ID>
		<CFSET iInvoiceNumber = '#InvoiceCheck.iInvoiceNumber#'>
		<!--- ==============================================================================
		Update current invoice with last finalized amount plus amount of this invoice
		=============================================================================== --->
		<CFQUERY NAME="qUpdateCurrentInvoice" DATASOURCE="#APPLICATION.datasource#">
			UPDATE	InvoiceMaster
			SET		mInvoiceTotal = #CurrentMonthInvoiceTotal#,
				<CFSET Comments = TRIM(InvoiceCheck.cComments) 
				& ' **Balance Forward Changed due to second tenant Move In.'>
					cComments = '#Comments#',
					dtRowStart = getdate(),
					iRowStartUser_ID = #SESSION.USERID#
			WHERE	iInvoiceMaster_ID = #InvoiceCheck.iInvoiceMaster_ID#
			<!---10/30/2008 Project 29842 ssathya added a condition to check dtrowdeleted is null --->
			AND dtrowdeleted is null
		</CFQUERY>		
	</CFIF>
</cfif>
<CFQUERY NAME='qHistSet' DATASOURCE="#APPLICATION.datasource#">
	SELECT	distinct tendtRowStart, cSLevelTypeSet, tendtRowEnd, tendtRowDeleted
	FROM	rw.vw_tenant_history_with_state
	WHERE	iTenant_ID = #TenantInfo.iTenant_ID#
	AND	'#TenantInfo.dtMoveIn#' between tenDtRowStart and tendtRowEnd
	ORDER BY tenDtRowStart desc
</CFQUERY>

<!--- ==============================================================================
Calculate ServiceLevel
=============================================================================== --->
<CFQUERY NAME = "SLevel" DATASOURCE = "#APPLICATION.datasource#">
	SELECT 	*
	FROM 	SLevelType
	WHERE	dtRowDeleted IS NULL
	AND		(iSPointsMin <= #TenantInfo.iSPoints# AND iSPointsMax >= #TenantInfo.iSPoints#)
	<CFIF qHistSet.RecordCount GT 0 AND qHistSet.cSLevelTypeSet NEQ ''>
		AND cSLevelTypeSet = #qHistSet.cSLevelTypeSet#
	<CFELSEIF IsDefined("TenantInfo.cSLevelTypeSet") AND TenantInfo.cSLevelTypeSet NEQ "" AND TenantInfo.cSLevelTypeSet NEQ 0>
		AND	cSLevelTypeSet	= #TenantInfo.cSLevelTypeSet#
	<CFELSE>
		AND cSLevelTypeSet	= #SESSION.cSLevelTypeSet#
	</CFIF>
</CFQUERY>
<!--- occupancy was here --->


<CFQUERY NAME="CheckCompanionFlag" DATASOURCE="#APPLICATION.datasource#">
	SELECT	bIsCompanionSuite
	FROM	AptAddress AD
	JOIN	AptType AT ON (AD.iAptType_ID = AT.iAptType_ID AND AT.dtRowDeleted is NULL)
	WHERE	AD.dtRowDeleted IS NULL
		AND		AD.iAptAddress_ID = #TenantInfo.iAptAddress_ID#
</CFQUERY>

<CFIF CheckCompanionFlag.bIsCompanionSuite EQ 1> <CFSET Occupancy = 1> </CFIF>

<!--- ==============================================================================
Do not Charge Standard Rent for Medicaid. TO be done by Acct. Rec.
=============================================================================== --->
<CFIF TenantInfo.iResidencyType_ID EQ 1 or TenantInfo.iResidencyType_ID EQ 2> <!--- was iResidencyType_ID EQ 1 ONLY sfarmer 3-9-15 --->
	<!--- ==============================================================================
	Create Rent InvoiceDetail
	=============================================================================== --->
	<!--- MLAW 08/22/2006 Add iProductline_ID filter --->
	<CFQUERY NAME = "StandardRent" DATASOURCE = "#APPLICATION.datasource#">
		<CFIF TenantInfo.iResidencyType_ID NEQ 2>
			<CFIF Occupancy EQ 1>
				SELECT	C.cDescription ,C.mAmount ,C.iQuantity ,CT.iChargeType_ID
				FROM	Charges C
				JOIN	ChargeType CT ON (CT.iChargeType_ID = C.iChargeType_ID
				 AND CT.dtRowDeleted IS NULL)
				WHERE	C.dtRowDeleted IS NULL
				AND	CT.bIsRent IS NOT NULL
				AND	CT.bIsDiscount IS NULL
				<!--- AND CT.bIsRentAdjustment IS NULL --->
				AND CT.bIsMedicaid IS NULL
				<!--- AND	CT.bAptType_ID IS NOT NULL --->
				<!--- AND	CT.bIsDaily IS NULL --->
				  AND	CT.bSLevelType_ID IS NULL 
				AND	C.iResidencyType_ID = #TenantInfo.iResidencyType_ID# 
				AND C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
				AND	C.iAptType_ID = #TenantInfo.iAptType_ID# AND C.iOccupancyPosition = 1
				AND	dtEffectiveStart <= #CreateODBCDateTime(TenantInfo.dtMoveIn)#
				AND dtEffectiveEnd >= #CreateODBCDateTime(TenantInfo.dtMoveIn)#
				AND C.iProductLine_ID = #TenantInfo.iProductLine_ID#
			<CFELSE>
				SELECT	C.cDescription ,C.mAmount ,C.iQuantity ,CT.iChargeType_ID
				FROM	Charges C
				JOIN	ChargeType CT ON (CT.iChargeType_ID = C.iChargeType_ID 
				AND CT.dtRowDeleted IS NULL)
				WHERE	C.dtRowDeleted IS NULL
				AND	CT.bIsRent IS NOT NULL
				AND	CT.bIsDiscount IS NULL
				<!--- AND CT.bIsRentAdjustment IS NULL --->
				AND CT.bIsMedicaid IS NULL
				<!--- AND	CT.bAptType_ID IS NOT NULL --->
				AND CT.bIsDaily IS NULL
				AND	CT.bSLevelType_ID IS NULL
			 	AND	C.iAptType_ID IS NULL 
				AND	C.iResidencyType_ID = #TenantInfo.iResidencyType_ID# AND C.iOccupancyPosition = 2
				AND	C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
				AND	dtEffectiveStart <= #CreateODBCDateTime(TenantInfo.dtMoveIn)#
				AND dtEffectiveEnd >= #CreateODBCDateTime(TenantInfo.dtMoveIn)#
				AND C.iProductLine_ID = #TenantInfo.iProductLine_ID#
			</CFIF>
		<CFELSE>
			SELECT	*
			FROM	InvoiceDetail INV
			JOIN 	InvoiceMaster IM	ON INV.iInvoiceMaster_ID = IM.iInvoiceMaster_ID
			JOIN 	ChargeType CT		ON CT.iChargeType_ID = INV.iChargeType_ID
			WHERE	INV.dtRowDeleted IS   NULL
			AND		IM.dtRowDeleted IS   NULL
			AND		IM.bMoveInInvoice IS NOT NULL
			AND		INV.iTenant_ID = #TenantInfo.iTenant_ID#
			AND		CT.bIsMedicaid IS NOT NULL
			AND		((CT.bIsRent IS NOT NULL) or (inv.ichargetype_id = 8)) 
			<!--- CT.bIsRent IS NOT NULL --->
		</CFIF>
	</CFQUERY>
 <cfoutput><cfdump var="#StandardRent#" label="StandardRent"></cfoutput> 
	<CFIF StandardRent.RecordCount EQ '0'>
	<br /> StandardRent2
		<!--- MLAW 08/22/2006 Add iProductline_ID filter --->
		<CFQUERY NAME = "StandardRent" DATASOURCE = "#APPLICATION.datasource#">
			SELECT	C.iChargeType_ID, C.iQuantity, C.cDescription, C.mAmount
			FROM	Charges	C
			JOIN 	ResidencyTYPE RT		ON	C.iResidencyType_ID = RT.iResidencyType_ID
			<!--- LEFT OUTER JOIN	SLevelType ST	ON	C.iSLevelType_ID = ST.iSLevelType_ID --->
			JOIN 	ChargeType CT			ON	CT.iChargeType_ID = C.iChargeType_ID
			WHERE	C.dtRowDeleted IS NULL
			AND CT.dtRowDeleted IS NULL
			AND	IsNull(C.iOccupancyPosition,1) = #Occupancy#
			<CFIF TenantInfo.cChargeSet NEQ ""> 
				AND	C.cChargeSet = '#TenantInfo.cChargeSet#' 
			<CFELSE> 
				AND C.cChargeSet IS NULL 
			</CFIF>
			<CFIF TenantInfo.iResidencyType_ID NEQ 3>
				<CFIF Occupancy NEQ 2> 
					AND C.iAptType_ID = #TenantInfo.iAptType_ID# 
				<CFELSE> 
					AND C.iAptType_ID IS NULL 
				</CFIF>
				<!--- AND		C.iSLevelType_ID = #SLevel.iSLevelType_ID# --->
				AND		CT.bIsDaily IS NULL
			</CFIF>
			AND		C.iResidencyType_ID = #TenantInfo.iResidencyType_ID#
			AND		C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
			AND (
				(iCharge_id = (select iCharge_id from rw.vw_Charges_history 
				where ihouse_id = #SESSION.qSelectedHouse.iHouse_ID# 
					AND '#TenantInfo.dtMovein#' between dtrowstart 
					and isNull(dtrowend,getdate())
					AND iChargeType_ID = C.iChargeType_ID 
					AND	iAptType_ID = C.iAptType_ID 
					AND cSLevelDescription = C.cSLevelDescription 
					<!--- AND iSLevelType_ID = #SLevel.iSLevelType_ID# ---> 
					and dtRowDeleted IS NULL)
				) OR  (dtEffectiveStart <= '#TenantInfo.dtMovein#' 
				AND dtEffectiveEnd >= '#TenantInfo.dtMovein#') )
			AND		C.iProductLine_ID = #TenantInfo.iProductLine_ID#
		</CFQUERY>
	</CFIF>

	<CFIF StandardRent.mAmount EQ "" AND TenantInfo.cBillingType NEQ 'D'>
		<CFOUTPUT>
			<br />The Standard Rate for this Type of Tenant is Missing!<BR>
			<A HREF="../Registration/Registration.cfm"> 
			Click Here to go back to the registration page.	</A>
		</CFOUTPUT>

		<CFMAIL TYPE ="HTML" FROM = "TIPS4-Message@alcco.com" TO = "#SESSION.AREmail#" 
			CC="CFDevelopers@enlivant.com" 
			SUBJECT = "Standard Rate Missing for #SESSION.HouseName#">
			#SESSION.FullName# has attempted a Move In, 
			however the Standard Rate for #SESSION.HouseName#,
			Tenant #TenantInfo.FullName#, #TenantInfo.iTenant_ID#
			Service Level #SLevel.cDescription#, <BR>
			and Apartment Type #TenantInfo.iAptType_ID#<BR>
			<BR>"#TenantInfo.cDescription#" is missing.<BR>
			#now()#(finalize) 
			<CFIF IsDefined("remote_addr")>#remote_addr#</CFIF>
			____________________________________________________<BR>
		</CFMAIL>
		<CFABORT>
	</CFIF>
	<!--- MLAW 08/22/2006 Add iProductline_ID filter --->
<!--- 	<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#">
 --->		
	<CFIF Occupancy EQ  1>
		<cfif tenantinfo.iresidencytype_id is not 2>DailyRent A
			<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#">
				SELECT	C.cDescription ,
				C.mAmount ,C.iQuantity ,CT.iChargeType_ID
				FROM	Charges C
				JOIN	ChargeType CT ON (CT.iChargeType_ID = C.iChargeType_ID AND CT.dtRowDeleted IS NULL)
				WHERE	C.dtRowDeleted IS NULL
				<CFIF TenantInfo.cChargeSet NEQ "" AND TenantInfo.iResidencyType_ID NEQ 3> 
					AND	C.cChargeSet = '#TenantInfo.cChargeSet#' 
				<CFELSE> 
					AND C.cChargeSet IS NULL 
				</CFIF>
				AND	CT.bIsRent IS NOT NULL
				AND	CT.bIsDiscount IS NULL AND CT.bIsRentAdjustment IS NULL AND CT.bIsMedicaid IS NULL
				<CFIF TenantInfo.iResidencyType_ID EQ 3>
					AND (C.iAptType_ID IS NULL OR C.iAptType_ID = #TenantInfo.iAptType_id#)
				<CFELSE>
					AND CT.bAptType_ID IS NOT NULL 
					AND CT.bIsDaily IS NOT NULL 
					<!--- AND	CT.bSLevelType_ID IS NULL --->
				</CFIF>
				AND	C.iResidencyType_ID = #TenantInfo.iResidencyType_ID#
				AND	C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
				AND	C.iAptType_ID = #TenantInfo.iAptType_ID#
				AND	C.iOccupancyPosition = 1
				AND	dtEffectiveStart <= '#TenantInfo.dtMovein#'
				AND dtEffectiveEnd >= '#TenantInfo.dtMovein#'
				<CFIF TenantInfo.cChargeSet NEQ '' AND TenantInfo.iResidencyType_ID NEQ 3>
					AND C.cChargeSet = '#TenantInfo.cChargeSet#'
				<CFELSE>
					AND C.cChargeSet IS NULL
				</CFIF>
				AND C.iProductLine_ID = #TenantInfo.iProductLine_ID#
				ORDER BY C.dtRowStart Desc
						</CFQUERY>
	<cfelse><!--- residency = 2 Medicaid --->DailyRent B
		<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#">
				SELECT	C.cDescription 
				,C.iChargeType_ID,
				case when ( C.iChargeType_ID = 1661)  
				then	#tenantinfo.mMedicaidCopay# 
				when (C.iChargeType_ID = 31)
					then #qryHouseMedicaid.mMedicaidBSF#
				else
					C.mAmount
				end mAmount
				  ,C.iQuantity 
				  ,CT.iChargeType_ID
				FROM	Charges C
				JOIN	ChargeType CT ON (CT.iChargeType_ID = C.iChargeType_ID AND CT.dtRowDeleted IS NULL)
				WHERE	C.dtRowDeleted IS NULL
					AND	CT.bIsRent IS NOT NULL
					AND	CT.bIsDiscount IS NULL 
					AND CT.bIsRentAdjustment IS NULL 
					<!--- AND	CT.bSLevelType_ID IS NULL --->
					AND	C.iResidencyType_ID = #TenantInfo.iResidencyType_ID#
					AND	C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
					<!--- AND	C.iOccupancyPosition = 1 --->
					AND	dtEffectiveStart <= '#TenantInfo.dtMovein#'
					AND dtEffectiveEnd >= '#TenantInfo.dtMovein#'
					AND C.cChargeSet = '#TenantInfo.cChargeSet#'
					
					AND C.iProductLine_ID = #TenantInfo.iProductLine_ID#
				ORDER BY C.dtRowStart Desc	
			</CFQUERY>		
	</cfif>
	<CFELSE>DailyRent D
		<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#">
			SELECT	C.cDescription ,
		  		<!---<cfif C.iChargeType_ID is 1661> #tenantinfo.mMedicaidCopay# 
				<cfelseif C.iChargeType_ID is 31>#qryHouseMedicaid.mMedicaidBSF#
				<cfelse>---> 
				C.mAmount
				<!---</cfif>--->
				,C.iQuantity ,CT.iChargeType_ID
			FROM	Charges C
			JOIN	ChargeType CT ON (CT.iChargeType_ID = C.iChargeType_ID 
			AND CT.dtRowDeleted IS NULL)
			WHERE	C.dtRowDeleted IS NULL
			<CFIF TenantInfo.cChargeSet NEQ "" AND TenantInfo.iResidencyType_ID NEQ 3> 
				AND	C.cChargeSet = '#TenantInfo.cChargeSet#' 
			<CFELSE> 
				AND C.cChargeSet IS NULL 
			</CFIF>
			AND	CT.bIsRent IS NOT NULL
			AND	CT.bIsDiscount IS NULL 
			AND CT.bIsRentAdjustment IS NULL 
			AND CT.bIsMedicaid IS NULL
			AND	CT.bAptType_ID IS NOT NULL 
			AND CT.bIsDaily IS NOT NULL 	
			<!--- AND	CT.bSLevelType_ID IS NULL --->
			<CFIF TenantInfo.iResidencyType_ID EQ 3>
				AND (C.iAptType_ID IS NULL OR C.iAptType_ID = #TenantInfo.iAptType_id#)
			<CFELSE>
				AND C.iAptType_ID IS NULL
			</CFIF>
			AND	C.iResidencyType_ID = #TenantInfo.iResidencyType_ID#
			AND	C.iOccupancyPosition = 2
			AND	C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
			AND	dtEffectiveStart <= '#TenantInfo.dtMovein#'
			AND dtEffectiveEnd >= '#TenantInfo.dtMovein#'
			<CFIF TenantInfo.cChargeSet NEQ '' AND TenantInfo.iResidencyType_ID NEQ 3>
				AND C.cChargeSet = '#TenantInfo.cChargeSet#'
			<CFELSE>
				AND C.cChargeSet IS NULL
			</CFIF>
			AND C.iProductLine_ID = #TenantInfo.iProductLine_ID#
			ORDER BY C.dtRowStart Desc
		</CFQUERY>
	</CFIF>
<!--- 	</CFQUERY> --->

	<CFIF DailyRent.RecordCount EQ 0 or DailyRent.mamount EQ 0>
		<!--- MLAW 08/22/2006 Add iProductline_ID filter --->
<!--- 		<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#"> --->
		<CFIF Occupancy EQ 1>DailyRent E
			<cfif tenantinfo.iresidencytype_id is not 2>
			<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#">
				SELECT	C.iChargeType_ID, C.iQuantity, C.cDescription, C.mAmount
				FROM	Charges	C
				JOIN 	ResidencyTYPE RT			ON C.iResidencyType_ID = RT.iResidencyType_ID
				LEFT OUTER JOIN	SLevelType ST	ON C.iSLevelType_ID = ST.iSLevelType_ID
				JOIN 	ChargeType CT				ON CT.iChargeType_ID = C.iChargeType_ID
				WHERE	C.dtRowDeleted IS NULL
				AND		CT.dtRowDeleted IS NULL
				<CFIF TenantInfo.cChargeSet NEQ ""> 
					AND	C.cChargeSet = '#TenantInfo.cChargeSet#' 
				<CFELSE> 
					AND C.cChargeSet IS NULL 
				</CFIF>
				<CFIF TenantInfo.iResidencyType_ID NEQ 3>
					AND		C.iAptType_ID = #TenantInfo.iAptType_ID#
					AND		C.iSLevelType_ID = #SLevel.iSLevelType_ID#
				</CFIF>
				AND		C.iResidencyType_ID = #TenantInfo.iResidencyType_ID#
				AND		C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
				AND		CT.bIsDaily IS NOT NULL
				AND		dtEffectiveStart <= '#TenantInfo.dtMovein#'
				AND		dtEffectiveEnd >= '#TenantInfo.dtMovein#'
				AND		C.iProductLine_ID = #TenantInfo.iProductLine_ID#
				ORDER BY C.dtRowstart desc
			</CFQUERY>
			<cfelseif tenantinfo.iresidencytype_id is  2>
				<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#">
					SELECT	C.iChargeType_ID
					, C.iQuantity
					, C.cDescription
					,case when ( C.iChargeType_ID =  1661) then
					  	#tenantinfo.mMedicaidCopay# 
					 when(  C.ichargeType_id = 31)
						then #qryHouseMedicaid.mMedicaidBSF#
						 else 
						 C.mAmount
					 end as mAmount
					FROM	Charges	C
					JOIN 	ResidencyTYPE RT		ON C.iResidencyType_ID = RT.iResidencyType_ID
					<!--- LEFT OUTER JOIN	SLevelType ST	ON C.iSLevelType_ID = ST.iSLevelType_ID --->
					JOIN 	ChargeType CT			ON CT.iChargeType_ID = C.iChargeType_ID
					WHERE	C.dtRowDeleted IS NULL
					AND		CT.dtRowDeleted IS NULL
					<CFIF TenantInfo.cChargeSet NEQ ""> 
						AND	C.cChargeSet = '#TenantInfo.cChargeSet#' 
					<CFELSE> 
						AND C.cChargeSet IS NULL 
					</CFIF>
					<!--- <CFIF TenantInfo.iResidencyType_ID NEQ 3>
						AND		C.iAptType_ID = #TenantInfo.iAptType_ID#
						AND		C.iSLevelType_ID = #SLevel.iSLevelType_ID#
					</CFIF> --->
					AND		C.iResidencyType_ID = #TenantInfo.iResidencyType_ID#
					AND		C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
					<!--- AND		CT.bIsDaily IS NOT NULL --->
					AND		dtEffectiveStart <= '#TenantInfo.dtMovein#'
					AND		dtEffectiveEnd >= '#TenantInfo.dtMovein#'
					AND		C.iProductLine_ID = #TenantInfo.iProductLine_ID#
					ORDER BY C.dtRowstart desc
				</CFQUERY>			
			</cfif>
		<CFELSE>DailyRent F
			<CFQUERY NAME="DailyRent" DATASOURCE="#APPLICATION.datasource#">
				SELECT	*
				FROM 	Charges C
						JOIN ChargeType CT	ON C.iChargeType_ID = CT.iChargeType_ID
				WHERE	C.dtRowDeleted IS NULL
				<CFIF TenantInfo.cChargeSet NEQ ""> 
					AND	C.cChargeSet = '#TenantInfo.cChargeSet#' 
				<CFELSE> 
					AND C.cChargeSet IS NULL 
				</CFIF>
				AND		CT.dtRowDeleted IS NULL
				AND		iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
				AND		C.iResidencyType_ID = #TenantInfo.iResidencyType_ID#
				AND		CT.bIsDaily IS NOT NULL
				AND		iOccupancyPosition = 2
				AND 	iSLevelType_ID = #SLevel.iSLevelType_ID#
				AND		dtEffectiveStart <= '#TenantInfo.dtMovein#'
				AND		dtEffectiveEnd >= '#TenantInfo.dtMovein#'
				AND 	C.iProductLine_ID = #TenantInfo.iProductLine_ID#
				ORDER BY C.dtRowstart desc
			</CFQUERY>
		</CFIF>
<!--- 		</CFQUERY> --->
	</CFIF>
<!--- <cfoutput><cfdump var="#DailyRent#" label="DailyRent"></cfoutput> --->
	<!--- ==============================================================================
	Create Rent Charge into Current open non-Move In Invoice
	=============================================================================== --->
	<CFQUERY NAME='qResidentCare' DATASOURCE="#APPLICATION.datasource#">
		SELECT	C.cDescription ,C.mAmount ,C.iQuantity ,CT.iChargeType_ID
		FROM	Charges C
		JOIN	ChargeType CT ON (CT.iChargeType_ID = C.iChargeType_ID AND CT.dtRowDeleted IS NULL)
		AND 	CT.bIsRent IS NOT NULL AND CT.bIsMedicaid IS NULL AND CT.bIsDiscount IS NULL
		AND 	CT.bIsRentAdjustment IS NULL
		WHERE	C.dtRowDeleted IS NULL AND C.iHouse_ID = #SESSION.qSelectedHouse.iHouse_ID#
		<CFIF TenantInfo.cChargeSet NEQ ''>
			AND C.cChargeSet = '#TenantInfo.cChargeSet#'
		<CFELSE>
			AND C.cChargeSet IS NULL
		</CFIF>
		AND	C.iResidencyType_ID = #TenantInfo.iResidencyType_ID# 
		AND C.iAptType_ID IS NULL 
		AND iSLevelType_ID = #SLevel.iSLevelType_ID#
		<CFIF TenantInfo.cBillingType EQ 'd'>
			AND CT.bIsDaily IS NOT NULL
		<CFELSE>
			AND CT.bIsDaily IS NULL
		</CFIF>
		AND iOccupancyPosition IS NULL
		AND	dtEffectiveStart <= #CreateODBCDateTime(TenantInfo.dtMoveIn)#
		AND	dtEffectiveEnd >= #CreateODBCDateTime(TenantInfo.dtMoveIn)#
	</CFQUERY>
	<CFSET NewMonth = SESSION.TIPSMonth>
	<CFSET cAppliesToAcctPeriod = DateFormat(NewMonth,"yyyy") & DateFormat(NewMonth,"mm")>

	<CFIF TenantInfo.cBillingType EQ 'D' OR SESSION.cBillingType EQ 'D' OR 1 EQ 1>
		<CFSCRIPT>
			if (TenantInfo.cBillingType EQ 'D') { vQuantity=DaysInMonth(SESSION.TIPSMonth); }
			else { vQuantity=qResidentCare.iQuantity; }
		</CFSCRIPT>
 	<br /><!---<cfoutput>
	StandardRent.iChargeType_ID	#StandardRent.iChargeType_ID# ::
	DailyRent.iChargeType_ID	 #DailyRent.iChargeType_ID# ::
	TenantInfo.iTenant_ID	  #TenantInfo.iTenant_ID#
		mMedicaidBSF::	#tenantinfo.mMedicaidBSF#<br />
		mStateMedicaidAmt_BSF_Daily::		#tenantinfo.mStateMedicaidAmt_BSF_Daily#<br />
		mMedicaidCopay::		#qryHouseMedicaid.mMedicaidCopay#<br />
		  </cfoutput><br /> --->
		<!--- 35227 RTS 2/2/2010 - get recurring r&b id to be inserted in the INSERT queries below --->
		
		<cfif tenantinfo.iresidencytype_id is not 2>
			<cfquery name="GetRecurringRBChargeID" datasource="#application.datasource#">	
				select * <!--- r.iRecurringCharge_ID --->
				from RecurringCharge r
				join Charges c on (c.iCharge_ID = r.iCharge_ID
					and (c.iChargeType_ID = '#StandardRent.iChargeType_ID#'
					 or c.iChargeType_ID = '#DailyRent.iChargeType_ID#'))
				where r.iTenant_ID = #TenantInfo.iTenant_ID#
				and r.dtRowDeleted is null
			</cfquery>
		<cfelse><!--- Medicaid --->
			<cfquery name="GetRecurringRBChargeID" datasource="#application.datasource#">	
				select r.iRecurringCharge_ID , c.ichargetype_id,r.mamount
				from RecurringCharge r
				join Charges c on ((c.iCharge_ID = r.iCharge_ID)
					and (c.iChargeType_ID in (8,31,1661)))
				where r.iTenant_ID = #TenantInfo.iTenant_ID#
				and r.dtRowDeleted is null
			</cfquery>
		</cfif>
<!---    		<cfoutput><cfdump var="#GetRecurringRBChargeID#" label="GetRecurringRBChargeID"></cfoutput>
		 <br />
		 <cfoutput> 
		<br /> Automatic Next Month Daily Base Rate #Variables.iInvoiceMaster_ID# ::
		 #GetRecurringRBChargeID.iRecurringCharge_ID# ::
		 #GetRecurringRBChargeID.ichargetype_id# ::
		 TenantInfo.cBillingType #TenantInfo.cBillingType#
		 </cfoutput>  --->
		 			<cfif standardrent.recordcount gt 0>
						<cfif TenantInfo.mBSFDisc is not ''>
							<cfset mamont = #TenantInfo.mBSFDisc#>
						<cfelse>
							<cfset mamont = #TenantInfo.mBSFOrig#>
						</cfif>
						<cfif tenantinfo.cBillingType is 'M'>
 							<cfset iquant = 1>	
						<cfelse>
 							<cfset iquant = #vQuantity#>						
						</cfif>	
						<cfset irecurringID =   #GetRecurringRBChargeID.irecurringcharge_id# >	
						<br />we got standardrent.recordcount
					<cfelseif ((#DailyRent.iChargeType_ID# is 89) and (#TenantInfo.mBSFDisc# gte 0))>
						<cfset mamont = #TenantInfo.mBSFDisc#>
 						<cfset iquant = #vQuantity#>
						<cfset irecurringID =   #GetRecurringRBChargeID.irecurringcharge_id# >
							<br />we got DailyRent.iChargeType_ID #DailyRent.iChargeType_ID#  #TenantInfo.mBSFDisc#
					<cfelseif ((#DailyRent.iChargeType_ID# is 89) and (#TenantInfo.mBSFDisc# is ''))> 
						<cfset irecurringID =   #GetRecurringRBChargeID.irecurringcharge_id# >
 						<cfset iquant = #vQuantity#>
						<cfset mamont = #DailyRent.mAmount#>
					<br />#DailyRent.iChargeType_ID# is 89  and  #TenantInfo.mBSFDisc# is null
					<cfelseif (DailyRent.ichargetype_id is 31) >
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID 
							where   ichargetype_id = 31
						</cfquery>
						<cfset iquant =	1>
						<cfset mamont = #qryMediaidRate.mamount# >	
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif   (DailyRent.ichargetype_id is 8)>
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID 
							where   ichargetype_id = 8
						</cfquery>
						<cfset iquant =  #vQuantity#>
						<cfset mamont = #qryMediaidRate.mamount# >  
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif (DailyRent.ichargetype_id is 1661)>
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID
							where   ichargetype_id = 1661
						</cfquery>
						<!--- <cfdump var="#qryMediaidRate#" label="qryMediaidRate"> --->
						<cfset iquant =	1>
						<cfset mamont = #qryMediaidRate.mamount# >
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif IsDefined('GetRecurringRBChargeID.iRecurringCharge_ID')and 
							#GetRecurringRBChargeID.iRecurringCharge_ID# is not ''>
						<cfset irecurringID = #GetRecurringRBChargeID.iRecurringCharge_ID#>
						<cfset iquant = #vQuantity#>
						<cfset mamont = #DailyRent.mAmount#>	
									
					<cfelse>
					
						<cfset irecurringID =  #GetRecurringRBChargeID.irecurringcharge_id#>
						<cfset iquant = #vQuantity#>
						<cfset mamont = #DailyRent.mAmount#>
					</cfif>	 
<cfoutput>
<cfdump var="#irecurringID#"	 label="Arecurring"	 ><br />
<cfdump var="#iquant#"	 label="Aiquant"	 ><br />
<cfdump var="#mamont#"	 label="Amamont"	 ><br />
</cfoutput>  
		<cfif tenantinfo.iresidencytype_id  is not 2>

		<CFQUERY NAME="InsertStandardRent" DATASOURCE="#APPLICATION.datasource#" > 
			INSERT INTO InvoiceDetail
				( iInvoiceMaster_ID ,iTenant_ID ,iChargeType_ID ,cAppliesToAcctPeriod 
					,bIsRentAdj ,dtTransaction ,cDescription  
					 ,iQuantity
					,mAmount 
					,dtAcctStamp 
					,iRowStartUser_ID 
					,dtRowStart
					,iRecurringCharge_ID
					,cComments
				)
				VALUES(
					#Variables.iInvoiceMaster_ID# 
					,#TenantInfo.iTenant_ID# 
					,<cfif standardrent.recordcount gt 0>
						#standardrent.iChargeType_ID# 
					<cfelse>
						#DailyRent.iChargeType_ID# 
					</cfif>
					,'#cAppliesToAcctPeriod#'
					,NULL 
					,getdate()
					 ,<cfif standardrent.recordcount gt 0>
					 	'#standardrent.cDescription#' 
					 <cfelse>
					 	'#DailyRent.cDescription#' 
					 </cfif>
					,#iQuant#
					,#mamont#
					,#CreateODBCDateTime(SESSION.AcctStamp)# 
					,0 
					,getdate()
					,#irecurringID#
					,'yes std rent'
				)
		</CFQUERY>
			<cfoutput>yes std rent 
					<cfif standardrent.recordcount gt 0>
						standardrent: #standardrent.iChargeType_ID# 
					<cfelse>
						DailyRent::	#DailyRent.iChargeType_ID# 
					</cfif> 
					<cfif standardrent.recordcount gt 0>
					 	standardrent::	'#standardrent.cDescription#' 
					 <cfelse>
					 	DailyRent::	'#DailyRent.cDescription#' 
					 </cfif></cfoutput><br />
		<cfset RentAdded = 'Y'>
 				</cfif>
	
	<CFELSE>
		<br /> not daily 
		<cfoutput>
			Automatic Next Month Daily Base Rate #Variables.iInvoiceMaster_ID# ::
			#GetRecurringRBChargeID.iRecurringCharge_ID# :: 
			TenantInfo.cBillingType #TenantInfo.cBillingType#
		</cfoutput>
					<cfif ((#DailyRent.iChargeType_ID# is 89) and (#TenantInfo.mBSFDisc# gte 0))>
						<cfset mamont = #TenantInfo.mBSFDisc#>
 						<cfset iquant = #vQuantity#>
						<cfset irecurringID =   #GetRecurringRBChargeID.irecurringcharge_id# >
					<cfelseif ((#DailyRent.iChargeType_ID# is 89) and (#TenantInfo.mBSFDisc# is ''))> 
						<cfset irecurringID =   #GetRecurringRBChargeID.irecurringcharge_id# >
 						<cfset iquant = #vQuantity#>
						<cfset mamont = #DailyRent.mAmount#>
					<cfelseif (DailyRent.ichargetype_id is 31) >
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID 
							where  ichargetype_id = 31
						</cfquery>
						<cfset iquant =	1>
						<cfset mamont = #qryMediaidRate.mamount# >	
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif   (DailyRent.ichargetype_id is 8)>
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID 
							where   ichargetype_id = 8
						</cfquery>
						<cfset iquant =  #vQuantity#>
						<cfset mamont = #qryMediaidRate.mamount# >  
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif (DailyRent.ichargetype_id is 1661)>
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID
							where  ichargetype_id = 1661
						</cfquery>
						<cfset iquant =	1>
						<cfset mamont = #qryMediaidRate.mamount# >
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif IsDefined('GetRecurringRBChargeID.iRecurringCharge_ID')and 
							#GetRecurringRBChargeID.iRecurringCharge_ID# is not ''>
						<cfset irecurringID = #GetRecurringRBChargeID.iRecurringCharge_ID#>
						<cfset iquant = #vQuantity#>
						<cfset mamont = #DailyRent.mAmount#>						
					<cfelse>
						<cfset irecurringID =  #GetRecurringRBChargeID.irecurringcharge_id#>
						<cfset iquant = #vQuantity#>
						<cfset mamont = #DailyRent.mAmount#>
					</cfif>	
					
<!--- <cfoutput><cfdump var="#irecurringID#"	 label="Brecurring"	 >
<cfdump var="#iquant#"	 label="Biquant"	 >
<cfdump var="#mamont#"	 label="Bmamont"	 ></cfoutput> --->	
	<cfif tenantinfo.iresidencytype_id  is not 2>
		<CFQUERY NAME="InsertStandardRent" DATASOURCE="#APPLICATION.datasource#">
			INSERT INTO InvoiceDetail

				( iInvoiceMaster_ID ,iTenant_ID ,iChargeType_ID ,cAppliesToAcctPeriod 
					,bIsRentAdj ,dtTransaction ,cDescription  
					,iQuantity 
					,mAmount 
					,dtAcctStamp 
					,iRowStartUser_ID 
					,dtRowStart
					,iRecurringCharge_ID
					,cComments 
				)
				VALUES(
					#Variables.iInvoiceMaster_ID# ,#TenantInfo.iTenant_ID# 
					,#StandardRent.iChargeType_ID# ,'#cAppliesToAcctPeriod#',
					NULL ,getdate() ,#StandardRent.iQuantity# ,'#StandardRent.cDescription#' 
					,#iquant#
					,#mamont#
					,#CreateODBCDateTime(SESSION.AcctStamp)# 
					,0 
					,getdate()
					,#irecurringID#
				    ,'res not 2'
				)
		</CFQUERY><cfoutput>res not 2 #StandardRent.iChargeType_ID# #StandardRent.cDescription#</cfoutput><br />
		</cfif>
	</CFIF>
	
	<!--- 35227 RTS 2/2/2010 - Get all other recurring charges created during MI for insert --->
		<cfquery name="CheckforExistingRecurringCharge" datasource="#application.datasource#">
			select rc.*,c.iChargeType_ID 
			from RecurringCharge rc
			join Charges c on (c.iCharge_ID = rc.iCharge_ID)
			where rc.iTenant_ID = #TenantInfo.iTenant_ID#
			and rc.dtRowDeleted is null
			and getdate() between  c.dteffectivestart and  c.dteffectiveend				
<!--- 			<Cfif IsDefined('GetRecurringRBChargeID.iRecurringCharge_ID')
				and #GetRecurringRBChargeID.iRecurringCharge_ID# is not ''>
				and rc.iRecurringCharge_ID <> #GetRecurringRBChargeID.iRecurringCharge_ID#
			</cfif> --->
			and  c.ichargetype_id not in (7,89, 1740,1682, 1748)  <!--- 75019 --->
		</cfquery>
		
		<cfquery name="qryCopay" dbtype="query">
			Select mamount from CheckforExistingRecurringCharge
			where iChargeType_ID = 1661
		</cfquery>
		
		<CFSCRIPT>
			  rcQuantity=DaysInMonth(SESSION.TIPSMonth);  
		</CFSCRIPT>
		<!--- rcquantity correction for ccmeals to be charged per days in month ticket 103503--->
<!--- 		<cfoutput>
		<cfdump var="#CheckforExistingRecurringCharge#" label="CheckforExistingRecurringCharge">
		</cfoutput> --->
		<cfset loadcount = loadcount + 1>
		<cfif CheckforExistingRecurringCharge.RecordCount gt 0>
			<cfloop query="CheckforExistingRecurringCharge">
			<br />
				<cfoutput>
				CheckforExistingRecurringCharge::
				 #CheckforExistingRecurringCharge.iChargeType_ID# ::
				#CheckforExistingRecurringCharge.mAmount# ::
				 #CheckforExistingRecurringCharge.cDescription# ::
				 #CheckforExistingRecurringCharge.iRecurringCharge_ID#
				</cfoutput><br />
					<cfif (CheckforExistingRecurringCharge.ichargetype_id is 31) >
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID 
							where  ichargetype_id = 31
						</cfquery>
						<cfset iquant =	1>
						<cfset mamont = #qryMediaidRate.mamount# >	
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif   (CheckforExistingRecurringCharge.ichargetype_id is 8)>
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID 
							where   ichargetype_id = 8
						</cfquery>
						<cfquery name="qryCopay" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID
							where  ichargetype_id = 1661
						</cfquery>
						<cfset iquant =  1>
						<cfset mamont = (#qryMediaidRate.mamount# * #vQuantity#)- qryCopay.mamount>  
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
					<cfelseif (CheckforExistingRecurringCharge.ichargetype_id is 1661)>
						<cfquery name="qryMediaidRate" dbtype="query"  >
							select mamount,irecurringcharge_id from GetRecurringRBChargeID
							where  ichargetype_id = 1661
						</cfquery>
						<cfset iquant =	1>
						<cfset mamont = #qryMediaidRate.mamount# >
						<cfset irecurringID =   #qryMediaidRate.irecurringcharge_id# >
<!--- 					<cfelseif IsDefined('GetRecurringRBChargeID.iRecurringCharge_ID')and 
							#GetRecurringRBChargeID.iRecurringCharge_ID# is not ''>
						<cfset irecurringID = #GetRecurringRBChargeID.iRecurringCharge_ID#>
						<cfset iquant = #vQuantity#>
						<cfset mamont = #DailyRent.mAmount#> --->						
					<cfelse>
						<cfset irecurringID =  #CheckforExistingRecurringCharge.irecurringcharge_id#>
						<cfif CheckforExistingRecurringCharge.bIsDaily is 1>
							<cfset iquant = #vQuantity#>
						<cfelse>
							<cfset iquant = 1>
						</cfif>
						<cfset mamont = #CheckforExistingRecurringCharge.mAmount#>
					</cfif>	 				
<!--- <cfoutput>
<cfdump var="#irecurringID#"	 label="Crecurring"	 >
<cfdump var="#iquant#"	 label="Ciquant"	 >
<cfdump var="#mamont#"	 label="Cmamont"	 > 		
RentAdded:: #RentAdded# #CheckforExistingRecurringCharge.iChargeType_ID#<br />	
</cfoutput>	 --->
			<cfif ((RentAdded is 'Y') and ((CheckforExistingRecurringCharge.iChargeType_ID is 1682) 
				or (CheckforExistingRecurringCharge.iChargeType_ID is 1748)))>
				rent loaded as standard rent
			<cfelse>
				<CFQUERY NAME="InsertAllOtherRecurringChargesFromMI" 
					DATASOURCE="#APPLICATION.datasource#" result="result">
						INSERT INTO InvoiceDetail
						( iInvoiceMaster_ID 
						,iTenant_ID 
						,iChargeType_ID 
						,cAppliesToAcctPeriod 
						,bIsRentAdj 
						,dtTransaction 
						,cDescription
						,iQuantity 
						, mAmount 
	
						, dtAcctStamp 
						,iRowStartUser_ID 
						,dtRowStart
						,dtRowEnd
						, iRecurringCharge_ID
						,cComments
						)VALUES(
						#Variables.iInvoiceMaster_ID# 
						,#TenantInfo.iTenant_ID# 
						,#CheckforExistingRecurringCharge.iChargeType_ID# 
						,'#cAppliesToAcctPeriod#'
						,NULL 
						,getdate() 
						,'#CheckforExistingRecurringCharge.cDescription#' 
						,#iquant#
						,#mamont#
						,#CreateODBCDateTime(SESSION.AcctStamp)# 
						,#session.userid# 
						,#CreateODBCDateTime(CheckforExistingRecurringCharge.dteffectivestart)#
						,#CreateODBCDateTime(CheckforExistingRecurringCharge.dteffectiveend)#						
						,#irecurringID#
						,#loadcount#
						)
					</CFQUERY>
				</cfif><cfoutput>InsertAllOtherRecurringChargesFromMI #CheckforExistingRecurringCharge.iChargeType_ID#</cfoutput><br />
			</cfloop>
		</cfif>
	
	
	<!--- End 35227 --->


	<!--- (SLevel.iSPointsMin NEQ '0' AND SLevel.iSPointsMax NEQ '0')

	<CFIF TenantInfo.iSPoints NEQ 0 AND (IsDefined('qResidentCare.RecordCount') AND IsDefined('qDailyCare.RecordCount')
		AND qResidentCare.RecordCount GT 0 AND qDailyCare.RecordCount GT 0)>
	--->

	<CFIF TenantInfo.iSPoints NEQ 0 AND TenantInfo.iResidencyType_id NEQ 2 
	AND qResidentCare.RecordCount GT 0>
		<CFSCRIPT>
			if (TenantInfo.cBillingType EQ 'D') { vQuantity=DaysInMonth(SESSION.TIPSMonth); }
			else { vQuantity=qResidentCare.iQuantity; }
		</CFSCRIPT>
		<cfif TenantInfo.dtrenteffective is not  TenantInfo.dtMoveIn>
			<cfif datepart('m', TenantInfo.dtMoveIn) is right(cAppliesToAcctPeriod,2)>
			   <cfset careQuantity = (daysinmonth(TenantInfo.dtMoveIn)
			    - datepart('d', TenantInfo.dtMoveIn) + 1)>
			<cfelse>
				<cfset careQuantity = vQuantity>
			</cfif>
		<cfelse>
			<cfset careQuantity = vQuantity>
		</cfif>
		<CFQUERY NAME="InsertCare" DATASOURCE="#APPLICATION.datasource#">
			INSERT INTO InvoiceDetail
			( iInvoiceMaster_ID 
			,iTenant_ID 
			,iChargeType_ID 
			,cAppliesToAcctPeriod 
			,bIsRentAdj 
			,dtTransaction 
			,iQuantity 
			,cDescription
			,mAmount 
			,cComments  
			,dtAcctStamp 
			,iRowStartUser_ID 
			,dtRowStart
			)
			VALUES(
				#Variables.iInvoiceMaster_ID# 
				,#TenantInfo.iTenant_ID# 
				,#qResidentCare.iChargeType_ID#
				,'#cAppliesToAcctPeriod#'
				,	NULL 
				,getdate() 
				,#careQuantity# 	 <!--- #vQuantity# --->
				,'#qResidentCare.cDescription#' 
				,#qResidentCare.mAmount#
				,<cfif IsDefined('carecomment') and carecomment is not ''>
					'#carecomment#'
				<cfelse>
					'Care'
				</cfif>
				,#CreateODBCDateTime(SESSION.AcctStamp)#
				,0 
				,getdate()
			)
		</CFQUERY><cfoutput>Z #qResidentCare.cDescription#</cfoutput><br />
	</CFIF>
 

 

	<CFQUERY NAME="qTotalNewMonthly" DATASOURCE="#APPLICATION.datasource#">
		SELECT	SUM(mAmount * iQuantity) as Total
		FROM InvoiceDetail
		WHERE dtRowDeleted IS NULL 
			and iInvoiceMaster_ID = #Variables.iInvoiceMaster_ID# 
			and iTenant_ID = #variables.iTenant_ID# 
			and ichargetype_id not in (69,8)
	</CFQUERY>

	<br /><cfdump var="#qTotalNewMonthly#" label="qTotalNewMonthly"><br />
<!--- 		<CFOUTPUT>
			<CFSET NewLastTotal = InvoiceTotal>
			#NewLastTotal#<BR>
		</CFOUTPUT> --->
<!--- /****************************************************************************************/ --->
		<CFQUERY NAME="qUpdateMonthlyInvoice" DATASOURCE="#Application.datasource#">
			UPDATE	InvoiceMaster
			SET		mInvoiceTotal = #qTotalNewMonthly.Total#,
					mLastInvoiceTotal = #CurrentMonthInvoiceTotal#,
					iRowStartUser_ID = 20,
					dtRowStart = GetDate()
			WHERE	iInvoiceMaster_ID = #Variables.iInvoiceMaster_ID#
			<!---10/30/2008 Project 29842 ssathya added a condition to check dtrowdeleted is null --->
		AND dtrowdeleted is null
		</CFQUERY>

		<CFQUERY NAME="qNewInvoiceData" DATASOURCE="#APPLICATION.datasource#">
			SELECT * FROM InvoiceMaster	
			WHERE iInvoiceMaster_ID = #Variables.iInvoiceMaster_ID#
			<!---10/30/2008 Project 29842 ssathya added a condition to check dtrowdeleted is null --->
		AND dtrowdeleted is null
		</CFQUERY>

<!--- 		<br />
		<CFOUTPUT>
		#qNewInvoiceData.mInvoiceTotal# This<BR> #qNewInvoiceData.mLastInvoiceTotal# LAST
		</CFOUTPUT>
		<BR> --->
</CFIF>
</CFTRANSACTION>

<!--- <cftransaction>
	<cfquery name="qresidentstatechange" datasource="leadtracking">
		select * from resident r
		join residentstate rs on r.iresident_id = rs.iresident_id and r.dtrowdeleted is null
		and rs.dtrowdeleted is null and rs.istatus_id <> 6
		where rs.itenant_id = #TenantInfo.iTenant_ID#
	</cfquery>
	<cfif qresidentstatechange.recordcount gt 0>
		<cfquery name="qchangeresidentstatus" datasource="leadtracking">
			update residentstate
			set istatus_id = 6 ,dtrowstart=getdate(), crowstartuser_id='#trim(session.username)#'
			from resident r
			join residentstate rs on r.iresident_id = rs.iresident_id and r.dtrowdeleted is null
			and rs.dtrowdeleted is null and rs.istatus_id <> 6
			where rs.itenant_id = #TenantInfo.iTenant_ID#
		</cfquery>
	</cfif>
</cftransaction> --->
<!--- <cfif    (cgi.server_name NEQ "vmappprod01dev3")> --->
<CFIF (SESSION.qSelectedHouse.ihouse_id NEQ 200)>
	<CFTRY>
	<!--- ==============================================================================
	Generate MoveIn Solomon Batch
	=============================================================================== --->
	<CFQUERY NAME='qAutoImport' DATASOURCE='#APPLICATION.datasource#'>
		Declare @Status int exec rw.sp_ExportInv2Solomon  
			#trim(SESSION.qSelectedHouse.ihouse_id)#, NULL, '#trim(MoveInInvoice.iInvoiceNumber)#', @Status OUTPUT
	</CFQUERY>
	<CFCATCH type="Any">
		<CFMAIL TYPE="HTML" 
		FROM="TIPS4-Message@alcco.com" 
		TO="CFDevelopers@enlivant.com" 
		SUBJECT="Auto Import MI">
			Declare @Status int
			exec sp_ExportInv2Solomon  
				#trim(SESSION.qSelectedHouse.ihouse_id)#
				, NULL
				, '#trim(MoveInInvoice.iInvoiceNumber)#'
				, @Status OUTPUT
			<p>message: #cfcatch.message#</p> 
			<p>detail: #cfcatch.detail#</p> 
			<p>server_name: #cgi.server_name#</p>
		</CFMAIL>
	<cfif    (cgi.server_name NEQ "vmappprod01dev3")>
			<p>	#trim(SESSION.qSelectedHouse.ihouse_id)#
				, NULL
				, '#trim(MoveInInvoice.iInvoiceNumber)#'
				, @Status OUTPUT</p> 
			<p>message: #cfcatch.message#</p> 
			<p>detail: #cfcatch.detail#</p> 
			<p>server_name: #cgi.server_name#</p>	
	</cfif>	
	</CFCATCH>
	</CFTRY>
</CFIF>
<!--- </cfif> --->
<!--- ==============================================================================
Generate MoveIn CSV
=============================================================================== --->
<br  />
<CFOUTPUT>
	CF_MoveIn iHouse_ID=#SESSION.qSelectedHouse.iHouse_ID# TipsMonth=#DateFormat(SESSION.TipsMonth,"yyyy-mm-dd")# iTenant_ID=#TenantInfo.iTenant_ID#
</CFOUTPUT> 
 <br />
 
<CF_MoveIn iHouse_ID=#SESSION.qSelectedHouse.iHouse_ID# TipsMonth=#DateFormat(SESSION.TipsMonth,"yyyy-mm-dd")# iTenant_ID=#TenantInfo.iTenant_ID#>


<!--- 

<!--- ==============================================================================
Generate MoveIn CSV
=============================================================================== --->
<CF_MoveIn iHouse_ID=#SESSION.qSelectedHouse.iHouse_ID# TipsMonth=#DateFormat(SESSION.TipsMonth,"yyyy-mm-dd")# iTenant_ID=#TenantInfo.iTenant_ID#>
<CFOUTPUT>
	CF_MoveIn iHouse_ID=#SESSION.qSelectedHouse.iHouse_ID# TipsMonth=#DateFormat(SESSION.TipsMonth,"yyyy-mm-dd")# iTenant_ID=#TenantInfo.iTenant_ID#
</CFOUTPUT> --->
<cfif SESSION.qSelectedHouse.ihouse_id neq 200>

<CFIF TenantInfo.iResidencyType_id EQ 2>
	<CFSCRIPT>
		medmi = "A new tenant has been moved into #SESSION.HouseName# by #SESSION.FullName#.<BR>";
		medmi = medmi & "Tenant: #TenantInfo.FullName#<BR>";
		medmi = medmi & "SolomonKey: #TenantInfo.cSolomonKey#<BR>";
		medmi = medmi & "Server Time = #now()#<BR>";
		medmi = medmi & "____________________________________________________<BR>";
	</CFSCRIPT>
	<CFIF SESSION.qSelectedHouse.iHouse_ID NEQ 200 
	and (server_name is 'CF01')>
		<CFMAIL TYPE="HTML" FROM="TIPS4-Message@alcco.com" TO="#GetEMail.AREmail#" 
		CC="#medicaidemails#" SUBJECT="New Medicaid Move In #TenantInfo.FullName#">
			#medmi#
		</CFMAIL>
	<CFELSE>
		<CFMAIL TYPE="HTML" FROM="TIPS4-Message@alcco.com" TO="#GetEMail.AREmail#" 
		SUBJECT="New Medicaid Move In #TenantInfo.FullName#">
			#medmi#
		</CFMAIL>
	</CFIF>

<!---	<CFDIRECTORY DIRECTORY="C:\Inetpub\wwwroot\intranet\TIPS4\MailLog\" ACTION="list" NAME="qDirList" FILTER="MedMoveInMail.txt">
	<CFIF qDirList.RecordCount GT 0>
		<CFFILE ACTION="append" FILE="C:\Inetpub\wwwroot\intranet\TIPS4\MailLog\MedMoveInMail.txt" OUTPUT="#medmi#">
	<CFELSE>
		<CFFILE ACTION="append" FILE="C:\Inetpub\wwwroot\intranet\TIPS4\MailLog\MedMoveInMail.txt" OUTPUT="#medmi#">
	</CFIF>
--->
<CFELSE>
	<cfif    (cgi.server_name NEQ "vmappprod01dev3")>
		<CFSCRIPT>
			newmi = "A new tenant has been moved into #SESSION.HouseName# by #SESSION.FullName#.<BR>";
			newmi = newmi & "Tenant: #TenantInfo.FullName#<BR>";
			newmi = newmi & "SolomonKey: #TenantInfo.cSolomonKey#<BR>";
			newmi = newmi & "Server Time = #now()#<BR>";
			newmi = newmi & "____________________________________________________";
		</CFSCRIPT>
		<CFMAIL TYPE="HTML" 
		FROM="TIPS4-Message@alcco.com" 
		TO="#GetEMail.AREmail#" 
		SUBJECT="New Move In #TenantInfo.FullName#">
			#newmi#
		</CFMAIL>
	</cfif>	
<!---	<CFDIRECTORY DIRECTORY="C:\Inetpub\wwwroot\intranet\TIPS4\MailLog\" ACTION="list" NAME="qDirList" FILTER="MoveInMail.txt">
	<CFIF qDirList.RecordCount GT 0>
		<CFFILE ACTION="append" FILE="C:\Inetpub\wwwroot\intranet\TIPS4\MailLog\MoveInMail.txt" OUTPUT="#newmi#">
	<CFELSE>
		<CFFILE ACTION="append" FILE="C:\Inetpub\wwwroot\intranet\TIPS4\MailLog\MoveInMail.txt" OUTPUT="#newmi#">
	</CFIF>--->
</CFIF>
</cfif>
<!--- </cfif> --->
         <CFIF SESSION.USERID is 9999 > 
	<BR><A HREF="../MainMenu.cfm">Continue.</A> <cfoutput>#SESSION.USERID#</cfoutput>
   <CFELSE>   	 
   
   <CFLOCATION URL="../MainMenu.cfm" ADDTOKEN="No">
   </CFIF>  