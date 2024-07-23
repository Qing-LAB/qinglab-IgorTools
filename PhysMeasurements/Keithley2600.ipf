#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7


#ifdef DEBUG_LEVEL_1
#define DEBUG_QDLVISA_1
#endif

#ifdef DEBUG_LEVEL_2
#define DEBUG_QDLVISA_2
#endif

#ifdef DEBUG_LEVEL_3
#define DEBUG_QDLVISA_3
#endif

#ifndef WAVEBROWSER
#include "WaveBrowser"
#endif

#ifndef QDATALINK
#include "QDataLink"
#endif

#include "keithley2600Constants"

Menu "QDataLink"
	Submenu "Keithley2600"
		"Connect to Keithley 2600", Keithley2600ConnectionINIT()
		"Setup SMUs", KeithleyConfigSMUs("SMUA;SMUB", "", SaveConfigStr="root:S_KeithleySMUConfig")
		"Initialize SMUs", KeithleyInit()
		"Reset Keithley", KeithleyReset()
	end
end

Function Keithley2600ConnectionINIT()
	String port_list=QDataLinkcore#QDLSerialPortGetList()
	String port_select=""
	PROMPT port_select, "Port Name", popup port_list
	DoPrompt "Select Serial Port", port_select
	
	SVAR configStr=root:S_KeithleyPortConfig
	if(!SVAR_Exists(configStr))
		String /G root:S_KeithleyPortConfig=""
		SVAR configStr=root:S_KeithleyPortConfig
	endif
	if(strlen(configStr)==0)		
		STRUCT QDLConnectionParam cp
		configStr=QDataLinkCore#QDLSetVISAConnectionParameters(configStr, paramStruct=cp)
	endif
	if(V_Flag==0)
		Variable instance_select=-1
		String cpStr=""
		cpStr=QDataLinkCore#QDLInitSerialPort(port_select, configStr, instance_select, quiet=1)
		if(strlen(cpStr)>0 && instance_select>=0)
			Variable slot=QDataLinkCore#QDLGetSlotInfo(instance_select)
			QDataLinkCore#QDLQuery(slot, "", 0, realtime_func="Keithley2600_rtfunc", postprocess_bgfunc="Keithley2600_postprocess_bgfunc")
			QDataLinkCore#qdl_update_instance_info(instance_select, "Keithley SMUs", "Keithley 2600 series", port_select)
			configStr=ReplaceStringByKey("SLOT", configStr, num2istr(slot))
			configStr=ReplaceStringByKey("INSTANCE", configStr, num2istr(instance_select))
		endif
	endif
End

Function /T Keithley2600GetPrivateFolderName()
	SVAR configStr=root:S_KeithleyPortConfig
	if(!SVAR_Exists(configStr))
		return ""
	endif
	Variable instance=str2num(StringByKey("INSTANCE", configStr))
	if(instance>=0)
		String fullPath=WBSetupPackageDir(QDLPackageName, instance=instance)
		return WBPkgGetName(fullPath, WBPkgDFDF, "Keithley2600")
	else
		return ""
	endif
End

Function k2600_RangeFromList(String range_str, String option_list, String value_list, Variable & range_value, Variable & range_idx)
	Variable retVal=0
	
	try
		range_idx=WhichListItem(range_str, option_list); AbortOnRTE
		if(range_idx<0)
			Variable val1, val2, i
			sscanf range_str, "%f", val1; AbortOnRTE
			for(i=0; i<ItemsInList(value_list); i+=1)
				sscanf StringFromList(i, value_list), "%f", val2; AbortOnRTE
				if(val2<val1)
					break
				endif
			endfor
			i-=1
			if(i<0)
				print "k2600_RangeFromList Warning: Request out of range. Maximum level is used."
				i=0
			endif
			range_idx=i; AbortOnRTE
		endif
		sscanf StringFromList(range_idx, value_list), "%f", range_value; AbortOnRTE
	catch
		Variable err=GetRTError(1)
		print "k2600_RangeFromList get an error: "+GetErrMessage(err)
		retVal=-1
	endtry
	
	return retVal
End


Function k2600_check_IV_limit(Variable & limitI, Variable & limitV)
	Variable retVal=0
	
	if(limitI>0.1) //100 mA
		if(limitV>20.2) //20.2V
			limitI=0.1
			print "k2600_check_IV_limit: current limit is out of range. force setting to 100mA"
			retVal+=1
		endif
	endif
	
	if(limitV>20.2)
		if(limitI>0.1)
			limitV=20.2
			print "k2600_check_IV_limit: voltage limit is out of range. force setting to 20.2V"
			retVal+=1
		endif
	endif	
	return retVal
End


