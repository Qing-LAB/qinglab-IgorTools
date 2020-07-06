#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma ModuleName=QDataPeakAnalysis

Menu "&QingLabTools"
	Submenu "DataAnalysis"
		"ID Peaks...", print "id peaks"
		"Pair Peaks...",  print "pair peaks"
	End
End

static function qdp_find_next_peak(wave w, variable & count, variable pos_or_neg, variable average_w, variable & startx, variable & endx, variable threshold, variable boxsize, wave peaks, wave FWHMs, variable maxpeakwidth)
	if(pos_or_neg>0)
		FindPeak /B=(boxsize) /Q /M=(average_w+threshold)/R=(startx, endx) w
	else
		FindPeak /B=(boxsize) /Q /N /M=(average_w-threshold) /R=(startx, endx) w
	endif
	
	if(V_PeakLoc<endx) //a peak is found		
		if(count >= DimSize(peaks, 0))
			InsertPoints /M=0 inf, 1, peaks
			Insertpoints /M=0 inf, 1, FWHMs
		endif
				
		peaks[count][]=NaN
		peaks[count][%pkLoc_ByFP]=V_PeakLoc
		peaks[count][%pkVal_ByFP]=V_PeakVal
		peaks[count][%pkWidth_ByFP]=V_PeakWidth
			
		//find the real local maximum near the peak point found in previous step
		//and find the FWHM for each peak
		Wavestats /Q/R=(V_PeakLoc-deltax(w)*boxsize, V_PeakLoc+deltax(w)*boxsize) w //search the peak point within adjacent points
		if(pos_or_neg>0)
			peaks[count][%pkVal_ByStat] = V_max
			peaks[count][%pkLoc_ByStat] = V_maxLoc
			peaks[count][%pkRowLoc_ByStat] = V_maxRowLoc
		else
			peaks[count][%pkVal_ByStat] = V_min
			peaks[count][%pkLoc_ByStat] = V_minLoc
			peaks[count][%pkRowLoc_ByStat] = V_minRowLoc
		endif	
		
		Variable peakheight = peaks[count][%pkVal_ByStat] - average_w
		FWHMs[count][%pkHeight] = peakheight
		
		findlevel /B=1 /EDGE=0 /Q/R=(peaks[count][%pkLoc_ByStat]-deltax(w)*maxpeakwidth, peaks[count][%pkLoc_ByStat]) w, peakheight/2
		FWHMs[count][%lvX_left] = V_levelX
		findlevel /B=1 /EDGE=0 /Q/R=(peaks[count][%pkLoc_ByStat], peaks[count][%pkLoc_ByStat]+deltax(w)*maxpeakwidth) w, peakheight/2
		FWHMs[count][%lvX_right] = V_levelX
		FWHMs[count][%fwhm] = FWHMs[count][%lvX_right] - FWHMs[count][%lvX_left] //calculate FWHM
		
		startx=peaks[count][%pkLoc_ByStat]+deltax(w)*boxsize
		count=count+1
	else
		return -1
	endif
	
	return 0
end

