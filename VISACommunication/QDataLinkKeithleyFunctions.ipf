#pragma IndependentModule= QDataLinkCore
#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//////////////////////////////////////////////////////////////////////////////
//Please use the following as a template to define user functions
//////////////////////////////////////////////////////////////////////////////
Constant KUSRCMD_STATUS_MESSAGESENT			=0x01
Constant KUSRCMD_STATUS_RESPONSERECEIVED	=0x02
Constant KUSRCMD_STATUS_NEW					=0x10
Constant KUSRCMD_STATUS_OLD					=0x20

//DO NOT MODIFY OR DELETE, NEEDED by Keithley2600 Module
ThreadSafe Function Keithley2600_rtfunc(Variable inittest, [Variable slot, STRUCT QDLConnectionParam & cp, WAVE request, WAVE status, WAVE /T inbox, WAVE /T outbox, WAVE /T param, WAVE /T auxret])
	Variable dfr_flag=0
	Variable nextround_flag=0
	
	String msg=""
	if(inittest==1) //initial call just to verify that the function exists
		return 0xFE //return some non-zero magic values so that you know it is the correct one that returned.
	endif
	
	//all optional parameters will be properly defined, by design, from the caller in the worker thread
	try
		NVAR LAST_USERCMD_STATUS=:LAST_USERCMD_STATUS; AbortOnRTE
		if(!NVAR_Exists(LAST_USERCMD_STATUS))
			Variable /G :LAST_USERCMD_STATUS; AbortOnRTE
			NVAR LAST_USERCMD_STATUS=:LAST_USERCMD_STATUS; AbortOnRTE
		endif
		
		if(request[slot] & QDL_REQUEST_WRITE_COMPLETE)
			if(LAST_USERCMD_STATUS & KUSRCMD_STATUS_NEW)
				LAST_USERCMD_STATUS = (LAST_USERCMD_STATUS & (~KUSRCMD_STATUS_NEW)) | KUSRCMD_STATUS_MESSAGESENT
			endif	
			if(strlen(outbox[slot])==0) //blank write operation, goto next round directly
				nextround_flag=1
			elseif((request[slot] & QDL_REQUEST_READ)==0) //actual writing done and not expecting response
				dfr_flag=1
				nextround_flag=1
			endif
		endif
		if(request[slot] & QDL_REQUEST_READ_COMPLETE)
			//reading task is done
			dfr_flag=1
			Variable retCnt=0
			String cleanupCmd="*CLS"
			viWrite(cp.instr, cleanupCmd, strlen(cleanupCmd), retCnt)
			if(retCnt!=strlen(cleanupCmd))
				print "*CLS was not sent properly. retCnt:", retCnt
			endif
			retCnt=0
			cleanupCmd="status.reset(); status.request_enable=status.MAV"
			viWrite(cp.instr, cleanupCmd, strlen(cleanupCmd), retCnt)
			if(retCnt!=strlen(cleanupCmd))
				print "'status.reset(); status.request_enable=status.MAV' was not sent properly. retCnt:", retCnt
			endif
			nextround_flag=1
			if(!(LAST_USERCMD_STATUS & KUSRCMD_STATUS_OLD) && (LAST_USERCMD_STATUS & KUSRCMD_STATUS_MESSAGESENT))
				if(!(LAST_USERCMD_STATUS & KUSRCMD_STATUS_RESPONSERECEIVED))
					LAST_USERCMD_STATUS = LAST_USERCMD_STATUS | KUSRCMD_STATUS_RESPONSERECEIVED
				endif
			endif
		else
			dfr_flag=0
		endif
		
		if(dfr_flag==1)
			msg=inbox[slot]
			//print "message received: ", msg
			//print "request status: ", request[slot]
			//need to send message back to background post-process function
			NewDataFolder :dfr; AbortOnRTE
			Variable /G :dfr:instance; AbortOnRTE
			Variable /G :dfr:slot; AbortOnRTE
			String /G :dfr:sent_cmd; AbortOnRTE
			String /G :dfr:received_message=""; AbortOnRTE
			Variable /G :dfr:request_status; AbortOnRTE
			Variable /G :dfr:last_usercmd_status; AbortOnRTE
			
			NVAR inst=:dfr:instance; AbortOnRTE
			inst=cp.instance; AbortOnRTE
			NVAR slt=:dfr:slot; AbortOnRTE
			slt=slot; AbortOnRTE
			SVAR recv_msg=:dfr:received_message; AbortOnRTE
			recv_msg=inbox[slot]; AbortOnRTE
			NVAR req_stat=:dfr:request_status; AbortOnRTE
			req_stat=request[slot]; AbortOnRTE
			SVAR snt_cmd=:dfr:sent_cmd; AbortOnRTE
			snt_cmd=outbox[slot]; AbortOnRTE
			NVAR last_status=:dfr:last_usercmd_status; AbortOnRTE
			last_status=LAST_USERCMD_STATUS
			
			ThreadGroupPutDF 0, :dfr; AbortOnRTE
		endif
		
		if(nextround_flag==1)
			//initiate the next cycle
			//print "Keithley rtfunc next round initiated..."
			String cmdStr=param[slot]; AbortOnRTE
			Variable req_update=QDL_REQUEST_WRITE
			if(strlen(cmdStr)>0)
				//print "cmd "+cmdStr+" received by rtfunc."
				if(cmpstr("__STOP__", cmdStr)==0)
					cmdStr=""
					param[slot]=cmdStr
					req_update=0
					LAST_USERCMD_STATUS=0
				else
					Variable readFlag=str2num(cmdStr[0])				
					String cmdStr2=cmdStr[1,inf]
					cmdStr=cmdStr2
					LAST_USERCMD_STATUS = KUSRCMD_STATUS_NEW
					if(readFlag!=0)
						req_update = req_update | QDL_REQUEST_READ
					endif
					
					cmdStr2=""
					param[slot]=cmdStr2					
				endif
			else
				LAST_USERCMD_STATUS=LAST_USERCMD_STATUS | KUSRCMD_STATUS_OLD
			endif
			outbox[slot]=cmdStr; AbortOnRTE
			cmdStr=""; AbortOnRTE
			inbox[slot]=cmdStr; AbortOnRTE
			request[slot]=req_update; AbortOnRTE
		endif
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "EMController_rtfunc encountered an error for slot "+num2istr(slot)+": "+GetErrMessage(err)
		endif
	endtry
	return 0
