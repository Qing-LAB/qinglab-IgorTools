#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "QDataLink"

Menu "QDataLink"
	Submenu "EMController"
		"InitEMController", EMControllerINIT()
	End
End

Function EMControllerINIT()
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
		if(strlen(cpStr)>0)
			QDataLinkCore#QDLQuery(0, "", 0, realtime_func="EMController_rtfunc", postprocess_bgfunc="EMController_postprocess_bgfunc")
		endif
	endif
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
	SetVariable output_chn0,fSize=9,format="%+10.6f"
	SetVariable output_chn0,limits={-inf,inf,0},value= $(EMPrivatePath+"output_chn")[0],noedit= 1
	SetVariable output_chn1,pos={112.20,140.40},size={106.80,13.80},bodyWidth=60,title="OUT_CHN1"
	SetVariable output_chn1,userdata(ResizeControlsInfo)= A"!!,FC!!#@V!!#@,!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable output_chn1,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable output_chn1,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable output_chn1,fSize=9,format="%+10.6f"
	SetVariable output_chn1,limits={-inf,inf,0},value= $(EMPrivatePath+"output_chn")[1],noedit= 1
	SetVariable output_chn2,pos={112.20,161.40},size={106.80,13.80},bodyWidth=60,title="OUT_CHN2"
	SetVariable output_chn2,userdata(ResizeControlsInfo)= A"!!,FE!!#@m!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable output_chn2,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable output_chn2,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable output_chn2,fSize=9,format="%+10.6f"
	SetVariable output_chn2,limits={-inf,inf,0},value= $(EMPrivatePath+"output_chn")[2],noedit= 1
	SetVariable output_chn3,pos={112.20,179.40},size={106.80,13.80},bodyWidth=60,title="OUT_CHN3"
	SetVariable output_chn3,userdata(ResizeControlsInfo)= A"!!,FG!!#A*!!#@,!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable output_chn3,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable output_chn3,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable output_chn3,fSize=9,format="%+10.6f"
	SetVariable output_chn3,limits={-inf,inf,0},value= $(EMPrivatePath+"output_chn")[3],noedit= 1
	SetVariable pid_setpoint,pos={9.00,225.00},size={99.00,13.80},title="PID SETP"
	SetVariable pid_setpoint,help={"PID setpoint"}
	SetVariable pid_setpoint,userdata(ResizeControlsInfo)= A"!!,B)!!#AP!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_setpoint,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_setpoint,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_setpoint,fSize=9,format="%+10.6f"
	SetVariable pid_setpoint,limits={-inf,inf,0},value= $(EMPrivatePath+"pid_setpoint"),noedit= 1
	SetVariable pid_gain_P,pos={126.00,222.00},size={86.40,13.80},bodyWidth=40,title="PID GAIN P"
	SetVariable pid_gain_P,help={"PID gain proportional"}
	SetVariable pid_gain_P,userdata(ResizeControlsInfo)= A"!!,FQ!!#AL!!#?Y!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_P,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_P,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_P,fSize=9,format="%.3f"
	SetVariable pid_gain_P,limits={-inf,inf,0},value= $(EMPrivatePath+"pid_gain_P"),noedit= 1
	SetVariable pid_gain_I,pos={128.40,239.40},size={84.00,13.80},bodyWidth=40,title="PID GAIN I"
	SetVariable pid_gain_I,help={"PID gain integral"}
	SetVariable pid_gain_I,userdata(ResizeControlsInfo)= A"!!,FS!!#A^!!#?W!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_I,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_I,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_I,fSize=9,format="%.3f"
	SetVariable pid_gain_I,limits={-inf,inf,0},value= $(EMPrivatePath+"pid_gain_I"),noedit= 1
	SetVariable pid_gain_D,pos={124.20,257.40},size={88.20,13.80},bodyWidth=40,title="PID GAIN D"
	SetVariable pid_gain_D,help={"PID gain differential"}
	SetVariable pid_gain_D,userdata(ResizeControlsInfo)= A"!!,FQ!!#Ao!!#?Y!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_D,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_D,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_D,fSize=9,format="%.3f"
	SetVariable pid_gain_D,limits={-inf,inf,0},value= $(EMPrivatePath+"pid_gain_D"),noedit= 1
	SetVariable pid_scale_factor,pos={9.00,246.00},size={99.00,13.80},title="PID IN SCALE"
	SetVariable pid_scale_factor,help={"PID input scale factor (with polarity)"}
	SetVariable pid_scale_factor,userdata(ResizeControlsInfo)= A"!!,An!!#Af!!#@*!!#;mz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_scale_factor,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_scale_factor,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_scale_factor,fSize=9,format="+%.2f"
	SetVariable pid_scale_factor,limits={-inf,inf,0},value= $(EMPrivatePath+"pid_scale_factor"),noedit= 1
	SetVariable pid_offset_factor,pos={9.00,267.00},size={99.00,13.80},title="PID IN OFFSET"
	SetVariable pid_offset_factor,help={"PID input offset"}
	SetVariable pid_offset_factor,userdata(ResizeControlsInfo)= A"!!,A^!!#B$!!#@*!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_offset_factor,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_offset_factor,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_offset_factor,fSize=9,format="%+.2f"
	SetVariable pid_offset_factor,limits={-inf,inf,0},value= $(EMPrivatePath+"pid_offset_factor"),noedit= 1
	SetVariable pid_gain_filter,pos={126.60,274.80},size={85.80,13.80},bodyWidth=40,title="PID GAIN F"
	SetVariable pid_gain_filter,help={"PID input filter setting, 0 to 1"}
	SetVariable pid_gain_filter,userdata(ResizeControlsInfo)= A"!!,FU!!#B-!!#?Y!!#;]z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable pid_gain_filter,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable pid_gain_filter,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetVariable pid_gain_filter,fSize=9,format="%.2f"
	SetVariable pid_gain_filter,limits={-inf,inf,0},value= $(EMPrivatePath+"pid_gain_filter"),noedit= 1
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
End

