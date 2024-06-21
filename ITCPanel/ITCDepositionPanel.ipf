#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu ITCMenuStr
	Submenu "DepositionData"
		"Inspect Deposition Data", DP_inspect_data_panel_init()
	End
End

Constant MaxDepositionRawRecordingLength = 600 // sec

Function DepositPanel_PostSlackChannel(String token, String channel, String message, String notify_person)
	String URL = "https://slack.com/api/chat.postMessage"
	String postData = "channel="+URLEncode(channel)+"&text=@"+URLEncode(notify_person)+"%20"+URLEncode(message)+"&pretty=1"
	URLRequest /DSTR = postData url=URL, method = post, headers = token
End

Constant MIN_PULSE_WIDTH=1
Constant MAX_PULSE_WIDTH=100
Constant MIN_PRE_PULSE_TIME=50
Constant MAX_PRE_PULSE_TIME=100
Constant MIN_POST_PULSE_DELAY=10
Constant MAX_POST_PULSE_DELAY=50
Constant MIN_POST_PULSE_SAMPLELEN=10

Function DepositionPanelPrepareDataFolder(variable len, variable samplingrate, variable adc_chnnum, variable dac_chnnum)
	Variable retVal=0
	
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName); AbortOnRTE
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance); AbortOnRTE
	WAVE /T chnlist=$WBPkgGetName(fPath, WBPkgDFWave, "ADC_Channel"); AbortOnRTE
	WAVE /T dacchnlist=$WBPkgGetName(fPath, WBPkgDFWave, "DAC_Channel"); AbortONRTE
	WAVE selectedchn=$WBPkgGetName(fPath, WBPkgDFWave, "selectedadcchn"); AbortOnRTE
	WAVE selecteddacchn=$WBPkgGetName(fPath, WBPkgDFWave, "selecteddacchn"); AbortOnRTE
	

	Variable max_cycle_count = round(MaxDepositionRawRecordingLength / (len/samplingrate)) // this is the number of cycles in half an hour that will be recorded with all raw data
	String deposit_folder_name = UniqueName("DepositRecord", 11, 0)
	DFREF dfr = GetDataFolderDFR()
	
	try
		NewDataFolder /O/S root:$deposit_folder_name
		
		Variable chnnum=adc_chnnum+dac_chnnum+2 // all channels plus two conductance calculation
		
		String raw_record_name = "root:"+deposit_folder_name+":"+deposit_folder_name+"_raw"
		String history_record_name = "root:"+deposit_folder_name+":"+deposit_folder_name+"_history"
		String raw_record_file_idx = "root:"+deposit_folder_name+":"+deposit_folder_name+"_rawidx"
		String history_view_name = "root:"+deposit_folder_name+":HISTORY_VIEW"
		
		Make /O/N=(len, chnnum+1)/D $raw_record_name=NaN //rawwave has one more colume for time stamp
		Wave rawwave=$raw_record_name
		
		Make /O/N=(15, chnnum, max_cycle_count)/D $history_record_name = NaN, $history_view_name = NaN
		Make /O/N=(len)/T=(strlen("raw_")+8+strlen("_")+8+strlen(".ibw")) $raw_record_file_idx

		Wave historywave=$history_record_name
		wave hist_view=$history_view_name
		
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
		SetDimLabel 0, 13, PULSE_HEIGHT, historywave, hist_view
		SetDimLabel 0, 14, FLAGS, historywave, hist_view
		
		Variable i
		for(i=0; i<adc_chnnum; i+=1)
			SetDimLabel 1, i, $(chnlist[selectedchn[i]]), historywave, hist_view
			SetDimLabel 1, i, $(chnlist[selectedchn[i]]), rawwave
		endfor
		for(i=adc_chnnum; i<adc_chnnum+dac_chnnum; i+=1)
			SetDimLabel 1, i, $(dacchnlist[selecteddacchn[i-adc_chnnum]]), historywave, hist_view
			SetDimLabel 1, i, $(dacchnlist[selecteddacchn[i-adc_chnnum]]), rawwave
		endfor
		SetDimLabel 1, adc_chnnum+dac_chnnum, TUNNELING_COND, historywave, rawwave, hist_view
		SetDimLabel 1, adc_chnnum+dac_chnnum+1, IONIC_COND, historywave, rawwave, hist_view
		SetDimLabel 1, adc_chnnum+dac_chnnum+2, TIMESTAMP, rawwave //rawwave has one more colume for time stamp
				
		SetDimLabel 2, -1, RECORD_TIME, historywave, hist_view
		
		SetScale /P z, 0, len/samplingrate, "s", historywave, hist_view
		SetScale /P x, 0, 1/samplingrate, "s", rawwave
		
		SetWindow ITCPanel, userdata(DepositRecord_FOLDER)=deposit_folder_name
		SetWindow ITCPanel, userdata(DepositRecord_RAW)=raw_record_name
		SetWindow ITCPanel, userdata(DepositRecord_HISTORY)=history_record_name
		SetWindow ITCPanel, userdata(DepositRecord_HISTORYVIEW)=history_view_name
		SetWindow ITCPanel, userdata(DepositRecord_RAWFILEIDX)=raw_record_file_idx
		
		Variable /G tunneling_conductance=0
		Variable /G tunneling_conductance_stdev=0
		Variable /G ionic_conductance=0
		Variable /G ionic_conductance_stdev=0
		
		Variable /G tunneling_scale=1e-6
		Variable /G tunneling_ADC_offset=0
		Variable /G tunneling_DAC0_offset=0
		Variable /G tunneling_DAC1_offset=0
		Variable /G ionic_scale=1e-6
		Variable /G ionic_ADC_offset=0
		Variable /G ionic_DAC0_offset=0
		Variable /G ionic_DAC1_offset=0
		
		Variable /G rest_bias=-0.4
		Variable /G deposit_bias=-1.3
		Variable /G removal_bias=0.6
		
		Variable /G target_cond=2
		Variable /G target_err_ratio=10 //in percent
		
		Variable /G total_cycle_time=0
		
		Variable /G tunneling_deltaV=0.01
		Variable /G ionic_deltaV=0.05
		Variable /G rest_cycle_number=1
		Variable /G rest_cycle_countdown=0
		
		Variable /G pulse_width=MIN_PULSE_WIDTH*2
		Variable /G pre_pulse_time=MIN_PRE_PULSE_TIME*2
		Variable /G post_pulse_delay=MIN_POST_PULSE_DELAY*2
		Variable /G post_pulse_sample_len=MIN_POST_PULSE_SAMPLELEN
		
		Variable /G Kp=1
		Variable /G Ki=0
		Variable /G Kd=0
		Variable /G Er_Int=0
		Variable /G Er_Prev=0
		Variable /G PID_CV=0
		Variable /G deposit_recording=0
		Variable /G display_len=60
		
		Variable /G PID_enabled=0
		Variable /G continuous_exec=0
		Variable /G exec_mode=1
		
		Variable /G deposition_status=0
		Variable /G deposition_indicator=0
		
	catch
		Variable err = GetRTError(1)		// Gets error code and clears error
		String errMessage = GetErrMessage(err)
		Printf "preparing data folder for depositpanel encountered the following error: %s\r", errMessage
		retVal=-1
	endtry
	
	SetDataFolder dfr
	return retVal
End



