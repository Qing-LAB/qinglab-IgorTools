#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7
#include "wavebrowser"
#include "keithley2336Constants"

Function /T K2336_SMUName(variable smu)
	String smuName=""
	
	switch(smu)
	case 0:
		smuName="smua"
		break
	case 1:
		smuName="smub"
		break
	default:
		smuName=""
	endswitch
	
	return smuName
End

Function K2336_RangeFromList(String range_str, String range_list, Variable & range_value, Variable & range_idx)
	Variable retVal=0
	
	try
		range_idx=WhichListItem(range_str, range_list); AbortOnRTE
		if(range_idx<0)
			Variable val1, val2, i
			sscanf range_str, "%f", val1; AbortOnRTE
			for(i=0; i<ItemsInList(range_list); i+=1)
				sscanf StringFromList(i, range_list), "%f", val2; AbortOnRTE
				if(val2<val1)
					break
				endif
			endfor
			i-=1
			if(i<0)
				print "K2336_RangeFromList Warning: Request out of range. Maximum level is used."
				i=0
			endif
			range_idx=i; AbortOnRTE
		endif
		sscanf StringFromList(range_idx, range_list), "%f", range_value; AbortOnRTE
	catch
		Variable err=GetRTError(1)
		print "K2336_RangeFromList get an error: "+GetErrMessage(err)
		retVal=-1
	endtry
	
	return retVal
End


Function K2336_check_IV_limit(Variable & limitI, Variable & limitV)
	Variable retVal=0
	
	if(limitI>=0.1) //100 mA
		if(limitV>=20.2) //20.2V
			limitI=0.1
			printf "K2336_check_IV_limit: current limit is out of range. force setting to 100mA"
			retVal+=1
		endif
	endif
	
	if(limitV>=20.2)
		if(limitI>=0.1)
			limitV=20.2
			printf "K2336_check_IV_limit: voltage limit is out of range. force setting to 20.2V"
			retVal+=1
		endif
	endif
	
End