//Function EMScanInit(Variable slot)
//
//	Make /O/N=(1000,4) root:EMdata
//	Make /O/N=1000 root:EMtime
//	Make /O/N=1000 root:EMrequestID
//	Make /O/N=1000/T root:EMresponse
//	NVAR c1=root:EMDataCount
//	if(!NVAR_Exists(c1))
//		Variable /G root:EMDataCount
//		NVAR c1=root:EMDataCount
//	endif
//	
//	WAVE EMdata=root:EMdata
//	WAVE EMtime=root:EMtime
//	WAVE EMrequestID=root:EMrequestID
//	WAVE /T EMresponse=root:EMresponse
//	
//	c1=0
//	EMdata=nan
//	EMtime=nan
//	EMrequestID=nan
//	EMresponse=""
//	
//	String time_ID=""
//	sprintf time_ID, "REQUEST_ID:%x;", ticks
//	String cmd=time_ID
//	String resp=""
//	
//	cmd+="SET_FPGA_STATE:1;"
//	cmd+="SET_OUTPUT:0,0,0,0;"
//	cmd+="SET_PID_SETPOINT:0;"
//	cmd+="SET_PID_RANGE:10,0;"
//	cmd+="SET_PID_GAIN:0.35,0.25,0.03,1,1,0;"
//	cmd+="SET_9219_CONVERSION_TIME:0;"//fast mode
//	cmd+="SET_9219_VOLTAGE_RANGE:0,1,4,4;" //60V for chn0, 15V for chn1, 0.125V for chn3 and chn4
//	cmd+="RESET_PID;"
//	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
//	
//	EMLog("EMInit send cmd to controller: "+cmd)
//	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
//	EMController_process_data(cmd, resp, slot)
//	
//	sprintf time_ID, "REQUEST_ID:%x;", ticks
//	cmd=time_ID
//	cmd+="SET_PID_INPUT_CHN:1;SET_PID_OUTPUT_CHN:1;SET_OUTPUT:10,0,0,0;"
//	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
//	EMLog("EMInit send cmd to controller: "+cmd)
//	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
//	EMController_process_data(cmd, resp, slot)
//	
//	sprintf time_ID, "REQUEST_ID:%x;", ticks
//	cmd=time_ID
//	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
//	EMLog("EMInit send cmd to controller: "+cmd)
//	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
//	EMController_process_data(cmd, resp, slot)
//	EMLog("Query finished. Last response is:"+resp)
//End

