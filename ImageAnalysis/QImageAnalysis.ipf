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

Function ipFillSelectedBoundaryOnly(Wave edgeFill, Wave rawEdgeX, Wave rawEdgeY, Wave pickedInfo, Variable edgeType)
	Variable cellIndex, boundary_start, boundary_end
	
	switch(edgeType)
	case 0: //inner edge
		cellIndex=2
		boundary_start=5
		boundary_end=6
		break
	case 1: //middle edge
		cellIndex=2+9
		boundary_start=5+9
		boundary_end=6+9
		break
	case 2:
		cellIndex=2+9*2
		boundary_start=5+9*2
		boundary_end=6+9*2
		break
	default:
		return -1
	endswitch
	
	try
		Variable i, j
		
		for(i=0; i<DimSize(pickedInfo, 0); i+=1) //column 2: cell index, 5: boundary start, 6: boundary end
			Variable t=(NumType(pickedInfo[i][0])!=0 || \
							NumType(pickedInfo[i][cellIndex])!=0 || \
							NumType(pickedInfo[i][boundary_start])!=0 || \
							NumType(pickedInfo[i][boundary_end])!=0); AbortOnRTE
			if(t==0)
				for(j=pickedInfo[i][boundary_start]; j<=pickedInfo[i][boundary_end] && j<DimSize(rawEdgeX, 0); j+=1)
					edgeFill[j][0]=rawEdgeX[j]; AbortOnRTE
					edgeFill[j][1]=rawEdgeY[j]; AbortOnRTE
				endfor
			else
				break
			endif
		endfor
	catch
		Variable err=GetRTError(1)
	endtry
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
		Variable pickStatus=str2num(GetUserData(graphName, "", "PICKSTATUS"))
		
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
			
			if(pickStatus==1 && WaveExists(pickedInfo))
				Wave e=$edgeName; AbortOnRTE
				ipFillSelectedBoundaryOnly(e, edgex, edgey, pickedInfo, 1); AbortOnRTE
				
				Wave e=$innerEdgeName; AbortOnRTE
				ipFillSelectedBoundaryOnly(e, inneredgex, inneredgey, pickedInfo, 0); AbortOnRTE
				
				Wave e=$outeredgeName; AbortOnRTE
				ipFillSelectedBoundaryOnly(e, outeredgex, outeredgey, pickedInfo, 2); AbortOnRTE
			else
				Wave e=$edgeName; AbortOnRTE
				e[][0]=edgex[p]; AbortOnRTE
				e[][1]=edgey[p]; AbortOnRTE
				
				Wave e=$innerEdgeName; AbortOnRTE			
				e[][0]=inneredgex[p]; AbortOnRTE
				e[][1]=inneredgey[p]; AbortOnRTE
				
				Wave e=$outeredgeName; AbortOnRTE
				e[][0]=outeredgex[p]; AbortOnRTE
				e[][1]=outeredgey[p]; AbortOnRTE
			endif
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