End

//DO NOT MODIFY OR DELETE, NEEDED by EMController Module
Constant Keithley2600_MAX_RECORD_LEN=3000
Function Keithley2600_postprocess_bgfunc(Variable instance_in, Variable slot_in, Variable dfr_received, DFREF dfr, String instanceDir)
	DFREF olddfr=GetDataFolderDFR(); AbortOnRTE
	try
		//print "Keithley background function called."
		String PkgPath=WBSetupPackageDir(QDLPackageName); AbortOnRTE
		WAVE /T outbox=$WBPkgGetName(PkgPath, WBPkgDFWave, "outbox_all"); AbortOnRTE
		WAVE /T inbox=$WBPkgGetName(PkgPath, WBPkgDFWave, "inbox_all"); AbortOnRTE
		WAVE /T param=$WBPkgGetName(PkgPath, WBPkgDFWave, "auxparam_all"); AbortOnRTE
		WAVE request=$WBPkgGetName(PkgPath, WBPkgDFWave, "request_record"); AbortOnRTE
		
		String privateDF=WBPkgGetName(instanceDir, WBPkgDFDF, "Keithley2600"); AbortOnRTE
		DFREF privateDFR=$privateDF
		if(DataFolderRefStatus(privateDFR)!=1)
			qdl_log("prepare privateDF for Keithley2600: "+privateDF, 0, 0, 0, 0)
			WBPrepPackagePrivateDF(instanceDir, "Keithley2600", nosubdir=1); AbortOnRTE
			privateDF=WBPkgGetName(instanceDir, WBPkgDFDF, "Keithley2600"); AbortOnRTE
			
			SetDataFolder $privateDF; AbortOnRTE
			
			Variable /G instance; AbortOnRTE
			Variable /G slot; AbortOnRTE
			String /G sent_cmd; AbortOnRTE
			String /G received_message=""; AbortOnRTE				
			Variable /G request_status; AbortOnRTE
			Variable /G smua_V; AbortOnRTE
			Variable /G smua_I; AbortOnRTE
			Variable /G smua_t; AbortOnRTE
			Variable /G smub_V; AbortOnRTE
			Variable /G smub_I; AbortOnRTE
			Variable /G smub_t; AbortOnRTE
			Variable /G record_counter=0; AbortOnRTE
			Variable /G last_usercmd_status=0; AbortOnRTE
			Make /D/N=(Keithley2600_MAX_RECORD_LEN, 6) history_record=NaN; AbortOnRTE
		else
			SetDataFolder $privateDF; AbortOnRTE
		endif
		
		NVAR instance=:instance; AbortOnRTE
		NVAR slot=:slot; AbortOnRTE
		SVAR sent_cmd=:sent_cmd; AbortOnRTE
		SVAR received_message=:received_message; AbortOnRTE
		NVAR request_status=:request_status; AbortOnRTE
		WAVE history_record=:history_record; AbortOnRTE
		NVAR counter=:record_counter; AbortOnRTE
		NVAR last_status=:last_usercmd_status; AbortOnRTE
		NVAR smua_V=:smua_V; AbortOnRTE
		NVAR smua_I=:smua_I; AbortOnRTE
		NVAR smua_t=:smua_t; AbortOnRTE
		NVAR smub_V=:smub_V; AbortOnRTE
		NVAR smub_I=:smub_I; AbortOnRTE
		NVAR smub_t=:smub_t; AbortOnRTE
			
		String tmpstr=""
		if(dfr_received==0)
			//no dfr received
			NVAR active=root:V_KeithleyActiveFlag
			if(NVAR_Exists(active))
				switch(active)
				case 0://gracefully stop activity
					if(request[slot_in]!=0)
						tmpstr="__STOP__"
						param[slot_in]=tmpstr
					endif
					break
				case 1: //normal requests
					if(request[slot_in]==0)
						tmpstr="status.reset(); status.request_enable=status.MAV"
						outbox[slot_in] = tmpstr
						request[slot_in] = QDL_REQUEST_WRITE
						qdl_log("initialized keithley by resetting status.request_enable=status.MAV", 0, 0, 0, 0)
					endif
					break
				case -1: //force reset
					tmpstr=""
					outbox[slot_in]=tmpstr
					inbox[slot_in]=tmpstr
					param[slot_in]=tmpstr
					request[slot_in]=0
					active=0
				default:
					break
				endswitch
			else
				Variable /G root:V_KeithleyActiveFlag=1
				qdl_log("root:V_KeithleyActiveFlag created. Setting this to 0 stops probing, set to 1 starts probing, set to -1 force stopping.", 0, 0, 0, 0)
			endif
			
			SVAR extra_cmd=root:S_KeithleyCMD //cmd that needs to be sent
			NVAR extra_cmd_readflag=root:V_KeithleyCMDReadFlag //does cmd expect to receive response from keithley
			NVAR extra_cmd_update=root:V_KeithleyCMDUpdateFlag //flag will be set when response is received
			
			if(SVAR_Exists(extra_cmd) && NVAR_Exists(extra_cmd_readflag) && NVAR_Exists(extra_cmd_update))
				if(strlen(extra_cmd)>0 && request[slot_in]!=0)
					if(extra_cmd_readflag!=0)
						tmpstr="1"+extra_cmd
					else
						tmpstr="0"+extra_cmd
					endif
					last_status=0
					param[slot_in]=tmpstr
					//print "parameter sets to "+tmpstr+" for rtfunc to read."
					extra_cmd=""
					extra_cmd_readflag=0
					extra_cmd_update=0
				endif
			else
				String /G root:S_KeithleyCMD=""
				Variable /G root:V_KeithleyCMDReadFlag=0
				Variable /G root:V_KeithleyCMDUpdateFlag=0
				qdl_log("root:S_KeithleyCMD and root:V_KeithleyCMDReadFlag created. send user commands to this string.", 0, 0, 0, 0)
			endif
		elseif(DataFolderRefStatus(dfr)==3) //Do not delete data folder as it will be handled at higher level
			//print "dfr received by bgfunc of keithley"
			
			NVAR instance2=dfr:instance; AbortOnRTE
			instance=instance2
			
			NVAR slot2=dfr:slot; AbortOnRTE
			slot=slot2
			
			SVAR sent_cmd2=dfr:sent_cmd; AbortOnRTE
			sent_cmd=sent_cmd2
			
			SVAR received_message2=dfr:received_message; AbortOnRTE
			received_message=received_message2
			
			NVAR request_status2=dfr:request_status; AbortOnRTE
			request_status=request_status2
			
			//print "Keithley returned message: "+received_message
			Variable data_updateflag=str2num(StringByKey("DATA_UPDATE", received_message))
			
			if(data_updateflag==1)
				sscanf StringByKey("SMUA_I", received_message), "%f", smua_I
				sscanf StringByKey("SMUA_V", received_message), "%f", smua_V
				sscanf StringByKey("SMUA_t", received_message), "%f", smua_t
				
				sscanf StringByKey("SMUB_I", received_message), "%f", smub_I
				sscanf StringByKey("SMUB_V", received_message), "%f", smub_V
				sscanf StringByKey("SMUB_t", received_message), "%f", smub_t
				
				//print /D smua_I,smua_V,smua_t
				//print /D smub_I,smub_V,smub_t
				
				history_record[counter][0]=smua_I
				history_record[counter][1]=smua_V
				history_record[counter][2]=smua_t
				history_record[counter][3]=smub_I
				history_record[counter][4]=smub_V
				history_record[counter][5]=smub_t

				counter+=1
				if(counter>=Keithley2600_MAX_RECORD_LEN)
					counter=0
				endif
			endif
			
			NVAR last_status2=dfr:last_usercmd_status; AbortOnRTE
			if(last_status==0) //the local status stored has been just reset
				if(!(last_status2 & KUSRCMD_STATUS_OLD)) //the first response from keithley after a new cmd was sent
					last_status=last_status2; AbortOnRTE
					//print "keithley user cmd status first updated to :", last_status
				endif //any other update with the OLD status bit means it is not related to the latest user cmd (since reset)
			elseif(!(last_status & KUSRCMD_STATUS_OLD)) //local status has been updated since reset, but no OLD bit set yet
				if(!(last_status2 & KUSRCMD_STATUS_OLD))//the update is not yet "OLD"
					last_status=last_status2
					//print "keithley user cmd status updated to :", last_status
				else //update is now "OLD", meaning there is no relevance to the user command.
					last_status=last_status | KUSRCMD_STATUS_OLD
					//print "Keithley OLD STATUS bit now set for user cmd status."
				endif
			endif			
		endif
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			qdl_log("EMController_postprocess_bgfunc encountered an error for slot "+num2istr(slot_in)+": "+GetErrMessage(err), 65535, 0, 0, 0)
		endif
	endtry
	
	SetDataFolder olddfr
	
	return 0
End