Function DepositionPanelInit(variable length)
	Variable retVal=0
	
	String PanelName=GetUserData("ITCPanel", "", "DepositionPanel")
	if(strlen(PanelName)>0)
		if(WinType(PanelName) == 7)
			return 0
		endif
	endif	
	
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
	
	DFREF dfr=GetDataFolderDFR()
	String deposit_folder_name = GetUserData("ITCPanel", "", "DepositRecord_FOLDER"); AbortOnRTE
	
	try		
		SetDataFolder root:$deposit_folder_name; AbortOnRTE
		
		NVAR tunneling_conductance; AbortOnRTE
		NVAR tunneling_conductance_stdev; AbortOnRTE
		NVAR ionic_conductance; AbortOnRTE
		NVAR ionic_conductance_stdev; AbortOnRTE
		
		NVAR tunneling_scale; AbortOnRTE
		NVAR tunneling_ADC_offset; AbortOnRTE
		NVAR tunneling_DAC0_offset; AbortOnRTE
		NVAR tunneling_DAC1_offset; AbortOnRTE
		NVAR ionic_scale; AbortOnRTE
		NVAR ionic_ADC_offset; AbortOnRTE
		NVAR ionic_DAC0_offset; AbortOnRTE
		NVAR ionic_DAC1_offset; AbortOnRTE
		
		NVAR rest_bias; AbortOnRTE
		NVAR deposit_bias; AbortOnRTE
		NVAR removal_bias; AbortOnRTE
		
		NVAR target_cond; AbortOnRTE
		NVAR target_err_ratio; AbortOnRTE
		
		NVAR total_cycle_time; AbortOnRTE
		NVAR pulse_width; AbortOnRTE
		NVAR pre_pulse_time; AbortOnRTE
		NVAR post_pulse_delay; AbortOnRTE
		NVAR post_pulse_sample_len; AbortOnRTE
		NVAR display_len; AbortOnRTE
		NVAR Kp; AbortOnRTE
		NVAR Ki; AbortOnRTE
		NVAR Kd; AbortOnRTE
		NVAR PID_CV; AbortOnRTE
		NVAR deposit_recording; AbortOnRTE
		
		NVAR tunneling_deltaV; AbortOnRTE
		NVAR ionic_deltaV; AbortOnRTE
		NVAR rest_cycle_number; AbortOnRTE
		NVAR rest_cycle_countdown; AbortOnRTE
		
		NVAR PID_enabled; AbortOnRTE
		NVAR continuous_exec; AbortOnRTE
		NVAR exec_mode; AbortOnRTE
		NVAR deposition_indicator; AbortOnRTE
		
		String tvalstr = ""
		
		NewPanel /EXT=0 /HOST=ITCPanel /K=2 /N=DepositionPanel /W=(0,0,420,500)
		String depositpanel_name = S_name
		SetWindow ITCPanel, userdata(DepositionPanel)="ITCPanel#"+depositpanel_name
		//ADC and DAC parameters
		GroupBox depositpanel_grp_adcdac,title="ADC and DAC settings",size={420,150},pos={0,0}
		
		PopupMenu depositpanel_tunneling_chn,title="tunneling I",size={180,20},bodyWidth=60,mode=1
		PopupMenu depositpanel_tunneling_chn,pos={20,20},value=#adcchn_list
		PopupMenu depositpanel_tunneling_chn,help={"Select the ADC channel representing \nthe raw voltage signal for tunneling current"}
		
		SetVariable depositpanel_tunneling_ADC_correction,title="offset(V)",size={60,20},pos={140,40}
		SetVariable depositpanel_tunneling_ADC_correction,bodywidth=40,limits={-0.5,0.5,0},value=tunneling_ADC_offset
		SetVariable depositpanel_tunneling_ADC_correction,help={"The correction for the raw signal of tunneling current.\nTune the current to be zero and \nread the ADC channel. \nIf the voltage is not zero, \nenter the negative of the value here.\nIt will be added to the recorded data\nto correct the error."}
		
		SetVariable depositpanel_tunneling_sensitivity,title="scale(A/V)",size={90,20},bodywidth=40
		SetVariable depositpanel_tunneling_sensitivity,pos={20,40},value=tunneling_scale,limits={1e-12,1,0}
		SetVariable depositpanel_tunneling_sensitivity,help={"Sensitivity for the preamp that converts\ntunneling current to voltage signal"}
		
		PopupMenu depositpanel_tunneling_bias_chn,title="tunneling V",size={180,20},mode=1
		PopupMenu depositpanel_tunneling_bias_chn,bodyWidth=60,pos={20,60},value=#dacchn_list
		PopupMenu depositpanel_tunneling_bias_chn,help={"Select the DAC channel that sends voltage signal to \nchange the potential on the tunneling current preamp side."}
		
		SetVariable depositpanel_tunneling_bias_offset,title="offset correction(V)", size={180,20}
		SetVariable depositpanel_tunneling_bias_offset,bodywidth=60, pos={20,80},value=tunneling_DAC0_offset,limits={-0.5,0.5,0}
		SetVariable depositpanel_tunneling_bias_offset,help={"The correction for the output signal of the bias channel.\nMeasure the actual output voltage when setting the output to zero.\nIf the actual voltage is not zero, \nenter the negative of the value here. \nIt will be added to the output wave before sending to the hardware\nto correct the offset error."}
		
		CheckBox depositpanel_tunneling_bias_subtraction,title="subtract?", size={50,20},pos={10, 62},side=1,value=1
		CheckBox depositpanel_tunneling_bias_subtraction,help={"If the tunneling current preamp circuit does not have compensation \nfor the bias applied at the preamp side, \nthis will subtract the applied bias (from the DAC record)\n from the read out voltage to correct the baseline shift."}
		
		PopupMenu depositpanel_tunneling_bias_counter_chn,title="tunneling V counter",size={180,20},mode=2
		PopupMenu depositpanel_tunneling_bias_counter_chn,bodyWidth=60,pos={20,100},value=#dacchn_list
		PopupMenu depositpanel_tunneling_bias_counter_chn,help={"Select the DAC channel that sends voltage signal to\nchange the potential on the opposite/counter side from the electrode \nconnected with the tunneling current preamp."}
		
		SetVariable depositpanel_tunneling_bias_counter_offset,title="offset correction(V)", size={180,20}
		SetVariable depositpanel_tunneling_bias_counter_offset,bodywidth=70, pos={20,120},value=tunneling_DAC1_offset,limits={-0.5,0.5,0}
		SetVariable depositpanel_tunneling_bias_counter_offset,help={"The correction for the output signal of the counter bias channel.\nMeasure the actual output voltage when setting the output to zero.\nIf the actual voltage is not zero, \nenter the negative of the value here. \nIt will be added to the output wave before sending to the hardware\nto correct the offset error."}
		
		PopupMenu depositpanel_ionic_chn,title="ionic I",size={180,20},bodyWidth=60,pos={220,20},value=#adcchn_list,mode=1
		PopupMenu depositpanel_ionic_chn,help={"Select the ADC channel representing \nthe raw voltage signal for ionic current"}
		
		SetVariable depositpanel_ionic_raw_correction,title="offset(V)",size={60,20},pos={340,40}
		SetVariable depositpanel_ionic_raw_correction,bodywidth=40,limits={-0.5,0.5,0},value=ionic_ADC_offset
		SetVariable depositpanel_ionic_raw_correction,help={"The correction for the raw signal of ionic current.\nTune the current to be zero and \nread the ADC channel. \nIf the voltage is not zero, \nenter the negative of the value here.\nIt will be added to the recorded data\nto correct the error."}
		
		SetVariable depositpanel_ionic_sensitivity,title="scale(A/V)",size={90,20},bodywidth=40
		SetVariable depositpanel_ionic_sensitivity,pos={220,40},value=ionic_scale,limits={1e-12,1,0}
		SetVariable depositpanel_ionic_sensitivity,help={"Sensitivity for the preamp that converts\nionic current to voltage signal"}
		
		PopupMenu depositpanel_ionic_bias_chn,title="ionic V",size={180,20},bodyWidth=60
		PopupMenu depositpanel_ionic_bias_chn,pos={220,60},value=#dacchn_list,mode=3
		PopupMenu depositpanel_ionic_bias_chn,help={"Select the DAC channel that sends voltage signal to \nchange the potential on the ionic current preamp side."}
		
		SetVariable depositpanel_ionic_bias_offset,title="offset correction(V)", size={180,20}
		SetVariable depositpanel_ionic_bias_offset,bodywidth=60, pos={220,80},value=ionic_DAC0_offset,limits={-inf,inf,0}
		SetVariable depositpanel_ionic_bias_offset,help={"The correction for the output signal of the bias channel.\nMeasure the actual output voltage when setting the output to zero.\nIf the actual voltage is not zero, \nenter the negative of the value here. \nIt will be added to the output wave before sending to the hardware\nto correct the offset error."}
		
		CheckBox depositpanel_ionic_bias_subtraction,title="subtract?", size={50,20},pos={210, 62},side=1,value=1
		CheckBox depositpanel_ionic_bias_subtraction,help={"If the ionic current preamp circuit does not have compensation \nfor the bias applied at the preamp side, \nthis will subtract the applied bias (from the DAC record)\n from the read out voltage to correct the baseline shift."}
		
		PopupMenu depositpanel_ionic_bias_counter_chn,title="ionic V counter",size={180,20},bodyWidth=60
		PopupMenu depositpanel_ionic_bias_counter_chn,pos={220,100},value=#dacchn_list,mode=4
		PopupMenu depositpanel_ionic_bias_counter_chn,help={"Select the DAC channel that sends voltage signal to\nchange the potential on the opposite/counter side from the electrode \nconnected with the ionic current preamp."}
		
		SetVariable depositpanel_ionic_bias_counter_offset,title="offset correction(V)", size={180,20},bodywidth=70
		SetVariable depositpanel_ionic_bias_counter_offset,pos={220,120},value=ionic_DAC1_offset,limits={-0.5,0.5,0}
		SetVariable depositpanel_ionic_bias_counter_offset,help={"The correction for the output signal of the counter bias channel.\nMeasure the actual output voltage when setting the output to zero.\nIf the actual voltage is not zero, \nenter the negative of the value here. \nIt will be added to the output wave before sending to the hardware\nto correct the offset error."}
		
		//display parameter
		GroupBox depositpanel_grp_display,title="Display/Graph",size={220,180},pos={200,160}
		CheckBox depositpanel_errorbar,title="error bar enabled", size={170,20},pos={280,180},side=1,bodywidth=60,proc=DepositPanel_cb_errorbar
		SetVariable depositionpanel_histlen, title="history display len (s)", value=display_len,size={180,20},bodywidth=70,pos={230,200},limits={10, MaxDepositionRawRecordingLength, 1}
		
		SetVariable depositpanel_target_conductance,title="Target(nS)",variable=target_cond,size={125,20},pos={210,220},limits={0.001,1000,0.1}	
		SetVariable depositpanel_target_conductance,help={"The target conductance when deposition/removal should be stopped."}
		SetVariable depositpanel_target_err_ratio,title="+/-(%)",variable=target_err_ratio,size={80,20},pos={335,220},limits={0.1,100,1}	
		SetVariable depositpanel_target_err_ratio,help={"The range in percentage that will trigger deposition or removal pulses."}
		
		PopupMenu depositpanel_target_variable,title="FeedbackChn:",value="Tunneling Conductance;Ionic Conductance",mode=1
		PopupMenu depositpanel_target_variable,size={200,20},bodywidth=120,pos={210,240}
		
		tvalstr="root:"+deposit_folder_name+":tunneling_conductance"
		Valdisplay depositpanel_t_cond,title="Cond_T (nS):",value=#(tvalstr),size={140,20},pos={210,260},format="%+0.3f"
		Valdisplay depositpanel_t_cond,valueBackColor=(3,52428,1)
		Valdisplay depositpanel_t_cond,help={"Calculated tunneling conductance"}
		tvalstr="root:"+deposit_folder_name+":tunneling_conductance_stdev"
		Valdisplay depositpanel_t_cond_stdev, title="+/-",value=#(tvalstr),size={60,20},pos={350,260},format="%0.3f"
		Valdisplay depositpanel_t_cond_stdev,valueBackColor=(3,52428,1)
		
		tvalstr="root:"+deposit_folder_name+":ionic_conductance"
		Valdisplay depositpanel_i_cond,title="Cond_I (nS):",value=#(tvalstr),size={140,20},pos={210,280},format="%+0.3f"
		Valdisplay depositpanel_i_cond,valueBackColor=(3,52428,1)
		Valdisplay depositpanel_i_cond,help={"Calculated cross-ionic channels conductance"}
		tvalstr="root:"+deposit_folder_name+":ionic_conductance_stdev"
		Valdisplay depositpanel_i_cond_stdev, title="+/-",value=#(tvalstr),size={60,20},pos={350,280},format="%0.3f"
		Valdisplay depositpanel_i_cond_stdev,valueBackColor=(3,52428,1)
		
				
		Checkbox depositpanel_recording,title="Data recording",size={90,25},pos={210,320},variable=deposit_recording
		Checkbox depositpanel_recording,help={"Get raw data saved into disk as individual wave files.\nIn the igor file, only history and file records are saved."}
		
		//deposition parameters
		GroupBox depositpanel_grp_depositwavesetup,title="Deposit pulse(Need Update)",size={200,330},pos={0,160},fColor=(65535,0,0),fstyle=1,labelBack=(65535,16385,16385,16384)
		
		SetVariable depositpanel_tunneling_deltaV,title="Tunneling deltaV",value=tunneling_deltaV,size={180,20},bodywidth=80,pos={10,180},limits={-0.2,0.2,0.01}
		SetVariable depositpanel_tunneling_deltaV,help={"The bias across the tunneling gap that should be maintained throughout the process."}
		SetVariable depositpanel_tunneling_deltaV,proc=DepositPanel_sv_update_depositwave
		
		SetVariable depositpanel_ionic_deltaV,title="Ionic deltaV",value=ionic_deltaV,size={180,20},bodywidth=80,pos={10,200},limits={-0.5,0.5,0.01}
		SetVariable depositpanel_ionic_deltaV,help={"The bias between the ionic channels that should be maintained throughout the process."}
		SetVariable depositpanel_ionic_deltaV,proc=DepositPanel_sv_update_depositwave
		
		PopupMenu depositpanel_pulse_method,title="DepBiasApplied",size={180,20},pos={10,240},bodyWidth=100,value="@Tunneling;@Reference;Customized;"
		PopupMenu depositpanel_pulse_method,help={"This specifies how the deposition bias should be applied: \neither letting the reference electrodes hold resting potential \nand apply just the pulse from the tunneling electrodes, \nor letting the tunneling electrodes always hold at \ngrounding potential, and change the reference electrodes.\nThe deltaV will be maintained between tunneling electrodes."}
		PopupMenu depositpanel_pulse_method,proc=DepositPanel_pm_update_depositwave
		
		SetVariable depositpanel_rest_bias,title="rest_bias (V)",value=rest_bias,size={180,20},pos={10,260},limits={-1.5,1.5,0.01}
		SetVariable depositpanel_rest_bias,proc=DepositPanel_sv_update_depositwave
		SetVariable depositpanel_deposit_bias,title="deposit_bias (V)",value=deposit_bias,size={180,20},pos={10,280},limits={-1.5,1.5,0.01}
		SetVariable depositpanel_deposit_bias,proc=DepositPanel_sv_update_depositwave
		SetVariable depositpanel_removal_bias,title="removal_bias (V)",value=removal_bias,size={180,20},pos={10,300},limits={-1.5,1.5,0.01}
		SetVariable depositpanel_removal_bias,proc=DepositPanel_sv_update_depositwave
		
		tvalstr="root:"+deposit_folder_name+":total_cycle_time"
		ValDisplay depositpanel_total_cycle_time,title="total_cycle_time (s)",value=#(tvalstr),size={180,20},pos={10,320},frame=0
		ValDisplay depositpanel_total_cycle_time,valueBackColor=(40969,65535,16385),labelBack=(32792,65535,1)
	
		SetVariable depositpanel_pulse_width,title="pulse_width (ms)",value=pulse_width,size={180,20},pos={10,340},limits={MIN_PULSE_WIDTH,MAX_PULSE_WIDTH,1}
		SetVariable depositpanel_pulse_width,proc=DepositPanel_sv_update_depositwave
		SetVariable depositpanel_pre_pulse_time,title="pre_pulse_time (ms)",value=pre_pulse_time,size={180,20},pos={10,360},limits={MIN_PRE_PULSE_TIME,MAX_PRE_PULSE_TIME,1}
		SetVariable depositpanel_pre_pulse_time,proc=DepositPanel_sv_update_depositwave
		SetVariable depositpanel_post_pulse_delay,title="post_pulse_delay (ms)",value=post_pulse_delay,size={180,20},pos={10,380},limits={MIN_POST_PULSE_DELAY,MAX_POST_PULSE_DELAY,1}
		SetVariable depositpanel_post_pulse_delay,proc=DepositPanel_sv_update_depositwave
		
		tvalstr="root:"+deposit_folder_name+":post_pulse_sample_len"
		ValDisplay depositpanel_post_pulse_samplelen,title="post_pulse_sample_len",value=#(tvalstr),size={180,20},pos={10,400},frame=0
		ValDisplay depositpanel_post_pulse_samplelen,valueBackColor=(40969,65535,16385),labelBack=(32792,65535,1)
		
		Button depositpanel_update_deposit_parameters, title="UPDATE!",size={180,50},pos={10,430},fColor=(52428,1,1),proc=DepositionPanel_Btn_update_deppulse

		//////////////////////////////////////
		// deposition control
		GroupBox depositpanel_grp_depositcontrol,title="Deposition Control",size={220,150},pos={200,340}
		
		SetVariable depositpanel_rest_cycle,title="rest cycle#",value=rest_cycle_number,size={180,20},pos={210,360},limits={1,100,1}
		SetVariable depositpanel_rest_cycle,help={"Set the blank cycles where only the rest potential is applied between application of pulses."}
		
		tvalstr="root:"+deposit_folder_name+":rest_cycle_countdown"
		Valdisplay depositpanel_pulsedelaycount, title="Rest cycle countdown:", value=#(tvalstr),size={180,20},pos={210,380}
		tvalstr="root:"+deposit_folder_name+":deposition_indicator"
		ValDisplay depositpanel_pulse_indicator,title="",pos={390,380},size={15,15},zeroColor=(0,65535,0),mode=1,barmisc={0,0},limits={-1,1,0},value=#(tvalstr)
		
		Button depositpanel_exec,title="Execute",size={80,20},pos={205,400},fColor=(0,32768,0),proc=DepositionPanel_Btn_exec
		PopupMenu depositpanel_depmode,title="mode",size={100,20},pos={290,400},value="Rest;Close;Open;ForcedClose;ForcedOpen;PID;",mode=exec_mode
		
		CheckBox depositpanel_continuous,title="continuous",size={80,20},pos={205,425},variable=continuous_exec
		
		SetVariable depositpanel_Kp,title="Kp",value=Kp,size={60,20},pos={205,450},limits={0,10,0.01}
		SetVariable depositpanel_Ki,title="Ki",value=Ki,size={60,20},pos={270,450},limits={0,10,0.01}
		SetVariable depositpanel_Kd,title="Kd",value=Kd,size={60,20},pos={335,450},limits={0,10,0.01}
		
		tvalstr="root:"+deposit_folder_name+":PID_CV"
		Valdisplay depositpanel_PID_CV, title="PID_CV", value=#(tvalstr),size={190,20},barmisc={0,50},format="%-2.5f",pos={205,470},limits={-10,10,0}
		
		//print("Deposition panel initialized.")
	catch	
		Variable err = GetRTError(1)		// Gets error code and clears error
		String errMessage = GetErrMessage(err)
		Printf "init deposit panel encountered the following error: %s\r", errMessage
		DepositionPanelexit()
		retVal=-1
	endtry
	return retVal	
