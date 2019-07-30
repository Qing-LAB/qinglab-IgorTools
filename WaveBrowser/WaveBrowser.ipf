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
#include <WaveSelectorWidget>
#include <PopupWaveSelector>

Constant WB_FOLDER_MUST_EXIST=0x01
Constant WB_WAVE_MUST_EXIST=0x02

Function WaveBrowser(panel_name, panel_title, positionx, positiony, title_folder, title_wave, options, initialfolder, initialname, callback_spec, [showWhat, nameFilter])
	String panel_name, panel_title
	Variable positionx, positiony
	String title_folder, title_wave
	Variable options // bit 0: disable edit folder, bit 1: disable edit wave
	String initialfolder, initialname
	String callback_spec
	String showWhat
	String nameFilter
	 
	 Variable content=WMWS_Waves
	 
	 if(WinType(panel_name)==7)
	 	KillWindow $panel_name
	 endif
	 
	 if(ParamIsDefault(nameFilter))
	 	nameFilter=""
	 endif
	 if(ParamIsDefault(showWhat))
	 	showWhat="WAVES"
	 endif
	 showWhat=UpperStr(showWhat)
	 strswitch(showWhat)
	 	case "WAVE":
	 	case "WAVES":
	 		break
	 	case "VARS":
	 	case "VAR":
	 	case "VARIABLE":
	 	case "VARIABLES":
	 		content=WMWS_NVars
	 		break
	 	case "STR":
	 	case "STRING":
	 	case "STRINGS":
	 		content=WMWS_Strings
	 		break
	 	case "DF":
	 	case "DATAFOLDER":
	 	case "DATAFOLDERS":
	 		content=WMWS_DataFolders
	 		break
	 endswitch
	 
	NewPanel /K=1 /N=$panel_name /W=(positionx, positiony, positionx+350, positiony+300) as panel_title
	SetVariable sv_folder win=$panel_name, title=title_folder,size={300,20},pos={20, 20},value=_STR:initialfolder,userdata(options)="0"
	if((options & WB_FOLDER_MUST_EXIST)!=0)
		SetVariable sv_folder,noedit=1,userdata(options)="1"
	endif
	SetVariable sv_wave win=$panel_name, title=title_wave,size={300,20},pos={20, 40},value=_STR:initialname,userdata(options)="0"
	if((options & WB_WAVE_MUST_EXIST)!=0)
		SetVariable sv_wave,noedit=1,userdata(options)="1"
	endif
	ListBox list_browser win=$panel_name,pos={20,60},size={300,200}
	MakeListIntoWaveSelector(panel_name, "list_browser", content=content, selectionMode=WMWS_SelectionSingle, nameFilterProc=nameFilter)
	PopupMenu WBrowser_sortKind, pos={220,270},title="Sort Waves By"
	MakePopupIntoWaveSelectorSort(panel_name, "list_browser", "WBrowser_sortKind")
	WS_SetNotificationProc(panel_name, "list_browser", "WBrowser_notification", isExtendedProc=1)

	Button btn_confirm win=$panel_name, title="Confirm",size={135,20}, pos={20,270},proc=WBrowser_btn_confirm
	SetWindow $panel_name,userdata(callback_spec)=callback_spec
	SetWindow $panel_name,userdata(confirmed)="0"
	SetWindow $panel_name,hook(onExit)=WBrowser_hook_onExit
End

Function  WBrowser_CallbackPrototype(stra, strb, strc)
	String stra, strb, strc
End

