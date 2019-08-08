#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink

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

ThreadSafe Function qdl_rtfunc_prototype(Variable inittest, [Variable slot, STRUCT QDLConnectionParam & cp, WAVE request, WAVE status, WAVE /T inbox, WAVE /T outbox, WAVE /T param, WAVE /T auxret])
	if(inittest==1)
		return 0
	endif
	return 0
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

Function qdl_postfix_callback_prototype(Variable instance, Variable slot, Variable dfr_received, DFREF dfr)
	return 0
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
	try
		SetDataFolder $fullPkgPath; AbortOnRTE
		NVAR threadGroupID=:vars:threadGroupID
		WAVE /T post_callback_func=:waves:post_callback_func_list
		WAVE /T active_instance_record=:waves:active_instance_record
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
				NVAR instance=dfr:instance; AbortOnRTE
				NVAR slot=dfr:slot; AbortOnRTE
				if(NVAR_Exists(instance) && NVAR_Exists(slot))
					if(slot>=0 && slot<QDL_MAX_CONNECTIONS)
						if(str2num(StringByKey("INSTANCE", active_instance_record[slot]))==instance)
							FUNCREF qdl_postfix_callback_prototype callback_ref=$(post_callback_func[slot])
							if(str2num(StringByKey("ISPROTO", FuncRefInfo(callback_ref)))==0)
								callback_ref(instance, slot, 1, dfr); err=GetRTError(1) //call user function for processing data
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
				Variable inst=str2num(StringByKey("INSTANCE", active_instance_record[slot]))			
				if(numtype(inst)==0 && strlen(post_callback_func[i])>0)
					FUNCREF qdl_postfix_callback_prototype callback_ref=$(post_callback_func[i])
					if(str2num(StringByKey("ISPROTO", FuncRefInfo(callback_ref)))==0)
						//call user function for maintenance when no data have arrived
						//user function should be quick and collaborative to handle this
						callback_ref(inst, i, 0, NULL); err=GetRTError(1)
					endif
				endif
			catch
				err=GetRTError(1)
			endtry
		endfor
		
	catch
		err=GetRTError(1)
	endtry
	
	SetDataFolder old_dfr	
	return 0
End

