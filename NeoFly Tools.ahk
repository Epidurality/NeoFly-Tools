versionNumber := "0.2.1"
; Updates:			https://github.com/Epidurality/NeoFly-Tools/

; Script Function:  Small collection of tools for use with the NeoFly career mode addon for MSFS 2020 (https://www.neofly.net/).
; Language:         English
; Tested on:        Windows 10 64-bit
; Author:           Epidurality



; This should be the path to your common.db neofly database.
global defaultDbPath := "C:\ProgramData\NeoFly\common.db"

; Automatically connects to the DBPath on startup if TRUE.
global autoConnect := FALSE

; The number of which tab to open to by default if AutoConnect is true (otherwise will default to the Settings tab). 1: Settings, 2: Goods Optimizer, etc.
global autoConnectDefaultTab := 2

; Set to TRUE if you don't want to have the tray icon appear in your system notification area.
global hideTrayIcon := false

; =============== EDITING ANYTHING BELOW HERE COULD BLOW THINGS UP ==================

; AHK Settings
{
#NoEnv
#SingleInstance force
SetWorkingDir, %A_ScriptDir%
}

; Includes
{
#Include %A_ScriptDir%/resources/Class_SQLiteDB.ahk ; This is the interface to the SQLite3 DLL. Credit to https://github.com/AHK-just-me/Class_SQLiteDB
#Include %A_ScriptDir%/resources/Vincenty.ahk ; This is for calculating distances given lat/lon values. Credit to https://autohotkey.com/board/topic/88476-vincenty-formula-for-latitude-and-longitude-calculations/
iconPath := A_ScriptDir . "/resources/default.ico"
}

; Persistent global objects and variables
{
global Pilot := {id: -1, weight: 170} ; Stores information about the current pilot
global Plane := {id: -1, name: "unknown", fuel: -1, maxFuel: -1, payload: -1, pax: -1, location: "unknown"} ; Stores information about the selected Hangar plane
global DB := new SQLiteDB ; SQLite database connection object
global marketRefreshHours := 24 ; How often (in hours) the NeoFly system will force a refresh of the market. This is used to ignore markets which are too old.
global fuelPercentForAircraftMarketPayload := 0.40 ; Percent (as decimal) of fuel to be used in the Effective Payload calculation, only in the Aircraft Market tab results.
}

; ==== GUI =====

; GUI setup
{
IfExist, %iconPath%
{
	Menu, Tray, Icon, %iconPath%
}
If (hideTrayIcon) {
	Menu, Tray, NoIcon
} Else {
	Menu, Tray, NoStandard
	Menu, Tray, Add, Show, ShowTool
	Menu, Tray, Add, Hide, HideTool
	Menu, Tray, Add, Reload, ReloadTool
	Menu, Tray, Add, Close, GuiClose
}
Gui, +LastFound +OwnDialogs
Gui, Add, Tab3, vGUI_Tabs, Settings|Goods Optimizer|Aircraft Market|Mission Generator
Gui, Add, StatusBar
}

; GUI Settings tab
{
Gui, Tab, Settings
Gui, Add, Text, , Database path:
Gui, Add, Edit, x+10 w300 vSettings_DBPath, % defaultDbPath
Gui, Add, Button, x+20 gSettings_Connect, Connect
Gui, Add, Text, xm+10 y+30, Selected Pilot:
Gui, Add, Text, x+10 vSettings_Pilot, Connect to a database to get pilot information.
Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vSettings_PilotLV gSettings_PilotLVClick
Gui, Add, Text, xm+10 y+20,
(
Note: Missions, Goods Market, and Aircraft Market are shared between Pilots. `n
Selecting a pilot here effectively just filters your Hangar in the Goods Optimizer. `n
The current NeoFly pilot will be used by default when you Connect to the database. `n
)
Gui, Add, Text, xm+10 y+100, Version: v%versionNumber%
}

; GUI Goods market tab
{
Gui, Tab, Goods Optimizer
Gui, Add, Text, w50 h25, Departure ICAO:
Gui, Add, Edit, x+10 wp hp vGoods_DepartureICAO,
Gui, Add, Text, R2 x+20 wp hp, Arrival ICAO:
Gui, Add, Edit, x+10 wp hp Disabled vGoods_ArrivalICAO, ---
Gui, Add, Text, R2 x+20 wp hp, Mission Weight:
Gui, Add, Edit, x+10 wp hp Disabled vGoods_MissionWeight, ---
Gui, Add, Text, R2 x+20 wp hp, Goods Weight:
Gui, Add, Edit, x+10 wp hp Disabled vGoods_GoodsWeight, ---

Gui, Add, Text, xm+20 y+20 w50 h15, Aircraft:
Gui, Add, Text, x+10 w150 hp vGoods_PlaneInfo, Double click a plane in the Hangar to select it
Gui, Add, Text, xm+20 y+10 w50 hp, Fuel:
Gui, Add, Text, x+10 w150 hp vGoods_FuelInfo, ---
Gui, Add, Text, xm+20 y+10 w50 hp, Payload:
Gui, Add, Text, x+10 w150 hp vGoods_PayloadInfo, ---
Gui, Add, Text, xm+20 y+10 w50 hp, Mission:
Gui, Add, Text, x+10 w200 hp vGoods_MissionInfo, ---

Gui, Add, Button, xm+600 y50 gGoods_RefreshHangar, Refresh Hangar
Gui, Add, CheckBox, x+30 vGoods_HangarAll gGoods_RefreshHangar, Show All
Gui, Add, Text, xm+600 y+10 w300 vGoods_Hangar, Hangar:
Gui, Add, ListView, xm+350 y+10 w575 h150 Grid vGoods_HangarLV gGoods_HangarLVClick

Gui, Add, Button, xm+10 y230 gGoods_RefreshMissions, Refresh Missions
Gui, Add, CheckBox, x+20 vGoods_IncludeIllicit gGoods_RefreshMissions, Include Illicit Goods
Gui, Add, Text, xm+10 y+10 w500 vGoods_Missions, NeoFly Missions (with viable markets):
Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vGoods_MissionsLV gGoods_MissionsLVClick

Gui, Add, Text, xm+10 y+10 w500 vGoods_TradeMissions, Trade / Transit Missions:
Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vGoods_TradeMissionsLV gGoods_TradeMissionsLVClick

Gui, Add, Text, xm+10 y+20 w400 vGoods_Trades, Optimal Goods:
Gui, Add, ListView, w915 h100 Grid Disabled vGoods_TradesLV
}

; GUI Aircraft Market tab
{
Gui, Tab, Aircraft Market
Gui, Add, Text, , Aircraft Name (or part of name) as seen in NeoFly database:
Gui, Add, Edit, w300 vAircraftMarket_Aircraft, Cessna
Gui, Add, Button, gAircraftMarket_Search, Search
Gui, Add, ListView, w915 h450 Grid vAircraftMarket_LV
Gui, Add, Text, xm+10 y+20, Note: Travel Cost represents a one-way trip from your pilot's current location to the plane's Location.
Gui, Add, Text, xm+10 y+20, % "Other Note: Effective Payload is the payload of the plane after subtracting the Pilot's weight (" . Pilot.weight . "lbs) and " . ROUND(fuelPercentForAircraftMarketPayload*100,0) . "% of max fuel."
}

; GUI Mission Generator tab
{
Gui, Tab, Mission Generator
Gui, Add, Button, xm+10 ym+50 gGenerator_Backup, Backup Database
Gui, Add, Text, R2 x+10 w600, Always backup your database before using the generator. Generator has database WRITE capabilities and CAN SCREW UP THE DATABASE. Read the readme that was included with this app, and use at your own risk.

Gui, Add, Text, xm+10 y+20, Departure ICAO:
Gui, Add, Edit, x+10 w50 vGenerator_departure, KJFK
Gui, Add, Text, x+30, Arrival:
Gui, Add, Edit, x+10 w200 vGenerator_arrival, KLAX
Gui, Add, Text, x+30, Expiration:
ForwardTime := A_Now
EnvAdd, ForwardTime, +24, hour
FormatTime, defaultExpiry, %ForwardTime%, yyyy-MM-dd HH:mm:ss
Gui, Add, Edit, x+10 w150 vGenerator_expiration, % defaultExpiry

Gui, Add, Text, xm+10 y+20, Mission Type:
Gui, Add, DropDownList, x+10 vGenerator_missionTypeS, Pax||Cargo|Mail|Sensitive cargo|VIP pax|Secret pax|Emergency|Illicit cargo|tourists ; Airline and Humanitarian missions removed until they work
Gui, Add, Text, x+30, Minimum Rank:
Gui, Add, DropDownList, x+10 vGenerator_rankS, Cadet||Second Officer|First Officer|Captain|Senior Captain
Gui, Add, Text, x+30, Pax#:
Gui, Add, Edit, x+10 w50 vGenerator_pax, 3
Gui, Add, Text, x+30, Cargo(lbs):
Gui, Add, Edit, x+10 w50 vGenerator_weight, 510

Gui, Add, Text, xm+10 y+20, Request:
Gui, Add, Edit, x+10 w400 vGenerator_request, This shows up in the mission selection screen of NeoFly
Gui, Add, Text, x+30, Tooltip Text:
Gui, Add, Edit, x+10 w200 vGenerator_misstoolTip, ToolTip over the mission on the map

Gui, Add, Text, xm+10 y+20, Reward:
Gui, Add, Edit, x+10 w75 vGenerator_reward, 12500
Gui, Add, Text, x+30, XP:
Gui, Add, Edit, x+10 w50 vGenerator_xp, 65

Gui, Add, Button, xm+10 y+20 gGenerator_FindLatLon, Find Lat/Lon
Gui, Add, Text, x+10, For Drop Zone and Tourist missions, Arrival Lat/Lon must be entered manually. Try www.gps-coordinates.net

Gui, Add, Text, xm+10 y+20 w100, Departure Lat:
Gui, Add, Edit, x+10 w200 vGenerator_latDep,
Gui, Add, Text, x+30 w60, Arrival Lat:
Gui, Add, Edit, x+10 w200 vGenerator_latArriv,

Gui, Add, Text, xm+10 y+10 w100, Departure Lon:
Gui, Add, Edit, x+10 w200 vGenerator_lonDep,
Gui, Add, Text, x+30 w60, Arrival Lon:
Gui, Add, Edit, x+10 w200 vGenerator_lonArriv,

Gui, Add, Button, xm+10 y+10 gGenerator_Distance, Calculate Distance
Gui, Add, Text, x+20, Distance (nm):
Gui, Add, Edit, x+10 w100 vGenerator_dist, 100

Gui, Add, Text, xm+10 y+20, Missions to Generate:
Gui, Add, Edit, x+10 w50 vGenerator_Quantity, 1
Gui, Add, CheckBox, x+10 vGenerator_RandomizePax, Randomize Pax
Gui, Add, CheckBox, x+10 vGenerator_RandomizeWeight, Randomize Weight
Gui, Add, CheckBox, x+10 vGenerator_RandomizeReward, Randomize Reward
Gui, Add, Text, x+20 w225, NOTE: Randimization will be proportional, and uses entered values as maximums.

Gui, Add, Button, xm+10 y+30 gGenerator_Preview, Generate Missions

Gui, Add, Text, xm+10 y+10, Generated Mission Previews:

Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vGenerator_PreviewLV gGenerator_PreviewLVClick

Gui, Add, Text, xm+10 y+10, Double-click a row to commit it to the database. IDs added:
Gui, Add, Edit, x+10 vscroll +readonly w150 h40 vGenerator_AddedIDs,

Gui, Add, Text, xm+10 y+10 R2, Warning: this can only be reversed by deleting the entry in the database. Recommend noting the generated IDs so that it's easy to find and remove if it causes issues with NeoFly.
}

; Program initialization
{
Gui, Show, h700 w960, NeoFly Tools
SB_SetText("Connect to a database using the Settings tab.")
If (autoConnect) {
	GoSub Settings_Connect
	GoSub Goods_RefreshHangar
	GuiControl, Choose, GUI_Tabs, %autoConnectDefaultTab%
}
return
}

; GUI functions
GuiClose:
{
	DB.CloseDB()
	ExitApp
	return
}

ReloadTool:
{
	DB.CloseDB()
	Reload
	return
}

ShowTool:
{
	Gui, Show
	return
}

HideTool:
{
	Gui, Hide
	return
}

; ==== SUBROUTINES =====

; == Subroutines - Settings Tab ==
Settings_Connect:
{
	SB_SetText("Creating DB object")
	DB := new SQLiteDB
	GuiControlGet, Settings_DBPath
	SB_SetText("Opening " . Settings_DBPath)
	If (!DB.OpenDB(Settings_DBPath, "R", False)) {
		MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		return
	}
	query = 
	(
		SELECT career.name AS [Pilot Callsign], career.id, currentPilot.pilotID AS [Current NeoFly Pilot] FROM career LEFT JOIN currentPilot ON career.id=currentPilot.pilotID
	)
	result := SQLiteGetTable(DB, query)
	If (!result.RowCount) {
		GuiControl, , Settings_Pilot, % "Valid pilots were not able to be loaded from database."
	} Else {
		Loop % result.RowCount {
			result.Next(Row)
			If (Row[2] == Row[3]) {
				Pilot.id := Row[2]
				GuiControl, , Settings_Pilot, % "ID: " . Row[2] . "`t Callsign: " . Row[1]
				Row[3] := "<<<"
			} Else {
				Row[3] := " "
			}
		}
		result.Reset()
		LV_ShowTable(result, "Settings_PilotLV")
		GoSub Goods_RefreshHangar
	}
	SB_SetText("Successfully opened " . Settings_DBPath)
	return
}

