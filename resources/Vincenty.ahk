#NoEnv
#SingleInstance on
SetFormat Float, 0.16e						 


pi  = 3.141592653589793238462643383279502884197169399375105820974944592 ; pi			 
;---------------------------------------------------------------------------------------
;*Calculates geodetic distance between two points specified by latitude/longitude using 
;*       Vincenty inverse formula for ellipsoids

;*     param   {Number} lat1, lon1: first point in decimal degrees
;*     param   {Number} lat2, lon2: second point in decimal degrees
;*    returns  (Number} distance in metres between points

;*Translated  from Vincenty Inverse Solution of Geodesics on the Ellipsoid (c) Chris Veness 2002-2012
;*Some modifications as per Wikipedia on Calculation of MajA and MajB
;*See http://www.movable-t...g-vincenty.html
InvVincenty(lat1, lon1, lat2, lon2)
{
; // WGS-84 ellipsoid params
	a := 6378137
	b := 6356752.314245
	f := 1 / 298.257223563  
	
	L := dtr(lon2-lon1)
   U1 := atan((1-f) * tan(dtr(lat1)))
   U2 := atan((1-f) * tan(dtr(lat2)))
sinU1 := sin(U1)
cosU1 := cos(U1)
sinU2 := sin(U2)
cosU2 := cos(U2)
  
lambda := L
lambdaP :=0
iterLimit := 100
While( abs(lambda - lambdaP) > 0.000000000001 and iterLimit > 0)
  {
         sinLambda := sin(lambda)
		 cosLambda := cos(lambda)
          sinSigma := Sqrt((cosU2 * sinLambda) * (cosU2 * sinLambda) + (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda) * (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda))
		 if (sinSigma = 0)
		   return 0
           cosSigma := sinU1 * sinU2 + cosU1 * cosU2 * cosLambda
              sigma := atan2(sinSigma , cosSigma)
		   sinAlpha := cosU1 * cosU2 * sinLambda / sinSigma
         cosSqAlpha := 1 - sinAlpha * sinAlpha
         cos2SigmaM := cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha
         if (isNaN(cos2SigmaM))
		   cos2SigmaM := 0
                C := f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha))
          lambdaP := lambda
           lambda := L + (1 - C) * f * sinAlpha * (sigma + C * sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
		iterLimit := iterLimit - 1
		
  } 

  if (iterLimit = 0)
     return NaN
	 
       uSq := cosSqAlpha * (a * a - b * b) / (b * b)
        k1 := (Sqrt(1 + uSq) -1) / (Sqrt(1 + uSq) +1)
      MajA := (1 + (k1 * k1) / 4) / (1 - k1)
      MajB := k1 * (1 - (3 * k1 * k1 / 8))
deltaSigma := MajB * sinSigma * (cos2SigmaM + MajB / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)- MajB / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3  + 4 * cos2SigmaM * cos2SigmaM)))
         s := ( b * MajA * (sigma - deltaSigma))
     fwdAz := rtd(atan2(cosU2 * sinLambda, cosU1 * sinU2 -sinU1 * cosU2 * cosLambda)) ;If required add to return value
     revAz := rtd(atan2(cosU1*sinLambda, -sinU1*cosU2+cosU1*sinU2*cosLambda)) ;If required add to return value
	
  return s
 } 

;-------------------------------------------------------------------------------------
;* Calculates destination point given start point lat/long, azimut & distance, 
;* using Vincenty inverse formula for ellipsoids
;*
;* @param   {Number} lat1, Latitude of origin point in decimal degrees
;* @param   {Number} lon1, Longitude of origin point in decimal degrees
;* @param   {Number} InitAz: initial azimut of travel in decimal degrees
;* @param   {Number} dist: distance along azimut in metres
;* @returns (LatLon} Latitude and Longitude of destination point, comma separated.
;*
;*Translated  from Vincenty Inverse Solution of Geodesics on the Ellipsoid (c) Chris Veness 2002-2012
;*Some modifications as per Wikipedia on Calculation of MajA and MajB
;*See http://www.movable-t...nty-direct.html

