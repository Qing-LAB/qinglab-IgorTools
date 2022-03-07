#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <ImageSlider>
#include <WMBatchCurveFitIM>

static Structure TIFFTagInfo
	int32 width
	int32 height
	int32 total_image_number
	int32 total_color_number
	int32 total_slice_number
	int32 total_time_frames
	
	double x_resolution
	double y_resolution
	double t_interval
	uchar xy_unit[16]
	uchar t_unit[16]
	
	int32 load_flag
	int32 loaded_idx[4]
	int32 loaded_channels[4]
	int32 loaded_slice
	int32 loaded_frame
EndStructure

static Structure ChannelInfo
	int32 channel_r
	int32 channel_g
	int32 channel_b
	int32 channel_single
	int32 slice
	int32 time_frame
	uchar dim_order[8]
EndStructure

function /T QITiffTagInfo(wave /T tagwave, STRUCT TiffTagInfo &taginfo)	
	String infostr=""
	variable i
	
	tagInfo.width=0
	tagInfo.height=0
	tagInfo.x_resolution=1
	tagInfo.y_resolution=1
	
	for(i=0; i<DimSize(tagwave, 0); i+=1)
		strswitch(tagwave[i][0])
			case "256": //IMAGEWIDTH
				tagInfo.width=str2num(tagwave[i][4])
				break
			case "257": //IMAGELENGTH
				tagInfo.height=str2num(tagwave[i][4])
				break
			case "270": //IMAGEDESCRIPTION
				infostr+=tagwave[i][4]+"\n"
				break
			case "282": //XRESOLUTION
				tagInfo.x_resolution=str2num(tagwave[i][4])
				break
			case "283": //YRESOLUTION
				tagInfo.y_resolution=str2num(tagwave[i][4])
				break		
		endswitch
	endfor
	
	variable tmpnum
	
	tmpnum=str2num(StringByKey("images", infostr, "=", "\n", 0))
	if(numtype(tmpnum)!=0 || tmpnum<=0)
		tagInfo.total_image_number=0
	else
		tagInfo.total_image_number=tmpnum
	endif
	
	tmpnum=str2num(StringByKey("channels", infostr, "=", "\n", 0))
	if(numtype(tmpnum)!=0 || tmpnum<=0)
		tagInfo.total_color_number=1
	else
		tagInfo.total_color_number=tmpnum
	endif
	
	tmpnum=str2num(StringByKey("slices", infostr, "=", "\n", 0))
	if(numtype(tmpnum)!=0 || tmpnum<=0)
		tagInfo.total_slice_number=1
	else
		tagInfo.total_slice_number=tmpnum
	endif
	
	tmpnum=str2num(StringByKey("frames", infostr, "=", "\n", 0))
	if(numtype(tmpnum)!=0 || tmpnum<=0)
		tagInfo.total_time_frames=tagInfo.total_image_number/tagInfo.total_color_number/tagInfo.total_slice_number
	else
		tagInfo.total_time_frames=tmpnum
	endif
	
	tmpnum=str2num(StringByKey("finterval", infostr, "=", "\n", 0))
	if(numtype(tmpnum)!=0 || tmpnum<=0)
		tagInfo.t_interval=1
	else
		tagInfo.t_interval=tmpnum
	endif
	
	tagInfo.xy_unit=StringByKey("unit", infostr, "=", "\n", 0)
	tagInfo.t_unit=StringByKey("time_unit", infostr, "=", "\n", 0)
	
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

StrConstant QIMAGEWAVEVERSION="1.0"

