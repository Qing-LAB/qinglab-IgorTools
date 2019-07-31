#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

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
				variable freethreadid=ThreadGroupWait(threadGroupID, 0); AbortOnRTE
			catch
				err=GetRTError(1)
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
				QDLSerialPortPrintError(RM, 0, status) 
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
	catch
		err=GetRTError(1)
		print "Error initializing QDataLink package: "+GeterrMessage(err)
	endtry
	return RM
End

ThreadSafe Function qdl_dummy_thread_worker_init(Variable i)
	return 0
End

Function QDLGetSlot(Variable instance)
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

Function /T QDLQuery(Variable slot, String send_msg, Variable expect_response, [Variable instance, String &receive_msg, 
						String realtime_func, String postfix_func, String auxparam, Variable timeout])
	String response=""
	String fullPkgPath=WBSetupPackageDir(QDLPackageName)
	DFREF dfr=GetDataFolderDFR()
	SetDataFolder $fullPkgPath
	
	if(ParamIsDefault(timeout))
		timeout=QDL_DEFAULT_TIMEOUT
	endif
	
	try
		WAVE /T instance_record=:waves:active_instance_record
		WAVE /T rtfunc_record=:waves:rt_callback_func_list
		WAVE /T postfixfunc_record=:waves:post_callback_func_list
		WAVE /T param_record=:waves:auxparam_all
		WAVE /T auxret_record=:waves:auxret_all
		WAVE /T inbox=:waves:inbox_all
		WAVE /T outbox=:waves:outbox_all
		WAVE request_record=:waves:request_record
		WAVE status_record=:waves:status_record
		WAVE connection_info=:waves:connection_type_info
		
		if(!ParamIsDefault(instance))
			if(str2num(StringByKey("INSTANCE", instance_record[slot]))!=instance)
				print "QDLQuery has inconsistent record of slot ["+num2istr(slot)+"] and instance ["+num2istr(instance)+"]"
				AbortOnValue -1, -1
			endif
		else
			instance=str2num(StringByKey("INSTANCE", instance_record[slot]))
		endif

		if(slot<QDL_MAX_CONNECTIONS)
			Variable update_func_flag=0
			Variable request_read=0
			Variable request_write=0			
			Variable start_time, current_time
			
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
			else
				param_record[slot]=""; AbortOnRTE
			endif
			if(update_func_flag==1)
				start_time=StopMSTimer(-2)/1000; AbortOnRTE
				auxret_record[slot]=""
				connection_info[slot]=connection_info[slot]|QDL_CONNECTION_ATTACH_FUNC
				if(timeout>0)
					do //waiting for the thread to answer to request of updating user functions
						Sleep /T 1
						DoUpdate; AbortOnRTE
						current_time=StopMSTimer(-2)/1000; AbortOnRTE
					while((current_time-start_time<timeout) && (connection_info[slot] & QDL_CONNECTION_ATTACH_FUNC))
				
					if(connection_info[slot] & QDL_CONNECTION_ATTACH_FUNC)
						print "Warning: timeout when trying to attach user defined function to instance "+num2istr(instance)
					endif
				else
					Sleep /T 1
					DoUpdate
				endif
			endif
			
			if(strlen(send_msg)>0)
				request_write=1
				outbox[slot]=send_msg; AbortOnRTE
			endif
			if(expect_response)
				request_read=1
				inbox[slot]=""; AbortOnRTE
			endif
			Variable request_flag=0; AbortOnRTE
			Variable response_flag=0
			if(request_write)
				request_flag=request_flag|QDL_REQUEST_WRITE; AbortOnRTE
				response_flag=QDL_REQUEST_WRITE_COMPLETE; AbortOnRTE
			endif
			if(request_read)
				request_flag=request_flag|QDL_REQUEST_READ; AbortOnRTE
				response_flag=QDL_REQUEST_READ_COMPLETE; AbortOnRTE
			endif
			
			request_record[slot]=request_flag; AbortOnRTE
			if(timeout>0)
				start_time=StopMSTimer(-2)/1000; AbortOnRTE
				do
					Sleep /T 1
					DoUpdate; AbortOnRTE
					current_time=StopMSTimer(-2)/1000; AbortOnRTE
				while((current_time-start_time<timeout) && !(request_record[slot] & response_flag))
				if(request_record[slot] & QDL_REQUEST_READ_COMPLETE)
					response=inbox[slot]
					if(!ParamIsDefault(receive_msg))
						receive_msg=response
					endif
				endif
			endif
		endif		
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "Error when query from instance "+num2istr(instance)+": "+GetErrMessage(err)
		endif
	endtry
	
	SetDataFolder dfr
	return response
