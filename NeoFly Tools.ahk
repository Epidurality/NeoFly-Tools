; ======================================================================================================================
; Script Function:  Searches a NeoFly database 
; Language:         English
; Tested on:        Windows 10 64-bit
; Author:           Epidurality
; Version:          0.0.0
/*  
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    <https://www.gnu.org/licenses/>
*/

; ======================================================================================================================
; AHK Settings
; ======================================================================================================================
#NoEnv
; #Warn
#SingleInstance force
SetWorkingDir, %A_ScriptDir%
SetBatchLines, -1

; Includes
#Include Class_SQLiteDB.ahk ; This is the interface to the SQLite3 DLL.
#Include Vincenty.ahk ; This is for calculating distances given lat/lon values.

;=======================================================================================================================
; YOU CAN EDIT THINGS HERE WITHOUT ANYTHING EXPLODING.
;=======================================================================================================================
; This should be the path to your common.db neofly database.
defaultDbPath := "C:\ProgramData\NeoFly\common.db"

; Setting this to TRUE will automatically use the path above to connect to the db and populate your hangar.
; If this setting is FALSE, the program will not automatically connect.
; By default this was FALSE to ensure the user does not get errors if connecting with a non-standard dbPath.
autoConnect := FALSE


;=======================================================================================================================
; EDITING ANYTHING BELOW HERE COULD BLOW THINGS UP
; I encourage you to read through and understand as much as you'd like, make changes to suit your desires.
; But I will not be able to provide any support or advice if the code is changed.
;=======================================================================================================================

; Persistent global objects and variables
global Plane := {id: -1, name: "unknown", fuel: -1, maxFuel: -1, payload: -1, pax: -1, location: "unknown"}
global DB := new SQLiteDB

