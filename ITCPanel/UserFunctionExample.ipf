#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "itcpanel"

//constant len=0.2  //sample length in s
constant Threshpct = 0.5  //impedance threshold as a fraction of baseline
constant DACscale = 1  //scales DAC source wave
constant hist_time_len=500 // sec

Function WirePanel()
	KillWindow /Z ITCPanel#WirePanel

	NewPanel /EXT=1 /HOST=ITCPanel /W=(160,0,0,250) /N=WirePanel
	Button btn_safe_disconnect win=ITCPanel#WirePanel, title="Safe Disconnect Done", size={155, 20}, proc=wirepanel_btnproc, disable=2
	Button btn_safe_disconnect win=ITCPanel#WirePanel, disable=0
	Button btn_continue_recording win=ITCPanel#WirePanel, title="Reconnect Device Done", size={155, 20}, proc=wirepanel_btnproc, disable=2
	Button btn_continue_recording win=ITCPanel#WirePanel, disable=2
	SetVariable sv_datafolder win=ITCPanel#WirePanel, title="Save to Folder", value=_STR:"test1", size={155,20}
	SetVariable sv_sethighV win=ITCPanel#WirePanel, title="Set V_high (V)", value=_NUM:0, size={155,20}
	SetVariable sv_setlowV win=ITCPanel#WirePanel, title="Set V_low (V)", value=_NUM:0, size={155,20}
	SetVariable sv_setpulsewidth win=ITCPanel#WirePanel, title="Set pulse width (ms)", value=_NUM:0, size={155,20}
	Button btn_manual_set_trace win=ITCPanel#WirePanel, title="Update output trace", size={155,20}
End

Function wirepanel_btnproc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			NVAR /Z rflag=root:relayflag
			strswitch(ba.ctrlName)
			case "btn_safe_disconnect":
				Button btn_safe_disconnect win=ITCPanel#WirePanel, disable=2
				Button btn_continue_recording win=ITCPanel#WirePanel, disable=0
				rflag=1; AbortOnRTE				
				break
			case "btn_continue_recording":
				Button btn_safe_disconnect win=ITCPanel#WirePanel, disable=2
				Button btn_continue_recording win=ITCPanel#WirePanel, disable=2
				rflag=2; AbortOnRTE
				break
			case "btn_manual_set_trace":
			
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


