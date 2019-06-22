#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink
///////////////////////////////////////////////////////////
// QDataLink
//root|Packages|QDataLink
//                maxInstanceRecord
//                infoStr  <- stores active instances, crossrefs between instance# and connection port/names
//                       |privateDF
//                       |strs
//                       |vars
//                           visaDefaultRM <- stores the VISA default resource manager session number, initialized when loaded
//                       |waves
//                           instance_param_records <- the connection type and names of the str for each active instances that stores the connection parameters
//                           request_records  <- request sent each active instances
//                           status_records   <- status returned for each active instances
//                       |instance0 <- holds all information on instance 0
//                       |instance1 <- holds all information on instance 1  <- each connection name will use the same instance # if possible
///////////////////////////////////////////////////////////
StrConstant QDLPackageName="QDataLink"
StrConstant QDLDefaultRMName="visaDefaultRM"
Strconstant QDLParamAndDataRecord="instance_param_name_records;inbox_all;outbox_all"
StrConstant QDLStatusRecord="request_records;status_records"
StrConstant QDLParamAndDataRecordSizes="10;10;10;"
StrConstant QDLStatusRecordSizes="10;10;" //make sure to have this the same as QDL_MAX_CONNECTIONS
Constant QDL_MAX_CONNECTIONS=10

Constant QDL_CONNECTION_TYPE_NONE=0
Constant QDL_CONNECTION_TYPE_SERIAL=1

//need national instrument VISA driver support
Constant QDL_VI_EVENT_SERIAL_TERMCHAR=0x3FFF2024
Constant QDL_VI_EVENT_SERIAL_CHAR=0x3FFF2035

Constant QDL_SERIAL_CONNECTION_NAME_MAXLEN=256
Constant QDL_MAX_BUFFER_LEN=16384
Constant QDL_SERIAL_PACKET_BUF_SIZE=64

Constant QDL_SERIAL_REQUEST_READ				=0x0001
Constant QDL_SERIAL_REQUEST_WRITE			=0x0002
Constant QDL_SERIAL_REQUEST_READ_BUSY		=0x0004
Constant QDL_SERIAL_REQUEST_WRITE_BUSY		=0x0008
Constant QDL_SERIAL_REQUEST_READ_COMPLETE	=0x0010
Constant QDL_SERIAL_REQUEST_WRITE_COMPLETE=0x0020
Constant QDL_SERIAL_REQUEST_TIMEOUT			=0x1000
Constant QDL_SERIAL_REQUEST_READ_ERROR		=0x0100
Constant QDL_SERIAL_REQUEST_WRITE_ERROR	=0x0200

Structure QDLConnectionParam
	uint32 connection_type
	char name[QDL_SERIAL_CONNECTION_NAME_MAXLEN+1]
	
	uint32 byte_at_port_check_flag
	//for serial connections
	uint64 instr
	uint32 baud_rate
	uchar data_bits
	uchar stop_bits
	uchar parity
	uchar flow_control
	uchar xon_char
	uchar xoff_char
	uchar term_char
	uchar end_in
	uchar end_out
	
	uint64 starttime_ticks
	uint32 timeout_ms
	
	
	//common information
	char packetbuf[QDL_SERIAL_PACKET_BUF_SIZE]
	uint32 packetbuf_start
	uint32 packetbuf_end
	
//	char inbox_buf_name[QDL_SERIAL_CONNECTION_NAME_MAXLEN+1]
	uint32 inbox_request_len
	uint32 inbox_received_len
	
//	char outbox_buf_name[QDL_SERIAL_CONNECTION_NAME_MAXLEN+1]
	uint32 outbox_request_len
	uint32 outbox_retCnt
	
	uint32 instance
	uint32 status
EndStructure