dirVincenty(Lat1, Lon1, InitAz, Dist)
{
; // WGS-84 ellipsoid params
	a := 6378137
	b := 6356752.314245
	f := 1 / 298.257223563  
	Global pi
	    s := dist  
   alpha1 := dtr(InitAz)
sinAlpha1 := sin(alpha1)
cosAlpha1 := cos(alpha1)
	
    tanU1 := (1 - f) * tan(dtr(lat1))
    cosU1 := 1 / sqrt((1 + tanU1 * tanU1))
    sinU1 := tanU1 * cosU1
   sigma1 := atan2(tanU1, cosAlpha1)
 sinAlpha := cosU1 * sinAlpha1
cosSqAlpha:= (1 - sinAlpha * sinAlpha)
      uSq := cosSqAlpha * (a * a - b * b) / (b * b)
       k1 := (Sqrt(1 + uSq) -1) / (Sqrt(1 + uSq) +1)
     MajA := (1 + (k1 * k1) / 4) / (1 - k1)
     MajB := k1 * (1 - (3 * k1 * k1 / 8))

	sigma := s / (b * MajA)
   sigmaP := 2 * pi
   while( abs(sigma - sigmaP) > 0.000000000001)
	   { 
	     cos2SigmaM := cos(2 * sigma1 + sigma)
	       sinSigma := sin(sigma)
		   cosSigma := cos(sigma)
		 deltaSigma := MajB * sinSigma * (cos2SigmaM + MajB / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)- MajB / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3  + 4 * cos2SigmaM * cos2SigmaM)))
		     sigmaP := sigma
			  sigma := s / (b * MajA) + deltaSigma
	   }
	   
   tmp := sinU1 * sinSigma - cosU1 * cosSigma * cosAlpha1
  lat2 := rtd(atan2(sinU1 * cosSigma + cosU1 * sinSigma * cosAlpha1, (1 - f) * sqrt(sinAlpha * sinAlpha + tmp * tmp)))
lambda := atan2(sinSigma * sinAlpha1, cosU1 * cosSigma - sinU1 * sinSigma * cosAlpha1) 
     C := f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha))
	 L := lambda - (1 -C ) * f * sinAlpha * (sigma + C *sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
  lon2 := rtd(dtr(lon1) + L) 
FinalAz:= rtd(atan2(sinAlpha, -tmp)) ; If required add to return value
 
 return % lat2 ", " lon2
}


;--------------------------------------------------------------------------------------
atan2(y,x) {	; 4-quadrant atan
   Return dllcall("msvcrt\atan2","Double",y, "Double",x, "CDECL Double")
}
;--------------------------------------------------------------------------------------
dtr(x){
   global pi
   return (x * pi / 180)
  
}  
;--------------------------------------------------------------------------------------
rtd(x){
  global pi
  return (x * 180 / pi)
} 
;---------------------------------------------------------------------------------------
 isNaN(x){    
   if x is number
      return false 
   else	  
      return true 
   } 
;-----------------------------------------------------------------------------------------
; Function for transforming decimal degrees to Deg min and seconds 
; by David Tryse   davidtryse@gmail.com
; http://david.tryse.net/googleearth/
; http://code.google.c...rth-autohotkey/

; call with latvar=Deg2Dec(decimalcoord,"lat") or latlong=Dec2Deg("-10.4949666667,105.5996")
; Input: -10.4949666667  105.5996   or    -10.4949666667,105.5996
; Output: 10° 29' 41.88'' S, 105° 35' 58.56'' E

