#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma ModuleName=QImageAnalysis

#include "QImageAnalysisUFPs"

Menu "&QingLabTools"
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
//this function will attach the hook function to the graph window
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
	DrawPICT /W=$panelName 0,210,0.25,0.25,QImageAnalysis#QingLabBadge
	DrawText /W=$panelName 22,230,"\\Z07QImageAnalysis\rBy QingLAB@ASU"
	qipGraphPanelResetControls(panelName)
	qipGenerateOverlayColorTables(graphname)
	SetWindow $graphname hook(qipHook)=qipHookFunction
End

Function qipGenerateOverlayColorTables(String graphname)
//standard color table will be used for specified color channels
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
		M_ColorTableRED[][3]=QIPUF_DEFAULT_ALPHA_RED*65535
		M_ColorTableGREEN[][3]=QIPUF_DEFAULT_ALPHA_GREEN*65535
		M_ColorTableBLUE[][3]=QIPUF_DEFAULT_ALPHA_BLUE*65535
		M_ColorTableGRAY[][3]=65535
	catch
	endtry
	SetDataFolder savedDF
End

Function qipGraphPanelResetControls(String panelName)
//redraw all controls
	SetVariable xy_cord win=$panelName, pos={2,10}, bodywidth=200, value=_STR:(""), noedit=1
	SetVariable img_value win=$panelName, pos={2,30}, bodywidth=200, value=_STR:(""), noedit=1
	SetVariable trace_value win=$panelName, pos={2,50}, bodywidth=200, value=_STR:(""), noedit=1
 
	CheckBox new_roi, win=$panelName, pos={2, 70}, bodywidth=50, title="New ROI",proc=qipGraphPanelCbRedraw
	CheckBox new_roi, win=$panelName, help={"Enter editing status to create global ROIs"}
	CheckBox enclosed_roi, win=$panelName, pos={50, 70}, bodywidth=50, title="Enclosed",proc=qipGraphPanelCbRedraw
	CheckBox enclosed_roi, win=$panelName,help={"Check this if you want the last point always close with the first point."}

	Button save_roi, win=$panelName, pos={0, 85}, size={95, 20}, title="Save ROI To Frame...",proc=qipGraphPanelBtnSaveROIToFrame
	Button copy_roi, win=$panelName, pos={0, 105}, size={95,20}, title="Copy ROI From...",proc=qipGraphPanelBtnCopyROIFrom
	Button clear_roi, win=$panelName, pos={0, 125}, size={95, 20}, title="Clear All ROI",proc=qipGraphPanelBtnClearAllROI
	Button imgproc_findobj, win=$panelName, fColor=(0,16384,0), pos={0, 145}, size={95,20}, title="Identify Objects",proc=qipGraphPanelBtnEdgeDetect
	
	SetVariable sv_objidx,win=$panelName,title="OBJ",pos={0, 170},size={48,20},value= _NUM:-1,limits={-2,inf,1},proc=qipGraphPanelSVIndex
	SetVariable sv_objidx,win=$panelName,help={"Index to selectively show edges of object defined by the dot ROIs.\n -2 means showing all raw detected edges, \n-1 means show edges of all detected  objects"}
	SetVariable sv_frameidx,win=$panelName,title="FRM",pos={48,170},size={48,20},value=_NUM:0,limits={0,inf,1},proc=qipGraphPanelSVIndex
	
	GroupBox gb_options  win=$panelName, pos={100,70}, size={100, 160}, frame=0, title="" 
	PopupMenu popup_options win=$panelName, pos={100, 70}, size={100,20}, value="ROI Options;Image Layers;Data Processing;",proc=qipGraphPanelPMOptions
	
	//the following will be with popup menu option 1: ROI options		
	GroupBox gb_frameroi, win=$panelName, pos={102,85}, size={95, 47}, frame=0, title="Show ROIs"
	CheckBox show_userroi, win=$panelName, pos={105,99}, bodywidth=50, title="Global",proc=qipGraphPanelCbRedraw
	CheckBox show_dot, win=$panelName, pos={105,114}, bodywidth=30, title="Dot",proc=qipGraphPanelCbRedraw
	CheckBox show_tag, win=$panelName, pos={135,114}, bodywidth=30, title="Tag",proc=qipGraphPanelCbRedraw
	CheckBox show_line, win=$panelName, pos={165,114}, bodywidth=30, title="Line",proc=qipGraphPanelCbRedraw
	
	GroupBox gb_edges, win=$panelName, pos={102,138}, size={95, 37}, frame=0, title="Obj Edges"
	Checkbox show_edgesI, win=$panelName, pos={105,155}, bodywidth=30, title="I",proc=qipGraphPanelCbRedraw
	Checkbox show_edgesM, win=$panelName, pos={135,155}, bodywidth=30, title="M",proc=qipGraphPanelCbRedraw
	Checkbox show_edgesO, win=$panelName, pos={165,155}, bodywidth=30, title="O",proc=qipGraphPanelCbRedraw

	//the following will be with popup menu option 2: Image Layers
	Button imgproc_addimglayer_GRAY, win=$panelName, pos={102, 90}, size={95,20}, title="Set Main Channel", disable=1, proc=qipGraphPanelBtnSetImageLayer
	Button imgproc_addimglayer_r, win=$panelName, pos={102, 120}, size={95,20}, title="Set Red Chn Overlay", disable=1, proc=qipGraphPanelBtnSetImageLayer
	Button imgproc_addimglayer_g, win=$panelName, pos={102, 140}, size={95,20}, title="Set Green Chn Overlay", disable=1, proc=qipGraphPanelBtnSetImageLayer
	Button imgproc_addimglayer_b, win=$panelName, pos={102, 160}, size={95,20}, title="Set Blue Chn Overlay", disable=1, proc=qipGraphPanelBtnSetImageLayer
	
	//the following will be with popup menu option 3: Data Processing
	Button imgproc_CallUserfunc, win=$panelName, pos={102,90}, size={95,20}, title="Call User Function...", disable=1,proc=qipGraphPanelBtnCallUserFunction
	
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
		
		//tmpframe[][]=w[p][q][0]
		ImageTransform /PTYP=0 /P=0 getPlane w
		Wave M_ImagePlane
		Duplicate /O M_ImagePlane, $tmpframeName
		KillWaves /Z M_ImagePlane
		Wave tmpframe=$tmpframeName
		
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

Function qipGraphPanelAddTraceByAxis(String graphName, Wave trace, String xaxisname, String yaxisname, [Variable r, Variable g, Variable b, Variable alpha, Variable show_marker, Variable mode, Variable redundantOK])
	Variable trace_drawn=0
//	String xaxisname=GetUserData(graphName, "", "ROI_XAXISNAME")
//	String yaxisname=GetUserData(graphName, "", "ROI_YAXISNAME")
	
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

Function qipGraphPanelPrepRedrawEdges(Variable show_edges, Variable showRawDetectedEdge, Variable objidx, 
													Variable edgeType, Wave ROI2InfoIndex, Wave rawEdge, String redrawEdgeName, string saveFuncName)
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
		
		if(showRawDetectedEdge)
			//simple duplication
			Duplicate /O rawEdge, $redrawEdgeName
			Note /K $redrawEdgeName		
		else
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
		endif
	else
	//no edges are shown
		Make /O /N=(1, 2) $redrawEdgeName=NaN; AbortOnRTE
		Note /K $redrawEdgeName; AbortOnRTE
	endif	
End

Function qipGraphPanelRedrawEdges(String graphName, [Variable rawDetectedEdge])
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
		
		Wave PointROIs=$(homeDFstr+"ROI:W_PointROI"); AbortOnRTE
		Wave ROI2InfoIndex=$(homeDFstr+"ROI:W_PointROI2Info"); AbortOnRTE
		Wave edgeBoundary=$(homeDFstr+"DetectedEdges:W_Boundary"); AbortOnRTE
		Wave inneredgeBoundary=$(homeDFstr+"innerEdge:DetectedEdges:W_Boundary"); AbortOnRTE
		Wave outeredgeBoundary=$(homeDFstr+"outerEdge:DetectedEdges:W_Boundary"); AbortOnRTE
		
		ControlInfo /W=$panelName sv_objidx
		variable objidx=V_Value
		Variable startp, endp
		
		if(WaveExists(edgeBoundary) && WaveExists(inneredgeBoundary) && WaveExists(outeredgeBoundary))
			if(rawDetectedEdge==1 || !WaveExists(PointROIs) || objidx==-2) //objidx == -1 means all objects, -2 means all raw edges
				qipGraphPanelPrepRedrawEdges(show_edgesM, 1, objidx, 1, ROI2InfoIndex, edgeBoundary, edgeName, "qipUFP_SavePointROIEdge_M")
				qipGraphPanelPrepRedrawEdges(show_edgesI, 1, objidx, 2, ROI2InfoIndex, inneredgeBoundary, innerEdgeName, "qipUFP_SavePointROIEdge_I")
				qipGraphPanelPrepRedrawEdges(show_edgesO, 1, objidx, 3, ROI2InfoIndex, outeredgeBoundary, outeredgeName, "qipUFP_SavePointROIEdge_O")
			else
				qipGraphPanelPrepRedrawEdges(show_edgesM, 0, objidx, 1, ROI2InfoIndex, edgeBoundary, edgeName, "qipUFP_SavePointROIEdge_M")
				qipGraphPanelPrepRedrawEdges(show_edgesI, 0, objidx, 2, ROI2InfoIndex, inneredgeBoundary, innerEdgeName, "qipUFP_SavePointROIEdge_I")
				qipGraphPanelPrepRedrawEdges(show_edgesO, 0, objidx, 3, ROI2InfoIndex, outeredgeBoundary, outeredgeName, "qipUFP_SavePointROIEdge_O")
			endif
		else
			Make /O /N=(1, 2) $edgeName=NaN; AbortOnRTE
			Note /K $edgeName; AbortOnRTE
			Make /O /N=(1, 2) $innerEdgeName=NaN; AbortOnRTE
			Note /K $innerEdgeName; AbortOnRTE
			Make /O /N=(1, 2) $outerEdgeName=NaN; AbortOnRTE
			Note /K $outerEdgeName; AbortOnRTE
		endif

		String roi_xaxisname=GetUserData(graphName, "", "ROI_XAXISNAME")
		String roi_yaxisname=GetUserData(graphName, "", "ROI_YAXISNAME")
		
		qipGraphPanelAddTraceByAxis(graphName, $outeredgeName, roi_xaxisname, roi_yaxisname, r=0, g=65535, b=0, alpha=32768); AbortOnRTE
		qipGraphPanelAddTraceByAxis(graphName, $edgeName, roi_xaxisname, roi_yaxisname, r=65535, g=0, b=0, alpha=32768); AbortOnRTE
		qipGraphPanelAddTraceByAxis(graphName, $inneredgeName, roi_xaxisname, roi_yaxisname, r=0, g=0, b=65535, alpha=32768); AbortOnRTE

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
	String roi_xaxisname=GetUserData(graphName, "", "ROI_XAXISNAME")
	String roi_yaxisname=GetUserData(graphName, "", "ROI_YAXISNAME")
	
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
		if(qipGraphPanelAddTraceByAxis(graphName, roi_cur_trace, roi_xaxisname, roi_yaxisname, r=0, g=32768, b=0, alpha=65535, show_marker=((43<<8)+(5<<4)+2), mode=4))
			ModifyGraph /Z /W=$(graphName) offset($roi_cur_basename)={0,0}
		endif
	endif
	
	if(show_userroi) //existing record of user ROI is shown only when checkbox is true
		if(strlen(roi_allName)>0)
			if(qipGraphPanelAddTraceByAxis(graphName, roi_all, roi_xaxisname, roi_yaxisname, r=32768, g=0, b=0, alpha=65535, show_marker=((43<<8)+(5<<4)+2), mode=4))
				ModifyGraph /Z /W=$(graphName) offset($roi_all_basename)={0,0}
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
				SetVariable sv_objidx, win=$panelName, value= _NUM:-1,limits={-2,maxobjidx,1}
			else
				SetVariable sv_objidx, win=$panelName, value= _NUM:V_Value,limits={-2,maxobjidx,1}
			endif
			
			if(WaveExists(wdot))
				Duplicate /O wdot, $dotwaveName; AbortOnRTE //copy to the root folder of the frame
			else
				Make /O/D/N=(1,2) $dotwaveName=NaN; AbortOnRTE //or just make a blank wave for the frame
			endif
			
			Wave framewdot=$dotwaveName; AbortOnRTE
			
			if(show_dot && WaveExists(framewdot))				
				qipGraphPanelAddTraceByAxis(graphName, framewdot, roi_xaxisname, roi_yaxisname, r=0, g=0, b=65535, alpha=65535, show_marker=((19<<8)+(2<<4)+1), mode=3); AbortOnRTE
				ModifyGraph /Z /W=$(graphName) offset($dotwaveBaseName)={0,0}
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
				qipGraphPanelAddTraceByAxis(graphName, framelinewave, roi_xaxisname, roi_yaxisname, r=0, g=0, b=65535, alpha=65535, mode=0); AbortOnRTE
				ModifyGraph /Z /W=$(graphName) offset($linewaveBaseName)={0,0}
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

Function qipGraphPanelUpdateSingleImageChannel(Variable request, String graphName, Variable frameidx, 
																String & frameName, Variable & channel_active_flag)
	channel_active_flag=0
	
	String imageName=""
	String usrFuncName=""	
	
	switch(request & 0xFF) //which channel is it?
	case QIPUFP_IMAGEFUNC_MAINIMAGE:
		imageName=GetUserData(graphName, "", "IMAGENAME")
		usrFuncName=GetUserData(graphName, "", "IMAGE_USERFUNC")
		frameName=GetUserData(graphName, "", "FRAMENAME")
		break
	case QIPUFP_IMAGEFUNC_OVERLAYIMAGE_RED:
		imageName=GetUserData(graphName, "", "OVERLAY_IMAGE_RED")
		usrFuncName=GetUserData(graphName, "", "OVERLAY_IMAGE_USERFUNC_RED")
		frameName=GetUserData(graphname, "", "OVERLAY_IMAGE_FRAMENAME_RED")
		break
	case QIPUFP_IMAGEFUNC_OVERLAYIMAGE_GREEN:
		imageName=GetUserData(graphName, "", "OVERLAY_IMAGE_GREEN")
		usrFuncName=GetUserData(graphName, "", "OVERLAY_IMAGE_USERFUNC_GREEN")
		frameName=GetUserData(graphname, "", "OVERLAY_IMAGE_FRAMENAME_GREEN")
		break
	case QIPUFP_IMAGEFUNC_OVERLAYIMAGE_BLUE:
		imageName=GetUserData(graphName, "", "OVERLAY_IMAGE_BLUE")
		usrFuncName=GetUserData(graphName, "", "OVERLAY_IMAGE_USERFUNC_BLUE")
		frameName=GetUserData(graphname, "", "OVERLAY_IMAGE_FRAMENAME_BLUE")
		break
	default:
		break
	endswitch
	
	Wave image=$imageName
	Wave frame=$frameName

	if(!WaveExists(image))
		if(strlen(frameName)>0)
			RemoveImage /W=$graphName /Z $(qipGetShortNameOnly(frameName))
		endif
		
		return -1
	endif
	
	FUNCREF qipUFP_IMGFUNC_DEFAULT usrFuncRef=$usrFuncName
	//if usrFuncRef is valid, it will called, otherwise, the default function will be called
	//which will just copy the corresponding frame
		
	if(request & QIPUFP_IMAGEFUNC_REDRAWUPDATE)

		if(!WaveExists(frame) || (DimSize(frame, 0)!=DimSize(image, 0) || DimSize(frame, 1)!=DimSize(image, 1)))
			Make /O/N=(DimSize(image, 0), DimSize(image, 1))/Y=(WaveType(image)) $frameName
			Wave frame=$frameName
		endif
		usrFuncRef(image, frame, graphname, frameidx, (request & 0xFF) + QIPUFP_IMAGEFUNC_REDRAWUPDATE)
		channel_active_flag=1
	endif
	
	if(request & QIPUFP_IMAGEFUNC_PREPROCESSING) //preprocessing is called before edge detection, and only user function for main frame is called
		usrFuncRef(image, frame, graphname, frameidx, (request & 0xFF) + QIPUFP_IMAGEFUNC_PREPROCESSING)
	endif
	
	if(request & QIPUFP_IMAGEFUNC_POSTPROCESSING) //postprocessing is called after all edges of Point ROIs (objectives) are detected
	//all color channels will be called in sequence
		usrFuncRef(image, frame, graphname, frameidx, (request & 0xFF) + QIPUFP_IMAGEFUNC_POSTPROCESSING)
	endif
End

Function qipGraphPanelRedrawImage(String graphName)
	String panelName=GetUserData(graphName, "", "PANELNAME")
	
	Variable frameidx=str2num(GetUserData(graphName, "", "FRAMEIDX"))
	String frameName=""
	Variable flag_r=0, flag_g=0, flag_b=0, flag_main=0
		
	//main channel image update
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_MAINIMAGE + QIPUFP_IMAGEFUNC_REDRAWUPDATE, graphName, \
													  frameidx, frameName, flag_main)
	Wave frame=$frameName
	if(flag_main)
		qipGraphPanelAddImageByAxis(graphName, frame, ctab=4, top=1)
	endif
	
	//blue channel overlay update
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_BLUE + QIPUFP_IMAGEFUNC_REDRAWUPDATE, graphName, \
													  frameidx, frameName, flag_b)
	Wave frame=$frameName
	if(flag_b)
		qipGraphPanelAddImageByAxis(graphName, frame, ctab=3, top=1)
	endif
	
	//green channel overlay update
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_GREEN + QIPUFP_IMAGEFUNC_REDRAWUPDATE, graphName, \
													  frameidx, frameName, flag_g)	
	Wave frame=$frameName
	if(flag_g)
		qipGraphPanelAddImageByAxis(graphName, frame, ctab=2, top=1)
	endif
	
	//red channel overlay update
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_RED + QIPUFP_IMAGEFUNC_REDRAWUPDATE, graphName, \
													  frameidx, frameName, flag_r)		
	Wave frame=$frameName
	if(flag_r)
		qipGraphPanelAddImageByAxis(graphName, frame, ctab=1, top=1)
	endif
	
	//update the display of frame number in panel window		
	SetVariable sv_frameidx, win=$panelName, value=_NUM:frameidx
End

