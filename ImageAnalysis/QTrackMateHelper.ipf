#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "WaveBrowser"

Menu "QTools"
	SubMenu "QTrackMateHelper"
		"Load TrackMate CSV file", QTM_load_track_file()
		"Analyze TrackMate Data", QTM_Analyze_TMData()
		"Plot Frame XY", QTM_Select_Frame()
		"Generate Histogram", QTM_Generate_Histogram()
		"Summarize All data in Frame Data Folder", QTM_Choose_FrameDF()
		"Extract value from track by frames", QTM_Choose_TrackDF()
	End
End

function QTM_load_track_file()
	Variable refNum

	Variable f
	String msgstr="Please select all files from TrackMate analysis."
	Open /MULT=1 /D /R /F="Data Files (*.txt,*.dat,*.csv):.txt,.dat,.csv;" /M=msgstr refNum
	String folderName=UniqueName("TrackMateData", 11, 0)
	
	String fullPath = S_fileName
	DFREF dfr=GetDataFolderDFR()
	try
		if(strlen(fullPath)>0)
			NewDataFolder /O/S $folderName
			Variable selected=ItemsInList(fullPath, "\r")
			Variable i, j
			DoAlert /T="SELECT THE RIGHT COLUMNS" 0, "Please make sure to select TRACK_ID column from Edge CSV file. Please only select columns that's going to be used, including ID, FRAME, POSITION_X, POSITION_Y, TRACI_ID, SPOT_SOURCE_ID, SPOT_TARGET_ID, and intensity data that you may need."
			
			for(i=0; i<selected; i+=1)
				String path=StringFromList(i, fullPath, "\r")
				print "Loading ", path
				LoadWave /Q/J/W/L={0, 4, 0, 0, 0}/K=0 /D /O path
				print "Loaded waves:", S_waveNames
				
				for(j=0; j<ItemsInList(S_waveNames); j+=1)
					wave w=$StringFromList(j, S_waveNames)
					note /k w, path
				endfor
			endfor
			
			String wlist=WaveList("*", ";", "")
			for(i=0; i<ItemsInList(wlist); i+=1)
				
			endfor
		else
			print "Cancelled."
		endif
	catch
		Variable err=GetRTError(1)
		if(err!=0)
			print "Error when loading file:", GetErrMessage(err)
		endif
	endtry
	SetDataFolder dfr
end

function QTM_Analyze_TMData()
	String dataFolderList=StringByKey("FOLDERS", DataFolderDir(1))
	dataFolderList=ReplaceString(",", dataFolderList, ";")
	String selectedFolder=StringFromList(0, dataFolderList)
	PROMPT selectedFolder, "Please select the DataFolder that contains TrackMate Data.", popup dataFolderList

	DoPROMPT "Select Data Folder", selectedFolder
	if(V_flag==0)
		print "Will analyze ", selectedFolder
		String WList=StringByKey("WAVES", DataFolderDir(2, $selectedFolder))
		WList=ReplaceString(",", WList, ";")
		
		String idw_str, trkid_str, frame_str, posx_str, posy_str, spotsrc_str, spottarget_str
		if(FindListItem("ID", WList)>=0)
			idw_str="ID"
		else
			idw_str=""
		endif
		
		if(FindListItem("TRACK_ID", WList)>=0)
			trkid_str="TRACK_ID"
		else
			trkid_str=""
		endif
		
		if(FindListItem("FRAME", WList)>=0)
			frame_str="FRAME"
		else
			frame_str=""
		endif
		
		if(FindListItem("FRAME", WList)>=0)
			frame_str="FRAME"
		else
			frame_str=""
		endif
		
		if(FindListItem("POSITION_X", WList)>=0)
			posx_str="POSITION_X"
		else
			posx_str=""
		endif
		
		if(FindListItem("POSITION_Y", WList)>=0)
			posy_str="POSITION_Y"
		else
			posy_str=""
		endif
		
		if(FindListItem("SPOT_SOURCE_ID", WList)>=0)
			spotsrc_str="SPOT_SOURCE_ID"
		else
			spotsrc_str=""
		endif
		
		if(FindListItem("SPOT_TARGET_ID", WList)>=0)
			spottarget_str="SPOT_TARGET_ID"
		else
			spottarget_str=""
		endif
		
		String additional_channel="", channelList=""
		
		variable avoid_frame_begin=0, avoid_frame_end=0, speed_frame_interval=1, time_interval=1
		
		PROMPT idw_str, "ID", popup WList
		PROMPT trkid_str, "TRACK_ID", popup WList
		PROMPT frame_str, "FRAME", popup WList
		PROMPT posx_str, "POSITION_X", popup WList
		PROMPT posy_str, "POSITION_Y", popup WList
		PROMPT spotsrc_str, "SPOT_SOURCE_ID", popup WList
		PROMPT spottarget_str, "SPOT_TARGET_ID", popup WList
		PROMPT additional_channel, "Additional waves to be included in tables (use ';' to separate them)"
		
		Variable ROI_diameter=50
		Variable Cell_diameter=25
		PROMPT ROI_diameter, "Diameter for ROI to calculate local density"
		PROMPT Cell_diameter, "Average cell diameter"
		PROMPT avoid_frame_begin, "Number of frames in the beginning of each track to ignore for the additional channels"
		PROMPT avoid_frame_end, "Number of frames in the end of each track to ignore for the additional channels"
		PROMPT speed_frame_interval, "Minimum Frame interval for calculating speed"
		PROMPT time_interval, "Time interval between frames"
		
		DoPROMPT "Please identify corresponding waves", idw_str, trkid_str, frame_str, posx_str, posy_str, spotsrc_str, spottarget_str, additional_channel
		if(V_flag!=0)
			print "Cancelled."
			return -1
		endif
		
		DoPROMPT "Please set parameters for analysis", ROI_diameter, cell_diameter, avoid_frame_begin, avoid_frame_end, speed_frame_interval, time_interval
		if(V_flag!=0)
			print "Cancelled."
			return -1
		endif
		
		Variable i
		for(i=0; i<ItemsInList(additional_channel); i+=1)
			//if(WaveExists($StringFromList(i, additional_channel)))
				channelList=AddListItem(StringFromList(i, additional_channel), channelList)
			//endif
		endfor
		
		DFREF dfr=GetDataFolderDFR()
		
		try
			SetDataFolder $selectedFolder
			
			WAVE TRACK_ID=$trkid_str
			WAVE POSITION_X=$posx_str
			WAVE POSITION_Y=$posy_str
			WAVE FRAME=$frame_str
			WAVE ID=$idw_str
			WAVE SPOT_SOURCE_ID=$spotsrc_str
			WAVE SPOT_TARGET_ID=$spottarget_str
			
			print "First generating the lookup table for the original tracks..."
			QTM_trackid_lookuptbl(TRACK_ID, POSITION_X, POSITION_Y, FRAME, ID, SPOT_SOURCE_ID, SPOT_TARGET_ID)
			print "Now will generate cell map for each frame..."
			QTM_generate_frame_map(channelList, ROI_diameter, Cell_diameter, FRAME, POSITION_X, POSITION_Y, ID)
			
			WAVE QTM_TRACK_TBL
			WAVE QTM_SPOT_SOURCE_ID
			WAVE QTM_SPOT_TARGET_ID
			
			channelList=AddListItem("QTM_DENSITY", channelList)
			print "Splitting the tracks based on branches..."
			QTM_Split_track(QTM_TRACK_TBL, TRACK_ID, ID, POSITION_X, POSITION_Y, FRAME, QTM_SPOT_SOURCE_ID, QTM_SPOT_TARGET_ID, \
								optionalList=channelList, avoid_frame_begin=avoid_frame_begin, \
								avoid_frame_end=avoid_frame_end, speed_frame_interval=speed_frame_interval, \
								time_interval=time_interval)
			print "All done."
		catch
			Variable err=GetRTError(1)
			if(err!=0)
				print "error during analysis:", GetErrMessage(err)
			endif
		endtry
		
		SetDataFolder dfr
		
	else
		print "Cancelled."
	endif
	