Function K2336_GenInitScript(Variable smu, String smu_condition, String & script)
	
	Variable retVal=0
	
	Variable instance=-1
	String dfr=WBSetupPackageDir(K2336PackageName, instance=instance, existence=1)
	
	String smuName=K2336_SMUName(smu)
	if(strlen(smuName)==0)
		return -1
	endif
	
	script=smuName+".reset()\r"

	try
		String svalue
		Variable dvalue, source_mode=-1
		String smuMode=""
						
		strswitch(StringByKey("SOURCE_TYPE_V", smu_condition))
		case "1": //V-source
			script+=smuName+".source.func="+smuName+".OUTPUT_DCVOLTS\r"
			source_mode=0
			break
		case "2": //I-source
			script+=smuName+".source.func="+smuName+".OUTPUT_DCAMPS\r"
			source_mode=1
			break
		default:
			AbortOnValue 1, -200
			break
		endswitch
		
		strswitch(StringByKey("SENSE_TYPE_V", smu_condition))
		case "0": //two-wire
			script+=smuName+".sense="+smuName+".SENSE_LOCAL\r"
			break
		case "1": //four-wire
			script+=smuName+".sense="+smuName+".SENSE_REMOTE\r"
			break
		default:
			break
		endswitch
		
		strswitch(StringByKey("AUTOZERO_TYPE_V", smu_condition))
		case "0": //Enable (auto)
			script+=smuName+".measure.autozero="+smuName+".AUTOZERO_AUTO\r"
			break
		case "1": //Only once
			script+=smuName+".measure.autozero="+smuName+".AUTOZERO_ONCE\r"
			break
		case "2": //Disabled
			script+=smuName+".measure.autozero="+smuName+".AUTOZERO_OFF\r"
			break
		default:
			break
		endswitch
		
		strswitch(StringByKey("SINK_MODE_V", smu_condition))
		case "0": //sink mode disabled
			script+=smuName+".source.sink="+smuName+".DISABLE\r"
			break
		case "1": //sink mode enabled
			script+=smuName+".source.sink="+smuName+".ENABLE\r"
			break
		default:
			break
		endswitch
		
		dvalue=str2num(StringByKey("SPEED", smu_condition))
		AbortOnValue (dvalue<0.001 || dvalue>25),-110
		sprintf svalue, "%.3f", dvalue
		script+=smuName+".measure.nplc="+svalue+"\r"
		
		dvalue=str2num(StringByKey("FILTER_TYPE_V", smu_condition))
		if(dvalue==0)
			script+=smuName+".measure.filter.enable="+smuName+".FILTER_OFF\r"
		else
			script+=smuName+".measure.filter.enable="+smuName+".FILTER_ON\r"
			switch(dvalue)
			case 1: //median				
				script+=smuName+".measure.filter.type="+smuName+".FILTER_MEDIAN\r"
				break
			case 2: //moving average
				script+=smuName+".measure.filter.type="+smuName+".FILTER_MOVING_AVG\r"
				break
			case 3: //repeat average
				script+=smuName+".measure.filter.type="+smuName+".FILTER_REPEAT_AVG\r"
				break
			default:
				AbortOnValue 1, -120
				break
			endswitch
			dvalue=str2num(StringByKey("FILTER_AVGCOUNT", smu_condition))
			AbortOnValue (dvalue<1 || dvalue>100), -110
			script+=smuName+".measure.filter.count="+num2istr(dvalue)+"\r"
		endif
		
		Variable limitV=str2num(StringByKey("LIMITV", smu_condition))
		if(numtype(limitV)!=0 || limitV<0)
			limitV=20.2 // default to 20.2V
		endif
		
		Variable limitI=str2num(StringByKey("LIMITI", smu_condition))
		if(numtype(limitI)!=0 || limitI<0) 
			limitI=0.1 // default to 100mA
		endif
		
		if(K2336_check_IV_limit(limitI, limitV)!=0)
			print "Current and Voltage limits are changed due to instrument limits. limitI, limitV:", limitI, limitV
		endif
		
		sprintf svalue, "%.3e", limitV
		script+=smuName+".source.limitv="+svalue+"\r"
		
		sprintf svalue, "%.3e", limitI
		script+=smuName+".source.limiti="+svalue+"\r"
		
		
		Variable range_idx
		//setting range v, depending on v-source or i-source, the key word should be source or measure
		switch(source_mode)
		case 0:
			smuMode=".source" //sourcing V
			break
		case 1:
			smuMode=".measure" //measuring V (sourcing I)
			break
		default:
			AbortOnValue 1, -200
		endswitch
		
		svalue=StringByKey("RANGEV", smu_condition)
		if(cmpstr(svalue, "AUTO")==0)
			script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_ON\r"
			svalue=StringByKey("RANGEV_AUTOLOWRANGE", smu_condition)
			K2336_RangeFromList(svalue, K2336_VOLTAGE_RANGE_VALUE, dvalue, range_idx)		
			sprintf svalue, "%.3e", dvalue
			script+=smuName+smuMode+".lowrangev="+svalue+"\r"
		else
			script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_OFF\r"
			K2336_RangeFromList(svalue, K2336_VOLTAGE_RANGE_VALUE, dvalue, range_idx)		
			sprintf svalue, "%.3e", dvalue
			script+=smuName+smuMode+".rangev="+svalue+"\r"
		endif

		//setting range i, depending on v-source or i-source, the key word should be measure or source
		switch(source_mode)
		case 0:
			smuMode=".measure" //measuring I (sourcing V)
			break
		case 1:
			smuMode=".source"	//sourcing I
			break
		default:
			AbortOnValue 1, -200
		endswitch
		svalue=StringByKey("RANGEI", smu_condition)
		if(cmpstr(svalue, "AUTO")==0)
			script+=smuName+smuMode+".autorangei="+smuName+".AUTORANGE_ON\r"
			svalue=StringByKey("RANGEI_AUTOLOWRANGE", smu_condition)
			K2336_RangeFromList(svalue, K2336_CURRENT_RANGE_VALUE, dvalue, range_idx)	
			sprintf svalue, "%.3e", dvalue
			script+=smuName+smuMode+".lowrangei="+svalue+"\r"
		else
			script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_OFF\r"
			K2336_RangeFromList(svalue, K2336_CURRENT_RANGE_VALUE, dvalue, range_idx)
			sprintf svalue, "%.3e", dvalue
			script+=smuName+smuMode+".rangei="+svalue+"\r"
		endif
	catch
		switch(V_AbortCode)
		case -100:
			print "error: cannot find the condition variable."
			break
		case -110:
			print "invalid speed NPLC value in the condition string for "+smuName+"."
			break
		case -120:
			print "invalid filter count value in the condition string for "+smuName+"."
			break
		case -200:
			print "SMU not used. Blank script with only resetting will be generated."
		default:
			break
		endswitch

		//script=""
		retVal=-1

	endtry

	Variable frequency=1000+500*smu
	script+="beeper.beep(0.2, "+num2istr(frequency)+")\r"
	script="loadscript "+k2336_initscriptNamePrefix+smuName+"\r"+script+"endscript\r"

	return retVal

End

