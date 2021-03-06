<cfoutput>

<cfparam name="url.sid" type="string" default="0">

<cfquery name="qsubservicelist" datasource="#application.datasource#">
	select 
		 sl.cdescription servicename
		,sb.*
	from 
		subservicelist sb
	join 
		servicelist sl on sl.iservicelist_id = sb.iservicelist_id and sl.dtrowdeleted is null
	and 
		sb.dtrowdeleted is null
	where 
		sl.iservicelist_id = '#serviceId#'
	order by 
		(sb.csortorder*1)
</cfquery>

<script type="text/javascript" src="../../../CFIDE/scripts/wddx.js"></script>
<script type="text/javascript" src="../../TIPS4/Shared/JavaScript/global.js"></script>
<script>
	
<cfwddx action="cfml2js" input="#qsubservicelist#" topLevelVariable="qsubservicelistJS">
function edit(str) {
	dmt=document.forms[0];
	for (a=0;a<=qsubservicelistJS['isubservicelist_id'].length-1;a++){
		if (str*1 == qsubservicelistJS['isubservicelist_id'][a]*1) { 
			dmt.cdescription.value=qsubservicelistJS['cdescription'][a];
			dmt.csortorder.value=qsubservicelistJS['csortorder'][a];
			dmt.fweight.value=qsubservicelistJS['fweight'][a];
			dmt.flweight.value=qsubservicelistJS['flweight'][a];
			if (qsubservicelistJS['bapprovalrequired'][a] == 1) { dmt.approval.checked=true; } else { dmt.approval.checked=false; }
			dmt.isubservicelist_id.value=qsubservicelistJS['isubservicelist_id'][a];
			document.all['editmessage'].innerHTML="<strong>Currently editing service  '"+qsubservicelistJS['cdescription'][a]+"'</strong><BR> <I STYLE='background:yellow;'>** Please press the cancel button if you are trying to add a new entry. **";
			document.all['editmessage'].style.display="inline";
		}
	}
	if (str*1 !== dmt.isubservicelist_id.value*1) { 
		dmt.cdescription.value='', dmt.csortorder.value='', dmt.fweight.value='', dmt.isubservicelist_id.value='';
		//dmt.iservicecategory_id[0].selectedIndex=true; 
		document.all['editmessage'].style.display="none";
	}
}
</script>

<cfif isDefined("url.message") AND url.message neq "">
	<span class="error"><strong>There was an error:</strong><br>#url.message#</span>
</cfif>

<form action="index.cfm" method="post">
<input type="hidden" name="isubservicelist_id" value="">
<input type="hidden" name="iservicelist_id" value="#serviceId#">
<input type="hidden" name="fuse" value="processEditSubService">

<a name="topedit"></a>

<table align="center" >
	<tr>
		<th class="assessmentMain" colspan="5"> 
			Sub Service List Administration 
		</th>
	</tr>
		<td class="assessmentMain">Description</td>
		<td class="assessmentMain" colspan=4>
			<input type="text" maxlength=300 size=100 name="cdescription" value="" onblur="trimspaces(this);" class="assessmentMain">
		</td> 
	</tr>
	<tr>
		<td class="assessmentMain">
			Sort Order
		</td>
		<td class="assessmentMain">
			<input type="text" name="csortorder" size=3 value="" class="assessmentMain">
		</td>
	</tr>
	<tr>
		<td class="assessmentMain">
			Weight
		</td>
		<td class="assessmentMain">
			<input type="text" name="fweight" size=3 value="" class="assessmentMain">
		</td>
		
		<td class="assessmentMain">
			Labor Weight
		</td>
		<td class="assessmentMain">
			<input type="text" name="flweight" size=3 value="" class="assessmentMain">
		</td>
	<tr>
		<td class="assessmentMain">
			Nurse Approval needed 
		</td>
		<td class="assessmentMain">
			<input type="checkbox" name="approval" value="" class="assessmentMain"> (Yes) 
		</td>
	</tr>
	<tr>
		<td colspan=4><input type="submit" name="Submit" value="Save"> <input type="reset" value="Clear"></td>
	</tr>
	<tr>
		<table style="border:1px solid ##006699;">
			<tr>
				<td class="administration">Service</td>
				<td class="administration">Subservice Description</td>
				<td class="administration">Order</td>
				<td class="administration">Bill Weight</td>
				<td class="administration">Labor Weight</td>
				<td class="administration">Appr.</td>
				<td class="administration">Options</td>
				<td class="administration">Delete</td>
			</tr>
			<cfset lastservicename=''>
			<cfloop query="qsubservicelist">
				<tr>
					<td class="assessmentMain">#IIF(lastservicename neq qsubservicelist.servicename,de(qsubservicelist.servicename),de(''))#</td>
					<td class="assessmentMain"><a href="javascript:;" onclick="edit(#qsubservicelist.isubservicelist_id#); location.href='##topedit';">#qsubservicelist.cDescription#</a></td>
					<td class="assessmentMain">#qsubservicelist.cSortOrder#</td>
					<td class="assessmentMain">#NumberFormat(qsubservicelist.fweight)#</td>
					<td class="assessmentMain">#NumberFormat(qsubservicelist.flweight)#</td>
					<td class="assessmentMain">#YesNoFormat(qsubservicelist.bapprovalrequired)#</td>
					<td class="assessmentMain"><a href="index.cfm?fuse=deleteSubService&subServiceid=#qsubservicelist.isubservicelist_id#">del</a></td>
				</tr>
			</cfloop>
		</table>
		</td>
	</tr>	
	<tr><td colspan=100>&nbsp;</td></tr>
</table>
</form>

</cfoutput>