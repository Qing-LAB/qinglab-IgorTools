#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function ipLoadFile() //Load image file
//This will try to identify the type of image file and use proper function to load it
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

//The following user data tags are/should be defined for all windows with this hook function
//PANELNAME : name of panel, first defined in ipEnableHook, used when values of controls in panel are needed
//PANELVISIBLE : whether panel is invisible or not, first defined in ipEnableHook, used only in ipHookFunction
//
//IMAGENAME : name of image wave, first defined in ipDisplayImage, not always defined if ipEnableHook is 
//				used only, in which case, the following values related to image will not be defined either.
//YAXISPOLARITY : polarity of image axis, first defined in ipDisplayImage, not always defined if ipEnableHook is used only
//FRAMENAME : the frame wave (extracted single frame from image wave) name, first defined in ipDisplayImage
//FRAMEIDX : the index of frame extracted from image wave, first defined in ipDisplayImage
//IXAXISNAME : the name of the xaxis for image, defined first in ipDisplayImage, used in ipHookFunction and Redraw functions
//IYAXISNAME : the name of the yaxis for image, defined first in ipDisplayImage, used in ipHookFunction and Redraw functions
//
//BASENAME : the name used for generating derived names. If IMAGENAME is defined, it will be used as the base.
//				 Otherwise, will use the name of the graph as the basename. This will be defined first in 
//				 ipEnableHook, and used everywhere else.
//
//ANALYSISDF : the name of datafolder for storing analysis results. It is first defined in ipEnableHook function
//
//ACTIVETRACE : the trace used for displaying information in the panel defined and changed by 
//					ipHookFunction whenever the mouse is clicked
//TXAXISNAME : the name of the xaxis of the active trace, updated in ipHookFunction
//TYAXISNAME : the name of the yaxis of the active trace, updated in ipHookFunction
//
//PICKSTATUS :
//
//ROISTATUS : status of tracking ROI traces, defined and changed in ipHookFunction
//ROI_CURRENTTRACENAME : name of the current ROI as user defines new components, used only in ipHookFunction and when clear all ROI
//ROI_ALLTRACENAME : name of already defined ROI, first checked and defined in ipHookFunction, used elsewhere
//
//ROIAVAILABLE : status of ROI. If ROI has been defined, this will be value 1. This value is first defined
//					  in ipEnableHook, and will be cleared to 0 in ipClearAllROI function
//ROI_XAXISNAME : xaxis name for ROI redraw, defined and changed in ipHookFunction, used in redraw functions
//ROI_YAXISNAME : yaxis name for ROI redraw, defined and changed in ipHookFunction, used in redraw functions

Function ipEnableHook(String graphname)
	String panelName=graphname+"_PANEL"

	NewPanel /EXT=0 /HOST=$graphname /K=2 /W=(0, 0, 200, 200) /N=$(panelName)
	panelName=graphname+"#"+S_Name //the actual name generated
	SetWindow $graphname userdata(PANELNAME)=panelName
	SetWindow $graphname userdata(PANELVISIBLE)="1"
	String imgName=GetUserData(graphname, "", "IMAGENAME")
	
	String baseName=graphname
	if(strlen(imgName)>0)
		baseName=imgName
	endif	
	SetWindow $graphname userdata(BASENAME)=baseName
	
	String analysisDF=ipGenerateDerivedName(baseName, ".DF")
	SetWindow $graphname userdata(ANALYSISDF)=analysisDF
	SetWindow $graphname userdata(ROIAVAILABLE)="0"
	
	String cordstr="x: , y:"
	String zval="val:"
	String frameidxstr=""
	SetVariable xy_cord win=$panelName, pos={10,10}, bodywidth=200, value=_STR:(cordstr), disable=2
	SetVariable z_value win=$panelName, pos={10,30}, bodywidth=200, value=_STR:(zval), disable=2
	SetVariable frame_idx win=$panelName, pos={10,50}, bodywidth=200, value=_STR:(frameidxstr), disable=2

	CheckBox new_roi, win=$panelName, pos={0, 70}, bodywidth=50, title="New ROI"
	CheckBox enclose_roi, win=$panelName, pos={50, 70}, bodywidth=50, title="Enclosed"
	
	Button save_roi, win=$panelName, pos={0, 90}, size={100, 20}, title="Save ROI To Frame...",proc=ipGraphPanelBtnSaveROIToFrame
	Button imgproc_edge, win=$panelName, pos={0, 110}, size={100,20}, title="Copy ROI From...",proc=ipGraphPanelBtnCopyROIFrom
	Button clear_roi, win=$panelName, pos={0, 130}, size={100, 20}, title="Clear All ROI",proc=ipGraphPanelBtnClearAllROI
	Button imgproc_selcell, win=$panelName, pos={0, 150}, size={100,20}, title="Identify Objects",proc=ipGraphPanelBtnEdgeDetect

	CheckBox show_dot, win=$panelName, pos={105,70}, bodywidth=50, title="Dot",proc=ipGraphPanelCbRedraw
	CheckBox show_line, win=$panelName, pos={135,70}, bodywidth=50, title="Line",proc=ipGraphPanelCbRedraw
	CheckBox show_tag, win=$panelName, pos={170,70}, bodywidth=50, title="Tag",proc=ipGraphPanelCbRedraw
	CheckBox show_userroi, win=$panelName, pos={105,90}, bodywidth=50, title="Show user ROI",proc=ipGraphPanelCbRedraw
	Checkbox show_boundary, win=$panelName, pos={105,110}, bodywidth=50, title="Show boundary",proc=ipGraphPanelCbRedraw

	SetWindow $graphname hook(ipHook)=ipHookFunction
End

Function ipDisplayImage(String wname)
	Wave w=$wname
	if(WaveExists(w))
		wname=ipGetFullWaveName(wname)
		String frameName=ipGenerateDerivedName(wname, ".f")
		
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

		String imginfo=ImageInfo(imgWinName, StringFromList(ItemsInList(frameName, ":")-1, frameName, ":"), 0)
		String xaxisname=StringByKey("XAXIS", imginfo)
		String yaxisname=StringByKey("YAXIS", imginfo)
		SetWindow $imgWinName userdata(IXAXISNAME)=xaxisname
		SetWindow $imgWinName userdata(IYAXISNAME)=yaxisname
		print xaxisname
		print yaxisname
		ipEnableHook(imgWinName)
	endif
End

Function /S ipLoadTIFFImageStack(String filename) //Load TIFF file
//This functino will load TIFF file, and store in a a single wave
//All frames in the TIFF will be loaded
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


