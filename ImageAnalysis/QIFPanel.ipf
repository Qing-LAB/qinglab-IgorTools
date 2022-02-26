#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <ImageSlider>
#include <WMBatchCurveFitIM>

function /T QITiffTagInfo(wave /T tagwave)

	String infostr=""
	variable i
	
	for(i=0; i<DimSize(tagwave, 0); i+=1)
		strswitch(tagwave[i][0])
		
			case "256": //IMAGEWIDTH
				infostr+="IMAGEWIDTH="+tagwave[i][4]+"\n"
				break
			case "257": //IMAGELENGTH
				infostr+="IMAGELENGTH="+tagwave[i][4]+"\n"
				break
			case "270": //IMAGEDESCRIPTION
				infostr+=tagwave[i][4]+"\n"
				break
			case "282": //XRESOLUTION
				infostr+="XRESOLUTION="+tagwave[i][4]+"\n"
				break
			case "283": //YRESOLUTION
				infostr+="YRESOLUTION="+tagwave[i][4]+"\n"
				break		
		endswitch
	endfor
	
	return infostr
end

function QIRefreshFilePath(string homePath, string & relativePath, string & fullPath)
//relative path is higher priority. if relativePath is not empy, will regenerate fullPath from homePath and relativePath
	int i, j
	int maxidxh=ItemsInList(homePath, ":")
	int maxidxf=ItemsInList(fullPath, ":")
	int maxidxr=ItemsInList(relativePath, ":")
	
	if(strlen(relativePath)==0)
		//need to generate the relative path		
		for(i=0; i<maxidxh && i<maxidxf; i+=1)
			if(cmpstr(StringFromList(i, homePath, ":"), StringFromList(i, fullPath, ":"))!=0)
				break
			endif
		endfor
		relativePath=""
		for(j=i; j<maxidxh; j+=1)
			relativePath+=":"
		endfor
		for(j=i; j<maxidxf; j+=1)
			relativePath+=":"+StringFromList(j, fullPath, ":")
		endfor
		//print relativePath
	else
		//need to generate the absolute path
		fullPath=homePath
		for(i=1; i<maxidxr; i+=1)
			string fname=StringFromList(i, relativePath, ":")
			if(strlen(fname)==0)
				fullPath=RemoveListItem(ItemsInList(fullPath, ":")-1, fullPath, ":")
			else
				fullPath=AddListItem(StringFromList(i, relativePath, ":"), fullPath, ":", inf)
			endif
		endfor
		fullPath=RemoveEnding(fullPath, ":")
		//print fullPath
	endif
end