Function WBrowser_notification(SelectedItem, EventCode, OwningWindowName, ListboxControlName)
	String SelectedItem			// string with full path to the item clicked on in the wave selector
	Variable EventCode			// the ListBox event code that triggered this notification
	String OwningWindowName	// String containing the name of the window containing the listbox
	String ListboxControlName	// String containing the name of the listbox control
	
	Variable folder_options=str2num(GetUserData(OwningWindowName, "sv_folder", "options"))
	Variable wave_options=str2num(GetUserData(OwningWindowName, "sv_wave", "options"))
	if(EventCode==4)
		DFREF dfr=$SelectedItem
		if(DataFolderRefStatus(dfr)==1)
			if(wave_options==1)
				// do nothing if an existing wave has to be selected
			else
				if(cmpstr(SelectedItem[strlen(SelectedItem)-1,inf], ":")!=0)
					SelectedItem+=":"
				endif
				SetVariable sv_folder win=$OwningWindowName,value=_STR:SelectedItem
			endif
		else
			Variable idx=ItemsInList(SelectedItem, ":")-1
			String wname, fname
			if(idx==0)
				fname=StringFromList(idx, SelectedItem, ":")+":"
				wname=""
			else
				wname=StringFromList(idx, SelectedItem, ":")
				fname=SelectedItem[0,strlen(SelectedItem)-strlen(wname)-1]
			endif
			SetVariable sv_folder win=$OwningWindowName,value=_STR:fname
			SetVariable sv_wave win=$OwningWindowName,value=_STR:wname
		endif
	endif
End