Function qipGraphPanelExtractSingleFrameFromImage(Wave img, String frameName, Variable frameidx)	
	if(WaveExists(img) && WaveExists($frameName))
		if(frameidx>=DimSize(img, 2))
			frameidx=DimSize(img, 2)-1
		endif
		if(numtype(frameidx)!=0 || frameidx<0)
			frameidx=0
		endif
		//multithread frame[][]=img[p][q][frameidx]; AbortOnRTE
		ImageTransform /P=(frameidx) /PTYP=0 getPlane img ; AbortOnRTE
		Wave M_ImagePlane
		Duplicate /O M_ImagePlane, $frameName
		KillWaves /Z M_ImagePlane
	endif
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
			Variable modified=str2num(StringByKey("TRACEMODIFIED", wavenote))
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
//if traces are modified, then each trace will be evaluated to see if "TRACEMODIFIED" flag is set, if so, will check the flag
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
	
	String panelName=GetUserData(graphname, "", "PANELNAME")
	if(strlen(panelName)>0)
		SetVariable sv_frameidx, win=$panelName, value=_NUM:frameidx
		SetWindow $graphName, userdata(FRAMEIDX)=num2str(frameidx)
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

	String traceValStr=""
	String imginfo=""
	String cordstr=""
	String imageValStr=""

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
	
	switch(s.eventCode)
		case 3:
			if(new_roi==1 && ((s.eventMod&0x4)==0)) //when ROI is being defined, and alt key is not down
				//will clear trace edit status
				trace_editstatus=0
				hookResult=1
			else
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
						
						if((s.eventMod&0xE)==0x8 || (s.eventMod&0xE)==0xA)	//ctrl is down when clicking, or ctrl and shift are both down
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
								if((s.eventMod&0x4)==0)
									hookResult=1
								endif
							endif
						endif
					endif
				endif
				
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
				sprintf imageValStr, "IMG[%s][val:%.1f] ", imageName, framew[imgx][imgy]
			endif
			
			if(numtype(trace_editstatus)!=0 || trace_editstatus==0)
				//Not editing the trace, try to set axis names and ACTIVETRACE correctly			
				tracex=NaN
				tracey=NaN
				traceInfoStr=TraceFromPixel(s.mouseLoc.h, s.mouseLoc.v, "")
				traceName=StringByKey("TRACE", traceInfoStr)
				traceHitStr=StringByKey("HITPOINT", traceInfoStr)
				trace_hitpoint=str2num(traceHitStr)
				if(strlen(traceName)==0 && s.eventCode!=5)
					traceName=activetrace
					trace_hitpoint=-1
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
		 			activetrace=traceName
		 			SetWindow $(s.winname) userdata(ACTIVETRACE)=traceName
		 		elseif(s.eventCode==5)
		 			activetrace=""
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
				endif 				
			endif //mouse up, or mouse moving with mouse key held down
			if((s.eventMod&0x04)==0)
				hookResult = 1
			else
				hookResult=0
			endif
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
		default:
			break
	endswitch
	
	if(hookResult)
	
		s.doSetCursor = 1
		s.cursorCode = 3
	
		SetWindow $s.winname userdata(TRACEEDITSTATUS)=num2istr(trace_editstatus)
		SetWindow $s.winname userdata(TRACEMODIFIED)=num2istr(trace_modified)
	
		if(trace_modified)
			TextBox /W=$(s.winname)/C/N=TRACE_MODIFIED_FLAG/S=3/B=(65535,32768,32768)/A=LT/X=0/Y=0/Z=1 "\\Z06\\Z08MODIFICATION \rNOT SAVED"
		else
			TextBox/W=$(s.winname)/K/N=TRACE_MODIFIED_FLAG
		endif
		
		String cordstr2=""
		
		if(strlen(traceName)>0)
			sprintf traceValStr, "TR[%s]", traceName
			sprintf cordstr2, "TR[x:%.1f,y:%.1f,#%d]", tracex, tracey, trace_hitpoint
		elseif(strlen(activetrace)>0)
			sprintf traceValStr, "TR[%s][x:%.1f,y:%.1f,#%d]", activetrace, tracex, tracey, trace_hitpoint
			sprintf cordstr2, "TR[x:%.1f,y:%.1f]", tracex, tracey
		else
			traceValStr+="TR[_None_]"
		endif
		cordstr+=cordstr2
		SetVariable xy_cord win=$panelName, value=_STR:(cordstr)
		SetVariable img_value win=$panelName, value=_STR:(imageValStr)
		SetVariable trace_value win=$panelName, value=_STR:(traceValStr)
	
		if(update_image==1)
			qipGraphPanelRedrawImage(s.winname)
		endif
		if(update_trace==1)
			qipGraphPanelRedrawROI(s.winname)
			qipGraphPanelRedrawEdges(s.winname)
		endif
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
	
	//option 2
	Button imgproc_addimglayer_r, win=$win,disable=opt2
	Button imgproc_addimglayer_g, win=$win,disable=opt2
	Button imgproc_addimglayer_b, win=$win,disable=opt2
	Button imgproc_addimglayer_GRAY, win=$win,disable=opt2
	
	//option 3
	Button imgproc_CallUserfunc, win=$win, disable=opt3
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
				fname=GetUserData(graphname, "", "OVERLAY_IMAGE_USERFUNC_RED")
				transparency=str2num(GetUserData(graphname, "", "OVERLAY_IMAGE_TRANSPARENCY_RED"))
				if(numtype(transparency)!=0)
					transparency=QIPUF_DEFAULT_ALPHA_RED
				endif
				channel_name="RED"
				channel_flag=1				
				break
			case "imgproc_addimglayer_g":
				wname=GetUserData(graphname, "", "OVERLAY_IMAGE_GREEN")
				fname=GetUserData(graphname, "", "OVERLAY_IMAGE_USERFUNC_GREEN")
				transparency=str2num(GetUserData(graphname, "", "OVERLAY_IMAGE_TRANSPARENCY_GREEN"))
				if(numtype(transparency)!=0)
					transparency=QIPUF_DEFAULT_ALPHA_GREEN
				endif				
				channel_name="GREEN"
				channel_flag=2
				break
			case "imgproc_addimglayer_b":
				wname=GetUserData(graphname, "", "OVERLAY_IMAGE_BLUE")
				fname=GetUserData(graphname, "", "OVERLAY_IMAGE_USERFUNC_BLUE")
				transparency=str2num(GetUserData(graphname, "", "OVERLAY_IMAGE_TRANSPARENCY_BLUE"))
				if(numtype(transparency)!=0)
					transparency=QIPUF_DEFAULT_ALPHA_BLUE
				endif
				channel_name="BLUE"
				channel_flag=3
				break
			case "imgproc_addimglayer_GRAY":
				wname=GetUserData(graphname, "", "IMAGENAME") //the main image cannot be changed
				fname=GetUserData(graphname, "", "IMAGE_USERFUNC")
				transparency=str2num(GetUserData(graphname, "", "OVERLAY_IMAGE_TRANSPARENCY_GRAY"))
				if(numtype(transparency)!=0)
					transparency=QIPUF_DEFAULT_ALPHA_GRAY
				endif
				channel_name="GRAY"
				channel_flag=-1 //main channel cannot be changed
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
			
			String imgselection="", funcSelection=""

			if(channel_flag>0)
				imgselection="_None_;"+WaveList("*", ";", "DIMS:3;WAVE:0;")
				PROMPT wname, "Name of image to be assigned to channel "+channel_name+":", popup, imgselection
			else
				imgselection=wname+";"
				PROMPT wname, "Main channel image cannot be changed:", popup, imgselection
			endif			
			
			funcSelection="_None_;"+FunctionList("QIPUF_*", ";", "KIND:2,NPARAMS:5,VALTYPE:1,WIN:Procedure")
			funcSelection+=FunctionList("QIPUF_*", ";", "KIND:2,NPARAMS:5,VALTYPE:1,WIN:QImageAnalysisUFPs.ipf")
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
			
			FUNCREF qipUFP_IMGFUNC_DEFAULT fRef=$fname
			if(str2num(StringByKey("ISPROTO", FUNCRefInfo(fRef)))==1)
				fname=""
			endif
			
			String overlay_framename=""
			strswitch(ba.ctrlName)
			case "imgproc_addimglayer_r":
				SetWindow $graphname userdata(OVERLAY_IMAGE_RED)=qipGetFullWaveName(wname)
				SetWindow $graphname userdata(OVERLAY_IMAGE_USERFUNC_RED)=fname
				overlay_framename=qipGenerateDerivedName(baseName, ".f.red")
				SetWindow $graphname userdata(OVERLAY_IMAGE_FRAMENAME_RED)=overlay_framename
				Wave colortab=$(analysisDF+":M_ColorTableRED")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_TRANSPARENCY_RED)=num2str(transparency)
				break
			case "imgproc_addimglayer_g":
				SetWindow $graphname userdata(OVERLAY_IMAGE_GREEN)=qipGetFullWaveName(wname)
				SetWindow $graphname userdata(OVERLAY_IMAGE_USERFUNC_GREEN)=fname
				overlay_framename=qipGenerateDerivedName(baseName, ".f.green")
				SetWindow $graphname userdata(OVERLAY_IMAGE_FRAMENAME_GREEN)=overlay_framename
				Wave colortab=$(analysisDF+":M_ColorTableGREEN")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_TRANSPARENCY_GREEN)=num2str(transparency)
				break
			case "imgproc_addimglayer_b":
				SetWindow $graphname userdata(OVERLAY_IMAGE_BLUE)=qipGetFullWaveName(wname)
				SetWindow $graphname userdata(OVERLAY_IMAGE_USERFUNC_BLUE)=fname
				overlay_framename=qipGenerateDerivedName(baseName, ".f.blue")
				SetWindow $graphname userdata(OVERLAY_IMAGE_FRAMENAME_BLUE)=overlay_framename
				Wave colortab=$(analysisDF+":M_ColorTableBLUE")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_TRANSPARENCY_BLUE)=num2str(transparency)
				break
			case "imgproc_addimglayer_GRAY":
				SetWindow $graphname, userdata(IMAGE_USERFUNC)=fname
				Wave colortab=$(analysisDF+":M_ColorTableGRAY")
				if(WaveExists(colortab))
					colortab[][3]=transparency*65535
				endif
				SetWindow $graphname userdata(OVERLAY_IMAGE_TRANSPARENCY_GRAY)=num2str(transparency)
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


Function qipGraphPanelBtnCallUserFunction(ba) : ButtonControl
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
				CheckBox enclosed_roi, win=$(cba.win), value=1
				SetWindow $graphname userdata(ENCLOSEDROI)="1"
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
			
				SetWindow $graphname userdata(NEWROI)="0"
				CheckBox new_roi, win=$(ba.win), value=0 //disable NEW_ROI status first
				
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
				
				SetVariable sv_frameidx, win=$ba.win, disable=2
				
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
		
		SetVariable sv_frameidx, win=$ba.win, disable=0
		
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

Function qipImageProcGenerateROIMaskFromBoundary(String graphName, Wave boundaryX, Wave boundaryY, String roimask_name, 
														[Variable valueE, Variable valueI, Variable erosion, Variable dilation, String getMaskBoundary])
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
	if(!ParamIsDefault(getMaskBoundary))
		ImageThreshold /Q/M=1/I  roimask
		Wave M_ImageThresh
		M_ImageThresh=255-M_ImageThresh
		ImageAnalyzeParticles /Q/W/FILL stats M_ImageThresh
		Wave W_BoundaryX, W_BoundaryY
		Make /O/D/N=(DimSize(W_BoundaryX, 0)) $(getMaskBoundary+"X"),$(getMaskBoundary+"Y")
		Wave saveX=$(getMaskBoundary+"X")
		Wave saveY=$(getMaskBoundary+"Y")
		saveX=W_BoundaryX
		saveY=W_BoundaryY
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
				String analysisDF=GetUserData(graphName, "", "ANALYSISDF")
				String refDF=analysisDF+":"+PossiblyQuoteName(num2istr(refFrameIdx))+":"
				String currentDF=analysisDF+":"+PossiblyQuoteName(num2istr(frameidx))+":"
				
				String refPointROIName=refDF+"ROI:W_PointROI"
				String refEdgeWaveName=refDF+"innerEdge:DetectedEdges:W_Boundary"
				String refEdgeInfoWaveName=refDF+"innerEdge:DetectedEdges:W_Info"
				
				Wave refPointROI=$refPointROIName
				Wave refEdgeWave=$refEdgeWaveName
				Wave refEdgeInfoWave=$refEdgeInfoWaveName
				
				Wave currentLineROI=ROIDF:W_RegionROIBoundary
				Wave currentLineROIIndex=ROIDF:W_RegionROIIndex
				
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
								
								qipImageProcGenerateROIMaskFromBoundary(graphName, M_ROIX, M_ROIY, roimask_name, erosion=dynamicTracking, getMaskBoundary=":GeneratedROIMASKBoundary")
								
								Wave MaskX=:GeneratedROIMASKBoundaryX
								Wave MaskY=:GeneratedROIMASKBoundaryY
								if(WaveExists(MaskX) && WaveExists(MaskX))
									if(roi_idx==0) //first call
										Make /O /D /N=(DimSize(MaskX, 0)+1, 2) ROIDF:W_RegionROIBoundary=NaN
										Wave currentLineROI=ROIDF:W_RegionROIBoundary
										Make /O /D /N=(1, 2) ROIDF:W_RegionROIIndex=NaN
										Wave currentLineROIIndex=ROIDF:W_RegionROIIndex
										currentLineROI[0,DimSize(MaskX, 0)-1][0]=MaskX[p]
										currentLineROI[0,DimSize(MaskY, 0)-1][1]=MaskY[p]
										currentLineROIIndex[0][0]=0
										currentLineROIIndex[0][1]=DimSize(MaskX, 0)-1
									else // add ROI points to the record of ROI in this frame
										Variable roistartp=DimSize(currentLineROI, 0)
										Variable roiindexp=DimSize(currentLineROIIndex, 0)
										Variable filllen=DimSize(MaskX, 0)
										InsertPoints /M=0 roistartp, filllen+1, currentLineROI
										InsertPoints /M=0 roiindexp, 1, currentLineROIIndex
										
										currentLineROI[roistartp, roistartp+filllen-1][0]=MaskX[p-roistartp]
										currentLineROI[roistartp, roistartp+filllen-1][1]=MaskY[p-roistartp]
										currentLineROI[roistartp+filllen][0]=NaN
										currentLineROI[roistartp+filllen][1]=NaN
										currentLineROIIndex[roiindexp][0]=roistartp
										currentLineROIIndex[roiindexp][1]=roistartp+filllen-1
									endif
								endif								
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

Function qipImageProcFindIndexForDotROI(Wave pointROI, Variable roiIdx, Wave infow, Wave boundary, Wave roi2info, Variable infocolumn, String roiEdgeName)
	Variable startp=-1, endp=-1, centerx=NaN, centery=NaN
	Variable selected_idx=qipBoundaryFindIndexByPoint(pointROI[roiIdx][0], pointROI[roiIdx][1], infow, startp, endp, centerx, centery); AbortOnRTE
	roi2info[roiidx][infocolumn]=selected_idx; AbortOnRTE
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
				
				qipImageProcFindIndexForDotROI(pointROI, i, middle_infow, middle_boundary, roi2info, 0, roiEdgeNameM); AbortOnRTE
				
				qipImageProcFindIndexForDotROI(pointROI, i, inner_infow, inner_boundary, roi2info, 1, roiEdgeNameI); AbortOnRTE
				
				qipImageProcFindIndexForDotROI(pointROI, i, outer_infow, outer_boundary, roi2info, 2, roiEdgeNameO); AbortOnRTE
				
			endfor
		endif
	catch
		Variable err=GetRTError(1)
		print "error when generating the index of W_Info for each Dot ROI:", err
	endtry
	SetDataFolder savedDF
End

Function qipImageProcAddDetectedEdge(DFREF homedfr)
//add detected edges in the current region ROI to the stored edge records
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

	if(!WaveExists(image))
		return -1
	endif
	
	Variable frameidx=-1
	Variable roi_counts=-1
	Variable stop_flag=0
	String frameName=""
	Variable update_flag
				
	DFREF savedDF=GetDataFolderDFR()
	NewDataFolder /O/S $(param.analysisDF)
	DFREF parentdfr=GetDataFolderDFR()
	
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_MAINIMAGE + QIPUFP_IMAGEFUNC_INIT, graphName, -1, frameName, update_flag)
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_RED + QIPUFP_IMAGEFUNC_INIT, graphName, -1, frameName, update_flag)
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_GREEN + QIPUFP_IMAGEFUNC_INIT, graphName, -1, frameName, update_flag)
	qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_BLUE + QIPUFP_IMAGEFUNC_INIT, graphName, -1, frameName, update_flag)
	
	try
		for(frameidx=param.startframe; frameidx>=0 && frameidx<=param.endframe && frameidx<=param.maxframeidx; frameidx+=1)
			SetWindow $graphName userdata(FRAMEIDX)=num2istr(frameidx)
			
			qipGraphPanelRedrawAll(graphName) //this will update all frames including all color channels
			
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
			
			String roimask_name=GetDataFolder(1)+"M_ROI"

			
			//preprocessing main image before edge detection
			
			qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_MAINIMAGE + QIPUFP_IMAGEFUNC_PREPROCESSING, graphName, frameidx, frameName, update_flag)
			Wave frame=$(frameName)
			
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
					ImageAnalyzeParticles /Q/D=$(frameName) /W/E/A=(param.minArea)/FILL stats homedfr:M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(frameName) /W/E/A=(param.minArea) stats homedfr:M_ImageMorph
				endif
				qipImageProcAddDetectedEdge(homedfr)
				Duplicate /O homedfr:M_ImageMorph, homedfr:M_FilledEdge
				String filledEdgeName=GetDataFolder(1)+"M_FilledEdge"
				qipImageProcGenerateROIMaskFromBoundary(graphName, homedfr:W_BoundaryX, homedfr:W_BoundaryY, filledEdgeName, valueE=255)
				
				NewDataFolder /O/S innerEdge
				ImageMorphology /E=4 /I=(param.dialation_iteration) Dilation $filledEdgeName
		
				if(param.allow_subset==0)
					ImageAnalyzeParticles /Q/D=$(frameName) /W/E/A=(param.minArea)/FILL stats :M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(frameName) /W/E/A=(param.minArea) stats :M_ImageMorph
				endif
				qipImageProcAddDetectedEdge(homedfr:innerEdge)
				SetDataFOlder ::
				
				NewDataFolder /O/S outerEdge
				ImageMorphology /E=4 /I=(param.dialation_iteration) Dilation $filledEdgeName
				ImageMorphology /E=4 /I=(param.erosion_iteration+param.dialation_iteration) Erosion :M_ImageMorph
		
				if(param.allow_subset==0)
					ImageAnalyzeParticles /Q/D=$(frameName) /W/E/A=(param.minArea)/FILL stats :M_ImageMorph
				else
					ImageAnalyzeParticles /Q/D=$(frameName) /W/E/A=(param.minArea) stats :M_ImageMorph
				endif
				qipImageProcAddDetectedEdge(homedfr:outerEdge)
				SetDataFolder :: //back to home directory for ROI reading in the next loop
				
				qipGraphPanelRedrawROI(graphName)
				qipGraphPanelRedrawEdges(graphName, rawDetectedEdge=1)
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
			
			//postprocessing
			SetDataFolder homedfr
			qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_MAINIMAGE + QIPUFP_IMAGEFUNC_POSTPROCESSING, graphName, frameidx, frameName, update_flag)
			qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_RED + QIPUFP_IMAGEFUNC_POSTPROCESSING, graphName, frameidx, frameName, update_flag)
			qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_GREEN + QIPUFP_IMAGEFUNC_POSTPROCESSING, graphName, frameidx, frameName, update_flag)
			qipGraphPanelUpdateSingleImageChannel(QIPUFP_IMAGEFUNC_OVERLAYIMAGE_BLUE + QIPUFP_IMAGEFUNC_POSTPROCESSING, graphName, frameidx, frameName, update_flag)
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


Function qipGraphPanelSVIndex(sva) : SetVariableControl
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
			Wave img=$(GetUserData(graphname, "", "IMAGENAME"))
			
			if(modified)
				DoAlert 1, "Traces in this frame has been modified. Save the changes?"
				if(V_flag==1)
					qipGraphPanelCallSaveFunc(graphname, frameidx)
				endif
				SetWindow $graphName, userdata(TRACEMODIFIED)="0"
			endif
			strswitch(sva.ctrlName)
			case "sv_frameidx":
				Variable maxidx=0
				if(WaveExists(img))
					maxidx=DimSize(img, 2)-1
					if(dval>maxidx)
						dval=maxidx
					endif
					if(numtype(dval)!=0 || dval<0)
						dval=0
					endif
				else
					dval=0
				endif
				SetVariable sv_frameidx, win=$sva.win, limits={0, maxidx, 1}, value=_NUM:(dval)
				SetWindow $graphName, userdata(FRAMEIDX)=num2str(dval)
				qipGraphPanelRedrawAll(graphname)
				break
			case "sv_objidx":
				qipGraphPanelRedrawROI(graphname)
				qipGraphPanelRedrawEdges(graphname)
				break
			default:
				break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