Menu "QDataLink", dynamic
	QDLMenuItem(-2), /Q, QDLMenuHandler(-2)
	QDLMenuItem(-1), /Q, QDLMenuHandler(-1)
	QDLMenuItem(0), /Q, QDLMenuHandler(0)
	QDLMenuItem(1), /Q, QDLMenuHandler(1)
	QDLMenuItem(2), /Q, QDLMenuHandler(2)
	QDLMenuItem(3), /Q, QDLMenuHandler(3)
	QDLMenuItem(4), /Q, QDLMenuHandler(4)
	QDLMenuItem(5), /Q, QDLMenuHandler(5)
	QDLMenuItem(6), /Q, QDLMenuHandler(6)
	QDLMenuItem(7), /Q, QDLMenuHandler(7)
	QDLMenuItem(8), /Q, QDLMenuHandler(8)
	QDLMenuItem(9), /Q, QDLMenuHandler(9) //matches QDL_MAX_CONNECTIONS=10
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
			return "Shutdown QDataLink..."
		endif
		
		if(idx>=0 && idx<maxidx) //idx should be within the number of active instances
			Variable instance=floor(str2num(StringFromList(idx, active_instance_list, ",")))
			Variable instance_check_flag=0
			String instance_info=WBPkgGetInfoString(QDLPackageName, instance=instance)
			
			if(strlen(instance_info)>0)
				String name, connection, notes
				QDLGetSerialInstanceInfo(instance, name, notes, connection)

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
				retStr="["+num2istr(idx)+"] "+name+" ("+connection+") "+" {"+notes+"}"
			else
				retStr="["+num2istr(idx)+"] ERROR!"
			endif
		else
			return ""
		endif
	catch
		print "ERROR: VISA environment not properly initialized."
	endtry
	
	return retStr
End

Function /T QDLSetSerialConnectionParameters(String configStr, [String name, String notes, Variable timeout, Struct QDLConnectionParam & paramStruct, variable quiet])
	String newconfigStr=""
	
	if(ParamIsDefault(name))
		name="untitled"
	endif
	if(ParamIsDefault(notes))
		notes="no notes"
	endif
	if(ParamIsDefault(timeout))
		timeout=5000
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

Function QDLMenuHandler(variable idx)
	if(idx==-2) //new connection
		String port_list=QDLSerialPortGetList()
		String port_select=""
		PROMPT port_select, "Port Name", popup port_list
		DoPrompt "Select Serial Port", port_select
		
		if(V_Flag==0)
			QDLInitSerialPort(port_select, "", quiet=0)
		endif
	endif
	if(idx==-1)
	endif
	if(idx>=0)
		String fullPkgPath=WBSetupPackageDir(QDLPackageName)
		String overall_info=WBPkgGetInfoString(QDLPackageName)
		String active_instances=StringByKey("ACTIVE_INSTANCES", overall_info, "=", ";")
		Variable instance_selected=str2num(StringFromList(idx, active_instances, ","))
		String name, notes, connection, panel
		Variable panel_flag=0
		try
			QDLGetSerialInstanceInfo(instance_selected, name, notes, connection, panel=panel)
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
			QDLUpdateSerialInstanceInfo(instance_selected, name, notes, connection, panel=panel)
		endif
	endif
End

Function QDLInit(Variable & initRM)
	variable init_flag=0
	Variable status=0
	
	initRM=-1
	try
		String fullPkgPath=WBSetupPackageDir(QDLPackageName, init_request=1)
		String defaultRM_str=WBPkgGetName(fullPkgPath, WBPkgDFVar, QDLDefaultRMName)
		NVAR DefaultRM=$defaultRM_str
		if(!NVAR_Exists(DefaultRM))
			WBPrepPackageVars(fullPkgPath, QDLDefaultRMName)
			init_flag=1
		elseif(DefaultRM>0)
			String str=""
			status=viGetAttributeString(DefaultRM, VI_ATTR_RSRC_NAME, str)
			if(status!=VI_SUCCESS)
				DefaultRM=-1
				init_flag=1
			else
				initRM=DefaultRM
			endif
		else
			init_flag=1
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
			Variable RM		
			status=viOpenDefaultRM(RM)
			if(status==VI_SUCCESS)
				print "VISA default resource manager initialized."
				initRM=RM
			else
				print "Error when initializing VISA default resource manager."
				QDLSerialPortPrintError(RM, 0, status) 
				RM=-1
			endif
		endif
	catch
		print "error initializing QDataLink package."
	endtry
	return RM
