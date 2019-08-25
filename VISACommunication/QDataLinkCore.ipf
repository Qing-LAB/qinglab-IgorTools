#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma IndependentModule=QDataLinkCore
#include "VISA"
#include "WaveBrowser"
#include "QDataLinkConstants"
#include "QDataLinkUserFunctions"


#ifdef DEBUG_QDLVISA_3
#ifndef DEBUG_QDLVISA_2
#define DEBUG_QDLVISA_2
#endif
#endif

#ifdef DEBUG_QDLVISA_2
#ifndef DEBUG_QDLVISA_1
#define DEBUG_QDLVISA_1
#endif
#endif

#ifdef DEBUG_QDLVISA
#ifndef DEBUG_QDL_VISA_1
#define DEBUG_QDL_VISA_1
#endif
#endif

//////////////////////////////////////////////////////////////////////////////////////
/////////QDataLinkMenu
//////////////////////////////////////////////////////////////////////////////////////
Menu "QDataLink", dynamic
	QDataLinkCore#QDLMenuItem(-2), /Q, QDataLinkCore#QDLMenuHandler(-2)
	QDataLinkCore#QDLMenuItem(-1), /Q, QDataLinkCore#QDLMenuHandler(-1)
	QDataLinkCore#QDLMenuItem(0), /Q, QDataLinkCore#QDLMenuHandler(0)
	QDataLinkCore#QDLMenuItem(1), /Q, QDataLinkCore#QDLMenuHandler(1)
	QDataLinkCore#QDLMenuItem(2), /Q, QDataLinkCore#QDLMenuHandler(2)
	QDataLinkCore#QDLMenuItem(3), /Q, QDataLinkCore#QDLMenuHandler(3)
	QDataLinkCore#QDLMenuItem(4), /Q, QDataLinkCore#QDLMenuHandler(4)
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
	String wname=UniqueName("qdlsc_panel", 9, 0)
	NewPanel /N=$wname /K=1 /W=(100,100,620,520) as "QDL Serial Connection Panel -"+connection
	SetVariable sv_name,pos={1,1},size={150,20},title="Name"
	SetVariable sv_name,value= _STR:(name),fixedSize=1
	SetVariable sv_connection, pos={160,1}, size={260,20},title="Connection"
	SetVariable sv_connection, value=_STR:(connection),fixedSize=1,disable=2
	SetVariable sv_notes,pos={1,25},size={500,20},title="Notes"
	SetVariable sv_notes,value= _STR:(notes),fixedSize=1
	Button btn_saveinfo, pos={460,1}, size={50,20}, title="save info",proc=QDLQueryPanel_btnfunc
	
	SetVariable sv_outbox,pos={1,40},size={500,20},title="Message for sending"
	SetVariable sv_outbox,value= _STR:"",fixedSize=1
	Button btn_send,pos={1,60},size={50,25},title="send",proc=QDLQueryPanel_btnfunc
	Button btn_query,pos={55,60},size={50,25},title="query",proc=QDLQueryPanel_btnfunc
	Button btn_read,pos={110,60},size={50,25},title="read",proc=QDLQueryPanel_btnfunc
	Button btn_clear, pos={170,60}, size={50,25}, title="clear",proc=QDLQueryPanel_btnfunc
	TitleBox tb_title,pos={5,90},size={75,25},title="Received Message"
	TitleBox tb_title,frame=0
	TitleBox tb_status,pos={90,90},size={300,20},title="Ready ", fixedSize=1
	SetWindow $wname, userdata(SerialConnectionParam)=param_str
	SetWindow $wname, userdata(instance)=num2istr(instance)	
	NewNotebook /HOST=$wname /F=1 /N=nb0 /OPTS=4 /W=(1,115,501,400)
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

//////////////////////////////////////////////////////////////////////////////////////
/////////QDataLinkCore
//////////////////////////////////////////////////////////////////////////////////////
Function QDLInit(Variable & initRM)
	variable init_flag=0
	Variable status=0
	
	initRM=-1
	
	Variable err = GetRTError(0)
	if (err != 0)
		String message = GetErrMessage(err)
		Printf "There was a RTError before calling QDLInit: %s\r", message
		err = GetRTError(1)			// Clear error state
		Print "Error cleared for continuing execution"
	endif
	
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName, init_request=1)
		String defaultRM_str=WBPkgGetName(fullPkgPath, WBPkgDFVar, QDLDefaultRMName)
		NVAR DefaultRM=$defaultRM_str
		if(!NVAR_Exists(DefaultRM))
			WBPrepPackageVars(fullPkgPath, QDLDefaultRMName)
			init_flag=1
		elseif(qdl_is_resource_manager_valid(DefaultRM)!=0)
			DefaultRM=-1
			init_flag=1
		else
			initRM=DefaultRM
		endif
		
		String threadGroupStr=WBPkgGetName(fullPkgPath, WBPkgDFVar, QDLWorkerThreadGroupID)
		NVAR threadGroupID=$threadGroupStr
		if(!NVAR_Exists(threadGroupID))
			WBPrepPackageVars(fullPkgPath, QDLWorkerThreadGroupID)
			NVAR threadGroupID=$threadGroupStr
			threadGroupID=-1
		else
			try
				variable freethreadid=ThreadGroupWait(threadGroupID, 0); err=GetRTError(1)
				AbortOnValue err!=0, -1
			catch
				if(err==QDL_RTERROR_THREAD_NOT_INITIALIZED)
					print "QDataLink thread workers not ready, will initialized now..."
					threadGroupID=-1
				else
					print "Unexpected error ["+num2istr(err)+"] happened. Thread workers not changed."
				endif
			endtry
		endif
		
		String paramNameRecord=WBPkgGetName(fullPkgPath, WBPkgDFWave, StringFromList(0, QDLParamAndDataRecord), quiet=1)
		WAVE /T param_names=$paramNameRecord
		if(!WaveExists(param_names))
			WBPrepPackageWaves(fullPkgPath, QDLParamAndDataRecord, text=1, sizes=QDLParamAndDataRecordSizes)
		endif
		
		String record_name=WBPkgGetName(fullPkgPath, WBPkgDFWave, StringFromList(0, QDLStatusRecord), quiet=1)		
		WAVE record=$record_name
		if(!WaveExists(record))
			WBPrepPackageWaves(fullPkgPath, QDLStatusRecord, sizes=QDLStatusRecordSizes)
		endif
		
		if(init_flag==1)
			//param_names=""
			qdl_clear_active_slot(inf)
			Variable RM		
			status=viOpenDefaultRM(RM)
			if(status==VI_SUCCESS)
				print "["+date()+"] ["+time()+"] VISA default resource manager initialized."
				initRM=RM
				defaultRM=RM
			else
				print "Error when initializing VISA default resource manager."
				QDLPrintVISAError(RM, 0, status) 
				RM=-1
			endif
		endif
		
		if(threadGroupID<0)
			threadGroupID=ThreadGroupCreate(QDL_MAX_CONNECTIONS)
			Variable i
			for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
				ThreadStart threadGroupID, i, qdl_dummy_thread_worker_init(i)
			endfor
			i=ThreadGroupwait(threadGroupID, 1000)
			for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
				if(ThreadReturnValue(threadGroupID, i)!=0)
					print "Thread worker "+num2istr(i)+" did not pass initial test run!"
					break
				endif
			endfor
			if(i<QDL_MAX_CONNECTIONS)
				print "Problem exists when creating thread group for QDataLink."
				Variable ret_release=ThreadGroupRelease(threadGroupID); AbortOnRTE
				print "Releasing thread group returned "+num2istr(ret_release)
				threadGroupID=-1
			endif
			print "["+date()+"] ["+time()+"] "+num2istr(QDL_MAX_CONNECTIONS)+" worker threads for QDataLink created with group ID "+num2istr(threadGroupID)
			WAVE thread_record=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "thread_record"); AbortOnRTE
			thread_record=-1
		endif
		
		CtrlNamedBackground QDL_BACKGROUND_TASK_NAME, status
		if(str2num(StringByKey("RUN", S_info))==0)
			CtrlNamedBackground QDL_BACKGROUND_TASK_NAME, burst=0, dialogsOK=1, period=1, proc=qdl_background_task, start
		endif
	catch
		err=GetRTError(1)
		print "Error initializing QDataLink package: "+GeterrMessage(err)
	endtry
	return RM
End

ThreadSafe Function qdl_dummy_thread_worker_init(Variable i)
	return 0
End

Function QDLGetSlotInfo(Variable instance)
	Variable slot=-1
	Variable i
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName)
		WAVE /T instance_record=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "active_instance_record")
		
		for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
			if(str2num(StringByKey("INSTANCE", instance_record[i]))==instance)
				break
			endif
		endfor
		if(i<QDL_MAX_CONNECTIONS)
			slot=i
		endif
	catch
	endtry
	
	return slot
End

Function /T QDLQuery(Variable slot, String send_msg, Variable expect_response, [Variable instance, String &receive_msg, Variable clear_device, String realtime_func, String postfix_func, String auxparam, Variable timeout, Variable & req_status, Variable quiet])
	String fullPkgPath=WBSetupPackageDir(QDLPackageName)
	DFREF dfr=GetDataFolderDFR()
	
	if(ParamIsDefault(timeout))
		timeout=QDL_DEFAULT_TIMEOUT
	endif

	STRUCT QDLConnectionParam cp
