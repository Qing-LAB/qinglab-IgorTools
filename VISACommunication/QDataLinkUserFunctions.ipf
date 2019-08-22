#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma IndependentModule= QDataLinkCore


//Please use the following as a template to define user functions
//
//ThreadSafe Function qdl_rtfunc_prototype(Variable inittest, [Variable slot, STRUCT QDLConnectionParam & cp, WAVE request, WAVE status, WAVE /T inbox, WAVE /T outbox, WAVE /T param, WAVE /T auxret])
//	if(inittest==1)
//		return 0
//	endif
//	return 0
//End
//
//Function qdl_postfix_callback_prototype(Variable instance, Variable slot, Variable dfr_received, DFREF dfr, String instanceDir)
//	return 0
//End

ThreadSafe Function EMcontroller_rtfunc(Variable inittest, [Variable slot, STRUCT QDLConnectionParam & cp, WAVE request, WAVE status, WAVE /T inbox, WAVE /T outbox, WAVE /T param, WAVE /T auxret])
	Variable dfr_flag=0
	
	if(inittest==0) //initial call just to verify that the function exists
		return 0
	endif
	
	//all optional parameters will be properly defined, by design, from the caller in the worker thread
	try
		if(request[slot] | QDL_REQUEST_WRITE_COMPLETE)
			//writing task is done
			
		endif
		if(request[slot] | QDL_REQUEST_READ_COMPLETE)
			//reading task is done
		endif
		if(dfr_flag==1)
			//need to send message back to background post-process function
			NewDataFolder :dfr; AbortOnRTE
			Variable /G :dfr:instance; AbortOnRTE
			Variable /G :dfr:slot; AbortOnRTE
			String /G :dfr:received_message=""; AbortOnRTE
			Variable /G :dfr:request_status; AbortOnRTE
			Variable /G :dfr:request_id; AbortOnRTE
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
			
			NVAR inst=:dfr:instance; AbortOnRTE
			inst=cp.instance; AbortOnRTE
			NVAR slt=:dfr:slot; AbortOnRTE
			slt=slot; AbortOnRTE
			SVAR recv_msg=:dfr:received_message; AbortOnRTE
			recv_msg=inbox[slot]; AbortOnRTE
			NVAR req_stat=:dfr:request_status; AbortOnRTE
			req_stat=request[slot]; AbortOnRTE
			
			String s=""; AbortOnRTE
			Variable d=NaN; AbortOnRTE
			s=StringByKey("REQUEST_ID", recv_msg, ":", ";"); AbortOnRTE
			if(strlen(s)>0)
				sscanf s, "%x", d; AbortOnRTE
			endif
			NVAR req_id=:dfr:request_id; AbortOnRTE
			req_id=d; AbortOnRTE
			
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
			NVAR pid_input=:dfr:pid_input_chn; AbortOnRTE
			pid_input=d; AbortOnRTE
			
			s=StringByKey("PID_OUTPUT_CHN", recv_msg, ":", ";"); AbortOnRTE
			if(strlen(s)>0)
				sscanf s, "%d", d; AbortOnRTE
			endif
			NVAR pid_output=:dfr:pid_output_chn; AbortOnRTE
			pid_output=d; AbortOnRTE
			
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
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "qdl_general_rtfunc encountered an error for slot "+num2istr(slot)+": "+GetErrMessage(err)
		endif
	endtry
End

