//	Copyright 2013-, Quan Qing, Nanoelectronics for Biophysics Lab, Arizona State University
// Web: http://qinglab.physics.asu.edu
// Email: quan.qing@asu.edu, quan.qing@yahoo.com
//	
//	Redistribution and use in source and binary forms, with or without
//	modification, are permitted provided that the following conditions
//	are met:
//	
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above copyright
//	  notice, this list of conditions and the following disclaimer in the
//	   documentation and/or other materials provided with the distribution.
//	
//	THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//	IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//	OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//	IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//	NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//	THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//	THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

//ChangeLog
//Last updated 2015/10/20
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "WaveBrowser"

Constant visaComm_ReadWaitTime=50 // in milliseconds
Constant visaComm_ReadPacketSize=4096
Constant visaComm_NoWait=0
Constant visaComm_WaitForEver=-1
//StrConstant visaComm_PackageRoot="root:Packages"
//StrConstant visaComm_PackageFolderName="VISACommunication"
StrConstant visaComm_PackageName="VISAComm"


StrConstant visaComm_PanelName="VISACommBkgrdTsk"
Constant visaComm_bkgd_task_ticks=3

//TODO:need to fix the default init strings. currently keithley control package uses this and this should be really moved to that package.
StrConstant visaComm_DefaultInitString="*CLS\rstatus.reset() status.request_enable=status.MAV\rformat.data=format.REAL64 format.byteorder=1"
StrConstant visaComm_DefaultClearQueueCmd="*CLS\rstatus.reset() status.request_enable=status.MAV"
StrConstant visaComm_DefaultShutdownCmd="*CLS\rreset()"
//TODO:should just use a constant instead of a string for this option
StrConstant visaComm_NoClearQueue="NO_CLEAR"

StrConstant visaComm_DEBUGSTR="KEITHLEY INSTRUMENTS.*MODEL 2636B [DEBUG MODE STRING]"

Function visaComm_CheckError(session, viObject, status, [quiet, AbortOnError])
	Variable session
	Variable viObject
	Variable status
	Variable quiet
	Variable AbortOnError
#ifndef DEBUGONLY
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
#endif
	return status
End

Function /S visaComm_GetList([filter, quiet])
	String filter
	Variable quiet
	
#ifndef DEBUGONLY
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
#else
	String list="SIMULATED_COM;"
#endif
	return list
End

Function visaComm_Init(instrDesc, [sessionRM, sessionINSTR, initCmdStr, quiet])
	String instrDesc
	Variable & sessionRM
	Variable & sessionINSTR
	String initCmdStr
	Variable quiet
	
	Variable len, retCnt	
	Variable status=0
	Variable RM, INSTR
#ifndef DEBUGONLY
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
		KillStrings /Z V_VISAsessionRM
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
#else
	if(ParamIsDefault(sessionRM))
		KillVariables /Z V_VISAsessionRM
		KillStrings /Z V_VISAsessionRM
		Variable /G V_VISAsessionRM=0
	else
		sessionRM=0
	endif
	if(ParamIsDefault(sessionINSTR))
		KillVariables /Z V_VISAsessionINSTR
		KillStrings /Z V_VISAsessionINSTR
		Variable /G V_VISAsessionINSTR=0
	else
		sessionINSTR=0
	endif
#endif
	return status
End

Function visaComm_Shutdown(instr, [openRM, shutdownCmdStr])
	Variable instr
	Variable openRM
	String shutdownCmdStr
	
	Variable len, retCnt
	Variable status=0
#ifndef DEBUGONLY
	if(ParamIsDefault(shutdownCmdStr))
		shutdownCmdStr=visaComm_DefaultShutdownCmd
	endif
	visaComm_WriteSequence(instr, shutdownCmdStr)	
	viClose(instr)
	if(!ParamIsDefault(openRM))
		viClose(openRM)
	endif
#endif
	return status
End

Function visaComm_DequeueEvent(instr, timeout_ms, clearPreviousEvents, retOnTimeOut)
	Variable instr, timeout_ms
	Variable clearPreviousEvents, retOnTimeOut
	
	Variable status, event, context
	
	status=0
#ifndef DEBUGONLY
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
#endif
	return status
End

Function visaComm_ReadStr(instr, str, packetSize, len) //read string until terminal character is reached, or if len>0, read the string of that length
	Variable instr
	String & str
	Variable packetSize
	Variable & len

	Variable status=0
