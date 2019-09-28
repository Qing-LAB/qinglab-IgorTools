#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma ModuleName=MeasurementExecutor
#include "EMController"
#include "Keithley2600"

Constant MeasuremenExecutorBgTaskPeriod = 6 //in ticks

Menu "QDataLink"
	Submenu "MeasurementExecutor"
		"Create instructions", /Q, print "Not implemented yet."
		"Start Execution", /Q, MEStartTask()
		"Stop Execution", /Q, MEStopTask()
	End
End

Function MEStartTask()
	WAVE /T w=root:W_INSTRUCTIONS
	if(WaveExists(w))
		w[0]="1"
	endif
	CtrlNamedBackground MEBackgroudTask, burst=0, dialogsOK=1,period=MeasuremenExecutorBgTaskPeriod,proc=MEBgTaskExecInstructions,start
End

Function MEStopTask()
	WAVE /T w=root:W_INSTRUCTIONS
	if(WaveExists(w))
		Variable c=str2num(w[0])
		if(c>0)
			w[0]=num2istr(-c)
		else
			w[0]="-1"
		endif
	endif
	CtrlNamedBackground MEBackgroundTask, stop=1
End

Function MEBgTaskExecInstructions(s)
	STRUCT WMBackgroundStruct & s
	
	WAVE /T instructions=root:W_INSTRUCTIONS
	WAVE /T results=root:W_RESULTS
	WAVE records=root:W_RECORDS
	NVAR record_counter=root:V_RECORD_COUNTER
	Variable rcounter=record_counter
	
	if(WaveExists(instructions)!=1 || DimSize(instructions, 0)<2)
		QDLLog("root:W_INSTRUCTION does not seem to be valid.")
		return -1
	endif
	Variable counter=str2num(instructions[0]) //this one stores the next instruction for execution
	
	if(numtype(counter)!=0 || counter==0)
		counter=1
	endif
	
	if(counter<0)
		QDLLog("Counter of the instructions has been reset. Execution of W_INSTRUCTIONS has stopped.")
		return -1
	endif
	
	if(counter>=DimSize(instructions, 0) || strlen(instructions[counter])==0)
		QDLLog("All instructions have been executed.")
		return 1
	endif
	
	String cmd=instructions[counter]
	
	String cmd_type=StringByKey("TYPE", cmd)
	Variable done_flag=0
	
	strswitch(cmd_type)
	case "EMCONTROLLER":
		//execute cmd or continue the execution from last time
		MEExecuteEMControllerCmd(cmd, results, counter, records, rcounter)
		record_counter=rcounter				
		done_flag=str2num(StringByKey("DONE_STATUS", cmd))
		break
	case "KEITHLEY":
		MEExecuteKeithleyCmd(cmd, results, counter, records, rcounter)
		record_counter=rcounter				
		done_flag=str2num(StringByKey("DONE_STATUS", cmd))
		break
	case "EXTFUNC":
		MEExecuteExtFunc(cmd, results, counter, records, rcounter)
		record_counter=rcounter
		done_flag=str2num(StringByKey("DONE_STATUS", cmd))
		break
	default:
		break
	endswitch
	
	instructions[counter]=cmd

	if(done_flag==2)
		counter+=1
	endif
	instructions[0]=num2istr(counter)
	
	//print "task returning zero"
	return 0
End

Function MEExtFuncPrototype(Variable & extfunc_call_count, WAVE /T results, Variable counter, WAVE records, Variable & rcounter, String cmd)
	extfunc_call_count+=1
	return 0
End

Constant ME_STANDARD_EMERROR=1e-3 //1 mV for 1 Gauss
Constant ME_STANDARD_TIMEOUT=1200 //20 sec

