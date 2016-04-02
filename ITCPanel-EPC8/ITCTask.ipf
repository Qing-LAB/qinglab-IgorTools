#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IndependentModule=ITCTask
#include "WaveBrowser"
#include "itcpanel_common"

#if exists("LIH_InitInterface")==3
#if defined(DEBUGONLY)
#define LIHDEBUG
#else		
#undef LIHDEBUG
#endif
#else
#define LIHDEBUG
#endif

Function ITCBackgroundTask(s)
	STRUCT WMBackgroundStruct &s
	Variable tRefNum, tMicroSec
	
	tRefNum=StartMSTimer
	Variable instance=WBPkgDefaultInstance
	String fPath=WBSetupPackageDir(ITC_PackageName, instance=instance)
	
	NVAR itcmodel=$WBPkgGetName(fPath, WBPkgDFVar, "ITCMODEL")
	SVAR Operator=$WBPkgGetName(fPath, WBPkgDFStr, "OperatorName")
	SVAR ExperimentTitle=$WBPkgGetName(fPath, WBPkgDFStr, "ExperimentTitle")
	SVAR DebugStr=$WBPkgGetName(fPath, WBPkgDFStr, "DebugStr")
	
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
			success=LIH_InitInterface(errMsg, itcmodel)
#endif
			if(success!=0)
				sprintf tmpstr, "Initialization of the ITC failed with message: %s", errMsg
				itc_updatenb(tmpstr, r=32768, g=0, b=0)
				AbortOnValue 1, 999
			else
				itc_updatenb("ITC initialized for starting acquisition.")
			endif
			
			if(itc_update_taskinfo()==0)
				//checking passed, waves and variables have been prepared etc.
				if(RecordingSize<=0)
					itc_updatenb("Error in RecordingSize ["+num2istr(RecordingSize)+"]", r=32768, g=0, b=0)
					AbortOnValue 1, 900
				endif
				if(BlockSize<0 || BlockSize>ITCMaxBlockSize || BlockSize>RecordingSize)
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
					itc_reload_dac_from_src(countDAC, dacdatawavepath, dacdata) //refresh dac data when the next cycle starts.
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
			ITCResetDACs()
			itc_updatenb("ITC stopped.")
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
		ITCResetDACs()
		LastIdleTicks=s.curRunTicks
		Status=0
	endtry
	tMicroSec=stopMSTimer(tRefNum)
	return 0
End