Dec2Deg(DecCoord, mode = "both") {
	StringReplace DecCoord,DecCoord,`",%A_Space%,All
	StringReplace DecCoord,DecCoord,`,,%A_Space%,All
	StringReplace DecCoord,DecCoord,:,%A_Space%,All
	StringReplace DecCoord,DecCoord,%A_Tab%,%A_Space%,All
	Loop {   ; loop to replace all double spaces (otherwise StringSplit wont work properly)
		StringReplace DecCoord,DecCoord,%A_Space%%A_Space%,%A_Space%,All UseErrorLevel
		if ErrorLevel = 0  ; No more replacements needed.
			break
	}
	DecCoord = %DecCoord%  ; remove start/end spaces
	StringSplit word, DecCoord, %A_Space%`,%A_Tab%
	LatDeg := Floor(word1**2**0.5)
	LatMin := Floor((word1**2**0.5 - LatDeg) * 60)
	LatSec := Round((word1**2**0.5 - LatDeg - LatMin/60) * 60 * 60,2)
	LatPol = N
	If (word1 < 0)
		LatPol = S
	Lat := LatDeg "° " LatMin "' " LatSec "'' " LatPol
	LongDeg := Floor(word2**2**0.5)
	LongMin := Floor((word2**2**0.5 - LongDeg) * 60)
	LongSec := Round((word2**2**0.5 - LongDeg - LongMin/60) * 60 * 60,2)
	LongPol = E
	If (word2 < 0)
		LongPol = W
	Long := LongDeg "° " LongMin "' " LongSec "'' " LongPol
	If mode = lat
		return Lat
	If mode = long
		return Long
	If mode = both
		return Lat ", " Long
}
;------------------------------------------------------------------------------------------------------
; Function for transforming decimal degrees to Deg min and seconds 
; by David Tryse   davidtryse@gmail.com
; http://david.tryse.net/googleearth/
; http://code.google.c...rth-autohotkey/
; call with latvar=Deg2Dec(coord,"lat") or longvar=Deg2Dec(coord,"long") - no 2nd param returns lat, long
; Input should be Degrees Minutes Seconds in any of these formats:
;    8 deg 32' 54.73" South	119 deg 29' 28.98" East
;    8°32'54.73"S, 119°29'28.98"E
;    8:32:54S,119:29:28E
; Output: -8.548333, 119.491383
Deg2Dec(DegCoord, mode = "both") {
	StringReplace DegCoord,DegCoord,and,%A_Space%,All	; replace all possible separators with space before StringSplit
	StringReplace DegCoord,DegCoord,`,,%A_Space%,All
	StringReplace DegCoord,DegCoord,degrees,%A_Space%,All
	StringReplace DegCoord,DegCoord,degree,%A_Space%,All
	StringReplace DegCoord,DegCoord,degs,%A_Space%,All
	StringReplace DegCoord,DegCoord,deg,%A_Space%,All
	StringReplace DegCoord,DegCoord,d,%A_Space%,All
	StringReplace DegCoord,DegCoord,°,%A_Space%,All
	StringReplace DegCoord,DegCoord,º,%A_Space%,All
	StringReplace DegCoord,DegCoord,`;,%A_Space%,All
	StringReplace DegCoord,DegCoord,minutes,%A_Space%,All
	StringReplace DegCoord,DegCoord,minute,%A_Space%,All
	StringReplace DegCoord,DegCoord,mins,%A_Space%,All
	StringReplace DegCoord,DegCoord,min,%A_Space%,All
	StringReplace DegCoord,DegCoord,m,%A_Space%,All
	StringReplace DegCoord,DegCoord,',%A_Space%,All
	StringReplace DegCoord,DegCoord,seconds,%A_Space%,All
	StringReplace DegCoord,DegCoord,second,%A_Space%,All
	StringReplace DegCoord,DegCoord,secs,%A_Space%,All
	StringReplace DegCoord,DegCoord,sec,%A_Space%,All
	StringReplace DegCoord,DegCoord,`",%A_Space%,All
	StringReplace DegCoord,DegCoord,:,%A_Space%,All
	StringReplace DegCoord,DegCoord,S,%A_Space%S		; add space before south/west/north/east to separate as a new word
	StringReplace DegCoord,DegCoord,N,%A_Space%N
	StringReplace DegCoord,DegCoord,E,%A_Space%E
	StringReplace DegCoord,DegCoord,W,%A_Space%W
	StringReplace DegCoord,DegCoord,Ea st,East		; fix when previous S/South and E/East replace break up west/east words...
	StringReplace DegCoord,DegCoord,W e st,West
	StringReplace DegCoord,DegCoord,W est,West
	StringReplace DegCoord,DegCoord,%A_Tab%,%A_Space%,All
	Loop {  		 	; loop to replace all double spaces (otherwise StringSplit wont work properly)
		StringReplace DegCoord,DegCoord,%A_Space%%A_Space%,%A_Space%,All UseErrorLevel
		if ErrorLevel = 0 	; No more replacements needed.
			break
	}
	DegCoord = %DegCoord% 		; remove start/end spaces
	Lat :=
	Loop, parse, DegCoord, %A_Space%,
	{
		if (A_Index = 1)
			LatD := A_LoopField
		else if (A_Index = 2) and (A_LoopField = "S" or A_LoopField = "South")	; format is Deg
			Lat := LatD * -1
		else if (A_Index = 2) and (A_LoopField = "N" or A_LoopField = "North")	; format is Deg
			Lat := LatD * 1
		else if (A_Index = 2)
			LatM := A_LoopField
		else if (A_Index = 3) and (A_LoopField = "S" or A_LoopField = "South")	; format is Deg Min
			Lat := (LatD + LatM/60) * -1
		else if (A_Index = 3) and (A_LoopField = "N" or A_LoopField = "North")	; format is Deg Min
			Lat := (LatD + LatM/60) * 1
		else if (A_Index = 3)
			LatS := A_LoopField
		else if (A_Index = 4) and (A_LoopField = "S" or A_LoopField = "South")	; format is Deg Min Sec
			Lat := (LatD + LatM/60 + LatS/60/60) * -1
		else if (A_Index = 4) and (A_LoopField = "N" or A_LoopField = "North")	; format is Deg Min Sec
			Lat := (LatD + LatM/60 + LatS/60/60) * 1
		if (A_Index = 4 and not Lat)
			return "error"
		if (Lat) {
			LatEnd := A_Index		; save where Latitude ends - for Longitude loop
			Break
		}
	}
	Long :=
	Loop, parse, DegCoord, %A_Space%,
	{
		if (A_Index = LatEnd+1)
			LongD := A_LoopField
		else if (A_Index = LatEnd+2) and (A_LoopField = "W" or A_LoopField = "West")	; format is Deg
			Long := LongD * -1
		else if (A_Index = LatEnd+2) and (A_LoopField = "E" or A_LoopField = "East")	; format is Deg
			Long := LongD * 1
		else if (A_Index = LatEnd+2)
			LongM := A_LoopField
		else if (A_Index = LatEnd+3) and (A_LoopField = "W" or A_LoopField = "West")	; format is Deg Min
			Long := (LongD + LongM/60) * -1
		else if (A_Index = LatEnd+3) and (A_LoopField = "E" or A_LoopField = "East")	; format is Deg Min
			Long := (LongD + LongM/60) * 1
		else if (A_Index = LatEnd+3)
			LongS := A_LoopField
		else if (A_Index = LatEnd+4) and (A_LoopField = "W" or A_LoopField = "West")	; format is Deg Min Sec
			Long := (LongD + LongM/60 + LongS/60/60) * -1
		else if (A_Index = LatEnd+4) and (A_LoopField = "E" or A_LoopField = "East")	; format is Deg Min Sec
			Long := (LongD + LongM/60 + LongS/60/60) * 1
		if (A_Index = LatEnd+4 and not Long)
			return "error"
		if (Long) {
			Break
		}
	}
	If mode = lat
		return Lat
	If mode = long
		return Long
	If mode = both
		return Lat ", " Long
}