function QILoadTiffByIdx(string frameWaveName, int idx, int refresh_tag_flag, int load_data_flag, [string &imginfo, variable ridx, variable gidx, variable bidx])
	
	Variable refNum
	Variable retVal=-1
	string imgidx="", compareidx=""
	
	string imageInfoStr=""
	if(WaveExists($frameWaveName))
		imageInfoStr=note($frameWaveName)
		if(strlen(StringByKey("QIWAVE", imageInfoStr, "=", "\n", 0))==0)
			refresh_tag_flag=1
		endif
	else
		refresh_tag_flag=1
	endif
	
	string absolutePath=StringByKey("FILE", imageInfoStr, "=", "\n", 0)
	string relativePath=StringByKey("RELATIVEPATH", imageInfoStr, "=", "\n", 0)
		 	
	if(refresh_tag_flag==1)	 	
	 	if(strlen(absolutePath)==0) //no file has ever been loaded
			Open /D /R /F="TIFF Files:.tif,.tiff;All Files:.*;" refNum
			absolutePath=S_fileName
			relativePath=""
		endif
		
		if(strlen(absolutePath)>0)
			PathInfo home
			string homePath
			
			if(V_flag==0)
				homePath=""
			else
				homePath=S_path
			endif
			
			QIRefreshFilePath(homepath, relativePath, absolutePath)
			imageInfoStr=ReplaceStringByKey("FILE", "QIWAVE=1\n", absolutePath, "=", "\n", 0)
			imageInfoStr=ReplaceStringByKey("RELATIVEPATH", imageInfoStr, relativePath, "=", "\n", 0)
			//print "tag refreshed"
			//load_data_flag=1 //force loading data
			imgidx=""
		endif
	else
		imgidx=StringByKey("IMAGEINDEX", imageInfoStr, "=", "\n", 0)
	endif
	
	if(strlen(absolutePath)==0)
		return -1
	endif
	
	variable total_frames=-1
	
	DFREF dfr=GetDataFolderDFR()
	KillWaves /Z :QITMPIMG_TAG, :QITMPIMG_IMG, :QITMPIMG_IMG_RAW; AbortOnRTE
	NewDataFolder/O/S QIImgTmp; AbortOnRTE
	try
		string winfo=imageInfoStr
		
		if(refresh_tag_flag==1)
			ImageLoad/T=tiff/Q/RTIO absolutePath; AbortOnRTE
			total_frames=V_numImages
					
			if(V_Flag==1)
				winfo += QITiffTagInfo(:Tag0:T_Tags)				
				MoveWave :Tag0:T_Tags, dfr:QITMPIMG_TAG; AbortOnRTE
				retVal=0
			else
				retVal=-1
			endif
		else
			total_frames=str2num(StringByKey("images", winfo, "=", "\n", 0))
		endif
		
		if(refresh_tag_flag==1 || load_data_flag==1)
			if(idx>=0)
				compareidx=AddListItem(num2istr(idx), "", ";", inf)
				ridx=idx
				compareidx=AddListItem(num2istr(idx), compareidx, ";", inf)
				gidx=idx
				compareidx=AddListItem(num2istr(idx), compareidx, ";", inf)
				bidx=idx
			else
				if(ParamIsDefault(ridx) || numtype(ridx)!=0 || ridx<0 || ridx>total_frames)
					ridx=-1
				endif
				if(ParamIsDefault(gidx) || numtype(gidx)!=0 || gidx<0 || gidx>total_frames)
					gidx=-1
				endif
				if(ParamIsDefault(bidx) || numtype(bidx)!=0 || bidx<0 || bidx>total_frames)
					bidx=-1
				endif
				compareidx=AddListItem(num2istr(ridx), "", ";", inf)
				compareidx=AddListItem(num2istr(gidx), compareidx, ";", inf)
				compareidx=AddListItem(num2istr(bidx), compareidx, ";", inf)
			endif
		endif
		
		winfo=ReplaceStringByKey("IMAGEINDEX", winfo, imgidx, "=", "\n", 0)
		
		if(load_data_flag==1)
			variable maxx, maxy
			
			maxx=str2num(StringByKey("IMAGEWIDTH", winfo, "=", "\n", 0))
			maxy=str2num(StringByKey("IMAGELENGTH", winfo, "=", "\n", 0))
			
			if(numtype(maxx)!=0 || maxx<=0 || numtype(maxy)!=0 || maxy<0)
				retVal=-3
			else
				Variable wtype=0x10
				if(ridx>=0)
					ImageLoad/T=tiff/Q/C=1/S=(ridx)/BIGT=1/N=tmpImg_R/O absolutePath; AbortOnRTE
					wtype=WaveType(:tmpImg_R)
				else
					Make /O/N=(maxx, maxy)/Y=0x10 :tmpImg_R=0
				endif
				
				if(gidx>=0)
					if(gidx==ridx)
						Duplicate /O :tmpImg_R, :tmpImg_G						
					else
						ImageLoad/T=tiff/Q/C=1/S=(gidx)/BIGT=1/N=tmpImg_G/O absolutePath; AbortOnRTE
					endif
					wtype=WaveType(:tmpImg_G)
				else
					Make /O/N=(maxx, maxy)/Y=0x10 :tmpImg_G=0
				endif
				
				if(bidx>=0)
					if(bidx==ridx)
						Duplicate /O :tmpImg_R, :tmpImg_B
					elseif(bidx==gidx)
						Duplicate /O :tmpImg_G, :tmpImg_B
					else
						ImageLoad/T=tiff/Q/C=1/S=(bidx)/BIGT=1/N=tmpImg_B/O absolutePath; AbortOnRTE
					endif
					wtype=WaveType(:tmpImg_B)
				else
					Make /O/N=(maxx, maxy)/Y=0x10 :tmpImg_B=0
				endif
				
				Make /O/N=(maxx, maxy, 3)/Y=(wtype) tmpImg, tmpImg_Raw
				wave tmpImg_R=:tmpImg_R
				wave tmpImg_G=:tmpImg_G
				wave tmpImg_B=:tmpImg_B
				
				tmpImg_raw[][][0]=tmpImg_R[p][q]
				ImageHistModification /I :tmpImg_R
				Wave M_ImageHistEq
				tmpImg[][][0]=M_ImageHistEq[p][q]
				
				tmpImg_raw[][][1]=tmpImg_G[p][q]
				ImageHistModification /I :tmpImg_G
				tmpImg[][][1]=M_ImageHistEq[p][q]
				
				tmpImg_raw[][][2]=tmpImg_B[p][q]
				ImageHistModification /I :tmpImg_B
				tmpImg[][][2]=M_ImageHistEq[p][q]
								
				MoveWave tmpImg, dfr:QITMPIMG_IMG; AbortOnRTE
				moveWave tmpImg_Raw, dfr:QITMPIMG_IMG_RAW; AbortOnRTE
				retVal=0
				
				imgidx=compareidx
				winfo=ReplaceStringByKey("IMAGEINDEX", winfo, imgidx, "=", "\n", 0)	
			endif
		endif	
	catch
		variable err=GetRTError(1)
		print "The following error encountered during loading image. Please click refresh button and try again, or check your relative path of images to the igor experiment file."
		print GetErrMessage(err)
		print "File information:", absolutePath
		print "Frame index:", idx
		retVal=-100
	endtry
	KillDataFolder :
	
	if(retVal==0)
		if(refresh_tag_flag==1)
			//Make /O /T /N=(DimSize(dfr:QITMPIMG_TAG, 0), DimSize(dfr:QITMPIMG_TAG, 1)) $(frameWaveName+"_Tag")
			//wave w_tag=$(frameWaveName+"_Tag")
			//Duplicate /O dfr:QITMPIMG_TAG, w_tag; AbortOnRTE
			Duplicate /O dfr:QITMPIMG_TAG, $(frameWaveName+"_Tag"); AbortOnRTE
		endif
		
		if(load_data_flag==1)
			//Make /O /N=(DimSize(dfr:QITMPIMG_IMG, 0), DimSize(dfr:QITMPIMG_IMG, 1)) $frameWaveName
			//wave w_img=$frameWaveName
			//Duplicate /O dfr:QITMPIMG_IMG, w_img	; AbortOnRTE
			Duplicate /O dfr:QITMPIMG_IMG_RAW, $(frameWaveName+"_Raw")	; AbortOnRTE
			wave w_raw=$(frameWaveName+"_Raw")
			//Make /O/N=(DimSize(w_raw, 0), DimSize(w_raw, 1), 3)/Y=0x10 $(frameWaveName)
			//Wave w_img=$frameWaveName
			Duplicate /O dfr:QITMPIMG_IMG, $(frameWaveName)
			wave w_img=$(frameWaveName)
			
			variable xres=str2num(StringByKey("XRESOLUTION", winfo, "=", "\n", 0))
			variable yres=str2num(StringByKey("YRESOLUTION", winfo, "=", "\n", 0))
			string unit=StringByKey("unit", winfo, "=", "\n", 0)
			
			if(numtype(xres)!=0)
				xres=1
			endif
			if(numtype(yres)!=0)
				yres=1
			endif
			SetScale/P x 0,1/xres, unit, w_img; AbortOnRTE
			SetScale/P y 0,1/yres, unit, w_img; AbortOnRTE
			
			note /k w_img, winfo; AbortOnRTE
		endif
		
		
		KillWaves /Z dfr:QITMPIMG_TAG, dfr:QITMPIMG_IMG, dfr:QITMPIMG_IMG_RAW; AbortOnRTE
		if(!ParamIsDefault(imginfo))
			imginfo=winfo
		endif
	endif
	
	return retVal