End

//print out description of the error associated with status. viObject set to 0 if the error is about the session
ThreadSafe Function QDLSerialPortPrintError(Variable session, Variable viObject, Variable status)
	String errDesc=""
	if(status<0)
		if(viObject==0)
			viObject=session
		endif
		viStatusDesc(viObject, status, errDesc)
		printf "VISA error: %s\n", errDesc
	endif
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
	QDLSerialPortPrintError(defaultRM, findList, status)

	return list
End

//
// the following are variable/wave/strings that are used per instance
//
StrConstant QDLSerialInstanceVarList="count;request_read_len;request_write_len;"
StrConstant QDLSerialInstanceStrList="connection_param;callback_func;inbox_str;outbox_str;"

Function /T QDLInitSerialPort(String instrDesc, String initParam, [variable quiet])
	String fullPkgPath=WBSetupPackageDir(QDLPackageName)
	String overall_info=WBPkgGetInfoString(QDLPackageName)
	//overall_info contains the record of all active connections, and the cross reference between these connections and the instance number.
			// for example: "ACTIVE_INSTANCES=0,3;0=ASRL3::INSTR;3=ASRL5::INSTR;ASRL3::INSTR=0;ASRL5::INSTR=3"
	String active_instances=StringByKey("ACTIVE_INSTANCES", overall_info, "=", ";")
	//print "active instances:", active_instances
	
	NVAR DefaultRM=$WBPkgGetName(fullPkgPath, WBPkgDFVar, QDLDefaultRMName)
	AbortOnValue DefaultRM<=0, -1
	
	variable i, n, openflag
	n=ItemsInList(active_instances, ",")
	openflag=0
	for(i=0; i<n; i+=1)
		String opened_port=StringByKey(StringFromList(i, active_instances, ","), overall_info, "=", ";")
		if(CmpStr(opened_port, instrDesc)==0)
			print "Port is already opened as instance ", i
			openflag=1
			break
		endif
	endfor
	if(openflag==1)
		return ""
	endif
	
	Variable instance_select=str2num(StringByKey(instrDesc, overall_info, "=", ";"))
	if(numtype(instance_select)!=0)
		instance_select=WBPkgNewInstance
	endif
	//print "proceed to init port ["+instrDesc+"] with instance requested as ", instance_select

	STRUCT QDLConnectionParam cp	
	cp.connection_type=QDL_CONNECTION_TYPE_NONE
	String configStr=QDLSetSerialConnectionParameters(initParam, paramStruct=cp, quiet=quiet)
	
	if(strlen(configStr)<=0)
		print "Error or user cancelled the initialization."
		return ""
	endif
	
	cp.name=instrDesc[0, QDL_SERIAL_CONNECTION_NAME_MAXLEN-1]
	cp.name[QDL_SERIAL_CONNECTION_NAME_MAXLEN]=0
	
	String retStr=""

	Variable len, retCnt	
	Variable status=0
	Variable instr, attr
	Variable success_flag=0
	instr=0

	if(DefaultRM>0)
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
				viEnableEvent(instr, VI_EVENT_SERVICE_REQ, VI_QUEUE, 0)
				AbortOnvalue status!=VI_SUCCESS, status
				viEnableEvent(instr, QDL_VI_EVENT_SERIAL_TERMCHAR, VI_QUEUE, 0)
				AbortOnvalue status!=VI_SUCCESS, status
				viEnableEvent(instr, QDL_VI_EVENT_SERIAL_CHAR, VI_QUEUE, 0)
				AbortOnvalue status!=VI_SUCCESS, status
				cp.byte_at_port_check_flag=1
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
				viEnableEvent(instr, VI_EVENT_SERVICE_REQ, VI_QUEUE, 0)
				AbortOnvalue status!=VI_SUCCESS, status
				viEnableEvent(instr, VI_EVENT_USB_INTR, VI_QUEUE, 0)
				AbortOnValue status!=VI_SUCCESS, status
