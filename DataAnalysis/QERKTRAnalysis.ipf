#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function LoadExcelNumericDataAsMatrix(pathName, fileName, worksheetName, [startCell, endCell])
	String pathName		// Name of Igor symbolic path or "" to get dialog
	String fileName		// Name of file to load or "" to get dialog
	String worksheetName
	String startCell		// e.g., "B1"
	String endCell			// e.g., "J100"
	
	if ((strlen(pathName)==0) || (strlen(fileName)==0))
		// Display dialog looking for file.
		Variable refNum
		String filters = "Excel Files (*.xls,*.xlsx,*.xlsm):.xls,.xlsx,.xlsm;"
		filters += "All Files:.*;"
		Open/D/R/P=$pathName /F=filters refNum as fileName
		fileName = S_fileName			// S_fileName is set by Open/D
		if (strlen(fileName) == 0)		// User cancelled?
			return -2
		endif
	endif
	
	if(ParamIsDefault(startCell) && ParamIsDefault(endCell))
		startCell="ALLCELLS"
		endCell="ALLCELLS"
		XLLoadWave /S=worksheetName /COLT="N"/O/V=0/K=0/Q fileName
	else
	// Load row 1 into numeric waves
		XLLoadWave/S=worksheetName/R=($startCell,$endCell)/COLT="N"/O/V=0/K=0/Q fileName
	endif
	
	if (V_flag == 0)
		return -1			// User cancelled
	endif

	String names = S_waveNames	// S_waveNames is created by XLLoadWave
	String nameOut = UniqueName("Matrix", 1, 0)
	Concatenate /KILL /O names, $nameOut	// Create matrix and kill 1D waves
	
	String format = "Created numeric matrix wave %s containing cells %s to %s in worksheet \"%s\"\r"
	Printf format, nameOut, startCell, endCell, worksheetName
End

Function TrackERKTR(wave w, variable start_timeindex, variable end_timeindex, variable delta_timeindex)
	
	Variable i=0
	Variable t=start_timeindex
	Variable total_cell=0
	Variable c=0, s=0
	
	for(; i<DimSize(w, 0) && w[i][0]<t; i+=1)
	endfor
	
	Make /O /D /N=(1, 4, 1) CellSummary // id, centerx, centery, ERKTR
	for(; i<DimSize(w, 0) && w[i][0]==t; i+=1)
		if(c!=0)
			InsertPoints /M=0 DimSize(CellSummary, 0), 1, CellSummary
		endif
		CellSummary[c][0][0]=w[i][3]
		CellSummary[c][1][0]=w[i][4]
		CellSummary[c][2][0]=w[i][5]
		CellSummary[c][3][0]=w[i][7]
		c+=1
	endfor
	total_cell=c
	c=0
	
	if(total_cell==0)
		print "no frame is within the time index range."
		return 0
	endif
	
	print "total cell to be tracked:", total_cell
	if(i>=DimSize(w, 0))
		return 0
	endif
	
	do
		t+=delta_timeindex
		variable previous_i=i
		for(; i<DimSize(w, 0) && w[i][0]<=t; i+=1)
		endfor
		InsertPoints /M=2 Inf, 1, CellSummary
		s+=1
		for(c=0; c<total_cell; c+=1)
			variable r=search_best_record(CellSummary[c][1][s-1], CellSummary[c][2][s-1], w, previous_i, i)
			if(r>=0)
				CellSummary[c][0][s]=w[r][3]
				CellSummary[c][1][s]=w[r][4]
				CellSummary[c][2][s]=w[r][5]
				CellSummary[c][3][s]=w[r][7]
			else
				print "strange. cannot find a match for cell ", c
			endif
		endfor
		
	while(t<=end_timeindex && i<DimSize(w, 0))

End

Function search_best_record(variable x, variable y, wave w, variable starti, variable endi)
	Variable distance=Inf
	Variable i
	Variable r=-1
	for(i=starti; i<DimSize(w, 0) && i<=endi; i+=1)
		Variable d=(x-w[i][4])^2+(y-w[i][5])^2
		if(d<distance)
			r=i
			distance=d
		endif
	endfor
	return r
End