End

function QTM_Generate_Histogram()
	String BINWList=WaveList("*_HIST_BIN", ";", "")
	print "Found histogram bin waves as:", BINWList
	if(strlen(BINWList)==0)
		print "No bin waves are found. This needs to be set up first with names as *_HIST_BIN. quitting now."
		return -1
	endif
	
	String dataFolderList=StringByKey("FOLDERS", DataFolderDir(1))
	dataFolderList=ReplaceString(",", dataFolderList, ";")
	String selectedFolder=StringFromList(0, dataFolderList)
	PROMPT selectedFolder, "Please select the DataFolder that contains TrackMate and QTrackMateHelper analysis Data.", popup dataFolderList
	
	DoPROMPT "Select Data Folder", selectedFolder
	DFREF sel_df=$selectedFolder
	
	if(V_flag==0)
	
		DFREF dfr=GetDataFolderDFR()
		try
			print "Will generate histogram for ", selectedFolder
			String WList=StringByKey("WAVES", DataFolderDir(2, $selectedFolder))
			WList=ReplaceString(",", WList, ";")
			
			String frame_str, qtm_speed_str, qtm_density_str, frame_bin_str, speed_bin_str, density_bin_str
			if(FindListItem("FRAME", WList)>=0)
				frame_str="FRAME"
			else
				frame_str=""
			endif
			
			if(FindListItem("QTM_SPEED", WList)>=0)
				qtm_speed_str="QTM_SPEED"
			else
				qtm_speed_str=""
			endif
			
			if(FindListItem("QTM_DENSITY", WList)>=0)
				qtm_density_str="QTM_DENSITY"
			else
				qtm_density_str=""
			endif
			
			if(FindListItem("FRAME_HIST_BIN", BINWList)>=0)
				frame_bin_str="FRAME_HIST_BIN"
			else
				frame_bin_str=""
			endif
			
			if(FindListItem("SPEED_HIST_BIN", BINWList)>=0)
				speed_bin_str="SPEED_HIST_BIN"
			else
				speed_bin_str=""
			endif
			
			if(FindListItem("DENSITY_HIST_BIN", BINWList)>=0)
				density_bin_str="DENSITY_HIST_BIN"
			else
				density_bin_str=""
			endif
			
			PROMPT frame_str, "Frame # for each cell", popup WList
			PROMPT qtm_speed_str, "QTM_SPEED result for each cell", popup WList
			PROMPT qtm_density_str, "QTMP_DENSITY result for each cell", popup WList
			PROMPT frame_bin_str, "Histogram BIN setting for Frame", popup BINWList
			PROMPT speed_bin_str, "Histogram BIN setting for speed", popup BINWList
			PROMPT density_bin_str, "Histogram BIN setting for density", popup BINWList
			
			DoPROMPT "Please selcect the correct waves:", frame_str, qtm_speed_str, qtm_density_str, frame_bin_str, speed_bin_str, density_bin_str
			if(V_flag==0)
				//the following is in the current datafolder
				Wave frame_bin=$frame_bin_str; AbortOnRTE
				Wave speed_bin=$speed_bin_str; AbortOnRTE
				Wave density_bin=$density_bin_str; AbortOnRTE
			
				SetDataFolder $selectedFolder; AbortOnRTE
				//the following is in the selected folder
				Wave frame=$frame_str; AbortOnRTE
				wave speed=$qtm_speed_str; AbortOnRTE
				Wave density=$qtm_density_str; AbortOnRTE
				
				QTM_Hist_Summary(frame, speed, density, frame_bin, speed_bin, density_bin); AbortOnRTE
			endif
		
		catch
			Variable err=GetRTError(1)
			
			if(err!=0)
				print "Error catched:"
				print GetErrMessage(err)
			endif	
		endtry
		SetDataFolder dfr
	endif
end


static function distance(variable posx1, variable posy1, variable posx2, variable posy2)
	return sqrt((posx1-posx2)^2+(posy1-posy2)^2)
end

static function angle(variable posx1, variable posy1, variable posx2, variable posy2)
	variable theta=atan((posy2-posy1)/(posx2-posx1))
	
	if(posx2-posx1<0)
		theta+=pi
	else
		if(posy2-posy1<0)
			theta+=2*pi
		endif
	endif
	
	return theta/pi*180
end

static function get_intersect_area_circle(variable R1, variable r2, variable d)

	if(d<min(R1, r2))
		return pi*min(R1, r2)^2
	elseif(d>R1+r2)
		return 0
	endif
	
	variable costheta=(R1^2+d^2-r2^2)/2/R1/d
	variable cosbeta=(r2^2+d^2-R1^2)/2/r2/d
	
	variable theta_angle=acos(costheta)
	variable beta_angle=acos(cosbeta)
	
	variable s1=R1^2*theta_angle
	variable s2=r2^2*beta_angle
	variable s3=sqrt((-d+R1+r2)*(d+R1-r2)*(d-R1+r2)*(d+R1+r2))/2
	return s1+s2-s3
	
end

static function calculate_density(wave table, variable R1, variable r2, wave DENSITY)
	variable i, j, a
	
	for(i=0; i<DimSize(table, 0); i+=1)
	
		a=pi*r2^2
		for(j=0; j<DimSize(table, 0); j+=1)
		
			if(i!=j)
				a+=get_intersect_area_circle(R1, r2, distance(table[i][%POS_X], table[i][%POS_Y], table[j][%POS_X], table[j][%POS_Y]))
			endif
			
		endfor
		
		a/=pi*R1^2 //this should be area ratio
		
		a/= r2^2 / R1^2 //this turns it into how many cells within R1 radius
		
		table[i][%DENSITY]=a
		DENSITY[table[i][%SPOT_ID_IDX]]=a
	endfor
end

