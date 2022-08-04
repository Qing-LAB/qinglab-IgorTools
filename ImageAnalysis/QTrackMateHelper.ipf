#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <New Polar Graphs>

Menu "QTrackMateHelper"
	"Load TrackMate CSV file", QTM_load_track_file()
	"Generate lookup table", QTM_trackid_lookuptbl(TRACK_ID, POSITION_X, POSITION_Y, FRAME, SPOT_SOURCE_ID, SPOT_TARGET_ID)
	"Disassemble tracks", QTM_disassemble_track(trackid_tbl, TRACK_ID, ID, POSITION_X, POSITION_Y, FRAME, SPOT_SOURCE_ID, SPOT_TARGET_ID)
	"Summarize table", QTM_summarize_tbl("", -1, -1)
	"Velocity histogram per frame", velocity_summary("", 0, 100, 10, 0.02, 500)
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

function QTM_trackid_lookuptbl(wave trackid, wave posx, wave posy, wave frame, wave spot_src, wave spot_target)

	Redimension/L frame, trackid
	Redimension/L spot_src, spot_target

	WaveStats /Q trackid
	variable max_id=V_max, min_id=V_min
	variable tbl_len=(max_id-min_id)+1
	
	Make /O/D/N=(tbl_len, 13) trackid_tbl=NaN
	
	SetDimLabel 1, 0, ID, trackid_tbl
	SetDimLabel 1, 1, finalID, trackid_tbl
	SetDimLabel 1, 2, startFrame, trackid_tbl
	SetDimLabel 1, 3, endFrame, trackid_tbl
	SetDimLabel 1, 4, startPosX, trackid_tbl
	SetDimLabel 1, 5, startPosY, trackid_tbl
	SetDimLabel 1, 6, endPosX, trackid_tbl
	SetDimLabel 1, 7, endPosY, trackid_tbl
	SetDimLabel 1, 8, refIdxStart, trackid_tbl
	SetDimLabel 1, 9, refIdxEnd, trackid_tbl
	SetDimLabel 1, 10, frameLen, trackid_tbl
	SetDimLabel 1, 11, totalDistance, trackid_tbl
	SetDimLabel 1, 12, totalAngle, trackid_tbl
	
	Variable refidx=0, tr_id=NaN, new_track_flag=0
	Variable tbl_counter=-1
	
	do
	
		if(refidx>=DimSize(trackid, 0) || trackid[refidx]!=tr_id)
		//track_id at refidx in trackid table is not the same as previous, or reached beyond the end of tbl
			if(new_track_flag==0) // this means we are hitting a new track_id
				if(refidx!=0) //not the first one, we need to then check back one more refidx to close the previous one
					trackid_tbl[tbl_counter][%endFrame]=frame[refidx-1]
					trackid_tbl[tbl_counter][%endPosX]=posx[refidx-1]
					trackid_tbl[tbl_counter][%endPosY]=posy[refidx-1]
					trackid_tbl[tbl_counter][%refIdxEnd]=refidx-1
					trackid_tbl[tbl_counter][%frameLen]=trackid_tbl[tbl_counter][%endFrame]-trackid_tbl[tbl_counter][%startFrame]
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
					trackid_tbl[tbl_counter][%finalID]=-1
					trackid_tbl[tbl_counter][%startFrame]=frame[refidx]
					trackid_tbl[tbl_counter][%startPosX]=posx[refidx]
					trackid_tbl[tbl_counter][%startPosY]=posy[refidx]
					trackid_tbl[tbl_counter][%refIdxStart]=refidx
					new_track_flag=1
				endif
			else //then something is wrong
				print "this should not happen."
				print "this could mean that for the previous track, there is only one frame."
				print "refidx=", refidx
				print "trackid[refidx]=", trackid[refidx]
				print "tr_id=", tr_id
			endif
			refidx+=1
		else //track_id at refidx is the same as previous record
			if(new_track_flag==1) //this was taken care of
				new_track_flag=0 //take the flag down, just keep going forward
			endif
			refidx+=1
		endif
	while(refidx<=DimSize(trackid, 0))
	
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