End

Function DepositPanel_sv_update_depositwave(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	String depositpanel_name = GetUserData("ITCPanel", "", "DepositionPanel")
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			GroupBox depositpanel_grp_depositwavesetup,win=$(depositpanel_name),title="Deposit pulse(Need Update)",fColor=(65535,0,0),fstyle=1,labelBack=(65535,16385,16385,16384)
			Button depositpanel_update_deposit_parameters,win=$(depositpanel_name),fColor=(52428,1,1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DepositPanel_pm_update_depositwave(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	String depositpanel_name = GetUserData("ITCPanel", "", "DepositionPanel")
	
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			GroupBox depositpanel_grp_depositwavesetup,win=$(depositpanel_name),title="Deposit pulse(Need Update)",fColor=(65535,0,0),fstyle=1,labelBack=(65535,16385,16385,16384)
			Button depositpanel_update_deposit_parameters,win=$(depositpanel_name),fColor=(52428,1,1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function DepositionPanelExit()
	String depositpanel_name = GetUserData("ITCPanel", "", "DepositionPanel")
	if(strlen(depositpanel_name)>0)
		KillWindow /Z $(depositpanel_name)
		SetWindow ITCPanel, userdata(DepositionPanel)=""
	endif
End

Function DepositPanel_cb_errorbar(cb) : CheckBoxControl
	STRUCT WMCheckboxAction & cb
	
	switch(cb.eventCode)
		case 2:		// Mouse up
			rtgraph_update_display()
			break
	endswitch
	
	return 0
End

Function DepositionPanel_Btn_update_deppulse(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String panel_name = GetUserData("ITCPanel", "", "DepositionPanel")
			String deposit_folder_name = GetUserData("ITCPanel", "", "DepositRecord_FOLDER"); AbortOnRTE

			ControlInfo /W=ITCPanel itc_sv_samplingrate
			Variable sampling_rate=V_Value
						
			ControlInfo /W=$(panel_name) depositpanel_pulse_method
			Variable pulse_method=V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_tunneling_bias_chn
			Variable tunneling_bias_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositpanel_tunneling_bias_counter_chn
			Variable tunneling_bias_counter_chn = V_Value - 1
			ControlInfo /W=$(panel_name) depositpanel_ionic_bias_chn
			Variable ionic_bias_chn = V_Value - 1			
			
			ControlInfo /W=$(panel_name) depositpanel_ionic_bias_counter_chn
			Variable ionic_bias_counter_chn = V_Value - 1	
			
			DepositePanel_GeneratePulse(deposit_folder_name, pulse_method, sampling_rate)
			DepositPanel_SendPulse(deposit_folder_name, -1, 0, 0, 0, tunneling_bias_chn, tunneling_bias_counter_chn, ionic_bias_chn, ionic_bias_counter_chn, 0)
			
			GroupBox depositpanel_grp_depositwavesetup,win=$(panel_name),title="Deposit pulse(Updated)",fColor=(0,0,0),fstyle=0,labelBack=0
			Button depositpanel_update_deposit_parameters,win=$(panel_name),fColor=(0,0,0)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DepositePanel_GeneratePulse(string deposit_folder_name, variable pulse_method, variable sampling_rate)
	
	DFREF dfr=GetDataFolderDFR()
	
	try
		SetDataFolder $("root:"+deposit_folder_name); AbortOnRTE
		
		NVAR tunneling_scale; AbortOnRTE		
		NVAR tunneling_DAC0_offset; AbortOnRTE
		NVAR tunneling_DAC1_offset; AbortOnRTE
		
		NVAR ionic_scale; AbortOnRTE		
		NVAR ionic_DAC0_offset; AbortOnRTE
		NVAR ionic_DAC1_offset; AbortOnRTE
		
		NVAR rest_bias; AbortOnRTE
		NVAR deposit_bias; AbortOnRTE
		NVAR removal_bias; AbortOnRTE
		
		NVAR total_cycle_time; AbortOnRTE
		NVAR pulse_width; AbortOnRTE
		NVAR pre_pulse_time; AbortOnRTE
		NVAR post_pulse_delay; AbortOnRTE
		NVAR post_pulse_sample_len; AbortOnRTE
		NVAR tunneling_deltaV; AbortOnRTE
		NVAR ionic_deltaV; AbortOnRTE
		
		Variable total_len = total_cycle_time * sampling_rate
		Variable prepulse_idx = floor(sampling_rate*pre_pulse_time/1000+1)
		Variable pulse_end_idx = prepulse_idx+floor(sampling_rate*pulse_width/1000+1)
		
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_DEPOSIT")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_DEPOSIT")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_DEPOSIT")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_DEPOSIT")
		
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_REMOVAL")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_REMOVAL")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_REMOVAL")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_REMOVAL")
		
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_REST")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_REST")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_REST")
		Make /N=(total_len)/D/O $("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_REST")
		
		Wave tdacw0_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_DEPOSIT")
		Wave tdacw1_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_DEPOSIT")
		Wave idacw0_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_DEPOSIT")
		Wave idacw1_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_DEPOSIT")
		
		Wave tdacw0_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_REMOVAL")
		Wave tdacw1_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_REMOVAL")
		Wave idacw0_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_REMOVAL")
		Wave idacw1_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_REMOVAL")
		
		
		Wave tdacw0_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_REST")
		Wave tdacw1_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_REST")
		Wave idacw0_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_REST")
		Wave idacw1_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_REST")
		
		
		SetScale/P x 0,5e-5,"s", tdacw0_dp, tdacw1_dp, idacw0_dp, idacw1_dp, tdacw0_rm, tdacw1_rm, idacw0_rm, idacw1_rm, tdacw0_rest, tdacw1_rest, idacw0_rest, idacw1_rest
			
		if(pulse_method==1) //@tunneling
			
			tdacw0_dp[0,prepulse_idx-1] = tunneling_DAC0_offset + rest_bias
			tdacw0_rm[0,prepulse_idx-1] = tunneling_DAC0_offset + rest_bias
			tdacw0_rest = tunneling_DAC0_offset + rest_bias
			tdacw1_rest = tunneling_DAC1_offset + rest_bias + tunneling_deltaV
			
			tdacw0_dp[prepulse_idx, pulse_end_idx-1] = tunneling_DAC0_offset + deposit_bias
			tdacw0_rm[prepulse_idx, pulse_end_idx-1] = tunneling_DAC0_offset + removal_bias
			
			tdacw0_dp[pulse_end_idx, total_len-1] = tunneling_DAC0_offset + rest_bias
			tdacw0_rm[pulse_end_idx, total_len-1] = tunneling_DAC0_offset + rest_bias
			
			tdacw1_dp=tdacw0_dp + (-tunneling_DAC0_offset + tunneling_DAC1_offset + tunneling_deltaV)
			tdacw1_rm=tdacw0_rm + (-tunneling_DAC0_offset + tunneling_DAC1_offset + tunneling_deltaV)
			
			idacw0_dp = ionic_DAC0_offset
			idacw0_rm = ionic_DAC0_offset
			idacw0_rest = ionic_DAC0_offset
			idacw1_rest = ionic_DAC1_offset + ionic_deltaV
			
			idacw1_dp = ionic_DAC1_offset + ionic_deltaV
			idacw1_rm = idacw1_dp
		
		elseif(pulse_method==2) //@reference
			
			tdacw0_dp = tunneling_DAC0_offset
			tdacw0_rm = tunneling_DAC0_offset
			
			tdacw0_rest = tunneling_DAC0_offset
			tdacw1_rest = tunneling_DAC1_offset + tunneling_deltaV
			
			tdacw1_dp = tunneling_DAC1_offset + tunneling_deltaV
			tdacw1_rm = tunneling_DAC1_offset + tunneling_deltaV
			
			idacw0_dp[0,prepulse_idx-1] = ionic_DAC0_offset - rest_bias
			idacw0_rm[0,prepulse_idx-1] = ionic_DAC0_offset - rest_bias
			
			idacw0_rest = ionic_DAC0_offset - rest_bias
			idacw1_rest = ionic_DAC1_offset - rest_bias + ionic_deltaV
			
			idacw0_dp[prepulse_idx, pulse_end_idx-1] = ionic_DAC0_offset - deposit_bias
			idacw0_rm[prepulse_idx, pulse_end_idx-1] = ionic_DAC0_offset - removal_bias
			
			idacw0_dp[pulse_end_idx, total_len-1] = ionic_DAC0_offset - rest_bias
			idacw0_rm[pulse_end_idx, total_len-1] = ionic_DAC0_offset - rest_bias
						
			idacw1_dp = idacw0_dp[p] + (-ionic_DAC0_offset + ionic_DAC1_offset + ionic_deltaV)
			idacw1_rm = idacw0_rm[p] + (-ionic_DAC0_offset + ionic_DAC1_offset + ionic_deltaV)
		
		elseif(pulse_method==3) //customized
			print("Customized wave not implemented yet.")
		endif
	
	catch
		Variable err=GetRTError(1)
		print "Error when generating the wave for pulse deposition: ", err
		print GetRTErrMessage()
	endtry
	
	SetDataFolder dfr
	
