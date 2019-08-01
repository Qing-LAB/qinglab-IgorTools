#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink

//this function will take parameters from configStr to set up a proper dialog for the user to
//confirm the parameters for the serial connection.
//if the item is not present in configStr, default values will be used.
//if quiet set to 1, no dialog will be presented, but extracted parameters and/or default values will be
//used to set up the connection
//resulting parameters will be stored to paramStruct, if this is not left blank
//the function will return a key=value; string that contains all the parameters set by this function
//names gives the connection name
//notes gives a user note for the connection
//timeout for connection timeout

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
	String endout_str=StringByKey("END_IN", configStr, ":", ";")
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
			sprintf newconfigStr, "BAUDRATE:%s;DATABITS:%s;STOPBITS:%s;PARITY:%s;FLOWCONTROL:%s;XONCHAR:%d;XOFFCHAR:%d;TERMCHAR:%d;TIMEOUT:%d", baudrate_str, databits_str, stopbits_str, parity_str, flowcontrol_str, xon_char, xoff_char, term_char, timeout
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

			SetDataFolder $(instancePath)
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
			SetDataFolder $fullPkgPath
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

ThreadSafe Function qdl_VISALock(Variable instr, Variable timeout)
	String tmpKeyin=""
	String tmpKeyout=""
	
	Variable status=viLock(instr, VI_EXCLUSIVE_LOCK, timeout, tmpKeyin, tmpKeyout)
	if(status!=VI_SUCCESS && status!=VI_SUCCESS_NESTED_EXCLUSIVE)
		print "Error when locking VISA device: ", instr, status
		QDLPrintVISAError(instr, 0, status)
		return -1
	endif
	return 0
End

ThreadSafe Function qdl_VISAunLock(Variable instr)
	Variable status=viUnlock(instr)
	if(status!=VI_SUCCESS  && status!=VI_SUCCESS_NESTED_EXCLUSIVE)
		print "Error when unlocking VISA device: ", instr
		QDLPrintVISAError(instr, 0, status)
		return -1
	endif
	return 0
End

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
			status=viClear(instr)
			req[slot] = req[slot] & (~ QDL_REQUEST_CLEAR_BUFFER)
#ifdef DEBUG_QDLVISA
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
#ifdef DEBUG_QDLVISA
						print "viWrite error."
						print "viWrite status:", num2istr(status)
#endif
						AbortOnValue -1, -4
					else
						cp.outbox_retCnt=retCnt
						req[slot] = (req[slot] & (~(QDL_REQUEST_WRITE | QDL_REQUEST_WRITE_BUSY))) \
										| QDL_REQUEST_WRITE_COMPLETE
#ifdef DEBUG_QDLVISA
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
				current_time=StopMSTimer(-2)/1000
				if((current_time-cp.starttime_ms)>=cp.timeout_ms)
					req[slot] = (req[slot] & (~ (QDL_REQUEST_READ | QDL_REQUEST_READ_BUSY))) \
							| QDL_REQUEST_TIMEOUT | QDL_REQUEST_READ_COMPLETE
#ifdef DEBUG_QDLVISA
					print "VISA read timed out:", current_time-cp.starttime_ms, cp.timeout_ms
#endif
				endif
			endif
			
			if(qdl_is_connection_callable(connection_type, slot) && !(req[slot] & QDL_REQUEST_READ_COMPLETE))
				Variable termChar
				status=viGetAttribute(instr, VI_ATTR_TERMCHAR, termChar)
				AbortOnValue status!=VI_SUCCESS, -8			
	
				Variable outEventType, outContext
				status=viWaitOnEvent(instr, VI_ALL_ENABLED_EVENTS, QDL_EVENT_POLLING_TIMEOUT, outEventType, outContext)
#ifdef DEBUG_QDLVISA
				print "viWaitOnEvent returned ", num2istr(status)
#endif
				Variable bytes_at_port=0
				
				if(cp.byte_at_port_check_flag==1)
					status=viGetAttribute(instr, VI_ATTR_ASRL_AVAIL_NUM, bytes_at_port)
					AbortOnvalue status!=VI_SUCCESS, -6
				endif
				
				if(cp.byte_at_port_check_flag==0 || bytes_at_port>0)
					Variable packetSize=QDL_SERIAL_PACKET_BUF_SIZE
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
					
					retCnt=0
					if(packetSize>0)	
						status=viRead(instr, receivedStr, packetSize, retCnt)	
						if(retCnt>0)
#ifdef DEBUG_QDLVISA
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
#ifdef DEBUG_QDLVISA
						print "read request completed."
						print "request status:", num2istr(req[slot])
#endif
					endif
					
					if(outContext!=VI_NULL)
						viClose(outContext)
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