//	Variable lock_state=0
	cp.instr=0
	cp.connection_type=QDL_CONNECTION_TYPE_NONE
	
	String response=""	
	try
		SetDataFolder $fullPkgPath; AbortOnRTE
		
		WAVE /T instance_record=:waves:active_instance_record
		WAVE /T rtfunc_record=:waves:rt_callback_func_list
		WAVE /T postfixfunc_record=:waves:post_callback_func_list
		WAVE /T param_record=:waves:auxparam_all
		WAVE /T auxret_record=:waves:auxret_all
		WAVE /T inbox=:waves:inbox_all
		WAVE /T outbox=:waves:outbox_all
		WAVE request_record=:waves:request_record
		WAVE status_record=:waves:status_record
		WAVE connection_type_info=:waves:connection_type_info
		WAVE /T connection_param=:waves:connection_param_record
		
		Variable request_flag=0; AbortOnRTE
		Variable check_response_flag=0
		
		if(!ParamIsDefault(instance))
			if(str2num(StringByKey("INSTANCE", instance_record[slot]))!=instance)
				print "QDLQuery has inconsistent record of slot ["+num2istr(slot)+"] and instance ["+num2istr(instance)+"]"
				AbortOnValue -1, -1
			endif
		else
			instance=str2num(StringByKey("INSTANCE", instance_record[slot]))
		endif
		
		Variable query_quiet=0
		
		if(!ParamIsDefault(quiet) && quiet!=0)
			query_quiet=QDL_CONNECTION_QUERY_QUIET
		endif
		
		if(slot<QDL_MAX_CONNECTIONS)
//			String param_str=connection_param[slot]; AbortOnRTE
//			if(strlen(param_str)>0)
//				StructGet /S cp, connection_param[slot]; AbortOnRTE
//			else
//				print "WARNING: QDLQuery received a slot number with empty connection parameter settings."
//			endif
//			
//			qdl_lock(cp, VI_TMO_INFINITE); AbortOnRTE
//			lock_state=1
				
			Variable update_func_flag=0
			Variable start_time, current_time
			
			connection_type_info[slot] = connection_type_info[slot] | (QDL_CONNECTION_RTCALLBACK_SUSPENSE| query_quiet)
		
			if(!ParamIsDefault(timeout) && numtype(timeout)==1) //timeout is infinite
				connection_type_info[slot] = connection_type_info[slot] | QDL_CONNECTION_NO_TIMEOUT
			else
				connection_type_info[slot] = connection_type_info[slot] & (~ QDL_CONNECTION_NO_TIMEOUT)
			endif
				
			if(!ParamIsDefault(realtime_func) && strlen(realtime_func)>0)
				rtfunc_record[slot]=realtime_func; AbortOnRTE
				update_func_flag=1
			endif
			if(!ParamIsDefault(postfix_func) && strlen(postfix_func)>0)
				postfixfunc_record[slot]=postfix_func; AbortOnRTE
				update_func_flag=1
			endif
			if(!ParamIsDefault(auxparam) && strlen(auxparam)>0)
				param_record[slot]=auxparam; AbortOnRTE
			//else
			//	param_record[slot]=""; AbortOnRTE
			endif
			if(update_func_flag==1)
				start_time=StopMSTimer(-2)/1000; AbortOnRTE
				auxret_record[slot]=""
				connection_type_info[slot] = connection_type_info[slot] | QDL_CONNECTION_ATTACH_FUNC
				//there will always be a waiting for this operation to make sure that the function attaches appropriately
				do //waiting for the thread to answer to request of updating user functions
					Sleep /T 6
					DoUpdate; AbortOnRTE
					current_time=StopMSTimer(-2)/1000; AbortOnRTE
				while((current_time-start_time<QDL_DEFAULT_TIMEOUT) && (connection_type_info[slot] & QDL_CONNECTION_ATTACH_FUNC))
			
				if(connection_type_info[slot] & QDL_CONNECTION_ATTACH_FUNC)
					print "Warning: timeout when trying to attach user defined function to instance "+num2istr(instance)
				endif
			endif
			
			if(!ParamIsDefault(clear_device) && clear_device==1)
				request_flag = request_flag | QDL_REQUEST_CLEAR_BUFFER
			endif
			
			if(strlen(send_msg)>0)
				outbox[slot]=send_msg; AbortOnRTE
				request_flag = request_flag | QDL_REQUEST_WRITE; AbortOnRTE
				check_response_flag = check_response_flag | QDL_REQUEST_WRITE_COMPLETE; AbortOnRTE
			endif
			if(expect_response!=0)
				inbox[slot]=""; AbortOnRTE
				request_flag = request_flag | QDL_REQUEST_READ; AbortOnRTE
				check_response_flag = check_response_flag | QDL_REQUEST_READ_COMPLETE; AbortOnRTE
			endif
			
			request_record[slot]=request_flag; AbortOnRTE
			
			if(timeout>0)
				start_time=StopMSTimer(-2)/1000; AbortOnRTE
				//print "start waiting for task complete..."
				do
					Sleep /T 6
					DoUpdate; AbortOnRTE
					current_time=StopMSTimer(-2)/1000; AbortOnRTE
				while((current_time-start_time<timeout) && ((request_record[slot] & check_response_flag)!=check_response_flag))
				//print "end for task complete. status:"+num2istr(request_record[slot])
				
				if(request_record[slot] & QDL_REQUEST_READ_COMPLETE)
					response=inbox[slot]; AbortOnRTE
					if(!ParamIsDefault(receive_msg))
						receive_msg=response; AbortOnRTE
					endif
				endif
				
				if(!ParamIsDefault(req_status))
					req_status=request_record[slot]; AbortOnRTE
				endif
			endif
		endif		
		connection_type_info[slot] = connection_type_info[slot] & (~(QDL_CONNECTION_RTCALLBACK_SUSPENSE | query_quiet))
//		qdl_unlock(cp)
//		lock_state=0
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "Error when query from instance "+num2istr(instance)+": "+GetErrMessage(err)
		endif
		if(slot<QDL_MAX_CONNECTIONS && WaveExists(connection_type_info))
			connection_type_info[slot] = connection_type_info[slot] & (~(QDL_CONNECTION_RTCALLBACK_SUSPENSE | query_quiet))
		endif
//		if(lock_state!=0)
//			qdl_unlock(cp)
//		endif		
	endtry
	
	SetDataFolder dfr
	return response
End

