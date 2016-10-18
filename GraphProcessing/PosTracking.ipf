#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "WaveBrowser"

StrConstant PosTracking_VARS="MAX_INSTANCE"

Function InitPosTracking()
	Variable instance0=0
	String fPath0=WBSetupPackageDir("PosTracking")
	fPath0=WBSetupPackageDir("PosTracking", instance=instance0)
	
	NVAR max_instance=$WBPkgGetName(fPath0, WBPkgDFVar, "MAX_INSTANCE", quiet=1)
	if(!NVAR_Exists(max_instance))
		WBPrepPackageVars(fPath0, PosTracking_VARS)
	endif

End