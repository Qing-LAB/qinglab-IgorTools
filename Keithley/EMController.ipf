#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "QDataLink"
#include "keithley2600"

Function EMController_process_data(String cmd, String msg, Variable slot)
	WAVE d=root:EMdata
	WAVE t=root:EMtime
	WAVE reqid=root:EMrequestID
	WAVE /T response=root:EMresponse
	NVAR c1=root:EMDataCount
	String tmpstr=""
	try
		if(c1>=1000)
			c1=0
		endif
		
		Variable reqid1=nan
		Variable reqid2=nan
		
		response[c1]=msg
		if(strlen(cmd)>0 && strlen(msg)>0)				
			sscanf StringByKey("REQUEST_ID", cmd), "%x", reqid1; AbortOnRTE
			sscanf StringByKey("REQUEST_ID", msg), "%x", reqid2; AbortOnRTE
		endif
		if(reqid1!=reqid2)
			//print "EMController_process_data get inconsistent id. ID in command: "+num2istr(reqid1)+", ID in response:"+num2istr(reqid2); AbortOnRTE
			//EMLog("Clearing device: "+"REQUEST_ID=123;GET_DATA;GET_SYSTEM_STATUS;")
			EMLog("WARNING: REQUEST_ID is different from expectation.", r=65535)
			//QDLQuery(slot, "", 0, clear_device=1)
			//Sleep /S 1
			//tmpstr=QDLQuery(slot, "REQUEST_ID=123;GET_DATA;GET_SYSTEM_STATUS;", 1)
			//
			//EMLog("Response:"+tmpstr)
		endif
	
		variable n=str2num(StringFromList(0, StringByKey("INPUT_CHN_DATA", msg, ":", ";"), ","))
		if(numtype(n)==0)
			d[c1][]=str2num(StringFromList(q, StringByKey("INPUT_CHN_DATA", msg, ":", ";"), ","))
			t[c1]=str2num(StringByKey("DATA_TIMESTAMP", msg, ":", ";"))
			if(numtype(reqid2)==0)
				reqid[c1]=reqid2
			else
				reqid[c1]=0
			endif
			c1+=1
		endif
	catch
		Variable err=GetRTError(1)
		print "EMController_process_data get error:"+GetErrMessage(err)
	endtry
	
End

Function EMScanInit(Variable slot)

	Make /O/N=(1000,4) root:EMdata
	Make /O/N=1000 root:EMtime
	Make /O/N=1000 root:EMrequestID
	Make /O/N=1000/T root:EMresponse
	NVAR c1=root:EMDataCount
	if(!NVAR_Exists(c1))
		Variable /G root:EMDataCount
		NVAR c1=root:EMDataCount
	endif
	
	WAVE EMdata=root:EMdata
	WAVE EMtime=root:EMtime
	WAVE EMrequestID=root:EMrequestID
	WAVE /T EMresponse=root:EMresponse
	
	c1=0
	EMdata=nan
	EMtime=nan
	EMrequestID=nan
	EMresponse=""
	
	String time_ID=""
	sprintf time_ID, "REQUEST_ID:%x;", ticks
	String cmd=time_ID
	String resp=""
	
	cmd+="SET_FPGA_STATE:1;"
	cmd+="SET_OUTPUT:0,0,0,0;"
	cmd+="SET_PID_SETPOINT:0;"
	cmd+="SET_PID_RANGE:10,0;"
	cmd+="SET_PID_GAIN:0.35,0.25,0.03,1,1,0;"
	cmd+="SET_9219_CONVERSION_TIME:0;"//fast mode
	cmd+="SET_9219_VOLTAGE_RANGE:0,1,4,4;" //60V for chn0, 15V for chn1, 0.125V for chn3 and chn4
	cmd+="RESET_PID;"
	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
	
	EMLog("EMInit send cmd to controller: "+cmd)
	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
	EMController_process_data(cmd, resp, slot)
	
	sprintf time_ID, "REQUEST_ID:%x;", ticks
	cmd=time_ID
	cmd+="SET_PID_INPUT_CHN:1;SET_PID_OUTPUT_CHN:1;SET_OUTPUT:10,0,0,0;"
	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
	EMLog("EMInit send cmd to controller: "+cmd)
	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
	EMController_process_data(cmd, resp, slot)
	
	sprintf time_ID, "REQUEST_ID:%x;", ticks
	cmd=time_ID
	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
	EMLog("EMInit send cmd to controller: "+cmd)
	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
	EMController_process_data(cmd, resp, slot)
	EMLog("Query finished. Last response is:"+resp)
End