Function KeithleyGenerateInitScript(String configStr, String & nbName)
	
	Variable retVal=0
	
	Variable instance=-1
	String dfr=WBSetupPackageDir(k2600PackageName, instance=instance, existence=1)
	
	nbName=UniqueName(nbName, 10, 0)
	NewNotebook /F=1 /K=1 /N=$nbName; AbortOnRTE
	String script=""
			
	Variable smu, number_of_smu
	String smuName=""
	number_of_smu=ItemsInList(configStr, "#")
	
	for(smu=0; smu<number_of_smu; smu+=1)
		smuName=LowerStr(StringFromList(0, StringFromList(smu, configStr, "#"), "@"))
		
		if(strlen(smuName)==0)
			continue
		endif
		
		String smu_condition=""
		smu_condition=StringByKey(smuName, configStr, "@", "#", 0)
		
		script+="loadscript "+k2600_initscriptNamePrefix+smuName+"\r"
		script+=smuName+".reset()\r"
	
		try
			String svalue
			Variable dvalue, source_mode=-1
			String smuMode=""
							
			strswitch(StringByKey("SOURCE_TYPE", smu_condition))
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
			
			strswitch(StringByKey("SENSE_TYPE", smu_condition))
			case "0": //two-wire
				script+=smuName+".sense="+smuName+".SENSE_LOCAL\r"
				break
			case "1": //four-wire
				script+=smuName+".sense="+smuName+".SENSE_REMOTE\r"
				break
			default:
				break
			endswitch
			
			strswitch(StringByKey("AUTOZERO_TYPE", smu_condition))
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
			
			strswitch(StringByKey("SINK_MODE", smu_condition))
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
			
			dvalue=str2num(StringByKey("DELAY", smu_condition))
			if(dvalue==0)
				svalue=smuName+".DELAY_OFF"
			elseif(dvalue<0)
				svalue=smuName+".DELAY_AUTO"
			else
				sprintf svalue, "%.3f", dvalue
			endif
			script+=smuName+".measure.delay="+svalue+"\r"
			script+=smuName+".source.delay="+svalue+"\r"
			
			dvalue=str2num(StringByKey("FILTER_TYPE", smu_condition))
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
			
			if(k2600_check_IV_limit(limitI, limitV)!=0)
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
				k2600_RangeFromList(svalue, k2600_VOLTAGE_AUTORANGE_STR, k2600_VOLTAGE_RANGE_VALUE, dvalue, range_idx)		
				sprintf svalue, "%.3e", dvalue
				script+=smuName+smuMode+".lowrangev="+svalue+"\r"
			else
				script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_OFF\r"
				k2600_RangeFromList(svalue, k2600_VOLTAGE_RANGE_STR, k2600_VOLTAGE_RANGE_VALUE, dvalue, range_idx)		
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
				k2600_RangeFromList(svalue, k2600_CURRENT_AUTORANGE_STR, k2600_CURRENT_RANGE_VALUE, dvalue, range_idx)	
				sprintf svalue, "%.3e", dvalue
				script+=smuName+smuMode+".lowrangei="+svalue+"\r"
			else
				script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_OFF\r"
				k2600_RangeFromList(svalue, k2600_CURRENT_RANGE_STR, k2600_CURRENT_RANGE_VALUE, dvalue, range_idx)
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
				print "SMU "+smuName+" not used. Blank script with only resetting will be generated."
			default:
				break
			endswitch
			retVal=-1	
		endtry
	
		Variable frequency=1000+500*smu
		script+="beeper.beep(0.2, "+num2istr(frequency)+")\r"
		script+="endscript\r"
		print "SMU "+smuName+" initialization script generated."
	endfor
	
	script+="loadscript IgorKeithleyInit_all()\r"
	script+="smua.reset()\r"
	script+="smub.reset()\r"
	script+="reset()\r"
	script+="IgorKeithleyInit_smua()\r"
	script+="IgorKeithleyInit_smub()\r"
	script+="display.clear()\r"
	script+="display.setcursor(1,1)\r"
	script+="display.settext(\"SMUs Initialized\")\r"
	script+="status.reset()\r"
	script+="status.request_enable=status.MAV\r"
	script+="print(\"Keithley initialized.\")\r"
	script+="endscript\r"
	
	script+="IgorKeithleyInit_all()"
	
	Notebook $nbName, text="Keithley Script Generated ["+date()+", "+time()+"]\r\r\r"
	Notebook $nbName, text="KEITHLEY INIT SCRIPT BEGIN\r\r"
	Notebook $nbName, text=script
	Notebook $nbName, text="\rKEITHLEY INIT SCRIPT END\r"
	return retVal
End

