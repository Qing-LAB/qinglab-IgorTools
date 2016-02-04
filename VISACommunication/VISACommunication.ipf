//ChangeLog
//Last updated 2015/10/20
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Constant visaComm_ReadWaitTime=50 // in milliseconds
Constant visaComm_ReadPacketSize=4096
Constant visaComm_NoWait=0
Constant visaComm_WaitForEver=-1
StrConstant visaComm_PackageRoot="root:Packages"
StrConstant visaComm_PackageFolderName="VISACommunication"
StrConstant visaComm_PanelName="VISACommBkgrdTsk"
Constant visaComm_bkgd_task_ticks=3
StrConstant visaComm_DefaultInitString="*CLS\rstatus.reset() status.request_enable=status.MAV\rformat.data=format.REAL64 format.byteorder=1"
StrConstant visaComm_DefaultClearQueueCmd="*CLS\rstatus.reset() status.request_enable=status.MAV"
StrConstant visaComm_DefaultShutdownCmd="*CLS\rreset()"
StrConstant visaComm_NoClearQueue="NO_CLEAR"

Function visaComm_CheckError(session, viObject, status, [quiet, AbortOnError])
	Variable session
	Variable viObject
	Variable status
	Variable quiet
	Variable AbortOnError
	
	String errorDesc=""
	if(status<0)
		if(viObject==0)
			viObject=session
		endif
		viStatusDesc(viObject, status, errorDesc)
		if(quiet!=0)
			printf "VISA error: %s\r", errorDesc
		endif
		if(AbortOnError!=0)
			abort("VISA error: "+errorDesc)
		endif
	endif
	return status
End

Function /S visaComm_GetList([filter, quiet])
	String filter
	Variable quiet
	
	Variable defaultRM, status
	Variable findList, retCnt
	String instrDesc
	String list
	
	if(ParamIsDefault(filter))
		filter="?*INSTR"
	endif
	
	list=""
	findList=0
	retCnt=0
	status=viOpenDefaultRM(defaultRM)
	if(status==VI_SUCCESS)
		do
			status=viFindRsrc(defaultRM, filter, findList, retCnt, instrDesc)
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
	visaComm_CheckError(defaultRM, findList, status, quiet=quiet)

	return list
End

Function visaComm_Init(instrDesc, [sessionRM, sessionINSTR, initCmdStr, quiet])
	String instrDesc
	Variable & sessionRM
	Variable & sessionINSTR
	String initCmdStr
	Variable quiet
	
	Variable len, retCnt	
	Variable status
	Variable RM, INSTR
	
	RM=0
	INSTR=0
	status=viOpenDefaultRM(RM)
	if(status==VI_SUCCESS)
		status=viOpen(RM, instrDesc, 0, 0, INSTR)
		if(status==VI_SUCCESS)
			viClear(INSTR)
			viEnableEvent(INSTR, VI_EVENT_SERVICE_REQ, VI_QUEUE, 0)
			if(ParamIsDefault(initCmdStr))
				initCmdStr=visaComm_DefaultInitString
			endif
			visaComm_WriteSequence(instr, initCmdStr)
		endif
	endif
	visaComm_CheckError(RM, INSTR, status, quiet=quiet)
	if(ParamIsDefault(sessionRM))
		KillVariables /Z V_VISAsessionRM
		KilLStrings /Z V_VISAsessionRM
		Variable /G V_VISAsessionRM=RM
	else
		sessionRM=RM
	endif
	if(ParamIsDefault(sessionINSTR))
		KillVariables /Z V_VISAsessionINSTR
		KillStrings /Z V_VISAsessionINSTR
		Variable /G V_VISAsessionINSTR=INSTR
	else
		sessionINSTR=INSTR
	endif

	return status
End

Function visaComm_Shutdown(instr, [openRM, shutdownCmdStr])
	Variable instr
	Variable openRM
	String shutdownCmdStr
	
	Variable len, retCnt
	Variable status=0
	if(ParamIsDefault(shutdownCmdStr))
		shutdownCmdStr=visaComm_DefaultShutdownCmd
	endif
	visaComm_WriteSequence(instr, shutdownCmdStr)	
	viClose(instr)
	if(!ParamIsDefault(openRM))
		viClose(openRM)
	endif
		
	return status
End