Function EMShutdown(Variable slot)
	String time_ID=""
	sprintf time_ID, "REQUEST_ID:%x;", ticks
	String cmd=time_ID
	String resp=""
	
	cmd+="SET_FPGA_STATE:0;"
	cmd+="SET_OUTPUT:0,0,0,0;"
	cmd+="SET_PID_SETPOINT:0;SET_PID_GAIN:0,0,0,0,1,0;"
	cmd+="SET_PID_INPUT_CHN:4;SET_PID_OUTPUT_CHN:4;"
	cmd+="RESET_PID;"	
	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
	EMLog("EMShutdown send cmd to controller: "+cmd)
	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
	EMController_process_data(cmd, resp, slot)
	
	sprintf time_ID, "REQUEST_ID:%x;", ticks
	cmd=time_ID
	resp=""
	cmd+="GET_DATA;GET_SYSTEM_STATUS;"
	EMLog("EMShutdown send cmd to controller: "+cmd)
	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
	EMController_process_data(cmd, resp, slot)
	EMLog("Query finished. Response processed:"+resp)
End

StrConstant PID_POSITIVE_GAIN_SETTING="0.35,0.25,0.03,1,1,0"
StrConstant PID_NEGATIVE_GAIN_SETTING="0.35,0.25,0.03,1,-1,0"

Function EMSetpoint(Variable slot, Variable setpoint, Variable timeout_ticks, Variable allowed_error, Variable polarity, [Variable & timestamp, Variable strict_zero])

	String time_ID=""
	String cmd=""
	String resp=""
	
	String pid_gain_setting=""
	
	if(polarity>0)
		polarity=1
	elseif(polarity<0)
		polarity=-1
	else
		print "polarity cannot be zero."
		return -1
	endif
	
	if(polarity<0)
		pid_gain_setting=PID_NEGATIVE_GAIN_SETTING
	else
		pid_gain_setting=PID_POSITIVE_GAIN_SETTING
	endif
	
	if(setpoint>10)
		setpoint=10
	endif
	
	if(setpoint==0)
		if(ParamIsDefault(strict_zero) || strict_zero==0)
			setpoint=allowed_error*polarity
		endif
	endif
	
	sprintf time_ID, "REQUEST_ID:%x;SET_PID_GAIN:%s;SET_PID_SETPOINT:%.6f;", ticks, pid_gain_setting, setpoint
	cmd=time_ID
	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
	
	//EMLog("EMSetpoint send cmd to controller: "+cmd)
	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
	EMController_process_data(cmd, resp, slot)
	
	WAVE d=root:EMdata
	WAVE t=root:EMtime
	NVAR c1=root:EMDataCount
	Variable oldc
	Variable start_time=ticks
	Variable current_time=start_time
	Variable actual_value=nan
	do
		Sleep /S 2
		sprintf cmd, "REQUEST_ID:%x;GET_DATA;GET_SYSTEM_STATUS;", current_time
		resp=""
		EMLog("EMSetpoint send cmd to controller: "+cmd)
		resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
		EMController_process_data(cmd, resp, slot)
		oldc=c1-1
		if(oldc<0)
			oldc=999
		endif
		actual_value=d[oldc][1]
		if(!ParamIsDefault(timestamp))
			timestamp=t[oldc]
		endif
		current_time=ticks
	while(current_time-start_time<timeout_ticks && abs(actual_value-setpoint)>allowed_error)
	EMLog("EMSetpoint finished trying. Last status update: "+resp)
	
	if(abs(actual_value-setpoint)<=allowed_error)
		sprintf resp, "EMSetpoint finds the field [%.6f] to be within allowed error [%.6f] around setpoint [%.6f]", actual_value, allowed_error, setpoint
		EMLog(resp, g=32768)
	else
		sprintf resp, "EMSetpoint timed out when waiting field [%.6f] to settle down to be within allowed error [%.6f] around setpoint [%.6f]", actual_value, allowed_error, setpoint
		EMLog(resp, r=65535)
	endif
	//print "timestamp is:", timestamp
	return actual_value
End


Constant DEFAULT_KEITHLEY_TIMEOUT=1000 //ms
Constant GaussMeterScaleFactor=1000 // 1 V = 1000 Gauss