#ifndef DEBUGONLY	
	Variable rflag=1, retCnt, rlen
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
#else
	str=visaComm_DEBUGSTR;
#endif

	return status
End

Function visaComm_ReadFixedWithPrefix(instr, str)
	Variable instr
	String & str
	
	Variable len=0
	Variable termChar
	String buf
#ifndef DEBUGONLY
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
#endif
End

Function visaComm_WriteSequence(instr, cmd)
	Variable instr
	String cmd
	Variable status=VI_SUCCESS
#ifndef DEBUGONLY
	String str
	Variable n=ItemsInList(cmd, "\r")
	Variable i, len, retCnt
	
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
#endif
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

#ifndef DEBUGONLY

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
#else
	if(!ParamIsDefault(response))
		response=visaComm_DEBUGSTR
	endif
#endif

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
		Variable instance=str2num(GetUserData(ba.win, ba.ctrlName, "instance"))
		//String savedDF=GetDataFolder(1)
		//String fullPackagePath=visaComm_PackageRoot+":"+visaComm_PackageFolderName
		String fullPackagePath=WBSetupPackageDir(visaComm_PackageName, instance=instance, existence=WBPkgShouldExist)
		//SetDataFolder(fullPackagePath); AbortOnRTE
		NVAR request=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtRequest")
		//if(NVAR_Exists(request))
			request=-99
		//endif
		//SetDataFolder(savedDF)	
		break
	case -1: // control being killed
		break
	endswitch
End

Function visaComm_WriteAndReadTask(s)
	STRUCT WMBackgroundStruct &s
	Variable timer1=StartMSTimer
	
	//String savedDF=GetDataFolder(1)
	Variable instance=str2num(StringFromList(1, s.name, "_"))
	
	//String fullPackagePath=visaComm_PackageRoot+":"+visaComm_PackageFolderName
	String fullPackagePath=WBSetupPackageDir(visaComm_PackageName, instance=instance, existence=WBPkgShouldExist)
	Variable retVal=0
	try
		AbortOnValue !DataFolderExists(fullPackagePath), -100
		
		//SetDataFolder(fullPackagePath); AbortOnRTE
		
		NVAR request=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtRequest") //set by user
		NVAR requestType=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtRequestType") //set by user
		
		SVAR setcmd=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtCmdOut") //set by user
		SVAR setclearcmd=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtClearQueueCmd") //set by user
		NVAR setsession=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtSessionID") //set by user
		NVAR setlen=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtReadLen") //set by user
		
		SVAR setParam=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtCallbackParam") //set by user
		SVAR setFuncName=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtCallbackFuncName") //set by user
		
		NVAR state=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "funcState") //state of the background task
		NVAR exec_time=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "execTime") //how much time for each cycle execution
		SVAR cmd=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "sendCmd")
		NVAR count=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "countNumber") // how many cycles the call back function has been called
		SVAR clearQCmd=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "clearQueueCmd")
		NVAR session=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "sessionID")
		NVAR fixedlen=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "readLen")
		
		SVAR callParam=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "callbackParam")
		SVAR callFuncName=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "callbackFuncName")
		
		SVAR response=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "responseStr")	
		
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
	//SetDataFolder(savedDF)	
	if(retVal!=0)
		if(WinType(visaComm_PanelName)==7)
			KillWindow $visaComm_PanelName
		endif
	else
		if(WinType(visaComm_PanelName)==0)
			NewPanel /FLT=1 /K=2 /N=$visaComm_PanelName /W=(0,0,120,40)
			Button /Z visaComm_PanelButton font="Arial", fsize=10, fstyle=1, title="VISA Running..", valueColor=(65535,0,0), win=$visaComm_PanelName, size={80, 20}, pos={20, 10}, proc=visaComm_PanelButtonFunc, userdata(instance)=num2istr(instance)
			SetActiveSubwindow _endfloat_
		endif
	endif
	if(timer1!=-1)
		exec_time=stopMSTimer(timer1)/1000000
	endif

	if(retVal!=0)
		print "visaComm background task instance ["+num2istr(instance)+"] exited with code "+num2istr(retVal)
	endif
	return retVal
End


StrConstant visaComm_VARLIST="ExtRequest;ExtRequestType;ExtSessionID;ExtReadLen;funcState;execTime;readLen;sessionID;countNumber"
StrConstant visaComm_STRLIST="ExtCallbackFuncName;ExtCallbackParam;ExtCmdOut;ExtClearQueueCmd;callbackFuncName;callbackParam;responseStr;sendCmd;clearQueueCmd"