//Function EMShutdown(Variable slot)
//	String time_ID=""
//	sprintf time_ID, "REQUEST_ID:%x;", ticks
//	String cmd=time_ID
//	String resp=""
//	
//	cmd+="SET_FPGA_STATE:0;"
//	cmd+="SET_OUTPUT:0,0,0,0;"
//	cmd+="SET_PID_SETPOINT:0;SET_PID_GAIN:0,0,0,0,1,0;"
//	cmd+="SET_PID_INPUT_CHN:4;SET_PID_OUTPUT_CHN:4;"
//	cmd+="RESET_PID;"	
//	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
//	EMLog("EMShutdown send cmd to controller: "+cmd)
//	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
//	EMController_process_data(cmd, resp, slot)
//	
//	sprintf time_ID, "REQUEST_ID:%x;", ticks
//	cmd=time_ID
//	resp=""
//	cmd+="GET_DATA;GET_SYSTEM_STATUS;"
//	EMLog("EMShutdown send cmd to controller: "+cmd)
//	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
//	EMController_process_data(cmd, resp, slot)
//	EMLog("Query finished. Response processed:"+resp)
//End
//
//StrConstant PID_POSITIVE_GAIN_SETTING="0.35,0.25,0.03,1,1,0"
//StrConstant PID_NEGATIVE_GAIN_SETTING="0.35,0.25,0.03,1,-1,0"
//
//Function EMSetpoint(Variable slot, Variable setpoint, Variable timeout_ticks, Variable allowed_error, Variable polarity, [Variable & timestamp, Variable strict_zero])
//
//	String time_ID=""
//	String cmd=""
//	String resp=""
//	
//	String pid_gain_setting=""
//	
//	if(polarity>0)
//		polarity=1
//	elseif(polarity<0)
//		polarity=-1
//	else
//		print "polarity cannot be zero."
//		return -1
//	endif
//	
//	if(polarity<0)
//		pid_gain_setting=PID_NEGATIVE_GAIN_SETTING
//	else
//		pid_gain_setting=PID_POSITIVE_GAIN_SETTING
//	endif
//	
//	if(setpoint>10)
//		setpoint=10
//	endif
//	
//	if(setpoint==0)
//		if(ParamIsDefault(strict_zero) || strict_zero==0)
//			setpoint=allowed_error*polarity
//		endif
//	endif
//	
//	sprintf time_ID, "REQUEST_ID:%x;SET_PID_GAIN:%s;SET_PID_SETPOINT:%.6f;", ticks, pid_gain_setting, setpoint
//	cmd=time_ID
//	cmd+="GET_DATA;GET_SYSTEM_STATUS;GET_ERROR_LOG;"
//	
//	//EMLog("EMSetpoint send cmd to controller: "+cmd)
//	resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
//	EMController_process_data(cmd, resp, slot)
//	
//	WAVE d=root:EMdata
//	WAVE t=root:EMtime
//	NVAR c1=root:EMDataCount
//	Variable oldc
//	Variable start_time=ticks
//	Variable current_time=start_time
//	Variable actual_value=nan
//	do
//		Sleep /S 2
//		sprintf cmd, "REQUEST_ID:%x;GET_DATA;GET_SYSTEM_STATUS;", current_time
//		resp=""
//		EMLog("EMSetpoint send cmd to controller: "+cmd)
//		resp=QDataLinkCore#QDLQuery(slot, cmd, 1)
//		EMController_process_data(cmd, resp, slot)
//		oldc=c1-1
//		if(oldc<0)
//			oldc=999
//		endif
//		actual_value=d[oldc][1]
//		if(!ParamIsDefault(timestamp))
//			timestamp=t[oldc]
//		endif
//		current_time=ticks
//	while(current_time-start_time<timeout_ticks && abs(actual_value-setpoint)>allowed_error)
//	EMLog("EMSetpoint finished trying. Last status update: "+resp)
//	
//	if(abs(actual_value-setpoint)<=allowed_error)
//		sprintf resp, "EMSetpoint finds the field [%.6f] to be within allowed error [%.6f] around setpoint [%.6f]", actual_value, allowed_error, setpoint
//		EMLog(resp, g=32768)
//	else
//		sprintf resp, "EMSetpoint timed out when waiting field [%.6f] to settle down to be within allowed error [%.6f] around setpoint [%.6f]", actual_value, allowed_error, setpoint
//		EMLog(resp, r=65535)
//	endif
//	//print "timestamp is:", timestamp
//	return actual_value
//End