function QILoadTiffByIdx(string frameWaveName, int idx, [variable refresh_tag_flag, variable load_data_flag, STRUCT ChannelInfo &Channels])
	Variable refNum
	Variable retVal=-1
	string img_loaded_idx="", compareidx=""
	string imageInfoStr=""
	
	if(ParamIsDefault(refresh_tag_flag))
		refresh_tag_flag=1
	endif
	
	if(ParamIsDefault(load_data_flag))
		load_data_flag=1
	endif
	
	if(WaveExists($frameWaveName))
		imageInfoStr=note($frameWaveName)
		if(strlen(StringByKey("QIMAGEWAVEVER", imageInfoStr, "=", "\n", 0))==0)
			refresh_tag_flag=1
		endif
	else
		refresh_tag_flag=1
	endif
	
	string absolutePath=StringByKey("FILE", imageInfoStr, "=", "\n", 0)
	string relativePath=StringByKey("RELATIVEPATH", imageInfoStr, "=", "\n", 0)
	STRUCT TiffTagInfo taginfo
	string taginfostr=""
	
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
			imageInfoStr=ReplaceStringByKey("QIMAGEWAVEVER", imageInfoStr, QIMAGEWAVEVERSION, "=", "\n", 0)
			imageInfoStr=ReplaceStringByKey("FILE", imageInfoStr, absolutePath, "=", "\n", 0)
			imageInfoStr=ReplaceStringByKey("RELATIVEPATH", imageInfoStr, relativePath, "=", "\n", 0)
		endif
	endif
	
	if(strlen(absolutePath)==0)
		return -1
	endif
	
	variable total_frames=-1
	
	DFREF dfr=GetDataFolderDFR()
	KillWaves /Z :QITMPIMG_TAG, :QITMPIMG_IMG, :QITMPIMG_IMG_RAW; AbortOnRTE
	NewDataFolder/O/S QIImgTmp; AbortOnRTE
	
	try
		if(refresh_tag_flag==1)
			ImageLoad/T=tiff/Q/RTIO absolutePath; AbortOnRTE
			total_frames=V_numImages
			
			if(V_Flag==1)
				QITiffTagInfo(:Tag0:T_Tags, taginfo)
				StructPut /S taginfo, taginfostr
				MoveWave :Tag0:T_Tags, dfr:QITMPIMG_TAG; AbortOnRTE
				retVal=0
			else
				retVal=-1;
			endif
		else
			taginfostr=StringByKey("TAGINFO", imageInfoStr, "=", "\n", 0)
			StructGet /S tagInfo, taginfostr
			retVal=0
		endif
		AbortOnValue retVal==-1, -100
				
		variable ridx=-1, gidx=-1, bidx=-1
		
		if(!ParamIsDefault(Channels))
			idx=-1
			variable chn_r=Channels.channel_r
			variable chn_g=Channels.channel_g
			variable chn_b=Channels.channel_b
			variable chn_single=Channels.channel_single
			variable zidx=Channels.slice
			variable tidx=Channels.time_frame
			string dimorder=Channels.dim_order
			
			if(chn_single>=0)
				idx=QIGetIdxByChn(chn_single, zidx, tidx, dimorder, tagInfo)
				
				taginfo.load_flag=1
				taginfo.loaded_idx[0]=-1
				taginfo.loaded_idx[1]=-1
				taginfo.loaded_idx[2]=-1
				taginfo.loaded_idx[3]=idx
				taginfo.loaded_channels[0]=-1
				taginfo.loaded_channels[1]=-1
				taginfo.loaded_channels[2]=-1
				taginfo.loaded_channels[3]=chn_single
				taginfo.loaded_slice=zidx
				taginfo.loaded_frame=tidx
			else
				ridx=QIGetIdxByChn(chn_r, zidx, tidx, dimorder, tagInfo)
				gidx=QIGetIdxByChn(chn_g, zidx, tidx, dimorder, tagInfo)
				bidx=QIGetIdxByChn(chn_b, zidx, tidx, dimorder, tagInfo)
				
				taginfo.load_flag=2
				taginfo.loaded_idx[0]=ridx
				taginfo.loaded_idx[1]=gidx
				taginfo.loaded_idx[2]=gidx
				taginfo.loaded_idx[3]=-1
				taginfo.loaded_channels[0]=chn_r
				taginfo.loaded_channels[1]=chn_g
				taginfo.loaded_channels[2]=chn_b
				taginfo.loaded_channels[3]=-1
				taginfo.loaded_slice=zidx
				taginfo.loaded_frame=tidx
			endif
		else
			taginfo.load_flag=0
			taginfo.loaded_idx[0]=-1
			taginfo.loaded_idx[1]=-1
			taginfo.loaded_idx[2]=-1
			taginfo.loaded_idx[3]=idx
			taginfo.loaded_channels[0]=-1
			taginfo.loaded_channels[1]=-1
			taginfo.loaded_channels[2]=-1
			taginfo.loaded_channels[3]=0
			taginfo.loaded_slice=-1
			taginfo.loaded_frame=-1
		endif
		
		StructPut /S taginfo, taginfostr
		
		if(cmpstr(taginfostr, StringByKey("TAGINFO", imageInfoStr, "=", "\n", 0))!=0)
		//requested is not the same as loaded data, or force loading data
			load_data_flag=1
		endif
		
		if(load_data_flag==1) 
			variable maxx, maxy
			
			maxx=taginfo.width
			maxy=taginfo.height
			
			if(numtype(maxx)!=0 || maxx<=0 || numtype(maxy)!=0 || maxy<0)
				retVal=-3
			else
				Variable wtype=0x10
				
				if(idx>=0)					
					ImageLoad/T=tiff/Q/C=1/S=(idx)/BIGT=1/N=tmpImg_Raw/O absolutePath; AbortOnRTE
					Wave tmpImg_Raw
					wtype=WaveType(tmpImg_Raw)
					
					MatrixOP /O/NPRM tmpImg=tmpImg_Raw; AbortOnRTE
				else
					
					if(ridx>=0)
						ImageLoad/T=tiff/Q/C=1/S=(ridx)/BIGT=1/N=tmpImg_R/O absolutePath; AbortOnRTE
						wtype=WaveType(:tmpImg_R)
					else
						Make /O/N=(maxx, maxy)/Y=0x10 :tmpImg_R=0; AbortOnRTE
					endif
					
					if(gidx>=0)
						if(gidx==ridx)
							Duplicate /O :tmpImg_R, :tmpImg_G						
						else
							ImageLoad/T=tiff/Q/C=1/S=(gidx)/BIGT=1/N=tmpImg_G/O absolutePath; AbortOnRTE
						endif
						wtype=WaveType(:tmpImg_G)
					else
						Make /O/N=(maxx, maxy)/Y=0x10 :tmpImg_G=0; AbortOnRTE
					endif
					
					if(bidx>=0)
						if(bidx==ridx)
							Duplicate /O :tmpImg_R, :tmpImg_B; AbortOnRTE
						elseif(bidx==gidx)
							Duplicate /O :tmpImg_G, :tmpImg_B; AbortOnRTE
						else
							ImageLoad/T=tiff/Q/C=1/S=(bidx)/BIGT=1/N=tmpImg_B/O absolutePath; AbortOnRTE
						endif
						wtype=WaveType(:tmpImg_B)
					else
						Make /O/N=(maxx, maxy)/Y=0x10 :tmpImg_B=0; AbortOnRTE
					endif
					
					Wave tmpImg_R, tmpImg_G, tmpImg_B
					MatrixOp /O tmpImg_R_Adj=scale(tmpImg_R, 0, 65535); AbortOnRTE
					MatrixOp /O tmpImg_G_Adj=scale(tmpImg_G, 0, 65535); AbortOnRTE
					MatrixOp /O tmpImg_B_Adj=scale(tmpImg_B, 0, 65535); AbortOnRTE
					
					Concatenate /O {tmpImg_R, tmpImg_G, tmpImg_B}, tmpImg_Raw; AbortOnRTE
					Concatenate /O {tmpImg_R_Adj, tmpImg_G_Adj, tmpImg_B_Adj}, tmpImg; AbortOnRTE
				endif
				
				MoveWave tmpImg, dfr:QITMPIMG_IMG; AbortOnRTE
				MoveWave tmpImg_Raw, dfr:QITMPIMG_IMG_RAW; AbortOnRTE
				retVal=0
				imageInfoStr=ReplaceStringByKey("TAGINFO", imageInfoStr, taginfostr, "=", "\n", 0)
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
			Duplicate /O dfr:QITMPIMG_TAG, $(frameWaveName+"_Tag"); AbortOnRTE
		endif
		
		if(load_data_flag==1)
			Duplicate /O dfr:QITMPIMG_IMG_RAW, $(frameWaveName+"_Raw")	; AbortOnRTE
			wave w_raw=$(frameWaveName+"_Raw")
			
			Duplicate /O dfr:QITMPIMG_IMG, $(frameWaveName)
			wave w_img=$(frameWaveName)
			
			variable xres=taginfo.x_resolution
			variable yres=taginfo.y_resolution
			string unit=taginfo.xy_unit
			
			if(numtype(xres)!=0)
				xres=1
			endif
			if(numtype(yres)!=0)
				yres=1
			endif
			SetScale/P x 0,1/xres, unit, w_img, w_raw; AbortOnRTE
			SetScale/P y 0,1/yres, unit, w_img, w_raw; AbortOnRTE
			
			note /k w_img, imageInfoStr; AbortOnRTE
			note /k w_raw, imageInfoStr; AbortOnRTE
		endif
		
		KillWaves /Z dfr:QITMPIMG_TAG, dfr:QITMPIMG_IMG, dfr:QITMPIMG_IMG_RAW; AbortOnRTE
	endif
	
	return retVal