End

Function DepositionPanel_update_exec_button(Variable flag)
	String panel_name = GetUserData("ITCPanel", "", "DepositionPanel")
	String deposit_folder_name = GetUserData("ITCPanel", "", "DepositRecord_FOLDER"); AbortOnRTE
	
	Variable deposition_status = str2num(GetUserData("ITCPanel", "", "DepositRecord_DEPOSIT_EXEC"))
	
	switch(flag)
	case 0:
		deposition_status = 0
		break
	case 1:
		deposition_status = 1
		break
	default:
		deposition_status = ! deposition_status
	endswitch
	
	NVAR rest_cycle = $("root:"+deposit_folder_name+":rest_cycle_number")
	NVAR rest_cycle_countdown = $("root:"+deposit_folder_name+":rest_cycle_countdown")
		
	if(deposition_status == 0)
		SetWindow ITCPanel, userdata(DepositRecord_DEPOSIT_EXEC)="0"
		Button depositpanel_exec,win=$panel_name,title="Execute",fColor=(0,32768,0)
		rest_cycle_countdown = rest_cycle
	else
		SetWindow ITCPanel, userdata(DepositRecord_DEPOSIT_EXEC)="1"
		Button depositpanel_exec,win=$panel_name,title="STOP",fColor=(32768,0,0)
		rest_cycle_countdown = rest_cycle
	endif