Function ipUpdateROITraces(String graphName, String roi_cur_traceName, String roi_allName, String xaxisname, String yaxisname)
	//check if the ROI traces are added to the graph already
	String trList=TraceNameList(graphName, ";", 1)
	String roicurtrName=StringFromList(ItemsInList(roi_cur_traceName, ":")-1, roi_cur_traceName, ":")
	String roialltrName=StringFromList(ItemsInList(roi_allName, ":")-1, roi_allName, ":")
	String panelName=GetUserData(graphName, "", "PANELNAME")

	ControlInfo /W=$panelName show_ROI
	Variable show_roi=V_value

	Wave roi_cur_trace=$roi_cur_traceName
	Wave roi_all=$roi_allName
	
	//current ROI definitionis always shown
	if(WhichListItem(roicurtrName, trList)<0 && WaveExists(roi_cur_trace))
		ipAddROIByAxis(graphName, xaxisname, yaxisname, roi_cur_trace, r=0, g=32768, b=0, alpha=32768, show_marker=((43<<8)+(5<<4)+2))
	else
		ModifyGraph /W=$(graphName) offset($PossiblyQuoteName(roicurtrName))={0,0}
	endif
	if(show_roi) //existing record of ROI is shown only when checkbox is true
		if(WhichListItem(roialltrName, trList)<0 && WaveExists(roi_all))
			ipAddROIByAxis(graphName, xaxisname, yaxisname, roi_all, r=32768, g=0, b=0, alpha=32768, show_marker=((43<<8)+(5<<4)+2))
		else
			ModifyGraph /W=$(graphName) offset($PossiblyQuoteName(roialltrName))={0,0}
		endif
	else		
		if(WhichListItem(roialltrName, trList)>=0 && WaveExists(roi_all))
			RemoveFromGraph /W=$graphname $roialltrName
		endif
	endif
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
	
	String roi_cur_traceName=GetUserData(s.winname, "", "ROI_CURRENTTRACENAME")
	String roi_allName=GetUserData(s.winname, "", "ROI_ALLTRACENAME")
	
	Variable update_graph_window=0
	
	switch(s.eventCode)
		case 4:
		case 5:
			Variable imgx, imgy, tracex, tracey
			String ixaxisname, iyaxisname, txaxisname, tyaxisname
			
			imgx=NaN
			imgy=NaN
			if(strlen(panelName)<=0)
				break
			endif
			
			if(WaveExists(framew))
				imginfo=ImageInfo(s.winname, StringFromList(ItemsInList(frameName, ":")-1, frameName, ":"), 0)
				ixaxisname=StringByKey("XAXIS", imginfo)
				iyaxisname=StringByKey("YAXIS", imginfo)
				
				if(strlen(ixaxisname)>0 && strlen(iyaxisname)>0)
					imgx=AxisValFromPixel(s.winname, ixaxisname, s.mouseLoc.h)
					imgy=AxisValFromPixel(s.winname, iyaxisname, s.mouseLoc.v)
					if(yaxispolarity==1)
						GetAxis /Q /W=$(s.winName) $iyaxisname
						if(V_min<V_max)
							SetAxis /W=$(s.winName) $iyaxisname, V_max, V_min
						endif
					endif
				endif
			
				imgx=round(imgx)
				imgy=round(imgy)
				if(imgx<0)
					imgx=0
				endif						
				if(imgx>=DimSize(framew, 0))
					imgx=DimSize(framew, 0)-1
				endif
				if(imgy<0)
					imgy=0
				endif
				if(imgy>=DimSize(framew, 1))
					imgy=DimSize(framew, 1)-1
				endif
				
				sprintf cordstr, "IMG[x:%d, y:%d] ", imgx, imgy
				sprintf valstr, "IMG[val:%.1f] ", framew[imgx][imgy]
			endif
			//see if traces are also available there
			tracex=NaN
			tracey=NaN
			traceInfoStr=TraceFromPixel(s.mouseLoc.h, s.mouseLoc.v, "")
			traceName=StringByKey("TRACE", traceInfoStr)
			traceHitStr=StringByKey("HITPOINT", traceInfoStr)
			if(strlen(traceName)==0)
				traceName=activetrace
			endif
			
			if(strlen(traceName)>0)					
				traceInfoStr=TraceInfo(s.winName, traceName, 0)
				txaxisname=StringByKey("XAXIS", traceInfoStr)
				tyaxisname=StringByKey("YAXIS", traceInfoStr)

				if(strlen(txaxisname)>0 && strlen(tyaxisname)>0)
					tracex=AxisValFromPixel(s.winname, txaxisname, s.mouseLoc.h)
					tracey=AxisValFromPixel(s.winname, tyaxisname, s.mouseLoc.v)
				endif
			endif
			if(NumType(tracex)==0 && NumType(tracey)==0)
				String cordstr2=""		
				sprintf cordstr2, "TR[x:%.2f, y:%.2f]", tracex, tracey
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
						SetWindow $(s.winname), userdata(ROI_CURRENTTRACENAME)=roi_cur_traceName
						SetWindow $(s.winname), userdata(ROI_ALLTRACENAME)=roi_allName
						
						if(roi_status!=1)
							roi_status=1
							SetWindow $(s.winname), userdata(ROISTATUS)="1"
							
							Make /N=(1, 2) /O /D $roi_cur_traceName
							Wave roi_cur_trace=$roi_cur_traceName
							
							if(NumType(imgx)==0 && NumType(imgy)==0)
								roi_cur_trace[0][0]=imgx
								roi_cur_trace[0][1]=imgy
								xaxisname=ixaxisname
								yaxisname=iyaxisname
							elseif(NumType(tracex)==0 && NumType(tracey)==0)
								roi_cur_trace[0][0]=tracex
								roi_cur_trace[0][1]=tracey
								xaxisname=txaxisname
								yaxisname=tyaxisname
							else
								roi_cur_trace[0][]=NaN
							endif
							
							if(!WaveExists($roi_allName))
								Make /N=(1, 2) /O /D $roi_allName
								Wave roi_all=$roi_allName
								roi_all[0][]=NaN
							endif
						else
							Wave roi_cur_trace=$roi_cur_traceName
							idx=DimSize(roi_cur_trace, 0)
							InsertPoints /M=0 idx, 1, roi_cur_trace
							
							if(NumType(imgx)==0 && NumType(imgy)==0)
								roi_cur_trace[idx][0]=imgx
								roi_cur_trace[idx][1]=imgy
								xaxisname=ixaxisname
								yaxisname=iyaxisname
							elseif(NumType(tracex)==0 && NumType(tracey)==0)
								roi_cur_trace[idx][0]=tracex
								roi_cur_trace[idx][1]=tracey
								xaxisname=txaxisname
								yaxisname=tyaxisname
							else
								roi_cur_trace[0][]=NaN
							endif
							
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
						update_graph_window=1
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
		ipUpdateROITraces(s.winname, roi_cur_traceName, roi_allName, xaxisname, yaxisname)		
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
	endif
	Make /O /N=(1,2) $roi_cur_traceName=NaN
	
	if(WhichListItem(roialltrName, trList)>=0 && WaveExists(roi_all))
		RemoveFromGraph /W=$graphname $roialltrName
	endif
	Make /O /N=(1,2) $roi_allName=NaN
	
	SetWindow $(graphName), userdata(ROITRACE)=""
	SetWindow $(graphName), userdata(ROISTATUS)="0"
	SetWindow $(graphName), userdata(PICKSTATUS)="0"
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
			else
				proceed=1
			endif
			
			if(proceed==0)
				return 1
			endif
			
			Variable threshold=-1
			Variable minArea=100
			Variable dialation_iteration=3
			Variable erosion_iteration=3
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
//			print "time per loop=",timeperloop
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
			SetWindow $graphname, userdata(PICKSTATUS)="1"
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ipFindBoundaryIndexBySpot(Variable x, Variable y, Wave xmin, Wave xmax, Wave ymin, Wave ymax)
	Variable j, s
	
	s=DimSize(xmin, 0)
	try
		for(j=0; j<s; j+=1)
			Variable t=(x>=xmin[j] && x<=xmax[j] && y>=ymin[j] && y<=ymax[j]); AbortOnRTE
			if(t==1)
				break
			endif
		endfor
	catch
		Variable err=GetRTError(1)
		j=-1
	endtry
	
	if(j>=s)
		j=-1
	endif
	
	return j