static function calculate_speed(wave tr, variable avoid_frame_begin, variable avoid_frame_end, variable speed_frame_interval, variable time_interval, wave id, wave speed_tbl)

	variable i, j
	variable len=DimSize(tr, 0)
	
	for(i=0; i<len; i+=1)
		if(i<avoid_frame_begin || len-i<=avoid_frame_end)
			tr[i][5,inf]=NaN
		endif
		for(j=i-1;j>=0 && tr[i][%FRAME_IDX]-tr[j][%FRAME_IDX]<speed_frame_interval; j-=1)
		endfor
		if(j>=0)
			variable deltaT=time_interval*(tr[i][%FRAME_IDX]-tr[j][%FRAME_IDX])
			variable dist=distance(tr[i][%POSX], tr[i][%POSY], tr[j][%POSX], tr[j][%POSY])
			tr[i][%SPEED]= dist / deltaT
			
			variable idx=find_value(id, tr[i][%SPOT_ID])
			if(idx>=0)
				speed_tbl[idx]=dist / deltaT
			else
				print "error, id ", tr[i][%SPOT_ID], " cannot be found in the ID wave record"
			endif
		endif
	endfor
	
end

//this generates a summary table, to have the starting and ending ID that belongs to a single track and other information in one place
//this also have the raw index of each track's starting and end point in that table for later lookup
function QTM_trackid_lookuptbl(wave trackid, wave posx, wave posy, wave frame, wave id_tbl, wave spot_src, wave spot_target)

	Redimension/L frame, trackid
	Redimension/L spot_src, spot_target
	Duplicate /O spot_src, QTM_SPOT_SOURCE_ID
	QTM_SPOT_SOURCE_ID=-1
	Duplicate /O spot_target, QTM_SPOT_TARGET_ID
	QTM_SPOT_TARGET_ID=-1

	WaveStats /Q trackid
	variable max_id=V_max, min_id=V_min
	variable tbl_len=(max_id-min_id)+1
	
	Make /O/D/N=(tbl_len, 13) QTM_TRACK_TBL=NaN
	
	SetDimLabel 1, 0, ID, QTM_TRACK_TBL //the track ID
	SetDimLabel 1, 1, firstNodeIdx, QTM_TRACK_TBL //this shows where the first node of the track tree is located (relative to the first node in the whole track), in a sorted table, this should be zero
	SetDimLabel 1, 2, startFrame, QTM_TRACK_TBL //the frame where this track started
	SetDimLabel 1, 3, endFrame, QTM_TRACK_TBL //the frame where this track ended
	SetDimLabel 1, 4, startPosX, QTM_TRACK_TBL //the position x where this track started
	SetDimLabel 1, 5, startPosY, QTM_TRACK_TBL //the position y where this track started
	SetDimLabel 1, 6, endPosX, QTM_TRACK_TBL //the position x where this track ended
	SetDimLabel 1, 7, endPosY, QTM_TRACK_TBL //the position y where this track ended
	SetDimLabel 1, 8, refIdxStart, QTM_TRACK_TBL //the index in the "TRACK_ID" referring to the start of the track
	SetDimLabel 1, 9, refIdxEnd, QTM_TRACK_TBL //the index in the "TRACK_ID" referring to the end of the track
	SetDimLabel 1, 10, frameLen, QTM_TRACK_TBL //total number of frames of the track
	SetDimLabel 1, 11, totalDistance, QTM_TRACK_TBL //total distance between the first and last frame
	SetDimLabel 1, 12, totalAngle, QTM_TRACK_TBL //angle of the displacement between first and last frame
	
	Variable refidx=0, tr_id=NaN, new_track_flag=0
	Variable tbl_counter=-1
	variable track_to_ID_idx
	do	
		if(refidx>=DimSize(trackid, 0) || trackid[refidx]!=tr_id)
		//track_id at refidx in trackid table is not the same as previous, or reached beyond the end of tbl
			if(new_track_flag==0) // this means we are hitting a new track_id
				if(refidx!=0) //not the first one, we need to then check back one more refidx to close the previous one
					print "New track identified. Track#:", QTM_TRACK_TBL[tbl_counter][%ID]
					
					//there is a chance that the data points are not sorted by frame/time. this part takes care of that
					Variable startrefidx=QTM_TRACK_TBL[tbl_counter][%refIdxStart]
					Make /FREE/D/N=(refidx-startrefidx) tmpframe_src, tmpsrc_id, tmptarget_id, tmpidx
					
					tmpsrc_id=spot_src[startrefidx+p]
					tmptarget_id=spot_target[startrefidx+p]
					tmpidx=p
					tmpframe_src=frame[find_value(id_tbl, tmpsrc_id[p])]
					
					Sort tmpframe_src, tmpframe_src, tmpsrc_id, tmptarget_id, tmpidx //sorting these columns based on frame (time)
					////// sorting done
					QTM_TRACK_TBL[tbl_counter][%startFrame]=tmpframe_src[0]
					QTM_TRACK_TBL[tbl_counter][%firstNodeIdx]=tmpidx[0]
					
					//tmpsrc_id[0] gives the ID for the first point, need to
					//look it up in the ID table to find its index
					track_to_ID_idx=find_value(id_tbl, tmpsrc_id[0]) 
					QTM_TRACK_TBL[tbl_counter][%startPosX]=posx[track_to_ID_idx]
					QTM_TRACK_TBL[tbl_counter][%startPosY]=posy[track_to_ID_idx]
					
					//tmptarget_id[DimSize(tmptarget_id, 0)-1] gives the ID for the last point, need to
					//look it up in the ID table to find its index
					track_to_ID_idx=find_value(id_tbl, tmptarget_id[DimSize(tmptarget_id, 0)-1])					
					QTM_TRACK_TBL[tbl_counter][%endFrame]=frame[track_to_ID_idx]
					
					QTM_TRACK_TBL[tbl_counter][%endPosX]=posx[track_to_ID_idx]
					QTM_TRACK_TBL[tbl_counter][%endPosY]=posy[track_to_ID_idx]
					
					QTM_TRACK_TBL[tbl_counter][%refIdxEnd]=refidx-1
					QTM_TRACK_TBL[tbl_counter][%frameLen]=QTM_TRACK_TBL[tbl_counter][%endFrame]-QTM_TRACK_TBL[tbl_counter][%startFrame]+1
					variable px1, px2, py1, py2
					
					px1=QTM_TRACK_TBL[tbl_counter][%startPosX]
					px2=QTM_TRACK_TBL[tbl_counter][%endPosX]
					py1=QTM_TRACK_TBL[tbl_counter][%startPosY]
					py2=QTM_TRACK_TBL[tbl_counter][%endPosY]
					
					QTM_TRACK_TBL[tbl_counter][%totalDistance]=distance(px1, py1, px2, py2)
					QTM_TRACK_TBL[tbl_counter][%totalAngle]=angle(px1, py1, px2, py2)
					
					QTM_SPOT_SOURCE_ID[startrefidx, refidx-1]=tmpsrc_id[p-startrefidx]
					QTM_SPOT_TARGET_ID[startrefidx, refidx-1]=tmptarget_id[p-startrefidx]
				endif
				
				if(refidx<DimSize(trackid, 0))
					tbl_counter+=1
					tr_id=trackid[refidx]
					QTM_TRACK_TBL[tbl_counter][%ID]=tr_id

					QTM_TRACK_TBL[tbl_counter][%refIdxStart]=refidx
					new_track_flag=1
				endif
			else //then something is wrong
				print "this should not happen."
				print "this could mean that for the previous track, there is only one edge."
				print "refidx=", refidx
				if(refidx<DimSize(trackid, 0))
					print "trackid[refidx]=", trackid[refidx]
				endif
				print "tr_id=", tr_id
				if(new_track_flag==1) //this was taken care of
					new_track_flag=0 //take the flag down, just keep going forward
					refidx-=1
				endif
			endif
			refidx+=1
		else //track_id at refidx is the same as previous record
			if(new_track_flag==1) //this was taken care of
				new_track_flag=0 //take the flag down, just keep going forward
			endif
			refidx+=1
		endif
	while(refidx<=DimSize(trackid, 0))
	
	DeletePoints /M=0 tbl_counter+1, inf, QTM_TRACK_TBL