end

function QIGetIdxByChn(int ColorChn, int ZIdx, int TimeIdx, String DimOrder, String TiffInfo)
	variable totalColorChn=str2num(StringByKey("channels", TiffInfo, "=", "\n", 0))
	variable totalIdx=str2num(StringByKey("images", TiffInfo, "=", "\n", 0))
	variable totalZ=str2num(StringByKey("slices", TiffInfo, "=", "\n", 0))
	variable totalTimeIdx=str2num(StringByKey("frames", TiffInfo, "=", "\n", 0))
	
	if(numtype(totalColorChn)!=0)
		totalColorChn=1
	endif
	if(numtype(totalZ)!=0)
		totalZ=1
	endif
	if(numtype(totalIdx)!=0)
		totalIdx=0
	endif	
	if(numtype(totalTimeIdx)!=0)
		totalTimeIdx=totalIdx/totalColorChn/totalZ
	endif
	
	variable idx=-1
	
	strswitch(DimOrder)
		case "XYCZT":
			if(ColorChn>=0 && ColorChn<totalColorChn && ZIdx<totalZ && TimeIdx<totalTimeIdx)
				idx=(totalColorChn*totalZ)*TimeIdx + totalColorChn*zIdx + ColorChn
				if(numtype(idx)!=0 || idx>=totalIdx)
					idx=-1
				endif
			endif
			break
	endswitch
	
	return idx
end