Function MEExtFunc_StandardScan(Variable call_count, WAVE /T results, Variable counter, WAVE records, Variable & rcounter, String & cmd)
	String srcWaveName=StringByKey("SRCWAVENAME", cmd, "=", ";")
	WAVE srcw=$srcWaveName
	if(WaveExists(srcw) && DimSize(srcw, 1)>=3)
		Variable wcount=str2num(StringByKey("SRCWAVECOUNT", cmd))
		if(numtype(wcount)!=0)
			wcount=0
		endif
		variable cyclecount=str2num(StringByKey("SRCWAVECYCLECOUNT", cmd))
		if(numtype(cyclecount)!=0)
			cyclecount=0
		endif
		Variable totalcycle=str2num(StringByKey("SRCWAVETOTALCYCLE", cmd))
		if(numtype(totalcycle)!=0)
			totalcycle=1
		endif
		
		Variable EMSetpoint=srcw[wcount][0]
		Variable KSMUASrc=srcw[wcount][1]
		Variable KSMUBSrc=srcw[wcount][2]
		
		String point_info=""
		point_info=results[rcounter]
		Variable status=str2num(StringByKey("DONE_STATUS", point_info))
		if(numtype(status)!=0)
			status=0
		endif

		switch(status)
		case 0: //first call
			point_info=ReplaceStringByKey("EMCONTROLLER_STATUS", point_info, "0")
			point_info=ReplaceStringByKey("KEITHLEY_STATUS", point_info, "0")
			point_info=ReplaceStringByKey("EMSETPOINT", point_info, num2str(EMSetpoint))
			point_info=ReplaceStringByKey("SMUA_SRC", point_info, num2str(KSMUASrc))
			point_info=ReplaceStringByKey("SMUB_SRC", point_info, num2str(KSMUBSrc))
			variable done_flag=0
			EMScanInit(1, 1, done_flag)
			KeithleyInit()
			break
		case 1: //setting done
			break
		case 2: //points taken
			break
		case 3: //done for the point
			break
		default:
			break
		endswitch
		point_info=ReplaceStringByKey("DONE_STATUS", point_info, num2istr(status))
		results[rcounter]=point_info
	else
		QDLLog("Wave "+srcWaveName+" not valid for automatic sourcing.")
	endif
End

Function MEExecuteExtFunc(String & cmd, WAVE /T results, Variable counter, WAVE records, Variable & record_counter)
	try
		Variable extfunc_call_count=str2num(StringByKey("EXTFUNC_CALL_COUNT", cmd))
		if(numtype(extfunc_call_count)!=0 || extfunc_call_count<=0)
			extfunc_call_count=0
		endif
		Variable extfunc_start_time=str2num(StringByKey("EXTFUNC_START_TIME", cmd))
		if(numtype(extfunc_start_time)!=0)
			extfunc_start_time=ticks
			cmd=ReplaceStringByKey("EXTFUNC_START_TIME", cmd, num2istr(extfunc_start_time))
		endif
		String funcname=StringByKey("EXTFUNC_NAME", cmd)
		FUNCREF MEExtFuncPrototype rfunc=$funcname
		Variable isproto=Str2num(StringByKey("ISPROTO", FuncRefInfo(rfunc)))
		if(isproto==0)
			if(MEExtFuncPrototype(extfunc_call_count, results, counter, records, record_counter, cmd)==0)
				cmd=ReplaceStringByKey("DONE_STATUS", cmd, "2")
			else
				cmd=ReplaceStringByKey("DONE_STATUS", cmd, "1")
			endif
		else
			QDLLOG("User function "+funcname+" is not valid. No ext function called.")
			cmd=ReplaceStringByKey("DONE_STATUS", cmd, "2")
		endif
		cmd=ReplaceStringByKey("EXTFUNC_CALL_COUNT", cmd, num2istr(extfunc_call_count))
	catch
		Variable err=GetRTError(1)
		print "ExecuteExtFunc caught an error: "+GetErrMessage(err)
		print "cmd: "+cmd
		print "counter: ", counter, "record_counter: ", record_counter
	endtry
End