; Start & GUI
Start:
{
Gui, +LastFound +OwnDialogs
Gui, Add, Tab3, vGUI_Tabs, Settings|Goods Optimizer|Aircraft Market|Mission Generator
Gui, Add, StatusBar

; Settings tab
Gui, Tab, Settings
Gui, Add, Text, , Database path:
Gui, Add, Edit, vSettings_DBPath, % defaultDbPath
Gui, Add, Button, gSettings_Connect, Connect
;Gui, Add, Button, gSettings_Restart, Restart Script
Gui, Add, Text, , Pilot loaded:
Gui, Add, Text, x+10 vSettings_PilotInfo, Connect to a database to get pilot information.
Gui, Add, Text, y+50,
(
V 0.0.0

KNOWN ISSUES:
	- Don't use non-alphanumeric characters if you can help it. Particularly double-quotes, `', `%, etc as the SQL queries are not being sanitized.
		Especially on the Mission Generator this will cause the SQL query to fail.

PLANNED UPDATES:
	Mission Generator
		- Multiple mission generation
		- Random and pseudo-random generation
		- Double-click a single previewed mission to commit to database
		- Add Airline and Humanitarian missions. They currently crash the NeoFly client and I don't know why.

	Goods Optimizer
		- Show actual (based on plane and mission) maximum profit instead of theoretical in the Missons lists
	
	Aircraft Market
		- Use the Vincenty model for distance estimation instead of the garbage estimation used currently
		
	General
		- Improve UI layout/looks (low priority)
		- Sanitize SQL inputs (not likely to happen)
		- Port this over to using a real language instead of AutoHotkey (not likely to happen)
)
Gui, Add, Text, y+100,
(
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

<https://www.gnu.org/licenses/>
)

; Goods market tab
Gui, Tab, Goods Optimizer
Gui, Add, Text, w50 h25, Departure ICAO:
Gui, Add, Edit, x+10 wp hp Disabled vGoods_DepartureICAO,
Gui, Add, Text, R2 x+20 wp hp, Arrival ICAO:
Gui, Add, Edit, x+10 wp hp Disabled vGoods_ArrivalICAO,
Gui, Add, Text, R2 x+20 wp hp, Mission Weight:
Gui, Add, Edit, x+10 wp hp Disabled vGoods_MissionWeight, 

Gui, Add, Text, xm+20 y+20 w100 h15, Aircraft:
Gui, Add, Text, x+10 w300 hp vGoods_PlaneInfo, Double click a plane in the Hangar to select it
Gui, Add, Text, xm+20 y+10 w100 hp, Fuel:
Gui, Add, Text, x+10 w300 hp vGoods_FuelInfo, ---
Gui, Add, Text, xm+20 y+10 w100 hp, Payload:
Gui, Add, Text, x+10 w300 hp vGoods_PayloadInfo, ---
Gui, Add, Text, xm+20 y+10 w100 hp, Mission:
Gui, Add, Text, x+10 w300 hp vGoods_MissionInfo, ---

Gui, Add, Button, xm+10 y+40 gGoods_RefreshHangar, Refresh Hangar
Gui, Add, Text, w600 vGoods_Hangar, Hangar planes: None
Gui, Add, ListView, w750 h100 Grid vGoods_HangarLV gGoods_HangarLVClick

Gui, Add, Button, gGoods_RefreshMissions, Refresh Missions
Gui, Add, Text, x+10 yp+4 w500 vGoods_Missions, Viable missions with markets: None
Gui, Add, ListView, xm+10 y+10 w750 h100 Grid vGoods_MissionsLV gGoods_MissionsLVClick

Gui, Add, Button, gGoods_RefreshTradeMissions, Refresh Trades Missions
Gui, Add, Text, x+10 yp+4 vGoods_TradeMissions, Trade Missions Available: None
Gui, Add, ListView, xm+10 y+10 w750 h100 Grid vGoods_TradeMissionsLV gGoods_TradeMissionsLVClick

Gui, Add, Button, gGoods_RefreshMarket, Refresh Market
Gui, Add, Text, x+10 yp+4 w400 vGoods_Market, Suitable Market Goods: None
Gui, Add, ListView, xm+10 y+10 w750 h100 Grid Disabled vGoods_MarketLV

Gui, Add, Text, w400 vGoods_Trades, Optimum Trades: None
Gui, Add, ListView, w750 h100 Grid Disabled vGoods_TradesLV

; Aircraft Market tab
Gui, Tab, Aircraft Market
Gui, Add, Text, , Aircraft Name (or part of name) as seen in NeoFly database:
Gui, Add, Edit, w300 vAircraftMarket_Aircraft, CJ4
Gui, Add, Button, gAircraftMarket_Search, Search
Gui, Add, ListView, w750 h700 Grid vAircraftMarket_LV

; Mission Generator tab
Gui, Tab, Mission Generator
Gui, Add, Button, xm+10 ym+50 gGenerator_Backup, Backup Database
Gui, Add, Text, R2 x+10 w600, Always backup your database before using the generator. Confirm that the button above works as intended first. Generator has database WRITE capabilities and CAN SCREW UP THE DATABASE. Use at own risk.
Gui, Add, Text, xm+10 y+20, Departure ICAO:
Gui, Add, Edit, x+10 w50 vGenerator_departure, KJFK
Gui, Add, Text, x+30, Arrival:
Gui, Add, Edit, x+10 w200 vGenerator_arrival, KLAX
Gui, Add, Text, x+30, Mission Type:
Gui, Add, DropDownList, x+10 vGenerator_missionTypeS, Pax||Cargo|Mail|Sensitive cargo|VIP pax|Secret pax|Emergency|Illicit cargo|tourists ; Airline and Humanitarian missions removed until they work
Gui, Add, Text, xm+10 y+10, Minimum Rank:
Gui, Add, DropDownList, x+10 vGenerator_rankS, Cadet||Second Officer|First Officer|Captain|Senior Captain

Gui, Add, Text, x+30, Expiration:
FormatTime, defaultExpiry, , yyyy-MM-dd HH:mm:ss
Gui, Add, Edit, x+10 w150 vGenerator_expiration, % defaultExpiry
Gui, Add, Text, x+30, Request:
Gui, Add, Edit, x+10 w200 vGenerator_request, Fly and try not to crash!
Gui, Add, Text, xm+10 y+10, Tooltip Text:
Gui, Add, Edit, x+10 w200 vGenerator_misstoolTip, Description of the mission for the tooltip
Gui, Add, Text, x+30, Pax#:
Gui, Add, Edit, x+10 w50 vGenerator_pax, 3
Gui, Add, Text, x+30, Cargo(lbs):
Gui, Add, Edit, x+10 w50 vGenerator_weight, 510

Gui, Add, Button, xm+10 y+10 gGenerator_FindLatLon, Find Lat/Lon
Gui, Add, Text, xm+10 y+10, Departure Lat:
Gui, Add, Edit, x+10 w200 vGenerator_latDep
Gui, Add, Text, x+10, Departure Lon:
Gui, Add, Edit, x+10 w200 vGenerator_lonDep
Gui, Add, Text, xm+10 y+10, Arrival Lat:
Gui, Add, Edit, x+10 w200 vGenerator_latArriv
Gui, Add, Text, x+10, Arrival Lon:
Gui, Add, Edit, x+10 w200 vGenerator_lonArriv
Gui, Add, Button, xm+10 y+10 gGenerator_Distance, Calculate Distance
Gui, Add, Text, xm+10 y+10, Distance (nm):
Gui, Add, Edit, x+10 w100 vGenerator_dist, 100

Gui, Add, Text, xm+10 y+10, Reward:
Gui, Add, Edit, x+10 vGenerator_reward, 12500
Gui, Add, Text, x+20, XP:
Gui, Add, Edit, x+10 vGenerator_xp, 75

Gui, Add, Button, xm+10 y+20 gGenerator_Preview, Preview
Gui, Add, Text, xm+10 y+20, Generated Preview(s):
Gui, Add, ListView, xm+10 y+10 w750 h200 Grid vGenerator_PreviewLV
Gui, Add, Button, xm+10 y+20 Disabled vGenerator_Commit gGenerator_Commit, Commit to Database
Gui, Add, Text, xm+10 y+10, Warning: This will commit the mission to the database based on the entered information, NOT based on the preview.

; Startup
Gui, Show, w800, NeoFly Tools
If (autoConnect) {
	GoSub Settings_Connect
	GoSub Goods_RefreshHangar
	GuiControl, Choose, GUI_Tabs, 2
}
SB_SetText("Connect to a database using the Settings tab.")
}
return

; GUI functions
GuiClose:
{
	Gui, Cancel
	DB.CloseDB()
	ExitApp
}
return

; Functions - Settings Tab
Settings_Restart:
{
	Gui, Cancel
	DB.CloseDB()
	Reload
}
return

Settings_Connect:
{
	SB_SetText("Creating DB object")
	DB := new SQLiteDB
	GuiControlGet, Settings_DBPath
	SB_SetText("Opening " . Settings_DBPath)
	If (!DB.OpenDB(Settings_DBPath, "R")) {
		MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		return
	}
	query = 
	(
		SELECT name, id FROM career WHERE id=(SELECT pilotID FROM currentpilot LIMIT 1)
	)
	result := SQLiteGetTable(DB, query)
	If (!result.RowCount) {
		GuiControl, , Settings_PilotInfo, % "Pilot was not able to be loaded from database."
	} Else {
		result.GetRow(1, Row)
		GuiControl, , Settings_PilotInfo, % "ID: " . Row[2] . "`t Name: " . Row[1]
	}
	SB_SetText("Successfully opened " . Settings_DBPath)
	if (!autoConnect) {
		GoSub Goods_RefreshHangar
	}
}
return