end

static function branch_number(wave f, variable position, variable maxidx)
	
	variable i=-1, j
	
	for(j=position; j<maxidx; j+=i)
	
		for(i=1; i+j < maxidx && f[i+j]==f[j]; i+=1)
		endfor	
		
		break
				
	endfor	
	
	return i
end

static function find_value(wave w, variable value, [wave flag])
	variable i
	
	if(ParamIsDefault(flag))
		for(i=0; i<DimSize(w, 0); i+=1)
			if(w[i]==value)
				return i
			endif
		endfor
	else
		for(i=0; i<DimSize(w, 0); i+=1)
			if(flag[i]<0 && w[i]==value) //only when flag marks unoccupied
				return i
			endif
		endfor
	endif
	
	return -1
end

//this function creates a new datafolder that contains frame by frame all the x, y and density information and other
//information as noted in one place
function QTM_generate_frame_map(String dataList, variable density_diameter, variable cell_diameter, wave FRAME, wave POSITION_X, wave POSITION_Y, wave ID, [variable show_menu])
	
	if(density_diameter<0 || cell_diameter<0 || show_menu==1)
	
		PROMPT dataList, "List of values to be included in each frame table"
		PROMPT density_diameter, "Diameter of ROI for density calculation"
		PROMPT cell_diameter, "Diameter of cells"
		
		DoPROMPT "Set up parameters for frame maps", dataList, density_diameter, cell_diameter
		if(V_flag!=0 || density_diameter<0 || cell_diameter<0)
			print "Cancelled."
			return -1
		endif
	endif
	
	Variable i, j, k
	
	variable frametbl_count=0
	Variable datacolumns=ItemsInList(dataList)
	Variable datacol_idx
	String datacol_name
	
	String dfName=UniqueName("DataPerFrame", 11, 0)
	
	DFREF dfr=GetDataFolderDFR()

	try	
		NewDataFolder /O/S $dfName; AbortOnRTE
		
//		wave FRAME = dfr:FRAME; AbortOnRTE
//		wave POSITION_X = dfr:POSITION_X; AbortOnRTE
//		wave POSITION_Y = dfr:POSITION_Y; AbortOnRTE
//		wave ID = dfr:ID; AbortOnRTE
		Make /O/D/N=(DimSize(FRAME, 0)) dfr:QTM_DENSITY;AbortOnRTE
		wave DENSITY=dfr:QTM_DENSITY;AbortOnRTE
		DENSITY=NaN
		String notestr=""
		notestr = ReplaceStringByKey("ROI_DIAMETER", notestr, num2str(density_diameter))
		notestr = ReplaceStringByKey("CELL_DIAMETER", notestr, num2str(cell_diameter))
		variable max_frame=WaveMax(FRAME)
		
		do
			k=0
			Make /O/FREE/D/N=(1, datacolumns+6) tmp_frame; AbortOnRTE
			SetDimLabel 1, 0, FRAME, tmp_frame; AbortOnRTE
			SetDimLabel 1, 1, POS_X, tmp_frame; AbortOnRTE
			SetDimLabel 1, 2, POS_Y, tmp_frame; AbortOnRTE
			SetDimLabel 1, 3, SPOT_ID, tmp_frame; AbortOnRTE
			SetDimLabel 1, 4, SPOT_ID_IDX, tmp_frame; AbortOnRTE
			SetDimLabel 1, 5, DENSITY, tmp_frame; AbortOnRTE
			for(j=0; j<datacolumns; j+=1)
				SetDimLabel 1, j+6, $StringFromList(j, dataList), tmp_frame; AbortOnRTE
			endfor
			
			for(i=0; i<DimSize(FRAME, 0); i+=1)
				if(FRAME[i]==frametbl_count)
					tmp_frame[k][%FRAME]=frametbl_count; AbortOnRTE
					tmp_frame[k][%POS_X]=POSITION_X[i]; AbortOnRTE
					tmp_frame[k][%POS_Y]=POSITION_Y[i]; AbortOnRTE
					tmp_frame[k][%SPOT_ID]=ID[i]; AbortOnRTE
					tmp_frame[k][%SPOT_ID_IDX]=i; AbortOnRTE
					tmp_frame[k][%DENSITY]=NaN; AbortOnRTE
					for(j=0; j<datacolumns; j+=1)
						wave w=dfr:$StringFromList(j, dataList); AbortOnRTE
						if(WaveExists(w))
							tmp_frame[k][j+6]=w[i]; AbortOnRTE
						else
							tmp_frame[i][j+6]=NaN; AbortOnRTE
						endif
					endfor
					InsertPoints /M=0 k+1, 1, tmp_frame; AbortOnRTE
					k+=1
				endif
			endfor
			print "Frame #", frametbl_count, " table ready. Calculating density..."
			if(k>0)
				DeletePoints /M=0 k, 1, tmp_frame; AbortOnRTE
				calculate_density(tmp_frame, density_diameter/2, cell_diameter/2, DENSITY); AbortOnRTE
				Duplicate /O tmp_frame, $("frame"+num2istr(frametbl_count)); AbortOnRTE
				note /k $("frame"+num2istr(frametbl_count)), notestr ; AbortOnRTE
				frametbl_count+=1
			endif
			
			print "Frame #", frametbl_count, "out of ", max_frame, "is finished."
		while(k>0)
	catch
		Variable err=GetRTError(1)
		
		if(err!=0)
			print "Error catched:"
			print GetErrMessage(err)
			print "when working on item #", i, " in track table"
		endif	
	endtry
	note /k DENSITY, notestr
	SetDataFolder dfr
	print "all done."

end

Function QTMFilter_framewave(theNameWithPath, ListContents)
	String theNameWithPath
	Variable ListContents
	Variable numItems = ItemsInList(theNameWithPath, ":")
	
	return stringmatch(StringFromList(numItems-1, theNameWithPath, ":"), "frame*")
end

Function QTMFilter_trackwave(theNameWithPath, ListContents)
	String theNameWithPath
	Variable ListContents
	Variable numItems = ItemsInList(theNameWithPath, ":")
	
	return stringmatch(StringFromList(numItems-1, theNameWithPath, ":"), "tr_*")