Function visaComm_SetupBackgroundTask(name, [instance])
	String name
	Variable instance
	
	if(ParamIsDefault(instance))
		instance=WBPkgNewInstance
	endif
	
	String PackageDir
	if(instance==WBPkgNewInstance)
		PackageDir=WBSetupPackageDir(visaComm_PackageName, instance=instance, existence=WBPkgExclusive, name=name)
	else
		PackageDir=WBSetupPackageDir(visaComm_PackageName, instance=instance, existence=WBPkgOverride, name=name)
	endif
	
	WBPrepPackageVars(PackageDir, visaComm_VARLIST)
	WBPrepPackageStrs(PackageDir, visaComm_STRLIST)
	
	try
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "ExtRequest")
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar,"ExtRequestType")
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "ExtSessionID")
		AbortOnValue !NVAR_Exists(a), -1
		a=-1
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "ExtReadLen")
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "ExtCallbackFuncName")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "ExtCallbackParam")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "ExtCmdOut")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "ExtClearQueueCmd")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "funcState")
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "execTime")
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "readLen")
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "sessionID")
		AbortOnValue !NVAR_Exists(a), -1
		a=-1
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "callbackFuncName")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "callbackParam")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		NVAR a=$WBPkgGetName(PackageDir, WBPkgDFVar, "countNumber")
		AbortOnValue !NVAR_Exists(a), -1
		a=0
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "responseStr")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "sendCmd")
		AbortOnValue !SVAR_Exists(b), -1
		b=""
		
		SVAR b=$WBPkgGetName(PackageDir, WBPkgDFStr, "clearQueueCmd")
		AbortOnValue !SVAR_Exists(b), -1		
		b=""
	catch
		abort "error setting up the variables used in VISA background task"
	endtry	
	
	return instance
End

Function visaComm_SendAsyncRequest(instr, cmdstr, repeatwrite, readtype, readlen, clearoutputqueue, callbackFunc, callbackParam, [cycle_ticks, instance])
	Variable instr
	String cmdstr
	Variable repeatwrite
	Variable readtype, readlen
	String clearoutputqueue
	String callbackFunc
	String callbackParam
	Variable cycle_ticks
	Variable instance
	
	if(ParamIsDefault(instance))
		instance=WBPkgNewInstance
	endif
	
	String name=""
	Variable status
	
	status = viGetAttributeString(instr, VI_ATTR_INTF_INST_NAME, name)
	if(status!=VI_SUCCESS)
		name="N/A"
	endif
	
	instance=visaComm_SetupBackgroundTask(name, instance=instance)
		
	//String savedDF=GetDataFolder(1)
	String fullPackagePath=WBSetupPackageDir(visaComm_PackageName, instance=instance)
	//SetDataFolder(fullPackagePath)
	
	NVAR request=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtRequest")
	NVAR requesttype=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtRequestType")
	NVAR session=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtSessionID")
	NVAR setlen=$WBPkgGetName(fullPackagePath, WBPkgDFVar, "ExtReadLen")
	SVAR callName=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtCallbackFuncName")
	SVAR callParam=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtCallbackParam")
	SVAR cmdOut=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtCmdOut")
	SVAR clearQueue=$WBPkgGetName(fullPackagePath, WBPkgDFStr, "ExtClearQueueCmd")
	
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
		
		String taskname="visaCommTsk_"+num2istr(instance)
		CtrlNamedBackground $(taskname), status
		if(str2num(StringByKey("RUN", S_info))==0)
			CtrlNamedBackground $(taskname), burst=0, dialogsOK=1, proc=visaComm_WriteAndReadTask
			if(ParamIsDefault(cycle_ticks) || cycle_ticks<2)
				cycle_ticks=visaComm_bkgd_task_ticks
			endif
			CtrlNamedBackground $(taskname), period=(cycle_ticks)			
			CtrlNamedBackground $(taskname), start
		else
			if(!ParamIsDefault(cycle_ticks) && cycle_ticks>=2)
				CtrlNamedBackground $(taskname), period=(cycle_ticks)
			endif
		endif
		print "visaComm background task instance ["+num2istr(instance)+"] initialized"
	else
		print "Last request has not been processed yet. Background Task instance ["+num2istr(instance)+"is busy"
	endif
	//SetDataFolder(savedDF)
	return instance
End