Function QDLCheckStatus(Variable req_stat, [Variable & read_complete, Variable & write_complete, Variable & read_error, Variable & write_error, Variable & timeout)
	if(!ParamIsDefault(read_complete))
		read_complete=((req_stat | QDL_REQUEST_READ_COMPLETE)!=0)
	endif
	if(!ParamIsDefault(write_complete))
		write_complete=((req_stat | QDL_REQUEST_WRITE_COMPLETE)!=0)
	endif

	if(!ParamIsDefault(read_error))
		read_error=((req_stat | QDL_REQUEST_READ_ERROR)!=0)
	endif
	if(!ParamIsDefault(write_error))
		write_error=((req_stat | QDL_REQUEST_WRITE_ERROR)!=0)
	endif
	
	if(!ParamIsDefault(timeout))
		timeout=((req_stat | QDL_REQUEST_TIMEOUT)!=0)
	endif
End

//
//ThreadSafe Function qdl_lock(STRUCT QDLConnectionParam & cp, Variable timeout)
//	switch(cp.connection_type)
//		case QDL_CONNECTION_TYPE_SERIAL:
//		case QDL_CONNECTION_TYPE_USB:
//			if(cp.instr>0)
//				return qdl_VISALock(cp.instr, timeout)
//			endif
//			break
//		default:
//	endswitch
//	return -1
//End
//
//ThreadSafe Function qdl_unlock(STRUCT QDLConnectionParam & cp)
//	switch(cp.connection_type)
//		case QDL_CONNECTION_TYPE_SERIAL:
//		case QDL_CONNECTION_TYPE_USB:
//			if(cp.instr>0)
//				return qdl_VISAUnLock(cp.instr)
//			endif
//			break
//		default:
//	endswitch
//	return -1
//End

ThreadSafe Function qdl_thread_request_handler(Variable slot, Variable threadIDX, WAVE request, WAVE status, 
																WAVE connection_type, WAVE /T active_instances, 
																WAVE /T connection_param, WAVE /T inbox, 
																WAVE /T outbox, WAVE /T rt_callback_func, 
																WAVE /T auxparam, WAVE /T auxret, WAVE thread_record)
	if(slot<0 || slot >= QDL_MAX_CONNECTIONS)
		print "invalid slot sent to thread worker!", slot
		return -1
	endif
	
	if(thread_record[threadIDX]!=slot)
		print "Thread "+num2istr(threadIDX)+" should be registered to slot "+num2istr(thread_record[threadIDX])+", but instead slot "+num2istr(slot)+" is attached."
		print "Thread worker will quit due to inconsistency."
	endif
	
	STRUCT QDLConnectionparam cp
	cp.connection_type=QDL_CONNECTION_TYPE_NONE
	cp.instr=0
	
	Variable cp_init=0
	String cp_str=""
	if(strlen(connection_param[slot])>0)
		StructGet /S cp, connection_param[slot]
		cp_init=1
	endif
	
	String rtcallbackfunc_name=rt_callback_func[slot]
	qdl_update_rtcallback_func(rtcallbackfunc_name, rt_callback_func, slot, quiet=(connection_type[slot] & QDL_CONNECTION_QUERY_QUIET))
	FUNCREF qdl_rtfunc_prototype rtcallbackfunc_ref=$(rt_callback_func[slot])
	
	Variable retVal=0
//	Variable lock_state=0, vi_status
	String tmpkeyin="", tmpkeyout=""
	do
		try
			if((connection_type[slot] & QDL_CONNECTION_QUITTING) !=0)
				retVal=-99
			else
				if((connection_type[slot] & QDL_CONNECTION_ATTACH_FUNC)!=0)
					rtcallbackfunc_name=rt_callback_func[slot]
					qdl_update_rtcallback_func(rtcallbackfunc_name, rt_callback_func, slot, quiet=(connection_type[slot] & QDL_CONNECTION_QUERY_QUIET))
					FUNCREF qdl_rtfunc_prototype rtcallbackfunc_ref=$(rt_callback_func[slot])
					connection_type[slot] = connection_type[slot] & (~ QDL_CONNECTION_ATTACH_FUNC)
				endif
				if((connection_type[slot] & QDL_CONNECTION_TYPE_MASK) != cp.connection_type)
					print "connection_type_info is inconsistent with parameters stored for slot ["+num2istr(slot)+"]"
					retVal=-98
				else
					//if(qdl_lock(cp, VI_TMO_INFINITE)==0)
					//	lock_state=1
						switch(connection_type[slot] & QDL_CONNECTION_TYPE_MASK)
						case QDL_CONNECTION_TYPE_SERIAL:
						case QDL_CONNECTION_TYPE_USB:
							if((connection_type[slot] & QDL_CONNECTION_QUITTING)==0) //no request to quit yet
								retVal=qdl_thread_serialport_req(cp, slot, request, status, connection_type, \
																		inbox, outbox, auxparam, auxret, \
																		rtcallbackfunc_ref); AbortOnRTE
							endif
							break
						default:
							retVal=-1
						endswitch
						//qdl_unlock(cp)
						//lock_state=0
					//endif
				endif //check consistency of connection_type and connection_parameters
			endif //connection not quitting
		catch
			Variable err=GetRTError(1)
			print "Error happened for thread worker of QDataLink slot "+num2istr(slot)+": "+GetErrMessage(err)
			//if(lock_state)
			//	qdl_unlock(cp)
			//endif
		endtry
		if(cp_init)
			StructPut /S cp, cp_str
			connection_param[slot]=cp_str
		endif
		//Sleep /T 1
	while(retVal==0)
	
	connection_type[slot] = connection_type[slot] | QDL_CONNECTION_QUITTED
	thread_record[threadIDX]=QDL_THREAD_STATE_FREE
	print "Thread worker for QDataLink slot "+num2istr(slot)+" has quitted."
	return retVal
End

//Background task runs in main thread
//It will cleanup threads that quit. In this case, the connection will be closed properly
//It will also track the status of request. When the request is complete, it will call user
//function, if defined, to process this information.
Function qdl_background_task(s)
	STRUCT WMBackgroundStruct &s
	String fullPkgPath=WBSetupPackageDir(QDLPackageName); AbortOnRTE
	DFREF old_dfr=GetDataFolderDFR()
	Variable flag=1
	Variable i
	Variable err
	//print "qdl_background_task called."
	try
		SetDataFolder $fullPkgPath; AbortOnRTE
		NVAR threadGroupID=:vars:threadGroupID
		WAVE /T post_callback_func=:waves:post_callback_func_list
		WAVE /T active_instance_record=:waves:active_instance_record
		String instanceDir=""
		do
			DFREF dfr=ThreadGroupGetDFR(threadGroupID, 0); AbortOnRTE
			switch(DataFolderRefstatus(dfr))
			case 0: //invalid
				flag=0
				break
			case 1: //regular global data folder, should not happen
				print "QDataLink background task received a global datafolder ref. This should not happen..."
				break
			case 3: //free datafolder ref
				//print "dfr received. dfr status: ", DataFolderRefstatus(dfr)
				NVAR DFinstance=dfr:instance; AbortOnRTE
				NVAR slot=dfr:slot; AbortOnRTE								
				if(NVAR_Exists(DFinstance) && NVAR_Exists(slot))
					Variable instance=DFinstance
					if(slot>=0 && slot<QDL_MAX_CONNECTIONS && instance>=0)
						if(str2num(StringByKey("INSTANCE", active_instance_record[slot]))==instance)
							instanceDir=WBSetupPackageDir(QDLPackageName, instance=instance)
							FUNCREF qdl_postprocess_bgfunc_prototype callback_ref=$(post_callback_func[slot])
							if(str2num(StringByKey("ISPROTO", FuncRefInfo(callback_ref)))==0)
								callback_ref(instance, slot, 1, dfr, instanceDir); err=GetRTError(1) //call user function for processing data
							endif
						endif
					endif
				endif
				KillDataFolder /Z dfr; AbortOnRTE
				break
			default:
				flag=0
				break
			endswitch
		while(flag==1)
		
		//will call all background function for non-critical job without dfr
		for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
			try
				Variable inst=str2num(StringByKey("INSTANCE", active_instance_record[i]))
				if(numtype(inst)==0 && inst>=0 && strlen(post_callback_func[i])>0)
					//print "user function is set as ...", post_callback_func[i]
					FUNCREF qdl_postprocess_bgfunc_prototype callback_ref=$(post_callback_func[i])
					if(str2num(StringByKey("ISPROTO", FuncRefInfo(callback_ref)))==0)
						instanceDir=WBSetupPackageDir(QDLPackageName, instance=inst)
						//call user function for maintenance when no data have arrived
						//user function should be quick and collaborative to handle this
						//print "calling user function when no dfr has come."
						callback_ref(inst, i, 0, NULL, instanceDir); err=GetRTError(1)
					endif
				endif
			catch
				err=GetRTError(1)
				if(err!=0)
					print "QDataLink background function encountered an error when calling user function:"+GetErrMessage(err)
				endif
			endtry
		endfor
		
	catch
		err=GetRTError(1)
		if(err!=0)
			print "QDataLink background function encountered an error:"+GetErrMessage(err)
		endif
	endtry
	
	SetDataFolder old_dfr
	return 0
End

///////////////////////////////////////////////////////////////////////////////
/////QDataLinkBookkeeping
///////////////////////////////////////////////////////////////////////////////

Function qdl_is_connection_open(string connectionDescr)
	String fullPkgPath=WBSetupPackageDir(QDLPackageName)
	String overall_info=WBPkgGetInfoString(QDLPackageName)
	//overall_info contains the record of all active connections, and the cross reference 
	//between these connections and the instance number.
	// for example: "ACTIVE_INSTANCES=0,3;0=ASRL3::INSTR;3=ASRL5::INSTR;ASRL3::INSTR=0;ASRL5::INSTR=3"
	String active_instances=StringByKey("ACTIVE_INSTANCES", overall_info, "=", ";")

	variable i, n, openidx
	n=ItemsInList(active_instances, ",")
	openidx=-1
	for(i=0; i<n; i+=1)
		String opened_port=StringByKey(StringFromList(i, active_instances, ","), overall_info, "=", ";")
		if(CmpStr(opened_port, connectionDescr)==0)
			openidx=i
			break
		endif
	endfor
	return openidx
End

Function qdl_find_instance_for_connection(string connectionDescr)
	String overall_info=WBPkgGetInfoString(QDLPackageName)
	Variable previous_instance=str2num(StringByKey(connectionDescr, overall_info, "=", ";"))
	if(numtype(previous_instance)!=0)
		return WBPkgNewInstance
	else
		return previous_instance
	endif
End

//this function will find an available slot, find a thread that can be attached to
//returns the slot number and the thread index
//if either the slot or the thread can not be properly identified, will return -1
//thread state is tracked in thread_record wave. A thread can be free, reserved (not running), and running
//when a thread is running, the corresponding element in thread_record will have the number of the slot this thread
//is associated with.
//when this function returns successfully, the slot and the thread will be both labelled as reserved
Function qdl_reserve_active_slot(Variable & threadIDX)
	Variable slot_num=-1
	threadIDX=-1
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName)
		WAVE /T active_instance_record=$(WBPkgGetName(fullPkgPath, WBPkgDFWave, "active_instance_record")); AbortOnRTE
		NVAR threadGroupID=$WBPkgGetName(fullPkgPath, WBPkgDFVar, "threadGroupID"); AbortOnRTE
		WAVE thread_record=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "thread_record"); AbortOnRTE
		
		if(WaveExists(active_instance_record)==1)
			Variable i
			for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
				if(str2num(StringByKey("INSTANCE", active_instance_record[i]))==-1)
					active_instance_record[i]=ReplaceStringByKey("INSTANCE", active_instance_record[i], num2istr(QDL_SLOT_STATE_RESERVED))
					active_instance_record[i]=ReplaceStringByKey("THREAD", active_instance_record[i], "-1") //no thread attached yet
					break
				endif
			endfor
		endif
		if(i<QDL_MAX_CONNECTIONS)
			Variable thIDX=ThreadGroupWait(threadGroupID, -2)-1; AbortOnRTE
			//thread_record will store the active slot number attached to each thread
			if(thIDX>=0)
				if(thread_record[thIDX]==QDL_THREAD_STATE_FREE)
					thread_record[thIDX]=QDL_THREAD_STATE_RESERVED
					threadIDX=thIDX
					slot_num=i
				else
					print "Thread worker "+num2istr(thIDX)+" is labelled as free, which is inconsistent with records. Failed to allocate active connection slot "+num2istr(i)
					thIDX=-1
				endif
			else
				print "No free thread can be found. This should not happen."
			endif
			if(thIDX<0) //not properly assigned
				active_instance_record[i]=ReplaceStringByKey("INSTANCE", active_instance_record[i], num2istr(QDL_SLOT_STATE_FREE))
				active_instance_record[i]=ReplaceStringByKey("THREAD", active_instance_record[i], "-1") //set things back to free state
			endif
		endif
	catch
		print "Error happened when reserving active slot for QDataLink connection."
		Variable err=GetRTError(1)
		print GetErrMessage(err)
	endtry
	return slot_num
