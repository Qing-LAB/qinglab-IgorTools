#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "QDataLink"

Menu "QDataLink"
	Submenu "EMController"
		"Connect to EMController", EMControllerConnectionINIT()
		"EMController Panel", EMControllerPanel(EMControllerGetPrivateFolderName())
		"Set FPGA State", EMControllerSetFPGAState()
		"Set PID channels", EMControllerSetPIDChannels()
	End
End

Function EMControllerConnectionINIT()
	String port_list=QDataLinkcore#QDLSerialPortGetList()
	String port_select=""
	PROMPT port_select, "Port Name", popup port_list
	DoPrompt "Select Serial Port", port_select
	
	SVAR configStr=root:S_EMControllerPortConfig
	if(!SVAR_Exists(configStr))
		String /G root:S_EMControllerPortConfig=""
		SVAR configStr=root:S_EMControllerPortConfig
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
			QDataLinkCore#QDLQuery(slot, "", 0, realtime_func="EMController_rtfunc", postprocess_bgfunc="EMController_postprocess_bgfunc")
			QDataLinkCore#qdl_update_instance_info(instance_select, "EMController", "Remote Control for Electromagnet", port_select)
			configStr=ReplaceStringByKey("SLOT", configStr, num2istr(slot))
			configStr=ReplaceStringByKey("INSTANCE", configStr, num2istr(instance_select))
		endif
	endif
End

Function /T EMControllerGetPrivateFolderName()
	SVAR configStr=root:S_EMControllerPortConfig
	if(!SVAR_Exists(configStr))
		return ""
	endif
	Variable instance=str2num(StringByKey("INSTANCE", configStr))
	if(instance>=0)
		String fullPath=WBSetupPackageDir(QDLPackageName, instance=instance)
		return WBPkgGetName(fullPath, WBPkgDFDF, "EMController")
	else
		return ""
	endif
End

Function /T EMControllerGetPrivateFlagName()
	return EMControllerGetPrivateFolderName()+"last_usrcmd_status"
End