Function visaComm_DequeueEvent(instr, timeout_ms, clearPreviousEvents, retOnTimeOut)
	Variable instr, timeout_ms
	Variable clearPreviousEvents, retOnTimeOut
	
	Variable status, event, context
	
	event=VI_NULL
	context=VI_NULL
	
	if(clearPreviousEvents!=0) // previously existing events will be cleared before waiting
		status=viDiscardEvents(instr , VI_ALL_ENABLED_EVENTS , VI_QUEUE )
	endif
	
	do
		status=viWaitOnEvent(instr, VI_ALL_ENABLED_EVENTS, timeout_ms, event, context)
		if(retOnTimeOut!=0 || status!=VI_ERROR_TMO)
			break
		endif
	while(1)	

	if(context!=VI_NULL)
		viClose(context)
	endif
	
	return status
End

Function visaComm_ReadStr(instr, str, packetSize, len) //read string until terminal character is reached, or if len>0, read the string of that length
	Variable instr
	String & str
	Variable packetSize
	Variable & len
	
	Variable rflag=1, retCnt, status, rlen
	String buf=""
	str=""
	rlen=0
	if(len>=0)
		do
			if(len>0 && packetSize>(len-rlen))
				packetSize=len-rlen
			endif
			status=viRead(instr, buf, packetSize, retCnt)
			switch(status)
				case VI_SUCCESS:
				case VI_SUCCESS_TERM_CHAR:
					str+=buf
					rlen+=retCnt
					rflag=0
					break
				case VI_SUCCESS_MAX_CNT:
					str+=buf
					rlen+=retCnt
					break
				default:
					rflag=0
					break
			endswitch		
		while(rflag && rlen<len)
	endif
	return status
End

Function visaComm_ReadFixedWithPrefix(instr, str)
	Variable instr
	String & str
	
	Variable len=0
	Variable termChar
	String buf
	
	viGetAttribute(instr , VI_ATTR_TERMCHAR_EN , termChar)
	viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, char2num("\r"))
	visaComm_ReadStr(instr, buf, visaComm_ReadPacketSize, len)
	len=strsearch(buf, "QQDATA_FIXED", 0)
	str=""
	if(len>=0)
		if(cmpstr(buf[len+12,len+15], "BSTR")==0)
			len=str2num(buf[len+16,inf])
			if(len>0) //length in prefix can be set to zero so no binary reading will be performed, this is used for the intialization
				viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, 0)
				visaComm_ReadStr(instr, str, visaComm_ReadPacketSize, len)
			endif
		elseif(cmpstr(buf[len+12,len+15], "KDBL")==0)
			len=str2num(buf[len+16,inf])
			if(len>0) //length in prefix can be set to zero so no binary reading will be performed, this is used for the intialization
				len=len*8+3
				viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, 0)
				visaComm_ReadStr(instr, buf, visaComm_ReadPacketSize, len)
				str=buf[2, len-2]
			endif
		else
			len=0
		endif
	endif
	viSetAttribute(instr, VI_ATTR_TERMCHAR_EN, termChar)
End

Function visaComm_WriteSequence(instr, cmd)
	Variable instr
	String cmd
	
	String str
	Variable n=ItemsInList(cmd, "\r")
	Variable i, len, status=VI_SUCCESS, retCnt
	
	for(i=0; i<n; i+=1)
		str=StringFromList(i, cmd, "\r")
		len=strlen(str)
		if(len>0)
			status=viWrite(instr, str, len, retCnt)
			if(status!=VI_SUCCESS)
				break
			endif
		endif
	endfor
	return status
End


Function visaComm_SyncedWriteAndRead(instr, readType, [cmd, response, clearOutputQueue, clearQueueCmd, fixedlen])
	Variable instr
	Variable readType
	String cmd
	String & response
	Variable clearOutputQueue
	String clearQueueCmd
	Variable fixedlen

	Variable len=0
	Variable retCnt, status, termChar
	
	if(ParamIsDefault(clearOutputQueue) || clearOutputQueue!=0)
		if(ParamIsDefault(clearQueueCmd))
			clearQueueCmd=visaComm_DefaultClearQueueCmd
		endif
		visaComm_WriteSequence(instr, clearQueueCmd)
		visaComm_DequeueEvent(instr, visaComm_NoWait, 1, 1)
	endif
	if(!ParamIsDefault(cmd))
		len=strlen(cmd)
		if(len>0)
			viWrite(instr, cmd, len, retCnt)
		endif
	endif
	if(ParamIsDefault(fixedlen))
		fixedlen=-1
	endif
	if(!ParamIsDefault(response))
		do
			status=visaComm_DequeueEvent(instr, visaComm_ReadWaitTime, 0, 1)
			if(status!=VI_ERROR_TMO)
				if(status==VI_SUCCESS || status==VI_SUCCESS_QUEUE_EMPTY || VI_SUCCESS_QUEUE_NEMPTY)
					if(readType==0) //type 0: read whatever is present in the queue
						len=0
						visaComm_ReadStr(instr, response, visaComm_ReadPacketSize, len)
					elseif(readType==1 && fixedlen>0) //type 1: read a fixed length of binary string as specified by user
						len=fixedlen
						visaComm_ReadStr(instr, response, visaComm_ReadPacketSize, len)
					elseif(readType==2) //type 2: read a fixed length of binary string as specified by prefix info sent from server
						visaComm_ReadFixedWithPrefix(instr, response)
					endif
				endif
				break
			elseif(readType<0) //not expecting any readouts
				break
			endif
		while(1)
	endif