End

Function DepositionPanel_Btn_exec(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			DepositionPanel_update_exec_button(-1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function /T Deposition_getDACWaveList()
	Variable instance=WBPkgGetLatestInstance(ITC_PackageName); AbortOnRTE
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance); AbortOnRTE
	WAVE /T dacdatawavepath=$WBPkgGetName(fPath, WBPkgDFWave, "DACDataWavePath")
	String list=""
	variable i
	for(i=0; i<DimSize(dacdatawavepath,0); i+=1)
		list+=dacdatawavepath[i]+";"
	endfor
	return list
End

Function ITCUSERFUNC_DepositionDataProcFunc(wave adcdata, wave dacdata, int64 total_count, int64 cycle_count, int length, int adc_chnnum, int dac_chnnum, double samplingrate, int flag)

	Variable ret_val=0
	
	DFREF dfr=GetDataFolderDFR()
	
	try
		if(flag ==ITCUSERFUNC_FIRSTCALL)
			if(DepositionPanelPrepareDataFolder(length, samplingrate, adc_chnnum, dac_chnnum)!=0)
				return -1
			endif
			if(DepositionPanelInit(length)!=0)
				return -1
			endif		
		endif
	
		String panel_name=GetUserData("ITCPanel","","DepositionPanel"); AbortOnRTE
		String deposit_folder_name = GetUserData("ITCPanel", "", "DepositRecord_FOLDER"); AbortOnRTE
		String raw_record_name = GetUserData("ITCPanel", "", "DepositRecord_RAW"); AbortOnRTE
		String history_record_name = GetUserData("ITCPanel", "", "DepositRecord_HISTORY"); AbortOnRTE
		String raw_record_file_idx = GetUserData("ITCPanel", "", "DepositRecord_RAWFILEIDX"); AbortOnRTE
		//String data_folder = GetUserData("ITCPanel", "", "DEPOSIT_DATAFOLDER"); AbortOnRTE
		
		Variable save_folder_ready = str2num(GetUserData("ITCPanel","","DepositRecord_SAVE_FOLDER_READY")); AbortOnRTE
		String save_data_folder = GetUserData("ITCPanel", "", "DepositRecord_SAVE_DATA_FOLDER")); AbortOnRTE
		
		PathInfo /S savefolder; AbortOnRTE
		SetDataFolder root:$deposit_folder_name; AbortOnRTE
		
		NVAR tunneling_conductance; AbortOnRTE
		NVAR tunneling_conductance_stdev; AbortOnRTE
		NVAR ionic_conductance; AbortOnRTE
		NVAR ionic_conductance_stdev; AbortOnRTE
		
		NVAR tunneling_scale; AbortOnRTE
		NVAR tunneling_ADC_offset; AbortOnRTE
		NVAR tunneling_DAC0_offset; AbortOnRTE
		NVAR tunneling_DAC1_offset; AbortOnRTE
		NVAR ionic_scale; AbortOnRTE
		NVAR ionic_ADC_offset; AbortOnRTE
		NVAR ionic_DAC0_offset; AbortOnRTE
		NVAR ionic_DAC1_offset; AbortOnRTE
		
		NVAR rest_bias; AbortOnRTE
		NVAR deposit_bias; AbortOnRTE
		NVAR removal_bias; AbortOnRTE
		
		NVAR target_cond; AbortOnRTE
		NVAR target_err_ratio; AbortOnRTE
		
		NVAR total_cycle_time; AbortOnRTE
		NVAR pulse_width; AbortOnRTE
		NVAR pre_pulse_time; AbortOnRTE
		NVAR post_pulse_delay; AbortOnRTE
		NVAR post_pulse_sample_len; AbortOnRTE
		NVAR display_len; AbortOnRTE
		NVAR Kp; AbortOnRTE
		NVAR Ki; AbortOnRTE
		NVAR Kd; AbortOnRTE
		NVAR PID_CV; AbortOnRTE
		NVAR deposit_recording; AbortOnRTE
		
		NVAR tunneling_deltaV; AbortOnRTE
		NVAR ionic_deltaV; AbortOnRTE
		NVAR rest_cycle_number; AbortOnRTE
		NVAR rest_cycle_countdown; AbortOnRTE
		
		NVAR Er_Int; AbortOnRTE
		NVAR Er_Prev; AbortOnRTE
		
		NVAR PID_enabled; AbortOnRTE
		NVAR continuous_exec; AbortOnRTE
		NVAR exec_mode; AbortOnRTE
		NVAR deposition_status; AbortOnRTE
		NVAR deposition_indicator; AbortOnRTE
		
		ControlInfo /W=$(panel_name) depositpanel_depmode
		exec_mode = V_value
		
		ControlInfo /W=$(panel_name) depositpanel_target_variable
		Variable feedbackcontrol=V_value
		
		if(exec_mode == 6) //PID
			PID_enabled = 1
		endif
		
		deposition_status = str2num(GetUserData("ITCPanel", "", "DepositRecord_DEPOSIT_EXEC"))
		if(deposition_status == 0)
			deposition_indicator = 0
		endif
		
		total_cycle_time=length/samplingrate
		
		Variable pulse_sample_start=round(samplingrate*(pre_pulse_time+pulse_width+post_pulse_delay)/1000)
		
		post_pulse_sample_len = length - pulse_sample_start
		if(post_pulse_sample_len<MIN_POST_PULSE_SAMPLELEN)
			post_pulse_sample_len = MIN_POST_PULSE_SAMPLELEN 
			pulse_sample_start = length - post_pulse_sample_len
		endif
			
		if(WinType(panel_name)==7)
			//////////////////////////////////////////////////
			// tunneling setting
			ControlInfo /W=$(panel_name) depositpanel_tunneling_chn
			Variable tunneling_current_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositpanel_tunneling_bias_chn
			Variable tunneling_bias_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositpanel_tunneling_bias_counter_chn
			Variable tunneling_bias_counter_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositpanel_tunneling_bias_subtraction
			Variable tunneling_bias_subtraction=V_Value
			
			
			////////////////////////////////////////////////////
			// ionic setting
			ControlInfo /W=$(panel_name) depositpanel_ionic_chn
			Variable ionic_current_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositpanel_ionic_bias_chn
			Variable ionic_bias_chn = V_Value - 1
			
			ControlInfo /W=$(panel_name) depositpanel_ionic_bias_counter_chn
			Variable ionic_bias_counter_chn = V_Value - 1	
			
			ControlInfo /W=$(panel_name) depositpanel_ionic_bias_subtraction
			Variable ionic_bias_subtraction=V_Value
			
			
			////////////////////////////////
			// historical display setting
			Variable hist_len = display_len / (length/samplingrate)
			
			String hist_view_name = GetUserData("ITCPanel", "", "DepositRecord_HISTORYVIEW")
			Wave hist_view = $hist_view_name
			
			ControlInfo /W=$(panel_name) depositpanel_errorbar
			Variable errorbar_enabled=V_Value
			
			ControlInfo /W=$(panel_name) depositpanel_pulse_method
			Variable pulse_method=V_Value
			
		endif
			
		switch(flag)
		case ITCUSERFUNC_FIRSTCALL: //called when user function is first selected, user can prepare tools/dialogs for the function
			/////////////////////////////
			//User code here
			/////////////////////////////
			DoAlert /T="Experiment must be saved first", 0, "Experiment must be saved before this program can continue. Please make sure to properly save this experiment in a folder with space for additional data storage."
			do
				variable repeat_save=0
				try
					SaveExperiment; AbortOnRTE
					PathInfo /SHOW home
					String deposit_path = S_path
					repeat_save=99
				catch
					Variable save_err = GetRTError(1)
					print "save experiment failed once, will try three times before giving up..."
					print GetErrMessage(save_err)
					repeat_save+=1
					print "retry time: ", repeat_save
				endtry
			while(repeat_save<3)
						
			if(strlen(S_path)>0)
				SetWindow ITCPanel, userdata(DEPOSIT_DATAFOLDER)=deposit_path
				save_data_folder = ParseFilePath(2, deposit_path, ":", 0, 0)
				save_data_folder += deposit_folder_name
				print "Data folder for saving records are created as ", save_data_folder
				NewPath /C/O/Z/Q savefolder, save_data_folder; AbortOnRTE
				SetWindow ITCPanel, userdata(DepositRecord_SAVE_FOLDER_READY)="1"
				SetWindow ITCPanel, userdata(DepositRecord_SAVE_DATA_FOLDER)=save_data_folder
				ret_val=0
			else
				SetWindow ITCPanel, userdata(DepositRecord_SAVE_FOLDER_READY)="0"
				print "Experiment must be saved before using this program"
				ret_val=-1
			endif		
			//if ret_val is set to non-zero, user function will not be set and an error will be generated
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
			print "If actual sampling rate does not match, disable user function, update the wave and restart again."
			DepositionPanelInit(length)
			ret_val=0
			hist_view=NaN
			
			DepositionPanel_update_exec_button(0)
			DepositePanel_GeneratePulse(deposit_folder_name, pulse_method, samplingrate)
			break
		case ITCUSERFUNC_CYCLESYNC: //called at the end of every full cycle of data is recorded in adcdata
			/////////////////////////////
			//User code here
			/////////////////////////////
			
			wave rawwave = $raw_record_name
			wave historywave = $history_record_name
			wave /T rawwaveidx = $raw_record_file_idx
			
			dacdata[][tunneling_bias_chn] -= tunneling_DAC0_offset
			dacdata[][tunneling_bias_counter_chn] -= tunneling_DAC1_offset

			if(tunneling_bias_subtraction!=0)
				adcdata[][tunneling_current_chn] -= dacdata[p][tunneling_bias_chn]
			endif
			adcdata[][tunneling_current_chn] += tunneling_ADC_offset
			adcdata[][tunneling_current_chn] *= tunneling_scale
			
			Make /FREE/D/N=(DimSize(adcdata, 0)) tunneling_cond=adcdata[p][tunneling_current_chn] / (dacdata[p][tunneling_bias_chn]-dacdata[p][tunneling_bias_counter_chn])
			
			dacdata[][ionic_bias_chn] -= ionic_DAC0_offset
			dacdata[][ionic_bias_counter_chn] -= ionic_DAC1_offset
			
			if(ionic_bias_subtraction!=0)
				adcdata[][ionic_current_chn] -= dacdata[p][ionic_bias_chn]
			endif
			adcdata[][ionic_current_chn] -= ionic_ADC_offset
			adcdata[][ionic_current_chn] *= ionic_scale
			
			Make /FREE/D/N=(DimSize(adcdata, 0)) ionic_cond=(adcdata[p][ionic_current_chn]) / (dacdata[p][ionic_bias_chn]-dacdata[p][ionic_bias_counter_chn])
			
			Make /FREE/D/N=(DimSize(adcdata, 0)) pulse_wave = dacdata[p][tunneling_bias_chn] - dacdata[p][ionic_bias_chn] //the difference between tunnling electrodes and the reference should give the pulse information
			
			Make /FREE/D/N=(post_pulse_sample_len,adc_chnnum+dac_chnnum+2) tmp_stat
			
			tmp_stat[][0,adc_chnnum-1] = adcdata[pulse_sample_start+p][q];AbortOnRTE
			rawwave[][0,adc_chnnum-1] = adcdata[p][q];AbortOnRTE
			
			tmp_stat[][adc_chnnum,adc_chnnum+dac_chnnum-1] = dacdata[pulse_sample_start+p][q-adc_chnnum];AbortOnRTE
			rawwave[][adc_chnnum, adc_chnnum+dac_chnnum-1] = dacdata[p][q-adc_chnnum];AbortOnRTE
			
			tmp_stat[][adc_chnnum+dac_chnnum] = tunneling_cond[pulse_sample_start+p];AbortOnRTE
			rawwave[][adc_chnnum+dac_chnnum] = tunneling_cond[p];AbortOnRTE
			
			tmp_stat[][adc_chnnum+dac_chnnum+1] = ionic_cond[pulse_sample_start+p];AbortOnRTE
			rawwave[][adc_chnnum+dac_chnnum+1] = ionic_cond[p];AbortOnRTE
			
			rawwave[][adc_chnnum+dac_chnnum+2] = total_count*length/samplingrate+p/samplingrate; AbortOnRTE
			
			Variable timestamp_ticks = ticks
			
			Variable hist_endidx=str2num(note(historywave))
			Variable fileidx_last=str2num(note(rawwaveidx))
			
			if(numtype(fileidx_last)!=0)
				fileidx_last = 0
			endif
			
			if(numtype(hist_endidx)!=0)
				hist_endidx=0
			endif
			
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
			
			Variable t_cond=historywave[%MEANVALUE][%TUNNELING_COND][hist_endidx]*1e9
			Variable i_cond=historywave[%MEANVALUE][%IONIC_COND][hist_endidx]*1e9
			Variable src_cond
			
			if(feedbackcontrol==1)
				src_cond=t_cond
			else
				src_cond=i_cond
			endif
						
			tunneling_conductance = t_cond
			tunneling_conductance_stdev=historywave[%SDEV][%TUNNELING_COND][hist_endidx]*1e9
			ionic_conductance = i_cond
			ionic_conductance_stdev=historywave[%SDEV][%IONIC_COND][hist_endidx]*1e9
			
			WaveStats /Q pulse_wave
			
			historywave[%PULSE_HIGH][][hist_endidx]=V_max;AbortOnRTE
			historywave[%PULSE_LOW][][hist_endidx]=V_min;AbortOnRTE
			
			if(V_max-V_avg > V_avg-V_min)
				historywave[%PULSE_HEIGHT][][hist_endidx] = V_max-V_min
			else
				historywave[%PULSE_HEIGHT][][hist_endidx] = V_min-V_max
			endif
			
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
			
			note /k historywave, num2str(hist_endidx)
			//check if need to save data
			if(save_folder_ready ==1 && deposit_recording == 1)
				
				String tmpstr=""
				sprintf tmpstr, "raw_%08d_%08d", hist_endidx, cycle_count
				
				Duplicate /O rawwave, $tmpstr
				
				NewPath /C/O/Q savefolder, save_data_folder
				
				SaveData /D=1/L=1/O/Q/P=savefolder/J=tmpstr ":"
				KillWaves /Z $tmpstr
				rawwaveidx[fileidx_last] = tmpstr
				fileidx_last += 1
				note /k rawwaveidx, num2istr(fileidx_last)
			endif
			
			if(cycle_count==0 || PID_enabled==0)
				Er_Int=0
				Er_Prev=src_cond
			else
				if(rest_cycle_countdown <= 0)
					Variable er = abs(src_cond) - abs(target_cond)
					Er_Int+=er
					Variable diff_er=er-Er_Prev
					Er_Prev=er
					PID_CV = Kp*er + Ki*Er_Int + Kd*diff_er
				endif
			endif
			
			if(deposition_status)
				if(rest_cycle_countdown >= rest_cycle_number)
					if(deposition_indicator==0)
						deposition_indicator=DepositPanel_SendPulse(deposit_folder_name, exec_mode, target_cond, target_err_ratio, src_cond, tunneling_bias_chn, tunneling_bias_counter_chn, ionic_bias_chn, ionic_bias_counter_chn, PID_CV)
					endif
					rest_cycle_countdown -= 1				
				else
					if(deposition_indicator!=0)
						deposition_indicator=DepositPanel_SendPulse(deposit_folder_name, -1, target_cond, target_err_ratio, src_cond, tunneling_bias_chn, tunneling_bias_counter_chn, ionic_bias_chn, ionic_bias_counter_chn, PID_CV)
					endif
					rest_cycle_countdown -= 1
					if(rest_cycle_countdown <0)
						rest_cycle_countdown = rest_cycle_number						
						rest_cycle_countdown=rest_cycle_number
						
						if(continuous_exec)
							DepositionPanel_update_exec_button(1)
						else
							DepositionPanel_update_exec_button(0)
						endif					
					endif
				endif				
			endif
			
			ret_val=0 //if need to stop recording by the user function, return a non-zero value
			break
		case ITCUSERFUNC_STOP: //called when the user requested to stop the recording
			/////////////////////////////
			//User code here
			/////////////////////////////
			DepositionPanel_update_exec_button(0)
			break //ret_val is not checked for this call
		
		case ITCUSERFUNC_DISABLE: //called when the user unchecked the USER_FUNC
			
			SetWindow ITCPanel, userdata(DepositRecord_SAVE_FOLDER_READY)="0"
			DepositionPanel_update_exec_button(0)
			
			DepositionPanelExit()
			break
		case ITCUSERFUNC_CUSTOMDISPLAY: //called by GUI controller where user can use the ITCPanel#rtgraph to display customized content
			AppendToGraph /W=ITCPanel#rtgraph /L=left1 /B hist_view[%MEANVALUE][%TUNNELING_COND][0,hist_len-1] //vs hist_view[%TIMESTAMP][%TUNNELING_COND][]
			ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos(left1)=0,lblPos(left1)=60,notation(left1)=0,ZisZ(left1)=1,fsize=12; AbortOnRTE
			ModifyGraph /W=ITCPanel#rtgraph freePos(left1)=0,lblPos(bottom)=40,notation(bottom)=0,fsize=12,ZisZ=1; AbortOnRTE
			
			AppendToGraph /W=ITCPanel#rtgraph /L=left2 /B hist_view[%MEANVALUE][%IONIC_COND][0,hist_len-1] //vs hist_view[%TIMESTAMP][%IONIC_COND][]
			ModifyGraph /W=ITCPanel#rtgraph grid=2,tick=2,axThick=2,standoff=0,freePos(left2)=0,lblPos(left2)=60,notation(left2)=0,ZisZ(left2)=1,fsize=12; AbortOnRTE
			ModifyGraph /W=ITCPanel#rtgraph freePos(left2)=0,lblPos(bottom)=40,notation(bottom)=0,fsize=12,ZisZ=1; AbortOnRTE
			ModifyGraph /W=ITCPanel#rtgraph lblPos(left1)=80, lblPos(left2)=80, nticks(left1)=2, nticks(left2)=2
			
			AppendToGraph /W=ITCPanel#rtgraph /R=right1 hist_view[%PULSE_HEIGHT][%TUNNELING_COND][0,hist_len-1]
			
			ModifyGraph /W=ITCPanel#rtgraph axThick=2,standoff=0,freePos(right1)=0;DelayUpdate
			
			ModifyGraph /W=ITCPanel#rtgraph lsize($(NameOfWave(hist_view)+"#2"))=3,rgb($(NameOfWave(hist_view)+"#2"))=(49163,65535,32768,19661)
			
			if(errorbar_enabled)
				ErrorBars /W=ITCPanel#rtgraph $(NameOfWave(hist_view)) SHADE= {0,0,(0,0,0,0),(0,0,0,0)},wave=(hist_view[%SDEV][%TUNNELING_COND][0,hist_len-1],hist_view[%SDEV][%TUNNELING_COND][0,hist_len-1])
				ErrorBars /W=ITCPanel#rtgraph $(NameOfWave(hist_view)+"#1") SHADE= {0,0,(0,0,0,0),(0,0,0,0)},wave=(hist_view[%SDEV][%IONIC_COND][0,hist_len-1],hist_view[%SDEV][%IONIC_COND][0,hist_len-1])
			else
				ErrorBars /W=ITCPanel#rtgraph $(NameOfWave(hist_view)) OFF
				ErrorBars /W=ITCPanel#rtgraph $(NameOfWave(hist_view)+"#1") OFF
			endif
			
			SetAxis /W=ITCPanel#rtgraph /A=2/N=2 left1
			SetAxis /W=ITCPanel#rtgraph /A=2/N=2 left2
			SetAxis /W=ITCPanel#rtgraph right1 -2,2

			ModifyGraph /W=ITCPanel#rtgraph axisEnab(left1)={0.52,1}
			ModifyGraph /W=ITCPanel#rtgraph axisEnab(left2)={0,0.48}
			
			ModifyGraph /W=ITCPanel#rtgraph rgb($(NameOfWave(hist_view)+"#1"))=(0,0,65535)
			
			Label /W=ITCPanel#rtgraph left1 "G_tunneling\n/\U S"
			Label /W=ITCPanel#rtgraph left2 "G_ionic\n/\U S"
			Label /W=ITCPanel#rtgraph bottom "relative time / \\U"
			Label /W=ITCPanel#rtgraph right1 "pulse height / V"
			
			ModifyGraph /W=ITCPanel#rtgraph margin(left)=80; AbortOnRTE
			ModifyGraph /W=ITCPanel#rtgraph margin(right)=80; AbortOnRTE
			
			//ret_val is not checked for this call
			break
		default:
			ret_val=-1 //this should not happen
			break
		endswitch
	catch
		Variable err = GetRTError(1)		// Gets error code and clears error
		String errMessage = GetErrMessage(err)
		Printf "deposit function encountered the following error: %s\r", errMessage
		DepositionPanel_update_exec_button(0)
		ret_val=-1
	endtry
	SetDataFolder dfr
	return ret_val