//				viEnableEvent(instr, QDL_VI_EVENT_SERIAL_TERMCHAR, VI_QUEUE, 0)
//				AbortOnvalue status!=VI_SUCCESS, status
//				viEnableEvent(instr, QDL_VI_EVENT_SERIAL_CHAR, VI_QUEUE, 0)
//				AbortOnvalue status!=VI_SUCCESS, status

				cp.byte_at_port_check_flag=0			
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
				QDLSerialPortPrintError(instr, 0, status)
				viClose(instr)
			endif
		endtry
	endif
	
	WAVE /T param_name_records=$WBPkgGetname(fullPkgpath, WBPkgDFWave, StringFromList(0, QDLParamAndDataRecord))
	if(success_flag==1)
		try
			cp.instr=instr
			
			String instancePath
			if(instance_select==WBPkgNewInstance)
				instancePath=WBSetupPackageDir(QDLPackageName, instance=instance_select, init_request=1)
				WBPrepPackageVars(instancePath, QDLSerialInstanceVarList)
				WBPrepPackageStrs(instancePath, QDLSerialInstanceStrList)
				//WBPrepPackageWaves(instancePath, QDLPackageByteWaveList, datatype=0x48) //unsigned byte wave
			else
				instancePath=WBSetupPackageDir(QDLPackagename, instance=instance_select)
			endif
			
			if(instance_select>=0)
				param_name_records[instance_select]="" //clean up first, initialize all parameters and then put this back to order
			endif
//the following needs to be properly initialized
//StrConstant QDLPackageVarList="count;request_read_len;request_write_len;"
//StrConstant QDLPackageStrList="connection_param;callback_func;inbox_str;outbox_str;"
			
			NVAR count=$WBPkgGetName(instancePath, WBPkgDFVar, "count")
			NVAR req_readlen=$WBPkgGetName(instancePath, WBPkgDFVar, "request_read_len")
			NVAR req_writelen=$WBPkgGetName(instancePath, WBPkgDFVar, "request_write_len")
			String param_str_name=WBPkgGetName(instancePath, WBPkgDFStr, "connection_param")
			SVAR cparam=$param_str_name
			SVAR callback_func=$WBPkgGetName(instancePath, WBPkgDFStr, "callback_func")
			SVAR inbox=$WBPkgGetName(instancePath, WBPkgDFStr, "inbox_str")
			SVAR outbox=$WBPkgGetName(instancePath, WBPkgDFStr, "outbox_str")
			
			count=0
			req_readlen=0
			req_writelen=0
			callback_func=""
			inbox=""
			outbox=""
			StructPut /S cp, cparam //update the parameter stored in the instance string folder
			retStr=cparam

			//for menu item display
			active_instances=AddListItem(num2istr(instance_select), active_instances, ",")
			overall_info=ReplaceStringByKey("ACTIVE_INSTANCES", overall_info, active_instances, "=", ";")
			overall_info=ReplaceStringByKey(num2istr(instance_select), overall_info, instrDesc, "=", ";")
			overall_info=ReplaceStringByKey(instrDesc, overall_info, num2istr(instance_select), "=", ";")
			WBPkgSetInfoString(QDLPackageName, overall_info)
				
			QDLUpdateSerialInstanceInfo(instance_select, "Untitled", "No notes", instrDesc)
			
			//for background task information. the first character is a number representing the connection time, followed by the name of the string that stores the parameters
			param_name_records[instance_select]=num2istr(QDL_CONNECTION_TYPE_SERIAL)+param_str_name

			print "VISA serial port initialization succeeded for instance "+num2istr(instance_select)
		catch
			print "Error when trying to clean up the package datafolder for instance ", instance_select
			print "Will now close the serial port."
			viClose(instr)		
		endtry
	endif
	
	return retStr
