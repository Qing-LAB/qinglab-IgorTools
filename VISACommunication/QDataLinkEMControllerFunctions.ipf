#pragma IndependentModule= QDataLinkCore
#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//////////////////////////////////////////////////////////////////////////////
//Please use the following as a template to define user functions
//////////////////////////////////////////////////////////////////////////////
Constant EMC_USRCMD_STATUS_MSGSENT			=0x01
Constant EMC_USRCMD_STATUS_RESPONSERECEIVED	=0x02
Constant EMC_USRCMD_STATUS_NEW				=0x10
Constant EMC_USRCMD_STATUS_OLD				=0x20

//DO NOT MODIFY OR DELETE, NEEDED by EMController Module
ThreadSafe Function EMcontroller_rtfunc(Variable inittest, [Variable slot, STRUCT QDLConnectionParam & cp, WAVE request, WAVE status, WAVE /T inbox, WAVE /T outbox, WAVE /T param, WAVE /T auxret])
	Variable dfr_flag=0
	String msg=""
	if(inittest==1) //initial call just to verify that the function exists
		return 0xFF
	endif
	
	//all optional parameters will be properly defined, by design, from the caller in the worker thread
	try
		NVAR LAST_USER_CMD_STATUS=:LAST_USER_CMD_STATUS
		NVAR RESPONSE_COUNT_SINCE=:RESPONSE_COUNT_SINCE
		if(!NVAR_Exists(LAST_USER_CMD_STATUS) || !NVAR_Exists(RESPONSE_COUNT_SINCE))
			Variable /G LAST_USER_CMD_STATUS=0
			Variable /G RESPONSE_COUNT_SINCE=0
			print "LAST_USER_CMD_STATUS and RESPONSE_COUNT_SINCE created for thread worker."
			NVAR RESPONSE_COUNT_SINCE=:RESPONSE_COUNT_SINCE
			NVAR LAST_USER_CMD_STATUS=:LAST_USER_CMD_STATUS
		endif
		
		if(request[slot] & QDL_REQUEST_WRITE_COMPLETE)
			if(LAST_USER_CMD_STATUS & EMC_USRCMD_STATUS_NEW)
				LAST_USER_CMD_STATUS = (LAST_USER_CMD_STATUS & (~ EMC_USRCMD_STATUS_NEW)) | EMC_USRCMD_STATUS_MSGSENT
				RESPONSE_COUNT_SINCE = 0
			endif
		endif
		
		if(request[slot] & QDL_REQUEST_READ_COMPLETE)
			dfr_flag=1
			if(LAST_USER_CMD_STATUS & EMC_USRCMD_STATUS_MSGSENT)
				if(!(LAST_USER_CMD_STATUS & EMC_USRCMD_STATUS_RESPONSERECEIVED))
					LAST_USER_CMD_STATUS = LAST_USER_CMD_STATUS | EMC_USRCMD_STATUS_RESPONSERECEIVED
					RESPONSE_COUNT_SINCE = 0
				endif
			endif
		else
			dfr_flag=0
		endif
		
		if(dfr_flag==1)
			msg=inbox[slot]

			if(strlen(msg)>0)	
				RESPONSE_COUNT_SINCE+=1
				//need to send message back to background post-process function
				NewDataFolder :dfr; AbortOnRTE
				Variable /G :dfr:instance; AbortOnRTE
				Variable /G :dfr:slot; AbortOnRTE
				String /G :dfr:sent_cmd; AbortOnRTE
				String /G :dfr:received_message=""; AbortOnRTE
				Variable /G :dfr:request_status; AbortOnRTE
				Variable /G :dfr:request_id_out; AbortOnRTE
				Variable /G :dfr:request_id_in; AbortOnRTE
				Make /D/N=4 :dfr:input_chn=NaN; AbortOnRTE
				Make /D/N=4 :dfr:output_chn=NaN; AbortOnRTE
				Variable /G :dfr:pid_gain_P; AbortOnRTE
				Variable /G :dfr:pid_gain_I; AbortOnRTE
				Variable /G :dfr:pid_gain_D; AbortOnRTE
				Variable /G :dfr:pid_gain_filter; AbortOnRTE
				Variable /G :dfr:pid_scale_factor; AbortOnRTE
				Variable /G :dfr:pid_offset_factor; AbortOnRTE
				Variable /G :dfr:pid_setpoint; AbortOnRTE
				Variable /G :dfr:pid_input_chn=NaN; AbortOnRTE
				Variable /G :dfr:pid_output_chn=NaN; AbortOnRTE
				Variable /G :dfr:cpu_load_total; AbortOnRTE
				String /G :dfr:fpga_state=""; AbortOnRTE
				Variable /G :dfr:fpga_cycle_time; AbortOnRTE
				String /G :dfr:system_init_time=""; AbortOnRTE
				Variable /G :dfr:data_timestamp; AbortOnRTE
				Variable /G :dfr:status_timestamp; AbortOnRTE
				Variable /G :dfr:error_log_num; AbortOnRTE
				Variable /G :dfr:last_usrcmd_status; AbortOnRTE
				Variable /G :dfr:response_count_since; AbortOnRTE
				
				NVAR lus=:dfr:last_usrcmd_status; AbortOnRTE
				lus=LAST_USER_CMD_STATUS
				NVAR rcs=:dfr:response_count_since; AbortOnRTE
				rcs=RESPONSE_COUNT_SINCE

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
				
				String s=""; AbortOnRTE
				Variable d=NaN; AbortOnRTE
				s=StringByKey("REQUEST_ID", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%x", d; AbortOnRTE
				endif
				NVAR req_id_in=:dfr:request_id_in; AbortOnRTE
				req_id_in=d; AbortOnRTE
				
				s=StringByKey("REQUEST_ID", snt_cmd, ":", ";"); AbortOnRTE
				d=NaN
				if(strlen(s)>0)
					sscanf s, "%x", d; AbortOnRTE
				endif
				NVAR req_id_out=:dfr:request_id_out; AbortOnRTE
				req_id_out=d; AbortOnRTE
				
				variable clear_flag=0
				
				if(req_id_in==req_id_out || (numtype(req_id_in)==2 && numtype(req_id_out)==2))
					//print "REQUEST_ID matches in rtfunc!"
				else
					//print "EMController rtfunc WARNING: REQUEST_ID OUT does not match REQUEST_ID IN:", req_id_out, req_id_in
					clear_flag=QDL_REQUEST_CLEAR_BUFFER
				endif
				
				Variable d1,d2,d3,d4
				WAVE in_chn=:dfr:input_chn; AbortOnRTE
				s=StringByKey("INPUT_CHN_DATA", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f,%f,%f,%f", d1, d2, d3, d4; AbortOnRTE
					in_chn[0]=d1
					in_chn[1]=d2
					in_chn[2]=d3
					in_chn[3]=d4
				endif
				
				WAVE out_chn=:dfr:output_chn
				s=StringByKey("OUTPUT_CHN_DATA", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f,%f,%f,%f", d1, d2, d3, d4; AbortOnRTE
					out_chn[0]=d1
					out_chn[1]=d2
					out_chn[2]=d3
					out_chn[3]=d4
				endif
				
				NVAR Gain_P=:dfr:pid_gain_P; AbortOnRTE
				NVAR Gain_I=:dfr:pid_gain_I; AbortOnRTE
				NVAR Gain_D=:dfr:pid_gain_D; AbortOnRTE
				NVAR Gain_F=:dfr:pid_gain_filter; AbortOnRTE
				NVAR Gain_S=:dfr:pid_scale_factor; AbortOnRTE
				NVAR Gain_O=:dfr:pid_offset_factor; AbortOnRTE
				s=StringByKey("PID_GAINS", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f,%f,%f,%f,%f,%f", Gain_P, Gain_I, Gain_D, Gain_F, Gain_S, Gain_O; AbortOnRTE
				endif
				
				s=StringByKey("PID_SETPOINT", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f", d; AbortOnRTE
				endif
				NVAR pid_setpoint=:dfr:pid_setpoint; AbortOnRTE
				pid_setpoint=d; AbortOnRTE
				
				s=StringByKey("PID_INPUT_CHN", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%d", d; AbortOnRTE
				endif
				NVAR pid_inputchn=:dfr:pid_input_chn; AbortOnRTE
				pid_inputchn=d; AbortOnRTE
				
				s=StringByKey("PID_OUTPUT_CHN", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%d", d; AbortOnRTE
				endif
				NVAR pid_outputchn=:dfr:pid_output_chn; AbortOnRTE
				pid_outputchn=d; AbortOnRTE
				
				s=StringByKey("CPU_LOAD_PERCENT", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f", d; AbortOnRTE
				endif
				NVAR cpu_total=:dfr:cpu_load_total; AbortOnRTE
				cpu_total=d; AbortOnRTE
				
				s=StringByKey("FPGA_STATE", recv_msg, ":", ";"); AbortOnRTE
				SVAR fpga_state=:dfr:fpga_state; AbortOnRTE
				if(strlen(s)>0)
					fpga_state=s; AbortOnRTE
				endif
				
				s=StringByKey("FPGA_CYCLE_TIME", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f", d; AbortOnRTE
				endif
				NVAR fpga_cycle_time=:dfr:fpga_cycle_time; AbortOnRTE
				fpga_cycle_time=d; AbortOnRTE
				
				s=StringByKey("ERROR_NUMBER", recv_msg, ":", ";"); AbortOnRTE
				d=0
				if(strlen(s)>0)
					sscanf s, "%d", d; AbortOnRTE
				endif
				NVAR errnum=:dfr:error_log_num
				errnum=d
				
				s=StringByKey("SYSTEM_INIT_TIME", recv_msg, ":", ";"); AbortOnRTE
				SVAR init_time=:dfr:system_init_time; AbortOnRTE
				if(strlen(s)>0)
					init_time=s; AbortOnRTE
				endif
				
				s=StringByKey("DATA_TIMESTAMP", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f", d; AbortOnRTE
				endif
				NVAR data_timestamp=:dfr:data_timestamp; AbortOnRTE
				data_timestamp=d; AbortOnRTE
				
				
				s=StringByKey("SYSTEM_STATUS_TIMESTAMP", recv_msg, ":", ";"); AbortOnRTE
				if(strlen(s)>0)
					sscanf s, "%f", d; AbortOnRTE
				endif
				NVAR status_timestamp=:dfr:status_timestamp; AbortOnRTE
				status_timestamp=d; AbortOnRTE
			
				WaveClear in_chn; AbortOnRTE
				WaveClear out_chn; AbortOnRTE				
				ThreadGroupPutDF 0, :dfr; AbortOnRTE

			endif
			
			//initiate the next read cycle
			String cmdStr=param[slot]; AbortOnRTE
			String idstr=""; AbortOnRTE
			sprintf idstr, "%x", ticks; AbortOnRTE
			Variable req_update=QDL_REQUEST_READ | QDL_REQUEST_WRITE; AbortOnRTE
			
			if(strlen(cmdStr)>0)
				if(cmpstr("__STOP__", cmdStr)==0)
					cmdStr=""
					req_update=0
					LAST_USER_CMD_STATUS =0
					RESPONSE_COUNT_SINCE =0
				else
					cmdStr=ReplaceStringByKey("REQUEST_ID", cmdStr, idstr, ":", ";"); AbortOnRTE
					cmdStr=ReplaceStringByKey("GET_DATA", cmdStr, "", ":", ";"); AbortOnRTE
					cmdStr=ReplaceStringByKey("GET_SYSTEM_STATUS", cmdStr, "", ":", ";"); AbortOnRTE
					//print "new user command sent: ", cmdStr
					LAST_USER_CMD_STATUS = EMC_USRCMD_STATUS_NEW
				endif
			else
				cmdStr="REQUEST_ID:"+idstr+";GET_DATA;GET_SYSTEM_STATUS;"; AbortOnRTE
				LAST_USER_CMD_STATUS = LAST_USER_CMD_STATUS | EMC_USRCMD_STATUS_OLD
			endif
			
			outbox[slot]=cmdStr; AbortOnRTE
			cmdStr=""; AbortOnRTE
			param[slot]=cmdStr; AbortOnRTE
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
Constant EMCONTROLLER_MAX_RECORD_LEN=3000
Function EMController_postprocess_bgfunc(Variable instance_in, Variable slot_in, Variable dfr_received, DFREF dfr, String instanceDir)
	DFREF olddfr=GetDataFolderDFR(); AbortOnRTE
	try
		//print "EMController background function called."
		String PkgPath=WBSetupPackageDir(QDLPackageName); AbortOnRTE
		WAVE /T outbox=$WBPkgGetName(PkgPath, WBPkgDFWave, "outbox_all"); AbortOnRTE
		WAVE /T inbox=$WBPkgGetName(PkgPath, WBPkgDFWave, "inbox_all"); AbortOnRTE
		WAVE /T param=$WBPkgGetName(PkgPath, WBPkgDFWave, "auxparam_all"); AbortOnRTE
		WAVE request=$WBPkgGetName(PkgPath, WBPkgDFWave, "request_record"); AbortOnRTE
		
		String tmpstr=""
		if(dfr_received==0)
			//no dfr received
			NVAR active=root:V_EMControllerActiveFlag
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
						sprintf tmpstr, "REQUEST_ID:%x;GET_DATA;GET_SYSTEM_STATUS;", ticks
						outbox[slot_in] = tmpstr
						request[slot_in] = QDL_REQUEST_READ | QDL_REQUEST_WRITE
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
				Variable /G root:V_EMControllerActiveFlag=1
				print "root:V_EMControllerActiveFlag created. Setting this to 0 stops probing, set to 1 starts probing, set to -1 force stopping."
			endif
			
			SVAR extra_cmd=root:S_EMControllerCMD			
			if(SVAR_Exists(extra_cmd))
				if(strlen(extra_cmd)>0 && request[slot_in]!=0)
					tmpstr=extra_cmd
					param[slot_in]=tmpstr
					extra_cmd=""
				endif
			else
				String /G root:S_EMControllerCMD=""
				print "root:S_EMControllerCMD created. send user commands to this string."
			endif
		elseif(DataFolderRefStatus(dfr)==3) //Do not delete data folder as it will be handled at higher level
			String privateDF=WBPkgGetName(instanceDir, WBPkgDFDF, "EMController"); AbortOnRTE
			DFREF privateDFR=$privateDF
			if(DataFolderRefStatus(privateDFR)!=1)
				print "prepare privateDF for EMController:", privateDF
				WBPrepPackagePrivateDF(instanceDir, "EMController", nosubdir=1); AbortOnRTE
				privateDF=WBPkgGetName(instanceDir, WBPkgDFDF, "EMController"); AbortOnRTE
				
				SetDataFolder $privateDF; AbortOnRTE
				
				Variable /G instance; AbortOnRTE
				Variable /G slot; AbortOnRTE
				String /G sent_cmd; AbortOnRTE
				String /G received_message=""; AbortOnRTE
				Variable /G request_status; AbortOnRTE
				Variable /G request_id_out; AbortOnRTE
				Variable /G request_id_in; AbortOnRTE
				Make /D/N=4 input_chn=NaN; AbortOnRTE
				Make /D/N=4 output_chn=NaN; AbortOnRTE
				Variable /G pid_gain_P; AbortOnRTE
				Variable /G pid_gain_I; AbortOnRTE
				Variable /G pid_gain_D; AbortOnRTE
				Variable /G pid_gain_filter; AbortOnRTE
				Variable /G pid_scale_factor; AbortOnRTE
				Variable /G pid_offset_factor; AbortOnRTE
				Variable /G pid_setpoint; AbortOnRTE
				Variable /G pid_input_chn=NaN; AbortOnRTE
				Variable /G pid_output_chn=NaN; AbortOnRTE
				Variable /G cpu_load_total; AbortOnRTE
				String /G fpga_state=""; AbortOnRTE
				Variable /G fpga_cycle_time; AbortOnRTE
				String /G system_init_time=""; AbortOnRTE
				Variable /G data_timestamp; AbortOnRTE
				Variable /G status_timestamp; AbortOnRTE
				Variable /G error_log_num; AbortOnRTE
				Variable /G last_usrcmd_status; AbortOnRTE
				Variable /G response_count_since; AbortOnRTE
				
				Variable /G record_counter=0; AbortOnRTE
				Make /D/N=(EMCONTROLLER_MAX_RECORD_LEN, 15) history_record=NaN
				//0-3 : input channel
				//4-7 : output channel
				//8   : time stamp for data
				//9   : pid_setpoint
				//10  : pid_scale_factor
				//11  : pid_offset_factor
				//12  : cpu_load_total
				//13  : request_id_in
				//14  : request_id_out
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
			
			NVAR request_id_out=:request_id_out; AbortOnRTE
			NVAR request_id_out2=dfr:request_id_out; AbortOnRTE
			request_id_out=request_id_out2
			
			NVAR request_id_in=:request_id_in; AbortOnRTE
			NVAR request_id_in2=dfr:request_id_in; AbortOnRTE
			request_id_in=request_id_in2
			
			WAVE input_chn=:input_chn; AbortOnRTE
			WAVE input_chn2=dfr:input_chn; AbortOnRTE
			input_chn=input_chn2
			
			WAVE output_chn=:output_chn; AbortOnRTE
			WAVE output_chn2=dfr:output_chn; AbortOnRTE
			output_chn=output_chn2
			
			NVAR pid_gain_P=:pid_gain_P; AbortOnRTE
			NVAR pid_gain_P2=dfr:pid_gain_P; AbortOnRTE
			pid_gain_P=pid_gain_P2
			
			
			NVAR pid_gain_I=:pid_gain_I; AbortOnRTE
			NVAR pid_gain_I2=dfr:pid_gain_I; AbortOnRTE
			pid_gain_I=pid_gain_I2
			
			NVAR pid_gain_D=:pid_gain_D; AbortOnRTE
			NVAR pid_gain_D2=dfr:pid_gain_D; AbortOnRTE
			pid_gain_D=pid_gain_D2			
			
			NVAR pid_gain_filter=:pid_gain_filter; AbortOnRTE
			NVAR pid_gain_filter2=dfr:pid_gain_filter; AbortOnRTE
			pid_gain_filter=pid_gain_filter2			
			
			NVAR pid_scale_factor=:pid_scale_factor; AbortOnRTE
			NVAR pid_scale_factor2=dfr:pid_scale_factor; AbortOnRTE
			pid_scale_factor=pid_scale_factor2
			
			NVAR pid_offset_factor=:pid_offset_factor; AbortOnRTE
			NVAR pid_offset_factor2=dfr:pid_offset_factor; AbortOnRTE
			pid_offset_factor=pid_offset_factor2
			
			NVAR pid_setpoint=:pid_setpoint; AbortOnRTE
			NVAR pid_setpoint2=dfr:pid_setpoint; AbortOnRTE
			pid_setpoint=pid_setpoint2
			
			NVAR pid_input_chn=:pid_input_chn; AbortOnRTE
			NVAR pid_input_chn2=dfr:pid_input_chn; AbortOnRTE
			pid_input_chn=pid_input_chn2
			
			NVAR pid_output_chn=:pid_output_chn; AbortOnRTE
			NVAR pid_output_chn2=dfr:pid_output_chn; AbortOnRTE
			pid_output_chn=pid_output_chn2
			
			NVAR cpu_load_total=:cpu_load_total; AbortOnRTE
			NVAR cpu_load_total2=dfr:cpu_load_total; AbortOnRTE
			cpu_load_total=cpu_load_total2
			
			SVAR fpga_state=:fpga_state; AbortOnRTE
			SVAR fpga_state2=dfr:fpga_state; AbortOnRTE
			fpga_state=fpga_state2			
			
			NVAR fpga_cycle_time=:fpga_cycle_time; AbortOnRTE
			NVAR fpga_cycle_time2=dfr:fpga_cycle_time; AbortOnRTE
			fpga_cycle_time=fpga_cycle_time2
			
			SVAR system_init_time=:system_init_time; AbortOnRTE
			SVAR system_init_time2=dfr:system_init_time; AbortOnRTE
			system_init_time=system_init_time2
			
			NVAR data_timestamp=:data_timestamp; AbortOnRTE
			NVAR data_timestamp2=dfr:data_timestamp; AbortOnRTE
			data_timestamp=data_timestamp2; AbortOnRTE			
			
			NVAR status_timestamp=:status_timestamp; AbortOnRTE
			NVAR status_timestamp2=dfr:status_timestamp; AbortOnRTE
			status_timestamp=status_timestamp2
			
			NVAR error_log_num=:error_log_num; AbortOnRTE
			NVAR error_log_num2=dfr:error_log_num; AbortOnRTE
			error_log_num=error_log_num2
			
			WAVE history_record=:history_record; AbortOnRTE
			NVAR counter=:record_counter; AbortOnRTE
			history_record[counter][0,3]=input_chn[q]; AbortOnRTE
			history_record[counter][4,7]=output_chn[q-4]; AbortOnRTE
			history_record[counter][8]=data_timestamp; AbortOnRTE
			history_record[counter][9]=pid_setpoint; AbortOnRTE
			history_record[counter][10]=pid_scale_factor; AbortOnRTE
			history_record[counter][11]=pid_offset_factor; AbortOnRTE
			history_record[counter][12]=cpu_load_total; AbortOnRTE
			history_record[counter][13]=request_id_in; AbortOnRTE
			history_record[counter][14]=request_id_out; AbortOnRTE
			
			counter+=1
			if(counter>=EMCONTROLLER_MAX_RECORD_LEN)
				counter=0
			endif

			NVAR usrcmdsta=:last_usrcmd_status; AbortOnRTE
			NVAR usrcmdsta2=dfr:last_usrcmd_status; AbortOnRTE
			if(usrcmdsta==0) //the local status stored has been just reset
				if(!(usrcmdsta2 & EMC_USRCMD_STATUS_OLD)) //the first response from controller after a new cmd was sent
					usrcmdsta=usrcmdsta2; AbortOnRTE
					print "EMController user cmd status first updated to :", usrcmdsta
				endif //any other update with the OLD status bit means it is not related to the latest user cmd (since reset)
			elseif(!(usrcmdsta & EMC_USRCMD_STATUS_OLD)) //local status has been updated since reset, but no OLD bit set yet
				if(!(usrcmdsta2 & EMC_USRCMD_STATUS_OLD))//the update is not yet "OLD"
					usrcmdsta=usrcmdsta2
					print "EMController user cmd status updated to :", usrcmdsta
				else //update is now "OLD", meaning there is no relevance to the user command.
					usrcmdsta=usrcmdsta|EMC_USRCMD_STATUS_OLD
					print "EMController OLD STATUS bit now set for user cmd status."
				endif
			endif
						
			NVAR respcount=:response_count_since; AbortOnRTE
			NVAR respcount2=dfr:response_count_since; AbortOnRTE
			respcount=respcount2; AbortOnRTE

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