Function /T KeithleyConfigSMUs(String smu_list, String configStr, [Variable timeout, String SaveConfigStr])
	if(ItemsInList(smu_list)<1)
		return ""
	endif
		
	NewPanel /N=k2600Panel /W=(0,0,240,430) /K=1
	String wname=S_name
	
	TabControl smu_tab win=$wname, pos={5,5}, size={230,360}, proc=k2600_smu_tab
	Variable i
	for(i=0; i<ItemsInList(smu_list); i+=1)
		TabControl smu_tab win=$wname, tabLabel(i)=StringFromList(i, smu_list)
	endfor
	
	PopupMenu smu_source_type win=$wname, title="Source Type",fSize=12,pos={160,35}, bodywidth=90
	PopupMenu smu_source_type win=$wname, value=#("\""+k2600_SOURCE_TYPE+"\""), mode=1
	PopupMenu smu_source_type win=$wname, proc=k2600_smu_popup
	
	SetVariable smu_limitv win=$wname,title="Voltage Limit (V)",fSize=11, pos={160,60}, bodywidth=90
	SetVariable smu_limitv win=$wname,format="%.3g",limits={k2600_MIN_LIMITV,k2600_MAX_LIMITV,0},value=_NUM:20
	SetVariable smu_limitv win=$wname,proc=k2600_smu_setvar
	
	SetVariable smu_limiti win=$wname,title="Current Limit (A)",fSize=11, pos={160,85}, bodywidth=90
	SetVariable smu_limiti win=$wname,format="%.3g",limits={k2600_MIN_LIMITI,k2600_MAX_LIMITI,0},value=_NUM:0.1
	SetVariable smu_limiti win=$wname,proc=k2600_smu_setvar
	
	PopupMenu smu_rangev win=$wname,pos={120, 110},fSize=11, bodyWidth=95,title="V Range"
	PopupMenu smu_rangev win=$wname,value=#("\""+k2600_VOLTAGE_AUTORANGE_STR+"\""),mode=4
	PopupMenu smu_rangev win=$wname, proc=k2600_smu_popup
	
	CheckBox smu_autoV win=$wname,title="AUTO",size={40,20},fSize=11,pos={175,110},value=1,proc=k2600_smu_checkbox
	
	PopupMenu smu_rangei win=$wname,pos={120, 135},fSize=11, bodyWidth=95,title="I Range"
	PopupMenu smu_rangei win=$wname,value=#("\""+k2600_CURRENT_AUTORANGE_STR+"\""),mode=12
	PopupMenu smu_rangei win=$wname, proc=k2600_smu_popup
	
	CheckBox smu_autoI win=$wname,title="AUTO",size={40,20},fSize=11,pos={175,135},value=1,proc=k2600_smu_checkbox
	
	PopupMenu smu_sensetype win=$wname,pos={160, 160},fSize=11, bodyWidth=90,title="Sense type"
	PopupMenu smu_sensetype win=$wname,value=#("\""+k2600_SENSE_TYPE+"\""),mode=1
	PopupMenu smu_sensetype win=$wname, proc=k2600_smu_popup
	
	PopupMenu smu_autozero win=$wname,pos={160, 185},fSize=11, bodyWidth=90,title="Auto Zero"
	PopupMenu smu_autozero win=$wname,value=#("\""+k2600_AUTOZERO_TYPE+"\""),mode=1
	PopupMenu smu_autozero win=$wname, proc=k2600_smu_popup
	
	PopupMenu smu_sinkmode win=$wname,pos={160, 210},fSize=11, bodyWidth=90,title="Sink Mode"
	PopupMenu smu_sinkmode win=$wname,value=#("\""+k2600_SINK_MODE+"\""),mode=1
	PopupMenu smu_sinkmode win=$wname, proc=k2600_smu_popup
	
	SetVariable smu_speed win=$wname,pos={160, 235},fSize=11, bodyWidth=90,title="Speed (NPLC)"
	SetVariable smu_speed win=$wname,limits={0.001,25,0.5},value=_NUM:1
	SetVariable smu_speed win=$wname, proc=k2600_smu_setvar
	
	SetVariable smu_delay win=$wname,title="Delay (s)",fSize=11, pos={160,260}, bodywidth=90
	SetVariable smu_delay win=$wname,format="%.3g",limits={-1,100,0},value=_NUM:(-1),help={"-1 means AUTO delay"}
	SetVariable smu_delay win=$wname,proc=k2600_smu_setvar
	
	PopupMenu smu_filter win=$wname,pos={160, 285},fSize=11, bodyWidth=90,title="Filter Type"
	PopupMenu smu_filter win=$wname,value=#("\""+k2600_FILTER_TYPE+"\""),mode=1
	PopupMenu smu_filter win=$wname, proc=k2600_smu_popup
	
	SetVariable smu_filtercount win=$wname,title="Average count",fSize=11, pos={160,310}, bodywidth=90
	SetVariable smu_filtercount win=$wname,format="%d",limits={1,100,1},value=_NUM:1
	SetVariable smu_filtercount win=$wname,proc=k2600_smu_setvar
	
	Button smu_reset_default win=$wname,title="Reset to Default", fSize=11, pos={50, 335}, size={140, 20}
	Button smu_reset_default win=$wname,proc=k2600_smu_btn
	
	Button smu_OK win=$wname,title="Accept settings", fSize=11, pos={40, 380}, size={160, 20}
	Button smu_OK win=$wname,proc=k2600_smu_btn
	
	Button smu_CANCEL win=$wname,title="Cancel", fSize=11, pos={40, 400}, size={160, 20}
	Button smu_CANCEL win=$wname,proc=k2600_smu_btn
		
	String strName=UniqueName("S_"+wname+"_CfgStr", 4, 0)
	String newcfgstr=""
	Variable starttime=ticks
	
	if(!ParamIsDefault(SaveConfigStr))
		SVAR saveto=$SaveConfigStr; AbortOnRTE
		if(!SVAR_Exists(saveto))
			String /G $SaveConfigStr=""; AbortOnRTE
			SVAR saveto=$SaveConfigStr; AbortOnRTE
		endif
		if(strlen(configStr)==0 && strlen(saveto)>0)
			configStr=saveto; AbortOnRTE
		endif
	endif
	
	try
		String /G $(strName);AbortOnRTE
		SVAR cfgStr=$(strName)
		cfgStr=configStr; AbortOnRTE
		SetWindow $wname, UserData(CONFIG_STR_STORAGE_NAME)=strName; AbortOnRTE
		SetWindow $wname, UserData(CONFIG_STR)=configStr; AbortOnRTE
		
		String smuconfig=""
		for(i=ItemsInList(smu_list)-1; i>=0; i-=1)
			TabControl smu_tab win=$wname, value=i
			k2600_update_controls(wname)
			k2600_update_configstr(wname)
		endfor
		
		Variable timeoutflag=0
		
		if(!ParamIsDefault(timeout))
			Button smu_OK win=$wname,pos={40, 390}
			Button smu_CANCEL win=$wname,pos={40, 410}
			do
				PauseForUser /C $wname; AbortOnRTE
				if(V_Flag)
					Sleep /T 10
					TitleBox smu_timeout_note, win=$wname, fColor=(65535,0,0), title="Time out in "+num2istr(round((timeout*60-(ticks-starttime))/60))+" secs...", pos={40, 370}; AbortOnRTE
				else
					break
				endif
			while(ticks-starttime<timeout*60)
			timeoutflag=1
		else
			PauseForUser $wname; AbortOnRTE
		endif
		
		if(timeoutflag==1)
			KillWindow /Z $wname
		endif
		
	catch
		Variable err=GetRTError(1)
		print "k2600Panel catched an error: "+GetErrMessage(err)
		if(SVAR_Exists(cfgStr))
			cfgStr=""
		endif
		newcfgstr=""
	endtry
	SVAR cfgStr=$(strName)
	if(SVAR_Exists(cfgStr))
		newcfgstr=cfgStr
		KillStrings /Z $strName
	endif
	
	if(strlen(newcfgstr)>0 && !ParamIsDefault(SaveConfigStr))
		SVAR saveto=$SaveConfigStr; AbortOnRTE
		saveto=newcfgstr; AbortOnRTE
	endif
	
	return newcfgstr