End

Function QDLGetSerialInstanceInfo(Variable instance, String & name, String & notes, String & connection, [String & param_str, String & panel])
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
End

Function QDLUpdateSerialInstanceInfo(Variable instance, String name, String notes, String connection, [String param_str, String panel])
	String fullPkgPath=WBSetupPackageDir(QDLPackageName, instance=instance)
	String infoStr=WBPkgGetInfoString(QDLPackageName, instance=instance)
	
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
End


Function /T QDLSerialConnectionPanel(Variable instance)
	String name, notes, connection, param_str
	
	QDLGetSerialInstanceInfo(instance, name, notes, connection, param_str=param_str)
	STRUCT QDLConnectionParam cp
	StructGet /S cp, param_str
	if(CmpStr(connection, cp.name)!=0)
		print "possible error: connection information does not match parameter setting."
		print "connection by instance: "+connection
		print "connection in parameter setting: "+cp.name
	endif
	if(cp.connection_type!=QDL_CONNECTION_TYPE_SERIAL)
		print "connection type is wrong for instance "+num2istr(instance)
		print "type is set to "+num2istr(cp.connection_type)+", but "+num2istr(QDL_CONNECTION_TYPE_SERIAL)+" is expected."
		return ""
	endif
	
	NewPanel /N=qdlsc_panel /K=1 /FLT /W=(100,100,620,320) as "QDL Serial Connection Panel -"+connection
	SetVariable sv_name,pos={1,1},size={150,20},title="Name"
	SetVariable sv_name,value= _STR:(name),fixedSize=1
	SetVariable sv_connection, pos={160,1}, size={260,20},title="Connection"
	SetVariable sv_connection, value=_STR:(connection),fixedSize=1,disable=2
	SetVariable sv_notes,pos={1,20},size={500,20},title="Notes"
	SetVariable sv_notes,value= _STR:(notes),fixedSize=1
	Button btn_saveinfo, pos={460,1}, size={50,20}, title="save info",proc=QDLSerialPanel_btnfunc
	
	SetVariable sv_outbox,pos={1,40},size={500,20},title="Message for sending"
	SetVariable sv_outbox,value= _STR:"",fixedSize=1
	Button btn_send,pos={1,55},size={50,20},title="send"
	Button btn_query,pos={55,55},size={50,20},title="query"
	Button btn_read,pos={110,55},size={50,20},title="read"
	Button btn_clear, pos={170,55}, size={50,20}, title="clear"
	TitleBox tb_title,pos={5,80},size={75,20},title="Received Message"
	TitleBox tb_title,frame=0
	TitleBox tb_receivedmsg,pos={1,95},size={500,80},title=" "
	TitleBox tb_receivedmsg,fixedSize=1
	TitleBox tb_status,pos={1,180},size={500,20},title=" ", fixedSize=1
	SetWindow kwTopWin, userdata(SerialConnectionParam)=param_str
	SetWindow kwTopWin, userdata(instance)=num2istr(instance)	
	String wname=WinName(0, 64, 1, 1)
	SetActiveSubwindow _endfloat_
	return wname
End

Function QDLSyncedSerialPortQuery(Variable instance, [String outbox, String & expected_response, Variable timeout])

End

