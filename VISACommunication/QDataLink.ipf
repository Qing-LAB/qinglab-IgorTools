#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink
#include "QDataLinkconstants"
#include "QDataLinkCore"

///////////////////////////////////////////////////////////
//QDataLink data folder structure
//
//root|Packages|QDataLink
//                maxInstanceRecord
//                infoStr  <- stores active instances, crossrefs between instance# and connection port/names
//                       |privateDF
//                       |strs
//                       |vars
//                           visaDefaultRM <- stores the VISA default resource manager session number, initialized when loaded
//									  threadGroupID <- thread group ID for the thread workers, initialized when loaded
//                       |waves
//									  active_instance_record <- list of active instances for each slot of "active connections"
//                           connection_param_record <- correspondingly, the connection parameters (wave of string storing structure info)
//									  inbox_all <- message received for each active connection, updated in real-time by thread workers
//									  outbox_all <- message to be sent for each active connection
//									  auxparam_all <- auxillary parameters that can be read by thread workers in real-time
//									  auxret_all <- auxillary return information that can be accessed by thread workders
//									  rt_callback_func_list <- list of callback function names, threadsafe, that will be called by thread workders
//									  post_callback_func_list <- list of callback function names, that will be called by background task periodically
//                           request_record  <- request sent each active instances
//                           status_record   <- status returned for each active instances
//									  connection_type_info <- connection type and other information for thread handlers
//                       |instance0 <- holds all information on instance 0
//                       |instance1 <- holds all information on instance 1  <- each connection name will use the same instance # if possible
///////////////////////////////////////////////////////////

StrConstant QDLLogBookName="QDL_LOG"

Function QDLLog(String msg, [Variable r, Variable g, Variable b, Variable notimestamp])
	if(ParamIsDefault(r))
		r=0
	endif
	if(ParamIsDefault(g))
		g=0
	endif
	if(ParamIsDefault(b))
		b=0
	endif
	
	String wname=QDLLogBookName
	if(WinType(wname)!=5)
		NewNotebook /N=$wname /F=1 /K=3 /OPTS=12
		SetWindow $wname, userdata(LASTMESSAGE)=msg
		SetWindow $wname, userdata(LASTMESSAGE_REPEAT)="0"
	endif
	String lastmsg=GetUserData(wname, "", "LASTMESSAGE")
	Variable repeat=str2num(GetUserData(wname, "", "LASTMESSAGE_REPEAT"))
	String additional_str=""
	Variable repeated_msg=0
	if(cmpstr(msg,lastmsg)==0)
		repeated_msg=1
		repeat+=1
		additional_str="****Message repeated****\r\n"
	endif
	if(!repeated_msg)
		if(repeat>=1) //new message coming, last message was repeated
			additional_str="****Last message repeated "+num2istr(repeat+1)+" times.****\r\n"
		endif
		repeat=0
		SetWindow $wname, userdata(LASTMESSAGE)=msg
	endif
	SetWindow $wname, userdata(LASTMESSAGE_REPEAT)=num2istr(repeat)
	Notebook $wname, selection={endOfFile, endOfFile}, findText={"",1}
	
	if(repeat<2)
		if(strlen(additional_str)>0)
			Notebook $wname, textRGB=(65535, 0, 0), text=additional_str
		endif
		if(ParamIsDefault(notimestamp) || notimestamp==0)
			Notebook $wname, textRGB=(0, 0, 65535), text="["+date()+"] ["+time()+"]\r\n"
		endif
		Notebook $wname, textRGB=(r, g, b), text=msg+"\r\n"
	endif
End