end

Function QTM_Select_Frame()
	Variable minDensity=1, maxDensity=4 //number of cells per ROI circle
	
	PROMPT minDensity, "min density (number of cells per ROI circle)"
	PROMPT maxDensity, "max density (number of cells per ROI circle)"
	DoPrompt "Density color min and max", minDensity, maxDensity
	
	WaveBrowser("SelectFrameTable", "Select Frame Table", \
				100, 100, "Folder Name", "Table Name", 3, "root:", "", \
				"CALLBACKFUNC:QTM_plot_framexy;FUNCPARAM:MIN="+num2str(minDensity)+",MAX="+num2str(maxDensity)+";", \
				nameFilter="QTMFilter_framewave")
End

Function QTM_plot_framexy(String param, String datafolder, String wname)
	print param
	print dataFolder
	print wname
	wave w=$(datafolder+wname)
	
	string use_wave=StringByKey("USE_WAVE", param, "=", ",")
	variable no_draw=str2num(StringByKey("NO_DRAW", param, "=", ","))
	
	if(strlen(use_wave)>0)
		Duplicate /O w, $use_wave
		wave w=$use_wave
	endif
	
	if(WaveExists(w))
		variable mindensity=str2num(StringByKey("MIN", param, "=", ","))
		variable maxdensity=str2num(StringByKey("MAX", param, "=", ","))
		
		if(no_draw==1)
			//only update the wave
		else
			Display w[][%POS_Y] vs w[][%POS_X]
			SetAxis/A/N=1/E=1 left;DelayUpdate
			SetAxis/A/N=1/E=1 bottom;DelayUpdate
			ModifyGraph standoff=0
			ModifyGraph width={perUnit,0.566929,bottom},height={perUnit,0.566929,left}
			ModifyGraph mode=3, msize=4
			ModifyGraph marker=19,zColor={w[*][%DENSITY],mindensity,maxdensity,RainBow,1}
		endif
	endif
End

//this breaks off tracks that have branches and separate them into individual tracks
function QTM_Split_track(wave trackid_tbl, wave trackid, wave id, wave posx, wave posy, wave frame, wave spot_src, wave spot_tg, [string optionalList, variable avoid_frame_begin, variable avoid_frame_end, variable speed_frame_interval, variable time_interval, variable show_menu])

	Variable i
	
	variable tstbl_count=0, track_to_spotid_idx
	
	String dfName=UniqueName("SplittedTraces", 11, 0)
	
	DFREF dfr=GetDataFolderDFR()
	
	if(ParamIsDefault(avoid_frame_begin))
		avoid_frame_begin=0
	endif
	
	if(ParamIsDefault(avoid_frame_end))
		avoid_frame_end=0
	endif
	
	if(ParamIsDefault(speed_frame_interval))
		speed_frame_interval=1
	endif
	
	if(ParamIsDefault(time_interval))
		time_interval=30
	endif
	
	variable max_trackid=WaveMax(trackid)
	
	if(show_menu==1)
		PROMPT optionalList, "Wave list to be included for track records"
		PROMPT avoid_frame_begin, "Number of frames at the beginning of track to avoid filling numbers"
		PROMPT avoid_frame_end, "Number of frames at the end of track to avoid filling numbers"
		PROMPT speed_frame_interval, "Minimal frame interval for calculating speed"
		PROMPT time_interval, "Time interval between frames"
		DoPROMPT "Set ip parameter for splitting track records", optionalList, avoid_frame_begin, avoid_frame_end, speed_frame_interval, time_interval
		
		if(V_Flag!=0)
			print "Cancelled"
			return -1
		endif
	endif
	
	Make /O/D/N=(DimSize(id, 0)) QTM_SPEED=NaN
	wave speed_tbl=QTM_SPEED
	
	Variable optionalListLen=ItemsInList(optionalList)
	Variable j

	try	
		NewDataFolder /S $dfName; AbortOnRTE
		
		for(i=0; i<DimSize(trackid_tbl, 0); i+=1)
			print "working on track record #", i, "out of ", DimSize(trackid_tbl, 0), "records. ", "track id is: ", trackid_tbl[i][%ID], "/", max_trackid

			Variable tr_ref_start=trackid_tbl[i][%refIdxStart]; AbortOnRTE
			Variable tr_ref_end=trackid_tbl[i][%refIdxEnd]; AbortOnRTE
			Variable tr_frame_start=trackid_tbl[i][%startFrame]; AbortOnRTE
			Variable tr_frame_end=trackid_tbl[i][%endFrame]; AbortOnRTE
			
			print "track id ref start and end:", tr_ref_start, tr_ref_end
			print "track frame start and end:", tr_frame_start, tr_frame_end
			
			Variable tr_totallen=tr_ref_end - tr_ref_start+1
			Variable tr_totalframe=tr_frame_end - tr_frame_start+1
			print "track total length (upper limit):", tr_totallen
			print "track frame length (upper limit):", tr_totalframe
			
			if(tr_totallen<=1)
				print "track length is not longer than 1. skipping."
				continue
			endif
			
			Make /FREE/L/N=(tr_totallen) tmp_flag=-1, tmp_spot_src=-1, tmp_spot_tg=-1; AbortOnRTE
			
			tmp_spot_src = spot_src[tr_ref_start+p]; AbortOnRTE
			tmp_spot_tg = spot_tg[tr_ref_start+p]; AbortOnRTE
	
			FindDuplicates /FREE /DN=tmp_dup_src tmp_spot_src; AbortOnRTE
			
			variable tmp_start_pos=0
			variable tmp_tr_position

			do
						
				if(tmp_flag[tmp_start_pos]<0) //the spot has not been covered, indicating a start
				
					Make /D/N=(tr_totalframe, 6+optionalListLen) $("tr_"+num2istr(tstbl_count)); AbortOnRTE
					wave tr=$("tr_"+num2istr(tstbl_count)); AbortOnRTE
					
					SetDimLabel 1, 0, ORIG_TRACK_ID, tr; AbortOnRTE
					SetDimLabel 1, 1, FRAME_IDX, tr; AbortOnRTE
					SetDimLabel 1, 2, POSX, tr; AbortOnRTE
					SetDimLabel 1, 3, POSY, tr; AbortOnRTE
					SetDimLabel 1, 4, SPOT_ID, tr; AbortOnRTE
					SetDimLabel 1, 5, SPEED, tr; AbortOnRTE
					
					tmp_tr_position=tmp_start_pos
					Variable tr_counter=0
					tr[][%ORIG_TRACK_ID]=trackid_tbl[i][%ID]; AbortOnRTE
					tr[][%SPEED]=NaN; AbortOnRTE
					print "splitting a new track#", tstbl_count
					do
						tmp_flag[tmp_tr_position]=tstbl_count
						
						track_to_spotid_idx=find_value(id, tmp_spot_src[tmp_tr_position])
						
						tr[tr_counter][%FRAME_IDX]=frame[track_to_spotid_idx]; AbortOnRTE
						tr[tr_counter][%POSX]=posx[track_to_spotid_idx]; AbortOnRTE
						tr[tr_counter][%POSY]=posy[track_to_spotid_idx]; AbortOnRTE
						tr[tr_counter][%SPOT_ID]=id[track_to_spotid_idx]; AbortOnRTE
						
						for(j=0; j<optionalListLen; j+=1)
							wave optionalw=dfr:$(StringFromList(j, optionalList))
							SetDimLabel 1, j+6, $(StringFromList(j, optionalList)), tr
							
							if(WaveExists(optionalw))
								tr[tr_counter][j+6]=optionalw[track_to_spotid_idx]; AbortOnRTE
							endif
						endfor
						
						variable current_id=tr[tr_counter][%SPOT_ID]
						tr_counter+=1
						
						if(tr_counter>1 && find_value(tmp_dup_src, current_id)>=0) //this spot is a src for multiple
							break //then this trace should stop here
						else //get to the next spot in the link chain
							variable target_id
							
							target_id=tmp_spot_tg[tmp_tr_position]
							
							if(target_id>=0)
								tmp_tr_position=find_value(tmp_spot_src, target_id, flag=tmp_flag) //position of the next target ID	
							
								if(tmp_tr_position<0) //this target is not a source for anyone
									//should be the last point of this track
									//but this target ID should be the last point of this track so it should be written down
									track_to_spotid_idx=find_value(id, target_id)
						
									tr[tr_counter][%FRAME_IDX]=frame[track_to_spotid_idx]; AbortOnRTE
									tr[tr_counter][%POSX]=posx[track_to_spotid_idx]; AbortOnRTE
									tr[tr_counter][%POSY]=posy[track_to_spotid_idx]; AbortOnRTE
									tr[tr_counter][%SPOT_ID]=id[track_to_spotid_idx]; AbortOnRTE
									
									for(j=0; j<optionalListLen; j+=1)
										wave optionalw=dfr:$(StringFromList(j, optionalList))

										if(WaveExists(optionalw))
											tr[tr_counter][j+6]=optionalw[track_to_spotid_idx]; AbortOnRTE
										endif
									endfor						
									
									note /k tr, "TIME_INTERVAL:"+num2str(time_interval)
									tr_counter+=1
									
									break
									
								endif
							
							else
								//this should be the last point because this node has no further target.
								tmp_tr_position=-1
								break
							endif
							
						endif
									
					while(tmp_tr_position>=0 && tmp_tr_position<tr_totallen)
					
					DeletePoints tr_counter, inf, tr
					
					calculate_speed(tr, avoid_frame_begin, avoid_frame_end, speed_frame_interval, time_interval, id, speed_tbl)
					print "splitted track#", tstbl_count, " finished."
					tstbl_count+=1
				
				else
					
					tmp_start_pos+=1 //move to the next record where the spot is not included in any track yet
				
				endif
											
			while(tmp_start_pos>=0 && tmp_start_pos<tr_totallen)
			
		endfor
	catch
		Variable err=GetRTError(1)
		
		if(err!=0)
			print "Error catched:"
			print GetErrMessage(err)
			print "when working on item #", i, " in track table"
		endif	
	endtry
	
	SetDataFolder dfr

