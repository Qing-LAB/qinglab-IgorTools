#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink

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
		
		Variable maxinstances=WBPkgGetLatestInstance(QDLPackageName)
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
				Variable slot=QDLGetSlotInfo(instance)
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
				retStr="[slot#"+num2istr(slot)+"][instance#"+num2istr(instance)+"] "+name+" ("+connection+") "+" {"+notes+"}"
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
	
	String name, notes, connection, panel
	Variable panel_flag=0
	Variable instance_from_panel
	if(idx==-1) //close connection, not sure what to do for this option
		String close_instance=""
		PROMPT close_instance, "Instance#", popup ReplaceString(",", active_instances, ";")
		DoPrompt "Which instance to close?", close_instance
		
		if(V_flag==0)
			qdl_get_instance_info(str2num(close_instance), name, notes, connection, panel=panel)
			if(winType(panel)==7)
				instance_from_panel=str2num(GetUserData(panel, "", "instance")); AbortOnRTE
				if(strlen(panel)>0 && instance_from_panel==str2num(close_instance))
					KillWindow $panel
					panel_flag=0
				endif
			endif
			qdl_update_instance_info(str2num(close_instance), name, notes, connection, panel="")
			QDLCloseSerialport(instance=str2num(close_instance))
		endif
	endif
	
	if(idx>=0)
		Variable instance_selected=str2num(StringFromList(idx, active_instances, ","))
		try
			qdl_get_instance_info(instance_selected, name, notes, connection, panel=panel)
			if(winType(panel)==7)
				instance_from_panel=str2num(GetUserData(panel, "", "instance")); AbortOnRTE
				if(strlen(panel)>0 && instance_from_panel==instance_selected)
					DoWindow /F $panel
					panel_flag=1		
				endif
			endif
		catch
			Variable error=GetRTError(1)
		endtry
		if(panel_flag==0)
			panel=QDLQueryPanel(instance_selected)
			qdl_update_instance_info(instance_selected, name, notes, connection, panel=panel)
		endif
	endif
End

Function /T QDLQueryPanel(Variable instance)
	String name, notes, connection, param_str
	
	qdl_get_instance_info(instance, name, notes, connection, param_str=param_str)
	STRUCT QDLConnectionParam cp
	StructGet /S cp, param_str
	if(CmpStr(connection, cp.name)!=0)
		print "possible error: connection information does not match parameter setting."
		print "connection by instance: "+connection
		print "connection in parameter setting: "+cp.name
	endif
	if(cp.connection_type!=QDL_CONNECTION_TYPE_SERIAL && cp.connection_type!=QDL_CONNECTION_TYPE_USB)
		print "connection type is wrong for instance "+num2istr(instance)
		print "currently type is set to "+num2istr(cp.connection_type)
		return ""
	endif
	
	NewPanel /N=qdlsc_panel /K=1 /FLT /W=(100,100,620,320) as "QDL Serial Connection Panel -"+connection
	SetVariable sv_name,pos={1,1},size={150,20},title="Name"
	SetVariable sv_name,value= _STR:(name),fixedSize=1
	SetVariable sv_connection, pos={160,1}, size={260,20},title="Connection"
	SetVariable sv_connection, value=_STR:(connection),fixedSize=1,disable=2
	SetVariable sv_notes,pos={1,20},size={500,20},title="Notes"
	SetVariable sv_notes,value= _STR:(notes),fixedSize=1
	Button btn_saveinfo, pos={460,1}, size={50,20}, title="save info",proc=QDLQueryPanel_btnfunc
	
	SetVariable sv_outbox,pos={1,40},size={500,20},title="Message for sending"
	SetVariable sv_outbox,value= _STR:"",fixedSize=1
	Button btn_send,pos={1,55},size={50,20},title="send",proc=QDLQueryPanel_btnfunc
	Button btn_query,pos={55,55},size={50,20},title="query",proc=QDLQueryPanel_btnfunc
	Button btn_read,pos={110,55},size={50,20},title="read",proc=QDLQueryPanel_btnfunc
	Button btn_clear, pos={170,55}, size={50,20}, title="clear",proc=QDLQueryPanel_btnfunc
	TitleBox tb_title,pos={5,80},size={75,20},title="Received Message"
	TitleBox tb_title,frame=0
	//TitleBox tb_receivedmsg,pos={1,95},size={500,80},title=" "
	//TitleBox tb_receivedmsg,fixedSize=1
	
	TitleBox tb_status,pos={1,180},size={500,20},title=" ", fixedSize=1
	SetWindow kwTopWin, userdata(SerialConnectionParam)=param_str
	SetWindow kwTopWin, userdata(instance)=num2istr(instance)	
	String wname=WinName(0, 64, 1, 1)
	NewNotebook /HOST=$wname /F=1 /N=nb0 /OPTS=4 /W=(1,95,501,175)
	SetActiveSubwindow _endfloat_
	return wname
End


Function QDLQueryPanel_btnfunc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	Variable instance, slot, status
	String status_str=""
	String msg_received="", msg_out=""
	String parent_window=ba.win
	
	instance=str2num(GetUserData(parent_window, "", "instance"))
	slot=QDLGetSlotInfo(instance)
	status=0
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here			
			strswitch(ba.ctrlName)
			case "btn_saveinfo":
				ControlInfo /W=$parent_window sv_name
				String name=S_Value
				ControlInfo /W=$parent_window sv_notes
				String notes=S_Value
				ControlInfo /W=$parent_window sv_connection
				String connection=S_Value
				qdl_update_instance_info(instance, name, notes, connection)
				break
			case "btn_send":
				ControlInfo /W=$parent_window sv_outbox
				msg_out=S_Value
				QDLQuery(slot, msg_out, 0, instance=instance, req_status=status)
				sprintf status_str, "write request status: 0x%x", status
				TitleBox tb_status, win=$parent_window, title=status_str
				break
			case "btn_query":
				ControlInfo /W=$parent_window sv_outbox
				msg_out=S_Value
				msg_received=""
				QDLQuery(slot, msg_out, 1, instance=instance, receive_msg=msg_received, req_status=status)
				//TitleBox tb_receivedmsg, win=$parent_window, title=msg_received
				NoteBook $(parent_window+"#nb0"), text="["+date()+" "+time()+"]\n\r"+msg_received+"\n\r"
				sprintf status_str, "query request status: 0x%x", status
				TitleBox tb_status, win=$parent_window, title=status_str
				break
			case "btn_read":
				msg_out=""
				msg_received=""
				QDLQuery(slot, msg_out, 1, instance=instance, receive_msg=msg_received, req_status=status)
				//TitleBox tb_receivedmsg, win=$parent_window, title=msg_received
				NoteBook $(parent_window+"#nb0"), text="["+date()+" "+time()+"]\n\r"+msg_received+"\n\r"
				sprintf status_str, "read request status: 0x%x", status
				TitleBox tb_status, win=$parent_window, title=status_str
				break
			case "btn_clear":
				msg_out=""
				msg_received=""
				QDLQuery(slot, msg_out, 0, instance=instance, clear_device=1, req_status=status)
				sprintf status_str, "clear_device request status: 0x%x", status
				TitleBox tb_status, win=$parent_window, title=status_str
				break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
