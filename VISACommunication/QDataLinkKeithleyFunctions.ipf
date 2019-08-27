#pragma IndependentModule= QDataLinkCore
#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//////////////////////////////////////////////////////////////////////////////
//Please use the following as a template to define user functions
//////////////////////////////////////////////////////////////////////////////

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
		if(request[slot] & QDL_REQUEST_WRITE_COMPLETE)
			//request[slot]=request[slot] & (~QDL_REQUEST_WRITE_COMPLETE)
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
			
			ThreadGroupPutDF 0, :dfr; AbortOnRTE
			print "data message sent to background function with instance and slot as:", inst, slt
		endif
		
		if(nextround_flag==1)
			//initiate the next cycle
			//print "Keithley rtfunc next round initiated..."
			String cmdStr=param[slot]; AbortOnRTE
			Variable req_update=0
			if(strlen(cmdStr)>0)
				if(cmpstr("__STOP__", cmdStr)==0)
					cmdStr=""
					param[slot]=cmdStr
					req_update=0
				else
					Variable readFlag=str2num(cmdStr[0])				
					String cmdStr2=cmdStr[1,inf]
					cmdStr=cmdStr2
					print "new user command sent: ", cmdStr
					print "readFlag set to: ", readFlag
					req_update=QDL_REQUEST_WRITE
					if(readFlag!=0)
						req_update = req_update | QDL_REQUEST_READ
					endif
					cmdStr2=""
					param[slot]=cmdStr2
				endif
			else
				cmdStr=""; AbortOnRTE
				param[slot]=cmdStr; AbortOnRTE
				req_update=QDL_REQUEST_WRITE; AbortOnRTE //blank write only. no real actions, just keep rtfunc getting called
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
						tmpstr=""
						outbox[slot_in] = tmpstr
						request[slot_in] = QDL_REQUEST_WRITE
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
				Variable /G root:V_KeithleyActiveFlag=0
				print "root:V_KeithleyActiveFlag created. Setting this to 0 stops probing, set to 1 starts probing, set to -1 force stopping."
			endif
			
			SVAR extra_cmd=root:S_KeithleyCMD
			NVAR extra_cmd_readflag=root:V_KeithleyCMDReadFlag
			
			if(SVAR_Exists(extra_cmd) && NVAR_Exists(extra_cmd_readflag))
				if(strlen(extra_cmd)>0 && request[slot_in]!=0)
					if(extra_cmd_readflag!=0)
						tmpstr="1"+extra_cmd
					else
						tmpstr="0"+extra_cmd
					endif
					param[slot_in]=tmpstr
					extra_cmd=""
					extra_cmd_readflag=0
				endif
			else
				String /G root:S_KeithleyCMD=""
				Variable /G root:V_KeithleyCMDReadFlag=0
				print "root:S_KeithleyCMD and root:V_KeithleyCMDReadFlag created. send user commands to this string."				
			endif
		elseif(DataFolderRefStatus(dfr)==3) //Do not delete data folder as it will be handled at higher level
			String privateDF=WBPkgGetName(instanceDir, WBPkgDFDF, "Keithley2600"); AbortOnRTE
			DFREF privateDFR=$privateDF
			if(DataFolderRefStatus(privateDFR)!=1)
				print "prepare privateDF for Keithley2600:", privateDF
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
				Make /D/N=(Keithley2600_MAX_RECORD_LEN, 6) history_record=NaN
			else
				SetDataFolder $privateDF
			endif
			
			NVAR instance=:instance; AbortOnRTE
			NVAR instance2=dfr:instance; AbortOnRTE
			instance=instance2
			
			NVAR slot=:slot; AbortOnRTE
			NVAR slot2=dfr:slot; AbortOnRTE
			slot=slot2
			
			SVAR sent_cmd=:sent_cmd; AbortOnRTE
			SVAR sent_cmd2=dfr:sent_cmd; AbortOnRTE
			sent_cmd=sent_cmd2
			
			SVAR received_message=:received_message; AbortOnRTE
			SVAR received_message2=dfr:received_message; AbortOnRTE
			received_message=received_message2
			
			NVAR request_status=:request_status; AbortOnRTE
			NVAR request_status2=dfr:request_status; AbortOnRTE
			request_status=request_status2

			print "sent command: ", sent_cmd
			print "received_message: ", received_message
			
//			WAVE history_record=:history_record
//			NVAR counter=:record_counter
//			history_record[counter][0,3]=input_chn[q]
//			history_record[counter][4,7]=output_chn[q-4]
//			history_record[counter][8]=data_timestamp
//			history_record[counter][9]=pid_setpoint
//			history_record[counter][10]=pid_scale_factor
//			history_record[counter][11]=pid_offset_factor
//			history_record[counter][12]=cpu_load_total
//			history_record[counter][13]=request_id_in
//			history_record[counter][14]=request_id_out
			
//			counter+=1
//			if(counter>=Keithley2600_MAX_RECORD_LEN)
//				counter=0
//			endif
		endif
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "EMController_postprocess_bgfunc encountered an error for slot "+num2istr(slot_in)+": "+GetErrMessage(err)
		endif
	endtry
	
	SetDataFolder olddfr
	
	return 0
End