End

Function ipFindBoundaryXYGroupByIndex(Wave boundaryX, Wave boundaryIndex, Variable index, Variable & boundary_start, Variable & boundary_end)
	Variable j
	try
		boundary_start=NaN
		boundary_end=NaN
		if(WaveExists(boundaryX) && WaveExists(boundaryIndex))
			boundary_start=boundaryIndex[index]; AbortOnRTE
			for(j=boundary_start; j<DimSize(boundaryX, 0) && NumType(boundaryX[j])==0; j+=1)
			endfor
			boundary_end=j-1; AbortOnRTE
		endif
	catch
		boundary_start=NaN
		boundary_end=NaN
		Variable err=GetRTError(1)
	endtry
	
End

Function ipFindParticleBoundaryInfoByXY(Variable x, Variable y, Wave W_info, Variable infoRowIdx, Variable infoColumnIdx)
	Variable retVal=0
	try
		Wave spotx=:W_SpotX
		Wave spoty=:W_SpotY
		Wave xmax=:W_xmax
		Wave xmin=:W_xmin
		Wave ymax=:W_ymax
		Wave ymin=:W_ymin
		
		Variable i=0
		Variable obj_idx, boundary_start, boundary_end, boundary_centerx, boundary_centery, boundary_area, boundary_perimeter
		
		obj_idx=ipFindBoundaryIndexBySpot(x, y, xmin, xmax, ymin, ymax) //find the corresponding inner boundary
			
		if(obj_idx>=0) //a valid boundary is found
			
			boundary_centerx=spotx[obj_idx]; AbortOnRTE
			boundary_centery=spoty[obj_idx]; AbortOnRTE
			
			Wave obj_area=:W_ImageObjArea; AbortOnRTE
			Wave obj_perimeter=:W_ImageObjPerimeter; AbortOnRTE
			
			boundary_area=obj_area[obj_idx]; AbortOnRTE
			boundary_perimeter=obj_perimeter[obj_idx]; AbortOnRTE
			
			Wave boundaryX=:W_BoundaryX; AbortOnRTE
			Wave boundaryY=:W_BoundaryY; AbortOnRTE
			Wave boundaryIndex=:W_BoundaryIndex; AbortOnRTE
			
			ipFindBoundaryXYGroupByIndex(boundaryX, boundaryIndex, obj_idx, boundary_start, boundary_end)
			
			W_info[infoRowIdx][infoColumnIdx+0]=obj_idx; AbortOnRTE
			
			W_info[infoRowIdx][infoColumnIdx+1]=boundary_centerx; AbortOnRTE
			W_info[infoRowIdx][infoColumnIdx+2]=boundary_centery; AbortOnRTE
			
			W_info[infoRowIdx][infoColumnIdx+3]=boundary_start; AbortOnRTE
			W_info[infoRowIdx][infoColumnIdx+4]=boundary_end; AbortOnRTE
			
			
			W_info[infoRowIdx][infoColumnIdx+5]=boundary_area; AbortOnRTE
			W_info[infoRowIdx][infoColumnIdx+6]=boundary_perimeter; AbortOnRTE
			
			W_info[infoRowIdx][infoColumnIdx+7]=sum(boundaryX, boundary_start, boundary_end)/(boundary_end-boundary_start+1);
			W_info[infoRowIdx][infoColumnIdx+8]=sum(boundaryY, boundary_start, boundary_end)/(boundary_end-boundary_start+1);
			
			retVal=1
		endif
	catch
		Variable err=GetRTError(1)		
	endtry
	
	return retVal