Function MyDataProcFunc(wave adcdata, int64 total_count, int64 cycle_count, int flag)
//this function assumes that: 
// (1) at least three channels of ADCs are selected, with the first one ADC0 getting the raw amplitude from lock-in, ADC1 the raw phase from lock-in, and ADC2 the output from DAC
// (2) the output of DAC uses root:scaledac as the wave for generating the signal
	Variable ret_val=0
	Variable intervaltime, freq, section_length, channelnum
	
	intervaltime=deltax(adcdata) //this value is only valid when flag==ITCUSERFUNC_CYCLESYNC
	freq=1/intervaltime //this value is only valid when flag==ITCUSERFUNC_CYCLESYNC
	section_length=DimSize(adcdata, 0)
	channelnum=DimSize(adcdata, 1)
	
	switch(flag)
	case ITCUSERFUNC_FIRSTCALL: //called when user function is first selected, user can prepare tools/dialogs for the function
		/////////////////////////////
		//User code here
		/////////////////////////////
		Variable adc_chn_num=str2num(GetUserData("ITCPanel", "itc_grp_ADC", "selected"))
		Variable dac_chn_num=str2num(GetUserData("ITCPanel", "itc_grp_DAC", "selected"))
		if(adc_chn_num>=3 && dac_chn_num>=1)
			NVAR /Z relay_flag=root:relayflag
			if(NVAR_Exists(relay_flag))
				Variable /G root:relayflag=0
			endif
			WirePanel()
			ret_val=0 //if ret_val is set to non-zero, user function will not be set and an error will be generated
		else
			DoAlert 0, "Minimal of three ADC channels and one DAC channel is needed."
			ret_val=-1
		endif
		break
	case ITCUSERFUNC_IDLE://called when background cycle is idel (not continuously recording)
		/////////////////////////////
		/////////////////////////////
		break // ret_val is not checked in idle call
	case ITCUSERFUNC_START_BEFOREINIT: //called after user clicked "start recording", before initializing the card
		/////////////////////////////
		NVAR relay_flag=root:relayflag //waiting for the user to manually change the connections before switching digital controls, and then set relay flag to 1 for continuing
		if(relay_flag==1)
			ret_val=0
		else
			ret_val=1
		endif
		/////////////////////////////
		//set ret_val to non-zero to hold initialization of the card, otherwise, set to zero
		break
	case ITCUSERFUNC_START_AFTERINIT: //called after user clicked "start recording", and after initializing the card
		/////////////////////////////
		NVAR relay_flag=root:relayflag //LIH board is initialized, manually reconnect, and set digital output properly, and then manually set relay flag to 2
		if(relay_flag==2)
			ret_val=0
		else
			ret_val=2
		endif
		/////////////////////////////
		break
	case ITCUSERFUNC_CYCLESYNC: //called at the end of every full cycle of data is recorded in adcdata
		/////////////////////////////
		try
			Variable history_len=round(hist_time_len/(section_length*intervaltime))
			String testfolder=""
			ControlInfo /W=ITCPanel#WirePanel sv_datafolder
			testfolder=S_value
		
			if(!exists("root:"+testfolder+":BaselineV"))
				Variable /G $("root:"+testfolder+":BaselineV")=0
				Variable /G $("root:"+testfolder+":ThresholdV")=0
				Variable /G $("root:"+testfolder+":index")=0
				Variable /G $("root:"+testfolder+":hist_idx")=0
			endif
			NVAR BaselineV=$("root:"+testfolder+":BaselineV")
			NVAR ThresholdV=$("root:"+testfolder+":ThresholdV")
			NVAR idx=$("root:"+testfolder+":index")
			NVAR hist_idx=$("root:"+testfolder+":hist_idx")		
			
			WAVE dacref=root:testdac  //defines shape of voltage pulse for DAC output
			WAVE dacw=root:scaleddac  //actual DAC output
		
			if(cycle_count==0)
				make /O/N=(history_len*section_length) $("root:"+testfolder+":ADC0track"); AbortOnRTE
				make /O/N=(history_len*section_length) $("root:"+testfolder+":ADC1track"); AbortOnRTE
				make /O/N=(history_len*section_length) $("root:"+testfolder+":DACtrack"); AbortOnRTE
				make /O/N=(history_len) $("root:"+testfolder+":ADCCompactHist"); AbortOnRTE
				SetScale/P x 0,intervaltime,"s", $("root:"+testfolder+":ADC0track"), $("root:"+testfolder+":ADC1track"), $("root:"+testfolder+":DACtrack"); AbortOnRTE
				SetScale/P x 0,(section_length*intervaltime),"s", $("root:"+testfolder+":ADCCompactHist"); AbortOnRTE
				hist_idx=0
				BaselineV=0
				ThresholdV=0
				idx=0
			endif
		
			WAVE ADC0track=$("root:"+testfolder+":ADC0track")
			WAVE ADC1track=$("root:"+testfolder+":ADC1track")
			WAVE DACtrack=$("root:"+testfolder+":DACtrack")
			WAVE ADCCompact=$("root:"+testfolder+":ADCCompactHist")
			
			if(hist_idx>=DimSize(ADCCompact, 0))
				InsertPoints /M=0 DimSize(ADCCompact, 0), history_len, ADCCompact; AbortOnRTE
			endif

			variable startx, endx
			startx=idx*section_length
			endx=startx+section_length-1
			
			multithread ADC0track[startx,endx]=adcdata[p-startx][0]
			multithread ADC1track[startx,endx]=adcdata[p-startx][1]
			multithread DACtrack[startx,endx]=adcdata[p-startx][2]
			WaveStats /Q/Z ADC0track
			ADCCompact[hist_idx]=V_avg
			//////////////////////////////////////////////////////////
			//Here should be the logic of how to set the thredshold, or how to modify the dac output based on historical data etc.
			//only the recent history_length sec of data is kept. however, the start and end time need to be noted with caution as the data
			//would overwrite previous ones
			
			/////////////////////////////////////////////////////////
			hist_idx+=1
			idx+=1
			if(idx>history_len)
				idx=0 //will overwrite previous data
			endif
			
			//print commands keep track of variable values to ensure proper functioning during testing
		catch
			variable err=GetRTError(1)
			String message = GetErrMessage(err)
			print cycle_count
			print hist_idx
			print idx
			print dimsize(adcdata, 0)
			print dimsize(adcdata, 1)
			print err
			print message
		
			ret_val=-1
		endtry
		/////////////////////////////
		ret_val=0 //if need to stop recording by the user function, return a non-zero value
		break
	case ITCUSERFUNC_STOP: //called when the user requested to stop the recording
		/////////////////////////////
		//User code here
		/////////////////////////////
		Button btn_safe_disconnect win=ITCPanel#WirePanel, disable=0
		Button btn_continue_recording win=ITCPanel#WirePanel, disable=2
		break //ret_val is not checked for this call
	default:
		ret_val=-1 //this should not happen
		break
	endswitch
	
	return ret_val
End