End

Function k2600_update_configstr(String wname)
	String configStrName=GetUserData(wname, "", "CONFIG_STR_STORAGE_NAME")
	String config=GetUserData(wname, "", "CONFIG_STR")
	SVAR cfgStr=$(configStrName)
	
	if(SVAR_Exists(cfgStr))
		try
			ControlInfo /W=$wname smu_tab; AbortOnRTE
			String smu_name=S_Value
			//print "SMU: "+smu_name+" selected."
			String smuconfig=StringByKey(smu_name, cfgStr, "@", "#"); AbortOnRTE
			
			ControlInfo /W=$wname smu_source_type; AbortOnRTE
			switch(V_Value)
			case 2:
				smuconfig=ReplaceStringByKey("SOURCE_TYPE", smuconfig, "1"); AbortOnRTE
				break
			case 3:
				smuconfig=ReplaceStringByKey("SOURCE_TYPE", smuconfig, "2"); AbortOnRTE
				break
			default:
				smuconfig=ReplaceStringByKey("SOURCE_TYPE", smuconfig, "-1"); AbortOnRTE
				break
			endswitch
			
			Variable limitv, limiti
			ControlInfo /W=$wname smu_limitv; AbortOnRTE
			limitv=V_Value; AbortOnRTE
			ControlInfo /W=$wname smu_limiti; AbortOnRTE
			limiti=V_Value; AbortOnRTE
			
			if(k2600_Check_IV_limit(limiti, limitv)!=0)
				SetVariable smu_limitv, win=$wname, value=_NUM:(limitv); AbortOnRTE
				SetVariable smu_limiti, win=$wname, value=_NUM:(limiti); AbortOnRTE
			endif
			smuconfig=ReplaceStringByKey("LIMITV", smuconfig, num2str(limitv)); AbortOnRTE
			smuconfig=ReplaceStringByKey("LIMITI", smuconfig, num2str(limiti)); AbortOnRTE
			
			String rangeSel=""
			ControlInfo /W=$wname smu_rangev; AbortOnRTE
			rangeSel=S_Value; AbortOnRTE
			
			ControlInfo /W=$wname smu_autoV; AbortOnRTE
			if(V_Value)
				smuconfig=ReplaceStringByKey("RANGEV", smuconfig, "AUTO"); AbortOnRTE
				smuconfig=ReplaceStringByKey("RANGEV_AUTOLOWRANGE", smuconfig, rangeSel); AbortOnRTE
			else
				smuconfig=ReplaceStringByKey("RANGEV", smuconfig, rangeSel); AbortOnRTE
				smuconfig=RemoveByKey("RANGEV_AUTOLOWRANGE", smuconfig); AbortOnRTE
			endif
			
			ControlInfo /W=$wname smu_rangei; AbortOnRTE
			rangeSel=S_Value; AbortOnRTE
			
			ControlInfo /W=$wname smu_autoI; AbortOnRTE
			if(V_Value)
				smuconfig=ReplaceStringByKey("RANGEI", smuconfig, "AUTO"); AbortOnRTE
				smuconfig=ReplaceStringByKey("RANGEI_AUTOLOWRANGE", smuconfig, rangeSel); AbortOnRTE
			else
				smuconfig=ReplaceStringByKey("RANGEI", smuconfig, rangeSel); AbortOnRTE
				smuconfig=RemoveByKey("RANGEI_AUTOLOWRANGE", smuconfig); AbortOnRTE
			endif
			
			ControlInfo /W=$wname smu_sensetype; AbortOnRTE
			switch(V_Value)
			case 1: //two wire
				smuconfig=ReplaceStringByKey("SENSE_TYPE", smuconfig, "0"); AbortOnRTE
				break
			case 2: //four wire
				smuconfig=ReplaceStringByKey("SENSE_TYPE", smuconfig, "1"); AbortOnRTE
				break
			default:
				break
			endswitch
			
			ControlInfo /W=$wname smu_autozero; AbortOnRTE
			switch(V_Value)
			case 1: //Enabled (auto)
				smuconfig=ReplaceStringByKey("AUTOZERO_TYPE", smuconfig, "0"); AbortOnRTE
				break
			case 2: //Only Once
				smuconfig=ReplaceStringByKey("AUTOZERO_TYPE", smuconfig, "1"); AbortOnRTE
				break
			case 3: //Disabled
				smuconfig=ReplaceStringByKey("AUTOZERO_TYPE", smuconfig, "2"); AbortOnRTE
				break
			default:
				smuconfig=ReplaceStringByKey("AUTOZERO_TYPE", smuconfig, "-1"); AbortOnRTE
				break
			endswitch
			
			ControlInfo /W=$wname smu_sinkmode; AbortOnRTE
			switch(V_Value)
			case 1: //sink mode disabled
				smuconfig=ReplaceStringByKey("SINK_MODE", smuconfig, "0"); AbortOnRTE
				break
			case 2: //sink mode enabled
				smuconfig=ReplaceStringByKey("SINK_MODE", smuconfig, "1"); AbortOnRTE
				break
			default:
				smuconfig=ReplaceStringByKey("SINK_MODE", smuconfig, "-1"); AbortOnRTE
				break
			endswitch

			ControlInfo /W=$wname smu_speed; AbortOnRTE
			smuconfig=ReplaceStringByKey("SPEED", smuconfig, num2str(V_Value)); AbortOnRTE
			
			ControlInfo /W=$wname smu_delay; AbortOnRTE
			if(V_Value<0)
				SetVariable smu_delay, win=$wname, value=_NUM:(-1); AbortOnRTE
				smuconfig=ReplaceStringByKey("DELAY", smuconfig, "-1"); AbortOnRTE
			else
				smuconfig=ReplaceStringByKey("DELAY", smuconfig, num2str(V_Value)); AbortOnRTE
			endif
			
			Variable filtertype, filtercount
			ControlInfo /W=$wname smu_filter; AbortOnRTE
			filtertype=V_Value; AbortOnRTE
			ControlInfo /W=$wname smu_filtercount; AbortOnRTE
			filtercount=V_Value; AbortOnRTE
			
			switch(filtertype)
			case 1: //Disabled
				smuconfig=ReplaceStringByKey("FILTER_TYPE", smuconfig, "0"); AbortOnRTE
				break
			case 2: //Median
				smuconfig=ReplaceStringByKey("FILTER_TYPE", smuconfig, "1"); AbortOnRTE
				break
			case 3: //Move average
				smuconfig=ReplaceStringByKey("FILTER_TYPE", smuconfig, "2"); AbortOnRTE
				break
			case 4: //Repeat average
				smuconfig=ReplaceStringByKey("FILTER_TYPE", smuconfig, "3"); AbortOnRTE
				break
			default:
				smuconfig=ReplaceStringByKey("FILTER_TYPE", smuconfig, "0"); AbortOnRTE
				break
			endswitch
			smuconfig=ReplaceStringByKey("FILTER_AVGCOUNT", smuconfig, num2istr(filtercount)); AbortOnRTE
			
			cfgStr=ReplaceStringByKey(smu_name, cfgStr, smuconfig, "@", "#"); AbortOnRTE
		catch
			Variable err=GetRTError(1)
			print "k2600_update_configstr encountered an error: "+GetErrMessage(err)
		endtry
		config=cfgStr
	endif
	SetWindow $wname, UserData(CONFIG_STR)=config
