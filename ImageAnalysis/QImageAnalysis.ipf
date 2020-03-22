#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "QingLabTools"
	Submenu "ImageAnalysis"
		"Load File...", qipLoadFile("")
		"Display Image...", qipDisplayImage("")
	End
End

Function qipLoadFile(String name) //Load image file
//This will try to identify the type of image file and use proper function to load it
	Variable refNum=0
	String fileFilters = "Image Movies (*.tif, *.gif):.tif,.gif;"
	String message="Please select the image to load"
	
	if(strlen(name)==0)
		Open /D /R /F=fileFilters /M=message refNum
		String fullPath=S_fileName
	else
		fullPath=name
	endif
	
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
		String wname=qipLoadTIFFImageStack(fullPath)
		break
	default:
		print "File type not recognized/supported."
		break
	endswitch
End

//The following user data tags are/should be defined for all windows with this hook function
//PANELNAME : name of panel, first defined in qipEnableHook, used when values of controls in panel are needed
//PANELVISIBLE : whether panel is invisible or not, first defined in qipEnableHook, used only in qipHookFunction
//
//IMAGENAME : name of image wave, first defined in qipDisplayImage, not always defined if qipEnableHook is 
//				used only, in which case, the following values related to image will not be defined either.
//YAXISPOLARITY : polarity of image axis, first defined in qipDisplayImage, not always defined if qipEnableHook is used only
//FRAMENAME : the frame wave (extracted single frame from image wave) name, first defined in qipDisplayImage
//FRAMEIDX : the index of frame extracted from image wave, first defined in qipDisplayImage
//IXAXISNAME : the name of the xaxis for image, defined first in qipDisplayImage, used in qipHookFunction and Redraw functions
//IYAXISNAME : the name of the yaxis for image, defined first in qipDisplayImage, used in qipHookFunction and Redraw functions
//
//BASENAME : the name used for generating derived names. If IMAGENAME is defined, it will be used as the base.
//				 Otherwise, will use the name of the graph as the basename. This will be defined first in 
//				 qipEnableHook, and used everywhere else.
//
//ANALYSISDF : the name of datafolder for storing analysis results. It is first defined in qipEnableHook function
//
//ACTIVETRACE : the trace used for displaying information in the panel defined and changed by 
//					qipHookFunction whenever the mouse is clicked
//TXAXISNAME : the name of the xaxis of the active trace, updated in qipHookFunction
//TYAXISNAME : the name of the yaxis of the active trace, updated in qipHookFunction
//
//NEWROI : user request to define ROI region
//ROISTATUS : status of tracking ROI traces, defined and changed in qipHookFunction, if this is set, a ROI is being defined
//ROI_CURRENTTRACENAME : name of the current ROI as user defines new components, used only in qipHookFunction and when clear all ROI
//ROI_ALLTRACENAME : name of already defined ROI, first checked and defined in qipHookFunction, used elsewhere
//
//ROIAVAILABLE : status of ROI. If ROI has been defined, this will be value 1. This value is first defined
//					  in qipEnableHook, and will be cleared to 0 in qipClearAllROI function
//ROI_XAXISNAME : xaxis name for ROI redraw, defined and changed in qipHookFunction, used in redraw functions
//ROI_YAXISNAME : yaxis name for ROI redraw, defined and changed in qipHookFunction, used in redraw functions
//
//
//TRACEEDITSTATUS: set in qipHookFunction, indicate whether trace is being edited by mouse clicks. Trace edit will start
//						if (1) not in the new ROI mode (NEWROI is set to 0), and (2) both ctrl and shift key is pressed when mouse clicks
//						left click will move the hitpoint of the trace to the new position. mouse move will drag the point too
//						right click will delete the point. For ROI for every frame if deletion is on a line of ROI, the point is removed. 
//						if deletion is on	a point set ROI, the point is set to NaN. This behavior is to make sure that the number of points
//						is kept the same before and after edition to keep tags consistent.
//TRACEEDITHITPOINT: set in qipHookFunction, records the hit point by the mouse
//TRACEMODIFIED: this is set in qipHookFunction, indicating that in the graph there are traces that are modified so that when
//						changing frame index, the user will be notified to decide if changes should be saved/updated
// To enable a trace for edit in a graph, the trace will need to have note string defined including the following information:
//      MODIFYFUNC : name of user function that will decide how to fill-in the new coordinates. For user defined traces, the user should
//						 use the prototype function qipUFP_MODIFYFUNC(Wave wave_for_mod, Variable index, Variable new_x, Variable new_y, Variable flag)
//						 where flag is set to -1 for deletion operation. The function should return 0 if the modification does not need
//						 to be saved when frame is changed, otherwise, should return 1 if modification should be updated later.
//      SAVEFUNC : name of user function that will decide how to save/update the changed trace. For user defined traces, the user
//						should use the prototype function qipUFP_SAVEFUNC(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
//      NEED_SAVE_IF_MODIFIED : flag to indicate if trace has been modified, does it need save before frame index is changed.
//										  this value need to be 1 for proper update. otherwise all modification of trace will be lost when
//										  frame index changes and traces updated by the frame-specific content
//      MODIFIED: this should be set by the user function defined by MODIFYFUNC. this is used as a flag to tag traces that are modified

Function qipPrepAnalysisDFNames(String graphname, String & imageName, String & baseName, String & analysisDF)
//this function will help to setup the basic structure of analysis data folder and
//base names for generating other state variables for the graph and image
//if image name is provided, it will be saved to the graph window, otherwise it will
//be read from the graph window and used for setting basenames.
//if image name is not present either way, the graph name will be used for setting up names.
	if(WinType(graphname)!=1)
		print "The wrong type of window is used when calling PrepAnalysisDFName. Graph name was: ", graphname
		return -1
	endif
	
	DFREF savedDF=GetDataFolderDFR()
	try
		SetDataFolder root:
		
		if(strlen(imageName)==0)
			imageName=GetUserData(graphname, "", "IMAGENAME")
		else
			SetWindow $graphname userdata(IMAGENAME)=imageName
		endif
		baseName=graphname
		if(strlen(imageName)>0)
			baseName=imageName+"."+graphname
		endif
		
		analysisDF=qipGenerateDerivedName(baseName, ".DF")
		String uniqueDF=qipGetShortNameOnly(analysisDF)
		uniqueDF=ReplaceString("'", uniqueDF, "")
		uniqueDF=UniqueName(uniqueDF, 11, 0) //find unique name for datafolder
		
		analysisDF=qipGetPathNameOnly(baseName)+":"+PossiblyQuoteName(uniqueDF)
		
		NewDataFolder /O $analysisDF
		SetWindow $graphname userdata(ANALYSISDF)=analysisDF
		print "DataFolder ", analysisDF, " created."
		
		baseName=analysisDF+":"+qipGetShortNameOnly(baseName)
		SetWindow $graphname userdata(BASENAME)=baseName
	catch
		Variable err=GetRTError(1)
	endtry
	SetDataFolder savedDF
End

Function qipEnableHook(String graphname)
	String panelName=graphname+"_PANEL"

	NewPanel /EXT=0 /HOST=$graphname /K=2 /W=(0, 0, 200, 230) /N=$(panelName)
	panelName=graphname+"#"+S_Name //the actual name generated
	SetWindow $graphname userdata(PANELNAME)=panelName
	SetWindow $graphname userdata(PANELVISIBLE)="1"
	SetWindow $graphname userdata(ROIAVAILABLE)="0"
	
	String imgName=GetUserData(graphname, "", "IMAGENAME")
	String baseName=GetUserData(graphname, "", "BASENAME")
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	if(strlen(baseName)==0 || strlen(analysisDF)==0 || DataFolderExists(analysisDF)==0)
		qipPrepAnalysisDFNames(graphname, imgName, basename, analysisDF)
	endif
	
	qipGraphPanelResetControls(panelName)
	qipGenerateOverlayColorTables(graphname)
	SetWindow $graphname hook(qipHook)=qipHookFunction
End

Function qipGenerateOverlayColorTables(String graphname)
	DFREF savedDF=GetDataFolderDFR()
	try
		String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
		NewDataFolder /O/S $analysisDF
		ColorTab2Wave Red
		Rename M_colors, M_ColorTableRED
		Wave M_ColorTableRED=:M_ColorTableRED
		ColorTab2Wave Green
		Rename M_colors, M_ColorTableGREEN
		Wave M_ColorTableGREEN=:M_ColorTableGREEN
		ColorTab2Wave Blue
		Rename M_colors, M_ColorTableBLUE
		Wave M_ColorTableBLUE=:M_ColorTableBLUE
		ColorTab2Wave Grays
		Rename M_colors, M_ColorTableGRAY
		Wave M_ColorTableGRAY=:M_ColorTableGRAY
		
		InsertPoints /M=1 3, 1, M_ColorTableRED, M_ColorTableGREEN, M_ColorTableBLUE, M_ColorTableGRAY
		M_ColorTableRED[][3]=(1-QIP_ALPHA_RED)*65535
		M_ColorTableGREEN[][3]=(1-QIP_ALPHA_GREEN)*65535
		M_ColorTableBLUE[][3]=(1-QIP_ALPHA_BLUE)*65535
		M_ColorTableGRAY[][3]=65535
	catch
	endtry
	SetDataFolder savedDF
End

Function qipGraphPanelResetControls(String panelName)
	String cordstr="x: , y:"
	String zval="val:"
	String frameidxstr=""
	SetVariable xy_cord win=$panelName, pos={2,10}, bodywidth=200, value=_STR:(cordstr), noedit=1
	SetVariable z_value win=$panelName, pos={2,30}, bodywidth=200, value=_STR:(zval), noedit=1
	SetVariable frame_idx win=$panelName, pos={2,50}, bodywidth=185, value=_STR:(frameidxstr), noedit=1
	Button goto_frameidx win=$panelName, pos={185,50}, size={15,15}, title="#", proc=qipGraphPanelBtnGotoFrame
 
	CheckBox new_roi, win=$panelName, pos={2, 70}, bodywidth=50, title="New ROI",proc=qipGraphPanelCbRedraw
	CheckBox enclosed_roi, win=$panelName, pos={50, 70}, bodywidth=50, title="Enclosed",proc=qipGraphPanelCbRedraw
	
	Button save_roi, win=$panelName, pos={0, 90}, size={100, 20}, title="Save ROI To Frame...",proc=qipGraphPanelBtnSaveROIToFrame
	Button copy_roi, win=$panelName, pos={0, 110}, size={100,20}, title="Copy ROI From...",proc=qipGraphPanelBtnCopyROIFrom
	Button clear_roi, win=$panelName, pos={0, 130}, size={100, 20}, title="Clear All ROI",proc=qipGraphPanelBtnClearAllROI
	Button imgproc_findobj, win=$panelName, fColor=(0,0,32768), pos={0, 150}, size={100,20}, title="Identify Objects",proc=qipGraphPanelBtnEdgeDetect
	SetVariable sv_objidx,win=$panelName,title="ObjIndex",pos={0, 170},size={100,20},value= _NUM:-1,limits={-1,inf,1},proc=qipGraphPanelSVObjIdx
	
	Button imgproc_CallUserfunc, win=$panelName, pos={0,210}, size={100,20}, title="Call User Function"
	
	PopupMenu popup_options win=$panelName, pos={100, 70}, size={100,20}, value="ROI Options;Image Layers;Trace Layers;",proc=qipGraphPanelPMOptions
	GroupBox gb_options  win=$panelName, pos={100,70}, size={100, 160}, title="" 
	
	//the following will be with popup menu option 1: ROI options
	CheckBox show_userroi, win=$panelName, pos={105,90}, bodywidth=50, title="Show global ROI",proc=qipGraphPanelCbRedraw
	
	GroupBox gb_frameroi, win=$panelName, pos={102,105}, size={95, 35}, title="Frame ROI"
	CheckBox show_dot, win=$panelName, pos={105,120}, bodywidth=30, title="Dot",proc=qipGraphPanelCbRedraw
	CheckBox show_tag, win=$panelName, pos={135,120}, bodywidth=30, title="Tag",proc=qipGraphPanelCbRedraw
	CheckBox show_line, win=$panelName, pos={165,120}, bodywidth=30, title="Line",proc=qipGraphPanelCbRedraw
	
	GroupBox gb_edges, win=$panelName, pos={102,140}, size={95, 35}, title="Obj Edges"
	Checkbox show_edgesI, win=$panelName, pos={105,155}, bodywidth=30, title="I",proc=qipGraphPanelCbRedraw
	Checkbox show_edgesM, win=$panelName, pos={135,155}, bodywidth=30, title="M",proc=qipGraphPanelCbRedraw
	Checkbox show_edgesO, win=$panelName, pos={165,155}, bodywidth=30, title="O",proc=qipGraphPanelCbRedraw
	
	Button imgproc_pickobjs, win=$panelName, pos={102, 180}, size={95, 20}, title="Track single obj...",proc=qipGraphPanelBtnPickObjs

	//the following will be with popup menu option 2: Image Layers
	Button imgproc_addimglayer_GRAY, win=$panelName, pos={102, 90}, size={95,20}, title="Set Main Channel", disable=1, proc=qipGraphPanelBtnSetImageLayer
	Button imgproc_addimglayer_r, win=$panelName, pos={102, 120}, size={95,20}, title="Set Red Chn Overlay", disable=1, proc=qipGraphPanelBtnSetImageLayer
	Button imgproc_addimglayer_g, win=$panelName, pos={102, 140}, size={95,20}, title="Set Green Chn Overlay", disable=1, proc=qipGraphPanelBtnSetImageLayer
	Button imgproc_addimglayer_b, win=$panelName, pos={102, 160}, size={95,20}, title="Set Blue Chn Overlay", disable=1, proc=qipGraphPanelBtnSetImageLayer
	
	ControlInfo /W=$panelName popup_options
	qipGraphPanelUpdateOptionCtrls(panelName, V_Value)