; Functions - Goods Tab
Goods_RefreshHangar:
{
	SB_SetText("Refreshing hangar")
	query = 
	(
		SELECT 
			hangar.id, 
			hangar.Aircraft, 
			hangar.Qualification, 
			hangar.MaxPayloadlbs AS [Max Payload], 
			hangar.Pax AS [Max Pax], 
			hangar.Location, 
			hangar.statusEngine AS Engine, 
			hangar.statusHull AS Hull, 
			hangar.currentFuel AS Fuel,
			aircraftdata.FuelCaplbs AS [Max Fuel]
		FROM hangar INNER JOIN aircraftdata ON hangar.Aircraft=aircraftdata.Aircraft
		WHERE owner=(SELECT pilotID FROM currentpilot LIMIT 1) AND status=0
	)
	result := SQLiteGetTable(DB, query)
	If (!result.RowCount) {
		GuiControl, , Goods_Hangar, % "Hangar planes: Searched database and did not find any available planes for the current pilot."
	} Else {
		GuiControl, , Goods_Hangar, % "Hangar planes: " . result.RowCount
	}
	LV_ShowTable(result, "Goods_HangarLV")
	SB_SetText("Hangar refreshed")
}
return

Goods_HangarLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		Gui, ListView, Goods_HangarLV
		LV_GetText(lvID, A_EventInfo, 1)
		LV_GetText(lvName, A_EventInfo, 2)
		LV_GetText(lvPayload, A_EventInfo, 4)
		LV_GetText(lvPax, A_EventInfo, 5)
		LV_GetText(lvLocation, A_EventInfo, 6)
		LV_GetText(lvFuel, A_EventInfo, 9)	
		LV_GetText(lvMaxFuel, A_EventInfo, 10)
		Plane.id := lvId
		Plane.name := lvName
		Plane.payload := lvPayload
		Plane.pax := lvPax
		Plane.location := lvLocation
		Plane.fuel := lvFuel
		Plane.maxFuel := lvMaxFuel
		GuiControl, , Goods_PlaneInfo, % Plane.name . " (ID#" . Plane.id . ")"
		GuiControl, , Goods_PayloadInfo, Double-click a mission (or trade mission) to display payload statistics
		GuiControl, , Goods_FuelInfo, % Plane.fuel . " / " . Plane.maxFuel . "lbs (" . ROUND(Plane.fuel*100/Plane.maxFuel,0) . "%)"
		GuiControl, , Goods_MissionInfo, Double-click a mission (or trade mission) to display mission info
		GuiControl, , Goods_DepartureICAO, % Plane.location
		SB_SetText("New plane selected")
		GoSub Goods_RefreshMissions
		GoSub Goods_RefreshTradeMissions
	}
}
return