function QILoadTiffByChn(string frameWaveName, string ColorChnList, int ZIdx, int TimeIdx, int refresh_tag_flag, [string DimOrder])
	variable retVal=-1
	
	if(ParamIsDefault(DimOrder))
		DimOrder="XYCZT"
	else
		DimOrder=UpperStr(DimOrder)
	endif
	//print ColorChn, ZIdx, TimeIdx, DimOrder
	
	string imageInfoStr=""
	if(WaveExists($frameWaveName))
		imageInfoStr=note($frameWaveName)
		if(strlen(StringByKey("QIWAVE", imageInfoStr, "=", "\n", 0))==0)
			refresh_tag_flag=1
		endif
	else
		refresh_tag_flag=1
	endif
	
	Variable color_idx=-1
	
	if(refresh_tag_flag==1)
 		retVal=QILoadTiffByIdx(frameWaveName, 0, 1, 0, imginfo=imageInfoStr) //refresh tag info only, no data loaded
	else
		retVal=0
	endif
	
	variable max_channels=str2num(StringByKey("channels", imageInfoStr, "=", "\n"))
	if(numtype(max_channels)!=0)
		max_channels=1
	endif
	
	if(retVal==0)
		retVal=-1
		variable idx=-1
		switch(ItemsInList(ColorChnList))
		case 1: //only a single channel is selected
			color_idx=str2num(StringFromList(0, ColorChnList))
			if(color_idx>=0 && color_idx<max_channels)
				idx=QIGetIdxByChn(color_idx, ZIdx, TimeIdx, DimOrder, imageInfoStr)
				if(idx>=0)
					retVal=QILoadTiffByIdx(frameWaveName, idx, 0, 0, imginfo=imageInfoStr)
				endif
			endif
			break
		case 3: //rgb channels requested.
			variable ridx, gidx, bidx
			ridx=str2num(StringFromList(0, ColorChnList))
			idx=QIGetIdxByChn(ridx, ZIdx, TimeIdx, DimOrder, imageInfoStr)
			ridx=idx
			
			gidx=str2num(StringFromList(1, ColorChnList))
			idx=QIGetIdxByChn(gidx, ZIdx, TimeIdx, DimOrder, imageInfoStr)
			gidx=idx
			
			bidx=str2num(StringFromList(2, ColorChnList))
			idx=QIGetIdxByChn(bidx, ZIdx, TimeIdx, DimOrder, imageInfoStr)
			bidx=idx
			
			retVal=QILoadTiffByIdx(frameWaveName, -1, 0, 1, imginfo=imageInfoStr, ridx=ridx, gidx=gidx, bidx=bidx)			
			break
		default:
			retVal=-1
		endswitch
	endif
	
	if(retVal==0)
		imageInfoStr=ReplaceStringByKey("CURRENT_CHANNEL", imageInfoStr, ColorChnList, "=", "\n", 0)
		imageInfoStr=ReplaceStringByKey("CURRENT_SLICE", imageInfoStr, num2istr(ZIdx), "=", "\n", 0)
		imageInfoStr=ReplaceStringByKey("CURRENT_FRAME", imageInfoStr, num2istr(TimeIdx), "=", "\n", 0)
		//imageInfoStr=ReplaceStringByKey("CURRENT_INDEX", imageInfoStr, num2istr(idx), "=", "\n", 0)
		note /k $frameWaveName, imageInfoStr
	endif
		
	return retVal
end

