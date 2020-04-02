#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma ModuleName=QImageAnalysisUFPs

//user function prototypes

Constant QIPUFP_IMAGEFUNC_MAINIMAGE=0x1
Constant QIPUFP_IMAGEFUNC_OVERLAYIMAGE_RED=0x2
Constant QIPUFP_IMAGEFUNC_OVERLAYIMAGE_GREEN=0x4
Constant QIPUFP_IMAGEFUNC_OVERLAYIMAGE_BLUE=0x8
Constant QIPUFP_IMAGEFUNC_REDRAWUPDATE=0x100
Constant QIPUFP_IMAGEFUNC_INIT=0x200
Constant QIPUFP_IMAGEFUNC_PREPROCESSING=0x400
Constant QIPUFP_IMAGEFUNC_POSTPROCESSING=0x800
Constant QIPUFP_IMAGEFUNC_FINALIZE=0x1000

Constant QIPUF_DEFAULT_ALPHA_RED = 0.701
Constant QIPUF_DEFAULT_ALPHA_GREEN = 0.413
Constant QIPUF_DEFAULT_ALPHA_BLUE = 0.886
Constant QIPUF_DEFAULT_ALPHA_GRAY = 1

//functions for processing image stacks and frame data
Function QIPUF_CalculateFluorescenceRatio(Wave srcImage, Wave frameImage, String graphname, Variable frameidx, Variable request)
	try
		if(request & QIPUFP_IMAGEFUNC_REDRAWUPDATE) //normal process of updating frame data
			qipGraphPanelExtractSingleFrameFromImage(srcImage, GetWavesDataFolder(frameImage, 2), frameidx)
		endif
		
		if(request & QIPUFP_IMAGEFUNC_INIT) //prepare for variables etc
		//by default nothing is done here
		endif
		
		if(request & QIPUFP_IMAGEFUNC_POSTPROCESSING)
			Variable i
			Wave PointROI=:ROI:W_PointROI
			Wave ratio=root:W_FluorecenceRatio
			
			if(WaveExists(srcImage) && WaveExists(PointROI))
			
				Variable width=DimSize(frameImage, 0)
				Variable height=DimSize(frameImage, 1)
				
				if(!WaveExists(ratio) || (DimSize(ratio, 0)!=DimSize(srcImage, 2)) || (DimSize(ratio, 1) !=DimSize(PointROI, 0)))
					Make /O/N=(DimSize(srcImage, 2), DimSize(PointROI, 0)) root:W_FluorecenceRatio=NaN
				endif
				
				Wave ratio=root:W_FluorecenceRatio
				
				Variable inner_boundary_len, inner_boundary_dotproduct
				Variable outer_boundary_len, outer_boundary_dotproduct
				String homedf=GetDataFolder(1)
				
				for(i=0; i<DimSize(PointROI, 0); i+=1)
					if(numtype(PointROI[i][0])==0)
						String name=":ROI:PointROIObjEdges:"+PossiblyQuoteName("W_ROIBoundary"+num2istr(i)+".I")
						Wave b=$name

						if(WaveExists(b))
							GetBoundaryMaskProduct(frameImage, b, width, height, inner_boundary_len, inner_boundary_dotproduct)
						endif
						name=":ROI:PointROIObjEdges:"+PossiblyQuoteName("W_ROIBoundary"+num2istr(i)+".O")
						Wave b=$name
						if(WaveExists(b))
							GetBoundaryMaskProduct(frameImage, b, width, height, outer_boundary_len, outer_boundary_dotproduct)
						endif
						ratio[frameidx][i]=(outer_boundary_dotproduct/outer_boundary_len)/(inner_boundary_dotproduct/inner_boundary_len)
					endif
				endfor
			endif
		endif
		
		if(request & QIPUFP_IMAGEFUNC_FINALIZE)
		//by default nothing is done here
		endif
		
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
End

Static Function GetBoundaryMaskProduct(Wave img, Wave boundary, Variable width, Variable height, Variable & boundary_len, Variable & boundary_dotproduct)
	Make /FREE /D/N=(DimSize(boundary, 0)) tmpx, tmpy
	tmpx=boundary[p][0]
	tmpy=boundary[p][1]
	ImageBoundaryToMask width=width, height=height, xwave=tmpx, ywave=tmpy
	Wave M_ROIMask
	WaveStats /Q M_ROIMASK
	M_ROIMASK/=V_Max
	Redimension/Y=(WaveType(img)) M_ROIMask
	boundary_len=sum(M_ROIMask)
	MatrixOp /FREE tmpProduct = M_ROIMask.img
	boundary_dotproduct=tmpProduct[0]
End


//functions for processing image stacks and frame data
Function qipUFP_IMGFUNC_DEFAULT(Wave srcImage, Wave frameImage, String graphname, Variable frameidx, Variable request)
	try
		if(request & QIPUFP_IMAGEFUNC_REDRAWUPDATE) //normal process of updating frame data
			qipGraphPanelExtractSingleFrameFromImage(srcImage, GetWavesDataFolder(frameImage, 2), frameidx)
		endif
		if(((request & 0xFF)==QIPUFP_IMAGEFUNC_MAINIMAGE) && (request & QIPUFP_IMAGEFUNC_PREPROCESSING)) 
		//for main image, will perform filtering as pre-processing of edge detection
			MatrixFilter /N=3 /P=3 gauss frameImage
		endif
		//by default, there is no postprocessing done
	catch
		Variable err=GetRTError(1)
	endtry
	return 0
End

//prototype for modifying traces used in hook function
Function qipUFP_MODIFYFUNC(Wave wave_for_mod, Variable index, Variable new_x, Variable new_y, Variable flag)
	return 0
End


//prototype for save function when traces are marked as "need for saving"
Function qipUFP_SAVEFUNC(Wave wave_for_save, String graphname, Variable frameidx, Variable flag)
	return 0
End

//save dot ROIs
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

//save middle edges of selected object
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

//save inner edges of selected object
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

//save outer edges of selected objective
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
			wavenote=ReplaceStringByKey("TRACEMODIFIED", wavenote, "1"); AbortOnRTE
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
		wavenote=ReplaceStringByKey("TRACEMODIFIED", wavenote, "1"); AbortOnRTE
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
