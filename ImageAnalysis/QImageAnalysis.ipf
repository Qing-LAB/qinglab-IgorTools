#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function ipLoadFile()
	Variable refNum=0
	String fileFilters = "Image Movies (*.tif, *.gif):.tif,.gif;"
	String message="Please select the image to load"
	
	Open /D /R /F=fileFilters /M=message refNum
	String fullPath=S_fileName
	
	if(strlen(fullPath)==0)
		return -1 //user cancelled or an error happened
	endif
	if(refNum!=0)
		Close refNum
	endif
	
	String regExp="(^.*)\.([a-zA-Z0-9]*)$"
	String fileName="", fileType=""
	SplitString /E=regExp fullPath, filename, fileType
	fileType=UpperStr(fileType)
	
	strswitch(fileType)
	case "TIF":
	case "TIFF":
		String wname=ipLoadTIFFImageStack(fullPath)
		if(strlen(wname)>0)
			ipDisplayImage(wname)
		else
			print "error when loading "+fullPath
		endif 
		break
	endswitch
End

Function ipAddROIByAxis(String graphName, String xaxisname, String yaxisname, Wave trace, [Variable r, Variable g, Variable b, Variable alpha, Variable show_marker])
	String xaxtype=StringByKey("AXTYPE", AxisInfo(graphName, xaxisname))
	String yaxtype=StringByKey("AXTYPE", AxisInfo(graphName, yaxisname))
	String wname=NameOfWave(trace)
	
	if(cmpstr(xaxtype, "bottom")==0)
		if(cmpstr(yaxtype, "left")==0)
			AppendToGraph /W=$(graphName) /B=$xaxisname /L=$yaxisname trace[][1] vs trace[][0]
			if(show_marker>0)
				ModifyGraph /W=$(graphName) mode($wname)=4, marker($wname)=((show_marker & 0xFF00)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0, rgb($wname)=(r, g, b, alpha)
			endif
		elseif(cmpstr(yaxtype, "right")==0)
			AppendToGraph /W=$(graphName) /B=$xaxisname /R=$yaxisname trace[][1] vs trace[][0]
			if(show_marker>0)
				ModifyGraph /W=$(graphName) mode($wname)=4, marker($wname)=((show_marker & 0xFF0)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0, rgb($wname)=(r, g, b, alpha)
			endif
		else
		endif
	elseif(cmpstr(xaxtype, "top")==0)
		if(cmpstr(yaxtype, "left")==0)
			AppendToGraph /W=$(graphName) /T=$xaxisname /L=$yaxisname trace[][1] vs trace[][0]
			if(show_marker>0)
				ModifyGraph /W=$(graphName) mode($wname)=4, marker($wname)=((show_marker & 0xFF00)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0, rgb($wname)=(r, g, b, alpha)
			endif
		elseif(cmpstr(yaxtype, "right")==0)
			AppendToGraph /W=$(graphName) /T=$xaxisname /R=$yaxisname trace[][1] vs trace[][0]
			if(show_marker>0)
				ModifyGraph /W=$(graphName) mode($wname)=4, marker($wname)=((show_marker & 0xFF00)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0, rgb($wname)=(r, g, b, alpha)
			endif
		else
		endif
	else
	endif
End

Function ipAddImageByAxis(String graphName, String xaxisname, String yaxisname, Wave image)
	String xaxtype=StringByKey("AXTYPE", AxisInfo(graphName, xaxisname))
	String yaxtype=StringByKey("AXTYPE", AxisInfo(graphName, yaxisname))
	String wname=NameOfWave(image)
	
	if(cmpstr(xaxtype, "bottom")==0)
		if(cmpstr(yaxtype, "left")==0)
			AppendImage /W=$(graphName) /B=$xaxisname /L=$yaxisname image
		elseif(cmpstr(yaxtype, "right")==0)
			AppendImage /W=$(graphName) /B=$xaxisname /R=$yaxisname image
		else
		endif
	elseif(cmpstr(xaxtype, "top")==0)
		if(cmpstr(yaxtype, "left")==0)
			AppendImage /W=$(graphName) /T=$xaxisname /L=$yaxisname image
		elseif(cmpstr(yaxtype, "right")==0)
			AppendImage /W=$(graphName) /T=$xaxisname /R=$yaxisname image
		else
		endif
	else
	endif
End

Function ipUpdateEdgeTraces(frameidx, graphName, analysisDF, edgeName, outerEdgeName, innerEdgeName, xaxisname, yaxisname)
	Variable frameidx
	String graphName, analysisDF, edgeName, outerEdgeName, innerEdgeName, xaxisname, yaxisname
	Variable i, j
	
	DFREF savedDF=GetDataFolderDFR(); AbortOnRTE
	try
		String trList=TraceNameList(graphName, ";", 1)
		String edgeTraceName=StringFromList(ItemsInList(edgeName, ":")-1, edgeName, ":")
		String outerEdgeTraceName=StringFromList(ItemsInList(outerEdgeName, ":")-1, outerEdgeName, ":")
		String innerEdgeTraceName=StringFromList(ItemsInList(innerEdgeName, ":")-1, innerEdgeName, ":")
		
		SetDataFolder $analysisDF; AbortOnRTE 
		SetDataFolder $(num2istr(frameidx)); AbortOnRTE //getting into the datafolder for the frame
		
		DFREF dfr=GetDataFolderDFR(); AbortOnRTE
		Wave edgex=dfr:W_BoundaryX; AbortOnRTE
		Wave edgey=dfr:W_BoundaryY; AbortOnRTE
		DFREF innerdfr=dfr:innerEdge; AbortOnRTE
		DFREF outerdfr=dfr:outerEdge; AbortOnRTE
		Wave inneredgex=innerdfr:W_BoundaryX; AbortOnRTE
		Wave inneredgey=innerdfr:W_BoundaryY; AbortOnRTE
		Wave outeredgex=outerdfr:W_BoundaryX; AbortOnRTE
		Wave outeredgey=outerdfr:W_BoundaryY; AbortOnRTE
		Wave pickedInfo=dfr:W_pickedInfo; AbortOnRTE
		
		if(WaveExists(inneredgey) && WaveExists(inneredgex) && WaveExists(outeredgex) && WaveExists(outeredgey) && WaveExists(edgex) && WaveExists(edgey))
			Make /O /N=(DimSize(edgex, 0), 2) $edgeName=NaN; AbortOnRTE
			Make /O /N=(DimSize(inneredgex, 0), 2) $innerEdgeName=NaN; AbortOnRTE
			Make /O /N=(DimSize(outeredgex, 0), 2) $outerEdgeName=NaN; AbortOnRTE
			
			Wave e=$edgeName; AbortOnRTE
			e[][0]=edgex[p]; AbortOnRTE
			e[][1]=edgey[p]; AbortOnRTE
			
			Wave e=$innerEdgeName; AbortOnRTE
			if(WaveExists(pickedInfo))
				for(i=0; i<DimSize(pickedInfo, 0); i+=1)
					if(NumType(pickedInfo[i][0])!=0 || NumType(pickedInfo[i][2])!=0 || NumType(pickedInfo[i][3]!=0))
						break
					else
						for(j=pickedInfo[i][3]; j<=pickedInfo[i][4] && j<DimSize(edgex, 0); j+=1)
							e[j][0]=inneredgex[j]; AbortOnRTE
							e[j][1]=inneredgey[j]; AbortOnRTE
						endfor
					endif
				endfor
			else
				e[][0]=inneredgex[p]; AbortOnRTE
				e[][1]=inneredgey[p]; AbortOnRTE
			endif
			
			Wave e=$outeredgeName; AbortOnRTE
			e[][0]=outeredgex[p]; AbortOnRTE
			e[][1]=outeredgey[p]; AbortOnRTE
		endif
		
		Wave e=$edgeName; AbortOnRTE
		if(WhichListItem(edgeTraceName, trList)<0 && WaveExists(e))
			ipAddROIByAxis(graphName, xaxisname, yaxisname, e, r=0, g=65535, b=0, alpha=32768); AbortOnRTE
		endif
		
		Wave e=$inneredgeName; AbortOnRTE
		if(WhichListItem(innerEdgeTraceName, trList)<0 && WaveExists(e))
			ipAddROIByAxis(graphName, xaxisname, yaxisname, e, r=65535, g=0, b=0, alpha=32768); AbortOnRTE
		endif
		
		Wave e=$outeredgeName; AbortOnRTE
		if(WhichListItem(outerEdgeTraceName, trList)<0 && WaveExists(e))
			ipAddROIByAxis(graphName, xaxisname, yaxisname, e, r=0, g=0, b=65535, alpha=32768); AbortOnRTE
		endif
	catch
		Variable err=GetRTError(0)
		if(err!=0)
			//print "Error: ", GetErrMessage(err)
			err=GetRTError(1)

			Make /O /N=(0, 2) $edgeName; AbortOnRTE
			Make /O /N=(0, 2) $innerEdgeName; AbortOnRTE
			Make /O /N=(0, 2) $outerEdgeName; AbortOnRTE
		endif
	endtry
	SetDataFolder savedDF
End

Function ipHookFunction(s)
	STRUCT WMWinHookStruct &s
	
	Variable hookResult = 0	// 0 if we do not handle event, 1 if we handle it.
	
	String frameName, panelName, imageName, activetrace
	panelName=GetUserData(s.winName, "", "PANELNAME")
	frameName=GetUserData(s.winName, "", "FRAMENAME")
	imageName=GetUserData(s.winName, "", "IMAGENAME")
	activetrace=GetUserData(s.winName, "", "ACTIVETRACE")
	String analysisDF
	analysisDF=GetUserData(s.winName, "", "ANALYSISDF")
	String edgeName=ipGetDerivedWaveName(frameName, ".edge")
	String outerEdgeName=ipGetDerivedWaveName(frameName, ".outerEdge")
	String innerEdgeName=ipGetDerivedWaveName(frameName, ".innerEdge")
	
	Variable frameidx=str2num(GetUserData(s.winName, "", "FRAMEIDX"))
	Variable yaxispolarity=str2num(GetUserData(s.winName, "", "YAXISPOLARITY"))
	Variable roi_status=str2num(GetUserData(s.winname, "", "ROISTATUS"))
	
	if(yaxispolarity!=1)
		yaxispolarity=0
	endif
	
	String frameidxstr=""
	String imginfo=""
	String cordstr=""
	String valstr=""
	String xaxisname=""
	String yaxisname=""
	Wave imgw=$imageName
	Wave framew=$frameName
	String traceInfoStr=""
	String traceName=""
	String traceHitStr=""
	
	String roi_cur_traceName=""
	String roi_allName=""
	
	Variable update_graph_window=0
	
	switch(s.eventCode)
		case 4:
		case 5:
			Variable x, y
			
			if(strlen(panelName)<=0)
				break
			endif
			
			if(WaveExists(framew))
				imginfo=ImageInfo(s.winname, StringFromList(ItemsInList(frameName, ":")-1, frameName, ":"), 0)
				xaxisname=StringByKey("XAXIS", imginfo)
				yaxisname=StringByKey("YAXIS", imginfo)
				
				if(strlen(xaxisname)>0 && strlen(yaxisname)>0)
					x=AxisValFromPixel(s.winname, xaxisname, s.mouseLoc.h)
					y=AxisValFromPixel(s.winname, yaxisname, s.mouseLoc.v)
					if(yaxispolarity==1)
						GetAxis /Q /W=$(s.winName) $yaxisname
						if(V_min<V_max)
							SetAxis /W=$(s.winName) $yaxisname, V_max, V_min
						endif
					endif
				endif
			
				x=round(x)
				y=round(y)
				if(x<0)
					x=0
				endif						
				if(x>=DimSize(framew, 0))
					x=DimSize(framew, 0)-1
				endif
				if(y<0)
					y=0
				endif
				if(y>=DimSize(framew, 1))
					y=DimSize(framew, 1)-1
				endif
				
				sprintf cordstr, "IMG[x:%d, y:%d] ", x, y
				sprintf valstr, "IMG[val:%.1f] ", framew[x][y]
			endif
			//see if traces are also available there
			x=NaN
			y=NaN
			traceInfoStr=TraceFromPixel(s.mouseLoc.h, s.mouseLoc.v, "")
			traceName=StringByKey("TRACE", traceInfoStr)
			traceHitStr=StringByKey("HITPOINT", traceInfoStr)
			if(strlen(traceName)==0)
				traceName=activetrace
			endif
			
			if(strlen(traceName)>0)					
				traceInfoStr=TraceInfo(s.winName, traceName, 0)
				xaxisname=StringByKey("XAXIS", traceInfoStr)
				yaxisname=StringByKey("YAXIS", traceInfoStr)

				if(strlen(xaxisname)>0 && strlen(yaxisname)>0)
					x=AxisValFromPixel(s.winname, xaxisname, s.mouseLoc.h)
					y=AxisValFromPixel(s.winname, yaxisname, s.mouseLoc.v)
				endif
			endif
			if(NumType(x)==0 && NumType(y)==0)
				String cordstr2=""		
				sprintf cordstr2, "TR[x:%.2f, y:%.2f]", x, y
				cordstr+=cordstr2
				String valstr2=""
				sprintf valstr2, "TR[HitPt: %s]", traceHitStr
				valstr+=valstr2
			endif
			
			SetVariable xy_cord win=$panelName, value=_STR:(cordstr)
			SetVariable z_value win=$panelName, value=_STR:(valstr)
			
			if(s.eventCode==5) //mouse clicked
		 		if(strlen(traceName)>0) //the current trace at the pixel is set as active trace
		 			SetWindow $(s.winname), userdata(ACTIVETRACE)=traceName
		 		endif
		 		
		 		if((s.eventMod & 0xA)!=0)//ctrl or shift is held down
					ControlInfo /W=$(panelName) new_roi
					Variable new_roi=V_value
					ControlInfo /W=$(panelName) enclose_roi
					Variable enclose_roi=V_value
					Variable idx=-1
					Variable roi_ending=0
					
					if((s.eventMod & 0x8)!=0) //if ctrl is held down
						if(new_roi==0) //user want to start a new roi
							new_roi=1
							CheckBox new_roi, win=$(panelName), value=1
						else //roi is being defined
							//do nothing
						endif
					endif
					
					if(new_roi==1)
						roi_cur_traceName=ipGetDerivedWaveName(imageName, ".roi0")
						roi_allName=ipGetDerivedWaveName(imageName, ".roi")
												
						if(roi_status!=1)
							roi_status=1
							SetWindow $(s.winname), userdata(ROISTATUS)="1"
							
							Make /N=(1, 2) /O /D $roi_cur_traceName
							Wave roi_cur_trace=$roi_cur_traceName
							roi_cur_trace[0][0]=x
							roi_cur_trace[0][1]=y
							
							if(!WaveExists($roi_allName))
								Make /N=(1, 2) /O /D $roi_allName
								Wave roi_all=$roi_allName
								roi_all[0][]=NaN
							endif
						else
							Wave roi_cur_trace=$roi_cur_traceName
							idx=DimSize(roi_cur_trace, 0)
							InsertPoints /M=0 idx, 1, roi_cur_trace
							
							roi_cur_trace[idx][0]=x
							roi_cur_trace[idx][1]=y
						endif
											
						if((s.eventMod & 0xA)==0xA) //both ctrl and shift is held down
							if(enclose_roi==1) //user need to close the ROI
								idx=DimSize(roi_cur_trace, 0)
								if(roi_cur_trace[idx-1][0]!= roi_cur_trace[0][0] && roi_cur_trace[idx-1][1]!=roi_cur_trace[0][1])
									InsertPoints /M=0 idx, 1, roi_cur_trace
									roi_cur_trace[idx][0]=roi_cur_trace[0][0]
									roi_cur_trace[idx][1]=roi_cur_trace[0][1]
								endif
							endif
							//finish the current ROI block
							Wave roi_all=$roi_allName
							Variable allidx=DimSize(roi_all, 0), i
							InsertPoints /M=0 allidx, DimSize(roi_cur_trace, 0)+1, roi_all
							for(i=0; i<DimSize(roi_cur_trace, 0); i+=1)
								roi_all[i+allidx][]=roi_cur_trace[i][q]
							endfor
							roi_all[i+allidx][]=NaN
							roi_cur_trace=NaN
							
							CheckBox new_roi, win=$(panelName), value=0
							SetWindow $(s.winname), userdata(ROISTATUS)="0"
							SetWindow $(s.winname), userdata(ROITRACE)=roi_allName					
						endif
						
						//check if the ROI traces are added to the graph already
						String trList=TraceNameList(s.winname, ";", 1)
						String roicurtrName=StringFromList(ItemsInList(roi_cur_traceName, ":")-1, roi_cur_traceName, ":")
						String roialltrName=StringFromList(ItemsInList(roi_allName, ":")-1, roi_allName, ":")

						Wave roi_cur_trace=$roi_cur_traceName
						Wave roi_all=$roi_allName
						if(WhichListItem(roicurtrName, trList)<0 && WaveExists(roi_cur_trace))
							ipAddROIByAxis(s.winname, xaxisname, yaxisname, roi_cur_trace, r=0, g=32768, b=0, alpha=32768, show_marker=((43<<8)+(5<<4)+2))
						else
							ModifyGraph /W=$(s.winname) offset($PossiblyQuoteName(roicurtrName))={0,0}
						endif
						if(WhichListItem(roialltrName, trList)<0 && WaveExists(roi_all))
							ipAddROIByAxis(s.winname, xaxisname, yaxisname, roi_all, r=32768, g=0, b=0, alpha=32768, show_marker=((43<<8)+(5<<4)+2))
						else
							ModifyGraph /W=$(s.winname) offset($PossiblyQuoteName(roialltrName))={0,0}
						endif
						
					endif //new_roi checkbox is set
				endif //waveexists
			endif //mouse clicked
			
			break
			
		case 22: // mousewheel event
			
			Variable scaleFactor=1
			
			if(WaveExists(framew))
				imginfo=ImageInfo(s.winname, StringFromList(ItemsInList(frameName, ":")-1, frameName, ":"), 0)
				xaxisname=StringByKey("XAXIS", imginfo)
				yaxisname=StringByKey("YAXIS", imginfo)
							
				if((s.eventMod & 0x4)!=0) //Alt or Opt key is down
					if(s.wheelDx<0)
						scaleFactor=1.10
					else
						scaleFactor=0.9
					endif						
					if(strlen(xaxisname)>0 && strlen(yaxisname)>0)
						GetAxis /Q /W=$(s.winName) $yaxisname
						Variable ymin=V_min, ymax=V_max
						GetAxis /Q /W=$(s.winName) $xaxisname
						Variable xmin=V_min, xmax=V_max
						Variable centerx=(xmin+xmax)/2
						Variable centery=(ymin+ymax)/2
						Variable newdimx=(xmax-xmin)*scaleFactor
						Variable newdimy=(ymax-ymin)*scaleFactor
						xmin=centerx-newdimx/2
						xmax=centerx+newdimx/2
						ymin=centery-newdimy/2
						ymax=centery+newdimy/2
						SetAxis /W=$(s.winName) $yaxisname, ymin, ymax
						SetAxis /W=$(s.winName) $xaxisname, xmin, xmax
					endif
					hookResult = 1
				elseif(s.eventMod & 0x8) //Ctrl or Cmd key is down
					if(WaveExists(imgw) && WaveExists(framew))
						if(s.wheelDy<0)
							frameidx+=1
						else
							frameidx-=1
						endif
						
						if(frameidx<0)
							frameidx=DimSize(imgw, 2)-1
						endif
						if(frameidx>=DimSize(imgw, 2))
							frameidx=0
						endif
						
						update_graph_window=1
						
					endif
					hookResult = 1
				endif
				
			endif			
			break
		
		case 11:	// Keyboard event
			if(WaveExists(framew) && WaveExists(imgw))
				switch(s.specialKeyCode)
				case 100: //left arrow
					frameidx-=1
					hookResult = 1	// We handled keystroke
					break
				case 101: //right arrow
					frameidx+=1
					hookResult = 1	// We handled keystroke
					break
				case 204:
					if(roi_status==1)
						roi_cur_traceName=ipGetDerivedWaveName(imageName, ".roi0")
						Make /N=(1, 2) /O /D $roi_cur_traceName
						Wave roi_cur_trace=$roi_cur_traceName
						roi_cur_trace[0][0]=NaN
						roi_cur_trace[0][1]=NaN
						CheckBox new_roi, win=$(panelName), value=0
						
						SetWindow $(s.winname), userdata(ROISTATUS)="0"
					endif
					hookResult = 1	// We handled keystroke
					break
				default:
					break
				endswitch
				if(frameidx<0)
					frameidx=DimSize(imgw, 2)-1
				endif
				if(frameidx>=DimSize(imgw, 2))
					frameidx=0
				endif
				
				update_graph_window=1
			
			endif
			
			break
	endswitch
	
	if(WaveExists(imgw) && WaveExists(framew))
		SetWindow $(s.winName), userdata(FRAMEIDX)=num2istr(frameidx)
		sprintf frameidxstr, "IMG[%s]:[%d] ", StringFromList(ItemsInList(imageName, ":")-1, imageName, ":"), frameidx
	endif
	if(strlen(traceName)>0)
		frameidxstr+="TR["+traceName+"]"
	endif
	SetVariable frame_idx win=$panelName, value=_STR:(frameidxstr)
	
	if(update_graph_window==1)
		framew[][]=imgw[p][q][frameidx]
		ipUpdateEdgeTraces(frameidx, s.winName, analysisDF, edgeName, outerEdgeName, innerEdgeName, xaxisname, yaxisname)
	endif
	
	return hookResult		// If non-zero, we handled event and Igor will ignore it.

End

Function /S ipGetFullWaveName(String wname)
	String dfstr=StringFromList(0, wname, ":")
	String rootdf=""
	String fullName=""
	String quotedFullName=""
	
	if(strlen(dfstr)==0 || cmpstr(dfstr, "root")!=0)
		rootdf=GetDataFolder(1)
	endif
	if(strlen(rootdf)>0)
		if(cmpstr(wname[0], ":")==0)
			fullName=rootdf+wname[1,inf]
		else
			fullName=rootdf+wname
		endif
	else
		fullName=wname
	endif
	
	Variable i
	quotedFullName=StringFromList(0, fullName, ":")
	for(i=1; i<ItemsInList(fullName, ":"); i+=1)
		quotedFullName+=":"
		quotedFullName+=PossiblyQuoteName(StringFromList(i, fullName, ":"))
	endfor
	return quotedFullName
End

Function /S ipGetDerivedWaveName(String wname, String suffix)
	Variable i
	String newwname=RemoveListItem(ItemsInList(wname, ":")-1, wname, ":")
	newwname=RemoveEnding(newwname, ":")
	String derivedName=StringFromList(ItemsInList(wname, ":")-1, wname, ":")
	derivedName=ReplaceString("'", derivedName, "")
	derivedName+=suffix
	derivedName=PossiblyQuoteName(derivedName)
	newwname+=":"+derivedName
	
	return newwname	
End

Function ipPanelBtnClearROI(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			String imageName=GetUserData(graphname, "", "IMAGENAME")
			String roi_cur_traceName=ipGetDerivedWaveName(imageName, ".roi0")
			String roi_allName=ipGetDerivedWaveName(imageName, ".roi")
			
			ipClearROI(graphname, roi_cur_traceName, roi_allName)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ipClearROI(String graphname, String roi_cur_traceName, String roi_allName)
	String trList=TraceNameList(graphname, ";", 1)
	String roicurtrName=StringFromList(ItemsInList(roi_cur_traceName, ":")-1, roi_cur_traceName, ":")
	String roialltrName=StringFromList(ItemsInList(roi_allName, ":")-1, roi_allName, ":")

	Wave roi_cur_trace=$roi_cur_traceName
	Wave roi_all=$roi_allName
	if(WhichListItem(roicurtrName, trList)>=0 && WaveExists(roi_cur_trace))
		RemoveFromGraph /W=$graphname $roicurtrName
		KillWaves /Z $roi_cur_traceName
	endif
	if(WhichListItem(roialltrName, trList)>=0 && WaveExists(roi_all))
		RemoveFromGraph /W=$graphname $roialltrName
		KillWaves /Z $roi_allName
	endif
	SetWindow $(graphName), userdata(ROITRACE)=""
	SetWindow $(graphName), userdata(ROISTATUS)="0"
End

Function MySpinHook(s)
	STRUCT WMWinHookStruct &s
	
	if( s.eventCode == 23 )
		ValDisplay valdisp0,value= _NUM:1,win=$s.winName
		DoUpdate/W=$s.winName
		if( V_Flag == 2 )	// we only have one button and that means abort
			KillWindow $s.winName
			return 1
		endif
	endif
	return 0
End


Function ipPanelBtnEdgeDetect(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			String imageName=GetUserData(graphname, "", "IMAGENAME")
			String frameName=GetUserData(graphname, "", "FRAMENAME")
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			String analysisFolder=ipGetDerivedWaveName(imageName, ".DF")
			Variable proceed=0
			
			if(DataFolderExists(analysisFolder))
				DoAlert 1, "Old results exist. Proceed to overwrite?"
				switch(V_flag)
				case 1:
					proceed=1
				case 2:
					SetWindow $graphName, userdata(ANALYSISDF)=analysisFolder
					break
				default:
					break
				endswitch
			endif
			
			if(proceed==0)
				return 1
			endif
			
			Variable threshold=-1
			Variable minArea=100
			Variable dialation_iteration=2
			Variable erosion_iteration=2
			Variable allow_subset=1
			Variable startFrame=frameidx
			Variable endFrame=frameidx
			
			PROMPT threshold, "Threshold for image analysis (-1 means automatic iteration)"
			PROMPT minArea, "Minimal area for edge identification"
			PROMPT dialation_iteration, "Iterations for dialation (for inner boundary)"
			PROMPT erosion_iteration, "Iterations for erosion (for outer boundary)"
			PROMPT allow_subset, "Allow subset masks (masks that are contained entirely inside another one)", popup, "No;Yes;"
			PROMPT startFrame, "Starting from frame:"
			PROMPT endFrame, "End at frame:"
			DoPrompt "Parameters for analysis", threshold, dialation_iteration, erosion_iteration, minArea, allow_subset, startframe, endframe
			if(V_flag!=0)
				break
			endif
			
			if(allow_subset==1) //No is selected
				allow_subset=0
			endif
			
			String /G $(analysisFolder+":ParticleAnalysisSettings")
			SVAR analysissetting=$(analysisFolder+":ParticleAnalysisSettings")
			
			sprintf analysissetting, "Threshold:%.1f;MinArea:%.1f;DialationIteration:%d;ErosionIteration:%d", threshold, minArea, dialation_iteration, erosion_iteration
			
			Variable nloops=DimSize($imageName, 2)
		
			Variable useIgorDraw=0	// set true to force Igor's own draw method rather than native
			
			NewPanel/FLT /N=myProgress/W=(285,111,739,193)
			SetVariable frame_idx, pos={25,10}, bodywidth=300, value=_STR:"", disable=2
			ValDisplay valdisp0,pos={25,32},size={342,18},limits={0,100,0},barmisc={0,0}
			ValDisplay valdisp0,value= _NUM:0
			ValDisplay valdisp0,mode= 4	// candy stripe
			if( useIgorDraw )
				ValDisplay valdisp0,highColor=(0,65535,0)
			endif
			Button bStop,pos={375,32},size={50,20},title="Abort"
			SetActiveSubwindow _endfloat_
			DoUpdate/W=myProgress/E=1		// mark this as our progress window
			
			SetWindow myProgress,hook(spinner)=MySpinHook
			
			Variable t0= ticks,i
			if(startFrame<0)
				startFrame=0
			endif
			if(numtype(endFrame)!=0 || endFrame>=nloops)
				endFrame=nloops-1
			endif
			for(i=startFrame;i<=endFrame;i+=1)
				SetVariable frame_idx, win=myProgress, value=_STR:("processing frame:"+num2istr(i))
				ipImageProcEdgeDetection(graphname, analysisFolder, imageName, frameName, i, threshold, \
												dialation_iteration, erosion_iteration, minArea, allow_subset)
				if(WinType("myProgress")!=7)
					break
				else
				endif
			endfor
			Variable timeperloop= (ticks-t0)/(60*nloops)
			
			KillWindow /Z myProgress			
			print "time per loop=",timeperloop

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function ipPanelBtnPickCells(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			String imageName=GetUserData(graphname, "", "IMAGENAME")
			String frameName=GetUserData(graphname, "", "FRAMENAME")
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			String analysisFolder=ipGetDerivedWaveName(imageName, ".DF")
			String roiName=GetUserData(graphName, "", "ROITRACE")
			
			ipPickCells(imageName, frameidx, roiName, analysisFolder, -1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ipPickCells(String imageName, Variable frameidx, String roiName, String analysisFolder, Variable prevFrame)
	
	DFREF savedDF=GetDataFolderDFR()
	
	try
		SetDataFolder $(analysisFolder)
		SetDataFolder :$(num2istr(frameidx))
		
		Wave roi=$roiName
		
		Make /O /D /N=(DimSize(roi, 0), 17) W_pickedInfo=NaN; AbortOnRTE
		
		SetDataFolder :innerEdge
		
		Wave spotx=:W_SpotX
		Wave spoty=:W_SpotY
		Wave xmax=:W_xmax
		Wave xmin=:W_xmin
		Wave ymax=:W_ymax
		Wave ymin=:W_ymin
		
		print "The following cells centered at (x, y) are picked:"
		Variable i=0
		Variable j, objidx
		Variable boundaryidx, boundarycnt
		Variable cnt=0
		do
			for(; i<DimSize(roi, 0); i+=1)
				if(NumType(roi[i][0])==0 && NumType(roi[i][1])==0)
					break
				endif
			endfor
			
			if(i<DimSize(roi, 0))
				Variable x=roi[i][0]; AbortOnRTE
				Variable y=roi[i][1]; AbortOnRTE
				
				for(j=0; j<DimSize(xmin, 0); j+=1)
					if(x>=xmin[j] && x<=xmax[j] && y>=ymin[j] && y<=ymax[j])
						AbortOnRTE
						break
					endif
				endfor
				
				Variable boundarystart, boundaryend, boundaryarea, boundaryperimeter
				if(j<DimSize(xmin, 0))
					objidx=j
					x=spotx[objidx]
					y=spoty[objidx]
					Wave obj_area=:W_ImageObjArea
					Wave obj_perimeter=:W_ImageObjPerimeter
					boundaryarea=obj_area[objidx]
					boundaryperimeter=obj_perimeter[objidx]
					
					
					print x, y
					
					boundarystart=NaN
					boundaryend=NaN
					
					Wave boundaryIndex=:W_BoundaryIndex
					Wave boundaryx=:W_BoundaryX
					
					boundarystart=boundaryIndex[objidx]
					for(j=boundarystart; j<DimSize(boundaryx, 0) && NumType(boundaryx[j])==0; j+=1)
					endfor
					boundaryend=j-1; AbortOnRTE					
					
					W_pickedInfo[cnt][0]=x
					W_pickedInfo[cnt][1]=y
					W_pickedInfo[cnt][2]=objidx
					W_pickedInfo[cnt][3]=boundarystart
					W_pickedInfo[cnt][4]=boundaryend
					W_pickedInfo[cnt][5]=boundaryarea
					W_pickedInfo[cnt][6]=boundaryperimeter
					
					cnt+=1
				endif
				i+=1
			endif
		while(i<DimSize(roi, 0))
	catch
		Variable err=GetRTError(0)
		if(err!=0)
			print "Error: ", GetErrMessage(err)
			err=GetRTError(1)
		endif
	endtry
	
	SetDataFolder savedDF
End

Function ipImageProcEdgeDetection(String graphName, String analysisFolder, String imageName, 
											String frameName, Variable frameidx, Variable threshold, 
											Variable dialation_iteration, variable erosion_iteration, 
											Variable minArea, Variable allow_subset)
	Wave image=$imageName
	Wave frame=$frameName
	
	if(WaveExists(image) && WaveExists(frame) && frameidx>=0 && frameidx<DimSize(image, 2))
	else
		print "original image and frame wave does not exist, or frame idx is not correct."
		print "image name:", imageName
		print "frame name:", frameName
		print "frame index:", frameidx
		return -1
	endif
	
	multithread frame[][]=image[p][q][frameidx]
			
	DFREF savedDF=GetDataFolderDFR()
	try
		if(DataFolderExists(analysisFolder)==0)
			NewDataFolder /O/S $analysisFolder		
			analysisFolder=GetDataFolder(1)
			SetWindow $graphName, userdata(ANALYSISDF)=analysisFolder
		else
			SetDataFolder $analysisFolder
		endif
		
		NewDataFolder /O/S $(num2istr(frameidx))
		DFREF homedfr=GetDataFolderDFR()

		if(threshold>0)
			ImageThreshold /Q/M=0/T=(threshold)/i frame
		else
			ImageThreshold /Q/M=1/i frame
		endif
		
		ImageMorphology /E=6 Opening homedfr:M_ImageThresh
		ImageMorphology /E=4 Closing homedfr:M_ImageMorph
		ImageMorphology /E=5 Opening homedfr:M_ImageMorph

		if(allow_subset==0)
			ImageAnalyzeParticles /Q/D=$frameName /W/E/A=(minArea)/FILL stats homedfr:M_ImageMorph
		else
			ImageAnalyzeParticles /Q/D=$frameName /W/E/A=(minArea) stats homedfr:M_ImageMorph
		endif
		
		NewDataFolder /O/S outerEdge
		ImageMorphology /E=4 /I=(erosion_iteration) Erosion homedfr:M_ImageMorph
		
		if(allow_subset==0)
			ImageAnalyzeParticles /Q/D=$frameName /W/E/A=(minArea)/FILL stats :M_ImageMorph
		else
			ImageAnalyzeParticles /Q/D=$frameName /W/E/A=(minArea) stats :M_ImageMorph
		endif
		
		SetDataFOlder ::
		NewDataFolder /O/S innerEdge
		
		ImageMorphology /E=4 /I=(dialation_iteration) Dilation homedfr:M_ImageMorph
		
		if(allow_subset==0)
			ImageAnalyzeParticles /Q/D=$frameName /W/E/A=(minArea)/FILL stats :M_ImageMorph
		else
			ImageAnalyzeParticles /Q/D=$frameName /W/E/A=(minArea) stats :M_ImageMorph
		endif
	catch
		Variable err=GetRTError(0)
		if(err!=0)
			print "Error: ", GetErrMessage(err)
			err=GetRTError(1)
		endif
	endtry	
	SetDataFolder savedDF
End

Function ipRemoveSubsetMasks()
//	DFREF dfr=GetDataFolderDFR()
//	NewDataFolder /O/S removeSubset
//	
//	Duplicate /O dfr:M_ImageMorph, :M_ImageMorphFilled
//	Variable i
//	Wave spotx=dfr:W_SpotX
//	Wave spoty=dfr:W_SpotY
//	for(i=0; i<DimSize(spotx, 0); i+=1)
//		ImageSeedFill min=0, max=0, seedX=spotx[i], seedY=spoty[i], target=0, srcWave=:M_ImageMorphFilled
//	endfor
//	
//	SetDataFolder dfr
End

Function ipEnableHook(String imgWinName)	
	String panelName=imgWinName+"_PANEL"
	
	NewPanel /EXT=0 /HOST=$imgWinName /K=2 /W=(0, 0, 200, 200) /N=$(panelName)
	panelName=imgWinName+"#"+panelName
	SetWindow $imgWinName userdata(PANELNAME)=panelName
	
	String cordstr="x: , y:"
	String zval="val:"
	String frameidxstr=""
	SetVariable xy_cord win=$panelName, pos={10,10}, bodywidth=200, value=_STR:(cordstr), disable=2
	SetVariable z_value win=$panelName, pos={10,30}, bodywidth=200, value=_STR:(zval), disable=2
	SetVariable frame_idx win=$panelName, pos={10,50}, bodywidth=200, value=_STR:(frameidxstr), disable=2

	CheckBox new_roi, win=$panelName, pos={0, 70}, bodywidth=50, title="NewROI"
	CheckBox enclose_roi, win=$panelName, pos={50, 70}, bodywidth=50, title="Enclosed"
	Button clear_roi, win=$panelName, pos={0, 90}, size={100, 20}, title="ClearROI",proc=ipPanelBtnClearROI
	Button imgproc_edge, win=$panelName, pos={0, 110}, size={100,20}, title="DetectEdge",proc=ipPanelBtnEdgeDetect
	Button imgproc_selcell, win=$panelName, pos={0, 130}, size={100,20}, title="PickCells", proc=ipPanelBtnPickCells
	SetWindow $imgWinName hook(ipHook)=ipHookFunction
End

Function ipDisplayImage(String wname)
	Wave w=$wname
	if(WaveExists(w))
		wname=ipGetFullWaveName(wname)
		String frameName=ipGetDerivedWaveName(wname, ".f")
		Wave frame=$frameName
		Make /O /Y=(WaveType(w)) /N=(DimSize(w, 0), DimSize(w, 1)) $frameName
		Wave frame=$frameName
		frame[][]=w[p][q][0]
		
		NewImage /K=0 frame
		Variable ratio=DimSize(w, 1)/DimSize(w, 0)
		ModifyGraph height={Aspect, ratio}
		
		String imgWinName=S_Name
		SetWindow $imgWinName userdata(IMAGENAME)=wname
		SetWindow $imgWinName userdata(FRAMENAME)=frameName
		SetWindow $imgWinName userdata(FRAMEIDX)="0"
		SetWindow $imgWinName userdata(YAXISPOLARITY)="1"
		ipEnableHook(imgWinName)
	endif
End

Function /S ipLoadTIFFImageStack(String filename)
	Variable start_idx=0
	Variable total_images=-1
	String wname="", path="", extension=""
	String regExp="(^.*)\:(.*)\.([a-zA-Z0-9]*)$"
	SplitString /E=regExp filename, path, wname, extension
	if(strlen(wname)==0)
		wname="image"
	endif
	wname=CleanupName(wname, 0)
	PROMPT wname, "Wave Name:"
	PROMPT start_idx, "Start from image index:"
	PROMPT total_images, "Total pages of image (-1 means all):"
	DoPrompt "TIFF Image Loading setting:", wname, start_idx, total_images
	if(V_flag==0)
		ImageLoad /Q /C=(total_images) /S=(start_idx) /LR3D /N=$wname filename
		return StringFromList(0, S_waveNames)
	else
		return ""
	endif
End

Function ipGetFrameData(Variable frameidx)
End