Function appendTrace(wave w, variable startid, variable endid, string ex_id_str, Variable threshold)
	Variable id
	Variable c=0
	
	Variable j
	Make /O/N=(1, DimSize(w, 2)) AverageRecord=0
	Make /O/N=1 AverageRecordFlag=NaN
	Make /O/N=(2, endid-startid+2) CellWithResponse, CellWithoutResponse, CellExcluded
	Make /FREE /N=(DimSize(w, 2)) tmp
	CellWithResponse=NaN
	CellWithoutResponse=NaN
	CellExcluded=NaN
	display
	for(id=startid; id<endid; id+=1)
		variable ex_id_idx=FindListItem(num2istr(id), ex_id_str)
		
		if(ex_id_idx<0)
			for(j=0; j<DimSize(w, 0); j+=1)
				if(id==w[j][0][0])
					if(c>0)
						InsertPoints /M=0 inf, 1, AverageRecord, AverageRecordFlag
					endif
					AverageRecord[c][]=w[j][3][q]
					AverageRecordFlag[c]=0
					
					tmp[]=AverageRecord[c][p]
					WaveStats /Q tmp
					if(V_sdev>threshold)
						CellWithResponse[0][id]=w[j][1][0]
						CellWithResponse[1][id]=w[j][2][0]
						print "setting cell with response :", id
						AverageRecordFlag[c]=1
					else
						CellWithoutResponse[0][id]=w[j][1][0]
						CellWithoutResponse[1][id]=w[j][2][0]
						print "setting cell without response :", id
					endif
					String name="CELL_"+num2istr(id)
					AppendToGraph w[j][3][]/TN=$name
					if(AverageRecordFlag[c])
						ModifyGraph rgb($name)=(65535,0,0)
					else
						ModifyGraph rgb($name)=(0,0,65535)
					endif
					c+=1
					print "ID ", id, " found at index ", j, " stdev: ", V_sdev
					break
				endif
			endfor
		else
			CellExcluded[0][id]=w[j][1][0]
			CellExcluded[1][id]=w[j][2][0]
			print "Cell excluded explicitly:", id
		endif
	endfor
End

Function getAvgStat(wave record, string avgwavename, [wave flag])
//by default, all records are used for averaging
//if flag is set, only use records that are marked as responsive (flag[]=1)
	string avgErrName=avgwavename+"_stdev"
	variable totalnum
	if(ParamIsDefault(flag))
		SumDimension /D=0 /DEST=$avgwavename record
		wave avgw=$avgwavename
		totalnum=DimSize(record, 0)
		Make /FREE /N=(DimSize(record, 0)) tmpflag=1
	else
		Duplicate /FREE record, tmprecord
		tmprecord=record[p][q]*flag[p]
		SumDimension /D=0 /DEST=$avgwavename tmprecord
		wave avgw=$avgwavename
		totalnum=sum(flag)
		Duplicate /FREE flag, tmpflag
	endif
	avgw/=totalnum
	Make /FREE /D /N=(DimSize(record, 0), DimSize(record, 1)) avg_cal
	avg_cal=avgw[q]
	MatrixOP /O /FREE diff=record-avg_cal
	MatrixOP /O /FREE diff=diff*diff
	MatrixOP /O /FREE stdev=sqrt(sumCols(diff)/(totalnum-1))
	Duplicate /O stdev, $avgErrName
End

Function setupLinkedTrace(string graphname, string summarywavename)
	NewPanel /EXT=2 /HOST=$graphname /W=(0,0,400,150) /N=linkedTrace
	SetWindow $graphname, userdata(TRACEWINDOW)=S_Name
	SetWindow $graphname, userdata(SUMMARYWAVE)=summarywavename
	SetWindow $graphname, hook(linkedTrace)=hookLinkedTrace	
	wave w=$summarywavename
	Make /O/N=(DimSize(w, 2)) root:W_linkedTrace=NaN
	Display /HOST=$(graphname+"#"+S_Name) /W=(0,0,1,1) root:W_linkedTrace
End

Function hookLinkedTrace(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0

	switch(s.eventCode)
		case 0: //activated
		case 7: //cursor moved
			string curinfo=CsrInfo(A, s.WinName)
			string trName=StringByKey("TNAME", curinfo)
			Variable xpt=str2num(StringByKey("POINT", curinfo))
			
			if(numtype(xpt)==0)
				try
					wave w=$GetUserData(s.WinName, "", "SUMMARYWAVE")
					Make /O/N=(DimSize(w, 2)) root:W_linkedTrace=NaN
					wave t=root:W_linkedTrace
					t=w[xpt][3][p]
				catch
					variable e=GetRTError(1)
					print "error in getting trace updated.", GetErrMessage(e)
				endtry
			endif
			break
	endswitch

	return hookResult		// 0 if nothing done, else 1
End

Function normalizeTraceImage(wave w, [variable offset])

	variable i
	variable c
	if(ParamIsDefault(offset))
		offset=0
	endif
	for(i=0; i<DimSize(w, 0); i+=1)
		c=w[i][offset]
		w[i][]=w[i][q]/c		
	endfor
	
	MatrixOP /O w=w^t	
End

