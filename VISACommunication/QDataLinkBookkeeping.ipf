#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink

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
	
	if(ParamIsDefault(quiet) || quiet==0)
		print "User requested to attach function ["+funcname+"] to QDataLink slot "+num2istr(slot)
	endif
	if(strlen(funcname)>0)
		FUNCREF qdl_rtfunc_prototype ref=$(funcname)
		try
			ref(1); AbortOnRTE
		catch
			Variable err=GetRTError(1)
			if(ParamIsDefault(quiet) || quiet==0)
				print "User defined real-time callback function failed init test for slot "+num2istr(slot)
				print "No user defined real-time will be called."
			endif
			FUNCREF qdl_rtfunc_prototype ref=qdl_rtfunc_prototype
		endtry
	endif
	String update_funcname=StringByKey("NAME", FuncRefInfo(ref))
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

