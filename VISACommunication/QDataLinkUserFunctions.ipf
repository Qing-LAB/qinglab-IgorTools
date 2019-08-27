#pragma IndependentModule= QDataLinkCore
#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//////////////////////////////////////////////////////////////////////////////
//Please use the following as a template to define user functions
//////////////////////////////////////////////////////////////////////////////

//DO NOT MODIFY OR DELETE
ThreadSafe Function qdl_example_rtfunc(Variable inittest, [Variable slot, STRUCT QDLConnectionParam & cp, WAVE request, WAVE status, WAVE /T inbox, WAVE /T outbox, WAVE /T param, WAVE /T auxret])
	Variable dfr_flag=0
	String msg=""
	if(inittest==1) //initial call just to verify that the function exists
		return 0x01 //return some non-zero magic values so that you know it is the correct one that returned.
	endif
	
	//all optional parameters will be properly defined, by design, from the caller in the worker thread
	try
		if(request[slot] & QDL_REQUEST_WRITE_COMPLETE) //when writing is complete
			////////////////////
			//DO SOMETHING HERE
			////////////////////
			request[slot]=request[slot] & (~QDL_REQUEST_WRITE_COMPLETE)
		endif
		
		if(request[slot] & QDL_REQUEST_READ_COMPLETE) //when reading is complete
			////////////////////
			//DO SOMETHING HERE
			////////////////////
			dfr_flag=1 // typically you will send out a packet of data to background task through a datafolder reference
		else
			dfr_flag=0
		endif
		
		if(dfr_flag==1)
			NewDataFolder :dfr; AbortOnRTE
			Variable /G :dfr:instance; AbortOnRTE //this variable should always be in the folder
			Variable /G :dfr:slot; AbortOnRTE	//this variable should always be in the folder
			//////////////////////
			//DO SOMETHING ELSE TO FILL THE FOLDER WITH DATA/INFORMATION
			//////////////////////
			
			ThreadGroupPutDF 0, :dfr; AbortOnRTE
			
			//////////////////////
			//DO SOMETHING ELSE: typically including clear out request status and in/outbox and parameters etc.
			//////////////////////
		endif
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "_qdl_example_rtfunc encountered an error for slot "+num2istr(slot)+": "+GetErrMessage(err)
		endif
	endtry
	return 0
End

//////////////////////////////////////////////////////////////////////////////
//Please use the following as a template to define user functions
//////////////////////////////////////////////////////////////////////////////

//DO NOT MODIFY OR DELETE
Function qdl_example_postprocess_bgfunc(Variable instance_in, Variable slot_in, Variable dfr_received, DFREF dfr, String instanceDir)
	DFREF olddfr=GetDataFolderDFR(); AbortOnRTE
	try
		String PkgPath=WBSetupPackageDir(QDLPackageName); AbortOnRTE
		WAVE /T outbox=$WBPkgGetName(PkgPath, WBPkgDFWave, "outbox_all"); AbortOnRTE
		WAVE /T inbox=$WBPkgGetName(PkgPath, WBPkgDFWave, "inbox_all"); AbortOnRTE
		WAVE /T param=$WBPkgGetName(PkgPath, WBPkgDFWave, "auxparam_all"); AbortOnRTE
		WAVE request=$WBPkgGetName(PkgPath, WBPkgDFWave, "request_record"); AbortOnRTE // in case you need to access there data (with caution)
		
		if(dfr_received==0) //no datafolder ref has been received yet, only for maintanance check etc.
			//DO SOMETHING
		elseif(DataFolderRefStatus(dfr)==3) //DFR received, BUT !!!Do not delete data folder as it will be handled at higher level!!!
			String privateDF=WBPkgGetName(instanceDir, WBPkgDFDF, "YOUR_PRIVATE_FOLDER_FOR_STORING_INFO"); AbortOnRTE
			DFREF privateDFR=$privateDF
			if(DataFolderRefStatus(privateDFR)!=1) //first call, need to prepare the private data folder
				WBPrepPackagePrivateDF(instanceDir, "YOUR_PRIVATE_FOLDER_FOR_STORING_INFO", nosubdir=1); AbortOnRTE
				privateDF=WBPkgGetName(instanceDir, WBPkgDFDF, "YOUR_PRIVATE_FOLDER_FOR_STORING_INFO"); AbortOnRTE
				
				SetDataFolder $privateDF; AbortOnRTE
				//Prepare your private datafolder for storing information/data
			else
				SetDataFolder $privateDF
			endif
			
		endif
		//////////////////////
		//DO SOMETHING USING THE DFR 
		//////////////////////
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "EMController_postprocess_bgfunc encountered an error for slot "+num2istr(slot_in)+": "+GetErrMessage(err)
		endif
	endtry
	
	SetDataFolder olddfr
	
	return 0
End

