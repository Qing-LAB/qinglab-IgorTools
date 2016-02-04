//	Copyright 2013-, Quan Qing, Nanoelectronics for Biophysics Lab, Arizona State University
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

#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "TableMonitorHook"
#include "WaveBrowser"

Menu "ITC18"
	"Init ITC Panel", ITC_Init()
	"Shutdown ITC", ITC_Quit()
	"Kill Notebook Log",ITC_KillNoteBookLog()
End

Function ITC_KillNoteBookLog()
	String nblist=""
	PROMPT nblist,"notebook list", popup WinList("ITCPanelLog*",";","WIN:16")
	DoPrompt "Please select the notebook to kill", nblist
	if(V_flag==0 && WinType(nblist)==5)
		KillWindow $nblist 
	endif
End

Constant ITC18TASK_TICK=1 //1/60 sec
StrConstant ITC18_PackageName="ITC18"
StrConstant ITC18_ExperimentInfoStrs="OperatorName;ExperimentTitle;DebugStr;TelegraphInfo"
StrConstant ITC18_ChnInfoWaves="ADC_Channel;DAC_Channel;ADC_DestFolder;ADC_DestWave;DAC_SrcFolder;DAC_SrcWave;ADCScaleUnit"

StrConstant ITC18_DataWaves="ADCData;DACData;SelectedADCChn;SelectedDACChn;TelegraphAssignment;ADCScaleFactor"
StrConstant ITC18_DataWavesInfo="ADCDataWavePath;DACDataWavePath"

StrConstant ITC18_AcquisitionSettingVars="SamplingRate;ContinuousRecording;RecordingLength;RecordingSize;BlockSize;LastIdleTicks"
StrConstant ITC18_AcquisitionControlVars="Status;RecordingNum;FIFOBegin;FIFOEnd;FIFOVirtualEnd;ADCDataPointer;SaveRecording;TelegraphGain;ChannelOnGainBinFlag"
StrConstant ITC18_BoardInfo="V_SecPerTick;MinSamplingTime;MaxSamplingTime;FIFOLength;NumberOfDacs;NumberOfAdcs"
Constant ITC18MaxBlockSize=16383
Constant ITC18MinRecordingLen=0.2 //minimal length of data in sec for continuous acquisitions
StrConstant ITC18_ADCChnDefault="DATAFOLDER=;WAVENAME=;TITLE=ADC#;TELEGRAPH=1;SCALEFACTOR=1;SCALEUNIT=V;FOLDERLABEL=Destination data folder;WAVELABEL=Destination wave;DEFAULTFOLDER=root:;DEFAULTWAVE=adc#;OPTIONS=0;DISABLE=0"
StrConstant ITC18_DACChnDefault="DATAFOLDER=;WAVENAME=;TITLE=DAC#;FOLDERLABEL=Source data folder;WAVELABEL=Source wave;DEFAULTFOLDER=;DEFAULTWAVE=;OPTIONS=3;DISABLE=0"

StrConstant ITC18_TelegraphList="_none_;#GAIN;#CSLOW;#FILTER;#MODE;"

Function /T ITC_setup_directory()
	String fPath=WBSetupPackageDir(ITC18_PackageName)
	if(strlen(fPath)<=0)
		abort "Cannot properly prepare ITC18 package data folder!"
	endif
	DFREF dfr=$fPath
		
	try	
		AbortOnValue WBPrepPackageStrs(fPath, ITC18_ExperimentInfoStrs)!=0, -100
		AbortOnValue WBPrepPackageWaves(fPath, ITC18_ChnInfoWaves, text=1)!=0, -110
		AbortOnValue WBPrepPackageWaves(fPath, ITC18_DataWaves)!=0, -120
		AbortOnValue WBPrepPackageWaves(fPath, ITC18_DataWavesInfo, text=1)!=0, -125
		AbortOnValue WBPrepPackageVars(fPath, ITC18_AcquisitionSettingVars)!=0, -130
		AbortOnValue WBPrepPackageVars(fPath, ITC18_AcquisitionControlVars)!=0, -140
		AbortOnValue WBPrepPackageVars(fPath, ITC18_BoardInfo)!=0, -150
	catch
		abort "error setting up ITC18 data folder."
	endtry
	
	return fPath
End


Function ITC_init()
	
	if(WinType("ITCPanel")==7)
		print "ITC Panel already initialized."
		return -1
	endif
	
	String fPath=ITC_setup_directory()
		
//TODO
	Variable error
	String errMsg=""
#if defined(LIHDEBUG)
	error=0
#else
	error=LIH_InitInterface(errMsg, 11)
	if(error!=0)
		DoAlert /T="Initialize failed" 0, "Initialization of the ITC18 failed with message: "+errMsg
		return -1
	endif
#endif
	
	String operatorname="unknown", experimenttitle="unknown"
	PROMPT operatorname, "Operator Name"
	PROMPT experimenttitle, "Experiment title"
	DoPrompt "Start experiment", operatorname, experimenttitle
	if(V_Flag!=0)
		print "experiment cancelled."
		return -1
	endif
	
	SVAR opname=$WBPkgGetName(fPath, "OperatorName")
	SVAR exptitle=$WBPkgGetName(fPath, "ExperimentTitle")
	SVAR debugstr=$WBPkgGetName(fPath, "DebugStr")
	NVAR taskstatus=$WBPkgGetName(fPath, "Status")
	NVAR recordnum=$WBPkgGetName(fPath, "RecordingNum")
	NVAR samplingrate=$WBPkgGetName(fPath, "SamplingRate")
	NVAR recordinglen=$WBPkgGetName(fPath, "RecordingLength")
	NVAR continuous=$WBPkgGetName(fPath, "ContinuousRecording")
	NVAR saverecording=$WBPkgGetName(fPath, "SaveRecording")
	
	opname=operatorname
	exptitle=experimenttitle
	taskstatus=0 //idle
	samplingrate=10000
	recordnum=0
	recordinglen=ITC18MinRecordingLen
	continuous=0
	saverecording=0

	//"V_SecPerTick;MinSamplingTime;MaxSamplingTime;FIFOLength;NumberOfDacs;NumberOfAdcs"	
	Variable v0,v1,v2,v3,v4,v5
	NVAR V_SecPerTick=$WBPkgGetName(fPath, "V_SecPerTick")
	NVAR MinSamplingTime=$WBPkgGetName(fPath, "MinSamplingTime")
	NVAR MaxSamplingTime=$WBPkgGetName(fPath, "MaxSamplingTime")
	NVAR FIFOLength=$WBPkgGetName(fPath, "FIFOLength")
	NVAR NumberOfDacs=$WBPkgGetName(fPath, "NumberOfDacs")
	NVAR NumberOfAdcs=$WBPkgGetName(fPath, "NumberOfAdcs")

#if defined(LIHDEBUG)
	v0=1e-6; v1=1e-5;v2=20;v3=16384;v4=8;v5=4;
#else
	LIH_GetBoardInfo (v0,v1,v2,v3,v4,v5)