Function WBrowser_btn_confirm(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String hostWindow=ba.win
	switch( ba.eventCode )
		case 2: // mouse up
			
			String funcspec=GetUserData(hostWindow, "", "callback_spec")
			String funcname=StringByKey("CALLBACKFUNC", funcspec)
			String funcparam=StringByKey("FUNCPARAM", funcspec)
			FUNCREF WBrowser_CallbackPrototype func=$funcname
			
			if(str2num(StringByKey("ISPROTO", FuncRefInfo(func)))==0)
				String folderstr=""
				String wavestr=""
				ControlInfo /W=$hostWindow sv_folder
				folderstr=S_Value
				ControlInfo /W=$hostWindow sv_wave
				wavestr=S_Value
				func(funcparam, folderstr, wavestr)
			endif
			SetWindow $hostWindow, userdata(confirmed)="1"
			KillWindow $hostWindow
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

Function WBrowser_hook_onExit(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	String hostWindow=s.winName
	switch(s.eventCode)
		case 2:
			Variable confirmed=str2num(GetUserData(hostWindow, "", "confirmed"))
			if(confirmed==0)				
				String funcspec=GetUserData(hostWindow, "", "callback_spec")
				String funcname=StringByKey("CALLBACKFUNC", funcspec)
				String funcparam=StringByKey("FUNCPARAM", funcspec)
				FUNCREF WBrowser_CallbackPrototype func=$funcname
				
				if(str2num(StringByKey("ISPROTO", FuncRefInfo(func)))==0)				
					func(funcparam, "", "")
				endif
			endif
			break
		default:
			break
	endswitch

	return hookResult		// 0 if nothing done, else 1
End

Function WBrowserCreateDF(dfstr)
	String dfstr

	if(cmpstr(dfstr[0,0], ":")==0)
		dfstr=GetDataFolder(1)+dfstr[1,inf]
	endif

	Variable n=ItemsInList(dfstr, ":")
	Variable i
	Variable retVal=-1
	
	String oldFolder=GetDataFolder(1)
	try
		String subfolder=""
		SetDataFolder root:
		for(i=1; i<n; i+=1)
			subfolder=StringFromList(i, dfstr, ":")
			if(strlen(subfolder)>0)
				NewDataFolder /O $(":"+PossiblyQuoteName(subfolder)); AbortOnRTE
				SetDataFolder $(":"+PossiblyQuoteName(subfolder)); AbortOnRTE
			else
				SetDataFolder ::
			endif
		endfor
		retVal=0
	catch
		print "Error when trying to create the data folder structure "+dfstr
	endtry
	
	SetDataFolder(oldFolder)
	return retVal
End

static Function /T wbgenerateDFName(root, packagename, instance, [package_name_only])
	String root, packagename
	Variable instance
	Variable package_name_only
	
	if(package_name_only!=1)
		return root+PossiblyQuoteName(PackageName)+":instance"+num2str(instance)+":"
	else
		return root+PossiblyQuoteName(PackageName)+":"
	endif
End

//
// package structure:
// 
// root-
//      |-Package-
//                |-PackageName-
//                    infoStr
//                    maxInstanceRecord
//                              |-vars
//                              |-strs
//                              |-waves
//                              |-privateDF
//                              |-instance0-
//												infoStr
//                                          |-vars
//                                          |-strs
//														  |-waves
//                                          |-privateDF
//                              |-instance1-
//												infoStr
//                                          |-vars
//                                          |-strs
//                                          |-waves
//                                          |-privateDF
//                               ...
//
// infoStr format:


StrConstant WB_PackageRoot="root:Packages:"
Constant WBPkgNewInstance=-1
Constant WBPkgCommonDirOnly=NaN
Constant WBPkgDefaultInstance=0
Constant WBPkgMaxInstances=100
StrConstant WB_InstanceCountName="maxInstanceRecord"
StrConstant WB_InfoStringName="infoStr"

//constants for existence
Constant WBPkgExclusive=-1
Constant WBPkgOverride=0
Constant WBPkgShouldExist=1

Function /T WBSetupPackageDir(PackageName, [instance, existence, info, init_request]) //when error happens, return ""
	String PackageName
	Variable & instance//when instance is not negative, the user asks for a specific instance
							 //when instance is negative,
							 //     if existance is -1, this means the user asks to create a new instance
							 //     if existance is 1, this means the user asks to find the most recently created instance
	Variable existence //when existence is -1, the user do not expect to see an exist folder
							 //when existence is 0, the user do not care, but want to make sure folder is created
							 //when existence is 1, the user expect the folder to exist, otherwise an error should be produced
							 //by default, existence is set to 1
	String info			// name for each instance
	Variable init_request //called by the initialization function, will do the hard work of creating all the directories
								// otherwise will only return the string of the data folder pathname
								// this value should only be set to non-zero when instance is omitted (only common directory needed),
								// or instance is set to WBPkgDefaultInstance, or WBPkgNewInstance
	
	Variable createNew=0 // flag for creating new data folder
	Variable idx
	String fullPath=""
	String tmpStrName=""
	
	if(ParamIsDefault(existence))
		if(!ParamIsDefault(instance))
			if(instance<0)
				existence=WBPkgExclusive
			else
				existence=WBPkgShouldExist
			endif
		endif
	endif
	if(ParamIsDefault(info))
		info=""
	endif

	//if instance is not provided, or set to NaN (WBPkgCommonDirOnly)
	//only the top common directory for the package will be prepared.
	//this is for the case where no special instance is required.
	if(ParamIsDefault(instance) || NumType(instance)==2) 
		fullPath=wbgenerateDFName(WB_PackageRoot, PackageName, 0, package_name_only=1)
		existence=WBPkgOverride
	else
		if(instance<0) //if instance is set to negative, means user want to find a new instance slot
			for(idx=0; idx<WBPkgMaxInstances; idx+=1)
				fullPath=wbgenerateDFName(WB_PackageRoot, PackageName, idx)
				if(!DataFolderExists(fullPath))
					break
				endif
			endfor
			
			if(existence==WBPkgShouldExist) //user asks to find the newest instance that should exist.
				if(idx>0)
					idx-=1
				endif
			elseif(existence==WBPkgExclusive)//the user asks to create a new instance
				//keep idx value because this is an available name for the new instance
				init_request=1
			else
				print "existance has to be set to either 1 or -1 when instance is set to negative."
				AbortOnValue -1, -1
			endif
			
			if(idx>=WBPkgMaxInstances)
				print "Trying to create too many instances for package "+fullPath
				AbortOnValue -1, -2
			endif
			instance=idx
		elseif(instance>0) //if the user call with a specific instance number that is not zero,
								 //that means the user has called this function before with instance=-1
								 //and got a unique instance assigned. So the existence should be WBPkgShouldExist
								 //in other words, init_request should only be used with instance=WBPkgDefaultInstance,
								 // or instance=WBPkgNewInstance
			existence=WBPkgShouldExist
		endif
		fullPath=wbgenerateDFName(WB_PackageRoot, PackageName, instance)		
	endif
	
	if(init_request!=0) //this means the caller intend to generate the directory structure or check the structure
							  // instead of only need the string of the pathname.					
		switch(existence)
		case WBPkgExclusive:
			if(DataFolderExists(fullPath))
				print "package ["+fullPath+"] already exists - this is not expected."
				AbortOnValue -1, -3
			endif
			createNew=1
			break
		case WBPkgOverride:
			if(!DataFolderExists(fullPath))
				createNew=1
			endif
			break
		case WBPkgShouldExist:
			if(!DataFolderExists(fullPath))
				print "package ["+fullPath+"] should already exist but not found."
				AbortOnValue -1, -4
			endif
			break
		default:
			print "unknown value of existence request for package "+PackageName
			AbortOnValue -1, -5
			break
		endswitch
		
		if(createNew==1)
			if(WBrowserCreateDF(fullPath)!=0 || WBrowserCreateDF(fullPath+"vars")!=0 || WBrowserCreateDF(fullPath+"strs")!=0 || WBrowserCreateDF(fullPath+"waves")!=0 || WBrowserCreateDF(fulLPath+"privateDF")!=0)
				print "Error when trying to create a new instance for package "+PackageName
				AbortOnValue -1, -6
			endif
		endif //create_new==1
		
		try //prepare the common/parent directory for the package
			//there will be two common variables: instance count, and info string that contains basic information for all instances
			tmpStrName=wbgenerateDFName(WB_PackageRoot, PackageName, -1, package_name_only=1)+WB_InstanceCountName
			NVAR maxInsRecord=$(tmpStrName)
			if(!NVAR_Exists(maxInsRecord))
				Variable /G $(tmpStrName)
				NVAR maxInsRecord=$(tmpStrName)
				maxInsRecord=-1
			endif
			if(!ParamIsDefault(instance) && instance>=0)
				if(maxInsRecord<instance)
					maxInsRecord=instance
				endif
			endif
			
			tmpStrName=wbgenerateDFName(WB_PackageRoot, PackageName, -1, package_name_only=1)+WB_InfoStringName		
			SVAR infoStr=$(tmpStrName)
			if(!SVAR_Exists(infoStr))
				String /G $(tmpStrName)
				SVAR infoStr=$(tmpStrName)
				infoStr=""
			endif
			if(!ParamIsDefault(instance) && instance>=0)
				WBPkgSetInfoString(PackageName, info, instance=instance); AbortOnRTE
			endif
			
		catch
			print "Error when trying to set the common instance variables for package "+PackageName
		endtry
		
	endif //init_request!=0

	return fullPath
End

Function WBPkgGetNumberOfInstances(PackageName)
	String PackageName
	variable n=-1
	try
		NVAR ins=$(wbgenerateDFName(WB_PackageRoot, PackageName, -1, package_name_only=1)+WB_InstanceCountName)
		n=ins ; AbortOnRTE
	catch
		print "Error getting instance count for "+PackageName
	endtry
	return n
End

Function /T WBPkgGetInfoString(PackageName, [instance])
	String PackageName
	Variable instance
	String key
	String info=""
	try
		String infostr_name=""
		if(ParamIsDefault(instance))
			infostr_name=wbgenerateDFName(WB_PackageRoot, PackageName, -1, package_name_only=1)+WB_InfoStringName
		else
			infostr_name=wbgenerateDFName(WB_PackageRoot, PackageName, instance)+WB_InfoStringName
		endif
		SVAR infostr=$infostr_name
		if(!SVAR_Exists(infostr))
			String /G $infostr_name=""
			SVAR infostr=$infostr_name; AbortOnRTE
			info=""
		else
			info=infostr
		endif

	catch
		print "Error when accessing infostr for package "+PackageName+" instance "+num2istr(instance)
		info=""
	endtry
	
	return info
End

Function WBPkgSetInfoString(PackageName, str, [instance])
	String PackageName
	String str
	Variable instance
	try
		String infostr_name=""
		if(ParamIsDefault(instance))
			infostr_name=wbgenerateDFName(WB_PackageRoot, PackageName, -1, package_name_only=1)+WB_InfoStringName
		else
			infostr_name=wbgenerateDFName(WB_PackageRoot, PackageName, instance)+WB_InfoStringName
		endif
		
		SVAR infostr=$infostr_name
		if(!SVAR_Exists(infostr))
			String /G $infostr_name=""
			SVAR infostr=$infostr_name
		endif
		if(!ParamIsDefault(instance) && instance>=0)
			infostr=str; AbortOnRTE
		else
			infostr=str; AbortOnRTE
		endif
	catch
		print "Error setting info string for "+PackageName
	endtry
End

Constant WBPkgDFWave=0
Constant WBPkgDFVar=1
Constant WBPkgDFStr=2
Constant WBPkgDFDF=3

//sizes should contain the size of the waves, otherwise the size of waves will be set to zero
//if all waves are the same size, only one number is needed
//if not, all different numbers should be listed first, and the waves of one same size will be listed as
//the last item in sizes
Function WBPrepPackageWaves(fullPath, wlist, [text, datatype, sizes, quiet, nosubdir])
	String fullPath, wlist
	Variable text, datatype
	String sizes
	Variable quiet, nosubdir

	Variable c
	String s
	Variable sz
	Variable retVal=-1
	try
		s=""
		for(c=ItemsInList(wlist)-1;c>=0; c-=1)
			if(nosubdir==1)
				s=fullPath+PossiblyQuoteName(StringFromList(c, wlist))
			else
				s=fullPath+"waves:"+PossiblyQuoteName(StringFromList(c, wlist))
			endif
			sz=0
			if(!ParamIsDefault(sizes))
				variable itemnum=ItemsInList(sizes, ";")
				if(c<itemnum)
					sz=floor(str2num(StringFromList(c, sizes, ";")))
				else
					sz=floor(str2num(StringFromList(itemnum-1, sizes, ";")))
				endif
				
				if(numtype(sz)!=0)
					sz=0
				endif
			endif
			//AbortOnValue exists(s)!=0, -1
			if(!ParamIsDefault(text) && text>0)
				Make /T /N=(sz) /O $s=""; AbortOnRTE
			elseif(ParamIsDefault(datatype))
				Make /N=(sz) /O /D $s=0; AbortOnRTE
			else
				Make /N=(sz) /O /Y=(datatype) $s=0; AbortOnRTE
			endif
			WAVE w=$s
			AbortOnValue !WaveExists(w), -1
			if(ParamIsDefault(quiet) || quiet==0)
				print "["+s+"] created successfully."
			endif
		endfor
		retVal=0
	catch
		print "Error when trying to prepare wave ["+s+"]"
	endtry
	return retVal
End

Function WBPrepPackageVars(fullPath, vlist, [complx, quiet, nosubdir])
	String fullPath, vlist
	Variable complx, quiet, nosubdir

	Variable c
	String s
	Variable retVal=-1
	try
		s=""
		for(c=ItemsInList(vlist)-1;c>=0; c-=1)
			if(nosubdir==1)
				s=fullPath+PossiblyQuoteName(StringFromList(c, vlist))
			else
				s=fullPath+"vars:"+PossiblyQuoteName(StringFromList(c, vlist))
			endif
			//AbortOnValue exists(s)!=0, -1
			if(ParamIsDefault(complx))
				Variable /G $s; AbortOnRTE
			else
				Variable /G /C $s; AbortOnRTE
			endif
			NVAR v=$s
			AbortOnValue !NVAR_Exists(v), -1
			if(ParamIsDefault(quiet) || quiet==0)
				print "["+s+"] created successfully."
			endif
		endfor
		retVal=0
	catch
		print "Error when trying to prepare variable ["+s+"]"
	endtry	
	return retVal
End

Function WBPrepPackageStrs(fullPath, slist, [quiet, nosubdir])
	String fullPath, slist
	Variable quiet, nosubdir

	Variable c
	String s
	Variable retVal=-1
	try
		s=""
		for(c=ItemsInList(slist)-1;c>=0; c-=1)
			if(nosubdir==1)
				s=fullPath+PossiblyQuoteName(StringFromList(c, slist))
			else
				s=fullPath+"strs:"+PossiblyQuoteName(StringFromList(c, slist))
			endif
			//AbortOnValue exists(s)!=0, -1
			String /G $s; AbortOnRTE
			
			SVAR s1=$s
			AbortOnValue !SVAR_Exists(s1), -1
			if(ParamIsDefault(quiet) || quiet==0)
				print "["+s+"] created successfully."
			endif
		endfor
		retVal=0
	catch
		print "Error when trying to prepare string ["+s+"]"
	endtry	
	return retVal
End

Function WBPrepPackagePrivateDF(fullPath, dflist, [quiet, nosubdir])
	String fullPath, dflist
	Variable quiet, nosubdir

	Variable c
	String s
	Variable retVal=-1
	try
		s=""
		for(c=ItemsInList(dflist)-1;c>=0; c-=1)
			s=fullPath+"privateDF:"+PossiblyQuoteName(StringFromList(c, dflist))
			//AbortOnValue exists(s)!=0, -1
			WBrowserCreateDF(s); AbortOnRTE
			if(ParamIsDefault(nosubdir) || nosubdir==0)
				WBrowserCreateDF(s+":strs"); AbortOnRTE
				WBrowserCreateDF(s+":vars"); AbortOnRTE
				WBrowserCreateDF(s+":waves"); AbortOnRTE
			endif
			AbortOnValue !DataFolderExists(s), -1
			if(ParamIsDefault(quiet) || quiet==0)
				print "["+s+"] created successfully."
			endif
		endfor
		retVal=0
	catch
		print "Error when trying to prepare private DF ["+s+"]"
	endtry	
	return retVal
End

Function /T WBPkgGetName(fullPath, type, name, [quiet])
	String fullPath
	Variable type
	String name
	Variable quiet
	
	String subfd=""
	
	switch(type)
	case WBPkgDFWave:
		subfd="waves:";
		break
	case WBPkgDFVar:
		subfd="vars:";
		break
	case WBPkgDFStr:
		subfd="strs:";
		break
	case WBPkgDFDF:
		subfd="privateDF:";
	default:
	endswitch
	
	String s=fullPath+subfd+PossiblyQuoteName(name)
	if(type==WBPkgDFDF)
		s+=":"
	endif
	try
		switch(type)
		case WBPkgDFWave:
			AbortOnValue WaveExists($s)==0, -1
			break
		case WBPkgDFVar:
			NVAR nv=$s
			AbortOnValue NVAR_Exists(nv)==0, -1
			break
		case WBPkgDFStr:
			SVAR sv=$s
			AbortOnValue SVAR_Exists(sv)==0, -1
			break
		case WBPkgDFDF:
			AbortOnValue strlen(name)==0 || DataFolderExists(s)==0, -1
		default:
		endswitch		
	catch
		if(ParamIsDefault(quiet) || quiet==0)
			print "Warning: Request to access a content in package ["+s+"] that does not exist."
		endif
		s=""
	endtry
	return s
End
