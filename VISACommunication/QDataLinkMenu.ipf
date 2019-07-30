#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "QDataLink", dynamic
	QDLMenuItem(-2), /Q, QDLMenuHandler(-2)
	QDLMenuItem(-1), /Q, QDLMenuHandler(-1)
	QDLMenuItem(0), /Q, QDLMenuHandler(0)
	QDLMenuItem(1), /Q, QDLMenuHandler(1)
	QDLMenuItem(2), /Q, QDLMenuHandler(2)
	QDLMenuItem(3), /Q, QDLMenuHandler(3)
	QDLMenuItem(4), /Q, QDLMenuHandler(4)
	//matches QDL_MAX_CONNECTIONS
End

Function /S QDLMenuItem(variable idx)
	String retStr=""
	Variable initRM=0
	
	QDLInit(initRM)
	String fullPkgPath=WBSetupPackageDir(QDLPackageName)
	try
		NVAR DefaultRM=$WBPkgGetName(fullPkgPath, WBPkgDFVar, "visaDefaultRM")
		AbortOnValue DefaultRM<0, -1
		DefaultRM=initRM
		
		Variable maxinstances=WBPkgGetNumberofInstances(QDLPackageName)
		String overall_info=WBPkgGetInfoString(QDLPackageName)
		//overall_info contains the record of all active connections, and the cross reference between these connections and the instance number.
		// for example: "ACTIVE_INSTANCES=0,3;0=ASRL3::INSTR;3=ASRL5::INSTR;ASRL3::INSTR=0;ASRL5::INSTR=3"
		String active_instance_list=StringByKey("ACTIVE_INSTANCES", overall_info, "=", ";")
		Variable maxidx=ItemsInList(active_instance_list, ",")
		
		if(idx==-2)
			return "New Connection..."
		endif
		
		if(idx==-1)
			return "Close Connection..."
		endif
		
		if(idx>=0 && idx<maxidx) //idx should be within the number of active instances
			Variable instance=floor(str2num(StringFromList(idx, active_instance_list, ",")))
			Variable instance_check_flag=0
			String instance_info=WBPkgGetInfoString(QDLPackageName, instance=instance)
			
			if(strlen(instance_info)>0)
				String name, connection, notes
				qdl_get_instance_info(instance, name, notes, connection)

				Variable instance_ref=floor(str2num(StringByKey(connection, overall_info, "=", ";")))
				if (instance_ref!=instance)
					print "instance record is inconsistent with the menu for index ", idx
					print "record of idx is ", connection
					print "this should be for instance ", instance
					print "but record of connection is for instance ", instance_ref
				else
					instance_check_flag=1
				endif
			endif
			if(instance_check_flag==1)
				retStr="[instance"+num2istr(instance)+"] "+name+" ("+connection+") "+" {"+notes+"}"
			else
				retStr="[instance"+num2istr(instance)+"] ERROR!"
			endif
		else
			return ""
		endif
	catch
		print "ERROR: VISA environment not properly initialized."
	endtry
	
	return retStr
End

//whenever a new connection is asked for, we will look for an instance used before that has this connection's information
//otherwise, will ask for a new instance number. The information of previously used instances (for a certain connection)
//will be stored in the global infoStr and will remain there.
//the number of active connections is contained in the infoStr, and the total number of instances listed there
//is kept below QDL_MAX_CONNECTIONS
Function QDLMenuHandler(variable idx)
	String fullPkgPath=WBSetupPackageDir(QDLPackageName)
	String overall_info=WBPkgGetInfoString(QDLPackageName)
	String active_instances=StringByKey("ACTIVE_INSTANCES", overall_info, "=", ";")
	
	if(idx==-2) //new connection
		if(ItemsInList(active_instances)>=QDL_MAX_CONNECTIONS)
			print "Currently too many connections are open. No more new connections will be created."
			return -1
		endif
		
		String port_list=QDLSerialPortGetList()
		String port_select=""
		PROMPT port_select, "Port Name", popup port_list
		DoPrompt "Select Serial Port", port_select
		
		if(V_Flag==0)
			Variable instance_select=-1
			QDLInitSerialPort(port_select, "", instance_select, quiet=0)
		endif
	endif
	
	if(idx==-1) //close connection, not sure what to do for this option
		String close_instance=""
		PROMPT close_instance, "Instance#", popup ReplaceString(",", active_instances, ";")
		DoPrompt "Which instance to close?", close_instance
		
		if(V_flag==0)
			QDLCloseSerialport(instance=str2num(close_instance))
		endif
	endif
	
	if(idx>=0)
		Variable instance_selected=str2num(StringFromList(idx, active_instances, ","))
		String name, notes, connection, panel
		Variable panel_flag=0
		try
			qdl_get_instance_info(instance_selected, name, notes, connection, panel=panel)
			if(winType(panel)==7)
				Variable instance_from_panel=str2num(GetUserData(panel, "", "instance")); AbortOnRTE
				if(strlen(panel)>0 && instance_from_panel==instance_selected)
					DoWindow /F $panel
					panel_flag=1		
				endif
			endif
		catch
			Variable error=GetRTError(1)
		endtry
		if(panel_flag==0)
			panel=QDLSerialConnectionPanel(instance_selected)
			qdl_update_instance_info(instance_selected, name, notes, connection, panel=panel)
		endif
	endif
End
