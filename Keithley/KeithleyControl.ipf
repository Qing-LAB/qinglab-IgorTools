//	Copyright 2013-, Quan Qing, Nanoelectronics for Biophysics Lab, Arizona State University
// Web: http://qinglab.physics.asu.edu
// Email: quan.qing@asu.edu, quan.qing@yahoo.com
//	
//	Redistribution and use in source and binary forms, with or without
//	modification, are permitted provided that the following conditions
//	are met:
//	
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above copyright
//	  notice, this list of conditions and the following disclaimer in the
//	   documentation and/or other materials provided with the distribution.
//	
//	THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//	IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//	OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//	IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//	NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//	THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//	THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

//ChangeLog
//Last Updated 2015/10/20

#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma moduleName=KeithleyControl
#pragma Independent Module=KeithleyControl
#pragma IgorVersion=6.35
#include "VISACommunication"

#if exists("LIH_InitInterface")==3
	#if defined(DEBUGONLY)
		#define LIHDEBUG
	#else
		#undef LIHDEBUG
	#endif
#else
	#define LIHDEBUG
#endif

#if defined(LIHDEBUG)
	StrConstant KeithleyControlMenuStr="KeithleyControl(DEMO)"
#else
	StrConstant KeithleyControlMenuStr="KeithleyControl"
#endif


Menu KeithleyControlMenuStr
	"About", KeithleyPanelAbout()
	"Init Keithley control panel", KeithleyPanelInit()
	"Shutdown Keithley control panel", KeithleyPanelShutdown()
End

StrConstant kcontrol_PackageRoot="root:Packages"
StrConstant kcontrol_PackageFolderName="KeithleyControl"

Constant kcontrol_MAX_LIMITI=1.5
Constant kcontrol_MIN_LIMITI=1e-11
Constant kcontrol_MAX_LIMITV=20
Constant kcontrol_MIN_LIMITV=0.001
StrConstant kcontrol_SOURCE_TYPE="Not Used;V-Source;I-Source;"
StrConstant kcontrol_VOLTAGE_RANGE="Auto;200V;20V;2V;200mV;"
StrConstant kcontrol_VOLTAGE_RANGE_VALUE="0.2;200;20;2;0.2;"
StrConstant kcontrol_CURRENT_RANGE="Auto;1.5A;1A;100mA;10mA;1mA;100uA;10uA;1uA;100nA;10nA;1nA;100pA;"
StrConstant kcontrol_CURRENT_RANGE_VALUE="1e-10;1.5;1;0.1;0.01;0.001;1e-4;1e-5;1e-6;1e-7;1e-8;1e-9;1e-10;"
StrConstant kcontrol_SENSE_TYPE="Two wire;Four wire"
StrConstant kcontrol_AUTOZERO_TYPE="Enabled (auto);Only once;Disabled"
StrConstant kcontrol_SINK_MODE="Disabled;Enabled"
StrConstant kcontrol_SMUConditionStrPrefix="SMUCondition_Chan"
StrConstant kcontrol_SMURTUpdateStrPrefix="SMURTUpdate_Chan"

StrConstant kcontrol_FILTER_TYPE="Disabled;Median;Moving Average;Repeat Average"
StrConstant kcontrol_initscriptNamePrefix="IgorKeithleyInit_"

Strconstant KeithleyControl_licesence="Igor Pro script for using Keithley 2600 Series in Igor Pro.\r\rAll rights reserved."
Strconstant KeithleyControl_contact="The Qing Research Lab at Arizona State University\r\rhttp://qinglab.physics.asu.edu"

Function KeithleyPanelAbout()
	DoWindow /K AboutKeithleyPanel
	NewPanel /K=1 /W=(50,50,530,290) /N=AboutKeithleyPanel
	Variable res
	String platform=UpperStr(igorinfo(2))
	if(strsearch(platform, "WINDOWS", 0)>=0)
		res=96
	else
		res=72
	endif
	
	DrawPICT /W=AboutKeithleyPanel /RABS 20,20,180, 180, KeithleyControl#QingLabBadge
	DrawText /W=AboutKeithleyPanel 25, 200, "QingLab Keithley Control Program"
	DrawText /W=AboutKeithleyPanel 25, 220, "Programmed by Quan Qing"
	NewNotebook /F=1/N=AboutKeithleyPanel/OPTS=15 /W=(220,20,450,210) /HOST=AboutKeithleyPanel
	Notebook # text=KeithleyControl_licesence
	Notebook # text="\r\r"
	Notebook # text=KeithleyControl_contact
End

Function KeithleyPanelInit()
	Variable defaultRM
	String klist
	
	kcontrol_SetupDirectory()
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	
	If(WinType("KeithleyControl")==7)
		print "Keithley control is already initiated."
		return -1
	endif
	klist=visaComm_GetList()
	klist="\""+klist+"RefreshList\""
	
	NewPanel /N=KeithleyControl/W=(0,0,320,500)/K=2
	PopupMenu keithley_id win=KeithleyControl,title="DEV_ID",fSize=12,bodywidth=120,pos={125,15},value=#klist,proc=kcontrol_listproc,mode=1
	Button kcontrol_btn_init win=KeithleyControl,title="Init",fSize=12,pos={185,14},size={50,20},proc=kcontrol_init,userdata(state)="0"
	TitleBox instr_info win=KeithleyControl, title="No instrument initialized",fixedSize=1,size={250,30},pos={10, 45},fsize=12
	
	TabControl tab_smu_setup win=KeithleyControl,tabLabel(0)="SMUA",tabLabel(1)="SMUB",tabLabel(2)="Sweep Control",tabLabel(3)="ITC I/O",fsize=12,fstyle=1
	TabControl tab_smu_setup win=KeithleyControl,labelBack=(60928,60928,60928),pos={10,80},size={300,370},proc=kcontrol_tab_smu_setup
	TabControl tab_smu_setup win=KeithleyControl,value=1,UserData(state)="0"
	
	PopupMenu smu_source_type win=KeithleyControl, title="Source Type",fSize=12,pos={180,105}, bodywidth=130
	PopupMenu smu_source_type win=KeithleyControl, proc=kcontrol_smu_popup
	PopupMenu smu_source_type win=KeithleyControl, value=#("\""+kcontrol_SOURCE_TYPE+"\""), mode=3
	
	SetVariable smu_limitv win=KeithleyControl,title="Voltage Limit (V)",pos={180,130}, bodywidth=130
	SetVariable smu_limitv win=KeithleyControl,format="%.3g",limits={kcontrol_MIN_LIMITV,kcontrol_MAX_LIMITV,0},value=_NUM:20
	SetVariable smu_limitv win=KeithleyControl,proc=kcontrol_smu_setvar
	
	SetVariable smu_limiti win=KeithleyControl,title="Current Limit (A)",pos={180,150}, bodywidth=130
	SetVariable smu_limiti win=KeithleyControl,format="%.3g",limits={kcontrol_MIN_LIMITI,kcontrol_MAX_LIMITI,0},value=_NUM:1.5
	SetVariable smu_limiti win=KeithleyControl,proc=kcontrol_smu_setvar
	
	PopupMenu smu_rangev win=KeithleyControl,pos={180, 170},bodyWidth=130,title="Voltage Range"
	PopupMenu smu_rangev win=KeithleyControl,value=#("\""+kcontrol_VOLTAGE_RANGE+"\""),mode=2
	PopupMenu smu_rangev win=KeithleyControl, proc=kcontrol_smu_popup
	
	PopupMenu smu_rangei win=KeithleyControl,pos={180, 195},bodyWidth=130,title="Current Range"
	PopupMenu smu_rangei win=KeithleyControl,value=#("\""+kcontrol_CURRENT_RANGE+"\""),mode=2
	PopupMenu smu_rangei win=KeithleyControl, proc=kcontrol_smu_popup
	
	PopupMenu smu_sensetype win=KeithleyControl,pos={180, 220},bodyWidth=130,title="Sense type"
	PopupMenu smu_sensetype win=KeithleyControl,value=#("\""+kcontrol_SENSE_TYPE+"\"")
	PopupMenu smu_sensetype win=KeithleyControl, proc=kcontrol_smu_popup
	
	PopupMenu smu_autozero win=KeithleyControl,pos={180, 245},bodyWidth=130,title="Auto Zero"
	PopupMenu smu_autozero win=KeithleyControl,value=#("\""+kcontrol_AUTOZERO_TYPE+"\"")
	PopupMenu smu_autozero win=KeithleyControl, proc=kcontrol_smu_popup
	
	PopupMenu smu_sinkmode win=KeithleyControl,pos={180, 270},bodyWidth=130,title="Sink Mode"
	PopupMenu smu_sinkmode win=KeithleyControl,value=#("\""+kcontrol_SINK_MODE+"\"")
	PopupMenu smu_sinkmode win=KeithleyControl, proc=kcontrol_smu_popup
	
	SetVariable smu_speed win=KeithleyControl,pos={180, 295},bodyWidth=130,title="Speed (NPLC)"
	SetVariable smu_speed win=KeithleyControl,limits={0.001,25,0.5},value=_NUM:1
	SetVariable smu_speed win=KeithleyControl, proc=kcontrol_smu_setvar
	
	SetVariable smu_delay win=KeithleyControl,title="Delay (s)",pos={180,320}, bodywidth=130
	SetVariable smu_delay win=KeithleyControl,format="%.3g",limits={0,100,0},value=_NUM:0
	SetVariable smu_delay win=KeithleyControl,proc=kcontrol_smu_setvar
	
	PopupMenu smu_filter win=KeithleyControl,pos={180, 345},bodyWidth=130,title="Filter Type"
	PopupMenu smu_filter win=KeithleyControl,value=#("\""+kcontrol_FILTER_TYPE+"\"")
	PopupMenu smu_filter win=KeithleyControl, proc=kcontrol_smu_popup
	
	SetVariable smu_filtercount win=KeithleyControl,title="Average count",pos={180,370}, bodywidth=130
	SetVariable smu_filtercount win=KeithleyControl,format="%d",limits={1,100,1},value=_NUM:1
	SetVariable smu_filtercount win=KeithleyControl,proc=kcontrol_smu_setvar
	
	Button smu_reset_default win=KeithleyControl,title="Reset to Default", pos={30, 400}, size={200, 20}
	Button smu_reset_default win=KeithleyControl,proc=kcontrol_resetdefault
	
	Button sweep_funcgen win=KeithleyControl,title="Assign Vector For",pos={20,110},size={130,20}
	Button sweep_funcgen win=KeithleyControl,proc=kcontrol_funcgen
	
	PopupMenu sweep_assign win=KeithleyControl,title="",pos={190,110},bodyWidth=80
	PopupMenu sweep_assign win=KeithleyControl,value="SMUA;SMUB"
	
	TitleBox smu_vectorlist win=KeithleyControl,title="Assigned Vectors:\rSMUA:_none_\rSMUB:_none_"
	TitleBox smu_vectorlist win=KeithleyControl,fixedsize=1,fsize=12,pos={20, 135},size={220, 75}
	TitleBox smu_vectorlist win=KeithleyControl,UserData(assignment)="Assigned Vectors:\rSMUA:_none_\rSMUB:_none_"
	
	Button smu_startmeasurement win=KeithleyControl,title="Start Measurement",pos={20, 220},size={130,20}
	Button smu_startmeasurement win=KeithleyControl,proc=kcontrol_startmeasurement,UserData(measurement)="0"
	
	TitleBox smu_result0 win=KeithleyControl,title="",variable=$(fullPackagePath+":"+kcontrol_SMURTUpdateStrPrefix+"0")
	TitleBox smu_result0 win=KeithleyControl,fixedsize=1,fsize=12,pos={20, 250},size={220, 75}

	TitleBox smu_result1 win=KeithleyControl,title="test",variable=$(fullPackagePath+":"+kcontrol_SMURTUpdateStrPrefix+"1")
	TitleBox smu_result1 win=KeithleyControl,fixedsize=1,fsize=12,pos={20, 350},size={220, 75}
	
	
	CheckBox itc_adc0  win=KeithleyControl,title="ADC0",pos={50,150},proc=itc_setadc
	CheckBox itc_adc1  win=KeithleyControl,title="ADC1",pos={50,170},proc=itc_setadc
	CheckBox itc_adc2  win=KeithleyControl,title="ADC2",pos={50,190},proc=itc_setadc
	CheckBox itc_adc3  win=KeithleyControl,title="ADC3",pos={50,210},proc=itc_setadc
	CheckBox itc_adc4  win=KeithleyControl,title="ADC4",pos={50,230},proc=itc_setadc
	CheckBox itc_adc5  win=KeithleyControl,title="ADC5",pos={50,250},proc=itc_setadc
	CheckBox itc_adc6  win=KeithleyControl,title="ADC6",pos={50,270},proc=itc_setadc
	CheckBox itc_adc7  win=KeithleyControl,title="ADC7",pos={50,290},proc=itc_setadc
	
	SetVariable itc_TTL_pre win=KeithleyControl,format="%04b",limits={0,15,1},value=_NUM:15,title="TTL OUT before experiment",size={200,20},pos={50, 310}
	SetVariable itc_TTL_out win=KeithleyControl,format="%04b",limits={0,15,1},value=_NUM:0,title="TTL OUT during experiment",size={200,20},pos={50, 330}
	SetVariable itc_TTL_post win=KeithleyControl,format="%04b",limits={0,15,1},value=_NUM:15,title="TTL OUT after experiment  ",size={200,20},pos={50, 350}
	
	CheckBox itc_enabled  win=KeithleyControl,title="ITC I/O enabled",pos={20,120},proc=itc_setadc
	
	SetVariable itc_wname title="Save ITC Data to",value=_STR:"",size={200,20}, pos={50, 380}
	
	kcontrol_smu_tab_state(tab=0)
	kcontrol_UpdateSMU(0)	
	kcontrol_UpdateSMU(1)
	kcontrol_UpdateSMUAssignment()
End

Function kcontrol_getVectorName(wname, selMsg, owOpt, suggestName, dlgMsg)
	String & wname
	String selMsg, owOpt, suggestName, dlgMsg

	Variable waveselect=1
	Variable overwrite=1
	String newwname=UniqueName(suggestName, 1, 0)
	String wlist=WaveList("*", ";", "TEXT:0")
	wlist="_new_;"+wlist

	try
		PROMPT waveselect, selMsg, popup wlist
		PROMPT newwname, "Name for the new wave"
		PROMPT overwrite, "Overwrite existing wave?",popup owOpt
		
		DoPrompt dlgMsg, waveselect, overwrite
		AbortOnValue V_flag!=0, -100
		
		if(waveselect==1) //new vector
			DoPrompt "New wave name", newwname
			AbortOnValue V_flag!=0, -100
			
			if(WaveExists($newwname) && ItemsInList(owOpt)>1)
				Variable overwrite2=1
				PROMPT overwrite2, "Wave will be overwritten. Is this OK?", popup "Yes;No, I'll start over again"
				DoPrompt "Wave already exists. Overwrite?", overwrite2
				AbortOnValue (V_flag!=0) || overwrite2==2, -100
				overwrite=overwrite2
			else
				overwrite=1
			endif
		else
			newwname=StringFromList(waveselect-1, wlist)
		endif
	catch
		switch(V_AbortCode)
		default:
			wname=""
			overwrite=0
			break
		endswitch
	endtry
	wname=newwname
	return overwrite
End

Function kcontrol_generateVector(wname, overwrite_flag)
	String wname
	Variable overwrite_flag
	
	if(overwrite_flag==2) //no modification of the wave
		return 0
	endif
	try
		Variable level1=0, level2=1, level3=0, level4=-1, level5=0
		Variable n1=49, n2=49, n3=49, n4=49
		Variable cycles=1
		Variable numOfpts, delta
		PROMPT level1, "start level"
		PROMPT n1, "number of points between level1 and level2"
		PROMPT level2, "second level"
		PROMPT n2, "number of points between level2 and level3"
		PROMPT level3, "third level"
		PROMPT n3,  "number of points between level3 and level4"
		PROMPT level4, "fourth level"
		PROMPT n4,  "number of points between level4 and level5"
		PROMPT level5, "end level"
		PROMPT cycles, "cycle of runs"
		DoPrompt "Linear parameters", level1, n1, level2, n2, level3, n3, level4, n4, level5, cycles
		Make /FREE/N=(cycles*(n1+n2+n3+n4+5))/D tmp=-99
		Variable i, n0
		for(i=0; i<cycles; i+=1)
			n0=i*(n1+n2+n3+n4+5)
			delta=(level2-level1)/(n1+1)
			tmp[n0, n0+n1]=level1+delta*(p-n0)
			n0+=n1+1
			delta=(level3-level2)/(n2+1)
			tmp[n0, n0+n2]=level2+delta*(p-n0)
			n0+=n2+1
			delta=(level4-level3)/(n3+1)
			tmp[n0, n0+n3]=level3+delta*(p-n0)
			n0+=n3+1
			delta=(level5-level4)/(n4+1)
			tmp[n0, n0+n4]=level4+delta*(p-n0)
			n0+=n4+1
			tmp[n0]=level5
		endfor
		
		if(overwrite_flag==3) //append
			Concatenate /NP {tmp}, $wname; AbortOnRTE
		elseif(overwrite_flag==1) //overwrite
			Duplicate /O tmp, $wname; AbortOnRTE
		endif
	catch
		switch(V_AbortCode)
		case -4:
			print "Runtime error = ", GetRTErrMessage()
			Variable err=GetRTError(1)
			break
		default:
			print "User cancelled operation."
			break
		endswitch
		return -1
	endtry
	
	return 0	