Function RunTest(Variable maxB, Variable errB, Variable number_of_pnts, Variable injectCurrent, Variable time_delay, Variable VISASlotEM, Variable VISASlotKeithley, String KeithleyScriptNB)

	Variable Bfield, BActualField, starttimestamp, currenttimestamp
	Variable deltaB
	Variable i
	
	String nbName=KeithleyScriptNB
	maxB=abs(maxB)
	errB=abs(errB)/GaussMeterScaleFactor
	
	deltaB=maxB/(number_of_pnts-1)
	
	try
		String wname=UniqueName("BScan_"+num2istr(maxB)+"Gauss", 1, 0)
		Make /O/D/N=(4*number_of_pnts-2, 8) $wname=nan
		Make /FREE/N=6 keithley_result
		WAVE w=$wname
		Variable count=0
		
		String smuconfig=KeithleyConfigSMUs("SMUA;SMUB", "")
		if(strlen(smuconfig)>0)
			KeithleyGenerateInitScript(smuconfig, nbName)		
		else
			AbortOnValue -1, -1
		endif
		display w[][6] vs w[][0]
		String graph_name=S_name
		edit w
		Execute /Z "TileWindows /C/O=(0x01+0x02+0x08)"
		DoWindow /F $EMLogBookName
		
		NewPanel /K=1 /W=(0,0,400,100) as "Please switch polarity of power supply to positive"
		DoWindow/C tmp_PauseforPositivePolarity
		AutoPositionWindow/E/M=1/R=$graph_name
		DrawText 21,20,"Switch the polarity of power supply to positive"
		DrawText 21,40,"And close this window to continue..."
		
		PauseForUser tmp_PauseforPositivePolarity
		KillWindow /Z tmp_PauseforPositivePolarity
		
		KeithleyInit(VISASlotKeithley, nbName, DEFAULT_KEITHLEY_TIMEOUT)
		EMScanInit(VISASlotEM)
		
		EMSetpoint(VISASlotEM, 0, time_delay*2, errB, 1, timestamp=starttimestamp)	
		KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 1, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, 0)
		
		for(i=0; i<number_of_pnts; i+=1)
			
			Bfield=i*deltaB/GaussMeterScaleFactor
		
			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, 1, timestamp=currenttimestamp)
			
			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
			
			w[count][0]=BActualField*GaussMeterScaleFactor
			
			w[count][1]=currenttimestamp-starttimestamp
			w[count][2]=keithley_result[0] //SMUA current
			w[count][3]=keithley_result[1] //SMUA voltage
			w[count][4]=keithley_result[2] //SMUA timestamp
			w[count][5]=keithley_result[3] //SMUB current
			w[count][6]=keithley_result[4] //SMUB voltage
			w[count][7]=keithley_result[5] //SMUB timestamp
			count+=1
			//PauseForUser /C $graph_name
		endfor
		
		for(i=number_of_pnts-2; i>=0; i-=1)
			Bfield=i*deltaB/GaussMeterScaleFactor

			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, 1, timestamp=currenttimestamp)
			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
			
			w[count][0]=BActualField*GaussMeterScaleFactor
			
			w[count][1]=currenttimestamp-starttimestamp
			w[count][2]=keithley_result[0] //SMUA current
			w[count][3]=keithley_result[1] //SMUA voltage
			w[count][4]=keithley_result[2] //SMUA timestamp
			w[count][5]=keithley_result[3] //SMUB current
			w[count][6]=keithley_result[4] //SMUB voltage
			w[count][7]=keithley_result[5] //SMUB timestamp
			count+=1
			
			//PauseForUser /C $graph_name
		endfor
		
		
		NewPanel /K=1 /W=(0,0,400,100) as "Please switch polarity of power supply to negative"
		DoWindow/C tmp_PauseforNegativePolarity
		AutoPositionWindow/E/M=1/R=$graph_name
		DrawText 21,20,"Switch the polarity of power supply to negative"
		DrawText 21,40,"And close this window to continue..."
		
		PauseForUser tmp_PauseforNegativePolarity
		KillWindow /Z tmp_PauseforNegativePolarity
			
		for(i=0; i<number_of_pnts; i+=1)
			Bfield=-i*deltaB/GaussMeterScaleFactor
			
			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, -1, timestamp=currenttimestamp)
			
			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
			
			w[count][0]=BActualField*GaussMeterScaleFactor
			
			w[count][1]=currenttimestamp-starttimestamp
			w[count][2]=keithley_result[0] //SMUA current
			w[count][3]=keithley_result[1] //SMUA voltage
			w[count][4]=keithley_result[2] //SMUA timestamp
			w[count][5]=keithley_result[3] //SMUB current
			w[count][6]=keithley_result[4] //SMUB voltage
			w[count][7]=keithley_result[5] //SMUB timestamp
			count+=1
			//PauseForUser /C $graph_name
		endfor
		
		for(i=number_of_pnts-2; i>=0; i-=1)
			Bfield=-i*deltaB/GaussMeterScaleFactor
			
			if(Bfield==0)
				Bfield=-abs(errB)
			endif
			
			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, -1, timestamp=currenttimestamp)
			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
			
			w[count][0]=BActualField*GaussMeterScaleFactor
			
			w[count][1]=currenttimestamp-starttimestamp
			w[count][2]=keithley_result[0] //SMUA current
			w[count][3]=keithley_result[1] //SMUA voltage
			w[count][4]=keithley_result[2] //SMUA timestamp
			w[count][5]=keithley_result[3] //SMUB current
			w[count][6]=keithley_result[4] //SMUB voltage
			w[count][7]=keithley_result[5] //SMUB timestamp
			count+=1
			
			//PauseForUser /C $graph_name
		endfor
	
	catch
		Variable err=GetRTError(1)
		print "ERROR During measurement: "+GetErrMessage(err)
	endtry

	KeithleyShutdown(VISASlotKeithley, DEFAULT_KEITHLEY_TIMEOUT)
	EMShutdown(VISASlotEM)
End