static function find_value(wave w, variable value)
	variable i
	
	for(i=0; i<DimSize(w, 0); i+=1)
		if(w[i]==value)
			return i
		endif
	endfor
	
	return -1
end

function QTM_disassemble_track(wave trackid_tbl, wave trackid, wave id, wave posx, wave posy, wave frame, wave spot_src, wave spot_tg)

	Variable i
	
	variable tstbl_count=0
	
	String dfName=UniqueName("SplittedTraces", 11, 0)
	
	DFREF dfr=GetDataFolderDFR()

	try	
		NewDataFolder /S $dfName; AbortOnRTE
		
		for(i=0; i<DimSize(trackid_tbl, 0); i+=1)
			
			Variable tr_ref_start=trackid_tbl[i][%refIdxStart]; AbortOnRTE
			Variable tr_ref_end=trackid_tbl[i][%refIdxEnd]; AbortOnRTE
			Variable tr_frame_start=trackid_tbl[i][%startFrame]; AbortOnRTE
			Variable tr_frame_end=trackid_tbl[i][%endFrame]; AbortOnRTE
			
			Variable tr_totallen=tr_ref_end - tr_ref_start+1
			Variable tr_totalframe=tr_frame_end - tr_frame_start+1
			
			Make /FREE/L/N=(tr_totallen) tmp_frames=-1, tmp_flag=-1, tmp_spot_id=-1, tmp_spot_src=-1, tmp_spot_tg=-1; AbortOnRTE
			Make /FREE/D/N=(tr_totallen) tmp_posx, tmp_posy; AbortOnRTE
			
			tmp_frames=frame[tr_ref_start+p]; AbortOnRTE
			tmp_spot_id[]=id[tr_ref_start+p]; AbortOnRTE
			tmp_posx[]=posx[tr_ref_start+p]; AbortOnRTE
			tmp_posy[]=posy[tr_ref_start+p]; AbortOnRTE
			
			tmp_spot_src[0, tr_totallen-2]=spot_src[tr_ref_start-i+p]; AbortOnRTE
			tmp_spot_tg[0, tr_totallen-2]=spot_tg[tr_ref_start-i+p]; AbortOnRTE
			
			FindDuplicates /FREE /DN=tmp_dup_src tmp_spot_src; AbortOnRTE
			
			print "working on track record #", i

			variable tmp_start_pos=0
			variable tmp_tr_position

			do
						
				if(tmp_flag[tmp_start_pos]<0) //the spot has not been covered, indicating a start
				
					Make /D/N=(tr_totalframe, 5) $("tr_"+num2istr(tstbl_count)); AbortOnRTE
					wave tr=$("tr_"+num2istr(tstbl_count)); AbortOnRTE
					
					SetDimLabel 1, 0, ORIG_TRACK_ID, tr
					SetDimLabel 1, 1, FRAME_IDX, tr
					SetDimLabel 1, 2, POSX, tr
					SetDimLabel 1, 3, POSY, tr
					SetDimLabel 1, 4, SPOT_ID, tr; AbortOnRTE
					
					tmp_tr_position=tmp_start_pos
					Variable tr_counter=0
					tr[][%ORIG_TRACK_ID]=i; AbortOnRTE
					
					do
						tmp_flag[tmp_tr_position]=tstbl_count
						
						tr[tr_counter][%FRAME_IDX]=tmp_frames[tmp_tr_position]; AbortOnRTE
						tr[tr_counter][%POSX]=tmp_posx[tmp_tr_position]; AbortOnRTE
						tr[tr_counter][%POSY]=tmp_posy[tmp_tr_position]; AbortOnRTE
						tr[tr_counter][%SPOT_ID]=tmp_spot_id[tmp_tr_position]; AbortOnRTE
						tr_counter+=1
						
						if(find_value(tmp_dup_src, tmp_spot_id[tmp_tr_position])>=0) //this spot is a src for multiple
							break //then this trace should stop here
						else //get to the next spot in the link chain
							variable target_id_pos, target_id
							
							target_id_pos=find_value(tmp_spot_src, tmp_spot_id[tmp_tr_position])
							
							if(target_id_pos>=0)
								
								target_id=tmp_spot_tg[target_id_pos]
								
								if(target_id>=0)
									tmp_tr_position=find_value(tmp_spot_id, target_id) //position of the next target ID	
								else
									//this should be the last point because this node has no further target.
									tmp_tr_position=-1
									break
								endif
							else
								break //this should be the last point because this node is not source to any children nodes
							endif
						endif
									
					while(tmp_tr_position<tr_totallen)
					
					DeletePoints tr_counter, inf, tr
					
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