End

Function DepositPanel_SendPulse(String deposit_folder_name, Variable deposition_mode, Variable target_cond, Variable target_err_ratio, Variable src_cond, Variable tunneling_bias_chn, Variable tunneling_bias_counter_chn, Variable ionic_bias_chn, Variable ionic_bias_counter_chn, Variable PID_CV)	
	try
		String wlist=Deposition_GetDACWaveList()
		
		Wave tdacw0_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_DEPOSIT")
		Wave tdacw1_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_DEPOSIT")
		Wave idacw0_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_DEPOSIT")
		Wave idacw1_dp=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_DEPOSIT")
		
		Wave tdacw0_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_REMOVAL")
		Wave tdacw1_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_REMOVAL")
		Wave idacw0_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_REMOVAL")
		Wave idacw1_rm=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_REMOVAL")
		
		
		Wave tdacw0_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC0_REST")
		Wave tdacw1_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_TDAC1_REST")
		Wave idacw0_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC0_REST")
		Wave idacw1_rest=$("root:"+deposit_folder_name+":PULSE_WAVE_IDAC1_REST")
		
		Wave tdacw0 = $StringFromList(tunneling_bias_chn, wlist); AbortOnRTE
		Wave tdacw1 = $StringFromList(tunneling_bias_counter_chn, wlist); AbortOnRTE
		Wave idacw0 = $StringFromList(ionic_bias_chn, wlist); AbortOnRTE
		Wave idacw1 = $StringFromList(ionic_bias_counter_chn, wlist); AbortOnRTE
		
		Variable deltaC = abs(abs(src_cond) - abs(target_cond))
		
		Variable retVal = 0
		
		switch(deposition_mode)
		case 1: //rest
			duplicate /O tdacw0_rest, tdacw0; AbortOnRTE
			duplicate /O tdacw1_rest, tdacw1; AbortOnRTE
			duplicate /O idacw0_rest, idacw0; AbortOnRTE
			duplicate /O idacw1_rest, idacw1; AbortOnRTE
			break
		case 2: //close			
			if((abs(src_cond) < abs(target_cond))  && (deltaC > abs(target_cond)*target_err_ratio/100))
				//print "will close"
				duplicate /O tdacw0_dp, tdacw0; AbortOnRTE
				duplicate /O tdacw1_dp, tdacw1; AbortOnRTE
				duplicate /O idacw0_dp, idacw0; AbortOnRTE
				duplicate /O idacw1_dp, idacw1; AbortOnRTE
				retVal = -1
			endif
			
			break
		case 3: //open	
			if(abs(src_cond) > abs(target_cond)  && deltaC > abs(target_cond)*target_err_ratio/100)
				//print "will open"
				duplicate /O tdacw0_rm, tdacw0; AbortOnRTE
				duplicate /O tdacw1_rm, tdacw1; AbortOnRTE
				duplicate /O idacw0_rm, idacw0; AbortOnRTE
				duplicate /O idacw1_rm, idacw1; AbortOnRTE
				retVal = 1
			endif
			
			break
		case 4: //forced close
			duplicate /O tdacw0_dp, tdacw0; AbortOnRTE
			duplicate /O tdacw1_dp, tdacw1; AbortOnRTE
			duplicate /O idacw0_dp, idacw0; AbortOnRTE
			duplicate /O idacw1_dp, idacw1; AbortOnRTE
			retVal = -1
			break
		case 5: //forced open
			duplicate /O tdacw0_rm, tdacw0; AbortOnRTE
			duplicate /O tdacw1_rm, tdacw1; AbortOnRTE
			duplicate /O idacw0_rm, idacw0; AbortOnRTE
			duplicate /O idacw1_rm, idacw1; AbortOnRTE
			retVal = 1
			break
		case 6: //PID
			if(PID_CV>0)
				if(deltaC > abs(target_cond)*target_err_ratio/100)
					retVal = 1
				endif
			elseif(PID_CV<0)
				if(deltaC > abs(target_cond)*target_err_ratio/100)
					retVal = -1
				endif
			endif
			
			if(retVal>0)
				duplicate /O tdacw0_rm, tdacw0; AbortOnRTE
				duplicate /O tdacw1_rm, tdacw1; AbortOnRTE
				duplicate /O idacw0_rm, idacw0; AbortOnRTE
				duplicate /O idacw1_rm, idacw1; AbortOnRTE
			elseif(retVal<0)
				duplicate /O tdacw0_dp, tdacw0; AbortOnRTE
				duplicate /O tdacw1_dp, tdacw1; AbortOnRTE
				duplicate /O idacw0_dp, idacw0; AbortOnRTE
				duplicate /O idacw1_dp, idacw1; AbortOnRTE
			else
				duplicate /O tdacw0_rest, tdacw0; AbortOnRTE
				duplicate /O tdacw1_rest, tdacw1; AbortOnRTE
				duplicate /O idacw0_rest, idacw0; AbortOnRTE
				duplicate /O idacw1_rest, idacw1; AbortOnRTE
			endif
				
			break
		default: //send rest potential only
			duplicate /O tdacw0_rest, tdacw0; AbortOnRTE
			duplicate /O tdacw1_rest, tdacw1; AbortOnRTE
			duplicate /O idacw0_rest, idacw0; AbortOnRTE
			duplicate /O idacw1_rest, idacw1; AbortOnRTE
			break
		endswitch
	catch
		Variable err = GetRTError(1)
		print "Error captured during sending pulse:", err
		print GetErrMessage(err)
	endtry
	
	return retVal