End

Function qipDisplayImage(String wname, [Variable bg_r, Variable bg_g, Variable bg_b])
	if(strlen(wname)==0)
		String imgselection=WaveList("*", ";", "DIMS:3;WAVE:0;")
		imgselection+=WaveList("*", ";", "DIMS:2;WAVE:0;")
		PROMPT wname, "Image wave:", popup, imgselection
		DoPrompt "Select a image:", wname
		if(V_flag!=0)
			return -1
		endif
	endif

	Wave w=$wname
	if(WaveExists(w))
		String graphname=UniqueName("QIPGraph", 6, 0)
		wname=qipGetFullWaveName(wname)
		
		String tmpframeName=UniqueName("M_tmpImageFrame", 1, 0)
		Make /O /Y=(WaveType(w)) /N=(DimSize(w, 0), DimSize(w, 1)) $tmpframeName
		Wave tmpframe=$tmpframeName
		tmpframe[][]=w[p][q][0]

		NewImage /N=$graphname /K=0 tmpframe
		graphname=S_Name
		Variable ratio=DimSize(w, 1)/DimSize(w, 0)
		ModifyGraph height={Aspect, ratio}
				
		String baseName=""
		String analysisDF=""
		
		qipPrepAnalysisDFNames(graphname, wname, baseName, analysisDF)
		
		String frameName=qipGenerateDerivedName(baseName, ".f")
		Duplicate /O tmpframe, $frameName
		Wave newframe=$frameName
		ReplaceWave /W=$graphname image=$tmpframeName, $frameName
		KillWaves /Z $tmpframeName
				
		if(ParamIsDefault(bg_r))
			bg_r=0
		endif
		if(ParamIsDefault(bg_g))
			bg_g=0
		endif
		if(ParamIsDefault(bg_b))
			bg_b=0
		endif
		DrawAction /W=$graphName /L=UserBack delete
		SetDrawLayer /W=$graphName UserBack
		SetDrawEnv /W=$graphName fillbgc= (bg_r,bg_g,bg_b),fillfgc= (bg_r,bg_g,bg_b)
		DrawRect /W=$graphName 0, 0, 1, 1
	
		SetWindow $graphname userdata(IMAGENAME)=wname
		SetWindow $graphname userdata(FRAMENAME)=frameName
		SetWindow $graphname userdata(FRAMEIDX)="0"
		SetWindow $graphname userdata(YAXISPOLARITY)="1"

		String imginfo=ImageInfo(graphname, StringFromList(ItemsInList(frameName, ":")-1, frameName, ":"), 0)
		String xaxisname=StringByKey("XAXIS", imginfo)
		String yaxisname=StringByKey("YAXIS", imginfo)
		SetWindow $graphname userdata(IXAXISNAME)=xaxisname
		SetWindow $graphname userdata(IYAXISNAME)=yaxisname
		
		qipEnableHook(graphname)
	endif
End

Function /S qipLoadTIFFImageStack(String filename) //Load TIFF file
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
		ImageLoad /Q /C=(total_images) /S=(start_idx) /LR3D /N=$wname /T=TIFF filename
		return StringFromList(0, S_waveNames)
	else
		return ""
	endif
End


Function qipGraphPanelAddTraceByAxis(String graphName, Wave trace, [Variable r, Variable g, Variable b, Variable alpha, Variable show_marker, Variable mode, Variable redundantOK])
	Variable trace_drawn=0
	String xaxisname=GetUserData(graphName, "", "ROI_XAXISNAME")
	String yaxisname=GetUserData(graphName, "", "ROI_YAXISNAME")
	
	if(strlen(xaxisname)==0 || strlen(yaxisname)==0)
		return 0
	endif
	
	String xaxtype=StringByKey("AXTYPE", AxisInfo(graphName, xaxisname))
	String yaxtype=StringByKey("AXTYPE", AxisInfo(graphName, yaxisname))
	String wname=NameOfWave(trace)

	String trList=TraceNameList(graphName, ";", 1)
	String wbasename=qipGetShortNameOnly(wname)
	
	if(!WaveExists(trace))
		return 0
	endif
	
	Variable trIdx=WhichListItem(wbasename, trList)
	
	if(cmpstr(xaxtype, "bottom")==0)
		if(cmpstr(yaxtype, "left")==0)			
			if(redundantOK==1 || trIdx<0)
				AppendToGraph /W=$(graphName) /B=$xaxisname /L=$yaxisname trace[][1] vs trace[][0]
				trace_drawn=1
			elseif(trIdx>=0)
				trace_drawn=1
			endif
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
			if(redundantOK==1 || trIdx<0)
				AppendToGraph /W=$(graphName) /B=$xaxisname /R=$yaxisname trace[][1] vs trace[][0]
				trace_drawn=1
			elseif(trIdx>=0)
				trace_drawn=1
			endif
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
			if(redundantOK==1 || trIdx<0)
				AppendToGraph /W=$(graphName) /T=$xaxisname /L=$yaxisname trace[][1] vs trace[][0]
				trace_drawn=1
			elseif(trIdx>=0)
				trace_drawn=1
			endif
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
			if(redundantOK==1 || trIdx<0)
				AppendToGraph /W=$(graphName) /T=$xaxisname /R=$yaxisname trace[][1] vs trace[][0]
				trace_drawn=1
			elseif(trIdx>=0)
				trace_drawn=1
			endif
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
	
	return trace_drawn
End

Function qipGraphPanelAddImageByAxis(String graphName, Wave image, [Variable ctab, Variable minrgb, Variable maxrgb, Variable mask_r, Variable mask_g, Variable mask_b, Variable mask_alpha, Variable top])
	String xaxisname=GetUserData(graphName, "", "IXAXISNAME")
	String yaxisname=GetUserData(graphName, "", "IYAXISNAME")
	Variable image_displayed=1
	
	if(strlen(xaxisname)==0 || strlen(yaxisname)==0 || !WaveExists(image))
		return -1
	endif
	
	String xaxtype=StringByKey("AXTYPE", AxisInfo(graphName, xaxisname))
	String yaxtype=StringByKey("AXTYPE", AxisInfo(graphName, yaxisname))
	String wname=NameOfWave(image)
	String wbasename=PossiblyQuoteName(StringFromList(ItemsInList(wname, ":")-1, wname, ":"))

	String imglist=ImageNameList(graphName, ";")
	if(WhichListItem(wbasename, imglist)<0)
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
	
	String colortabstr=GetUserData(graphName, "", "ANALYSISDF")
	if(!ParamIsDefault(ctab))
		switch(ctab)
		case 1: //red
			colortabstr+=":M_ColorTableRED"
			break
		case 2: //green
			colortabstr+=":M_ColorTableGREEN"
			break
		case 3: //blue
			colortabstr+=":M_ColorTableBLUE"
			break
		case 4: //gray
			colortabstr+=":M_ColorTableGRAY"
			break
		default:
			ctab=0
			break
		endswitch
	else
		ctab=0
	endif
	
	if(image_displayed==1)
		if(!ParamIsDefault(mask_r) && !ParamIsDefault(mask_g) && !ParamIsDefault(mask_b) && !ParamIsDefault(mask_alpha))
			ModifyImage /W=$(graphName) $wbasename eval={0,mask_r,mask_g,mask_b,mask_alpha},eval={255,0,0,0,0},explicit=1
		endif
		if(ctab>0)
			ModifyImage /W=$(graphName) $wbasename ctab={,,$colortabstr,0},minRGB=NaN,maxRGB=0
		endif
		if(!ParamIsDefault(minrgb))
			ModifyImage /W=$(graphName) $wbasename minRGB=minrgb
		endif
		if(!ParamIsDefault(maxrgb))
			ModifyImage /W=$(graphName) $wbasename maxRGB=maxrgb
		endif
		if(!ParamIsDefault(top) && top==1 && ItemsInList(ImageNameList(graphName, ";"))>1)
			ReorderImages /W=$(graphName) _back_, {$wbasename}
		endif
	endif
End

Function qipGraphPanelPrepRedrawEdges(Variable show_edges, Variable objidx, Variable edgeType, Wave ROI2InfoIndex, String redrawEdgeName, string saveFuncName)
//this function will assume that you are in the folder of the frame
	if(show_edges)
		String postfix=""
		switch(edgeType)
		case 1: //middle
			postfix=".M"
			break
		case 2: //inner
			postfix=".I"
			break
		case 3: //outer
			postfix=".O"
			break
		default:
			break
		endswitch
		
		if(objidx>=0 && objidx<DimSize(ROI2InfoIndex, 0))
		//edge of the selected point ROI obj will be shown, if exists/properly extracted by EdgeDetection function
			String roiEdgeName=":ROI:PointROIObjEdges:"+PossiblyQuoteName("W_ROIBoundary"+num2istr(objidx)+postfix)
			
			if(WaveExists($roiEdgeName) && WaveExists(ROI2InfoIndex)) 
				//the corresponding boundary has been copied to the PointROIObjEdges folder
				Duplicate /O $roiEdgeName, $redrawEdgeName; AbortOnRTE
				Wave edge=$redrawEdgeName
				String wavenote=note(edge)
				wavenote=ReplaceStringByKey("MODIFYFUNC", wavenote, "qipUFP_BoundaryLineModifier") //for dots, we will not delete points, only fill in NaN for deletion
				wavenote=ReplaceStringByKey("NEED_SAVE_IF_MODIFIED", wavenote, "1") //for frame specific ROIs we need specific function for update changes
				wavenote=ReplaceStringByKey("OBJECT_INDEX", wavenote, num2istr(objidx))
				wavenote=ReplaceStringByKey("SAVEFUNC", wavenote, saveFuncName)
				Note /K edge, wavenote; AbortOnRTE
			endif
		else
		//all edges will be shown
			Variable i
			for(i=0; i<DimSize(ROI2InfoIndex, 0); i+=1)
				String boundaryWaveName=":ROI:PointROIObjEdges:"+PossiblyQuoteName("W_ROIBoundary"+num2istr(i)+postfix)
				Wave boundaryWave=$boundaryWaveName
				if(WaveExists(boundaryWave))
					if(i==0)
						Duplicate /O boundaryWave, $redrawEdgeName; AbortOnRTE
					else
						Wave edge=$redrawEdgeName
						Variable startp=DimSize(edge, 0)
						InsertPoints /M=0 DimSize(edge, 0), DimSize(boundaryWave, 0)+1, edge
						edge[startp][]=NaN
						startp+=1
						edge[startp,][]=boundaryWave[p-startp][q]
					endif
				endif
			endfor
			Note /K $redrawEdgeName; AbortOnRTE
		endif
	else
	//no edges are shown
		Make /O /N=(1, 2) $redrawEdgeName=NaN; AbortOnRTE
		Note /K $redrawEdgeName; AbortOnRTE
	endif	
End

Function qipGraphPanelRedrawEdges(String graphName)
	Variable i, j
	String baseName=GetUserData(graphName, "", "BASENAME")
	String analysisDF=GetUserData(graphName, "", "ANALYSISDF")
	String imgName=GetUserData(graphName, "", "IMAGENAME")
	String panelName=GetUserData(graphName, "", "PANELNAME")
	Variable frameidx=str2num(GetUserData(graphName, "", "FRAMEIDX"))
	
	Wave imgw=$imgName
	
	Variable show_edgesI=str2num(GetUserData(graphName, "", "SHOW_EDGES_INNER"))
	Variable show_edgesM=str2num(GetUserData(graphName, "", "SHOW_EDGES_MIDDLE"))
	Variable show_edgesO=str2num(GetUserData(graphName, "", "SHOW_EDGES_OUTER"))

	if(!WaveExists(imgw))
		return -1
	endif

	DFREF savedDF=GetDataFolderDFR()
	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		
		String edgeName=qipGenerateDerivedName(baseName, ".edge"); AbortOnRTE
		String outerEdgeName=qipGenerateDerivedName(baseName, ".outeredge"); AbortOnRTE
		String innerEdgeName=qipGenerateDerivedName(baseName, ".inneredge"); AbortOnRTE
		NewDataFolder /O/S $(num2istr(frameidx)); AbortOnRTE //getting into the datafolder for the frame

		String homeDFstr=GetDataFolder(1); AbortOnRTE
		
		Wave ROI2InfoIndex=$(homeDFstr+"ROI:W_PointROI2Info"); AbortOnRTE
		Wave edgeBoundary=$(homeDFstr+"DetectedEdges:W_Boundary"); AbortOnRTE
		Wave inneredgeBoundary=$(homeDFstr+"innerEdge:DetectedEdges:W_Boundary"); AbortOnRTE
		Wave outeredgeBoundary=$(homeDFstr+"outerEdge:DetectedEdges:W_Boundary"); AbortOnRTE
		
		ControlInfo /W=$panelName sv_objidx
		variable objidx=V_Value
		Variable startp, endp
		
		if(WaveExists(edgeBoundary) && WaveExists(inneredgeBoundary) && WaveExists(outeredgeBoundary))
			qipGraphPanelPrepRedrawEdges(show_edgesM, objidx, 1, ROI2InfoIndex, edgeName, "qipUFP_SavePointROIEdge_M")
			qipGraphPanelPrepRedrawEdges(show_edgesI, objidx, 2, ROI2InfoIndex, innerEdgeName, "qipUFP_SavePointROIEdge_I")
			qipGraphPanelPrepRedrawEdges(show_edgesO, objidx, 3, ROI2InfoIndex, outeredgeName, "qipUFP_SavePointROIEdge_O")
		else
			Make /O /N=(1, 2) $edgeName=NaN; AbortOnRTE
			Note /K $edgeName; AbortOnRTE
			Make /O /N=(1, 2) $innerEdgeName=NaN; AbortOnRTE
			Note /K $innerEdgeName; AbortOnRTE
			Make /O /N=(1, 2) $outerEdgeName=NaN; AbortOnRTE
			Note /K $outerEdgeName; AbortOnRTE
		endif

		qipGraphPanelAddTraceByAxis(graphName, $outeredgeName, r=0, g=65535, b=0, alpha=32768); AbortOnRTE
		qipGraphPanelAddTraceByAxis(graphName, $edgeName, r=65535, g=0, b=0, alpha=32768); AbortOnRTE
		qipGraphPanelAddTraceByAxis(graphName, $inneredgeName, r=0, g=0, b=65535, alpha=32768); AbortOnRTE

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