end


function QTM_summarize_tbl(String datafolder, variable distance_threshold, variable frame_threshold)

	DFREF dfr=GetDataFolderDFR()

	
	if(strlen(datafolder)<=0 || distance_threshold<0 || frame_threshold<0)
		String foldername=datafolder
		Variable dist_threshold=10
		Variable fr_threshold=10
		
		String folderList=DataFolderDir(1)
		folderList=StringByKey("FOLDERS", folderList, ":", ";")
		folderList=ReplaceString(",", folderList, ";")
		PROMPT foldername, "Data Folder Name that contains the tracks", popup folderList
		PROMPT dist_threshold, "Maximum distance between adjacent points within a track that will trigger a warning"
		PROMPT fr_threshold, "Minimum number of frames that are needed to be included in the table"
		
		DoPROMPT "Please enter the following values", foldername, dist_threshold, fr_threshold
		if(V_flag==0 && DataFolderExists(foldername) && dist_threshold>0 && fr_threshold>0)
			datafolder=foldername
			distance_threshold=dist_threshold
			frame_threshold=fr_threshold
		else
			return -1
		endif
	endif
	
	try	
		SetDataFolder $datafolder; AbortOnRTE
		
		String wlist=WaveList("tr_*", ";", "DF:0"); AbortOnRTE
		variable total_tracks=ItemsInList(wlist); AbortOnRTE
		variable track_count=0
		
		Make /O/D/N=(total_tracks, 10) track_summary = NaN; AbortOnRTE
		wave tbl=track_summary
		SetDimLabel 1, 0, NEW_TRACK_ID, tbl
		SetDimLabel 1, 1, ORIG_TRACK_ID, tbl
		SetDimLabel 1, 2, START_FRAME, tbl
		SetDimLabel 1, 3, END_FRAME, tbl
		SetDimLabel 1, 4, START_POSX, tbl
		SetDimLabel 1, 5, START_POSY, tbl
		SetDimLabel 1, 6, END_POSX, tbl
		SetDimLabel 1, 7, END_POSY, tbl
		SetDimLabel 1, 8, TOTAL_DISTANCE, tbl
		SetDimLabel 1, 9, TOTAL_ANGLE, tbl
		
		variable i, j
		
		for(i=0; i<total_tracks; i+=1)		
			wave w=$(StringFromList(i, wlist)); AbortOnRTE
			variable lastidx=DimSize(w, 0)-1; AbortOnRTE
			
			for(j=1; j<DimSize(w, 0); j+=1)
				if(round(w[j][%FRAME_IDX]-w[j-1][%FRAME_IDX])!=1)
					print "warning: missing frame found. frame idx check failed for track#", i, " at ", j; AbortOnRTE
					break
				endif
				if(distance(w[j][%POSX], w[j][%POSY], w[j-1][%POSX], w[j-1][%POSY])>distance_threshold)
					print "warning: distance threshold faild for track#", i, "at ", j, ", cell moves too far", distance(w[j][%POSX], w[j][%POSY], w[j-1][%POSX], w[j-1][%POSY])
				endif
			endfor
			
			if(w[lastidx][%FRAME_IDX] - w[0][%FRAME_IDX] +1 < frame_threshold)
				print "track#", i, "has only ", w[lastidx][%FRAME_IDX] - w[0][%FRAME_IDX] +1, "frames, will not be included in summary table"
			else
				variable x0, y0, x1, y1
				
				tbl[i][%NEW_TRACK_ID]=i; AbortOnRTE
				tbl[i][%ORIG_TRACK_ID]=w[0][%ORIG_TRACK_ID]; AbortOnRTE
				tbl[i][%START_FRAME]=w[0][%FRAME_IDX]; AbortOnRTE
				tbl[i][%END_FRAME]=w[lastidx][%FRAME_IDX]; AbortOnRTE
				
				x0=w[0][%POSX]; AbortOnRTE
				tbl[i][%START_POSX]=x0; AbortOnRTE
				
				y0=w[0][%POSY]; AbortOnRTE
				tbl[i][%START_POSY]=y0; AbortOnRTE
				
				x1=w[lastidx][%POSX]; AbortOnRTE
				tbl[i][%END_POSX]=x1; AbortOnRTE
				
				y1=w[lastidx][%POSY]; AbortOnRTE
				tbl[i][%END_POSY]=y1; AbortOnRTE
				
				tbl[i][%TOTAL_DISTANCE]=distance(x0, y0, x1, y1); AbortOnRTE
				tbl[i][%TOTAL_ANGLE]=angle(x0, y0, x1, y1); AbortOnRTE
				
				track_count+=1
			endif
		endfor
		
	catch
		Variable err=GetRTError(1)
		
		if(err!=0)
			print "Error catched:"
			print GetErrMessage(err)
			print "when working on item #", i, " in track table"
		endif	
	endtry
	print "Total ", track_count, "out of ", total_tracks, " are included in summary table"
	SetDataFolder dfr