End

Function qdl_set_active_slot(Variable slot, [Variable startThreadIDX, Variable instance, String connection_param, 
											String inbox, String outbox, String auxparam, String auxret, 
											String rt_callback_func, String post_callback_func, 
											Variable request, Variable status, Variable connection_type])
	if(slot<0 || slot>=QDL_MAX_CONNECTIONS)
		return -1
	endif
	
	DFREF dfr=GetDataFolderDFR()
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName); AbortOnRTE
		String overall_info=WBPkgGetInfoString(QDLPackageName); AbortOnRTE
		
		SetDataFolder $fullPkgPath; AbortOnRTE
		
		WAVE /T instance_record=:waves:active_instance_record; AbortOnRTE
		WAVE /T connection_param_record=:waves:connection_param_record; AbortOnRTE
		WAVE /T inbox_all=:waves:inbox_all; AbortOnRTE
		WAVE /T outbox_all=:waves:outbox_all; AbortOnRTE
		WAVE /T auxparam_all=:waves:auxparam_all; AbortOnRTE
		WAVE /T auxret_all=:waves:auxret_all; AbortOnRTE
		WAVE /T rt_callback_func_list=:waves:rt_callback_func_list; AbortOnRTE
		WAVE /T post_callback_func_list=:waves:post_callback_func_list; AbortOnRTE
		WAVE request_record=:waves:request_record; AbortOnRTE
		WAVE status_record=:waves:status_record; AbortOnRTE
		WAVE connection_type_info=:waves:connection_type_info; AbortOnRTE
		NVAR threadGroupID=:vars:threadGroupID; AbortOnRTE
		WAVE thread_record=:waves:thread_record; AbortOnRTE
		
		if(!ParamIsDefault(instance))
			instance_record[slot]=ReplaceStringByKey("INSTANCE", instance_record[slot], num2istr(instance)); AbortOnRTE
		endif
		
		if(!ParamIsDefault(connection_param))
			connection_param_record[slot]=connection_param; AbortOnRTE
		endif
	
		if(!ParamIsDefault(inbox))
			inbox_all[slot]=inbox; AbortOnRTE
		endif
	
		if(!ParamIsDefault(outbox))
			outbox_all[slot]=outbox; AbortOnRTE
		endif
		
		if(!ParamIsDefault(auxparam))
			auxparam_all[slot]=auxparam; AbortOnRTE
		endif
	
		if(!ParamIsDefault(auxret))
			auxret_all[slot]=auxret; AbortOnRTE
		endif
	
		if(!ParamIsDefault(rt_callback_func))
			rt_callback_func_list[slot]=rt_callback_func; AbortOnRTE
		endif
	
		if(!ParamIsDefault(post_callback_func))
			post_callback_func_list[slot]=post_callback_func; AbortOnRTE
		endif
	
		if(!ParamIsDefault(request))
			request_record[slot]=request; AbortOnRTE
		endif
	
		if(!ParamIsDefault(status))
			status_record[slot]=status; AbortOnRTE
		endif
		
		if(!ParamIsDefault(connection_type))
			connection_type_info[slot]=connection_type; AbortOnRTE
		endif
		
		//update the list of active instances in the overall information string for the package
		Variable i
		String active_instances=""
		for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
			String instance_str = StringByKey("INSTANCE", instance_record[i])
			if(str2num(instance_str)>=0)
				active_instances+=instance_str+","
			endif
		endfor

//overall_info contains the record of all active connections, and the cross reference 
//between these connections and the instance number.
// for example: "ACTIVE_INSTANCES=0,3;0=ASRL3::INSTR;3=ASRL5::INSTR;ASRL3::INSTR=0;ASRL5::INSTR=3"
		overall_info=ReplaceStringByKey("ACTIVE_INSTANCES", overall_info, active_instances, "=", ";", 1)
		WBPkgSetInfoString(QDLPackageName, overall_info)
		
		if(!ParamIsDefault(startThreadIDX))
			if(thread_record[startThreadIDX]!=QDL_THREAD_STATE_RESERVED)
				print "Thread worker ["+num2istr(startThreadIDX)+"] is not labelled as reserved while attaching to active slot "+num2istr(slot)
				print "This should not happen. No action will be taken."
			else
				if(startThreadIDX>=0 && startThreadIDX<QDL_MAX_CONNECTIONS)
					ThreadStart threadGroupID, startThreadIDX, qdl_thread_request_handler(slot, startThreadIDX, request_record, \
																								status_record, connection_type_info, \
																								instance_record, connection_param_record, \
																								inbox_all, outbox_all, rt_callback_func_list, \
																								auxparam_all, auxret_all, thread_record); AbortOnRTE
					thread_record[startThreadIDX]=slot; AbortOnRTE
					print "Thread worker index "+num2istr(startThreadIDX)+" for slot "+num2istr(slot)+" started."
				endif
				if(startThreadIDX<QDL_MAX_CONNECTIONS)
					instance_record[slot]=ReplaceStringByKey("THREAD", instance_record[slot], num2istr(startThreadIDX))
				else
					print "When setting active slot["+num2istr(slot)+"], thread index ["+num2istr(startThreadIDX)+"]is out of range."
				endif
			endif																		
		endif
	catch
		Variable err=GetRTError(1)
		print "Error when setting connection record: "+GetErrMessage(err)
	endtry
	
	SetDataFolder dfr
	return 0
End

Function qdl_release_active_slot(Variable slot, Variable timeout_ms)
	if(slot<0 || slot>=QDL_MAX_CONNECTIONS)
		return -1
	endif
	
	Variable starttime=StopMSTimer(-2)
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName); AbortOnRTE
		WAVE connection_type=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "connection_type_info"); AbortOnRTE
		WAVE /T active_instance_record=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "active_instance_record"); AbortOnRTE
		NVAR threadGroupID=$WBPkgGetName(fullPkgPath, WBPkgDFVar, "threadGroupID"); AbortOnRTE
		WAVE thread_record=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "thread_record"); AbortOnRTE
		
		String instance_str=StringByKey("INSTANCE", active_instance_record[slot])
		String thread_str=StringByKey("THREAD", active_instance_record[slot])
		
		if(str2num(instance_str)>=0)
			//set signal to thread to ask it to quit
			connection_type[slot] = connection_type[slot] | QDL_CONNECTION_QUITTING ; AbortOnRTE
			Variable flag=-1
			Variable threadIDX=str2num(thread_str)
			//verify that the correct thread is associated with this lot
			if(threadIDX>=0 && threadIDX<QDL_MAX_CONNECTIONS)
				if(thread_record[threadIDX]==slot) //thread is running and associated with the correct slot number
					flag=1
					do
						Sleep /T 1
						Variable thID=ThreadGroupWait(threadGroupID, 0); AbortOnRTE
						if(thread_record[threadIDX]==QDL_THREAD_STATE_FREE) //the thread worker should set this value when quitting
							flag=0; AbortOnRTE
						endif
						if((StopMSTimer(-2)-starttime)>=timeout_ms*1000)
							flag=-1; AbortOnRTE
						endif
					while(flag>0)
					if(flag==0)
						print "Thread worker for slot "+num2istr(slot)+" stopped gracefully."
					endif
				elseif(thread_record[threadIDX]==QDL_THREAD_STATE_RESERVED)
					thread_record[threadIDX]=QDL_THREAD_STATE_FREE
					flag=0
				else
					print "Inconsistency found in record."
					print "slot number: ", slot
					print "instance number:", instance_str
					print "thread index record:", thread_str
					if(threadIDX>=0 && threadIDX<QDL_MAX_CONNECTIONS)
						print "thread state:", thread_record[threadIDX]
					else
						print "cannot find thread state for invalid thread index"
					endif
				endif
			endif
			
			if(flag>=0)
				active_instance_record[slot]=ReplaceStringByKey("INSTANCE", active_instance_record[slot], num2istr(QDL_SLOT_STATE_FREE))
				active_instance_record[slot]=ReplaceStringByKey("THREAD", active_instance_record[slot], "-1")
				if(flag>0)
					print "The thread worker did not quit gracefully in time. Will forcefully set thread record as free. This may lead to inconsistency."
					print "Slot ["+num2istr(slot)+"], instance ["+instance_str+"], thread index [+"+num2istr(threadIDX)+"]"
					thread_record[threadIDX]=QDL_THREAD_STATE_FREE
				endif
			else
				print "Invalid record of thread found..."
				print "Slot ["+num2istr(slot)+"], instance ["+instance_str+"], thread index [+"+num2istr(threadIDX)+"]"
			endif
		endif
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "Error when releasing active slots."
			print GetErrMessage(err)
		endif
	endtry
End

Function qdl_clear_active_slot(Variable slot)
	Variable i
	
	if(numtype(slot)==0)
		if(slot>=0 && slot<QDL_MAX_CONNECTIONS)
			qdl_set_active_slot(slot, instance=-1, connection_param="", \
									inbox="", outbox="", auxparam="", auxret="", \
									rt_callback_func="", post_callback_func="", request=0, \
									status=0, connection_type=QDL_CONNECTION_TYPE_NONE)
		endif
	elseif(numtype(slot)==1) //slot = inf
		for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
			qdl_set_active_slot(i, instance=-1, connection_param="", \
									inbox="", outbox="", auxparam="", auxret="", \
									rt_callback_func="", post_callback_func="", request=0, \
									status=0, connection_type=QDL_CONNECTION_TYPE_NONE)
		endfor
	endif