//Constant DEFAULT_KEITHLEY_TIMEOUT=1000 //ms
//Constant GaussMeterScaleFactor=1000 // 1 V = 1000 Gauss
//
//Function RunTest(Variable maxB, Variable errB, Variable number_of_pnts, Variable injectCurrent, Variable time_delay, Variable VISASlotEM, Variable VISASlotKeithley, String KeithleyScriptNB)
//
//	Variable Bfield, BActualField, starttimestamp, currenttimestamp
//	Variable deltaB
//	Variable i
//	
//	String nbName=KeithleyScriptNB
//	maxB=abs(maxB)
//	errB=abs(errB)/GaussMeterScaleFactor
//	
//	deltaB=maxB/(number_of_pnts-1)
//	
//	try
//		String wname=UniqueName("BScan_"+num2istr(maxB)+"Gauss", 1, 0)
//		Make /O/D/N=(4*number_of_pnts-2, 8) $wname=nan
//		Make /FREE/N=6 keithley_result
//		WAVE w=$wname
//		Variable count=0
//		
//		String smuconfig=KeithleyConfigSMUs("SMUA;SMUB", "")
//		if(strlen(smuconfig)>0)
//			KeithleyGenerateInitScript(smuconfig, nbName)		
//		else
//			AbortOnValue -1, -1
//		endif
//		display w[][6] vs w[][0]
//		String graph_name=S_name
//		edit w
//		Execute /Z "TileWindows /C/O=(0x01+0x02+0x08)"
//		DoWindow /F $EMLogBookName
//		
//		NewPanel /K=1 /W=(0,0,400,100) as "Please switch polarity of power supply to positive"
//		DoWindow/C tmp_PauseforPositivePolarity
//		AutoPositionWindow/E/M=1/R=$graph_name
//		DrawText 21,20,"Switch the polarity of power supply to positive"
//		DrawText 21,40,"And close this window to continue..."
//		
//		PauseForUser tmp_PauseforPositivePolarity
//		KillWindow /Z tmp_PauseforPositivePolarity
//		
//		KeithleyInit(VISASlotKeithley, nbName, DEFAULT_KEITHLEY_TIMEOUT)
//		EMScanInit(VISASlotEM)
//		
//		EMSetpoint(VISASlotEM, 0, time_delay*2, errB, 1, timestamp=starttimestamp)	
//		KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 1, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, 0)
//		
//		for(i=0; i<number_of_pnts; i+=1)
//			
//			Bfield=i*deltaB/GaussMeterScaleFactor
//		
//			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, 1, timestamp=currenttimestamp)
//			
//			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
//			
//			w[count][0]=BActualField*GaussMeterScaleFactor
//			
//			w[count][1]=currenttimestamp-starttimestamp
//			w[count][2]=keithley_result[0] //SMUA current
//			w[count][3]=keithley_result[1] //SMUA voltage
//			w[count][4]=keithley_result[2] //SMUA timestamp
//			w[count][5]=keithley_result[3] //SMUB current
//			w[count][6]=keithley_result[4] //SMUB voltage
//			w[count][7]=keithley_result[5] //SMUB timestamp
//			count+=1
//			//PauseForUser /C $graph_name
//		endfor
//		
//		for(i=number_of_pnts-2; i>=0; i-=1)
//			Bfield=i*deltaB/GaussMeterScaleFactor
//
//			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, 1, timestamp=currenttimestamp)
//			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
//			
//			w[count][0]=BActualField*GaussMeterScaleFactor
//			
//			w[count][1]=currenttimestamp-starttimestamp
//			w[count][2]=keithley_result[0] //SMUA current
//			w[count][3]=keithley_result[1] //SMUA voltage
//			w[count][4]=keithley_result[2] //SMUA timestamp
//			w[count][5]=keithley_result[3] //SMUB current
//			w[count][6]=keithley_result[4] //SMUB voltage
//			w[count][7]=keithley_result[5] //SMUB timestamp
//			count+=1
//			
//			//PauseForUser /C $graph_name
//		endfor
//		
//		
//		NewPanel /K=1 /W=(0,0,400,100) as "Please switch polarity of power supply to negative"
//		DoWindow/C tmp_PauseforNegativePolarity
//		AutoPositionWindow/E/M=1/R=$graph_name
//		DrawText 21,20,"Switch the polarity of power supply to negative"
//		DrawText 21,40,"And close this window to continue..."
//		
//		PauseForUser tmp_PauseforNegativePolarity
//		KillWindow /Z tmp_PauseforNegativePolarity
//			
//		for(i=0; i<number_of_pnts; i+=1)
//			Bfield=-i*deltaB/GaussMeterScaleFactor
//			
//			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, -1, timestamp=currenttimestamp)
//			
//			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
//			
//			w[count][0]=BActualField*GaussMeterScaleFactor
//			
//			w[count][1]=currenttimestamp-starttimestamp
//			w[count][2]=keithley_result[0] //SMUA current
//			w[count][3]=keithley_result[1] //SMUA voltage
//			w[count][4]=keithley_result[2] //SMUA timestamp
//			w[count][5]=keithley_result[3] //SMUB current
//			w[count][6]=keithley_result[4] //SMUB voltage
//			w[count][7]=keithley_result[5] //SMUB timestamp
//			count+=1
//			//PauseForUser /C $graph_name
//		endfor
//		
//		for(i=number_of_pnts-2; i>=0; i-=1)
//			Bfield=-i*deltaB/GaussMeterScaleFactor
//			
//			if(Bfield==0)
//				Bfield=-abs(errB)
//			endif
//			
//			BActualField=EMSetpoint(VISASlotEM, Bfield, time_delay*2, errB, -1, timestamp=currenttimestamp)
//			KeithleySMUMeasure(VISASlotKeithley, injectCurrent, 0, 0, keithley_result, DEFAULT_KEITHLEY_TIMEOUT, count)
//			
//			w[count][0]=BActualField*GaussMeterScaleFactor
//			
//			w[count][1]=currenttimestamp-starttimestamp
//			w[count][2]=keithley_result[0] //SMUA current
//			w[count][3]=keithley_result[1] //SMUA voltage
//			w[count][4]=keithley_result[2] //SMUA timestamp
//			w[count][5]=keithley_result[3] //SMUB current
//			w[count][6]=keithley_result[4] //SMUB voltage
//			w[count][7]=keithley_result[5] //SMUB timestamp
//			count+=1
//			
//			//PauseForUser /C $graph_name
//		endfor
//	
//	catch
//		Variable err=GetRTError(1)
//		print "ERROR During measurement: "+GetErrMessage(err)
//	endtry
//
//	KeithleyShutdown(VISASlotKeithley, DEFAULT_KEITHLEY_TIMEOUT)
//	EMShutdown(VISASlotEM)
//End