End

Function k2600_update_controls(String wname)
	try	
		String configstr=GetUserData(wname, "", "CONFIG_STR");AbortOnRTE
	
		ControlInfo /W=$wname smu_tab; AbortOnRTE
		String smu_name=S_Value
		String smuconfig=StringByKey(smu_name, configstr, "@", "#"); AbortOnRTE
		
		if(strlen(smuconfig)==0)
			k2600_smu_resetdefault(wname); AbortOnRTE
			configstr=GetUserData(wname, "", "CONFIG_STR");AbortOnRTE
			smuconfig=StringByKey(smu_name, configstr, "@", "#"); AbortOnRTE
		endif
		
		String svalue
		Variable dvalue, idxvalue
		
		svalue=StringByKey("SOURCE_TYPE", smuconfig); AbortOnRTE
		strswitch(svalue)
		case "1":
			PopupMenu smu_source_type, win=$wname, mode=2; AbortOnRTE
			break
		case "2":
			PopupMenu smu_source_type, win=$wname, mode=3; AbortOnRTE
			break
		default:
			PopupMenu smu_source_type, win=$wname, mode=1; AbortOnRTE
			break
		endswitch
		
		Variable limiti, limitv
		
		svalue=StringByKey("LIMITV", smuconfig)
		limitv=str2num(svalue)
		svalue=StringByKey("LIMITI", smuconfig)
		limiti=str2num(svalue)
		if(!(numtype(limitv)==0 && limitv>=0 && limitv<=200))
			limitv=20
		endif
		if(!(numtype(limiti)==0 && limiti>=0 && limiti<=1.5))
			limiti=0.1
		endif
		K2600_check_IV_limit(limiti, limitv)
		SetVariable smu_limitv, win=$wname, value=_NUM:limitv; AbortOnRTE
		SetVariable smu_limiti, win=$wname, value=_NUM:limiti; AbortOnRTE
		
		svalue=StringByKey("RANGEV", smuconfig)
		if(cmpstr(svalue, "AUTO")==0)
			CheckBox smu_autov, win=$wname, value=1; AbortOnRTE
			svalue=StringByKey("RANGEV_AUTOLOWRANGE", smuconfig)
			k2600_RangeFromList(svalue, k2600_VOLTAGE_AUTORANGE_STR, k2600_VOLTAGE_RANGE_VALUE, dvalue, idxvalue)
			PopupMenu smu_rangev, win=$wname, value=#("\""+k2600_VOLTAGE_AUTORANGE_STR+"\""), mode=(idxvalue+1); AbortOnRTE
		else
			CheckBox smu_autov, win=$wname, value=0; AbortOnRTE
			k2600_RangeFromList(svalue, k2600_VOLTAGE_RANGE_STR, k2600_VOLTAGE_RANGE_VALUE, dvalue, idxvalue)
			PopupMenu smu_rangev, win=$wname, value=#("\""+k2600_VOLTAGE_RANGE_STR+"\""), mode=(idxvalue+1); AbortOnRTE
		endif
		
		svalue=StringByKey("RANGEI", smuconfig)
		if(cmpstr(svalue, "AUTO")==0)
			CheckBox smu_autoi, win=$wname, value=1; AbortOnRTE
			svalue=StringByKey("RANGEI_AUTOLOWRANGE", smuconfig)
			k2600_RangeFromList(svalue, k2600_CURRENT_AUTORANGE_STR, k2600_CURRENT_RANGE_VALUE, dvalue, idxvalue)
			PopupMenu smu_rangei, win=$wname, value=#("\""+k2600_CURRENT_AUTORANGE_STR+"\""), mode=(idxvalue+1); AbortOnRTE
		else
			CheckBox smu_autoi, win=$wname, value=0; AbortOnRTE
			k2600_RangeFromList(svalue, k2600_CURRENT_RANGE_STR, k2600_CURRENT_RANGE_VALUE, dvalue, idxvalue)
			PopupMenu smu_rangei, win=$wname, value=#("\""+k2600_CURRENT_RANGE_STR+"\""), mode=(idxvalue+1); AbortOnRTE
		endif
		
		svalue=StringByKey("SENSE_TYPE", smuconfig)
		strswitch(svalue)
		case "0":
			PopupMenu smu_sensetype, win=$wname, mode=1
			break
		case "1":
			PopupMenu smu_sensetype, win=$wname, mode=2
			break
		default:
			PopupMenu smu_sensetype, win=$wname, mode=1
			break
		endswitch
		
		svalue=StringByKey("AUTOZERO_TYPE", smuconfig)
		strswitch(svalue)
		case "0":
			PopupMenu smu_autozero, win=$wname, mode=1
			break
		case "1":
			PopupMenu smu_autozero, win=$wname, mode=2
			break
		case "2":
			PopupMenu smu_autozero, win=$wname, mode=3
			break
		default:
			PopupMenu smu_autozero, win=$wname, mode=1
			break
		endswitch
		
		svalue=StringByKey("SINK_MODE", smuconfig)
		strswitch(svalue)
		case "0":
			PopupMenu smu_sinkmode, win=$wname, mode=1
			break
		case "1":
			PopupMenu smu_sinkmode, win=$wname, mode=2
			break
		default:
			PopupMenu smu_sinkmode, win=$wname, mode=1
			break
		endswitch
		
		svalue=StringByKey("SPEED", smuconfig)
		dvalue=str2num(svalue)
		if(!(numtype(dvalue)==0 && dvalue>=0.001 && dvalue<=25))
			dvalue=1
		endif
		SetVariable smu_speed, win=$wname, value=_NUM:dvalue
		
		svalue=StringByKey("DELAY", smuconfig)
		dvalue=str2num(svalue)
		if(!(numtype(dvalue)==0 && dvalue>=-1 && dvalue<=100))
			dvalue=-1
		endif
		if(dvalue<0)
			dvalue=-1
		endif
		SetVariable smu_delay, win=$wname, value=_NUM:dvalue
		
		svalue=StringByKey("FILTER_TYPE", smuconfig)
		strswitch(svalue)
		case "0":
			PopupMenu smu_filter, win=$wname, mode=1
			break
		case "1":
			PopupMenu smu_filter, win=$wname, mode=2
			break
		case "2":
			PopupMenu smu_filter, win=$wname, mode=3
			break
		case "3":
			PopupMenu smu_filter, win=$wname, mode=4
			break
		default:
			PopupMenu smu_filter, win=$wname, mode=1
			break
		endswitch
		
		svalue=StringByKey("FILTER_AVGCOUNT", smuconfig)
		dvalue=str2num(svalue)
		if(!(numtype(dvalue)==0 && dvalue>=1 && dvalue<=100))
			dvalue=1
		endif
		SetVariable smu_filtercount, win=$wname, value=_NUM:dvalue
	catch
		Variable err=GetRTError(1)
		print "k2600_update_control encountered an error: "+GetErrMessage(err)
	endtry