Function qipGraphPanelRedrawROI(String graphName)
	//check if the ROI traces are added to the graph already
	String roi_cur_traceName=GetUserData(graphName, "", "ROI_CURRENTTRACENAME")
	String roi_allName=GetUserData(graphName, "", "ROI_ALLTRACENAME")
	String analysisDF=GetUserData(graphName, "", "ANALYSISDF")
	Variable frameidx=str2num(GetUserData(graphName, "", "FRAMEIDX"))
	String baseName=GetUserData(graphName, "", "BASENAME")
	
	String panelName=GetUserData(graphName, "", "PANELNAME")
	
	ControlInfo /W=$panelName show_userroi
	Variable show_userroi=V_value

	Wave roi_cur_trace=$roi_cur_traceName
	Wave roi_all=$roi_allName
	String roi_cur_basename=qipGetShortNameOnly(roi_cur_traceName)
	String roi_all_basename=qipGetShortNameOnly(roi_allName)
	
	if(WaveExists(roi_all))
		String roinote=note(roi_all)
		roinote=ReplaceStringByKey("MODIFYFUNC", roinote, "qipUFP_BoundaryLineModifier") 
		roinote=ReplaceStringByKey("NEED_SAVE_IF_MODIFIED", roinote, "0") //for global ROIs the save is automatically done by modifier
		Note /K roi_all, roinote
	endif
	
	//current user ROI definitionis always shown
	if(strlen(roi_cur_traceName)>0)
		if(qipGraphPanelAddTraceByAxis(graphName, roi_cur_trace, r=0, g=32768, b=0, alpha=65535, show_marker=((43<<8)+(5<<4)+2), mode=4))
			ModifyGraph /W=$(graphName) offset($roi_cur_basename)={0,0}
		endif
	endif
	
	if(show_userroi) //existing record of user ROI is shown only when checkbox is true
		if(strlen(roi_allName)>0)
			if(qipGraphPanelAddTraceByAxis(graphName, roi_all, r=32768, g=0, b=0, alpha=65535, show_marker=((43<<8)+(5<<4)+2), mode=4))
				ModifyGraph /W=$(graphName) offset($roi_all_basename)={0,0}
			endif
		endif
	else
		if(strlen(roi_allName)>0)
			RemoveFromGraph /W=$graphname /Z $qipGetShortNameOnly(roi_allName)
		endif
	endif
	
	//ROI specific to the current frame
	variable show_dot=str2num(GetUserData(graphname, "", "ROISHOW_DOT"))
	variable show_line=str2num(GetUserData(graphname, "", "ROISHOW_LINE"))
	variable show_tag=str2num(GetUserData(graphname, "", "ROISHOW_TAG"))
		
	if(strlen(analysisDF)>0 && frameidx>=0)
		DFREF savedDF=GetDataFolderDFR()
		try //draw ROI for frames
			SetDataFolder $analysisDF; AbortOnRTE
			NewDataFolder /O/S :$(num2str(frameidx)); AbortOnRTE
			NewDataFolder /O/S :ROI; AbortOnRTE
			
			String dotwaveName=qipGenerateDerivedName(baseName, ".f.roi.dot"); AbortOnRTE
			String dotwaveBaseName=qipGetShortNameOnly(dotwaveName); AbortOnRTE
			
			String linewaveName=qipGenerateDerivedName(baseName, ".f.roi.line"); AbortOnRTE
			String linewaveBaseName=qipGetShortNameOnly(linewaveName); AbortOnRTE
			
			String tagwave=qipGenerateDerivedName(baseName, ".f.roi.tags"); AbortOnRTE
			
			Wave wdot=:W_PointROI; AbortOnRTE //wdot now should point to the dot ROIs of the frame (in the datafolder for the frame)
			Wave wline=:W_RegionROIBoundary; AbortOnRTE //same as above for the line ROIs
			
			ControlInfo /W=$panelName sv_objidx
			Variable objidx=V_Value
			Variable maxobjidx=DimSize(wdot, 0)-1
			if(objidx>maxobjidx)
				SetVariable sv_objidx, win=$panelName, value= _NUM:-1,limits={-1,maxobjidx,1}
			else
				SetVariable sv_objidx, win=$panelName, value= _NUM:V_Value,limits={-1,maxobjidx,1}
			endif
			
			if(WaveExists(wdot))
				Duplicate /O wdot, $dotwaveName; AbortOnRTE //copy to the root folder of the frame
			else
				Make /O/D/N=(1,2) $dotwaveName=NaN; AbortOnRTE //or just make a blank wave for the frame
			endif
			
			Wave framewdot=$dotwaveName; AbortOnRTE
			
			if(show_dot && WaveExists(framewdot))				
				qipGraphPanelAddTraceByAxis(graphName, framewdot, r=0, g=0, b=65535, alpha=65535, show_marker=((19<<8)+(2<<4)+1), mode=3); AbortOnRTE
				ModifyGraph /W=$(graphName) offset($dotwaveBaseName)={0,0}
				roinote=note(framewdot)
				roinote=ReplaceStringByKey("MODIFYFUNC", roinote, "qipUFP_BoundaryPointModifier") //for dots, we will not delete points, only fill in NaN for deletion
				roinote=ReplaceStringByKey("NEED_SAVE_IF_MODIFIED", roinote, "1") //for frame specific ROIs we need specific function for update changes
				roinote=ReplaceStringByKey("SAVEFUNC", roinote, "qipUFP_saveDotROI")
				Note /K framewdot, roinote
			else
				RemoveFromGraph /W=$graphname /Z $dotwaveBaseName; AbortOnRTE				
			endif			
			String taglist=AnnotationList(graphName); AbortOnRTE
			DeleteAnnotations /A/W=$graphName; AbortOnRTE
			if(show_tag && WaveExists(framewdot))
				Variable i
				for(i=0; i<DimSize(framewdot, 0); i+=1)
					if(objidx<0 || i==objidx)
						Tag /W=$graphName /C/N=$("FRAME_ROI_TAG"+num2istr(i))/B=(65535,65535,65535)/G=(0,0,65535)/I=1 $dotwaveBaseName,i,num2istr(i); AbortOnRTE
					endif
				endfor
			endif

			if(WaveExists(wline))
				Duplicate /O wline, $linewaveName; AbortOnRTE
			else
				Make /O/D/N=(1,2) $linewaveName=NaN; AbortOnRTE
			endif
			Wave framelinewave=$linewaveName; AbortOnRTE
			
			
			if(show_line && WaveExists(framelinewave))				
				qipGraphPanelAddTraceByAxis(graphName, framelinewave, r=0, g=0, b=65535, alpha=65535, mode=0); AbortOnRTE
				ModifyGraph /W=$(graphName) offset($linewaveBaseName)={0,0}
				roinote=note(framelinewave)
				roinote=ReplaceStringByKey("MODIFYFUNC", roinote, "qipUFP_BoundaryLineModifier")
				roinote=ReplaceStringByKey("NEED_SAVE_IF_MODIFIED", roinote, "1") //for frame specific ROIs we need specific function for update changes
				roinote=ReplaceStringByKey("SAVEFUNC", roinote, "qipUFP_saveLineROI")
				Note /K framelinewave, roinote
			else
				RemoveFromGraph /W=$graphname /Z $linewaveBaseName; AbortOnRTE
			endif
		catch
			Variable err=GetRTError(1)
		endtry
		
		SetDataFolder savedDF
	endif
End

Function qipGraphPanelRedrawAll(String graphName)
	qipGraphPanelRedrawImage(graphName)
	qipGraphPanelRedrawROI(graphName)
	qipGraphPanelRedrawEdges(graphName)
End

Function qipGraphPanelRedrawImage(String graphName)
	Wave img=$GetUserData(graphName, "", "IMAGENAME")
	Wave frame=$GetUserData(graphName, "", "FRAMENAME")
	Variable frameidx=str2num(GetUserData(graphName, "", "FRAMEIDX"))
	
	//main channel image update
	qipGraphPanelUpdateFrameWave(img, frame, frameidx)
	String usrFunc=GetUserData(graphName, "", "IMAGE_USERFUNC")
	if(strlen(usrFunc)>0)
		FUNCREF qipUFP_IMGFUNC usrFuncRef=$usrFunc
		usrFuncRef(img, frame, graphname, frameidx, QIPUFP_IMAGEFUNC_MAINIMAGE+QIPUFP_IMAGEFUNC_REDRAWUPDATE)
	endif
	
	String overlayFrameName_r="", overlayFrameName_g="", overlayFrameName_b=""
	Variable flag_r=0, flag_g=0, flag_b=0
	
	//red channel overlay update
	Wave overlayImage=$GetUserData(graphName, "", "OVERLAY_IMAGE_RED")
	usrFunc=GetUserData(graphName, "", "OVERLAY_IMAGE_RED_USERFUNC")
	overlayFrameName_r=GetUserData(graphname, "", "OVERLAY_IMAGE_RED_FRAMENAME")
	if(WaveExists(overlayImage))
		FUNCREF qipUFP_IMGFUNC usrFuncRef=$usrFunc
		//if usrFuncRef is valid, it will called, otherwise, the default function will be called
		//which will just copy the corresponding frame
		Wave overlayFrame_r=$overlayFrameName_r
		if(!WaveExists(overlayframe_r) || (DimSize(overlayframe_r, 0)!=DimSize(overlayImage, 0) || DimSize(overlayframe_r, 1)!=DimSize(OverlayImage, 1)))
			Make /O/N=(DimSize(overlayImage, 0), DimSize(overlayImage, 1))/Y=(WaveType(overlayImage)) $overlayFrameName_r
			Wave overlayFrame_r=$overlayFrameName_r
		endif
		usrFuncRef(overlayImage, overlayFrame_r, graphname, frameidx, QIPUFP_IMAGEFUNC_APPENDIXIMAGE_RED + QIPUFP_IMAGEFUNC_REDRAWUPDATE)
		flag_r=1
	else
		if(strlen(overlayFrameName_r)>0)
			RemoveImage /W=$graphName /Z $(qipGetShortNameOnly(overlayFrameName_r))
		endif
	endif
	
	//green channel overlay update
	Wave overlayImage=$GetUserData(graphName, "", "OVERLAY_IMAGE_GREEN")
	usrFunc=GetUserData(graphName, "", "OVERLAY_IMAGE_GREEN_USERFUNC")
	overlayFrameName_g=GetUserData(graphname, "", "OVERLAY_IMAGE_GREEN_FRAMENAME")
	if(WaveExists(overlayImage))
		FUNCREF qipUFP_IMGFUNC usrFuncRef=$usrFunc
		//if usrFuncRef is valid, it will called, otherwise, the default function will be called
		//which will just copy the corresponding frame
		Wave overlayFrame_g=$overlayFrameName_g
		if(!WaveExists(overlayframe_g) || (DimSize(overlayframe_g, 0)!=DimSize(overlayImage, 0) || DimSize(overlayframe_g, 1)!=DimSize(OverlayImage, 1)))
			Make /O/N=(DimSize(overlayImage, 0), DimSize(overlayImage, 1))/Y=(WaveType(overlayImage)) $overlayFrameName_g
			Wave overlayFrame_g=$overlayFrameName_g
		endif
		usrFuncRef(overlayImage, overlayFrame_g, graphname, frameidx, QIPUFP_IMAGEFUNC_APPENDIXIMAGE_GREEN + QIPUFP_IMAGEFUNC_REDRAWUPDATE)
		flag_g=1
	else
		if(strlen(overlayFrameName_g)>0)
			RemoveImage /W=$graphName /Z $(qipGetShortNameOnly(overlayFrameName_g))
		endif
	endif
	
	//blue channel overlay update
	Wave overlayImage=$GetUserData(graphName, "", "OVERLAY_IMAGE_BLUE")
	usrFunc=GetUserData(graphName, "", "OVERLAY_IMAGE_BLUE_USERFUNC")
	overlayFrameName_b=GetUserData(graphname, "", "OVERLAY_IMAGE_BLUE_FRAMENAME")
	if(WaveExists(overlayImage))
		FUNCREF qipUFP_IMGFUNC usrFuncRef=$usrFunc
		//if usrFuncRef is valid, it will called, otherwise, the default function will be called
		//which will just copy the corresponding frame
		
		Wave overlayFrame_b=$overlayFrameName_b
		if(!WaveExists(overlayframe_b) || (DimSize(overlayframe_b, 0)!=DimSize(overlayImage, 0) || DimSize(overlayframe_b, 1)!=DimSize(OverlayImage, 1)))
			Make /O/N=(DimSize(overlayImage, 0), DimSize(overlayImage, 1))/Y=(WaveType(overlayImage)) $overlayFrameName_b
			Wave overlayFrame_b=$overlayFrameName_b
		endif
		usrFuncRef(overlayImage, overlayFrame_b, graphname, frameidx, QIPUFP_IMAGEFUNC_APPENDIXIMAGE_BLUE + QIPUFP_IMAGEFUNC_REDRAWUPDATE)
		flag_b=1
	else
		if(strlen(overlayFrameName_b)>0)
			RemoveImage /W=$graphName /Z $(qipGetShortNameOnly(overlayFrameName_b))
		endif
	endif
	
	qipGraphPanelAddImageByAxis(graphName, frame, ctab=4, top=1)
	
	if(flag_b)
		qipGraphPanelAddImageByAxis(graphName, overlayFrame_b, ctab=3, top=1)
	endif
	if(flag_g)
		qipGraphPanelAddImageByAxis(graphName, overlayFrame_g, ctab=2, top=1)
	endif
	if(flag_r)
		qipGraphPanelAddImageByAxis(graphName, overlayFrame_r, ctab=1, top=1)
	endif