function QTM_velocity_summary(String DFName, variable start_frame, variable end_frame, Variable time_interval, Variable velocity_hist_binsize, Variable velocity_hist_binnum)
	DFREF dfr=GetDataFolderDFR()

	if(strlen(DFName)<=0)
		String foldername=DFName
		Variable fr_threshold=10
		
		String folderList=DataFolderDir(1)
		folderList=StringByKey("FOLDERS", folderList, ":", ";")
		folderList=ReplaceString(",", folderList, ";")
		PROMPT foldername, "Data Folder Name that contains the tracks", popup folderList
		PROMPT start_frame, "Start from Frame#"
		PROMPT end_frame, "End at Frame#"
		PROMPT time_interval, "Time interval between frames"
		PROMPT velocity_hist_binsize, "Histogram bin size for velocity"
		PROMPT velocity_hist_binnum, "Histogram number of bins"
		
		DoPROMPT "Please enter the following values", foldername, start_frame, end_frame, time_interval, velocity_hist_binsize, velocity_hist_binnum
		if(V_flag==0 && DataFolderExists(foldername))
			DFName=foldername
		else
			return -1
		endif
	endif
	
	try
	
		SetDataFolder $DFName; AbortOnRTE
		variable i, j, k
		String trackList=WaveList("tr_*", ";", "DF:0");
		variable track_number=ItemsInList(trackList)
		Make /D/N=(track_number)/FREE tmp_velocity
		
		Make /D/N=(end_frame-start_frame+1, velocity_hist_binnum)/O velocity_histogram_summary=NaN
		wave vtbl=velocity_histogram_summary
		
		for(i=start_frame; i<=end_frame; i+=1)
			
			tmp_velocity=NaN
			
			for(j=0; j<track_number; j+=1)
			
				wave tr=$StringFromList(j, trackList)
				
				if(WaveExists(tr))
					
					for(k=0; k<DimSize(tr, 0); k+=1)
					
						if(tr[k][%FRAME_IDX]==i)
							
							if(k-1>=0)
								
								Variable x0, y0, x1, y1, t, velocity
								
								x0=tr[k-1][%POSX]
								y0=tr[k-1][%POSY]
								x1=tr[k][%POSX]
								y1=tr[k][%POSY]
								
								t=tr[k][%FRAME_IDX]-tr[k-1][%FRAME_IDX]
								t=t * time_interval
								
								velocity=distance(x0, y0, x1, y1)/t
								tmp_velocity[j]=velocity
								
							endif
							
						endif
					
					endfor
					
				endif
			
			endfor
			
			Make/N=(velocity_hist_binnum)/D/FREE tmp_hist
			Histogram/B={0,velocity_hist_binsize,velocity_hist_binnum} tmp_velocity, tmp_hist
			variable total_pnt=sum(tmp_hist)
			tmp_hist/=total_pnt
			vtbl[i-start_frame][]=tmp_hist[q]
			SetScale /P y, leftx(tmp_hist), deltax(tmp_hist), "um/min", vtbl
		endfor
		
	catch
	
		Variable err=GetRTError(1)
		
		if(err!=0)
			print "Error catched:"
			print GetErrMessage(err)
		endif
		
	endtry
	
	SetDataFolder dfr
end

