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

#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7
#pragma ModuleName=ITCPanel
#include "TableMonitorHook"
#include "WaveBrowser"


#if !defined(ITCDEBUG)
#if exists("LIH_InitInterface")==3
#if defined(DEBUGONLY)
#define ITCDEBUG
#else		
#undef ITCDEBUG
#endif
#else
#define ITCDEBUG
#endif
#endif

#if defined(ITCDEBUG)
StrConstant ITCMenuStr="ITC(DEMO)"
Constant ITCDEMO=1
#else
StrConstant ITCMenuStr="ITC"
Constant ITCDEMO=0
#endif

Menu ITCMenuStr
	"About ITCPanel",/Q, ITC_About()
	help={"About ITCPanel"}
	
	"Init ITCPanel",/Q, ITC_Init()
	help={"Initialize ITCPanel"}
	
	"Shutdown ITCPanel",/Q,ITC_Quit()
	help={"Shutdown ITCPanel"}
	
	"Plot trace record with histogram (slow)...",/Q,ITC_Plot_TraceRecord()
	help={"Plot trace with specified record number"}
	
	"Kill Notebook Log...",/Q,ITC_KillNoteBookLog()
	help={"Kill previous notebook logs"}
End

Strconstant ITC_licesence="Igor Pro script for using ITC/EPC8 in Igor Pro.\r\rAll rights reserved."
Strconstant ITC_contact="The Qing Research Lab at Arizona State University\r\rhttp://qinglab.physics.asu.edu"

static Function killwin(wname)
	String wname
	
	if(WinType(wname)!=0)
		KillWindow $wname
	endif
End

Function ITC_About()
	DoWindow /K AboutITCPanel
	NewPanel /K=1 /W=(50,50,530,290) /N=AboutITCPanel
	Variable res
	String platform=UpperStr(igorinfo(2))
	if(strsearch(platform, "WINDOWS", 0)>=0)
		res=96
	else
		res=72
	endif
	
	DrawPICT /W=AboutITCPanel /RABS 20,20,180, 180, ITCPanel#QingLabBadge
	DrawText /W=AboutITCPanel 25, 200, "QingLab ITC/EPC8 Control"
	DrawText /W=AboutITCPanel 25, 220, "Programmed by Quan Qing"
	NewNotebook /F=1/N=AboutITCPanel/OPTS=15 /W=(220,20,450,210) /HOST=AboutITCPanel
	Notebook # text=ITC_licesence
	Notebook # text="\r\r"
	Notebook # text=ITC_contact
End

Function ITC_KillNoteBookLog()
	String nblist=""
	PROMPT nblist,"notebook list", popup WinList("ITCPanelLog*",";","WIN:16")
	DoPrompt "Please select the notebook to kill", nblist
	if(V_flag==0 && WinType(nblist)==5)
		killwin(nblist)
	endif
End

#if defined(DEBUGONLY)
Constant ITCTASK_TICK=20 // 1/3 sec
#else
Constant ITCTASK_TICK=1 // 1/60 sec
#endif
Constant ITC_DefaultSamplingRate=20000 // 20KHz
StrConstant ITC_PackageName="ITC"
StrConstant ITC_ExperimentInfoStrs="OperatorName;ExperimentTitle;DebugStr;TelegraphInfo;UserDataProcessFunction;TaskRecordingCount"
StrConstant ITC_ChnInfoWaves="ADC_Channel;DAC_Channel;ADC_DestFolder;ADC_DestWave;DAC_SrcFolder;DAC_SrcWave;ADCScaleUnit"

StrConstant ITC_DataWaves="ADCData;DACData;SelectedADCChn;SelectedDACChn;TelegraphAssignment;ADCScaleFactor"
StrConstant ITC_DataWavesInfo="ADCDataWavePath;DACDataWavePath"

StrConstant ITC_AcquisitionSettingVars="ITCMODEL;SamplingRate;ContinuousRecording;RecordingLength;RecordingSize;BlockSize;LastIdleTicks"
StrConstant ITC_AcquisitionControlVars="Status;RecordingNum;FIFOBegin;FIFOEnd;FIFOVirtualEnd;ADCDataPointer;SaveRecording;TelegraphGain;ChannelOnGainBinFlag;DigitalChannels"
StrConstant ITC_BoardInfo="V_SecPerTick;MinSamplingTime;MaxSamplingTime;FIFOLength;NumberOfDacs;NumberOfAdcs"
Constant ITCMaxBlockSize=16383
Constant ITCMinRecordingLen=0.2 //minimal length of data in sec for continuous acquisitions
StrConstant ITC_ADCChnDefault="DATAFOLDER=;WAVENAME=;TITLE=ADC#;TELEGRAPH=1;SCALEFACTOR=1;SCALEUNIT=V;FOLDERLABEL=Destination data folder;WAVELABEL=Destination wave;DEFAULTFOLDER=root:;DEFAULTWAVE=adc#;OPTIONS=0;DISABLE=0"
StrConstant ITC_DACChnDefault="DATAFOLDER=;WAVENAME=;TITLE=DAC#;FOLDERLABEL=Source data folder;WAVELABEL=Source wave;DEFAULTFOLDER=;DEFAULTWAVE=;OPTIONS=3;DISABLE=0"

StrConstant ITC_TelegraphList="_none_;#GAIN;#CSLOW;#FILTER;#MODE;"

Function /T ITC_setup_directory()
	Variable instance=WBPkgNewInstance
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance, existence=-1, init_request=1)
	if(strlen(fPath)<=0)
		abort "Cannot properly prepare ITC package data folder!"
	endif
	DFREF dfr=$fPath
		
	try	
		AbortOnValue WBPrepPackageStrs(fPath, ITC_ExperimentInfoStrs)!=0, -100
		AbortOnValue WBPrepPackageWaves(fPath, ITC_ChnInfoWaves, text=1)!=0, -110
		AbortOnValue WBPrepPackageWaves(fPath, ITC_DataWaves)!=0, -120
		AbortOnValue WBPrepPackageWaves(fPath, ITC_DataWavesInfo, text=1)!=0, -125
		AbortOnValue WBPrepPackageVars(fPath, ITC_AcquisitionSettingVars)!=0, -130
		AbortOnValue WBPrepPackageVars(fPath, ITC_AcquisitionControlVars)!=0, -140
		AbortOnValue WBPrepPackageVars(fPath, ITC_BoardInfo)!=0, -150
	catch
		abort "error setting up ITC data folder."
	endtry
	
	return fPath
End


Function ITC_init()
	
	if(WinType("ITCPanel")==7)
		print "ITC Panel already initialized."
		return -1
	endif
	
	if(exists("root:ITCPanelRunning")!=2)
		Variable /G root:ITCPanelRunning=1
	else
		NVAR itcrunning=root:ITCPanelRunning
		itcrunning=1
	endif 
	
	String fPath=ITC_setup_directory()
	
	String operatorname="unknown", experimenttitle="unknown"
	Variable model=1
	PROMPT operatorname, "Operator Name"
	PROMPT experimenttitle, "Experiment title"
	PROMPT model, "ITC Model", popup, "USB-18;USB-16"
	DoPrompt "Start experiment", operatorname, experimenttitle, model
	if(V_Flag!=0)
		print "experiment cancelled."
		return -1
	endif
	
	switch(model)
		case 1: //USB-18
			model=11;
			break
		case 2: //USB-16
			model=10;
			break
		default: //unknown
			model=0
			break
	endswitch
	
	Variable error
	String errMsg=""
#if defined(ITCDEBUG)
	error=0
#else
	error=LIH_InitInterface(errMsg, model)
	if(error!=0)
		DoAlert /T="Initialize failed" 0, "Initialization of the ITC failed with message: "+errMsg
		return -1
	endif
#endif

	NVAR itcmodel=$WBPkgGetName(fPath, WBPkgDFVar, "ITCMODEL")
	SVAR opname=$WBPkgGetName(fPath, WBPkgDFStr, "OperatorName")
	SVAR exptitle=$WBPkgGetName(fPath, WBPkgDFStr, "ExperimentTitle")
	SVAR debugstr=$WBPkgGetName(fPath, WBPkgDFStr, "DebugStr")
	NVAR taskstatus=$WBPkgGetName(fPath, WBPkgDFVar, "Status")
	NVAR recordnum=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingNum")
	NVAR samplingrate=$WBPkgGetName(fPath, WBPkgDFVar, "SamplingRate")
	NVAR recordinglen=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingLength")
	NVAR continuous=$WBPkgGetName(fPath, WBPkgDFVar, "ContinuousRecording")
	NVAR saverecording=$WBPkgGetName(fPath, WBPkgDFVar, "SaveRecording")
	
	opname=operatorname
	exptitle=experimenttitle
	itcmodel=model
	taskstatus=0 //idle
	samplingrate=ITC_DefaultSamplingRate
	recordnum=0
	recordinglen=ITCMinRecordingLen
	continuous=0
	saverecording=0

	//"V_SecPerTick;MinSamplingTime;MaxSamplingTime;FIFOLength;NumberOfDacs;NumberOfAdcs"	
	Variable v0,v1,v2,v3,v4,v5
	NVAR V_SecPerTick=$WBPkgGetName(fPath, WBPkgDFVar, "V_SecPerTick")
	NVAR MinSamplingTime=$WBPkgGetName(fPath, WBPkgDFVar, "MinSamplingTime")
	NVAR MaxSamplingTime=$WBPkgGetName(fPath, WBPkgDFVar, "MaxSamplingTime")
	NVAR FIFOLength=$WBPkgGetName(fPath, WBPkgDFVar, "FIFOLength")
	NVAR NumberOfDacs=$WBPkgGetName(fPath, WBPkgDFVar, "NumberOfDacs")
	NVAR NumberOfAdcs=$WBPkgGetName(fPath, WBPkgDFVar, "NumberOfAdcs")

#if defined(ITCDEBUG)
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
	
	SVAR TaskRecordingCount=$WBPkgGetName(fPath, WBPkgDFStr, "TaskRecordingCount")
	TaskRecordingCount="0,0"
	SVAR UserDataProcessFunction=$WBPkgGetName(fPath, WBPkgDFStr, "UserDataProcessFunction")
	UserDataProcessFunction=""
	
	String telegraphassignment=WBPkgGetName(fPath, WBPkgDFWave, "TelegraphAssignment")
	String adcscalefactor=WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleFactor")
	String adcscaleunit=WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleUnit")
		
	Make /O /D /N=(ItemsInList(ITC_TelegraphList)-1) $telegraphassignment=-1; AbortOnRTE

	Make /O /D /N=9 $adcscalefactor=1; AbortOnRTE

	Make /O /T /N=9 $adcscaleunit="V"; AbortOnRTE
	WAVE /T wscaleunit=$adcscaleunit
	wscaleunit[8]="N/A"

	NVAR chnongainbinflag=$WBPkgGetName(fPath, WBPkgDFVar, "ChannelOnGainBinFlag"); AbortOnRTE
	chnongainbinflag=0
	
	NewPanel /N=ITCPanel /K=2 /W=(50,50,850,500) as "(ITCPanel) Experiment : "+exptitle
	ModifyPanel /W=ITCPanel fixedSize=1,noedit=1
		
	GroupBox itc_infobox win=ITCPanel,title="",pos={10,1},size={395,50}
	
	SetVariable itc_sv_opname win=ITCPanel,title="Operator", pos={20,6},size={150,16},variable=opname,noedit=1
	SetVariable itc_sv_opname win=ITCPanel,valueColor=(0,0,65280)
	SetVariable itc_sv_opname win=ITCPanel,valueBackColor=(57344,65280,48896)
	
	Button itc_btn_recording win=ITCPanel,title="Start saving recording",pos={190,4}, fcolor=(0,65535,0),fsize=12,fstyle=0, size={140,22}
	Button itc_btn_recording win=ITCPanel,proc=itc_btnproc_saverecording,userdata(status)="0",disable=2
	SetVariable itc_sv_recordnum win=ITCPanel,title="#",pos={345, 6},size={90,16},limits={0,inf,0},variable=recordnum,noedit=1,fstyle=1,disable=2
	SetVariable itc_sv_recordnum win=ITCPanel,frame=0,valueColor=(65280,0,0)
	SetVariable itc_sv_note win=ITCPanel,title="Quick notes",pos={20,26},size={380,16},value=_STR:"",proc=itc_quicknote
	
	SetVariable itc_sv_samplingrate win=ITCPanel,title="Sampling Rate (Hz)",pos={600, 10},size={190,16},limits={1/MaxSamplingTime,1/MinSamplingTime,0},variable=samplingrate
	SetVariable itc_sv_recordinglen win=ITCPanel,title="Recording length (sec)",pos={600,30},size={190,16},limits={ITCMinRecordingLen,inf,0},variable=recordinglen
	
	GroupBox itc_acquistion_box win=ITCPanel,title="",pos={410,1},size={185,50}	
	Button itc_btn_start win=ITCPanel,title="Start Acquisition",pos={415,4},size={170,25},fcolor=(0,65535,0),proc=itc_btnproc_startacq,userdata(status)="0"
	CheckBox itc_cb_forcereset win=ITCPanel, title="Force INIT", pos={510, 30}, size={65, 20}
	CheckBox itc_cb_userfunc win=ITCPanel, title="USER_FUNC", pos={420, 30}, size={65,20},proc=itc_cbproc_setuserfunc
	
	GroupBox itc_grp_ADC win=ITCPanel,title="ADCs",pos={20,50},size={90,195}
	CheckBox itc_cb_adc0  win=ITCPanel,title="ADC0",pos={35,65},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "0")
	CheckBox itc_cb_adc1  win=ITCPanel,title="ADC1",pos={35,85},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "1")
	CheckBox itc_cb_adc2  win=ITCPanel,title="ADC2",pos={35,105},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "2")
	CheckBox itc_cb_adc3  win=ITCPanel,title="ADC3",pos={35,125},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "3")
	CheckBox itc_cb_adc4  win=ITCPanel,title="ADC4",pos={35,145},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "4")
	CheckBox itc_cb_adc5  win=ITCPanel,title="ADC5",pos={35,165},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "5")
	CheckBox itc_cb_adc6  win=ITCPanel,title="ADC6",pos={35,185},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "6")
	CheckBox itc_cb_adc7  win=ITCPanel,title="ADC7",pos={35,205},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_ADCChnDefault, "7")
	CheckBox itc_cb_adc16  win=ITCPanel,title="DIGI_IN",pos={35,225},proc=itc_cbproc_selchn,userdata(param)=ReplaceStringByKey("SCALEUNIT", ReplaceString("adc#", ReplaceString("ADC#", ITC_ADCChnDefault, "DIGI_IN", 1), "digi_in", 1), "N/A", "=", ";")
	
	GroupBox itc_grp_DAC win=ITCPanel,title="DACs",pos={20,245},size={90,115}
	CheckBox itc_cb_dac0  win=ITCPanel,title="DAC0",pos={35,260},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_DACChnDefault, "0")
	CheckBox itc_cb_dac1  win=ITCPanel,title="DAC1",pos={35,280},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_DACChnDefault, "1")
	CheckBox itc_cb_dac2  win=ITCPanel,title="DAC2",pos={35,300},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_DACChnDefault, "2")
	CheckBox itc_cb_dac3  win=ITCPanel,title="DAC3",pos={35,320},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("#", ITC_DACChnDefault, "3")
	CheckBox itc_cb_dac8  win=ITCPanel,title="DIGI_OUT",pos={35,340},proc=itc_cbproc_selchn,userdata(param)=ReplaceString("DAC#", ITC_DACChnDefault, "DIGI_OUT", 1)
	
	Button itc_btn_telegraph win=ITCPanel,title="Scale&Telegraph",pos={5,360},size={110,20},proc=itc_btnproc_telegraph
	Button itc_btn_setsealtest win=ITCPanel,title="Setup seal test",pos={5,380},size={110,20}, proc=itc_btnproc_sealtest
	Button itc_btn_displastrecord win=ITCPanel,title="Last recording",pos={5,400},size={110,20},proc=itc_btnproc_lastrecord
	Button itc_btn_updatedacdata win=ITCPanel,title="New StimWave",pos={5,420},size={110,20},proc=itc_btnproc_generatewave
	
	Edit /HOST=ITCPanel /N=itc_tbl_adclist /W=(120, 60, 590, 265) as "ADC list" 
	Edit /HOST=ITCPanel /N=itc_tbl_daclist /W=(120, 270, 590, 410) as "DAC list"
		
	debugstr=" "
	TitleBox itc_tb_debug win=ITCPanel,variable=debugstr,pos={120,416},fixedSize=1,frame=2,size={470,25},fColor=(32768,0,0)
	
	GroupBox itc_grp_rtdac win=ITCPanel,title="RealTime DACs (V)",pos={600, 60}, size={195,75}
	SetVariable itc_sv_rtdac0 win=ITCPanel, title="DAC0", pos={610, 80},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="0"
	SetVariable itc_sv_rtdac1 win=ITCPanel,title="DAC1", pos={700, 80},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="1"
	SetVariable itc_sv_rtdac2 win=ITCPanel,title="DAC2", pos={610, 100},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="2"
	SetVariable itc_sv_rtdac3 win=ITCPanel,title="DAC3", pos={700, 100},size={80,16},format="%6.4f",limits={-10.2,10.2,0},value=_NUM:0,proc=itc_svproc_rtdac,userdata(channel)="3"
	
	GroupBox itc_grp_rtadc win=ITCPanel,title="RealTime ADCs (V)", pos={600,140},size={195, 110}
	ValDisplay itc_vd_rtadc0 win=ITCPanel,title="ADC0",pos={605,160},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc1 win=ITCPanel,title="ADC1",pos={605,180},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc2 win=ITCPanel,title="ADC2",pos={605,200},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc3 win=ITCPanel,title="ADC3",pos={605,220},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc4 win=ITCPanel,title="ADC4",pos={700,160},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc5 win=ITCPanel,title="ADC5",pos={700,180},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc6 win=ITCPanel,title="ADC6",pos={700,200},size={90,16},format="%8.6f",value=_NUM:0
	ValDisplay itc_vd_rtadc7 win=ITCPanel,title="ADC7",pos={700,220},size={90,16},format="%8.6f",value=_NUM:0
	
	GroupBox itc_grp_rtdigital win=ITCPanel,title="RealTime Digital", pos={593,250},size={205, 45}
	CheckBox itc_cb_digital0  win=ITCPanel,title="0",pos={598,270},proc=itc_cbproc_digitals
	CheckBox itc_cb_digital1  win=ITCPanel,title="1",pos={623,270},proc=itc_cbproc_digitals
	CheckBox itc_cb_digital2  win=ITCPanel,title="2",pos={648,270},proc=itc_cbproc_digitals
	CheckBox itc_cb_digital3  win=ITCPanel,title="3",pos={673,270},proc=itc_cbproc_digitals
	CheckBox itc_cb_digital4  win=ITCPanel,title="4",pos={698,270},proc=itc_cbproc_digitals
	CheckBox itc_cb_digital5  win=ITCPanel,title="5",pos={723,270},proc=itc_cbproc_digitals
	CheckBox itc_cb_digital6  win=ITCPanel,title="6",pos={748,270},proc=itc_cbproc_digitals
	CheckBox itc_cb_digital7  win=ITCPanel,title="7",pos={773,270},proc=itc_cbproc_digitals
	
	NewNotebook /F=1 /N=ITCPanelLog /HOST=ITCPanel /W=(600,300,795,440)
	Notebook ITCPanel#ITCPanelLog writeProtect=1,fSize=8,magnification=125
	String initmsg="ITCPanel initialized.\r"
	initmsg+="Experiment operator:"+opname+"\r"
	initmsg+="Experiment title:"+exptitle+"\r\r"
	initmsg+="ITC initialized with board information as following:\r\r"
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
	StartITCTask()