#endif

	V_SecPerTick=v0
	MinSamplingTime=v1
	MaxSamplingTime=v2
	FIFOLength=v3
	NumberOfDacs=v4
	NumberOfAdcs=v5
	
	String telegraphassignment=WBPkgGetName(fPath, "TelegraphAssignment")
	String adcscalefactor=WBPkgGetName(fPath, "ADCScaleFactor")
	String adcscaleunit=WBPkgGetName(fPath, "ADCScaleUnit")
	
	Make /O /D /N=(ItemsInList(ITC18_TelegraphList)-1) $telegraphassignment=-1; AbortOnRTE
	Make /O /D /N=8 $adcscalefactor=1; AbortOnRTE
	Make /O /T /N=8 $adcscaleunit="V"; AbortOnRTE

	NVAR chnongainbinflag=$WBPkgGetName(fPath, "ChannelOnGainBinFlag"); AbortOnRTE
	chnongainbinflag=0
	
	NewPanel /N=ITCPanel /K=2 /W=(50,50,730,500) as "(ITCPanel) Experiment : "+exptitle
	ModifyPanel /W=ITCPanel fixedSize=1,noedit=1
	SetVariable itc_sv_opname win=ITCPanel,title="Operator", pos={20,10},size={150,16},variable=opname,noedit=1
	SetVariable itc_sv_opname win=ITCPanel,valueColor=(0,0,65280)
	SetVariable itc_sv_opname win=ITCPanel,valueBackColor=(57344,65280,48896)
	
	Button itc_btn_recording win=ITCPanel,title="Start saving recording",pos={180,7}, fcolor=(0,65535,0),fsize=12,fstyle=0, size={140,22}
	Button itc_btn_recording win=ITCPanel,proc=itc_btnproc_saverecording,userdata(status)="0",disable=2
	SetVariable itc_sv_recordnum win=ITCPanel,title="#",pos={320, 10},size={100,16},limits={0,inf,0},variable=recordnum,noedit=1,fstyle=1,disable=2
	SetVariable itc_sv_recordnum win=ITCPanel,frame=0,valueColor=(65280,0,0)
	
	SetVariable itc_sv_samplingrate win=ITCPanel,title="Sampling Rate",pos={520, 10},size={150,16},format="%.3W1PHz",limits={1/MaxSamplingTime,1/MinSamplingTime,0},variable=samplingrate
	SetVariable itc_sv_recordinglen win=ITCPanel,title="Recording length (sec)",pos={520,30},size={150,16},limits={ITC18MinRecordingLen,inf,0},variable=recordinglen
		
	Button itc_btn_start win=ITCPanel,title="Start Acquisition",pos={420,8},size={100,40},fcolor=(0,65535,0),proc=itc_btnproc_startacq,userdata(status)="0"
	SetVariable itc_sv_note win=ITCPanel,title="Quick notes",pos={20,30},size={390,16},value=_STR:"",proc=itc_quicknote
	
	GroupBox itc_grp_ADC win=ITCPanel,title="ADCs",pos={20,50},size={90,190}
	CheckBox itc_cb_adc0  win=ITCPanel,title="ADC0",pos={40,75},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "0")
	CheckBox itc_cb_adc1  win=ITCPanel,title="ADC1",pos={40,95},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "1")
	CheckBox itc_cb_adc2  win=ITCPanel,title="ADC2",pos={40,115},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "2")
	CheckBox itc_cb_adc3  win=ITCPanel,title="ADC3",pos={40,135},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "3")
	CheckBox itc_cb_adc4  win=ITCPanel,title="ADC4",pos={40,155},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "4")
	CheckBox itc_cb_adc5  win=ITCPanel,title="ADC5",pos={40,175},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "5")
	CheckBox itc_cb_adc6  win=ITCPanel,title="ADC6",pos={40,195},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "6")
	CheckBox itc_cb_adc7  win=ITCPanel,title="ADC7",pos={40,215},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_ADCChnDefault, "7")
	
	GroupBox itc_grp_DAC win=ITCPanel,title="DACs",pos={20,245},size={90,110}
	CheckBox itc_cb_dac0  win=ITCPanel,title="DAC0",pos={40,270},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_DACChnDefault, "0")
	CheckBox itc_cb_dac1  win=ITCPanel,title="DAC1",pos={40,290},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_DACChnDefault, "1")
	CheckBox itc_cb_dac2  win=ITCPanel,title="DAC2",pos={40,310},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_DACChnDefault, "2")
	CheckBox itc_cb_dac3  win=ITCPanel,title="DAC3",pos={40,330},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC18_DACChnDefault, "3")
	
	GroupBox itc_grp_rtdac win=ITCPanel,title="RealTime DACs (V)",pos={480, 60}, size={195,80}
	SetVariable itc_sv_rtdac0 win=ITCPanel, title="DAC0", pos={490, 80},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="0"
	SetVariable itc_sv_rtdac1 win=ITCPanel,title="DAC1", pos={580, 80},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="1"
	SetVariable itc_sv_rtdac2 win=ITCPanel,title="DAC2", pos={490, 100},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="2"
	SetVariable itc_sv_rtdac3 win=ITCPanel,title="DAC3", pos={580, 100},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="3"
	GroupBox itc_grp_rtadc win=ITCPanel,title="RealTime ADCs (V)", pos={480,140},size={195, 110}
	ValDisplay itc_vd_rtadc0 win=ITCPanel,title="ADC0",pos={485,160},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc1 win=ITCPanel,title="ADC1",pos={485,180},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc2 win=ITCPanel,title="ADC2",pos={485,200},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc3 win=ITCPanel,title="ADC3",pos={485,220},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc4 win=ITCPanel,title="ADC4",pos={580,160},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc5 win=ITCPanel,title="ADC5",pos={580,180},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc6 win=ITCPanel,title="ADC6",pos={580,200},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc7 win=ITCPanel,title="ADC7",pos={580,220},size={90,16},format="%8.6f",value=_NUM:0
	
	
	///TODO
	Button itc_btn_telegraph win=ITCPanel,title="Scale&Telegraph",pos={10,360},size={105,20},proc=itc_btnproc_telegraph
	Button itc_btn_setsealtest win=ITCPanel,title="Setup seal test",pos={10,380},size={105,20}, proc=itc_btnproc_sealtest
	Button itc_btn_displastrecord win=ITCPanel,title="Last recording",pos={10,400},size={105,20},proc=itc_btnproc_lastrecord
	Button itc_btn_updatedacdata win=ITCPanel,title="Update DAC",pos={10,420},size={105,20},proc=itc_btnproc_updatedacdata, disable=2
	
	Edit /HOST=ITCPanel /N=itc_tbl_adclist /W=(120, 60, 470, 265) as "ADC list" 
	Edit /HOST=ITCPanel /N=itc_tbl_daclist /W=(120, 270, 470, 410) as "DAC list"
	
	///TODO
	GroupBox itc_grp_status win=ITCPanel,title="",pos={120,415},size={550,30}
	debugstr=" "
	TitleBox itc_tb_debug win=ITCPanel,variable=debugstr,pos={130,419},fixedSize=1,frame=0,size={540,22},fColor=(32768,0,0)
	
	NewNotebook /F=1 /N=ITCPanelLog /HOST=ITCPanel /W=(480,250,670,410)
	Notebook ITCPanel#ITCPanelLog writeProtect=1,fSize=8
	String initmsg="ITCPanel initialized.\r"
	initmsg+="Experiment operator:"+opname+"\r"
	initmsg+="Experiment title:"+exptitle+"\r\r"
	initmsg+="ITC18 initialized with board information as following:\r\r"
	initmsg+="V_SecPerTick="+num2str(v0)+"\r"
	initmsg+="MinSamplingTime="+num2str(v1)+" sec\r"
	initmsg+="MaxSamplingTime="+num2str(v2)+" sec\r"
	initmsg+="MaxSamplingRate="+num2str(1/v1)+" Hz\r"
	initmsg+="MinSamplingRate="+num2str(1/v2)+" Hz\r"
	initmsg+="FIFOLength="+num2str(v3)+"\r"
	initmsg+="NumberOfDacs="+num2str(v4)+"\r"
	initmsg+="NumberOfAdcs="+num2str(v5)
	itc_updatenb(initmsg)
		
	StartMonitorEditPanel("ITCPanel", "itc_tbl_adclist;itc_tbl_daclist", "itc_update_chninfo")
	
	itc_update_chninfo("", 11)
	StartITC18Task()
End