End

//when not trying to attach a function, or quitting a connection, it is callable
ThreadSafe Function qdl_is_connection_callable(WAVE connection_type, Variable slot)
	return !(connection_type[slot] & (QDL_CONNECTION_ATTACH_FUNC | QDL_CONNECTION_QUITTING | QDL_CONNECTION_QUITTED)); AbortOnRTE
End

Function qdl_is_resource_manager_valid(variable rm)
	String str=""
	Variable status=0
	if(rm<=0)
		return -1
	endif
	
	status=viGetAttributeString(rm, VI_ATTR_RSRC_NAME, str)
	if(status!=VI_SUCCESS)
		return -1
	endif
	
	return 0
End

ThreadSafe Function qdl_update_rtcallback_func(String funcname, WAVE /T funcname_list, Variable slot, [Variable quiet])
	FUNCREF qdl_rtfunc_prototype ref=qdl_rtfunc_prototype
	String update_funcname=StringByKey("NAME", FuncRefInfo(ref))
	if(ParamIsDefault(quiet) || quiet==0)
		print "User requested to attach function ["+funcname+"] to QDataLink slot "+num2istr(slot)
	endif
	if(strlen(funcname)>0)
		FUNCREF qdl_rtfunc_prototype ref=$(funcname)
		try
			print "Initial call to "+funcname+"(1) successfully returned: ", ref(1); AbortOnRTE
			//update_funcname=StringByKey("NAME", FuncRefInfo(ref))
			update_funcname=funcname
		catch
			Variable err=GetRTError(1)
			if(ParamIsDefault(quiet) || quiet==0)
				print "User defined real-time callback function failed init test for slot "+num2istr(slot)
				print "No user defined real-time will be called."
			endif
			FUNCREF qdl_rtfunc_prototype ref=qdl_rtfunc_prototype
		endtry
	endif
	
	print "NAME tag from funcref is: ", update_funcname
	if(strlen(update_funcname)<=0)
		update_funcname="qdl_rtfunc_prototype"
	endif
	funcname_list[slot]=update_funcname
	if(ParamIsDefault(quiet) || quiet==0)
		print "New real-time callback function ["+update_funcname+"] attached to slot "+num2istr(slot)
	endif
End

Function qdl_get_instance_info(Variable instance, String & name, String & notes, String & connection, [String & param_str, String & panel])
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName, instance=instance)
		String infoStr=WBPkgGetInfoString(QDLPackageName, instance=instance)
		
		name=StringByKey("NAME", infoStr, "=", ";")
		notes=StringByKey("NOTE", infoStr, "=", ";")
		connection=StringByKey("CONNECTION", infoStr, "=", ";")
		if(!ParamIsDefault(panel))
			panel=StringByKey("PANEL", infostr, "=", ";")
		endif
		if(!ParamIsDefault(param_str))
			SVAR connectionParam=$WBPkgGetName(fullPkgPath, WBPkgDFStr, "connection_param")
			param_str=connectionParam		
		endif
	catch
		Variable err=GetRTError(1)
		print "error when getting information of QDataLink instance ["+num2istr(instance)+"]:"+GetErrMessage(err)
	endtry
End

Function qdl_update_instance_info(Variable instance, String name, String notes, String connection, [String param_str, String panel])
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName, instance=instance)
		String infoStr=WBPkgGetInfoString(QDLPackageName, instance=instance)
		String overall_info=WBPkgGetInfoString(QDLPackageName)
		
		infoStr=ReplaceStringByKey("NAME", infoStr, name, "=", ";")
		infoStr=ReplaceStringByKey("NOTE", infoStr, notes, "=", ";")
		infoStr=ReplaceStringByKey("CONNECTION", infoStr, connection, "=", ";")
		if(!ParamIsDefault(panel))
			infoStr=ReplaceStringByKey("PANEL", infoStr, panel, "=", ";")
		endif
		
		WBPkgSetInfoString(QDLPackageName, infostr, instance=instance)
		
		if(!ParamIsDefault(param_str))
			SVAR connectionParam=$WBPkgGetName(fullPkgPath, WBPkgDFStr, "connection_param")
			connectionParam=param_str
		endif

//overall_info contains the record of all active connections, and the cross reference 
//between these connections and the instance number.
// for example: "ACTIVE_INSTANCES=0,3;0=ASRL3::INSTR;3=ASRL5::INSTR;ASRL3::INSTR=0;ASRL5::INSTR=3"
		overall_info=ReplaceStringByKey(connection, overall_info, num2istr(instance), "=", ";", 1)
		overall_info=ReplaceStringByKey(num2istr(instance), overall_info, connection, "=", ";", 1)
		WBPkgSetInfoString(QDLPackageName, overall_info)
	catch
		Variable err=GetRTError(1)
		print "error when getting information of QDataLink instance ["+num2istr(instance)+"]:"+GetErrMessage(err)
	endtry
End


//print out description of the error associated with status. viObject set to 0 if the error is about the session
ThreadSafe Function QDLPrintVISAError(Variable session, Variable viObject, Variable status)
	String errDesc=""
	//if(status<0)
		if(viObject==0)
			viObject=session
		endif
		viStatusDesc(viObject, status, errDesc)
		printf "VISA error: %s\n", errDesc
	//endif
End

//get a list of VISA supported serial ports
Function /T QDLSerialPortGetList()
	Variable defaultRM, status
	Variable findList, retCnt
	String instrDesc
	String list
		
	list=""
	instrDesc=""
	findList=0
	retCnt=0

	status=viOpenDefaultRM(defaultRM)
	if(status==VI_SUCCESS)
		do
			status=viFindRsrc(defaultRM, "?*", findList, retCnt, instrDesc)
			if(status<0 || retCnt<=0)
				break
			endif
			do
				list+=instrDesc+";"
				retCnt-=1
				if(retCnt>0)
					status=viFindNext(findList, instrDesc)
					if(status<0)
						break
					endif
				endif
			while(retCnt>0)
		while(0)
		if(findList!=0)
			viClose(findList)
		endif
		viClose(defaultRM)
	endif
	
	return list
End



///////////////////////////////////////////////////////////////////////////////
/////QDataLinkVISASerial
///////////////////////////////////////////////////////////////////////////////