End

Function itc_btnproc_lastrecord(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
		
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	
	NVAR recordingnum=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingNum")
		
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if(recordingnum>0)
				itc_plot_trace_record(recordingnum-1, 0)
			endif		
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ITC_Plot_TraceRecord()
	Variable recnum=0
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	try
		String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)	
		NVAR recordingnum=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingNum"); AbortOnRTE
		
		PROMPT recnum, "record number"
		DoPROMPT "record number", recnum
		if(V_flag==0)
			itc_plot_trace_record(recnum, 1)
		endif
	catch
		String tmpstr
		sprintf tmpstr, "Error when plotting trace record. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		print tmpstr
	endtry
End

Function itc_plot_trace_record(recNum, histogram_mode)
	Variable recNum, histogram_mode
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	try
		String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
		WAVE /T adcdatawavepath=$WBPkgGetName(fPath, WBPkgDFWave, "ADCDataWavePath")
		Variable i, n
		n=DimSize(adcdatawavepath, 0)
		if(n>0)
			String displayname=UniqueName("record"+num2istr(recNum)+"_", 6, 0)
			WBrowserCreateDF("root:tmpHistograms")
			
			Display /K=1 /N=$displayname as displayname
			ModifyGraph /W=$displayname height={Aspect, n/2}
			string xaxisname, yaxisname,wfullname,wname,hname
			variable range_start,range_end
			range_end=1
					
			for(i=0; i<n; i+=1)
				yaxisname="left"+num2istr(i)
				range_start=1-(i+1)/n
				wfullname=adcdatawavepath[i]+"_"+num2istr(recNum)
				
				if(WaveExists($wfullname))
					AppendToGraph /W=$displayname /L=$yaxisname /B=timeaxis $wfullname
					ModifyGraph /W=$displayname grid($yaxisname)=1,tick($yaxisname)=2,mirror($yaxisname)=1,axThick($yaxisname)=2,standoff($yaxisname)=0
					ModifyGraph /W=$displayname axisEnab($yaxisname)={range_start,range_end},minor($yaxisname)=1,freePos($yaxisname)=0
					ModifyGraph /W=$displayname axisOnTop($yaxisname)=1,sep($yaxisname)=15
					wname=StringFromList(ItemsInList(wfullname, ":")-1, wfullname, ":")
					ModifyGraph /W=$displayname rgb($PossiblyQuoteName(wname))=(65535,0,0)
					if(histogram_mode==1)
						hname="root:tmpHistograms:"+PossiblyQuoteName("hist_"+wname)
						Make/N=0/O $hname

						Histogram/B=5 $wfullname,$hname

						xaxisname="hist"+num2istr(i)
						AppendToGraph /W=$displayname /B=$xaxisname /L=$yaxisname /VERT $hname
						wname=StringFromList(ItemsInList(hname, ":")-1, hname, ":")
						ModifyGraph /W=$displayname mode($wname)=5,hbFill($wname)=4;
						ModifyGraph /W=$displayname rgb($wname)=(0,0,0),plusRGB($wname)=(1,16019,65535),negRGB($wname)=(1,16019,65535)
						ModifyGraph /W=$displayname hbFill($wname)=2,usePlusRGB($wname)=1,useNegRGB($wname)=1					
						ModifyGraph tick($xaxisname)=1,axThick=2,standoff($xaxisname)=0;DelayUpdate
						ModifyGraph axisEnab($xaxisname)={0.75,0.95},freePos($xaxisname)={range_start,kwFraction}
						SetAxis /A /N=1 $xaxisname
					endif
				endif
				SetAxis /W=$displayname /A=2/N=2 $yaxisname
				ModifyGraph /W=$displayname nticks($yaxisname)=3,lblPosMode($yaxisname)=2
				Label /W=$displayname $yaxisname "\\c / \\U"
				range_end=range_start
			endfor
			ModifyGraph /W=$displayname grid(timeaxis)=1,tick(timeaxis)=2,mirror(timeaxis)=1,axThick(timeaxis)=2,freePos(timeaxis)=0
			ModifyGraph /W=$displayname lblPosMode(timeaxis)=2
			if(histogram_mode==1)
				ModifyGraph /W=$displayname axisEnab(timeaxis)={0,0.7}
			endif
			Label /W=$displayname timeaxis "Time / \\U"
		endif
	catch
		String tmpstr
		sprintf tmpstr, "Error when plotting last trace. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr)
	endtry	
End

Function itc_btnproc_telegraph(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	
	NVAR recordingnum=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingNum")
	WAVE /T adcdatawavepath=$WBPkgGetName(fPath, WBPkgDFWave, "ADCDataWavePath")
		
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
	if(numtype(telegraph)!=0 || telegraph<0 || telegraph>ItemsInList(ITC_TelegraphList))
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

Function itc_set_adc_scale_factor(ctrlname, telegraph, factor, unit)
	String ctrlname
	Variable telegraph
	Variable factor
	String unit
	
	String tmpstr
	try	
		String tmpparam=GetUserData("ITCPanel", ctrlname, "param"); AbortOnRTE
		if(numtype(telegraph)!=0 || telegraph<0 || telegraph>ItemsInList(ITC_TelegraphList))
			telegraph=1			
		endif
		tmpparam=ReplaceStringByKey("TELEGRAPH", tmpparam, num2istr(telegraph), "=", ";")
		if(numtype(factor)!=0)
			factor=1
		endif
		sprintf tmpstr, "%.6e", factor
		tmpparam=ReplaceStringByKey("SCALEFACTOR", tmpparam, tmpstr, "=", ";")		
		tmpparam=ReplaceStringByKey("SCALEUNIT", tmpparam, unit, "=", ";")
		
		CheckBox $ctrlname, win=ITCPanel, userdata(param)=tmpparam; AbortOnRTE
	catch
		sprintf tmpstr, "Error when setting telegraph/scale/units for %s. Telegraph[%d], Factor[%f], unit[%s]. ", ctrlname, telegraph, factor, unit
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr, r=32768, g=0, b=0)
	endtry
	
	return 0
End

Function itc_setup_telegraph()
	Variable i
	String ctrlName
	String tmpstr1, tmpstr2
	Variable telegraphsignal
	Variable scalefactor
	String scaleunit
	String notestr="Setting scale unit to '#GAIN' will scale the signal \rusing the gain telegraph signal."
	
	killwin("ITCTelegraph")
	NewPanel /N=ITCTelegraph /W=(100, 100, 450, 450) /K=1
	SetDrawEnv textxjust=0, textyjust=2,textrgb=(0, 0, 63000)
	DrawText /W=ITCTelegraph 20, 20, notestr
	for(i=0; i<8; i+=1)
		ctrlName="itc_cb_adc"+num2istr(i)
		
		itc_get_adc_scale_factor(ctrlName, telegraphsignal, scalefactor, scaleunit)
		
		sprintf tmpstr1, "Set ADC%d as:", i
		tmpstr2="\""+ReplaceString("_none_", ITC_TelegraphList, "ADC"+num2istr(i))+"\""
		TitleBox $("tb_adc"+num2istr(i)),win=ITCTelegraph,title=tmpstr1,pos={20,25*(i+1)+52},frame=0
		
		PopupMenu $("pm_adc"+num2istr(i)),win=ITCTelegraph,mode=telegraphsignal,bodywidth=80,value=#tmpstr2,pos={125,25*(i+1)+50},proc=itc_popproc_telegraphchoice
		TitleBox $("tb_scale_adc"+num2istr(i)),win=ITCTelegraph,title="1 V scale =",pos={180,25*(i+1)+52},frame=0
		SetVariable $("sv_scale_adc"+num2istr(i)),win=ITCTelegraph,pos={240,25*(i+1)+52},value=_NUM:scalefactor,limits={-inf,inf,0},size={50, 20},proc=itc_svproc_scalefactor
		SetVariable $("sv_scaleunit_adc"+num2istr(i)),win=ITCTelegraph,pos={290,25*(i+1)+52},value=_STR:scaleunit,size={50, 20},proc=itc_svproc_scalefactor
	endfor
	TitleBox tb_errormsg, win=ITCTelegraph, pos={20, 280},size={320,30},fixedsize=1
	Button btn_setEPC8default, win=ITCTelegraph, title="Defaults for EPC8", pos={20, 315}, size={150, 25}, proc=itc_btnproc_defaultTelegraph,userdata(status)="0"
	Button btn_apply, win=ITCTelegraph, title="Apply", pos={185,315}, size={150,25},proc=itc_btnproc_telegraph_commit
	itc_update_telegraphvar()
End