Function EMControllerPanel(String EMPrivatePath)

	NVAR reqID_IN=$(EMPrivatePath+"request_id_in")
	if(NVAR_Exists(reqID_IN)==0)
		print "Invalid path provided when trying to creating EMControllerPanel"
		return -1
	endif
	
	String wlist=WinList("EMControllerPanel*", ";", "WIN:64")
	Variable i
	
	for(i=0; i<ItemsInList(wlist); i+=1)
		String wname=StringFromList(i, wlist)
		if(WinType(wname)==7)
			KillWindow $wname
		endif
	endfor
	
	NewPanel /K=1 /N=EMControllerPanel /W=(112.2,58.8,349.2,367.8)
	ModifyPanel fixedSize=1
	SetVariable req_id_in,pos={13.20,84.00},size={90.60,13.80},bodyWidth=50,title="REQID_IN"
	SetVariable req_id_in,userdata(ResizeControlsInfo)= A"!!,A>!!#?=!!#?o!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable req_id_in,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable req_id_in,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable req_id_in,format="%X"
	SetVariable req_id_in,limits={-inf,inf,0},fSize=9,value= $(EMPrivatePath+"request_id_in"),noedit= 1
	SetVariable req_id_out,pos={4.80,102.00},size={99.00,13.80},bodyWidth=50,title="REQID_OUT"
	SetVariable req_id_out,userdata(ResizeControlsInfo)= A"!!,?8!!#?]!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable req_id_out,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable req_id_out,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable req_id_out,format="%X"
	SetVariable req_id_out,limits={-inf,inf,0},fSize=9,value= $(EMPrivatePath+"request_id_out"),noedit= 1
	SetVariable fpga_state,pos={5.40,33.00},size={144.60,13.80},bodyWidth=95,title="FPGA STATE"
	SetVariable fpga_state,userdata(ResizeControlsInfo)= A"!!,@C!!#=S!!#@t!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable fpga_state,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable fpga_state,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable fpga_state,fSize=9,value= $(EMPrivatePath+"fpga_state"),noedit= 1
	SetVariable fpga_cycle_time,pos={9.00,48.00},size={115.20,13.80},bodyWidth=70,title="FPGA TIME"
	SetVariable fpga_cycle_time,userdata(ResizeControlsInfo)= A"!!,@c!!#>B!!#@J!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable fpga_cycle_time,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable fpga_cycle_time,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable fpga_cycle_time,format="%.0f ms"
	SetVariable fpga_cycle_time,limits={-inf,inf,0},fSize=9,value= $(EMPrivatePath+"fpga_cycle_time"),noedit= 1
	SetVariable cpu_load_total,pos={155.40,33.00},size={62.40,13.80},bodyWidth=35,title="RTCPU"
	SetVariable cpu_load_total,userdata(ResizeControlsInfo)= A"!!,G*!!#=S!!#>b!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable cpu_load_total,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable cpu_load_total,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable cpu_load_total,format="%.0f%%"
	SetVariable cpu_load_total,limits={-inf,inf,0},fSize=9,value= $(EMPrivatePath+"cpu_load_total"),noedit= 1
	SetVariable system_init_time,pos={3.60,15.00},size={214.80,13.80},bodyWidth=160,title="SYSINIT TIME"
	SetVariable system_init_time,userdata(ResizeControlsInfo)= A"!!,<7!!#;M!!#A]!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable system_init_time,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable system_init_time,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable system_init_time,fSize=9,value= $(EMPrivatePath+"system_init_time"),noedit= 1
	SetVariable data_timestamp,pos={109.20,102.00},size={109.80,13.80},bodyWidth=50,title="TIMESTAMP_D"
	SetVariable data_timestamp,userdata(ResizeControlsInfo)= A"!!,F9!!#?a!!#@@!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable data_timestamp,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable data_timestamp,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable data_timestamp,limits={-inf,inf,0},fSize=9,value= $(EMPrivatePath+"data_timestamp"),noedit= 1
	SetVariable status_timestamp,pos={111.00,84.00},size={108.00,13.80},bodyWidth=50,title="TIMESTAMP_S"
	SetVariable status_timestamp,userdata(ResizeControlsInfo)= A"!!,F9!!#?E!!#@@!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable status_timestamp,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable status_timestamp,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable status_timestamp,limits={-inf,inf,0},fSize=9,value= $(EMPrivatePath+"status_timestamp"),noedit= 1
	SetVariable error_number,pos={144.60,48.00},size={73.20,13.80},bodyWidth=35,title="ERRNUM"
	SetVariable error_number,userdata(ResizeControlsInfo)= A"!!,Ff!!#>B!!#?A!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable error_number,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable error_number,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable error_number,limits={-inf,inf,0},fSize=9,value= $(EMPrivatePath+"error_log_num"),noedit= 1
	SetVariable input_chn0,pos={5.40,120.00},size={98.40,13.80},bodyWidth=60,title="IN_CHN0"
	SetVariable input_chn0,userdata(ResizeControlsInfo)= A"!!,@s!!#@,!!#@,!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable input_chn0,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable input_chn0,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable input_chn0,fSize=9,format="%+10.7f"
	SetVariable input_chn0,limits={-inf,inf,0},value= $(EMPrivatePath+"input_chn")[0],noedit= 1
	SetVariable input_chn1,pos={5.40,141.00},size={98.40,13.80},bodyWidth=60,title="IN_CHN1"
	SetVariable input_chn1,userdata(ResizeControlsInfo)= A"!!,@s!!#@P!!#@,!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable input_chn1,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable input_chn1,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable input_chn1,fSize=9,format="%+10.7f"
	SetVariable input_chn1,limits={-inf,inf,0},value= $(EMPrivatePath+"input_chn")[1],noedit= 1
	SetVariable input_chn2,pos={6.00,162.00},size={98.40,13.80},bodyWidth=60,title="IN_CHN2"
	SetVariable input_chn2,userdata(ResizeControlsInfo)= A"!!,@s!!#@l!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable input_chn2,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable input_chn2,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable input_chn2,fSize=9,format="%+10.7f"
	SetVariable input_chn2,limits={-inf,inf,0},value= $(EMPrivatePath+"input_chn")[2],noedit= 1
	SetVariable input_chn3,pos={6.00,180.00},size={98.40,13.80},bodyWidth=60,title="IN_CHN3"
	SetVariable input_chn3,userdata(ResizeControlsInfo)= A"!!,@c!!#A)!!#@,!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable input_chn3,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable input_chn3,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable input_chn3,fSize=9,format="%+10.7f"
	SetVariable input_chn3,limits={-inf,inf,0},value= $(EMPrivatePath+"input_chn")[3],noedit= 1
	SetVariable output_chn0,pos={112.20,119.40},size={106.80,13.80},bodyWidth=60,title="OUT_CHN0"
	SetVariable output_chn0,userdata(ResizeControlsInfo)= A"!!,FE!!#@,!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable output_chn0,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable output_chn0,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable output_chn0,fSize=9,format="%+10.6f",proc=EMControllerPanel_sv_outputchn
	SetVariable output_chn0,limits={-10,10,0},value= $(EMPrivatePath+"output_chn")[0]
	SetVariable output_chn1,pos={112.20,140.40},size={106.80,13.80},bodyWidth=60,title="OUT_CHN1"
	SetVariable output_chn1,userdata(ResizeControlsInfo)= A"!!,FC!!#@V!!#@,!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable output_chn1,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable output_chn1,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable output_chn1,fSize=9,format="%+10.6f",proc=EMControllerPanel_sv_outputchn
	SetVariable output_chn1,limits={-10,10,0},value= $(EMPrivatePath+"output_chn")[1]
	SetVariable output_chn2,pos={112.20,161.40},size={106.80,13.80},bodyWidth=60,title="OUT_CHN2"
	SetVariable output_chn2,userdata(ResizeControlsInfo)= A"!!,FE!!#@m!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable output_chn2,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable output_chn2,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable output_chn2,fSize=9,format="%+10.6f",proc=EMControllerPanel_sv_outputchn
	SetVariable output_chn2,limits={-10,10,0},value= $(EMPrivatePath+"output_chn")[2]
	SetVariable output_chn3,pos={112.20,179.40},size={106.80,13.80},bodyWidth=60,title="OUT_CHN3"
	SetVariable output_chn3,userdata(ResizeControlsInfo)= A"!!,FG!!#A*!!#@,!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable output_chn3,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable output_chn3,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable output_chn3,fSize=9,format="%+10.6f",proc=EMControllerPanel_sv_outputchn
	SetVariable output_chn3,limits={-10,10,0},value= $(EMPrivatePath+"output_chn")[3]
	SetVariable pid_setpoint,pos={9.60,222.60},size={99.00,13.80},proc=EMControllerPanel_sv_setpoint,title="PID SETP"
	SetVariable pid_setpoint,help={"PID setpoint"}
	SetVariable pid_setpoint,userdata(ResizeControlsInfo)= A"!!,B)!!#AP!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_setpoint,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_setpoint,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_setpoint,fSize=9,format="%+10.6f"
	SetVariable pid_setpoint,limits={-10,10,0},value= $(EMPrivatePath+"pid_setpoint")
	SetVariable pid_gain_P,pos={124.80,222.60},size={86.40,13.80},bodyWidth=40,proc=EMControllerPanel_sv_pid,title="PID GAIN P"
	SetVariable pid_gain_P,help={"PID gain proportional"}
	SetVariable pid_gain_P,userdata(ResizeControlsInfo)= A"!!,FQ!!#AL!!#?Y!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_P,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_P,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_P,fSize=9,format="%.3f"
	SetVariable pid_gain_P,limits={0,100,0},value= $(EMPrivatePath+"pid_gain_P")
	SetVariable pid_gain_I,pos={127.20,241.20},size={84.00,13.80},bodyWidth=40,proc=EMControllerPanel_sv_pid,title="PID GAIN I"
	SetVariable pid_gain_I,help={"PID gain integral"}
	SetVariable pid_gain_I,userdata(ResizeControlsInfo)= A"!!,FS!!#A^!!#?W!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_I,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_I,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_I,fSize=9,format="%.3f"
	SetVariable pid_gain_I,limits={0,100,0},value= $(EMPrivatePath+"pid_gain_I")
	SetVariable pid_gain_D,pos={123.00,258.60},size={88.20,13.80},bodyWidth=40,proc=EMControllerPanel_sv_pid,title="PID GAIN D"
	SetVariable pid_gain_D,help={"PID gain differential"}
	SetVariable pid_gain_D,userdata(ResizeControlsInfo)= A"!!,FQ!!#Ao!!#?Y!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_D,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_D,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_D,fSize=9,format="%.3f"
	SetVariable pid_gain_D,limits={0,100,0},value= $(EMPrivatePath+"pid_gain_D")
	SetVariable pid_scale_factor,pos={9.00,241.20},size={99.00,13.80},proc=EMControllerPanel_sv_pid,title="PID IN SCALE"
	SetVariable pid_scale_factor,help={"PID input scale factor (with polarity)"}
	SetVariable pid_scale_factor,userdata(ResizeControlsInfo)= A"!!,An!!#Af!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_scale_factor,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_scale_factor,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_scale_factor,fSize=9,format="%+.2f"
	SetVariable pid_scale_factor,limits={-100,100,0},value= $(EMPrivatePath+"pid_scale_factor")
	SetVariable pid_offset_factor,pos={9.00,260.40},size={99.00,13.80},proc=EMControllerPanel_sv_pid,title="PID IN OFFSET"
	SetVariable pid_offset_factor,help={"PID input offset"}
	SetVariable pid_offset_factor,userdata(ResizeControlsInfo)= A"!!,A^!!#B$!!#@*!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_offset_factor,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_offset_factor,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_offset_factor,fSize=9,format="%+.2f"
	SetVariable pid_offset_factor,limits={-100,100,0},value= $(EMPrivatePath+"pid_offset_factor")
	SetVariable pid_gain_filter,pos={125.40,275.40},size={85.80,13.80},bodyWidth=40,proc=EMControllerPanel_sv_pid,title="PID GAIN F"
	SetVariable pid_gain_filter,help={"PID input filter setting, 0 to 1"}
	SetVariable pid_gain_filter,userdata(ResizeControlsInfo)= A"!!,FU!!#B-!!#?Y!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_filter,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_filter,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_filter,fSize=9,format="%.2f"
	SetVariable pid_gain_filter,limits={0,1,0},value= $(EMPrivatePath+"pid_gain_filter")
	
	Button reset_pid,pos={10.20,277.20},size={96.60,15.00},proc=EMControllerPanel_btn_resetpid,title="reset PID"
	
	GroupBox pid_group,pos={1.80,208.20},size={228.00,90.00},title="PID PARAM"
	GroupBox pid_group,userdata(ResizeControlsInfo)= A"!!,?X!!#A>!!#AZ!!#?ez!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	GroupBox pid_group,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	GroupBox pid_group,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	GroupBox pid_group,fSize=9
	GroupBox sys_info,pos={1.20,0.00},size={228.00,66.00},title="SYS INFO"
	GroupBox sys_info,userdata(ResizeControlsInfo)= A"!!*'\"z!!#Aa!!#?9z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	GroupBox sys_info,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	GroupBox sys_info,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	GroupBox sys_info,fSize=9
	GroupBox group_channels,pos={1.80,69.00},fSize=9,size={228.00,135.00},title="I/O CHANNELS"
	SetWindow kwTopWin,userdata(ResizeControlsInfo)= A"!!*'\"z!!#B*!!#B?1G]\"2zzzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzz!!!"
	SetWindow kwTopWin,hook(myhook)=EMControllerPanelHook
	SetWindow kwTopWin,userdata(PID_INPUT_CHN)="4"
	SetWindow kwTopWin,userdata(PID_OUTPUT_CHN)="4"