function QIPanel([string graphName, variable refresh])
	if(ParamIsDefault(graphName))
		graphName=WinName(0, 1)
	endif
	if(ParamIsDefault(refresh))
		refresh=1
	endif
	
	//get info of the image first
	string imglist=ImageNameList(graphName, ";")
	string imgname=StringFromList(0, imglist)
	DFREF dfr=$(StringByKey("ZWAVEDF", ImageInfo(graphName, imgname, 0), ":", ";"))
	wave img=dfr:$imgname
	string imginfo=note(img)
	
	variable totalColorChn=str2num(StringByKey("channels", imginfo, "=", "\n", 0))
	variable totalIdx=str2num(StringByKey("images", imginfo, "=", "\n", 0))
	variable totalZ=str2num(StringByKey("slices", imginfo, "=", "\n", 0))
	variable totalTimeIdx=str2num(StringByKey("frames", imginfo, "=", "\n", 0))
	string current_colorchn=StringByKey("CURRENT_CHANNEL", imginfo, "=", "\n", 0)
	variable current_zidx=str2num(StringByKey("CURRENT_SLICE", imginfo, "=", "\n", 0))
	variable current_timeidx=str2num(StringByKey("CURRENT_FRAME", imginfo, "=", "\n", 0))
	
	if(numtype(totalColorChn)!=0)
		totalColorChn=1
	endif
	if(numtype(totalZ)!=0)
		totalZ=1
	endif
	if(numtype(totalIdx)!=0)
		totalIdx=0
	endif	
	if(numtype(totalTimeIdx)!=0)
		totalTimeIdx=totalIdx/totalColorChn/totalZ
	endif
	
	if(refresh==0)
		if(strlen(current_colorchn)==0)
			current_colorchn="0;"
		endif
		if(numtype(current_zidx)!=0)
			current_zidx=0
		endif
		if(numtype(current_timeidx)!=0)
			current_timeidx=0
		endif
	else
		current_colorchn="0;"
		current_zidx=0
		current_timeidx=0
	endif

	if(strlen(GetUserData(graphName, "", "QIPANEL"))==0)
		ModifyGraph /W=$graphName width={Aspect,(DimDelta(img, 0)*DimSize(img, 0))/(DimDelta(img, 1)*DimSize(img, 1))}
		QILoadTiffByChn(GetWavesDataFolder(img, 2), current_colorchn, current_zidx, current_timeidx, refresh)
		DoUpdate
		imginfo=note(img)
		string roi_tracelist=StringByKey("ROITRACE", imginfo, "=", "\n", 0)
		if(strlen(roi_tracelist)==0)
			roi_tracelist=";"
		endif
		NewPanel /Ext=0 /HOST=$graphName	/N=$(graphName+"QIPanel") /W=(0, 0, 200, 400)
		SetWindow $S_name, userdata(GRAPHNAME)=graphName
		SetWindow $graphName, userdata(QIPANEL)=S_name
		SetWindow $graphName, userdata(IMAGEWAVE)=GetWavesDataFolder(img, 2)
		SetWindow $graphName, hook(QIPanel_MouseFunc)=QIPanel_MouseFunc
		
		TitleBox cords, title="Px=?, Py=?\nx=?, y=?", size={150, 40}
		Button refresh, title="Refresh/Reload File", size={150, 20}, proc=QIPanel_RefreshFile
		CheckBox channel_rgb, title="RGB channel enabled", size={150, 20}, proc=QIPanel_ReloadFrame
		SetVariable channel_r, limits={-1, totalColorChn, 1}, live=1, value=_NUM:0, title="channel#", format="%d / "+num2istr(totalColorChn-1), size={150, 20}, proc=QIPanel_ReloadFrame
		SetVariable channel_b, limits={-1, totalColorChn, 1}, live=1, value=_NUM:0, title="channel#", format="%d / "+num2istr(totalColorChn-1), size={150, 20}, disable=2, proc=QIPanel_ReloadFrame
		SetVariable channel_g, limits={-1, totalColorChn, 1}, live=1, value=_NUM:0, title="channel#", format="%d / "+num2istr(totalColorChn-1), size={150, 20}, disable=2, proc=QIPanel_ReloadFrame		
		SetVariable slice, limits={-1, totalZ, 1}, live=1, value=_NUM:current_zidx, title="slice#", format="%d / "+num2istr(totalZ-1), size={150, 20}, proc=QIPanel_ReloadFrame
		SetVariable frame, limits={-1, totalTimeIdx, 1}, live=1, value=_NUM:current_timeidx, title="time#", format="%d / "+num2istr(totalTimeIdx-1), size={150, 20}, proc=QIPanel_ReloadFrame
		Button roi_new, title="New ROI", size={80,20}, proc=QIPanel_ROINew
		Button roi_edit, title="Edit ROI", size={80,20}, proc=QIPanel_ROIEdit
		PopupMenu roi_list, size={80,20}, title="ROI#", value=#roi_tracelist
		Button roi_del, title="Delete ROI", size={80,20}, proc=QIPanel_ROIDelete
		
		string userfunc_type="WIN:Procedure;KIND:2;NPARAMS:7"
		Button call_userfunc1, title="call", size={30, 20}
		PopupMenu userfunc_list1, size={80, 20}, title="#1", value=FunctionList("QIF_*", ";", "")
		
	endif
end