Function K2336Panel(String smu_list, String configStr)

	NewPanel /N=K2336Panel /W=(0,0,230,400) /K=1
	String wname=S_name
	
	PopupMenu smu_selector win=$wname, title="Select SMU", fSize=12, pos={160, 10}, bodywidth=90
	PopupMenu smu_selector win=$wname, value=#("\""+smu_list+"\""), mode=1
	PopupMenu smu_selector win=$wname, proc=k2336_smu_selector_popup
	
	PopupMenu smu_source_type win=$wname, title="Source Type",fSize=12,pos={160,35}, bodywidth=90
	PopupMenu smu_source_type win=$wname, value=#("\""+k2336_SOURCE_TYPE+"\""), mode=1
	PopupMenu smu_source_type win=$wname, proc=k2336_smu_popup
	
	SetVariable smu_limitv win=$wname,title="Voltage Limit (V)",fSize=12, pos={160,60}, bodywidth=90
	SetVariable smu_limitv win=$wname,format="%.3g",limits={k2336_MIN_LIMITV,k2336_MAX_LIMITV,0},value=_NUM:20
	SetVariable smu_limitv win=$wname,proc=k2336_smu_setvar
	
	SetVariable smu_limiti win=$wname,title="Current Limit (A)",fSize=12, pos={160,85}, bodywidth=90
	SetVariable smu_limiti win=$wname,format="%.3g",limits={k2336_MIN_LIMITI,k2336_MAX_LIMITI,0},value=_NUM:0.1
	SetVariable smu_limiti win=$wname,proc=k2336_smu_setvar
	
	PopupMenu smu_rangev win=$wname,pos={120, 110},fSize=12, bodyWidth=50,title="Voltage Range"
	PopupMenu smu_rangev win=$wname,value=#("\""+k2336_VOLTAGE_RANGE_STR+"\""),mode=2
	PopupMenu smu_rangev win=$wname, proc=k2336_smu_popup
	
	CheckBox smu_autoV title="AUTO",size={40,20},fSize=11,pos={160,110},proc=k2336_smu_checkbox
	
	PopupMenu smu_rangei win=$wname,pos={120, 135},fSize=12, bodyWidth=50,title="Current Range"
	PopupMenu smu_rangei win=$wname,value=#("\""+k2336_CURRENT_RANGE_STR+"\""),mode=2
	PopupMenu smu_rangei win=$wname, proc=k2336_smu_popup
	
	CheckBox smu_autoI title="AUTO",size={40,20},fSize=11,pos={160,135},proc=k2336_smu_checkbox
	
	PopupMenu smu_sensetype win=$wname,pos={160, 160},fSize=12, bodyWidth=90,title="Sense type"
	PopupMenu smu_sensetype win=$wname,value=#("\""+k2336_SENSE_TYPE+"\"")
	PopupMenu smu_sensetype win=$wname, proc=k2336_smu_popup
	
	PopupMenu smu_autozero win=$wname,pos={160, 185},fSize=12, bodyWidth=90,title="Auto Zero"
	PopupMenu smu_autozero win=$wname,value=#("\""+k2336_AUTOZERO_TYPE+"\"")
	PopupMenu smu_autozero win=$wname, proc=k2336_smu_popup
	
	PopupMenu smu_sinkmode win=$wname,pos={160, 210},fSize=12, bodyWidth=90,title="Sink Mode"
	PopupMenu smu_sinkmode win=$wname,value=#("\""+k2336_SINK_MODE+"\"")
	PopupMenu smu_sinkmode win=$wname, proc=k2336_smu_popup
	
	SetVariable smu_speed win=$wname,pos={160, 235},fSize=12, bodyWidth=90,title="Speed (NPLC)"
	SetVariable smu_speed win=$wname,limits={0.001,25,0.5},value=_NUM:1
	SetVariable smu_speed win=$wname, proc=k2336_smu_setvar
	
	SetVariable smu_delay win=$wname,title="Delay (s)",fSize=12, pos={160,260}, bodywidth=90
	SetVariable smu_delay win=$wname,format="%.3g",limits={0,100,0},value=_NUM:0
	SetVariable smu_delay win=$wname,proc=k2336_smu_setvar
	
	PopupMenu smu_filter win=$wname,pos={160, 285},fSize=12, bodyWidth=90,title="Filter Type"
	PopupMenu smu_filter win=$wname,value=#("\""+k2336_FILTER_TYPE+"\"")
	PopupMenu smu_filter win=$wname, proc=k2336_smu_popup
	
	SetVariable smu_filtercount win=$wname,title="Average count",fSize=12, pos={160,310}, bodywidth=90
	SetVariable smu_filtercount win=$wname,format="%d",limits={1,100,1},value=_NUM:1
	SetVariable smu_filtercount win=$wname,proc=k2336_smu_setvar
	
	Button smu_reset_default win=$wname,title="Reset to Default", fSize=12, pos={20, 335}, size={170, 25}
	Button smu_reset_default win=$wname,proc=k2336_smu_btn
	
	Button smu_OK win=$wname,title="Accept settings", fSize=12, pos={20, 360}, size={170, 25}
	Button smu_OK win=$wname,proc=k2336_smu_btn
	
	Button smu_CANCEL win=$wname,title="Cancel", fSize=12, pos={20, 385}, size={170, 25}
	Button smu_CANCEL win=$wname,proc=k2336_smu_btn
	
	PauseForUser $wname

	

End


Function k2336_smu_selector_popup(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function k2336_smu_popup(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function k2336_smu_setvar(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function k2336_smu_btn(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			
			strswitch(ba.ctrlName)
			case "smu_reset_default":
				break
			case "smu_OK":
				break
			case "smu_cancel":
				break
			default:
				break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