End

Function DepositPanel_PID_CV(variable PID_CV, variable target, variable cond, variable stdev)
	
End

Function /T DP_get_deposition_folder()
	String dfdir=StringByKey("FOLDERS", DataFolderDir(1), ":", ";")
	variable i
	String liststr=""
	for(i=0; i<ItemsInList(dfdir, ","); i+=1)
		String fdstr=stringfromList(i, dfdir, ",")
		if(stringmatch(fdstr, "DepositRecord*")==1)
			liststr+=fdstr+";"
		endif
	endfor
	return liststr
End

Function /T DP_get_dimlabels(string folder, string wname, variable dimsel)
	DFREF dfr=GetDataFolderDFR()
	String liststr=""
	try
		SetDataFolder $("root:"+folder)
		WAVE w=$wname
		if(WaveExists(w))
			variable i
			for(i=0; i<DimSize(w, dimsel); i+=1)
				liststr+=GetDimLabel(w, dimsel, i)+";"
			endfor
		endif
	catch
	endtry
	
	SetDataFolder dfr
	return liststr
End

Function DP_inspect_data_panel_init()
	Display /N=DPInspection /K=1
	String panel_name = S_name
	NewPanel /HOST=$panel_name /EXT=2 /k=2 /W=(0,0,600,200)
	
	
	PopupMenu DP_folder,title="DepositionFolder",value=DP_get_deposition_folder()
	PopupMenu DP_folder,pos={10,10},size={250,20},bodywidth=150
	String s=StringFromList(0, DP_get_deposition_folder(), ";")
	String sl="\""+DP_get_dimlabels(s, s+"_history", 1)+"\""
	PopupMenu DP_trace,title="Signal",value=#sl
	PopupMenu DP_trace,pos={10,30},size={250,20},bodywidth=150
	Checkbox DP_errorbar,title="Show error bar",pos={10,50},size={250,20}
	Button DF_update_hist_trace,title="update trace",pos={10,70},size={250,20},proc=DP_btn_update_trace