Function ipGraphPanelAddROIByAxis(String graphName, Wave trace, [Variable r, Variable g, Variable b, Variable alpha, Variable show_marker, Variable mode])
	String xaxisname=GetUserData(graphName, "", "ROI_XAXISNAME")
	String yaxisname=GetUserData(graphName, "", "ROI_YAXISNAME")
	
	if(strlen(xaxisname)==0 || strlen(yaxisname)==0)
		return -1
	endif
	
	String xaxtype=StringByKey("AXTYPE", AxisInfo(graphName, xaxisname))
	String yaxtype=StringByKey("AXTYPE", AxisInfo(graphName, yaxisname))
	String wname=NameOfWave(trace)

	if(cmpstr(xaxtype, "bottom")==0)
		if(cmpstr(yaxtype, "left")==0)
			AppendToGraph /W=$(graphName) /B=$xaxisname /L=$yaxisname trace[][1] vs trace[][0]
			if(mode>0)
				ModifyGraph /W=$(graphName) mode($wname)=(mode)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0
			endif
			if(show_marker>0)
				ModifyGraph /W=$(graphName) marker($wname)=((show_marker & 0xFF00)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) rgb($wname)=(r, g, b, alpha)
			endif
		elseif(cmpstr(yaxtype, "right")==0)
			AppendToGraph /W=$(graphName) /B=$xaxisname /R=$yaxisname trace[][1] vs trace[][0]
			if(mode>0)
				ModifyGraph /W=$(graphName) mode($wname)=(mode)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0
			endif
			if(show_marker>0)
				ModifyGraph /W=$(graphName) marker($wname)=((show_marker & 0xFF0)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) rgb($wname)=(r, g, b, alpha)
			endif
		else
		endif
	elseif(cmpstr(xaxtype, "top")==0)
		if(cmpstr(yaxtype, "left")==0)
			AppendToGraph /W=$(graphName) /T=$xaxisname /L=$yaxisname trace[][1] vs trace[][0]
			if(mode>0)
				ModifyGraph /W=$(graphName) mode($wname)=(mode)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0
			endif
			if(show_marker>0)
				ModifyGraph /W=$(graphName) marker($wname)=((show_marker & 0xFF00)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) rgb($wname)=(r, g, b, alpha)
			endif
		elseif(cmpstr(yaxtype, "right")==0)
			AppendToGraph /W=$(graphName) /T=$xaxisname /R=$yaxisname trace[][1] vs trace[][0]
			if(mode>0)
				ModifyGraph /W=$(graphName) mode($wname)=(mode)
			else
				ModifyGraph /W=$(graphName) mode($wname)=0
			endif
			if(show_marker>0)
				ModifyGraph /W=$(graphName) marker($wname)=((show_marker & 0xFF00)>>8), msize($wname)=((show_marker&0xF0)>>4), mrkThick($wname)=(show_marker & 0x0F), rgb($wname)=(r, g, b, alpha)
			else
				ModifyGraph /W=$(graphName) rgb($wname)=(r, g, b, alpha)
			endif
		else
		endif
	else
	endif
End

Function ipGraphPanelAddImageByAxis(String graphName, Wave image, [Variable mask_r, Variable mask_g, Variable mask_b, Variable mask_alpha])
	String xaxisname=GetUserData(graphName, "", "IXAXISNAME")
	String yaxisname=GetUserData(graphName, "", "IYAXISNAME")
	Variable image_displayed=1
	
	if(strlen(xaxisname)==0 || strlen(yaxisname)==0 || !WaveExists(image))
		return -1
	endif
	
	String xaxtype=StringByKey("AXTYPE", AxisInfo(graphName, xaxisname))
	String yaxtype=StringByKey("AXTYPE", AxisInfo(graphName, yaxisname))
	String wname=NameOfWave(image)
	String wbasename=StringFromList(ItemsInList(wname, ":")-1, wname, ":")

	String imglist=ImageNameList(graphName, ";")
	if(FindListItem(wbasename, imglist)<0)
		if(cmpstr(xaxtype, "bottom")==0)
			if(cmpstr(yaxtype, "left")==0)
				AppendImage /W=$(graphName) /B=$xaxisname /L=$yaxisname image
			elseif(cmpstr(yaxtype, "right")==0)
				AppendImage /W=$(graphName) /B=$xaxisname /R=$yaxisname image
			else
				image_displayed=0
			endif
		elseif(cmpstr(xaxtype, "top")==0)
			if(cmpstr(yaxtype, "left")==0)
				AppendImage /W=$(graphName) /T=$xaxisname /L=$yaxisname image
			elseif(cmpstr(yaxtype, "right")==0)
				AppendImage /W=$(graphName) /T=$xaxisname /R=$yaxisname image
			else
				image_displayed=0
			endif
		else
			image_displayed=0
		endif
	endif
	
	if(image_displayed==1)
		if(!ParamIsDefault(mask_r) && !ParamIsDefault(mask_g) && !ParamIsDefault(mask_b) && !ParamIsDefault(mask_alpha))
			ModifyImage /W=$(graphName) $wbasename eval={0,mask_r,mask_g,mask_b,mask_alpha},eval={255,0,0,0,0},explicit=1
		endif
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

//Function ipGraphPanelRedrawBoundary(frameidx, graphName, analysisDF, edgeName, outerEdgeName, innerEdgeName, xaxisname, yaxisname)
//	Variable frameidx
//	String graphName, analysisDF, edgeName, outerEdgeName, innerEdgeName, xaxisname, yaxisname
//	Variable i, j
//
//	DFREF savedDF=GetDataFolderDFR(); AbortOnRTE
//	try
//		String trList=TraceNameList(graphName, ";", 1)
//		String edgeTraceName=StringFromList(ItemsInList(edgeName, ":")-1, edgeName, ":")
//		String outerEdgeTraceName=StringFromList(ItemsInList(outerEdgeName, ":")-1, outerEdgeName, ":")
//		String innerEdgeTraceName=StringFromList(ItemsInList(innerEdgeName, ":")-1, innerEdgeName, ":")
//		Variable pickStatus=str2num(GetUserData(graphName, "", "PICKSTATUS"))
//
//		SetDataFolder $analysisDF; AbortOnRTE
//		SetDataFolder $(num2istr(frameidx)); AbortOnRTE //getting into the datafolder for the frame
//
//		DFREF dfr=GetDataFolderDFR(); AbortOnRTE
//		Wave edgex=dfr:W_BoundaryX; AbortOnRTE
//		Wave edgey=dfr:W_BoundaryY; AbortOnRTE
//		DFREF innerdfr=dfr:innerEdge; AbortOnRTE
//		DFREF outerdfr=dfr:outerEdge; AbortOnRTE
//		Wave inneredgex=innerdfr:W_BoundaryX; AbortOnRTE
//		Wave inneredgey=innerdfr:W_BoundaryY; AbortOnRTE
//		Wave outeredgex=outerdfr:W_BoundaryX; AbortOnRTE
//		Wave outeredgey=outerdfr:W_BoundaryY; AbortOnRTE
//		Wave pickedInfo=dfr:W_pickedInfo; AbortOnRTE
//
//		if(WaveExists(inneredgey) && WaveExists(inneredgex) && WaveExists(outeredgex) && WaveExists(outeredgey) && WaveExists(edgex) && WaveExists(edgey))
//			Make /O /N=(DimSize(edgex, 0), 2) $edgeName=NaN; AbortOnRTE
//			Make /O /N=(DimSize(inneredgex, 0), 2) $innerEdgeName=NaN; AbortOnRTE
//			Make /O /N=(DimSize(outeredgex, 0), 2) $outerEdgeName=NaN; AbortOnRTE
//
//			if(pickStatus==1 && WaveExists(pickedInfo))
//				Wave e=$edgeName; AbortOnRTE
//				ipFillSelectedBoundaryOnly(e, edgex, edgey, pickedInfo, 1); AbortOnRTE
//
//				Wave e=$innerEdgeName; AbortOnRTE
//				ipFillSelectedBoundaryOnly(e, inneredgex, inneredgey, pickedInfo, 0); AbortOnRTE
//
//				Wave e=$outeredgeName; AbortOnRTE
//				ipFillSelectedBoundaryOnly(e, outeredgex, outeredgey, pickedInfo, 2); AbortOnRTE
//			else
//				Wave e=$edgeName; AbortOnRTE
//				e[][0]=edgex[p]; AbortOnRTE
//				e[][1]=edgey[p]; AbortOnRTE
//
//				Wave e=$innerEdgeName; AbortOnRTE
//				e[][0]=inneredgex[p]; AbortOnRTE
//				e[][1]=inneredgey[p]; AbortOnRTE
//
//				Wave e=$outeredgeName; AbortOnRTE
//				e[][0]=outeredgex[p]; AbortOnRTE
//				e[][1]=outeredgey[p]; AbortOnRTE
//			endif
//		endif
//
//		Wave e=$edgeName; AbortOnRTE
//		if(WhichListItem(edgeTraceName, trList)<0 && WaveExists(e))
//			ipGraphPanelAddROIByAxis(graphName, e, r=0, g=65535, b=0, alpha=32768); AbortOnRTE
//		endif
//
//		Wave e=$inneredgeName; AbortOnRTE
//		if(WhichListItem(innerEdgeTraceName, trList)<0 && WaveExists(e))
//			ipGraphPanelAddROIByAxis(graphName, e, r=65535, g=0, b=0, alpha=32768); AbortOnRTE
//		endif
//
//		Wave e=$outeredgeName; AbortOnRTE
//		if(WhichListItem(outerEdgeTraceName, trList)<0 && WaveExists(e))
//			ipGraphPanelAddROIByAxis(graphName, e, r=0, g=0, b=65535, alpha=32768); AbortOnRTE
//		endif
//	catch
//		Variable err=GetRTError(0)
//		if(err!=0)
//			//print "Error: ", GetErrMessage(err)
//			err=GetRTError(1)
//
//			Make /O /N=(0, 2) $edgeName; AbortOnRTE
//			Make /O /N=(0, 2) $innerEdgeName; AbortOnRTE
//			Make /O /N=(0, 2) $outerEdgeName; AbortOnRTE
//		endif
//	endtry
//	SetDataFolder savedDF
//End

