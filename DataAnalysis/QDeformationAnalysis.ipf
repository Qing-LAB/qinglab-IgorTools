#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function splitPeriod(wave w, variable length, variable remove_offset_flag, [variable startidx, variable endidx])
	string wname=NameOfWave(w)+"_split"
	string wname_stdev=NameOfWave(w)+"_split_stdev"
	
	Make /N=(length) /D /O $wname, $wname_stdev
	Make /N=(length, 1) /D /O /FREE tmp
	wave s=$wname
	wave e=$wname_stdev
	s=0
	
	variable offset=0
	variable count=0
	if(ParamIsDefault(startidx))
		startidx=0
	endif
	if(ParamIsDefault(endidx))
		endidx=inf
	endif
	
	do
		//s=s[p]+w[offset+p]
		if(count==0)
			tmp[][0]=w[offset+p]
		else
			insertpoints /M=1 inf, 1, tmp
			tmp[][count]=w[offset+p]
		endif
		offset+=length
		count+=1
	while(offset+length<=DimSize(w, 0))
	count=0
	
	variable i, j, stdev
	
	for(i=startidx; i<=endidx && i<dimsize(tmp, 1); i+=1)
		//print i
		s+=tmp[p][i]
		count+=1
	endfor

	s/=count
	
	for(i=0; i<length; i+=1)
		stdev=0
		for(j=0; j<DimSize(tmp, 1); j+=1)
			stdev+=(tmp[i][j]-s[i])^2
		endfor
		stdev/=DimSize(tmp, 1)-1
		e[i]=stdev
	endfor
	
	if(remove_offset_flag!=0)
		WaveStats /Q s
		s-=V_avg
	endif
end