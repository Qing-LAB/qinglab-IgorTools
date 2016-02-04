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

Function protoFunc_modifyCallBack(window_name, event)
	String window_name
	Variable event
	
	return 0
End

Function hook_capture_change(s)
	STRUCT WMWinHookStruct &s
	Variable statusCode= 0
	String editNameList="", editName=""
	Variable m, n
	
	GetWindow $s.winName activeSW
	String activeSubwindow = S_value
	m=ItemsInList(activeSubwindow, "#")
	String hostWindow=StringFromList(0, activeSubwindow, "#")
	String hookstatus=""
	hookstatus=GetUserData(hostWindow, "", "TableMonitorHookStatus")

	String editWindow=StringFromList(m-1, activeSubwindow, "#")
	
	editNameList=GetUserData(hostWindow, "", "CaptureEditName" )
	m=ItemsInList(editNameList)
	for(n=0; n<m; n+=1)
		editName=StringFromList(n, editNameList)
		if(strlen(editName)>0 && CmpStr(editWindow, editName)==0) //not the right edit window, no process
			break
		endif
	endfor
	if(n>=m)
		return statusCode
	endif

#if (IgorVersion()>=7)
	if((s.eventCode==0) || (s.eventCode==1) || (s.eventCode==5) || s.eventCode==11 && (s.specialKeyCode>=100 && s.specialKeyCode<=204)) //check if waves in edit window is in the allowed list, and add must waves if not included
#else
	if((s.eventCode==0) || (s.eventCode==1) || (s.eventCode==5) || s.eventCode==11 && (s.keyCode==13 || s.keyCode==3 || (s.keyCode>=28 && s.keyCode<=31)))
#endif
		try
			Variable c=NumberByKey("COLUMNS", TableInfo(activeSubwindow, -2), ":", ";")
			Variable i, j, k
			
			String wlist=""
			
			for(i=0; i<c-1; i+=1)
				wlist+=NameOfWave(WaveRefIndexed(activeSubwindow, i, 1))+";"
			endfor
			
			String allowedlist=GetUserData(hostWindow, "", "AllowedWaveList")
			String musthavelist=GetUserData(hostWindow, "", "MustHaveWaveList")
			
			Variable n1=ItemsInList(wlist)
			Variable n2=ItemsInList(allowedlist)
			Variable n3=ItemsInList(musthavelist)
			
			String w1, w2, w3, w4
			for(i=0; i<n1; i+=1)
				w1=StringFromList(i, wlist)
				for(k=0; k<n3; k+=1)
					w3=StringFromList(k, musthavelist)
					w4=StringFromList(ItemsInList(w3, ":")-1, w3, ":")
					if(cmpstr(w1, w4)==0)
						break
					endif
				endfor
				if(k>=n3)			
					for(j=0; j<n2; j+=1)
						w2=StringFromList(j, allowedlist)
						if(stringmatch(w1, w2)==1)
							break
						endif
					endfor
					if(j>0 && j>=n2)
						RemoveFromTable /W=$activeSubwindow $w1; AbortOnRTE
					endif
				endif
			endfor
			
			c=NumberByKey("COLUMNS", TableInfo(activeSubwindow, -2), ":", ";")
			wlist=""
			for(i=0; i<c-1; i+=1)
				wlist+=NameOfWave(WaveRefIndexed(activeSubwindow, i, 1))+";"
			endfor
			n1=ItemsInList(wlist)
			for(k=0; k<n3; k+=1)
				w3=StringFromList(k, musthavelist)
				w4=StringFromList(ItemsInList(w3, ":")-1, w3, ":")
				for(i=0; i<n1; i+=1)
					w1=StringFromList(i, wlist)
					if(cmpstr(w1, w4)==0)
						break
					endif
				endfor
				if(i>=n1)
					AppendToTable /W=$activeSubwindow $w3; AbortOnRTE
				endif
			endfor
			catch
				print "Error when regulating the waves included in edit window "+activeSubwindow
				print "wave in edit: "+wlist
				print "allowed: "+allowedlist
				print "must have: "+musthavelist
			endtry

#if (IgorVersion()>=7)
		if((s.eventCode==5) || (s.eventCode==11 && (s.specialKeyCode>=100 && s.specialKeyCode<=204))) //call user defined function if the event involves selecting and/or changing
#else
		if((s.eventCode==5) || (s.eventCode==11 && (s.keyCode==13 || s.keyCode==3 || (s.keyCode>=28 && s.keyCode<=31))))
#endif
		//mouse up, modified, or "enter" key has been pressed
		//mouse down is not recommended for use in hook functions with edit panel as suggested by WaveMetrics
			try
				FUNCREF protoFunc_modifyCallBack rFunc=$GetUserData(hostWindow, "", "modifyCallbackFunc"); AbortOnRTE
				String checkfunc=FuncRefInfo(rFunc)
				if(strlen(StringByKey("NAME", checkfunc))>0 && str2num(StringByKey("ISPROTO", checkfunc))==0)
					rFunc(activeSubwindow, s.eventCode); AbortOnRTE //the event can only be 5 or 11
				endif
			catch
				print "Invalid callback function or callback error for monitoring the modification of window "+activeSubwindow
			endtry
		endif
	endif
	
End

Function StartMonitorEditPanel(panelname, editname, funcname, [allowedWaveList, mustHaveWaveList])
	String panelname, editname, funcname, allowedWaveList, mustHaveWaveList
	
	try
		SetWindow $panelname, UserData(CaptureEditName)=(editname); AbortOnRTE
		SetWindow $panelname, UserData(modifyCallbackFunc)=(funcname); AbortOnRTE
		SetWindow $panelname, hook(monitorEdit)=hook_capture_change; AbortOnRTE
	
		if(ParamIsDefault(allowedWaveList))
			SetWindow $panelname, UserData(AllowedWaveList)="*"
		else
			SetWindow $panelname, UserData(AllowedWaveList)=(allowedWaveList); AbortOnRTE
		endif
		
		if(ParamIsDefault(mustHaveWaveList))
			SetWindow $panelname, UserData(MustHaveWaveList)=""
		else
			SetWindow $panelname, UserData(mustHaveWaveList)=(mustHaveWaveList); AbortOnRTE
		endif
	catch
		print "Error when setting up hook function and user data for monitoring the panel."
	endtry
End

Function StopMonitorEditPanel(panelname)
	String panelname
	
	try
		SetWindow $panelname, UserData(CaptureEditName)=""; AbortOnRTE
		SetWindow $panelname, UserData(modifyCallbackFunc)=""; AbortOnRTE
		SetWindow $panelname, hook(monitorEdit)=$""; AbortOnRTE
		SetWindow $panelname, UserData(AllowedWaveList)=""; AbortOnRTE
		SetWindow $panelname, UserData(MustHaveWaveList)=""; AbortOnRTE	
	catch
		print "Error when removing hook function and user data for monitoring the panel."
	endtry
End