ThreadSafe Function qdl_thread_serial_request_handler(Variable idx, String & param, WAVE request_records, WAVE status_records, WAVE /T outbox_all, WAVE /T inbox_all)
	if(strlen(param)<=0)
		return -1
	endif
	
	Variable status=-1
	Variable cp_modified=0

	try		
		STRUCT QDLConnectionParam cp
		StructGet /S cp, param; AbortOnRTE
		Variable instance=cp.instance
		AbortOnValue idx!=instance, -1
		
		Variable timeout=cp.timeout_ms
		Variable req=request_records[instance]
		Variable instr=cp.instr
		Variable retCnt
		
		AbortOnValue (instance<0 || instance>=QDL_MAX_CONNECTIONS || instr<=0), -1

		if(!(req & QDL_SERIAL_REQUEST_READ_BUSY)) //request for writing comes before reading, but not in the middle of it
			if((req & QDL_SERIAL_REQUEST_WRITE) && !(req & QDL_SERIAL_REQUEST_WRITE_COMPLETE))				
				if(cp.outbox_request_len>strlen(outbox_all[instance]))
					cp.outbox_request_len=strlen(outbox_all[instance])
				endif
			
				retCnt=0
				status=viWrite(instr, outbox_all[instance], cp.outbox_request_len, retCnt)
				if(status!=VI_SUCCESS)
					cp.outbox_retCnt=0
					cp_modified=1
					AbortOnValue -1, -4
				endif
				print "msg sent out."
				req =req & (~QDL_SERIAL_REQUEST_WRITE)
				req =req | QDL_SERIAL_REQUEST_WRITE_COMPLETE				
			endif
		endif
		
		Variable read_complete_flag=0
		
		if((req & QDL_SERIAL_REQUEST_READ))
			if(!(req & QDL_SERIAL_REQUEST_READ_BUSY)) //first time receiving something
				if(cp.inbox_request_len<=0)
					cp.inbox_request_len=QDL_MAX_BUFFER_LEN
					cp_modified=1
				endif
				inbox_all[instance]=""
				cp.inbox_received_len=0
				cp.starttime_ticks=ticks
				cp_modified=1
				req = req | QDL_SERIAL_REQUEST_READ_BUSY
			else
				if(((ticks-cp.starttime_ticks)*1000/60)>=cp.timeout_ms)
					req = req & (~QDL_SERIAL_REQUEST_READ)
					req = req & (~QDL_SERIAL_REQUEST_READ_BUSY)
					req = req | QDL_SERIAL_REQUEST_TIMEOUT
					req = req | QDL_SERIAL_REQUEST_READ_COMPLETE
				endif
			endif
			
			if(!(req & QDL_SERIAL_REQUEST_READ_COMPLETE))
				Variable termChar
				status=viGetAttribute(instr, VI_ATTR_TERMCHAR, termChar)
				AbortOnValue status!=VI_SUCCESS, -8			
	
				Variable outEventType, outContext
				status=viWaitOnEvent(instr, VI_ALL_ENABLED_EVENTS, 20, outEventType, outContext)
				
				Variable bytes_at_port=0
				
				if(status!=VI_ERROR_TMO)
					//print "wait on event returned status: "+num2istr(status)
					if(outEventType==QDL_VI_EVENT_SERIAL_TERMCHAR)
					//	print "termChar Event detected."
					endif
					
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
						
	//					if(cp.packetbuf_end-cp.packetbuf_start>0)
	//						packetSize -= cp.packetbuf_end-cp.packetbuf_start
	//					endif
						
						if(packetSize>0) //we have not handled the other cases yet, which means that
												// there may be residues from last time readings
							retCnt=0
							status=viRead(instr, receivedStr, packetSize, retCnt)
							//AbortOnValue status!=VI_SUCCESS, -7
							//print "packet buf read: ["+receivedStr+"]"
						
							if(retCnt>0)
								//SOCKITstringtoWave /FREE /DEST=tmpw 0x48, receivedStr
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
										print "terminal char detected."
										print "event :"+num2istr(outEventType)									
										print "status:"+num2istr(status)
										print "position of termChar:"+num2istr(i)
										print "retCnt of the packet received:"+num2istr(retCnt)
										print "warning: this case is not well handled. the rest of the string will be lost in the next reading"
									endif
								endif
								cp.inbox_received_len+=i+1
								inbox_all[instance]+=receivedStr[0,i]
								cp_modified=1
							endif
						endif
						
						if(cp.inbox_request_len>0 && cp.inbox_received_len>=cp.inbox_request_len)
							read_complete_flag=1
						endif
											
						if(read_complete_flag)
							req = req & (~QDL_SERIAL_REQUEST_READ)
							req = req & (~QDL_SERIAL_REQUEST_READ_BUSY)
							req = req | QDL_SERIAL_REQUEST_READ_COMPLETE
						endif
					endif
					
					if(outContext!=VI_NULL)
						viClose(outContext)
					endif
				endif //event arrived
			endif //read not complete?
		endif
	catch
		//print "RunTime error: ", GetRTError(1), GetRTErrMessage()
		//print "VISA status code: "+num2istr(status)	
		//QDLSerialPortPrintError(instr, 0, status)
	endtry
	
	try
		if(cp_modified==1)
			StructPut /S cp, param; AbortOnRTE
		endif
		request_records[instance]=req; AbortOnRTE
		status_records[instance]=status; AbortOnRTE
	catch
		status=-1
		print "error when updating final request status and connection records for instance "+num2istr(instance)
	endtry
	
	return status