end

function QIGetIdxByChn(int ColorChn, int ZIdx, int TimeIdx, String DimOrder, STRUCT TiffTagInfo &taginfo)
	variable totalColorChn= taginfo.total_color_number
	variable totalIdx= taginfo.total_image_number
	variable totalZ= taginfo.total_slice_number
	variable totalTimeIdx= taginfo.total_time_frames
	
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

function QILoadTiffByChn(string frameWaveName, int single_color_channel, int r, int g, int b, int ZIdx, int TimeIdx, int refresh_tag_flag, [string DimOrder, string absolutePath, STRUCT TiffTagInfo & taginfo, string saveaswave])
	variable retVal=-1
	
	if(ParamIsDefault(DimOrder))
		DimOrder="XYCZT"
	else
		DimOrder=UpperStr(DimOrder)
	endif
	
	if(ParamIsDefault(saveaswave))
		STRUCT ChannelInfo channels
		channels.channel_r=r
		channels.channel_g=g
		channels.channel_b=b
		channels.channel_single=single_color_channel
		channels.slice=ZIdx
		channels.time_frame=TimeIdx
		channels.dim_order=DimOrder
		
		retVal=QILoadTiffByIdx(frameWaveName, -1, refresh_tag_flag=refresh_tag_flag, Channels=channels)
	else
		try
			if(!ParamIsDefault(taginfo) && !ParamIsDefault(absolutePath))
				if(single_color_channel>=0)
					variable single_idx=QIGetIdxByChn(single_color_channel, ZIdx, TimeIdx, DimOrder, taginfo)
					if(single_idx>=0)
						ImageLoad/T=tiff/Q/C=1/S=(single_idx)/BIGT=1/N=$saveaswave/O absolutePath
						retVal=(V_flag==1)?0:-1
					endif
				else
					Make /FREE/N=3 idx_rgb
					idx_rgb[0]=QIGetIdxByChn(r, ZIdx, TimeIdx, DimOrder, taginfo)
					idx_rgb[1]=QIGetIdxByChn(g, ZIdx, TimeIdx, DimOrder, taginfo)
					idx_rgb[2]=QIGetIdxByChn(b, ZIdx, TimeIdx, DimOrder, taginfo)
					variable i, count=0
					for(i=0; i<3; i+=1)
						if(idx_rgb[i]>=0)
							variable separate_chn_idx=QIGetIdxByChn(idx_rgb[i], ZIdx, TimeIdx, DimOrder, taginfo)
							if(separate_chn_idx>=0)
								ImageLoad/T=tiff/Q/C=1/S=(separate_chn_idx)/BIGT=1/N=$saveaswave/O absolutePath
								if(V_Flag==1)
									wave w=$saveaswave
									if(count==0)
										Duplicate /FREE w, tmp_Img
									else
										Concatenate {$saveaswave}, tmp_Img
									endif
									count+=1
								endif
							endif
						endif
					endfor
					if(count>0)
						Duplicate /O tmp_Img, $saveaswave
					endif
				endif
			else
				print "when use QILoadTiffByChn to save a wave, you must explicitly provide the taginfo struct and absolute path of the file in parameters."
			endif
		catch
		endtry
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
	
	if(cmpstr(StringByKey("QIMAGEWAVEVER", imginfo, "=", "\n", 0), QIMAGEWAVEVERSION)!=0)
		print "the graph does not have the right QImageWave information for loading the data and panel correctly."
		return -1
	endif
	
	string taginfostr=StringByKey("TAGINFO", imginfo, "=", "\n", 0)
	STRUCT TiffTagInfo taginfo
	StructGet /S taginfo, taginfostr
	
	variable totalColorChn=taginfo.total_color_number
	variable totalIdx=taginfo.total_image_number 
	variable totalZ=taginfo.total_slice_number
	variable totalTimeIdx=taginfo.total_time_frames
	
	variable current_singlechn=taginfo.loaded_channels[3]
	variable current_chn_r=taginfo.loaded_channels[0]
	variable current_chn_g=taginfo.loaded_channels[1]
	variable current_chn_b=taginfo.loaded_channels[2]
	variable load_flag=taginfo.load_flag
	
	if(load_flag<1 || load_flag>2)
		load_flag=1
	endif
	
	variable current_zidx=taginfo.loaded_slice
	variable current_timeidx=taginfo.loaded_frame
	
	if(refresh==1)
		current_singlechn=0
		current_chn_r=-1
		current_chn_g=-1
		current_chn_b=-1
		
		current_zidx=0
		current_timeidx=0
		load_flag=1
	endif
	
	if(strlen(GetUserData(graphName, "", "QIPANEL"))==0)
		ModifyGraph /W=$graphName width={Aspect,(DimDelta(img, 0)*DimSize(img, 0))/(DimDelta(img, 1)*DimSize(img, 1))}
		//QILoadTiffByChn(GetWavesDataFolder(img, 2), current_singlechn, current_chn_r, current_chn_g, current_chn_b, current_zidx, current_timeidx, refresh)
		DoUpdate
		imginfo=note(img)
		string roi_tracelist=StringByKey("ROITRACE", imginfo, "=", "\n", 0)
		if(strlen(roi_tracelist)==0)
			roi_tracelist=";"
		endif
		NewPanel /Ext=0 /HOST=$graphName	/N=$(graphName+"QIPanel") /W=(0, 0, 200, 400)
		SetWindow $S_name, userdata(GRAPHNAME)=graphName
		String panelname=S_name
		SetWindow $graphName, userdata(QIPANEL)=panelname
		SetWindow $graphName, userdata(IMAGEWAVE)=GetWavesDataFolder(img, 2)
		SetWindow $graphName, hook(QIPanel_MouseFunc)=QIPanel_MouseFunc
		
		TitleBox cords, title="Px=?, Py=?\nx=?, y=?", size={150, 40}, pos={0, 0}
		Button refresh, title="Refresh/Reload File", size={150, 20}, pos={0, 40}, proc=QIPanel_RefreshFile
		
		TabControl channel_select value=(load_flag-1),tabLabel(0)="Single",tabLabel(1)="RGB", size={200, 140}, pos={0, 60}, proc=QIPanel_ChannelTab
		Button channel_setting, title="@", size={20, 20}, pos={5, 90}
		SetVariable channel, limits={-1, totalColorChn, 1}, live=1, value=_NUM:current_singlechn, title="Chn#", format="%d/"+num2istr(totalColorChn-1), size={150, 20}, pos={25, 90}, proc=QIPanel_ReloadFrame
		Button channel_setting_r, title="@", size={20, 20}, pos={5, 90}, disable=1
		SetVariable channel_r, limits={-1, totalColorChn, 1}, live=1, value=_NUM:current_chn_r, title="Chn_R#", format="%d/"+num2istr(totalColorChn-1), size={150, 20}, pos={25, 90}, disable=1, proc=QIPanel_ReloadFrame
		Button channel_setting_g, title="@", size={20, 20}, pos={5, 110}, disable=1
		SetVariable channel_g, limits={-1, totalColorChn, 1}, live=1, value=_NUM:current_chn_g, title="Chn_G#", format="%d/"+num2istr(totalColorChn-1), size={150, 20}, pos={25, 110}, disable=1, proc=QIPanel_ReloadFrame
		Button channel_setting_b, title="@", size={20, 20}, pos={5, 130}, disable=1
		SetVariable channel_b, limits={-1, totalColorChn, 1}, live=1, value=_NUM:current_chn_b, title="Chn_B#", format="%d/"+num2istr(totalColorChn-1), size={150, 20}, pos={25, 130}, disable=1, proc=QIPanel_ReloadFrame		

		SetVariable slice, limits={-1, totalZ, 1}, live=1, value=_NUM:current_zidx, title="slice#", format="%d / "+num2istr(totalZ-1), size={150, 20}, pos={10, 150}, proc=QIPanel_ReloadFrame
		SetVariable frame, limits={-1, totalTimeIdx, 1}, live=1, value=_NUM:current_timeidx, title="time#", format="%d / "+num2istr(totalTimeIdx-1), pos={10, 170}, size={150, 20}, proc=QIPanel_ReloadFrame
		
		GroupBox roi_op, title="ROI Definition", pos={0, 200}, size={200, 70}
		Button roi_new, title="New ROI", size={90,20}, pos={5, 220}, proc=QIPanel_ROINew
		Button roi_edit, title="Edit ROI", size={90, 20}, pos={95, 220}, proc=QIPanel_ROIEdit
		PopupMenu roi_list, size={90,20}, title="ROI#", pos={5, 240}, value=#roi_tracelist
		Button roi_del, title="Delete ROI", size={90,20}, pos={95, 240}, proc=QIPanel_ROIDelete
		
		GroupBox user_functions, title="User Functions", size={200, 100}, pos={0, 280}
		string userfunc_type="WIN:Procedure;KIND:2;NPARAMS:7"
		Button call_userfunc1, size={40, 20}, title="call", pos={5, 300}
		PopupMenu call_type, value="--;@1;@*;", size={50, 20}, pos={50, 300} 
		PopupMenu userfunc_list1, size={100, 20}, pos={95, 300}, value=FunctionList("QIF_*", ";", "")
		
		QIPanel_ReloadFrameAction(panelname, refresh=refresh)
	endif