// PNG: width= 142, height= 142
static Picture QingLabBadge
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"Z!!!"Z#Qau+!,/"&?N:'+&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U+94u$5u`*!<4hD`D:`bR<l<ek%!V]qDrBYL8u+jLQ8MdMXB+(=,tK"d!!3;EhrQNU%ikl\i&&#^V
	]-YcjHemuZpdh=`L2+$I.M^"ktYmFHWO32gaC3(_#84lEA"JN>.&+I.dX_n!t'BE*bPV>6(:VZdkmp
	%faVP/dK-Xf:KdGj(_ed!RA$'JE!d(O;?eIhOO+VN!HVY%_:4kr8iFlRd!60V9egmJ#&L5M)(hNkA>
	g7VQS+([AEX$"8o<E(C<D@2W8\p5Y\BBP.qJ@2!2)YdA;5W3A<<R2AqrfUOUSBBOGc:\7:APuP@S8X
	N&2k^.*FAtqQbo3k+(b3N$`sJ78\bi'WGXtKIRlhA>0Lp"/BUnbTQR0)$O$b5SHniHg>g<F.S?1-!2
	><1bVenX,8UL/1TQZ445ZHTg2$o#)Eo="^`th@de`3,$3;K$q8%e(CnZV8.ABP7nKsmkB//WD-JdVl
	n`$iVP%IO.d,&&""PN,3F`<6JnRt\<A/(MLBM@F6tBn?8[=EcN0nW\0bXSLJOte<%1iMu'J+k_1'!C
	qA<(,,ShmX>.8`uaJ-\C?C;:$a?tKHO]3Z$W<="9-!0@Tu!r?dO*1A+MU<R]de<@A?)KSe1!`f:7OK
	=u^;'fjL.>\<9ACFkk#tY7%MB3In';0mhA?]p7*'bsoB\A$D+W;Q*C5``EUKQK]fu+k%l8Ub'c'EBN
	;q)t'0EhP91\=6J+@RNqM9$j"a5]I+&HX2^@j#k%W!_BT;Jt3kmC!gVe&u-%S8jZV&_R0sYSdEMVMU
	7gJBYf.'aW&88_<+WB*#k7^')GlQ;e:F'74@cOp=5u7g,b>!uMo+!<=hS#Qe[YJnS;O!.D;GZSKKCN
	]<t?Aed'$0[jR$%G6r%TSPpH"GU:a!0@3a%<<d^B4M>r69m"M)::IA5_`["VJ-T`!Q:06J>.?FFikt
	'-3-XB$qpqC+94ethQoNLJ-KD]!X,M'D+qeeKg=kmVGkSH>fu1oEtVmcEf>h-<(ogtd7c*ZR13;L:]
	NTh)C/,dKlbO"VZ;a>^d(d=\pe=]:#@eYMePJ;N0qZe.=i'j77:ZU5l`Y?!#%^R<(-cu+.0)1fJt2i
	!)lf*c@\`JWZYt%VN;7T!>WfY#QOjTN#3-,MLl6O<JmN85m@Fi>fsb;rCfU%U]R4/BE3RN!!J6Sfg&
	73!"F;]_)k%-0Se`&c_b0oli])K@u$/]3HFI<pO*fE73a'6<BqiS1D(3!!($bk5qi9`<H*s1%1s"lW
	PD2);9Q75cP_]RlDe;lo,OFM31,L7Ec?_X;ahj@)^).!3X$`t!8)u.oR.fUW$mRu#f/6g6O&O\mt\(
	1]"X(LaGp9`3cE*\#(utg$:(QJ`=O_sAlM$<#RKRSg<Gq9`t3o&V^)HVSM-scPe&a_&J:Ff9b8!FQi
	Rat!PfP>OP/:=2XT3p"Umu1O&6T=j,Wt!?a'g!Jn6i/Z:&@3U.PEa7Nf3.1c7%-3Q3TpHh:aAbogcf
	OJu38dP2IT/[[<XY'lS2/#l3-(s1,]8%#FK3QoKF!8nikJHI"s6tCga!WWG#KLVbF`*d7HRWI9(L]V
	p.$h6:O0!LCOTECTNahk!Pi)Ipc8nR/:bT$gTo4H9E6mS\_pSu"5NnBb&N3R6S:#Ceb1-9)9`$h9,W
	e(f,`'dU%d:3/A6tKt"n>MV72k-/M!2AO\X>A*hk_")n><hb7A#,9t,kJ%)U;g:LXJuU3M?)^f)'(I
	@#Qg;i)WB&F[Z(S8<1`bB73?T/P"j(E!'1g)KVV!9AnJYB;?8WV-pr!bg:FR>(ZdEmNFl6Q7p:b;C5
	Jl=l`MhGS!"jMpZnYj%\`Nd71@7f>a"HM2kV-"!*hE];ZoHQ+3_qC'WagG?ts?tUY<1_'8k^R(hJO2
	9?o93;IraNW@?uJ3?`?W(1T[#!sKtP#)$?e"TUef;bBX*JV=ZjOJNikmEkO*2g2PiVlZP)AskBIA-,
	1B!(6r[8rQFbPpH6o>has@Vu]mUToFpPj!o?>[7ecEb3dT$>,oQjF1g:e"l(eFZe_c;5XeDl%$;5EE
	e-p]qthj'pHrm'>cs_0UDdeD^`Rr'$s>icVD8IHEC$!I%`n]9ND)&WWfS,:P^@b`Y2d*V\t##H;pX5
	![>,j]*,W,-k@-3%4M\k`_XVk+pHu"IXalAMe%..<(eP<-"Y%9$#0$WIAfqu@^bQHd;$%mpK6&J$F_
	'hM9igEf*^<b3]36$Do'Uc?e]0WB]:<N7m84^s,g59^gK[Ggj70WFC=8b?!+Z@IVP^@CV>t"9WiDMC
	'TpM6PYt,%*YKk6&0YZ9Qi]8j:e!]lUkDP^!aq3RA9+[nkFuhKo$UmHrFYZ`:L?W!E],qfn^QO(2i@
	EIdgtch7;OU4ACd>)5Q'1f*kh<i=ET4s?0g.mdOqa8Lq,eE8=T],BBf#$1g9QLY0;s=DgJ'Hs4<=0N
	O4eR`$-(nAS9!s6B)1_@\QXb8o;%.o;lMGR>/hkPOJKPs$FogNIU\@_rHZ3fj]FakBuaD?"T['Vd7o
	B=j3itWt<-%$q/%jFmW"bAdXpA6tEcHAu8sA*%2N_W%Os2E]tqM;`C_hpK*CccJO,LGlB]0j[X7'4*
	pbCh@I=tRH>#tBBRnFlJA)df]T<]5!O>O3Lifh4R!gfYT]DXmRZk#X8r7IJZ7tD:#!*#6JetgR`,R9
	o%UUD/>c8LeN!;7?8]A9%M/:Uj_\i23RIHhFSP4j0E:#bo;D=Q6U1#E!/lesh<XHUn`gX6d(JnlLNd
	VZ%`Ng]0:Ve%j\m.$9ld=*^1l.^Y_Xu2&Ou`-mJ?0=UJ-2o/fVjF,!5+W?hr\Sna)uefD?R^8HI>AJ
	P&Z=C=A&\9IUKa7YK!E->'+VLnW_%&XY\*8DS7\jtBL_<pnsf7NPS>`qYdSR:/0.]Q_ZoIDR=3<TUp
	_q_k9m`6N9+9f\\T[..tD?7uV)>`Wttg;JBQbbfo(Nf6OMh9)-/5Q&Xh`,6*CMg+'.mA4THMEh!qrf
	=0JgTCX27<r#7PeQj&IGq`s5Pi:pU-0bFhtM+O)P\cC<n4K,ZOnDR1%m=_:dcPJ*=+/6O9-Q71:4%H
	;d0?g0s<dSSM.Ek[CUC$>1H@hSi(H$IK+6c^AGN$(/6i/Smqt$#sKNno.?2Fkdqq^RMG^%?*8URetq
	)qC2RTjm:OXK(@<=r('PM+*k24:@tL5`&1CfE(46-$"2bOa-JHKcP"EV)3+>AtcRo8aJOg3n$osfFW
	\D%ngH+K./2h>Q++A>*rWh8MHi&Bu$NLp7/lY*%P$jU2`Xs[%A)!ksRYLlJ4"4&c8\V2dPLQb+jhO&
	s<g5HAe\o\UJ1.(&T\<q9U0Z60o2S$uFIR0L1>VZ!:23@,F)\i4Rc3Z.lCs73m^nZ5j_+k[QtTmiI`
	Rga;&"m`fJ*@+W5B%>7LDNh@\>u:J7sLhfEBQLUoUW]h8d%n%__o7K3p/Fe\/HL]DpGD`T_D,%*._X
	IL#pV"h[K!Q^dC=ZWl(kf+7SE['CZ/6P2p708pYhHdL7s;?bnc[C<uFFds0SnmiMdPC[dmJ$BNbp9S
	-(M@rb:TV./J`+n.ZeYk#2&J5HTZPif^,'iWMP15l=ITZ<uebshhf7NVEBP^gLT)c)kg;Rs7IrON2(
	[o-96&pAP@OafLccUrQ)qM(43<1c%ehLG3kh`,88'B(KT<Md3LVb"a0]\U#6kmJ&j_X9(F[Np'l#K>
	8bKYFKkc)5=>lat20j.2)mH3PX+0hi!&AJ!@GNCk=%KMp-o\Q@\*<n!F!UOQN-R,Jp!!J%R$=H>RJ0
	$6(YIN!@lnX([kstdDLSp1S/ro)7cQCI%C2>fool<AWgRn0O[d0f2To7;u-'$/K^l?=,G5fW*i+.-,
	Lb2[>5Z,d!iJ>_t!.lRtdA:MT'mSd(jSIE5gUHd#UJ2^J`;TY00>?/(qrn>-4^AdPCnbYGTT&#aM!1
	RK?1=H=!C7@A7K<RYL;'%6U^S2@n^I#DYJ0l+0BXLNIIuda#EP2f(M-lNE+bLRrSd[s=2+m0<f^%Cb
	@Lt<qXs04UZ9o#`Rup%$;Fkhm_JMUdGhR#p0W5^FEk0!DhiIB3ZlFWN+oiiRS>F;(`r$NR4e3_o;:3
	Df5&Vc4ak6A%T!)Gp\hB(VUN,D*6n6/kP``ar,f8ol0-:3$SSXFHRng7&@2_$&/kNcWW=OM)ZYC-b`
	_3Cda/!D'EHN]gXR,TdcUPdr=\"4Du9(FMrVL7ViK[5o]@r:qsmhfRo`qome=<Ck48M(e`gXMD/Yss
	UWNGpq!a^;Fmp!YRGu?YK:<s"DNF%`Y9M&2M#C]mZ"pM-2)g.0eA/2=V<c/lJ+TkbGJ47LI;n`?FF/
	>%&T)G!^A=kBE+Ag*Dk+Oc[qW/@1$<4\c;E[*HFLD)_VQ*q+NA<,fpnVBbB<+(D;3AH%jo=e]JoGg;
	>e_k_qpm`DBph%h(R&,p(%]-NXjB9QXU<J5JR!5X7H&8D7;r2bcdQ+dII"Zj1QO?4o<\m^OkEB[%5L
	GI-Y"CYCAQmC.VR?S3r.iUDh+SP[$1e>`e`H\C[6.f0g!<li$)%m,3Bh++9WiG&;qk_8:ADjlG?Ps7
	BCen(t\1p:9Nn*"n>V'qQFc8kBS)LOl=9l3<H*ArQNNar<Tsq!dcl*;e-sLUZ.:'u':e^3<r^rjQLs
	q;(1GYM7T?qUs*dXqYLFTC5;2*E)8#0#_9T0)'#@q4cON=aXA"i=EYlc7\De+VANP(^<M]\3.P%UE?
	tSmZ`!q>X6eu-HA$6KZWu'UW`$]8hm>!o8lIB2kPTf&-(2-%mi9eNhVgCN?!9-N+j:;$GI"("+VO^g
	ZGrrQpNq:;]+%=*M!Ya7H#0e6"=R"gs^:aEpbA/p>Y%Ye+G4aiTMCZ7tH;Sh%:TO*2ZZHG-u<H6tt%
	j0al=a=O+pqqgNB9gHRsdOW9`R/-3^P1O7Yc0J^u:JC"FmOf/K3HbZMk;/fh^o[g!rZhDA5\)03ZpF
	m"B=b2-o;o"Vrf&W>W+@AD@P,qoLQ3^%_$!<g5BEYPG?IUH)42BN\dC*KEMea!Y.pr(<s)hC<mkp(T
	6O5tJ\RR9AnXTHG`*$+ci?#!C\1POfS8^5hN63'0R<`FQ*FG=CWT`t=s#@db)4@7n),?O][r1f8T?4
	DmDX4m$K^!lfMaQ6A\;^+Uk]&\KKV:Y$+D=)V#a$9)Af2'-f[ROMNG;)..Lb+?"8WSGBF/RW,4*OL,
	+[;MYG(@<Mb]MYM?st?B$HpJH>E`=eN-2GY3O-a4LSOJPNfp4=%4Qa(R#J`0<&VHTEp?GL*:n/9Ss]
	&&i.!AN&"#W2ML0PEE-#DbDAO.H>C2a)IaUL3%L>dD-KL#5QD?^@;%3\@aa/<FhlhRWN)?d!$Gn%KL
	.p4&<&RpCUX2\)/V#e9R=QuN9eWq`i1"h?*B#le$lZp"NQ=37:g#cco\,k+]PjOc41/#)f[[0Cg*(K
	Lj3T?qSlUsYMO/Gq(>,Zi5p4+3k98&gun*+2,p@4\m8Sm_0I-B?.3CPF.j0r<EVR)'Rf\:4UG4g!<Y
	[O(d/FMKM7sS63-'Vgu'k#T$"@lY.Y510Gk(],KJBT6.Eucn3u4Cf#OL53#!MM'XB7,BNj*SdMK&+:
	RWhIS$k\F!=SI3-j1$:aT,F.<FIq[FBo\m<"b9tNp;jZPOks@6*YO_FqoOuT7?_6hk.[TDKTmuWMcF
	i1it#Y_7:3&:dkuCn2D^a[IXEL7DNpRV?J+t.T"&T-sc5SnE$!o&t3G0dDttn7mob0$W?B$cI-0,&n
	XHr!u-H*V=W!*%$[PfNFaG=%r&Xedh-k>V/=>S`T*>DB5ZdmGEX^ODoLqnn,:XFR's]D[\'gsED[TU
	MLJfDjeQE8*L4I+"W+"hOF0SefsD)TjXUku&ubr;:F;R\F:`e_D;1<9-jmnD6rV6[Ur4-kdc;F6NZk
	<<ZQ3'+i//Kf'8ZALYcMSSS(7LSMA]#fJZgk`^i`I\AggX2;MH?(+#+[GAE\&p%KRd-&.7Xu<[m[X(
	S+qk=Y?$aod>0X5('_dp[,ZDh[&qqTDn/+s)7ntW"-9#``-`Jg`re.Ff`MR4,Vts'EA+JJ9Nb/)E9%
	f3Zcn7#Le-,(L7).cXA()]2oQ8`2KA.,d;+[U]LNq!*)op+u+",W.\VLL8^+g0huA6EsXFq3$(fliU
	I-969/!Y!5KkQigAD?-T\'+$5J@baYA^B-&8`J@rQ%blUed%WQSbf_!@h\JW!oIkX5%4HmKtmf(WAo
	:h5*I-:#1sO:`C2eVK#L/R&D[1h@s$)%jJ?[)n%gJiZg`L6.,>4inS74$KeA`,F;q/>1qHIK0qT@T%
	*QbPg@k/Y%1NB)C`F@C[uu(=_B.rR[XO0(!6h%_!6I=-r7]YdF#n%!D:l/e\O'-oh9.5UC'_VMC*.&
	)McqiICcHGjDK4g]$H(5#7f#H)iAm-0WDa&-,ZA11`fa,V[s*,@h-H4!VmEM3ZF%EjF1<[1iVC2^'7
	EGYU/"/DA2s'>^Ua'StCm5g7NpW<3^q;b:_9kYMT,^_8CN)Dd&6ZO:*`C:7Sog&B7^e8D=>"^F:N='
	de_M)#Z#I2g=\:]Uini/0l(0EU8o(nqo[W+0:T(5s`3(ki)bc4`6/SdZ4%.n]&;G:$^PV?"cI4*<61
	6i`$3hJG[sJj),u?gV@=gNPmXZi?NPqk/tdUMBh:0?h0)h<R#&hsIhS6G)Z:6co^+#lm3j5YqKtfrp
	;b!$hZr-Wf?Ul/P;.n*\f&PNQ9)r:H<ge)Bi=HR[\4$%jMX/QgDl`$,2c!SWa)"`OGAaQN`+m;UYhq
	8*jPd`B9(d4O?9kAIn[FRRNIicI6mlq/T8$C[.s!^I%0AMH<P;37:Q!43/;9[/pcTM!LF:+0h$E:<L
	-s2a)I<(og]o.Q[T/j`PK&jn\M(<THeg8Snm_Z5<0UN1dAKFApS"X$5GN0kfb,\@fY8Ved0;7/7O6&
	)o(-o(rnG_.?U7r>0>55?[]ankD4P-.k]mbH&/IU$-\SM0F'h;.h_s7WpNk8JCJd]G-6UKItf,W\^.
	$G4(T:]s8qCeq9o'a-c6"G(@gngc@XZTj":DLV<U4/WT1::_58B9==#OuumD"&K+3g/1I!+sSoI,=>
	A%_%[.lfJK%bZD'\06Ubn(^Xj&T!F;qd\ek(?@T#gA=Ys;_<ZmEefGGX:D$rb1c4N,`#5$gR>u!:',
	9nqfBdii7D)QA55+`!%)IKW_j70gIZ6Vc^6h]FLF=3^JDC-J4;OC4R=p.7u![CPQ-:f0pU<:i,S+S$
	q0"n3$qK@IACr_r8;8IA+/jQ'0L.2C88[>#Q9O=5*l.2bQs(qSp0;dRP&,kOOgZ*qPhtui`CTda]Cs
	Lr;eM"Z+S_kNpB9.R8An9!pblA0B<tGPf))R([V?hcSN(W!;2h1bcdBDCKAY%F_FT1e)jMA8`J1#1G
	5k'gecP'[j0`3MA4$k9)@qI?E*'qkBgGJ16=DlfSH"(E-eB-sCf,VYLh8SHZ>0O8@D2_1&Zg$"dPRN
	^idKi*/7'tG"O;tTJ>a1VOSB[(cJ%!,%S9-c0H[kq_CqdYi9K+"i=GK;\rK[Td2A@um(LntY&:k)pB
	9T?_bU<;Z7@!F9UfguV2!ig%+MMMN_V`)AM_7mo:d`p0M](oN4rC*>h;WJMft[RYpYU5]Yg8)_q7-s
	jrq-'UJ+rFCs0-YFKE(S95CN"6:EEehm@3"7MmB:^gim;GVI1N;W9B`Q)5n-2JO**8,8a>E-/QE8g#
	TKocc7/V\i=&oje`)483:Z\&JT[e,nrU8GA2#_\%L(DI*`#Mqq-t9N2"H`PKtj^T7)kUc`Tqg2"^=t
	4KR.IJ+@OSZJ;IN%t/^_J*+.?pRZ`_QXNp\@6STN58M:rI0sk"liB2#"B="M$tP%05"0RK`s:N%]qq
	Lks8+.Eg,jfW\()V-5Q%qmYK9+6:_l;2"9M+U/28GIlo.*d#!%bQJpp6jQXRK0'N^G6BJ(?Cn(lul-
	At#3?u6=B+:F;S!C5<%5q!!WKES"A!2uZ_k:q+_^H$`B(+u*:.n:ueoQph<npEWl^%0l+L%K&(H0=&
	;LS$^-bVKVslPR6,W=$tKA,r9UUhC5IaPb\'PlT#.%)G$?5F]@aoJ=th5T`3ODjhP@(1j3\h%p2]@o
	I$_WalGb:H0(;)`WC(6et2pRdK[I4b&ts=6HKJb>7P5gjS*`.jn\NjTV->(Bcp*oBn"!\=V#:n^5%p
	#Pmf.+5@dbO1If\EcL3pan;RSfmIgb4?kiZrP_TeQ.He>A=K<*8X?1pL;Te"rGR2/Tj)tn+7GcWrRi
	i9!*?r)!q4CF!F7keFW_eL&1AG2.YZrg.AS#TPY!FGiUOHA?GZI!qSBk6VuU#WJ'bq*Q>;rR$dXg0Z
	]'>U^C;fjcg9!qK\2m3#qIDg\Hd7PMf/=e5Pt'BrPr78a1$!]Ru>6e^28X,4r19cd:2OYrp":hk,6P
	=pcR^*>qm9m,pl%9d0_Wt,:=['KLi,#!0"!MW`deI)SC%^)Vd?"R-td?BX6:V6AXRHQO.`b22o+RQ.
	'9Tfh;EfZQ>H%go`<uhV0RHE\rK*O+-b?s+:*E*?&e(U!$Gf6Rr\<QUQ=P]DU3m:VZDVrO;SUs24`;
	^\,J=W0#du]Q\&,0fc^\UhLX.gZ:n#08C'%*glD>Z$/<[n`b[-?_"k.oTeU3*u)`7SbT<R$ZKb-S<\
	3cieq1Aj$3OT5P`nY$2!@cId>f+J,e8Ib-72-,%Xo?$\MtHJY>6.a)H%ti"p<*,X-YL#`]D]P>C'8X
	8fL%ptf#$"2u-cRB.7rl9G3knjboc:LCa-[F\0fpaTN1Gmp9:C,P`K:;T<R[\9?Ffoo'Wk8[:E:6N<
	^B7CsdI<;6_mT\N^JR3fqn_S_!:SN,.l4%CXDuB#>^N?F^.J^:5UCse^!t]^/;W-a\AY%^@B]..DkN
	AK9oOn%[n$5Ic%7L:@./V84P@^*d54m]=?KU!ddt<GE^%Xf%0J1IkFa<`!%s6Rmq8,)H[#[NES.-&;
	+@*0$\"L2PYLCVC5Pl-WIj9@4lNR.jG;%9+roDaF:+WYGlEY)&Q,H@fYeN.JMu&)I.)\o"hu<D'D+2
	FOX06p>T@?Y"]74k'),2``El2c^aIup&s%N+@%=\?>3;30-[piWKqp)Yc+Uoi-P%.NA*.(1nZW_kLn
	HXR>Qh]d\Xb(I2+'KH[ki-h3,61bH[V];Dk+TRjcY^mHkKa&'bI??Nf8fa+YKhUkCX[(Nb`RL=F(Wh
	DcuEs_%*SSm&+=mZTA8,Gf_%s'ohU)9GNe<jgL;Ej8PphNY>4PVs5\+tiNI`QnASJ#1@;ZUpJ?SOJ;
	k,%cj11&r>GYF_134k&4gqAPp>:HHhS%=Vu)B.0LUp]T+=)1]frEV7Hq/5[smu0jY,KaB.M]E9%:(D
	b6NH63<e\`U+,pig?1#Gah'YF/\+OCAm]k<T79J9+3JZNp3"&nq5*NArV5MZlb-H4\4EMj=`%^5S`B
	7VCjrmm<B#t60-6]cK3#,/+1f/&<OBF=J,[(5MpIHUJ)7m:o(;$F1lT%Q,1(KoR=4=bp;*<fm_/1hS
	*bMbg7.T<2ipO=O@2bU#9Gt8oCMSJhjKuuSubtJKs-9=m^aT07CASd%*HQ+>`jf3&\MQ"%DL*)q.90
	VL\\KYMWnr'E.GZg3!_jE#!h/K.4qhI4Zn)`PFpUM[qA]`]%Jq3ff-YFK?_e"(IgTTQkD3.&Ct-rmC
	%e$Wl^V^N(3Ek-R1Bes+m?$Na[hg(rC2JVrm?o\fir%6YC5YD6n*VU$G1+C;Mr7Dn!K-0>@5mX2"TN
	5<'`0MccqC0(kcHY0064+q:,LJLj,YY+3i4Dd5MSqF5IFS7Y\]3O5E4chd>kY3"`akfP^QQi#H;^3V
	IOa,<rDGSZXHgpXrXq3?TtA.R%qn%Er6kARc#hUQb,7][qL/bb`m7uqQ$q9/;0^2cQCGi>LQ8gLmFM
	l2()>N_%hhL5<8edVLiG96bCkKc;@rF4B%_dHrRR0bkGrTU(i`hR8*O!Nnc@t_(qVnTllFrl[)?N$F
	uWT!)oLLl3bIX_:Sm_\Ko_!Q;)s5[MdpV3MfU\aeQ[c10d-?@C%M3B\ggU;Onh<#g9Y*RhF/2nk.lO
	'g[/QC`&N*$-?lZEO!b@3;r`Yc&#KJ$uoaU*Qp\0LtA)s4`,lVAQ[SZnltYF.7@-P>ZA#Y"-4p3f*r
	r@d'=rtk^]m.Q(Lb9[cZ.*]-%?MWC5a[r(_7op48ItCT`=mTS:eE5C27;$bre^_f^6lM"O4`(fj%6G
	Yp8P)@\H=OntcVCL<?E@+Im!F_mR_*:-QMf:nCL;Ikq;gu5akbplC%LiaqSE-rj=Rh8BXrNNQgXA4g
	15AGmFdc@#&o$q5PaT2m-T#o:ER*BgRGFdAMX;d+94u$5u]cj3H$H\?\T,dVEn]Y(cr-oBsXKsWnQ$
	73*9Gch60O:pZc#FG.T5Qmi-^6V:BmVEV7Guo,mu$iVO^_Rsq5JVsDg`s.R2Nj`'ZjB16D6?udm>mN
	_r1oX!#]s1*XOGi-,+MgYI+Y+D^hRl3P:[TjTNY7&EN:T!a:?Jfpf`7;MWD*c.$8-=Gf.=`'5'2\W,
	-)r)l?]8$0+-"r^MSaVuV<>nj=lI81I5+$h[cubAa)LM&JVL(`jDb+PJ,dRYbRFs1=WFg>6\.mh_FW
	UX,0imGV"BLh0[!TR>1k6t._%`p2k/!-Nha0*L?O/&mt:40L*h,t#pM<F40,B6B:lAfXtO,G6;i5Z0
	td8[bs20aTAj<B/O+%1nu[,aMk?JEH0SXB@(NaK5C7E\n\m.ehS1U8r6W?i_('!=8.IaP8J-oO.uPT
	q6UBQRZpXH+^l9hWH=^:sZb$(9.VLTrrOm'?Aqu;FC`fi5/s\HjI(^*']Nj./L!KjhE!U&^%8`lnHM
	64-X,fHW)Z*ApVQ34B?[cki\X2l#Cu1qD@S3SV0Ug5ZSpa?U5Q9a'e:CVrCVbQ-)R:M7/!2!baH-F%
	GFa3$$ER&0/FVGBk9iKbCtb[?GWiceS='/CVUP@::L6"+!aqRZkMQ46eK929n^1f/ShuS8o+PJc^]\
	L-6P4'Fa-dLO3_'=ETQ!pe=te/+5p/[G5u]hD*(!=JY9c5>!_AEp32d5FrN9oWkhloNl"!YNnE;9b_
	>a.Hc9Jjb8H,!Wm@D_o_jg<8^8TSLM@!!>_=Y:qqu2B6lUSEJ$tdk0=O0'#A0)]rJ=$WD+I7IE.AiV
	nftl-Eqta6@n5&HCT>0TFBi.%+]PO=c)5**.ApXbiqMII]I!Y7gc0COOOUJM#07D>V6\Xa8D)Wi.bD
	WuN]g\E5l(OG="1q.tbU]lg=/Gb&J6ol;%,5rPi.FJ??"u#oC"!JZ$.Xh_O:`rdOWYeYAHJQ4<s(OA
	nS@=em-JODT9\G6,kKJ^Jo&BM&3p!Wp;cWOE5&t%k*,JshYI/`5MU`b(2%3PH[C51TL6;(LG#;eR=q
	l?(lMM]@qpeSp=_rrW&^_3FBp]pNL9e!&3FogSm:C#EEPu8ZDr_NB%'%FLs$B+B1qE*p!#X]mG@aKs
	72d@U\\H5)Ol^F9n3%Xg2)0$ceB2\k3$JumDeA?cejf>fr[>TkK_]m`biqj+F%q*W!Xtb"Ta.DF4\H
	T2k4ctHVJ_<V`U5\W5_h#1%^=?L![CN*P_;O/?AAZHbNf)689Kji<N4&A;:f,$RRu#Da+/2/eX7I6i
	V?Phu*A@[kH:W]7):/TZIO=_LmIc2#?k,c&^_2\%00DL]PS\-Nc3\0ts3m8t!HpfYAp=d9XeH+B8Z)
	l>Z2KG$?jRSJtRuY4ZpNaCa%a?hhq8IcI(#_0\Uuomcq4-EhjZ>TA>7TaT,r[[//)0*oqVeI3XbTHb
	R9Y>XFD()S46fM`fpUeprYUD'D=P^jL9^p8&ff=$)?22#9*kD7aj-'JZ\3.g?.??u']??Lr1_s5nO#
	B.B;!8?(FmEUL138t\7lD<[$U]%lr5Q$GS-m%9Z0eFc:@_#X.<k3c/j]Fdq=eE-ddZnLDGOAE7jcC:
	RZ';C9Ofkh&-<33b>oM/JnS%s4*)EGq)7"I]aX4%Jb*"XJMg8a+\@qY.f8k\D)aorl:`OlE)diUero
	Z7H85TATo0DLG$Y`Mop2t>Z>G2PbL_Y[lJJAAaO:9Z9%5[r05<T<"!!C:F`H:sQDgh5fcbJg:<<b7c
	H;sQc^K<&PZKcAar90=T=,#B]VXEL`:%l5l?pYfcPlNN_p=\.HH!dOZQZ?%Kjq%Rpk9qMi;]8R#;`$
	ig?\D9ZN)WB&'ZcBPH1daqiQ=K1`fQW=J/T=\&r$JQ1-B[fUVMgJ`-Eab.tEKe)0-(K-C)2hGl;\:"
	T`r=q",puled!&*n%-k9.nRf%G8:/)+ar6)1>Mr.dWDDU+?\u"_^^52*m&D&&CsM%k**u;j&\f$4P'
	`YpPj"iV@bGo/9i)b9T>X*#uNLCO*A073Tn.<)_(0PT_5)1KWTdjrrh=XY-#i>u)/*OS&o3=$Un'_<
	f9;Oq7UY-:!:jk@_L7kNaF!?@m5cdoJ)/9"<1Fr<G92o(q%agK-W>P(6X*Xa"=lLQjk'11NjEM!Y&<
	cTQX$87J$oJ>m%%^)FSSa>%[RBS6^J8<tM(%M=gp&L+6RJdS!5'ED9XVm8?KK^;)e#%&DlFXBrdfc;
	/?#tuYU)Vsg2FrlP>l*Far_Iro1LN_(:s6pg<REVhK0U[k/,b\e$:fg4'L_ADQM"W2M+#a4IZ3h2LU
	5/d^B4(d+o3=u0(-%b=#cTffT2!F0XcC!+o4WF8h@5#Ib4?H3OCCBck%nF;A.T"s@Wa;S%LgC5HWV)
	,?#4!-k'5QqMK/n$]JGre'Z%&+)!iTt$pb2QJ.T`lWK$6*H8Pr[S'RSKG*4U8_9dD(BBt>6XrSS@ph
	0Vcp5^hRO[@To8F._Qap%-;mY1`eZ)W>+U6#ATOeS:pO[;oigpLX)21uA^P#Sh;C.&3O$jN0AN55js
	&Xab1ag.C(EkrHl/@IRt_."k)Dbp\J^VB4;CZ<8P%C=J<pJg)$B:aB.Ss?>rDkEp<5D/(;b+c;[UFN
	#l6H\<7WM'ohdkQoabTLRd9I-#obRm\QKPUj)lh.R+R>B5*7*1\?9FW;gY%o+dp8`@?:H\1/p<eU1:
	E:IO5S5gT&-<Gh6:Dedcnc^/chA3=U]&/@6$nNJIV73acCW`m</qF'5QQP0Qkqh52A,<C0BRV.7G!a
	UqVlNF=p2l+C#>.CZc.=ib3(FUUJ$?%-o3k;Z(-U!%Lj>@ju<lOmJ>JS^1HH,%*Y5r54tnRa-nl_]U
	LeMT'ASd\RF,E1D)=.K++CfE!75mA4W7oK@[::?j[<n2U(iRVt0M]p>EU,d]\tu`R8$TECg<G*HqdU
	VT4m?]m%O.<YO!VEg>[H:ccbWWUKF46miZ_1FN;=5*X?V(`Ee_8B;(\BS<7OL*:FmO71l9f(O.p>@Q
	BIb;i7lLh)J.R(^tM4Xa&pf>$hNfeZ_,ff4>^?n,#RqUf@6E=P6"Utmp@o_e><+)fPdSp3'\Uk-a+k
	?,WcT!FnjT`BbMg8qLG/REbfV$Eo2X6!72>>JKX=.[$tX-bOn0<`?4-$ACn2Fh]JbUO0!m0L:;=cQJ
	9b9_&Qq-@K$baXlc&J=oEH+43q#bc?.P&jt(.TnV2C0?j&;'K1&[/IG<D3'=\_2@KiS;kCm0'ZmRed
	lUaS((mHq.C5Qr8m>.ml$4[cYn;VGkSWaT$cnXI2LKKMW@Z.=<AWo^\VUVr-G[mbMH*,p5$UE[='#>
	!N6j6J?#%UJ/JE6Db=E9L^F>89@Lq(dp9+"MFZBC=!3&RaIpg79!L?9WV?*E2fF93q"Wdef=nng:HR
	(_7#=#K'-[MZYZaU.g-N1'g"G&t_oI(DDL2Nj2'Da<8GuSkfU5P8\-h*MhhTDHC-&K?Wc*ZO392?A%
	RYO5m(<JUp75ZIi'Q[j"0=EXSki=%Fcf^c->7AGXZlaFo$QL:A3?nCl2,(8fr(O2N9^5_<3[L"E[68
	oB,;AF*j3i8LVB<Q7Wh_Var196G.Un[ntrl[K+RD:Fk;\k(I'kUk*M!Aa$SLLD1N4qZe;a%k6U:h0F
	WLQMACp7Z<A"f642J[R6>][e@RHNcu3'_:`Em7lj+UJV6NtCfegN_!%hbPMX%EBAQ&\!67,Z$?_F%C
	dpbIJMVnWfFub!o'pI))hY!)cNU(cV;/E]c@bWIoDK?d+ag"?&n'R>]<Q]I.YhgFc,:7g&WM_C]o@9
	er7aNO=lA>eUl`F"=REWECQ%/kge`KptI@]6i"eD3N^?h5B@DL=1Mrh'J]f/-'/>G6>1q@B?%cqe='
	n3K8o[3Ops8%L`n%<oYg]G@S]n[h6>S&f./8CUWAaO3rk]4#4lgZCQ.%6VkA"&ShL%"KcGKshJ&B0m
	2U(rE7$W0*)+$Ek7\<=m>G^eYT$Ls3e+*3o_!k<-[K@+p@<Vq]f2,c@R/Q\u0,UG^17e6PDUTX==VN
	_>,8c'nr6TsS+X;:EOS08c%W`i#\'9jP'+Ti-&B&p`f%KSpsNQ:(uhS)3]VQS%tTqMLSM#t0(;!(I#
	dJ2e$QnLFra,eR(q>$LepfIL4HgcJ&aU)(l;'_$Zgo.bcj\J+!X)2!#fK6mMbOZ*+hBUMt%Pn(bOT%
	:*mH,%*C5#S7O<<;iF*d9U,k9+(3Fi3!Zs(NCg.\GaO3Z(+S>N'$!9dIM(!&AtMg+'\mQZ0#bBWXPF
	eF/jkoc0BNVb[Ungs(5O0b^3)Yp?U4l+-2h+,dZIG3o<C/b^`c=Li4Op/f:LQMs>6&&K&5BQjG1k+P
	O=0>oF/g>`$'01j7N47PB<JR_iUbiK?kN-kCS]qN1"#;8OZuG^<U[,Ub/PV6eYr#JRR:EGdgMWn/p@
	L=p0E_E.":6[rgg)M>&TXSlK0g/rdt@WJY(@5mKbW6HM%[pi-+R92(^pZY0Wo%BVS0P>\Be,SB'S?e
	4dZ8K05d;,T$G6qP?D%V5BGf!V3??aR>g1'A[,Au;3@.+$SOUm7Hd%[:q2a&5#Bil1.EcL<U'[4+pS
	*N+X&2,B3r<WaALVbAm:mToMP"ma;;DO[\qm*Pm=A7F0C)Xq"3&Bm.gGLf)5gqHoueW*6#=C]`rXK;
	8a<BF8,.[;+[PbMZp&=7O'l?_ZSgW=O65qX<KaH`siF3$@"tqq1>_?.B+d.3Tn'L+h48Lgt$k[4Zi>
	nZ@H%W<R-aC_,mH7D>MmG/nX/(onFFkp1t48bqqdUe(pbT*#t#3(d"WUT;>l;E5mQRe`DIYc8esO:M
	d^8Qa4bGIqS]-$g$J#fnWTbR\<'a>d4gb#Np`f3oum<pV'F#2-Y!TaFPcS3$1<^q@3D>>=g-;Ua_d7
	"\bLr<('PLVm3FWK.cFu3ICTh,flF[=b_TcTO<1,P/Mp<h3tudKs'`B-YL\5"kBFB"_Ibpm%"n5MF*
	dL"A?/X1sktr#B[[LNY*2I0)"=Ggb$gi[-Kc8#[j>WN,6:@fKa6pc76e?jk+Ma-3L/B!a"GT=*VWI1
	(eg#Obmk7FhsiYSkhlJ/Q\1MQmj<AL4SL9lK&s6\:o.m)"#bJVm!js$ntlBpJ&-MX;ChIl.X\<g%N+
	or?3-VdHK(:?G0Nlq1de[n^AM:+sKH]N9903.'6:EM21gI:Zq?>o@N'BB3&TWc4S\4(P8AWNHPntG]
	49of<h>gNeY.G!KrUe%dN'%ZVM[Uq/4EU9/-Gi;?TGN0HM01)2b/DAJ]9uqqg?'p2mo_\$fSUhhmh#
	a$sO&ZU6;]m[g!m"#@?&^KR_neJ`V,$md5fn2Z/,f/OZ@B8[ZWJ-FFD<QkkNae96\RZ_8Y)Xuam:Sg
	.>miO[s9AhPB&?9f]b7GdTr&^N.4m<?03>;+S`LNV6F&`t3X"#6tF%.Q%"AJ%+#Rjd/'2#`Tn^8rfm
	/,9246*VK),)[M0:I#T/mn["5R*OF1p60&XgdifS$J2&EhmsU9<[a_Ma*r6SlVr)%&t0bF7"f\A&9j
	)NClC1\nD/K%=gd]c3'a3Z0hD,=_p/N$PVp^Nr$JgAcV&-;mFim\S'Q:EOg6"P-Pr<3^e`GMSqro2;
	`uH6UZTtdUL%^B$s0pgrQ@5:9DDdO2-h0Kg+2[EHCVg3bXhX1:(J_&]%!AOhA2sFiiC%mX\B:%V8r^
	C[W(<:$e4DNeS_mU1@Vrq_-ioT,k%`q@i2+5/eM3Ot%)nDDcRn!O;b.coGeWd"%:$bB;5)%Zj%s7EJ
	(\p8UB6f(@eg,-Dk'9g+T4F6+gFX?=mq.gbS[lqs+*6S[C`75Qp?"@s;$Y^OqFga6tS,c=<kJ,5U>\
	pRP>dY=.sn/u+EbR"sud1pdAOB_qEoI1FW=#^4R0k8@lc3lZ6&<c(jq$<@o0Gb/O`I?m]4?PTPn!DK
	u$Gaf<m(AJp"VbLDmHs<6c&WJCQL9IiT"apP.o=f\Pg8h<lQWg]Gd`u,]i.YekcB'uI69V%0nQ]PDL
	6S?17t,ClV_n&(kIg5]'t($SKC>&L2BkX"Mtm>UZ.8bnpkT%P+_1ZaT4"hcXQ7b(Va_*@/r'8q[?DX
	:I)?UP$+)o[3#()%2BFB#H8_?@mKB+D-BNER2@Cb3-'H4S$$f@X`MTl=a3B<S<4_$&',X1P=NTfG44
	YQCq53QEPtj[DI:)'>*TV.9/.-P",0E&HodN]?oi/"-WPg."55B&;V#ARh'geEBfRY;!?Kd7?.ItH(
	EoH&,9fV84t]%3e_GVXS^c1i0ptR0-k_\!!s%UbNfl`jM6%8=gQ0Z%*hRbmGl7g8\3,2H^ADm&P@?M
	]s7kLg^NaMDPW>550?`&":0!?N%C7HD!X&[[Z7'p/)c%SG3BmH3POZ'Db,6S/kp[K^V5W0`-sXN)Ie
	f2"p@#c&3^2AiS9Ztf/-'3QVOrR^Ob"D&B+VDqG4qZ@Meq=>=)A`iMlQ0eEQ(?&0IR^tb;,H;<g*'W
	5Rd"+9gG'G`N]!B0q,MiaQO3C,%=2uaW/iR`Qfb%$ljYFfn;LM@e(Rj&rIioU)L&o::2JX@N[HO((g
	XGb#i%^0QtF2Ei&)j,TM1D&:h'@,'5P<i&^Z$dA+%WhOh5gKK?)P53W,m=cLc/$Gtcda_k+I=,h3@k
	J>u<^Kl#_hVZgI7jj`d9A-jq=&5@/p;qUj1."__aQ.qSeXSF:@7W.M0:]3m@s%&pLR@PDp!2%<?fCC
	1`M?<D<#[!cZ=TMEpuM/IGkZakeYY!Y=FnkQn?`$93(GVdH#F1O!!#;V1MT6#6gWR;=ftZ;.0D:ZJn
	O8HWX<<7TP;\\[b*FM.%hpt=Wh@"6k1V8d?I?>9gLY91g*j6m9b3d['^(9Z/>2QLD6(LQ].I/K$mih
	:"Wn5RF*kS'YD*JqihMB*ASS>0hZ5kdS-YXL&/jpK"C5Op:dOr#(i<+K_"oroY]Ef<$;m>J]a&\>0V
	X!KER[K(.FLX(^)2Lh56Z1S+l^[\7q;,dC.;T2R`o=H+BB/Tcsh;kF4WVK0#Q9@T3C@KuC,5:KBnt*
	MI0DaW5m";0fSU9q-2G6,7J?<RS;llLE["Q4$ol#pKJWR3;P@^hP+$5o^0\E'S?JJHoZb+:oNHmsO.
	Gok_##qt\eq)H8#\\,d(SPfi!e>MHt][p%".[qo<q':('P8?R'pR`jKgj8*R[SeI2882%5fcK2'Pe9
	1c=Q2.8W`.$NY0E_BR0[?po/P:Ui@F_ill^]LSYTYD14tpG<#utGL2siA6HIfY#SXZ8Lh2dFfg]a%j
	(0::7A16bdf4U2f_+p$ZrRHCbB<UX^cnU\B)[/a5A`]FjDI^HLFIfk6gnms6qGg;bqW2J(rd^J.46+
	lAb9n,#mr-P?:TNN\>?9CL#\d.\6J*hb".CGANZg#<G2l/Bd&+KpI1'D1q+aO]QIiYAkhl?RH].PJ2
	p%LF_IIC`PfeO$dD>D)SLRdo`p)>t2pc<tahSFDN*+1&^_!X>6OHO"&9>MZl,1-BR]\(VS#0>[/N0Z
	YhTmIZEk\*k]$2]f5.Gq7l7(/%ZV74"o>,^*S5M*Un4!nC"dMFf0TA)h*\(5d\"Jea#Shf(CTA\;?0
	fiB/h5pG2O3IBQTKeAP.pB&#p^:Bd6pt:@M[([Z`[[7o]GG`IqV$Z\()d+PkCt5KN6X/+#/l[X&A:J
	qPZS?0)Jn?e]O`1V1!F7F\Rf/R%5WTFtmPS@)$C,-\\a2Gj<FM:J[R/qNY-SLS=bSct6R$](HE<Xnq
	J'5Q.p9[Mk?>"^AFb`6r)G1a>eeoPG,10i+^6?@DM5k(e2i)>/!qV9R8Sg\^SS4?A3*^?V/Q--"3X-
	fL<:Ki$>P&pblbBA=oPd!`EFM#!5p/trgh_M<@'h>6o1fk*BUmW)'NM^`qt/!],RG/qP%Gk1QT>P6K
	OQ:n"+;7F?H7#%dXB&Y3n#f+5=;C2B3-;@+h7\PRufj]*4TDL[Zgc(.d"7&$l9Fb1Q(u2WZiV%olcM
	dFX8]C$b`A=G*.XO[K/b]TsqU;q&SbljO<)p3F@RV]U)#JV*aoiI=<g(@-g`.?+;7l+]%bRqsn;Pq0
	1@PRt7mLSHdFJfmBnp`gP.U8>L$sH!HMr!Bh`[,*5'RD_BLs@j?9;h)Ie+XVhg1&=j\547#p$54j8D
	^;J_A*W+q^lu[;4*kOXP"d>3:),N?:B+j^MdsNQ*hU<KfisY?!09F#CS8Y*Xs#T,Yk#IU$Ze!5gisT
	*/'XWmJ1s"BA=[:'lnJ]Q6ZPfUhem>O2lMr:@hHa-5,hqTL&Z_8tT4NrWk[J6aqr9JX2V>DnXL%5'X
	/7DrXnOj.WPKLR:;Tc1;/#76tJ-Uo,EjEl)GroOGuDnk0L4e<CB2BA7s#RKl)_*g-dQ5cYp1F\6fY)
	cV#[==kicUR#@fnhGLMS+fE8%0i2(Ad^(%*R>L[:c[cAO%?W<-F`8*)J&`fjo5E\EK7%!abZM/#+c2
	Ed2<e0tSbNR:@Phm"o![=N_)t?iIars5;bOph0]HS)^jSjK*Td4o%!Z3!pA4RB01"'D?Fp@uT8ldIm
	7jrSZ9#hpL[=o<3YGF*Y8R%15noj*^=?bX;JV?rh^T?8\Mj%Lb]l)n%"RQS+9?U@O".+qOu%l](V[6
	K,ot&Xd1R[iR0j4i56Tn6tXJkI/#*+!B&nbG&cbUYp=)+#,^7PA-2u<&l2NUbO[sKo:<<Y04j5o:d-
	:-,ME6O,S\;\#YQS?Ms/lE9hD,]6OtiU?3^'G>X?UJ16;D`j4o-8=CCIQ+q_,##?SHY#e[S!GQ9ih:
	p_u1[c888bZhD^\q/[k.*:C$rhQqM$-+-D-si`^2k[pi^`%"B:hhlnU6#l_6%aI19+b@'LT6t5o&Uo
	(U($_PJF5]UTDn@2NoI3b5_MDR1[4C@U_'i&6-%*AdM64iMR[mkAIq[31?3@1Rm)@1MCBQ`*>ok*Ig
	8LaM7g+Jdug`0H=7#":CW@C0Sb.VTd*b3GW-@XsFS,Gm:]&]3%a9hL'A@PQ17SHN-b_j*Z7E_NjA5G
	F<LsEoHTWc>0UgqXW7(PA6NWVGBO=3Huj2jBYX7[@*j.8[>_*`kH<E6"^_^/fpRn_paN1N1Q4m0NH(
	WJeDQ[7.u<J2,R]p&G/Y4;>=pn0"/PmdEL7%A,kKLqq](#os#R)`D]hjJ*.>D(G@H<PsTXH3@$uZ5q
	cMjlHWUPNH*\("a'/%UEc/o9P.MC2's9\,L@!X#6D[g/2p6;8532Gk89tj<hV"$hR%.SJ2A_@rcD/N
	&=g3nHA'J\31hh_h$<Z3Z/=A,1<5()Ri*H=#fPr[M2:2!?$">u$9tG$2OmbM$33Tj*qYqV&M,<McDf
	s'R0%:0-IXu8Vs1#5.36@ZUjW*fXfJ:$T;Q>DK`g4UgoP'lS:'hR*gP:!0B&^a)U6ojM9I+tna^M4B
	8_ki]%!i@UmeV"O<"kWonH0^#tM9qCdV?m_dYG(e6^^hF20OUS2q!#Yd;VXRa:K_`>4;X@$+?pCAV3
	WIkhZ^K4GPHcS&X0F)<1_6>BG<K8R(HEOf>FmZTKJle?phk4,4qg#_CV,3R1IBLW'!-jU[6,a%,52Y
	#X>b#M<!6b*1"0EsoI:a%YKo'-$1,mlZXJuDS:>Tc3o?/5J5>E`-[G?'1o_0H]*Ai%UbL(HNjPV8P,
	!.^pNF:MFT5gun%b2B1/E9g6%(AiQ/Ea5b+GrjRI[,9V$=Z$AH/u>SjOn_c3VJC>1K"!IUmG)s"=at
	hrpl.4Ul>$%je#h?DM1C[*W'Mi#j_E:g>=E8/nDNTb]Gs_Q!#$.g4HO.dnsaW$?ti'Vi9Qpo3BfGa:
	0m<nfjuo3RM*#f<]*#2FS4Y"LK+p4,GC;`:1D8eBg%'8+6@aY?A0Z&>q1`C.a"nS-1@'1).76CV(6u
	XR^i:jG-8;t\QCaA3C>VnJ:JmNJ.B[WQa>B5mV\t@a`>X,Z?Lkj,E&gNV6:_oUq0h2o'Q2F(<\fm[:
	JO.CK?YHAA)1(J*Z:$rR_(T(`/9fR8qc\TujMSi09"kVba<7HlfWnCX6NH0se=UC6@E^14+9G_&g5;
	5%[m/qVV:=^\G;<p<-h=lJMMXs*K*?Z9+[0\g7Qq24^o%lV#k'%mKr:Vsc,.pO;W+^"KaRp\(5.lF*
	K`&C$'Qk.sE!;XFf^.U>r[9pZdd#r(Ga#\(rOaeRtWGW$MUIUhs8ZX(COcTX5>T&\XR#7h?boBd>I>
	qr\boSegV\17.)eH_pX=!=S8mQ;@%meG)ph+"`mD$Stpci7-4.PdGk95RT](QLS8-`>"_5C"IV:@5V
	\8N@O,ZIqo)me46VV<>.I5"cUQMelN^Zu%^j<Iku,VpkgaC:04E"UKhRS6Lk"SXr.!9]s*/0,X`i+9
	4u$5ub1sDV]?ig7G,G8(6Bd:%[aoqtO%%4#7''>R2K3Rqc+_;N+2lpl")JP]MWD&\u3D)`4n"*7aD.
	G-.X#B]QDiV>#EogWDeWKr=+krAM<5j-%A2kp-B=k`@8&MoB/<4/kGh2r&f\i9!P)AGnUY5J"'^/IT
	=?+VK;*1ZpAWbTqAgi><^O3jolnbTm:+Asco<o^%(trU>e"SN,6a[$XX+5&o==ZfddO.,2="Anr?pC
	_`W]Q#0Mj?plG:8*`n@p,b?$!L1(U07NN#nDZ7iE>VfrUahOJ&uoV#R@IF*VEb=e)Z0>@"AHh";XRI
	MG"bGL@H9h'bGm"_5!B7qeX4uO6fH9%H3V9g&eqd,RlWJpCh'LU_c'Xm\8'c9P7mQ9DjpIj@I`tYUs
	bhsn3gWILMm'I\e71Mm@\hMIPe:Tag!Rs/7o.f%\<D>M'C@tk:dqRhtkdKf![)XDdM"Vd\^@fc5RLa
	P?sXC^]";LEUi#HdH%)bq;g-*BjKW+?L2$4^!gf8mXilt0UJeO;hmUJ$g0n7CYJsWg#`tM?$Ys#\9o
	_U`hmGai[1!gNQ)\MY'[L,Z(C$&@O<%E-q"CWPF8r5h>-S:FqR'h93pr!G,(Ik9C+_S@gW:]RWE)7W
	[RaZe1c`!b0inn[_I1SC]bQk1Ir:ii.DP37'iUuQaJnZC)3dR$4b4?4c+6=)#I$X4A#[uZSH1_%$U5
	SJ+<KE?7q:>c1-*X:Wd"tgNWD+nth>h.KZX5d2>9i^QqiL!,bn94cospYX.fHPZWbF&BHReAqhM*,e
	8h9m>Rc>ea5P/4]YWpUg+InK7oB/+^CO3l`si@nYrgORs&rLfQA2RO@)Ic/=:Pk:bXX.(!CEJVCD7F
	D#<"uM@K6[=UXN.Zf<n"bOnCo)DP5BaXLV9\nQL"Y&J%_d0Pjb"/iBf=#F4Vkhu]e,,s1-bXU7Xl^f
	,AcP1cc+\Bu4Z<l1uFB2@<U*:Ia[Cq!EdWXHr"Z&hG6EV,W/4"9M#ci,ABtG;XO?*A_KLDh47@@4km
	QchncJEiu29fek_S'f2q5*,@n)'9bCYS0(.a-rEP>?)'D-M!"FBK&<bsY9k]E\PTF4#m(#CScC"=#b
	!62&[H!/oO;*0&&p&L"H$IPTY-b-G"!p-fP`jsbmLho+:f68;*8m&B3J3,SM7'@6(g\Mh'aa$hBj]K
	kh01F+.VEI\IR%*#/\MA[_.UmR?rE>_6panG-\Q`_Y!*,J<Q/9t2]iQQB3T^e*Fc":2?@V!Ca%OiM^
	0heS@BQ]uQ-^)bTQn>H^4Ka%!EL;!3"t?U7='pb\bY[]o-fcVR+9`85fR\Qa<<ZiA-OO-Q.([C1,:G
	L#\L0@H03o:@D!D"+;Fj\6DM(T++$BJc>I7WjF"@]dc19?8AmbP#mI+].hCLfR`3Y^F!E%58L+_Yj^
	Y7(bZ.qKf4jPT5(s$_OSQ1k&Z3NWhK#"/7XI`.l-M3%+T]4W>^3%Z2,'5hV:`i#,QA#j'io\Pb>qXj
	]M?lbt,G[NcS-T!j7NsZV2-+e@N!L:H#Nq"A(ED0%`Zq7pEk*aE18Q6VC7cUp65.O:lD*FUNYO6[Le
	;Cj8-Y`45-!Z-8Zb!i(?hGP4*g=jT:YuUS\=C`_IQ?*AeY7kO&R<K(sfcE0kDOFJDfq<p&2fpmMh@K
	.O^0'eGrMOH1:%C)a>c1S[D1Y@^SAB"Uh;tB[RL(Emlq=hWaI`)^gJZ#PDcP1jS3&fDai<m_/O=G-8
	!*,,KC+^cL7s%2!T!99=47-A5a>I[4!KC,:Tp.0B-IY?;P>.-I+`LqtG2)kU0X-)\itMEm2^+m7-r%
	BP7>TDMf5frU7lI5`\n+t41m=]LKP$Xa*fL%hOCWmR!&@R(E*0a7^m`pDDjGPf;4l"j9+/fl*7#'9D
	Mj\aGTd+!a]E/?O]A[>QTe!-t6>n4Pf![K;;KpZcWps&KJj'Zn9G@%0-hS4.$k<J=i^0Mf#R?f"C9h
	mPG3o^4j8.`mu^^ch,d4aA(K>VEG,q3$d2&.7AaikH[O$8!`NO+[0.WXE'CEA1f00^!=;9PhiR'd]5
	I!Y8/47A6B\.aJ6FSV>;%Usa#@XG`S\301`7Go0_jcZ3g@[L1)TsERc=-9&Od:X8q!@b$ZY^(>Pc^#
	I_&Xd@b24MkUq"V?ICI.M[_9=p[(ct.OgJ.,4e2D`]8ZTh/n$c<eF><B\.SF_E3X=,*?.TS59V#ZkZ
	(+fo&</jMJF&Yoo9COjla41n&7QV&qLbQj=i5[;Y*12HX3te@p:64obTg-(:[;b#(<eW)Zq=5?s7";
	EI_7d&Y'.8<Q0[1+03p.[s675'+8qREh\gWTAO6A$.Y\fP7R=$ue=gu#S(5p2pPXA/[oT!/Vr5pSeU
	TNu=F0`2hSUH8W*HMuk=u?DL&LBT?cLcB#%Z1s:>9X;hu%HlreD0&C-:/`Icof34&9/JPu_ARJi`&P
	4[K-k?j):!"DT9Vg!2s]L2'L<0T&+$8t^gV0ORdN6J7dF:N&rDWt@\MD87S^BK#1YaV9*pl=+N7"W&
	J1(NUMHP9@Si_BFnkh`!ZEpQrMB,^7oZB>Lga$[%^<-"SDgaJPph63q]L2Cp61(E;9JgdZ>L;RP`Un
	OZ^nFt7t7UXA,Nb![(60d]-QeR:2$P[fa5%/[bWX^=]$-$:'"ob4R3H]R@a:Rq7$M""4>TR-:B\@`3
	oUVHePbtn=b4.aY_O1+Vq#c+j6,o5,+eu>^?mE`iBq!l%IoDdIhhCZ?u#1-ms]:Gr-X5j3HTC*[_hK
	Q?l\qA]0eaNI;.pr;$_kTm@-=U%Ij4cd]r2[Td?`b\uoh]/oQ.PV+=4Z[sj"Ul&/6nEFm$lPBTn]R(
	OFi<_*>mjBQbg3[$ZOSr;J(HO"%Asc.UY.;2ML6BFM1W7_>Jq:):<u"=<6)j8BfA5otY#*jAj_dg86
	lWE'Lb$pV@9&.!_/I%$1K)`#s[AA4\\sS02E?,=)B?'4p*Yo7Z$r]%_Gds7=!IVEuCrJkjZ1nE3p9,
	`EVk9S2GZ%*o^WGk7.7j0Dhq^j>O$o$V<<AiFQb5QAk(+9.lr4d`Roc!n(a=A^&2g3W:7.*;dUNm_M
	q2^n,YI.r-h5Jj=BY,pAZ6MXka^3tA(f$EE0&$+.mlamnblmohNIeiY*4ma\s_AK*Ii4Y>Hr+'no[*
	O,AEk!Bb]_(2t;65rAXQ2JIYJfdcWiCkHRPf^@W2ApL]q`=1Zc&QUg#llVgqY<44CF]o=J8m"/S5j4
	RY[>VE.dtf>2&-^C']?GcFG:pjBWkfrI[U/hf1(AS:gl)/"qLH@+tc;oJqT'C,r0H8'U#nN<cp<<Q6
	Gt7U2OT5'Zr@IqVGt%KSaHejtOa&^WOJJS8A`!ZtlVIsS;Ho;Chp<P#Dbe9;M5kNe]'B(Ktsr;Cir4
	UuQOGlR*E(Zmf]=U\UaoA/`94kflqS>:En+gn`*k3fq;s8(%o^&ApTH.G_d+5ZqkntYq45(:.u'KtK
	Qh>M8AKs"d3TQ.)7Z+;Q:r.?*D]C/aheS%!.DB#+)G+X2oXU5G)QNYK.9ujrB:/q;1OP'e\hL!Y/Lu
	/#(KS[?ef`_@sqShtV4]/LX9nr]OLo+WBpi\(`,@a,d,#r68;U/;IAW/VaNash-,@ib2-4C/kfKG*#
	B.9cNcI+(26@`gdN1K&O[*P^<.RWau`QN'"#l(a@60&@%^bGp/,#Qo0Ok/@%G<_n45Fa8_1`Kl>iqU
	[^YIAu/NG_ekm`j&*aY,kA/q:5ahVJ4on+UsQfPYdh.kY(t?%4FXqNI+3)'^>Cjk.9DhP4;a%k4<=@
	U)\)B&"[WCrYM+0>GX_>s!.S[VdT;Am,",D`rR0-SK;eK`RiI455)W@^38G#mE;lI:?.$0&g8I'EB.
	I-FrGucoIFj,,,X#pKl9\?hO4;d+K)Pc4D?W?iX6SQqAJkVLu(CL4Vu$I)ZtpiKp\QC6hR//C`3\C[
	S7/DgDF?-4\l:78tI20s^m"1U+f#!UUjeV)a=2KJN%=9WJB'c)U?FYC(JpL3>1_H*1C8nA%ElOVBr<
	bh7WrEdd`>#<1#SMm93P[RO]oeQ;<qX*M.#nA"nSeZtcZ4F$&OBpd/&C&QgCUEU[2RqY$tr2nk+Y\5
	*Un:u@$F2T*f#]Y!7h"Rcl.LT=O$dKNZ5L&$9?G4).Sf['D'R8NF3-]i65Q5Wfi-<k9+uHR^N9g&o5
	0p[+."*aI,i?T6_,7[U`q@F<+9pWppHH8roR/,\'cB@2q$uo,j$P-iU'SsCK]^TleZb^"Ir*j/X(VM
	65Z1J!W8`^hgY$aMO[0]d$.1+FHp"l7a>o07M'=,U0bOSOWMIJh(#.45V$jFU#_:DIG\>0\!VJ7%JK
	P5\+q4H06tE<ZH5GW(i,KoD17=LR/N+VKj3?.uZb-1/D>T]uJm4/XjsP*'rJSFJn(i@<;urq+ni'n1
	rPNQc0AeaZQM7LS"eVo_:@5o?Ecj:r!mI_<1?M;2*`))#_J\PH!8(ASmQZ[1n;HDc^\Ni[DS6XDL#l
	eI^3&&Q[Pr'qLAQEfX+'``m<H'YN6,J8C!ttf]j%-&D<JSk1Il7nI@#C=-(I.ZX6?n.)U>AEC79f<&
	s4:Lo76TQG0GhrVWb2j+:omA`10hjBc'hZ(cmD=al(t7`,#^ERAl!u%"VsX>k"0-;<BSZWf(nE9,'M
	#:"p`&p\sl1^?SZR4h9.u!+=<lNl84o_/(H1;EJo^2ll%><1Oc,C=g_Ab9r$&RYI/83rSOmMfEK60$
	cF?qcW)q3h9Tin^?Gq*YVL[HG5Es]&ieKO$DmVLZ%`D<NVQK<BVOEeTgKG;*B7%%t?O`jrW>rYN;mu
	-U2jNHg@f)_kS)12<Yn'$9rk$qWt&Ff#EMpMC"mrnqS=YUVk4g\ut!KSPBJ7!&28t('Mi1-$+Nk`ih
	e'm5L=RK1Z1aFIU9J7dl1iM9,3ORT93p)dF.uc=K^;$q,c>b?Z;[LGXB64cuW>'q,+7*J5:V1C_Hp^
	?koRERT./>X4HJhg]i/CE_,ib+KFGjRLMe(I8%gP,TUX^nl6dn3O.^7"DS"TNKG4_Y)%Cqg\Mdal+T
	hmlR*bV:3>72guasSfa6hrS>BDk3`#npV'p=hU[bV]#TTNa7o*&,<\)GC/-&O;D2lgcX"6`cbI43:I
	Z5%e(+;s?Te;uIgrkOI<fVZSh7#1g!]`W;>'35IsZ4rV%;9SW5lJ`%R0f%q"[#%C40eQ>3$0Dl,=HI
	[XE:B\#bI9]i$$SaB;g<q28Es!'naj>`T,;-mF8rg$oA\*S7'`Bq07FeS9'\lFQE`Y6LHK;!!K]V6m
	S8!rt>-cccajDr5P'=bU=-[U<^f]NDAUP_2K'[d0sLSHPBULK:af>g6osY1ke^]!f%sq!Pcc:loCSb
	hg;U#:'?[P^V^`5oG(c^m"@\SsGk2Esu2(N+TKnFVEA<4o4<M[f6&_j,NC!]H-a9)Y?YZg<Y9Jp7M>
	"r90Kn>aRGcDf1m=qTJORr9hQ(k.c61J,CC#cT[O)%@O_>!:K#trK"[^7eQIs9",o!s7:a?l+d&/G>
	:r+Ru_UXD/8k%AofYq>l,o+/REnj5$D=DOhaYVLQ=WHo>`qKfXA,d,U,31KG`I_Z7LCTFd'r.pu/!J
	W_uH]A^6AL!:!C?!+]c_##>e-&1r;98Y@Ke!2L&IV,W5Eq6a&R(D7+I(e<_U#1gO6esKpukKV#DPok
	Yk7/$?JQ=ZK\/u<6T!((5=VL]:DcT;ik_*K9DS_^hTSt=nc%d;7oH)I;ZU;10:`eJ)Y63\j^W$(GtJ
	N+r]X=,RLe@9HYh:h`!n(!\QnF-DJm(N-ub]TOIbs;CmrnIJ*@m@a-9YIj?;)lg4?osj#gNSZ3!-VX
	QHgS;?rOe/,VmgOarPd[hGCI)H]%jaT4>%Z1C"i-tok2#3e^7H)mrnF@hDJgrCFIu>.Pd`V*Euk3Xt
	9\lJ=-!97#:pE@Z3U+bOVuOSY"=r#ARr1O9Y4^qomtOkJ$Bc9LM2QKb%J<mSm3X`)Q!mkMA5.`6KBg
	fH>'82IJn-PYqRjY%_`^+Tqed3H'mH6iJN:W(J0VkKF'Z!*'4F>Cdr94?tqg.JgcKdRo:$_(gguLaE
	6C<3DK_9HcihW2_#N:,<hILPO6#DDYZE*<B.:Qf_ZT7dcb@S<ol'.TWifllI3,s67eIC:X$)hqi\X[
	EWgM9eT%2-b!us+$Z-i/mqfEeu"Z,NG&1N4fcHZkhtri2m5D-h#jJ.023MklE=RPrM/gdqYb=h]A$!
	=26n?e-:^O#$do_.<u)69Xp_1$O<e\DP+?Z%eob8d1Gd2jY!m)=%RnbF#Q[3X1O,+O=j@m^/=I,m?+
	2gVg21&m_J`Ji_0=?/OdKW(^h1,$0`k0OF?#gdM.i9UX,<ne`Yh.sXJuV^g,k[sT"B4c!2(5L">NfQ
	d>a''d&*0C(c!:u9=YKO5S8g3@c+Z^C=+nS"(=um`#5[!5DI^O[s&QQaPC!8p0Frt[;U;@47-ArXmT
	J;I[2`1Sim#2)i(n@9tu.$r:R6pYJ$62gRk$OZgjo#P"^-bh7ET%?TH6]pMnuqQeBoJ#>Mt'f(%aRQ
	i>O-cmpbf/mLBCI%"%A$.qPLe7n2=PK%-s](]00\d7mV,a"tOS:Yfo&n;UfA;4n#K3nM%a6R\0TUf0
	&-c`l@AQ]d;2q4LjF5+-mom4;V5rJQ43#M][dEtiZ!fth^=/:QT3G0Cmp9.^Nl3`BRLft#$SF[k^5Q
	I8DqW,R_]FP2JW;,Es?nu9o?*7VHk"FWgZRGpKW.=ps0TZhW+]F?)=fqS0HdY(qS#3M*3B?&2Xs$&5
	PjQ%b!,_+/)LqFhl]]k%o>W-g*aU;5%U"VDrEnDq2OJj&o%Zk=GdD*Eoq[m>EoFq8cJFK*0*p%[$JT
	aIL!&F*2CG?)?[hC]hu2^0GJ<a[.M#E^RAtNFE$dH0#Ar(.%u(9+\aqq0l5J.s3*C%SJLV81lFCEsk
	8o"+&g@OUcT*WYiAiAt:t[QJkD6&dbPf*^j*L?e.0\np6Z\!Zl2[C6B!k)_#0`t.G\_MYK0Q8iRk\t
	if0rOJi]mf54$;(XH$3l:J4/J?4)tgf&D?^:mesIRpX3[6S>5%(PpQ0e^kcYPh#k!P!6_)Z_ONCoYR
	1$jqY6.H!@5^g*`lCm%l14=>e^!HJ%GNjn#ifVohenbk&r9EF(Mb%[T\1M+Z>h$-m4Eo'8;7@AVKef
	EoE1U.t*sI&]'d4]+6>RF1)#02n&bUNt+,hB3Q=eE`?$`#,Iak5j<O"3,o"NSH<C1gJ;/YoUoS@%]Q
	5'_[Q"c[u4oR:uM[Vi3NS'3QE:rY3SJDF"Ri=AjoS`?+a.'ebX@9%JY'F+g;"M,!`n\V??f26,4oDR
	$3+Fo8lV!o4Tg/5Qc"dW<OV*0`qDOm%#rqQl/.T-#]7&_4e7G:So!@%@B:l!`1Y3EpbJ#6C:G:(G>(
	-k#%b70+gHHF`VTgbePLt]drB(\5m;/CA6EE7nAtj7X+kV+$@&K-`96ZYfbXU`b*\O0.QZQKFAiHij
	R7Xfep$a\strF>>%^[`HM'Vh*:[?q>,"mRSV40W^c>\5S(jCC*j3(/>!t):33SjYD'Kb00]'!3KIW:
	]3qM7k(oRL3G0K7`NN=5ZC1"9+)Hgj9FO*m=nn+FUFe4=)#M#pL/kRcGmR8+O).1VFkF,6%.d^*`%K
	5@pl:0XU`i)s&JQ7L,t)QjCfAV>(X>apF]!C,/e+C\#YJdeK-Oq>">H=3+\7Kb"CRB!T^Z8nBJg0bB
	EB;H_3L:TDiZMWZ<Kg3e#4h2VEul:f!T0&`A7'k.tCTR#2jCJD"$dsrhJpgH/Znu^\R2Js7AZA?Bs"
	,qWd1qrpG*=e/VIDRQ4tm'Ur.RfS-8Kk@C8UFRdf1msOBJ5Q@XBpF^j)fPF?-$F-P?D\A1W`.GA_];
	f#2a,_P?k/\*];3!9r9Bd<LRK65cb`(m/197!R5DNf')AjZdVcNX@[7V-"JV[UcCmm.ueh0]<>Mj7S
	U&`P1LC`]BWTWUiHEoh+0EN@@:0fDufr)KKpsb9>HF"#NKY:pMhqj<LSd[l@+BkMF2"*r`M5kaD.T@
	H^hjQ!K2H+,RL"CfiD1)M7-cnBSc)T:+1RVp6KdI<jC6L>Kn4?M@.=@f5feSaUnjW6L90N1>l#&Oce
	@k)nSN]$5H7`XP9c$-`ejTo)@okCB$b)9_]^j;?J+qjhs%i[d_f,SS0<SPRYJ9YUfkIBOlo4N5(ccC
	C*_lK5orZ/4DquT`]6HcZo[V(Xs0KC'q31^KkeVRDN/C(?I9nr)UN.RB$tMa]lW8IQncEgJ^+$i'?@
	Mj<:!e"hOHpG:=U;S#WnP(*V<PRbU^p9<1l#8-<\?ZR!Ws\l:_8Hr]<5?WaJc1dh1X4aSH.WF.i38e
	k0EjG1)a=13LB_WJ.+hbDM,mMBF4o&!6@RdLmc(E9bC7H;AKi^!)&K$2'lU]?j>IY?DQ5K[ZZG/,ED
	nu4M3o9X@#u[N!L-B7#]g"Wdui2!@GdoW-!CP.)q/hUT,LSk+Ps:EUhGS(OtW6G@M<e&HS'q`k[F%W
	d8/((N/lQhu;@$2^g+N7uKqVcV@4OVo<\]L"39-gDKh:ZeRDpgW"R1gc'`'^%g;lIrDSJ?XV0-U+?:
	BPZ;H2;F!W_;Q"F.rlr\,s'UnJ`ZaEAIEq%Dp289[`dIrd#V8H&Lu(/\OU2_=:mi345:%Ku!d$ur.#
	aC39IYf@@;nelaU^nof$9l(kD;FdqIf!??:&3[7!m@p!?r_6F?UX4.En&H/fTZ[0G1:?VX0FI/2jWM
	'YG5<?rB;sY25SIUVZR]FoC-#\(6HnLBN8RKS&$YXO'5==;E)Nj?u\4X7g^IHZEMB?hdq_V\gL?])/
	6]7r9'0KHR=G&[O\l3VoKBA^dJUbVl$.L#$khg8sN9BQpKZkr!hV8L:d(Lm[@(l&'6mG@#V.pU<$\)
	5uW=Ab>6p=/`-pa=&oE\SU]Iq6NkHqK"Z&cG4MN9hLB_#Wd*6dfR=H7KC6J_q"?;+(?LNDYQ6sL_DS
	N0Dqb`EY^AA+ii8XZ!%TH5Q^hQTG@s\Up:l44c'jT![/bFLa7[b:<X0j%KL#H+V9cmZ6>$IlR'Xn%0
	h`62_(lqg"s,P4Kd'l&Ci=pF5\*j!5Mt_*nUpN0d_FdLmZ,F?+IH9ipZikU?'<m18))MbK]=)S,Ma/
	KddJN7>;9m$Dsmm:'K.W8%/\LPhLb%*W*PN\GkcoeR[HWD+_pV/"Ch-WmDEfKVrL=ID8GfO:1\H4^h
	/sn%EC1R(#5rUPELNI8G*8WTFfn:bJa_:`$N]Fm_$rMg!$I-p#$:7mk5uLc3Tf_%RVR<K/Aih;(PcQ
	r=W:^)-b+_iOAPh;XVqi]/gf>c!;&1[J2$>(SBGN/!.cR$/#PTS.2fLS?b(5W.f$VQ>)]cm]7c>^^%
	ikB!TqW$j<+f\;fg#I3fddUp&T]+,$l/0H`:jD9ntj(rc345XeMou<c1bF86ipQO^un?&>QB'$g_Fr
	uZC/S@YL0cP+`726hY?&WCE]hj`aJ1nS0"-A<DXXO9NQqXt3P`_IO-+hTY//]?L]/JbI#IWWcYB&6D
	pdoUI\n+hA9:n9lh;4IbXTVDYq0$J>&#ec4"ocd$'`cUb/>N:ioDe@RSj/[7fq$bUk6X)\WH(udG-d
	ZK1C_GLLZAjkO5sGX/5,]j?5V%uonS5%qd8$+^]nVmL*0^W[C!dRNMOZ9%EW%=bpGMP=0B$t%6$H/*
	.PIuc/r^#MajH[W4o3VT6-[^q#q?uAP?R>*.,6F6oO:UK4N3r]PKq0X?JjG&9fX`@qVTm/A`5KEf:P
	3LdTZpSeM>YF=`@^PR8h#k9`u%d7JO!J.Oe<2uoo3Al;\o8Z*`9L`n(,[:!fCL^ls<0H!U@I84SB\n
	(q0.O);j_e;$q-2Tk_!X>UD0qV3Z^%+eJfsYa-'F*MELo<:2N7)EP>gp9qYq1g/QHGZ)Fq7r0,?.C/
	AjF9;D2>?3%HqQ\pbjU5dj3CQ66!T3J.t;W0qp!(0b<,XDB?LcraLu-"V!GLI&'TaXC`9oX*ij#&8L
	D_*Q67`/"?Z"^[l+F_@_l)0FJKO#[V%g2I!OLpctK@l$QoJFQF[qao0TDrEll:MZAWj&.>`c9*Cp+U
	^Nr>EFGHm\cjEi:!POs9rSR/I:+BYelZ]Lq`@.+R9P3;hl@@!b=Ql+GAGsg]V-)FW,5r1p%o"E#"RB
	8cn7d'1^YIH/Q+&H*kX>e4W9Z9!tae<8e^[M$+FfM)s`S4jU%>?e*1s3M?XAj<`mt\[lJm*j.hZ!4F
	6t.[._0YpTALd?C4qgfM&3&0niY]"GglZ<[*[%'d7)#Dc>_*di?'qroE*82@rTA/\jKXk/,ffdnc>=
	kA$Kbg+YjPd<i.PLe-:/'Ot3orU(.0W=f12+94u$5uaik+[G3.Ka7ZE3.t+^E9hImY+UUm'LbHCjlN
	OMGfF8SGG0++Du/gK-ZO/L+JPUo(dXmPW$G(BrH'^nCBKA(+Y&KRKV4,5*H4D3UQ)[;LljQX0db##C
	h]<D*/Pq]RO"*7K?;r]-:Zrjq$+5UlO&:ZREkC1!"^Rd<m3ZEX?ZXe4L6q?9[**YdaRK?2.gW>0U\a
	\8.6)`[*b\V+E0$^pRUc4O54%/DuJV_Du]LfDZ0>XC@AYC3[O0FB*'h(!0kjY?t!#n2!Nqm6L<l<;A
	^cFYS^kZ;iWgg<40L78_D_<!L:G_KQ;(BptX>2?[/0.QKHHpJ-a(16O;L\f\p]ARc_A+<p?cT+(I.I
	(h6*P>P.pUci:VTs36$,Ob--c4CoC4>INq@jsQc?-P?tWB"$8o_EsZuiF5%;S2)%DOC[Tt3Zj=s6,\
	jWP_LSd<HU%`&S$<1i-_R;nhbE1UQA<OiPn>\&g.>Xc)f\;/b*AOb#/968&OlXQjJ>J%:2@X`['ifh
	_eSY@ktUcdS%pcl(@J!g/_n:Yg70U<qYT.IP!KsgA,iXlEZq27R/;\>gG3-01?r^qNVTjp]%Sukq?*
	s[iQ/CB8XXDI!fapSlI'_Ai;54+M(Z:?cNut7$5JJ0!kVKAP#%QN!P>Eq<?f7E;[kJbKBVU4@q<ppS
	ubtNL*t)p!s#l9q*KQZ6W#Q^V0A6WAI?L-//3.X[YV=PH7Ca6oW-k:aGAi09EVKJK54_,,JuYGB`ja
	N53L?%*0iZ'M._N+jR.AmQNR)>_p[dpW%F0`#)e9MW7MnBGkP<NeLUbA^[A);O(-#S-Y6GCWMEE@8R
	_1jMY4/U%#^nXH)Z4<[Uq4^./_]JW>(L!0#DlIs)c?qXDB=^\,"P,26o`;\[eQF)WgYo,ZN@?FDmLj
	?os[F:=M&QLaj!roT]VhnHh/\U/e^XSFggj>JcG1:I)M@b\i$9!G@[3*PBBM#nb$F0J]seU0)GZful
	:cMRV>O*cYG,(eDB\?,C/3679#4I_L7=cm8udkpFi4_7UuN+oEo3>!0)ePpY:AiLu&Ud4_>iVobD]m
	!T(lPM!D_q%eL4]D8`+8NjVM&8Y!O:'8PKQ_aUIrc8BYG1ZQ]Um^hZ#:!jWDKQ(;CDW2Wn:0s!>4Y/
	p>38QdhST$!_Ahng!WbD#jbKRW]'(_$sh(GKt9.mU,ouJ#cKA$:]LY9YT^CfU0h,3qU0HMObXG<F:+
	t&H=aeag2#gI+8>(Z`TUQD#r2h_Cu0X9nXZ<MUjD?tjk5%/8#Y0fe!(,Z;UJTXD/P;h;:XdT.RgUnA
	qJ94LK:a:+Ma;)RsIqIp[O7AQXB>+Hnq.uR=LBf7&JM"hN]U2EG6I^:o2`.CqHh<hGA?#h#G,he_(@
	$P-3O47$jKmr1fgp#IA-qn#8FYK75Y6"$)?TKmU(^h&hK)#V^u9<BHTjDs^^n6Rp9+W""io2X+Jm\;
	_17C+h2mf!4fXid<KbQ5F*C-3>C9Ju(jdng8C$mF.Z]]/stEWt2#<enE[p\o6lTM+%al9P3'!lmjqt
	?Fo^Jhd(Ndfs+DKbsGn8me6"<&)8PA/4[R5iY13Us4P`-J+`C&Rr@u_dl!UeLkcOcXe$#Wj!5S%9O*
	LkGmLppYK,ZH_us?+`l0Du:^RdhGb8`IRVM`/DpI5<BJ=3;8Pt]f^_Q\,(LDLaKeKLS664#A^_2W(*
	K_+4@J,W`q"oi(Om^o'$f"rdFQ)a[Mq&P99ZquEfqK8tFk-3S4K&+C'D"^%'PCF5<B1q4b[*;DXZCJ
	sl+E&c5Y>ak%>77P3X>o?&_t%AN%VCm18EBuPm<nl!-us[:Kg1/FPpnTkMVp*e&M-@A`r"t16N6:OW
	uSZ38qoW,k!B-M`sc)jfc=AmQ9<Bf2d'BRj?++!H6ba^\;^KP%Q8SP)kYfrJ,m(hg0K#SZJ`gOR,<8
	/tBC(4s-DE[(ZCQEBi?_C[nRj>eG'_I-9nYC;(1jA2$<s&elI?N^6R&EH6I%cMPT.F<sSeeq%=@[&b
	l54TFd-`QM7((*_8R2+YJh9(dNQID=>5&.ejC!`D_aA'[?pgtj)Z^Z@q5Yr2SO,^!Sa"5T[?fmk4IF
	$c=ipj&]Gb`r3PXYj`5Ii++!CB[<<O\QRP!<(bf2!VQHBq#`SIP_WY6?f=M,(KYA7-VS8'7qD6S07'
	1[JfNKak+O$nN[sSSDN-*JfmQm'[XW@e2+e8%T/$]ZDXpNiG<Q1iqDc/)l+6C1-_4/f5?V_q*LPBkF
	lY2qf$=dEE]K.ko6rhSK/7;B>46%b4Es-`@J0@fDYQtRt(GKfsKhK\c)5KAI)Ya(Q($7b8X*2dG@B$
	Lk;S4:dj4!iSbDYVN%sj8+\^%obCS5SI6I_.]&:R9?V(u7[KO,NK&b*/$Sc^X##6L<S^kWT5>bXJm`
	r=jXZZ&$]??-ZU#+\,&:.mn+XE\r`>H;W/ru,X#)m[Wl?f'Ph*HgD=Q"lIQ?.b%]PcDPjDV2PIcDa:
	arH);2R]-*f\pcBpo6_!_OJ<7*tmAH/jiUCc<)fi.=P_GB]'bDlLMf'sX^$,^3jR5et;`?m9;<IdRq
	^:>&G*e)NPnHMWKicTG3!aG>.bCi4.9p\&'#-^mpCbCS8-%i@:E@hQ=s^A-uOmGj7Fl?K\_S+O&#\n
	mgM"?;jqP?V7\5PiL\bHJo]mprc)#\YC^&6R0gdmP!'\R=gi$=g;P7M8c=^"!iBOC;$.-"m;epQJbK
	nJL[[JtEu3'Hm4A7r%d_e(JteoCh!76o9^;2Br2*W!&?(QeAIOK<&dD-k_@cZ#347B*iP<G38aH4br
	-q-Mk;&=^6of;MkIPGAg7ep<0`O/lD[afqM*@7Zn=Xo8uVB^&DDVS[2XV8i.]Ejg:\d0"6%)gLu3\A
	#C^=;Pgurl)lXuc4u3'pC!0&2MmA^MbcS9kb%fVV)9J7n&#(<]7!0k+8$;tcdEj`j&fR@8p%`jIIIk
	T\9(5[Rcgo`.d&^eUV&3WgWN*=/+`W*5Q:<5kJ-S+^,=^%>Afos]YZ'(Jmsq?ar2)6[&O1iUrakdh_
	4+1<L+%_6Vh^e8d(EI<,9?GK0pKDS;SNn3_cbAjZ^!n'*=AJ@\m1te@WRCS;:?2s5:o^RKCl21B9*Q
	^2@`ic%$?;Jr+:g+X[kb15\X[cAqSai9lB(kK:3+p8L*/&PSo^Up[\*;5$k2\Yu=,LHr`!3>u?j_K<
	H&@uTF*'bQNBY[nJ&mh_<3)Jdf`K\4:b[[q#b+2'V]m%j=m3WaeoGC?24$:KG10G(ZeI2IBt=Ym&;H
	smJe>W$0FK*F(nJ9^_WDpFZ.C)`_3L]lF2O_6E"H$80202>\kS-^P!,^f%(nk1Y(/G*k9[V,40W4].
	[b2#-`J+]/ss0)I/>^Lf$C4`aWGno+3?'j9T,g2)hK(Y'3:pIGa#n<Q"9_Y%`OD7G!T>t'c0f4l.:`
	D1cE,dJQ$BYT2!')5nKLet]J#6C;!@?AEn0m7Knb,2\1*2LWEn3p^]6?.J;JMDuG3I:;-%J;`'Tn>K
	80j1Ds4W6J]T93e15eRRULC:4!1Jp9X$HafZ]p_DAe7q]cPs%P>haQ[9b_:e6^EsJ;([mUMA]eeZ&1
	dlQ;pi6\ns5L*1S/@$"<Qa+`epURM<"2;8Q@15Yj['&Z2])*8@?ja*Y-'YDqH>5aohcn%<Qb#)/G@l
	11cT>=fSG_59Co91GOV+$KQJ?[cBedujBMJ$>Tq8mOY8CIU6@-SPK5>l/c`[gR>b@8cCm8)M]iPu;:
	t*=R6EbESk(J1.M;$NhdZL-s<5>&.#.5Q`JZV)1LDW1KMRbfFljWNY%\<TgiJo_L)AL">@"Q5EQO[3
	0^F5ST;(@RQ/GJgV-n,bdXCU#((pA"'lmfdQ.u#Ns[me22ip-r:80M?ne/i97C^gC>E9M2@s\2!^8q
	8^g7eMF:m<g>rRbp/VqH6u*/1gb`d&^s6B9MKPU#*UGZd\49%(,16T$(_p!D"ab.P]&O/7-5l)*cDo
	pLSWn6ch?1)NAPH!1Ef1)u%OK_CbUg%Q#0Te)Z1e+%nbef'6Z\BunN:XmF$J<Jb^TQG>CZIXoZK1rP
	l.2pd;1uR0p@,!g/-D([<]?r^7fBV"c05]c&@3>8Bm2B`*uRe5Z^n^F1AZZ#5%@4%Q^q)`DB<Ae+$:
	WI^(<>R`3h-&4-bl(^g<PTE#+n6\YRX6>M5*5g@UBJhia,+2SW1Q%pFg^"d<8@djGL.\O_?n4[L.D3
	RB<#%=gHgH2mu!63qWE$-ID[OCuR+-mF%R.'EcD+b>:-fs=!+3@tu/2&c`#UhlNUNO<S!2,DV,%`#c
	;MYrf6BisE00HV`8oM3VC+Pj5e<+N8"'D[i1i:deNnj.J[o;uDaa.OS`n9#(B^(pt_PE^m.lVA7/15
	%;9`i_*Jk<<Eo':aKo$H73?@<*f[ejp*+X;$n]b<V6?:kHT0qaS$BG;q.?pG<l*Db$PABbb#5`F*9+
	.;RL*k:B;EBd57:OSq%!/,T*j/dI-Bc?0ide^Q<Lg&VU;sbtJJge]6d3@`s_XZ,LAjao`BHFk5P*JP
	?p`apX,3gebU3#s"o)oY&UDL*BH1.oNqfWk]]r0L3R?9cR&K(1R+p(B2!'m]0199lXp.i5J0Hb4AQ^
	N$&);rUV,RFNY0H`%ucig?VR*AYJk8:'jl.S05p6-r6Y"1)j`[bG]=I!lRgh^i)eT<Z+(d,+,4RB]4
	XK4(goTeN&r0DX-WS>=41SYrrV1cfEGrY&JDXD?A`ujaL^YdrGjicn1P'/WMK?hrPQS&KZ1'A[9OVF
	Gi"Fq&8$ChC,%ip7*%/O/nhnoY_q_5gLC[A#r<jB+,m'G"j%#2K=F^94E'ZLtRodD/\DL!rl#oAIsf
	7jf":rak>D2baI1qJ&`41!<a,=i_0#6>SO;+O/jjq'jmI,in8kdGEc''ImPV3KM".2<GTl?VLH[I(S
	"$<[BpU3,\[pleo;SQe?A"h3tW4uNFl6ig*a6pecC`K$'<O$<.=l=DjMq0\(%$\ud]BTfI"'h_1Ui&
	5g)fP?rL`_EkI]rh@Y3_L*T(,H1#/:?U(g=O)_j^8%eH1@:aC]3"_FFTD.nT>TE5T=cLNSf&crqJqp
	K8(3hGSDfIqu%j^_]5=Jb)8P@MND=CVBF?-S?lOa/hbm/r>i8>><EfgP8eo;RIBKq&CNCP['n[.Ci:
	7j&u#HXAZ6mS$IXb=GYi6-8)kQ'IGIp]2i]IiR9=n'@EEkUB2CWd!0K@7ZW<G;VHQRGU*:D+dO)FAJ
	d5^\":Th`PH$o8QIL_@7M?%t!q(n'D3J_R*/'P!TJ0"4+e1M_+V56B#SStt!/!U3bi8H)@ni%gA13P
	ZH\^>tI<p?Rj8:,4hqG_)011k(l`#9lIGYuSU@Zo.%0D\.S^sJt,/U1qhSSbK0>[B9Wp+NW['TLE9Q
	0;t%2pB1@k*RC'dPUK4^f(W"(n=IB[g3R,^>k^CU=/BbK:0d?j'jL+Cl&"qj^+9oW5Vg]<q/um6KDJ
	rnWX@%mRXMI$?@`BtCpiF$XNt]$+b7W8o"f7KC7mL?Si\PG@H9Y5/DY7$Z;Z:=#GIaOD7D,c`am!8t
	qs!UG";/k"l>d8MI2;1EQTd]hUj!WYRM*$_+&b-G?9%aM/2h'j6eD2^ZS-Hig>o5lUV0p0f"J,l-[Y
	T]\G_C,m6#SSpBi23&@kCls&N=rY0I5$*@K<pmsO02gfkg`b.5471L<pn91+%8VP9fN(8dWR]b7FiC
	)HIauKit>g)?<R<j2_sC*C$:9@m)'e>Y@$&!G(&:P%ZM#XhF4Q39u//i/8.K'&?6S$A'eU8JO-8q-I
	r?S`6@hanl=AO/XW=QUkmh3%+o\6ke;J,&L'LdGj`NeH4.V`%mHBCfm#VSdknKc20LaC(o'1b=$$A<
	[\Vh_9_/&;s0s.q+\BBAZP`?">4:6,7gcU8`oqel^'jWthV3PYf>"cBKt8E(i*/.a1@W!kct0nbe*U
	P3gtFu;r(CBXG.r&>'btH"d78)Pjb-2LT#-Z3-qpNX323FQRYe[r6pQZQ1Lol;GjXmL:+3>"b<3S/m
	2b*;52&5Uo4OMWKfd"/NhNB;3E,Pt-/ICcj\\d4MA8T^c`<q'7Bto5O`XR"_ekt#aGPTT/spR*j34.
	qf8osd5<h]<1:1-.+L,=V(EoXHrkPj.Jfp!XH"&cj<B25mTrJfZ;(;o/JJenAoDP],H_;nF^B'oO`$
	#E%g=\88IeBQ9j)Nn`)]KaA\PB.h>T?XN@Z9-D;1U(<KU]*UIVVa!7lnY!d'odtb2k//laK,cUgrF/
	,,-IeK0Y"87jAii#9irDg#(J*FU^_N@Z8#Wm>hT'c\n&gZ`k8Ze&ELSLlrUG(aU0\*kUg34keU4*&%
	`=aDG@"+\?o^,qW6G(aVV90Ob%:+$u-\IGq`aPE-e7eH@KiS+3;cp?C//s-+Rc=#6<qaKdA?HVHc"]
	FClt[Zp,\jni21D`$66ZX.!bi2-J4hd(^!Mfs*f!EG,;6%!2IN1Ui`%*/]?5u]&BDBM?cNrFoD1hm2
	d5F&h.n,CntB1!C?Z=,sHo#("-p!0F+R\n:K5pF.X/PB.KN*m2+V1o=D4Y;T'20CEdlOdp/efVI1`?
	5^!&0j[H5"VP[&iLr&Ts#.%XFqk?me35f")7B^8;ITV&A<V:db_uIEUc_jl;f)B#PQlE1mJC;hRo&T
	4*iCAG+h@*!jXQa&<q,()#XAN4?Q@Y)?u0."?]2DpQEp%AWm@*qW`d<J%\ugS0;(*,]/@H2n+;99>5
	kgh_s+DN00")#m!mB:2EI;9NB.8B=7"^K;GfW!=t^6'ADIX,&0J:0C,#O9D\h$Dk+B\ZF^g]Wduc&'
	9O#]d2a^h/KqiH:e1R1SU*Pk8d?3+SBkPfjV8R6Bsi/(Ye%Oa5Q]!W2pO:4XGmN7+Za=A<S+RH[u86
	:NO;qi+FCiQb:>Ga+AG8NeasCT`[HrqBVd8[b[q(#g/M3R3KI4!#Y-PlRM5bs(]nI:pNi1O*FXaBM(
	!D[(hR!a,LV;YK^Nj8hump5k?MCJ,haAq[K%BDp?&DoaLiZchteTi.duL>QS2[.iG`NFIK&$mZVMBu
	4Yk-B)I]$,7ZQHIc,jmR)n3;@X6[?=iWUV^CLrI1$)JCnNmp%f=A#>.nBLdY"!oi1L?Q0b>G1joI93
	)uWu?eM#RES4=&s_:S)L^Q'SR41o44BZm>T?$K7a9&PY%$@>o&>+X:Qt+;-$hc.#m&e&P)6*-a3H6a
	%&:p5c_GYR8J$BjpW9VKSY:(P!j9'drh9H?&aJ.UA>$t)[%:hAh\fbj9+!g<Wo_B\?C9-WYL@;`;,D
	;$ka5cbMBiCN>$(Oe/6j`7:NISHH#(_(Crb*cpe"$kFB]#EH"omcT_:qR:UN(m<B+Vl[u+,QnJ"hI0
	6:#TN5^ur2o_1f%*H&8A+]!8p"%[M[SkPfH>:-.an/1KGFcrd+<!/R&'9#H:&&1r8,d#FS8'9;))HU
	'\XH0@?GdY5*GfjF#e+8d_-sW6.GYcQfn1pX&i.1BpBGoU_^?nefq>-+lVW*#G3C.6;_9N_XTGfN'<
	3`dhsjA/0"aRD*[=7aJIXa"HXLtUZka#)ZZAcK@[q]CTTejlW;:N6OeRYa=INu*icUo:EgrcUT@#=5
	(NU"NM(apXCVB&o0e\.@r.X!Go-\Xa6BBnKf[Hd'3:"@lGE&5"#E<(9m3Q!5Z<!jU:GA`XC:C/npV8
	Rp(%#W6*Bl/9dokf+;*,..RR?[b=Y=#,#B\\TTl*r4_BLmS$5ML2C<td!!%^DJ?_I9[/^M2^HWtfcO
	l,aec:+fXi8VY8egKbj?"6Te']p)G'/(u6PL-/2&&%a2Vs.rjgJU\`&g\T-OGJdgY*Yd41&^4mnjiR
	SU9]R0?/Go-74$C(F2D2#f'!,ZrTY3@li3tZ:P-BM-7N>aW!rB$#'hS4p$X?$E\1\jlb3tI-E*2'LK
	mJ[9h@m4F6%Y,bADgE1]\3Md\k=PUO?Y[&J4l[U4Gg9kKiF):C?Y]TXmP]R2p8HW*@.)/mtk!+&m`G
	i>(__6\3CJm\m@PjOs4cL,QbJluJ%fV!bG7_+\NdQ!l;?j$n5"g;<RFZ!#7>d-KW@l5nM2E+D^*s1\
	WnLi6fgGJ0YZmN%lSqHm0Ok'D/n8g04&jZO!#XfuZ>N:@HJs,?M[4iLRF#fd?,U,RNcGBa51V\A(do
	V"Y%sEA*<iMrhk:V5^lOX!B^IhSZ!Z<(IN%mk2O=mt,.>(665DMNJ$Bgp2J_3U2cC^B?TMh_1+DAT$
	$n5ncPFtWrmbGA9Su[29R3H4LFs3L'GMdYO#Yi/n5nF/"3h;#lS-+iYU(@N4Q$9Z#q=SZ:J#oCI$#,
	ipJR(Ldc_$aQGLJJ='b81F`Sq]+9HJ]EE)>%QJQe%(eK93E^%p7UG]K[]#3@+k9p(OC.OYT+OVk<Dc
	=^!8>?p_k[k9.]9W<_P1/)d.I1g&AJmtN.o<NE^k_&u&9V/,SC]k?G;[i.O@nkC6\h%7.?l5+n,\T$
	Z$?P1&(IjHKEi1L!Y5lG`UkQpH%$D4L2Tpr!io=]5h>b_a/VbZE@6Cj[9@'HlG\L@R6SW<Z`@/lfBT
	,KEo#=mQ\i3_Tqs:Yu@jB!?5B/$m+J[=t>l2=dZHQ2]HV(*!BqmYD3n\892_O`pH"K:K'gogM)LVM2
	456t;U^sd_f/7W*#\:?N5-u;XQ6i(\*mEs'oc&5GE9LTRLscl,Q\)NO0td(=a]"$J\N3c&!bUS?YLd
	.Vp,@l4J)t/H?GXFf`ESh@rjVpf_gh^Tc*)T$I'C48:6fln.Q&X\Z"M%?"O`l$RaLuN)'psRA6DArD
	;4<ka)<VN]4)o$-7VDO%['t11lW$,&BK_=ZR1tI<)&Zi[<EXAVmpg@,8)1_XUCDMM4HF;7>/RiU0_j
	8n])\uplQE']lg5)C\6"()a#O4\Csg/ddckdS*ugEK;<?2j^al/#7JG_1tbsAAkqbm8I>NO!\l+ALb
	[5dYY'hW9-D<&Ki0DH$NX]^:Cu_8;At'0g4mg&8a1ftEG^!D5([;VMn5pkIumIH=I7+'[1+0:"Jlg,
	[%XVeGqVmT[V^6_M\spiL8mq1A.mToS*[uq>Zk[&BWVS<0dokW8X9&0fsAXRcWp8=2t)VDeTDJc@`8
	8*4'R4+rK%!<05ggJLPrLlTUPU7'Eeag3ZgLTTiPA=%9K0N@[gZFhI+Q;HhYe:DuB6?Aq+W#(S+25A
	O`LETpiU%AS+;!P;87C6l&1-:<=%p(Z3Q4'j\VVM-qQA`_k<N`ao1s&!kLP6X@:;:3)O86"7)k6Q8K
	,m/GDKg[F6`6_R+OIdVeJ]29L$8qaXt6o9,e>"kh>Lp!c*M2afOOTHd?r:,/^Hcq/-b/Q+ciRlO(\n
	_sX:ho7;KDD>O'+M>^etfsN]QHs+grh47!%@3$Y*+lX_Np_qhcHg@4?U?iB`W_fR!"i<`8Hps(*7fj
	QBk-3*j#tS&VKeO=thX8>^61OoABPUH02)YjlO13*-F/R_`QJi5Q:KR#=#s"2h,VG?X%SOhTVgaS(-
	YNY;EiWV3=3NqVkH(;Dtc\'BfVg5.P\1-bm#mH`LP#%%9UXnE&'Vp)W$ISW:C)nGq`]N5(uhd@J9)m
	Z#;03em+;s8GfCn]N$Qq!VSgc"i)]qr=6\Wgn2^="ETfNM\!II;fI=HV;A)7'j=AiS!B!QQBnD@AQP
	_6;YNH4;mD3,.hV1-2i95>`:BpQ5Fd`D1;?<qk7h$TLf>.:[1gXk[\H\@!:f4i6fa8YW!eH-mg]emT
	/e)dW;*X)LU%Fd"rMO$'8[H9D!TirUa.C5L;S4Ua/NHiF<>9Q1Mt[Me-WQ"t.V[KN\aLK\"+&@l"ts
	#L6]PfDekE_Xlg(E3FD@ZBkfSQ^@u$[W[,p_spNOK%E1gEQtd4Li".qUhS>e<]\!7Ie_"G\H+E7%Ip
	Mli:^2om:P=).c@<E6=<lK[YjFFF/TG>Y%q+)pKW&oGGr*Ql/[(WLtG_XE;9l;4SPCb54OW!@+5jj>
	D[FQ3:T2:9%$jU9qmes5/2Q[=&p3u6m-pI_8Rdn<,:e/.SuoLq,"tWfPl'5NX/Cr_O7fR3##jH678=
	&86TH2L,=Np@-!-A<b5e\;!hqX?+lsbSscFTQ'`^Hf5^N@LY9?).14@)S`m"+5SQs%XVt,fEqB(>%u
	Y^K>qh(loYGqC(Q3tp*l57\.3WK/d6IhF8Pl7ZM6ZXA&7Hs4i9;UZJ,#SN9/"SVQOY<VCK@e&]Q7/S
	Wr0i^n,D5M`SEW=[F.c4/#T&)YLu7"fjO4<,=_d)&2jGldT^DFh)F2nG4u\tk8LI&@]>\ASLThk^%Z
	Bu[VbmpEn9]Q'nJ=mm^hj!Bc?p-gr?0DI\BLc,\j]pOq2nG3"W=21,_OL[Wurg]m'#]<Up+i)GWjl5
	u^k=Q>PZJQd!>Xna^FO-:D6R0]X@"\"(dQ5(l2Z'rWqSUGEjNQoYGuFS=_iX,fE,pTj5A\gHBaD,1;
	NJ9hWsc>N7q\Pa6C6SK_-g=1=)larXCF/kGA.3jt+@t?oBL\ni7U]'99K',6'$<AlV-k<Cb)EdRuQ'
	m@lCRZUVE[6ZGTHKM8X3!><VMY0%8,_YHQbN2aUG"jDgX!$ha2djH9@uL73h"R%r:\_!I_U?pSP)FZ
	k\!f<6<WW]?e`ep]hnHX'3$S,[!i<TH/mKJ`iX]STeR<,]68WcksTJrJPJU:l[/[0B<-nlO9:&4i4?
	K55QE;-@opL7V:a*?\%TaHg.NZ1Zt^?s@o1NIDV^]:]a^EC7]h(69>sh**iii&"G9lECc/[;mi==\d
	#pp2Lqr5AR[P?9P18PcUSS@a%YL:-Jj-g*FoBT&"a"e;H9WD1%pj@Q^=S*m;GpUu>9A;*-duCr]l,>
	SJm_D1(Cjf%oB<S@o7P`C6&HLgS.b+HNAJmED)Ts;&Kuio1p\M/p>@I]>o$qe!l1Dk0ZJ*AiQB-)5P
	TQpXY5_gXkun(=CYXfkB25c;BPku=1A5+5H,1M5?gkfFf>s'U03fP\I/ek5/1n).d^521;L8u&)M_9
	mHlP/@9K@dL\h<%-TN=#g0UtLom02mr*CfldH@]:pM>Jg,VR=Zo)<#N&/V@g[&lraB\(\?o)Z\S#<L
	L=Ffk5I*;*CJqW7(kX&C4_f^YKFJ5[I&dK,S[@[I<1&U[N:kN0?jFe5AU<Ds+Zc=YQ&)7tbj]D"l.V
	9Q+7cD7h]g^\Ye(b['G;iman[r?XM9Q]SM1r@=j`1h-]Dgr>$h]0'JM6++U.lo.8\pSMifOJeQS4@%
	mD<kKf6'I)^I,eK_X[aHn7*ea>7u(*Xc($ukkkRIB_r@^M:<oKb)t_:S&7lY+=fk'agUFBdhuBs,q:
	?EC/6ck@.uf9>)]N/`nm:1R"p8Ki37iB!q"6T"CEN94e"j-:K>,WofVRCI>&3^lLSF!3d_BFnn:V7g
	k2[`=+hf4u9,tfGSN!4%gLbZ"&I%(!gaEJA(japAH`t0nANdPFn_uLB_%0f+A8"];["T&+6"E8k,#L
	I>;KTt08WBV]*uU>%3[puuh7Hn_j5Yj0n3eCQ^sM0Y;`B1?;I)2ohWS?NlF"#i^](XO^cVb?'&2R4P
	O!Sa]Sk;k95r0&S'^1T^NOJnmKY7"pCY*"P32X4FS1d&J+s9>^r8$sBR>>s<.`iJ6L,(PAgt-%RMr;
	j;);&98%g&bHZNN=='$LDDu\'<s8B\QIcFYmosHrPbb>M?H6u1-m>[[Or2[a8oJbJ$0M.rmGap2Td"
	;l.B7I.VkW5uiIb<67RVM;(5ANIZE372.o>?Y\*F'Ck-mC/l.hKS4aKAN`Y<_P/0`V2%?j&-R^"@^S
	_sboL0/l,j#_[hG.(7;eCX_S<j];[u46d:4^:V)NbVMaISX[Pra/n\oINnSMbm*T9K*7i*QIf'#e<:
	O"&16N6`pI_%;$&,!#SP7m7F-dgOV3rC,j/LKJ)Ps4bElqM!7pe+jGZg!]MGS2-B3N`m6#/6[<o.C3
	H#gi'GGPcWT=!QMr4I8FnP#Z09/U/SWHEo9FF+2lA]Ze98ReMO[51&<PkmJY4YY,:rbUW*fTmZ@gh2
	nf%M5E.s^^Um4@)e/i!'9P2"`\T7$Z/maFt<B$RQ^fZWR&dMJMo4Rq($ZsMe.R_a),IcZia5Q3Cm\A
	"K3V*Rn.FCmUG=WSP&prVUk##0KRWfkHF.IPl;Z3KsH[2Z=Im,c@7raKg(RWe_p+NnUdL3;\;h2g^%
	^+JAj+Bo:EFQ$,3&k=tq6om'X=%kXfT#19s7S?8"&V/EcE-\u2-&`3m*=B3D]0dnkh<I1D&]`?K19I
	e0Ta--H5Sb-b\[2/Wo,+_%rHXt#mb>YX70u?+7;Q"-Gk5h!\P+Gbn0l+m0>7/JY89tt2&Ru^\Tm%A_
	r;k>50OqsU8h$^U.VBl_uY[EKW$bj!j/l=M%b<Q1`7k@LE9atcbHs[?iI&#ek>lZ/%;7B\Mb+'Mm2g
	DY=D+3`>DR5_<UC'$O^<fW``QYi?hqpgFF<FO:OOFr6m1lrkS[e.iDc>:g%Sg[e8L$IUE,&W(qSfM?
	/6]5i@;ZAo4QRm-0kNr6"\.^t@har2"/8TTOO?mHr.orpCm,k0Cg5'[E7tm(;-q/*"^B)PWcN1)*[M
	\9&WHdd;T5r0`2,[m#9@KCcE!DZWF"[%6"+b+bDP\Xuh;V\#3qE$ktd//@Y^@AFsS0^WMjk\34nGBE
	c^#C9mr5T$(q9h"%h2icdB?]W5rAe)fI)I.[\Z)+Y;FHe+NTR`,8=\=t[Pubo%NAsn[>*TpZ)MetC,
	"+_-&O8%i\0+`5VZ8/T=ldP3=,2\!/1KKRTY5\r3+ihPmu99X^\P"-5:hYO>idQ>IdtP'POIphrs-#
	OD/D8c(bAJsn,DZTHi%$JUJXgk'E<5.=InQjmk$'>^\aZ&7puF1"CVI#!2;p#M^4$X<emB;*:.O'`L
	@)SYWrS#qtiU+q=`-`.GiBk]COC.QbW9%lrb9$-J22d+oif0Yspu=M5-/M(BZo:bX/7Gh0SCB5<L$!
	LtFOY8CCf+b:e9d;WO)t,_VlpM,/O(@rS)k8H_<u4W4_;iV_WL*ZZW1[kZIqCj18/f4C]+8s4%@s2W
	C]f3gL.L;e"cjm(9Hht^#jl,&Q\*[0&lf,D>TVFa'OK>+Lq"Ro0V=3TTnGY]l^6GnA,OA_l2&-g(GY
	S7S(2T*ARV2H-2]kWn#p6t.(q(-mRTaT1/-,ZG&P%b>GmflDm`N[+]]R2Q(m;MHELB<a?I=6>6pquF
	8LsgVC4H3dNou\)CC<p^\MU[LO)[W+U@R^JC5&D9]/kdBS@^25DlhL865Pr?P?LlR;r:876Z^/'!i>
	:7`H<J;>XKA%Ck/g9Rqr;[b`4QV>ME>*_pM.:KMuXaWZlb#&!0P'/Bp*,iU/f?^c:t%-^klduM%`iV
	!2Qc_-5$p474/?Xq8bQZl6fXc*kq<UMLHdC22B(FD]Lc2NZ(kTH2[,-#dLTI'leBlb1FA5qY[Z5XXl
	`r4T_p-WiF&E7U'u?C5k!WC)\7#Sn^Tfa>UA'd_Lu.F7?!A-r#R##SFJcP,`o6:gCSJc^`s8B@Fc9P
	t)lJcCR0E'VuLAc!aBj)3-=uj6INP_;3sDm_&PEW2eJ@@PqW\^lX)t(s#lB)NFUlIREaScRKq@J:OS
	.%tb'?%*3BiebPWl@;V</^%-kIY&5=la3Et9h]2Uef@a])N;>'N5MlFc2uJpK]9SK+^eqE<G.^D(8<
	,qHC]r`r*l'5F`[`a"]m03brRST9jU;H"%RbPNiRA%]!CR*CE2"YTW3$L\"&U"^^MQoMmDX.gg%FKH
	%)@eP1hAZ#S`#8^Ttd,a*#4m0CRg2Bqt/nb^A?s%K"5r\9'a'!9k;Mq;NbSKj72mM6j=$W'Nulh?f\
	roIPq@d.SDR]Y[JUo#7hM+)TCXJ"/Mr>G9e.F6CY"<SiPEkq$74WV$lWe/!D<[6n7doc!f`0kP@)N7
	\aqie(sD.4"D-=1^[H&!AVplFCW3@/TmMlh_S5(:0[D<R8oiK%bBA(XL&@n47hM(US6$)+9,^J!B0[
	Q%ZWJK(H625J*\Xi3:l\1hW!HE[oMG#QCp:EQ]N>s$<p5bL^Ak>7HjAGL10"fIeip;msaS9J#@!m<n
	kDb`sO-uCFKu^VL_":1(][`%KnLSQYNX.XjbKDFIn[^Ds>Cjp"U?Bn(aHSN/](bZJ[b"h1ah4PpBGt
	JI!H)3-,SVI/&?/Z[%%9GGh#RK/UWdiPOmFBJc/"9g8CJHBr)^m]>#t2<"+(1HsO-IFi$*q59f=$U^
	+^a3hqXUkuH4"V902*l%lOU'<#bE6b/<eo@QD]4hZt8p_dlY]7'L[!)/eKg5BCf\2blnAdVo^7hrOR
	Mlq:VQFY97Y<Tnn3N0be\Q\7*H)F0%d4cJM+EQCkh-',,c.A=-Ae<EOEtX9jS-B4rC=VKpY,:+@Wu<
	A;Yi?@]`6tm?<D+.Mf':?NfU>kP'X#m'ALMa[>7q%l<ZCHlEd2ARr.#qZ?l5iY?n!a8Tf7t?"6>edl
	,5:/iPqM8Rg!+!:Tn64hC:%&-%+YqIWS=l]439G4BtG*GW!n[K_$.*u(_^5iWlj@*^b&C1dd"N&is/
	>bje#\XCqPYJ(n?Q6DDkB@C>Q5Q%JYlbBogCT9im?IB1G<`\T_k$qnWBLV6uY4iJr&Ls4]+^u'DU3u
	`;s%dQMBs>%IH<G/p!KF32QfYoG#;5C[DU(W%\F`%+Af\5["K5Ol9]g]6)TX$YZheo-Ti>kkF@e(Y@
	,AQm^\l&+X%UcfZ0:B8E,\c7D28K$Mg"5jl,&.B<SilmHbko-5%2]%0l%LM6iiF6F;+ii!e<[QA895
	pi"$)/7t]nV4Rsco_b[FBI.E-;l\e:"_l^&c\)3U#fR*(^Yd:+IH#+tiW&5/!1[GtVlIj,oa6AAO*$
	iN&04(@B1"J30qR,@9;(jk&+Rc^4Uil(mmd.Edof%(2Dr)=)B/2J`a4iO[ZZXfm[F(A/R#kKP(i#Zq
	%bI>%ltjH*2RfMt!Q_T(NK_HC>RQ_hHThSq,9BismW6</Ef<kZ&oL.V>2-6\cI"5`\9)J9HZH+LI.B
	gUFAgCqB=m:cf89a$`gJ+.ZH5sD[>OYo7pp2q]MbbrB<eG:l'+/*'TC8[6-7Bj_387'Ouo-&S+"RkD
	!g[la&Ca"L<0)Z1sJB*fk=`gFeV=(e66S"+9WBHd)&=N.je`l+rYun&QIq0c[m^*0T`F_kWC:8]=<*
	"eMb`TBsuIYT.=-UZa98P=.7%+C`f0=P6@UnN1bP$"sMEo14tXrkIWh<h.nM+%BjWK`j:P:59"mlb:
	jL0bUA<o*aKH7dHqru3,9#u$S\#K<E8+-k#b4dKVB/o_]\QG=b&U*:[W[hYV([QOQ?XR,R/*:OU`?;
	[8LZ_7H*I);G*Y2`YbPAV?%52V3TTR!^Q5a.=JBf5-YS6TZ@9U?TJ\4#fI2eogP8ch=7kU'dk7sV3>
	WMHDOS*cXPX<$igj/7hf`UN8f&B%tF3ZWS2E)CEbUeDchO`YlHJMejAAki*_p)otfqE]+D)6`B^!p&
	5]XoW"j%Ia3:8QTM_"'U19,f5Y,(VOdcZ4-;W,FMs874d8>^_QW81gQ9U`F7?&&uWN(@8[J+(2a`9g
	21u?KGqTd[.Vk<b=>;TMd<[efm":'a8U5*U$s0&\Kqj#qrcM1I@h+_oLBBJ"CE[4fRPmf*>C^GC.6h
	4:_a<-TKaFj(r-U7_\0k.>]eR_h1m[cSN\St)_=&g;$F6"H5TQt2^o=u5eOY^Ntp&2T5.4CKBKQ^D\
	M!_Db2I2E/RT\Z5j2eWE<pQVsLLCT@.4&gI6tAG=S$f.b3X0JeFW?Y[#`(h%DCn1+0a^STcfRPZG'+
	gm")OdN[ZHMt(829P1X'9rh8rn8"cPq;ZRUu'im_pXd&nI#Q%kg8CD5aF]p(_J"u_,G=CQ:!U9*%l$
	pNNa,P,X"12N:I')#dL\V=8%>E>fOK64O=,*,*r,SFj5F(.sXVn`QN,*`-YmX$R<P:;`kR(=)D''"<
	-^4X;,H$aaT[%q"'p](0AGJEu36[-`LgQsQliqiG+gU]B@IOq6P<V30UQ;,s8?I$;-3up4S:<Rs4]^
	0P(!c^%'`!*"Pe9J[kW[+:<lM4:UcSh-!h5Y8Fed4s;;:Ns0GIsQ@`ThQRS1fmX8o[<U,9:f#0EX_?
	?#pA6DM;@R:CA:+%*TK>J?lDiB-u+cn%(&:9Ed+/-W8n7,rDUk-p8;?*"4.V;8(qMU,5lEh"soG+>Z
	A+:a3q\$_("L%?$Qm'Mubrgan8/#9@ifU^A7RPU"-NdmhM/OHV\jZ^a"bUtCJj*MP0>R8\,5Th;Bg.
	1q+3-\G?;$WY?[=E0;FOeU>J1&+Td!ii8;SppD/:X:(%O86;gp%$?d?[_n0djO\UA*gX25Q?%N]=Ks
	b5CN)456$Ffo:,,c^\[*Mro43k4?rha?iB*V?[VSAJ+L.U$?r!j'4^P^N,@C1e`5-==VFTg\S*t8r:
	Rg2^&7lhW5Zm<bI<gNml^I)K:a%Nc-$oif@ShdQ+;ciK5ZCS8<:8?R['S.WPhos"-KTr=IC51Kfi0S
	@7D[lel=.D6&!G8>(h^MX;!R:KFgKV)ca*'Fr5n6DX6]$:`brXoOBmQ4@mVWBia>cZV],XRf[_1eKc
	Ca`Y)C2>/)"=o!K0<Upc?p]?KWEYBN"YBmAfMrolrDi4O^[1>,bT`W-W=!/HDaHMM0\?Jhl.)k[JI=
	`Gg.E(TCa"^X#F8R`>hpE\_km:B`kRElX7FM#@c![q]`RTZYk5tfgP7<>#eB6E*4h9Fc2@<)2+Mf*r
	I`#%m6T:DJMo0<6F<"eU[0i#o;=<,HRaOr)O^mL[`_!k_2n4t]es2@c`p-C`Shl^kB+$Or?nXkBs`U
	j+Yn[iGimp>]hDq]I<jeMVQjC:EG/XNN]S(70h(Jht(->%:m6<4(6Y>];8]3RX]_tj+\E?'/6hFsDN
	2OcS1=Y%A,0Qu8q(e-04h%n%$lS?\F(FKa=hn48`GBn6bS$/u5S#.&[99mdD4rB%5k3Z.S6(tWncJ:
	JJ3`?L3F\6qk4lRCOKF].frlN.Afo*J/hp'Km?JhpLkbNP!]q\@eX?ZT8s8;'3asi*S4grOW:tqBoU
	Bu`eFFDuIf!h^Ig-#[cZ0Y6*ZHG/,B/M1)7iFi'UdA4*,oirG<*%`gi3V*qe4gOc)N1R5#tYaBW""A
	pT0g<XIX^jtH[Qc`=L=U.kWnJ5d<q'X>?0d[G$rWiY-q$Kh;+V\iH2eYoe4'c]t+"3o3^"*=`7m-GD
	i=%;eJI];8$/pS(mXQL5I^X@i2K-TUi9YIIZ<T04XNth(0>"G!8ER%e&sBQ@*_!3Y'(#p%:!I:S'Zd
	a78H[C)D^$I"$NnN^o/W[cfbW?=(<jZWZ*i^&%HEdjHI4US#2WpYX<CT>10\X*NM`I.53u^:IOVa,B
	*E;f"DM55W7+>@1W?*'J\*mI',kml#C!9i\Sqh;,71RoO1Oa^9P/puLJ)^\d-YB4$,[kpOea>ol6/\
	A!28]`2YFV/P>Yc1#%fVHp'El8@`u&?_3NK3#$mf5FaFFl.+.Mj(\M!?"CJMAh'iWe%6*S.tk)=u2U
	\as8mM^`tNNKI9f8!GPsN,34,.>#[Gh/1!(X=t,UQ3@c<^$3O$+Lp7QgJ7(A)/aB,MUG/3cb$`AN8o
	`^U3,WLN_Ho*k*jI(Y-Q(nU@&F6VbPq`6rVnNo%pkcBP^W!74+aatVPOA@2Ep2&@^6ILS.D5U/Rb(b
	P+mm0Ic3nDd+KsGSLfp9`t5i)q^>s1&Rd[4\SX^U%-oH@FgRY@#^ICIQROm^o/Q[K)E9YFO+B:9:tG
	Rs,1tT:K12ZtB/V`.Vr]uOQjgg)?ue/E+Y/MgTs2r$P"3t'H"I7'cKlstR5$H(@1s6lPZZW2+AOCr'
	FY%$"0eeM3;CK?oCb"8PPd<Ni:l`RK<Xhm%CL\s<%p$_[`k8\*))B+HXm80aYbsCH!:##O-=l4[b']
	>*m70\$[>mD'%BcIF+R;?7jX+1"U62Pc.RZRThHFUM310`Wg".M(h95#3*+i/?-*rk38a&a7OV-!X`
	/93=JEKkh8C[nN&kZ];;R4)5nORJ!'o<J-@Uc,5+L<;mg!GPM"(U;\dpE_f"e.4hY/Pg?Od;U_DV`]
	i#KoNg^O7D$1A>brL3B8pMs&Sr6_>bB*6ps;f3+#gdn?6(cbuCRQ-W1>ZE#?ka'?k(bfs>OgmKH.Qh
	jW9ZS+u1)GJ317?&<Wl7rJ%%aM]P,B0T'h9V^\K;A2KM\?l?<#agO?!p20K(492Q+EViCn.M;`rC%^
	)Os!-@eCI$-pQ>]M(m2PIYE@S4q^G0K.ZEpu0$0AG5mFgb7%r0JE1fp,&$[-nA(0(;pen[`>?F0KRk
	>bSar1#+:#[qs>Ie_Uqut%!.3?%e-!:pXS4b0^O3d;hY`UoBCT@Cq@Oj;_,i:A;@kDO9&*W!*=a`0u
	KE['Uode:-g)S!Fu4K9Uqi%W/Vo2lO+GdA%$)pfbgKO`fe;3+\HQ-\UC?-2`>.9abjk1&6)KA"tGiW
	,)<<q;)$aQ/36-!Ya[EQk37@!A.t$JLlM,8/cnf_&HTgE*JIq]U4lEqs0!X6F0o<t[XF+3:!"6tX?X
	9qi^SYVB``\OW8624J]UFRKA"@Kp-]GHq^7X0Z7HQr9#66+E,mZ9JpK(<NB.X\+h1'R&Z0->@]YC&a
	IXn&K86Ia-<+A@'NpM1/5kt"A?[/7pWd(p2)-^oKkt:S:VjEe<#0W\Ri?;Xm$669p3A`Ckh:^+iJp6
	ZHX7_t!seI^ZQnno7<Z2>^qQH5]g[]R-=d>'j>7*,Y"esr!J3AKBOZ,^0`(FeNuQ?'%%mo>4E5;:((
	meB*h((R;iS\O8L+74SZm='_8p$jH+G(PRlE$<+:X?'*@qCq,%4n(@3P6i`o8Jn=o<aLN+8&Q)p,A+
	z8OZBBY!QNJ
	ASCII85End
End