Function /T QDLSetVISAConnectionParameters(String configStr, [String name, String notes, Variable timeout, Struct QDLConnectionParam & paramStruct, Variable quiet])
	String newconfigStr=""
	
	if(ParamIsDefault(name))
		name="untitled"
	endif
	if(ParamIsDefault(notes))
		notes="no notes"
	endif
	if(ParamIsDefault(timeout))
		timeout=QDL_DEFAULT_TIMEOUT
	endif
	
	String baudrate_list="600;1200;2400;4800;7200;9600;14400;19200;38400;57600;115200;"
	String baudrate_str=StringByKey("BAUDRATE", configStr, ":", ";")
	if(strlen(baudrate_str)==0 || WhichListItem(baudrate_str, baudrate_list, ";")<0)
		baudrate_str="115200"
	endif	
	PROMPT baudrate_str, "Baud rate", popup baudrate_list

	String databits_list="8;7;6;5;4;"
	String databits_str=StringByKey("DATABITS", configStr, ":", ";")
	if(strlen(databits_str)==0 || WhichListItem(databits_str, databits_list, ";")<0)
		databits_str="8"
	endif
	PROMPT databits_str, "Data bits", popup databits_list

	String stopbits_list="1;1.5;2;"
	String stopbits_str=StringByKey("STOPBITS", configStr, ":", ";")
	if(strlen(stopbits_str)==0 || WhichListItem(stopbits_str, stopbits_list, ";")<0)
		stopbits_str="1"
	endif
	PROMPT stopbits_str, "Stop bits", popup stopbits_list

	String parity_list="None;Odd;Even;Mark;Space;"
	String parity_str=StringByKey("PARITY", configStr, ":", ";")
	if(strlen(parity_str)==0 || WhichListItem(parity_str, parity_list, ";")<0)
		parity_str="None"
	endif
	PROMPT parity_str, "Parity", popup parity_list

	String flowcontrol_list="None;Xon/Xoff;RTS/CTS;Xon/Xoff&RTS/CTS;DTR/DSR;Xon/Xoff&DTR/DSR;"
	String flowcontrol_str=StringByKey("FLOWCONTROL", configStr, ":", ";")
	if(strlen(flowcontrol_str)==0 || WhichListItem(flowcontrol_str, flowcontrol_list, ";")<0)
		flowcontrol_str="None"
	endif
	PROMPT flowcontrol_str, "Flow control", popup flowcontrol_list
	
	variable xon_char=str2num(StringByKey("XONCHAR", configStr, ":", ";"))
	if(NumType(xon_char)!=0 || xon_char<0 || xon_char>255)
		xon_char=0x11
	endif
	PROMPT xon_char, "XON Char"
	
	variable xoff_char=str2num(StringByKey("XOFFCHAR", configStr, ":", ";"))
	if(NumType(xoff_char)!=0 || xoff_char<0 || xoff_char>255)
		xoff_char=0x13
	endif
	PROMPT xoff_char, "XOFF Char"
	
	variable term_char=str2num(StringByKey("TERMCHAR", configStr, ":", ";"))
	if(NumType(term_char)!=0 || term_char<0 || term_char>255)
		term_char=0x0D
	endif
	PROMPT term_char, "Terminal Char (Line feed \\n: 10 (0x0A), Carriage return \\r: 13 (0x0D)"
	
	String endin_list="None;LastBit;TermChar;"
	String endin_str=StringByKey("END_IN", configStr, ":", ";")
	if(strlen(endin_str)==0 || WhichListItem(endin_str, endin_list, ";")<0)
		endin_str="TermChar"
	endif
	PROMPT endin_str, "End mode for reading", popup endin_list
	
	String endout_list="None;LastBit;TermChar;Break;"
	String endout_str=StringByKey("END_OUT", configStr, ":", ";")
	if(strlen(endout_str)==0 || WhichListItem(endout_str, endout_list, ";")<0)
		endout_str="None"
	endif
	PROMPT endout_str, "End mode for writing", popup endout_list

	if(ParamIsDefault(quiet) || quiet==0)
		variable prompt_done=0
		do
			DoPrompt "Set Connection Parameters", baudrate_str, databits_str, stopbits_str, parity_str, flowcontrol_str, xon_char, xoff_char, term_char, endin_str, endout_str
			if (V_flag==0)
				if (xon_char<0 || xon_char>255)
					DoAlert /T="XON Char error" 0, "XON Char must be between 0 and 255."
				elseif (xoff_char<0 || xoff_char>255)
					DoAlert /T="XOFF Char error" 0, "XOFF Char must be between 0 and 255."
				elseif (term_char<0 || term_char>255)
					DoAlert /T="Terminal Char error" 0, "Terminal Char must be between 0 and 255."
				elseif (timeout<0 || timeout>30000)
					DoAlert /T="Timeout value out of range" 0, "Timeout must be between 0 and 30000ms."
				else
					prompt_done=1
				endif			
			else
				break
			endif
		while(prompt_done!=1)
	
		if(prompt_done==1)
			sprintf newconfigStr, "BAUDRATE:%s;DATABITS:%s;STOPBITS:%s;PARITY:%s;FLOWCONTROL:%s;XONCHAR:%d;XOFFCHAR:%d;TERMCHAR:%d;TIMEOUT:%d;END_IN:%s;END_OUT:%s;", baudrate_str, databits_str, stopbits_str, parity_str, flowcontrol_str, xon_char, xoff_char, term_char, timeout, endin_str, endout_str
		else
			newconfigStr=""
		endif
	else
		newconfigStr=configStr
	endif
	if(strlen(newconfigStr)>0 && !ParamIsDefault(paramStruct))
		paramStruct.connection_type=QDL_CONNECTION_TYPE_SERIAL
		paramStruct.baud_rate=str2num(baudrate_str)
		paramStruct.data_bits=str2num(databits_str)
		switch(WhichListItem(stopbits_str, stopbits_list, ";"))
			case 0: //1
				paramStruct.stop_bits=VI_ASRL_STOP_ONE
				break
			case 1: //1.5
				paramStruct.stop_bits=VI_ASRL_STOP_ONE5
				break
			case 2: //2
				paramStruct.stop_bits=VI_ASRL_STOP_TWO
				break
			default:
				Abort "invalid stop bit for serial port configuration."
		endswitch
		paramStruct.parity=WhichListItem(parity_str, parity_list, ";")
			//Constant VI_ASRL_PAR_NONE = 0
			//Constant VI_ASRL_PAR_ODD = 1
			//Constant VI_ASRL_PAR_EVEN = 2
			//Constant VI_ASRL_PAR_MARK = 3
			//Constant VI_ASRL_PAR_SPACE = 4

		paramStruct.flow_control=WhichListItem(flowcontrol_str, flowcontrol_list, ";")
			//combination of several bits
			//Constant VI_ASRL_FLOW_NONE = 0
			//Constant VI_ASRL_FLOW_XON_XOFF = 1
			//Constant VI_ASRL_FLOW_RTS_CTS = 2
			//Constant VI_ASRL_FLOW_DTR_DSR = 4

		paramStruct.xon_char=xon_char
		paramStruct.xoff_char=xoff_char
		paramStruct.term_char=term_char
		paramStruct.end_in=WhichListItem(endin_str, endin_list, ";")
		paramStruct.end_out=WhichListItem(endout_str, endout_list, ";")
			//Constant VI_ASRL_END_NONE = 0
			//Constant VI_ASRL_END_LAST_BIT = 1
			//Constant VI_ASRL_END_TERMCHAR = 2
			//Constant VI_ASRL_END_BREAK = 3
		
		paramStruct.timeout_ms=timeout
		paramStruct.packetbuf_start=0
		paramStruct.packetbuf_end=0
		paramStruct.inbox_request_len=0
		paramStruct.inbox_received_len=0
		paramStruct.outbox_request_len=0
		paramStruct.outbox_retCnt=0
		paramStruct.instance=-1
		paramStruct.status=0
	endif
	
	return newconfigStr
End