function qdpIDPeaks(wave w, variable boxsize, string peak_direction, [variable threshold, variable maxpeakwidth, string suffix])
	variable startx=0, endx=deltax(w)*DimSize(w, 0)
	
	//calculate the wave average to determine the threshold of peak finding
	WaveStats /Q w
	Variable average_w=V_avg
	
	if(ParamIsDefault(threshold) || numtype(threshold)!=0)
		threshold=5*V_sdev
	endif
	print "stdev: ", V_sdev, ", we are using threshold of :", threshold
	
	if(ParamIsDefault(maxpeakwidth) || numtype(maxpeakwidth)!=0)
		maxpeakwidth=10*boxsize
	endif
	print "max peak width set to: ", maxpeakwidth, " points, corresponding to :", maxpeakwidth*deltax(w), " seconds"
	
	if(ParamIsDefault(suffix))
		suffix=""
	endif
	
	variable pos_or_neg=0
	
	strswitch(peak_direction)
	case "UPWARD":
	case "UP":
	case "POSITIVE":
	case "+":
		pos_or_neg=1
		break
	case "NEGATIVE":
	case "DOWN":
	case "DOWNWARD":
	case "-":
		pos_or_neg=-1
		break
	default:
		print "peak direction has to be either + or -"
		return -1
	endswitch
	
	string orig_name=NameOfWave(w)
	string peakinfoname, peak_FWHM_points
	
	if(pos_or_neg>0)
		peakinfoname=orig_name+"_pk_up"+suffix
		peak_FWHM_points=orig_name+"_fwhm_up"+suffix
	else
		peakinfoname=orig_name+"_pk_down"	
		peak_FWHM_points=orig_name+"_fwhm_down"
	endif
		
	Make /N=(1, 6) /O $peakinfoname
	WAVE peaks=$peakinfoname
	
	SetDimLabel 1, 0, pkLoc_ByFP, peaks
	SetDimLabel 1, 1, pkVal_ByFP, peaks
	SetDimLabel 1, 2, pkWidth_ByFP, peaks
	SetDimLabel 1, 3, pkLoc_ByStat, peaks
	SetDimLabel 1, 4, pkVal_ByStat, peaks
	SetDimLabel 1, 5, pkRowLoc_ByStat, peaks
	
	//find the FWHM point before and after each point
	make /N=(1,4) /O $peak_FWHM_points
	wave FWHMs=$peak_FWHM_points
	SetDimLabel 1, 0, lvX_left, FWHMs
	SetDimLabel 1, 1, lvX_right, FWHMs
	SetDimLabel 1, 2, fwhm, FWHMs
	SetDimLabel 1, 3, pkHeight, FWHMs

	variable count=0
	variable flag=0
	do
		variable old_startx=startx
		flag=qdp_find_next_peak(w, \
								count, \
								pos_or_neg, \
								average_w, \
								startx, \
								endx, \
								threshold, \
								boxsize, \
								peaks, \
								FWHMs, \
								maxpeakwidth)
		//print "flag: ", flag, "count: ", count, "next start point: ", startx
		if(old_startx==startx) //got stuck
			startx=old_startx+deltax(w)*boxsize
		endif
	while(flag>=0 && startx<endx)	
end

function qdpPairPeaks(wave pk1, wave fwhm1, wave pk2, wave fwhm2, string combined_name)
	variable i, j, flag, count
	Make /O /N=(1, 8) $combined_name
	wave w=$combined_name
	
	SetDimLabel 1, 0, pk1_loc, w
	SetDimLabel 1, 1, pk2_loc, w
	SetDimLabel 1, 2, pk1_width, w
	SetDimLabel 1, 3, pk2_width, w
	SetDimLabel 1, 4, pk1_height, w
	SetDimLabel 1, 5, pk2_height, w
	SetDimLabel 1, 6, pk2_pk1Diff, w
	SetDimLabel 1, 7, pk2_pk1WidthDiff, w
	
	j=0
	flag=0
	count=0
	for(i=0; i<DimSize(pk1, 0) && j<DimSize(pk2, 0); i+=1)
		variable pk1loc=pk1[i][%pkLoc_byFP]
		variable pk1height=fwhm1[i][%pkHeight]
		variable pk1width=fwhm1[i][%fwhm]
		do
			variable pk2loc=pk2[j][%pkLoc_byFP]
			variable pk2height=fwhm2[j][%pkHeight]
			variable pk2width=fwhm2[j][%fwhm]
			variable threshold=pk1width+pk2width
			
			if(abs(pk2loc-pk1loc)<threshold)
				flag = 1
				if(count>0)
					InsertPoints /M=0 inf, 1, w
				endif
				w[count][%pk1_loc]=pk1loc
				w[count][%pk2_loc]=pk2loc
				w[count][%pk1_width]=pk1width
				w[count][%pk2_width]=pk2width
				w[count][%pk1_height]=pk1height
				w[count][%pk2_height]=pk2height
				w[count][%pk2_pk1Diff]=pk2loc-pk1loc
				w[count][%pk2_pk1WidthDiff]=pk2width-pk1width
				
				count += 1
			elseif(pk2loc>pk1loc)
				flag = -1
			else
				j+=1
				
				if(j>=DimSize(pk2, 0))
					flag = -1
				else
					flag = 0
				endif
			endif
		while(flag==0)
	endfor
end