end

static function normalize_hist_by_area(wave h)

	variable i, j
	variable s
	
	for(i=0; i<DimSize(h, 0); i+=1)
		
		s=0
		for(j=0; j<DimSize(h, 1); j+=1)
			s+=h[i][j]
		endfor
		
		h[i][]/=s
		
	endfor

end

function QTM_Hist_Summary(wave frame, wave speed, wave density, wave frame_bin, wave speed_bin, wave density_bin, [variable UniqueDF])
	
	String dfName=""
	
	if(ParamIsDefault(UniqueDF))		
		DoAlert 1, "Generate unique name for datafolder? If select no, we will overwrite existing one with name 'Histograms'"
		if(V_flag==1)
			UniqueDF=1
		else
			UniqueDF=0
		endif
	endif
	
	if(UniqueDF==1)
		dfName=UniqueName("Histograms", 11, 0)
	else
		dfName="Histograms"
	endif
	
	
	DFREF dfr=GetDataFolderDFR()
	try
		NewDataFolder /O/S $dfName; AbortOnRTE
		Duplicate /O frame_bin, HIST_BIN_FRAME; AbortOnRTE
		Duplicate /O speed_bin, HIST_BIN_SPEED; AbortOnRTE
		Duplicate /O density_bin, HIST_BIN_DENSITY; AbortOnRTE
		Make /FREE/D/N=(DimSize(frame, 0)) tmp_frame
		tmp_frame=frame
		
		JointHistogram /BINS={0, 0} /XBWV=HIST_BIN_FRAME /YBWV=HIST_BIN_SPEED /DEST=HIST2D_FRAME_SPEED tmp_frame, speed; AbortOnRTE
		Duplicate /O HIST2D_FRAME_SPEED, HIST2D_NORM_FRAME_SPEED; AbortOnRTE
		normalize_hist_by_area(HIST2D_NORM_FRAME_SPEED); AbortOnRTE
		
		JointHistogram /BINs={0, 0} /XBWV=HIST_BIN_FRAME /YBWV=HIST_BIN_DENSITY /DEST=HIST2D_FRAME_DENSITY tmp_frame, density; AbortOnRTE
		Duplicate /O HIST2D_FRAME_DENSITY, HIST2D_NORM_FRAME_DENSITY; AbortOnRTE
		normalize_hist_by_area(HIST2D_NORM_FRAME_DENSITY); AbortOnRTE
		
		JointHistogram /BINS={0, 0} /XBWV=HIST_BIN_DENSITY /YBWV=HIST_BIN_SPEED /DEST=HIST2D_DENSITY_SPEED density, speed; AbortOnRTE
		Duplicate /O HIST2D_DENSITY_SPEED, HIST2D_NORM_DENSITY_SPEED; AbortOnRTE
		normalize_hist_by_area(HIST2D_NORM_DENSITY_SPEED); AbortOnRTE
		
		JointHistogram /BINS={0, 0, 0} /XBWV=HIST_BIN_FRAME /YBWV=HIST_BIN_SPEED /ZBWV=HIST_BIN_DENSITY /DEST=HIST3D_FRAME_SPEED_DENSITY tmp_frame, speed, density; AbortOnRTE
		variable i
		for(i=0; i<DimSize(HIST3D_FRAME_SPEED_DENSITY, 2); i+=1)
			Make /D/O/N=(DimSize(HIST3D_FRAME_SPEED_DENSITY, 0), DimSize(HIST3D_FRAME_SPEED_DENSITY, 1)) $("HIST2D_FRAME_SPEED_BYDENSITY"+num2istr(i)), $("HIST2D_NORM_FRAME_SPEED_BYDENSITY"+num2istr(i)); AbortOnRTE
			Wave hist=$("HIST2D_FRAME_SPEED_BYDENSITY"+num2istr(i)); AbortOnRTE
			Wave hist_n=$("HIST2D_NORM_FRAME_SPEED_BYDENSITY"+num2istr(i)); AbortOnRTE
			hist[][]=HIST3D_FRAME_SPEED_DENSITY[p][q][i]; AbortOnRTE
			hist_n=hist; AbortOnRTE
			normalize_hist_by_area(hist_n); AbortOnRTE
		endfor
	catch
		Variable err=GetRTError(1)
		
		if(err!=0)
			print "Error catched:"
			print GetErrMessage(err)
		endif	
	endtry
	SetDataFolder dfr
	print "Done."
end

Function QTM_Choose_FrameDF()
	WaveBrowser("FrameFolderSelector", "Select Frame Data Folder", 100, 100, \
				"Folder Name", "Any wave for frame data", 3, "root:", "", \
				"CALLBACKFUNC:QTM_Extract_Frame_Values;FUNCPARAM:", \
				showWhat="WAVES", nameFilter="QTMFilter_framewave")
End

Function QTM_Extract_Frame_Values(String param, String datafolder, String wname)
	DFREF dfr=GetDataFolderDFR()

	try
		
		SetDataFolder $datafolder
		
		String wlist=WaveList("frame*", ";", "")
		Variable wlistNum=ItemsInList(wlist)
		
		print "working in DataFolder: ", datafolder
		print "total ", wlistNum, " frames are detected."
		Wave w=$StringFromList(0, wlist)
		
		if(WaveExists(w))
			Variable dimCol=DimSize(w, 1)
			Variable i
			String colList=""
			for(i=dimCol-1; i>=0; i-=1)
				colList=AddListItem(num2istr(i)+":"+GetDimLabel(w, 1, i), colList, ";")
			endfor
			
			Variable colidx=0
			PROMPT colidx, "Select column for processing", popup colList
			String procFuncList=FunctionList("QTMFRAMEPROC*", ";", "KIND:2;NPARAMS:5")
			String procFunc=StringFromList(0, procFuncList)
			PROMPT procFunc, "Select processing function", popup procFuncList
			
			DoPROMPT "Select column and processing function", colidx, procFunc			
			
			if(V_Flag==0)
				colidx-=1
				print "column ", colidx, " selected."
				if(str2num(StringFromList(0, StringFromList(colidx, colList, ";"), ":"))!=colidx)
					print "the order of column name is messed up, please check again."
				else
					FUNCREF QTMFRAMEPROC_Average fRef=$procFunc
					String fparam=fRef(0, colidx, wlistNum, "", w)
					if(strlen(fparam)==0)
						print "init of processing function returned null string. process cancelled."
					else
						for(i=0; i<wlistNum; i+=1)
							Wave w=$StringFromList(i, wlist)
							fRef(1, colidx, wlistNum, fparam, w)
						endfor
					endif
				endif
			endif			
		endif
	catch
	endtry
	
	SetDataFolder dfr