function QIPanel_ReloadFrameAction(string panelname, [variable refresh])
	string parentwin=GetUserData(panelname, "", "GRAPHNAME")
	string fw=GetUserData(parentwin, "", "IMAGEWAVE")
	string imginfo=note($fw)
	
	variable totalColorChn=str2num(StringByKey("channels", imginfo, "=", "\n", 0))
	variable totalTimeIdx=str2num(StringByKey("frames", imginfo, "=", "\n", 0))
	variable totalZ=str2num(StringByKey("slices", imginfo, "=", "\n", 0))
	variable totalIdx=str2num(StringByKey("images", imginfo, "=", "\n", 0))
	if(numtype(totalColorChn)!=0)
		totalColorChn=1
	endif
	if(numtype(totalZ)!=0)
		totalZ=1
	endif
	if(numtype(totalIdx)!=0)
		totalIdx=0
	endif	
	if(numtype(totalTimeIdx)!=0)
		totalTimeIdx=totalIdx/totalColorChn/totalZ
	endif
	
	ControlInfo /W=$panelname channel
	Variable channel=V_Value
	ControlInfo /W=$panelname slice
	Variable slice=V_Value
	ControlInfo /W=$panelname frame
	Variable frame=V_Value
	
	if(channel>=totalColorChn)
		channel=0
	endif
	if(channel<0)
		channel=totalColorChn-1
	endif
	
	if(slice>=totalZ)
		slice=0
	endif
	if(slice<0)
		slice=totalZ-1
	endif
	
	if(frame>=totalTimeIdx)
		frame=0
	endif
	if(frame<0)
		frame=totalTimeIdx-1
	endif
	
	SetVariable channel, win=$panelname, value=_NUM:channel
	SetVariable slice, win=$panelname, value=_NUM:slice
	SetVariable frame, win=$panelname, value=_NUM:frame
	
	if(ParamIsDefault(refresh))
		refresh=0
	else
		refresh=1
	endif
	
	//QILoadTiffByChn(fw, channel, slice, frame, refresh)
end