End


Function visaComm_CallbackProtoType(session, strData, strParam, count, strCmd)
	Variable session
	String strData
	String strParam
	Variable & count
	String & strCmd

	return 0
End

Function visaComm_PanelButtonFunc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
	case 2: // mouse up
		String savedDF=GetDataFolder(1)
		String fullPackagePath=visaComm_PackageRoot+":"+visaComm_PackageFolderName
		SetDataFolder(fullPackagePath); AbortOnRTE
		NVAR request=ExtRequest
		if(NVAR_Exists(request))
			request=-99
		endif
		SetDataFolder(savedDF)	
		break
	case -1: // control being killed
		break
	endswitch
End

Function visaComm_WriteAndReadTask(s)
	STRUCT WMBackgroundStruct &s
	Variable timer1=StartMSTimer
	String savedDF=GetDataFolder(1)
	String fullPackagePath=visaComm_PackageRoot+":"+visaComm_PackageFolderName
	Variable retVal=0
	try
		AbortOnValue !DataFolderExists(fullPackagePath), -100
		
		SetDataFolder(fullPackagePath); AbortOnRTE
		
		NVAR request=ExtRequest //set by user
		NVAR requestType=ExtRequestType //set by user
		
		SVAR setcmd=ExtCmdOut //set by user
		SVAR setclearcmd=ExtClearQueueCmd //set by user
		NVAR setsession=ExtSessionID //set by user
		NVAR setlen=ExtReadLen //set by user
		
		SVAR setParam=ExtCallbackParam //set by user
		SVAR setFuncName=ExtCallbackFuncName //set by user
		
		NVAR state=funcState //state of the background task
		NVAR exec_time=execTime //how much time for each cycle execution
		SVAR cmd=sendCmd
		NVAR count=countNumber // how many cycles the call back function has been called
		SVAR clearQCmd=clearQueueCmd
		NVAR session=sessionID
		NVAR fixedlen=readLen
		
		SVAR callParam=callbackParam
		SVAR callFuncName=callbackFuncName
		
		SVAR response=responseStr		
		
		AbortOnValue (!NVAR_Exists(request) || !NVAR_Exists(requestType) || !NVAR_Exists(state)), -101
					
		Variable stateflag=trunc(state) & 15
		Variable stateoptions=(trunc(state) & (~15)) / (2^4)
		Variable stateoption_clearqueue=(stateoptions &1)
		Variable stateoption_repeatwriting=(stateoptions & 2)
		Variable stateoption_fixedlengthprefix=(stateoptions & 4)
		Variable stateoption_fixedlengthbyuser=(stateoptions & 8)
		
		Variable len=0
		String strBuf=""
		Variable viStatus
		Variable callback_flag=0
		
		AbortOnRTE
		
		switch(stateflag & 7) //highest bit reserved to indicate whether the call is the first time or cycled
		case 0: //waiting for command
			//print "waiting for command..."
			AbortOnValue (!NVAR_Exists(setsession) || !NVAR_Exists(session) || !NVAR_Exists(fixedlen) || !NVAR_Exists(setlen) || !SVAR_Exists(setcmd) || !SVAR_Exists(cmd)), -101
			
			if(request>0)
				session=setsession
				fixedlen=setlen
				cmd=setcmd
				
				if(SVAR_Exists(setParam) && SVAR_Exists(setFuncName) && SVAR_Exists(callParam) && SVAR_Exists(callFuncName))
					callParam=setParam
					callFuncName=setFuncName
				endif
				
				if(requestType & 1) // clear queue?
					stateoption_clearqueue=1
				else
					stateoption_clearqueue=0
				endif
				if(requestType & 2) // write command every time?
					stateoption_repeatwriting=2
				else
					stateoption_repeatwriting=0
				endif
				if(requestType & 4) //fixed length readout defined by prefix?
					stateoption_fixedlengthprefix=4
				else
					stateoption_fixedlengthprefix=0
				endif
				if(requestType & 8) //fixed length readout specified by user?
					stateoption_fixedlengthbyuser=8
				else
					stateoption_fixedlengthbyuser=0
				endif
				if(!(stateflag & 8)) //highest bit, zero indicates whether this is the first call
					count=0 //clear the count of cycles for each new request
					if(stateoption_clearqueue)
						//print "clearing output queue..."
						clearQCmd=setclearcmd
						visaComm_WriteSequence(session, clearQCmd)
						visaComm_DequeueEvent(session, visaComm_NoWait, 1, 1)
					endif
					stateflag = stateflag | 8 //next cycle is not considered as first call
				endif
				visaComm_WriteSequence(session, cmd)
				
				stateoptions=stateoption_clearqueue | stateoption_repeatwriting | stateoption_fixedlengthprefix | stateoption_fixedlengthbyuser
				stateflag =stateflag | 1 //in reading state
				request=0 //request translation complete
				//print "command received, cycling..."
			elseif(request==-99) //request is -99, means that the user is asking to abort the background task
				AbortOnValue 1, -110
			endif
			AbortOnRTE
			break
		case 1: // reading state
			if(request==0)
				viStatus=visaComm_DequeueEvent(session, visaComm_NoWait, 0, 1)
				if(viStatus!=VI_ERROR_TMO)
					//print "reading coming in..."
					if(viStatus==VI_SUCCESS || viStatus==VI_SUCCESS_QUEUE_NEMPTY || viStatus==VI_SUCCESS_QUEUE_EMPTY)
						if(stateoption_fixedlengthprefix) //read with a prefix specifying the length by the server
							visaComm_ReadFixedWithPrefix(session, strBuf)
						elseif(stateoption_fixedlengthbyuser) //read with a fixed length as specified by the user
							len=fixedlen
							visaComm_ReadStr(session, strBuf, visaComm_ReadPacketSize, len)
						else //read until a terminal character is reached. if no reading is wanted, set fixed length to <0
							if(fixedlen>=0)
								len=0
								visaComm_ReadStr(session, strBuf, visaComm_ReadPacketSize, len)
							endif
						endif
						response=strBuf
						callback_flag=1 //need to call the user defined function after getting the buffer filled
						if(stateoption_repeatwriting)
							stateflag = stateflag & (~1) //switch to writing period in the next cycle
							stateflag = stateflag | 2
						endif
					else
						state=0
						AbortOnValue 1, viStatus
					endif
				endif
			else
				stateflag=0 //new request is coming, get ready for that in the next cycle
				stateoptions=0
			endif
			AbortOnRTE
			break
		case 2: // writing state
			if(request==0)
				//print "writing new command..."
				visaComm_WriteSequence(session, cmd)
				stateflag = stateflag & (~2) //switch to read period in the next cycle
				stateflag = stateflag | 1
			else
				stateflag=0 // new request is coming, get ready for that in the next cycle
				stateoptions=0
			endif
			AbortOnRTE
			break
		default:
			AbortOnValue 1, -104
		endswitch
	
		if(callback_flag)
			//print "calling user function..."
			if(SVAR_Exists(callFuncName) || SVAR_Exists(callParam))
				FUNCREF visaComm_CallbackProtoType callbackFunc=$callFuncName
				Variable funcstatus,userRetVal
				String funcinfo=FuncRefInfo(callbackFunc)
				Variable newcount=count
				String newcmd=cmd
				funcstatus=(strlen(StringByKey("ISPROTO", funcinfo))>0) && (str2num(StringByKey("ISPROTO", funcinfo))==0) && (str2num(StringByKey("ISXFUNC", funcinfo))==0)
				
				if(funcstatus)
					userRetVal=callbackFunc(session, response, callParam, newcount, newcmd); AbortOnRTE
					count=newcount
					count+=1
					cmd=newcmd
					if(userRetVal<0)
						stateflag=0
						AbortOnValue 1, -110
					endif
				endif
			endif
		endif				
		state=((stateoptions &15)*(2^4)) | (stateflag &15) // put flags and states back together
	catch
		switch(V_AbortCode)
		case -4:
			print "Runtime error in VISA Communication background task = ", GetRTErrMessage()
			Variable err=GetRTError(1)
			break
		case -100:
			print "Data folder error in VISA Communication background task."
			break
		case -101:
			print "Variables or strings are not initialized correctly for VISA Communication background task."
			break
		case -104:
			if(NVAR_Exists(state))
				printf "Unknown state in VISA Communication background task: %d\r", state
			else
				print "Cannot access state for VISA Communication background task."
			endif
			break
		case -110:
			print "User or User Function Stopped VISA Communication Background Task."
			break
		default:
			printf "Possibly encountered VISA error. Status code: 0x%x\r", V_AbortCode
			String desc=""
			viStatusDesc(session, V_AbortCode, desc)
			printf "Possible description of error by viStatusDesc: %s\r", desc
			break
		endswitch
		if(NVAR_Exists(state))
			state=0
		endif
		retVal=2
	endtry
	SetDataFolder(savedDF)	
	if(retVal!=0)
		if(WinType(visaComm_PanelName)==7)
			KillWindow $visaComm_PanelName
		endif
	else
		if(WinType(visaComm_PanelName)==0)
			NewPanel /FLT=1 /K=2 /N=$visaComm_PanelName /W=(0,0,120,40)
			Button /Z visaComm_PanelButton font="Arial", fsize=10, fstyle=1, title="VISA Running..", valueColor=(65535,0,0), win=$visaComm_PanelName, size={80, 20}, pos={20, 10}, proc=visaComm_PanelButtonFunc
			SetActiveSubwindow _endfloat_
		endif
	endif
	if(timer1!=-1)
		exec_time=stopMSTimer(timer1)/1000000
	endif
	return retVal