End


Function k2600_smu_popup(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			k2600_update_configstr(pa.win)
			break
		case -1: // control being killed
			break
	endswitch
	
	return 0
End

Function k2600_smu_setvar(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			k2600_update_configstr(sva.win)
			break
		case -1: // control being killed
			break
	endswitch
	
	return 0
End

Function k2600_smu_resetdefault(String wname)
	PopupMenu smu_source_type,win=$wname, value=#("\""+k2600_SOURCE_TYPE+"\""), mode=1; AbortOnRTE
	SetVariable smu_limitv,win=$wname,value=_NUM:20; AbortOnRTE
	SetVariable smu_limiti,win=$wname,value=_NUM:0.1; AbortOnRTE
	PopupMenu smu_rangev,win=$wname,mode=4; AbortOnRTE
	CheckBox smu_autoV,win=$wname,value=1; AbortOnRTE
	PopupMenu smu_rangei,win=$wname,mode=12; AbortOnRTE
	CheckBox smu_autoI,win=$wname,value=1; AbortOnRTE
	PopupMenu smu_sensetype,win=$wname,mode=1; AbortOnRTE
	PopupMenu smu_autozero,win=$wname,mode=1; AbortOnRTE
	PopupMenu smu_sinkmode,win=$wname,mode=1; AbortOnRTE
	SetVariable smu_speed,win=$wname,value=_NUM:1; AbortOnRTE
	SetVariable smu_delay,win=$wname,value=_NUM:(-1); AbortOnRTE
	PopupMenu smu_filter,win=$wname,mode=1; AbortOnRTE
	SetVariable smu_filtercount,win=$wname,value=_NUM:1; AbortOnRTE
	
	k2600_update_configstr(wname)
End


Function k2600_smu_btn(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String cfgStrName=GetUserData(ba.win, "", "CONFIG_STR_STORAGE_NAME")
	String wname=ba.win
	
	switch( ba.eventCode )
		case 2: // mouse up
			try
				strswitch(ba.ctrlName)
				case "smu_reset_default":
					k2600_smu_resetdefault(wname)
					break
				case "smu_OK":
					SVAR cfgStr=$(cfgStrName)
					if(SVAR_Exists(cfgStr))
						k2600_update_configstr(ba.win)
					endif
					KillWindow /Z $(ba.win)
					break
				case "smu_cancel":
					SVAR cfgStr=$(cfgStrName)
					if(SVAR_Exists(cfgStr))
						cfgStr=""
					endif
					print "User cancelled Keithley 2600 SMU setup."
					KillWindow /Z $(ba.win)
					break
				default:
					break
				endswitch
			catch
				Variable err=GetRTError(1)
				print "K2600Panel catched error: "+GetErrMessage(err)
			endtry
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function k2600_smu_tab(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			k2600_update_controls(tca.win)
			break
		case -1: // control being killed
			break
	endswitch
	
	return 0
End


Function k2600_smu_checkbox(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	String wname=cba.win
	
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			strswitch(cba.ctrlName)
			case "smu_autov":
				ControlInfo /W=$wname smu_rangev
				if(checked)
					PopupMenu smu_rangev,win=$wname,value=#("\""+k2600_VOLTAGE_AUTORANGE_STR+"\""),mode=V_Value; AbortOnRTE
				else
					PopupMenu smu_rangev,win=$wname,value=#("\""+k2600_VOLTAGE_RANGE_STR+"\""),mode=V_Value; AbortOnRTE
				endif
				break
			case "smu_autoi":
				ControlInfo /W=$wname smu_rangei
				if(checked)
					PopupMenu smu_rangei,win=$wname,value=#("\""+k2600_CURRENT_AUTORANGE_STR+"\""),mode=V_Value; AbortOnRTE
				else
					PopupMenu smu_rangei,win=$wname,value=#("\""+k2600_CURRENT_RANGE_STR+"\""),mode=V_Value; AbortOnRTE
				endif
				break
			default:
				break
			endswitch
			k2600_update_configstr(wname)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function KeithleyGetInitScript(String nbName, String & initScript)
	initScript=""
	try
		Notebook $nbName, findText={"KEITHLEY INIT SCRIPT BEGIN", 0x01+0x04+0x08}
		if(V_flag==1)
			Variable textflag=0
			do
				Notebook $nbName, selection={startOfNextParagraph, endOfNextParagraph}
				if(V_flag==0)
					GetSelection notebook, $nbName, 0x02
					String content=TrimString(S_selection)
					if(V_flag==1 && CmpStr(content, "KEITHLEY INIT SCRIPT END")!=0)
						if(strlen(content)>0)
							initScript+=S_selection
						endif
					else
						textflag=1
					endif
				else
					textflag=-1
				endif
			while (textflag==0)
			if(textflag!=1)
				print "Init script is not contained between 'KEITHLEY INIT SCRIPT BEGIN' and 'KEITHLEY INIT SCRIPT END' properly."
			endif
		endif
	catch
	endtry
End

Function KeithleyInit()

	String initscript=""
	String iscript=""
	
	SVAR configStr=root:S_KeithleySMUConfig
	if(!SVAR_Exists(configStr) || strlen(configStr)==0)
		return -1
	endif
	
	SVAR portStr=root:S_KeithleyPortConfig
	if(!SVAR_Exists(portStr) || strlen(portStr)==0)
		return -1
	endif
	
	Variable slot=str2num(StringByKey("SLOT", portStr))
	if(slot>=0)
		String nbName="KeithleyINITScript"
		KeithleyGenerateInitScript(configStr, nbName)	
		KeithleyGetInitScript(nbName, initscript)
		
		SVAR cmd_out=root:S_KeithleyCMD
		NVAR cmd_responseflag=root:V_KeithleyCMDReadFlag
		
		cmd_out=ReplaceString("\r", initscript, "\n")
		cmd_responseflag=1
		QDLLog("Keithley InitScript sent as:\r\n\t\t\t\t\t"+ReplaceString("\r", initscript, "\r\t\t\t\t\t"))
	endif
End
	
Function KeithleyReset()
	String cmd="smua.reset()\nsmub.reset()\nreset()\nstatus.reset()\nstatus.request_enable=status.MAV\nprint(\"Keithley has been reset.\")"
	SVAR cmd_out=root:S_KeithleyCMD
	NVAR cmd_responseflag=root:V_KeithleyCMDReadFlag
	cmd_out=cmd
	cmd_responseflag=1
End

Function /T KeithleyGetPrivateFolderName()
	SVAR configStr=root:S_KeithleyPortConfig
	if(!SVAR_Exists(configStr))
		return ""
	endif
	Variable instance=str2num(StringByKey("INSTANCE", configStr))
	if(instance>=0)
		String fullPath=WBSetupPackageDir(QDLPackageName, instance=instance)
		return WBPkgGetName(fullPath, WBPkgDFDF, "Keithley2600")
	else
		return ""
	endif
End

Function /T KeithleyGetPrivateFlagName()
	return KeithleyGetPrivateFolderName()+"last_usercmd_status"
End


Function KeithleyResetCMDStatusFlag()
	NVAR flag=$(KeithleyGetPrivateFlagName())
	if(NVAR_Exists(flag))
		flag=0
		return 0
	endif
	return -1
End

//Constant KUSRCMD_STATUS_OLD				=0x20
Function KeithleyCheckCMDStatusFlag()
#ifdef DEBUG_MEASUREMENTEXECUTOR
	return 1
#else
	NVAR flag=$(KeithleyGetPrivateFlagName())
	if(NVAR_Exists(flag))
		if(flag!=0)
			return 1
		else
			return 0
		endif
	endif
	return -1
#endif
End

Function KeithleyGetLastSMUReading(WAVE w)
	NVAR i0=$(KeithleyGetPrivateFolderName()+"smua_I")
	NVAR v0=$(KeithleyGetPrivateFolderName()+"smua_V")
	NVAR t0=$(KeithleyGetPrivateFolderName()+"smua_t")
	NVAR i1=$(KeithleyGetPrivateFolderName()+"smub_I")
	NVAR v1=$(KeithleyGetPrivateFolderName()+"smub_V")
	NVAR t1=$(KeithleyGetPrivateFolderName()+"smub_t")
	
	if(NVAR_Exists(i0) && NVAR_Exists(v0) && NVAR_Exists(t0) && NVAR_Exists(i1) && NVAR_Exists(v1) && NVAR_Exists(t1) && DimSize(w, 0)>=6)
		w[0]=i0
		w[1]=v0
		w[2]=t0
		w[3]=i1
		w[4]=v1
		w[5]=t1
	endif
End

Function KeithleySMUMeasure(String & cmd, Variable smua_srctype, Variable smua_src, Variable smub_srctype, Variable smub_src, Variable initial_take, Variable record_counter, WAVE kwave, [variable display_panel])
	Variable retVal=-1
	Variable status=str2num(StringByKey("SOURCE_MEASURE_STATUS", cmd))
	if(numtype(status)!=0)
		status=0
	endif
	
	if(ParamIsDefault(display_panel))
		display_panel=1
	endif
	
	if(status==0)
		String smu_cmd=""
		String line=""
		if(initial_take==1)
			smu_cmd="timer.reset() format.data=format.ASCII format.asciiprecision=10 "
		endif
		
		if(display_panel>0)
			sprintf line, "beeper.beep(0.2,1000) display.clear() display.setcursor(1,1) display.settext(\"DataPnt#%d\") ", record_counter
			smu_cmd+=line
		endif
			
		switch(smua_srctype)
		case 1: //V-source
			sprintf line, "smua.source.levelv=%.10e ", smua_src
			break
		case 2: //I-source
			sprintf line, "smua.source.leveli=%.10e ", smua_src
			break
		default:
			line=""
			break
		endswitch
		
		String smua_meas_str=""
		
		if(numtype(smua_src)==0 && strlen(line)>0)
			if(initial_take==1)
				line+="smua.source.output=1 "
			endif
			smu_cmd+=line
			smua_meas_str="i0,v0=smua.measure.iv() t0=timer.measure.t() "
		else
			smua_meas_str="i0=\"NaN\" v0=\"NaN\" t0=\"NaN\" "
		endif
		
		switch(smub_srctype)
		case 1://V-source
			sprintf line, "smub.source.levelv=%.10e ", smub_src
			break
		case 2://I-source
			sprintf line, "smub.source.leveli=%.10e ", smub_src
			break
		default:
			line=""
			break
		endswitch
		
		String smub_meas_str=""
		
		if(numtype(smub_src)==0 && strlen(line)>0)
			if(initial_take==1)
				line+="smub.source.output=1 "
			endif
			smu_cmd+=line
			smub_meas_str="i1,v1=smub.measure.iv() t1=timer.measure.t() "
		else
			smub_meas_str="i1=\"NaN\" v1=\"NaN\" t1=\"NaN\" "
		endif
		
		smu_cmd+=smua_meas_str
		smu_cmd+=smub_meas_str
		
		smu_cmd+="print(\"DATA_UPDATE:1;SMUA_I:\",i0,\";SMUA_V:\",v0,\";SMUA_t:\",t0,\";SMUB_I:\",i1,\";SMUB_V:\",v1,\";SMUB_t:\",t1) "
		if(display_panel>0)
			smu_cmd+="display.setcursor(2,1) display.settext(\"done!\") beeper.beep(0.2, 1500)"
		endif
		
		//print smu_cmd
		SVAR Ecmd=root:S_KeithleyCMD
		NVAR Eresp=root:V_KeithleyCMDReadFlag
		
		if(SVAR_Exists(Ecmd))
			Ecmd=smu_cmd
			Eresp=1
		endif
		status=1
	elseif(status==1)
		if(KeithleyCheckCMDStatusFlag()==1)
			KeithleyGetLastSMUReading(kwave)
			status=2
			retVal=0
		endif
	endif
	cmd=ReplaceStringByKey("SOURCE_MEASURE_STATUS", cmd, num2istr(status))
	return retVal
End