Function itc_btnproc_defaultTelegraph(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Variable status=str2num(GetUserData("ITCTelegraph", "btn_setEPC8default", "status"))
			if(status==0)
				itc_set_EPC8_telegraph_default(0)
				Button btn_setEPC8default, win=ITCTelegraph, title="Clear All Telegraph",userdata(status)="1"
			else
				itc_set_EPC8_telegraph_default(1)
				Button btn_setEPC8default, win=ITCTelegraph, title="Defaults for EPC8",userdata(status)="0"
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_set_EPC8_telegraph_default(c)
	Variable c
	
	if(c==0)
		itc_set_adc_scale_factor("itc_cb_adc0", 1, 1, "#GAIN")
		itc_set_adc_scale_factor("itc_cb_adc1", 1, 0.1, "V")
		itc_set_adc_scale_factor("itc_cb_adc2", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc3", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc4", 5, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc5", 2, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc6", 4, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc7", 3, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc16", 3, 1, "N/A")
	else
		itc_set_adc_scale_factor("itc_cb_adc0", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc1", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc2", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc3", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc4", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc5", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc6", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc7", 1, 1, "V")
		itc_set_adc_scale_factor("itc_cb_adc16", 1, 1, "N/A")
	endif
	itc_setup_telegraph()
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
				killwin("ITCTelegraph")
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function itc_update_telegraphvar([commit])
	Variable commit
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	
	NVAR ChnOnGainBinFlags=$WBPkgGetName(fPath, WBPkgDFVar, "ChannelOnGainBinFlag")
	WAVE scalefactor=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleFactor")
	WAVE /T scaleunit=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleUnit")
	WAVE telegraphassignment=$WBPkgGetName(fPath, WBPkgDFWave, "TelegraphAssignment")
	Make /FREE /N=(DimSize(scalefactor, 0)) tmpfactor
	Make /FREE /T /N=(DimSize(scaleunit, 0)) tmpunit
	Make /FREE /N=(ItemsInList(ITC_TelegraphList)-1) tmpassignment=-1, tmpcount=0; AbortOnRTE
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

					tmpchnongainflag=tmpchnongainflag | (1<<i)

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
			String factorstr
			for(i=0; i<8; i+=1)
				ctrlname="itc_cb_adc"+num2istr(i)
				param=GetUserData("ITCPanel", ctrlname, "param")
				param=ReplaceStringByKey("TELEGRAPH", param, num2istr(tmpadctelegraphflag[i]), "=", ";")
				sprintf factorstr, "%.6e", tmpfactor[i]
				param=ReplaceStringByKey("SCALEFACTOR", param, factorstr, "=", ";")
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

Function itc_btnproc_generatewave(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	
	NVAR recordingnum=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingNum")
	WAVE /T adcdatawavepath=$WBPkgGetName(fPath, WBPkgDFWave, "ADCDataWavePath")
		
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_setup_sealtest_default(pulsev, pulsew, [clear_channels])
	Variable pulsev, pulsew, clear_channels
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	NVAR samplingrate=$WBPkgGetName(fPath, WBPkgDFVar, "SamplingRate")
	NVAR recordinglen=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingLength")
	NVAR continuous=$WBPkgGetName(fPath, WBPkgDFVar, "ContinuousRecording")
	NVAR saverecording=$WBPkgGetName(fPath, WBPkgDFVar, "SaveRecording")
	NVAR chn_gain_flag=$WBPkgGetName(fPath, WBPkgDFVar, "ChannelOnGainBinFlag")
	
	Variable i
	samplingrate=ITC_DefaultSamplingRate
	recordinglen=0.2*3
	continuous=inf
	saverecording=0
	WBrowserCreateDF("root:seal_tests:")
	Make /O/N=(samplingrate*recordinglen)/D root:seal_tests:W_sealtestCmdV=0
	WAVE w=root:seal_tests:W_sealtestCmdV
	for(i=floor(recordinglen/pulsew/2)-1; i>=0; i-=1)
		w[samplingrate*pulsew*(i*2+0.5), samplingrate*pulsew*(i*2+1.5)]=pulsev*10 //EPC8 has a scale factor of 10 for DACs
	endfor

	String chninfo=GetUserData("ITCPanel", "itc_cb_adc0", "param")
	chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "root:seal_tests:","=", ";")
	chninfo=ReplaceStringByKey("WAVENAME", chninfo, "W_sealtest_I","=", ";")
	CheckBox itc_cb_adc0, win=ITCPanel, userdata(param)=chninfo, value=1
	
	chninfo=GetUserData("ITCPanel","itc_cb_adc1", "param")
	chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "root:seal_tests:","=", ";")
	chninfo=ReplaceStringByKey("WAVENAME", chninfo, "W_sealtest_V","=", ";")
	CheckBox itc_cb_adc1, win=ITCPanel, userdata(param)=chninfo, value=1
	
	if(!ParamIsDefault(clear_channels) && clear_channels==1)
		for(i=2; i<8; i+=1)
			chninfo=GetUserData("ITCPanel","itc_cb_adc"+num2istr(i), "param")
			chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "","=", ";")
			chninfo=ReplaceStringByKey("WAVENAME", chninfo, "","=", ";")
			CheckBox $("itc_cb_adc"+num2istr(i)), win=ITCPanel, userdata(param)=chninfo, value=0
		endfor
	endif
	
	chninfo=GetUserData("ITCPanel","itc_cb_dac0", "param")
	chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "root:seal_tests:","=", ";")
	chninfo=ReplaceStringByKey("WAVENAME", chninfo, "W_sealtestCmdV","=", ";")
	CheckBox itc_cb_dac0, win=ITCPanel, userdata(param)=chninfo, value=1
	
	if(!ParamIsDefault(clear_channels) && clear_channels==1)
		for(i=1; i<4; i+=1)
			chninfo=GetUserData("ITCPanel","itc_cb_dac"+num2istr(i), "param")
			chninfo=ReplaceStringByKey("DATAFOLDER", chninfo, "","=", ";")
			chninfo=ReplaceStringByKey("WAVENAME", chninfo, "","=", ";")
			CheckBox $("itc_cb_dac"+num2istr(i)), win=ITCPanel, userdata(param)=chninfo, value=0
		endfor
	endif
	chn_gain_flag=floor(chn_gain_flag)|1
	
	itc_update_chninfo("", 11)
End