End

Function QDLSerialQuery(variable instance, [string in, string &out])
	String fullPkgPath=WBSetupPackageDir(QDLPackageName, instance=instance)
	String param_name=WBPkgGetName(fullPkgPath, WBPkgDFStr, "connection_param")
	//WAVE outbox=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "outbox")
	//WAVE inbox=$WBPkgGetName(fullPkgPath, WBPkgDFWave, "inbox")

End

ThreadSafe Function qdl_request_handler(Variable instance, WAVE type, WAVE /T param, WAVE request_records, WAVE status_records, WAVE /T outbox_all, WAVE /T inbox_all)
	variable retVal=0
	try
		switch(type[instance])
		case QDL_CONNECTION_TYPE_SERIAL:
			string tmpstr=param[instance]	

			retVal=qdl_thread_serial_request_handler(instance, tmpstr, request_records, status_records, outbox_all, inbox_all)
			param[instance]=tmpstr
			break
		default:
			retVal=-1
		endswitch
	catch
		retVal=-1
	endtry
	return retVal
End

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
				if(!(request_records[i] & QDL_SERIAL_REQUEST_READ) && !(request_records[i] & QDL_SERIAL_REQUEST_READ_BUSY) && !(request_records[i] & QDL_SERIAL_REQUEST_READ_COMPLETE))
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
					request_records[i]=QDL_SERIAL_REQUEST_READ | QDL_SERIAL_REQUEST_WRITE
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
	
	multithread tmp_retVals=qdl_request_handler(p, tmp_connection_types, tmp_params, request_records, status_records, outbox_all, inbox_all)

	for(i=0; i<QDL_MAX_CONNECTIONS; i+=1)
		if(tmp_connection_types[i]>0)
			SVAR paramstr=$((param_name_records[i])[1,inf])
			
			//debug query begin
			StructGet /S cp, tmp_params[i]
			if(request_records[i] & QDL_SERIAL_REQUEST_READ_COMPLETE)
				process_data(inbox_all[i])
				request_records[i] = 0
			endif
			//debug query end
			
			paramstr=tmp_params[i] //update the parameter records of each active connection
		endif
	endfor

	return 0
End

Function QDLSerialPanel_btnfunc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String parent_window=ba.win
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			strswitch(ba.ctrlName)
			case "btn_saveinfo":
				Variable instance=str2num(GetUserData(parent_window, "", "instance"))
				ControlInfo /W=$parent_window sv_name
				String name=S_Value
				ControlInfo /W=$parent_window sv_notes
				String notes=S_Value
				ControlInfo /W=$parent_window sv_connection
				String connection=S_Value
				QDLUpdateSerialInstanceInfo(instance, name, notes, connection)
				break
			case "btn_send":
				break
			case "btn_query":
				break
			case "btn_read":
				break
			case "btn_clear":
				break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