Goods_RefreshMissions:
{
	SB_SetText("Refreshing trade missions")
	GuiControlGet, Goods_DepartureICAO
	GuiControlGet, Goods_ArrivalICAO
	qPayload := Plane.payload - Plane.fuel
	qPax := Plane.pax
	query = 
	(
		SELECT m.id, m.departure AS Departure, gm.location AS Arrival, m.dist AS Distance, m.pax AS Pax, m.weight AS Cargo, m.reward AS Pay, m.missionTypeS AS [Mission Type], m.xp AS XP, SUM(gm.[Max Profit]) AS [Trade Profit Available]
		FROM missions AS m
		INNER JOIN (
			SELECT
				dep.name AS Good,
				dep.unitWeight AS [Weight/u],
				dep.quantity,
				dep.unitPrice,
				dest.quantity,
				dest.unitPrice,
				dest.unitPrice - dep.unitPrice AS [Profit/unit],
				ROUND((dest.unitPrice - dep.unitPrice)/dep.unitWeight, 2) AS [Profit/lb],
				MIN(dest.quantity, dep.quantity) AS [Max Qty],
				MIN(dest.quantity, dep.quantity)*(dest.unitPrice-dep.unitPrice) AS [Max Profit],
				dest.location AS location
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location LIKE UPPER('%Goods_DepartureICAO%') AND
				dep.tradeType=0 AND
				dest.tradeType=1 ) 
		AS gm ON m.arrival=gm.location
		WHERE
			departure LIKE UPPER('%Goods_DepartureICAO%')
			AND m.weight < %qPayload%
			AND m.pax < %qPax%
			AND m.misionType != 7
			AND m.misionType != 8
			AND m.misionType != 9
			AND m.misionType != 12
		GROUP BY gm.location, m.id
		ORDER BY [Trade Profit Available] DESC
	)
	result := SQLiteGetTable(DB, query)
	GuiControl, , Goods_Missions, % "Viable missions with markets: " . result.RowCount
	LV_ShowTable(result, "Goods_MissionsLV")
	SB_SetText("Trade missions refreshed")
}
return

Goods_MissionsLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		Gui, ListView, Goods_MissionsLV
		LV_GetText(lvID, A_EventInfo, 1)
		LV_GetText(lvDeparture, A_EventInfo, 2)
		LV_GetText(lvArrival, A_EventInfo, 3)
		LV_GetText(lvMissionWeight, A_EventInfo, 6)
		LV_GetText(lvMissionType, A_EventInfo, 8)
		GuiControl, , Goods_MissionWeight, % lvMissionWeight
		GuiControl, , Goods_ArrivalICAO, % lvArrival
		GuiControl, , Goods_MissionInfo, % lvDeparture . ">" . lvArrival . " - " . lvMissionType
		GoSub Goods_RefreshMarket
	}
}
return