//this function will initialize serial port and usb port that is compliant with VISA API
//instrDesc is a string that can be obtained from QDLGetList()
//initParam is a key=value; string that contains initial settings for the connection, or blank, which will
//ask the program to choose default values for different parameters.
//instance_select is a reference to a variable, which in the end will contain the instance number
//of this connection, when everything is ok
//when setting quiet=1, no dialog will be displayed and parameters for connection will be either picked from
//initParam, or as default when missing from there
//for serial connection, three events will be captured: VI_EVENT_SERVICE_REQ, QDL_VI_EVENT_SERIAL_TERMCHAR 
// and QDL_VI_EVENT_SERIAL_CHAR
//for USB connection, two events will be captures: VI_EVENT_SERVICE_REQ, VI_EVENT_USB_INTR
//however, so far we have not successfully demonstrated that USB devices actually trigger these events so 
//we will need additional tests to evaluate this when communicating through VISA USB interface
//the function will return a string, which contains the content of Structure QDLConnectionParam
Function /T QDLInitSerialPort(String instrDesc, String initParam, Variable & instance_select, [Variable quiet, Variable & slot])
	String fullPkgPath=WBSetupPackageDir(QDLPackageName)	
	String retStr=""
	Variable len, retCnt	
	Variable status=0
	Variable instr, attr
	Variable success_flag=0
	instr=0
	Variable init_check_flag=0
	
	Variable threadIDX=-1
	Variable slot_num=-1
	
	//check if resource manager is properly initialized.
	try
		NVAR DefaultRM=$WBPkgGetName(fullPkgPath, WBPkgDFVar, QDLDefaultRMName)
		if(qdl_is_resource_manager_valid(DefaultRM)!=0)
			print "Invalid Default Resource Manager found. Error in initialization."
			AbortOnValue -1, -1
		endif
		//check if the connection is already open
		Variable check_openidx=qdl_is_connection_open(instrDesc)
		if(check_openidx>=0)
			print "Connection "+instrDesc+" is already opened as instance ", check_openidx
			AbortOnValue -1, -1
		endif
		
		slot_num=qdl_reserve_active_slot(threadIDX)
		if(slot_num<0 || threadIDX<0)
			print "Run out of available slots or thread worker for new connections. No further actions."
			AbortOnValue -1, -1
		endif
	
		instance_select=qdl_find_instance_for_connection(instrDesc)
	
		STRUCT QDLConnectionParam cp
		cp.connection_type=QDL_CONNECTION_TYPE_NONE
		String configStr=QDLSetVISAConnectionParameters(initParam, paramStruct=cp, quiet=quiet)
		
		if(strlen(configStr)<=0)
			print "Error or user cancelled the initialization."
			AbortOnValue -1, -1
		endif
		
		cp.name=instrDesc[0, QDL_SERIAL_CONNECTION_NAME_MAXLEN-1]
		cp.name[QDL_SERIAL_CONNECTION_NAME_MAXLEN]=0
		
		init_check_flag=1
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "Error happened when initializing serial port:"+GetErrMessage(err)
		endif
		if(slot_num>0)
			qdl_release_active_slot(slot_num, QDL_DEFAULT_TIMEOUT)
		endif
	endtry

	if(init_check_flag==1 && DefaultRM>0)
		try
			status=viOpen(DefaultRM, instrDesc, 0, 0, instr)
			AbortOnvalue status!=VI_SUCCESS, status
			
			status=viGetAttribute(instr, VI_ATTR_INTF_TYPE, attr)
			AbortOnvalue status!=VI_SUCCESS, status
			
			switch(attr)
			case VI_INTF_ASRL:
				status=viSetAttribute(instr, VI_ATTR_ASRL_BAUD, cp.baud_rate)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_DATA_BITS, cp.data_bits)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_STOP_BITS, cp.stop_bits)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_PARITY, cp.parity)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_FLOW_CNTRL, cp.flow_control)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_XON_CHAR, cp.xon_char)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_XOFF_CHAR, cp.xoff_char)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_TERMCHAR, cp.term_char)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_END_IN, cp.end_in)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viSetAttribute(instr, VI_ATTR_ASRL_END_OUT, cp.end_out)
				AbortOnvalue status!=VI_SUCCESS, status
				if(cp.term_char>0)
					status=viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, VI_TRUE)
				else
					status=viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, VI_FALSE)
				endif
				AbortOnvalue status!=VI_SUCCESS, status
								
				status=viClear(instr)
				AbortOnvalue status!=VI_SUCCESS, status
				//status=viEnableEvent(instr, VI_EVENT_SERVICE_REQ, VI_QUEUE, 0)
				//AbortOnvalue status!=VI_SUCCESS, status
				status=viEnableEvent(instr, QDL_VI_EVENT_SERIAL_TERMCHAR, VI_QUEUE, 0)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viEnableEvent(instr, QDL_VI_EVENT_SERIAL_CHAR, VI_QUEUE, 0)
				AbortOnvalue status!=VI_SUCCESS, status
				cp.byte_at_port_check_flag=1
				cp.instr=instr
				cp.connection_type=QDL_CONNECTION_TYPE_SERIAL
				cp.starttime_ms=0
				cp.inbox_attempt_count=0
				cp.outbox_attempt_count=0
				success_flag=1
				break
			case VI_INTF_USB:
				print "Warning: this is a USB VISA interface. Will initialize with minimal default attributes."
				if(cp.term_char>0)
					status=viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, VI_TRUE)
					print "setting VI_ATTR_TERMCHAR_CN to VI_TRUE"
				else
					status=viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, VI_FALSE)
					print "setting VI_ATTR_TERMCHAR_CN to VI_FALSE"
				endif
				AbortOnvalue status!=VI_SUCCESS, status
				
				status=viSetAttribute(instr, VI_ATTR_TERMCHAR, cp.term_char)
				print "setting VI_ATTR_TERMCHAR to "+num2str(cp.term_char)
				AbortOnvalue status!=VI_SUCCESS, status
				
				if(cp.end_out==2) //send end on writes
					status=viSetAttribute(instr, VI_ATTR_SEND_END_EN, VI_TRUE)
					print "setting VI_ATTR_SEND_END_EN to VI_TRUE"
				else
					status=viSetAttribute(instr, VI_ATTR_SEND_END_EN, VI_FALSE)
					print "setting VI_ATTR_SEND_END_EN to VI_FALSE"
				endif
				AbortOnvalue status!=VI_SUCCESS, status
				
				status=viClear(instr)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viEnableEvent(instr, VI_EVENT_SERVICE_REQ, VI_QUEUE, 0)
				AbortOnvalue status!=VI_SUCCESS, status
				status=viEnableEvent(instr, VI_EVENT_USB_INTR, VI_QUEUE, 0)
				AbortOnValue status!=VI_SUCCESS, status

				cp.byte_at_port_check_flag=0
				cp.instr=instr
				cp.connection_type=QDL_CONNECTION_TYPE_USB	
				cp.starttime_ms=0
				cp.inbox_attempt_count=0
				cp.outbox_attempt_count=0
				success_flag=1
				break
			default:
				print "Unknonwn interface type: "+num2istr(attr)+". Do not know how to initialize."
				break
			endswitch			
		catch
			print "Error when initializing serial port."
			print "Runtime error: ", GetRTErrMessage(), GetRTError(1)
			if(instr!=0)
				QDLPrintVISAError(instr, 0, status)
				viClose(instr)
			endif
		endtry
	endif
	
	if(success_flag==1)
	
		DFREF saved_dfr=GetDataFolderDFR()
		
		try
			String instancePath
			String instancePrivatePath
			
			if(instance_select==WBPkgNewInstance)
				instancePath=WBSetupPackageDir(QDLPackageName, instance=instance_select, init_request=1)

				WBPrepPackageVars(instancePath, QDLSerialInstanceVarList)
				WBPrepPackageStrs(instancePath, QDLSerialInstanceStrList)
			else
				instancePath=WBSetupPackageDir(QDLPackagename, instance=instance_select)

			endif

			SetDataFolder $(instancePath); AbortOnRTE
			NVAR connection_active=:vars:connection_active
			NVAR count=:vars:count
			NVAR req_readlen=:vars:request_read_len
			NVAR req_writelen=:vars:request_write_len
			SVAR param_str=:strs:connection_param
			SVAR callback_func=:strs:callback_func
			SVAR inbox=:strs:inbox_str
			SVAR outbox=:strs:outbox_str

			connection_active=1
			count=0
			req_readlen=0
			req_writelen=0
			callback_func=""
			inbox=""
			outbox=""
			StructPut /S cp, param_str //update the parameter stored in the instance string folder
			retStr=param_str

			if(0 > qdl_set_active_slot(slot_num, startThreadIDX=threadIDX, instance=instance_select, \
														connection_param=param_str, inbox="", outbox="", \
														auxparam="", auxret="", rt_callback_func="", \
														post_callback_func="", request=0, status=0, \
														connection_type=cp.connection_type))
				AbortOnValue -1, -1
			endif
			
			qdl_update_instance_info(instance_select, "Untitled", "No notes", instrDesc)
			if(!ParamIsDefault(slot))
				slot=slot_num
			endif
			print "VISA serial port initialization succeeded for instance "+num2istr(instance_select)
		catch
			print "Error when trying to clean up the package datafolder for instance ", instance_select
			print "Will now close the serial port."
			if(slot_num>=0 && slot_num<QDL_MAX_CONNECTIONS)
				qdl_release_active_slot(slot_num, QDL_DEFAULT_TIMEOUT)
				qdl_clear_active_slot(slot_num)
			endif
			viClose(instr)		
		endtry
		
		SetDataFolder saved_dfr
	else
		if(slot_num>=0 && slot_num<QDL_MAX_CONNECTIONS)
			qdl_release_active_slot(slot_num, QDL_DEFAULT_TIMEOUT)
			qdl_clear_active_slot(slot_num)
		endif
	endif
	return retStr
End

Function QDLCloseSerialPort([String instrDesc, Variable instance])
	Variable instance_select=-1
	
	if(!ParamIsDefault(instance))
		instance_select=instance
	elseif(!ParamIsDefault(instrDesc))
		Variable openidx=qdl_is_connection_open(instrDesc)
		if(openidx>=0)
			instance_select=openidx
		endif
	endif
	
	if(instance_select>=0)
		DFREF dfr=GetDataFolderDFR()
		try
			String fullPkgPath=WBSetupPackageDir(QDLPackageName)
			SetDataFolder $fullPkgPath; AbortOnRTE
			WAVE /T active_instance_record=:waves:active_instance_record
			Variable i
			for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
				if(str2num(StringByKey("INSTANCE", active_instance_record[i]))==instance_select)
					print "Releasing active slot "+num2istr(i)+" ..."
					qdl_release_active_slot(i, 5000); AbortOnRTE
					qdl_clear_active_slot(i); AbortOnRTE
					break
				endif
			endfor
	
			String instance_folder=WBSetupPackageDir(QDLPackageName, instance=instance_select)
			SetDataFolder $instance_folder; AbortOnRTE
			NVAR connection_active=:vars:connection_active
			connection_active=0; AbortOnRTE
			SVAR param=:strs:connection_param; AbortOnRTE
			STRUCT QDLConnectionParam cp; AbortOnRTE
			StructGet /S cp, param; AbortOnRTE
			Variable status=viClose(cp.instr); AbortOnRTE
			AbortOnValue status!=VI_SUCCESS, -1
		catch
			Variable err=GetRTError(1)
			if(err!=0)
				print "Error when closing connection instance ["+num2istr(instance_select)+"]:"+GeterrMessage(err)
			endif
		endtry
		SetDataFolder dfr
	else
		print "No such connection is found to be active. No action taken."
	endif
End

//ThreadSafe Function qdl_VISALock(Variable instr, Variable timeout)
//	String tmpKeyin=""
//	String tmpKeyout=""
//	
//	Variable status=viLock(instr, VI_EXCLUSIVE_LOCK, timeout, tmpKeyin, tmpKeyout)
//	if(status!=VI_SUCCESS && status!=VI_SUCCESS_NESTED_EXCLUSIVE)
//		print "Error when locking VISA device: ", instr, status
//		QDLPrintVISAError(instr, 0, status)
//		return -1
//	endif
//	return 0
//End
//
//ThreadSafe Function qdl_VISAunLock(Variable instr)
//	Variable status=viUnlock(instr)
//	if(status!=VI_SUCCESS  && status!=VI_SUCCESS_NESTED_EXCLUSIVE)
//		print "Error when unlocking VISA device: ", instr
//		QDLPrintVISAError(instr, 0, status)
//		return -1
//	endif
//	return 0
//End

//This function will be called by the thread handling the specific instance
//the thread will be called by the qdl_thread_request_handler in QDataLinkCore.ipf
//the thread should not run in loops, but rather assume that it will not finish the whole
//job in one run, and will need to keep its state for the next call from qdl_thread_request_handler
//to continue the work.
//return nonzero value will terminate the thread
//the thread will first see if there is writing request (while previous reading is not still in progress)
//if so, will write the content in the outbox
//next will see if a read request is present
//if so, will try to read section by section until termination/timeout/specific length is satisified
ThreadSafe Function qdl_thread_serialport_req(STRUCT QDLConnectionparam & cp, Variable slot, 
															WAVE req, WAVE stat, WAVE connection_type,
															WAVE /T inbox, WAVE /T outbox,
															WAVE /T auxparam, WAVE /T auxret, 
															FUNCREF qdl_rtfunc_prototype rtcallbackfunc_ref)
	Variable retVal=0
	Variable status=0
	
	if(cp.connection_type!=(connection_type[slot] & QDL_CONNECTION_TYPE_MASK) || \
			(cp.connection_type!=QDL_CONNECTION_TYPE_SERIAL && \
			cp.connection_type!=QDL_CONNECTION_TYPE_USB))
		return -1
	endif
	
	try
		Variable timeout=cp.timeout_ms
		Variable instr=cp.instr
		Variable retCnt
		Variable current_time=StopMSTimer(-2)/1000 // in ms
		
		if((req[slot] & QDL_REQUEST_STATE_MASK) == 0) //initial read/write request
			cp.starttime_ms=current_time //setting start time of this request
			cp.inbox_attempt_count=0
			cp.outbox_attempt_count=0
		endif
		
		AbortOnValue (cp.instance<0 || cp.instance>=QDL_MAX_CONNECTIONS || instr<=0), -1
		
		if(!(req[slot] & (QDL_REQUEST_READ_BUSY | QDL_REQUEST_WRITE_BUSY)) && (req[slot] & QDL_REQUEST_CLEAR_BUFFER))
			status=viDiscardEvents(instr, VI_ALL_ENABLED_EVENTS, VI_QUEUE)
			if(status!=VI_SUCCESS && status!=VI_SUCCESS_QUEUE_EMPTY)