Function QIPanel_ReloadFrame(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			//Variable dval = sva.dval
			//String sval = sva.sval
			DoUpdate
			QIPanel_ReloadFrameAction(sva.win)
			DoUpdate
			break
		case -1: // control being killed
			break
	endswitch
	
	return 0
End

Function QIPanel_MouseFunc(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	string axis
	string xaxis, yaxis
	
	axis=AxisList(s.winName)
	yaxis=StringFromList(0, axis)
	xaxis=StringFromList(1, axis)
	
	variable xmin, xmax, ymin, ymax
	GetAxis /W=$(s.winName) /Q $xaxis
	xmin=V_min
	xmax=V_max
	GetAxis /W=$(s.winName) /Q $yaxis
	ymin=V_min
	ymax=V_max
	variable cur_x=AxisValFromPixel(s.winName, xaxis, s.mouseLoc.h)
	variable cur_y=AxisValFromPixel(s.winName, yaxis, s.mouseLoc.v)
	string imgwave=GetUserData(s.winName, "", "IMAGEWAVE")
	wave imgw=$imgwave
	string panelname=GetUserData(s.winName, "", "QIPANEL")
	
	switch(s.eventCode)
		case 0:				// Activate
			// Handle activate
			break

		case 1:				// Deactivate
			// Handle deactivate
			break
		case 11:
			if(s.specialKeyCode == 202)
				GetWindow /Z $panelname hide
				if(V_value==0)
					SetWindow $panelname, hide=1
					SetDrawlayer /W=$(s.winName) ProgFront
					SetDrawEnv fname="Arial", fsize=10, textrgb=(65535,0,0), xcoord=abs, ycoord=abs
					DrawText /W=$(s.winName) 0, 10, "QIPanel hidden"
				else
					SetWindow $panelname, hide=0
					SetDrawLayer /W=$(s.winName) /K ProgFront
				endif
			endif
			break
		case 4: //moved
			string tmptxt
			variable px=floor((cur_x-DimOffset(imgw, 0))/DimDelta(imgw, 0)+0.5)
			variable py=floor((cur_y-DimOffset(imgw, 1))/DimDelta(imgw, 1)+0.5)
			sprintf tmptxt, "Px=%d, Py=%d\nx=%.2f, y=%.2f", px, py, cur_x, cur_y
			TitleBox cords, win=$panelname, title=tmptxt
			DoUpdate
			break
			
		case 22: //wheel
			if((s.eventMod & 8)!=0) //Ctrl key
				variable xrange=xmax-xmin
				variable yrange=ymax-ymin
				variable midx=(xmax+xmin)/2
				variable midy=(ymax+ymin)/2
				
				if(s.wheelDx+s.wheelDy<0)
					xrange=xrange*1.05
					yrange=yrange*1.05
				elseif(s.wheelDx+s.wheelDy>0)
					xrange=xrange*0.95
					yrange=yrange*0.95
				endif
				xmin=midx-xrange/2
				xmax=midx+xrange/2
				ymin=midy-yrange/2
				ymax=midy+yrange/2
	
				SetAxis /W=$(s.winName) $xaxis, xmin, xmax
				SetAxis /W=$(s.winName) $yaxis, ymin, ymax
			else
				ControlInfo /W=$panelname frame
				variable f=V_Value
				if(s.wheelDx+s.wheelDy<0)
					f+=1
				elseif(s.wheelDx+s.wheelDy>0)
					f-=1
				endif
				SetVariable frame, win=$panelname, value=_NUM:f
				QIPanel_ReloadFrameAction(panelname)
				DoUpdate
			endif
			
			break
		// And so on . . .
	endswitch

	return hookResult		// 0 if nothing done, else 1
End

Function QIPanel_ROINew(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			string panelname=ba.win
			string parentwin=GetUserData(panelname, "", "GRAPHNAME")
			variable edit_flag=str2num(GetUserData(parentwin, "", "ROI_EDIT_MODE"))
			
			string imgwave=GetUserData(parentwin, "", "IMAGEWAVE")
			wave imgw=$imgwave
			string imginfo=note(imgw)
			
			string axis=AxisList(parentwin)
			string yaxis=StringFromList(0, axis)
			string xaxis=StringFromList(1, axis)
			string xaxistype=StringByKey("AXTYPE", AxisINfo(parentwin, xaxis))
			string yaxistype=StringByKey("AXTYPE", AxisInfo(parentwin, yaxis))			
			string exec_cmd=""
			string roi_tracename=NameOfWave(imgw)+"_ROI"
			string roi_tracenamelist=StringByKey("ROITRACE", imginfo, "=", "\n", 0)
			variable roi_tracename_lastidx=str2num(StringFromList(ItemsInList(roi_tracenamelist)-1, roi_tracenamelist))
			
			if(numtype(roi_tracename_lastidx)!=0)
				roi_tracename_lastidx=0
			else
				roi_tracename_lastidx+=1
			endif
				
			if(numtype(edit_flag)!=0)
				edit_flag=0
			endif
			
			if(edit_flag==0)					
				exec_cmd="GraphWaveDraw /W="+parentwin+" /O "
				
				strswitch(yaxistype)
				case "left":
					exec_cmd+="/L="+yaxis+" "
					break
				case "right":
					exec_cmd+="/R="+yaxis+" "
					break
				endswitch
				
				strswitch(xaxistype)
				case "top":
					exec_cmd+="/T="+xaxis+" "
					break
				case "bottom":
					exec_cmd+="/B="+xaxis+" "
					break
				endswitch
				
				exec_cmd+=roi_tracename+"_Y"+num2istr(roi_tracename_lastidx)+", "+roi_tracename+"_X"+num2istr(roi_tracename_lastidx)
				Execute exec_cmd
				SetWindow $parentwin, userdata(ROI_EDIT_MODE)="1"
				Button roi_new, win=$panelname, title="Confirm ROI",fColor=(65535,0,0), disable=0
				Button roi_edit, win=$panelname, disable=2
				Button roi_del, win=$panelname, disable=2
			else//see if there is actually a new ROI created				
				GraphNormal /W=$parentwin
				SetWindow $parentwin, userdata(ROI_EDIT_MODE)="0"
				Button roi_new, win=$panelname, title="New ROI", fColor=(0,0,0)
				Button roi_edit, win=$panelname, disable=0
				Button roi_del, win=$panelname, disable=0
				DoUpdate
				string tracelist=TraceNameList(parentwin, ";", 1)
				variable i	
				
				for(i=0; i<ItemsInList(tracelist); i+=1)
					if(stringmatch(StringFromList(i, tracelist, ";"), roi_tracename+"_Y"+num2istr(roi_tracename_lastidx))==1)
						i=inf
						break
					endif
				endfor
				if(numtype(i)!=0)
					//there is a match in trace, meaning new ROI is created
					string updated_roilist=""
					for(i=0; i<=roi_tracename_lastidx; i+=1)
						wave testw1=$(roi_tracename+"_Y"+num2istr(i))
						wave testw2=$(roi_tracename+"_X"+num2istr(i))
						
						if(WaveExists(testw1) && WaveExists(testw2) && (i==roi_tracename_lastidx || FindListItem(num2istr(i), roi_tracenamelist)!=-1))
							updated_roilist=AddListItem(num2istr(i), updated_roilist, ";", inf)
						endif
					endfor
					
					imginfo=ReplaceStringByKey("ROITRACE", imginfo, updated_roilist, "=", "\n", 0)
					note /k imgw, imginfo
					updated_roilist="\"all;"+updated_roilist+"\""
					PopupMenu roi_list, win=$panelname, value=#updated_roilist					
				endif
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function QIPanel_RefreshFile(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			string panelname=ba.win
			QIPanel_ReloadFrameAction(panelname, refresh=1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function QIPanel_ROIEdit(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			string panelname=ba.win
			string parentwin=GetUserData(panelname, "", "GRAPHNAME")
			variable edit_flag=str2num(GetUserData(parentwin, "", "ROI_EDIT_MODE"))
			
			string imgwave=GetUserData(parentwin, "", "IMAGEWAVE")
			wave imgw=$imgwave
			string imginfo=note(imgw)
			
			string axis=AxisList(parentwin)
			string yaxis=StringFromList(0, axis)
			string xaxis=StringFromList(1, axis)
			string xaxistype=StringByKey("AXTYPE", AxisINfo(parentwin, xaxis))
			string yaxistype=StringByKey("AXTYPE", AxisInfo(parentwin, yaxis))			
			string exec_cmd=""
			
			string roi_tracename=NameOfWave(imgw)+"_ROI"
			
			string roi_tracenamelist=StringByKey("ROITRACE", imginfo, "=", "\n", 0)

			if(numtype(edit_flag)!=0)
				edit_flag=0
			endif
			
			variable i
			string tracelist=TraceNameList(parentwin, ";", 1)
			
			if(edit_flag==0)	
				for(i=0; i<ItemsInList(roi_tracenamelist); i+=1)
					variable traceidx=WhichListItem(roi_tracename+"_Y"+StringFromList(i, roi_tracenamelist), tracelist)
					if(traceidx!=-1)
						Tag /W=$parentwin/C/N=$("ROI_"+StringFromList(i, roi_tracenamelist))/B=2 $(StringFromList(traceidx, tracelist)), 0, "\\Z05ROI_"+StringFromList(i, roi_tracenamelist)
					endif
				endfor
			
				GraphWaveEdit /W=$parentwin				
				SetWindow $parentwin, userdata(ROI_EDIT_MODE)="1"
				Button roi_new, win=$panelname, disable=2
				Button roi_edit, win=$panelname, title="Confirm ROI",fColor=(65535,0,0)
				Button roi_del, win=$panelname, disable=2
			else	
				GraphNormal /W=$parentwin
				SetWindow $parentwin, userdata(ROI_EDIT_MODE)="0"
				Button roi_new, win=$panelname, disable=0 
				Button roi_edit, win=$panelname, title="Edit ROI", fColor=(0,0,0)
				Button roi_del, win=$panelname, disable=0
				for(i=0; i<ItemsInList(roi_tracenamelist); i+=1)
					Tag /W=$parentwin/K/N=$("ROI_"+StringFromList(i, roi_tracenamelist))
				endfor
				DoUpdate
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function QIPanel_ROIDelete(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			string panelname=ba.win
			string parentwin=GetUserData(panelname, "", "GRAPHNAME")
			variable edit_flag=str2num(GetUserData(parentwin, "", "ROI_EDIT_MODE"))
			
			string imgwave=GetUserData(parentwin, "", "IMAGEWAVE")
			wave imgw=$imgwave
			string imginfo=note(imgw)
			
			string axis=AxisList(parentwin)
			string yaxis=StringFromList(0, axis)
			string xaxis=StringFromList(1, axis)
			string xaxistype=StringByKey("AXTYPE", AxisINfo(parentwin, xaxis))
			string yaxistype=StringByKey("AXTYPE", AxisInfo(parentwin, yaxis))			
			string exec_cmd=""
			
			string roi_tracename=NameOfWave(imgw)+"_ROI"
			string roi_tracenamelist=StringByKey("ROITRACE", imginfo, "=", "\n", 0)

				
			if(numtype(edit_flag)!=0)
				edit_flag=0
			endif
			
			if(edit_flag==0)	
				ControlInfo /W=$panelname roi_list
				if(V_value>0 && strlen(S_value)>0)
					variable starti=V_value-2
					variable endi=V_value-2
					if(starti<0)
						starti=0
						endi=ItemsInList(roi_tracenamelist)-1
					endif
					variable i
					for(i=starti; i<=endi; i+=1)
						RemoveFromGraph /W=$parentwin /Z $(roi_tracename+"_Y"+StringFromList(i, roi_tracenamelist))
						DoUpdate
						KillWaves /Z $(roi_tracename+"_Y"+StringFromList(i, roi_tracenamelist))
						KillWaves /Z $(roi_tracename+"_X"+StringFromList(i, roi_tracenamelist))
						//print "list:", i, roi_tracenamelist
					endfor
					if(endi==starti)
						roi_tracenamelist=RemoveListItem(starti, roi_tracenamelist)
					else
						roi_tracenamelist=""
					endif
					
					imginfo=ReplaceStringByKey("ROITRACE", imginfo, roi_tracenamelist, "=", "\n", 0)
					note /k imgw, imginfo
					if(ItemsInList(roi_tracenamelist)>0)
						roi_tracenamelist="\"all;"+roi_tracenamelist+"\""
					else
						roi_tracenamelist="\"\""
					endif
					PopupMenu roi_list, win=$panelname, value=#roi_tracenamelist
				endif
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function QIF_lineprofile(wave img, variable chn, variable slice, variable frame, wave roix, wave roiy, variable width)

	ImageLineProfile /S/SC xWave=roix, yWave=roiy, srcwave=img, width=width

end