Function itc_btnproc_sealtest(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Variable v=0.01, w=0.02 //10mV pulse
			PROMPT v, "test pulse amplitude, between 0V-1V"
			PROMPT w, "test pulse width, between 0.01-0.2 sec"
			DoPrompt "Seal Test Pulse", v, w
			if(V_Flag==0 && (v>=0 && v<=1) && (w>=0.01 && w<=0.2))
				itc_setup_sealtest_default(v, w, clear_channels=1)
				itc_start_task(flag=1)
			else
				print "Seal pulse generation cancelled."
			endif	
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
#if !defined(ITCDEBUG)
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
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	NVAR saverecording=$WBPkgGetName(fPath, WBPkgDFVar, "SaveRecording")
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
	StopITCTask()
	
	String nbname=UniqueName("ITCPanelLog", 10, 0)
	NewNoteBook /N=$nbname /F=1 /V=1 /K=3
	itc_updatenb("ITCPanel shutdown.\r")
	Notebook ITCPanel#ITCPanelLog getData=1
	Notebook $nbname setData=S_value,writeProtect=1
	print "All logged messages have been saved to notebook "+nbname
	print "Please make sure to save the notebook before you kill it."
	killwin("ITCPanel")
	killwin("ITCTelegraph")

	if(exists("root:ITCPanelRunning")!=2)
		Variable /G root:ITCPanelRunning=0
	else
		NVAR itcrunning=root:ITCPanelRunning
		itcrunning=0
	endif
	
	print "ITCPanel closed."
End

Function itc_update_chninfo(windowname, event)
	String windowname
	Variable event
	
	if(event!=11) //event is given by TableMonitorHook callback
		return -1
	endif
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	String adc_chn_wname=WBPkgGetName(fPath, WBPkgDFWave, "ADC_Channel")
	String dac_chn_wname=WBPkgGetName(fPath, WBPkgDFWave, "DAC_Channel")
	String adc_chndestfolder_wname=WBPkgGetName(fPath, WBPkgDFWave, "ADC_DestFolder")
	String adc_chndestwave_wname=WBPkgGetName(fPath, WBPkgDFWave, "ADC_DestWave")
	String dac_chnsrcfolder_wname=WBPkgGetName(fPath, WBPkgDFWave, "DAC_SrcFolder")
	String dac_chnsrcwave_wname=WBPkgGetName(fPath, WBPkgDFWave, "DAC_SrcWave")
	
	String selectedadcchn=WBPkgGetName(fPath, WBPkgDFWave, "SelectedADCChn")
	String selecteddacchn=WBPkgGetName(fPath, WBPkgDFWave, "SelectedDACChn")
	String adcdatawavepath=WBPkgGetName(fPath, WBPkgDFWave, "ADCDataWavePath")
	String dacdatawavepath=WBPkgGetName(fPath, WBPkgDFWave, "DACDataWavePath")
	String adcscalefactor=WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleFactor")
	String adcscaleunit=WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleUnit")
	
	Variable i, j
	
	try
		Make /N=9/O/T $adc_chn_wname;AbortOnRTE
		WAVE /T textw=$adc_chn_wname
		for(i=0; i<8; i+=1)
			textw[i]="ADC"+num2istr(i);AbortOnRTE
		endfor
		textw[8]="DIGITAL_IN"; AbortOnRTE
		
		Make /N=5/O/T $dac_chn_wname;AbortOnRTE
		WAVE /T textw=$dac_chn_wname
		for(i=0; i<4; i+=1)
			textw[i]="DAC"+num2istr(i);AbortOnRTE
		endfor
		textw[4]="DIGITAL_OUT"; AbortOnRTE
		
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
		
		Make /N=9/O/T $adc_chndestfolder_wname;AbortOnRTE
		WAVE /T wadcdestfolder=$adc_chndestfolder_wname
		Make /N=9/O/T $adc_chndestwave_wname;AbortOnRTE
		WAVE /T wadcdestwave=$adc_chndestwave_wname
		String ctrlname=""
		String param=""
		String s1=""
		Variable CountADC=0
		Variable CountDAC=0

		Variable telegraph, scalefactor
		String scaleunit

		String ChnListStr=""; //this is to keep track of selected channels
			
		for(i=0; i<9; i+=1)
			if(i<8)
				ctrlname="itc_cb_adc"+num2istr(i)
			else
				ctrlname="itc_cb_adc16" //DIGITAL INPUT CHANNE
			endif
			itc_get_adc_scale_factor(ctrlname, telegraph, scalefactor, scaleunit, param=param)
			
			if(telegraph!=1) // telegraph is enabled
				s1=StringFromList(telegraph-1, ITC_TelegraphList); AbortOnRTE
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
					ChnListStr+=ctrlname+";"
				endif
			endif
			
			CheckBox $ctrlname, win=ITCPanel, userdata(param)=param; AbortOnRTE
			
		endfor
		
		GroupBox itc_grp_ADC win=ITCPanel, userdata(selected)=num2istr(CountADC), userdata(selected_list)=ChnListStr;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_adclist $adc_chndestfolder_wname;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_adclist $adc_chndestwave_wname;AbortOnRTE
		
		Make /N=5/O/T $dac_chnsrcfolder_wname;AbortOnRTE
		WAVE /T wdacsrcfolder=$dac_chnsrcfolder_wname
		Make /N=5/O/T $dac_chnsrcwave_wname;AbortOnRTE
		WAVE /T wdacsrcwave=$dac_chnsrcwave_wname

		ChnListStr=""; //this is to keep track of selected channels
		
		for(i=0; i<5; i+=1)
			if(i<4)
				ctrlname="itc_cb_dac"+num2istr(i)
			else
				ctrlname="itc_cb_dac8" //DIGITAL OUTPUT
			endif
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
				ChnListStr+=ctrlname+";"
			endif
		endfor
		GroupBox itc_grp_DAC win=ITCPanel,userdata(selected)=num2istr(CountDAC), userdata(selected_list)=ChnListStr;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_daclist $dac_chnsrcfolder_wname;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_daclist $dac_chnsrcwave_wname	;AbortOnRTE
		
		AppendToTable /W=ITCPanel#itc_tbl_adclist $adcscalefactor;AbortOnRTE
		AppendToTable /W=ITCPanel#itc_tbl_adclist $adcscaleunit;AbortOnRTE
		
		ModifyTable /W=ITCPanel#itc_tbl_adclist entryMode=0,showParts=(0+2+4+0+16+32+64+0),autosize={1,0,-1,0,0}
		ModifyTable /W=ITCPanel#itc_tbl_daclist entryMode=0,showParts=(0+2+4+0+16+32+64+0),autosize={1,0,-1,0,0}
	
		//prepare the selected channels record
		Make /O /N=(countADC) $selectedadcchn=0; AbortOnRTE
		WAVE chnlist=$selectedadcchn; AbortOnRTE
		Make /O /T /N=(countADC) $adcdatawavepath=""; AbortOnRTE
		WAVE /T wavepaths=$adcdatawavepath; AbortOnRTE
		// to do get read length, set up the wave to the proper length
		j=0
		Variable chn_num
		for(i=0; i<9; i+=1)
			if(i<8)
				ControlInfo /W=ITCPanel $("itc_cb_adc"+num2istr(i))
				chn_num=i
			else
				ControlInfo /W=ITCPanel $("itc_cb_adc16")
				chn_num=16
			endif
			if(V_value==1)
				chnlist[j]=chn_num; AbortOnRTE
				wavepaths[j]=wadcdestfolder[i]+wadcdestwave[i]; AbortOnRTE
				j+=1
			endif
		endfor
		
		//For DAC channels, if no DAC channel is selected, the first DAC channel will still be used as default (but filled with a constant value). 
		//otherwise the actual wave will be used.
		if(CountDAC==0)
			CountDAC=1
		endif
		Make /O /N=(countDAC) $selecteddacchn=0
		WAVE chnlist=$selecteddacchn; AbortOnRTE
		Make /O /T /N=(countDAC) $dacdatawavepath=""; AbortOnRTE //"" means the user has not specified a wave for this DAC channel, this is the default
		WAVE /T wavepaths=$dacdatawavepath
		j=0
		for(i=0; i<5; i+=1)
			if(i<4)
				ControlInfo /W=ITCPanel $("itc_cb_dac"+num2istr(i))
				chn_num=i
			else
				ControlInfo /W=ITCPanel $("itc_cb_dac8")
				chn_num=8
			endif
			if(V_value==1)
				chnlist[j]=Chn_num; AbortOnRTE
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

Function itc_cbproc_digitals(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	Variable i
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	NVAR digitals=$WBPkgGetName(fPath, WBPkgDFVar, "DigitalChannels"); AbortOnRTE
	int bitset=0
	switch( cba.eventCode )
		case 2: // mouse up			
			for(i=0; i<=7; i+=1)
				String ctrlname="itc_cb_digital"+num2istr(i)
				ControlInfo /W=ITCPanel $ctrlname
				if(V_value==1)
					bitset+=1<<i
				endif
			endfor
			digitals=bitset
#ifndef ITCDEBUG
			LIH_SetDigital(digitals)
#endif
			break
		case -1: // control being killed
			break
	endswitch	
	
	return 0
End

Function itc_paste_procedure_code(prototypename, newfunc_name)
	String prototypename, newfunc_name
	Variable retVal=0
	
	String funclist=FunctionList("*", ";", "")
	if(WhichListItem(prototypename, funclist)<0 || WhichListItem(newfunc_name, funclist)>=0)
		retVal=-1
	else	
		String templatestr=ProcedureText(prototypename, 0, "")
		templatestr=ReplaceString(prototypename, templatestr, newfunc_name, 1)
		templatestr="\r"+templatestr+"\r"
		DisplayProcedure /W=$"Procedure" /L=(2^30) //large enough line number, should scroll to the last line
		GetSelection procedure, $"Procedure", 2
		PutScrapText S_selection+templatestr
		DoIgorMenu "Edit", "Paste"
		Execute/P/Q "COMPILEPROCEDURES "
		Execute/P/Q "DisplayProcedure /W=$\"Procedure\" \""+newfunc_name+"\""
	endif
	
	return retVal
End

Function itc_cbproc_setuserfunc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			try
				Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
				String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
				SVAR usrfuncname=$WBPkgGetName(fPath, WBPkgDFStr, "UserDataProcessFunction")

				SVAR TaskRecordingCount=$WBPkgGetName(fPath, WBPkgDFStr, "TaskRecordingCount")
			
				int64 cycle_count, total_count
				sscanf TaskRecordingCount, "%x,%x", total_count, cycle_count
				 
			
				NVAR SamplingRate=$WBPkgGetName(fPath, WBPkgDFVar, "SamplingRate")
				NVAR RecordingSize=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingSize")
			
				WAVE adcdata=$WBPkgGetName(fPath, WBPkgDFWave, "ADCData")
				WAVE dacdata=$WBPkgGetName(fPath, WBPkgDFWave, "DACData")
				
				WAVE selectedadcchn=$WBPkgGetName(fPath, WBPkgDFWave, "SelectedADCChn")
				WAVE selecteddacchn=$WBPkgGetName(fPath, WBPkgDFWave, "SelectedDACChn")
				
				Variable selectedadc_number=DimSize(selectedadcchn, 0)
				Variable selecteddac_number=DimSize(selecteddacchn, 0)
		
				Variable userfunc_ret=0
				
				if(checked)
					checked=0
					String funclist="_none_;_create_new_;"+FunctionList("ITCUSERFunc_*", ";", "KIND:2,NPARAMS:9,VALTYPE:1")
					String selected_func=""
					PROMPT selected_func, "Select real-time data process function", popup funclist
					DoPrompt "select function", selected_func
					if(V_flag==0)
						strswitch(selected_func)
						case "_none_":
							checked=0
							break
						case "_create_new_":
							String newfunc_name="MyDataProcFunc"
							PROMPT newfunc_name, "Enter a name for the new user data processing function:"
							
							do
								checked=-1
								DoPrompt "Set new function name", newfunc_name
							
								if(V_flag==0)
									checked=itc_paste_procedure_code("prototype_userdataprocessfunc", newfunc_name)
									if(checked!=0)
										DoAlert 0, "Either the prototype function does not exist or the name of your function has already been used."								
									endif
								else
									checked=0
								endif
							while(checked==-1)
							checked=0
							break
						default:
							checked=1
						endswitch
					endif
				endif
				if(!checked)
					userfunc_ret=0
					if(strlen(usrfuncname)>0)
						FUNCREF prototype_userdataprocessfunc refFunc=$usrfuncname
						if(str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
							itc_update_taskinfo()
							userfunc_ret=refFunc(adcdata, dacdata, total_count, cycle_count, RecordingSize, selectedadc_number, selecteddac_number, SamplingRate, ITCUSERFUNC_DISABLE); AbortOnRTE
						endif
					endif
					usrfuncname = ""					
				else
					usrfuncname=selected_func
					userfunc_ret=0
					String tmpstr=""
					FUNCREF prototype_userdataprocessfunc refFunc=$usrfuncname
					if(str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
						itc_update_taskinfo()
						userfunc_ret=refFunc(adcdata, dacdata, total_count, cycle_count, RecordingSize, selectedadc_number, selecteddac_number, SamplingRate, ITCUSERFUNC_FIRSTCALL); AbortOnRTE
						if(userfunc_ret!=0) //user function cannot init properly
							sprintf tmpstr, "User function %s cannot initialize properly with return code %d... user function is removed.", usrfuncname, userfunc_ret
							itc_updatenb(tmpstr)
							checked=0
							usrfuncname=""
						endif
					endif
				endif
				CheckBox itc_cb_userfunc win=ITCPanel, value=checked
			catch
				print "error!"
			endtry
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

Function StartITCTask()
	Variable numTicks=ITCTASK_TICK
	CtrlNamedBackground itc_bgTask, period=numTicks,proc=ITCPanel#itc_bgTask
	CtrlNamedBackground itc_bgTask,burst=0,dialogsOK=1
	CtrlNamedBackground itc_bgTask, start
End

Function StopITCTask()
	CtrlNamedBackground itc_bgTask, stop
	
#if !defined(ITCDEBUG)
	LIH_Halt()
#endif
End

Function itc_start_task([flag])
	Variable flag
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	NVAR TaskStatus=$WBPkgGetName(fPath, WBPkgDFVar, "Status")
	NVAR Continuous=$WBPkgGetName(fPath, WBPkgDFVar, "ContinuousRecording")

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
			itc_update_taskinfo()
			itc_start_task()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function itc_rtgraph_init(left, top, right, bottom)
	Variable left, top, right, bottom
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	String wname=WBPkgGetName(fPath, WBPkgDFWave, "ADCData")
	WAVE selectedchn=$WBPkgGetName(fPath, WBPkgDFWave, "selectedadcchn")
	WAVE /T chnlist=$WBPkgGetName(fPath, WBPkgDFWave, "ADC_Channel")
	String chnname=chnlist[selectedchn[0]]; AbortOnRTE
	String selchn_list1="\""+chnname
	String selchn_list2="\"_none_;"+chnname
	Variable i
	for(i=1; i<DimSize(selectedchn, 0); i+=1)
		if(selectedchn[i]<8)
			selchn_list1+=";"+chnlist[selectedchn[i]]
			selchn_list2+=";"+chnlist[selectedchn[i]]
		else
			selchn_list1+=";"+"DIGITAL_IN"
			selchn_list2+=";"+"DIGITAL_IN"
		endif
	endfor
	selchn_list1+="\""
	selchn_list2+="\""

	NewPanel /EXT=0 /HOST=ITCPanel /N=rtgraphpanel /W=(0, 0, 150, 0) /K=2
	PopupMenu rtgraph_trace1name win=ITCPanel#rtgraphpanel,title="Trace1 Channel",value=#selchn_list1,mode=1,size={150,20},userdata(tracename)="1",proc=rtgraph_popproc_trace
	PopupMenu rtgraph_trace1color win=ITCPanel#rtgraphpanel,title="Trace1 Color",popColor=(65280,0,0),value="*COLORPOP*",size={150,20},proc=rtgraph_popproc_tracecolor
	SetVariable rtgraph_miny1 win=ITCPanel#rtgraphpanel,title="MinY1",value=_NUM:-10,size={120,20},limits={-inf, inf, 0},userdata(tracename)="1",disable=2,proc=rtgraph_svproc_setyaxis
	SetVariable rtgraph_maxy1 win=ITCPanel#rtgraphpanel,title="MaxY1",value=_NUM:10,size={120,20},limits={-inf, inf, 0},userdata(tracename)="1",disable=2,proc=rtgraph_svproc_setyaxis
	CheckBox rtgraph_autoy1 win=ITCPanel#rtgraphpanel,title="AutoY1",size={120,20},value=1,userdata(tracename)="1",proc=rtgraph_cbproc_autoy
	
	Variable ch2_sel, ch2_disable, ch2_split
	if(ItemsInList(selchn_list2)>2)
		ch2_sel=3
		ch2_disable=0
		ch2_split=1
	else
		ch2_sel=1
		ch2_disable=2
		ch2_split=0
	endif
	PopupMenu rtgraph_trace2name win=ITCPanel#rtgraphpanel,title="Trace2 Channel",value=#selchn_list2,mode=ch2_sel,size={150,20},userdata(tracename)="2",proc=rtgraph_popproc_trace
	PopupMenu rtgraph_trace2color win=ITCPanel#rtgraphpanel,title="Trace2 Color",popColor=(0,0,65280),value="*COLORPOP*",size={150,20},disable=ch2_disable,proc=rtgraph_popproc_tracecolor
	SetVariable rtgraph_miny2 win=ITCPanel#rtgraphpanel,title="MinY2",value=_NUM:-10,size={120,20},limits={-inf, inf, 0},userdata(tracename)="2",disable=2,proc=rtgraph_svproc_setyaxis
	SetVariable rtgraph_maxy2 win=ITCPanel#rtgraphpanel,title="MaxY2",value=_NUM:10,size={120,20},limits={-inf, inf, 0},userdata(tracename)="2",disable=2,proc=rtgraph_svproc_setyaxis
	CheckBox rtgraph_autoy2 win=ITCPanel#rtgraphpanel,title="AutoY2",size={120,20},value=1, disable=ch2_disable,userdata(tracename)="2",proc=rtgraph_cbproc_autoy
	
	SetVariable rtgraph_minx win=ITCPanel#rtgraphpanel,title="MinX",value=_NUM:0,size={120,20},limits={-inf, inf, 0},disable=2,proc=rtgraph_svproc_setxaxis
	SetVariable rtgraph_maxx win=ITCPanel#rtgraphpanel,title="MaxX",value=_NUM:(DimSize($wname, 0)*DimDelta($wname,0)),size={120,20},limits={-inf, inf, 0},disable=2,proc=rtgraph_svproc_setxaxis
	CheckBox rtgraph_autox win=ITCPanel#rtgraphpanel,title="AutoX",size={120,20}	,value=1,proc=rtgraph_cbproc_autox
	
	PopupMenu rtgraph_viewmode win=ITCPanel#rtgraphpanel,title="ViewMode",value="None;Single;Split;Y1vsY2;Y2vsY1;Custom;",mode=3,size={150,20},proc=rtgraph_popproc_viewmode

	Button rtgraph_showinfo win=ITCPanel#rtgraphpanel,title="Show info cursors",size={120,20},proc=rtgraph_btnproc_showinfo,userdata(status)="0"
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
					CheckBox rtgraph_autoy2 win=ITCPanel#rtgraphpanel, value=1, disable=2
					PopupMenu rtgraph_viewmode win=ITCPanel#rtgraphpanel, mode=2

				else
					PopupMenu rtgraph_trace2color win=ITCPanel#rtgraphpanel, disable=0
					SetVariable rtgraph_miny2 win=ITCPanel#rtgraphpanel, disable=2
					SetVariable rtgraph_maxy2 win=ITCPanel#rtgraphpanel, disable=2
					CheckBox rtgraph_autoy2 win=ITCPanel#rtgraphpanel, disable=0,value=1
					PopupMenu rtgraph_viewmode win=ITCPanel#rtgraphpanel, mode=3

				endif
			endif
			rtgraph_update_display()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_popproc_viewmode(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			rtgraph_update_display()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_popproc_tracecolor(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up			
			rtgraph_update_display()
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
			String axisname
			ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_viewmode
			Variable viewmode = V_value
			if(viewmode==2)
				if(tracenum!=1)
					axisname="right"+tracenumstr
				else
					axisname="left"+tracenumstr
				endif
			elseif(viewmode==3)
				axisname="left"+tracenumstr
			endif
			
			if(viewmode==2 || viewmode ==3)
				if(checked)
					SetVariable $controlname_miny win=ITCPanel#rtgraphpanel, disable=2
					SetVariable $controlname_maxy win=ITCPanel#rtgraphpanel, disable=2
					SetAxis /W=ITCPanel#rtgraph /A/N=2 $axisname
				else
					GetAxis /W=ITCPanel#rtgraph /Q $axisname
					SetVariable $controlname_miny win=ITCPanel#rtgraphpanel, value=_NUM:V_min, disable=0
					SetVariable $controlname_maxy win=ITCPanel#rtgraphpanel, value=_NUM:V_max, disable=0
					SetAxis /W=ITCPanel#rtgraph $axisname, V_min, V_max
				endif
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_cbproc_split(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			rtgraph_update_display()
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
			ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_viewmode
			Variable viewmode = V_value
			
			if(viewmode == 2 || viewmode == 3)
				if(checked)
					SetVariable rtgraph_minx win=ITCPanel#rtgraphpanel, disable=2
					SetVariable rtgraph_maxx win=ITCPanel#rtgraphpanel, disable=2
					SetAxis /W=ITCPanel#rtgraph /A/N=1 $("bottom1")
				else
					GetAxis /W=ITCPanel#rtgraph /Q $("bottom1")
					SetVariable rtgraph_minx win=ITCPanel#rtgraphpanel, value=_NUM:V_min, disable=0
					SetVariable rtgraph_maxx win=ITCPanel#rtgraphpanel, value=_NUM:V_max, disable=0
					SetAxis /W=ITCPanel#rtgraph $("bottom1"), V_min, V_max
				endif
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_svproc_setyaxis(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
			break
		case 2: // Enter key
			Variable dval = sva.dval
			String sval = sva.sval
			String tracenumstr=GetUserData("ITCPanel#rtgraphpanel", sva.ctrlName, "tracename")
			Variable tracenum=str2num(tracenumstr)
			String controlname_miny="rtgraph_miny"+tracenumstr
			String controlname_maxy="rtgraph_maxy"+tracenumstr
			
			Variable miny, maxy
			String axisname
			
			ControlInfo  /W=ITCPanel#rtgraphpanel $controlname_miny
			miny=V_value
			ControlInfo  /W=ITCPanel#rtgraphpanel $controlname_maxy
			maxy=V_value
			ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_viewmode
			Variable viewmode = V_value
			if(viewmode==2)
				if(tracenum!=1)
					axisname="right"+tracenumstr
				else
					axisname="left"+tracenumstr
				endif
				SetAxis /W=ITCPanel#rtgraph $axisname, miny, maxy
			elseif(viewmode==3)
				axisname="left"+tracenumstr
				SetAxis /W=ITCPanel#rtgraph $axisname, miny, maxy
			endif
			
			break
		case 3: // Live update			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_svproc_setxaxis(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
			break
		case 2: // Enter key
			Variable dval = sva.dval
			String sval = sva.sval
			Variable minx, maxx
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_minx
			minx=V_value
			
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_maxx
			maxx=V_value
			
			ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_viewmode
			Variable viewmode = V_value
			
			if(viewmode == 2 || viewmode == 3)
				SetAxis /W=ITCPanel#rtgraph $("bottom1"), minx, maxx
			endif
			break
		case 3: // Live update

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_btnproc_showinfo(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			//rtgraph_update_display()
			Variable status=str2num(GetUserData("ITCPanel#rtgraphpanel", ba.ctrlName, "status" ))
			if(status==0)
				ShowInfo /W=ITCPanel
				Button rtgraph_showinfo win=ITCPanel#rtgraphpanel,title="Hide info cursors",userdata(status)="1"
			else
				HideInfo /W=ITCPanel
				Button rtgraph_showinfo win=ITCPanel#rtgraphpanel,title="Show info cursors",userdata(status)="0"
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rtgraph_update_display()

	try
		Variable instance=WBPkgGetLatestInstance(ITC_PackageName); AbortOnRTE
		String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance); AbortOnRTE
		String dataname=WBPkgGetName(fPath, WBPkgDFWave, "ADCData"); AbortOnRTE
		WAVE datawave=$dataname; AbortOnRTE
		String dacdataname=WBPkgGetName(fPath, WBPkgDFWave, "DACData"); AbortOnRTE
		WAVE dacdatawave=$dataname; AbortOnRTE
		dataname=StringFromList(ItemsInList(dataname, ":")-1, dataname, ":"); AbortOnRTE
		WAVE selectedchn=$WBPkgGetName(fPath, WBPkgDFWave, "selectedadcchn"); AbortOnRTE
		WAVE /T chnlist=$WBPkgGetName(fPath, WBPkgDFWave, "ADC_Channel"); AbortOnRTE
		WAVE /T chnunit=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleUnit"); AbortOnRTE
		SVAR UserFunc=$WBPkgGetName(fPath, WBPkgDFStr, "UserDataProcessFunction"); AbortOnRTE
		NVAR SamplingRate=$WBPkgGetName(fPath, WBPkgDFVar, "SamplingRate"); AbortOnRTE
		NVAR RecordingSize=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingSize"); AbortOnRTE
		
		String chnname_1, chnname_2
		
		do
			String tracelist=TraceNameList("ITCPanel#rtgraph", ";", 1)
			Variable n=ItemsInList(tracelist)
			if(n>0)
				RemoveFromGraph /W=ITCPanel#rtgraph /Z $StringFromList(0, tracelist); AbortOnRTE
			endif
		while(n>0)
		
		Variable split = 0
		ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_viewmode;AbortOnRTE
		Variable viewmode = V_value
		
		TextBox /W=ITCPanel#rtgraph/K/N=RTTextBox0
		
		if(viewmode == 1) //None
			TextBox /W=ITCPanel#rtgraph/C/N=RTTextBox0/F=0/Z=1/A=MC/X=0.00/Y=0.00 "\\Z18Real-time display disabled"
			return 0
		endif
		
		if(viewmode == 2 || viewmode == 3 || viewmode == 4 || viewmode == 5)
		
			if(viewmode == 3)
				split = 1
			endif
		
			String xaxis="bottom1", yaxis_1="left1"
			Variable chn_1, chn_2
			
			//first trace
			ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_trace1name; AbortOnRTE
			chn_1=V_value-1
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_trace1color; AbortOnRTE
			Variable r1=V_red, g1=V_green, b1=V_blue
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_autoy1; AbortOnRTE
			Variable autoy_1=V_value
			Variable miny_1, maxy_1
			if(autoy_1==1)
				miny_1=NaN
				maxy_1=NaN
			else
				ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_miny1; AbortOnRTE
				miny_1=V_value
				ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_maxy1; AbortOnRTE
				maxy_1=V_Value	
			endif
			ControlInfo  /W=ITCPanel#rtgraphpanel  rtgraph_autox; AbortOnRTE
			Variable autox_1=V_value
			Variable minx_1, maxx_1
			if(autox_1==1)
				minx_1=NaN
				maxx_1=NaN
			else
				ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_minx; AbortOnRTE
				minx_1=V_value
				ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_maxx; AbortOnRTE
				maxx_1=V_value
			endif
				
			chnname_1=chnlist[selectedchn[chn_1]]; AbortOnRTE			
			
			String yaxis_2=""
			
			//second trace
			ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_trace2name; AbortOnRTE
			chn_2=V_value-2
			
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_trace2color; AbortOnRTE
			Variable r2=V_red, g2=V_green, b2=V_blue
			ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_autoy2; AbortOnRTE
			Variable autoy_2=V_value
			Variable miny_2, maxy_2
			if(autoy_2==1)
				miny_2=NaN
				maxy_2=NaN
			else
				ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_miny2; AbortOnRTE
				miny_2=V_value
				ControlInfo  /W=ITCPanel#rtgraphpanel rtgraph_maxy2; AbortOnRTE
				maxy_2=V_Value	
			endif
			
			chnname_2=chnlist[selectedchn[chn_2]]; AbortOnRTE
			
			if(viewmode == 2 || viewmode == 3) //single or split view of selected trace(s)
				AppendToGraph /W=ITCPanel#rtgraph /L=$yaxis_1 /B=$xaxis datawave[][chn_1]; AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos($yaxis_1)=0,lblPos($yaxis_1)=60,notation($yaxis_1)=0,ZisZ($yaxis_1)=1,fsize=12; AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph freePos($xaxis)=0,lblPos($xaxis)=40,notation($xaxis)=0,fsize=12,ZisZ=1; AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph rgb($dataname)=(r1, g1, b1); AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph margin(left)=80; AbortOnRTE
				if(split)
					ModifyGraph /W=ITCPanel#rtgraph margin(right)=25; AbortOnRTE
				else
					ModifyGraph /W=ITCPanel#rtgraph margin(right)=80; AbortOnRTE
				endif
		
				Label /W=ITCPanel#rtgraph $yaxis_1 chnname_1+" (\\E"+chnunit[selectedchn[chn_1]]+")"; AbortOnRTE
				Label /W=ITCPanel#rtgraph $xaxis "time (\\U)"; AbortOnRTE
				
				if(autox_1==1)
					SetAxis /W=ITCPanel#rtgraph /A=2/N=1 $xaxis; AbortOnRTE
				else
					SetAxis /W=ITCPanel#rtgraph $xaxis, minx_1, maxx_1; AbortOnRTE
				endif
				ModifyGraph /W=ITCPanel#rtgraph lowTrip($xaxis)=0.01; AbortOnRTE
				
				if(autoy_1==1)
					SetAxis /W=ITCPanel#rtgraph /A=2/N=2 $yaxis_1; AbortOnRTE
				else
					SetAxis /W=ITCPanel#rtgraph $yaxis_1, miny_1, maxy_1; AbortOnRTE
				endif
				ModifyGraph /W=ITCPanel#rtgraph lowTrip($yaxis_1)=0.01; AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph tlblRGB($yaxis_1)=(r1, g1, b1); AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph alblRGB($yaxis_1)=(r1, g1, b1); AbortOnRTE
				
				if(chn_2>=0)
					if(split==1)
						ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis_1)={0.52,1}; AbortOnRTE
						yaxis_2="left2"
					else
						ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis_1)={0,1}; AbortOnRTE
						yaxis_2="right2"
					endif
				
					if(split==1)
						AppendToGraph /W=ITCPanel#rtgraph /L=$yaxis_2 /B=$xaxis datawave[][chn_2]; AbortOnRTE
					else
						AppendToGraph /W=ITCPanel#rtgraph /R=$yaxis_2 /B=$xaxis datawave[][chn_2]; AbortOnRTE
					endif
					ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos($yaxis_2)=0,lblPos($yaxis_2)=60,notation($yaxis_2)=0,ZisZ($yaxis_2)=1,fsize=12; AbortOnRTE
					ModifyGraph /W=ITCPanel#rtgraph rgb($(dataname+"#1"))=(r2, g2, b2); AbortOnRTE
					
					Label /W=ITCPanel#rtgraph $yaxis_2 chnname_2+" (\\E"+chnunit[selectedchn[chn_2]]+")"; AbortOnRTE
					
					if(autoy_2==1)
						SetAxis /W=ITCPanel#rtgraph /A=2/N=2 $yaxis_2; AbortOnRTE
					else
						SetAxis /W=ITCPanel#rtgraph $yaxis_2, miny_2, maxy_2; AbortOnRTE
					endif
					ModifyGraph /W=ITCPanel#rtgraph lowTrip($yaxis_2)=0.01; AbortOnRTE
					
					if(split==1)
						ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis_2)={0,0.48}; AbortOnRTE
					else
						ModifyGraph /W=ITCPanel#rtgraph axisEnab($yaxis_2)={0,1}; AbortOnRTE
					endif
					ModifyGraph /W=ITCPanel#rtgraph tlblRGB($yaxis_2)=(r2, g2, b2); AbortOnRTE
					ModifyGraph /W=ITCPanel#rtgraph alblRGB($yaxis_2)=(r2, g2, b2); AbortOnRTE
				endif
			endif
			
			if(chn_2>=0 && (viewmode == 4 || viewmode == 5)) //Y1 vs Y2 or Y2 vs Y1
				if(viewmode == 4)
					AppendToGraph /W=ITCPanel#rtgraph /L=$yaxis_1 /B=$xaxis datawave[][chn_1] vs datawave[][chn_2]
				endif
				if(viewmode == 5)
					AppendToGraph /W=ITCPanel#rtgraph /L=$yaxis_1 /B=$xaxis datawave[][chn_2] vs datawave[][chn_1]
				endif
				ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos($yaxis_1)=0,lblPos($yaxis_1)=60,notation($yaxis_1)=0,ZisZ($yaxis_1)=1,fsize=12; AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph freePos($xaxis)=0,lblPos($xaxis)=40,notation($xaxis)=0,fsize=12,ZisZ=1; AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph rgb($dataname)=(r1, g1, b1); AbortOnRTE
				ModifyGraph /W=ITCPanel#rtgraph margin(left)=80,margin(right)=80; AbortOnRTE
				
				if(viewmode == 4)
					Label /W=ITCPanel#rtgraph $yaxis_1 chnname_1+" (\\E"+chnunit[selectedchn[chn_1]]+")"; AbortOnRTE
					Label /W=ITCPanel#rtgraph $xaxis chnname_2+" (\\E"+chnunit[selectedchn[chn_2]]+")"; AbortOnRTE
				endif
				if(viewmode == 5)
					Label /W=ITCPanel#rtgraph $yaxis_1 chnname_2+" (\\E"+chnunit[selectedchn[chn_2]]+")"; AbortOnRTE
					Label /W=ITCPanel#rtgraph $xaxis chnname_1+" (\\E"+chnunit[selectedchn[chn_1]]+")"; AbortOnRTE
				endif
			endif
		endif
		
		if(viewmode == 6) //custome display
			if(strlen(UserFunc)>0)
				FUNCREF prototype_userdataprocessfunc refFunc=$UserFunc
				if(str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
					refFunc(datawave, dacdatawave, 0, 0, RecordingSize, 0, 0, SamplingRate, ITCUSERFUNC_CUSTOMDISPLAY); AbortOnRTE
				endif
			endif
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
	killwin("ITCPanel#rtgraph")
	killwin("ITCPanel#rtgraphpanel")
	HideInfo /W=ITCPanel
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
		CheckBox itc_cb_adc16 win=ITCPanel,disable=0
	
		CheckBox itc_cb_dac0  win=ITCPanel,disable=0
		CheckBox itc_cb_dac1  win=ITCPanel,disable=0
		CheckBox itc_cb_dac2  win=ITCPanel,disable=0
		CheckBox itc_cb_dac3  win=ITCPanel,disable=0
		CheckBox itc_cb_dac8  win=ITCPanel,disable=0	
		
		Button itc_btn_telegraph win=ITCPanel,disable=0
		Button itc_btn_setsealtest win=ITCPanel,disable=0
		Button itc_btn_displastrecord win=ITCPanel,disable=0
		Button itc_btn_updatedacdata win=ITCPanel,disable=0
		
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
		
		CheckBox itc_cb_userfunc win=ITCPanel, disable=0
		CheckBox itc_cb_forcereset win=ITCPanel, disable=0
		
		GroupBox itc_grp_rtdigital win=ITCPanel, disable=0
		CheckBox itc_cb_digital0  win=ITCPanel,disable=0
		CheckBox itc_cb_digital1  win=ITCPanel,disable=0
		CheckBox itc_cb_digital2  win=ITCPanel,disable=0
		CheckBox itc_cb_digital3  win=ITCPanel,disable=0
		CheckBox itc_cb_digital4  win=ITCPanel,disable=0
		CheckBox itc_cb_digital5  win=ITCPanel,disable=0
		CheckBox itc_cb_digital6  win=ITCPanel,disable=0
		CheckBox itc_cb_digital7  win=ITCPanel,disable=0
		
		SetWindow ITCPanel#itc_tbl_adclist hide=0,needUpdate=1;DoUpdate
		SetWindow ITCPanel#itc_tbl_daclist hide=0,needUpdate=1;DoUpdate
		itc_rtgraph_quit()
		
		MoveSubWindow /W=ITCPanel#ITCPanelLog fnum=(600,300,795,440); DoUpdate
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
		CheckBox itc_cb_adc16 win=ITCPanel,disable=2
	
		CheckBox itc_cb_dac0  win=ITCPanel,disable=2
		CheckBox itc_cb_dac1  win=ITCPanel,disable=2
		CheckBox itc_cb_dac2  win=ITCPanel,disable=2
		CheckBox itc_cb_dac3  win=ITCPanel,disable=2
		CheckBox itc_cb_dac8  win=ITCPanel,disable=2

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
		
		GroupBox itc_grp_rtdigital win=ITCPanel, disable=1
		CheckBox itc_cb_digital0  win=ITCPanel,disable=1
		CheckBox itc_cb_digital1  win=ITCPanel,disable=1
		CheckBox itc_cb_digital2  win=ITCPanel,disable=1
		CheckBox itc_cb_digital3  win=ITCPanel,disable=1
		CheckBox itc_cb_digital4  win=ITCPanel,disable=1
		CheckBox itc_cb_digital5  win=ITCPanel,disable=1
		CheckBox itc_cb_digital6  win=ITCPanel,disable=1
		CheckBox itc_cb_digital7  win=ITCPanel,disable=1
		
		CheckBox itc_cb_userfunc win=ITCPanel, disable=2
		CheckBox itc_cb_forcereset win=ITCPanel, disable=2
		
		SetWindow ITCPanel#itc_tbl_adclist hide=1,needUpdate=1; DoUpdate
		SetWindow ITCPanel#itc_tbl_daclist hide=1,needUpdate=1; DoUpdate

		itc_rtgraph_init(118, 58, 795,318)
		MoveSubWindow /W=ITCPanel#ITCPanelLog fnum=(120, 320, 795, 405); DoUpdate
		DoUpdate /W=ITCPanel
	endif
End

Function itc_reload_dac_from_src(countDAC, wavepaths, dacwave)
	Variable countDAC
	WAVE /T wavepaths
	WAVE dacwave
	
	Variable i
	String tmpstr
	for(i=0; i<countDAC; i+=1) //if countDAC==0, that means no DAC has been selected, 
									 // and dacdata by default should have been filled with a single value set by 
									 // the RealTime DAC controls with no changes
		if(strlen(wavepaths[i])>0) // if no DAC is selected, this string should be ""
			WAVE srcwave=$wavepaths[i]; AbortOnRTE
			Variable n1=DimSize(dacwave, 0); AbortOnRTE
			Variable n2=DimSize(srcwave, 0); AbortOnRTE
			if(n1!=n2)
				sprintf tmpstr, "Warning: DAC source wave %s contains %d points while DAC buffer length is %d.", wavepaths[i], n2, n1; AbortOnRTE
				itc_updatenb(tmpstr, r=32768, g=0, b=0); AbortOnRTE
				if(n1>n2)
					n1=n2
				endif
			endif
			multithread dacwave[0,n1-1][i]=srcwave[p]; AbortOnRTE
		endif
	endfor
End

Function itc_update_taskinfo()
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	
	Variable retVal=-1

	itc_update_chninfo("", 11)
	//fill ADC channel indice and wave names
	WAVE /T wadcdestfolder=$WBPkgGetName(fPath, WBPkgDFWave, "ADC_DestFolder")
	WAVE /T wadcdestwave=$WBPkgGetName(fPath, WBPkgDFWave, "ADC_DestWave")
	WAVE /T wdacsrcfolder=$WBPkgGetName(fPath, WBPkgDFWave, "DAC_SrcFolder")
	WAVE /T wdacsrcwave=$WBPkgGetName(fPath, WBPkgDFWave, "DAC_SrcWave")
	String adcdata=WBPkgGetName(fPath, WBPkgDFWave, "ADCData")
	String dacdata=WBPkgGetName(fPath, WBPkgDFWave, "DACData")
	
	Variable countADC=str2num(GetUserdata("ITCPanel", "itc_grp_ADC", "selected"))
	Variable countDAC=str2num(GetUserdata("ITCPanel", "itc_grp_DAC", "selected"))
	
	NVAR recordinglen=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingLength")
	NVAR samplingrate=$WBPkgGetName(fPath, WBPkgDFVar, "SamplingRate")
	NVAR recordingsize=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingSize")
	NVAR blocksize=$WBPkgGetName(fPath, WBPkgDFVar, "BlockSize")
	
	String dacdatawavepath=WBPkgGetName(fPath, WBPkgDFWave, "DACDataWavePath")
	
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
		
	try
		//prepare ADCData and DACData
		recordingsize=round(samplingrate*recordinglen)
		if(recordingsize>ITCMaxBlockSize)
			blocksize=ITCMaxBlockSize
		else
			blocksize=recordingsize
		endif
		Make /O /D /N=(recordingsize, countADC) $adcdata=0; AbortOnRTE
		
		if(countDAC==0) //if no DAC is selected, dac0 will be used for the task, and it will hold a constant value as set by the 
							 //realtime dac setvariable control
							 //THE DIGITAL CHANNEL BY DEFAULT WILL RESET TO ALL ZEROES IF NOT SELECTED
			ControlInfo /W=ITCPanel itc_sv_rtdac0	
			Make /O /D /N=(recordingsize, 1) $dacdata=V_Value; AbortOnRTE
		else
			Make /O /D /N=(recordingsize, countDAC) $dacdata=0; AbortOnRTE
		endif
		
		j=0
		WAVE dacwave=$dacdata	
		WAVE /T wavepaths=$dacdatawavepath
		
		if(countDAC>0)
			itc_reload_dac_from_src(countDAC, wavepaths, dacwave)
		endif

		//preapare Telegraph assignments and scale factors
		WAVE TelegraphAssignment=$WBPkgGetName(fPath, WBPkgDFWave, "TelegraphAssignment"); AbortOnRTE
		WAVE adcscale=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleFactor"); AbortOnRTE
		WAVE /T adcunit=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleUnit"); AbortOnRTE
		
		Variable telegraph, scalefactor
		String scaleunit
		String ctrlname
		for(i=0; i<9; i+=1)
			if(i<8)
				ctrlname="itc_cb_adc"+num2istr(i)
			else
				ctrlname="itc_cb_adc16"
			endif
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

StrConstant ITC_TelegraphMODEList="VClamp;CClamp;LFVC 100;LFVC 30;LFVC 10;LFVC 3;LFVC 1"
StrConstant ITC_TelegraphFILTERList="100Hz;300Hz;500Hz;700Hz;1KHz;3KHz;5KHz;7KHz;10KHz;30KHz;100KHz"
StrConstant ITC_TelegraphGAINList="0.005;0.01;0.02;0.05;0.1;0.2;0.5;1;2;5;10;20;50;100;200;500;1000;2000"

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
			String gainstr=StringFromList(v, ITC_TelegraphGAINList)
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
			//sprintf infostr, "FILTER=%s#%.4f;", StringFromList(v, ITC_TelegraphFILTERList), signal
			sprintf infostr, "FILTER=%s;", StringFromList(v, ITC_TelegraphFILTERList)
		else
			sprintf infostr, "FILTER=?;"
		endif
		break
	case 3: //MODE
		v=round(signal)
		if(v>=1 && v<=7)
			//sprintf infostr, "MODE=%s#%.4f;", StringFromList(v-1, ITC_TelegraphMODEList), signal
			sprintf infostr, "MODE=%s;", StringFromList(v-1, ITC_TelegraphMODEList)
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
	
	for(i=ItemsInList(ITC_TelegraphList)-2; i>=0; i-=1)
		chn=telegraphassignment[i]
		tmpstr=""
		if(chn>=0 && chn<8)
#if defined(ITCDEBUG)
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

Function ITCResetDACs()
	Variable i
	Variable dacvalue
	
	for(i=0; i<4; i+=1)
		ControlInfo /W=ITCPanel $("itc_sv_rtdac"+num2istr(i))
#if !defined(ITCDEBUG)
		LIH_SetDac(i, V_value)
#endif
	endfor
End

Structure ITCChannelsParam
	int16 channels[17]
EndStructure

Function itc_update_gain_scale(scalefactor, scaleunit, flag, gain)
	WAVE scalefactor
	WAVE /T scaleunit
	Variable flag
	Variable gain
	
	Variable i
	Variable legalgain=(numtype(gain)==0)?1:0

	int a=round(flag)

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

		a=a>>1

	endfor
End

Constant ITCUSERFUNC_FIRSTCALL=999
Constant ITCUSERFUNC_IDLE=100
Constant ITCUSERFUNC_START_BEFOREINIT=200
Constant ITCUSERFUNC_START_AFTERINIT=300
Constant ITCUSERFUNC_CYCLESYNC=400
Constant ITCUSERFUNC_STOP=500
Constant ITCUSERFUNC_CUSTOMDISPLAY=600
Constant ITCUSERFUNC_DISABLE=-999

Constant ITCSTATUS_MASK=0xff
Constant ITCSTATUS_ALLOWINIT=0x100
Constant ITCSTATUS_INITDONE=0x200
Constant ITCSTATUS_FUNCALLED_BEFOREINIT=0x400
Constant ITCSTATUS_FUNCALLED_AFTERINIT=0x800

Function prototype_userdataprocessfunc(wave adcdata, wave dacdata, int64 total_count, int64 cycle_count, int length, int adc_chnnum, int dac_chnnum, double samplingrate, int flag)
//Please modify the code as needed 
//and set as user data process function from the ITCPanel
	Variable ret_val=0
	
	try
		switch(flag)
		case ITCUSERFUNC_FIRSTCALL: //called when user function is first selected, user can prepare tools/dialogs for the function
			/////////////////////////////
			//User code here
			/////////////////////////////
			ret_val=0 //if ret_val is set to non-zero, user function will not be set and an error will be generated
			break
		case ITCUSERFUNC_IDLE://called when background cycle is idel (not continuously recording)
			/////////////////////////////
			//User code here
			/////////////////////////////
			break // ret_val is not checked in idle call
		case ITCUSERFUNC_START_BEFOREINIT: //called after user clicked "start recording", before initializing the card
			//ATTENTION: At this point, no adcdata has been initalized so the length information is not valid
			/////////////////////////////
			//User code here
			/////////////////////////////
			ret_val=0 //set ret_val to non-zero to hold initialization of the card, otherwise, set to zero
			break
		case ITCUSERFUNC_START_AFTERINIT: //called after user clicked "start recording", and after initializing the card
			/////////////////////////////
			//User code here
			/////////////////////////////
			ret_val=0
			break
		case ITCUSERFUNC_CYCLESYNC: //called at the end of every full cycle of data is recorded in adcdata
			/////////////////////////////
			//User code here
			/////////////////////////////
			ret_val=0 //if need to stop recording by the user function, return a non-zero value
			break
		case ITCUSERFUNC_STOP: //called when the user requested to stop the recording
			/////////////////////////////
			//User code here
			/////////////////////////////
			break //ret_val is not checked for this call
		case ITCUSERFUNC_DISABLE: //called when the user unchecked the USER_FUNC
			/////////////////////////////
			//User code here
			/////////////////////////////
			//ret_val is not checked for this call
			break
		case ITCUSERFUNC_CUSTOMDISPLAY: //called by GUI controller where user can use the ITCPanel#rtgraph to display customized content
			/////////////////////////////
			//User code here
			/////////////////////////////
			//ret_val is not checked for this call
			break
		default:
			ret_val=-1 //this should not happen
			break
		endswitch
	catch
		Variable err = GetRTError(1)		// Gets error code and clears error
		String errMessage = GetErrMessage(err)
		Printf "user function encountered the following error: %s\r", errMessage
		ret_val=-1
	endtry
	
	return ret_val
End

Function itc_bgTask(s)
	STRUCT WMBackgroundStruct &s
	Variable tRefNum, tMicroSec
	
	tRefNum=StartMSTimer
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName)
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	
	NVAR itcmodel=$WBPkgGetName(fPath, WBPkgDFVar, "ITCMODEL")
	SVAR Operator=$WBPkgGetName(fPath, WBPkgDFStr, "OperatorName")
	SVAR ExperimentTitle=$WBPkgGetName(fPath, WBPkgDFStr, "ExperimentTitle")
	SVAR DebugStr=$WBPkgGetName(fPath, WBPkgDFStr, "DebugStr")
	SVAR UserFunc=$WBPkgGetName(fPath, WBPkgDFStr, "UserDataProcessFunction")
	SVAR TaskRecordingCount=$WBPkgGetName(fPath, WBPkgDFStr, "TaskRecordingCount")

	int64 cycle_count, total_count
	sscanf TaskRecordingCount, "%x,%x", total_count, cycle_count
	 
	NVAR Status=$WBPkgGetName(fPath, WBPkgDFVar, "Status")
	NVAR LastIdleTicks=$WBPkgGetName(fPath, WBPkgDFVar, "LastIdleTicks")
	NVAR RecordNum=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingNum")
	NVAR SamplingRate=$WBPkgGetName(fPath, WBPkgDFVar, "SamplingRate")
	NVAR RecordingLen=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingLength")
	NVAR Continuous=$WBPkgGetName(fPath, WBPkgDFVar, "ContinuousRecording")
	NVAR SaveRecording=$WBPkgGetName(fPath, WBPkgDFVar, "SaveRecording")
	NVAR TelegraphGain=$WBPkgGetName(fpath, WBPkgDFVar, "TelegraphGain")
	SVAR TelegraphInfo=$WBPkgGetName(fpath, WBPkgDFStr, "TelegraphInfo")
	
	NVAR FIFOBegin=$WBPkgGetName(fPath, WBPkgDFVar, "FIFOBegin")
	NVAR FIFOEnd=$WBPkgGetName(fPath, WBPkgDFVar, "FIFOEnd")
	NVAR FIFOVirtualEnd=$WBPkgGetName(fPath, WBPkgDFVar, "FIFOVirtualEnd")
	NVAR ADCDataPointer=$WBPkgGetName(fPath, WBPkgDFVar, "ADCDataPointer")

	NVAR ChnOnGainBinFlag=$WBPkgGetName(fPath, WBPkgDFVar, "ChannelOnGainBinFlag")
	
	NVAR BlockSize=$WBPkgGetName(fPath, WBPkgDFVar, "BlockSize")
	NVAR RecordingSize=$WBPkgGetName(fPath, WBPkgDFVar, "RecordingSize")

	WAVE adcdata=$WBPkgGetName(fPath, WBPkgDFWave, "ADCData")
	WAVE dacdata=$WBPkgGetName(fPath, WBPkgDFWave, "DACData")
	
	WAVE /T adcdatawavepath=$WBPkgGetName(fPath, WBPkgDFWave, "ADCDataWavePath")
	WAVE /T dacdatawavepath=$WBPkgGetName(fPath, WBPkgDFWave, "DACDataWavePath")
	
	WAVE adcscalefactor=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleFactor")
	WAVE /T adcscaleunit=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleUnit")
	
	WAVE selectedadcchn=$WBPkgGetName(fPath, WBPkgDFWave, "SelectedADCChn")
	WAVE selecteddacchn=$WBPkgGetName(fPath, WBPkgDFWave, "SelectedDACChn")
	
	WAVE telegraphassignment=$WBPkgGetName(fPath, WBPkgDFWave, "TelegraphAssignment")

	Variable countDAC=str2num(GetUserdata("ITCPanel", "itc_grp_DAC", "selected"))
	
	String tmpstr
	Variable itcstatus
	try
		Variable i, success, availablelen, p0, p1, upload_len, UploadHalt, saved_len
		Variable SampleInt, ADBlockSize, DABlockSize
		Variable tmp_gain
		STRUCT ITCChannelsParam ADCs
		STRUCT ITCChannelsParam DACs
		Variable selectedadc_number=DimSize(selectedadcchn, 0)
		Variable selecteddac_number=DimSize(selecteddacchn, 0)
		Variable userfunc_ret
				
		total_count+=1 //task execution count increase for every call of the background task
		
		switch(Status & ITCSTATUS_MASK)// higher bits are for internal status use only
		case 0: //idle
			if(s.curRunTicks-LastIdleTicks>3)
#if defined(ITCDEBUG)
				itcstatus=-99
#else
				itcstatus=LIH_Status()
#endif
				
#if !defined(ITCDEBUG)
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
			if(strlen(UserFunc)>0)
				FUNCREF prototype_userdataprocessfunc refFunc=$UserFunc
				if(str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
					refFunc(adcdata, dacdata, total_count, 0, RecordingSize, selectedadc_number, selecteddac_number, SamplingRate, ITCUSERFUNC_IDLE); AbortOnRTE
				endif
			endif
			break
		case 1: //request to start
			DebugStr="Starting acquisition... status:"+num2istr(Status);
			String errMsg=""
			//cycle of recording clear to zero. user function will receive a fresh start
			cycle_count=0

			if(strlen(UserFunc)>0)
				FUNCREF prototype_userdataprocessfunc refFunc=$UserFunc
				if(((Status & ITCSTATUS_ALLOWINIT)==0) && str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
					//Attention: at this point, no adcdata wave have been initialized
					userfunc_ret=refFunc(adcdata, dacdata, total_count, cycle_count, RecordingSize, selectedadc_number, selecteddac_number, SamplingRate, ITCUSERFUNC_START_BEFOREINIT); AbortOnRTE
					if(userfunc_ret>0) //user function can decide when to allow init
						if((Status & ITCSTATUS_FUNCALLED_BEFOREINIT)==0)
							sprintf tmpstr, "User function holds initialization with return code %d...", userfunc_ret
							itc_updatenb(tmpstr)
							Status = Status | ITCSTATUS_FUNCALLED_BEFOREINIT //only log this message once			
						endif					
						break //break off the switch case
					elseif(userfunc_ret<0)
						sprintf tmpstr, "Error: User function returned negative before_init code %d. Recording is terminated.", userfunc_ret
						itc_updatenb(tmpstr, r=32768, g=0, b=0)
						Status=4
						break //no longer continue
					else
						Status= Status | ITCSTATUS_ALLOWINIT
					endif
				endif
			else
				Status = Status | ITCSTATUS_ALLOWINIT
			endif
			
			ControlInfo /W=ITCPanel itc_cb_forcereset
			if(V_Value==1)
#if defined(ITCDEBUG)
				success=0
#else
				if((Status & ITCSTATUS_ALLOWINIT)!=0 && (Status & ITCSTATUS_INITDONE)==0) //allow init, and not inited before
					success=LIH_InitInterface(errMsg, itcmodel)
					Status = Status | ITCSTATUS_INITDONE //mask this so that init is only called once
					if(success!=0)
						sprintf tmpstr, "Initialization of the ITC failed with message: %s", errMsg
						itc_updatenb(tmpstr, r=32768, g=0, b=0)
						AbortOnValue 1, 999
					else
						itc_updatenb("ITC initialized (reset) for starting acquisition.")
					endif
				endif
#endif
			else
				Status = Status | ITCSTATUS_INITDONE
				Checkbox itc_cb_forcereset win=ITCPanel, value=0 //stop resetting next time.
				itc_updatenb("ITC skipped initialization/resetting.")
				success=0
			endif


			if(itc_update_taskinfo()==0) //will reload dac data too
				//checking passed, waves and variables have been prepared etc.
				if(RecordingSize<=0)
					itc_updatenb("Error in RecordingSize ["+num2istr(RecordingSize)+"]", r=32768, g=0, b=0)
					AbortOnValue 1, 900
				endif
				if(BlockSize<0 || BlockSize>ITCMaxBlockSize || BlockSize>RecordingSize)
					itc_updatenb("Error in BlockSize ["+num2istr(BlockSize)+"]", r=32768, g=0, b=0)
					AbortOnValue 1, 910
				endif
				
				userfunc_ret=0
				if(strlen(UserFunc)>0)
					FUNCREF prototype_userdataprocessfunc refFunc=$UserFunc
					if(str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
						userfunc_ret=refFunc(adcdata, dacdata, total_count, cycle_count, RecordingSize, selectedadc_number, selecteddac_number, SamplingRate, ITCUSERFUNC_START_AFTERINIT); AbortOnRTE
					endif
				endif
				
				if(userfunc_ret>0) //user function can decide when to continue after the init process
					if((Status & ITCSTATUS_FUNCALLED_AFTERINIT)==0)
						sprintf tmpstr, "User function pauses the recording with code %d...", userfunc_ret
						itc_updatenb(tmpstr)
						Status = Status | ITCSTATUS_FUNCALLED_AFTERINIT //message will only be logged once
					endif
					break //break off the switch case
				elseif(userfunc_ret<0)
					sprintf tmpstr, "Error: User function returned negative after_init code %d. Recording is terminated.", userfunc_ret
					itc_updatenb(tmpstr, r=32768, g=0, b=0)
					Status=4
					break //no longer continue
				endif
				
				Status = Status & ITCSTATUS_MASK //user function agrees to proceed, clear all internal flags
				
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
			
#if defined(ITCDEBUG)
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
				
				sprintf tmpstr, "Recording starts now. Acquisition parameters: BlockSize[%d], SamplingRate [%d], SampleInterval[%.2e]", BlockSize, SamplingRate, SampleInt
				itc_updatenb(tmpstr)
				tmpstr=""
				for(i=0; i<selectedadc_number; i+=1)
					tmpstr+="ADC Channel["+num2istr(selectedadcchn[i])+"] assigned to wave ["+adcdatawavepath[i]+"]; "
					
					if(selectedadcchn[i]>7)
						selectedadcchn[i]=8 //this is to keep the index for scale factor within range, and also the rtgraph update will use this to find the name of channel
					endif
				
				endfor
				itc_updatenb(tmpstr)
				
				tmpstr=""
				for(i=0; i<selecteddac_number; i+=1)
					tmpstr+="wave ["+dacdatawavepath[i]+"] assigned to DAC Channel ["+num2istr(selecteddacchn[i])+"]; "
					if(selecteddacchn[i]>3)
						selecteddacchn[i]=4
					endif
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
#if defined(ITCDEBUG)
			availablelen=round(BlockSize*0.7-(abs(floor(enoise(0.5*BlockSize))))); success=1
#else
			availablelen=LIH_AvailableStimAndSample(success)
#endif
			
			if(success!=1)
#if defined(ITCDEBUG)
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
				
				itc_reload_dac_from_src(countDAC, dacdatawavepath, dacdata) //refresh dac data first.
				
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
				
#if defined(ITCDEBUG)
				multithread tmpread[0, availablelen-1][]=gnoise(1); AbortOnRTE
#else
				LIH_ReadStimAndSample(tmpread, 0, availablelen) //read the data from the instrument to a temp wave
#endif
				if(upload_len>0)
#if defined(ITCDEBUG)
#else
					success=LIH_AppendToFIFO(tmpstim, UploadHalt, upload_len)
#endif
				endif

				if(success!=1)
					sprintf tmpstr, "Error: AppendToFIFO returned error code %d.", success
					itc_updatenb(tmpstr, r=32768, g=0, b=0)
				endif

			//now store data and decide if need to write to user spaces
				saved_len=0; //the data may have crossed the end point of each cycle, so this var specifies how many points have been stored
				if(ADCDataPointer+availablelen<RecordingSize) //the last point within RecordingSize-1, not including the last point is at RecordingSize-1
					
					multithread adcdata[ADCDataPointer, ADCDataPointer+availablelen-1][]=tmpread[p-ADCDataPointer][q]*adcscalefactor[selectedadcchn[q]]; AbortOnRTE //read is scaled immediately
					
					ADCDataPointer+=availablelen
					saved_len+=availablelen
				else
					Continuous-=1 //one cycle is done, so reduce the counter
					if(ADCDataPointer<RecordingSize)					
						multithread adcdata[ADCDataPointer, RecordingSize-1][]=tmpread[p-ADCDataPointer][q]*adcscalefactor[selectedadcchn[q]]; AbortOnRTE //read is scaled immediately
						saved_len+=RecordingSize-ADCDataPointer
						
						//try to call user defined function to post-process data or make decisions after each cycle
						//user defined function prototype: user_callback_func(wave adcdata, int64 total_count, int64 cycle_count, int flag)
						userfunc_ret=0
						if(strlen(UserFunc)>0)
							FUNCREF prototype_userdataprocessfunc refFunc=$UserFunc
							if(str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
								userfunc_ret=refFunc(adcdata, dacdata, total_count, cycle_count, RecordingSize, selectedadc_number, selecteddac_number, SamplingRate, ITCUSERFUNC_CYCLESYNC); AbortOnRTE
								if(userfunc_ret!=0) //user function returned non-zero code, will stop the recording
									sprintf tmpstr, "Error: User function returned code %d. Recording is terminated.", userfunc_ret
									itc_updatenb(tmpstr, r=32768, g=0, b=0)
									Status=4									
								endif
							endif
						endif
						
						cycle_count+=1 //cycle_count is increased after the user function is called with the previously recorded section
						
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
#if defined(ITCDEBUG)
			itcstatus=-99
#else
			itcstatus=LIH_Status()
#endif
			Variable delta_time=(s.curRunTicks - LastIdleTicks)*1000/60.15
			LastIdleTicks=s.curRunTicks
			tMicroSec=stopMSTimer(tRefNum)
			sprintf tmpstr, "Len(%6d, %2d, %2d),exec_time(%4d ms),time_gap(%4d ms),status(%d),", availablelen, availablelen-upload_len, availablelen-saved_len, tMicroSec/1000, delta_time, itcstatus
			DebugStr+=tmpstr

			break
		case 3: //request to stop
			if(strlen(UserFunc)>0)
				FUNCREF prototype_userdataprocessfunc refFunc=$UserFunc
				if(str2num(StringByKey("ISPROTO", FuncRefInfo(refFunc)))==0) //not prototype func
					refFunc(adcdata, dacdata, total_count, cycle_count, RecordingSize, selectedadc_number, selecteddac_number, SamplingRate, ITCUSERFUNC_STOP); AbortOnRTE
				endif
			endif
			Status=4
			break
		case 4: //stopped
			Status=0
#if !defined(ITCDEBUG)
			LIH_Halt()
#endif
			ITCResetDACs()
			itc_updatenb("ITC stopped.")
			itc_update_controls(0)
			LastIdleTicks=s.curRunTicks
			break
		default:
			break
		endswitch
		sprintf TaskRecordingCount, "%x,%x", total_count,cycle_count
	catch
		sprintf tmpstr, "Error in background task. V_AbortCode: %d. ", V_AbortCode
		if(V_AbortCode==-4)
			Variable err=GetRTError(0)
			tmpstr+="Runtime error message: "+GetErrMessage(err)
			err=GetRTError(1)
		endif
		itc_updatenb(tmpstr, r=32768, g=0, b=0)
		itc_update_controls(0)
		ITCResetDACs()
		LastIdleTicks=s.curRunTicks
		
		Status=0
	endtry	
	tMicroSec=stopMSTimer(tRefNum)
	return 0
End

Constant MaxDepositionRawRecordingLength = 600 // sec

Function PostSlackChannel(String token, String channel, String message, String notify_person)
	String URL = "https://slack.com/api/chat.postMessage"
	String postData = "channel="+URLEncode(channel)+"&text=@"+URLEncode(notify_person)+"%20"+URLEncode(message)+"&pretty=1"
	URLRequest /DSTR = postData url=URL, method = post, headers = token
End

Function DepositionPanelPrepareDataFolder(variable len, variable samplingrate, variable adc_chnnum, variable dac_chnnum)
	Variable max_cycle_count = round(MaxDepositionRawRecordingLength / (len/samplingrate)) // this is the number of cycles in half an hour that will be recorded with all raw data
	String deposit_folder_name = UniqueName("DepositRecord", 11, 0)
	DFREF dfr = GetDataFolderDFR()
	
	try
		NewDataFolder /O/S root:$deposit_folder_name
		
		Variable chnnum=adc_chnnum+dac_chnnum+1
		
		String raw_record_name = "root:"+deposit_folder_name+":"+deposit_folder_name+"_raw"
		String history_record_name = "root:"+deposit_folder_name+":"+deposit_folder_name+"_history"
		String history_view_name = "root:"+deposit_folder_name+":HISTORY_VIEW"
		
		Make /O/N=(len*max_cycle_count, chnnum+1)/D $raw_record_name=NaN
		Wave rawwave=$raw_record_name
		Note /K rawwave
		Note rawwave, "0;0"
		
		
		Make /O/N=(13, chnnum, max_cycle_count)/D $history_record_name = NaN, $history_view_name = NaN

		Wave historywave=$history_record_name
		wave hist_view=$history_view_name
		Note /K historywave
		Note historywave, "0;0"
		
		SetDimLabel 0, 0, CYCLEINDEX, historywave, hist_view
		SetDimLabel 0, 1, TIMESTAMP, historywave, hist_view
		SetDimLabel 0, 2, MEANVALUE, historywave, hist_view
		SetDimLabel 0, 3, SDEV, historywave, hist_view
		SetDimLabel 0, 4, MAXVALUE, historywave, hist_view
		SetDimLabel 0, 5, MINVALUE, historywave, hist_view
		SetDimLabel 0, 6, MEANL1, historywave, hist_view
		SetDimLabel 0, 7, MEANL2, historywave, hist_view
		SetDimLabel 0, 8, SKEWNESS, historywave, hist_view
		SetDimLabel 0, 9, KURTOSIS, historywave, hist_view
		SetDimLabel 0, 10, PULSE_HIGH, historywave, hist_view
		SetDimLabel 0, 11, PULSE_LOW, historywave, hist_view
		SetDimLabel 0, 12, PULSE_WIDTH, historywave, hist_view
		
		Variable i
		for(i=0; i<adc_chnnum; i+=1)
			SetDimLabel 1, i, ADC_CHANNELS, historywave, hist_view
			SetDimLabel 1, i, ADC_CHANNELS, rawwave
		endfor
		for(i=adc_chnnum; i<adc_chnnum+dac_chnnum; i+=1)
			SetDimLabel 1, i, DAC_CHANNELS, historywave, hist_view
			SetDimLabel 1, i, DAC_CHANNELS, rawwave
		endfor
		SetDimLabel 1, adc_chnnum+dac_chnnum, COND_CALC, historywave, rawwave, hist_view
		SetDimLabel 1, adc_chnnum+dac_chnnum+1, TIMESTAMP, rawwave
				
		SetDimLabel 2, -1, RECORD_TIME, historywave, hist_view
		
		SetScale /P z, 0, len/samplingrate, "s", historywave, hist_view
		SetScale /P x, 0, 1/samplingrate, "s", rawwave
		
		SetWindow ITCPanel, userdata(DepositRecord_FOLDER)=deposit_folder_name
		SetWindow ITCPanel, userdata(DepositRecord_RAW)=raw_record_name
		SetWindow ITCPanel, userdata(DepositRecord_HISTORY)=history_record_name
		SetWindow ITCPanel, userdata(DepositRecord_HISTORYVIEW)=history_view_name
		
		Variable /G control_count
		Variable /G pulse_flag
		
	catch
	endtry
	
	SetDataFolder dfr
		
End

Function DepositionPanelInit()
	String PanelName=GetUserData("ITCPanel", "", "DepositionPanel")
	if(strlen(PanelName)>0)
		if(WinType(PanelName) == 7)
			return 0
		endif
	endif
	print("Deposition panel initialized.")
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName); AbortOnRTE
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance); AbortOnRTE
	WAVE /T chnlist=$WBPkgGetName(fPath, WBPkgDFWave, "ADC_Channel"); AbortOnRTE
	WAVE /T dacchnlist=$WBPkgGetName(fPath, WBPkgDFWave, "DAC_Channel"); AbortONRTE
	WAVE selectedchn=$WBPkgGetName(fPath, WBPkgDFWave, "selectedadcchn"); AbortOnRTE
	WAVE selecteddacchn=$WBPkgGetName(fPath, WBPkgDFWave, "selecteddacchn"); AbortOnRTE
	String adcchn_list="\"", dacchn_list="\""
	Variable i
	for(i=0; i<DimSize(selectedchn, 0); i+=1)
		adcchn_list = adcchn_list+chnlist[selectedchn[i]]+";"
	endfor
	for(i=0; i<DimSize(selecteddacchn, 0); i+=1)
		dacchn_list = dacchn_list+dacchnlist[selecteddacchn[i]]+";"
	endfor
	adcchn_list+="\""
	dacchn_list+="\""
	
	NewPanel /EXT=0 /HOST=ITCPanel /K=2 /N=DepositionPanel /W=(0,0,200,500)
	String depositpanel_name = S_name
	SetWindow ITCPanel, userdata(DepositionPanel)="ITCPanel#"+depositpanel_name
	
	ValDisplay depositpanel_total_cycle_time,title="total_cycle_time (ms)",value=_NUM:NaN,size={200,20}
	//currently pulse wave used for dac channels are limited to be stored at root folder
	PopupMenu depositpanel_pulse_wave,title="deposit_wave",size={200,20},value=WaveList("*",";","DIMS:1;")
	SetVariable depositpanel_pulse_width,title="pulse_width (ms)",value=_NUM:50,size={200,20},limits={10,100,1}
	SetVariable depositpanel_pre_pulse_time,title="pre_pulse_time (ms)",value=_NUM:20,size={200,20},limits={20,50,1}
	SetVariable depositpanel_post_pulse_delay,title="post_pulse_delay (ms)",value=_NUM:50,size={200,20},limits={20,50,1}
	ValDisplay depositpanel_post_pulse_samplelen,title="post_pulse_sample_len",value=_NUM:NaN,size={200,20}
	
	PopupMenu depositpanel_tunneling_chn,title="tunneling_current_channel",size={200,20},value=#adcchn_list
	PopupMenu depositpanel_bias_chn,title="tunneling_bias_chn",size={200,20},value=#dacchn_list
	
	SetVariable depositpanel_rest_bias,title="rest_bias (V)",value=_NUM:0,size={200,20},limits={-1.5,1.5,0.01}
	SetVariable depositpanel_deposit_bias,title="deposit_bias (V)",value=_NUM:0,size={200,20},limits={-1.5,1.5,0.01}
	SetVariable depositpanel_removal_bias,title="removal_bias (V)",value=_NUM:0,size={200,20},limits={-1.5,1.5,0.01}
	Button depositpanel_newRTplot,title="new RT plot",size={200,20},proc=DepositionPanel_Btn_NewRTPlot
	SetVariable depositpanel_target_conductance,title="target_cond (nS)",value=_NUM:1,size={200,20},limits={0.001,100,0.01}
	SetVariable depositionpanel_histlen, title="tracking history len (s)", value=_NUM:120,size={200,20},limits={10, MaxDepositionRawRecordingLength, 1}
	Button depositpanel_autodep,title="start autodeposition",size={200,20},fColor=(0,32768,0),proc=DepositionPanel_Btn_autodep
	Valdisplay depositpanel_cond, title="Conductance monitor (nS):",value=_NUM:NaN,size={200,20}
	Valdisplay depositpanel_pulse, title="Active pulse potental (V):", value=_NUM:NaN,size={200,20}
	Valdisplay depositpanel_pulsedelaycount, title="Count down to next decision:", value=_NUM:NaN,size={200,20}
End

Function DepositionPanelExit()
	String depositpanel_name = GetUserData("ITCPanel", "", "DepositionPanel")
	if(strlen(depositpanel_name)>0)
		KillWindow /Z $(depositpanel_name)
		SetWindow ITCPanel, userdata(DepositionPanel)=""
	endif
End

Function DepositionPanel_KillRTPlot()
	String RTPlotName=GetUserData("ITCPanel", "", "DepositionPanel_RTPlot")
	if(strlen(RTPlotName)>0)
		KillWindow /Z $RTPlotName
		SetWindow ITCPanel, userdata(DepositionPanel_RTPlot)=""
	endif	
End


Function DepositionPanel_Btn_NewRTPlot(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			try
				DepositionPanel_KillRTPlot()
				
				ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_trace1name; AbortOnRTE
				Variable chn1=V_value-1
				ControlInfo /W=ITCPanel#rtgraphpanel rtgraph_trace2name; AbortOnRTE
				Variable chn2=V_value-2
				
				if(chn1>=0 && chn2>=0)
				
					Variable instance=WBPkgGetLatestInstance(ITC_PackageName); AbortOnRTE
					String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance); AbortOnRTE
					String dataname=WBPkgGetName(fPath, WBPkgDFWave, "ADCData"); AbortOnRTE
					WAVE datawave=$dataname; AbortOnRTE
					dataname=StringFromList(ItemsInList(dataname, ":")-1, dataname, ":"); AbortOnRTE
					WAVE selectedchn=$WBPkgGetName(fPath, WBPkgDFWave, "selectedadcchn"); AbortOnRTE
					WAVE /T chnlist=$WBPkgGetName(fPath, WBPkgDFWave, "ADC_Channel"); AbortOnRTE
					WAVE /T chnunit=$WBPkgGetName(fPath, WBPkgDFWave, "ADCScaleUnit"); AbortOnRTE
					
					String ylabel = chnlist[selectedchn[chn1]]+" (\\E"+chnunit[selectedchn[chn1]]+")"; AbortOnRTE
					String xlabel = chnlist[selectedchn[chn2]]+" (\\E"+chnunit[selectedchn[chn2]]+")"; AbortOnRTE
					
					Display /N=RealTime_XY_plot /B /L datawave[][chn1] vs datawave[][chn2]; AbortOnRTE
					String RTPlotName = S_name; AbortOnRTE
					Label bottom xlabel; AbortOnRTE
					Label left ylabel; AbortOnRTE
					ModifyGraph axThick=2,standoff(left)=0,freePos(left)=0,freePos(bottom)=0,standoff(bottom)=0; AbortOnRTE
					
					SetWindow ITCPanel, userdata(DepositionPanel_RTPlot)=RTPlotName				
				endif
			catch
				Variable err = GetRTError(1)		// Gets error code and clears error
				String errMessage = GetErrMessage(err)
				Printf "RTPlot encountered the following error: %s\r", errMessage
			endtry
		
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DepositionPanel_Btn_autodep(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			try
				String panel_name = GetUserData("ITCPanel", "", "DepositionPanel")
				String deposit_folder_name = GetUserData("ITCPanel","","DepositRecord_FOLDER")
				String raw_record_name = GetUserData("ITCPanel","","DepositRecord_RAW")
				String history_record_name = GetUserData("ITCPanel","","DepositRecord_HISTORY")
				Variable autodep_status = str2num(GetUserData("ITCPanel", "", "DepositRecord_AUTODEP_ENABLED"))
				
				if(autodep_status == 1)
					autodep_status = 0
					SetWindow ITCPanel, userdata(DepositRecord_AUTODEP_ENABLED)="0"
					Button depositpanel_autodep,win=$panel_name,title="start autodeposition",size={200,20},fColor=(0,32768,0)
				else
					autodep_status = 1
					Button depositpanel_autodep,win=$panel_name,title="stop autodeposition",size={200,20},fColor=(32768,0,0)
					SetWindow ITCPanel, userdata(DepositRecord_AUTODEP_ENABLED)="1"
				endif
			catch
				Variable err = GetRTError(1)		// Gets error code and clears error
				String errMessage = GetErrMessage(err)
				Printf "RTPlot encountered the following error: %s\r", errMessage
			endtry
		
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function DepositionPanelPulseGenerator(wave w, int length, int pre_pulse_len, int pulse_len, double rest_bias, double pulse_bias)
	Make /N=(length) /D dacwave
	dacwave = rest_bias
	variable i
	for(i=pre_pulse_len; i<length && i<pre_pulse_len+pulse_len; i+=1)
		dacwave[i]=pulse_bias
	endfor
	duplicate dacwave, w
End

Function Deposition_CopyHistoryRecord(wave hist_record, wave hist_fordisp, variable hist_endidx, variable hist_len)
End

Function ITCUSERFUNC_DepositionDataProcFunc(wave adcdata, wave dacdata, int64 total_count, int64 cycle_count, int length, int adc_chnnum, int dac_chnnum, double samplingrate, int flag)
//Please modify the code as needed 
//and set as user data process function from the ITCPanel
	Variable ret_val=0
	Variable total_cycle_time=length/samplingrate
	
	String panel_name=GetUserData("ITCPanel","","DepositionPanel")

	try
		if(WinType(panel_name)==7)
			ControlInfo /W=$(panel_name) depositpanel_target_conductance
			Variable target_conductance = V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_pulse_width
			Variable pulse_width = V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_pre_pulse_time
			Variable pre_pulse_time = V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_post_pulse_delay
			Variable post_pulse_delay = V_Value			
			
			ControlInfo /W=$(panel_name) depositpanel_rest_bias
			Variable rest_bias = V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_deposit_bias
			Variable deposit_bias = V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_rest_bias
			Variable oxidize_bias = V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_pulse_wave
			if(strlen(S_Value)>0)
				wave pulse_wave = $S_Value
			else
				Make /FREE /N=(length) /D tmp_wave = rest_bias
				wave pulse_wave = tmp_wave
			endif
			
			ControlInfo /W=$(panel_name) depositpanel_tunneling_chn
			Variable tunneling_current_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositpanel_bias_chn
			Variable tunneling_bias_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositionpanel_histlen
			Variable hist_len_time = V_Value
			Variable hist_len = hist_len_time / (length/samplingrate)
			
			String hist_view_name = GetUserData("ITCPanel", "", "DepositRecord_HISTORYVIEW")
			Wave hist_view = $hist_view_name
			
		endif
			
		switch(flag)
		case ITCUSERFUNC_FIRSTCALL: //called when user function is first selected, user can prepare tools/dialogs for the function
			/////////////////////////////
			//User code here
			/////////////////////////////
			DepositionPanelInit()
			DepositionPanelPrepareDataFolder(length, samplingrate, adc_chnnum, dac_chnnum)
			ret_val=0 //if ret_val is set to non-zero, user function will not be set and an error will be generated
			break
		case ITCUSERFUNC_IDLE://called when background cycle is idel (not continuously recording)
			/////////////////////////////
			//User code here
			/////////////////////////////
			
			break // ret_val is not checked in idle call
		case ITCUSERFUNC_START_BEFOREINIT: //called after user clicked "start recording", before initializing the card
			//ATTENTION: At this point, no adcdata has been initalized so the length information is not valid
			/////////////////////////////
			//User code here
			/////////////////////////////			
			ret_val=0 //set ret_val to non-zero to hold initialization of the card, otherwise, set to zero
			break
		case ITCUSERFUNC_START_AFTERINIT: //called after user clicked "start recording", and after initializing the card
			/////////////////////////////
			//User code here
			/////////////////////////////
			print "Initial call for DepositionPanel: total count=", total_count, "recording length = ", length, "sampling rate = ", samplingrate
			print "If actual sampling rate does not match, stop and restart again."
			DepositionPanelInit()
			ret_val=0
			hist_view=NaN
			break
		case ITCUSERFUNC_CYCLESYNC: //called at the end of every full cycle of data is recorded in adcdata
			/////////////////////////////
			//User code here
			/////////////////////////////
			
			ValDisplay depositpanel_total_cycle_time win=$panel_name,value=_NUM:(round(total_cycle_time*1000))
			
			Variable pulse_sample_start=round(samplingrate*(pre_pulse_time+pulse_width+post_pulse_delay)/1000)
			Variable pulse_sample_len = length - pulse_sample_start
			
			ValDisplay depositpanel_post_pulse_samplelen win=$panel_name,value=_NUM:(pulse_sample_len)
			
			Make /FREE/D/N=(DimSize(adcdata, 0)) cond_calc=adcdata[p][tunneling_current_chn] / dacdata[p][tunneling_bias_chn]
			Make /FREE/D/N=(pulse_sample_len,adc_chnnum+dac_chnnum+1) tmp_stat
			
			tmp_stat[][0,adc_chnnum-1] = adcdata[pulse_sample_start+p][q];AbortOnRTE
			tmp_stat[][adc_chnnum,adc_chnnum+dac_chnnum-1] = dacdata[pulse_sample_start+p][q-adc_chnnum];AbortOnRTE
			tmp_stat[][adc_chnnum+dac_chnnum] = cond_calc[pulse_sample_start+p];AbortOnRTE
			
			String deposit_folder_name = GetUserData("ITCPanel", "", "DepositRecord_FOLDER")
			String raw_record_name = GetUserData("ITCPanel", "", "DepositRecord_RAW")
			String history_record_name = GetUserData("ITCPanel", "", "DepositRecord_HISTORY")
			
			wave rawwave = $raw_record_name
			wave historywave = $history_record_name
			
			Variable timestamp_ticks = ticks
			
			Variable raw_startidx, raw_endidx, raw_base
			Variable hist_startidx, hist_endidx
			
			String raw_idx_str=note(rawwave)
			String hist_idx_str=note(historywave)
			
			raw_startidx=str2num(StringFromList(0, raw_idx_str))
			raw_endidx=str2num(StringFromList(1, raw_idx_str))
			raw_base = raw_endidx*length
			
			hist_startidx=str2num(StringFromList(0, hist_idx_str))
			hist_endidx=str2num(StringFromList(1, hist_idx_str))
			
			
			rawwave[raw_base, raw_base+length-1][0,adc_chnnum-1] = adcdata[p-raw_base][q];AbortOnRTE
			rawwave[raw_base, raw_base+length-1][adc_chnnum, adc_chnnum+dac_chnnum-1] = dacdata[p-raw_base][q-adc_chnnum];AbortOnRTE
			rawwave[raw_base, raw_base+length-1][adc_chnnum+dac_chnnum] = cond_calc[p-raw_base];AbortOnRTE
			rawwave[raw_base, raw_base+length-1][adc_chnnum+dac_chnnum+1] = total_count*length/samplingrate+(p-raw_base)/samplingrate; AbortOnRTE

			raw_endidx+=1
			Variable max_raw_idx = round(DimSize(rawwave, 0)/length)
			if(raw_endidx >= max_raw_idx)
				raw_endidx = 0
			endif
			if(raw_endidx==raw_startidx)
				raw_startidx+=1
			endif
			if(raw_startidx >= max_raw_idx)
				raw_startidx = 0
			endif
			
			note /k rawwave
			note rawwave, num2istr(raw_startidx)+";"+num2istr(raw_endidx)
			
			WaveStats /Q /PCST /Z tmp_stat
			Wave M_WaveStats
			historywave[%CYCLEINDEX][][hist_endidx]=cycle_count;AbortOnRTE
			historywave[%TIMESTAMP][][hist_endidx]=timestamp_ticks/60;AbortOnRTE
			historywave[%MEANVALUE][][hist_endidx]=M_WaveStats[%avg][q];AbortOnRTE
			historywave[%SDEV][][hist_endidx]=M_WaveStats[%sdev][q];AbortOnRTE
			historywave[%MAXVALUE][][hist_endidx]=M_WaveStats[%max][q];AbortOnRTE
			historywave[%MINVALUE][][hist_endidx]=M_WaveStats[%min][q];AbortOnRTE
			historywave[%MEANL1][][hist_endidx]=M_WaveStats[%meanL1][q];AbortOnRTE
			historywave[%MEANL2][][hist_endidx]=M_WaveStats[%meanL2][q];AbortOnRTE
			historywave[%SKEWNESS][][hist_endidx]=M_WaveStats[%skew][q];AbortOnRTE
			historywave[%KURTOSIS][][hist_endidx]=M_WaveStats[%kurt][q];AbortOnRTE
			
			WaveStats /Q pulse_wave
			historywave[%PULSE_HIGH][][hist_endidx]=V_max;AbortOnRTE
			historywave[%PULSE_LOW][][hist_endidx]=V_min;AbortOnRTE
			historywave[%PULSE_WIDTH][][hist_endidx]=pulse_width;AbortOnRTE
			
			if(hist_endidx<hist_len)
				hist_view[][][0, hist_endidx]=historywave[p][q][r]
			else
				hist_view[][][0, hist_len-1] = historywave[p][q][hist_endidx-hist_len+1+r]
			endif
			
			hist_endidx+=1
			if(hist_endidx>=DimSize(historywave, 2))
				InsertPoints /M=2 /V=(NaN) DimSize(historywave, 2), round(MaxDepositionRawRecordingLength / (length/samplingrate)), historywave;AbortOnRTE
			endif
			
			note /k historywave
			note historywave, "0;"+num2str(hist_endidx)
			
			ret_val=0 //if need to stop recording by the user function, return a non-zero value
			break
		case ITCUSERFUNC_STOP: //called when the user requested to stop the recording
			/////////////////////////////
			//User code here
			/////////////////////////////
			SetWindow ITCPanel, userdata(DepositRecord_AUTODEP_ENABLED)="0"
			DepositionPanel_KillRTPlot()			
			break //ret_val is not checked for this call
		
		case ITCUSERFUNC_DISABLE: //called when the user unchecked the USER_FUNC
			DepositionPanelExit()
			break
		case ITCUSERFUNC_CUSTOMDISPLAY: //called by GUI controller where user can use the ITCPanel#rtgraph to display customized content
			AppendToGraph /W=ITCPanel#rtgraph /L /B hist_view[%MEANVALUE][%COND_CALC][] vs hist_view[%TIMESTAMP][%COND_CALC][]
			ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos(left)=0,lblPos(left)=60,notation(left)=0,ZisZ(left)=1,fsize=12; AbortOnRTE
			ModifyGraph /W=ITCPanel#rtgraph freePos(left)=0,lblPos(bottom)=40,notation(bottom)=0,fsize=12,ZisZ=1; AbortOnRTE
			ModifyGraph /W=ITCPanel#rtgraph margin(left)=80; AbortOnRTE
			print("display updated.")
			//ret_val is not checked for this call
			break
		default:
			ret_val=-1 //this should not happen
			break
		endswitch
	catch
		Variable err = GetRTError(1)		// Gets error code and clears error
		String errMessage = GetErrMessage(err)
		Printf "user function encountered the following error: %s\r", errMessage
		ret_val=-1
	endtry
	
	return ret_val
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