Function MEExecuteKeithleyCmd(String & cmd, WAVE /T results, Variable counter, WAVE records, Variable & record_counter)
	try
		Variable reset_status=str2num(StringByKey("RESET_STATUS", cmd))
		if(reset_status!=1)
			KeithleyResetCmdStatusFlag()
			cmd=ReplaceStringByKey("RESET_STATUS", cmd, "1")
			reset_status=1
			//QDLLOG("Keithley new cmd status reset.")
		endif
		
		Variable done_flag=str2num(StringByKey("DONE_STATUS", cmd))
		if(numtype(done_flag)!=0)
			done_flag=0
		endif
		if(done_flag!=2)
			String exec=StringByKey("EXEC", cmd)
			Variable smua_src=str2num(StringByKey("SMUA_SRC", cmd))
			Variable smub_src=str2num(StringByKey("SMUB_SRC", cmd))
			
			SVAR kconfig=root:S_KeithleySMUConfig
			Variable smua_srctype=str2num(StringByKey("SOURCE_TYPE", StringByKey("SMUA", kconfig, "@", "#")))
			Variable smub_srctype=str2num(StringByKey("SOURCE_TYPE", StringByKey("SMUB", kconfig, "@", "#")))
			Variable initial_take=str2num(StringByKey("INITIAL_TAKE", cmd))
			
			if(numtype(initial_take)!=0)
				initial_take=0
			endif
			
			Make /FREE/D/N=6 ktmp
			
			strswitch(exec)
			case "INIT":
				if(done_flag==0)
					KeithleyInit()
					done_flag=1
					QDLLOG("KeithleyInit() called.")
				endif
				break
			case "RESET":
				if(done_flag==0)
					KeithleyReset()
					done_flag=1
					QDLLOG("KeithleyReset() called.")
				endif
				break
			case "SOURCE&MEASURE":
				done_flag=3 //KeithleySMUMeasure function will check status by itself
				if(KeithleySMUMeasure(cmd, smua_srctype, smua_src, smub_srctype, smub_src, initial_take, record_counter, ktmp)==0)
					Variable pid_input, pid_output, pid_setpoint
					EMControllerReadPIDChannels(pid_input, pid_output, pid_setpoint)
					records[record_counter][0]=counter; AbortOnRTE //which command resulted in this measurement
					records[record_counter][1]=DateTime; AbortOnRTE //date and time in seconds
					records[record_counter][2]=StopMSTimer(-2); AbortOnRTE //time from machine restart
					records[record_counter][3]=pid_setpoint; AbortOnRTE //setpoint of PID control
					records[record_counter][4]=pid_output; AbortOnRTE //output value of PID control
					records[record_counter][5]=pid_input; AbortOnRTE //actual reading of PID input
					records[record_counter][6,11]=ktmp[q-6]; AbortOnRTE //all keithley readings
					record_counter+=1; AbortOnRTE
					done_flag=2; AbortOnRTE
					String logstr=""
					sprintf logstr, "[%d] record: PID_input [%6f], SMUA_I[%6g], SMUA_V[%6g], SMUB_I[%6g], SMUB_V[%6g]", counter, pid_input, ktmp[0], ktmp[1], ktmp[3], ktmp[4]
					QDLLog(logstr)
				endif
				break
			default:
				done_flag=2
				break
			endswitch
		endif
		
		if(done_flag==1)
			if(KeithleyCheckCMDStatusFlag()==1)
				done_flag=2
			endif
		endif
		if(done_flag==2)
			QDLLOG("["+num2istr(counter)+"] KEITHLEY has taken action. Continue to next instruction...", g=32768)
		endif
		
		cmd=ReplaceStringByKey("DONE_STATUS", cmd, num2istr(done_flag))
	catch
		Variable err=GetRTError(1)
		print "ExecuteKeithleyCmd caught an error: "+GetErrMessage(err)
		print "cmd: "+cmd
		print "counter: ", counter, "record_counter: ", record_counter
	endtry