Goods_RefreshTradeMissions:
{
	SB_SetText("Refreshing trade missions")
	GuiControlGet, Goods_DepartureICAO
	GuiControlGet, Goods_ArrivalICAO
	qPayload := Plane.payload - Plane.fuel
	query = 
	(
		SELECT gm.departure AS Departure, gm.arrival AS Arrival, SUM(gm.[Max Profit]) AS [Trade Profit Available], SUM(gm.[Weight/u]*gm.[Max Qty]) AS [Total Weight], ROUND(SUM(gm.[Max Profit])/SUM(gm.[Weight/u]*gm.[Max Qty]), 2) AS [Profit/lb]
		FROM (
			SELECT
				dep.name AS Good,
				dep.unitWeight AS [Weight/u],
				dep.quantity,
				dep.unitPrice,
				dest.quantity,
				dest.unitPrice,
				dest.unitPrice - dep.unitPrice AS [Profit/unit],
				ROUND((dest.unitPrice - dep.unitPrice)/dep.unitWeight, 2) AS [Profit/lb],
				MIN(dest.quantity, dep.quantity) AS [Max Qty],
				MIN(dest.quantity, dep.quantity)*(dest.unitPrice-dep.unitPrice) AS [Max Profit],
				dest.location AS arrival,
				dep.location AS departure
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location LIKE UPPER('%Goods_DepartureICAO%') AND
				dep.tradeType=0 AND
				dest.tradeType=1 ) 
		AS gm
		GROUP BY Arrival
		ORDER BY [Profit/lb] DESC
	)
	result := SQLiteGetTable(DB, query)
	GuiControl, , Goods_TradeMissions, % "Trade missions available: " . result.RowCount
	LV_ShowTable(result, "Goods_TradeMissionsLV")
	SB_SetText("Trade missions refreshed")
	return
}

Goods_TradeMissionsLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		Gui, ListView, Goods_TradeMissionsLV
		LV_GetText(lvDeparture, A_EventInfo, 1)
		LV_GetText(lvArrival, A_EventInfo, 2)
		GuiControl, , Goods_MissionWeight, 0
		GuiControl, , Goods_ArrivalICAO, % lvArrival
		GuiControl, , Goods_MissionInfo, % lvDeparture . ">" . lvArrival . " - Custom trade only mission"
		GoSub Goods_RefreshMarket
	}
}
return

Goods_RefreshMarket:
{
	SB_SetText("Refreshing Market")
	GuiControlGet, Goods_DepartureICAO
	GuiControlGet, Goods_ArrivalICAO
	GuiControlGet, Goods_MissionWeight
	query = 
	(
		SELECT
			dep.name AS Good,
			replace(dep.unitWeight, ',', '.') AS [Weight/u],
			dep.quantity AS [Qty at %Goods_DepartureICAO%],
			dep.unitPrice AS [Price at %Goods_DepartureICAO%],
			dest.quantity AS [Qty at %Goods_ArrivalICAO%],
			dest.unitPrice AS [Price at %Goods_ArrivalICAO%],
			dest.unitPrice - dep.unitPrice AS [Profit/u],
			ROUND((dest.unitPrice - dep.unitPrice)/CAST(replace(dep.unitWeight, ',', '.') AS NUMERIC),2) AS [Profit/lb],
			MIN(dest.quantity, dep.quantity) AS [Max Qty],
			MIN(dest.quantity, dep.quantity)*(dest.unitPrice-dep.unitPrice) AS [Max Profit],
			replace(dep.unitWeight, ',', '.')*MIN(dest.quantity, dep.quantity) AS [Max Weight]
		FROM
			goodsMarket AS dep
		INNER JOIN
			goodsMarket AS dest ON dep.name=dest.name
		WHERE
			dep.location='%Goods_DepartureICAO%' AND
			dest.location='%Goods_ArrivalICAO%' AND
			dep.tradeType=0 AND
			dest.tradeType=1
		ORDER BY [Profit/lb] DESC
	)
	result := SQLiteGetTable(DB, query)
	GuiControl, , Goods_Market, % "Suitable Market Goods " . Goods_DepartureICAO . ">" . Goods_ArrivalICAO . ": " . result.RowCount
	LV_ShowTable(result, "Goods_MarketLV")
	result.Reset()
	SB_SetText("Market refreshed. Finding trade optimizations")
	simPayload := Plane.payload - Plane.fuel
	totalProfit := 0
	availablePayload := Plane.payload - Plane.fuel- Goods_MissionWeight - 170
	goodsWeight := availablePayload
	result.ColumnNames[9] := "Buy Qty"
	result.ColumnNames[10] := "Profit"
	result.ColumnNames[11] := "Weight"
	Loop % result.RowCount {
		result.Next(Row)
		maxQty := FLOOR(MIN(Row[9], availablePayload/Row[2]))
		Row[9] := maxQty
		Row[10] := maxQty * Row[7]
		Row[11] := Round(maxQty * Row[2],2)
		totalProfit += Row[10]
		availablePayload := availablePayload - maxQty*Row[2]
	}
	result.Reset()
	goodsWeight -= availablePayload
	GuiControl, , Goods_PayloadInfo, % CEIL(simPayload-availablePayload) . " / " . simPayload . "lbs (" . CEIL((simPayload-availablePayload)*100/simPayload) . "%)"
	GuiControl, , Goods_Trades, % "Optimum Trades " . Goods_DepartureICAO . ">" . Goods_ArrivalICAO . ": " . result.RowCount . ", Goods Profit: $" . totalProfit
	LV_ShowTable(result, "Goods_TradesLV")
	SB_SetText("Trades calculated")
}
return