End
Function kcontrol_resetdefault(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	try
		switch( ba.eventCode )
			case 2: // mouse up
				ControlInfo /W=KeithleyControl tab_smu_setup
				Variable smu=V_value
				SVAR smu_condition=dfr:$(kcontrol_SMUConditionStrPrefix+num2istr(smu))
				AbortOnValue !SVAR_Exists(smu_condition), -100
				smu_condition=""
				kcontrol_UpdateSMU(smu)
				break
			case -1: // control being killed
				break
		endswitch
	catch
	endtry
	
	return 0
End
	
Function kcontrol_funcgen(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			try
				ControlInfo /W=KeithleyControl sweep_assign
				String smu=S_Value
				String wname=""
				Variable status
				status=kcontrol_getVectorName(wname, "select vector for "+smu, "Yes;No, use as is;Append to existing vector", smu+"_vector", "Generate Vector for Sweeping")
				switch(status)
				case 0:
					AbortOnValue 1, -100
					break
				case 1: //overwrite wave
				case 3:
					AbortOnValue -1==kcontrol_generateVector(wname, status), -100
					break
				default:
					break
				endswitch
				kcontrol_UpdateSMUAssignment(smu=smu, vector=wname)
			catch
				switch(V_AbortCode)
				case -4:
					print "Runtime error in VISA Communication background task = ", GetRTErrMessage()
					Variable err=GetRTError(1)
					break
				default:
					print "User cancelled operation."
					break
				endswitch
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function kcontrol_smu_tab_state([tab])
	variable tab
	variable l1, l2, l3, l4, l5, sel
	
	Variable state=str2num(GetUserData("KeithleyControl", "tab_smu_setup", "state"))
	if(ParamIsDefault(tab))
		ControlInfo /W=KeithleyControl tab_smu_setup
		tab=V_value
	endif
	
	if(state<0) //complete lock down of tab
		l1=2
		sel=tab
	else
		l1=0
		sel=tab
	endif
	
	switch(tab)
	case 0:
	case 1:
		switch(state)
		case 0: //uninitialized
		case 1:
			l2=0; l3=1; l4=1; l5=1
			break
		case 2: //background task is running
			l2=2; l3=1; l4=1; l5=1
			break	
		default:
			break;
		endswitch
		break
	case 2:
		switch(state)
		case 0: //uninitialized
			l2=1; l3=2; l4=2; l5=1
			break
		case 1:
			l2=1; l3=0; l4=0; l5=1
			break
		case 2: //background task is running
			l2=1; l3=2; l4=0; l5=1
			break		
		default:
			break
		endswitch
		break
	case 3:
		switch(state)
		case 0: //uninitialized
			l2=1; l3=1; l4=1; l5=0
			break
		case 1:
			l2=1; l3=1; l4=1; l5=0
			break
		case 2: //background task is running
			l2=1; l3=1; l4=1; l5=2
			break
		default:
			break
		endswitch
		break
	default:
		l1=2; l2=2; l3=1; l4=1; l5=2; sel=0
		break
	endswitch
	
	TabControl tab_smu_setup win=KeithleyControl,disable=l1,value=sel
	PopupMenu smu_source_type win=KeithleyControl,disable=l2
	SetVariable smu_limitv win=KeithleyControl,disable=l2
	SetVariable smu_limiti win=KeithleyControl,disable=l2
	PopupMenu smu_rangev win=KeithleyControl,disable=l2
	PopupMenu smu_rangei win=KeithleyControl,disable=l2
	PopupMenu smu_sensetype win=KeithleyControl,disable=l2
	PopupMenu smu_autozero win=KeithleyControl,disable=l2
	PopupMenu smu_sinkmode win=KeithleyControl,disable=l2
	SetVariable smu_speed win=KeithleyControl,disable=l2
	SetVariable smu_delay win=KeithleyControl,disable=l2
	PopupMenu smu_filter win=KeithleyControl,disable=l2
	SetVariable smu_filtercount win=KeithleyControl,disable=l2
	Button smu_reset_default win=KeithleyControl,disable=l2
	
	Button sweep_funcgen win=KeithleyControl,disable=l3
	PopupMenu sweep_assign win=KeithleyControl,disable=l3
	TitleBox smu_vectorlist win=KeithleyControl,disable=l4
	Button smu_startmeasurement win=KeithleyControl,disable=l4
	TitleBox smu_result0 win=KeithleyControl,disable=l4
	TitleBox smu_result1 win=KeithleyControl,disable=l4
	
	CheckBox itc_adc0  win=KeithleyControl,disable=l5
	CheckBox itc_adc1  win=KeithleyControl,disable=l5
	CheckBox itc_adc2  win=KeithleyControl,disable=l5
	CheckBox itc_adc3  win=KeithleyControl,disable=l5
	CheckBox itc_adc4  win=KeithleyControl,disable=l5
	CheckBox itc_adc5  win=KeithleyControl,disable=l5
	CheckBox itc_adc6  win=KeithleyControl,disable=l5
	CheckBox itc_adc7  win=KeithleyControl,disable=l5

	SetVariable itc_TTL_pre win=KeithleyControl,disable=l5
	SetVariable itc_TTL_out win=KeithleyControl,disable=l5
	SetVariable itc_TTL_post win=KeithleyControl,disable=l5
	CheckBox itc_enabled win=KeithleyControl,disable=l5
	SetVariable itc_wname win=KeithleyControl,disable=l5
End

Function KeithleyPanelShutdown()
	if(WinType("KeithleyControl")==7)
		kcontrol_switch("OFF")
		KillWindow KeithleyControl
	endif
End

Function kcontrol_listproc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	Variable defaultRM
	String klist
	
	switch( pa.eventCode )
		case 2: // mouse up
			if(cmpstr(pa.popStr, "RefreshList")==0)
				klist=visaComm_GetList()
				klist="\""+klist+"RefreshList\""
				PopupMenu keithley_id win=KeithleyControl,value=#klist,mode=1
				ControlUpdate /W=KeithleyControl keithley_id
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function kcontrol_SetupDirectory()
	if(!DataFolderExists(kcontrol_PackageRoot))
		NewDataFolder /O $kcontrol_PackageRoot
	endif
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	
	if(!DataFolderExists(fullPackagePath))
		NewDataFolder /O $fullPackagePath
	endif
	DFREF dfr=$fullPackagePath
	if(DataFolderRefStatus(dfr)!=1)
		abort "cannot create KeithleyControl package data folder!"
	endif
	
	try
		if(exists(fullPackagePath+":defaultRM")==0)
			Variable /G dfr:defaultRM=-1
		endif
		NVAR a=dfr:defaultRM
		AbortOnValue !NVAR_Exists(a), -1
		
		if(exists(fullPackagePath+":sessionID")==0)
			Variable /G dfr:sessionID=-1
		endif
		NVAR a=dfr:sessionID
		AbortOnValue !NVAR_Exists(a), -1
		
		if(exists(fullPackagePath+":"+kcontrol_SMUConditionStrPrefix+"0")==0)
			String /G dfr:$(kcontrol_SMUConditionStrPrefix+"0")=""
		endif
		SVAR b=dfr:$(kcontrol_SMUConditionStrPrefix+"0")
		AbortOnValue !SVAR_Exists(b), -1
		
		if(exists(fullPackagePath+":"+kcontrol_SMUConditionStrPrefix+"1")==0)
			String /G dfr:$(kcontrol_SMUConditionStrPrefix+"1")=""
		endif
		SVAR b=dfr:$(kcontrol_SMUConditionStrPrefix+"1")
		AbortOnValue !SVAR_Exists(b), -1
		
		if(exists(fullPackagePath+":callbackParam")==0)
			String /G dfr:callbackParam=""
		endif
		SVAR b=dfr:callbackParam
		AbortOnValue !SVAR_Exists(b), -1
		
		if(exists(fullPackagePath+":"+kcontrol_SMURTUpdateStrPrefix+"0")==0)
			String /G dfr:$(kcontrol_SMURTUpdateStrPrefix+"0")="_none_"
		endif
		SVAR b=dfr:$(kcontrol_SMURTUpdateStrPrefix+"0")
		AbortOnValue !SVAR_Exists(b), -1

		if(exists(fullPackagePath+":"+kcontrol_SMURTUpdateStrPrefix+"1")==0)
			String /G dfr:$(kcontrol_SMURTUpdateStrPrefix+"1")="_none_"
		endif
		SVAR b=dfr:$(kcontrol_SMURTUpdateStrPrefix+"1")
		AbortOnValue !SVAR_Exists(b), -1

	catch
		abort "error setting up KeithleyControl data folder."
	endtry
End

Function kcontrol_switch(state)
	String state
	
	Variable status, defaultRM=-1, instr=-1
	String statusDesc
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	NVAR dRM=dfr:defaultRM
	NVAR session=dfr:sessionID
	
	try
		if(cmpstr(UpperStr(state), "OFF")==0)
			kcontrol_stopTask()
			if(session!=-1)
				viClose(session)
			endif
			if(dRM!=-1)
				viClose(dRM)
			endif
			session=-1
			dRM=-1
			kcontrol_stopTask()
			Button kcontrol_btn_init win=KeithleyControl,title="init",userdata(state)="0"
			PopupMenu keithley_id win=KeithleyControl,disable=0
			TitleBox instr_info win=KeithleyControl, title="No instrument initialized"
		elseif(cmpstr(UpperStr(state), "ON")==0)
			ControlInfo /W=KeithleyControl keithley_id
			status=visaComm_Init(S_Value, sessionRM=defaultRM, sessionINSTR=instr)			
			AbortOnValue status!=VI_SUCCESS, status
			dRM=defaultRM
			session=instr
			viClear(session)
			visaComm_SyncedWriteAndRead(session, 0, cmd="*IDN?", response=statusDesc, clearOutputQueue=1)
			if(GrepString(UpperStr(statusDesc), "KEITHLEY INSTRUMENTS.*MODEL 26[0-9]{2}[AB]?.*")==1)
				if(strlen(statusDesc)>38)
					statusDesc=statusDesc[0,37]+"..."
				endif
				TitleBox instr_info win=KeithleyControl, title=(statusDesc)
				Button kcontrol_btn_init win=KeithleyControl,title="close",userdata(state)="1"
				PopupMenu keithley_id win=KeithleyControl,disable=2
			else
				AbortOnValue 1, -100
			endif
		endif
	catch
		switch(V_AbortCode)
		case -4:
			print "Runtime error in VISA Communication background task = ", GetRTErrMessage()
			Variable err=GetRTError(1)
			break
		case -100:
			print "The instrument is not recognized as Keithley 2600 series."
			break
		default:
			print "Possible VISA communication error."
			viStatusDesc(dRM, status, statusDesc)
			printf "VISA error description for status code 0x%x : %s\r", V_AbortCode, statusDesc
		endswitch
		if(instr!=-1)
			viClose(instr)
			session=-1
		endif
		if(defaultRM!=-1)
			viClose(dRM)
			dRM=-1
		endif
	endtry
	return session
End

Function kcontrol_init(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			if(str2num(GetUserData("KeithleyControl", "kcontrol_btn_init", "state"))==0)
				if(kcontrol_switch("ON")!=-1)
					TabControl tab_smu_setup win=KeithleyControl,UserData(state)="1"
				else
					TabControl tab_smu_setup win=KeithleyControl,UserData(state)="0"
				endif
				kcontrol_smu_tab_state()
			else
				kcontrol_switch("OFF")
				TabControl tab_smu_setup win=KeithleyControl,UserData(state)="0"
				kcontrol_smu_tab_state()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function kcontrol_UpdateSMU(smu)
	Variable smu
	
	if(smu<0 || smu>1)
		return 0
	endif
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	try
		SVAR smu_condition=dfr:$(kcontrol_SMUConditionStrPrefix+num2str(smu))
		AbortOnValue !SVAR_Exists(smu_condition), -100
		
		String newcondition=smu_condition		
		kcontrol_UpdateSMULimit(smu, newcondition, 0)
		kcontrol_UpdateSMURange(smu, newcondition, "smu_rangev", "RANGEV", kcontrol_VOLTAGE_RANGE, 0)
		kcontrol_UpdateSMURange(smu, newcondition, "smu_rangei", "RANGEI", kcontrol_CURRENT_RANGE, 0)
		kcontrol_UpdateSMUConfig(smu, newcondition, 0)
		kcontrol_UpdateSMUdelay(smu, newcondition, 0)
		kcontrol_UpdateSMUAvgCount(smu, newcondition, 0)
		smu_condition=newcondition
	catch
		switch(V_AbortCode)
		case -100:
			print "error: channel does not exist."
			break
		default:
			break
		endswitch
	endtry
	return 0
End

Function kcontrol_UpdateSMUAssignment([smu, vector])
	String smu, vector
	String vectorA="", vectorB=""
	if(!ParamIsDefault(smu) && !ParamIsDefault(vector))
		strswitch(smu)
		case "SMUA":
			if(strlen(vector)>0)
				vectorA=vector
			else
				vectorA="_none_"
			endif
			break
		case "SMUB":
			if(strlen(vector)>0)
				vectorB=vector
			else
				vectorB="_none_"
			endif
			break
		default:
			break
		endswitch
	endif
	
	String assignment=GetUserData("KeithleyControl", "smu_vectorlist", "assignment")
	if(strlen(vectorA)==0)
		vectorA=StringFromList(0, StringByKey("SMUA", assignment, ":", "\r"), ",")
	endif
	if(strlen(vectorB)==0)
		vectorB=StringFromList(0, StringByKey("SMUB", assignment, ":", "\r"), ",")
	endif
	
	String smuA_src="Not Used", smuB_src="Not Used"
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	try
		SVAR smu_condition1=dfr:$(kcontrol_SMUConditionStrPrefix+"0")
		AbortOnValue !SVAR_Exists(smu_condition1), -100
		smuA_src="As "+StringByKey("SOURCE_TYPE_S", smu_condition1)
		
		SVAR smu_condition2=dfr:$(kcontrol_SMUConditionStrPrefix+"1")		
		AbortOnValue !SVAR_Exists(smu_condition2), -100		
		smuB_src="As "+StringByKey("SOURCE_TYPE_S", smu_condition2)
	catch
	endtry
	
	assignment=ReplaceStringByKey("SMUA", assignment, vectorA+", "+smuA_src, ":", "\r")
	assignment=ReplaceStringByKey("SMUB", assignment, vectorB+", "+smuB_src, ":", "\r")
	
	TitleBox smu_vectorlist win=KeithleyControl,title=assignment,UserData(assignment)=assignment
	return 0
End

Function kcontrol_tab_smu_setup(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			kcontrol_smu_tab_state(tab=tab)
			switch(tab)
			case 0:
			case 1:
				kcontrol_UpdateSMU(tab)
				break
			case 2:
				kcontrol_UpdateSMUAssignment()
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

Function kcontrol_smu_popup(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	ControlInfo /W=KeithleyControl tab_smu_setup
	Variable smu=V_Value
	
	if(smu<0 || smu>1) //not concerning SMU setup
		return 0
	endif
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	
	try
		SVAR smu_condition=dfr:$(kcontrol_SMUConditionStrPrefix+num2str(smu))
		AbortOnValue !SVAR_Exists(smu_condition), -100
		
		String newcondition=smu_condition		
		switch( pa.eventCode )
			case 2: // mouse up								
				strswitch(pa.ctrlName)
				case "smu_rangev":
					if(pa.popNum==1)
						kcontrol_setAutoLowRange("smu_rangev", "Lowest range for voltage auto range", kcontrol_VOLTAGE_RANGE, 2)
					endif
					kcontrol_UpdateSMURange(smu, newcondition, "smu_rangev", "RANGEV", kcontrol_VOLTAGE_RANGE, 1)
					break
				case "smu_rangei":
					if(pa.popNum==1)
						kcontrol_setAutoLowRange("smu_rangei", "Lowest range for current auto range", kcontrol_CURRENT_RANGE, 2)
					endif
					kcontrol_UpdateSMURange(smu, newcondition, "smu_rangei", "RANGEI", kcontrol_CURRENT_RANGE, 1)
					break
				case "smu_source_type":
				case "smu_sensetype":
				case "smu_autozero":
				case "smu_sinkmode":
				case "smu_filter":
					kcontrol_UpdateSMUConfig(smu, newcondition, 1)
					break
				default:
					break
				endswitch
				break
			case -1: // control being killed
				break
		endswitch
		smu_condition=newcondition
	catch
		switch(V_AbortCode)
		case -100:
			print "error: channel does not exist."
			break
		default:
			break
		endswitch
	endtry
	return 0
End

Function kcontrol_smu_setvar(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	ControlInfo /W=KeithleyControl tab_smu_setup
	Variable smu=V_Value
	
	if(smu<0 || smu>1) //not concerning SMU setup
		return 0
	endif
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	
	try
		SVAR smu_condition=dfr:$(kcontrol_SMUConditionStrPrefix+num2str(smu))
		AbortOnValue !SVAR_Exists(smu_condition), -100
		
		String newcondition=smu_condition		
		switch( sva.eventCode )
			case 1: // mouse up
			case 2: // Enter key
				strswitch(sva.ctrlName)
				case "smu_limitv":
				case "smu_limiti":
					kcontrol_UpdateSMULimit(smu, newcondition, 1)
					break
				case "smu_delay":
					kcontrol_UpdateSMUDelay(smu, newcondition, 1)
					break
				case "smu_filtercount":
					kcontrol_UpdateSMUAvgCount(smu, newcondition, 1)
					break
				case "smu_speed":
					kcontrol_UpdateSMUConfig(smu, newcondition, 1)
					if(sva.dval<=0.02)
						SetVariable smu_speed win=KeithleyControl,limits={0.001,25,0.005}
					elseif (sva.dval<=0.2)
						SetVariable smu_speed win=KeithleyControl,limits={0.001,25,0.01}
					elseif(sva.dval<=2)
						SetVariable smu_speed win=KeithleyControl,limits={0.001,25, 0.1}
					else
						SetVariable smu_speed win=KeithleyControl,limits={0.001,25,0.5}
					endif
					break
				default:
					break
				endswitch
				break
			case 3: // Live update
				break
			case -1: // control being killed
				break
		endswitch
		smu_condition=newcondition
	catch
		switch(V_AbortCode)
		case -100:
			print "error: channel does not exist."
			break
		default:
			break
		endswitch
	endtry
	return 0
End

static Function kcontrol_updatepopupmenu(pmenuName, condition, list, key, default_value, direction)
	String pmenuName
	String & condition
	String list, key
	Variable default_value
	Variable direction
	
	String str=""
	Variable val=0
	String pmenuitems=""

	if(direction) //update the condition string with the control window values, when direction is non-zero
		ControlInfo /W=KeithleyControl $pmenuName
		str=S_Value
		val=WhichListItem(str, list)
	else // update the control window using the condition string, when direction is set to zero
		str=StringByKey(key+"S", condition)
		val=WhichListItem(str, list)
		
		if(val<0)
			val=default_value
			str=StringFromList(0, list)
		endif
	endif
	PopupMenu $pmenuName win=KeithleyControl,mode=1+val
	condition=ReplaceStringByKey(key+"S", condition, str)
	condition=ReplaceStringByKey(key+"V", condition, num2str(val))
End

static Function kcontrol_updatesetvar(setvarName, condition, key, defaultVal, direction)
	String setvarName
	String & condition
	String key
	Variable defaultVal
	Variable direction
	
	Variable val
	String str
	if(direction) //update the condition string using the control window when direction is non-zero
		ControlInfo /W=KeithleyControl $setvarName
		val=V_Value
	else //update the control window using the condition string when direction is set to zero
		str=StringByKey(key, condition)
		if(strlen(str)>0)
			val=str2num(str)
		else
			val=defaultVal
		endif
	endif
	SetVariable $setvarName win=KeithleyControl, value=_NUM:(val)
	condition=ReplaceStringByKey(key, condition, num2str(val))
End

Function kcontrol_UpdateSMULimit(smu, condition, update_direction)
	Variable smu
	String & condition
	Variable update_direction
	
	kcontrol_updatesetvar("smu_limitv", condition, "LIMITV", kcontrol_MAX_LIMITV, update_direction)
	kcontrol_updatesetvar("smu_limiti", condition, "LIMITI", kcontrol_MAX_LIMITI, update_direction)
End

Function kcontrol_setAutoLowRange(pmenu, message, list, default_value)
	String pmenu, message, list
	Variable default_value

	Variable auto_lowrange=1
	String auto_lowrangestr=""
	PROMPT auto_lowrange, message, popup RemoveListItem(0, list)
	
	ControlInfo /W=KeithleyControl $pmenu
	
	if(V_Value==1) //the user want auto range
		DoPrompt "Set lowest range for auto range?", auto_lowrange
		if(V_flag==0)
			auto_lowrangestr=StringFromList(auto_lowrange,list)
		endif
	endif
	PopupMenu $pmenu win=KeithleyControl,UserData(auto_lowrange)=auto_lowrangestr
End

Function kcontrol_UpdateSMURange(smu, condition, pmenu, key, list, update_direction)
	Variable smu
	String & condition
	String pmenu, key, list
	Variable update_direction
	
	String newlist=list, range="", low_range=""
	Variable selection=-1
	if(update_direction) //use control window data to update condition string
		ControlInfo /W=KeithleyControl $pmenu
		if(V_value==1) //auto is selected
			low_range=GetUserData("KeithleyControl", pmenu, "auto_lowrange")
			range="AUTO"
			if(strlen(low_range)>0)
				newlist=StringFromList(0, list)+"/"+low_range+";"+RemoveListItem(0, list)
			endif
			selection=1
		else
			low_range=""
			selection=WhichListItem(S_Value, list)
			if(selection<0)
				selection=2
				range=StringFromList(1, list)
			else
				range=S_Value
				selection+=1
			endif
		endif
	else //use condition string to update control wnidow
		range=StringByKey(key, condition)
		low_range=StringByKey(key+"_AUTOLOWRANGE", condition)
		
		if(cmpstr(UpperStr(range), "AUTO")!=0) //not in automode
			selection=WhichListItem(range, list)
			if(selection<0)
				selection=1
				range=StringFromList(0, list)
			else
				selection+=1
			endif
			low_range=""
		else
			if(strlen(low_range)>0)
				newlist=StringFromList(0, list)+"/"+low_range+";"+RemoveListItem(0, list)
			endif
			selection=1
		endif
	endif
	newlist="\""+newlist+"\""
	PopupMenu $pmenu win=KeithleyControl, value=#newlist, mode=selection, UserData(choice_record)=num2istr(selection), UserData(auto_lowrange)=low_range
	condition=ReplaceStringByKey(key, condition, range)
	condition=ReplaceStringByKey(key+"_AUTOLOWRANGE", condition, low_range)
End

Function kcontrol_UpdateSMUSpeed(smu, condition, update_direction)
	Variable smu
	String & condition
	Variable update_direction
		
	if(!update_direction)
		Variable dvalue
		String svalue
		dvalue=str2num(StringByKey("SPEED", condition))
		if(dvalue>=0.001 && dvalue<=25)
			sprintf svalue, "%.3f", dvalue
		else
			svalue="1.000"
		endif
		condition=ReplaceStringByKey("SPEED", condition, svalue)
	endif
	kcontrol_updatesetvar("smu_speed", condition, "SPEED", 1, update_direction)
End

Function kcontrol_UpdateSMUConfig(smu, condition, update_direction)
	Variable smu
	String & condition
	Variable update_direction

	kcontrol_updatepopupmenu("smu_source_type", condition, kcontrol_SOURCE_TYPE, "SOURCE_TYPE_", 0, update_direction)
	kcontrol_updatepopupmenu("smu_sensetype", condition, kcontrol_SENSE_TYPE, "SENSE_TYPE_", 0, update_direction)
	kcontrol_updatepopupmenu("smu_autozero", condition, kcontrol_AUTOZERO_TYPE, "AUTOZERO_TYPE_", 0, update_direction)
	kcontrol_updatepopupmenu("smu_sinkmode", condition, kcontrol_SINK_MODE, "SINK_MODE_", 0, update_direction)
	kcontrol_updatepopupmenu("smu_filter", condition, kcontrol_FILTER_TYPE, "FILTER_TYPE_", 0, update_direction)
	
	kcontrol_UpdateSMUSpeed(smu, condition, update_direction)
		
	ControlInfo /W=KeithleyControl smu_filter
	if(V_Value==1) //filter set to disabled
		SetVariable smu_filtercount win=KeithleyControl,disable=2
	else
		SetVariable smu_filtercount win=KeithleyControl,disable=0
	endif

End

Function kcontrol_UpdateSMUdelay(smu, condition, update_direction)
	Variable smu
	String & condition
	Variable update_direction
	
	kcontrol_updatesetvar("smu_delay", condition, "DELAY", 0, update_direction)
End

Function kcontrol_UpdateSMUAvgCount(smu, condition, update_direction)
	Variable smu
	String & condition
	Variable update_direction
	
	if(!update_direction)
		Variable dvalue
		String svalue
		dvalue=str2num(StringByKey("FILTER_AVGCOUNT", condition))
		if(dvalue>=1 && dvalue<=100)
			svalue=num2istr(dvalue)
		else
			svalue="1"
		endif
		condition=ReplaceStringByKey("FILTER_AVGCOUNT", condition, svalue)
	endif
	kcontrol_updatesetvar("smu_filtercount", condition, "FILTER_AVGCOUNT", 1, update_direction)
End

Function /S kcontrol_smuname(smu)
	Variable smu
	
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

Function kcontrol_levelBySelection(key, list, valuelist)
	String key, list, valuelist
	Variable idx, dvalue
	
	idx=WhichListItem(key, list)
	if(strlen(key)==0 || idx<0)
		idx=0
	endif
	dvalue=str2num(StringFromList(idx, valuelist))
	return dvalue
End

Function kcontrol_generateInitScript(smu, script)
	Variable smu
	String & script
	
	String smuName=kcontrol_smuname(smu)
	if(strlen(smuName)==0)
		return -1
	endif
	
	script=smuName+".reset()\r"
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath	
	try
		String svalue
		Variable dvalue, source_mode=-1
		String smuMode=""
		SVAR smu_condition=dfr:$(kcontrol_SMUConditionStrPrefix+num2str(smu))
		AbortOnValue !SVAR_Exists(smu_condition), -100
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
		
		dvalue=str2num(StringByKey("LIMITV", smu_condition))
		if(dvalue>0) //if no limit is set, the instrument uses the limit saved in previous runs
			sprintf svalue, "%.3e", dvalue
			script+=smuName+".source.limitv="+svalue+"\r"
		endif
		
		dvalue=str2num(StringByKey("LIMITI", smu_condition))
		if(dvalue>0) //if no limit is set, the instrument uses the limit saved in previous runs
			sprintf svalue, "%.3e", dvalue
			script+=smuName+".source.limiti="+svalue+"\r"
		endif
		
		//setting range v, depending on v-source or i-source, the key word should be source or measure
		switch(source_mode)
		case 0:
			smuMode=".source"
			break
		case 1:
			smuMode=".measure"
			break
		default:
			AbortOnValue 1, -200
		endswitch
		svalue=StringByKey("RANGEV", smu_condition)
		if(cmpstr(svalue, "AUTO")==0)
			script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_ON\r"
			svalue=StringByKey("RANGEV_AUTOLOWRANGE", smu_condition)
			dvalue=kcontrol_levelBySelection(svalue, kcontrol_VOLTAGE_RANGE, kcontrol_VOLTAGE_RANGE_VALUE)		
			sprintf svalue, "%.3e", dvalue
			script+=smuName+smuMode+".lowrangev="+svalue+"\r"
		else
			script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_OFF\r"
			dvalue=kcontrol_levelBySelection(svalue, kcontrol_VOLTAGE_RANGE, kcontrol_VOLTAGE_RANGE_VALUE)		
			sprintf svalue, "%.3e", dvalue
			script+=smuName+smuMode+".rangev="+svalue+"\r"
		endif

		//setting range i, depending on v-source or i-source, the key word should be measure or source
		switch(source_mode)
		case 0:
			smuMode=".measure"
			break
		case 1:
			smuMode=".source"
			break
		default:
			AbortOnValue 1, -200
		endswitch
		svalue=StringByKey("RANGEI", smu_condition)
		if(cmpstr(svalue, "AUTO")==0)
			script+=smuName+smuMode+".autorangei="+smuName+".AUTORANGE_ON\r"
			svalue=StringByKey("RANGEI_AUTOLOWRANGE", smu_condition)
			dvalue=kcontrol_levelBySelection(svalue, kcontrol_CURRENT_RANGE, kcontrol_CURRENT_RANGE_VALUE)		
			sprintf svalue, "%.3e", dvalue
			script+=smuName+smuMode+".lowrangei="+svalue+"\r"
		else
			script+=smuName+smuMode+".autorangev="+smuName+".AUTORANGE_OFF\r"
			dvalue=kcontrol_levelBySelection(svalue, kcontrol_CURRENT_RANGE, kcontrol_CURRENT_RANGE_VALUE)		
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
		default:
			break
		endswitch
		//print "the init script will only reset "+smuName
		script=smuName+".reset()\r"
	endtry
	Variable frequency=1000+500*smu
	script+="beeper.beep(0.2, "+num2istr(frequency)+")\r"
	script="loadscript "+kcontrol_initscriptNamePrefix+smuName+"\r"+script+"endscript\r"
	return 0
End

Function itc_check(stage)
	Variable stage
	
	String ErrMsg=""
	
	if(stage==0)
		DoAlert /T="Disconnect sample" 0, "About to initializing ITC. Please make sure to disconnect your sample from the switching box first."
		ControlInfo /W=KeithleyControl itc_enabled
		if(V_Value==1) //itc enabled
#if defined(LIHDEBUG)
			DoAlert  /T="ITC Init Errir" 0, "ITC Initialization error: "+ErrMsg
			Abort("Measurement aborted.")
#else
			if(LIH_InitInterface(ErrMsg, 11) ==0)
				print "ITC initialized successfully."
				ControlInfo /W=KeithleyControl itc_TTL_pre
				printf "Setting ITC TTL output as 0b%04b\n\r", V_Value
				LIH_SetDigital(V_Value)
				DoAlert /T="Reconnect sample" 0, "Prepare for measurement. Please connect your sample to the switching box."
			else
				DoAlert  /T="ITC Init Errir" 0, "ITC Initialization error: "+ErrMsg
				Abort("Measurement aborted.")
			endif
#endif
		endif
	endif
	
	if(stage==1)
		ControlInfo /W=KeithleyControl itc_enabled
		if(V_Value==1) //itc enabled
			ControlInfo /W=KeithleyControl itc_TTL_out
			printf "Setting ITC TTL output as 0b%04b\n\r", V_Value
#if !defined(LIHDEBUG)
			LIH_SetDigital(V_Value)
#endif
		endif
	endif

	if(stage==2)
		ControlInfo /W=KeithleyControl itc_enabled
		if(V_Value==1) //itc enabled
			ControlInfo /W=KeithleyControl itc_TTL_post
			printf "Setting ITC TTL output as 0b%04b\n\r", V_Value
#if !defined(LIHDEBUG)
			LIH_SetDigital(V_Value)
#endif
			ControlInfo /W=KeithleyControl itc_wname
			if(strlen(S_Value)>0 && WaveExists($"root:RTITCData"))
				print "copying ITC data to wave root:"+PossiblyQuoteName(S_Value)
				Duplicate /O $"root:RTITCData", $("root:"+PossiblyQuoteName(S_Value)) ; AbortOnRTE
			endif
		endif
	endif
End

Function kcontrol_startmeasurement(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	NVAR instr=dfr:sessionID

	String initScript
	try
		switch( ba.eventCode )
			case 2: // mouse up
				Variable s=str2num(GetUserData("KeithleyControl", "smu_startmeasurement", "measurement"))
				if(s==0)
					itc_check(0)
					
					String timestamp=time()
					if(WinType("kcontrol_initscripts")==0)
						NewNotebook /F=0/N=kcontrol_initscripts as "Keithley Init script record"
					endif
					Notebook kcontrol_initscripts selection={startOfFile, endOfFile}, text="Init Script Record TimeStamp ["+timestamp+"]\r\r"
					
					visaComm_WriteSequence(instr, "*CLS") //clear output queue
					
					kcontrol_generateInitScript(0, initScript)
					visaComm_WriteSequence(instr, initScript) //define init function for smua
					Notebook kcontrol_initscripts text=initScript+"\r\r"
					
					kcontrol_generateInitScript(1, initScript)
					visaComm_WriteSequence(instr, initScript) //define init function for smub
					Notebook kcontrol_initscripts text=initScript+"\r\r"
					
					initScript="loadscript "+kcontrol_initscriptNamePrefix+"all()\r"
					initScript+="reset()\r"
					initScript+=kcontrol_initscriptNamePrefix+"smua()\r"
					initScript+=kcontrol_initscriptNamePrefix+"smub()\r"
					initScript+="display.clear()\r"
					initScript+="display.setcursor(1,1)\r"
					initScript+="display.settext(\"SMUs init timestamp\")\r"
					initScript+="display.setcursor(2,1)\r"
					initScript+="display.settext(\""+timestamp+"\")\r"
					initScript+="status.reset()\rstatus.request_enable=status.MAV\r"
					initScript+="endscript\r"
					visaComm_WriteSequence(instr, initScript)
					Notebook kcontrol_initscripts text=initScript+"\r\r"
					
					initScript="function delay_ms(deltat) t0=timer.measure.t() while(timer.measure.t()-t0<deltat/1000) do end end\r"
					visaComm_WriteSequence(instr, initScript)
					Notebook kcontrol_initscripts text=initScript+"\r\r"
					
					initScript="function reset_all() smua.reset() smub.reset() reset() end"
					visaComm_WriteSequence(instr, initScript)
					Notebook kcontrol_initscripts text=initScript+"\r\r"
					
					Notebook kcontrol_initscripts writeProtect=1
					
					kcontrol_startTask()
				else
					kcontrol_stopTask()
				endif
				
				break
			case -1: // control being killed
				break
		endswitch
	catch
	endtry
	
	return 0
End

Function /S kcontrol_prepareParam()
	String param
	
	Variable smu
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	Variable datadim=0
	Variable smunum=0
	String smuName=""
	String rwaveName
	param=""
	String vectorlist=GetUserData("KeithleyControl", "smu_vectorlist", "assignment")
	try
		for(smu=0; smu<2; smu+=1)
			smuName=kcontrol_smuname(smu)
			rwaveName=""
			SVAR condition=dfr:$(kcontrol_SMUConditionStrPrefix+num2istr(smu))
			AbortOnValue !SVAR_Exists(condition), -100
			String rtUpdateVarName=fullPackagePath+":"+kcontrol_SMURTUpdateStrPrefix+num2istr(smu)
			SVAR rtupdate=$rtUpdateVarName
			AbortOnValue !SVAR_Exists(rtupdate), -150

			rtupdate="_none_"
			
			Variable source_flag=str2num(StringByKey("SOURCE_TYPE_V", condition))
			if(source_flag>0)				
				String vectorName=StringFromList(0, StringByKey(UpperStr(smuName), vectorlist, ":", "\r"), ",")
				WAVE w=$vectorName
				if(WaveExists(w)!=0)
					vectorName=GetWavesDataFolder(w, 2)
				else
					AbortOnValue 1, -200
				endif

				AbortOnValue 0==kcontrol_getVectorName(rwaveName, "Wave for storing result from "+smuName, "Yes", UpperStr(smuName)+"_result", "Specify wave for storing the measurement result"), -300
				
				smunum+=1
				datadim+=3
				String smulist=StringByKey("smu_list", param, "=", "\r")
				smulist=AddListItem(smuName, smulist, ",", inf)
				param=ReplaceStringByKey("smu_list", param, smulist, "=", "\r")
				param=ReplaceStringByKey(smuName+"_vector", param, vectorName, "=", "\r")
				param=ReplaceStringByKey(smuName+"_src", param, num2istr(source_flag), "=", "\r")
				WAVE w=$rwaveName
				if(!WaveExists(w))
					Make /O/D/N=0 $rwaveName
					WAVE w=$rwaveName
				endif
				rwaveName=GetWavesDataFolder(w, 2)
				Note /K w, condition
				param=ReplaceStringByKey(smuName+"_result", param, rwaveName, "=", "\r")
				param=ReplaceStringByKey(smuName+"_delay", param, StringByKey("DELAY", condition), "=", "\r")
				param=ReplaceStringByKey(smuName+"_update", param, rtUpdateVarName, "=", "\r")
			else
				continue
			endif
		endfor
		AbortOnValue datadim==0 || smunum==0, -300
		param=ReplaceStringByKey("DataDimSize", param, num2istr(datadim), "=", "\r")
		param=ReplaceStringByKey("NumOfSMU", param, num2istr(smunum), "=", "\r")
		Variable run_cycles=1
		Prompt run_cycles, "How many cycles do you want to record?"
		DoPrompt "Record cycle", run_cycles
		AbortOnValue V_flag==1 || run_cycles<1, -400
		param=ReplaceStringByKey("Cycles", param, num2istr(round(run_cycles)), "=", "\r")
	catch
		switch(V_AbortCode)
		case -100:
			print "condition for SMU "+smuName+" not defined."
			break
		case -150:
			print "real time update variable for "+smuName+" not defined."
			break
		case -200:
			print "cannot identify the sourcing vector for SMU "+smuName+"."
			break
		case -300:
			print "no SMU is set for sourcing."
			break
		case -400:
			print "Zero cycle is set for measurement. No task will be running."
			break
		default:
			print "unknown error when preparing parameters for measurement task."
			break
		endswitch
		
		param=""
	endtry
	
	return param
End

Function kcontrol_startTask()
	String fullPackagePath=kcontrol_PackageRoot+":"+kcontrol_PackageFolderName
	DFREF dfr=$fullPackagePath
	NVAR instr=dfr:sessionID
	String param
	
	param=kcontrol_prepareParam()
	if(strlen(param)==0)
		return -1
	endif
	
	visaComm_WriteSequence(instr, kcontrol_initscriptNamePrefix+"all()")
	String cmdstr="print('QQDATA_FIXEDKDBL0\\r')"
	//repeat writing before reading, readtype=2 (prefixed), do clear queue before first write/read
	Sleep /S 1
	itc_check(1)
	Sleep /S 1
	
	visaComm_SendAsyncRequest(instr, cmdstr, 1, 2, 0, "", "kcontrol_callbackFunc", param, cycle_ticks=2)
	TabControl tab_smu_setup win=KeithleyControl,UserData(state)="2"
	Button smu_startmeasurement win=KeithleyControl,UserData(measurement)="1",title="Stop Measurement",fColor=(65535,0,0)
	kcontrol_smu_tab_state()
End

Function kcontrol_stopTask()
	Variable s1=str2num(GetUserData("KeithleyControl", "smu_startmeasurement", "measurement"))
	Variable s2=str2num(GetUserData("KeithleyControl", "tab_smu_setup", "state"))
	if(s1==1 || s2==2)
		Button smu_startmeasurement win=KeithleyControl,UserData(measurement)="0",title="Start Measurement",fColor=(0,0,0)
		TabControl tab_smu_setup win=KeithleyControl,UserData(state)="1"
		kcontrol_smu_tab_state()
	endif
End

Function kcontrol_resetInstr(instr)
	Variable instr
	
	visaComm_WriteSequence(instr, "reset_all()")
End

Function itc_preparedata(r)
	Variable r
	WAVE itc_chn=$"root:RTITCchn"
	
	if(WaveExists(itc_chn))
		Variable chnnum=DimSize(itc_chn, 0)
		if(chnnum>0)
			Make /O/D/N=(chnnum, r) root:RTITCData=NaN; AbortOnRTE
		endif
	endif
End

Function itc_getdata(count, d)
	variable count, d
	
	WAVE itc_chn=$"root:RTITCchn"
	
	if(WaveExists(itc_chn))
		Variable chnnum=DimSize(itc_chn, 0)
		if(chnnum>0)
			WAVE itcdata=$"root:RTITCData"
			Variable len=DimSize(itcdata, 1)
			
			if(count>=len)
				Make /O/D/N=(chnnum, len+d)/FREE tmp=NaN; AbortOnRTE
				multithread tmp[][0,len-1]=itcdata[x][y]
				Duplicate /O tmp, itcdata; AbortOnRTE
			endif
			Variable i
#if !defined(LIHDEBUG)
			for(i=0; i<chnnum; i+=1)
				itcdata[i][count-1]=LIH_ReadAdc(itc_chn[i]); AbortOnRTE
			endfor
#endif
		endif
	endif
End

Function kcontrol_callbackFunc(session, strData, strParam, count, strCmd)
	Variable session
	String strData
	String strParam
	Variable & count
	String & strCmd

	Variable dataDimSize=str2num(StringByKey("DataDimSize", strParam, "=", "\r"))
	SOCKITstringToWave /DEST=dbldata /FREE 4, strData
	
	Variable exec_status=str2num(GetUserData("KeithleyControl", "smu_startmeasurement", "measurement"))
	if(exec_status==0)
		itc_check(2)
		kcontrol_resetInstr(session)
		kcontrol_stopTask()
		return -99
	endif
	
	if(count>0 && dataDimSize!=DimSize(dbldata, 0))
		print "DimSize of returned data does not match with SMU setup."
		print count
		print dataDimSize
		print DimSize(dbldata, 0)
		return -1
	endif
	
	Variable NumOfSmu=str2num(StringByKey("NumOfSMU", strParam, "=", "\r"))
	Variable TotalCycles=str2num(StringByKey("Cycles", strParam, "=", "\r"))
	
	if(TotalCycles<=0)
		print "record cycle is set to zero."
		return -1
	endif
	
	Variable i
	
	if(NumOfSmu<1)
		print "No smu is set for sourcing."
		return -1
	endif
	
	Make /FREE/D/N=(NumOfSmu) level, delay
	Make /FREE/T/N=(NumOfSmu) smu_list, srctype_list, vector_list, resultwave_list
	Make /FREE/T/N=(dataDimSize) measurevar_list, timevar_list
	
	Variable dim_vector, dim_result
	String wnote
	String smu
	WAVE vector, result
	String resultName
	Variable srcType
	SVAR update
	try
				
		for(i=0; i<NumOfSmu; i+=1)
			smu=StringFromList(i, StringByKey("smu_list", strParam, "=", "\r"), ",")
			smu_list[i]=smu
			vector_list[i]=StringByKey(smu+"_vector", strParam, "=", "\r")
			WAVE vector=$(vector_list[i])
			resultwave_list[i]=StringByKey(smu+"_result", strParam, "=", "\r")
			WAVE result=$(resultwave_list[i])
			srcType=str2num(StringByKey(smu+"_src", strParam, "=", "\r"))
			
			if(srcType==1)
				srctype_list[i]="levelv"
			elseif(srcType==2)
				srctype_list[i]="leveli"
			else
				AbortOnValue 1, -100
			endif
			
			delay[i]=str2num(StringByKey(smu+"_delay", strParam, "=", "\r"))*1000
			measurevar_list[i]="i"+num2istr(i)+","+"v"+num2istr(i)
			timevar_list[i]="t"+num2istr(i)
			
			dim_vector=DimSize(vector, 0)
			dim_result=DimSize(result, 1)
			
			if(count==0)
				itc_preparedata(dim_vector)
			else
				itc_getdata(count, dim_vector)
			endif
		
			if(count>0)
				result[][count-1]=dbldata[i*3+x]; AbortOnRTE
				SVAR update=$(StringByKey(smu+"_update", strParam, "=", "\r"))
				if(SVAR_Exists(update) && count)
					Variable t0=dbldata[i*3+2]
					Variable v0=dbldata[i*3+1]
					Variable i0=dbldata[i*3]
					Variable magnitude=floor(log(abs(v0))/log(10)/3)
					String vunit="V", iunit="A"
					if(magnitude==0 && magnitude>=-3)
						vunit=StringFromList(-magnitude, "V;mV;uV;nV;")
						v0*=10^(-magnitude*3)
					endif
					magnitude=floor(log(abs(i0))/log(10)/3)
					if(magnitude<=0 && magnitude>=-5)
						iunit=StringFromList(-magnitude, "A;mA;uA;nA;pA;fA;")
						i0*=10^(-magnitude*3)
					endif
					sprintf update, "%s [%d]\rT:[%.4f] sec\rV: [%.4f] %s\rI: [%.4f] %s", smu, count-1, t0, v0, vunit, i0, iunit
				endif
			endif
			
			if(count==0)
				wnote=note(result)
				Make /O/D/N=(3, dim_vector)/FREE tmp=NaN; AbortOnRTE				
				Note /K tmp, wnote
				Duplicate /O tmp, result;AbortOnRTE
			elseif(count>=dim_result)
				if(round(count/dim_vector)>=TotalCycles)
					printf "recording cycle finished. total counts: %d\r", count
					itc_check(2)
					kcontrol_resetinstr(session)
					kcontrol_stopTask()
					return -100
				endif
				//for every cycle, clear out awaiting visa events or unread data in output queue, just in case there are errors
				visaComm_SyncedWriteAndRead(session, -1, clearOutputQueue=1)
				wnote=note(result)
				Make /O/D/N=(3, dim_result+dim_vector)/FREE tmp=NaN; AbortOnRTE
				multithread tmp[][0,dim_result-1]=result[x][y]
				Note /K tmp, wnote
				Duplicate /O tmp, result;AbortOnRTE
			endif			
			Duplicate /O result, $("root:RTKeithleyData"+num2istr(i)); AbortOnRTE
			level[i]=vector[mod(count, dim_vector)] ; AbortOnRTE
		endfor
		
		String newcmd="", printvar_list=""
		String svalue
		if(count==0)
			newcmd+="format.data=format.REAL64 format.byteorder=1 timer.reset() "
		endif
		for(i=0; i<NumOfSmu; i+=1)			
			sprintf svalue, "%.6e", level[i]
			newcmd+=smu_list[i]+".source."+srctype_list[i]+"="+svalue+" "
			if(count==0)
				newcmd+=smu_list[i]+".source.output=1"
			endif
			if(delay[i]!=0)
				sprintf svalue, "%f", delay[i]
				newcmd+="delay_ms("+svalue+") "
			endif
			newcmd+=measurevar_list[i]+"="+smu_list[i]+".measure.iv() "+timevar_list[i]+"=timer.measure.t()\r"
			printvar_list+=","+measurevar_list[i]+","+timevar_list[i]
		endfor
		newcmd+="print('QQDATA_FIXEDKDBL"+num2istr(dataDimSize)+"\\r') printnumber("+printvar_list[1,inf]+") "
		strCmd=newcmd
	catch
		return -1
	endtry	
	return 0
End


Function itc_setadc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	ControlInfo /W=KeithleyControl itc_enabled
	if(V_Value)
		variable i
		string chnstr=""
		for(i=0; i<8; i+=1)
			string chnname="itc_adc"+num2istr(i)
			ControlInfo /W=KeithleyControl $chnname
			if(V_value)
				chnstr+=num2istr(i)+";"
			endif
		endfor
		variable len=ItemsInList(chnstr)
		Make /O/B/U/N=(len) root:RTITCchn
		WAVE chn=root:RTITCchn
		for(i=0; i<len; i+=1)
			chn[i]=str2num(StringFromList(i, chnstr))
		endfor
	else
		Make /O/B/U/N=0 root:RTITCchn
	endif
	return 0
End



// PNG: width= 142, height= 142
static Picture QingLabBadge
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"Z!!!"Z#Qau+!,/"&?N:'+&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U+94u$5u`*!<4hD`D:`bR<l<ek%!V]qDrBYL8u+jLQ8MdMXB+(=,tK"d!!3;EhrQNU%ikl\i&&#^V
	]-YcjHemuZpdh=`L2+$I.M^"ktYmFHWO32gaC3(_#84lEA"JN>.&+I.dX_n!t'BE*bPV>6(:VZdkmp
	%faVP/dK-Xf:KdGj(_ed!RA$'JE!d(O;?eIhOO+VN!HVY%_:4kr8iFlRd!60V9egmJ#&L5M)(hNkA>
	g7VQS+([AEX$"8o<E(C<D@2W8\p5Y\BBP.qJ@2!2)YdA;5W3A<<R2AqrfUOUSBBOGc:\7:APuP@S8X
	N&2k^.*FAtqQbo3k+(b3N$`sJ78\bi'WGXtKIRlhA>0Lp"/BUnbTQR0)$O$b5SHniHg>g<F.S?1-!2
	><1bVenX,8UL/1TQZ445ZHTg2$o#)Eo="^`th@de`3,$3;K$q8%e(CnZV8.ABP7nKsmkB//WD-JdVl
	n`$iVP%IO.d,&&""PN,3F`<6JnRt\<A/(MLBM@F6tBn?8[=EcN0nW\0bXSLJOte<%1iMu'J+k_1'!C
	qA<(,,ShmX>.8`uaJ-\C?C;:$a?tKHO]3Z$W<="9-!0@Tu!r?dO*1A+MU<R]de<@A?)KSe1!`f:7OK
	=u^;'fjL.>\<9ACFkk#tY7%MB3In';0mhA?]p7*'bsoB\A$D+W;Q*C5``EUKQK]fu+k%l8Ub'c'EBN
	;q)t'0EhP91\=6J+@RNqM9$j"a5]I+&HX2^@j#k%W!_BT;Jt3kmC!gVe&u-%S8jZV&_R0sYSdEMVMU
	7gJBYf.'aW&88_<+WB*#k7^')GlQ;e:F'74@cOp=5u7g,b>!uMo+!<=hS#Qe[YJnS;O!.D;GZSKKCN
	]<t?Aed'$0[jR$%G6r%TSPpH"GU:a!0@3a%<<d^B4M>r69m"M)::IA5_`["VJ-T`!Q:06J>.?FFikt
	'-3-XB$qpqC+94ethQoNLJ-KD]!X,M'D+qeeKg=kmVGkSH>fu1oEtVmcEf>h-<(ogtd7c*ZR13;L:]
	NTh)C/,dKlbO"VZ;a>^d(d=\pe=]:#@eYMePJ;N0qZe.=i'j77:ZU5l`Y?!#%^R<(-cu+.0)1fJt2i
	!)lf*c@\`JWZYt%VN;7T!>WfY#QOjTN#3-,MLl6O<JmN85m@Fi>fsb;rCfU%U]R4/BE3RN!!J6Sfg&
	73!"F;]_)k%-0Se`&c_b0oli])K@u$/]3HFI<pO*fE73a'6<BqiS1D(3!!($bk5qi9`<H*s1%1s"lW
	PD2);9Q75cP_]RlDe;lo,OFM31,L7Ec?_X;ahj@)^).!3X$`t!8)u.oR.fUW$mRu#f/6g6O&O\mt\(
	1]"X(LaGp9`3cE*\#(utg$:(QJ`=O_sAlM$<#RKRSg<Gq9`t3o&V^)HVSM-scPe&a_&J:Ff9b8!FQi
	Rat!PfP>OP/:=2XT3p"Umu1O&6T=j,Wt!?a'g!Jn6i/Z:&@3U.PEa7Nf3.1c7%-3Q3TpHh:aAbogcf
	OJu38dP2IT/[[<XY'lS2/#l3-(s1,]8%#FK3QoKF!8nikJHI"s6tCga!WWG#KLVbF`*d7HRWI9(L]V
	p.$h6:O0!LCOTECTNahk!Pi)Ipc8nR/:bT$gTo4H9E6mS\_pSu"5NnBb&N3R6S:#Ceb1-9)9`$h9,W
	e(f,`'dU%d:3/A6tKt"n>MV72k-/M!2AO\X>A*hk_")n><hb7A#,9t,kJ%)U;g:LXJuU3M?)^f)'(I
	@#Qg;i)WB&F[Z(S8<1`bB73?T/P"j(E!'1g)KVV!9AnJYB;?8WV-pr!bg:FR>(ZdEmNFl6Q7p:b;C5
	Jl=l`MhGS!"jMpZnYj%\`Nd71@7f>a"HM2kV-"!*hE];ZoHQ+3_qC'WagG?ts?tUY<1_'8k^R(hJO2
	9?o93;IraNW@?uJ3?`?W(1T[#!sKtP#)$?e"TUef;bBX*JV=ZjOJNikmEkO*2g2PiVlZP)AskBIA-,
	1B!(6r[8rQFbPpH6o>has@Vu]mUToFpPj!o?>[7ecEb3dT$>,oQjF1g:e"l(eFZe_c;5XeDl%$;5EE
	e-p]qthj'pHrm'>cs_0UDdeD^`Rr'$s>icVD8IHEC$!I%`n]9ND)&WWfS,:P^@b`Y2d*V\t##H;pX5
	![>,j]*,W,-k@-3%4M\k`_XVk+pHu"IXalAMe%..<(eP<-"Y%9$#0$WIAfqu@^bQHd;$%mpK6&J$F_
	'hM9igEf*^<b3]36$Do'Uc?e]0WB]:<N7m84^s,g59^gK[Ggj70WFC=8b?!+Z@IVP^@CV>t"9WiDMC
	'TpM6PYt,%*YKk6&0YZ9Qi]8j:e!]lUkDP^!aq3RA9+[nkFuhKo$UmHrFYZ`:L?W!E],qfn^QO(2i@
	EIdgtch7;OU4ACd>)5Q'1f*kh<i=ET4s?0g.mdOqa8Lq,eE8=T],BBf#$1g9QLY0;s=DgJ'Hs4<=0N
	O4eR`$-(nAS9!s6B)1_@\QXb8o;%.o;lMGR>/hkPOJKPs$FogNIU\@_rHZ3fj]FakBuaD?"T['Vd7o
	B=j3itWt<-%$q/%jFmW"bAdXpA6tEcHAu8sA*%2N_W%Os2E]tqM;`C_hpK*CccJO,LGlB]0j[X7'4*
	pbCh@I=tRH>#tBBRnFlJA)df]T<]5!O>O3Lifh4R!gfYT]DXmRZk#X8r7IJZ7tD:#!*#6JetgR`,R9
	o%UUD/>c8LeN!;7?8]A9%M/:Uj_\i23RIHhFSP4j0E:#bo;D=Q6U1#E!/lesh<XHUn`gX6d(JnlLNd
	VZ%`Ng]0:Ve%j\m.$9ld=*^1l.^Y_Xu2&Ou`-mJ?0=UJ-2o/fVjF,!5+W?hr\Sna)uefD?R^8HI>AJ
	P&Z=C=A&\9IUKa7YK!E->'+VLnW_%&XY\*8DS7\jtBL_<pnsf7NPS>`qYdSR:/0.]Q_ZoIDR=3<TUp
	_q_k9m`6N9+9f\\T[..tD?7uV)>`Wttg;JBQbbfo(Nf6OMh9)-/5Q&Xh`,6*CMg+'.mA4THMEh!qrf
	=0JgTCX27<r#7PeQj&IGq`s5Pi:pU-0bFhtM+O)P\cC<n4K,ZOnDR1%m=_:dcPJ*=+/6O9-Q71:4%H
	;d0?g0s<dSSM.Ek[CUC$>1H@hSi(H$IK+6c^AGN$(/6i/Smqt$#sKNno.?2Fkdqq^RMG^%?*8URetq
	)qC2RTjm:OXK(@<=r('PM+*k24:@tL5`&1CfE(46-$"2bOa-JHKcP"EV)3+>AtcRo8aJOg3n$osfFW
	\D%ngH+K./2h>Q++A>*rWh8MHi&Bu$NLp7/lY*%P$jU2`Xs[%A)!ksRYLlJ4"4&c8\V2dPLQb+jhO&
	s<g5HAe\o\UJ1.(&T\<q9U0Z60o2S$uFIR0L1>VZ!:23@,F)\i4Rc3Z.lCs73m^nZ5j_+k[QtTmiI`
	Rga;&"m`fJ*@+W5B%>7LDNh@\>u:J7sLhfEBQLUoUW]h8d%n%__o7K3p/Fe\/HL]DpGD`T_D,%*._X
	IL#pV"h[K!Q^dC=ZWl(kf+7SE['CZ/6P2p708pYhHdL7s;?bnc[C<uFFds0SnmiMdPC[dmJ$BNbp9S
	-(M@rb:TV./J`+n.ZeYk#2&J5HTZPif^,'iWMP15l=ITZ<uebshhf7NVEBP^gLT)c)kg;Rs7IrON2(
	[o-96&pAP@OafLccUrQ)qM(43<1c%ehLG3kh`,88'B(KT<Md3LVb"a0]\U#6kmJ&j_X9(F[Np'l#K>
	8bKYFKkc)5=>lat20j.2)mH3PX+0hi!&AJ!@GNCk=%KMp-o\Q@\*<n!F!UOQN-R,Jp!!J%R$=H>RJ0
	$6(YIN!@lnX([kstdDLSp1S/ro)7cQCI%C2>fool<AWgRn0O[d0f2To7;u-'$/K^l?=,G5fW*i+.-,
	Lb2[>5Z,d!iJ>_t!.lRtdA:MT'mSd(jSIE5gUHd#UJ2^J`;TY00>?/(qrn>-4^AdPCnbYGTT&#aM!1
	RK?1=H=!C7@A7K<RYL;'%6U^S2@n^I#DYJ0l+0BXLNIIuda#EP2f(M-lNE+bLRrSd[s=2+m0<f^%Cb
	@Lt<qXs04UZ9o#`Rup%$;Fkhm_JMUdGhR#p0W5^FEk0!DhiIB3ZlFWN+oiiRS>F;(`r$NR4e3_o;:3
	Df5&Vc4ak6A%T!)Gp\hB(VUN,D*6n6/kP``ar,f8ol0-:3$SSXFHRng7&@2_$&/kNcWW=OM)ZYC-b`
	_3Cda/!D'EHN]gXR,TdcUPdr=\"4Du9(FMrVL7ViK[5o]@r:qsmhfRo`qome=<Ck48M(e`gXMD/Yss
	UWNGpq!a^;Fmp!YRGu?YK:<s"DNF%`Y9M&2M#C]mZ"pM-2)g.0eA/2=V<c/lJ+TkbGJ47LI;n`?FF/
	>%&T)G!^A=kBE+Ag*Dk+Oc[qW/@1$<4\c;E[*HFLD)_VQ*q+NA<,fpnVBbB<+(D;3AH%jo=e]JoGg;
	>e_k_qpm`DBph%h(R&,p(%]-NXjB9QXU<J5JR!5X7H&8D7;r2bcdQ+dII"Zj1QO?4o<\m^OkEB[%5L
	GI-Y"CYCAQmC.VR?S3r.iUDh+SP[$1e>`e`H\C[6.f0g!<li$)%m,3Bh++9WiG&;qk_8:ADjlG?Ps7
	BCen(t\1p:9Nn*"n>V'qQFc8kBS)LOl=9l3<H*ArQNNar<Tsq!dcl*;e-sLUZ.:'u':e^3<r^rjQLs
	q;(1GYM7T?qUs*dXqYLFTC5;2*E)8#0#_9T0)'#@q4cON=aXA"i=EYlc7\De+VANP(^<M]\3.P%UE?
	tSmZ`!q>X6eu-HA$6KZWu'UW`$]8hm>!o8lIB2kPTf&-(2-%mi9eNhVgCN?!9-N+j:;$GI"("+VO^g
	ZGrrQpNq:;]+%=*M!Ya7H#0e6"=R"gs^:aEpbA/p>Y%Ye+G4aiTMCZ7tH;Sh%:TO*2ZZHG-u<H6tt%
	j0al=a=O+pqqgNB9gHRsdOW9`R/-3^P1O7Yc0J^u:JC"FmOf/K3HbZMk;/fh^o[g!rZhDA5\)03ZpF
	m"B=b2-o;o"Vrf&W>W+@AD@P,qoLQ3^%_$!<g5BEYPG?IUH)42BN\dC*KEMea!Y.pr(<s)hC<mkp(T
	6O5tJ\RR9AnXTHG`*$+ci?#!C\1POfS8^5hN63'0R<`FQ*FG=CWT`t=s#@db)4@7n),?O][r1f8T?4
	DmDX4m$K^!lfMaQ6A\;^+Uk]&\KKV:Y$+D=)V#a$9)Af2'-f[ROMNG;)..Lb+?"8WSGBF/RW,4*OL,
	+[;MYG(@<Mb]MYM?st?B$HpJH>E`=eN-2GY3O-a4LSOJPNfp4=%4Qa(R#J`0<&VHTEp?GL*:n/9Ss]
	&&i.!AN&"#W2ML0PEE-#DbDAO.H>C2a)IaUL3%L>dD-KL#5QD?^@;%3\@aa/<FhlhRWN)?d!$Gn%KL
	.p4&<&RpCUX2\)/V#e9R=QuN9eWq`i1"h?*B#le$lZp"NQ=37:g#cco\,k+]PjOc41/#)f[[0Cg*(K
	Lj3T?qSlUsYMO/Gq(>,Zi5p4+3k98&gun*+2,p@4\m8Sm_0I-B?.3CPF.j0r<EVR)'Rf\:4UG4g!<Y
	[O(d/FMKM7sS63-'Vgu'k#T$"@lY.Y510Gk(],KJBT6.Eucn3u4Cf#OL53#!MM'XB7,BNj*SdMK&+:
	RWhIS$k\F!=SI3-j1$:aT,F.<FIq[FBo\m<"b9tNp;jZPOks@6*YO_FqoOuT7?_6hk.[TDKTmuWMcF
	i1it#Y_7:3&:dkuCn2D^a[IXEL7DNpRV?J+t.T"&T-sc5SnE$!o&t3G0dDttn7mob0$W?B$cI-0,&n
	XHr!u-H*V=W!*%$[PfNFaG=%r&Xedh-k>V/=>S`T*>DB5ZdmGEX^ODoLqnn,:XFR's]D[\'gsED[TU
	MLJfDjeQE8*L4I+"W+"hOF0SefsD)TjXUku&ubr;:F;R\F:`e_D;1<9-jmnD6rV6[Ur4-kdc;F6NZk
	<<ZQ3'+i//Kf'8ZALYcMSSS(7LSMA]#fJZgk`^i`I\AggX2;MH?(+#+[GAE\&p%KRd-&.7Xu<[m[X(
	S+qk=Y?$aod>0X5('_dp[,ZDh[&qqTDn/+s)7ntW"-9#``-`Jg`re.Ff`MR4,Vts'EA+JJ9Nb/)E9%
	f3Zcn7#Le-,(L7).cXA()]2oQ8`2KA.,d;+[U]LNq!*)op+u+",W.\VLL8^+g0huA6EsXFq3$(fliU
	I-969/!Y!5KkQigAD?-T\'+$5J@baYA^B-&8`J@rQ%blUed%WQSbf_!@h\JW!oIkX5%4HmKtmf(WAo
	:h5*I-:#1sO:`C2eVK#L/R&D[1h@s$)%jJ?[)n%gJiZg`L6.,>4inS74$KeA`,F;q/>1qHIK0qT@T%
	*QbPg@k/Y%1NB)C`F@C[uu(=_B.rR[XO0(!6h%_!6I=-r7]YdF#n%!D:l/e\O'-oh9.5UC'_VMC*.&
	)McqiICcHGjDK4g]$H(5#7f#H)iAm-0WDa&-,ZA11`fa,V[s*,@h-H4!VmEM3ZF%EjF1<[1iVC2^'7
	EGYU/"/DA2s'>^Ua'StCm5g7NpW<3^q;b:_9kYMT,^_8CN)Dd&6ZO:*`C:7Sog&B7^e8D=>"^F:N='
	de_M)#Z#I2g=\:]Uini/0l(0EU8o(nqo[W+0:T(5s`3(ki)bc4`6/SdZ4%.n]&;G:$^PV?"cI4*<61
	6i`$3hJG[sJj),u?gV@=gNPmXZi?NPqk/tdUMBh:0?h0)h<R#&hsIhS6G)Z:6co^+#lm3j5YqKtfrp
	;b!$hZr-Wf?Ul/P;.n*\f&PNQ9)r:H<ge)Bi=HR[\4$%jMX/QgDl`$,2c!SWa)"`OGAaQN`+m;UYhq
	8*jPd`B9(d4O?9kAIn[FRRNIicI6mlq/T8$C[.s!^I%0AMH<P;37:Q!43/;9[/pcTM!LF:+0h$E:<L
	-s2a)I<(og]o.Q[T/j`PK&jn\M(<THeg8Snm_Z5<0UN1dAKFApS"X$5GN0kfb,\@fY8Ved0;7/7O6&
	)o(-o(rnG_.?U7r>0>55?[]ankD4P-.k]mbH&/IU$-\SM0F'h;.h_s7WpNk8JCJd]G-6UKItf,W\^.
	$G4(T:]s8qCeq9o'a-c6"G(@gngc@XZTj":DLV<U4/WT1::_58B9==#OuumD"&K+3g/1I!+sSoI,=>
	A%_%[.lfJK%bZD'\06Ubn(^Xj&T!F;qd\ek(?@T#gA=Ys;_<ZmEefGGX:D$rb1c4N,`#5$gR>u!:',
	9nqfBdii7D)QA55+`!%)IKW_j70gIZ6Vc^6h]FLF=3^JDC-J4;OC4R=p.7u![CPQ-:f0pU<:i,S+S$
	q0"n3$qK@IACr_r8;8IA+/jQ'0L.2C88[>#Q9O=5*l.2bQs(qSp0;dRP&,kOOgZ*qPhtui`CTda]Cs
	Lr;eM"Z+S_kNpB9.R8An9!pblA0B<tGPf))R([V?hcSN(W!;2h1bcdBDCKAY%F_FT1e)jMA8`J1#1G
	5k'gecP'[j0`3MA4$k9)@qI?E*'qkBgGJ16=DlfSH"(E-eB-sCf,VYLh8SHZ>0O8@D2_1&Zg$"dPRN
	^idKi*/7'tG"O;tTJ>a1VOSB[(cJ%!,%S9-c0H[kq_CqdYi9K+"i=GK;\rK[Td2A@um(LntY&:k)pB
	9T?_bU<;Z7@!F9UfguV2!ig%+MMMN_V`)AM_7mo:d`p0M](oN4rC*>h;WJMft[RYpYU5]Yg8)_q7-s
	jrq-'UJ+rFCs0-YFKE(S95CN"6:EEehm@3"7MmB:^gim;GVI1N;W9B`Q)5n-2JO**8,8a>E-/QE8g#
	TKocc7/V\i=&oje`)483:Z\&JT[e,nrU8GA2#_\%L(DI*`#Mqq-t9N2"H`PKtj^T7)kUc`Tqg2"^=t
	4KR.IJ+@OSZJ;IN%t/^_J*+.?pRZ`_QXNp\@6STN58M:rI0sk"liB2#"B="M$tP%05"0RK`s:N%]qq
	Lks8+.Eg,jfW\()V-5Q%qmYK9+6:_l;2"9M+U/28GIlo.*d#!%bQJpp6jQXRK0'N^G6BJ(?Cn(lul-
	At#3?u6=B+:F;S!C5<%5q!!WKES"A!2uZ_k:q+_^H$`B(+u*:.n:ueoQph<npEWl^%0l+L%K&(H0=&
	;LS$^-bVKVslPR6,W=$tKA,r9UUhC5IaPb\'PlT#.%)G$?5F]@aoJ=th5T`3ODjhP@(1j3\h%p2]@o
	I$_WalGb:H0(;)`WC(6et2pRdK[I4b&ts=6HKJb>7P5gjS*`.jn\NjTV->(Bcp*oBn"!\=V#:n^5%p
	#Pmf.+5@dbO1If\EcL3pan;RSfmIgb4?kiZrP_TeQ.He>A=K<*8X?1pL;Te"rGR2/Tj)tn+7GcWrRi
	i9!*?r)!q4CF!F7keFW_eL&1AG2.YZrg.AS#TPY!FGiUOHA?GZI!qSBk6VuU#WJ'bq*Q>;rR$dXg0Z
	]'>U^C;fjcg9!qK\2m3#qIDg\Hd7PMf/=e5Pt'BrPr78a1$!]Ru>6e^28X,4r19cd:2OYrp":hk,6P
	=pcR^*>qm9m,pl%9d0_Wt,:=['KLi,#!0"!MW`deI)SC%^)Vd?"R-td?BX6:V6AXRHQO.`b22o+RQ.
	'9Tfh;EfZQ>H%go`<uhV0RHE\rK*O+-b?s+:*E*?&e(U!$Gf6Rr\<QUQ=P]DU3m:VZDVrO;SUs24`;
	^\,J=W0#du]Q\&,0fc^\UhLX.gZ:n#08C'%*glD>Z$/<[n`b[-?_"k.oTeU3*u)`7SbT<R$ZKb-S<\
	3cieq1Aj$3OT5P`nY$2!@cId>f+J,e8Ib-72-,%Xo?$\MtHJY>6.a)H%ti"p<*,X-YL#`]D]P>C'8X
	8fL%ptf#$"2u-cRB.7rl9G3knjboc:LCa-[F\0fpaTN1Gmp9:C,P`K:;T<R[\9?Ffoo'Wk8[:E:6N<
	^B7CsdI<;6_mT\N^JR3fqn_S_!:SN,.l4%CXDuB#>^N?F^.J^:5UCse^!t]^/;W-a\AY%^@B]..DkN
	AK9oOn%[n$5Ic%7L:@./V84P@^*d54m]=?KU!ddt<GE^%Xf%0J1IkFa<`!%s6Rmq8,)H[#[NES.-&;
	+@*0$\"L2PYLCVC5Pl-WIj9@4lNR.jG;%9+roDaF:+WYGlEY)&Q,H@fYeN.JMu&)I.)\o"hu<D'D+2
	FOX06p>T@?Y"]74k'),2``El2c^aIup&s%N+@%=\?>3;30-[piWKqp)Yc+Uoi-P%.NA*.(1nZW_kLn
	HXR>Qh]d\Xb(I2+'KH[ki-h3,61bH[V];Dk+TRjcY^mHkKa&'bI??Nf8fa+YKhUkCX[(Nb`RL=F(Wh
	DcuEs_%*SSm&+=mZTA8,Gf_%s'ohU)9GNe<jgL;Ej8PphNY>4PVs5\+tiNI`QnASJ#1@;ZUpJ?SOJ;
	k,%cj11&r>GYF_134k&4gqAPp>:HHhS%=Vu)B.0LUp]T+=)1]frEV7Hq/5[smu0jY,KaB.M]E9%:(D
	b6NH63<e\`U+,pig?1#Gah'YF/\+OCAm]k<T79J9+3JZNp3"&nq5*NArV5MZlb-H4\4EMj=`%^5S`B
	7VCjrmm<B#t60-6]cK3#,/+1f/&<OBF=J,[(5MpIHUJ)7m:o(;$F1lT%Q,1(KoR=4=bp;*<fm_/1hS
	*bMbg7.T<2ipO=O@2bU#9Gt8oCMSJhjKuuSubtJKs-9=m^aT07CASd%*HQ+>`jf3&\MQ"%DL*)q.90
	VL\\KYMWnr'E.GZg3!_jE#!h/K.4qhI4Zn)`PFpUM[qA]`]%Jq3ff-YFK?_e"(IgTTQkD3.&Ct-rmC
	%e$Wl^V^N(3Ek-R1Bes+m?$Na[hg(rC2JVrm?o\fir%6YC5YD6n*VU$G1+C;Mr7Dn!K-0>@5mX2"TN
	5<'`0MccqC0(kcHY0064+q:,LJLj,YY+3i4Dd5MSqF5IFS7Y\]3O5E4chd>kY3"`akfP^QQi#H;^3V
	IOa,<rDGSZXHgpXrXq3?TtA.R%qn%Er6kARc#hUQb,7][qL/bb`m7uqQ$q9/;0^2cQCGi>LQ8gLmFM
	l2()>N_%hhL5<8edVLiG96bCkKc;@rF4B%_dHrRR0bkGrTU(i`hR8*O!Nnc@t_(qVnTllFrl[)?N$F
	uWT!)oLLl3bIX_:Sm_\Ko_!Q;)s5[MdpV3MfU\aeQ[c10d-?@C%M3B\ggU;Onh<#g9Y*RhF/2nk.lO
	'g[/QC`&N*$-?lZEO!b@3;r`Yc&#KJ$uoaU*Qp\0LtA)s4`,lVAQ[SZnltYF.7@-P>ZA#Y"-4p3f*r
	r@d'=rtk^]m.Q(Lb9[cZ.*]-%?MWC5a[r(_7op48ItCT`=mTS:eE5C27;$bre^_f^6lM"O4`(fj%6G
	Yp8P)@\H=OntcVCL<?E@+Im!F_mR_*:-QMf:nCL;Ikq;gu5akbplC%LiaqSE-rj=Rh8BXrNNQgXA4g
	15AGmFdc@#&o$q5PaT2m-T#o:ER*BgRGFdAMX;d+94u$5u]cj3H$H\?\T,dVEn]Y(cr-oBsXKsWnQ$
	73*9Gch60O:pZc#FG.T5Qmi-^6V:BmVEV7Guo,mu$iVO^_Rsq5JVsDg`s.R2Nj`'ZjB16D6?udm>mN
	_r1oX!#]s1*XOGi-,+MgYI+Y+D^hRl3P:[TjTNY7&EN:T!a:?Jfpf`7;MWD*c.$8-=Gf.=`'5'2\W,
	-)r)l?]8$0+-"r^MSaVuV<>nj=lI81I5+$h[cubAa)LM&JVL(`jDb+PJ,dRYbRFs1=WFg>6\.mh_FW
	UX,0imGV"BLh0[!TR>1k6t._%`p2k/!-Nha0*L?O/&mt:40L*h,t#pM<F40,B6B:lAfXtO,G6;i5Z0
	td8[bs20aTAj<B/O+%1nu[,aMk?JEH0SXB@(NaK5C7E\n\m.ehS1U8r6W?i_('!=8.IaP8J-oO.uPT
	q6UBQRZpXH+^l9hWH=^:sZb$(9.VLTrrOm'?Aqu;FC`fi5/s\HjI(^*']Nj./L!KjhE!U&^%8`lnHM
	64-X,fHW)Z*ApVQ34B?[cki\X2l#Cu1qD@S3SV0Ug5ZSpa?U5Q9a'e:CVrCVbQ-)R:M7/!2!baH-F%
	GFa3$$ER&0/FVGBk9iKbCtb[?GWiceS='/CVUP@::L6"+!aqRZkMQ46eK929n^1f/ShuS8o+PJc^]\
	L-6P4'Fa-dLO3_'=ETQ!pe=te/+5p/[G5u]hD*(!=JY9c5>!_AEp32d5FrN9oWkhloNl"!YNnE;9b_
	>a.Hc9Jjb8H,!Wm@D_o_jg<8^8TSLM@!!>_=Y:qqu2B6lUSEJ$tdk0=O0'#A0)]rJ=$WD+I7IE.AiV
	nftl-Eqta6@n5&HCT>0TFBi.%+]PO=c)5**.ApXbiqMII]I!Y7gc0COOOUJM#07D>V6\Xa8D)Wi.bD
	WuN]g\E5l(OG="1q.tbU]lg=/Gb&J6ol;%,5rPi.FJ??"u#oC"!JZ$.Xh_O:`rdOWYeYAHJQ4<s(OA
	nS@=em-JODT9\G6,kKJ^Jo&BM&3p!Wp;cWOE5&t%k*,JshYI/`5MU`b(2%3PH[C51TL6;(LG#;eR=q
	l?(lMM]@qpeSp=_rrW&^_3FBp]pNL9e!&3FogSm:C#EEPu8ZDr_NB%'%FLs$B+B1qE*p!#X]mG@aKs
	72d@U\\H5)Ol^F9n3%Xg2)0$ceB2\k3$JumDeA?cejf>fr[>TkK_]m`biqj+F%q*W!Xtb"Ta.DF4\H
	T2k4ctHVJ_<V`U5\W5_h#1%^=?L![CN*P_;O/?AAZHbNf)689Kji<N4&A;:f,$RRu#Da+/2/eX7I6i
	V?Phu*A@[kH:W]7):/TZIO=_LmIc2#?k,c&^_2\%00DL]PS\-Nc3\0ts3m8t!HpfYAp=d9XeH+B8Z)
	l>Z2KG$?jRSJtRuY4ZpNaCa%a?hhq8IcI(#_0\Uuomcq4-EhjZ>TA>7TaT,r[[//)0*oqVeI3XbTHb
	R9Y>XFD()S46fM`fpUeprYUD'D=P^jL9^p8&ff=$)?22#9*kD7aj-'JZ\3.g?.??u']??Lr1_s5nO#
	B.B;!8?(FmEUL138t\7lD<[$U]%lr5Q$GS-m%9Z0eFc:@_#X.<k3c/j]Fdq=eE-ddZnLDGOAE7jcC:
	RZ';C9Ofkh&-<33b>oM/JnS%s4*)EGq)7"I]aX4%Jb*"XJMg8a+\@qY.f8k\D)aorl:`OlE)diUero
	Z7H85TATo0DLG$Y`Mop2t>Z>G2PbL_Y[lJJAAaO:9Z9%5[r05<T<"!!C:F`H:sQDgh5fcbJg:<<b7c
	H;sQc^K<&PZKcAar90=T=,#B]VXEL`:%l5l?pYfcPlNN_p=\.HH!dOZQZ?%Kjq%Rpk9qMi;]8R#;`$
	ig?\D9ZN)WB&'ZcBPH1daqiQ=K1`fQW=J/T=\&r$JQ1-B[fUVMgJ`-Eab.tEKe)0-(K-C)2hGl;\:"
	T`r=q",puled!&*n%-k9.nRf%G8:/)+ar6)1>Mr.dWDDU+?\u"_^^52*m&D&&CsM%k**u;j&\f$4P'
	`YpPj"iV@bGo/9i)b9T>X*#uNLCO*A073Tn.<)_(0PT_5)1KWTdjrrh=XY-#i>u)/*OS&o3=$Un'_<
	f9;Oq7UY-:!:jk@_L7kNaF!?@m5cdoJ)/9"<1Fr<G92o(q%agK-W>P(6X*Xa"=lLQjk'11NjEM!Y&<
	cTQX$87J$oJ>m%%^)FSSa>%[RBS6^J8<tM(%M=gp&L+6RJdS!5'ED9XVm8?KK^;)e#%&DlFXBrdfc;
	/?#tuYU)Vsg2FrlP>l*Far_Iro1LN_(:s6pg<REVhK0U[k/,b\e$:fg4'L_ADQM"W2M+#a4IZ3h2LU
	5/d^B4(d+o3=u0(-%b=#cTffT2!F0XcC!+o4WF8h@5#Ib4?H3OCCBck%nF;A.T"s@Wa;S%LgC5HWV)
	,?#4!-k'5QqMK/n$]JGre'Z%&+)!iTt$pb2QJ.T`lWK$6*H8Pr[S'RSKG*4U8_9dD(BBt>6XrSS@ph
	0Vcp5^hRO[@To8F._Qap%-;mY1`eZ)W>+U6#ATOeS:pO[;oigpLX)21uA^P#Sh;C.&3O$jN0AN55js
	&Xab1ag.C(EkrHl/@IRt_."k)Dbp\J^VB4;CZ<8P%C=J<pJg)$B:aB.Ss?>rDkEp<5D/(;b+c;[UFN
	#l6H\<7WM'ohdkQoabTLRd9I-#obRm\QKPUj)lh.R+R>B5*7*1\?9FW;gY%o+dp8`@?:H\1/p<eU1:
	E:IO5S5gT&-<Gh6:Dedcnc^/chA3=U]&/@6$nNJIV73acCW`m</qF'5QQP0Qkqh52A,<C0BRV.7G!a
	UqVlNF=p2l+C#>.CZc.=ib3(FUUJ$?%-o3k;Z(-U!%Lj>@ju<lOmJ>JS^1HH,%*Y5r54tnRa-nl_]U
	LeMT'ASd\RF,E1D)=.K++CfE!75mA4W7oK@[::?j[<n2U(iRVt0M]p>EU,d]\tu`R8$TECg<G*HqdU
	VT4m?]m%O.<YO!VEg>[H:ccbWWUKF46miZ_1FN;=5*X?V(`Ee_8B;(\BS<7OL*:FmO71l9f(O.p>@Q
	BIb;i7lLh)J.R(^tM4Xa&pf>$hNfeZ_,ff4>^?n,#RqUf@6E=P6"Utmp@o_e><+)fPdSp3'\Uk-a+k
	?,WcT!FnjT`BbMg8qLG/REbfV$Eo2X6!72>>JKX=.[$tX-bOn0<`?4-$ACn2Fh]JbUO0!m0L:;=cQJ
	9b9_&Qq-@K$baXlc&J=oEH+43q#bc?.P&jt(.TnV2C0?j&;'K1&[/IG<D3'=\_2@KiS;kCm0'ZmRed
	lUaS((mHq.C5Qr8m>.ml$4[cYn;VGkSWaT$cnXI2LKKMW@Z.=<AWo^\VUVr-G[mbMH*,p5$UE[='#>
	!N6j6J?#%UJ/JE6Db=E9L^F>89@Lq(dp9+"MFZBC=!3&RaIpg79!L?9WV?*E2fF93q"Wdef=nng:HR
	(_7#=#K'-[MZYZaU.g-N1'g"G&t_oI(DDL2Nj2'Da<8GuSkfU5P8\-h*MhhTDHC-&K?Wc*ZO392?A%
	RYO5m(<JUp75ZIi'Q[j"0=EXSki=%Fcf^c->7AGXZlaFo$QL:A3?nCl2,(8fr(O2N9^5_<3[L"E[68
	oB,;AF*j3i8LVB<Q7Wh_Var196G.Un[ntrl[K+RD:Fk;\k(I'kUk*M!Aa$SLLD1N4qZe;a%k6U:h0F
	WLQMACp7Z<A"f642J[R6>][e@RHNcu3'_:`Em7lj+UJV6NtCfegN_!%hbPMX%EBAQ&\!67,Z$?_F%C
	dpbIJMVnWfFub!o'pI))hY!)cNU(cV;/E]c@bWIoDK?d+ag"?&n'R>]<Q]I.YhgFc,:7g&WM_C]o@9
	er7aNO=lA>eUl`F"=REWECQ%/kge`KptI@]6i"eD3N^?h5B@DL=1Mrh'J]f/-'/>G6>1q@B?%cqe='
	n3K8o[3Ops8%L`n%<oYg]G@S]n[h6>S&f./8CUWAaO3rk]4#4lgZCQ.%6VkA"&ShL%"KcGKshJ&B0m
	2U(rE7$W0*)+$Ek7\<=m>G^eYT$Ls3e+*3o_!k<-[K@+p@<Vq]f2,c@R/Q\u0,UG^17e6PDUTX==VN
	_>,8c'nr6TsS+X;:EOS08c%W`i#\'9jP'+Ti-&B&p`f%KSpsNQ:(uhS)3]VQS%tTqMLSM#t0(;!(I#
	dJ2e$QnLFra,eR(q>$LepfIL4HgcJ&aU)(l;'_$Zgo.bcj\J+!X)2!#fK6mMbOZ*+hBUMt%Pn(bOT%
	:*mH,%*C5#S7O<<;iF*d9U,k9+(3Fi3!Zs(NCg.\GaO3Z(+S>N'$!9dIM(!&AtMg+'\mQZ0#bBWXPF
	eF/jkoc0BNVb[Ungs(5O0b^3)Yp?U4l+-2h+,dZIG3o<C/b^`c=Li4Op/f:LQMs>6&&K&5BQjG1k+P
	O=0>oF/g>`$'01j7N47PB<JR_iUbiK?kN-kCS]qN1"#;8OZuG^<U[,Ub/PV6eYr#JRR:EGdgMWn/p@
	L=p0E_E.":6[rgg)M>&TXSlK0g/rdt@WJY(@5mKbW6HM%[pi-+R92(^pZY0Wo%BVS0P>\Be,SB'S?e
	4dZ8K05d;,T$G6qP?D%V5BGf!V3??aR>g1'A[,Au;3@.+$SOUm7Hd%[:q2a&5#Bil1.EcL<U'[4+pS
	*N+X&2,B3r<WaALVbAm:mToMP"ma;;DO[\qm*Pm=A7F0C)Xq"3&Bm.gGLf)5gqHoueW*6#=C]`rXK;
	8a<BF8,.[;+[PbMZp&=7O'l?_ZSgW=O65qX<KaH`siF3$@"tqq1>_?.B+d.3Tn'L+h48Lgt$k[4Zi>
	nZ@H%W<R-aC_,mH7D>MmG/nX/(onFFkp1t48bqqdUe(pbT*#t#3(d"WUT;>l;E5mQRe`DIYc8esO:M
	d^8Qa4bGIqS]-$g$J#fnWTbR\<'a>d4gb#Np`f3oum<pV'F#2-Y!TaFPcS3$1<^q@3D>>=g-;Ua_d7
	"\bLr<('PLVm3FWK.cFu3ICTh,flF[=b_TcTO<1,P/Mp<h3tudKs'`B-YL\5"kBFB"_Ibpm%"n5MF*
	dL"A?/X1sktr#B[[LNY*2I0)"=Ggb$gi[-Kc8#[j>WN,6:@fKa6pc76e?jk+Ma-3L/B!a"GT=*VWI1
	(eg#Obmk7FhsiYSkhlJ/Q\1MQmj<AL4SL9lK&s6\:o.m)"#bJVm!js$ntlBpJ&-MX;ChIl.X\<g%N+
	or?3-VdHK(:?G0Nlq1de[n^AM:+sKH]N9903.'6:EM21gI:Zq?>o@N'BB3&TWc4S\4(P8AWNHPntG]
	49of<h>gNeY.G!KrUe%dN'%ZVM[Uq/4EU9/-Gi;?TGN0HM01)2b/DAJ]9uqqg?'p2mo_\$fSUhhmh#
	a$sO&ZU6;]m[g!m"#@?&^KR_neJ`V,$md5fn2Z/,f/OZ@B8[ZWJ-FFD<QkkNae96\RZ_8Y)Xuam:Sg
	.>miO[s9AhPB&?9f]b7GdTr&^N.4m<?03>;+S`LNV6F&`t3X"#6tF%.Q%"AJ%+#Rjd/'2#`Tn^8rfm
	/,9246*VK),)[M0:I#T/mn["5R*OF1p60&XgdifS$J2&EhmsU9<[a_Ma*r6SlVr)%&t0bF7"f\A&9j
	)NClC1\nD/K%=gd]c3'a3Z0hD,=_p/N$PVp^Nr$JgAcV&-;mFim\S'Q:EOg6"P-Pr<3^e`GMSqro2;
	`uH6UZTtdUL%^B$s0pgrQ@5:9DDdO2-h0Kg+2[EHCVg3bXhX1:(J_&]%!AOhA2sFiiC%mX\B:%V8r^
	C[W(<:$e4DNeS_mU1@Vrq_-ioT,k%`q@i2+5/eM3Ot%)nDDcRn!O;b.coGeWd"%:$bB;5)%Zj%s7EJ
	(\p8UB6f(@eg,-Dk'9g+T4F6+gFX?=mq.gbS[lqs+*6S[C`75Qp?"@s;$Y^OqFga6tS,c=<kJ,5U>\
	pRP>dY=.sn/u+EbR"sud1pdAOB_qEoI1FW=#^4R0k8@lc3lZ6&<c(jq$<@o0Gb/O`I?m]4?PTPn!DK
	u$Gaf<m(AJp"VbLDmHs<6c&WJCQL9IiT"apP.o=f\Pg8h<lQWg]Gd`u,]i.YekcB'uI69V%0nQ]PDL
	6S?17t,ClV_n&(kIg5]'t($SKC>&L2BkX"Mtm>UZ.8bnpkT%P+_1ZaT4"hcXQ7b(Va_*@/r'8q[?DX
	:I)?UP$+)o[3#()%2BFB#H8_?@mKB+D-BNER2@Cb3-'H4S$$f@X`MTl=a3B<S<4_$&',X1P=NTfG44
	YQCq53QEPtj[DI:)'>*TV.9/.-P",0E&HodN]?oi/"-WPg."55B&;V#ARh'geEBfRY;!?Kd7?.ItH(
	EoH&,9fV84t]%3e_GVXS^c1i0ptR0-k_\!!s%UbNfl`jM6%8=gQ0Z%*hRbmGl7g8\3,2H^ADm&P@?M
	]s7kLg^NaMDPW>550?`&":0!?N%C7HD!X&[[Z7'p/)c%SG3BmH3POZ'Db,6S/kp[K^V5W0`-sXN)Ie
	f2"p@#c&3^2AiS9Ztf/-'3QVOrR^Ob"D&B+VDqG4qZ@Meq=>=)A`iMlQ0eEQ(?&0IR^tb;,H;<g*'W
	5Rd"+9gG'G`N]!B0q,MiaQO3C,%=2uaW/iR`Qfb%$ljYFfn;LM@e(Rj&rIioU)L&o::2JX@N[HO((g
	XGb#i%^0QtF2Ei&)j,TM1D&:h'@,'5P<i&^Z$dA+%WhOh5gKK?)P53W,m=cLc/$Gtcda_k+I=,h3@k
	J>u<^Kl#_hVZgI7jj`d9A-jq=&5@/p;qUj1."__aQ.qSeXSF:@7W.M0:]3m@s%&pLR@PDp!2%<?fCC
	1`M?<D<#[!cZ=TMEpuM/IGkZakeYY!Y=FnkQn?`$93(GVdH#F1O!!#;V1MT6#6gWR;=ftZ;.0D:ZJn
	O8HWX<<7TP;\\[b*FM.%hpt=Wh@"6k1V8d?I?>9gLY91g*j6m9b3d['^(9Z/>2QLD6(LQ].I/K$mih
	:"Wn5RF*kS'YD*JqihMB*ASS>0hZ5kdS-YXL&/jpK"C5Op:dOr#(i<+K_"oroY]Ef<$;m>J]a&\>0V
	X!KER[K(.FLX(^)2Lh56Z1S+l^[\7q;,dC.;T2R`o=H+BB/Tcsh;kF4WVK0#Q9@T3C@KuC,5:KBnt*
	MI0DaW5m";0fSU9q-2G6,7J?<RS;llLE["Q4$ol#pKJWR3;P@^hP+$5o^0\E'S?JJHoZb+:oNHmsO.
	Gok_##qt\eq)H8#\\,d(SPfi!e>MHt][p%".[qo<q':('P8?R'pR`jKgj8*R[SeI2882%5fcK2'Pe9
	1c=Q2.8W`.$NY0E_BR0[?po/P:Ui@F_ill^]LSYTYD14tpG<#utGL2siA6HIfY#SXZ8Lh2dFfg]a%j
	(0::7A16bdf4U2f_+p$ZrRHCbB<UX^cnU\B)[/a5A`]FjDI^HLFIfk6gnms6qGg;bqW2J(rd^J.46+
	lAb9n,#mr-P?:TNN\>?9CL#\d.\6J*hb".CGANZg#<G2l/Bd&+KpI1'D1q+aO]QIiYAkhl?RH].PJ2
	p%LF_IIC`PfeO$dD>D)SLRdo`p)>t2pc<tahSFDN*+1&^_!X>6OHO"&9>MZl,1-BR]\(VS#0>[/N0Z
	YhTmIZEk\*k]$2]f5.Gq7l7(/%ZV74"o>,^*S5M*Un4!nC"dMFf0TA)h*\(5d\"Jea#Shf(CTA\;?0
	fiB/h5pG2O3IBQTKeAP.pB&#p^:Bd6pt:@M[([Z`[[7o]GG`IqV$Z\()d+PkCt5KN6X/+#/l[X&A:J
	qPZS?0)Jn?e]O`1V1!F7F\Rf/R%5WTFtmPS@)$C,-\\a2Gj<FM:J[R/qNY-SLS=bSct6R$](HE<Xnq
	J'5Q.p9[Mk?>"^AFb`6r)G1a>eeoPG,10i+^6?@DM5k(e2i)>/!qV9R8Sg\^SS4?A3*^?V/Q--"3X-
	fL<:Ki$>P&pblbBA=oPd!`EFM#!5p/trgh_M<@'h>6o1fk*BUmW)'NM^`qt/!],RG/qP%Gk1QT>P6K
	OQ:n"+;7F?H7#%dXB&Y3n#f+5=;C2B3-;@+h7\PRufj]*4TDL[Zgc(.d"7&$l9Fb1Q(u2WZiV%olcM
	dFX8]C$b`A=G*.XO[K/b]TsqU;q&SbljO<)p3F@RV]U)#JV*aoiI=<g(@-g`.?+;7l+]%bRqsn;Pq0
	1@PRt7mLSHdFJfmBnp`gP.U8>L$sH!HMr!Bh`[,*5'RD_BLs@j?9;h)Ie+XVhg1&=j\547#p$54j8D
	^;J_A*W+q^lu[;4*kOXP"d>3:),N?:B+j^MdsNQ*hU<KfisY?!09F#CS8Y*Xs#T,Yk#IU$Ze!5gisT
	*/'XWmJ1s"BA=[:'lnJ]Q6ZPfUhem>O2lMr:@hHa-5,hqTL&Z_8tT4NrWk[J6aqr9JX2V>DnXL%5'X
	/7DrXnOj.WPKLR:;Tc1;/#76tJ-Uo,EjEl)GroOGuDnk0L4e<CB2BA7s#RKl)_*g-dQ5cYp1F\6fY)
	cV#[==kicUR#@fnhGLMS+fE8%0i2(Ad^(%*R>L[:c[cAO%?W<-F`8*)J&`fjo5E\EK7%!abZM/#+c2
	Ed2<e0tSbNR:@Phm"o![=N_)t?iIars5;bOph0]HS)^jSjK*Td4o%!Z3!pA4RB01"'D?Fp@uT8ldIm
	7jrSZ9#hpL[=o<3YGF*Y8R%15noj*^=?bX;JV?rh^T?8\Mj%Lb]l)n%"RQS+9?U@O".+qOu%l](V[6
	K,ot&Xd1R[iR0j4i56Tn6tXJkI/#*+!B&nbG&cbUYp=)+#,^7PA-2u<&l2NUbO[sKo:<<Y04j5o:d-
	:-,ME6O,S\;\#YQS?Ms/lE9hD,]6OtiU?3^'G>X?UJ16;D`j4o-8=CCIQ+q_,##?SHY#e[S!GQ9ih:
	p_u1[c888bZhD^\q/[k.*:C$rhQqM$-+-D-si`^2k[pi^`%"B:hhlnU6#l_6%aI19+b@'LT6t5o&Uo
	(U($_PJF5]UTDn@2NoI3b5_MDR1[4C@U_'i&6-%*AdM64iMR[mkAIq[31?3@1Rm)@1MCBQ`*>ok*Ig
	8LaM7g+Jdug`0H=7#":CW@C0Sb.VTd*b3GW-@XsFS,Gm:]&]3%a9hL'A@PQ17SHN-b_j*Z7E_NjA5G
	F<LsEoHTWc>0UgqXW7(PA6NWVGBO=3Huj2jBYX7[@*j.8[>_*`kH<E6"^_^/fpRn_paN1N1Q4m0NH(
	WJeDQ[7.u<J2,R]p&G/Y4;>=pn0"/PmdEL7%A,kKLqq](#os#R)`D]hjJ*.>D(G@H<PsTXH3@$uZ5q
	cMjlHWUPNH*\("a'/%UEc/o9P.MC2's9\,L@!X#6D[g/2p6;8532Gk89tj<hV"$hR%.SJ2A_@rcD/N
	&=g3nHA'J\31hh_h$<Z3Z/=A,1<5()Ri*H=#fPr[M2:2!?$">u$9tG$2OmbM$33Tj*qYqV&M,<McDf
	s'R0%:0-IXu8Vs1#5.36@ZUjW*fXfJ:$T;Q>DK`g4UgoP'lS:'hR*gP:!0B&^a)U6ojM9I+tna^M4B
	8_ki]%!i@UmeV"O<"kWonH0^#tM9qCdV?m_dYG(e6^^hF20OUS2q!#Yd;VXRa:K_`>4;X@$+?pCAV3
	WIkhZ^K4GPHcS&X0F)<1_6>BG<K8R(HEOf>FmZTKJle?phk4,4qg#_CV,3R1IBLW'!-jU[6,a%,52Y
	#X>b#M<!6b*1"0EsoI:a%YKo'-$1,mlZXJuDS:>Tc3o?/5J5>E`-[G?'1o_0H]*Ai%UbL(HNjPV8P,
	!.^pNF:MFT5gun%b2B1/E9g6%(AiQ/Ea5b+GrjRI[,9V$=Z$AH/u>SjOn_c3VJC>1K"!IUmG)s"=at
	hrpl.4Ul>$%je#h?DM1C[*W'Mi#j_E:g>=E8/nDNTb]Gs_Q!#$.g4HO.dnsaW$?ti'Vi9Qpo3BfGa:
	0m<nfjuo3RM*#f<]*#2FS4Y"LK+p4,GC;`:1D8eBg%'8+6@aY?A0Z&>q1`C.a"nS-1@'1).76CV(6u
	XR^i:jG-8;t\QCaA3C>VnJ:JmNJ.B[WQa>B5mV\t@a`>X,Z?Lkj,E&gNV6:_oUq0h2o'Q2F(<\fm[:
	JO.CK?YHAA)1(J*Z:$rR_(T(`/9fR8qc\TujMSi09"kVba<7HlfWnCX6NH0se=UC6@E^14+9G_&g5;
	5%[m/qVV:=^\G;<p<-h=lJMMXs*K*?Z9+[0\g7Qq24^o%lV#k'%mKr:Vsc,.pO;W+^"KaRp\(5.lF*
	K`&C$'Qk.sE!;XFf^.U>r[9pZdd#r(Ga#\(rOaeRtWGW$MUIUhs8ZX(COcTX5>T&\XR#7h?boBd>I>
	qr\boSegV\17.)eH_pX=!=S8mQ;@%meG)ph+"`mD$Stpci7-4.PdGk95RT](QLS8-`>"_5C"IV:@5V
	\8N@O,ZIqo)me46VV<>.I5"cUQMelN^Zu%^j<Iku,VpkgaC:04E"UKhRS6Lk"SXr.!9]s*/0,X`i+9
	4u$5ub1sDV]?ig7G,G8(6Bd:%[aoqtO%%4#7''>R2K3Rqc+_;N+2lpl")JP]MWD&\u3D)`4n"*7aD.
	G-.X#B]QDiV>#EogWDeWKr=+krAM<5j-%A2kp-B=k`@8&MoB/<4/kGh2r&f\i9!P)AGnUY5J"'^/IT
	=?+VK;*1ZpAWbTqAgi><^O3jolnbTm:+Asco<o^%(trU>e"SN,6a[$XX+5&o==ZfddO.,2="Anr?pC
	_`W]Q#0Mj?plG:8*`n@p,b?$!L1(U07NN#nDZ7iE>VfrUahOJ&uoV#R@IF*VEb=e)Z0>@"AHh";XRI
	MG"bGL@H9h'bGm"_5!B7qeX4uO6fH9%H3V9g&eqd,RlWJpCh'LU_c'Xm\8'c9P7mQ9DjpIj@I`tYUs
	bhsn3gWILMm'I\e71Mm@\hMIPe:Tag!Rs/7o.f%\<D>M'C@tk:dqRhtkdKf![)XDdM"Vd\^@fc5RLa
	P?sXC^]";LEUi#HdH%)bq;g-*BjKW+?L2$4^!gf8mXilt0UJeO;hmUJ$g0n7CYJsWg#`tM?$Ys#\9o
	_U`hmGai[1!gNQ)\MY'[L,Z(C$&@O<%E-q"CWPF8r5h>-S:FqR'h93pr!G,(Ik9C+_S@gW:]RWE)7W
	[RaZe1c`!b0inn[_I1SC]bQk1Ir:ii.DP37'iUuQaJnZC)3dR$4b4?4c+6=)#I$X4A#[uZSH1_%$U5
	SJ+<KE?7q:>c1-*X:Wd"tgNWD+nth>h.KZX5d2>9i^QqiL!,bn94cospYX.fHPZWbF&BHReAqhM*,e
	8h9m>Rc>ea5P/4]YWpUg+InK7oB/+^CO3l`si@nYrgORs&rLfQA2RO@)Ic/=:Pk:bXX.(!CEJVCD7F
	D#<"uM@K6[=UXN.Zf<n"bOnCo)DP5BaXLV9\nQL"Y&J%_d0Pjb"/iBf=#F4Vkhu]e,,s1-bXU7Xl^f
	,AcP1cc+\Bu4Z<l1uFB2@<U*:Ia[Cq!EdWXHr"Z&hG6EV,W/4"9M#ci,ABtG;XO?*A_KLDh47@@4km
	QchncJEiu29fek_S'f2q5*,@n)'9bCYS0(.a-rEP>?)'D-M!"FBK&<bsY9k]E\PTF4#m(#CScC"=#b
	!62&[H!/oO;*0&&p&L"H$IPTY-b-G"!p-fP`jsbmLho+:f68;*8m&B3J3,SM7'@6(g\Mh'aa$hBj]K
	kh01F+.VEI\IR%*#/\MA[_.UmR?rE>_6panG-\Q`_Y!*,J<Q/9t2]iQQB3T^e*Fc":2?@V!Ca%OiM^
	0heS@BQ]uQ-^)bTQn>H^4Ka%!EL;!3"t?U7='pb\bY[]o-fcVR+9`85fR\Qa<<ZiA-OO-Q.([C1,:G
	L#\L0@H03o:@D!D"+;Fj\6DM(T++$BJc>I7WjF"@]dc19?8AmbP#mI+].hCLfR`3Y^F!E%58L+_Yj^
	Y7(bZ.qKf4jPT5(s$_OSQ1k&Z3NWhK#"/7XI`.l-M3%+T]4W>^3%Z2,'5hV:`i#,QA#j'io\Pb>qXj
	]M?lbt,G[NcS-T!j7NsZV2-+e@N!L:H#Nq"A(ED0%`Zq7pEk*aE18Q6VC7cUp65.O:lD*FUNYO6[Le
	;Cj8-Y`45-!Z-8Zb!i(?hGP4*g=jT:YuUS\=C`_IQ?*AeY7kO&R<K(sfcE0kDOFJDfq<p&2fpmMh@K
	.O^0'eGrMOH1:%C)a>c1S[D1Y@^SAB"Uh;tB[RL(Emlq=hWaI`)^gJZ#PDcP1jS3&fDai<m_/O=G-8
	!*,,KC+^cL7s%2!T!99=47-A5a>I[4!KC,:Tp.0B-IY?;P>.-I+`LqtG2)kU0X-)\itMEm2^+m7-r%
	BP7>TDMf5frU7lI5`\n+t41m=]LKP$Xa*fL%hOCWmR!&@R(E*0a7^m`pDDjGPf;4l"j9+/fl*7#'9D
	Mj\aGTd+!a]E/?O]A[>QTe!-t6>n4Pf![K;;KpZcWps&KJj'Zn9G@%0-hS4.$k<J=i^0Mf#R?f"C9h
	mPG3o^4j8.`mu^^ch,d4aA(K>VEG,q3$d2&.7AaikH[O$8!`NO+[0.WXE'CEA1f00^!=;9PhiR'd]5
	I!Y8/47A6B\.aJ6FSV>;%Usa#@XG`S\301`7Go0_jcZ3g@[L1)TsERc=-9&Od:X8q!@b$ZY^(>Pc^#
	I_&Xd@b24MkUq"V?ICI.M[_9=p[(ct.OgJ.,4e2D`]8ZTh/n$c<eF><B\.SF_E3X=,*?.TS59V#ZkZ
	(+fo&</jMJF&Yoo9COjla41n&7QV&qLbQj=i5[;Y*12HX3te@p:64obTg-(:[;b#(<eW)Zq=5?s7";
	EI_7d&Y'.8<Q0[1+03p.[s675'+8qREh\gWTAO6A$.Y\fP7R=$ue=gu#S(5p2pPXA/[oT!/Vr5pSeU
	TNu=F0`2hSUH8W*HMuk=u?DL&LBT?cLcB#%Z1s:>9X;hu%HlreD0&C-:/`Icof34&9/JPu_ARJi`&P
	4[K-k?j):!"DT9Vg!2s]L2'L<0T&+$8t^gV0ORdN6J7dF:N&rDWt@\MD87S^BK#1YaV9*pl=+N7"W&
	J1(NUMHP9@Si_BFnkh`!ZEpQrMB,^7oZB>Lga$[%^<-"SDgaJPph63q]L2Cp61(E;9JgdZ>L;RP`Un
	OZ^nFt7t7UXA,Nb![(60d]-QeR:2$P[fa5%/[bWX^=]$-$:'"ob4R3H]R@a:Rq7$M""4>TR-:B\@`3
	oUVHePbtn=b4.aY_O1+Vq#c+j6,o5,+eu>^?mE`iBq!l%IoDdIhhCZ?u#1-ms]:Gr-X5j3HTC*[_hK
	Q?l\qA]0eaNI;.pr;$_kTm@-=U%Ij4cd]r2[Td?`b\uoh]/oQ.PV+=4Z[sj"Ul&/6nEFm$lPBTn]R(
	OFi<_*>mjBQbg3[$ZOSr;J(HO"%Asc.UY.;2ML6BFM1W7_>Jq:):<u"=<6)j8BfA5otY#*jAj_dg86
	lWE'Lb$pV@9&.!_/I%$1K)`#s[AA4\\sS02E?,=)B?'4p*Yo7Z$r]%_Gds7=!IVEuCrJkjZ1nE3p9,
	`EVk9S2GZ%*o^WGk7.7j0Dhq^j>O$o$V<<AiFQb5QAk(+9.lr4d`Roc!n(a=A^&2g3W:7.*;dUNm_M
	q2^n,YI.r-h5Jj=BY,pAZ6MXka^3tA(f$EE0&$+.mlamnblmohNIeiY*4ma\s_AK*Ii4Y>Hr+'no[*
	O,AEk!Bb]_(2t;65rAXQ2JIYJfdcWiCkHRPf^@W2ApL]q`=1Zc&QUg#llVgqY<44CF]o=J8m"/S5j4
	RY[>VE.dtf>2&-^C']?GcFG:pjBWkfrI[U/hf1(AS:gl)/"qLH@+tc;oJqT'C,r0H8'U#nN<cp<<Q6
	Gt7U2OT5'Zr@IqVGt%KSaHejtOa&^WOJJS8A`!ZtlVIsS;Ho;Chp<P#Dbe9;M5kNe]'B(Ktsr;Cir4
	UuQOGlR*E(Zmf]=U\UaoA/`94kflqS>:En+gn`*k3fq;s8(%o^&ApTH.G_d+5ZqkntYq45(:.u'KtK
	Qh>M8AKs"d3TQ.)7Z+;Q:r.?*D]C/aheS%!.DB#+)G+X2oXU5G)QNYK.9ujrB:/q;1OP'e\hL!Y/Lu
	/#(KS[?ef`_@sqShtV4]/LX9nr]OLo+WBpi\(`,@a,d,#r68;U/;IAW/VaNash-,@ib2-4C/kfKG*#
	B.9cNcI+(26@`gdN1K&O[*P^<.RWau`QN'"#l(a@60&@%^bGp/,#Qo0Ok/@%G<_n45Fa8_1`Kl>iqU
	[^YIAu/NG_ekm`j&*aY,kA/q:5ahVJ4on+UsQfPYdh.kY(t?%4FXqNI+3)'^>Cjk.9DhP4;a%k4<=@
	U)\)B&"[WCrYM+0>GX_>s!.S[VdT;Am,",D`rR0-SK;eK`RiI455)W@^38G#mE;lI:?.$0&g8I'EB.
	I-FrGucoIFj,,,X#pKl9\?hO4;d+K)Pc4D?W?iX6SQqAJkVLu(CL4Vu$I)ZtpiKp\QC6hR//C`3\C[
	S7/DgDF?-4\l:78tI20s^m"1U+f#!UUjeV)a=2KJN%=9WJB'c)U?FYC(JpL3>1_H*1C8nA%ElOVBr<
	bh7WrEdd`>#<1#SMm93P[RO]oeQ;<qX*M.#nA"nSeZtcZ4F$&OBpd/&C&QgCUEU[2RqY$tr2nk+Y\5
	*Un:u@$F2T*f#]Y!7h"Rcl.LT=O$dKNZ5L&$9?G4).Sf['D'R8NF3-]i65Q5Wfi-<k9+uHR^N9g&o5
	0p[+."*aI,i?T6_,7[U`q@F<+9pWppHH8roR/,\'cB@2q$uo,j$P-iU'SsCK]^TleZb^"Ir*j/X(VM
	65Z1J!W8`^hgY$aMO[0]d$.1+FHp"l7a>o07M'=,U0bOSOWMIJh(#.45V$jFU#_:DIG\>0\!VJ7%JK
	P5\+q4H06tE<ZH5GW(i,KoD17=LR/N+VKj3?.uZb-1/D>T]uJm4/XjsP*'rJSFJn(i@<;urq+ni'n1
	rPNQc0AeaZQM7LS"eVo_:@5o?Ecj:r!mI_<1?M;2*`))#_J\PH!8(ASmQZ[1n;HDc^\Ni[DS6XDL#l
	eI^3&&Q[Pr'qLAQEfX+'``m<H'YN6,J8C!ttf]j%-&D<JSk1Il7nI@#C=-(I.ZX6?n.)U>AEC79f<&
	s4:Lo76TQG0GhrVWb2j+:omA`10hjBc'hZ(cmD=al(t7`,#^ERAl!u%"VsX>k"0-;<BSZWf(nE9,'M
	#:"p`&p\sl1^?SZR4h9.u!+=<lNl84o_/(H1;EJo^2ll%><1Oc,C=g_Ab9r$&RYI/83rSOmMfEK60$
	cF?qcW)q3h9Tin^?Gq*YVL[HG5Es]&ieKO$DmVLZ%`D<NVQK<BVOEeTgKG;*B7%%t?O`jrW>rYN;mu
	-U2jNHg@f)_kS)12<Yn'$9rk$qWt&Ff#EMpMC"mrnqS=YUVk4g\ut!KSPBJ7!&28t('Mi1-$+Nk`ih
	e'm5L=RK1Z1aFIU9J7dl1iM9,3ORT93p)dF.uc=K^;$q,c>b?Z;[LGXB64cuW>'q,+7*J5:V1C_Hp^
	?koRERT./>X4HJhg]i/CE_,ib+KFGjRLMe(I8%gP,TUX^nl6dn3O.^7"DS"TNKG4_Y)%Cqg\Mdal+T
	hmlR*bV:3>72guasSfa6hrS>BDk3`#npV'p=hU[bV]#TTNa7o*&,<\)GC/-&O;D2lgcX"6`cbI43:I
	Z5%e(+;s?Te;uIgrkOI<fVZSh7#1g!]`W;>'35IsZ4rV%;9SW5lJ`%R0f%q"[#%C40eQ>3$0Dl,=HI
	[XE:B\#bI9]i$$SaB;g<q28Es!'naj>`T,;-mF8rg$oA\*S7'`Bq07FeS9'\lFQE`Y6LHK;!!K]V6m
	S8!rt>-cccajDr5P'=bU=-[U<^f]NDAUP_2K'[d0sLSHPBULK:af>g6osY1ke^]!f%sq!Pcc:loCSb
	hg;U#:'?[P^V^`5oG(c^m"@\SsGk2Esu2(N+TKnFVEA<4o4<M[f6&_j,NC!]H-a9)Y?YZg<Y9Jp7M>
	"r90Kn>aRGcDf1m=qTJORr9hQ(k.c61J,CC#cT[O)%@O_>!:K#trK"[^7eQIs9",o!s7:a?l+d&/G>
	:r+Ru_UXD/8k%AofYq>l,o+/REnj5$D=DOhaYVLQ=WHo>`qKfXA,d,U,31KG`I_Z7LCTFd'r.pu/!J
	W_uH]A^6AL!:!C?!+]c_##>e-&1r;98Y@Ke!2L&IV,W5Eq6a&R(D7+I(e<_U#1gO6esKpukKV#DPok
	Yk7/$?JQ=ZK\/u<6T!((5=VL]:DcT;ik_*K9DS_^hTSt=nc%d;7oH)I;ZU;10:`eJ)Y63\j^W$(GtJ
	N+r]X=,RLe@9HYh:h`!n(!\QnF-DJm(N-ub]TOIbs;CmrnIJ*@m@a-9YIj?;)lg4?osj#gNSZ3!-VX
	QHgS;?rOe/,VmgOarPd[hGCI)H]%jaT4>%Z1C"i-tok2#3e^7H)mrnF@hDJgrCFIu>.Pd`V*Euk3Xt
	9\lJ=-!97#:pE@Z3U+bOVuOSY"=r#ARr1O9Y4^qomtOkJ$Bc9LM2QKb%J<mSm3X`)Q!mkMA5.`6KBg
	fH>'82IJn-PYqRjY%_`^+Tqed3H'mH6iJN:W(J0VkKF'Z!*'4F>Cdr94?tqg.JgcKdRo:$_(gguLaE
	6C<3DK_9HcihW2_#N:,<hILPO6#DDYZE*<B.:Qf_ZT7dcb@S<ol'.TWifllI3,s67eIC:X$)hqi\X[
	EWgM9eT%2-b!us+$Z-i/mqfEeu"Z,NG&1N4fcHZkhtri2m5D-h#jJ.023MklE=RPrM/gdqYb=h]A$!
	=26n?e-:^O#$do_.<u)69Xp_1$O<e\DP+?Z%eob8d1Gd2jY!m)=%RnbF#Q[3X1O,+O=j@m^/=I,m?+
	2gVg21&m_J`Ji_0=?/OdKW(^h1,$0`k0OF?#gdM.i9UX,<ne`Yh.sXJuV^g,k[sT"B4c!2(5L">NfQ
	d>a''d&*0C(c!:u9=YKO5S8g3@c+Z^C=+nS"(=um`#5[!5DI^O[s&QQaPC!8p0Frt[;U;@47-ArXmT
	J;I[2`1Sim#2)i(n@9tu.$r:R6pYJ$62gRk$OZgjo#P"^-bh7ET%?TH6]pMnuqQeBoJ#>Mt'f(%aRQ
	i>O-cmpbf/mLBCI%"%A$.qPLe7n2=PK%-s](]00\d7mV,a"tOS:Yfo&n;UfA;4n#K3nM%a6R\0TUf0
	&-c`l@AQ]d;2q4LjF5+-mom4;V5rJQ43#M][dEtiZ!fth^=/:QT3G0Cmp9.^Nl3`BRLft#$SF[k^5Q
	I8DqW,R_]FP2JW;,Es?nu9o?*7VHk"FWgZRGpKW.=ps0TZhW+]F?)=fqS0HdY(qS#3M*3B?&2Xs$&5
	PjQ%b!,_+/)LqFhl]]k%o>W-g*aU;5%U"VDrEnDq2OJj&o%Zk=GdD*Eoq[m>EoFq8cJFK*0*p%[$JT
	aIL!&F*2CG?)?[hC]hu2^0GJ<a[.M#E^RAtNFE$dH0#Ar(.%u(9+\aqq0l5J.s3*C%SJLV81lFCEsk
	8o"+&g@OUcT*WYiAiAt:t[QJkD6&dbPf*^j*L?e.0\np6Z\!Zl2[C6B!k)_#0`t.G\_MYK0Q8iRk\t
	if0rOJi]mf54$;(XH$3l:J4/J?4)tgf&D?^:mesIRpX3[6S>5%(PpQ0e^kcYPh#k!P!6_)Z_ONCoYR
	1$jqY6.H!@5^g*`lCm%l14=>e^!HJ%GNjn#ifVohenbk&r9EF(Mb%[T\1M+Z>h$-m4Eo'8;7@AVKef
	EoE1U.t*sI&]'d4]+6>RF1)#02n&bUNt+,hB3Q=eE`?$`#,Iak5j<O"3,o"NSH<C1gJ;/YoUoS@%]Q
	5'_[Q"c[u4oR:uM[Vi3NS'3QE:rY3SJDF"Ri=AjoS`?+a.'ebX@9%JY'F+g;"M,!`n\V??f26,4oDR
	$3+Fo8lV!o4Tg/5Qc"dW<OV*0`qDOm%#rqQl/.T-#]7&_4e7G:So!@%@B:l!`1Y3EpbJ#6C:G:(G>(
	-k#%b70+gHHF`VTgbePLt]drB(\5m;/CA6EE7nAtj7X+kV+$@&K-`96ZYfbXU`b*\O0.QZQKFAiHij
	R7Xfep$a\strF>>%^[`HM'Vh*:[?q>,"mRSV40W^c>\5S(jCC*j3(/>!t):33SjYD'Kb00]'!3KIW:
	]3qM7k(oRL3G0K7`NN=5ZC1"9+)Hgj9FO*m=nn+FUFe4=)#M#pL/kRcGmR8+O).1VFkF,6%.d^*`%K
	5@pl:0XU`i)s&JQ7L,t)QjCfAV>(X>apF]!C,/e+C\#YJdeK-Oq>">H=3+\7Kb"CRB!T^Z8nBJg0bB
	EB;H_3L:TDiZMWZ<Kg3e#4h2VEul:f!T0&`A7'k.tCTR#2jCJD"$dsrhJpgH/Znu^\R2Js7AZA?Bs"
	,qWd1qrpG*=e/VIDRQ4tm'Ur.RfS-8Kk@C8UFRdf1msOBJ5Q@XBpF^j)fPF?-$F-P?D\A1W`.GA_];
	f#2a,_P?k/\*];3!9r9Bd<LRK65cb`(m/197!R5DNf')AjZdVcNX@[7V-"JV[UcCmm.ueh0]<>Mj7S
	U&`P1LC`]BWTWUiHEoh+0EN@@:0fDufr)KKpsb9>HF"#NKY:pMhqj<LSd[l@+BkMF2"*r`M5kaD.T@
	H^hjQ!K2H+,RL"CfiD1)M7-cnBSc)T:+1RVp6KdI<jC6L>Kn4?M@.=@f5feSaUnjW6L90N1>l#&Oce
	@k)nSN]$5H7`XP9c$-`ejTo)@okCB$b)9_]^j;?J+qjhs%i[d_f,SS0<SPRYJ9YUfkIBOlo4N5(ccC
	C*_lK5orZ/4DquT`]6HcZo[V(Xs0KC'q31^KkeVRDN/C(?I9nr)UN.RB$tMa]lW8IQncEgJ^+$i'?@
	Mj<:!e"hOHpG:=U;S#WnP(*V<PRbU^p9<1l#8-<\?ZR!Ws\l:_8Hr]<5?WaJc1dh1X4aSH.WF.i38e
	k0EjG1)a=13LB_WJ.+hbDM,mMBF4o&!6@RdLmc(E9bC7H;AKi^!)&K$2'lU]?j>IY?DQ5K[ZZG/,ED
	nu4M3o9X@#u[N!L-B7#]g"Wdui2!@GdoW-!CP.)q/hUT,LSk+Ps:EUhGS(OtW6G@M<e&HS'q`k[F%W
	d8/((N/lQhu;@$2^g+N7uKqVcV@4OVo<\]L"39-gDKh:ZeRDpgW"R1gc'`'^%g;lIrDSJ?XV0-U+?:
	BPZ;H2;F!W_;Q"F.rlr\,s'UnJ`ZaEAIEq%Dp289[`dIrd#V8H&Lu(/\OU2_=:mi345:%Ku!d$ur.#
	aC39IYf@@;nelaU^nof$9l(kD;FdqIf!??:&3[7!m@p!?r_6F?UX4.En&H/fTZ[0G1:?VX0FI/2jWM
	'YG5<?rB;sY25SIUVZR]FoC-#\(6HnLBN8RKS&$YXO'5==;E)Nj?u\4X7g^IHZEMB?hdq_V\gL?])/
	6]7r9'0KHR=G&[O\l3VoKBA^dJUbVl$.L#$khg8sN9BQpKZkr!hV8L:d(Lm[@(l&'6mG@#V.pU<$\)
	5uW=Ab>6p=/`-pa=&oE\SU]Iq6NkHqK"Z&cG4MN9hLB_#Wd*6dfR=H7KC6J_q"?;+(?LNDYQ6sL_DS
	N0Dqb`EY^AA+ii8XZ!%TH5Q^hQTG@s\Up:l44c'jT![/bFLa7[b:<X0j%KL#H+V9cmZ6>$IlR'Xn%0
	h`62_(lqg"s,P4Kd'l&Ci=pF5\*j!5Mt_*nUpN0d_FdLmZ,F?+IH9ipZikU?'<m18))MbK]=)S,Ma/
	KddJN7>;9m$Dsmm:'K.W8%/\LPhLb%*W*PN\GkcoeR[HWD+_pV/"Ch-WmDEfKVrL=ID8GfO:1\H4^h
	/sn%EC1R(#5rUPELNI8G*8WTFfn:bJa_:`$N]Fm_$rMg!$I-p#$:7mk5uLc3Tf_%RVR<K/Aih;(PcQ
	r=W:^)-b+_iOAPh;XVqi]/gf>c!;&1[J2$>(SBGN/!.cR$/#PTS.2fLS?b(5W.f$VQ>)]cm]7c>^^%
	ikB!TqW$j<+f\;fg#I3fddUp&T]+,$l/0H`:jD9ntj(rc345XeMou<c1bF86ipQO^un?&>QB'$g_Fr
	uZC/S@YL0cP+`726hY?&WCE]hj`aJ1nS0"-A<DXXO9NQqXt3P`_IO-+hTY//]?L]/JbI#IWWcYB&6D
	pdoUI\n+hA9:n9lh;4IbXTVDYq0$J>&#ec4"ocd$'`cUb/>N:ioDe@RSj/[7fq$bUk6X)\WH(udG-d
	ZK1C_GLLZAjkO5sGX/5,]j?5V%uonS5%qd8$+^]nVmL*0^W[C!dRNMOZ9%EW%=bpGMP=0B$t%6$H/*
	.PIuc/r^#MajH[W4o3VT6-[^q#q?uAP?R>*.,6F6oO:UK4N3r]PKq0X?JjG&9fX`@qVTm/A`5KEf:P
	3LdTZpSeM>YF=`@^PR8h#k9`u%d7JO!J.Oe<2uoo3Al;\o8Z*`9L`n(,[:!fCL^ls<0H!U@I84SB\n
	(q0.O);j_e;$q-2Tk_!X>UD0qV3Z^%+eJfsYa-'F*MELo<:2N7)EP>gp9qYq1g/QHGZ)Fq7r0,?.C/
	AjF9;D2>?3%HqQ\pbjU5dj3CQ66!T3J.t;W0qp!(0b<,XDB?LcraLu-"V!GLI&'TaXC`9oX*ij#&8L
	D_*Q67`/"?Z"^[l+F_@_l)0FJKO#[V%g2I!OLpctK@l$QoJFQF[qao0TDrEll:MZAWj&.>`c9*Cp+U
	^Nr>EFGHm\cjEi:!POs9rSR/I:+BYelZ]Lq`@.+R9P3;hl@@!b=Ql+GAGsg]V-)FW,5r1p%o"E#"RB
	8cn7d'1^YIH/Q+&H*kX>e4W9Z9!tae<8e^[M$+FfM)s`S4jU%>?e*1s3M?XAj<`mt\[lJm*j.hZ!4F
	6t.[._0YpTALd?C4qgfM&3&0niY]"GglZ<[*[%'d7)#Dc>_*di?'qroE*82@rTA/\jKXk/,ffdnc>=
	kA$Kbg+YjPd<i.PLe-:/'Ot3orU(.0W=f12+94u$5uaik+[G3.Ka7ZE3.t+^E9hImY+UUm'LbHCjlN
	OMGfF8SGG0++Du/gK-ZO/L+JPUo(dXmPW$G(BrH'^nCBKA(+Y&KRKV4,5*H4D3UQ)[;LljQX0db##C
	h]<D*/Pq]RO"*7K?;r]-:Zrjq$+5UlO&:ZREkC1!"^Rd<m3ZEX?ZXe4L6q?9[**YdaRK?2.gW>0U\a
	\8.6)`[*b\V+E0$^pRUc4O54%/DuJV_Du]LfDZ0>XC@AYC3[O0FB*'h(!0kjY?t!#n2!Nqm6L<l<;A
	^cFYS^kZ;iWgg<40L78_D_<!L:G_KQ;(BptX>2?[/0.QKHHpJ-a(16O;L\f\p]ARc_A+<p?cT+(I.I
	(h6*P>P.pUci:VTs36$,Ob--c4CoC4>INq@jsQc?-P?tWB"$8o_EsZuiF5%;S2)%DOC[Tt3Zj=s6,\
	jWP_LSd<HU%`&S$<1i-_R;nhbE1UQA<OiPn>\&g.>Xc)f\;/b*AOb#/968&OlXQjJ>J%:2@X`['ifh
	_eSY@ktUcdS%pcl(@J!g/_n:Yg70U<qYT.IP!KsgA,iXlEZq27R/;\>gG3-01?r^qNVTjp]%Sukq?*
	s[iQ/CB8XXDI!fapSlI'_Ai;54+M(Z:?cNut7$5JJ0!kVKAP#%QN!P>Eq<?f7E;[kJbKBVU4@q<ppS
	ubtNL*t)p!s#l9q*KQZ6W#Q^V0A6WAI?L-//3.X[YV=PH7Ca6oW-k:aGAi09EVKJK54_,,JuYGB`ja
	N53L?%*0iZ'M._N+jR.AmQNR)>_p[dpW%F0`#)e9MW7MnBGkP<NeLUbA^[A);O(-#S-Y6GCWMEE@8R
	_1jMY4/U%#^nXH)Z4<[Uq4^./_]JW>(L!0#DlIs)c?qXDB=^\,"P,26o`;\[eQF)WgYo,ZN@?FDmLj
	?os[F:=M&QLaj!roT]VhnHh/\U/e^XSFggj>JcG1:I)M@b\i$9!G@[3*PBBM#nb$F0J]seU0)GZful
	:cMRV>O*cYG,(eDB\?,C/3679#4I_L7=cm8udkpFi4_7UuN+oEo3>!0)ePpY:AiLu&Ud4_>iVobD]m
	!T(lPM!D_q%eL4]D8`+8NjVM&8Y!O:'8PKQ_aUIrc8BYG1ZQ]Um^hZ#:!jWDKQ(;CDW2Wn:0s!>4Y/
	p>38QdhST$!_Ahng!WbD#jbKRW]'(_$sh(GKt9.mU,ouJ#cKA$:]LY9YT^CfU0h,3qU0HMObXG<F:+
	t&H=aeag2#gI+8>(Z`TUQD#r2h_Cu0X9nXZ<MUjD?tjk5%/8#Y0fe!(,Z;UJTXD/P;h;:XdT.RgUnA
	qJ94LK:a:+Ma;)RsIqIp[O7AQXB>+Hnq.uR=LBf7&JM"hN]U2EG6I^:o2`.CqHh<hGA?#h#G,he_(@
	$P-3O47$jKmr1fgp#IA-qn#8FYK75Y6"$)?TKmU(^h&hK)#V^u9<BHTjDs^^n6Rp9+W""io2X+Jm\;
	_17C+h2mf!4fXid<KbQ5F*C-3>C9Ju(jdng8C$mF.Z]]/stEWt2#<enE[p\o6lTM+%al9P3'!lmjqt
	?Fo^Jhd(Ndfs+DKbsGn8me6"<&)8PA/4[R5iY13Us4P`-J+`C&Rr@u_dl!UeLkcOcXe$#Wj!5S%9O*
	LkGmLppYK,ZH_us?+`l0Du:^RdhGb8`IRVM`/DpI5<BJ=3;8Pt]f^_Q\,(LDLaKeKLS664#A^_2W(*
	K_+4@J,W`q"oi(Om^o'$f"rdFQ)a[Mq&P99ZquEfqK8tFk-3S4K&+C'D"^%'PCF5<B1q4b[*;DXZCJ
	sl+E&c5Y>ak%>77P3X>o?&_t%AN%VCm18EBuPm<nl!-us[:Kg1/FPpnTkMVp*e&M-@A`r"t16N6:OW
	uSZ38qoW,k!B-M`sc)jfc=AmQ9<Bf2d'BRj?++!H6ba^\;^KP%Q8SP)kYfrJ,m(hg0K#SZJ`gOR,<8
	/tBC(4s-DE[(ZCQEBi?_C[nRj>eG'_I-9nYC;(1jA2$<s&elI?N^6R&EH6I%cMPT.F<sSeeq%=@[&b
	l54TFd-`QM7((*_8R2+YJh9(dNQID=>5&.ejC!`D_aA'[?pgtj)Z^Z@q5Yr2SO,^!Sa"5T[?fmk4IF
	$c=ipj&]Gb`r3PXYj`5Ii++!CB[<<O\QRP!<(bf2!VQHBq#`SIP_WY6?f=M,(KYA7-VS8'7qD6S07'
	1[JfNKak+O$nN[sSSDN-*JfmQm'[XW@e2+e8%T/$]ZDXpNiG<Q1iqDc/)l+6C1-_4/f5?V_q*LPBkF
	lY2qf$=dEE]K.ko6rhSK/7;B>46%b4Es-`@J0@fDYQtRt(GKfsKhK\c)5KAI)Ya(Q($7b8X*2dG@B$
	Lk;S4:dj4!iSbDYVN%sj8+\^%obCS5SI6I_.]&:R9?V(u7[KO,NK&b*/$Sc^X##6L<S^kWT5>bXJm`
	r=jXZZ&$]??-ZU#+\,&:.mn+XE\r`>H;W/ru,X#)m[Wl?f'Ph*HgD=Q"lIQ?.b%]PcDPjDV2PIcDa:
	arH);2R]-*f\pcBpo6_!_OJ<7*tmAH/jiUCc<)fi.=P_GB]'bDlLMf'sX^$,^3jR5et;`?m9;<IdRq
	^:>&G*e)NPnHMWKicTG3!aG>.bCi4.9p\&'#-^mpCbCS8-%i@:E@hQ=s^A-uOmGj7Fl?K\_S+O&#\n
	mgM"?;jqP?V7\5PiL\bHJo]mprc)#\YC^&6R0gdmP!'\R=gi$=g;P7M8c=^"!iBOC;$.-"m;epQJbK
	nJL[[JtEu3'Hm4A7r%d_e(JteoCh!76o9^;2Br2*W!&?(QeAIOK<&dD-k_@cZ#347B*iP<G38aH4br
	-q-Mk;&=^6of;MkIPGAg7ep<0`O/lD[afqM*@7Zn=Xo8uVB^&DDVS[2XV8i.]Ejg:\d0"6%)gLu3\A
	#C^=;Pgurl)lXuc4u3'pC!0&2MmA^MbcS9kb%fVV)9J7n&#(<]7!0k+8$;tcdEj`j&fR@8p%`jIIIk
	T\9(5[Rcgo`.d&^eUV&3WgWN*=/+`W*5Q:<5kJ-S+^,=^%>Afos]YZ'(Jmsq?ar2)6[&O1iUrakdh_
	4+1<L+%_6Vh^e8d(EI<,9?GK0pKDS;SNn3_cbAjZ^!n'*=AJ@\m1te@WRCS;:?2s5:o^RKCl21B9*Q
	^2@`ic%$?;Jr+:g+X[kb15\X[cAqSai9lB(kK:3+p8L*/&PSo^Up[\*;5$k2\Yu=,LHr`!3>u?j_K<
	H&@uTF*'bQNBY[nJ&mh_<3)Jdf`K\4:b[[q#b+2'V]m%j=m3WaeoGC?24$:KG10G(ZeI2IBt=Ym&;H
	smJe>W$0FK*F(nJ9^_WDpFZ.C)`_3L]lF2O_6E"H$80202>\kS-^P!,^f%(nk1Y(/G*k9[V,40W4].
	[b2#-`J+]/ss0)I/>^Lf$C4`aWGno+3?'j9T,g2)hK(Y'3:pIGa#n<Q"9_Y%`OD7G!T>t'c0f4l.:`
	D1cE,dJQ$BYT2!')5nKLet]J#6C;!@?AEn0m7Knb,2\1*2LWEn3p^]6?.J;JMDuG3I:;-%J;`'Tn>K
	80j1Ds4W6J]T93e15eRRULC:4!1Jp9X$HafZ]p_DAe7q]cPs%P>haQ[9b_:e6^EsJ;([mUMA]eeZ&1
	dlQ;pi6\ns5L*1S/@$"<Qa+`epURM<"2;8Q@15Yj['&Z2])*8@?ja*Y-'YDqH>5aohcn%<Qb#)/G@l
	11cT>=fSG_59Co91GOV+$KQJ?[cBedujBMJ$>Tq8mOY8CIU6@-SPK5>l/c`[gR>b@8cCm8)M]iPu;:
	t*=R6EbESk(J1.M;$NhdZL-s<5>&.#.5Q`JZV)1LDW1KMRbfFljWNY%\<TgiJo_L)AL">@"Q5EQO[3
	0^F5ST;(@RQ/GJgV-n,bdXCU#((pA"'lmfdQ.u#Ns[me22ip-r:80M?ne/i97C^gC>E9M2@s\2!^8q
	8^g7eMF:m<g>rRbp/VqH6u*/1gb`d&^s6B9MKPU#*UGZd\49%(,16T$(_p!D"ab.P]&O/7-5l)*cDo
	pLSWn6ch?1)NAPH!1Ef1)u%OK_CbUg%Q#0Te)Z1e+%nbef'6Z\BunN:XmF$J<Jb^TQG>CZIXoZK1rP
	l.2pd;1uR0p@,!g/-D([<]?r^7fBV"c05]c&@3>8Bm2B`*uRe5Z^n^F1AZZ#5%@4%Q^q)`DB<Ae+$:
	WI^(<>R`3h-&4-bl(^g<PTE#+n6\YRX6>M5*5g@UBJhia,+2SW1Q%pFg^"d<8@djGL.\O_?n4[L.D3
	RB<#%=gHgH2mu!63qWE$-ID[OCuR+-mF%R.'EcD+b>:-fs=!+3@tu/2&c`#UhlNUNO<S!2,DV,%`#c
	;MYrf6BisE00HV`8oM3VC+Pj5e<+N8"'D[i1i:deNnj.J[o;uDaa.OS`n9#(B^(pt_PE^m.lVA7/15
	%;9`i_*Jk<<Eo':aKo$H73?@<*f[ejp*+X;$n]b<V6?:kHT0qaS$BG;q.?pG<l*Db$PABbb#5`F*9+
	.;RL*k:B;EBd57:OSq%!/,T*j/dI-Bc?0ide^Q<Lg&VU;sbtJJge]6d3@`s_XZ,LAjao`BHFk5P*JP
	?p`apX,3gebU3#s"o)oY&UDL*BH1.oNqfWk]]r0L3R?9cR&K(1R+p(B2!'m]0199lXp.i5J0Hb4AQ^
	N$&);rUV,RFNY0H`%ucig?VR*AYJk8:'jl.S05p6-r6Y"1)j`[bG]=I!lRgh^i)eT<Z+(d,+,4RB]4
	XK4(goTeN&r0DX-WS>=41SYrrV1cfEGrY&JDXD?A`ujaL^YdrGjicn1P'/WMK?hrPQS&KZ1'A[9OVF
	Gi"Fq&8$ChC,%ip7*%/O/nhnoY_q_5gLC[A#r<jB+,m'G"j%#2K=F^94E'ZLtRodD/\DL!rl#oAIsf
	7jf":rak>D2baI1qJ&`41!<a,=i_0#6>SO;+O/jjq'jmI,in8kdGEc''ImPV3KM".2<GTl?VLH[I(S
	"$<[BpU3,\[pleo;SQe?A"h3tW4uNFl6ig*a6pecC`K$'<O$<.=l=DjMq0\(%$\ud]BTfI"'h_1Ui&
	5g)fP?rL`_EkI]rh@Y3_L*T(,H1#/:?U(g=O)_j^8%eH1@:aC]3"_FFTD.nT>TE5T=cLNSf&crqJqp
	K8(3hGSDfIqu%j^_]5=Jb)8P@MND=CVBF?-S?lOa/hbm/r>i8>><EfgP8eo;RIBKq&CNCP['n[.Ci:
	7j&u#HXAZ6mS$IXb=GYi6-8)kQ'IGIp]2i]IiR9=n'@EEkUB2CWd!0K@7ZW<G;VHQRGU*:D+dO)FAJ
	d5^\":Th`PH$o8QIL_@7M?%t!q(n'D3J_R*/'P!TJ0"4+e1M_+V56B#SStt!/!U3bi8H)@ni%gA13P
	ZH\^>tI<p?Rj8:,4hqG_)011k(l`#9lIGYuSU@Zo.%0D\.S^sJt,/U1qhSSbK0>[B9Wp+NW['TLE9Q
	0;t%2pB1@k*RC'dPUK4^f(W"(n=IB[g3R,^>k^CU=/BbK:0d?j'jL+Cl&"qj^+9oW5Vg]<q/um6KDJ
	rnWX@%mRXMI$?@`BtCpiF$XNt]$+b7W8o"f7KC7mL?Si\PG@H9Y5/DY7$Z;Z:=#GIaOD7D,c`am!8t
	qs!UG";/k"l>d8MI2;1EQTd]hUj!WYRM*$_+&b-G?9%aM/2h'j6eD2^ZS-Hig>o5lUV0p0f"J,l-[Y
	T]\G_C,m6#SSpBi23&@kCls&N=rY0I5$*@K<pmsO02gfkg`b.5471L<pn91+%8VP9fN(8dWR]b7FiC
	)HIauKit>g)?<R<j2_sC*C$:9@m)'e>Y@$&!G(&:P%ZM#XhF4Q39u//i/8.K'&?6S$A'eU8JO-8q-I
	r?S`6@hanl=AO/XW=QUkmh3%+o\6ke;J,&L'LdGj`NeH4.V`%mHBCfm#VSdknKc20LaC(o'1b=$$A<
	[\Vh_9_/&;s0s.q+\BBAZP`?">4:6,7gcU8`oqel^'jWthV3PYf>"cBKt8E(i*/.a1@W!kct0nbe*U
	P3gtFu;r(CBXG.r&>'btH"d78)Pjb-2LT#-Z3-qpNX323FQRYe[r6pQZQ1Lol;GjXmL:+3>"b<3S/m
	2b*;52&5Uo4OMWKfd"/NhNB;3E,Pt-/ICcj\\d4MA8T^c`<q'7Bto5O`XR"_ekt#aGPTT/spR*j34.
	qf8osd5<h]<1:1-.+L,=V(EoXHrkPj.Jfp!XH"&cj<B25mTrJfZ;(;o/JJenAoDP],H_;nF^B'oO`$
	#E%g=\88IeBQ9j)Nn`)]KaA\PB.h>T?XN@Z9-D;1U(<KU]*UIVVa!7lnY!d'odtb2k//laK,cUgrF/
	,,-IeK0Y"87jAii#9irDg#(J*FU^_N@Z8#Wm>hT'c\n&gZ`k8Ze&ELSLlrUG(aU0\*kUg34keU4*&%
	`=aDG@"+\?o^,qW6G(aVV90Ob%:+$u-\IGq`aPE-e7eH@KiS+3;cp?C//s-+Rc=#6<qaKdA?HVHc"]
	FClt[Zp,\jni21D`$66ZX.!bi2-J4hd(^!Mfs*f!EG,;6%!2IN1Ui`%*/]?5u]&BDBM?cNrFoD1hm2
	d5F&h.n,CntB1!C?Z=,sHo#("-p!0F+R\n:K5pF.X/PB.KN*m2+V1o=D4Y;T'20CEdlOdp/efVI1`?
	5^!&0j[H5"VP[&iLr&Ts#.%XFqk?me35f")7B^8;ITV&A<V:db_uIEUc_jl;f)B#PQlE1mJC;hRo&T
	4*iCAG+h@*!jXQa&<q,()#XAN4?Q@Y)?u0."?]2DpQEp%AWm@*qW`d<J%\ugS0;(*,]/@H2n+;99>5
	kgh_s+DN00")#m!mB:2EI;9NB.8B=7"^K;GfW!=t^6'ADIX,&0J:0C,#O9D\h$Dk+B\ZF^g]Wduc&'
	9O#]d2a^h/KqiH:e1R1SU*Pk8d?3+SBkPfjV8R6Bsi/(Ye%Oa5Q]!W2pO:4XGmN7+Za=A<S+RH[u86
	:NO;qi+FCiQb:>Ga+AG8NeasCT`[HrqBVd8[b[q(#g/M3R3KI4!#Y-PlRM5bs(]nI:pNi1O*FXaBM(
	!D[(hR!a,LV;YK^Nj8hump5k?MCJ,haAq[K%BDp?&DoaLiZchteTi.duL>QS2[.iG`NFIK&$mZVMBu
	4Yk-B)I]$,7ZQHIc,jmR)n3;@X6[?=iWUV^CLrI1$)JCnNmp%f=A#>.nBLdY"!oi1L?Q0b>G1joI93
	)uWu?eM#RES4=&s_:S)L^Q'SR41o44BZm>T?$K7a9&PY%$@>o&>+X:Qt+;-$hc.#m&e&P)6*-a3H6a
	%&:p5c_GYR8J$BjpW9VKSY:(P!j9'drh9H?&aJ.UA>$t)[%:hAh\fbj9+!g<Wo_B\?C9-WYL@;`;,D
	;$ka5cbMBiCN>$(Oe/6j`7:NISHH#(_(Crb*cpe"$kFB]#EH"omcT_:qR:UN(m<B+Vl[u+,QnJ"hI0
	6:#TN5^ur2o_1f%*H&8A+]!8p"%[M[SkPfH>:-.an/1KGFcrd+<!/R&'9#H:&&1r8,d#FS8'9;))HU
	'\XH0@?GdY5*GfjF#e+8d_-sW6.GYcQfn1pX&i.1BpBGoU_^?nefq>-+lVW*#G3C.6;_9N_XTGfN'<
	3`dhsjA/0"aRD*[=7aJIXa"HXLtUZka#)ZZAcK@[q]CTTejlW;:N6OeRYa=INu*icUo:EgrcUT@#=5
	(NU"NM(apXCVB&o0e\.@r.X!Go-\Xa6BBnKf[Hd'3:"@lGE&5"#E<(9m3Q!5Z<!jU:GA`XC:C/npV8
	Rp(%#W6*Bl/9dokf+;*,..RR?[b=Y=#,#B\\TTl*r4_BLmS$5ML2C<td!!%^DJ?_I9[/^M2^HWtfcO
	l,aec:+fXi8VY8egKbj?"6Te']p)G'/(u6PL-/2&&%a2Vs.rjgJU\`&g\T-OGJdgY*Yd41&^4mnjiR
	SU9]R0?/Go-74$C(F2D2#f'!,ZrTY3@li3tZ:P-BM-7N>aW!rB$#'hS4p$X?$E\1\jlb3tI-E*2'LK
	mJ[9h@m4F6%Y,bADgE1]\3Md\k=PUO?Y[&J4l[U4Gg9kKiF):C?Y]TXmP]R2p8HW*@.)/mtk!+&m`G
	i>(__6\3CJm\m@PjOs4cL,QbJluJ%fV!bG7_+\NdQ!l;?j$n5"g;<RFZ!#7>d-KW@l5nM2E+D^*s1\
	WnLi6fgGJ0YZmN%lSqHm0Ok'D/n8g04&jZO!#XfuZ>N:@HJs,?M[4iLRF#fd?,U,RNcGBa51V\A(do
	V"Y%sEA*<iMrhk:V5^lOX!B^IhSZ!Z<(IN%mk2O=mt,.>(665DMNJ$Bgp2J_3U2cC^B?TMh_1+DAT$
	$n5ncPFtWrmbGA9Su[29R3H4LFs3L'GMdYO#Yi/n5nF/"3h;#lS-+iYU(@N4Q$9Z#q=SZ:J#oCI$#,
	ipJR(Ldc_$aQGLJJ='b81F`Sq]+9HJ]EE)>%QJQe%(eK93E^%p7UG]K[]#3@+k9p(OC.OYT+OVk<Dc
	=^!8>?p_k[k9.]9W<_P1/)d.I1g&AJmtN.o<NE^k_&u&9V/,SC]k?G;[i.O@nkC6\h%7.?l5+n,\T$
	Z$?P1&(IjHKEi1L!Y5lG`UkQpH%$D4L2Tpr!io=]5h>b_a/VbZE@6Cj[9@'HlG\L@R6SW<Z`@/lfBT
	,KEo#=mQ\i3_Tqs:Yu@jB!?5B/$m+J[=t>l2=dZHQ2]HV(*!BqmYD3n\892_O`pH"K:K'gogM)LVM2
	456t;U^sd_f/7W*#\:?N5-u;XQ6i(\*mEs'oc&5GE9LTRLscl,Q\)NO0td(=a]"$J\N3c&!bUS?YLd
	.Vp,@l4J)t/H?GXFf`ESh@rjVpf_gh^Tc*)T$I'C48:6fln.Q&X\Z"M%?"O`l$RaLuN)'psRA6DArD
	;4<ka)<VN]4)o$-7VDO%['t11lW$,&BK_=ZR1tI<)&Zi[<EXAVmpg@,8)1_XUCDMM4HF;7>/RiU0_j
	8n])\uplQE']lg5)C\6"()a#O4\Csg/ddckdS*ugEK;<?2j^al/#7JG_1tbsAAkqbm8I>NO!\l+ALb
	[5dYY'hW9-D<&Ki0DH$NX]^:Cu_8;At'0g4mg&8a1ftEG^!D5([;VMn5pkIumIH=I7+'[1+0:"Jlg,
	[%XVeGqVmT[V^6_M\spiL8mq1A.mToS*[uq>Zk[&BWVS<0dokW8X9&0fsAXRcWp8=2t)VDeTDJc@`8
	8*4'R4+rK%!<05ggJLPrLlTUPU7'Eeag3ZgLTTiPA=%9K0N@[gZFhI+Q;HhYe:DuB6?Aq+W#(S+25A
	O`LETpiU%AS+;!P;87C6l&1-:<=%p(Z3Q4'j\VVM-qQA`_k<N`ao1s&!kLP6X@:;:3)O86"7)k6Q8K
	,m/GDKg[F6`6_R+OIdVeJ]29L$8qaXt6o9,e>"kh>Lp!c*M2afOOTHd?r:,/^Hcq/-b/Q+ciRlO(\n
	_sX:ho7;KDD>O'+M>^etfsN]QHs+grh47!%@3$Y*+lX_Np_qhcHg@4?U?iB`W_fR!"i<`8Hps(*7fj
	QBk-3*j#tS&VKeO=thX8>^61OoABPUH02)YjlO13*-F/R_`QJi5Q:KR#=#s"2h,VG?X%SOhTVgaS(-
	YNY;EiWV3=3NqVkH(;Dtc\'BfVg5.P\1-bm#mH`LP#%%9UXnE&'Vp)W$ISW:C)nGq`]N5(uhd@J9)m
	Z#;03em+;s8GfCn]N$Qq!VSgc"i)]qr=6\Wgn2^="ETfNM\!II;fI=HV;A)7'j=AiS!B!QQBnD@AQP
	_6;YNH4;mD3,.hV1-2i95>`:BpQ5Fd`D1;?<qk7h$TLf>.:[1gXk[\H\@!:f4i6fa8YW!eH-mg]emT
	/e)dW;*X)LU%Fd"rMO$'8[H9D!TirUa.C5L;S4Ua/NHiF<>9Q1Mt[Me-WQ"t.V[KN\aLK\"+&@l"ts
	#L6]PfDekE_Xlg(E3FD@ZBkfSQ^@u$[W[,p_spNOK%E1gEQtd4Li".qUhS>e<]\!7Ie_"G\H+E7%Ip
	Mli:^2om:P=).c@<E6=<lK[YjFFF/TG>Y%q+)pKW&oGGr*Ql/[(WLtG_XE;9l;4SPCb54OW!@+5jj>
	D[FQ3:T2:9%$jU9qmes5/2Q[=&p3u6m-pI_8Rdn<,:e/.SuoLq,"tWfPl'5NX/Cr_O7fR3##jH678=
	&86TH2L,=Np@-!-A<b5e\;!hqX?+lsbSscFTQ'`^Hf5^N@LY9?).14@)S`m"+5SQs%XVt,fEqB(>%u
	Y^K>qh(loYGqC(Q3tp*l57\.3WK/d6IhF8Pl7ZM6ZXA&7Hs4i9;UZJ,#SN9/"SVQOY<VCK@e&]Q7/S
	Wr0i^n,D5M`SEW=[F.c4/#T&)YLu7"fjO4<,=_d)&2jGldT^DFh)F2nG4u\tk8LI&@]>\ASLThk^%Z
	Bu[VbmpEn9]Q'nJ=mm^hj!Bc?p-gr?0DI\BLc,\j]pOq2nG3"W=21,_OL[Wurg]m'#]<Up+i)GWjl5
	u^k=Q>PZJQd!>Xna^FO-:D6R0]X@"\"(dQ5(l2Z'rWqSUGEjNQoYGuFS=_iX,fE,pTj5A\gHBaD,1;
	NJ9hWsc>N7q\Pa6C6SK_-g=1=)larXCF/kGA.3jt+@t?oBL\ni7U]'99K',6'$<AlV-k<Cb)EdRuQ'
	m@lCRZUVE[6ZGTHKM8X3!><VMY0%8,_YHQbN2aUG"jDgX!$ha2djH9@uL73h"R%r:\_!I_U?pSP)FZ
	k\!f<6<WW]?e`ep]hnHX'3$S,[!i<TH/mKJ`iX]STeR<,]68WcksTJrJPJU:l[/[0B<-nlO9:&4i4?
	K55QE;-@opL7V:a*?\%TaHg.NZ1Zt^?s@o1NIDV^]:]a^EC7]h(69>sh**iii&"G9lECc/[;mi==\d
	#pp2Lqr5AR[P?9P18PcUSS@a%YL:-Jj-g*FoBT&"a"e;H9WD1%pj@Q^=S*m;GpUu>9A;*-duCr]l,>
	SJm_D1(Cjf%oB<S@o7P`C6&HLgS.b+HNAJmED)Ts;&Kuio1p\M/p>@I]>o$qe!l1Dk0ZJ*AiQB-)5P
	TQpXY5_gXkun(=CYXfkB25c;BPku=1A5+5H,1M5?gkfFf>s'U03fP\I/ek5/1n).d^521;L8u&)M_9
	mHlP/@9K@dL\h<%-TN=#g0UtLom02mr*CfldH@]:pM>Jg,VR=Zo)<#N&/V@g[&lraB\(\?o)Z\S#<L
	L=Ffk5I*;*CJqW7(kX&C4_f^YKFJ5[I&dK,S[@[I<1&U[N:kN0?jFe5AU<Ds+Zc=YQ&)7tbj]D"l.V
	9Q+7cD7h]g^\Ye(b['G;iman[r?XM9Q]SM1r@=j`1h-]Dgr>$h]0'JM6++U.lo.8\pSMifOJeQS4@%
	mD<kKf6'I)^I,eK_X[aHn7*ea>7u(*Xc($ukkkRIB_r@^M:<oKb)t_:S&7lY+=fk'agUFBdhuBs,q:
	?EC/6ck@.uf9>)]N/`nm:1R"p8Ki37iB!q"6T"CEN94e"j-:K>,WofVRCI>&3^lLSF!3d_BFnn:V7g
	k2[`=+hf4u9,tfGSN!4%gLbZ"&I%(!gaEJA(japAH`t0nANdPFn_uLB_%0f+A8"];["T&+6"E8k,#L
	I>;KTt08WBV]*uU>%3[puuh7Hn_j5Yj0n3eCQ^sM0Y;`B1?;I)2ohWS?NlF"#i^](XO^cVb?'&2R4P
	O!Sa]Sk;k95r0&S'^1T^NOJnmKY7"pCY*"P32X4FS1d&J+s9>^r8$sBR>>s<.`iJ6L,(PAgt-%RMr;
	j;);&98%g&bHZNN=='$LDDu\'<s8B\QIcFYmosHrPbb>M?H6u1-m>[[Or2[a8oJbJ$0M.rmGap2Td"
	;l.B7I.VkW5uiIb<67RVM;(5ANIZE372.o>?Y\*F'Ck-mC/l.hKS4aKAN`Y<_P/0`V2%?j&-R^"@^S
	_sboL0/l,j#_[hG.(7;eCX_S<j];[u46d:4^:V)NbVMaISX[Pra/n\oINnSMbm*T9K*7i*QIf'#e<:
	O"&16N6`pI_%;$&,!#SP7m7F-dgOV3rC,j/LKJ)Ps4bElqM!7pe+jGZg!]MGS2-B3N`m6#/6[<o.C3
	H#gi'GGPcWT=!QMr4I8FnP#Z09/U/SWHEo9FF+2lA]Ze98ReMO[51&<PkmJY4YY,:rbUW*fTmZ@gh2
	nf%M5E.s^^Um4@)e/i!'9P2"`\T7$Z/maFt<B$RQ^fZWR&dMJMo4Rq($ZsMe.R_a),IcZia5Q3Cm\A
	"K3V*Rn.FCmUG=WSP&prVUk##0KRWfkHF.IPl;Z3KsH[2Z=Im,c@7raKg(RWe_p+NnUdL3;\;h2g^%
	^+JAj+Bo:EFQ$,3&k=tq6om'X=%kXfT#19s7S?8"&V/EcE-\u2-&`3m*=B3D]0dnkh<I1D&]`?K19I
	e0Ta--H5Sb-b\[2/Wo,+_%rHXt#mb>YX70u?+7;Q"-Gk5h!\P+Gbn0l+m0>7/JY89tt2&Ru^\Tm%A_
	r;k>50OqsU8h$^U.VBl_uY[EKW$bj!j/l=M%b<Q1`7k@LE9atcbHs[?iI&#ek>lZ/%;7B\Mb+'Mm2g
	DY=D+3`>DR5_<UC'$O^<fW``QYi?hqpgFF<FO:OOFr6m1lrkS[e.iDc>:g%Sg[e8L$IUE,&W(qSfM?
	/6]5i@;ZAo4QRm-0kNr6"\.^t@har2"/8TTOO?mHr.orpCm,k0Cg5'[E7tm(;-q/*"^B)PWcN1)*[M
	\9&WHdd;T5r0`2,[m#9@KCcE!DZWF"[%6"+b+bDP\Xuh;V\#3qE$ktd//@Y^@AFsS0^WMjk\34nGBE
	c^#C9mr5T$(q9h"%h2icdB?]W5rAe)fI)I.[\Z)+Y;FHe+NTR`,8=\=t[Pubo%NAsn[>*TpZ)MetC,
	"+_-&O8%i\0+`5VZ8/T=ldP3=,2\!/1KKRTY5\r3+ihPmu99X^\P"-5:hYO>idQ>IdtP'POIphrs-#
	OD/D8c(bAJsn,DZTHi%$JUJXgk'E<5.=InQjmk$'>^\aZ&7puF1"CVI#!2;p#M^4$X<emB;*:.O'`L
	@)SYWrS#qtiU+q=`-`.GiBk]COC.QbW9%lrb9$-J22d+oif0Yspu=M5-/M(BZo:bX/7Gh0SCB5<L$!
	LtFOY8CCf+b:e9d;WO)t,_VlpM,/O(@rS)k8H_<u4W4_;iV_WL*ZZW1[kZIqCj18/f4C]+8s4%@s2W
	C]f3gL.L;e"cjm(9Hht^#jl,&Q\*[0&lf,D>TVFa'OK>+Lq"Ro0V=3TTnGY]l^6GnA,OA_l2&-g(GY
	S7S(2T*ARV2H-2]kWn#p6t.(q(-mRTaT1/-,ZG&P%b>GmflDm`N[+]]R2Q(m;MHELB<a?I=6>6pquF
	8LsgVC4H3dNou\)CC<p^\MU[LO)[W+U@R^JC5&D9]/kdBS@^25DlhL865Pr?P?LlR;r:876Z^/'!i>
	:7`H<J;>XKA%Ck/g9Rqr;[b`4QV>ME>*_pM.:KMuXaWZlb#&!0P'/Bp*,iU/f?^c:t%-^klduM%`iV
	!2Qc_-5$p474/?Xq8bQZl6fXc*kq<UMLHdC22B(FD]Lc2NZ(kTH2[,-#dLTI'leBlb1FA5qY[Z5XXl
	`r4T_p-WiF&E7U'u?C5k!WC)\7#Sn^Tfa>UA'd_Lu.F7?!A-r#R##SFJcP,`o6:gCSJc^`s8B@Fc9P
	t)lJcCR0E'VuLAc!aBj)3-=uj6INP_;3sDm_&PEW2eJ@@PqW\^lX)t(s#lB)NFUlIREaScRKq@J:OS
	.%tb'?%*3BiebPWl@;V</^%-kIY&5=la3Et9h]2Uef@a])N;>'N5MlFc2uJpK]9SK+^eqE<G.^D(8<
	,qHC]r`r*l'5F`[`a"]m03brRST9jU;H"%RbPNiRA%]!CR*CE2"YTW3$L\"&U"^^MQoMmDX.gg%FKH
	%)@eP1hAZ#S`#8^Ttd,a*#4m0CRg2Bqt/nb^A?s%K"5r\9'a'!9k;Mq;NbSKj72mM6j=$W'Nulh?f\
	roIPq@d.SDR]Y[JUo#7hM+)TCXJ"/Mr>G9e.F6CY"<SiPEkq$74WV$lWe/!D<[6n7doc!f`0kP@)N7
	\aqie(sD.4"D-=1^[H&!AVplFCW3@/TmMlh_S5(:0[D<R8oiK%bBA(XL&@n47hM(US6$)+9,^J!B0[
	Q%ZWJK(H625J*\Xi3:l\1hW!HE[oMG#QCp:EQ]N>s$<p5bL^Ak>7HjAGL10"fIeip;msaS9J#@!m<n
	kDb`sO-uCFKu^VL_":1(][`%KnLSQYNX.XjbKDFIn[^Ds>Cjp"U?Bn(aHSN/](bZJ[b"h1ah4PpBGt
	JI!H)3-,SVI/&?/Z[%%9GGh#RK/UWdiPOmFBJc/"9g8CJHBr)^m]>#t2<"+(1HsO-IFi$*q59f=$U^
	+^a3hqXUkuH4"V902*l%lOU'<#bE6b/<eo@QD]4hZt8p_dlY]7'L[!)/eKg5BCf\2blnAdVo^7hrOR
	Mlq:VQFY97Y<Tnn3N0be\Q\7*H)F0%d4cJM+EQCkh-',,c.A=-Ae<EOEtX9jS-B4rC=VKpY,:+@Wu<
	A;Yi?@]`6tm?<D+.Mf':?NfU>kP'X#m'ALMa[>7q%l<ZCHlEd2ARr.#qZ?l5iY?n!a8Tf7t?"6>edl
	,5:/iPqM8Rg!+!:Tn64hC:%&-%+YqIWS=l]439G4BtG*GW!n[K_$.*u(_^5iWlj@*^b&C1dd"N&is/
	>bje#\XCqPYJ(n?Q6DDkB@C>Q5Q%JYlbBogCT9im?IB1G<`\T_k$qnWBLV6uY4iJr&Ls4]+^u'DU3u
	`;s%dQMBs>%IH<G/p!KF32QfYoG#;5C[DU(W%\F`%+Af\5["K5Ol9]g]6)TX$YZheo-Ti>kkF@e(Y@
	,AQm^\l&+X%UcfZ0:B8E,\c7D28K$Mg"5jl,&.B<SilmHbko-5%2]%0l%LM6iiF6F;+ii!e<[QA895
	pi"$)/7t]nV4Rsco_b[FBI.E-;l\e:"_l^&c\)3U#fR*(^Yd:+IH#+tiW&5/!1[GtVlIj,oa6AAO*$
	iN&04(@B1"J30qR,@9;(jk&+Rc^4Uil(mmd.Edof%(2Dr)=)B/2J`a4iO[ZZXfm[F(A/R#kKP(i#Zq
	%bI>%ltjH*2RfMt!Q_T(NK_HC>RQ_hHThSq,9BismW6</Ef<kZ&oL.V>2-6\cI"5`\9)J9HZH+LI.B
	gUFAgCqB=m:cf89a$`gJ+.ZH5sD[>OYo7pp2q]MbbrB<eG:l'+/*'TC8[6-7Bj_387'Ouo-&S+"RkD
	!g[la&Ca"L<0)Z1sJB*fk=`gFeV=(e66S"+9WBHd)&=N.je`l+rYun&QIq0c[m^*0T`F_kWC:8]=<*
	"eMb`TBsuIYT.=-UZa98P=.7%+C`f0=P6@UnN1bP$"sMEo14tXrkIWh<h.nM+%BjWK`j:P:59"mlb:
	jL0bUA<o*aKH7dHqru3,9#u$S\#K<E8+-k#b4dKVB/o_]\QG=b&U*:[W[hYV([QOQ?XR,R/*:OU`?;
	[8LZ_7H*I);G*Y2`YbPAV?%52V3TTR!^Q5a.=JBf5-YS6TZ@9U?TJ\4#fI2eogP8ch=7kU'dk7sV3>
	WMHDOS*cXPX<$igj/7hf`UN8f&B%tF3ZWS2E)CEbUeDchO`YlHJMejAAki*_p)otfqE]+D)6`B^!p&
	5]XoW"j%Ia3:8QTM_"'U19,f5Y,(VOdcZ4-;W,FMs874d8>^_QW81gQ9U`F7?&&uWN(@8[J+(2a`9g
	21u?KGqTd[.Vk<b=>;TMd<[efm":'a8U5*U$s0&\Kqj#qrcM1I@h+_oLBBJ"CE[4fRPmf*>C^GC.6h
	4:_a<-TKaFj(r-U7_\0k.>]eR_h1m[cSN\St)_=&g;$F6"H5TQt2^o=u5eOY^Ntp&2T5.4CKBKQ^D\
	M!_Db2I2E/RT\Z5j2eWE<pQVsLLCT@.4&gI6tAG=S$f.b3X0JeFW?Y[#`(h%DCn1+0a^STcfRPZG'+
	gm")OdN[ZHMt(829P1X'9rh8rn8"cPq;ZRUu'im_pXd&nI#Q%kg8CD5aF]p(_J"u_,G=CQ:!U9*%l$
	pNNa,P,X"12N:I')#dL\V=8%>E>fOK64O=,*,*r,SFj5F(.sXVn`QN,*`-YmX$R<P:;`kR(=)D''"<
	-^4X;,H$aaT[%q"'p](0AGJEu36[-`LgQsQliqiG+gU]B@IOq6P<V30UQ;,s8?I$;-3up4S:<Rs4]^
	0P(!c^%'`!*"Pe9J[kW[+:<lM4:UcSh-!h5Y8Fed4s;;:Ns0GIsQ@`ThQRS1fmX8o[<U,9:f#0EX_?
	?#pA6DM;@R:CA:+%*TK>J?lDiB-u+cn%(&:9Ed+/-W8n7,rDUk-p8;?*"4.V;8(qMU,5lEh"soG+>Z
	A+:a3q\$_("L%?$Qm'Mubrgan8/#9@ifU^A7RPU"-NdmhM/OHV\jZ^a"bUtCJj*MP0>R8\,5Th;Bg.
	1q+3-\G?;$WY?[=E0;FOeU>J1&+Td!ii8;SppD/:X:(%O86;gp%$?d?[_n0djO\UA*gX25Q?%N]=Ks
	b5CN)456$Ffo:,,c^\[*Mro43k4?rha?iB*V?[VSAJ+L.U$?r!j'4^P^N,@C1e`5-==VFTg\S*t8r:
	Rg2^&7lhW5Zm<bI<gNml^I)K:a%Nc-$oif@ShdQ+;ciK5ZCS8<:8?R['S.WPhos"-KTr=IC51Kfi0S
	@7D[lel=.D6&!G8>(h^MX;!R:KFgKV)ca*'Fr5n6DX6]$:`brXoOBmQ4@mVWBia>cZV],XRf[_1eKc
	Ca`Y)C2>/)"=o!K0<Upc?p]?KWEYBN"YBmAfMrolrDi4O^[1>,bT`W-W=!/HDaHMM0\?Jhl.)k[JI=
	`Gg.E(TCa"^X#F8R`>hpE\_km:B`kRElX7FM#@c![q]`RTZYk5tfgP7<>#eB6E*4h9Fc2@<)2+Mf*r
	I`#%m6T:DJMo0<6F<"eU[0i#o;=<,HRaOr)O^mL[`_!k_2n4t]es2@c`p-C`Shl^kB+$Or?nXkBs`U
	j+Yn[iGimp>]hDq]I<jeMVQjC:EG/XNN]S(70h(Jht(->%:m6<4(6Y>];8]3RX]_tj+\E?'/6hFsDN
	2OcS1=Y%A,0Qu8q(e-04h%n%$lS?\F(FKa=hn48`GBn6bS$/u5S#.&[99mdD4rB%5k3Z.S6(tWncJ:
	JJ3`?L3F\6qk4lRCOKF].frlN.Afo*J/hp'Km?JhpLkbNP!]q\@eX?ZT8s8;'3asi*S4grOW:tqBoU
	Bu`eFFDuIf!h^Ig-#[cZ0Y6*ZHG/,B/M1)7iFi'UdA4*,oirG<*%`gi3V*qe4gOc)N1R5#tYaBW""A
	pT0g<XIX^jtH[Qc`=L=U.kWnJ5d<q'X>?0d[G$rWiY-q$Kh;+V\iH2eYoe4'c]t+"3o3^"*=`7m-GD
	i=%;eJI];8$/pS(mXQL5I^X@i2K-TUi9YIIZ<T04XNth(0>"G!8ER%e&sBQ@*_!3Y'(#p%:!I:S'Zd
	a78H[C)D^$I"$NnN^o/W[cfbW?=(<jZWZ*i^&%HEdjHI4US#2WpYX<CT>10\X*NM`I.53u^:IOVa,B
	*E;f"DM55W7+>@1W?*'J\*mI',kml#C!9i\Sqh;,71RoO1Oa^9P/puLJ)^\d-YB4$,[kpOea>ol6/\
	A!28]`2YFV/P>Yc1#%fVHp'El8@`u&?_3NK3#$mf5FaFFl.+.Mj(\M!?"CJMAh'iWe%6*S.tk)=u2U
	\as8mM^`tNNKI9f8!GPsN,34,.>#[Gh/1!(X=t,UQ3@c<^$3O$+Lp7QgJ7(A)/aB,MUG/3cb$`AN8o
	`^U3,WLN_Ho*k*jI(Y-Q(nU@&F6VbPq`6rVnNo%pkcBP^W!74+aatVPOA@2Ep2&@^6ILS.D5U/Rb(b
	P+mm0Ic3nDd+KsGSLfp9`t5i)q^>s1&Rd[4\SX^U%-oH@FgRY@#^ICIQROm^o/Q[K)E9YFO+B:9:tG
	Rs,1tT:K12ZtB/V`.Vr]uOQjgg)?ue/E+Y/MgTs2r$P"3t'H"I7'cKlstR5$H(@1s6lPZZW2+AOCr'
	FY%$"0eeM3;CK?oCb"8PPd<Ni:l`RK<Xhm%CL\s<%p$_[`k8\*))B+HXm80aYbsCH!:##O-=l4[b']
	>*m70\$[>mD'%BcIF+R;?7jX+1"U62Pc.RZRThHFUM310`Wg".M(h95#3*+i/?-*rk38a&a7OV-!X`
	/93=JEKkh8C[nN&kZ];;R4)5nORJ!'o<J-@Uc,5+L<;mg!GPM"(U;\dpE_f"e.4hY/Pg?Od;U_DV`]
	i#KoNg^O7D$1A>brL3B8pMs&Sr6_>bB*6ps;f3+#gdn?6(cbuCRQ-W1>ZE#?ka'?k(bfs>OgmKH.Qh
	jW9ZS+u1)GJ317?&<Wl7rJ%%aM]P,B0T'h9V^\K;A2KM\?l?<#agO?!p20K(492Q+EViCn.M;`rC%^
	)Os!-@eCI$-pQ>]M(m2PIYE@S4q^G0K.ZEpu0$0AG5mFgb7%r0JE1fp,&$[-nA(0(;pen[`>?F0KRk
	>bSar1#+:#[qs>Ie_Uqut%!.3?%e-!:pXS4b0^O3d;hY`UoBCT@Cq@Oj;_,i:A;@kDO9&*W!*=a`0u
	KE['Uode:-g)S!Fu4K9Uqi%W/Vo2lO+GdA%$)pfbgKO`fe;3+\HQ-\UC?-2`>.9abjk1&6)KA"tGiW
	,)<<q;)$aQ/36-!Ya[EQk37@!A.t$JLlM,8/cnf_&HTgE*JIq]U4lEqs0!X6F0o<t[XF+3:!"6tX?X
	9qi^SYVB``\OW8624J]UFRKA"@Kp-]GHq^7X0Z7HQr9#66+E,mZ9JpK(<NB.X\+h1'R&Z0->@]YC&a
	IXn&K86Ia-<+A@'NpM1/5kt"A?[/7pWd(p2)-^oKkt:S:VjEe<#0W\Ri?;Xm$669p3A`Ckh:^+iJp6
	ZHX7_t!seI^ZQnno7<Z2>^qQH5]g[]R-=d>'j>7*,Y"esr!J3AKBOZ,^0`(FeNuQ?'%%mo>4E5;:((
	meB*h((R;iS\O8L+74SZm='_8p$jH+G(PRlE$<+:X?'*@qCq,%4n(@3P6i`o8Jn=o<aLN+8&Q)p,A+
	z8OZBBY!QNJ
	ASCII85End
End