End

Function visaComm_SetupBackgroundTask()
	if(!DataFolderExists(visaComm_PackageRoot))
		NewDataFolder /O $visaComm_PackageRoot
	endif
	String fullPackagePath=visaComm_PackageRoot+":"+visaComm_PackageFolderName
	
	if(!DataFolderExists(fullPackagePath))
		NewDataFolder /O $fullPackagePath
	endif
	DFREF dfr=$fullPackagePath
	if(DataFolderRefStatus(dfr)!=1)
		abort "cannot create VISA package data folder!"
	endif
	try
		if(exists(fullPackagePath+":ExtRequest")==0)
			Variable /G dfr:ExtRequest
		endif
		NVAR a=dfr:ExtRequest
		AbortOnValue !NVAR_Exists(a), -1
		a=0
			
		if(exists(fullPackagePath+":ExtRequestType")==0)
			Variable /G dfr:ExtRequestType
		endif
		NVAR a=dfr:ExtRequestType
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		if(exists(fullPackagePath+":ExtSessionID")==0)
			Variable /G dfr:ExtSessionID
		endif
		NVAR a=dfr:ExtSessionID
		AbortOnValue !NVAR_Exists(a), -1
		a=-1
		
		if(exists(fullPackagePath+":ExtReadLen")==0)
			Variable /G dfr:ExtReadLen
		endif
		NVAR a=dfr:ExtReadLen
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		if(exists(fullPackagePath+":ExtCallbackFuncName")==0)
			String /G dfr:ExtCallbackFuncName
		endif
		SVAR b=dfr:ExtCallbackFuncName
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		if(exists(fullPackagePath+":ExtCallbackParam")==0)
			String /G dfr:ExtCallbackParam
		endif
		SVAR b=dfr:ExtCallbackParam
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		if(exists(fullPackagePath+":ExtCmdOut")==0)
			String /G dfr:ExtCmdOut
		endif
		SVAR b=dfr:ExtCmdOut
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		if(exists(fullPackagePath+":ExtClearQueueCmd")==0)
			String /G dfr:ExtClearQueueCmd
		endif
		SVAR b=dfr:ExtClearQueueCmd
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		if(exists(fullPackagePath+":funcState")==0)
			Variable /G dfr:funcState=0
		endif
		NVAR a=dfr:funcState
		AbortOnValue !NVAR_Exists(a), -1
		
		if(exists(fullPackagePath+":execTime")==0)
			Variable /G dfr:execTime=0
		endif
		NVAR a=dfr:execTime
		AbortOnValue !NVAR_Exists(a), -1
		
		if(exists(fullPackagePath+":readLen")==0)
			Variable /G dfr:readLen=0
		endif
		NVAR a=dfr:readLen
		AbortOnValue !NVAR_Exists(a), -1
		
		if(exists(fullPackagePath+":sessionID")==0)
			Variable /G dfr:sessionID=-1
		endif
		NVAR a=dfr:sessionID
		AbortOnValue !NVAR_Exists(a), -1
		
		if(exists(fullPackagePath+":callbackFuncName")==0)
			String /G dfr:callbackFuncName=""
		endif
		SVAR b=dfr:callbackFuncName
		AbortOnValue !SVAR_Exists(b), -1
		
		if(exists(fullPackagePath+":callbackParam")==0)
			String /G dfr:callbackParam=""
		endif
		SVAR b=dfr:callbackParam
		AbortOnValue !SVAR_Exists(b), -1
		
		if(exists(fullPackagePath+":countNumber")==0)
			Variable /G dfr:countNumber=0
		endif
		NVAR a=dfr:countNumber
		AbortOnValue !NVAR_Exists(a), -1
		
		if(exists(fullPackagePath+":responseStr")==0)
			String /G dfr:responseStr=""
		endif
		SVAR b=dfr:responseStr
		AbortOnValue !SVAR_Exists(b), -1
		
		if(exists(fullPackagePath+":sendCmd")==0)
			String /G dfr:sendCmd=""
		endif
		SVAR b=dfr:sendCmd
		AbortOnValue !SVAR_Exists(b), -1
		
		if(exists(fullPackagePath+":clearQueueCmd")==0)
			String /G dfr:clearQueueCmd=visaComm_DefaultClearQueueCmd
		endif
		SVAR b=dfr:clearQueueCmd
		AbortOnValue !SVAR_Exists(b), -1		
	catch
		abort "error setting up the variables used in VISA background task"
	endtry	