End

Function MEExecuteEMControllerCmd(String & cmd, WAVE /T results, Variable counter, WAVE records, Variable & record_counter)
	try
		Variable reset_status=str2num(StringByKey("RESET_STATUS", cmd))
		if(reset_status!=1)
			EMResetCMDStatusFlag()
			cmd=ReplaceStringByKey("RESET_STATUS", cmd, "1")
			reset_status=1
			//QDLLOG("EMController new cmd status reset.")
		endif
		
		Variable done_flag=str2num(StringByKey("DONE_STATUS", cmd))
		if(numtype(done_flag)!=0)
			done_flag=0
		endif
		if(done_flag!=2)
			String exec=StringByKey("EXEC", cmd)
			String param=StringByKey("PARAM", cmd)
			
			strswitch(exec)
			case "INIT":
				Variable input_chn, output_chn
				sscanf param, "%d,%d", input_chn, output_chn
				EMScanInit(input_chn, output_chn, done_flag)
				QDLLOG("EMScanInit() called. PID INPUT CHN:"+num2istr(input_chn)+". PID OUTPUT CHN:"+num2istr(output_chn))
				break
			case "SHUTDOWN":
				EMShutdown(done_flag)
				QDLLOG( "EMShutdown() called.")
				break
			case "SETPOINT":
				Variable new_setpoint=nan
				Variable error_range=nan
				Variable timeout_ticks=nan
				sscanf param, "%f,%f,%d", new_setpoint, error_range,timeout_ticks
				if(numtype(new_setpoint)==0 && numtype(error_range)==0 && numtype(timeout_ticks)==0)
					if(new_setpoint==0)
						Variable strict_zero=str2num(StringByKey("STRICT_ZERO", cmd))
						if(strict_zero!=1)
							strict_zero=0
						endif
					endif
					if(EMSetpoint(cmd, new_setpoint, error_range, timeout_ticks, strict_zero)==0)
						done_flag=2
					endif
				else
					QDLLOG("ERROR in PARAM of SETPOINT. New setpoint:"+num2str(new_setpoint)+", error range:"+num2str(error_range)+", timeout (ticks):"+num2str(timeout_ticks), r=65535)
					done_flag=2
				endif
				break
			case "PID_GAIN":
				Variable p, i, d, f, s, o
				sscanf param, "%f,%f,%f,%f,%f,%f", p,i,d,f,s,o
				if(p>=0 && p<100 && i>=0 && i<100 && d>=0 && d<100 && f>=0 && f<=1 && s>=-100 && s<=100 && o>=-100 && o<=100)
					if(EMSetPIDGains(cmd, p,i,d,f,s,o)==0)
						done_flag=2
					endif
				else
					String logstr=""
					sprintf logstr, "ERROR in PARAM of PID_GAINS. P:%f, I:%f, D:%f, FILTER:%f, ScaleFactor:%f, OffsetFactor:%f", p,i,d,f,s,o
					QDLLOG(logstr, r=65535)
					done_flag=2
				endif
				break
			default:
				QDLLOG("UNKNOWN EXEC CMD FOR EMCONTROLLER:"+exec)
				done_flag=2
				break
			endswitch
		endif
		
		if(done_flag==1)
			if(EMCheckCMDStatusFlag()==1)
				done_flag=2
			endif
		endif
		if(done_flag==2)
			QDLLOG("["+num2istr(counter)+"] EMCONTROLLER has taken action. Continuing to next instruction...", g=32768)
		endif
		
		cmd=ReplaceStringByKey("DONE_STATUS", cmd, num2istr(done_flag))
	catch
		Variable err=GetRTError(1)
		print "ExecuteEMControllerCmd caught an error: "+GetErrMessage(err)
		print "cmd: "+cmd
		print "counter: ", counter, "record_counter: ", record_counter
	endtry
End
