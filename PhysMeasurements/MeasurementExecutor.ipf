#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "EMController"
#include "keithley2600"

Function bgfunc_ExecInstructions(s)
	STRUCT WMBackgroundStruct & s
	
	WAVE /T instructions=root:W_INSTRUCTIONS
	WAVE /T results=root:W_RESULTS
	WAVE records=root:W_RECORDS
	NVAR record_counter=root:V_RECORD_COUNTER
	Variable rcounter=record_counter
	
	if(WaveExists(instructions)!=1 || DimSize(instructions, 0)<2)
		print "root:W_INSTRUCTION does not seem to be valid."
		return -1
	endif
	Variable counter=str2num(instructions[0]) //this one stores the next instruction for execution
	if(numtype(counter)!=0 || counter<1)
		counter=1
	endif
	
	if(counter>=DimSize(instructions, 0) || strlen(instructions[counter])==0)
		print "all instructions have been executed."
		return 1
	endif
	
	String cmd=instructions[counter]
	
	String cmd_type=StringByKey("TYPE", cmd)
	Variable done_flag=0
	
	strswitch(cmd_type)
	case "EMCONTROLLER":
		//execute cmd or continue the execution from last time
		ExecuteEMControllerCmd(cmd, results, counter, records, rcounter)
		record_counter=rcounter				
		done_flag=str2num(StringByKey("DONE_STATUS", cmd))
		break
	case "KEITHLEY":
		ExecuteKeithleyCmd(cmd, results, counter, records, rcounter)
		record_counter=rcounter				
		done_flag=str2num(StringByKey("DONE_STATUS", cmd))
		break
	default:
		break
	endswitch
	
	instructions[counter]=cmd

	if(done_flag>1)
		counter+=1
	endif
	instructions[0]=num2istr(counter)
	
	//print "task returning zero"
	return 0
End

Function ExecuteKeithleyCmd(String & cmd, WAVE /T results, Variable counter, WAVE records, Variable & record_counter)
	Variable reset_status=str2num(StringByKey("RESET_STATUS", cmd))
	if(reset_status!=1)
		KeithleyResetCmdStatusFlag()
		cmd=ReplaceStringByKey("RESET_STATUS", cmd, "1")
		reset_status=1
		print "Keithley new cmd status reset."
	endif
	
	Variable done_flag=str2num(StringByKey("DONE_STATUS", cmd))
	if(numtype(done_flag)!=0 || done_flag==0)
		String exec=StringByKey("EXEC", cmd)
		String param=StringByKey("PARAM", cmd)
		
		strswitch(exec)
		case "KEITHLEYINIT":
			KeithleyInit()
			done_flag=1
			print "KeithleyInit() called."
			break
		case "KEITHLEYRESET":
			KeithleyReset()
			done_flag=1
			print "KeithleyReset() called."
			break
		default:
			done_flag=2
			break
		endswitch
	endif
	
	if(done_flag==1)
		if(KeithleyCheckCMDStatusFlag()==1)
			done_flag=2
			print "EXEC STATUS INDICATES EMCONTROLLER HAS TAKE ACTION. WILL CONTINUE TO NEXT INSTRUCTION."
		endif
	endif
	cmd=ReplaceStringByKey("DONE_STATUS", cmd, num2istr(done_flag))	
End

Function ExecuteEMControllerCmd(String & cmd, WAVE /T results, Variable counter, WAVE records, Variable & record_counter)
	
	Variable reset_status=str2num(StringByKey("RESET_STATUS", cmd))
	if(reset_status!=1)
		EMResetCMDStatusFlag()
		cmd=ReplaceStringByKey("RESET_STATUS", cmd, "1")
		reset_status=1
		print "EMController new cmd status reset."
	endif
	
	Variable done_flag=str2num(StringByKey("DONE_STATUS", cmd))
	if(numtype(done_flag)!=0 || done_flag==0)
		String exec=StringByKey("EXEC", cmd)
		String param=StringByKey("PARAM", cmd)
		
		strswitch(exec)
		case "EMINIT":
			Variable input_chn, output_chn
			sscanf param, "%d,%d", input_chn, output_chn
			EMScanInit(input_chn, output_chn)
			done_flag=1
			print "EMScanInit() called.", input_chn, output_chn
			break
		case "EMSHUTDOWN":
			EMShutdown()
			done_flag=1
			print "EMShutdown() called."
			break
		case "EMSETPOINT":
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
				print "ERROR in PARAM of EMSETPOINT.", new_setpoint, error_range, timeout_ticks
				done_flag=2
			endif
			break
		default:
			print "UNKNOWN EXEC CMD FOR EMCONTROLLER:", exec
			done_flag=2
			break
		endswitch
	endif
	
	if(done_flag==1)
		if(EMCheckCMDStatusFlag()==1)
			done_flag=2
			print "EXEC STATUS INDICATES EMCONTROLLER HAS TAKE ACTION. WILL CONTINUE TO NEXT INSTRUCTION."
		endif
	endif
	cmd=ReplaceStringByKey("DONE_STATUS", cmd, num2istr(done_flag))
End
