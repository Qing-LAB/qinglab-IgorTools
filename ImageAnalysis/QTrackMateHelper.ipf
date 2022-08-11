#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "WaveBrowser"

Menu "QTools"
	SubMenu "QTrackMateHelper"
		"Load TrackMate CSV file", QTM_load_track_file()
		"Generate TrackID lookup table", QTM_trackid_lookuptbl(TRACK_ID, POSITION_X, POSITION_Y, FRAME, ID, SPOT_SOURCE_ID, SPOT_TARGET_ID)
		"Generate Map per Frame", QTM_generate_frame_map("", 50, 30, show_menu=1)
		"Split branched tracks", QTM_Split_track(trackid_tbl, TRACK_ID, ID, POSITION_X, POSITION_Y, FRAME, SPOT_SOURCE_ID, SPOT_TARGET_ID, show_menu=1)
		"Plot Frame XY", QTM_Select_Frame()
		"Summarize", QTM_summarize_tbl("", -1, -1)
	End
End

function QTM_load_track_file()
	Variable refNum

	Variable f
	Open /D /R /F="Data Files (*.txt,*.dat,*.csv):.txt,.dat,.csv;" refNum
	
	String fullPath = S_fileName
	
	if(strlen(fullPath)>0)
	
		LoadWave /Q/J/W/L={0, 4, 0, 0, 0}/K=0 /D /O fullPath
		
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

	WaveStats /Q trackid
	variable max_id=V_max, min_id=V_min
	variable tbl_len=(max_id-min_id)+1
	
	Make /O/D/N=(tbl_len, 13) trackid_tbl=NaN
	
	SetDimLabel 1, 0, ID, trackid_tbl //the track ID
//	SetDimLabel 1, 1, finalID, trackid_tbl //the column saved for later splitting ID, not used
	SetDimLabel 1, 2, startFrame, trackid_tbl //the frame where this track started
	SetDimLabel 1, 3, endFrame, trackid_tbl //the frame where this track ended
	SetDimLabel 1, 4, startPosX, trackid_tbl //the position x where this track started
	SetDimLabel 1, 5, startPosY, trackid_tbl //the position y where this track started
	SetDimLabel 1, 6, endPosX, trackid_tbl //the position x where this track ended
	SetDimLabel 1, 7, endPosY, trackid_tbl //the position y where this track ended
	SetDimLabel 1, 8, refIdxStart, trackid_tbl //the index in the "TRACK_ID" referring to the start of the track
	SetDimLabel 1, 9, refIdxEnd, trackid_tbl //the index in the "TRACK_ID" referring to the end of the track
	SetDimLabel 1, 10, frameLen, trackid_tbl //total number of frames of the track
	SetDimLabel 1, 11, totalDistance, trackid_tbl //total distance between the first and last frame
	SetDimLabel 1, 12, totalAngle, trackid_tbl //angle of the displacement between first and last frame
	
	Variable refidx=0, tr_id=NaN, new_track_flag=0
	Variable tbl_counter=-1
	variable track_to_ID_idx
	do
	
		if(refidx>=DimSize(trackid, 0) || trackid[refidx]!=tr_id)
		//track_id at refidx in trackid table is not the same as previous, or reached beyond the end of tbl
			if(new_track_flag==0) // this means we are hitting a new track_id
				if(refidx!=0) //not the first one, we need to then check back one more refidx to close the previous one
					track_to_ID_idx=find_value(id_tbl, spot_target[refidx-1]) //spot_target gives the ID for the last point, need to
																							  //look it up in the ID table to find its index				
					trackid_tbl[tbl_counter][%endFrame]=frame[track_to_ID_idx]
					trackid_tbl[tbl_counter][%endPosX]=posx[track_to_ID_idx]
					trackid_tbl[tbl_counter][%endPosY]=posy[track_to_ID_idx]
					trackid_tbl[tbl_counter][%refIdxEnd]=refidx-1
					trackid_tbl[tbl_counter][%frameLen]=trackid_tbl[tbl_counter][%endFrame]-trackid_tbl[tbl_counter][%startFrame]+1
					variable px1, px2, py1, py2
					
					px1=trackid_tbl[tbl_counter][%startPosX]
					px2=trackid_tbl[tbl_counter][%endPosX]
					py1=trackid_tbl[tbl_counter][%startPosY]
					py2=trackid_tbl[tbl_counter][%endPosY]
					
					trackid_tbl[tbl_counter][%totalDistance]=distance(px1, py1, px2, py2)
					trackid_tbl[tbl_counter][%totalAngle]=angle(px1, py1, px2, py2)
				endif
				
				if(refidx<DimSize(trackid, 0))
					tbl_counter+=1
					tr_id=trackid[refidx]
					trackid_tbl[tbl_counter][%ID]=tr_id