; Functions - Aircraft Market Tab
AircraftMarket_Search:
{
	SB_SetText("Getting pilot location")
	GuiControlGet, AircraftMarket_Aircraft
	moveCostPerMile := 9.0
	query = 
	(	
		SELECT lonx, laty FROM airport WHERE ident=(SELECT pilotCurrentICAO FROM career WHERE id=(SELECT pilotID FROM currentPilot LIMIT 1) LIMIT 1) LIMIT 1
	)
	result := SQLiteGetTable(DB, query)
	If (!result.HasRows) {
		MsgBox Could not get pilot location
		return
	} Else {
		result.GetRow(1, pilotLocation)
		pilotLonX := pilotLocation[1]
		pilotLatY := pilotLocation[2]
	}
	
	SB_SetText("Finding planes")
	query = 
	(
		SELECT
		am.aircraft AS Airplane,
		airport.ident AS Location,
		CAST(am.cost + %moveCostPerMile%*(0.414*MIN(ABS((airport.laty - %pilotLatY%)) * 59.705, ABS((airport.lonx - %pilotLonX%)) * (1-ABS((airport.laty+%pilotLatY%)/2)/90) * 60.108) + MAX(ABS((airport.laty - %pilotLatY%)) * 59.705, ABS((airport.lonx - %pilotLonX%)) * (1-ABS((airport.laty+%pilotLatY%)/2)/90) * 60.108)) AS int) AS TotalCost,
		am.cost AS BasePrice,
		CAST((0.414*MIN(ABS((airport.laty - %pilotLatY%)) * 59.705, ABS((airport.lonx - %pilotLonX%)) * (1-ABS((airport.laty+%pilotLatY%)/2)/90) * 60.108) + MAX(ABS((airport.laty - %pilotLatY%)) * 59.705, ABS((airport.lonx - %pilotLonX%)) * (1-ABS((airport.laty+%pilotLatY%)/2)/90) * 60.108)) AS int) AS Distance,
		CAST(%moveCostPerMile%*(0.414*MIN(ABS((airport.laty - %pilotLatY%)) * 59.705, ABS((airport.lonx - %pilotLonX%)) * (1-ABS((airport.laty+%pilotLatY%)/2)/90) * 60.108) + MAX(ABS((airport.laty - %pilotLatY%)) * 59.705, ABS((airport.lonx - %pilotLonX%)) * (1-ABS((airport.laty+%pilotLatY%)/2)/90) * 60.108)) AS int) AS TravelCost
	FROM 
		airport INNER JOIN aircraftMarket AS am 
	ON 
		airport.ident = am.location
	WHERE 
		am.aircraft LIKE '`%%AircraftMarket_Aircraft%`%'
	ORDER BY
		TotalCost ASC
	)
	
	SB_SetText("Displaying results")
	result := SQLiteGetTable(DB, query)
	LV_ShowTable(result, "AircraftMarket_LV")
	
	SB_SetText("Showing results for: " . AircraftMarket_Aircraft)
}
return