Settings_PilotLVClick:
{
	If (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
		Gui, ListView, Settings_PilotLV
		LV_GetText(lvID, A_EventInfo, 2)
		LV_GetText(lvCallsign, A_EventInfo, 1)
		Pilot.id := lvID
		GuiControl, , Settings_Pilot, % "ID: " . Pilot.id . "`t Callsign: " . lvCallsign
		GoSub Goods_RefreshHangar
	}
	return
}

; == Subroutines - Goods Tab ==
Goods_RefreshHangar:
{
	SB_SetText("Refreshing hangar...")
	GuiControlGet, Goods_HangarAll
	LV_Clear("Goods_MissionsLV")
	LV_Clear("Goods_TradeMissionsLV")
	LV_Clear("Goods_TradesLV")
	GuiControl, , Goods_ArrivalICAO, ---
	GuiControl, , Goods_MissionWeight, ---
	GuiControl, , Goods_GoodsWeight, ---
	qPilotID := Pilot.id
	If (Goods_HangarAll) {
		qStatusClause := "hangar.status != 5"
	} Else {
		qStatusClause := "hangar.status = 0"
	}
	query = 
	(
		SELECT 
			hangar.id, 
			hangar.Aircraft, 
			CASE hangar.status
				WHEN 0 THEN 'Available'
				WHEN 1 THEN 'Flying'
				WHEN 3 THEN 'Hired'
				WHEN 5 THEN 'Removed'
				ELSE 'Unknown'
			END AS Status, 
			hangar.MaxPayloadlbs AS [Max Payload], 
			hangar.Pax AS [Max Pax], 
			hangar.Location, 
			CAST(hangar.statusEngine AS int) AS Engine, 
			CAST(hangar.statusHull AS int) AS Hull, 
			hangar.currentFuel AS Fuel,
			aircraftdata.FuelCaplbs AS [Max Fuel],
			hangar.Qualification
		FROM hangar INNER JOIN aircraftdata ON hangar.Aircraft=aircraftdata.Aircraft
		WHERE owner=%qPilotID% 
		AND %qStatusClause%
		ORDER BY hangar.id
	)
	result := SQLiteGetTable(DB, query)
	LV_ShowTable(result, "Goods_HangarLV")
	SB_SetText("Hangar refreshed")
	return
}