end

Function QIPanel_ChannelTab(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			QIPanel_ReloadFrameAction(tca.win)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function QIPanel_ReloadFrameAction(string panelname, [variable refresh])
	string parentwin=GetUserData(panelname, "", "GRAPHNAME")
	string fw=GetUserData(parentwin, "", "IMAGEWAVE")
	string imginfo=note($fw)
	string taginfostr=StringByKey("TAGINFO", imginfo, "=", "\n", 0)
	STRUCT TiffTagInfo taginfo
	
	StructGet /S taginfo, taginfostr
	
	variable totalColorChn=taginfo.total_color_number
	variable totalTimeIdx=taginfo.total_time_frames
	variable totalZ=taginfo.total_slice_number
	variable totalIdx=taginfo.total_image_number
	
	
	ControlInfo /W=$panelname channel_select
	Variable single_or_color=V_Value
	
	ControlInfo /W=$panelname channel
	Variable channel=V_Value
	
	ControlInfo /W=$panelname channel_r
	Variable channel_r=V_Value
	
	ControlInfo /W=$panelname channel_g
	Variable channel_g=V_Value
	
	ControlInfo /W=$panelname channel_b
	Variable channel_b=V_Value
		
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
		
	if(channel_r>=totalColorChn)
		channel_r=0
	endif
	
	if(channel_r<0)
		channel_r=-1
	endif
	
	if(channel_g>=totalColorChn)
		channel_g=0
	endif
	
	if(channel_g<0)
		channel_g=-1
	endif
	
	if(channel_b>=totalColorChn)
		channel_b=0
	endif
	
	if(channel_b<0)
		channel_b=-1
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
	
	if(single_or_color==1)
		Button channel_setting, win=$panelname, disable=1
		SetVariable channel, win=$panelname, disable=1
		Button channel_setting_r, win=$panelname, disable=0
		SetVariable channel_r, win=$panelname, disable=0
		Button channel_setting_g, win=$panelname, disable=0
		SetVariable channel_g, win=$panelname, disable=0
		Button channel_setting_b, win=$panelname, disable=0
		SetVariable channel_b, win=$panelname, disable=0
	else
		Button channel_setting, win=$panelname, disable=0
		SetVariable channel, win=$panelname, disable=0
		Button channel_setting_r, win=$panelname, disable=1
		SetVariable channel_r, win=$panelname, disable=1
		Button channel_setting_g, win=$panelname, disable=1
		SetVariable channel_g, win=$panelname, disable=1
		Button channel_setting_b, win=$panelname, disable=1
		SetVariable channel_b, win=$panelname, disable=1
	endif
			
	SetVariable channel, win=$panelname, value=_NUM:channel
	SetVariable channel_r, win=$panelname, value=_NUM:channel_r
	SetVariable channel_g, win=$panelname, value=_NUM:channel_g
	SetVariable channel_b, win=$panelname, value=_NUM:channel_b
	SetVariable slice, win=$panelname, value=_NUM:slice
	SetVariable frame, win=$panelname, value=_NUM:frame
	
	if(ParamIsDefault(refresh))
		refresh=0
	else
		refresh=1
	endif
	
	if(single_or_color==0)
		QILoadTiffByChn(fw, channel, -1, -1, -1, slice, frame, refresh)
	else
		QILoadTiffByChn(fw, -1, channel_r, channel_g, channel_b, slice, frame, refresh)
	endif
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

function QIGetLineProfile()
end

function QIF_lineprofile(wave img, variable chn, variable slice, variable frame, wave roix, wave roiy, variable width)

	String winfo=note(img)
	String taginfostr=StringByKey("TAGINFO", winfo, "=", "\n", 0)
	String absolutePath=StringByKey("FILE", winfo, "=", "\n", 0)
	STRUCT TiffTagInfo taginfo
	StructGet /S taginfo, taginfostr
	
	QILoadTiffByChn(NameOfWave(img), 0, -1, -1, -1, 0, 0, 0, absolutePath=absolutePath, taginfo=taginfo, saveaswave="test1") 
	QILoadTiffByChn(NameOfWave(img), -1, 0, 1, -1, 0, 0, 0, absolutePath=absolutePath, taginfo=taginfo, saveaswave="test2")
end