; Function - Mission Generator Tab
Generator_Backup:
{
	GuiControlGet, Settings_DBPath
	MsgBox, 36, Backup Confirmation, Clicking YES will attempt to create a backup of:`n`n%Settings_DBPath%`nas`n%Settings_DBPath%.backup`n`nThis will overwrite any previous backups. Are you sure you want to continue?
	IfMsgBox Yes 
	{
		IfNotExist %Settings_DBPath%
		{
			MsgBox, 16, Error, Cannot find file specified. Please double-check your database path in the Settings tab.
			return
		}
		FileCopy, %Settings_DBPath%, %Settings_DBPath%.backup, true
		If (ErrorLevel) {
			MsgBox, 16, Error, Could not complete backup. Error:`n%A_LastError%
		} else {
			MsgBox, 64, Success!, Backup performed, but it's a good idea to double-check if this was the first time backup up this database.
		}
	} else {
		MsgBox, 64, Aborted, Backup was not performed.
	}
}
return

Generator_FindLatLon:
{
	GuiControlGet, Generator_departure
	GuiControlGet, Generator_arrival
	query = 
	(
		SELECT lonx, laty FROM airport WHERE ident='%Generator_departure%' LIMIT 1
	)
	result := SQLiteGetTable(DB, query)
	result.GetRow(1, DepRow)
	lonDep := DepRow[1]
	latDep := DepRow[2]
	query = 
	(
		SELECT lonx, laty FROM airport WHERE ident='%Generator_arrival%' LIMIT 1
	)
	result := SQLiteGetTable(DB, query)
	result.GetRow(1, ArrivRow)
	lonArriv := ArrivRow[1]
	latArriv := ArrivRow[2]
	GuiControl, , Generator_lonDep, % lonDep
	GuiControl, , Generator_latDep, % latDep
	GuiControl, , Generator_lonArriv, % lonArriv
	GuiControl, , Generator_latArriv, % latArriv
}
return

Generator_Distance:
{
	GuiControlGet, Generator_lonDep
	GuiControlGet, Generator_latDep
	GuiControlGet, Generator_lonArriv
	GuiControlGet, Generator_latArriv
	distanceNM := ROUND(0.000539957*InvVincenty(Generator_latDep, Generator_lonDep, Generator_latArriv, Generator_lonArriv),0)
	GuiControl, , Generator_dist, % distanceNM
}
return

Generator_Commit:
{
	previewAccepted := TRUE
	DB.CloseDB()
	GuiControlGet, Settings_DBPath
	SB_SetText("Opening " . Settings_DBPath)
	If (!DB.OpenDB(Settings_DBPath)) {
		MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		return
	}
}
Generator_Preview:
{
	Gui, Submit, NoHide
	Switch Generator_rankS
	{
		Case "Cadet": 
			Generator_rank := 0
			rankI := "img/r0.png"
		Case "Second Officer": 
			Generator_rank := 1
			Generator_rankI := "img/r1.png"
		Case "First Officer":
			Generator_rank := 2
			Generator_rankI := "img/r2.png"
		Case "Captain":
			Generator_rank := 3
			Generator_rankI := "img/r3.png"
		Case "Senior Captain":
			Generator_rank := 4
			Generator_rankI := "img/r4.png"
		Default:
			Generator_rank := 0
			rankI := "img/r0.png"
	}
	
	Switch Generator_missionTypeS
	{
		Case "Pax": 
			Generator_misionType := 1
			Generator_missionTypeImage := "img/m1.png"
		Case "Cargo": 
			Generator_misionType := 2
			Generator_missionTypeImage := "img/m2.png"
		Case "Mail": 
			Generator_misionType := 3
			Generator_missionTypeImage := "img/m3.png"
		Case "Sensitive cargo": 
			Generator_misionType := 4
			Generator_missionTypeImage := "img/m4.png"
		Case "VIP pax": 
			Generator_misionType := 5
			Generator_missionTypeImage := "img/m5.png"
		Case "Secret pax": 
			Generator_misionType := 6
			Generator_missionTypeImage := "img/m6.png"
		Case "Emergency": 
			Generator_misionType := 7
			Generator_missionTypeImage := "img/m7.png"
		Case "Illicit cargo": 
			Generator_misionType := 8
			Generator_missionTypeImage := "img/m8.png"
		Case "tourists": 
			Generator_misionType := 9
			Generator_missionTypeImage := "img/m9.png"
		Case "Airline": 
			Generator_misionType := 11
			Generator_missionTypeImage := "img/carrier/NeoFly.png"
			MsgBox Airline missions have not been tested.
		Case "Humanitarian": 
			Generator_misionType := 12
			Generator_missionTypeImage := "img/m12.png"
			MsgBox Humanitarian missions not yet supported (they're more complicated I think)
			return
		Default: 
			Generator_misionType := 1
	}
	; NOTE: If it doesn't include a variable below, I don't know what it does and I'm just using a default.
	selectQuery =
	(
		SELECT
			'%Generator_departure%' AS departure,
			'%Generator_latDep%' AS latDep,
			'%Generator_lonDep%' AS lonDep,
			'' AS escale,
			0 AS latEsc,
			0 AS lonEsc,
			'%Generator_arrival%' AS arrival,
			'%Generator_latArriv%' AS latArriv,
			'%Generator_lonArriv%' AS lonArriv,
			1000 AS altMax,
			0 AS consigne,
			'0001-01-01 00:00:00' AS delay,
			%Generator_dist% AS dist,
			1 AS flightType,
			%Generator_misionType% AS misionType,
			%Generator_pax% AS pax,
			%Generator_weight% AS weight,
			%Generator_reward% AS reward,
			200 AS vsMax,
			'%Generator_request%' AS request,
			'' AS nameAirport,
			'%Generator_missionTypeS%' AS missionTypeS,
			'' AS flightTypeS,
			'%Generator_missionTypeImage%' AS missionTypeImage,
			'True' AS available,
			'0001-01-01 00:00:00' AS deadline,
			'%Generator_expiration%' AS expiration,
			'%Generator_departure%>%Generator_arrival%' AS fp,
			'%Generator_misstoolTip%' AS misstoolTip,
			%Generator_rank% AS rank,
			'%Generator_rankS%' AS rankS,
			'%Generator_rankI%' AS rankI,
			'' AS liveID,
			%Generator_xp% AS xp,
			(SELECT MAX(id)+1 FROM missions) AS id
	)
	If (previewAccepted) {
		query := "INSERT INTO missions " . selectQuery
		clipboard := query
		If (!DB.Exec(query)) {
			MsgBox, 16, SQLite Error, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		}
		DB.CloseDB()
		GuiControlGet, Settings_DBPath
		SB_SetText("Opening " . Settings_DBPath)
		If (!DB.OpenDB(Settings_DBPath, "R")) {
			MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
			return
		}
		SB_SetText("Mission entered into database. Database set back to Read Only.")
		GuiControl, Disable, Generator_Commit
	} else {
		result := SQLiteGetTable(DB, selectQuery)
		LV_ShowTable(result, "Generator_PreviewLV")
		SB_SetText("Mission preview generated")
		GuiControl, Enable, Generator_Commit
	}
	previewAccepted := FALSE
}
return


; SQL functions
SQLiteGetTable(database, query) {
	resultTable := ""
	If (!database.GetTable(query, resultTable)) {
		MsgBox, 16, SQLite Error: GetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`nQuery: `t" . query
	}
	clipboard := query
	return resultTable
}

; ListView functions
LV_ShowTable(Table, LV) {
	Gui, ListView, %LV%
	LV_Clear(LV)
	GuiControl, -ReDraw, %LV%
	If (Table.HasNames) {
		Loop, % Table.ColumnCount
			LV_InsertCol(A_Index,"", Table.ColumnNames[A_Index])
		If (Table.HasRows) {
			Loop, % Table.RowCount {
				RowCount := LV_Add("", "")
				Table.Next(stRow)
				Loop, % Table.ColumnCount
					LV_Modify(RowCount, "Col" . A_Index, stRow[A_Index])
			}
		}
    Loop, % Table.ColumnCount
        LV_ModifyCol(A_Index, "AutoHdr")
	}
	GuiControl, +ReDraw, %LV%
}

LV_Clear(LV) {
	Gui, ListView, %LV%
	ColCount := LV_GetCount("Column")
	LV_Delete()
	Loop %ColCount% {
		LV_DeleteCol(1)
	}
	return
}