End

Function /S QTMFRAMEPROC_Average(Variable initState, Variable colIdx, Variable totalFrames, String Param, Wave frameData)
	if(initState==0) //init step
		print "Will calculate average of the selected column #", colIdx, GetDimLabel(frameData, 1, colIdx)
		String wname="root:FrameAvgCol"+num2istr(colIdx)
		PROMPT wname, "Save final result to wave"
		DoPROMPT "Save result to", wname
		if(V_Flag==0)
			Make /O/D/N=(totalFrames, 4) $wname
			Wave w=$wname
			if(WaveExists(w))
				SetDimLabel 1, 0, AVERAGE, w
				SetDimLabel 1, 1, MINIMUM, w
				SetDimLabel 1, 2, MAXIMUM, w
				SetDimLabel 1, 3, STDEV, w
				return wname
			else
				return ""
			endif
		else
			return ""
		endif
	else
		Wave w=$Param
		if(WaveExists(w))
			Variable fr=frameData[0][%FRAME]
			Make /FREE/N=(DimSize(frameData, 0)) tmpData=frameData[p][colIdx]
			
			WaveTransform /O zapNaNs tmpData
			WaveStats /Q tmpData
			
			w[fr][%AVERAGE]=V_avg
			w[fr][%MINIMUM]=V_min
			w[fr][%MAXIMUM]=V_max
			w[fr][%STDEV]=V_sdev
		endif
	endif
End

Function /S QTMFRAMEPROC_Histogram(Variable initState, Variable colIdx, Variable totalFrames, String Param, Wave frameData)
	Variable bin_start=0
	Variable bin_size=1
	Variable bin_number=100
	PROMPT bin_start, "Histogram bin start"
	PROMPT bin_size, "Histogram bin size"
	PROMPT bin_number, "Histogram bin number"
	
	if(initState==0) //init step
		String setParam=""
		print "Will calculate histogram of the selected column #", colIdx, GetDimLabel(frameData, 1, colIdx)
		String wname="root:FrameHistCol"+num2istr(colIdx)
		PROMPT wname, "Save final result to wave"
		
		
		DoPROMPT "Save result to", wname, bin_start, bin_size, bin_number
		
		if(V_Flag==0)
			Make /O/D/N=(totalFrames, bin_number) $wname
			Wave w=$wname
			if(WaveExists(w))
				SetScale /P y bin_start, bin_size, "", w
				sprintf setParam, "WAVE:%s;BINSTART:%e;BINSIZE:%e;BINNUMBER:%d", wname, bin_start, bin_size, bin_number
				note /k w, setParam
				return setParam
			else
				return ""
			endif
		else
			return ""
		endif
	else
		Wave w=$StringByKey("WAVE", Param, ":", ";")
		bin_start=str2num(StringByKey("BINSTART", Param, ":", ";"))
		bin_size=str2num(StringByKey("BINSIZE", Param, ":", ";"))
		bin_number=str2num(StringByKey("BINNUMBER", Param, ":", ";"))
		
		if(WaveExists(w))
			Variable fr=frameData[0][%FRAME]
			Make /FREE/D/N=(DimSize(frameData, 0)) tmpData=frameData[p][colIdx]
			Make /FREE/D/N=(bin_number) tmpHist
			
			Histogram /B={bin_start, bin_size, bin_number} /DEST=tmpHist tmpData
			w[fr][]=tmpHist[q]
		endif
	endif
End

Function QTM_Choose_TrackDF()
	WaveBrowser("TrackFolderSelector", "Select Track Data Folder", 100, 100, \
				"Folder Name", "Any wave for track data", 3, "root:", "", \
				"CALLBACKFUNC:QTM_Extract_Value_byTrack;FUNCPARAM:", \
				showWhat="WAVES", nameFilter="QTMFilter_trackwave")
End

Function QTM_Extract_Value_byTrack(String param, String datafolder, String wname)

	DFREF dfr=GetDataFolderDFR()

	try
		
		SetDataFolder $datafolder
		
		String wlist=WaveList("tr_*", ";", "")
		Variable wlistNum=ItemsInList(wlist)
		
		print "working in DataFolder: ", datafolder
		print "total ", wlistNum, " tracks are detected."
		Wave w=$StringFromList(0, wlist)
		
		if(WaveExists(w))
			Variable dimCol=DimSize(w, 1)
			Variable i, j
			String colList=""
			for(i=dimCol-1; i>=0; i-=1)
				colList=AddListItem(num2istr(i)+":"+GetDimLabel(w, 1, i), colList, ";")
			endfor
			
			Variable colidx=0
			PROMPT colidx, "Select column for processing", popup colList
			Variable totalFrames=100
			PROMPT totalFrames, "Total frames to count"
						
			DoPROMPT "Select column to process", colidx, totalFrames
			
			if(V_Flag==0)
				colidx-=1
				print "column ", colidx, " selected."
				if(str2num(StringFromList(0, StringFromList(colidx, colList, ";"), ":"))!=colidx)
					print "the order of column name is messed up, please check again."
				else
					Make /N=(totalFrames, 3)/D/O ExtractedValuesFromTrackByFrame=NaN
					Make /N=(totalFrames, wlistNum)/D/FREE tmpw=NaN
					Wave w=ExtractedValuesFromTrackByFrame
					
					for(i=0; i<wlistNum; i+=1)
						wave tr=$StringFromList(i, wlist)
						if(WaveExists(tr))
							Variable dimx=DimSize(tr, 0)
							for(j=0; j<dimx; j+=1)
								Variable fr=tr[j][%FRAME_IDX]
								Variable val=tr[j][colidx]								
								if(numtype(val)==0 && fr>=0 && fr<DimSize(tmpw, 0))
									if(numtype(tmpw[fr][i])==0)
										print "error: a duplicated value was found for track", i, " on frame ", fr
									else
										tmpw[fr][i]=Val
									endif
								endif								
							endfor
						endif
					endfor
					
					for(i=0; i<DimSize(tmpw, 0); i+=1)
						Make /FREE/O/N=(wlistNum)/D tmpwfr=tmpw[i][p]
						WaveStats /Q tmpwfr
						w[i][0]=V_avg
						w[i][1]=V_sdev
						w[i][2]=V_npnts
					endfor
					
				endif
			endif			
		endif
	catch
	endtry
	
	SetDataFolder dfr
End