#if defined(DEBUG_QDLVISA_3)
				print "viDiscardEvents returned status: "+num2istr(status)
#endif
			endif
			status=viClear(instr)
			req[slot] = req[slot] & (~ QDL_REQUEST_CLEAR_BUFFER)
#if defined(DEBUG_QDLVISA_3)
			print "viClear status:", num2istr(status)
#endif
			AbortOnValue status!=VI_SUCCESS, -1
		endif
		if(!(req[slot] & QDL_REQUEST_READ_BUSY)) //request for writing comes before reading, but not in the middle of it
			if((req[slot] & QDL_REQUEST_WRITE) && !(req[slot] & QDL_REQUEST_WRITE_COMPLETE))
				
				if(!(req[slot] & QDL_REQUEST_WRITE_BUSY))
					req[slot] =req[slot] | QDL_REQUEST_WRITE_BUSY
					cp.outbox_request_len=strlen(outbox[slot])
				endif
				
				current_time=StopMSTimer(-2)/1000
				if(current_time-cp.starttime_ms >= cp.timeout_ms)
					req[slot] = (req[slot] & (~(QDL_REQUEST_WRITE | QDL_REQUEST_WRITE_BUSY))) \
										| QDL_REQUEST_WRITE_COMPLETE | QDL_REQUEST_WRITE_ERROR | QDL_REQUEST_TIMEOUT
				endif
				retCnt=0
				
				if(qdl_is_connection_callable(connection_type, slot)) //make sure not in a transition or ending time
					status=viWrite(instr, outbox[slot], cp.outbox_request_len, retCnt)
					if(status!=VI_SUCCESS)
						cp.outbox_attempt_count+=1
						stat[slot]=status
						cp.outbox_retCnt=0
						if(cp.outbox_attempt_count>5)
							req[slot] = (req[slot] & (~(QDL_REQUEST_WRITE | QDL_REQUEST_WRITE_BUSY))) \
											| QDL_REQUEST_WRITE_COMPLETE | QDL_REQUEST_WRITE_ERROR | QDL_REQUEST_TIMEOUT
						endif
#if defined(DEBUG_QDLVISA_1)
						print "viWrite error."
						print "viWrite status:", num2istr(status)
#endif
						AbortOnValue -1, -4
					else
						cp.outbox_retCnt=retCnt
						req[slot] = (req[slot] & (~(QDL_REQUEST_WRITE | QDL_REQUEST_WRITE_BUSY))) \
										| QDL_REQUEST_WRITE_COMPLETE
#if defined(DEBUG_QDLVISA_3)
						print "viWrite sent :"+outbox[slot]
						print "viWrite sent length:", retCnt
						print "viWrite status:", num2istr(status)
#endif
					endif
				endif
			endif
		endif
		
		Variable read_complete_flag=0
		
		if((req[slot] & QDL_REQUEST_READ) && !(req[slot] & QDL_REQUEST_WRITE_BUSY))
			if(!(req[slot] & QDL_REQUEST_READ_BUSY)) //first time receiving something
				req[slot] = req[slot] | QDL_REQUEST_READ_BUSY
				if(cp.inbox_request_len<=0)
					cp.inbox_request_len=QDL_MAX_BUFFER_LEN
				endif
				inbox[slot]=""
				cp.inbox_received_len=0
			else
				if(connection_type[slot] & QDL_CONNECTION_NO_TIMEOUT == 0)
					current_time=StopMSTimer(-2)/1000
					if((current_time-cp.starttime_ms)>=cp.timeout_ms)
						req[slot] = (req[slot] & (~ (QDL_REQUEST_READ | QDL_REQUEST_READ_BUSY))) \
								| QDL_REQUEST_TIMEOUT | QDL_REQUEST_READ_COMPLETE
#if defined(DEBUG_QDLVISA_2)
						print "VISA read timed out:", current_time-cp.starttime_ms, cp.timeout_ms
#endif
					endif
				endif
			endif
			
			if(qdl_is_connection_callable(connection_type, slot) && !(req[slot] & QDL_REQUEST_READ_COMPLETE))
				Variable termChar
				status=viGetAttribute(instr, VI_ATTR_TERMCHAR, termChar)
				AbortOnValue status!=VI_SUCCESS, -8			
	
				Variable outEventType, outContext=VI_NULL
				status=viWaitOnEvent(instr, VI_ALL_ENABLED_EVENTS, QDL_EVENT_POLLING_TIMEOUT, outEventType, outContext)
				
				if(status==VI_WARN_QUEUE_OVERFLOW)
					viDiscardEvents(instr, VI_ALL_ENABLED_EVENTS, VI_QUEUE)
					status=VI_SUCCESS_QUEUE_NEMPTY
				endif
				
				if(outContext!=VI_NULL)
					viClose(outContext)
				endif

				Variable bytes_at_port=0
				
				if(cp.byte_at_port_check_flag==1)
					status=viGetAttribute(instr, VI_ATTR_ASRL_AVAIL_NUM, bytes_at_port)
					AbortOnvalue status!=VI_SUCCESS, -6
				else
					if(status==VI_SUCCESS || status==VI_SUCCESS_QUEUE_NEMPTY)
#if defined(DEBUG_QDLVISA_3)
						print "viWaitOnEvent returned success:"+num2istr(outEventType)
#endif
						bytes_at_port=QDL_MAX_BUFFER_LEN
					elseif(status==VI_ERROR_TMO)
						bytes_at_port=0
					else
#if defined(DEBUG_QDLVISA_1)
				print "viWaitOnEvent returned unknown status: ", num2istr(status)
#endif
						bytes_at_port=0
					endif
				endif
				
				if(bytes_at_port>0)
					Variable packetSize					
					if(cp.byte_at_port_check_flag==1)
						packetSize=QDL_SERIAL_PACKET_BUF_SIZE
						String receivedStr=""
						
						if(cp.inbox_request_len>0)
							packetSize=cp.inbox_request_len-cp.inbox_received_len
						endif
						if(packetSize>QDL_SERIAL_PACKET_BUF_SIZE)
							packetSize=QDL_SERIAL_PACKET_BUF_SIZE
						endif
						if(cp.byte_at_port_check_flag==1)
							if(packetSize>bytes_at_port)
								packetSize=bytes_at_port
							endif
						endif
					else
						packetSize=bytes_at_port
					endif
					
					retCnt=0
					if(packetSize>0)	
						status=viRead(instr, receivedStr, packetSize, retCnt)	
						if(retCnt>0)
#if defined(DEBUG_QDLVISA_3)
							print "viRead get message: ", receivedStr
							print "viRead length:", retCnt
							print "viRead status:", num2istr(status)
#endif
							Variable i, termflag=0
							for(i=0; i<retCnt; i+=1)
								if(char2num(receivedStr[i])==termChar)
									termflag=1
									read_complete_flag=1
									break
								endif
							endfor
							if(termflag==1)			
								if(i+1!=retCnt)
									print "terminal char detected in the middle of received string."
									print "event :"+num2istr(outEventType)									
									print "status:"+num2istr(status)
									print "position of termChar:"+num2istr(i)
									print "retCnt of the packet received:"+num2istr(retCnt)
									print "warning: this case is not well handled. the rest of the string will be lost in the next reading"
								endif
							endif
							cp.inbox_received_len+=i+1
							inbox[slot]+=receivedStr[0,i]
						endif
					endif
					
					if(cp.inbox_request_len>0 && cp.inbox_received_len>=cp.inbox_request_len)
						read_complete_flag=1
					endif
					
					if(read_complete_flag)
						req[slot] = (req[slot] & (~(QDL_REQUEST_READ | QDL_REQUEST_READ_BUSY))) \
										 | QDL_REQUEST_READ_COMPLETE
#if defined(DEBUG_QDLVISA_3)
						print "read request completed."
						print "request status:", num2istr(req[slot])
#endif
					endif
					
				endif //event arrived
			endif //read not complete?
		endif
		if(qdl_is_connection_callable(connection_type, slot))
			if((req[slot] & QDL_REQUEST_READ_COMPLETE) || (req[slot] & QDL_REQUEST_WRITE_COMPLETE))
				if(!(req[slot] & QDL_CONNECTION_RTCALLBACK_SUSPENSE))
					rtcallbackfunc_ref(0, slot=slot, cp=cp, request=req, status=stat, inbox=inbox, outbox=outbox, param=auxparam, auxret=auxret)
				endif
			endif
		endif
	catch
		print "RunTime error: ", GetRTError(1), GetRTErrMessage()
		print "VISA status code: "+num2istr(status)
		QDLPrintVISAError(instr, 0, status)
		retVal=-1
	endtry

	return retVal
End