Goods_HangarLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
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
		GuiControl, , Goods_PayloadInfo, Choose mission
		GuiControl, , Goods_FuelInfo, % Plane.fuel . " / " . Plane.maxFuel . "lbs (" . FLOOR(Plane.fuel*100/Plane.maxFuel) . "%)"
		GuiControl, , Goods_MissionInfo, Choose mission
		GuiControl, , Goods_DepartureICAO, % Plane.location
		SB_SetText("New plane selected")
		GoSub Goods_RefreshMissions
	}
	return
}

Goods_RefreshMissions:
{
	SB_SetText("Refreshing missions...")
	LV_Clear("Goods_TradesLV")
	GuiControl, , Goods_ArrivalICAO, ---
	GuiControl, , Goods_MissionWeight, ---
	GuiControl, , Goods_GoodsWeight, ---
	GuiControlGet, Goods_DepartureICAO
	GuiControlGet, Goods_IncludeIllicit
	; Check for a market at the Departure ICAO
	query = 
	(
		SELECT 
			CASE SUBSTR(gm.refreshDate, 3, 1)
				WHEN '-' THEN SUBSTR(gm.refreshDate, 7, 4)||SUBSTR(gm.refreshDate, 4, 2)||SUBSTR(gm.refreshDate, 1, 2)||' '||SUBSTR(gm.refreshDate, 11)
				WHEN '/' THEN SUBSTR(gm.refreshDate, 7, 4)||SUBSTR(gm.refreshDate, 4, 2)||SUBSTR(gm.refreshDate, 1, 2)||' '||SUBSTR(gm.refreshDate, 11)
				WHEN '.' THEN SUBSTR(gm.refreshDate, 7, 4)||SUBSTR(gm.refreshDate, 4, 2)||SUBSTR(gm.refreshDate, 1, 2)||' '||SUBSTR(gm.refreshDate, 11)
				ELSE gm.refreshDate
			END  AS [Market Generated]
		FROM goodsMarket AS gm
		WHERE [Market Generated] > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
		AND gm.location = '%Goods_DepartureICAO%'
		LIMIT 1
	)
	result := SQLiteGetTable(DB, query)
	If (result.RowCount < 1) {
		MsgBox, 64, Error: No Market Data, % "Could not find market at Departure ICAO.`n`nPlease try searching or previewing the market at " . Goods_DepartureICAO . ", then refreshing the missions."
		LV_Clear("Goods_MissionsLV")
		LV_Clear("Goods_TradeMissionsLV")
		LV_Clear("Goods_TradesLV")
		return
	}
	If (Goods_IncludeIllicit) {
		qIllicit := "!= -1"
	} Else {
		qIllicit := "!= 4"
	}
	qPayload := Plane.payload - Plane.fuel - Pilot.weight
	qPax := Plane.pax
	; Get NeoFly missions
	query =
	(
		SELECT
			m.id, 
			m.departure AS Departure, 
			m.arrival AS Arrival, 
			m.dist AS Distance, 
			m.pax AS Pax, 
			m.weight AS Cargo, 
			m.reward AS Pay, 
			m.missionTypeS AS [Mission Type], 
			m.xp AS XP, 
			0 AS [Trade Profit],
			0 AS [Total Income],
			0 AS [Income/nm],
			CASE SUBSTR(gm.refreshDate, 3, 1)
				WHEN '-' THEN SUBSTR(gm.refreshDate, 7, 4)||SUBSTR(gm.refreshDate, 4, 2)||SUBSTR(gm.refreshDate, 1, 2)||' '||SUBSTR(gm.refreshDate, 11)
				WHEN '/' THEN SUBSTR(gm.refreshDate, 7, 4)||SUBSTR(gm.refreshDate, 4, 2)||SUBSTR(gm.refreshDate, 1, 2)||' '||SUBSTR(gm.refreshDate, 11)
				WHEN '.' THEN SUBSTR(gm.refreshDate, 7, 4)||SUBSTR(gm.refreshDate, 4, 2)||SUBSTR(gm.refreshDate, 1, 2)||' '||SUBSTR(gm.refreshDate, 11)
				ELSE gm.refreshDate
			END  AS [Market Generated],
			'' AS [Can Buy At Arrival],
			CASE SUBSTR(m.expiration, 3, 1)
				WHEN '-' THEN SUBSTR(m.expiration, 7, 4)||SUBSTR(m.expiration, 4, 2)||SUBSTR(m.expiration, 1, 2)||' '||SUBSTR(m.expiration, 11)
				WHEN '/' THEN SUBSTR(m.expiration, 7, 4)||SUBSTR(m.expiration, 4, 2)||SUBSTR(m.expiration, 1, 2)||' '||SUBSTR(m.expiration, 11)
				WHEN '.' THEN SUBSTR(m.expiration, 7, 4)||SUBSTR(m.expiration, 4, 2)||SUBSTR(m.expiration, 1, 2)||' '||SUBSTR(m.expiration, 11)
				ELSE m.expiration
			END  AS [Mission Expiration]
		FROM missions AS m
		INNER JOIN goodsMarket AS gm
		ON gm.location=m.arrival
		WHERE
			departure='%Goods_DepartureICAO%'
			AND gm.location != '%Goods_DepartureICAO%'
			AND m.weight <= %qPayload%
			AND m.pax <= %qPax%
			AND m.misionType != 7
			AND m.misionType != 8
			AND m.misionType != 9
			AND m.misionType != 12
			AND [Mission Expiration] > DATETIME('now', 'localtime')
			AND [Market Generated] > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
		GROUP BY m.id
	)
	result := SQLiteGetTable(DB, query)
	; Analyze NeoFly missions
	Loop % result.RowCount {
		result.Next(Row)
		qDeparture := Row[2]
		qArrival := Row[3]
		qCargo := Row[6]
		qPay := Row[7]
		query = 
		(
			SELECT
				dep.name AS Good,
				replace(dep.unitWeight, ',', '.') AS [Weight/u],
				dest.unitPrice - dep.unitPrice AS [Profit/u],
				MIN(dest.quantity, dep.quantity) AS [Max Qty],
				CASE SUBSTR(dep.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					ELSE dep.refreshDate
				END  AS depRefreshFormatted,
				CASE SUBSTR(dest.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					ELSE dest.refreshDate
				END  AS destRefreshFormatted
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location='%qDeparture%'
				AND dep.type %qIllicit%
				AND dest.location='%qArrival%'
				AND dep.tradeType=0
				AND dest.tradeType=1
				AND depRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
				AND destRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			ORDER BY [Profit/u]/[Weight/u] DESC
		)
		clipboard := query
		resultGood := SQLiteGetTable(DB, query)
		totalProfit := 0
		availablePayload := Plane.payload - Plane.fuel - qCargo - Pilot.weight
		Loop % resultGood.RowCount {
			resultGood.Next(RowGood)
			maxQty := FLOOR(MIN(RowGood[4], availablePayload/RowGood[2]))
			totalProfit := totalProfit + (maxQty * RowGood[3])
			availablePayload -= maxQty*RowGood[2]
		}
		Row[10] := totalProfit
		Row[11] := totalProfit + Row[7]
		Row[12] := ROUND(Row[11]/Row[4],0)
		query = 
		(
			SELECT name FROM goodsMarket WHERE location='%qArrival%' AND tradetype=0 AND type %qIllicit% ORDER BY unitprice/unitweight DESC
		)
		resultAvailable := SQLiteGetTable(DB, query)
		Loop % resultAvailable.RowCount {
			resultAvailable.Next(RowAvailable)
			Row[14] := Row[14] . RowAvailable[1] . ", "
		}
	}
	result.Reset()
	LV_ShowTable(result, "Goods_MissionsLV")
	LV_ModifyCol(12, "SortDesc")
	; Get viable trade missions
	query = 
	(
		SELECT 
			'%Goods_DepartureICAO%' AS Departure, 
			gm.location AS Arrival, 
			0 AS [Trade Profit], 
			0 AS Distance, 
			0 AS [Profit/nm],
			a.lonx AS [Arrival Lon],
			a.laty AS [Arrival Lat],
			gm.minRefreshDate AS [Market Generated],
			'' AS [Can Buy At Arrival]
		FROM (
			SELECT
				dest.location AS location,
				MIN(dep.refreshDate, dest.refreshDate) AS minRefreshDate,
				CASE SUBSTR(dep.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					ELSE dep.refreshDate
				END  AS depRefreshFormatted,
				CASE SUBSTR(dest.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					ELSE dest.refreshDate
				END  AS destRefreshFormatted	
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location='%Goods_DepartureICAO%'
				AND dep.tradeType=0
				AND dest.tradeType=1
				AND depRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
				AND destRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime') 
			GROUP BY dest.location) AS gm
		INNER JOIN airport AS a
		ON a.ident=gm.location
	)
	result := SQLiteGetTable(DB, query)
	; Get plane location for distance calcs
	qPlaneID := Plane.id
	query = 
	(
		SELECT a.lonx, a.laty
		FROM airport AS a
		INNER JOIN hangar AS h
		ON a.ident=h.Location
		WHERE h.id=%qPlaneID%
		LIMIT 1
	)
	resultPlaneLoc := SQLiteGetTable(DB, query)
	resultPlaneLoc.GetRow(1, RowPlaneLoc)
	pilotLonX := RowPlaneLoc[1]
	pilotLatY := RowPlaneLoc[2]
	; Analyze each trade mission
	Loop % result.RowCount {
		result.Next(Row)
		qDeparture := Row[1]
		qArrival := Row[2]
		query = 
		(
			SELECT
				dep.name AS Good,
				replace(dep.unitWeight, ',', '.') AS [Weight/u],
				dest.unitPrice - dep.unitPrice AS [Profit/u],
				MIN(dest.quantity, dep.quantity) AS [Max Qty],
				CASE SUBSTR(dep.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					ELSE dep.refreshDate
				END  AS depRefreshFormatted,
				CASE SUBSTR(dest.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					ELSE dest.refreshDate
				END  AS destRefreshFormatted				
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location='%qDeparture%'
				AND dep.type %qIllicit%
				AND dest.location='%qArrival%'
				AND dep.tradeType=0
				AND dest.tradeType=1
				AND depRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
				AND destRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			ORDER BY [Profit/u]/[Weight/u] DESC
		)
		resultGood := SQLiteGetTable(DB, query)
		totalProfit := 0
		availablePayload := Plane.payload - Plane.fuel - Pilot.weight
		Loop % resultGood.RowCount {
			resultGood.Next(RowGood)
			maxQty := FLOOR(MIN(RowGood[4], availablePayload/RowGood[2]))
			totalProfit += maxQty * RowGood[3]
			availablePayload := availablePayload - maxQty*RowGood[2]
		}
		Row[3] := totalProfit
		Row[4] := ROUND(0.000539957*InvVincenty(pilotLatY, pilotLonX, Row[7], Row[6]), 0)
		Row[5] := ROUND(Row[3]/Row[4],0)
		query = 
		(
			SELECT name FROM goodsMarket WHERE location='%qArrival%' AND tradetype=0 AND type %qIllicit% ORDER BY unitprice/unitweight DESC
		)
		resultAvailable := SQLiteGetTable(DB, query)
		Loop % resultAvailable.RowCount {
			resultAvailable.Next(RowAvailable)
			Row[9] := Row[9] . RowAvailable[1] . ", "
		}
	}
	result.Reset()
	LV_ShowTable(result, "Goods_TradeMissionsLV")
	LV_ModifyCol(5, "SortDesc")
	SB_SetText("Missions refreshed")
	return
}

Goods_MissionsLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
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
	return
}

Goods_TradeMissionsLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
		Gui, ListView, Goods_TradeMissionsLV
		LV_GetText(lvDeparture, A_EventInfo, 1)
		LV_GetText(lvArrival, A_EventInfo, 2)
		GuiControl, , Goods_MissionWeight, 0
		GuiControl, , Goods_ArrivalICAO, % lvArrival
		GuiControl, , Goods_MissionInfo, % lvDeparture . ">" . lvArrival . " - Goods Trade / Transit"
		GoSub Goods_RefreshMarket
	}
	return
}

Goods_RefreshMarket:
{
	SB_SetText("Refreshing optimal goods...")
	GuiControlGet, Goods_DepartureICAO
	GuiControlGet, Goods_ArrivalICAO
	GuiControlGet, Goods_MissionWeight
	; Get trades possible from current Dep/Arrival combination
	query = 
	(
		SELECT
			dep.name AS Good,
			CASE
				WHEN dep.type = 1 THEN 'Normal'
				WHEN dep.type = 2 THEN 'Fragile'
				WHEN dep.type = 3 THEN 'Perishable'
				WHEN dep.type = 4 THEN 'Illicit'
				ELSE 'Unknown' 
			END Type,
			replace(dep.unitWeight, ',', '.') AS [Weight/u],
			dep.quantity AS [Have at %Goods_DepartureICAO%],
			dep.unitPrice AS [Buy Price],
			dest.quantity AS [Want at %Goods_ArrivalICAO%],
			dest.unitPrice AS [Sell Price],
			dest.unitPrice - dep.unitPrice AS [Profit/u],
			ROUND((dest.unitPrice - dep.unitPrice)/CAST(replace(dep.unitWeight, ',', '.') AS NUMERIC),2) AS [Profit/lb],
			MIN(dest.quantity, dep.quantity) AS [Max Qty],
			0 AS [Buy Cost],
			MIN(dest.quantity, dep.quantity)*(dest.unitPrice-dep.unitPrice) AS [Max Profit],
			replace(dep.unitWeight, ',', '.')*MIN(dest.quantity, dep.quantity) AS [Max Weight]
		FROM
			goodsMarket AS dep
		INNER JOIN
			goodsMarket AS dest ON dep.name=dest.name
		WHERE
			dep.location='%Goods_DepartureICAO%'
			AND dep.type %qIllicit%
			AND dest.location='%Goods_ArrivalICAO%'
			AND dep.tradeType=0
			AND dest.tradeType=1
			AND CASE SUBSTR(dep.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					ELSE dep.refreshDate
				END > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			AND CASE SUBSTR(dest.refreshDate, 3, 1)
					WHEN '-' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '/' THEN SUBSTR(dest.refreshDate, 7, 4)||SUBSTR(dest.refreshDate, 4, 2)||SUBSTR(dest.refreshDate, 1, 2)||' '||SUBSTR(dest.refreshDate, 11)
					WHEN '.' THEN SUBSTR(dep.refreshDate, 7, 4)||SUBSTR(dep.refreshDate, 4, 2)||SUBSTR(dep.refreshDate, 1, 2)||' '||SUBSTR(dep.refreshDate, 11)
					ELSE dest.refreshDate
				END > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
		ORDER BY [Profit/lb] DESC
	)
	result := SQLiteGetTable(DB, query)
	; Optimize these trades
	simPayload := Plane.payload - Plane.fuel
	totalProfit := 0
	availablePayload := Plane.payload - Plane.fuel- Goods_MissionWeight - Pilot.weight
	goodsWeight := availablePayload
	result.ColumnNames[10] := "Buy Qty"
	result.ColumnNames[12] := "Profit"
	result.ColumnNames[13] := "Weight"
	Loop % result.RowCount {
		result.Next(Row)
		maxQty := FLOOR(MIN(Row[10], availablePayload/Row[3]))
		Row[10] := maxQty
		Row[12] := maxQty * Row[8]
		Row[11] := maxQty * Row[5]
		Row[13] := Round(maxQty * Row[3],2)
		totalProfit += Row[12]
		availablePayload := availablePayload - maxQty*Row[3]
	}
	result.Reset()
	goodsWeight -= availablePayload
	GuiControl, , Goods_PayloadInfo, % ROUND(simPayload-availablePayload,2) . " / " . simPayload . "lbs (" . CEIL((simPayload-availablePayload)*100/simPayload) . "%)"
	GuiControl, , Goods_GoodsWeight, % ROUND(goodsWeight,0)
	LV_ShowTable(result, "Goods_TradesLV")
	SB_SetText("Optimal goods refreshed")
	return
}

; == Subroutines - Aircraft Market Tab ==
AircraftMarket_Search:
{
	SB_SetText("Searching aircraft market...")
	GuiControlGet, AircraftMarket_Aircraft
	moveCostPerMile := 9.0
	query = 
	(	
		SELECT lonx, laty FROM airport WHERE ident=(SELECT pilotCurrentICAO FROM career WHERE id=(SELECT pilotID FROM currentPilot LIMIT 1) LIMIT 1) LIMIT 1
	)
	result := SQLiteGetTable(DB, query)
	If (!result.HasRows) {
		return
	} Else {
		result.GetRow(1, Row)
		pilotLonX := Row[1]
		pilotLatY := Row[2]
	}

	qPilotWeight := Pilot.weight
	query = 
	(
		SELECT
			am.aircraft AS Airplane,
			airport.ident AS Location,
			am.cost AS Price,
			0 AS [Travel Cost],
			0 AS [Total Cost],
			0 AS [Distance],
			airport.lonx AS Longitude,
			airport.laty AS Latitude,
			am.Qualification AS Qualification,
			ad.CruiseSpeedktas AS [Cruise Speed (kts)],
			ad.rangenm AS [Range(nm)],
			ad.FuelCaplbs AS [Max Fuel(lbs)],
			ad.MaxPayloadlbs AS [Max Payload],
			ad.MaxPayloadlbs - (ad.FuelCaplbs*%fuelPercentForAircraftMarketPayload%) - %qPilotWeight% AS [Effective Payload],
			ad.Pax AS [Pax],
			0 AS [Cost/Range]	,
			0 AS [Cost/Payload],
			0 AS [Cost/Effective Payload],
			0 AS [Cost/Pax]			
		FROM
			airport
		INNER JOIN 
			aircraftMarket AS am
		ON
			airport.ident = am.location
		INNER JOIN 
			aircraftData AS ad
		ON 
			ad.Aircraft = am.Aircraft
		WHERE
			am.aircraft LIKE '`%%AircraftMarket_Aircraft%`%'
		ORDER BY
			Price ASC
	)

	result := SQLiteGetTable(DB, query)
	Loop % result.RowCount {
		result.Next(Row)
		Row[6] := ROUND(0.000539957*InvVincenty(pilotLatY, pilotLonX, Row[8], Row[7]), 0)
		Row[4] := ROUND(Row[6] * moveCostPerMile,0)
		Row[5] := ROUND(Row[3] + Row[4],0)
		Row[16] := ROUND(Row[5] / Row[11],0) ; Cost/range
		Row[17] := ROUND(Row[5] / Row[13],0) ; Cost/payload
		Row[18] := ROUND(Row[5] / Row[14],0) ; Cost/effective payload
		Row[19] := ROUND(Row[5] / Row[15],0) ; Cost/Pax
	}
	result.reset()
	LV_ShowTable(result, "AircraftMarket_LV")
	LV_ModifyCol(5, "Sort")
	SB_SetText("Aircraft market searched")
	return
}

; == Subroutines - Mission Generator Tab ==
Generator_Backup:
{
	SB_SetText("Backing up database...")
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
	SB_SetText("Database backup performed")
	return
}

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
	return
}

Generator_Distance:
{
	GuiControlGet, Generator_lonDep
	GuiControlGet, Generator_latDep
	GuiControlGet, Generator_lonArriv
	GuiControlGet, Generator_latArriv
	distanceNM := ROUND(0.000539957*InvVincenty(Generator_latDep, Generator_lonDep, Generator_latArriv, Generator_lonArriv),0)
	GuiControl, , Generator_dist, % distanceNM
	return
}

Generator_Preview:
{
	SB_SetText("Generating mission previews...")
	Gui, Submit, NoHide
	Switch Generator_rankS
	{
		Case "Cadet": 
			Generator_rank := 0
			Generator_rankI := "img/r0.png"
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
			Generator_rankI := "img/r0.png"
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
		Case "Humanitarian": 
			Generator_misionType := 12
			Generator_missionTypeImage := "img/m12.png"
			return
		Default: 
			Generator_misionType := 1
	}
	
	query := ""
	Loop % Generator_Quantity {
		Random, rand, 0.0, 1.0
		If (Generator_RandomizePax) {
			qPax := MIN(ROUND((rand*Generator_pax+1),0), Generator_Pax)
		} Else {
			qPax := Generator_Pax
		}
		If (Generator_RandomizeWeight) {
			qWeight := ROUND(rand*Generator_weight, 0)
		} Else {
			qWeight := Generator_weight
		}
		If (Generator_RandomizeReward) {
			porportionalReward := 0.70 ; No matter what the 'rand' value is, reward will be at least this porportion of the original reward
			qReward := ROUND(rand*Generator_reward*(1-porportionalReward) + Generator_reward*porportionalReward, 0)
		} Else {
			qReward := Generator_reward
		}
		nextQuery =
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
				%qPax% AS pax,
				%qWeight% AS weight,
				%qReward% AS reward,
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
				%Generator_xp% AS xp
		)
		query := query . nextQuery
		If (A_Index<Generator_Quantity) {
			query := query . " UNION ALL "
		}
	}
	result := SQLiteGetTable(DB, query)
	LV_ShowTable(result, "Generator_PreviewLV")
	SB_SetText("Mission previews generated")
	return
}

Generator_PreviewLVClick:
{
	If (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
		SB_SetText("Committing mission to database...")
		Gui, ListView, Goods_PreviewLV
		varList := ""
		Loop % LV_GetCount("Column") {
			LV_GetText(qVar%A_Index%, A_EventInfo, A_Index)
		}

		query = 
		(
			INSERT INTO missions 
			SELECT
				'%qVar1%' AS departure,
				'%qVar2%' AS latDep,
				'%qVar3%' AS lonDep,
				'%qVar4%' AS escale,
				%qVar5% AS latEsc,
				%qVar6% AS lonEsc,
				'%qVar7%' AS arrival,
				'%qVar8%' AS latArriv,
				'%qVar9%' AS lonArriv,
				%qVar10% AS altMax,
				%qVar11% AS consigne,
				'%qVar12%' AS delay,
				%qVar13% AS dist,
				%qVar14% AS flightType,
				%qVar15% AS misionType,
				%qVar16% AS pax,
				%qVar17% AS weight,
				%qVar18% AS reward,
				%qVar19% AS vsMax,
				'%qVar20%' AS request,
				'%qVar21%' AS nameAirport,
				'%qVar22%' AS missionTypeS,
				'%qVar23%' AS flightTypeS,
				'%qVar24%' AS missionTypeImage,
				'%qVar25%' AS available,
				'%qVar26%' AS deadline,
				'%qVar27%' AS expiration,
				'%qVar28%' AS fp,
				'%qVar29%' AS misstoolTip,
				%qVar30% AS rank,
				'%qVar31%' AS rankS,
				'%qVar32%' AS rankI,
				'%qVar33%' AS liveID,
				%qVar34% AS xp,
				(SELECT id FROM missions ORDER BY id DESC LIMIT 1)+1 AS id
		)
		
		DB.CloseDB()
		GuiControlGet, Settings_DBPath
		If (!DB.OpenDB(Settings_DBPath, "W", false)) {
			MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
			return
		}
		If (!DB.Exec(query)) {
			MsgBox, 20, SQLite Error: SQLiteGetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`nQuery: `t" . query . "`n`nEnsure that the SQL query is valid`n`nDo you want to copy the query to the clipboard?"
			return
		}
		query =
		(
			SELECT id FROM missions ORDER BY id DESC LIMIT 1
		)
		result := SQLiteGetTable(DB, query)
		result.GetRow(1,Row)
		insertedId := Row[1]

		DB.CloseDB()
		If (!DB.OpenDB(Settings_DBPath, "R", false)) {
			MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
			return
		}
		GuiControlGet, Generator_AddedIDs
		GuiControl, , Generator_AddedIDs, % Generator_AddedIDs . insertedId . "`n"
		LV_Delete(A_EventInfo)
		SB_SetText("Mission entered into database. ID: " . insertedId)
	}
	return
}

; ==== FUNCTIONS ====

; == SQL functions ==
SQLiteGetTable(database, query) {
	resultTable := ""
	If (!database.GetTable(query, resultTable)) {
		
		MsgBox, 20, SQLite Error: SQLiteGetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`nQuery: `t" . query . "`n`nEnsure the database is connected in the settings tab, and that the SQL query is valid`n`nDo you want to copy the query to the clipboard?"
		IfMsgBox Yes
		{
			clipboard := query
		}
	}
	return resultTable
}

; == ListView functions ==
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
				Loop, % Table.ColumnCount {
					LV_Modify(RowCount, "Col" . A_Index, stRow[A_Index])
				}
			}
		}
	}
    Loop, % Table.ColumnCount {
        LV_ModifyCol(A_Index, "AutoHdr")
		LV_GetText(numberCheck, 1, A_Index)
		If numberCheck Is digit
		{
			LV_ModifyCol(A_Index, "Integer")
		}
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