Function itc_btnproc_lastrecord(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	
	NVAR recordingnum=$WBPkgGetName(fPath, "RecordingNum")
	WAVE /T adcdatawavepath=$WBPkgGetName(fPath, "ADCDataWavePath")
		
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Variable i, n
			n=DimSize(adcdatawavepath, 0)
			for(i=0; i<n; i+=1)
				if(WaveExists($(adcdatawavepath[i]+"_"+num2istr(recordingnum-1))))
					display /K=1 $(adcdatawavepath[i]+"_"+num2istr(recordingnum-1))
				endif
			endfor
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_btnproc_telegraph(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	
	NVAR recordingnum=$WBPkgGetName(fPath, "RecordingNum")
	WAVE /T adcdatawavepath=$WBPkgGetName(fPath, "ADCDataWavePath")
		
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			itc_setup_telegraph()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_get_adc_scale_factor(ctrlname, telegraph, factor, unit, [param])
	String ctrlname
	Variable & telegraph
	Variable & factor
	String & unit
	String & param
	
	String tmpstr
	telegraph=1
	factor=1
	unit="V"

	String tmpparam=GetUserData("ITCPanel", ctrlname, "param"); AbortOnRTE
	tmpstr=StringByKey("TELEGRAPH", tmpparam, "=", ";")
	telegraph=floor(str2num(tmpstr))
	if(numtype(telegraph)!=0 || telegraph<0 || telegraph>ItemsInList(ITC18_TelegraphList))
		telegraph=1
		tmpparam=ReplaceStringByKey("TELEGRAPH", tmpparam, num2istr(telegraph), "=", ";")
		CheckBox $ctrlname, win=ITCPanel, userdata(param)=tmpparam
	endif
	tmpstr=StringByKey("SCALEFACTOR", tmpparam, "=", ";")
	factor=str2num(tmpstr)
	if(numtype(factor)!=0)
		factor=1
		tmpparam=ReplaceStringByKey("SCALEFACTOR", tmpparam, num2str(factor), "=", ";")
		CheckBox $ctrlname, win=ITCPanel, userdata(param)=tmpparam
	endif
	tmpstr=StringByKey("SCALEUNIT", tmpparam, "=", ";")
	unit=tmpstr
	if(!ParamIsDefault(param))
		param=tmpparam
	endif
	return 0
End

Function itc_setup_telegraph()
	Variable i
	String ctrlName
	String tmpstr1, tmpstr2
	Variable telegraphsignal
	Variable scalefactor
	String scaleunit
	String notestr="Telegraph assignments have to be unique.\rSetting scale unit to '#GAIN' will scale the signal \rusing the gain telegraph signal."
	
	KillWindow ITCTelegraph
	NewPanel /N=ITCTelegraph /W=(100, 100, 450, 450) /K=1
	SetDrawEnv textxjust=0, textyjust=2,textrgb=(0, 0, 63000)
	DrawText /W=ITCTelegraph 20, 20, notestr
	for(i=0; i<8; i+=1)
		ctrlName="itc_cb_adc"+num2istr(i)
		
		itc_get_adc_scale_factor(ctrlName, telegraphsignal, scalefactor, scaleunit)
		
		sprintf tmpstr1, "Set ADC%d as:", i
		tmpstr2="\""+ReplaceString("_none_", ITC18_TelegraphList, "ADC"+num2istr(i))+"\""
		TitleBox $("tb_adc"+num2istr(i)),win=ITCTelegraph,title=tmpstr1,pos={20,25*(i+1)+52},frame=0
		
		PopupMenu $("pm_adc"+num2istr(i)),win=ITCTelegraph,mode=telegraphsignal,bodywidth=80,value=#tmpstr2,pos={125,25*(i+1)+50},proc=itc_popproc_telegraphchoice
		TitleBox $("tb_scale_adc"+num2istr(i)),win=ITCTelegraph,title="1 V scale =",pos={180,25*(i+1)+52},frame=0
		SetVariable $("sv_scale_adc"+num2istr(i)),win=ITCTelegraph,pos={240,25*(i+1)+52},value=_NUM:scalefactor,limits={-inf,inf,0},size={50, 20},proc=itc_svproc_scalefactor
		SetVariable $("sv_scaleunit_adc"+num2istr(i)),win=ITCTelegraph,pos={290,25*(i+1)+52},value=_STR:scaleunit,size={50, 20},proc=itc_svproc_scalefactor
	endfor
	TitleBox tb_errormsg, win=ITCTelegraph, pos={20, 280},size={320,30},fixedsize=1
	Button btn_apply, win=ITCTelegraph, title="Apply", pos={100,310}, size={150,30},proc=itc_btnproc_telegraph_commit
	itc_update_telegraphvar()
End

Function itc_popproc_telegraphchoice(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			itc_update_telegraphvar()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_svproc_scalefactor(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			itc_update_telegraphvar()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_btnproc_telegraph_commit(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if(itc_update_telegraphvar(commit=1)!=0)
				KillWindow ITCTelegraph
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function itc_update_telegraphvar([commit])
	Variable commit
	
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	
	NVAR ChnOnGainBinFlags=$WBPkgGetName(fPath, "ChannelOnGainBinFlag")
	WAVE scalefactor=$WBPkgGetName(fPath, "ADCScaleFactor")
	WAVE /T scaleunit=$WBPkgGetName(fPath, "ADCScaleUnit")
	WAVE telegraphassignment=$WBPkgGetName(fPath, "TelegraphAssignment")
	Make /FREE /N=(DimSize(scalefactor, 0)) tmpfactor
	Make /FREE /T /N=(DimSize(scaleunit, 0)) tmpunit
	Make /FREE /N=(ItemsInList(ITC18_TelegraphList)-1) tmpassignment=-1, tmpcount=0; AbortOnRTE
	Make /FREE /N=8 tmpadctelegraphflag=1
	
	Variable i, factor, tmpchnongainflag
	String unit, ctrlname, param
	
	if(ParamIsDefault(commit))
		commit=0
	endif
	
	try
		tmpchnongainflag=0
		for(i=0; i<8; i+=1)
			ControlInfo /W=ITCTelegraph $("pm_adc"+num2istr(i)); AbortOnRTE
			if(V_Value==1) // not assigned for telegraph signal
				TitleBox $("tb_scale_adc"+num2istr(i)),win=ITCTelegraph,disable=0; AbortOnRTE
				SetVariable $("sv_scale_adc"+num2istr(i)),win=ITCTelegraph,disable=0; AbortOnRTE
				SetVariable $("sv_scaleunit_adc"+num2istr(i)),win=ITCTelegraph,disable=0; AbortOnRTE
				
				ControlInfo /W=ITCTelegraph $("sv_scale_adc"+num2istr(i)); AbortOnRTE
				factor=V_Value
				ControlInfo /W=ITCTelegraph $("sv_scaleunit_adc"+num2istr(i)); AbortOnRTE
				unit=S_Value
				if(cmpstr(UpperStr(unit), "#GAIN")==0) //intend to use gain
					factor=1
					unit="#GAIN"
#if IgorVersion()>=7
					tmpchnongainflag=tmpchnongainflag | (1<<i)
#else
					tmpchnongainflag=tmpchnongainflag | (2^i)
#endif
					SetVariable $("sv_scale_adc"+num2istr(i)),win=ITCTelegraph,value=_NUM:1; AbortOnRTE
					SetVariable $("sv_scaleunit_adc"+num2istr(i)),win=ITCTelegraph,value=_STR:"#GAIN"; AbortOnRTE
				endif
			else
				tmpadctelegraphflag[i]=V_Value
				TitleBox $("tb_scale_adc"+num2istr(i)),win=ITCTelegraph,disable=1; AbortOnRTE
				SetVariable $("sv_scale_adc"+num2istr(i)),win=ITCTelegraph,disable=1; AbortOnRTE
				SetVariable $("sv_scaleunit_adc"+num2istr(i)),win=ITCTelegraph,disable=1; AbortOnRTE

				factor=1
				unit="V"
				tmpassignment[V_Value-2]=i; AbortOnRTE
				tmpcount[V_Value-2]+=1; AbortOnRTE
			endif
			tmpfactor[i]=factor; AbortOnRTE
			tmpunit[i]=unit; AbortOnRTE
		endfor
		for(i=0; i<DimSize(tmpcount, 0); i+=1)
			if(tmpcount(i)>1)
				TitleBox tb_errormsg, win=ITCTelegraph, title="Confliction detected. Changes can not be committed",fcolor=(65535,0,0); AbortOnRTE
				commit=0
				break
			else
				TitleBox tb_errormsg, win=ITCTelegraph, title="Settings are OK. Click Apply will commit the changes.",fcolor=(0,32768,0); AbortOnRTE
			endif
		endfor
		if(commit==1)
			scalefactor=tmpfactor; AbortOnRTE
			scaleunit=tmpunit; AbortOnRTE
			telegraphassignment=tmpassignment; AbortOnRTE
			ChnOnGainBinFlags=tmpchnongainflag; AbortOnRTE
			for(i=0; i<8; i+=1)
				ctrlname="itc_cb_adc"+num2istr(i)
				param=GetUserData("ITCPanel", ctrlname, "param")
				param=ReplaceStringByKey("TELEGRAPH", param, num2istr(tmpadctelegraphflag[i]), "=", ";")
				param=ReplaceStringByKey("SCALEFACTOR", param, num2istr(tmpfactor[i]), "=", ";")
				param=ReplaceStringByKey("SCALEUNIT", param, tmpunit[i], "=", ";")
				CheckBox $ctrlname,win=ITCPanel,userdata(param)=param
			endfor
			itc_update_chninfo("", 11) //will update the disable status of the controls, and the edit panel
			itc_update_controls(0)
		endif
	catch
		String tmpstr
		sprintf tmpstr, "Error when updating telegraph variables. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr, r=32768, g=0, b=0)
		commit=0
	endtry
	
	return commit
End

Function itc_btnproc_updatedacdata(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	
	NVAR recordingnum=$WBPkgGetName(fPath, "RecordingNum")
	WAVE /T adcdatawavepath=$WBPkgGetName(fPath, "ADCDataWavePath")
		
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_setup_EPC8default()
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	NVAR samplingrate=$WBPkgGetName(fPath, "SamplingRate")
	NVAR recordinglen=$WBPkgGetName(fPath, "RecordingLength")
	NVAR continuous=$WBPkgGetName(fPath, "ContinuousRecording")
	NVAR saverecording=$WBPkgGetName(fPath, "SaveRecording")
	NVAR chn_gain_flag=$WBPkgGetName(fPath, "ChannelOnGainBinFlag")
	
	samplingrate=30000
	recordinglen=0.2
	continuous=inf
	saverecording=0
	Make /O/N=(samplingrate*recordinglen)/D root:W_sealtestCmdV=0
	WAVE w=root:W_sealtestCmdV
	w[samplingrate*recordinglen/4, samplingrate*recordinglen/2]=0.01 //generate 10 mV pulses
	
	Variable i
	String chninfo=GetUserData("ITCPanel", "itc_cb_adc0", "param")
	chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "root:","=", ";")
	chninfo=ReplaceStringByKey("WAVENAME", chninfo, "W_sealtest_I","=", ";")
	CheckBox itc_cb_adc0, win=ITCPanel, userdata(param)=chninfo, value=1
	
	chninfo=GetUserData("ITCPanel","itc_cb_adc1", "param")
	chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "root:","=", ";")
	chninfo=ReplaceStringByKey("WAVENAME", chninfo, "W_sealtest_V","=", ";")
	CheckBox itc_cb_adc1, win=ITCPanel, userdata(param)=chninfo, value=1
	
	for(i=2; i<8; i+=1)
		chninfo=GetUserData("ITCPanel","itc_cb_adc"+num2istr(i), "param")
		chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "","=", ";")
		chninfo=ReplaceStringByKey("WAVENAME", chninfo, "","=", ";")
		CheckBox $("itc_cb_adc"+num2istr(i)), win=ITCPanel, userdata(param)=chninfo, value=0
	endfor
	
	chninfo=GetUserData("ITCPanel","itc_cb_dac0", "param")
	chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "root:","=", ";")
	chninfo=ReplaceStringByKey("WAVENAME", chninfo, "W_sealtestCmdV","=", ";")
	CheckBox itc_cb_dac0, win=ITCPanel, userdata(param)=chninfo, value=1
	
	for(i=1; i<4; i+=1)
		chninfo=GetUserData("ITCPanel","itc_cb_dac"+num2istr(i), "param")
		chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "","=", ";")
		chninfo=ReplaceStringByKey("WAVENAME", chninfo, "","=", ";")
		CheckBox $("itc_cb_dac"+num2istr(i)), win=ITCPanel, userdata(param)=chninfo, value=0
	endfor
	chn_gain_flag=floor(chn_gain_flag)|1
	
	itc_update_chninfo("", 11)
End

Function itc_btnproc_sealtest(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			itc_setup_EPC8default()
			itc_start_task(flag=1)			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function itc_svproc_rtdac(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			Variable chn=str2num(GetUserData("ITCPanel", sva.ctrlName, "channel"))
			if(chn>=0 && chn<4)
#if !defined(LIHDEBUG)
				LIH_SetDac(chn, dval)
#endif
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_updatenb(text,[r,g,b])
	String text
	Variable r,g,b
	Notebook ITCPanel#ITCPanelLog selection={endOfFile,endOfFile}
	Notebook ITCPanel#ITCPanelLog findText={"",1}
	Notebook ITCPanel#ITCPanelLog textRGB=(0,32768,0),text="["+time()+" on "+date()+"]:\t"
	Notebook ITCPanel#ITCPanelLog textRGB=(r,g,b),text=text+"\r"
End

Function itc_set_saverecording([flag])
	Variable flag
	
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	NVAR saverecording=$WBPkgGetName(fPath, "SaveRecording")
	String titlestr
	Variable fontsize, fontstyle
	Variable r, g, b
	
	if(ParamIsDefault(flag)) //by default will flip-flop the status
		Variable btnstatus=str2num(GetUserData("ITCPanel", "itc_btn_recording", "status" ))
		if(btnstatus==0)
			flag=1
		else
			flag=0
		endif
	endif
	
	if(flag==0)
		titlestr="Start saving recording"
		fontsize=12; fontstyle=0
		r=0; g=65535; b=0
	else
		titlestr="Stop saving recording"
		fontsize=12; fontstyle=1
		r=65535; g=0; b=0
	endif
	
	Button itc_btn_recording win=ITCPanel,fcolor=(r,g,b),fsize=fontsize,fstyle=fontstyle,title=titlestr,userdata(status)=num2istr(flag)
	saverecording=flag
End

Function itc_btnproc_saverecording(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			itc_set_saverecording()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_quicknote(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 2: // Enter key
			String sval = sva.sval
			if(strlen(sval)>0)
				itc_updatenb("User note: "+sval, r=0, g=0, b=32768)
				SetVariable itc_sv_note win=ITCPanel,value=_STR:""
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function ITC_Quit()
	if(WinType("ITCPanel")!=7)
		print "ITC Panel not initialized."
		return -1
	endif
//should call stopping task here
	StopITC18Task()
	
	String nbname=UniqueName("ITCPanelLog", 10, 0)
	NewNoteBook /N=$nbname /F=1 /V=1 /K=3
	itc_updatenb("ITCPanel shutdown.\r")
	Notebook ITCPanel#ITCPanelLog getData=1
	Notebook $nbname setData=S_value,writeProtect=1
	print "All logged messages have been saved to notebook "+nbname
	print "Please make sure to save the notebook before you kill it."
	DoWindow /K ITCPanel

	print "ITCPanel closed."
End

Function itc_update_chninfo(windowname, event)
	String windowname
	Variable event
	
	if(event!=11)
		return -1
	endif
	
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	String adc_chn_wname=WBPkgGetName(fPath, "ADC_Channel")
	String dac_chn_wname=WBPkgGetName(fPath, "DAC_Channel")
	String adc_chndestfolder_wname=WBPkgGetName(fPath, "ADC_DestFolder")
	String adc_chndestwave_wname=WBPkgGetName(fPath, "ADC_DestWave")
	String dac_chnsrcfolder_wname=WBPkgGetName(fPath, "DAC_SrcFolder")
	String dac_chnsrcwave_wname=WBPkgGetName(fPath, "DAC_SrcWave")
	
	String selectedadcchn=WBPkgGetName(fPath, "SelectedADCChn")
	String selecteddacchn=WBPkgGetName(fPath, "SelectedDACChn")
	String adcdatawavepath=WBPkgGetName(fPath, "ADCDataWavePath")
	String dacdatawavepath=WBPkgGetName(fPath, "DACDataWavePath")
	Variable i, j
	try
		Make /N=8/O/T $adc_chn_wname;AbortOnRTE
		WAVE /T textw=$adc_chn_wname
		for(i=0; i<8; i+=1)
			textw[i]="ADC"+num2istr(i);AbortOnRTE
		endfor
		Make /N=4/O/T $dac_chn_wname;AbortOnRTE
		WAVE /T textw=$dac_chn_wname
		for(i=0; i<4; i+=1)
			textw[i]="DAC"+num2istr(i);AbortOnRTE
		endfor
		Variable c=NumberByKey("COLUMNS", TableInfo("ITCPanel#itc_tbl_adclist", -2), ":", ";")
		for(i=1; i<c; i+=1)
			RemoveFromTable /W=ITCPanel#itc_tbl_adclist WaveRefIndexed("ITCPanel#itc_tbl_adclist", 0, 1);AbortOnRTE
		endfor
		c=NumberByKey("COLUMNS", TableInfo("ITCPanel#itc_tbl_daclist", -2), ":", ";")
		for(i=1; i<c; i+=1)
			RemoveFromTable /W=ITCPanel#itc_tbl_daclist WaveRefIndexed("ITCPanel#itc_tbl_daclist", 0, 1);AbortOnRTE
		endfor
		
		AppendToTable /W=ITCPanel#itc_tbl_adclist $adc_chn_wname;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_daclist $dac_chn_wname;AbortOnRTE
		
		Make /N=8/O/T $adc_chndestfolder_wname;AbortOnRTE
		WAVE /T wadcdestfolder=$adc_chndestfolder_wname
		Make /N=8/O/T $adc_chndestwave_wname;AbortOnRTE
		WAVE /T wadcdestwave=$adc_chndestwave_wname
		String ctrlname=""
		String param=""
		String s1=""
		Variable CountADC=0
		Variable CountDAC=0

		Variable telegraph, scalefactor
		String scaleunit
		
		for(i=0; i<8; i+=1)
		
			ctrlname="itc_cb_adc"+num2istr(i)
			itc_get_adc_scale_factor(ctrlname, telegraph, scalefactor, scaleunit, param=param)
			
			if(telegraph!=1) // telegraph is enabled
				s1=StringFromList(telegraph-1, ITC18_TelegraphList); AbortOnRTE
				CheckBox $ctrlname, win=ITCPanel, value=0, disable=2; AbortOnRTE //for telegraph channels, do not include in selected chns, and disable user access
				wadcdestfolder[i]="#Telegraph"; AbortOnRTE
				wadcdestwave[i]=s1; AbortOnRTE
				param=ReplaceStringByKey("DISABLE", param, "2", "=", ";"); AbortOnRTE
			else
				param=ReplaceStringByKey("DISABLE", param, "0", "=", ";"); AbortOnRTE
				s1=StringByKey("DATAFOLDER", param, "=", ";"); AbortOnRTE
				if(strlen(s1)<=0)
					wadcdestfolder[i]="#NotAssigned";AbortOnRTE
				else
					wadcdestfolder[i]=s1; AbortOnRTE
				endif
				s1=StringByKey("WAVENAME", param, "=", ";"); AbortOnRTE
				if(strlen(s1)<=0)
					wadcdestwave[i]="#NotAssigned";AbortOnRTE
				else
					wadcdestwave[i]=s1;AbortOnRTE
					CountADC+=1
				endif
			endif
			CheckBox $ctrlname, win=ITCPanel, userdata(param)=param; AbortOnRTE
		endfor
		GroupBox itc_grp_ADC win=ITCPanel, userdata(selected)=num2istr(CountADC);AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_adclist $adc_chndestfolder_wname;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_adclist $adc_chndestwave_wname;AbortOnRTE
		
		Make /N=4/O/T $dac_chnsrcfolder_wname;AbortOnRTE
		WAVE /T wdacsrcfolder=$dac_chnsrcfolder_wname
		Make /N=4/O/T $dac_chnsrcwave_wname;AbortOnRTE
		WAVE /T wdacsrcwave=$dac_chnsrcwave_wname

		for(i=0; i<4; i+=1)
			ctrlname="itc_cb_dac"+num2istr(i)
			param=GetUserData("ITCPanel", ctrlname, "param"); AbortOnRTE
			s1=StringByKey("DATAFOLDER", param, "=", ";"); AbortOnRTE
			if(strlen(s1)<=0)
				wdacsrcfolder[i]="#NotAssigned";AbortOnRTE
			else
				wdacsrcfolder[i]=s1;AbortOnRTE
			endif
			s1=StringByKey("WAVENAME", param, "=", ";")
			if(strlen(s1)<=0)
				wdacsrcwave[i]="#NotAssigned";AbortOnRTE
			else
				wdacsrcwave[i]=s1;AbortOnRTE
				CountDAC+=1
			endif
		endfor
		GroupBox itc_grp_DAC win=ITCPanel,userdata(selected)=num2istr(CountDAC);AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_daclist $dac_chnsrcfolder_wname;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_daclist $dac_chnsrcwave_wname	;AbortOnRTE

		//prepare the selected channels record
		Make /O /N=(countADC) $selectedadcchn=0; AbortOnRTE
		WAVE chnlist=$selectedadcchn; AbortOnRTE
		Make /O /T /N=(countADC) $adcdatawavepath=""; AbortOnRTE
		WAVE /T wavepaths=$adcdatawavepath; AbortOnRTE
		// to do get read length, set up the wave to the proper length
		j=0
		for(i=0; i<8; i+=1)
			ControlInfo /W=ITCPanel $("itc_cb_adc"+num2istr(i))
			if(V_value==1)
				chnlist[j]=i; AbortOnRTE
				wavepaths[j]=wadcdestfolder[i]+wadcdestwave[i]; AbortOnRTE
				j+=1
			endif
		endfor
		
		//For DAC channels, if no DAC channel is selected, zeros will be filled in the first DAC channel. otherwise the actual wave will be used.
		if(CountDAC==0)
			CountDAC=1
		endif
		Make /O /N=(countDAC) $selecteddacchn=0
		WAVE chnlist=$selecteddacchn; AbortOnRTE
		Make /O /T /N=(countDAC) $dacdatawavepath=""; AbortOnRTE //"" means the user has not specified a wave for this DAC channel, this is the default
		WAVE /T wavepaths=$dacdatawavepath
		j=0
		for(i=0; i<4; i+=1)
			ControlInfo /W=ITCPanel $("itc_cb_dac"+num2istr(i))
			if(V_value==1)
				chnlist[j]=i; AbortOnRTE
				wavepaths[j]=wdacsrcfolder[i]+wdacsrcwave[i]; AbortOnRTE
				j+=1
			endif
		endfor
	catch
		String tmpstr
		sprintf tmpstr, "Error when updating channel information. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr, r=32768, g=0, b=0)
	endtry
End

Function itc_cbproc_selchn(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			String ctrlName=cba.ctrlName
			String param=GetUserData("ITCPanel", ctrlName, "param")
			param=ReplaceStringByKey("DATAFOLDER", param, "", "=", ";")
			param=ReplaceStringByKey("WAVENAME", param, "", "=", ";")
			
			Variable adc_or_dac=0, chn=-1
			strswitch(ctrlName[0,9])
				case "itc_cb_adc":
					adc_or_dac=1
					chn=str2num(ctrlName[10,inf])			
					break
				case "itc_cb_dac":
					adc_or_dac=2
					chn=str2num(ctrlName[10,inf])			
					break
				default:
					adc_or_dac=-1
					param=""
					break
			endswitch
			
			CheckBox $cba.ctrlName win=ITCPanel,userdata(param)=param
			if(checked==1)
				itc_set_selectpanel(ctrlName, adc_or_dac, chn, param)
			else
				itc_update_chninfo("", 11)
			endif
			break
		case -1: // control being killed
			break
	endswitch
	
	
	return 0
End


Function itc_set_selectpanel(chnstr, adc_or_dac, chn, param)
	String chnstr
	Variable adc_or_dac, chn
	String param
	
	String panel_name=""
	String panel_title=""

	switch(adc_or_dac)
	case 1:
		panel_name="panel_adcchn_setup"
		panel_title="Set up ADC chn "+num2istr(chn)

		itc_selectwave(chn, chnstr, panel_name, panel_title, param)
		break
	case 2:
		panel_name="panel_dacchn_setup"
		panel_title="Set up DAC chn "+num2istr(chn)
		
		itc_selectwave(chn, chnstr, panel_name, panel_title, param)
		break
	default:
	endswitch
End

Function itc_selectwave(chn, chnstr, panel_name, panel_title, chninfo)
	Variable chn
	String chnstr
	String panel_name, panel_title	
	String chninfo
	
	String folder_label=StringByKey("FOLDERLABEL", chninfo, "=", ";")
	String wave_label=StringByKey("WAVELABEL", chninfo, "=", ";")
	String defaultfolder=StringByKey("DEFAULTFOLDER", chninfo, "=", ";")
	String defaultwave=StringByKey("DEFAULTWAVE", chninfo, "=", ";")
	Variable options=NumberByKey("OPTIONS", chninfo, "=", ";")
	
	if(numtype(options)!=0)
		options=0
	else
		options=floor(options)
	endif
		
	GetWindow ITCPanel,wsize
	Variable positionx=V_left
	Variable positiony=V_top
	ControlInfo /W=ITCPanel $chnstr
	positionx+=V_left
	positiony+=V_top
	WaveBrowser(panel_name, panel_title, positionx, positiony, folder_label, wave_label, options, defaultfolder, defaultwave, "CALLBACKFUNC:itc_selectwave_callback;FUNCPARAM:"+chnstr)
End

Function itc_selectwave_callback(controlname, datafolder, wname)
	String controlname, datafolder, wname
	
	String chninfo=GetUserData("ITCPanel", controlname, "param")
	if(strlen(datafolder)==0 || strlen(wname)==0)
		//selection cancelled
		chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "","=", ";")
		chninfo=ReplaceStringByKey("WAVENAME", chninfo, "","=", ";")
		CheckBox $controlname, win=ITCPanel, userdata(param)=chninfo,value=0
	else	
		WBrowserCreateDF(datafolder)
		if(cmpstr(datafolder[strlen(datafolder)-1,inf], ":")!=0)
			datafolder+=":"
		endif
		
		chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, datafolder,"=", ";")
		chninfo=ReplaceStringByKey("WAVENAME", chninfo, wname,"=", ";")
		CheckBox $controlname, win=ITCPanel, userdata(param)=chninfo
	endif
	itc_update_chninfo("", 11)
End

Function StartITC18Task()
	Variable numTicks=ITC18TASK_TICK
	CtrlNamedBackground ITC18BackgroundTask, period=numTicks,proc=ITC18_Task
	CtrlNamedBackground ITC18BackgroundTask,burst=0,dialogsOK=1
	CtrlNamedBackground ITC18BackgroundTask, start
End

Function StopITC18Task()
	CtrlNamedBackground ITC18BackgroundTask, stop
	
#if !defined(LIHDEBUG)
	LIH_Halt()
#endif
End

Function itc_start_task([flag])
	Variable flag
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	NVAR TaskStatus=$WBPkgGetName(fPath, "Status")
	NVAR Continuous=$WBPkgGetName(fPath, "ContinuousRecording")

	Variable countADC=str2num(GetUserdata("ITCPanel", "itc_grp_ADC", "selected"))
	Variable runflag=0
	
	if(countADC==0)
		DoAlert /T="No ADC selected", 0, "You have to select at least one ADC channel before running an acquisition task."
		return -1
	endif
	
	if(ParamIsDefault(flag) || flag!=1)
		Variable btnstatus=str2num(GetUserData("ITCPanel", "itc_btn_start", "status" ))
		if(btnstatus==0)
			//not started
			Continuous=0
			Variable cycles=Inf
			PROMPT cycles, "recording cycles"
		
			DoPrompt "How many recording cycles?", cycles
			
			if(V_flag==1 || numtype(cycles)==2 || cycles<0)
				runflag=0
			else
				Continuous=cycles
				runflag=1
			endif
		endif
	else
		runflag=1
	endif
	
	if(runflag==1 && numtype(Continuous)==0) //if the cycle is finite, ask if to save from the start
		DoAlert /T="Save trace?", 2, "Save traces from the beginning?"
		switch(V_flag)
		case 1: //yes save the trace
			itc_set_saverecording(flag=1)
			break
		case 2:
			itc_set_saverecording(flag=0)
			break
		default:
			itc_set_saverecording(flag=0)
			runflag=0
			break
		endswitch
	endif
	
	if(runflag)
		TaskStatus=1 //requesSt start
		btnstatus=1
	else
		TaskStatus=3
		btnstatus=0
	endif
	
	itc_update_controls(btnstatus)
End

Function itc_btnproc_startacq(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			itc_start_task()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_rtgraph_init(left, top, right, bottom)
	Variable left, top, right, bottom
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	String wname=WBPkgGetName(fPath, "ADCData")
	WAVE selectedchn=$WBPkgGetName(fPath, "selectedadcchn")
	WAVE /T chnlist=$WBPkgGetName(fPath, "ADC_Channel")
	String chnname=chnlist[selectedchn[0]]; AbortOnRTE
	String selchn_list1="\""+chnname
	String selchn_list2="\"_none_;"+chnname
	Variable i
	for(i=1; i<DimSize(selectedchn, 0); i+=1)
		selchn_list1+=";"+chnlist[selectedchn[i]]
		selchn_list2+=";"+chnlist[selectedchn[i]]
	endfor
	selchn_list1+="\""
	selchn_list2+="\""

	NewPanel /EXT=0 /HOST=ITCPanel /N=rtgraphpanel /W=(0, 400, 150, 0) /K=2
	PopupMenu rtgraph_trace1name win=ITCPanel#rtgraphpanel,title="Trace1 Channel",value=#selchn_list1,mode=1,size={150,20},userdata(tracename)="1",proc=rtgraph_popproc_trace
	PopupMenu rtgraph_trace1color win=ITCPanel#rtgraphpanel,title="Trace1 Color",popColor=(65280,0,0),value="*COLORPOP*",size={150,20}
	SetVariable rtgraph_miny1 win=ITCPanel#rtgraphpanel,title="MinY1",value=_NUM:-10,size={120,20},limits={-inf, inf, 0},disable=2
	SetVariable rtgraph_maxy1 win=ITCPanel#rtgraphpanel,title="MaxY1",value=_NUM:10,size={120,20},limits={-inf, inf, 0},disable=2
	CheckBox rtgraph_autoy1 win=ITCPanel#rtgraphpanel,title="AutoY1",size={120,20},value=1,userdata(tracename)="1",proc=rtgraph_cbproc_autoy
	
	PopupMenu rtgraph_trace2name win=ITCPanel#rtgraphpanel,title="Trace2 Channel",value=#selchn_list2,mode=1,size={150,20},userdata(tracename)="2",proc=rtgraph_popproc_trace
	PopupMenu rtgraph_trace2color win=ITCPanel#rtgraphpanel,title="Trace2 Color",popColor=(0,0,65280),value="*COLORPOP*",size={150,20},disable=2
	SetVariable rtgraph_miny2 win=ITCPanel#rtgraphpanel,title="MinY2",value=_NUM:-10,size={120,20},limits={-inf, inf, 0},disable=2
	SetVariable rtgraph_maxy2 win=ITCPanel#rtgraphpanel,title="MaxY2",value=_NUM:10,size={120,20},limits={-inf, inf, 0},disable=2
	CheckBox rtgraph_autoy2 win=ITCPanel#rtgraphpanel,title="AutoY2",size={120,20},disable=2,userdata(tracename)="2",proc=rtgraph_cbproc_autoy
	
	SetVariable rtgraph_minx win=ITCPanel#rtgraphpanel,title="MinX",value=_NUM:0,size={120,20},limits={-inf, inf, 0},disable=2
	SetVariable rtgraph_maxx win=ITCPanel#rtgraphpanel,title="MaxX",value=_NUM:(DimSize($wname, 0)*DimDelta($wname,0)),size={120,20},limits={-inf, inf, 0},disable=2
	CheckBox rtgraph_autox win=ITCPanel#rtgraphpanel,title="AutoX",size={120,20}	,value=1,proc=rtgraph_cbproc_autox

	CheckBox rtgraph_split win=ITCPanel#rtgraphpanel,title="Split Display",size={120,20},disable=2
	Button rtgraph_update win=ITCPanel#rtgraphpanel,title="Update Display",size={120,20},proc=rtgraph_btnproc_update
	
	Display /HOST=ITCPanel /N=rtgraph /W=(left, top, right, bottom);

	rtgraph_update_display()
End

Function rtgraph_popproc_trace(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			String tracenumstr=GetUserData("ITCPanel#rtgraphpanel", pa.ctrlName, "tracename")
			Variable tracenum=str2num(tracenumstr)
			
			if(tracenum==2)
				if(popNum==1) // _none_ is selected
					PopupMenu rtgraph_trace2color win=ITCPanel#rtgraphpanel, disable=2
					SetVariable rtgraph_miny2 win=ITCPanel#rtgraphpanel, disable=2
					SetVariable rtgraph_maxy2 win=ITCPanel#rtgraphpanel, disable=2
					CheckBox rtgraph_autoy2 win=ITCPanel#rtgraphpanel, disable=2
					CheckBox rtgraph_split win=ITCPanel#rtgraphpanel, value=0, disable=2
				else
					PopupMenu rtgraph_trace2color win=ITCPanel#rtgraphpanel, disable=0
					SetVariable rtgraph_miny2 win=ITCPanel#rtgraphpanel, disable=2
					SetVariable rtgraph_maxy2 win=ITCPanel#rtgraphpanel, disable=2
					CheckBox rtgraph_autoy2 win=ITCPanel#rtgraphpanel, disable=0,value=1
					CheckBox rtgraph_split win=ITCPanel#rtgraphpanel, value=1, disable=0
				endif
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_cbproc_autoy(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			String tracenumstr=GetUserData("ITCPanel#rtgraphpanel", cba.ctrlName, "tracename")
			Variable tracenum=str2num(tracenumstr)
			String controlname_miny="rtgraph_miny"+tracenumstr
			String controlname_maxy="rtgraph_maxy"+tracenumstr
			
			if(checked)
				SetVariable $controlname_miny win=ITCPanel#rtgraphpanel, disable=2
				SetVariable $controlname_maxy win=ITCPanel#rtgraphpanel, disable=2
			else
				SetVariable $controlname_miny win=ITCPanel#rtgraphpanel, disable=0
				SetVariable $controlname_maxy win=ITCPanel#rtgraphpanel, disable=0
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_cbproc_autox(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
						
			if(checked)
				SetVariable rtgraph_minx win=ITCPanel#rtgraphpanel, disable=2
				SetVariable rtgraph_maxx win=ITCPanel#rtgraphpanel, disable=2
			else
				SetVariable rtgraph_minx win=ITCPanel#rtgraphpanel, disable=0
				SetVariable rtgraph_maxx win=ITCPanel#rtgraphpanel, disable=0
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_btnproc_update(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			rtgraph_update_display()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_update_display()
	try
		String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
		String dataname=WBPkgGetName(fPath, "ADCData")
		WAVE datawave=$dataname; AbortOnRTE
		dataname=StringFromList(ItemsInList(dataname, ":")-1, dataname, ":")
		WAVE selectedchn=$WBPkgGetName(fPath, "selectedadcchn"); AbortOnRTE
		WAVE /T chnlist=$WBPkgGetName(fPath, "ADC_Channel"); AbortOnRTE
		WAVE /T chnunit=$WBPkgGetName(fPath, "ADCScaleUnit"); AbortOnRTE
		String chnname
		
		do
			String tracelist=TraceNameList("ITCPanel#rtgraph", ";", 1)
			Variable n=ItemsInList(tracelist)
			if(n>0)
				RemoveFromGraph /W=ITCPanel#rtgraph /Z $StringFromList(0, tracelist); AbortOnRTE
			endif
		while(n>0)
		
		String xaxis="bottom1", yaxis="left1"
		Variable chn
		
		//first trace
		ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_trace1name; AbortOnRTE
		chn=V_value-1
		ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_trace1color; AbortOnRTE
		Variable r=V_red, g=V_green, b=V_blue
		ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_autoy1; AbortOnRTE
		Variable autoy=V_value
		Variable miny, maxy
		if(autoy==1)
			miny=NaN
			maxy=NaN
		else
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_miny1; AbortOnRTE
			miny=V_value
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_maxy1; AbortOnRTE
			maxy=V_Value	
		endif
		ControlInfo  /W=ITCPanel#rtgraphpanel  rtgraph_autox; AbortOnRTE
		Variable autox=V_value
		Variable minx, maxx
		if(autox==1)
			minx=NaN
			maxx=NaN
		else
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_minx; AbortOnRTE
			minx=V_value
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_maxx; AbortOnRTE
			maxx=V_value
		endif
	
		ControlInfo  /W=ITCPanel#rtgraphpanel  rtgraph_split; AbortOnRTE
		Variable split=V_value
		
		chnname=chnlist[selectedchn[chn]]; AbortOnRTE
		AppendToGraph /W=ITCPanel#rtgraph /L=$yaxis /B=$xaxis datawave[][chn]; AbortOnRTE
		ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos($yaxis)=0,lblPos($yaxis)=60,notation($yaxis)=0,ZisZ($yaxis)=1,fsize=12; AbortOnRTE
		ModifyGraph /W=ITCPanel#rtgraph freePos($xaxis)=0,lblPos($xaxis)=40,notation($xaxis)=0,fsize=12,ZisZ=1; AbortOnRTE
		ModifyGraph /W=ITCPanel#rtgraph rgb($dataname)=(r, g, b); AbortOnRTE
		ModifyGraph /W=ITCPanel#rtgraph margin(left)=80; AbortOnRTE
		ModifyGraph /W=ITCPanel#rtgraph margin(right)=25; AbortOnRTE
		
		Label /W=ITCPanel#rtgraph $yaxis chnname+" (\\E"+chnunit[selectedchn[chn]]+")"; AbortOnRTE
		Label /W=ITCPanel#rtgraph $xaxis "time (\\U)"; AbortOnRTE
		
		if(autox==1)
			SetAxis /W=ITCPanel#rtgraph /A=2/E=1 $xaxis; AbortOnRTE
		else
			SetAxis /W=ITCPanel#rtgraph $xaxis, minx, maxx; AbortOnRTE
		endif
		ModifyGraph /W=ITCPanel#rtgraph lowTrip($xaxis)=0.01; AbortOnRTE
		
		if(autoy==1)
			SetAxis /W=ITCPanel#rtgraph /A=2/N=2 $yaxis; AbortOnRTE
		else
			SetAxis /W=ITCPanel#rtgraph $yaxis, miny, maxy; AbortOnRTE
		endif
		ModifyGraph /W=ITCPanel#rtgraph lowTrip($yaxis)=0.01; AbortOnRTE
		
		if(split==1)
			ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis)={0.52,1}; AbortOnRTE
			yaxis="left2"
		else
			ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis)={0,1}; AbortOnRTE
			yaxis="right1"
		endif
		
		//second trace
		ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_trace2name; AbortOnRTE
		chn=V_value-2
		if(chn<0) //_none_ is selected
			return 0
		endif
		
		ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_trace2color; AbortOnRTE
		r=V_red; g=V_green; b=V_blue
		ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_autoy2; AbortOnRTE
		autoy=V_value
		if(autoy==1)
			miny=NaN
			maxy=NaN
		else
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_miny2; AbortOnRTE
			miny=V_value
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_maxy2; AbortOnRTE
			maxy=V_Value	
		endif
		
		chnname=chnlist[selectedchn[chn]]; AbortOnRTE
		if(split)
			AppendToGraph /W=ITCPanel#rtgraph /L=$yaxis /B=$xaxis datawave[][chn]; AbortOnRTE
		else
			AppendToGraph /W=ITCPanel#rtgraph /R=$yaxis /B=$xaxis datawave[][chn]; AbortOnRTE
		endif
		ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos($yaxis)=0,lblPos($yaxis)=60,notation($yaxis)=0,ZisZ($yaxis)=1,fsize=12; AbortOnRTE
		ModifyGraph /W=ITCPanel#rtgraph rgb($(dataname+"#1"))=(r, g, b); AbortOnRTE
		
		Label /W=ITCPanel#rtgraph $yaxis chnname+" (\\E"+chnunit[selectedchn[chn]]+")"; AbortOnRTE
		if(autoy==1)
			SetAxis /W=ITCPanel#rtgraph /A=2/N=2 $yaxis; AbortOnRTE
		else
			SetAxis /W=ITCPanel#rtgraph $yaxis, miny, maxy; AbortOnRTE
		endif
		ModifyGraph /W=ITCPanel#rtgraph lowTrip($yaxis)=0.01; AbortOnRTE
		
		if(split==1)
			ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis)={0,0.48}; AbortOnRTE
		else
			ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis)={0,1}; AbortOnRTE
		endif
	catch
		String tmpstr
		sprintf tmpstr, "Error when updating the real time plot. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr, r=32768, g=0, b=0)
	endtry
End

Function itc_rtgraph_quit()	
	KillWindow ITCPanel#rtgraph
	KillWindow ITCPanel#rtgraphpanel
End

Function itc_update_controls(runstatus)
	Variable runstatus
	Variable i, cb_disable
	
	if(runstatus==0)
	//not running
		Button itc_btn_start,win=ITCPanel,title="Start Acquisition",fcolor=(0,65535,0),userdata(status)="0"
		itc_set_saverecording(flag=0)
		Button itc_btn_recording win=ITCPanel,disable=2
		SetVariable itc_sv_recordnum win=ITCPanel,disable=2
	
		SetVariable itc_sv_samplingrate win=ITCPanel,disable=0
		SetVariable itc_sv_recordinglen win=ITCPanel,disable=0
	
		for(i=0; i<8; i+=1)
			string param=GetUserData("ITCPanel","itc_cb_adc"+num2istr(i), "param")
			cb_disable=str2num(StringByKey("DISABLE", GetUserData("ITCPanel","itc_cb_adc"+num2istr(i), "param"), "=", ";"))
			CheckBox $("itc_cb_adc"+num2istr(i)) win=ITCPanel,disable=cb_disable
		endfor
	
		CheckBox itc_cb_dac0  win=ITCPanel,disable=0
		CheckBox itc_cb_dac1  win=ITCPanel,disable=0
		CheckBox itc_cb_dac2  win=ITCPanel,disable=0
		CheckBox itc_cb_dac3  win=ITCPanel,disable=0	
		
		Button itc_btn_telegraph win=ITCPanel,disable=0
		Button itc_btn_setsealtest win=ITCPanel,disable=0
		Button itc_btn_displastrecord win=ITCPanel,disable=0
		Button itc_btn_updatedacdata win=ITCPanel,disable=2
		
		GroupBox itc_grp_rtdac win=ITCPanel,disable=0
		SetVariable itc_sv_rtdac0 win=ITCPanel,disable=0
		SetVariable itc_sv_rtdac1 win=ITCPanel,disable=0
		SetVariable itc_sv_rtdac2 win=ITCPanel,disable=0
		SetVariable itc_sv_rtdac3 win=ITCPanel,disable=0
		GroupBox itc_grp_rtadc win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc0 win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc1 win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc2 win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc3 win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc4 win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc5 win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc6 win=ITCPanel,disable=0
		ValDisplay itc_vd_rtadc7 win=ITCPanel,disable=0
	
		SetWindow ITCPanel#itc_tbl_adclist hide=0,needUpdate=1;DoUpdate
		SetWindow ITCPanel#itc_tbl_daclist hide=0,needUpdate=1;DoUpdate
		itc_rtgraph_quit()
		
		MoveSubWindow /W=ITCPanel#ITCPanelLog fnum=(480,250,670,410); DoUpdate
		DoUpdate /W=ITCPanel
	else
	//running
		Button itc_btn_start,win=ITCPanel,title="Stop Acquisition",fcolor=(65535,0,0),userdata(status)="1"	
		Button itc_btn_recording win=ITCPanel,disable=0
		SetVariable itc_sv_recordnum win=ITCPanel,disable=0
	
		SetVariable itc_sv_samplingrate win=ITCPanel,disable=2
		SetVariable itc_sv_recordinglen win=ITCPanel,disable=2
	
		CheckBox itc_cb_adc0  win=ITCPanel,disable=2
		CheckBox itc_cb_adc1  win=ITCPanel,disable=2
		CheckBox itc_cb_adc2  win=ITCPanel,disable=2
		CheckBox itc_cb_adc3  win=ITCPanel,disable=2
		CheckBox itc_cb_adc4  win=ITCPanel,disable=2
		CheckBox itc_cb_adc5  win=ITCPanel,disable=2
		CheckBox itc_cb_adc6  win=ITCPanel,disable=2
		CheckBox itc_cb_adc7  win=ITCPanel,disable=2
	
		CheckBox itc_cb_dac0  win=ITCPanel,disable=2
		CheckBox itc_cb_dac1  win=ITCPanel,disable=2
		CheckBox itc_cb_dac2  win=ITCPanel,disable=2
		CheckBox itc_cb_dac3  win=ITCPanel,disable=2

		Button itc_btn_telegraph win=ITCPanel,disable=2
		Button itc_btn_setsealtest win=ITCPanel,disable=2
		Button itc_btn_displastrecord win=ITCPanel,disable=0
		Button itc_btn_updatedacdata win=ITCPanel,disable=0

		GroupBox itc_grp_rtdac win=ITCPanel,disable=1
		SetVariable itc_sv_rtdac0 win=ITCPanel,disable=1
		SetVariable itc_sv_rtdac1 win=ITCPanel,disable=1
		SetVariable itc_sv_rtdac2 win=ITCPanel,disable=1
		SetVariable itc_sv_rtdac3 win=ITCPanel,disable=1
		GroupBox itc_grp_rtadc win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc0 win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc1 win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc2 win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc3 win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc4 win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc5 win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc6 win=ITCPanel,disable=1
		ValDisplay itc_vd_rtadc7 win=ITCPanel,disable=1
		
		SetWindow ITCPanel#itc_tbl_adclist hide=1,needUpdate=1; DoUpdate
		SetWindow ITCPanel#itc_tbl_daclist hide=1,needUpdate=1; DoUpdate

		itc_rtgraph_init(118, 58, 672,318)
		MoveSubWindow /W=ITCPanel#ITCPanelLog fnum=(120, 320, 670, 405); DoUpdate
		DoUpdate /W=ITCPanel
	endif
End

Function itc_update_taskinfo()
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	
	Variable retVal=-1

	itc_update_chninfo("", 11)
	//fill ADC channel indice and wave names
	WAVE /T wadcdestfolder=$WBPkgGetName(fPath, "ADC_DestFolder")
	WAVE /T wadcdestwave=$WBPkgGetName(fPath, "ADC_DestWave")
	WAVE /T wdacsrcfolder=$WBPkgGetName(fPath, "DAC_SrcFolder")
	WAVE /T wdacsrcwave=$WBPkgGetName(fPath, "DAC_SrcWave")
	String adcdata=WBPkgGetName(fPath, "ADCData")
	String dacdata=WBPkgGetName(fPath, "DACData")
	
	Variable countADC=str2num(GetUserdata("ITCPanel", "itc_grp_ADC", "selected"))
	Variable countDAC=str2num(GetUserdata("ITCPanel", "itc_grp_DAC", "selected"))
	
	NVAR recordinglen=$WBPkgGetName(fPath, "RecordingLength")
	NVAR samplingrate=$WBPkgGetName(fPath, "SamplingRate")
	NVAR recordingsize=$WBPkgGetName(fPath, "RecordingSize")
	NVAR blocksize=$WBPkgGetName(fPath, "BlockSize")
	
	String dacdatawavepath=WBPkgGetName(fPath, "DACDataWavePath")
	
	String tmpstr
	
	if(numtype(countADC)!=0)
		countADC=0
	endif
	if(numtype(countDAC)!=0)
		countDAC=0
	endif
	
	Variable i, j
	
	if(countADC==0)
		return -1
	endif
	if(countDAC==0)
		countDAC=1
	endif
	
	try
		//prepare ADCData and DACData
		recordingsize=round(samplingrate*recordinglen)
		if(recordingsize>ITC18MaxBlockSize)
			blocksize=ITC18MaxBlockSize
		else
			blocksize=recordingsize
		endif
		Make /O /D /N=(recordingsize, countADC) $adcdata=0; AbortOnRTE
		Make /O /D /N=(recordingsize, countDAC) $dacdata=0; AbortOnRTE 
		j=0
		WAVE dacwave=$dacdata	
		WAVE /T wavepaths=$dacdatawavepath
		for(i=0; i<countDAC; i+=1)
			if(strlen(wavepaths[i])>0)
				WAVE srcwave=$wavepaths[i]
				Variable n1=DimSize(dacwave, 0)
				Variable n2=DimSize(srcwave, 0)
				if(n1!=n2)
					sprintf tmpstr, "Warning: DAC source wave %s contains %d points while DAC buffer length is %d.", wavepaths[i], n2, n1
					itc_updatenb(tmpstr, r=32768, g=0, b=0)
					if(n1>n2)
						n1=n2
					endif
				endif
				multithread dacwave[0,n1-1][i]=srcwave[p]; AbortOnRTE
			endif
		endfor
		//preapare Telegraph assignments and scale factors
		//Make /O /D /N=(ItemsInList(ITC18_TelegraphList)-1) $telegraphassignment=-1; AbortOnRTE
		WAVE TelegraphAssignment=$WBPkgGetName(fPath, "TelegraphAssignment"); AbortOnRTE
		//Make /O /D /N=8 $adcscalefactor=1; AbortOnRTE
		WAVE adcscale=$WBPkgGetName(fPath, "ADCScaleFactor"); AbortOnRTE
		//Make /O /T /N=8 $adcscaleunit="V"; AbortOnRTE
		WAVE /T adcunit=$WBPkgGetName(fPath, "ADCScaleUnit"); AbortOnRTE
		
		Variable telegraph, scalefactor
		String scaleunit
		String ctrlname
		for(i=0; i<8; i+=1)
			ctrlname="itc_cb_adc"+num2istr(i)
			itc_get_adc_scale_factor(ctrlname, telegraph, scalefactor, scaleunit); AbortOnRTE
			if(telegraph!=1)
				TelegraphAssignment[telegraph-2]=i; AbortOnRTE
			endif
			adcscale[i]=scalefactor
			adcunit[i]=scaleunit
		endfor
		retVal=0
	catch
		sprintf tmpstr, "Error when updating task information. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr, r=32768, g=0, b=0)
	endtry
	return retVal
End

StrConstant ITC18_TelegraphMODEList="VClamp;CClamp;LFVC 100;LFVC 30;LFVC 10;LFVC 3;LFVC 1"
StrConstant ITC18_TelegraphFILTERList="100Hz;300Hz;500Hz;700Hz;1KHz;3KHz;5KHz;7KHz;10KHz;30KHz;100KHz"
StrConstant ITC18_TelegraphGAINList="0.005;0.01;0.02;0.05;0.1;0.2;0.5;1;2;5;10;20;50;100;200;500;1000;2000"

Function itc_translate_telegraphsignal(sigidx, signal, infostr, [return_gain])
	Variable sigidx, signal
	String & infostr
	Variable return_gain
	
	Variable retVal=NaN
	Variable v
	
	switch(sigidx)
	case 0: //GAIN
		v=round(signal*2)
		if(v>=0 && v<=17)
			String gainstr=StringFromList(v, ITC18_TelegraphGAINList)
			//sprintf infostr, "GAIN=%s#%.4f;", gainstr, signal
			sprintf infostr, "GAIN=%smV/pA;", gainstr
			if(!ParamIsDefault(return_gain) && return_gain!=0)
				retVal=str2num(gainstr)
			endif
		else
			sprintf infostr, "GAIN=?;"
		endif
		break
	case 1: //CSLOW
		signal=round(signal*100)/100
		if(signal>0)
			//sprintf infostr, "CSLOW=%.1fpF#%.4f;", signal*10,signal
			sprintf infostr, "CSLOW=%.1fpF;", signal*10
		elseif(signal<0)
				//sprintf infostr, "CSLOW=%.1fpF#%.4f;", abs(signal)*100,signal
			sprintf infostr, "CSLOW=%.1fpF;", abs(signal)*100
		else
			infostr="CSLOW=OFF;"
		endif
		break
	case 2: //FILTER
		v=round(signal)
		if(v>=0 && v<=10)
			//sprintf infostr, "FILTER=%s#%.4f;", StringFromList(v, ITC18_TelegraphFILTERList), signal
			sprintf infostr, "FILTER=%s;", StringFromList(v, ITC18_TelegraphFILTERList)
		else
			sprintf infostr, "FILTER=?;"
		endif
		break
	case 3: //MODE
		v=round(signal)
		if(v>=1 && v<=7)
			//sprintf infostr, "MODE=%s#%.4f;", StringFromList(v-1, ITC18_TelegraphMODEList), signal
			sprintf infostr, "MODE=%s;", StringFromList(v-1, ITC18_TelegraphMODEList)
		else
			sprintf infostr, "MODE=?;"
		endif
		break
	default:
		break
	endswitch
	
	return retVal
End

Function /T itc_read_telegraph(telegraphassignment, [gain])
	WAVE telegraphassignment
	Variable & gain
	
	Variable i, chn, signal, gainvalue
	String tmpstr
	String infostr=""
	
	for(i=ItemsInList(ITC18_TelegraphList)-2; i>=0; i-=1)
		chn=telegraphassignment[i]
		tmpstr=""
		if(chn>=0 && chn<8)
#if defined(LIHDEBUG)
			switch(i)
			case 0: //gain
				signal=1 //1mV/pA
				break
			case 1: //cslow
				signal=0 //OFF
				break
			case 2: //filter
				signal=5.0 //3KHz
				break
			case 3: //mode
				signal=1 //VClamp
				break
			default:
				signal=NaN
				break
			endswitch
#else
			signal=LIH_ReadADC(chn)
#endif
		else
			signal=NaN
		endif
		gainvalue=itc_translate_telegraphsignal(i, signal, tmpstr, return_gain=1)
		if(i==0 && !ParamIsDefault(gain)) //GAIN channel
			gain=gainvalue
		endif
		infostr+=tmpstr
	endfor
	return infostr
End

Function ITC18ResetDACs()
	Variable i
	Variable dacvalue
	
	for(i=0; i<4; i+=1)
		ControlInfo /W=ITCPanel $("itc_sv_rtdac"+num2istr(i))
#if !defined(LIHDEBUG)
		LIH_SetDac(i, V_value)
#endif
	endfor
End

Structure ITC18ChannelsParam
	int16 channels[17]
EndStructure

Function itc_update_gain_scale(scalefactor, scaleunit, flag, gain)
	WAVE scalefactor
	WAVE /T scaleunit
	Variable flag
	Variable gain
	
	Variable i
	Variable legalgain=(numtype(gain)==0)?1:0
#if IgorVersion()>=7
	int a=round(flag)
#else
	Variable a=round(flag)
#endif
	for(i=0; i<8; i+=1)
		if(a&1!=0)
			if(legalgain)
				scalefactor[i]=1e-9/gain //gain is mV per pA, so the scale factor converts V to A
				scaleunit[i]="A"
			else
				scalefactor[i]=1
				scaleunit[i]="?GAIN"
			endif
		endif
#if IgorVersion()>=7
		a=a>>1
#else
		a=floor(a/2)
#endif
	endfor
End

Function ITC18_Task(s)
	STRUCT WMBackgroundStruct &s
	Variable tRefNum, tMicroSec
	
	tRefNum=StartMSTimer
	
	String fPath=WBSetupPackageDir(ITC18_PackageName, should_exist=1)
	
	SVAR Operator=$WBPkgGetName(fPath, "OperatorName")
	SVAR ExperimentTitle=$WBPkgGetName(fPath, "ExperimentTitle")
	SVAR DebugStr=$WBPkgGetName(fPath, "DebugStr")
	
	NVAR Status=$WBPkgGetName(fPath, "Status")
	NVAR LastIdleTicks=$WBPkgGetName(fPath, "LastIdleTicks")
	NVAR RecordNum=$WBPkgGetName(fPath, "RecordingNum")
	NVAR SamplingRate=$WBPkgGetName(fPath, "SamplingRate")
	NVAR RecordingLen=$WBPkgGetName(fPath, "RecordingLength")
	NVAR Continuous=$WBPkgGetName(fPath, "ContinuousRecording")
	NVAR SaveRecording=$WBPkgGetName(fPath, "SaveRecording")
	NVAR TelegraphGain=$WBPkgGetName(fpath, "TelegraphGain")
	SVAR TelegraphInfo=$WBPkgGetName(fpath, "TelegraphInfo")
	
	NVAR FIFOBegin=$WBPkgGetName(fPath, "FIFOBegin")
	NVAR FIFOEnd=$WBPkgGetName(fPath, "FIFOEnd")
	NVAR FIFOVirtualEnd=$WBPkgGetName(fPath, "FIFOVirtualEnd")
	NVAR ADCDataPointer=$WBPkgGetName(fPath, "ADCDataPointer")

	NVAR ChnOnGainBinFlag=$WBPkgGetName(fPath, "ChannelOnGainBinFlag")
	
	NVAR BlockSize=$WBPkgGetName(fPath, "BlockSize")
	NVAR RecordingSize=$WBPkgGetName(fPath, "RecordingSize")

	WAVE adcdata=$WBPkgGetName(fPath, "ADCData")
	WAVE dacdata=$WBPkgGetName(fPath, "DACData")
	
	WAVE /T adcdatawavepath=$WBPkgGetName(fPath, "ADCDataWavePath")
	WAVE /T dacdatawavepath=$WBPkgGetName(fPath, "DACDataWavePath")
	
	WAVE adcscalefactor=$WBPkgGetName(fPath, "ADCScaleFactor")
	WAVE /T adcscaleunit=$WBPkgGetName(fPath, "ADCScaleUnit")
	
	WAVE selectedadcchn=$WBPkgGetName(fPath, "SelectedADCChn")
	WAVE selecteddacchn=$WBPkgGetName(fPath, "SelectedDACChn")
	
	WAVE telegraphassignment=$WBPkgGetName(fPath, "TelegraphAssignment")
	
	String tmpstr
	Variable itcstatus
	try
		Variable i, success, availablelen, p0, p1, upload_len, UploadHalt, saved_len
		Variable SampleInt, ADBlockSize, DABlockSize
		Variable tmp_gain
		STRUCT ITC18ChannelsParam ADCs
		STRUCT ITC18ChannelsParam DACs
		Variable selectedadc_number=DimSize(selectedadcchn, 0)
		Variable selecteddac_number=DimSize(selecteddacchn, 0)
				
		switch(Status)
		case 0: //idle
			if(s.curRunTicks-LastIdleTicks>3)
#if defined(LIHDEBUG)
				itcstatus=-99
#else
				itcstatus=LIH_Status()
#endif
				
#if !defined(LIHDEBUG)
				for(i=0; i<8; i+=1)
					ControlInfo /W=ITCPanel $("itc_cb_adc"+num2istr(i)); AbortOnRTE
					if(V_value==1)
						ValDisplay $("itc_vd_rtadc"+num2istr(i)) win=ITCPanel,value=_NUM:LIH_ReadAdc(i); AbortOnRTE
					endif
				endfor
#endif
				LastIdleTicks=s.curRunTicks
				TelegraphInfo=itc_read_telegraph(telegraphassignment, gain=tmp_gain)
				telegraphgain=tmp_gain
				itc_update_gain_scale(adcscalefactor, adcscaleunit, ChnOnGainBinFlag, tmp_gain)
				sprintf DebugStr, "idle; status(%d); [ %s ].", itcstatus, TelegraphInfo
			endif			
			break
		case 1: //request to start
			DebugStr="Starting acquisition...";
			String errMsg=""
#if defined(LIHDEBUG)
			success=0
#else
			success=LIH_InitInterface(errMsg, 11)
#endif
			if(success!=0)
				sprintf tmpstr, "Initialization of the ITC18 failed with message: %s", errMsg
				itc_updatenb(tmpstr, r=32768, g=0, b=0)
				AbortOnValue 1, 999
			else
				itc_updatenb("ITC18 initialized for starting acquisition.")
			endif
			
			if(itc_update_taskinfo()==0)
				//checking passed, waves and variables have been prepared etc.
				if(RecordingSize<=0)
					itc_updatenb("Error in RecordingSize ["+num2istr(RecordingSize)+"]", r=32768, g=0, b=0)
					AbortOnValue 1, 900
				endif
				if(BlockSize<0 || BlockSize>ITC18MaxBlockSize || BlockSize>RecordingSize)
					itc_updatenb("Error in BlockSize ["+num2istr(BlockSize)+"]", r=32768, g=0, b=0)
					AbortOnValue 1, 910
				endif
				
				for(i=0; i<selectedadc_number; i+=1)
					ADCs.channels[i]=selectedadcchn[i]
				endfor
				for(i=0; i<selecteddac_number; i+=1)
					DACs.channels[i]=selecteddacchn[i]
				endfor
				
				FIFOBegin=0 //FIFOBegin gives the position of the starting position of the last uploaded data
				FIFOEnd=BlockSize-1				
				FIFOVirtualEnd=FIFOEnd
				ADCDataPointer=0
				ADBlockSize=BlockSize
				DABlockSize=BlockSize
				SampleInt=1/SamplingRate; AbortOnRTE; 
				if(SampleInt<=0)
					itc_updatenb("Error in SampleInt ["+num2istr(SampleInt)+"]", r=32768, g=0, b=0)
					AbortOnValue 1, 920
				endif
				
				//update telegraph information immediately before starting. so if you change the modes/gain/filter/cslow during recording
				//it will not be updated because the LIH is occupied and the telegraph signal cannot be captured.
				TelegraphInfo=itc_read_telegraph(telegraphassignment, gain=tmp_gain)
				telegraphgain=tmp_gain
				itc_update_gain_scale(adcscalefactor, adcscaleunit, ChnOnGainBinFlag, tmp_gain)
				
				sprintf tmpstr, "startstim(%d,%.1e)-", BlockSize,SampleInt
				DebugStr+=tmpstr
#if defined(LIHDEBUG)
				success=1
#else
				success=LIH_StartStimAndSample (dacdata, adcdata, ADBlockSize, DABlockSize, DACs, ADCs, SampleInt, 1+2+4); ;AbortOnRTE
#endif
				SamplingRate=1/SampleInt
				SetScale /P x, 0, SampleInt, "s", adcdata; AbortOnRTE
				SetScale d -10.24,10.24, "V", adcdata; AbortOnRTE
				Status=2
			
				if(success!=1)
					itc_updatenb("Error when starting acquisition.", r=32768, g=0, b=0)
					Status=4 //change back to idle
				endif
				DebugStr+="OK;"
				
				sprintf tmpstr, "Acquisition parameters: BlockSize[%d], SamplingRate [%d], SampleInterval[%.2e]", BlockSize, SamplingRate, SampleInt
				itc_updatenb(tmpstr)
				tmpstr=""
				for(i=0; i<selectedadc_number; i+=1)
					 tmpstr+="ADC Channel["+num2istr(selectedadcchn[i])+"] assigned to wave ["+adcdatawavepath[i]+"]; "
				endfor
				itc_updatenb(tmpstr)
			else
				//checking not passed
				itc_updatenb("Error when preparing background task.", r=32768, g=0, b=0)
				Status=4 //change back to idle
			endif

			break
		case 2: //acquisition started
			DebugStr=""
			SampleInt=1/SamplingRate
#if defined(LIHDEBUG)
			availablelen=round(BlockSize*0.7-(abs(floor(enoise(0.5*BlockSize))))); success=1
#else
			availablelen=LIH_AvailableStimAndSample(success)
#endif
			
			if(success!=1)
#if defined(LIHDEBUG)
				itcstatus=-99
#else
				itcstatus=LIH_Status()
#endif
				itc_updatenb("Acquisition has stopped running by itself. Status code: "+num2istr(itcstatus))
				Status=4 //back to idle
				if(itcstatus==2)
					DebugStr+="idle;"
					success=1
				endif
			endif
			
			//prepare the waves for read and write/upload, before comitting the actual action
			if(success==1 && availablelen>0)
			//upload first before storing data
				//decide whether we need to upload DAC data, if so, how many (continous or not)
				if(availablelen>BlockSize)
					sprintf tmpstr, "Warning: availablelen [%d] exceeds BlockSize [%d]. Forcing availablelen to be BlockSize for this cycle.", availablelen, BlockSize
					itc_updatenb(tmpstr, r=32768, g=0, b=0)
					availablelen=BlockSize
				endif
				
				Make /FREE /D /N=(availablelen, selectedadc_number) tmpread
				Make /FREE /D /N=(availablelen, selecteddac_number) tmpstim
				
				FIFOBegin=FIFOEnd+1
				FIFOVirtualEnd=FIFOEnd+availablelen
				UploadHalt=0
				if(Continuous<=0) //no continuous, the virtual end should be the last point
					if(FIFOVirtualEnd>=RecordingSize)
						FIFOVirtualEnd=RecordingSize-1
						UploadHalt=1
					endif
				endif
								
				if(FIFOVirtualEnd>=RecordingSize) //if the virtual end is longer than recording size, the first section of ending should be set to the last point
					FIFOEnd=RecordingSize-1
				else
					FIFOEnd=FIFOVirtualEnd
				endif
								
				upload_len=0

				if(FIFOBegin<FIFOVirtualEnd)	//filling the first section
					if(FIFOBegin<RecordingSize && FIFOEnd>=FIFOBegin)
						p0=0; p1=FIFOEnd-FIFOBegin						
						upload_len+=p1-p0+1; 
						if(upload_len<=0)
							sprintf tmpstr, "Error in upload_len [%d], p0 [%d], p1 [%d], availablelen[%d], RecordingSize[%d], FIFOBegin [%d], FIFOEnd [%d], FIFOVirtualEnd[%d], when filling the first section.", upload_len, p0, p1, availablelen, RecordingSize, FIFOBegin, FIFOEnd, FIFOVirtualEnd
							itc_updatenb(tmpstr, r=32768, g=0, b=0)
							AbortOnValue 1, 930
						endif
						multithread tmpstim[p0,p1][]=dacdata[p+FIFOBegin][q]; AbortOnRTE
					else
						FIFOBegin=0
					endif
				endif
				
				if(FIFOEnd<FIFOVirtualEnd) //filling the second section
					FIFOEnd=FIFOVirtualEnd-FIFOEnd-1 //now this is the new ending point, for the next task cycle, the new begin will be based on this point
					p0=upload_len; p1=p0+FIFOEnd; 
					upload_len+=FIFOEnd+1
					if(p1>=RecordingSize)
						sprintf tmpstr, "Error in upload_len [%d], p0 [%d], p1 [%d], availablelen[%d], RecordingSize[%d], FIFOBegin [%d], FIFOEnd [%d], FIFOVirtualEnd[%d], when filling the second section", upload_len, p0, p1, availablelen, RecordingSize, FIFOBegin, FIFOEnd, FIFOVirtualEnd
						itc_updatenb(tmpstr, r=32768, g=0, b=0)
						AbortOnValue 1, 940
					endif
					multithread tmpstim[p0,p1][]=dacdata[p-p0][q]; AbortOnRTE
				endif
				
#if defined(LIHDEBUG)
				multithread tmpread[0, availablelen-1][]=gnoise(1); AbortOnRTE
#else
				LIH_ReadStimAndSample(tmpread, 0, availablelen) //read the data from the instrument to a temp wave
#endif
				if(upload_len>0)
#if defined(LIHDEBUG)
					success=1
#else
					success=LIH_AppendToFIFO(tmpstim, UploadHalt, upload_len)
#endif
				endif

				if(success!=1)
					sprintf tmpstr, "Error: AppendToFIFO returned error code %d.", success
					itc_updatenb(tmpstr, r=32768, g=0, b=0)
				endif

			//now store data and decide if need to write to user spaces
				saved_len=0				
				if(ADCDataPointer+availablelen<RecordingSize) //the last point within RecordingSize-1, not including the last point is at RecordingSize-1

					multithread adcdata[ADCDataPointer, ADCDataPointer+availablelen-1][]=tmpread[p-ADCDataPointer][q]*adcscalefactor[selectedadcchn[q]]; AbortOnRTE //read is scaled immediately
					
					ADCDataPointer+=availablelen
					saved_len+=availablelen
				else
					Continuous-=1 //one cycle is done, so reduce the counter
					if(ADCDataPointer<RecordingSize)
					
						multithread adcdata[ADCDataPointer, RecordingSize-1][]=tmpread[p-ADCDataPointer][q]*adcscalefactor[selectedadcchn[q]]; AbortOnRTE //read is scaled immediately
						
						saved_len+=RecordingSize-ADCDataPointer
					endif
					
					if(SaveRecording!=0)
						String allwnames="Saved traces: "
						String stamp
						sprintf stamp, "TIMESTAMP=%s on %s;OPERATOR=%s;EXPERIMENTTITLE=%s;%s", time(), date(), Operator, ExperimentTitle, TelegraphInfo

						for(i=0; i<selectedadc_number; i+=1)
							if(strlen(adcdatawavepath[i])>0)
								String wname=adcdatawavepath[i]+"_"+num2istr(RecordNum)
								Make /O /N=(RecordingSize) /D $wname; AbortOnRTE
								WAVE saveto=$wname
								multithread saveto[]=adcdata[p][i]; AbortOnRTE
								SetScale /P x, 0, SampleInt, "s", saveto; AbortOnRTE
								SetScale d 0,0, adcscaleunit[selectedadcchn[i]], saveto; AbortOnRTE
								Note /k saveto, stamp; AbortOnRTE
								allwnames+=wname+", "
							endif
						endfor
						RecordNum+=1
						itc_updatenb(allwnames)
					endif
					ADCDataPointer=0
					
					//now save the second section of data
					if(Continuous<=0)
						Status=4
					else
						ADCDataPointer=availablelen-saved_len; 
						
						if(ADCDataPointer>0 && ADCDataPointer<RecordingSize)
							multithread adcdata[0,ADCDataPointer-1][]=tmpread[p+saved_len][q]*adcscalefactor[selectedadcchn[q]]; AbortOnRTE //read is scaled immediately
							saved_len+=ADCDataPointer
						else
							if(ADCDataPointer<0 || ADCDataPointer>=RecordingSize)
								itc_updatenb("Error in ADCDataPointer ["+num2istr(ADCDataPointer)+"]", r=32768, g=0, b=0)
								AbortOnValue 1, 950
							endif
						endif
					endif
				endif
			endif
#if defined(LIHDEBUG)
			itcstatus=-99
#else
			itcstatus=LIH_Status()
#endif
			tMicroSec=stopMSTimer(tRefNum)
			sprintf tmpstr, "Len(%6d, %2d, %2d),time(%4d ms),status(%d)", availablelen, availablelen-upload_len, availablelen-saved_len, tMicroSec/1000, itcstatus
			DebugStr+=tmpstr

			break
		case 3: //request to stop
			Status=4

			break
		case 4: //stopped
			Status=0
#if !defined(LIHDEBUG)
			LIH_Halt()
#endif
			ITC18ResetDACs()
			itc_updatenb("ITC18 stopped.")
			itc_update_controls(0)
			LastIdleTicks=s.curRunTicks
			break
		default:
		endswitch
	catch
		sprintf tmpstr, "Error in background task. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr, r=32768, g=0, b=0)
		itc_update_controls(0)
		ITC18ResetDACs()
		LastIdleTicks=s.curRunTicks
		Status=0
	endtry
	tMicroSec=stopMSTimer(tRefNum)
	return 0
End