End

Function qipGraphPanelUpdateFrameWave(Wave img, Wave frame, Variable frameidx)	
	if(WaveExists(img) && WaveExists(frame))
		if(frameidx>=DimSize(img, 2))
			frameidx=DimSize(img, 2)-1
		endif
		if(numtype(frameidx)!=0 || frameidx<0)
			frameidx=0
		endif
		multithread frame[][]=img[p][q][frameidx]; AbortOnRTE
	endif
End

Function qipUFP_MODIFYFUNC(Wave wave_for_mod, Variable index, Variable new_x, Variable new_y, Variable flag)
	return 0
End


Function qipUFP_SAVEFUNC(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
	return 0
End

Function qipUFP_saveDotROI(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	
	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		NewDataFolder /O/S :$(num2istr(frameidx)); AbortOnRTE
		
		if(WaveExists(wave_for_save))
			NewDataFolder /O/S :ROI ; AbortOnRTE
			Duplicate /O wave_for_save, W_PointROI
		endif
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
end

Function qipUFP_SavePointROIEdge_M(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	
	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		NewDataFolder /O/S :$(num2istr(frameidx)); AbortOnRTE
		String wavenote=note(wave_for_save)
		Variable objidx=str2num(StringByKey("OBJECT_INDEX", wavenote))
		String roiEdgeNameM=qipGenerateDerivedName(":ROI:PointROIObjEdges:W_ROIBoundary", num2istr(objidx)+".M")

		if(WaveExists(wave_for_save))
			Duplicate /O wave_for_save, $roiEdgeNameM ; AbortOnRTE
		endif
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
end

Function qipUFP_SavePointROIEdge_I(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	
	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		NewDataFolder /O/S :$(num2istr(frameidx)); AbortOnRTE
		String wavenote=note(wave_for_save)
		Variable objidx=str2num(StringByKey("OBJECT_INDEX", wavenote))
		String roiEdgeNameI=qipGenerateDerivedName(":ROI:PointROIObjEdges:W_ROIBoundary", num2istr(objidx)+".I")

		if(WaveExists(wave_for_save))
			Duplicate /O wave_for_save, $roiEdgeNameI ; AbortOnRTE
		endif
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
end

Function qipUFP_SavePointROIEdge_O(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	
	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		NewDataFolder /O/S :$(num2istr(frameidx)); AbortOnRTE
		String wavenote=note(wave_for_save)
		Variable objidx=str2num(StringByKey("OBJECT_INDEX", wavenote))
		String roiEdgeNameO=qipGenerateDerivedName(":ROI:PointROIObjEdges:W_ROIBoundary", num2istr(objidx)+".O")

		if(WaveExists(wave_for_save))
			Duplicate /O wave_for_save, $roiEdgeNameO ; AbortOnRTE
		endif
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
end

Function qipUFP_saveLineROI(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	
	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		NewDataFolder /O/S :$(num2istr(frameidx)); AbortOnRTE
		
		if(WaveExists(wave_for_save))
			NewDataFolder /O/S :ROI ; AbortOnRTE
			Make /O /D /N=(1, 2) W_RegionROIIndex=NaN
			Make /O /D /N=(1, 2) W_RegionROIBoundary=NaN
			
			Variable startidx=0, endidx=0
			Variable len=0
			Variable cnt_regionIdx=0
			Variable cnt_regionStart=0
			Variable cnt_point=0
			Variable i
		
			do
				len=qipBoundaryGetNextGroup(wave_for_save, startidx, endidx); AbortOnRTE
		
				if(len>1)//single point will not be saved
					if(cnt_regionIdx!=0)//following insertion will need to have NaN space saved
						InsertPoints /M=0 DimSize(W_RegionROIIndex, 0), 1, W_RegionROIIndex; AbortOnRTE
						InsertPoints /M=0 DimSize(W_RegionROIBoundary, 0), len+1, W_RegionROIBoundary; AbortOnRTE
					else //first insertion has the first element as blank
						InsertPoints /M=0 DimSize(W_RegionROIBoundary, 0), len, W_RegionROIBoundary; AbortOnRTE
					endif
					W_RegionROIIndex[cnt_regionIdx][0]=cnt_regionStart; AbortOnRTE //boundary start point
					for(i=0; i<len && cnt_regionStart<DimSize(W_RegionROIBoundary, 0); cnt_regionStart+=1, i+=1)
						W_RegionROIBoundary[cnt_regionStart][0]=wave_for_save[startidx+i][0]; AbortOnRTE
						W_RegionROIBoundary[cnt_regionStart][1]=wave_for_save[startidx+i][1]; AbortOnRTE
					endfor
					W_RegionROIBoundary[cnt_regionStart][]=NaN; AbortOnRTE
					W_RegionROIIndex[cnt_regionIdx][1]=cnt_regionStart-1; AbortOnRTE //boundary end point
					cnt_regionStart+=1
					cnt_regionIdx+=1
				endif
		
				//find the next region/point
				startidx=endidx+1
				endidx=startidx
			while(len>0)
		endif
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
end

Function qipUFP_BoundaryLineModifier(Wave wave_for_mod, Variable index, Variable new_x, Variable new_y, Variable flag)
	Variable modify_flag=0
	Variable retVal=0
	try
		switch(flag)
		case 0: //just change the value
			wave_for_mod[index][0]=new_x; AbortOnRTE
			wave_for_mod[index][1]=new_y; AbortOnRTE
			modify_flag=1
			break
		case 1: //insert a point
			InsertPoints /M=0 index, 1, wave_for_mod; AbortOnRTE
			wave_for_mod[index][0]=new_x; AbortOnRTE
			wave_for_mod[index][1]=new_y; AbortOnRTE
			modify_flag=1
			break
		case -1: //delete the point
			DeletePoints /M=0 index, 1, wave_for_mod; AbortOnRTE
			modify_flag=1
			break
		default:
			break
		endswitch
		
		if(modify_flag)
			String wavenote=note(wave_for_mod); AbortOnRTE
			wavenote=ReplaceStringByKey("MODIFIED", wavenote, "1"); AbortOnRTE
			Note /K wave_for_mod, wavenote ; AbortOnRTE
			
			Variable needsave=str2num(StringByKey("NEED_SAVE_IF_MODIFIED", wavenote))
			
			if(needsave==1)
				retVal=1
			endif
		endif
	catch
		Variable err=GetRTError(1)
	endtry
	
	return retVal
End

Function qipUFP_BoundaryPointModifier(Wave wave_for_mod, Variable index, Variable new_x, Variable new_y, Variable flag)
	Variable modify_flag=0
	//point modifier will not allow inserting new points to keep index always the same
	try
		switch(flag)
		case -1: //for dots, we will just fill in NaN, instead of removing the dot because we do not want to change index order/number
			wave_for_mod[index][]=NaN; AbortOnRTE
			break
		default: //just change the value
			wave_for_mod[index][0]=new_x; AbortOnRTE
			wave_for_mod[index][1]=new_y; AbortOnRTE
			break
		endswitch
		
		String wavenote=note(wave_for_mod); AbortOnRTE
		wavenote=ReplaceStringByKey("MODIFIED", wavenote, "1"); AbortOnRTE
		Variable NEED_SAVE_IF_MODIFIED=str2num(StringByKey("NEED_SAVE_IF_MODIFIED", wavenote))
		
		if(NEED_SAVE_IF_MODIFIED==1)
			modify_flag=1
		endif
		
		Note /K wave_for_mod, wavenote ; AbortOnRTE
	catch
		Variable err=GetRTError(1)
	endtry
	
	return modify_flag
End

Function qipAddPointToCurrentROI(Wave roiw, Variable idx, Variable imgx, Variable imgy, 
											Variable tracex, Variable tracey, 
											String ixaxis, String iyaxis, 
											String txaxis, String tyaxis,
											String & xaxisname, String & yaxisname)
	Variable maxidx=DimSize(roiw, 0)
	Variable roi_newx=NaN, roi_newy=NaN
	Variable minresx=0, minresy=0
	
	if(NumType(imgx)==0 && NumType(imgy)==0)
		roi_newx=imgx
		roi_newy=imgy
		xaxisname=ixaxis
		yaxisname=iyaxis
		minresx=1
		minresy=1
	elseif(NumType(tracex)==0 && NumType(tracey)==0)
		roi_newx=tracex
		roi_newy=tracey
		xaxisname=txaxis
		yaxisname=tyaxis
	else
		xaxisname=""
		yaxisname=""
	endif
	
	if(numtype(roi_newx)==0 && numtype(roi_newy)==0)
		if(idx>=maxidx && maxidx>0)
			Variable lastx=roiw[maxidx-1][0]
			Variable lasty=roiw[maxidx-1][1]
			
			if(abs(roi_newx-lastx)>minresx || abs(roi_newy-lasty)>minresy)
				InsertPoints /M=0 maxidx, 1, roiw
		
				roiw[maxidx][0]=roi_newx
				roiw[maxidx][1]=roi_newy
			endif
		else
			roiw[idx][0]=roi_newx
			roiw[idx][1]=roi_newy
		endif
	endif
End

Function qipGraphPanelCallSaveFunc(String graphname, Variable frameidx)
	String tracelist=TraceNameList(graphname, ";", 1) //list only normal graph traces
	Variable i
	for(i=0; i<ItemsInList(tracelist); i+=1)
		Wave trW=TraceNametoWaveRef(graphname, StringFromList(i, tracelist))
		if(WaveExists(trW))
			String wavenote=note(trW)
			Variable modified=str2num(StringByKey("MODIFIED", wavenote))
			Variable needsave=str2num(StringByKey("NEED_SAVE_IF_MODIFIED", wavenote))
			
			if(modified==1 && needsave==1)							
				String saveFuncRef=StringByKey("SAVEFUNC", wavenote)
				FUNCREF qipUFP_SAVEFUNC usrFuncRef=$saveFuncRef
				usrFuncRef(trW, graphname, frameidx, 0)
			endif
		endif
	endfor
End

Function qipGraphPanelUpdateFrameIndex(String graphname, Wave imgw, Wave framew, Variable & frameidx, 
													Variable & trace_modified, Variable deltaIdx)
//this function will check if traces have been modified at the current frame, before changing the frame index to another one
//if traces are modified, then each trace will be evaluated to see if "MODIFIED" flag is set, if so, will check the flag
// "NEED_SAVE_IF_MODIFIED, if both are 1, then will call the function with its name stored in "SAVEFUNC"
	Variable change_frame=1

	if(trace_modified)
		DoAlert 2, "Traces on this frame has been modified, shall we save these changes accordingly?"
		switch(V_flag)
			case 1: //yes
				qipGraphPanelCallSaveFunc(graphname, frameidx)
				break
			case 2: //no
				break
			default: //cancel
				change_frame=0
				break
		endswitch
	endif
		
	if(WaveExists(imgw) && WaveExists(framew) && DimSize(imgw, 2)>0)		
		if(change_frame)
			if(deltaIdx<0)
				frameidx-=1
			else
				frameidx+=1
			endif

			if(frameidx<0)
				frameidx=DimSize(imgw, 2)-1
			endif
			if(frameidx>=DimSize(imgw, 2))
				frameidx=0
			endif
			trace_modified=0 //for new frame, reset the status of traces-need-saving
		endif
	else
		frameidx=0
	endif
End

Function qipHookFunction(s)
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

	Variable frameidx=str2num(GetUserData(s.winName, "", "FRAMEIDX"))
	Variable yaxispolarity=str2num(GetUserData(s.winName, "", "YAXISPOLARITY"))
	Variable roi_status=str2num(GetUserData(s.winname, "", "ROISTATUS"))
	
	Variable new_roi=str2num(GetUserData(s.winname, "", "NEWROI"))
	Variable enclosed_roi=str2num(GetUserData(s.winname, "", "ENCLOSEDROI"))
	
	Variable	trace_editstatus=str2num(GetUserData(s.winname, "", "TRACEEDITSTATUS"))
	Variable trace_hitpoint=str2num(GetUserData(s.winName, "", "TRACEEDITHITPOINT"))
	Variable trace_modified=str2num(GetUserData(s.winname, "", "TRACEMODIFIED"))
	Variable trace_edit_insert_flag=0
	Variable trace_edit_new_modification=0
	
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
		roi_cur_traceName=qipGenerateDerivedName(baseName, ".roi0")
		SetWindow $(s.winname), userdata(ROI_CURRENTTRACENAME)=roi_cur_traceName
	endif
	if(strlen(roi_allName)==0)
		roi_allName=qipGenerateDerivedName(baseName, ".roi")						
		SetWindow $(s.winname), userdata(ROI_ALLTRACENAME)=roi_allName
	endif
	
	String ixaxisname=GetUserData(s.winname, "", "IXAXISNAME")
	String iyaxisname=GetUserData(s.winname, "", "IYAXISNAME")
	
	String txaxisname=GetUserData(s.winname, "", "TXAXISNAME")
	String tyaxisname=GetUserData(s.winname, "", "TYAXISNAME")
	
	String roi_xaxisname=GetUserData(s.winname, "", "ROI_XAXISNAME")
	String roi_yaxisname=GetUserData(s.winname, "", "ROI_YAXISNAME")

	Variable imgx, imgy, tracex, tracey
	Variable update_image=0
	Variable update_trace=0
	
	String wavenote=""
	String modifyfuncName=""
	
	if(trace_modified)
		TextBox /W=$(s.winname)/C/N=TRACE_MODIFIED_FLAG/S=3/B=(65535,32768,32768)/A=LT/X=0/Y=0/V=1 "\\Z06\\Z08MODIFICATION \rNOT SAVED"
	else
		TextBox /W=$(s.winname)/C/N=TRACE_MODIFIED_FLAG/V=0
	endif
	
	switch(s.eventCode)
		case 3:
			if(new_roi==1) //when ROI is being defined, no effect for mouse down
				trace_editstatus=0
				hookResult=1
			elseif((s.eventMod&0xE)==0x8 || (s.eventMod&0xE)==0xA) //ctrl is down when clicking, or ctrl and shift are both down
				trace_editstatus=0
				//check conditions for starting edit
				traceInfoStr=TraceFromPixel(s.mouseLoc.h, s.mouseLoc.v, "")
				traceName=StringByKey("TRACE", traceInfoStr)
				traceHitStr=StringByKey("HITPOINT", traceInfoStr)

				if(strlen(traceName)>0)
					activetrace=traceName
					Wave w_active=TraceNameToWaveRef(s.winname, activetrace)
					trace_hitpoint=str2num(traceHitStr)
					if(WaveExists(w_active) && numtype(trace_hitpoint)==0 && trace_hitpoint>=0 && trace_hitpoint<DimSize(w_active, 0))						
						traceInfoStr=TraceInfo(s.winName, traceName, 0)
						txaxisname=StringByKey("XAXIS", traceInfoStr)
						tyaxisname=StringByKey("YAXIS", traceInfoStr)
						
						SetWindow $s.winName userdata(ACTIVETRACE)=(activetrace)
						SetWindow $s.winName userdata(TRACEEDITHITPOINT)=num2istr(trace_hitpoint)
						SetWindow $s.winName userdata(TXAXISNAME)=(txaxisname)
						SetWindow $s.winName userdata(TYAXISNAME)=(tyaxisname)
								
						if(strlen(txaxisname)>0 && strlen(tyaxisname)>0)
							wavenote=note(w_active)
							modifyfuncName=StringByKey("MODIFYFUNC", wavenote)
							FUNCREF qipUFP_MODIFYFUNC modifyfuncRef=$modifyfuncName
							
							if((s.eventMod&0xE)==0x8 && (s.eventMod&0x10)!=0) //ctrl and right click happens means delete
								tracex=NaN
								tracey=NaN
								trace_editstatus=0
								trace_edit_new_modification=modifyfuncRef(w_active, trace_hitpoint, tracex, tracey, -1)								
							else
								tracex=AxisValFromPixel(s.winname, txaxisname, s.mouseLoc.h)
								tracey=AxisValFromPixel(s.winname, tyaxisname, s.mouseLoc.v)
								trace_editstatus=1
								trace_edit_insert_flag= ((s.eventMod&0xE)==0xA) //if ctrl and shift are both down, insert
								trace_edit_new_modification=modifyfuncRef(w_active, trace_hitpoint, tracex, tracey, trace_edit_insert_flag)
							endif
							trace_modified=trace_modified || trace_edit_new_modification
						endif	//axis are correctly labelled
					endif //wave and point index are correct
				endif //trace is available at the point of mouse
				hookResult=1
			else
				trace_editstatus=0
			endif
			break
					
		case 4: //mouse moving
		case 5: //mouse up
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
			
			if(numtype(trace_editstatus)!=0 || trace_editstatus==0)
				//Not editing the trace, try to set axis names and ACTIVETRACE correctly			
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
				
				if((strlen(traceName)>0) && (s.eventCode==5) && ((s.eventMod&0x1E)==0))
					//simple mouse up on a trace with no key modifiers
		 			//the current trace at the pixel is set as active trace
		 			SetWindow $(s.winname) userdata(ACTIVETRACE)=traceName
		 		elseif(s.eventCode==5)
		 			SetWindow $(s.winname) userdata(ACTIVETRACE)=""
		 		endif
		 		trace_editstatus=0
		 	else
		 		//if trace is being edited
		 		traceInfoStr=TraceInfo(s.winName, activetrace, 0)
				txaxisname=StringByKey("XAXIS", traceInfoStr)
				tyaxisname=StringByKey("YAXIS", traceInfoStr)
				traceHitStr=GetUserData(s.winName, "", "TRACEEDITHITPOINT")
				trace_hitpoint=str2num(traceHitStr)
				
				if(strlen(txaxisname)>0 && strlen(tyaxisname)>0)
					tracex=AxisValFromPixel(s.winname, txaxisname, s.mouseLoc.h)
					tracey=AxisValFromPixel(s.winname, tyaxisname, s.mouseLoc.v)
				endif
				
				if(s.eventCode==5) //mouse up stops the edit status
					trace_editstatus=0
				else
					Wave w_active=TraceNameToWaveRef(s.winname, activetrace)
					if(WaveExists(w_active))
						wavenote=note(w_active)
						modifyfuncName=StringByKey("MODIFYFUNC", wavenote)
						FUNCREF qipUFP_MODIFYFUNC modifyfuncRef=$modifyfuncName
						
						if((s.eventMod&0x10)!=0 && (s.eventMod&0xE)==0x8) //ctrl + right click happens means delete
							tracex=NaN
							tracey=NaN
							trace_editstatus=0
							modifyfuncRef(w_active, trace_hitpoint, tracex, tracey, -1)								
						else
							tracex=AxisValFromPixel(s.winname, txaxisname, s.mouseLoc.h)
							tracey=AxisValFromPixel(s.winname, tyaxisname, s.mouseLoc.v)
							trace_editstatus=1
							trace_edit_insert_flag= ((s.eventMod&0xE)==0xA) //if ctrl and shift are both down, insert
							trace_edit_new_modification=modifyfuncRef(w_active, trace_hitpoint, tracex, tracey, trace_edit_insert_flag)
							trace_modified=trace_modified || trace_edit_new_modification
						endif
					endif
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
		 		
			if(s.eventCode==5 || (s.eventMod&0x1)!=0) //mouse up, or mouse moving with mouse key held down
		 		if(trace_editstatus==1)
		 			if((s.eventMod&0xE)!=0x8) //ctrl is released
		 				trace_editstatus=0
		 			endif
		 		elseif((s.eventMod&0x4)==0 && new_roi) //no alt or opt key held down
					Variable idx=-1
					
					if(roi_status!=1) //new line/dot is just being started
						update_trace=1 //traces need to be updated
						roi_status=1
						SetWindow $(s.winname), userdata(ROISTATUS)="1"
						SetWindow $(s.winname) userdata(ROISHOW_USERROI)="1"
						CheckBox show_userroi, win=$(panelName), value=1 //when new roi is being defined, show it.

						Make /N=(1, 2) /O /D $roi_cur_traceName
						Wave roi_cur_trace=$roi_cur_traceName
						
						qipAddPointToCurrentROI(roi_cur_trace, 0, imgx, imgy, tracex, tracey, \
													ixaxisname, iyaxisname, txaxisname, tyaxisname,\
													roi_xaxisname, roi_yaxisname)

						if(!WaveExists($roi_allName))
							Make /N=(1, 2) /O /D $roi_allName
							Wave roi_all=$roi_allName
							roi_all[0][]=NaN
						endif
					else //continuing new roi definition
						Wave roi_cur_trace=$roi_cur_traceName
						qipAddPointToCurrentROI(roi_cur_trace, inf, imgx, imgy, tracex, tracey, \
													ixaxisname, iyaxisname, txaxisname, tyaxisname,\
													roi_xaxisname, roi_yaxisname)
					endif
					SetWindow $(s.winname), userdata(ROI_XAXISNAME)=roi_xaxisname
					SetWindow $(s.winname), userdata(ROI_YAXISNAME)=roi_yaxisname

					if((s.eventMod&0x8)==0x8) // ctrl or cmd is held down, does not care about shift or others
						if(enclosed_roi==1) //user need to close the ROI
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

						SetWindow $(s.winname), userdata(ROISTATUS)="0"
						SetWindow $(s.winname), userdata(ROIAVAILABLE)="1"
					endif
				endif //waveexists
				hookResult = 1
			endif //mouse clicked

			break

		case 22: // mousewheel event
			Variable scaleFactor=1

			if(WaveExists(framew))
				if((s.eventMod&0xE)==0x4) //Alt or Opt key is down, scaling
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
				elseif((s.eventMod&0xE)==0x8) //Ctrl or Cmd key is down, changing frame
					qipGraphPanelUpdateFrameIndex(s.winname, imgw, framew, frameidx, trace_modified, -s.wheelDy)
					update_image=1
					update_trace=1
				endif
				hookResult = 1
			endif //frame exists
			break

		case 11:	// Keyboard event
			if(WaveExists(framew) && WaveExists(imgw))
				variable delta=0
				switch(s.specialKeyCode)
				case 100: //left arrow
					//frameidx-=1
					delta=-1
					update_image=1
					update_trace=1
					hookResult = 1	// We handled keystroke
					break
				case 101: //right arrow
					//frameidx+=1
					delta=1
					update_image=1
					update_trace=1
					hookResult = 1	// We handled keystroke
					break
				case 204:
					if(roi_status==1)
						Make /N=(1, 2) /O /D $roi_cur_traceName
						Wave roi_cur_trace=$roi_cur_traceName
						roi_cur_trace[0][0]=NaN
						roi_cur_trace[0][1]=NaN
						SetWindow $(s.winname), userdata(ROISTATUS)="0"
					else
						CheckBox new_roi, win=$(panelName), value=0
						SetWindow $(s.winname), userdata(NEWROI)="0"
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
						qipGraphPanelResetControls(panelName)
					endif
					SetWindow $(s.winname), userData(PANELVISIBLE)=num2istr(panelVisible)
					hookResult = 1
					break
				default:
					break
				endswitch
				if(delta!=0)
					qipGraphPanelUpdateFrameIndex(s.winname, imgw, framew, frameidx, trace_modified, delta)
				endif
			endif

			break
	endswitch
	
	SetWindow $s.winname userdata(TRACEEDITSTATUS)=num2istr(trace_editstatus)
	SetWindow $s.winname userdata(TRACEMODIFIED)=num2istr(trace_modified)
	
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

	if(update_image==1)
		qipGraphPanelRedrawImage(s.winname)
	endif
	if(update_trace==1)
		qipGraphPanelRedrawROI(s.winname)
		qipGraphPanelRedrawEdges(s.winname)
	endif

	return hookResult	// If non-zero, we handled event and Igor will ignore it.
End

Function /S qipGetFullWaveName(String wname, [WAVE wref])
	if(!ParamIsDefault(wref))
		wname=GetWavesDataFolder(wref, 2)
	endif
	
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

Function /S qipGenerateDerivedName(String wname, String suffix, [Variable unique])
	Variable i
	String newwname=RemoveListItem(ItemsInList(wname, ":")-1, wname, ":")
	newwname=RemoveEnding(newwname, ":")
	String derivedName=StringFromList(ItemsInList(wname, ":")-1, wname, ":")
	derivedName=ReplaceString("'", derivedName, "")
	derivedName+=suffix
	if(unique==1)
		derivedName=UniqueName(derivedName, 1, 0)
	endif
	derivedName=PossiblyQuoteName(derivedName)
	newwname+=":"+derivedName

	return newwname
End

Function /S qipGetShortNameOnly(String wname) //return name without folder/path involved, quoted if necessary
	return PossiblyQuoteName(StringFromList(ItemsInList(wname, ":")-1, wname, ":"))
End

Function /S qipGetPathNameOnly(String wname) //return the path of wave without the name
	String newwname=RemoveListItem(ItemsInList(wname, ":")-1, wname, ":")
	newwname=RemoveEnding(newwname, ":")
	return newwname
End

Function qipGraphPanelBtnSaveROIToFrame(ba) : ButtonControl
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
					qipImageProcUpdateROIRecord(graphName, frameidx, -1, 0)
				endfor
				qipGraphPanelRedrawROI(graphName)
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function qipGraphPanelBtnCopyROIFrom(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			Variable fromFrame=frameidx, toFrame=frameidx
			Variable dynamicFlag=1
			PROMPT fromFrame, "Copy from frame:"
			PROMPT toFrame, "Save to frame:"
			PROMPT dynamicFlag, "Use identified object boundary from reference frame?", popup, "_None_;inner boundary;middle boundary;outer boundary;"
			
			DoPrompt "Copy ROI from which frame to which frame?", fromFrame, dynamicFlag, toFrame
			if(V_flag==0 && fromFrame>=0 && toFrame>=0 && fromFrame!=toFrame)
				qipImageProcUpdateROIRecord(graphName, toFrame, fromFrame, dynamicFlag)
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function qipGraphPanelBtnGotoFrame(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
		
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			Wave img=$(GetUserData(graphname, "", "IMAGENAME"))
			Wave frame=$(GetUserData(graphname, "", "FRAMENAME"))
			
			if(NumType(frameidx)==0 && WaveExists(img) && WaveExists(frame))
				PROMPT frameidx, "Frame #"
				DoPrompt "Get to which frame?", frameidx
				if(V_flag==0)
					if(frameidx>=0 && frameidx<DimSize(img, 2))
						SetWindow $graphname, userdata(FRAMEIDX)=num2istr(frameidx)
						qipGraphPanelRedrawAll(graphname)
					endif
				endif
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function qipGraphPanelBtnClearAllROI(ba) : ButtonControl
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
				qipGraphPanelClearROI(graphname, clear_userroi, clear_framestart, clear_frameend)
			endif
			qipGraphPanelRedrawROI(graphname)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function qipGraphPanelPMOptions(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			qipGraphPanelUpdateOptionCtrls(pa.win, popNum)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function qipGraphPanelUpdateOptionCtrls(String win, Variable opt)
	variable opt1=1, opt2=1, opt3=1
	switch(opt)
	case 1:
		opt1=0; opt2=1; opt3=1;
		break
	case 2:
		opt1=1; opt2=0; opt3=1;
		break
	case 3:
		opt1=1; opt2=1; opt3=0;
		break
	default:
	endswitch
	
	//option 1
	CheckBox show_userroi,win=$win,disable=opt1
	
	GroupBox gb_frameroi win=$win,disable=opt1
	CheckBox show_dot win=$win,disable=opt1
	CheckBox show_tag win=$win,disable=opt1
	CheckBox show_line win=$win,disable=opt1

	GroupBox gb_edges win=$win,disable=opt1
	Checkbox show_edgesI win=$win,disable=opt1
	Checkbox show_edgesM win=$win,disable=opt1
	Checkbox show_edgesO win=$win,disable=opt1
	
	Button imgproc_pickobjs, win=$win,disable=opt1
	//option 2
	Button imgproc_addimglayer_r, win=$win,disable=opt2
	Button imgproc_addimglayer_g, win=$win,disable=opt2
	Button imgproc_addimglayer_b, win=$win,disable=opt2
	Button imgproc_addimglayer_GRAY, win=$win,disable=opt2
End

Constant QIPUFP_IMAGEFUNC_MAINIMAGE=1
Constant QIPUFP_IMAGEFUNC_APPENDIXIMAGE_RED=2
Constant QIPUFP_IMAGEFUNC_APPENDIXIMAGE_GREEN=4
Constant QIPUFP_IMAGEFUNC_APPENDIXIMAGE_BLUE=8
Constant QIPUFP_IMAGEFUNC_REDRAWUPDATE=16
Constant QIPUFP_IMAGEFUNC_PREPROCESSING=32

Constant QIP_ALPHA_RED = 0.299
Constant QIP_ALPHA_GREEN = 0.587
Constant QIP_ALPHA_BLUE = 0.114

Function qipUFP_IMGFUNC(Wave srcImage, Wave frameImage, String graphname, Variable frameidx, Variable flag)
	try
		if(flag&QIPUFP_IMAGEFUNC_REDRAWUPDATE) //normal process of updating frame data
			qipGraphPanelUpdateFrameWave(srcImage, frameImage, frameidx)
		endif
		if(flag&QIPUFP_IMAGEFUNC_PREPROCESSING) //pre-processing of edge detection
			MatrixFilter /N=3 /P=3 gauss frameImage
		endif
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
End

Function qipGraphPanelBtnSetImageLayer(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Variable update_graph=0
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			String baseName=GetUserData(graphname, "", "BASENAME")
			String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
			
			Variable channel_flag=0
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			String wname="", fname=""
			String channel_name=""
			Variable transparency=1

			strswitch(ba.ctrlName)
			case "imgproc_addimglayer_r":
				wname=GetUserData(graphname, "", "OVERLAY_IMAGE_RED")
				fname=GetUserData(graphname, "", "OVERLAY_IMAGE_RED_USERFUNC")
				transparency=str2num(GetUserData(graphname, "", "OVERLAY_IMAGE_RED_TRANSPARENCY"))
				channel_name="RED"
				channel_flag=1				
				break
			case "imgproc_addimglayer_g":
				wname=GetUserData(graphname, "", "OVERLAY_IMAGE_GREEN")
				fname=GetUserData(graphname, "", "OVERLAY_IMAGE_GREEN_USERFUNC")
				transparency=str2num(GetUserData(graphname, "", "OVERLAY_IMAGE_GREEN_TRANSPARENCY"))
				channel_name="GREEN"
				channel_flag=2
				break
			case "imgproc_addimglayer_b":
				wname=GetUserData(graphname, "", "OVERLAY_IMAGE_BLUE")
				fname=GetUserData(graphname, "", "OVERLAY_IMAGE_BLUE_USERFUNC")
				transparency=str2num(GetUserData(graphname, "", "OVERLAY_IMAGE_BLUE_TRANSPARENCY"))
				channel_name="BLUE"
				channel_flag=3
				break
			case "imgproc_addimglayer_GRAY":
				wname=GetUserData(graphname, "", "IMAGENAME") //the main image cannot be changed
				fname=GetUserData(graphname, "", "IMAGE_USERFUNC")
				channel_name="GRAY"
				break
			default:
				return -1
			endswitch
			
			if(strlen(wname)==0)
				wname="_None_"
			else
				wname=qipGetShortNameOnly(wname)
			endif
			if(strlen(fname)==0)
				fname="_None_"
			endif
			if(numtype(transparency)!=0)
				transparency=1
			endif
			
			String imgselection="", funcSelection=""

			if(channel_flag>0)
				imgselection="_None_;"+WaveList("*", ";", "DIMS:3;WAVE:0;")
				PROMPT wname, "Name of image to be assigned to channel "+channel_name+":", popup, imgselection
			else
				imgselection=wname+";"
				PROMPT wname, "Main channel image cannot be changed:", popup, imgselection
			endif			
			
			funcSelection="_None_;"+FunctionList("QIPUF_*", ";", "KIND:2,NPARAMS:5,VALTYPE:1,WIN:Procedure")
			PROMPT fname, "User function for image redraw/update. User function needs to be defined in the Procedure window with its name starting with prefix 'QIPUF_':", popup, funcSelection
			PROMPT transparency, "Transparency (0 means completely transparent, 1 means completely opaque)"
			
			DoPrompt "Select a image and user function:", wname, fname, transparency
			
			if(V_flag!=0)
				return -1
			endif
			
			if(cmpstr(wname, "_None_")==0)
				wname=""
			endif
			if(cmpstr(fname, "_None_")==0)
				fname=""
			endif
			if(numtype(transparency)!=0 || transparency<0)
				transparency=0
			endif
			if(transparency>1)
				transparency=1
			endif
			
			FUNCREF qipUFP_IMGFUNC fRef=$fname
			if(str2num(StringByKey("ISPROTO", FUNCRefInfo(fRef)))==1)
				fname=""
			endif
			
			String overlay_framename=""
			strswitch(ba.ctrlName)
			case "imgproc_addimglayer_r":
				SetWindow $graphname userdata(OVERLAY_IMAGE_RED)=qipGetFullWaveName(wname)
				SetWindow $graphname userdata(OVERLAY_IMAGE_RED_USERFUNC)=fname
				overlay_framename=qipGenerateDerivedName(baseName, ".f.red")
				SetWindow $graphname userdata(OVERLAY_IMAGE_RED_FRAMENAME)=overlay_framename
				Wave colortab=$(analysisDF+":M_ColorTableRED")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_RED_TRANSPARENCY)=num2str(transparency)
				break
			case "imgproc_addimglayer_g":
				SetWindow $graphname userdata(OVERLAY_IMAGE_GREEN)=qipGetFullWaveName(wname)
				SetWindow $graphname userdata(OVERLAY_IMAGE_GREEN_USERFUNC)=fname
				overlay_framename=qipGenerateDerivedName(baseName, ".f.green")
				SetWindow $graphname userdata(OVERLAY_IMAGE_GREEN_FRAMENAME)=overlay_framename
				Wave colortab=$(analysisDF+":M_ColorTableGREEN")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_GREEN_TRANSPARENCY)=num2str(transparency)
				break
			case "imgproc_addimglayer_b":
				SetWindow $graphname userdata(OVERLAY_IMAGE_BLUE)=qipGetFullWaveName(wname)
				SetWindow $graphname userdata(OVERLAY_IMAGE_BLUE_USERFUNC)=fname
				overlay_framename=qipGenerateDerivedName(baseName, ".f.blue")
				SetWindow $graphname userdata(OVERLAY_IMAGE_BLUE_FRAMENAME)=overlay_framename
				Wave colortab=$(analysisDF+":M_ColorTableBLUE")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_BLUE_TRANSPARENCY)=num2str(transparency)
				break
			case "imgproc_addimglayer_GRAY":
				SetWindow $graphname, userdata(IMAGE_USERFUNC)=fname
				Wave colortab=$(analysisDF+":M_ColorTableGRAY")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_GRAY_TRANSPARENCY)=num2str(transparency)
				break
			default:
				break
			endswitch
			
			update_graph=1
			break

		case -1: // control being killed
			break
	endswitch
	
	if(update_graph)	
		qipGraphPanelRedrawAll(graphname)
	endif
	
	return 0
End

Function qipGraphPanelCbRedraw(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			String graphname=cba.win
			graphname=StringFromList(0, graphname, "#")
			
			strswitch(cba.ctrlName)
			case "show_tag":
				if(checked)
					CheckBox show_dot, win=$(cba.win), value=1
					SetWindow $graphname userdata(ROISHOW_DOT)="1"
					SetWindow $graphname userdata(ROISHOW_TAG)="1"
				else
					SetWindow $graphname userdata(ROISHOW_TAG)="0"
				endif
				break
				
			case "show_dot":
				if(!checked)
					CheckBox show_tag, win=$(cba.win), value=0
					SetWindow $graphname userdata(ROISHOW_TAG)="0"
				endif
				SetWindow $graphname userdata(ROISHOW_DOT)=num2istr(checked)
				break
				
			case "show_line":
				SetWindow $graphname userdata(ROISHOW_LINE)=num2istr(checked)
				break
				
			case "new_roi":
				SetWindow $graphname userdata(NEWROI)=num2istr(checked)
				break
				
			case "enclosed_roi":
				SetWindow $graphname userdata(ENCLOSEDROI)=num2istr(checked)
				break
			
			case "show_edgesI":
				SetWindow $graphname userdata(SHOW_EDGES_INNER)=num2istr(checked)
				break
				
			case "show_edgesM":
				SetWindow $graphname userdata(SHOW_EDGES_MIDDLE)=num2istr(checked)
				break
				
			case "show_edgesO":
				SetWindow $graphname userdata(SHOW_EDGES_OUTER)=num2istr(checked)
				break
			default:
				break
				
			endswitch
						
			qipGraphPanelRedrawAll(graphName)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function qipGraphPanelClearROI(String graphname, Variable clear_userroi, Variable clear_framestart, Variable clear_frameend)
	String imageName=GetUserData(graphname, "", "IMAGENAME")
	String analysisDF=GetUserData(graphname, "", "ANALYSISDF")
	String roi_cur_traceName=GetUserData(graphname, "", "ROI_CURRENTTRACENAME")
	String roi_allName=GetUserData(graphname, "", "ROI_ALLTRACENAME")
	
	String trList=TraceNameList(graphname, ";", 1)
	
	if(clear_userroi)	
		String roicurtrName=PossiblyQuoteName(StringFromList(ItemsInList(roi_cur_traceName, ":")-1, roi_cur_traceName, ":"))
		String roialltrName=PossiblyQuoteName(StringFromList(ItemsInList(roi_allName, ":")-1, roi_allName, ":"))
	
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
		print idxcount, " frames has their static ROI removed."
	catch
		err=GetRTError(1)
	endtry
	SetDataFolder savedDF

	SetWindow $(graphName), userdata(ROIAVAILABLE)="0"
	SetWindow $(graphName), userdata(ROISTATUS)="0"
	SetWindow $(graphName), userdata(PICKSTATUS)="0"
	print "ROIs cleaned for graph window:", graphname, ", and image:", imageName
End

Function qipGraphPanelSpinHook(s)
	STRUCT WMWinHookStruct &s

	if( s.eventCode == 23 )	
		DoUpdate/W=$s.winName
	endif
	return 0
End

STRUCTURE qipImageProcParam
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
	Variable dynamicROITracking
	
	String analysisDF
	String imageName
	String frameName

	Variable maxframeidx
	
ENDSTRUCTURE

Function qipGraphPanelBtnEdgeDetect(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	Variable finished_flag=0
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String graphname=ba.win
			graphname=StringFromList(0, graphname, "#")
			
			Variable edgedetection_status=str2num(GetUserData(graphname, "", "EDGEDETECTION_STATUS"))
			Variable edgedetection_stop=str2num(GetUserData(graphname, "", "EDGEDETECTION_STOP"))
			if(edgedetection_status==1)
				SetWindow $ba.win,hook(spinner)=$""
				DoUpdate/W=$ba.win /E=0
				
				finished_flag=1
			else
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
				Variable minArea=50
				Variable dialation_iteration=3
				Variable erosion_iteration=4
				Variable allow_subset=1
				Variable startFrame=frameidx
				Variable endFrame=frameidx
				Variable filterMatrixSize=3
				Variable filterIteration=1
				Variable useROI=1
				Variable useConstantROI=1
				Variable dynamicROITracking=0
	
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
					dynamicROITracking=(dialation_iteration+erosion_iteration)*2
					PROMPT dynamicROITracking, "Iterations of expansion from previous objects' boundaries"
					DoPrompt "Use dynamic ROI by tracking previously identified objects?", dynamicROITracking
					if(V_flag==1)
						dynamicROITracking=0
					endif
				endif
	
				STRUCT qipImageProcParam param
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
				param.dynamicROITracking=dynamicROITracking
				
				param.analysisDF=analysisDF
				param.imageName=imageName
				param.frameName=frameName
				param.maxframeidx=DimSize($imagename, 2)-1
	
				String /G $(analysisDF+":ParticleAnalysisSettings")
				SVAR analysissetting=$(analysisDF+":ParticleAnalysisSettings")
	
				sprintf analysissetting, "GraphName:%s;GaussianFilterMatrixSize:%d;GaussianFilterIteration:%d;Threshold:%.1f;MinArea:%.1f;DialationIteration:%d;ErosionIteration:%d", graphname, filterMatrixSize, filterIteration, threshold, minArea, dialation_iteration, erosion_iteration
	
				edgedetection_stop=0
				edgedetection_status=1
				SetWindow $graphname,userdata(EDGEDETECTION_STATUS)=num2istr(edgedetection_status)
				SetWindow $graphname,userdata(EDGEDETECTION_STOP)=num2istr(edgedetection_stop)
				
				SetWindow $ba.win,hook(spinner)=qipGraphPanelSpinHook
				DoUpdate/W=$ba.win /E=1
				PopupMenu popup_options, win=$ba.win, mode=1
				qipGraphPanelResetControls(ba.win)
				PopupMenu popup_options, win=$ba.win, disable=2
				Button save_roi, win=$ba.win, disable=2
				Button copy_roi, win=$ba.win, disable=2
				Button clear_roi, win=$ba.win, disable=2
				Button imgproc_CallUserfunc, win=$ba.win, disable=2
				Button goto_frameidx, win=$ba.win, disable=2
				
				CheckBox new_roi, win=$ba.win, disable=2
				CheckBox enclosed_roi, win=$ba.win, disable=2
				
				Button imgproc_findobj, win=$ba.win, fColor=(32768,0,0), title="STOP Edge Detection"
				
				qipImageProcEdgeDetection(graphname, param)
				finished_flag=1
			endif
			break
		case -1: // control being killed
			break
	endswitch
	
	if(finished_flag==1)
		edgedetection_stop=1
		edgedetection_status=0
		SetWindow $graphname,userdata(EDGEDETECTION_STATUS)=num2istr(edgedetection_status)
		SetWindow $graphname,userdata(EDGEDETECTION_STOP)=num2istr(edgedetection_stop)
		
		PopupMenu popup_options, win=$ba.win, disable=0
		Button save_roi, win=$ba.win, disable=0
		Button copy_roi, win=$ba.win, disable=0
		Button clear_roi, win=$ba.win, disable=0
		Button imgproc_CallUserfunc, win=$ba.win, disable=0
		Button goto_frameidx, win=$ba.win, disable=0
		
		CheckBox new_roi, win=$ba.win, disable=0
		CheckBox enclosed_roi, win=$ba.win, disable=0
		
		Button imgproc_findobj, win=$ba.win, fColor=(0,0,32768), title="Identify Objects"
	endif
	
	return 0
End

Function qipBoundaryFindGroupByIndex(Wave boundaryX, Wave boundaryIndex, Variable index, Variable & boundary_start, Variable & boundary_end)
//if a index wave is provided for boundary wave that are separated by NaN or Inf between groups
//this function will provide the start and end point numbers of the group identified by index number
//the number of points for the group will be returned
	Variable j
	Variable cnt=0
	try
		boundary_start=NaN
		boundary_end=NaN
		if(WaveExists(boundaryX) && WaveExists(boundaryIndex) && index>=0 && index<DimSize(boundaryIndex, 0))
			boundary_start=boundaryIndex[index][0]; AbortOnRTE
			if(DimSize(boundaryIndex, 1)>=2)
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

Function qipBoundaryGetNextGroup(Wave boundary, Variable & startidx, Variable & endidx)
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

Function qipBoundaryFindIndexByPoint(Variable x, Variable y, Wave W_info, Variable & startp, Variable &endp, Variable & centerx, Variable & centery)
	startp=-1
	endp=-1
	centerx=NaN
	centery=NaN
	Variable i
	Variable selected_distance=inf
	Variable selected_i=NaN
	Variable distance=NaN
	
	for(i=0; i<DimSize(W_info, 0); i+=1)
		if(x>=W_info[i][2] && x<=W_info[i][3] && y>=W_info[i][4] && y<=W_info[i][5])
			distance=(x-W_info[i][8])^2+(y-W_info[i][9])^2
			if(distance<selected_distance)
				selected_distance=distance
				selected_i=i
			endif
		endif
	endfor
	if(selected_i>=0 && selected_i<DimSize(W_Info, 0))
		startp=W_info[selected_i][0]
		endp=W_info[selected_i][1]
		centerx=W_info[selected_i][8]
		centery=W_info[selected_i][9]
	else
		selected_i=-1
	endif
	return selected_i
End

Function qipImageProcUpdateROIRecord(String graphName, Variable currentFrame, Variable refFrame, Variable dynamicFlag)
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
	Variable err
	
	try
		NewDataFolder /O/S $analysisDF; AbortOnRTE
		NewDataFolder /O/S :$(num2istr(currentFrame)); AbortOnRTE

		if(refFrame<0) //global user ROI is used
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
					len=qipBoundaryGetNextGroup(roiwave, startidx, endidx); AbortOnRTE

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
		else //need to copy from reference frame to targe frame, no global ROI is used.
			String refDF=""
			if(dynamicFlag>=2 && dynamicFlag<=4)
				//following frames will used previous tracked particle's edge region to get new ROI defined
			   //we should be inside the datafolder for the current folder
				refDF=analysisDF+":"+PossiblyQuoteName(num2istr(refFrame))+":ROI" ; AbortOnRTE
				DFREF refDF_ROI=$refDF; AbortOnRTE
				DFREF refDF_Boundary=$(refDF+":PointROIObjEdges"); AbortOnRTE
				if(DataFolderRefStatus(refDF_ROI)==1 && DataFolderRefStatus(refDF_Boundary)==1)
					Wave refPointROI=refDF_ROI:W_PointROI
					
					NewDataFolder /O/S :ROI ; AbortOnRTE
					Make /O /D /N=(1, 2) W_RegionROIIndex=NaN; AbortOnRTE
					Make /O /D /N=(1, 2) W_RegionROIBoundary=NaN; AbortOnRTE
					
					if(WaveExists(refPointROI) && refFrame!=currentFrame)
						Duplicate /O refPointROI, :W_PointROI; AbortOnRTE
					endif
					
					String postfix="", boundaryName=""
					switch(dynamicFlag)
					case 2: //inner
						postfix=".I"
						break
					case 3: //middle
						postfix=".M"
						break
					case 4: //outer
						postfix=".O"
						break
					default:
						postfix=""
						break
					endswitch					
	
					Variable j
					for(j=0; j<DimSize(refPointROI, 0); j+=1)
						boundaryName="W_ROIBoundary"+num2istr(j)+postfix; AbortOnRTE
						Wave boundarywave=refDF_Boundary:$boundaryName; AbortOnRTE
						if(WaveExists(boundarywave))
							InsertPoints /M=0 DimSize(W_RegionROIBoundary, 0), DimSize(boundarywave, 0)+1, W_RegionROIBoundary; AbortOnRTE
							if(j==0)
								W_RegionROIBoundary[1,DimSize(boundarywave, 0)][]=boundarywave[p-1][q]; AbortOnRTE
								W_RegionROIBoundary[DimSize(W_RegionROIBoundary, 0)-1][]=NaN; AbortOnRTE
								W_RegionROIIndex[0][0]=1; AbortOnRTE
								W_RegionROIIndex[0][1]=DimSize(boundaryWave, 0); AbortOnRTE
							else
								Variable idxbase=W_RegionROIIndex[j-1][1]+2 ; AbortOnRTE //the end point of last index
								InsertPoints /M=0 DimSize(W_RegionROIIndex, 0), 1, W_RegionROIIndex; AbortOnRTE
								W_RegionROIBoundary[idxbase,idxbase+DimSize(boundarywave, 0)-1][]=boundarywave[p-idxbase][q]; AbortOnRTE
								W_RegionROIBoundary[DimSize(W_RegionROIBoundary, 0)-1][]=NaN; AbortOnRTE
								W_RegionROIIndex[j][0]=idxbase; AbortOnRTE
								W_RegionROIIndex[j][1]=idxbase+DimSize(boundarywave, 0)-1
							endif
						endif
					endfor
					
				endif
			else
				//simply copy the ROI from the refFrame's ROI folder over
				if(refFrame!=currentFrame)
					try
						refDF=analysisDF+":"+PossiblyQuoteName(num2istr(refFrame))+":ROI" ; AbortOnRTE
						DFREF refDFREF=$refDF; AbortOnRTE
						if(DataFolderRefStatus(refDFREF)==1)
							Wave refLineROIIdx=refDFREF:W_RegionROIIndex
							Wave refLineROI=refDFREF:W_RegionROIBoundary
							Wave refPointROI=refDFREF:W_PointROI
							
							if(WaveExists(refLineROIIdx))
								Duplicate /O refLineROIIdx, :ROI:W_RegionROIIndex
							endif
							if(WaveExists(refLineROI))
								Duplicate /O refLineROI, :ROI:W_RegionROIBoundary
							endif
							if(WaveExists(refPointROI))
								Duplicate /O refPointROI, :ROI:W_PointROI
							endif
						endif
					catch
						err=GetRTError(1)
					endtry
				endif
			endif
		endif
	catch
		err=GetRTError(1)
	endtry

	SetDataFolder savedDF

	return retVal
End

Function qipImageProcGenerateROIMaskFromBoundary(String graphName, Wave boundaryX, Wave boundaryY, String roimask_name, [Variable valueE, Variable valueI, Variable erosion, Variable dilation])
	if(ParamIsDefault(valueE)) // for background
		valueE=1
	endif
	if(ParamIsDefault(valueI)) // for identified region
		valueI=0
	endif
	
	Wave roimask=$roimask_name
	String roimaskbasename=qipGetShortNameOnly(roimask_name)
	qipGraphPanelAddImageByAxis(graphName, roimask)
	
	DrawAction /W=$graphName /L=ProgFront delete
	
	SetDrawLayer /W=$graphName ProgFront
	SetDrawEnv /W=$graphName linefgc= (65535,65535,0),fillpat= 0,xcoord= top,ycoord= left, save			
	DrawPoly /W=$graphName boundaryX[0], boundaryY[0], 1, 1, boundaryX, boundaryY
	ImageGenerateROIMask /E=(valueE) /I=(valueI) /W=$graphName $roimaskbasename
	
	DrawAction /W=$graphName /L=ProgFront delete
	
	Wave M_ROIMask=:M_ROIMask
	Duplicate /O M_ROIMask, roimask
	RemoveImage /W=$graphName /Z $roimaskbasename
	
	if(!ParamIsDefault(erosion) && erosion>0)
		ImageMorphology /i=(erosion) /E=4 Erosion roimask
		Duplicate /O :M_ImageMorph, roimask
	endif
	
	if(!ParamIsDefault(dilation) && dilation>0)
		ImageMorphology /i=(dilation) /E=4 Dilation roimask
		Duplicate /O :M_ImageMorph, roimask
	endif
End

Function qipImageProcGenerateROIMask(String graphName, DFREF ROIDF, Variable roi_idx, Variable frameidx, Wave frame, String roimask_name, Variable dynamicTracking)
//this function will generate ROI mask and will return the index for the next iteration
//when no more ROI is available, -1 will be returned
	Variable fallback=1
	Variable nextidx=-1
	
	if(DataFolderRefStatus(ROIDF)==1 && roi_idx>=0)
		if(dynamicTracking>0)
			Variable refFrameIdx=frameidx-1
			if(refFrameIdx>=0)
				String refDF=GetUserData(graphName, "", "ANALYSISDF")+":"+PossiblyQuoteName(num2istr(refFrameIdx))+":"
				String refPointROIName=refDF+"ROI:W_PointROI"
				String refEdgeWaveName=refDF+"innerEdge:DetectedEdges:W_Boundary"
				String refEdgeInfoWaveName=refDF+"innerEdge:DetectedEdges:W_Info"
				
				Wave refPointROI=$refPointROIName
				Wave refEdgeWave=$refEdgeWaveName
				Wave refEdgeInfoWave=$refEdgeInfoWaveName
				
				if(WaveExists(refPointROI) && WaveExists(refEdgeWave) && WaveExists(refEdgeInfoWave))
					Variable maxidx=DimSize(refPointROI, 0)
					if(roi_idx==0) //first call
						Make /O /D /N=(DimSize(refPointROI, 0), 2) ROIDF:W_PointROI=NaN
						Wave currentPointROI=ROIDF:W_PointROI
					else
						Wave currentPointROI=ROIDF:W_PointROI
						if(DimSize(currentPointROI, 0)!=DimSize(refPointROI, 0) || DimSize(currentPointROI, 1)!=2)
							print "error in dimensions of point ROIs for frame ", frameidx
							return -1
						endif
					endif
					
					if(roi_idx>=maxidx)
						return -1
					endif
					
					for(nextidx=roi_idx; nextidx<maxidx; nextidx+=1)
						Variable startp=-1, endp=-1, centerx=NaN, centery=NaN
						if(NumType(refPointROI[nextidx][0])==0)
							qipBoundaryFindIndexByPoint(refPointROI[nextidx][0], refPointROI[nextidx][1], refEdgeInfoWave, startp, endp, centerx, centery)
							currentPointROI[nextidx][0]=centerx
							currentPointROI[nextidx][1]=centery
							if(startp>=0 && endp>=startp)
								Make /O/D/N=(endp-startp+1) ROIDF:M_ROIX, ROIDF:M_ROIY
								Wave M_ROIX=ROIDF:M_ROIX
								Wave M_ROIY=ROIDF:M_ROIY
								M_ROIX=refEdgeWave[startp+p][0]
								M_ROIY=refEdgeWave[startp+p][1]
								Make /O /N=(DimSize(frame, 0), DimSize(frame, 1)) /Y=0x48 $roimask_name=0
								qipImageProcGenerateROIMaskFromBoundary(graphName, M_ROIX, M_ROIY, roimask_name, erosion=dynamicTracking)
								nextidx+=1 //this part is done, go and wait for next call
								break
							endif
						endif
					endfor
					fallback=0
				endif
			endif
		endif
		
		if(fallback) //typical static ROI defined in ROI folder		
			Wave W_idx=ROIDF:W_RegionROIIndex
			Wave W_region=ROIDF:W_RegionROIBoundary
			
			Variable startidx=-1, endidx=-1, cnt=-1
			cnt=qipBoundaryFindGroupByIndex(W_region, W_idx, roi_idx, startidx, endidx)
			if(cnt>0)
				Make /O /N=(DimSize(frame, 0), DimSize(frame, 1)) /Y=0x48 $roimask_name=0
				Make /N=(cnt) /D /O ROIDF:M_ROIMaskX, ROIDF:M_ROIMaskY
				Wave tmpx=ROIDF:M_ROIMaskX
				Wave tmpy=ROIDF:M_ROIMaskY
				tmpx[]=W_region[startidx+p][0]
				tmpy[]=W_region[startidx+p][1]
				
				qipImageProcGenerateROIMaskFromBoundary(graphName, tmpx, tmpy, roimask_name)				
				nextidx=roi_idx+1
			else
				nextidx=-1
			endif
		endif
	endif
	
	return nextidx
End

Function qipImageProcClearEdges(String graphName, Variable frameidx, Variable edgeType)
	Variable clean_flag=1
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
	case 3:
		dfname+="ROI:PointROIObjEdges"
		break
	default:
		dfname=""
		clean_flag=0
		break
	endswitch
	
	if(clean_flag)
		KillDataFolder /Z $dfname
	endif
End

Function qipImageProcFindIndexForDotROI(Wave pointROI, Variable roiIdx, Wave infow, Wave boundary, Wave roi2info, String roiEdgeName)
	Variable startp=-1, endp=-1, centerx=NaN, centery=NaN
	Variable selected_idx=qipBoundaryFindIndexByPoint(pointROI[roiIdx][0], pointROI[roiIdx][1], infow, startp, endp, centerx, centery); AbortOnRTE
	roi2info[roiidx][0]=selected_idx; AbortOnRTE
	if(selected_idx>=0)
		Duplicate /O/R=[infow[selected_idx][0], infow[selected_idx][1]][], boundary, $roiEdgeName
	else
		Make /O /N=(1,2) /D $roiEdgeName=NaN
	endif
End

Function qipImageProcGenerateInfoIndexForDotROIs(DFREF homedfr)
//this function will look through the point ROIs and see which boundary of the inner, middle and outer
// edges of the identified object it falls in. If found, the index of that boundary in the W_Info
// is recorded in the wave W_PointROI2Info. The column 0 for middle, 1 for inner and 2 for outer
// the boundary for the object is then saved in :ROI:PointROIObjEdges: data folder with the names
// set as W_ROIBoundaryN.I/M/O, where the N is the index of the point ROI
	DFREF savedDF=GetDataFolderDFR()
	try
		SetDataFolder homedfr
		NewDataFolder /O :ROI:PointROIObjEdges ; AbortOnRTE
		//DFREF pointROIEdgeDF=:ROI:PointROIObjEdges ; AbortOnRTE
		
		Wave pointROI=:ROI:W_PointROI ; AbortOnRTE
		
		Wave middle_infow=:DetectedEdges:W_Info ; AbortOnRTE
		Wave middle_boundary=:DetectedEdges:W_Boundary ; AbortOnRTE
		
		Wave inner_infow=:innerEdge:DetectedEdges:W_Info ; AbortOnRTE
		Wave inner_boundary=:innerEdge:DetectedEdges:W_Boundary ; AbortOnRTE
		
		Wave outer_infow=:outerEdge:DetectedEdges:W_Info ; AbortOnRTE
		Wave outer_boundary=:outerEdge:DetectedEdges:W_Boundary ; AbortOnRTE
		
		if(WaveExists(pointROI) && WaveExists(middle_infow) && WaveExists(inner_infow) && WaveExists(outer_infow))
			Variable maxidx=DimSize(pointROI, 0) ; AbortOnRTE
			Make /O /N=(maxidx, 3) :ROI:W_PointROI2Info ; AbortOnRTE
			Wave roi2info=:ROI:W_PointROI2Info ; AbortOnRTE
			 //this stores the index for W_Info for edges, inner edges and outer edges that 
			 //best match the point ROI
			
			Variable i
			for(i=0; i<maxidx; i+=1)
			
				String roiEdgeNameM=qipGenerateDerivedName(":ROI:PointROIObjEdges:W_ROIBoundary", num2istr(i)+".M")
				String roiEdgeNameI=qipGenerateDerivedName(":ROI:PointROIObjEdges:W_ROIBoundary", num2istr(i)+".I")
				String roiEdgeNameO=qipGenerateDerivedName(":ROI:PointROIObjEdges:W_ROIBoundary", num2istr(i)+".O")
				
				qipImageProcFindIndexForDotROI(pointROI, i, middle_infow, middle_boundary, roi2info, roiEdgeNameM); AbortOnRTE
				
				qipImageProcFindIndexForDotROI(pointROI, i, inner_infow, inner_boundary, roi2info, roiEdgeNameI); AbortOnRTE
				
				qipImageProcFindIndexForDotROI(pointROI, i, outer_infow, outer_boundary, roi2info, roiEdgeNameO); AbortOnRTE
				
			endfor
		endif
	catch
		Variable err=GetRTError(1)
		print "error when generating the index of W_Info for each Dot ROI:", err
	endtry
	SetDataFolder savedDF
End

Function qipImageProcAddDetectedEdge(DFREF homedfr)
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
		
		if(DimSize(W_newx, 0)==0)
			return -1
		endif
		
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
			qipBoundaryFindGroupByIndex(W_newx, W_newidx, i, startidx, endidx)
			if(startidx>=0 && endidx>=startidx)
				W_Info[info_baseidx+i][0]=boundary_baseidx+startidx //start and end index should always be the first two
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

Function qipImageProcEdgeDetection(String graphName, STRUCT qipImageProcParam & param)
	Wave image=$(param.imageName)
	Wave frame=$(param.frameName)

	if(!WaveExists(image) || !WaveExists(frame))
		return -1
	endif
	
	Variable frameidx
	Variable roi_counts
	Variable stop_flag
	
	DFREF savedDF=GetDataFolderDFR()
	NewDataFolder /O/S $(param.analysisDF)
	DFREF parentdfr=GetDataFolderDFR()
	FUNCREF qipUFP_IMGFUNC usrFuncRef=$(GetUserData(graphName, "", "IMAGE_USERFUNC"))
	try
		for(frameidx=param.startframe; frameidx>=0 && frameidx<=param.endframe && frameidx<=param.maxframeidx; frameidx+=1)
			SetWindow $graphName userdata(FRAMEIDX)=num2istr(frameidx)
			qipGraphPanelRedrawAll(graphName)
			
			stop_flag=str2num(GetUserData(graphName, "", "EDGEDETECTION_STOP"))
			if(stop_flag==1)
				break
			endif
			
			SetDataFolder parentdfr
			NewDataFolder /O/S $(num2istr(frameidx))
			
			DFREF homedfr=GetDataFolderDFR()
			qipImageProcClearEdges(graphName, frameidx, 0) //clear existing info of edge
			qipImageProcClearEdges(graphName, frameidx, 1)
			qipImageProcClearEdges(graphName, frameidx, 2)
			qipImageProcClearEdges(graphName, frameidx, 3)

			multithread frame[][]=image[p][q][frameidx]; AbortOnRTE
			
			String roimask_name=GetDataFolder(1)+"M_ROI"

			usrFuncRef(image, frame, graphname, frameidx, 1) //preprocessing of frame data before threshold
			
			roi_counts=0
			do
				if(param.useROI==1)
					DFREF roidf=:ROI
					if(frameidx==param.startframe) //first frame will not follow dynamic tracking, but use the ROI defined for this frame
						roi_counts=qipImageProcGenerateROIMask(graphName, roidf, roi_counts, frameidx, frame, roimask_name, 0)
					else
						roi_counts=qipImageProcGenerateROIMask(graphName, roidf, roi_counts, frameidx, frame, roimask_name, param.dynamicROITracking)
					endif
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
						ImageThreshold /Q/M=0/T=(param.threshold)/I frame
					else
						ImageThreshold /Q/M=1/I frame
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
				qipImageProcAddDetectedEdge(homedfr)
				Duplicate /O homedfr:M_ImageMorph, homedfr:M_FilledEdge
				String filledEdgeName=GetDataFolder(1)+"M_FilledEdge"
				qipImageProcGenerateROIMaskFromBoundary(graphName, homedfr:W_BoundaryX, homedfr:W_BoundaryY, filledEdgeName, valueE=255)
				

				NewDataFolder /O/S innerEdge
				ImageMorphology /E=4 /I=(param.dialation_iteration) Dilation $filledEdgeName
		
				if(param.allow_subset==0)
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea)/FILL stats :M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea) stats :M_ImageMorph
				endif
				qipImageProcAddDetectedEdge(homedfr:innerEdge)
				SetDataFOlder ::
				
				NewDataFolder /O/S outerEdge
				ImageMorphology /E=4 /I=(param.dialation_iteration) Dilation $filledEdgeName
				ImageMorphology /E=4 /I=(param.erosion_iteration+param.dialation_iteration) Erosion :M_ImageMorph
		
				if(param.allow_subset==0)
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea)/FILL stats :M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(param.frameName) /W/E/A=(param.minArea) stats :M_ImageMorph
				endif
				qipImageProcAddDetectedEdge(homedfr:outerEdge)
				SetDataFolder :: //back to home directory for ROI reading in the next loop
				
				qipGraphPanelRedrawROI(graphName)
				qipGraphPanelRedrawEdges(graphName)
				DoUpdate
				stop_flag=str2num(GetUserData(graphName, "", "EDGEDETECTION_STOP"))
				if(stop_flag==1)
					break
				endif
			while(roi_counts>=0)
			qipImageProcGenerateInfoIndexForDotROIs(homedfr) 
			//if dot ROI exists, will generate another table
			//that tells which item in W_Info best links to each dot
			// :ROI:W_PointROI2Info will have the same rows as W_PointROI
			//   column [0] for middle edge index in W_Info
			//   column [1] for inner edge index in W_Info
			//   column [2] for outer edge index in W_Info
		endfor
	catch
		Variable err=GetRTError(0)
		if(err!=0)
			print "Error: ", GetErrMessage(err)
			err=GetRTError(1)
		endif
	endtry

	SetDataFolder savedDF
	
	qipGraphPanelRedrawAll(graphName)
End


Function qipGraphPanelSVObjIdx(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			String graphname=sva.win
			graphname=StringFromList(0, graphname, "#")
			Variable frameidx=str2num(GetUserData(graphname, "", "FRAMEIDX"))
			Variable modified=str2num(GetUserData(graphname, "", "TRACEMODIFIED"))
			if(modified)
				DoAlert 1, "Trace has been modified. Save the changes?"
				if(V_flag==1)
					qipGraphPanelCallSaveFunc(graphname, frameidx)
				endif
				SetWindow $graphName, userdata(TRACEMODIFIED)="0"
			endif
			qipGraphPanelRedrawROI(graphname)
			qipGraphPanelRedrawEdges(graphname)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Constant QIPUF_CHANNEL_GRAY=0
Constant QIPUF_CHANNEL_RED=1
Constant QIPUF_CHANNEL_GREEN=2
Constant QIPUF_CHANNEL_BLUE=3

Function qipUF_GetFrame(Variable channel, Variable frameidx)

End

Function qipUF_GetObj(Variable frameidx, Variable objidx, Variable & x, Variable & y, WAVE & bTrace, WAVE & bMask)
End

Function qipUF_GetFrameNumber()
End

Function qipUF_GetObjNumber()
End