End

ThreadSafe Function qdl_rtfunc_prototype(Variable inittest, [Variable slot, STRUCT QDLConnectionParam & cp, WAVE request, WAVE status, WAVE /T inbox, WAVE /T outbox, WAVE /T param, WAVE /T auxret])
	if(inittest==1)
		return 0
	endif
	return 0
End

ThreadSafe Function qdl_retrieve_funcref(String funcname, WAVE /T funcname_list, Variable slot, FUNCREF qdl_rtfunc_prototype & ref)
	FUNCREF qdl_rtfunc_prototype ref=qdl_rtfunc_prototype
	print "User requested to attach function ["+funcname+"] to QDataLink slot "+num2istr(slot)
	if(strlen(funcname)>0)
		FUNCREF qdl_rtfunc_prototype ref=$(funcname)
		try
			ref(1); AbortOnRTE
		catch
			Variable err=GetRTError(1)
			print "User defined real-time callback function failed init test for slot "+num2istr(slot)
			print "No user defined real-time will be called."
			FUNCREF qdl_rtfunc_prototype ref=qdl_rtfunc_prototype
		endtry
	endif
	String update_funcname=StringByKey("NAME", FuncRefInfo(ref))
	if(strlen(update_funcname)<=0)
		update_funcname="qdl_rtfunc_prototype"
		FUNCREF qdl_rtfunc_prototype ref=$(update_funcname)
	endif
	funcname_list[slot]=update_funcname
	print "New real-time callback function ["+update_funcname+"] attached to slot "+num2istr(slot)
End