End

Function visaComm_SendAsyncRequest(instr, cmdstr, repeatwrite, readtype, readlen, clearoutputqueue, callbackFunc, callbackParam, [cycle_ticks])
	Variable instr
	String cmdstr
	Variable repeatwrite
	Variable readtype, readlen
	String clearoutputqueue
	String callbackFunc
	String callbackParam
	Variable cycle_ticks
	
	visaComm_SetupBackgroundTask()
	
	String savedDF=GetDataFolder(1)
	String fullPackagePath=visaComm_PackageRoot+":"+visaComm_PackageFolderName
	SetDataFolder(fullPackagePath)
	
	NVAR request=ExtRequest
	NVAR requesttype=ExtRequestType
	NVAR session=ExtSessionID
	NVAR setlen=ExtReadLen
	SVAR callName=ExtCallbackFuncName
	SVAR callParam=ExtCallbackParam
	SVAR cmdOut=ExtCmdOut
	SVAR clearQueue=ExtClearQueueCmd
	
	if(request==0)
		Variable ropt_clearqueue=0, ropt_repeatwrite=0, ropt_useprefix=0, ropt_setreadlen=0
		if(cmpstr(clearoutputqueue, visaComm_NoClearQueue)!=0)
			ropt_clearqueue=1
			if(strlen(clearoutputqueue)>0)
				clearQueue=clearoutputqueue
			else
				clearQueue=visaComm_DefaultClearQueueCmd
			endif
		else
			clearQueue=""
		endif
		if(repeatwrite!=0)
			ropt_repeatwrite=2
		endif
		
		if(readtype==2)
			ropt_useprefix=4
		elseif(readtype==1)
			ropt_setreadlen=8
		endif
		requesttype=ropt_clearqueue | ropt_repeatwrite | ropt_useprefix | ropt_setreadlen
		session=instr
		setlen=readlen
		callName=callbackFunc
		callParam=callbackParam
		cmdOut=cmdstr
		request=1
		
		CtrlNamedBackground visaComm_BackgroundTask, status
		if(str2num(StringByKey("RUN", S_info))==0)
			CtrlNamedBackground visaComm_BackgroundTask, burst=0, dialogsOK=1, proc=visaComm_WriteAndReadTask
			if(ParamIsDefault(cycle_ticks) || cycle_ticks<2)
				cycle_ticks=visaComm_bkgd_task_ticks
			endif
			CtrlNamedBackground visaComm_BackgroundTask, period=(cycle_ticks)			
			CtrlNamedBackground visaComm_BackgroundTask, start
		else
			if(!ParamIsDefault(cycle_ticks) && cycle_ticks>=2)
				CtrlNamedBackground visaComm_BackgroundTask, period=(cycle_ticks)
			endif
		endif
	else
		print "Last request has not been processed yet. Background Task is busy"
	endif
	SetDataFolder(savedDF)
End