End


Function DP_btn_update_trace(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String panelname=ba.win
	String dispname=StringFromList(0, panelname, "#")
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			HideInfo /W=$dispname
			string trlist = TraceNameList(dispname, ";", 1)
			variable i
			i=ItemsInList(trlist, ";")
			do
				if(i>0)
					RemoveFromGraph /W=$dispname $(StringFromList(i-1, trlist))
				endif
				trlist = TraceNameList(dispname, ";", 1)
				i=ItemsInList(trlist, ";")				
			while(i>0)
			
			ControlInfo /W=$panelname DP_folder
			String foldername = S_Value
			Wave w = $("root:"+foldername+":"+foldername+"_history")
			
			ControlInfo /W=$panelname DP_trace
			String signal=S_Value
			Variable idx = FindDimLabel(w, 1, signal)
			
			ControlInfo /W=$panelname DP_errorbar
			Variable errbar=V_value
			
			AppendToGraph /W=$dispname w[%MEANVALUE][idx][] vs w[%TIMESTAMP][idx][]
			ModifyGraph /W=$dispname mode=3
			trlist = StringFromList(0, TraceNameList(dispname, ";", 1), ";")
			if(errbar)
				ErrorBars /W=$dispname $trlist SHADE={0,0,(0,0,0,0),(0,0,0,0)},wave=(w[%SDEV][idx][*],w[%SDEV][idx][*])
			endif
			ShowInfo /W=$dispname
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
