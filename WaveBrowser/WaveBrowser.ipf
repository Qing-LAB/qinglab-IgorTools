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
#include <WaveSelectorWidget>
#include <PopupWaveSelector>

Constant WBFOLDERMUSTEXIST=0x01
Constant WBWAVEMUSTEXIST=0x02

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
	if((options&1)!=0)
		SetVariable sv_folder,noedit=1,userdata(options)="1"
	endif
	SetVariable sv_wave win=$panel_name, title=title_wave,size={300,20},pos={20, 40},value=_STR:initialname,userdata(options)="0"
	if((options&2)!=0)
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

StrConstant WB_PackageRoot="root:Packages:"

Function /T WBSetupPackageDir(PackageName, [instance, singular, should_exist]) //when error happens, return ""
	String PackageName
	Variable instance, singular
	Variable should_exist
	
	String fullPath=""
	if(!ParamIsDefault(instance))
		fullPath=WB_PackageRoot+PossiblyQuoteName(PackageName+"_"+num2str(instance))+":"
	else
		fullPath=WB_PackageRoot+PossiblyQuoteName(PackageName)+":"
	endif
	if(!DataFolderExists(fullPath))
		if(!ParamIsDefault(should_exist) && should_exist!=0)
			fullPath=""
		else
			if(WBrowserCreateDF(fullPath)!=0)
				fullPath=""
			endif
		endif
	else
		if(!ParamIsDefault(singular) && singular>0)
			print "The preparation of data folder for Package ["+PackageName+"] failed singularity check."
			fullPath=""
		endif
	endif
	return fullPath
End

Function WBPrepPackageWaves(fullPath, wlist, [text, datatype])
	String fullPath, wlist
	Variable text, datatype

	Variable c
	String s
	Variable retVal=-1
	try
		s=""
		for(c=ItemsInList(wlist)-1;c>=0; c-=1)
			s=fullPath+PossiblyQuoteName(StringFromList(c, wlist))
			//AbortOnValue exists(s)!=0, -1
			if(!ParamIsDefault(text) && text>0)
				Make /T /N=0 /O $s; AbortOnRTE
			elseif(ParamIsDefault(datatype))
				Make /N=0 /O /D $s; AbortOnRTE
			else
				Make /N=0 /O /Y=(datatype) $s; AbortOnRTE
			endif
			WAVE w=$s
			AbortOnValue !WaveExists(w), -1			
		endfor
		retVal=0
	catch
		print "Error when trying to prepare wave ["+s+"]"
	endtry
	return retVal
End

Function WBPrepPackageVars(fullPath, vlist, [complex])
	String fullPath, vlist
	Variable complex

	Variable c
	String s
	Variable retVal=-1
	try
		s=""
		for(c=ItemsInList(vlist)-1;c>=0; c-=1)
			s=fullPath+PossiblyQuoteName(StringFromList(c, vlist))
			//AbortOnValue exists(s)!=0, -1
			if(ParamIsDefault(complex))
				Variable /G $s; AbortOnRTE
			else
				Variable /G /C $s; AbortOnRTE
			endif
			NVAR v=$s
			AbortOnValue !NVAR_Exists(v), -1
		endfor
		retVal=0
	catch
		print "Error when trying to prepare variable ["+s+"]"
	endtry	
	return retVal
End

Function WBPrepPackageStrs(fullPath, slist)
	String fullPath, slist

	Variable c
	String s
	Variable retVal=-1
	try
		s=""
		for(c=ItemsInList(slist)-1;c>=0; c-=1)
			s=fullPath+PossiblyQuoteName(StringFromList(c, slist))
			//AbortOnValue exists(s)!=0, -1
			String /G $s; AbortOnRTE
			
			SVAR s1=$s
			AbortOnValue !SVAR_Exists(s1), -1
		endfor
		retVal=0
	catch
		print "Error when trying to prepare string ["+s+"]"
	endtry	
	return retVal
End

Function /T WBPkgGetName(fullPath, name)
	String fullPath, name
	
	String s=fullPath+PossiblyQuoteName(name)
	try
		AbortOnValue exists(s)==0, -1
	catch
		print "Request to access a content in package ["+s+"] that does not exist."
		s=""
	endtry
	return s
End