End

Function EMControllerPanelHook(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	Variable pid_in, pid_out
	
	pid_in=str2num(GetUserData(s.winName, "", "PID_INPUT_CHN"))
	pid_out=str2num(GetUserData(s.winName, "", "PID_OUTPUT_CHN"))
	
	NVAR current_pid_in=$(EMControllerGetPrivateFolderName()+"pid_input_chn")
	NVAR current_pid_out=$(EMControllerGetPrivateFolderName()+"pid_output_chn")
	
	Variable flag=-1
	
	if(NVAR_Exists(current_pid_in) && NVAR_Exists(current_pid_out))
		if(current_pid_in!=pid_in)
			pid_in=current_pid_in
			flag=0
		endif
		if(current_pid_out!=pid_out)
			pid_out=current_pid_out
			flag=0
		endif
	endif
	
	Variable i

	switch(s.eventCode)
		case 0://activate
		case 1://deactiate
		case 16://show
			if(flag==0)
				SetWindow $(s.winName),userdata(PID_INPUT_CHN)=num2istr(pid_in)
				SetWindow $(s.winName),userdata(PID_OUTPUT_CHN)=num2istr(pid_out)
				for(i=0; i<4; i+=1)
					if(i==pid_in)
						SetVariable $("input_chn"+num2istr(i)),fColor=(65535,0,0)
					else
						SetVariable $("input_chn"+num2istr(i)),fColor=(0,0,0)
					endif
					if(i==pid_out)
						SetVariable $("output_chn"+num2istr(i)),fColor=(65535,0,0)
					else
						SetVariable $("output_chn"+num2istr(i)),fColor=(0,0,0)
					endif
				endfor
			endif
		break
		// And so on . . .
	endswitch

	return hookResult		// 0 if nothing done, else 1
End

Function EMControllerPanel_btn_resetpid(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	ControlInfo /W=$(ba.win) fpga_state
	if(strlen(S_value)>0 && cmpstr(S_value, "Safe State")==0)
		return 0
	endif
	
	SVAR Ecmd=root:S_EMControllerCMD
	String cmd=""
	
	Variable flag=0
	if(!SVAR_Exists(Ecmd))
		flag=-1
	endif
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if(flag==0)
				cmd="RESET_PID:1;"
				Ecmd=cmd
				//print cmd
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function EMControllerPanel_sv_outputchn(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	ControlInfo /W=$(sva.win) fpga_state
	if(strlen(S_value)>0 && cmpstr(S_value, "Safe State")==0)
		return 0
	endif
	
	WAVE o=$(EMControllerGetPrivateFolderName()+"output_chn")
	SVAR Ecmd=root:S_EMControllerCMD
	String cmd=""
	Variable o0,o1,o2,o3
	Variable flag=0
	if(WaveExists(o) && SVAR_Exists(Ecmd))
		o0=o[0]
		o1=o[1]
		o2=o[2]
		o3=o[3]
	else
		flag=-1
	endif
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			
			strswitch(sva.ctrlName)
			case "output_chn0":
				o0=dval
				break
			case "output_chn1":
				o1=dval
				break
			case "output_chn2":
				o2=dval
				break
			case "output_chn3":
				o3=dval
				break
			default:
				flag=-1
				break
			endswitch
			
			if(flag==0)
				sprintf cmd, "SET_OUTPUT:%f,%f,%f,%f;", o0,o1,o2,o3
				//print cmd
				Ecmd=cmd
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function EMControllerPanel_sv_pid(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	ControlInfo /W=$(sva.win) fpga_state
	if(strlen(S_value)>0 && cmpstr(S_value, "Safe State")==0)
		return 0
	endif
	
	NVAR pid_gain_P=$(EMControllerGetPrivateFolderName()+"pid_gain_P")
	NVAR pid_gain_I=$(EMControllerGetPrivateFolderName()+"pid_gain_I")
	NVAR pid_gain_D=$(EMControllerGetPrivateFolderName()+"pid_gain_D")
	NVAR pid_gain_filter=$(EMControllerGetPrivateFolderName()+"pid_gain_filter")
	NVAR pid_scale_factor=$(EMControllerGetPrivateFolderName()+"pid_scale_factor")
	NVAR pid_offset_factor=$(EMControllerGetPrivateFolderName()+"pid_offset_factor")
	SVAR Ecmd=root:S_EMControllerCMD
	String cmd=""
	Variable p, i, d, f, s, o
	Variable flag=0
	
	if(NVAR_Exists(pid_gain_P) && NVAR_Exists(pid_gain_I) && NVAR_Exists(pid_gain_D) && NVAR_Exists(pid_gain_filter) && NVAR_Exists(pid_scale_factor) && NVAR_Exists(pid_offset_factor) && SVAR_Exists(Ecmd))
		p=pid_gain_P
		i=pid_gain_I
		d=pid_gain_D
		f=pid_gain_filter
		s=pid_scale_factor
		o=pid_offset_factor
	else
		flag=-1
	endif
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			strswitch(sva.ctrlName)
			case "pid_gain_P":
				p=dval
				break
			case "pid_gain_I":
				i=dval
				break
			case "pid_gain_D":
				d=dval
				break
			case "pid_gain_filter":
				f=dval
				break
			case "pid_scale_factor":
				s=dval
				break
			case "pid_offset_factor":
				o=dval
				break
			default:
				flag=-1
				break
			endswitch
			
			if(flag==0)
				sprintf cmd, "SET_PID_GAIN:%f,%f,%f,%f,%f,%f;", p,i,d,f,s,o
				Ecmd=cmd
				//print cmd
			endif
						
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function EMControllerPanel_sv_setpoint(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	ControlInfo /W=$(sva.win) fpga_state
	if(strlen(S_value)>0 && cmpstr(S_value, "Safe State")==0)
		return 0
	endif
	
	SVAR Ecmd=root:S_EMControllerCMD
	String cmd=""
	
	Variable flag=0
	if(!SVAR_Exists(Ecmd))
		flag=-1
	endif
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			if(flag==0)
				sprintf cmd, "SET_PID_SETPOINT:%f;", dval
				Ecmd=cmd
				//print cmd
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//globalVar should be cleared first before calling this function
Function EMControllerWaitForUserAction(String msg, String globalVarName, Variable finalValue)
	String wlist=WinList("EMControllerNOTIFICATION*", ";", "WIN:64")
	Variable i
	String wname=""
	
	for(i=0; i<ItemsInList(wlist); i+=1)
		wname=StringFromList(i, wlist)
		if(WinType(wname)==7)
			String oldmsg=GetUserData(wname, "", "MESSAGE")
			if(cmpstr(oldmsg, msg)==0)
				break 
			endif
		endif
	endfor
	
	if(i>=0 && i<ItemsInList(wlist))
		//window is present, not closed
		//print "User has not responded to the last same message yet."
		SetWindow $wname, userdata(MESSAGE)=msg
		SetWindow $wname, userdata(GLOBALVARNAME)=globalVarName
		SetWindow $wname, userdata(FINALVALUE)=num2istr(finalValue)
		SetWindow $wname, hook(myhook)=EMControllerWaitForUserActionHook
		DoWindow /F $wname
	else
		NewPanel /K=1 /N=EMControllerNOTIFICATION /W=(0,0,350,150)
		wname=S_name
		TitleBox message win=$wname,fsize=24,fcolor=(65535,0,0),title=msg+"\n\nClose Window When Done."
		SetWindow kwTopWin, userdata(MESSAGE)=msg
		SetWindow kwTopWin, userdata(GLOBALVARNAME)=globalVarName
		SetWindow $wname, userdata(FINALVALUE)=num2istr(finalValue)
		SetWindow kwTopWin, hook(myhook)=EMControllerWaitForUserActionHook

		AutoPositionWindow /E /M=0
	endif
End

Function EMControllerWaitForUserActionHook(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0

	switch(s.eventCode)
		case 2:
			// Handle kill
			String varname=GetUserData(s.winName, "", "GLOBALVARNAME")
			Variable finalValue=str2num(GetUserData(s.winName, "", "FINALVALUE"))
			//print varname
			NVAR nv=$varname
			if(NVAR_Exists(nv))
				nv=finalValue
			endif
			break
		default:
			break
	endswitch

	return hookResult		// 0 if nothing done, else 1
End

Function EMControllerSetPIDChannels()
	Variable pid_in=5
	Variable pid_out=5
	Prompt pid_in, "PID Input Channel", popup, "0;1;2;3;None;"
	Prompt pid_out, "PID Output Channel", popup, "0;1;2;3;None;"
	DoPrompt "Select PID I/O channels", pid_in, pid_out
	
	String cmd=""
	sprintf cmd, "SET_PID_INPUT_CHN:%d;SET_PID_OUTPUT_CHN:%d;", pid_in-1, pid_out-1
	SVAR Ecmd=root:S_EMControllerCMD
	if(SVAR_Exists(Ecmd))
		Ecmd=cmd
	endif
End

Function EMControllerSetFPGAState()
	Variable state=1

	Prompt state, "FPGA State", popup, "Safe State;PID I/O Control;"
	
	DoPrompt "Select FPGA State", state
	
	String cmd=""
	sprintf cmd, "SET_FPGA_STATE:%d;", state-1
	SVAR Ecmd=root:S_EMControllerCMD
	if(SVAR_Exists(Ecmd))
		Ecmd=cmd
	endif
End

Function EMResetCMDStatusFlag()
	NVAR flag=$(EMControllerGetPrivateFlagName())
	if(NVAR_Exists(flag))
		flag=0
		return 0
	endif
	return -1
End

Constant EMC_USRCMD_STATUS_OLD				=0x20

Function EMCheckCMDStatusFlag()
#ifdef DEBUG_MEASUREMENTEXECUTOR
	return 1
#else
	NVAR flag=$(EMControllerGetPrivateFlagName())
	if(NVAR_Exists(flag))
		if(flag & EMC_USRCMD_STATUS_OLD)
			return 1
		else
			return 0
		endif
	endif
	return -1
#endif
End

Function EMScanInit(Variable PID_INPUT_CHN, Variable PID_OUTPUT_CHN)
	NVAR EMFlag=root:V_EMControllerActiveFlag
	EMFlag=1
	
	String cmd=""
	cmd+="SET_FPGA_STATE:1;"
	cmd+="SET_OUTPUT:0,0,0,0;"
	cmd+="SET_PID_SETPOINT:0;"
	cmd+="SET_PID_RANGE:10,0;"
	cmd+="SET_PID_GAIN:0.35,0.30,0.03,1,1,0;"
	cmd+="SET_9219_CONVERSION_TIME:2;"//fast mode
	cmd+="SET_9219_VOLTAGE_RANGE:0,1,4,4;" //60V for chn0, 15V for chn1, 0.125V for chn3 and chn4
	cmd+="RESET_PID;"
	cmd+="SET_PID_INPUT_CHN:"+num2istr(PID_INPUT_CHN)+";SET_PID_OUTPUT_CHN:"+num2istr(PID_OUTPUT_CHN)+";SET_OUTPUT:10,0,0,0;"
	
	SVAR Ecmd=root:S_EMControllerCMD
	if(SVAR_Exists(Ecmd))
		Ecmd=cmd
	endif
	return 0
End

Function EMShutdown()
	String cmd=""
		
	cmd+="SET_FPGA_STATE:0;"
	cmd+="SET_OUTPUT:0,0,0,0;"
	cmd+="SET_PID_SETPOINT:0;SET_PID_GAIN:0,0,0,0,1,0;"
	cmd+="SET_PID_INPUT_CHN:4;SET_PID_OUTPUT_CHN:4;"
	cmd+="RESET_PID;"	
	
	SVAR Ecmd=root:S_EMControllerCMD
	if(SVAR_Exists(Ecmd))
		Ecmd=cmd
	endif
	return 0
End

Function EMSetPIDGains(String &cmd, Variable p, Variable i, Variable d, Variable f, Variable s, Variable o)
	Variable retVal=-1
	Variable status=str2num(StringByKey("PID_GAIN_STATUS", cmd))
	if(numtype(status)!=0)
		status=0
	endif
	
	DFREF olddfr=GetDataFolderDFR()	
	try
		SetDataFolder $EMControllerGetPrivateFolderName()
		NVAR pid_scale_factor=:pid_scale_factor
				
		Variable new_polarity=1
		String new_polarity_str="POSITIVE"
		
		if(s<0)
			new_polarity=-1
			new_polarity_str="NEGATIVE"
		endif
		
		Variable old_polarity=1
		if(pid_scale_factor<0)
			old_polarity=-1
		endif
		
		String msg_out=""
		
		switch(status)
		case 0: //initial call, check polarity first
			if(new_polarity!=old_polarity)
				//polarity is not correct
				if(EMCheckCMDStatusFlag()!=1)
					//print "need to switch polarity."
					EMControllerWaitForUserAction("Please switch the polarity\nto "+new_polarity_str, EMControllerGetPrivateFlagName(), EMC_USRCMD_STATUS_OLD)
				else
					//print "User has confirmed changing the physical switch to polarity ["+new_polarity_str+"]"
					EMResetCMDStatusFlag()
					status=1
				endif
			else
				status=1 //polarity is already correct.
			endif
			break
		case 1: //update gain settings
			sprintf msg_out, "SET_PID_GAIN:%f,%f,%f,%f,%f,%f;", p, i, d, f, s, o
			SVAR Ecmd=root:S_EMControllerCMD
			if(SVAR_Exists(Ecmd))
				Ecmd=msg_out
			endif
			print "PID Gain parameters set as: "+msg_out
			status=2
			break			
		case 2: //checking if last command have been received
			if(EMCheckCMDStatusFlag()==1)
				print "PID Gain setting command has been received."
				status=3
				retVal=0
			endif
			break
		default:
			break
		endswitch
	catch
		Variable err=GetRTError(1)
		print "EMSetPIDGains encountered RTError: "+GetErrMessage(err)
	endtry
	
	SetDataFolder olddfr
	
	cmd=ReplaceStringByKey("PID_GAIN_STATUS", cmd, num2istr(status))
	return retVal
End

Constant EM_POSITIVE_ZERO=1e-6
Constant EM_NEGATIVE_ZERO=-1e-6

Function EMSetpoint(String & cmd, Variable new_setpoint, Variable error_range, Variable timeout_ticks, Variable strict_zero)
	Variable retVal=-1
	Variable status=str2num(StringByKey("SETPOINT_STATUS", cmd))
	if(numtype(status)!=0)
		status=0
	endif
	
	DFREF olddfr=GetDataFolderDFR()	
	try
		SetDataFolder $EMControllerGetPrivateFolderName()
		
		NVAR current_setpoint=:pid_setpoint
		WAVE input_chn=:input_chn
		NVAR chn_num=:pid_input_chn
		NVAR pid_gain_P=:pid_gain_P
		NVAR pid_gain_I=:pid_gain_I
		NVAR pid_gain_D=:pid_gain_D
		NVAR pid_gain_filter=:pid_gain_filter
		NVAR pid_scale_factor=:pid_scale_factor
		NVAR pid_offset_factor=:pid_offset_factor
		
		Variable polarity=1

		if(pid_scale_factor<0)
			polarity=-1
		endif
		
		if(new_setpoint==0)
			if(strict_zero!=1)
				new_setpoint=polarity*EM_POSITIVE_ZERO
			endif
		endif
		
		if(new_setpoint>10)
			new_setpoint=10
		endif
		
		if(new_setpoint<-10)
			new_setpoint=-10
		endif
		
		String polarity_str="POSITIVE"
		Variable correct_scale_factor=abs(pid_scale_factor)
		if(new_setpoint<0)
			polarity_str="NEGATIVE"
			correct_scale_factor=-abs(pid_scale_factor)
		endif
		
		String msg_out=""
		
		//when the same setpoint is issued, no new command will be sent, but only to check
		//the current input channel value to see if it is within error range.
		if((status==0) && (new_setpoint==current_setpoint) && (polarity*new_setpoint>=0)) //the same setpoint was sent again
			cmd=ReplaceStringByKey("SETPOINT_CHECK_START_TIME", cmd, num2istr(ticks))
			EMResetCMDStatusFlag()
			status=3
		endif
		
		switch(status)
		case 0: //initial call, check polarity first
			if(polarity*new_setpoint<0)
				//polarity is not correct
				if(EMCheckCMDStatusFlag()!=1)
					//print "current scale factor for setpoint is:"+num2str(pid_scale_factor)+", inconsistent with polarity of requested setpoint:"+num2str(new_setpoint)+". Asking user to switch."
					EMControllerWaitForUserAction("Please switch the polarity\nto "+polarity_str, EMControllerGetPrivateFlagName(), EMC_USRCMD_STATUS_OLD)
				else
					//print "User has confirmed changing the physical switch to polarity ["+polarity_str+"]. now will update polarity status together with setpoint."
					EMResetCMDStatusFlag()
					status=1
				endif
			else
				status=1 //polarity is already correct.
			endif
			break
		case 1: //update setpoint with proper scale factor/polarity
			String tmpstr=""
			if(correct_scale_factor!=pid_scale_factor) //will set the correct scale factor, offset is not changed though
				sprintf tmpstr, "SET_PID_GAIN:%f,%f,%f,%f,%f,%f;", pid_gain_P, pid_gain_I, pid_gain_D, pid_gain_filter, correct_scale_factor, pid_offset_factor
				msg_out+=tmpstr
			endif
			sprintf tmpstr, "SET_PID_SETPOINT:%f;", new_setpoint
			msg_out+=tmpstr
			SVAR Ecmd=root:S_EMControllerCMD
			if(SVAR_Exists(Ecmd))
				Ecmd=msg_out
			endif
			print "Setpoint parameters set as: "+msg_out
			status=2
			break			
		case 2: //checking if last command have been received
			if(EMCheckCMDStatusFlag()==1)
				print "EMSetpoint command has been received."
				status=3
				cmd=ReplaceStringByKey("SETPOINT_CHECK_START_TIME", cmd, num2istr(ticks))
			endif
			break
		case 3: // checking if current output is within error of setpoint
			Variable starttime=str2num(StringByKey("SETPOINT_CHECK_START_TIME", cmd))
			Variable currenttime=ticks
			if(currenttime-starttime>=timeout_ticks || abs(input_chn[chn_num]-new_setpoint)<=error_range)
				print "Within "+num2istr(currenttime-starttime)+" ticks, EMSetpoint found the input as "+num2str(input_chn[chn_num])+" after setting the setpoint:"+num2str(new_setpoint)+" and error range:"+num2str(error_range)
				status=4
				retVal=0
			endif
			break
		default:
			break
		endswitch
	catch
		Variable err=GetRTError(1)
		print "EMSetpoint encountered RTError: "+GetErrMessage(err)
	endtry
	
	SetDataFolder olddfr
	
	cmd=ReplaceStringByKey("SETPOINT_STATUS", cmd, num2istr(status))
	return retVal
End

Function EMControllerReadPIDChannels(Variable & input, Variable & output, Variable & setpoint)
	WAVE in_chns=$(EMControllerGetPrivateFolderName()+"input_chn")
	NVAR in_chn_num=$(EMControllerGetPrivateFolderName()+"pid_input_chn")
	WAVE out_chns=$(EMControllerGetPrivateFolderName()+"output_chn")
	NVAR out_chn_num=$(EMControllerGetPrivateFolderName()+"pid_output_chn")
	NVAR pid_setpoint=$(EMControllerGetPrivateFolderName()+"pid_setpoint")
	
	if(WAVEExists(in_chns) && WaveExists(out_chns) && NVAR_Exists(in_chn_num) && NVAR_Exists(out_chn_num) && NVAR_Exists(pid_setpoint))
		if(in_chn_num>=0 && in_chn_num<4)
			input=in_chns[in_chn_num]
		endif
		if(out_chn_num>=0 && out_chn_num<4)
			output=out_chns[out_chn_num]
		endif
		setpoint=pid_setpoint
	endif
End
