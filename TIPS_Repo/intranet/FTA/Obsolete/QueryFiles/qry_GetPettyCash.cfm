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
| ranklam    | 01/31/2006 | Created                                                            |
----------------------------------------------------------------------------------------------->

<cfparam name="yearforqueries" default="#DatePart("y",now())#">
<cfparam name="GetHouseInfo.iHouse_ID" default="0">

<cfquery name="GetPettyCash" datasource="#ComshareDS#"> 
	select 
		*
	from 
		ALC.FINLOC_BASE
	where
		year_id= #yearforqueries#   
	and
		Line_id= 80000027  
	and                                     
		unit_id= #GetHouseInfo.iHouse_ID#  
	and
		ver_id=  1  
	and
		Cust1_id= 0  
	and
		Cust2_id= 0  
	and
		Cust3_id= 0  
	and
		Cust4_id= 0 
</cfquery>