Function ipGraphPanelRedrawROI(String graphName)
	//check if the ROI traces are added to the graph already
	String roi_cur_traceName=GetUserData(graphName, "", "ROI_CURRENTTRACENAME")
	String roi_allName=GetUserData(graphName, "", "ROI_ALLTRACENAME")
	String analysisDF=GetUserData(graphName, "", "ANALYSISDF")
	Variable frameidx=str2num(GetUserData(graphName, "", "FRAMEIDX"))
	String baseName=GetUserData(graphName, "", "BASENAME")
	
	String trList=TraceNameList(graphName, ";", 1)
	String roicurtrName=StringFromList(ItemsInList(roi_cur_traceName, ":")-1, roi_cur_traceName, ":")
	String roialltrName=StringFromList(ItemsInList(roi_allName, ":")-1, roi_allName, ":")
	
	String panelName=GetUserData(graphName, "", "PANELNAME")
	
	ControlInfo /W=$panelName show_userroi
	Variable show_userroi=V_value

	Wave roi_cur_trace=$roi_cur_traceName
	Wave roi_all=$roi_allName

	//current user ROI definitionis always shown
	if(strlen(roicurtrName)>0)
		if(WhichListItem(roicurtrName, trList)<0 && WaveExists(roi_cur_trace))
			ipGraphPanelAddROIByAxis(graphName, roi_cur_trace, r=0, g=32768, b=0, alpha=65535, show_marker=((43<<8)+(5<<4)+2), mode=4)
		else
			ModifyGraph /W=$(graphName) offset($PossiblyQuoteName(roicurtrName))={0,0}
		endif
	endif
	
	if(show_userroi) //existing record of user ROI is shown only when checkbox is true
		if(strlen(roi_allName)>0)
			if(WhichListItem(roialltrName, trList)<0 && WaveExists(roi_all))
				ipGraphPanelAddROIByAxis(graphName, roi_all, r=32768, g=0, b=0, alpha=65535, show_marker=((43<<8)+(5<<4)+2), mode=4)
			else
				ModifyGraph /W=$(graphName) offset($PossiblyQuoteName(roialltrName))={0,0}
			endif
		endif
	else
		if(strlen(roi_allName)>0)
			if(WhichListItem(roialltrName, trList)>=0 && WaveExists(roi_all))
				RemoveFromGraph /W=$graphname /Z $roialltrName
			endif
		endif
	endif
	
	ControlInfo /W=$panelName show_dot
	variable show_dot=V_value
	ControlInfo /W=$panelName show_line
	variable show_line=V_value
	ControlInfo /W=$panelName show_tag
	variable show_tag=V_value
		
	if(strlen(analysisDF)>0 && frameidx>=0)
		DFREF savedDF=GetDataFolderDFR()
		try //draw ROI for frames
			SetDataFolder $analysisDF; AbortOnRTE
			NewDataFolder /O/S :$(num2str(frameidx)); AbortOnRTE
			NewDataFolder /O/S :ROI; AbortOnRTE
			
			String dotwaveName=ipGenerateDerivedName(baseName, ".f.roi.dot"); AbortOnRTE
			String dotwaveBaseName=StringFromList(ItemsInList(dotwaveName, ":")-1, dotwaveName, ":"); AbortOnRTE
			
			String linewaveName=ipGenerateDerivedName(baseName, ".f.roi.line"); AbortOnRTE
			String linewaveBaseName=StringFromList(ItemsInList(linewaveName, ":")-1, linewaveName, ":"); AbortOnRTE
			
			String tagwave=ipGenerateDerivedName(baseName, ".f.roi.tags"); AbortOnRTE
			
			Wave wdot=:W_PointROI; AbortOnRTE
			Wave wline=:W_RegionROIBoundary; AbortOnRTE
			
			if(WaveExists(wdot))
				Duplicate /O wdot, $dotwaveName; AbortOnRTE
			else
				Make /O/D/N=(1,2) $dotwaveName=NaN; AbortOnRTE
			endif
			Wave dotwave=$dotwaveName; AbortOnRTE
			if(show_dot && WaveExists(dotwave))				
				if(WhichListItem(dotwaveBaseName, trList)<0)
					ipGraphPanelAddROIByAxis(graphName, dotwave, r=0, g=0, b=65535, alpha=65535, show_marker=((19<<8)+(2<<4)+1), mode=3); AbortOnRTE
				else
					ModifyGraph /W=$(graphName) offset($PossiblyQuoteName(dotwaveBaseName))={0,0}
				endif
			else
				RemoveFromGraph /W=$graphname /Z $dotwaveBaseName; AbortOnRTE				
			endif			
			String taglist=AnnotationList(graphName); AbortOnRTE
			DeleteAnnotations /A/W=$graphName; AbortOnRTE
			if(show_tag && WaveExists(dotwave))
				Variable i
				for(i=0; i<DimSize(dotwave, 0); i+=1)
					Tag /W=$graphName /C/N=$("FRAME_ROI_TAG"+num2istr(i))/G=(16385,28398,65535)/B=1 $dotwaveBaseName,i,num2istr(i); AbortOnRTE
				endfor
			endif

			if(WaveExists(wline))
				Duplicate /O wline, $linewaveName; AbortOnRTE
			else
				Make /O/D/N=(1,2) $linewaveName=NaN; AbortOnRTE
			endif
			Wave linewave=$linewaveName; AbortOnRTE
			
			if(show_line && WaveExists(linewave))				
				if(WhichListItem(linewaveBaseName, trList)<0)
					ipGraphPanelAddROIByAxis(graphName, linewave, r=0, g=0, b=65535, alpha=65535, mode=0); AbortOnRTE
				else
					ModifyGraph /W=$(graphName) offset($PossiblyQuoteName(linewaveBaseName))={0,0}
				endif
			else
				RemoveFromGraph /W=$graphname /Z $linewaveBaseName; AbortOnRTE
			endif			
		catch
			Variable err=GetRTError(1)
		endtry
		
		SetDataFolder savedDF
	endif