End

Function ipPickCells(String imageName, Variable frameidx, String roiName, String analysisFolder, Variable prevFrame)
	
	DFREF savedDF=GetDataFolderDFR()
	
	try
		SetDataFolder $(analysisFolder)
		Variable i, start_frameidx, end_frameidx
		Wave imgWave=$imageName
		if(WaveExists(imgWave))	
			DoAlert 1, "Do this for all frames after the current one?"
			if(V_Flag==1)
				start_frameidx=frameidx
				end_frameidx=DimSize(imgWave, 2)-1
			else
				start_frameidx=frameidx
				end_frameidx=frameidx
			endif
		else
			start_frameidx=0
			end_frameidx=-1
		endif
		
		Wave roi=$roiName		
		Make /FREE /D /N=(DimSize(roi, 0), 2) centerxy=NaN; AbortOnRTE

		for(i=start_frameidx; i<=end_frameidx; i+=1)
			SetDataFolder :$(num2istr(i))
			
			Variable sizeOfInfo=9
			Make /O /D /N=(DimSize(roi, 0), (2+sizeOfInfo*3)) W_pickedInfo=NaN; AbortOnRTE
			Variable cnt=0
			Variable roi_idx=0			
			
			if(i==start_frameidx)
				print "The following cells centered at (x, y) are picked:"
			endif
			do
				if(i==start_frameidx)
					for(; roi_idx<DimSize(roi, 0); roi_idx+=1) //pick the points from ROI that is not NaN
						if(NumType(roi[roi_idx][0])==0 && NumType(roi[roi_idx][1])==0)
							break
						endif
					endfor
					
					if(roi_idx<DimSize(roi, 0))
						Variable x=roi[roi_idx][0]; AbortOnRTE
						Variable y=roi[roi_idx][1]; AbortOnRTE
					else
						x=NaN
						y=NaN
					endif
				else
					x=centerxy[cnt][0]
					y=centerxy[cnt][1]
				endif
				
				if(NumType(x)==0 && NumType(y)==0)
					W_pickedInfo[cnt][0]=x; AbortOnRTE
					W_pickedInfo[cnt][1]=y; AbortOnRTE
					
					SetDataFolder :innerEdge; AbortOnRTE //start from inner Edge folder
					if(ipFindParticleBoundaryInfoByXY(x, y, W_pickedInfo, cnt, 2))
						x=W_pickedInfo[cnt][9] // weighed center of boundary
						y=W_pickedInfo[cnt][10] //weighed center of boundary
						
						if(i==start_frameidx)
							print "index:",W_pickedInfo[cnt][2], "centerX:", x, "centerY:", y
						endif						
						
						SetDataFolder :: ;AbortOnRTE //middle edge
						ipFindParticleBoundaryInfoByXY(x, y, W_pickedInfo, cnt, 2+sizeOfInfo)
						
						SetDataFolder :outerEdge; AbortOnRTE //outer edge
						ipFindParticleBoundaryInfoByXY(x, y, W_pickedInfo, cnt, 2+sizeOfInfo*2)
						
						centerXY[cnt][0]=x
						centerXY[cnt][1]=y
						cnt+=1
					else
						if(i>start_frameidx)
							centerXY[cnt][0]=NaN
							centerXY[cnt][1]=NaN
							cnt+=1
						endif
					endif
					SetDataFolder :: ;AbortOnRTE //go back to middle edge
				else
					cnt+=1
				endif
				roi_idx+=1
			while(((i==start_frameidx) && (roi_idx<DimSize(roi, 0))) || ((i>start_frameidx) && (cnt<DimSize(centerXY, 0))))
			
			if(i==start_frameidx)
				print "Total Number of cells: ", cnt
				DeletePoints /M=0 cnt, DimSize(centerXY, 0)-cnt, centerXY
			endif
			
			SetDataFolder :: //go back up in folder
			print "frame:", i, " is done."
		endfor
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
		
		MatrixFilter /N=3 /P=3 gauss frame
		//ImageHistModification /O frame
		//MatrixFilter /N=3 /P=3 gauss frame

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
	
	CheckBox show_ROI, win=$panelName, pos={110,70}, bodywidth=50, title="ShowROI"
	CheckBox display_edges, win=$panelName, pos={110, 90}, bodywidth=50, title="ShowEdge"
	CheckBox display_pickedcell, win=$panelName, pos={110,110}, bodywidth=50, title="ShowPicked"
	
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