//					trackid_tbl[tbl_counter][%finalID]=-1
					track_to_ID_idx=find_value(id_tbl, spot_src[refidx]) //spot_target gives the ID for the last point, need to
																							//look it up in the ID table to find its index
					trackid_tbl[tbl_counter][%startFrame]=frame[track_to_ID_idx]
					trackid_tbl[tbl_counter][%startPosX]=posx[track_to_ID_idx]
					trackid_tbl[tbl_counter][%startPosY]=posy[track_to_ID_idx]
					trackid_tbl[tbl_counter][%refIdxStart]=refidx
					new_track_flag=1
				endif
			else //then something is wrong
				print "this should not happen."
				print "this could mean that for the previous track, there is only one frame."
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
	
	DeletePoints /M=0 tbl_counter+1, inf, trackid_tbl
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
function QTM_generate_frame_map(String dataList, variable density_diameter, variable cell_diameter, [variable show_menu])
	
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
		NewDataFolder /S $dfName; AbortOnRTE
		
		wave FRAME = dfr:FRAME; AbortOnRTE
		wave POSITION_X = dfr:POSITION_X; AbortOnRTE
		wave POSITION_Y = dfr:POSITION_Y; AbortOnRTE
		wave ID = dfr:ID; AbortOnRTE
		Make /O/D/N=(DimSize(FRAME, 0)) dfr:QTM_DENSITY;AbortOnRTE
		wave DENSITY=dfr:QTM_DENSITY;AbortOnRTE
		DENSITY=NaN
		
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
						tmp_frame[k][j+6]=w[i]; AbortOnRTE
					endfor
					InsertPoints /M=0 k+1, 1, tmp_frame; AbortOnRTE
					k+=1
				endif
			endfor
			if(k>0)
				DeletePoints /M=0 k, 1, tmp_frame; AbortOnRTE
				calculate_density(tmp_frame, density_diameter/2, cell_diameter/2, DENSITY); AbortOnRTE
				Duplicate /O tmp_frame, $("frame"+num2istr(frametbl_count)); AbortOnRTE
				frametbl_count+=1
			endif
		while(k>0)
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

Function QTM_Select_Frame()
	Variable minDensity=1, maxDensity=4 //number of cells per ROI circle
	
	PROMPT minDensity, "min density (number of cells per ROI circle)"
	PROMPT maxDensity, "max density (number of cells per ROI circle)"
	DoPrompt "Density color min and max", minDensity, maxDensity
	
	WaveBrowser("SelectFrameTable", "Select Frame Table", 100, 100, "Folder Name", "Table Name", 3, "root:", "", "CALLBACKFUNC:QTM_plot_framexy;FUNCPARAM:MIN="+num2str(minDensity)+",MAX="+num2str(maxDensity)+";", nameFilter="frame*")
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
function QTM_Split_track(wave trackid_tbl, wave trackid, wave id, wave posx, wave posy, wave frame, wave spot_src, wave spot_tg, [string optionalList, variable show_menu])

	Variable i
	
	variable tstbl_count=0, track_to_spotid_idx
	
	String dfName=UniqueName("SplittedTraces", 11, 0)
	
	DFREF dfr=GetDataFolderDFR()
	
	Variable avoid_frame_begin=0
	Variable avoid_frame_end=0
	Variable speed_frame_interval=1
	Variable time_interval=30 //sec
	
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
			print "working on track record #", i, "track id is: ", trackid_tbl[i][%ID]

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
			
			tmp_spot_src = spot_src[tr_ref_start-i+p]; AbortOnRTE
			tmp_spot_tg = spot_tg[tr_ref_start-i+p]; AbortOnRTE
	
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

function QTM_ExtractSummary(wave summary_tbl)

	Make /D/N=(DimSize(summary_tbl, 0))/O distance_summary, angle_summary
	
	distance_summary=summary_tbl[p][%TOTAL_DISTANCE]
	angle_summary=summary_tbl[p][%TOTAL_ANGLE]

end