ThreadSafe Function qdl_thread_request_handler(Variable slot, Variable threadIDX, WAVE request, WAVE status, 
																WAVE connection_type, WAVE /T active_instances, 
																WAVE /T connection_param, WAVE /T inbox, 
																WAVE /T outbox, WAVE /T rt_callback_func, 
																WAVE /T auxparam, WAVE /T auxret, WAVE thread_record)
	if(slot<0 || slot >= QDL_MAX_CONNECTIONS)
		return -1
	endif
	
	if(thread_record[threadIDX]!=slot)
		print "Thread "+num2istr(threadIDX)+" should be registered to slot "+num2istr(thread_record[threadIDX])+", but instead slot "+num2istr(slot)+" is attached."
		print "Thread worker will quit due to inconsistency."
	endif
	
	STRUCT QDLConnectionparam cp
	cp.connection_type=QDL_CONNECTION_TYPE_NONE
	
	Variable cp_init=0
	String cp_str=""
	if(strlen(connection_param[slot])>0)
		StructGet /S cp, connection_param[slot]
		cp_init=1
	endif
	
	FUNCREF qdl_rtfunc_prototype rtcallbackfunc_ref=qdl_rtfunc_prototype
	
	String rtcallbackfunc_name=rt_callback_func[slot]
	qdl_retrieve_funcref(rtcallbackfunc_name, rt_callback_func, slot, rtcallbackfunc_ref)
	
	Variable retVal=0	
	do
		try
			if((connection_type[slot] & QDL_CONNECTION_QUITTING) !=0)
				retVal=-99
			else
				if((connection_type[slot] & QDL_CONNECTION_ATTACH_FUNC)!=0)
					rtcallbackfunc_name=rt_callback_func[slot]
					qdl_retrieve_funcref(rtcallbackfunc_name, rt_callback_func, slot, rtcallbackfunc_ref)
					connection_type[slot] = connection_type[slot] & (~ QDL_CONNECTION_ATTACH_FUNC)
				endif
				
				switch(connection_type[slot] & QDL_CONNECTION_TYPE_MASK)
				case QDL_CONNECTION_TYPE_SERIAL:
				case QDL_CONNECTION_TYPE_USB:
					if((connection_type[slot] & QDL_CONNECTION_QUITTING)==0) //no request to quit yet
						retVal=qdl_thread_serialport_req(cp, slot, request, status, connection_type, \
																	inbox, outbox, auxparam, auxret, \
																	rtcallbackfunc_ref)
					endif
					break
				default:
					retVal=-1
				endswitch
			endif
		catch
			Variable err=GetRTError(1)
			print "Error happened for thread worker of QDataLink slot "+num2istr(slot)+": "+GetErrMessage(err)
		endtry
		if(cp_init)
			StructPut /S cp, cp_str
			connection_param[slot]=cp_str
		endif
		Sleep /T 1
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
	String fullPkgCommonPath=WBSetupPackageDir(QDLPackageName)
	WAVE /T param_name_records=$WBPkgGetName(fullPkgCommonPath, WBPkgDFWave, StringFromList(0, QDLParamAndDataRecord))
	WAVE /T inbox_all=$WBPkgGetName(fullPkgCommonPath, WBPkgDFWave, StringFromList(1, QDLParamAndDataRecord))
	WAVE /T outbox_all=$WBPkgGetName(fullPkgCommonPath, WBPkgDFWave, StringFromList(2, QDLParamAndDataRecord))
	WAVE request_records=$WBPkgGetName(fullPkgCommonPath, WBPkgDFWave, StringFromList(0, QDLStatusRecord))
	WAVE status_records=$WBPkgGetName(fullPkgCommonPath, WBPkgDFWave, StringFromList(1, QDLStatusRecord))
	Make /FREE /N=(QDL_MAX_CONNECTIONS) tmp_retVals, tmp_connection_types
	Make /FREE /T /N=(QDL_MAX_CONNECTIONS) tmp_params
	Variable i
	
	String inboxname, outboxname
	
	for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
		if(strlen((param_name_records[i]))>1)
			SVAR paramstr=$((param_name_records[i])[1,inf])
			if(SVAR_Exists(paramstr))			
				tmp_connection_types[i]=str2num((param_name_records[i])[0,0])							
				//debug sending request begin
				STRUCT QDLConnectionParam cp
				StructGet /S cp, paramstr
				if(!(request_records[i] & QDL_REQUEST_READ) && !(request_records[i] & QDL_REQUEST_READ_BUSY) && !(request_records[i] & QDL_REQUEST_READ_COMPLETE))
					SVAR cmd=root:cmd
					SVAR addcmd=root:addcmd
					outbox_all[i]=cmd
					inbox_all[i]=""			
					
					if(strlen(addcmd)>0)
						outbox_all[i]+=addcmd
						addcmd=""
						print "special cmd updated:"+outbox_all[i]
					endif
					cp.outbox_request_len=strlen(outbox_all[i])
					request_records[i]=QDL_REQUEST_READ | QDL_REQUEST_WRITE
					StructPut /S cp, paramstr
					//print "request submitted."
				endif				
				//debug sending request end
			
				tmp_params[i]=paramstr
			else
				tmp_params[i]=""
				tmp_connection_types[i]=-1
			endif
		else
			tmp_params[i]=""
			tmp_connection_types[i]=-1
		endif
	endfor
	
//	multithread tmp_retVals=qdl_request_handler(p, tmp_connection_types, tmp_params, request_records, status_records, outbox_all, inbox_all)

	for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
		if(tmp_connection_types[i]>0)
			SVAR paramstr=$((param_name_records[i])[1,inf])
			
			//debug query begin
			StructGet /S cp, tmp_params[i]
			if(request_records[i] & QDL_REQUEST_READ_COMPLETE)
				process_data(inbox_all[i])
				request_records[i] = 0
			endif
			//debug query end
			
			paramstr=tmp_params[i] //update the parameter records of each active connection
		endif
	endfor

	return 0
End