End

Function ipGraphPanelRedrawAll(String graphName)
	Wave img=$GetUserData(graphName, "", "IMAGENAME")
	Wave frame=$GetUserData(graphName, "", "FRAMENAME")
	Variable frameidx=str2num(GetUserData(graphName, "", "FRAMEIDX"))
	
	if(WaveExists(img) && WaveExists(frame) && NumType(frameidx)==0 && frameidx>=0 && frameidx<DimSize(img, 2))
		multithread frame[][]=img[p][q][frameidx]
	endif
	
	ipGraphPanelRedrawROI(graphName)
End

Function ipHookFunction(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0	// 0 if we do not handle event, 1 if we handle it.

	String baseName=GetUserData(s.winName, "", "BASENAME")
	String panelName=GetUserData(s.winName, "", "PANELNAME")
	Variable panelVisible=str2num(GetUserData(s.winName, "", "PANELVISIBLE"))
	String analysisDF=GetUserData(s.winName, "", "ANALYSISDF")
	if(strlen(baseName)==0 || strlen(panelName)==0 || strlen(analysisDF)==0 || NumType(panelVisible)!=0)
		//these should be defined, otherwise the hook function does not do anything
		return 1
	endif
	
	String frameName=GetUserData(s.winName, "", "FRAMENAME")
	String imageName=GetUserData(s.winName, "", "IMAGENAME")
	String activetrace=GetUserData(s.winName, "", "ACTIVETRACE")
	
	String edgeName=ipGenerateDerivedName(baseName, ".edge")
	String outerEdgeName=ipGenerateDerivedName(baseName, ".outerEdge")
	String innerEdgeName=ipGenerateDerivedName(baseName, ".innerEdge")

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

	Wave imgw=$imageName
	Wave framew=$frameName
	String traceInfoStr=""
	String traceName=""
	String traceHitStr=""

	String roi_cur_traceName=GetUserData(s.winname, "", "ROI_CURRENTTRACENAME")
	String roi_allName=GetUserData(s.winname, "", "ROI_ALLTRACENAME")
	if(strlen(roi_cur_traceName)==0)
		roi_cur_traceName=ipGenerateDerivedName(baseName, ".roi0")
		SetWindow $(s.winname), userdata(ROI_CURRENTTRACENAME)=roi_cur_traceName
	endif
	if(strlen(roi_allName)==0)
		roi_allName=ipGenerateDerivedName(baseName, ".roi")						
		SetWindow $(s.winname), userdata(ROI_ALLTRACENAME)=roi_allName
	endif
	
	String ixaxisname=GetUserData(s.winname, "", "IXAXISNAME")
	String iyaxisname=GetUserData(s.winname, "", "IYAXISNAME")
	
	String txaxisname=GetUserData(s.winname, "", "TXAXISNAME")
	String tyaxisname=GetUserData(s.winname, "", "TYAXISNAME")
	
	String roi_xaxisname=GetUserData(s.winname, "", "ROI_XAXISNAME")
	String roi_yaxisname=GetUserData(s.winname, "", "ROI_YAXISNAME")

	Variable update_graph_window=0

	switch(s.eventCode)
		case 3:
			if((s.eventMod & 0xA)!=0)
				hookResult=1
			endif
			break
		case 4:
		case 5:
			Variable imgx, imgy, tracex, tracey

			imgx=NaN
			imgy=NaN
			if(strlen(panelName)<=0)
				break
			endif

			if(WaveExists(framew))
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
			if(strlen(traceName)==0 && s.eventCode!=5)
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
			else
				txaxisname=""
				tyaxisname=""
			endif
			SetWindow $(s.winname) userdata(TXAXISNAME)=txaxisname
			SetWindow $(s.winname) userdata(TYAXISNAME)=tyaxisname
			
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

			if(s.eventCode==5 || (s.eventMod & 0x01) !=0) //mouse clicked
		 		if(strlen(traceName)>0 && (s.eventMod & 0xA)==0) 
		 			//the current trace at the pixel is set as active trace, if no ctrl/shift key is held down
		 			SetWindow $(s.winname) userdata(ACTIVETRACE)=traceName
		 		elseif(s.eventCode==5)
		 			SetWindow $(s.winname) userdata(ACTIVETRACE)=""
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
						if(roi_status!=1)
							roi_status=1
							SetWindow $(s.winname), userdata(ROISTATUS)="1"
							CheckBox show_userroi, win=$(panelName), value=1 //when new roi is being defined, show it.

							Make /N=(1, 2) /O /D $roi_cur_traceName
							Wave roi_cur_trace=$roi_cur_traceName
							roi_xaxisname=""
							roi_yaxisname=""

							if(NumType(imgx)==0 && NumType(imgy)==0)
								roi_cur_trace[0][0]=imgx
								roi_cur_trace[0][1]=imgy
								roi_xaxisname=ixaxisname
								roi_yaxisname=iyaxisname
							elseif(NumType(tracex)==0 && NumType(tracey)==0)
								roi_cur_trace[0][0]=tracex
								roi_cur_trace[0][1]=tracey
								roi_xaxisname=txaxisname
								roi_yaxisname=tyaxisname
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
							roi_xaxisname=""
							roi_yaxisname=""

							if(NumType(imgx)==0 && NumType(imgy)==0)
								roi_cur_trace[idx][0]=imgx
								roi_cur_trace[idx][1]=imgy
								roi_xaxisname=ixaxisname
								roi_yaxisname=iyaxisname
							elseif(NumType(tracex)==0 && NumType(tracey)==0)
								roi_cur_trace[idx][0]=tracex
								roi_cur_trace[idx][1]=tracey
								roi_xaxisname=txaxisname
								roi_yaxisname=tyaxisname
							else
								roi_cur_trace[0][]=NaN
							endif
						endif
						SetWindow $(s.winname), userdata(ROI_XAXISNAME)=roi_xaxisname
						SetWindow $(s.winname), userdata(ROI_YAXISNAME)=roi_yaxisname

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
							SetWindow $(s.winname), userdata(ROIAVAILABLE)="1"
						endif
						update_graph_window=1
					endif //new_roi checkbox is set
				endif //waveexists
			endif //mouse clicked

			break

		case 22: // mousewheel event
			Variable scaleFactor=1

			if(WaveExists(framew))
				if((s.eventMod & 0x4)!=0) //Alt or Opt key is down, scaling
					if(s.wheelDx<0)
						scaleFactor=1.10
					else
						scaleFactor=0.9
					endif
					if(strlen(ixaxisname)>0 && strlen(iyaxisname)>0)
						GetAxis /Q /W=$(s.winName) $iyaxisname
						Variable ymin=V_min, ymax=V_max
						GetAxis /Q /W=$(s.winName) $ixaxisname
						Variable xmin=V_min, xmax=V_max
						Variable centerx=(xmin+xmax)/2
						Variable centery=(ymin+ymax)/2
						Variable newdimx=(xmax-xmin)*scaleFactor
						Variable newdimy=(ymax-ymin)*scaleFactor
						xmin=centerx-newdimx/2
						xmax=centerx+newdimx/2
						ymin=centery-newdimy/2
						ymax=centery+newdimy/2
						SetAxis /W=$(s.winName) $iyaxisname, ymin, ymax
						SetAxis /W=$(s.winName) $ixaxisname, xmin, xmax
					endif
				elseif(s.eventMod & 0x8) //Ctrl or Cmd key is down, changing frame
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
				endif
				hookResult = 1
			endif //frame exists
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
						Make /N=(1, 2) /O /D $roi_cur_traceName
						Wave roi_cur_trace=$roi_cur_traceName
						roi_cur_trace[0][0]=NaN
						roi_cur_trace[0][1]=NaN
						CheckBox new_roi, win=$(panelName), value=0

						SetWindow $(s.winname), userdata(ROISTATUS)="0"
					endif
					hookResult = 1	// We handled keystroke
					break
				case 202: //Tab key pressed
					if(panelVisible==1) //panel is visible now
						panelVisible=0
						SetWindow $(panelName), hide=1
					else
						panelVisible=1
						SetWindow $(panelName), hide=0, needupdate=1
						DoWindow /F $(s.winname)
					endif
					SetWindow $(s.winname), userData(PANELVISIBLE)=num2istr(panelVisible)
					hookResult = 1
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
	else
		frameidxstr+="TR[NoActive]"
	endif
	SetVariable frame_idx win=$panelName, value=_STR:(frameidxstr)

	if(update_graph_window==1)
		ipGraphPanelRedrawAll(s.winname)
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

Function /S ipGenerateDerivedName(String wname, String suffix)
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

Function ipGraphPanelBtnSaveROIToFrame(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")

			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			
			Variable startidx=frameidx
			Variable endidx=frameidx
			PROMPT startidx, "Save ROI to frame starting at:"
			PROMPT endidx, "Save ROI to frame ending at:"
			DoPrompt "save to frame range", startidx, endidx
			
			if(V_flag==0)
				for(frameidx=startidx; frameidx<=endidx; frameidx+=1)
					ipImageProcUpdateROIRecord(graphName, frameidx, -1)
				endfor
				ipGraphPanelRedrawROI(graphName)
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ipGraphPanelBtnCopyROIFrom(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ipGraphPanelBtnClearAllROI(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			Variable clear_userroi=2
			Variable clear_framestart=-1
			Variable clear_frameend=-1
			PROMPT clear_userroi, "Clear USER ROI?", popup, "No;Yes;"
			PROMPT clear_framestart, "Clear saved ROI starting at frame:"
			PROMPT clear_frameend, "Clear saved ROI ending at frame:"
			DoPrompt "Which ROI do you want to clear?", clear_userroi, clear_framestart, clear_frameend
			
			if(V_flag==0)
				if(clear_userroi==2)
					clear_userroi=1
				else
					clear_userroi=0
				endif
				ipGraphPanelClearROI(graphname, clear_userroi, clear_framestart, clear_frameend)
			endif
			ipGraphPanelRedrawROI(graphname)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ipGraphPanelCbRedraw(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			if(checked && cmpstr(cba.ctrlName, "show_tag")==0)
				CheckBox show_dot, win=$(cba.win), value=1
			endif
			
			if(cmpstr(cba.ctrlName, "show_dot")==0)
				CheckBox show_tag, win=$(cba.win), value=0
			endif

			String graphname=cba.win
			graphname=StringFromList(0, graphname, "#")
			ipGraphPanelRedrawAll(graphName)
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function ipGraphPanelClearROI(String graphname, Variable clear_userroi, Variable clear_framestart, Variable clear_frameend)
	String imageName=GetUserData(graphname, "", "IMAGENAME")
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	String roi_cur_traceName=GetUserData(graphname, "", "ROI_CURRENTTRACENAME")
	String roi_allName=GetUserData(graphname, "", "ROI_ALLTRACENAME")
	
	String trList=TraceNameList(graphname, ";", 1)
	
	if(clear_userroi)	
		String roicurtrName=StringFromList(ItemsInList(roi_cur_traceName, ":")-1, roi_cur_traceName, ":")
		String roialltrName=StringFromList(ItemsInList(roi_allName, ":")-1, roi_allName, ":")
	
		Wave roi_cur_trace=$roi_cur_traceName
		Wave roi_all=$roi_allName
		if(WhichListItem(roicurtrName, trList)>=0 && WaveExists(roi_cur_trace))
			RemoveFromGraph /W=$graphname /Z $roicurtrName
		endif
		Make /O /N=(1,2) $roi_cur_traceName=NaN
	
		if(WhichListItem(roialltrName, trList)>=0 && WaveExists(roi_all))
			RemoveFromGraph /W=$graphname /Z $roialltrName
		endif
		Make /O /N=(1,2) $roi_allName=NaN
		print "User ROI cleared."
	endif

	Variable idx, err
	DFREF savedDF=GetDataFolderDFR()

	try
		SetDataFolder $(analysisDF); AbortOnRTE
		Variable maxidx=DimSize($imageName, 2)
		Variable idxcount=0
		for(idx=clear_framestart; idx>=0 && idx<=clear_frameend && idx<maxidx; idx+=1)
			try
				SetDataFolder :$(num2istr(idx)); AbortOnRTE
				if(DataFolderExists("ROI"))
					SetDataFolder :ROI; AbortOnRTE
					KillWaves /A/Z; AbortOnRTE
					SetDataFolder :: ; AbortOnRTE
					KillDataFolder /Z :ROI ; AbortOnRTE
					if(V_flag!=0)
						print "Cannot cleanly kill ROI folder for frame ", idx
						print "This could lead to mis-operations in analysis."
					endif
				endif
				SetDataFolder :: ; AbortOnRTE
				idxcount+=1
			catch
				err=GetRTError(1)
				SetDataFolder $(analysisDF); AbortOnRTE
			endtry
		endfor
		print idxcount, " frames has their ROI removed."
	catch
		err=GetRTError(1)
	endtry
	SetDataFolder savedDF

	SetWindow $(graphName), userdata(ROIAVAILABLE)="0"
	SetWindow $(graphName), userdata(ROISTATUS)="0"
	SetWindow $(graphName), userdata(PICKSTATUS)="0"
	print "ROIs cleaned for graph window:", graphname, ", and image:", imageName
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

STRUCTURE ipImageProcParam
	Variable threshold
	Variable minArea
	Variable dialation_iteration
	Variable erosion_iteration
	Variable allow_subset
	Variable startFrame
	Variable endFrame
	Variable filterMatrixSize
	Variable filterIteration
	Variable useROI
	
	String analysisDF
	String imageName
	String frameName

	Variable maxframeidx
	
ENDSTRUCTURE

Function ipGraphPanelBtnEdgeDetect(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			String imageName=GetUserData(graphname, "", "IMAGENAME")
			String frameName=GetUserData(graphname, "", "FRAMENAME")
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
			Variable proceed=0

			if(DataFolderExists(analysisDF))
				DoAlert 1, "Old results might already exist. Proceed to overwrite?"
				switch(V_flag)
				case 1:
					proceed=1
					break
				case 2:
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
			Variable filterMatrixSize=3
			Variable filterIteration=1
			Variable useROI=1
			Variable useConstantROI=1

			PROMPT filterMatrixSize, "Gaussian filter matrix size"
			PROMPT filterIteration, "Gaussian filter iteration"
			PROMPT threshold, "Threshold for image analysis (-1 means automatic iteration)"
			PROMPT minArea, "Minimal area for edge identification"
			PROMPT dialation_iteration, "Iterations for dialation (for inner boundary)"
			PROMPT erosion_iteration, "Iterations for erosion (for outer boundary)"
			PROMPT allow_subset, "Allow subset masks (masks that are contained entirely inside another one)", popup, "No;Yes;"
			PROMPT useROI, "Use ROI for local edge detection and/or tracking selected individual objects", popup, "No;Yes;"
			PROMPT startFrame, "Starting from frame:"
			PROMPT endFrame, "End at frame:"

			DoPrompt "Parameters for analysis", filterMatrixSize, filterIteration, threshold, dialation_iteration, erosion_iteration, minArea, allow_subset, useROI, startframe, endframe
			if(V_flag!=0)
				break
			endif

			if(allow_subset==1) //No is selected
				allow_subset=0
			else //Yes is selected
				allow_subset=1
			endif

			if(useROI==1)//No is selected
				useROI=0
			else //Yes is selected
				useROI=1
			endif

			if(useROI)
				DoAlert 1, "Use constant ROI for all frames or use regions identified in previous frame to guide the next frame?"
				if(V_flag==1)
					useConstantROI=1
				else
					useConstantROI=0
				endif
			endif

			STRUCT ipImageProcParam param
			param.threshold=threshold
			param.minArea=minArea
			param.dialation_iteration=dialation_iteration
			param.erosion_iteration=erosion_iteration
			param.allow_subset=allow_subset
			param.startFrame=startFrame
			param.endFrame=endFrame
			param.filterMatrixSize=filterMatrixSize
			param.filterIteration=filterIteration
			param.useROI=useROI
			
			param.analysisDF=analysisDF
			param.imageName=imageName
			param.frameName=frameName
			param.maxframeidx=DimSize($imagename, 0)-1

			String /G $(analysisDF+":ParticleAnalysisSettings")
			SVAR analysissetting=$(analysisDF+":ParticleAnalysisSettings")

			sprintf analysissetting, "GaussianFilterMatrixSize:%d;GaussianFilterIteration:%d;Threshold:%.1f;MinArea:%.1f;DialationIteration:%d;ErosionIteration:%d", filterMatrixSize, filterIteration, threshold, minArea, dialation_iteration, erosion_iteration

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

			//Variable t0= ticks
			if(startFrame<0)
				startFrame=0
			endif
			if(numtype(endFrame)!=0 || endFrame>=nloops)
				endFrame=nloops-1
			endif
			
			ipImageProcEdgeDetection(graphname, param, progress="myProgress")
			//Variable timeperloop= (ticks-t0)/(60*nloops)
			KillWindow /Z myProgress
//			print "time per loop=",timeperloop
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function ipGraphPanelBtnPickCells(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			String imageName=GetUserData(graphname, "", "IMAGENAME")
			String frameName=GetUserData(graphname, "", "FRAMENAME")
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			String analysisFolder=GetUserData(graphname, "", "ANALYSISDF")
			String roiName=GetUserData(graphName, "", "ROI_ALLTRACENAME")
			Variable roiAvailable=str2num(GetUserData(graphName, "", "ROIAVAILABLE"))
			
			if(roiAvailable==1)
				ipImageProcPickCells(imageName, frameidx, roiName, analysisFolder, -1)
				SetWindow $graphname, userdata(PICKSTATUS)="1"
			endif
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

Function ipBoundaryFindGroupByIndex(Wave boundaryX, Wave boundaryIndex, Variable index, Variable & boundary_start, Variable & boundary_end)
//if a index wave is provided for boundary wave that are separated by NaN or Inf between groups
//this function will provide the start and end point numbers of the group identified by index number
//the number of points for the group will be returned
	Variable j
	Variable cnt=0
	try
		boundary_start=NaN
		boundary_end=NaN
		if(WaveExists(boundaryX) && WaveExists(boundaryIndex))
			boundary_start=boundaryIndex[index][0]; AbortOnRTE
			if(DimSize(boundaryIndex, 1)==2)
				boundary_end=boundaryIndex[index][1]; AbortOnRTE
			else
				for(j=boundary_start; j<DimSize(boundaryX, 0) && NumType(boundaryX[j])==0; j+=1)
				endfor
				boundary_end=j-1; AbortOnRTE
			endif
			cnt=boundary_end-boundary_start+1
		endif
	catch
		boundary_start=NaN
		boundary_end=NaN
		cnt=0
		Variable err=GetRTError(1)
	endtry
	return cnt
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
		Variable obj_idx, boundary_start, boundary_end, boundary_spotx, boundary_spoty, boundary_area, boundary_perimeter

		obj_idx=ipFindBoundaryIndexBySpot(x, y, xmin, xmax, ymin, ymax) //find the corresponding inner boundary

		if(obj_idx>=0) //a valid boundary is found

			boundary_spotx=spotx[obj_idx]; AbortOnRTE
			boundary_spoty=spoty[obj_idx]; AbortOnRTE

			Wave obj_area=:W_ImageObjArea; AbortOnRTE
			Wave obj_perimeter=:W_ImageObjPerimeter; AbortOnRTE

			boundary_area=obj_area[obj_idx]; AbortOnRTE
			boundary_perimeter=obj_perimeter[obj_idx]; AbortOnRTE

			Wave boundaryX=:W_BoundaryX; AbortOnRTE
			Wave boundaryY=:W_BoundaryY; AbortOnRTE
			Wave boundaryIndex=:W_BoundaryIndex; AbortOnRTE

			ipBoundaryFindGroupByIndex(boundaryX, boundaryIndex, obj_idx, boundary_start, boundary_end)

			W_info[infoRowIdx][infoColumnIdx+0]=obj_idx; AbortOnRTE

			W_info[infoRowIdx][infoColumnIdx+1]=boundary_spotx; AbortOnRTE
			W_info[infoRowIdx][infoColumnIdx+2]=boundary_spoty; AbortOnRTE

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

Function ipImageProcPickCells(String imageName, Variable frameidx, String roiName, String analysisFolder, Variable prevFrame)

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

Function ipBoundaryGetNextGroup(Wave boundary, Variable & startidx, Variable & endidx)
//for waves that has point groups separated by NaN or Inf gaps, find the next group, store the idx of starting and ending points
//return value is the length of the next group
	Variable maxidx=DimSize(boundary, 0); AbortOnRTE

	Variable i

	for(i=startidx; i<maxidx; i+=1)
		if(NumType(boundary[i][0])==0)
			break //find the first number
		endif
	endfor
	startidx=i
	endidx=startidx
	for(; i<maxidx; i+=1)
		if(NumType(boundary[i][0])!=0)
			break //find the next NaN or Inf
		endif
	endfor
	endidx=i-1
	if(endidx>=maxidx)
		endidx=startidx
	endif
	if(startidx>=maxidx)
		return 0
	else
		return endidx-startidx+1
	endif
End

Function ipImageProcUpdateROIRecord(String graphName, Variable currentFrame, Variable refFrame)
//This function will update ROI records from refFrame's ROI datafolder
//If the refFrame < 0, user ROI (defined by mouse clicks) will be used for update
//This will separate singular dots, and lines/regions from each other, and generate index etc
	String imageName=GetUserData(graphName, "", "IMAGENAME")
	String analysisDF=GetUserData(graphName, "", "ANALYSISDF")
	String userROIname=GetUserData(graphName, "", "ROI_ALLTRACENAME")
	Variable maxFrame=-1	
	Wave imgw=$imageName
	if(WaveExists(imgw))
		maxFrame=DimSize(imgw, 2)-1
	else
		return -1
	endif

	if(currentFrame<0 || currentFrame>=DimSize(imgw, 2) || strlen(analysisDF)==0)
		return -1
	endif

	Variable retVal=-1
	DFREF savedDF=GetDataFolderDFR()

	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		NewDataFolder /O/S :$(num2istr(currentFrame)); AbortOnRTE

		if(refFrame<0) //user ROI is used
			Wave roiwave=$userROIname; AbortOnRTE
			if(WaveExists(roiwave))
				//we need to find the ROIs with more than one points which will define the "regions"
				//single point ROIs will be used just to mark the objects that has its center close to that spot for tracking
				NewDataFolder /O/S :ROI ; AbortOnRTE
				Make /O /D /N=(1, 2) W_RegionROIIndex=NaN
				Make /O /D /N=(1, 2) W_RegionROIBoundary=NaN
				Make /O /D /N=(1, 2) W_PointROI=NaN

				Variable startidx=0, endidx=0
				Variable len=0
				Variable cnt_regionIdx=0
				Variable cnt_regionStart=0
				Variable cnt_point=0
				Variable i

				do
					len=ipBoundaryGetNextGroup(roiwave, startidx, endidx); AbortOnRTE

					if(len>0)
						if(len==1)
							//single point ROI
							if(cnt_point!=0)
								InsertPoints /M=0 DimSize(W_PointROI, 0), 1, W_pointROI; AbortOnRTE
							endif
							W_pointROI[cnt_point][0]=roiwave[startidx][0]; AbortOnRTE
							W_pointROI[cnt_point][1]=roiwave[startidx][1]; AbortOnRTE
							cnt_point+=1
						else
							if(cnt_regionIdx!=0)//following insertion will need to have NaN space saved
								InsertPoints /M=0 DimSize(W_RegionROIIndex, 0), 1, W_RegionROIIndex; AbortOnRTE
								InsertPoints /M=0 DimSize(W_RegionROIBoundary, 0), len+1, W_RegionROIBoundary; AbortOnRTE
							else //first insertion has the first element as blank
								InsertPoints /M=0 DimSize(W_RegionROIBoundary, 0), len, W_RegionROIBoundary; AbortOnRTE
							endif
							W_RegionROIIndex[cnt_regionIdx][0]=cnt_regionStart; AbortOnRTE //boundary start point
							for(i=0; i<len && cnt_regionStart<DimSize(W_RegionROIBoundary, 0); cnt_regionStart+=1, i+=1)
								W_RegionROIBoundary[cnt_regionStart][0]=roiwave[startidx+i][0]; AbortOnRTE
								W_RegionROIBoundary[cnt_regionStart][1]=roiwave[startidx+i][1]; AbortOnRTE
							endfor
							W_RegionROIBoundary[cnt_regionStart][]=NaN; AbortOnRTE
							W_RegionROIIndex[cnt_regionIdx][1]=cnt_regionStart-1; AbortOnRTE //boundary end point
							cnt_regionStart+=1
							cnt_regionIdx+=1
						endif

						//find the next region/point
						startidx=endidx+1
						endidx=startidx
					endif
				while(len>0)

				retVal=0
			endif
		else //following frames will used previous tracked particle's edge region to get new ROI defined
			try

			catch
			endtry
		endif
	catch
		Variable err=GetRTError(1)
	endtry

	SetDataFolder savedDF

	return retVal
End

Function ipImageProcGenerateROIMask(String graphName, DFREF ROIDF, Variable roi_idx, Wave frame, String roimask_name)
//this function will generate ROI mask and will return the index for the next iteration
//when no more ROI is available, -1 will be returned
	Variable nextidx=-1
	if(DataFolderRefStatus(ROIDF)==1 && roi_idx>=0)
		Wave W_idx=ROIDF:W_RegionROIIndex
		Wave W_region=ROIDF:W_RegionROIBoundary
		
		Variable startidx=-1, endidx=-1, cnt=-1
		cnt=ipBoundaryFindGroupByIndex(W_region, W_idx, roi_idx, startidx, endidx)
		if(cnt>0)
			Make /O /N=(DimSize(frame, 0), DimSize(frame, 1)) /Y=0x48 $roimask_name=0
			Make /N=(cnt) /D /O ROIDF:M_ROIMaskX, ROIDF:M_ROIMaskY
			Wave tmpx=ROIDF:M_ROIMaskX
			Wave tmpy=ROIDF:M_ROIMaskY
			tmpx[]=W_region[startidx+p][0]
			tmpy[]=W_region[startidx+p][1]
			
			Wave roimask=$roimask_name
			String roimaskbasename=StringFromList(ItemsInList(roimask_name, ":")-1, roimask_name, ":")
			
			ipGraphPanelAddImageByAxis(graphName, roimask)
			
			DrawAction /W=$graphName /L=ProgFront delete
			
			SetDrawLayer /W=$graphName ProgFront
			SetDrawEnv /W=$graphName linefgc= (65535,65535,0),fillpat= 0,xcoord= top,ycoord= left, save			
			DrawPoly /W=$graphName tmpx[0],tmpy[0],1,1,tmpx,tmpy
			ImageGenerateROIMask /E=1/I=0/W=$graphName $roimaskbasename
			
			DrawAction /W=$graphName /L=ProgFront delete
			
			Wave M_ROIMask=:M_ROIMask
			Duplicate /O M_ROIMask, roimask
			RemoveImage /W=$graphName /Z $roimaskbasename
			
			nextidx=roi_idx+1
		endif
	else
		nextidx=-1
	endif
	print "next roi idx returned as:", nextidx
	return nextidx
End

Function ipImageProcClearEdges(String graphName, Variable frameidx, Variable edgeType)
	String analysisDF=GetUserData(graphName, "", "ANALYSISDF")
	String dfname=analysisDF+":"+PossiblyQuoteName(num2istr(frameidx))+":"
	switch(edgeType)
	case 0: //normal edge
		dfname+="DetectedEdges"
		break
	case 1: //inner edge
		dfname+="innerEdge:DetectedEdges"
		break	
	case 2: //outer edge
		dfname+="outerEdge:DetectedEdges"
		break
	default:
		dfname=""
		break
	endswitch
	
	if(strlen(dfname)>0)
		KillDataFolder /Z $dfname
	endif
End

Function ipImageProcAddDetectedEdge(DFREF homedfr)
	try
		NewDataFolder /O homedfr:DetectedEdges; AbortOnRTE
		DFREF edgeDF=homedfr:DetectedEdges; AbortOnRTE
		
		Wave W_Boundary=edgeDF:W_Boundary
		Wave W_Info=edgeDF:W_Info
		
		Wave W_newx=homedfr:W_BoundaryX
		Wave W_newy=homedfr:W_BoundaryY
		Wave W_newidx=homedfr:W_BoundaryIndex
		Wave W_xmax=homedfr:W_xmax
		Wave W_xmin=homedfr:W_xmin
		Wave W_ymax=homedfr:W_ymax
		Wave W_ymin=homedfr:W_ymin
		Wave W_spotx=homedfr:W_SpotX
		Wave W_spoty=homedfr:W_SpotY
		Wave W_area=homedfr:W_ImageObjArea
		Wave W_perimeter=homedfr:W_ImageObjPerimeter
		Wave W_rectangularity=homedfr:W_rectangularity
		Wave W_circularity=homedfr:W_circularity
		
		Variable boundary_baseidx=0
		Variable info_baseidx=0
		
		if(!WaveExists(W_Boundary))
			Make /D/O/N=(DimSize(W_newx, 0), 2) edgeDF:W_Boundary; AbortOnRTE
			Wave W_Boundary=edgeDF:W_Boundary; AbortOnRTE
			W_Boundary[][0]=W_newx[p]; AbortOnRTE
			W_Boundary[][1]=W_newy[p]; AbortOnRTE
		else
			boundary_baseidx=DimSize(W_Boundary, 0)
			InsertPoints /M=0 boundary_baseidx, DimSize(W_newx, 0)+1, W_Boundary; AbortOnRTE
			W_Boundary[boundary_baseidx][]=NaN; AbortOnRTE
			
			boundary_baseidx+=1
			W_Boundary[boundary_baseidx,][0]=W_newx[p-boundary_baseidx]; AbortOnRTE
			W_Boundary[boundary_baseidx,][1]=W_newy[p-boundary_baseidx]; AbortOnRTE
		endif
		
		if(!WaveExists(W_Info))
			Make /D/O/N=(DimSize(W_newidx, 0), 14) edgeDF:W_Info; AbortOnRTE
			Wave W_Info=edgeDF:W_Info; AbortOnRTE
		else
			info_baseidx=DimSize(W_Info, 0)
			InsertPoints /M=0 info_baseidx, DimSize(W_newidx, 0), W_Info; AbortOnRTE
		endif
		
		Variable i
		for(i=0; i<DimSize(W_newidx, 0); i+=1)
			Variable startidx, endidx
			ipBoundaryFindGroupByIndex(W_newx, W_newidx, i, startidx, endidx)
			if(startidx>=0 && endidx>=startidx)
				W_Info[info_baseidx+i][0]=boundary_baseidx+startidx
				W_Info[info_baseidx+i][1]=boundary_baseidx+endidx
				
				W_Info[info_baseidx+i][2]=W_xmin[i]
				W_Info[info_baseidx+i][3]=W_xmax[i]
				W_Info[info_baseidx+i][4]=W_ymin[i]
				W_Info[info_baseidx+i][5]=W_ymax[i]
				
				W_Info[info_baseidx+i][6]=W_SpotX[i]
				W_Info[info_baseidx+i][7]=W_SpotY[i]
				
				W_Info[info_baseidx+i][8]=sum(W_newx, startidx, endidx)/(endidx-startidx+1)
				W_Info[info_baseidx+i][9]=sum(W_newy, startidx, endidx)/(endidx-startidx+1)
				
				W_Info[info_baseidx+i][10]=W_area[i]
				W_Info[info_baseidx+i][11]=W_perimeter[i]
				W_Info[info_baseidx+i][12]=W_rectangularity[i]
				W_Info[info_baseidx+i][13]=W_circularity[i]
			else
				W_Info[info_baseidx+i][]=NaN
			endif				
		endfor
	catch
		Variable err=GetRTError(1)
		print err
	endtry
	
	return 0
End

Function ipImageProcEdgeDetection(String graphName, STRUCT ipImageProcParam & param, [String progress])
	Wave image=$(param.imageName)
	Wave frame=$(param.frameName)

	if(!WaveExists(image) || !WaveExists(frame))
		return -1
	endif
	
	Variable frameidx
	Variable roi_counts
	
	DFREF savedDF=GetDataFolderDFR()
	NewDataFolder /O/S $(param.analysisDF)	
	NewDataFolder /O/S $(num2istr(frameidx))
	DFREF homedfr=GetDataFolderDFR()
			
	for(frameidx=param.startframe; frameidx>=0 && frameidx<=param.endframe && frameidx<=param.maxframeidx; frameidx+=1)
		try
			if(!ParamIsDefault(progress))
				if(wintype(progress)!=7)
					break
				else
					String updatestr="Working on Frame:"+num2istr(frameidx); AbortOnRTE
					SetVariable frame_idx, win=$progress, value=_STR:(updatestr); AbortOnRTE
				endif
			endif

			multithread frame[][]=image[p][q][frameidx]; AbortOnRTE
			
			String roimask_name=GetDataFolder(1)+"M_ROI"

			MatrixFilter /N=3 /P=3 gauss frame
			
			ipImageProcClearEdges(graphName, frameidx, 0) //clear existing info of edge
			ipImageProcClearEdges(graphName, frameidx, 1)
			ipImageProcClearEdges(graphName, frameidx, 2)
			
			roi_counts=0
			do
				if(param.useROI==1)
					DFREF roidf=:ROI
					roi_counts=ipImageProcGenerateROIMask(graphName, roidf, roi_counts, frame, roimask_name)
					Wave roimask=$roimask_name
					if(roi_counts>=0 && WaveExists(roimask))
						if(param.threshold>0)
							ImageThreshold /Q/M=0/T=(param.threshold)/R={roimask,0} frame
							Wave thresh=homedfr:M_ImageThresh
							thresh=255-thresh
						else
							ImageThreshold /Q/M=1/R={roimask, 0} frame
							Wave thresh=homedfr:M_ImageThresh
							thresh=255-thresh
						endif
					else
						break
					endif
				else
					roi_counts=-1
					if(param.threshold>0)
						ImageThreshold /Q/M=0/T=(param.threshold)/i frame
					else
						ImageThreshold /Q/M=1/i frame
					endif
				endif
						
				ImageMorphology /E=6 Opening homedfr:M_ImageThresh
				ImageMorphology /E=4 Closing homedfr:M_ImageMorph
				ImageMorphology /E=5 Opening homedfr:M_ImageMorph
		
				if(param.allow_subset==0)
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea)/FILL stats homedfr:M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea) stats homedfr:M_ImageMorph
				endif
				
				ipImageProcAddDetectedEdge(homedfr)
				
		
				NewDataFolder /O/S outerEdge
				ImageMorphology /E=4 /I=(param.erosion_iteration) Erosion homedfr:M_ImageMorph
		
				if(param.allow_subset==0)
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea)/FILL stats :M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea) stats :M_ImageMorph
				endif
				
				ipImageProcAddDetectedEdge(homedfr:outerEdge)
		
				SetDataFOlder ::
				NewDataFolder /O/S innerEdge
		
				ImageMorphology /E=4 /I=(param.dialation_iteration) Dilation homedfr:M_ImageMorph
		
				if(param.allow_subset==0)
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea)/FILL stats :M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea) stats :M_ImageMorph
				endif
				
				ipImageProcAddDetectedEdge(homedfr:innerEdge)
				
				SetDataFolder ::
				
			while(roi_counts>=0)
		catch
			Variable err=GetRTError(0)
			if(err!=0)
				print "Error: ", GetErrMessage(err)
				err=GetRTError(1)
			endif
		endtry
	endfor
	SetDataFolder savedDF
End

