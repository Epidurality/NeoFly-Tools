; AHK Settings
{
#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%
}

versionNumber := "0.3.0"

; Updates:			https://github.com/Epidurality/NeoFly-Tools/

; Script Function:  Small collection of tools for use with the NeoFly career mode addon for MSFS 2020 (https://www.neofly.net/).
; Language:         English
; Tested on:        Windows 10 64-bit
; Author:           Epidurality

; =============== USER CONFIGURABLE OPTIONS ==================

; This should be the path to your common.db neofly database.
global defaultDbPath := "C:\ProgramData\NeoFly\common.db"

; Automatically connects to the DBPath on startup if TRUE.
global autoConnect := FALSE

; Index of the date format to be used by default. They are numbered starting at 1, following the order of the DropDown in the Settings tab
global defaultMissionDateFormat := 1
global defaultGoodsDateFormat := 1

; The number of which tab to open to by default if AutoConnect is true (otherwise will default to the Settings tab). 1: Settings, 2: Goods Optimizer, etc in order of how they appear in the GUI.
global autoConnectDefaultTab := 2

; Set to TRUE if you don't want to have the tray icon appear in your system notification area.
global hideTrayIcon := FALSE

; Change this to any valid AutoHotkey key combination, and it will act as the Hotkey for the Auto-Market entry initiation.
global autoMarketHotkey := "NumpadEnter"

; =============== EDITING ANYTHING BELOW HERE COULD BLOW THINGS UP ==================

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
	Gui, Add, Tab3, vGUI_Tabs, Settings|Goods Optimizer|Market Finder|Aircraft Market|Mission Generator|Auto-Market
	Gui, Add, StatusBar
}

; GUI Settings tab
{
	Gui, Tab, Settings
	Gui, Add, Text, , Database path:
	Gui, Add, Edit, x+10 w300 vSettings_DBPath, % defaultDbPath
	Gui, Add, Button, x+20 gSettings_Connect, Connect
	Gui, Add, Button, x+40 gSettings_Disconnect, Disconnect
	Gui, Add, Text, x+50, NeoFly Tools Version: v%versionNumber%

	Gui, Add, Text, xm+10 y+30, Selected Pilot:
	Gui, Add, Text, x+10 vSettings_Pilot, Connect to a database to get pilot information.
	Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vSettings_PilotLV gSettings_PilotLVClick
	Gui, Add, Text, xm+10 y+20,
	(
	Notes:
	Missions, Goods Market, and Aircraft Market are shared between Pilots.
	Selecting a pilot here effectively just filters your Hangar in the Goods Optimizer.
	The current NeoFly pilot will be used by default when you Connect to the database.
	)
	Gui, Add, Text, xm+10 y+40 w200, Mission.Expiration format:
	Gui, Add, DropDownList, x+10 w200 vSettings_MissionDateFormat Choose%defaultMissionDateFormat%, yyyy/mm/dd|dd/mm/yyyy|mm/dd/yyyy
	Gui, Add, Text, xm+10 y+10 w200, GoodsMarket.RefreshDate format:
	Gui, Add, DropDownList, x+10 w200 vSettings_GoodsDateFormat Choose%defaultGoodsDateFormat%, yyyy/mm/dd|dd/mm/yyyy|mm/dd/yyyy
	Gui, Add, Button, x+20 w150 y+-40 gSettings_TimestampCheck, Check Timestamp Formatting
	Gui, Add, Text, xm+10 y+25, Note: The '/' can be any character and leading zeroes don't matter, for example: yyyy.m.d format will work when using yyyy/mm/dd option. Use the button above to double-check.
	Gui, Add, Text, xm+10 y+20, Date Formatting Samples from Database:`t`t`tNote: These dates are drawn from the Missions and GoodsMarket database, so you must have data in them.
	Gui, Add, ListView, xm+10 y+10 w915 h150 vSettings_TimestampLV, 
}

; GUI Goods Optimizer tab
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

	Gui, Add, Button, xm+600 y50 w150 gGoods_RefreshHangar, Refresh Hangar
	Gui, Add, CheckBox, x+30 y+-15 vGoods_HangarAll gGoods_RefreshHangar, Show All
	Gui, Add, Text, xm+600 y+10 w300 vGoods_Hangar, Hangar:
	Gui, Add, ListView, xm+350 y+10 w575 h150 Grid vGoods_HangarLV gGoods_HangarLVClick

	Gui, Add, Button, xm+10 w125 y230 gGoods_RefreshMissions, Refresh Missions
	Gui, Add, CheckBox, x+10 y+-50 vGoods_IncludeIllicit, Include Illicit Goods
	Gui, Add, Checkbox, xp y+10 vGoods_IncludeFragile Checked, Include Fragile Goods
	Gui, Add, Checkbox, xp y+10 vGoods_IncludePerishable Checked, Include Perishable Goods
	Gui, Add, Checkbox, xp y+10 vGoods_IncludeNormal Checked, Include Normal Goods
	Gui, Add, Text, xm+10 y+5 w125 vGoods_Missions, NeoFly Missions:
	Gui, Add, Text, x+40 w700 vGoods_MissionsText,
	Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vGoods_MissionsLV gGoods_MissionsLVClick

	Gui, Add, Text, xm+10 y+10 w500 vGoods_TradeMissions, Trade / Transit Missions:
	Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vGoods_TradeMissionsLV gGoods_TradeMissionsLVClick

	Gui, Add, Text, xm+10 y+20 w400 vGoods_Trades, Optimal Goods:
	Gui, Add, ListView, w915 h100 Grid vGoods_TradesLV
}

; GUI Market Finder tab
{
	Gui, Tab, Market Finder
	Gui, Add, Text, xm+10 ym+50 w50, Name:
	Gui, Add, ComboBox, x+10 w200 vMarket_Name, ||Beer|Caviar|Cigarette|Clothes|Coffee|Computer|Contraband Cigars|Fish|Flower|Fruit|Fuel|Magazine|Meat|Mechanical parts|Medicine|Old wine|Phone|Pillza|Vegetable|Whiskey
	Gui, Add, Text, x+20 yp+5, I want to
	Gui, Add, Radio, x+10 yp-5 vMarket_RadioBuy, Buy
	Gui, Add, Radio, y+10 Checked vMarket_RadioSell, Sell
	Gui, Add, Button, x+30 y+-30 gMarket_Search, Search

	Gui, Add, Text, xm+10 y+10 w300, Leave the Name field blank to search for goods of any name.

	Gui, Add, Text, xm+10 y+20 w50, Type(s):
	Gui, Add, CheckBox, x+10 Checked vMarket_Normal, Normal
	Gui, Add, CheckBox, y+10 Checked vMarket_Fragile, Fragile
	Gui, Add, CheckBox, y+10 Checked vMarket_Perishable, Perishable
	Gui, Add, CheckBox, y+10 Checked vMarket_Illicit, Illicit

	Gui, Add, Text, xm+10 y+20 w50, Minimum Price:
	Gui, Add, Edit, x+10 w50 vMarket_MinimumPrice, 0
	Gui, Add, Text, x+30 w50, Maximum Price:
	Gui, Add, Edit, x+10 w50 vMarket_MaximumPrice, 9999

	Gui, Add, ListView, xm+10 y+30 w915 h400 Grid vMarket_MarketLV
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
	Gui, Add, Edit, x+10 w150 vGenerator_expiration,

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

; GUI Auto-Market
{
	Gui, Tab, Auto-Market
	Gui, Add, Text, xm+10 ym+50, Center ICAO:
	Gui, Add, Edit, x+10 w50 vAuto_CenterICAO, KJFK
	Gui, Add, Text, x+30, Max. Distance
	Gui, Add, Edit, x+10 w75 vAuto_MaxDistance, 100
	
	Gui, Add, Button, xm+10 y+20 gAuto_List, List ICAOs
	Gui, Add, Text, x+40, 
	(
List is generated by using active Missions at the Center ICAO as a list of viable market destinations, and filters out ones with already valid markets.
If no ICAOs are showing, try Searching or Resetting your Missions at the Center ICAO.
	)
	
	Gui, Add, Text, xm+10 y+20, ICAOs to Search:
	Gui, Add, ListView, xm+10 y+10 w915 h300 vAuto_ListLV
	
	Gui, Add, Button, xm+10 y+20 gAuto_Load, Load for Entry
	Gui, Add, Button, x+30 gAuto_Unload, Stop Entry
	Gui, Add, Checkbox, x+30 vAuto_IgnoreWindow, Ignore Active Window Check (only use if script is not properly detecting that NeoFly is the active window)
	
	Gui, Add, Text, xm+10 y+30, 
	(
Ensure your cursor is in the ICAO edit box in the NeoFly Market tab. 
When you press {%autoMarketHotkey%}, this script will go through each ICAO you've selected above, doing the following:
	1. Send Ctrl+A to highlight any text in the ICAO box
	2. Send the new ICAO name, corresponding to the first selected ICAO left in the list view above
	3. Send the Enter key to search the Market
	4. Remove the already-searched ICAO from the list above.
Press the {%autoMarketHotkey%} again, and it will do the same with the next selected ICAO.
The Hotkey is only active after you've pressed Load for Entry. Active status is confirmed by a tooltip appearing by your cursor.
You can Ctrl+Click or Shift+Click to multi-select entries in the table above. You can also change your entries while the Hotkey is active.
You can change the Hotkey from {%autoMarketHotkey%} to whatever you'd like by modifying the defaults at the top of the script (if using script version - no .ini file yet available for binary).
	)
	
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
	SB_SetText("Opening " . Settings_DBPath . "...")
	DB := new SQLiteDB
	GuiControlGet, Settings_DBPath
	If (!DB.OpenDB(Settings_DBPath, "R", False)) { ; Connect read-only
		MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		return
	}
	; Get the list of pilots
	query =
	(
		SELECT career.name AS [Pilot Callsign], career.id, currentPilot.pilotID AS [Current NeoFly Pilot] FROM career LEFT JOIN currentPilot ON career.id=currentPilot.pilotID
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
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
	query = 
	(
		SELECT expiration FROM missions ORDER BY id DESC LIMIT 1
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	If (!result.RowCount) {
		GuiControl, , Generator_expiration, DATE HERE
	} Else {
		result.Next(Row)
		GuiControl, , Generator_expiration, % Row[1]
	}
	SB_SetText("Opened " . Settings_DBPath)
	return
}

Settings_Disconnect:
{
	SB_SetText("Disconnecting from the database...")
	DB.CloseDB()
	GuiControl, , Settings_Pilot, % "Connect to a database to select a pilot"
	LV_Clear("Settings_PilotLV")
	LV_Clear("Goods_HangarLV")
	LV_Clear("Goods_MissionsLV")
	LV_Clear("Goods_TradeMissionsLV")
	LV_Clear("Goods_TradesLV")
	SB_SetText("Disconnected from the database")
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

Settings_TimestampCheck:
{
	SB_SetText("Checking timestamp conversion...")
	GuiControlGet, Settings_MissionDateFormat
	GuiControlGet, Settings_GoodsDateFormat
	qExpiration := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "expiration")
	qRefreshDate := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "refreshDate")
	query = 
	( 
		SELECT * FROM (
			SELECT DISTINCT 'GoodsMarket.RefreshDate' AS [DB Field], refreshDate AS [DB Value], %qRefreshDate% AS Formatted, IFNULL(datetime(%qRefreshDate%), 'INVALID') AS [Validation] FROM goodsMarket ORDER BY id DESC LIMIT 300 )
		UNION ALL SELECT * FROM (
			SELECT DISTINCT 'Missions.Expiration' AS [DB Field], expiration AS [DB Value], %qExpiration% AS Formatted, IFNULL(datetime(%qExpiration%), 'INVALID') AS [Validation] FROM missions ORDER BY id DESC LIMIT 300 )
		ORDER BY Validation DESC
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	LV_ShowTable(result, "Settings_TimestampLV")
	SB_SetText("Timestamp conversions previewed.")
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
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
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
	LV_Clear("Goods_TradeMissionsLV")
	LV_Clear("Goods_MissionsLV")
	LV_Clear("Goods_TradesLV")
	GuiControl, , Goods_ArrivalICAO, ---
	GuiControl, , Goods_MissionWeight, ---
	GuiControl, , Goods_GoodsWeight, ---
	GuiControl, , Goods_MissionsText, 
	GuiControlGet, Goods_DepartureICAO
	GuiControlGet, Goods_IncludeIllicit
	GuiControlGet, Goods_IncludeNormal
	GuiControlGet, Goods_IncludeFragile
	GuiControlGet, Goods_IncludePerishable
	GuiControlGet, Settings_MissionDateFormat
	GuiControlGet, Settings_GoodsDateFormat

	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	query = 
	(
		SELECT 
			%qRefreshDateField%  AS [Market Generated]
		FROM goodsMarket AS gm
		WHERE 
			[Market Generated] > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			AND gm.location = '%Goods_DepartureICAO%'
		LIMIT 1
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	If (result.RowCount < 1) {
		GuiControl, , Goods_MissionsText, % "Could not find market at Departure ICAO: '" . Goods_DepartureICAO . "' . Please try searching or previewing the market in NeoFly, then refreshing."
		LV_Clear("Goods_MissionsLV")
		LV_Clear("Goods_TradeMissionsLV")
		LV_Clear("Goods_TradesLV")
		return
	}
	goodsChecked := 0
	If (Goods_IncludeIllicit) {
		qIllicit := "!= -1"
		goodsChecked := 1
	} Else {
		qIllicit := "!= 4"
	}
	If (Goods_IncludeNormal) {
		qNormal := "!= -1"
		goodsChecked := 1
	} Else {
		qNormal := "!= 1"
	}
	If (Goods_IncludeFragile) {
		qFragile := "!= -1"
		goodsChecked := 1
	} Else {
		qFragile := "!= 2"
	}
	If (Goods_IncludePerishable) {
		qPerishable := "!= -1"
		goodsChecked := 1
	} Else {
		qPerishable := "!= 3"
	}
	if (goodsChecked=0) {
		MsgBox, 48, Error: No goods types, You must include at least 1 type of good.
		return
	}
	qPayload := Plane.payload - Plane.fuel - Pilot.weight
	qPax := Plane.pax
	; Get NeoFly missions
	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	qExpirationField := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "m.expiration")
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
			%qRefreshDateField%  AS [Market Generated],
			'' AS [Can Buy At Arrival],
			%qExpirationField% AS [Mission Expiration]
		FROM missions AS m
		LEFT JOIN goodsMarket AS gm
		ON gm.location=m.arrival
		WHERE
			departure='%Goods_DepartureICAO%'
			AND gm.location != '%Goods_DepartureICAO%'
			AND m.weight <= %qPayload%
			AND m.pax <= %qPax%
			AND [Mission Expiration] > DATETIME('now', 'localtime')
			AND [Market Generated] > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
		GROUP BY m.id
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	; Analyze NeoFly missions
	If (result.RowCount<1) {
		GuiControl, , Goods_MissionsText, % "Could not find missions at Departure ICAO: '" . Goods_DepartureICAO . "' . Please try searching for missions in NeoFly and markets at their destinations, then refreshing."
	}
	qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
	qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
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
				%qDepRefreshDateField% AS depRefreshFormatted,
				%qDestRefreshDateField% AS destRefreshFormatted
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location='%qDeparture%'
				AND dep.type %qIllicit%
				AND dep.type %qNormal%
				AND dep.type %qPerishable%
				AND dep.type %qFragile%
				AND dest.location='%qArrival%'
				AND dep.tradeType=0
				AND dest.tradeType=1
				AND depRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
				AND destRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			ORDER BY [Profit/u]/[Weight/u] DESC
		)
		clipboard := query
		If !(resultGood := SQLiteGetTable(DB, query)) {
			return
		}
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
		If !(resultAvailable := SQLiteGetTable(DB, query)) {
			return
		}
		Loop % resultAvailable.RowCount {
			resultAvailable.Next(RowAvailable)
			Row[14] := Row[14] . RowAvailable[1] . ", "
		}
	}
	result.Reset()
	LV_ShowTable(result, "Goods_MissionsLV")
	LV_ModifyCol(12, "SortDesc")
	
	; Get viable trade missions
	qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
	qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
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
				%qDepRefreshDateField% AS depRefreshFormatted,
				%qDestRefreshDateField% AS destRefreshFormatted	
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location='%Goods_DepartureICAO%'
				AND dep.type %qIllicit%
				AND dep.type %qNormal%
				AND dep.type %qPerishable%
				AND dep.type %qFragile%
				AND dep.tradeType=0
				AND dest.tradeType=1
				AND depRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
				AND destRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime') 
			GROUP BY dest.location) AS gm
		INNER JOIN airport AS a
		ON a.ident=gm.location
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	If (result.RowCount < 1) {
		GuiControl, , Goods_MissionsText, % "Could not find any suitable markets to trade with. Please try searching or previewing more markets in NeoFly, then refreshing."
	}
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
	If !(resultPlaneLoc := SQLiteGetTable(DB, query)) {
		return
	}
	resultPlaneLoc.GetRow(1, RowPlaneLoc)
	pilotLonX := RowPlaneLoc[1]
	pilotLatY := RowPlaneLoc[2]
	; Analyze each trade mission
	qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
	qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
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
				%qDepRefreshDateField% AS depRefreshFormatted,
				%qDestRefreshDateField% AS destRefreshFormatted				
			FROM
				goodsMarket AS dep
			INNER JOIN
				goodsMarket AS dest ON dep.name=dest.name
			WHERE
				dep.location='%qDeparture%'
				AND dep.type %qIllicit%
				AND dep.type %qNormal%
				AND dep.type %qPerishable%
				AND dep.type %Fragile%
				AND dest.location='%qArrival%'
				AND dep.tradeType=0
				AND dest.tradeType=1
				AND depRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
				AND destRefreshFormatted > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			ORDER BY [Profit/u]/[Weight/u] DESC
		)
		If !(resultGood := SQLiteGetTable(DB, query)) {
			return
		}
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
		If !(resultAvailable := SQLiteGetTable(DB, query)) {
			return
		}
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
	GuiControlGet, Goods_IncludeIllicit
	GuiControlGet, Goods_IncludeNormal
	GuiControlGet, Goods_IncludeFragile
	GuiControlGet, Goods_IncludePerishable	
	GuiControlGet, Settings_MissionDateFormat
	GuiControlGet, Settings_GoodsDateFormat
	goodsChecked := 0
	If (Goods_IncludeIllicit) {
		qIllicit := "!= -1"
		goodsChecked := 1
	} Else {
		qIllicit := "!= 4"
	}
	If (Goods_IncludeNormal) {
		qNormal := "!= -1"
		goodsChecked := 1
	} Else {
		qNormal := "!= 1"
	}
	If (Goods_IncludeFragile) {
		qFragile := "!= -1"
		goodsChecked := 1
	} Else {
		qFragile := "!= 2"
	}
	If (Goods_IncludePerishable) {
		qPerishable := "!= -1"
		goodsChecked := 1
	} Else {
		qPerishable := "!= 3"
	}
	if (goodsChecked=0) {
		MsgBox, 48, Error: No goods types, You must include at least 1 type of good.
		return
	}
	; Get trades possible from current Dep/Arrival combination
	qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
	qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
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
			AND dep.type %qNormal%
			AND dep.type %qPerishable%
			AND dep.type %qFragile%
			AND dest.location='%Goods_ArrivalICAO%'
			AND dep.tradeType=0
			AND dest.tradeType=1
			AND %qDepRefreshDateField% > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			AND %qDestRefreshDateField% > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
		ORDER BY [Profit/lb] DESC
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
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

; == Subroutines - Market Finder tab
Market_Search:
{
	SB_SetText("Searching the markets...")
	GuiControlGet, Market_Name
	GuiControlGet, Market_RadioBuy
	GuiControlGet, Market_RadioSell
	GuiControlGet, Market_Normal
	GuiControlGet, Market_Fragile
	GuiControlGet, Market_Perishable
	GuiControlGet, Market_Illicit
	GuiControlGet, Market_MinimumPrice
	GuiControlGet, Market_MaximumPrice
	GuiControlGet, Settings_GoodsDateFormat
	qTypeConditions := ""
	If (Market_Normal=1) {
		qTypeConditions := qTypeConditions . "OR type=1 "
	}
	If (Market_Fragile=1) {
		qTypeConditions := qTypeConditions . "OR type=2 "
	}
	If (Market_Perishable=1) {
		qTypeConditions := qTypeConditions . "OR type=3 "
	}
	If (Market_Illicit=1) {
		qTypeConditions := qTypeConditions . "OR type=4 "
	}
	qTypeConditions := SubStr(qTypeConditions, 3)
	If (qTypeConditions="") {
		MsgBox, 48, Error: No types chosen, You must choose at least one Type checkbox.
		return
	}
	If (Market_RadioSell=1) {
		qTradeType := 1
	} Else {
		qTradeType := 0
	}
	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "refreshDate")
	query =
	(
		SELECT
			name AS Good,
			CASE
				WHEN type = 1 THEN 'Normal'
				WHEN type = 2 THEN 'Fragile'
				WHEN type = 3 THEN 'Perishable'
				WHEN type = 4 THEN 'Illicit'
				ELSE 'Unknown' 
			END Type,
			location AS Location,
			quantity AS [Quantity],
			unitprice AS [Price/u],
			unitweight AS [Price/lb],
			CASE
				WHEN tradetype = 0 THEN 'For Sale'
				WHEN tradetype = 1 THEN 'Will Buy'
				ELSE 'Unknown'
			END [Trade Type],
			CASE ttl
				WHEN 720 THEN ''
				WHEN 0 THEN ''
				ELSE ttl
			END AS [Time to Live],
			%qRefreshDateField% AS [Market Generated],
			id AS [Database ID]
		FROM goodsMarket
		WHERE
			name LIKE '`%%Market_Name%`%'
			AND [Market Generated] > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			AND (%qTypeConditions%)
			AND tradetype = %qTradeType%
		ORDER BY Location ASC
	)
	clipboard := query
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	LV_ShowTable(result, "Market_MarketLV")
	SB_SetText("Markets searched")
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
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
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

	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
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
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	result.GetRow(1, DepRow)
	lonDep := DepRow[1]
	latDep := DepRow[2]
	query = 
	(
		SELECT lonx, laty FROM airport WHERE ident='%Generator_arrival%' LIMIT 1
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
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
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
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
		If !(result := SQLiteGetTable(DB, query)) {
			return
		}
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

; == Subroutines - Auto-Market tab
Auto_List:
{
	SB_SetText("Finding list of mission destinations...")
	GuiControlGet, Auto_CenterICAO
	GuiControlGet, Auto_MaxDistance
	GuiControlGet, Settings_MissionDateFormat
	qExpiration := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "m.expiration")
	qRefreshDate := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "refreshDate")
	query = 
	(
		SELECT DISTINCT 
			m.arrival AS ICAO, 
			m.dist AS Distance,
			' ' AS ' '
		FROM
			missions AS m
		INNER JOIN
			airport AS a
		ON
			a.ident = m.arrival
		WHERE
			m.departure = '%Auto_CenterICAO%'
			AND m.dist <= %Auto_MaxDistance%
			AND %qExpiration% > DATETIME('now', 'localtime')
			AND m.arrival NOT IN (
				SELECT DISTINCT location FROM goodsMarket WHERE %qRefreshDate% > DATETIME('now', '-%marketRefreshHours% hours', 'localtime') )
		ORDER BY ICAO
	)
	If !(result := SQLiteGetTable(DB, query)) {
		return
	}
	LV_ShowTable(result, "Auto_ListLV")	
	SB_SetText("Found list of mission destinations")
	return
}

Auto_Load:
{
	HotKey, %autoMarketHotkey%, Auto_Entry, On
	Gui, ListView, "Auto_ListLV"
	If !(LV_GetCount("Selected")) {
		MsgBox No ICAOs selected for entry.
		return
	}
	ToolTip % "READ THE INSTRUCTIONS BELOW!`t`t" . LV_GetCount("Selected") . " ICAOs left to enter"
	return
}

Auto_Entry:
{
	GuiControlGet, Auto_IgnoreWindow
	If (!Auto_IgnoreWindow) {
		WinGet, activeProcess, ProcessName, A
		If !(activeProcess="NeoFly.exe") {
			ToolTip, NeoFly does not appear to be the active window.
			return
		}
	}			
	Gui, ListView, "Auto_ListLV"
	Row := LV_GetNext(0)
	If (!Row) {
		MsgBox No ICAOs selected for entry.
		return
	}
	LV_GetText(ICAO, Row, 1)
	Send ^a{Delete}%ICAO%{Enter}
	LV_Delete(Row)
	If !(LV_GetCount("Selected")) {
		GoSub Auto_Unload
		return
	}
	ToolTip % LV_GetCount("Selected") . "  ICAOs left to enter"
	return
}

Auto_Unload:
{
	HotKey, %autoMarketHotkey%, Off
	ToolTip
	return
}

; ==== FUNCTIONS ====

; == SQL functions ==
SQLiteGetTable(database, query) {
	If !(database._Handle) {
         MsgBox, 48, No Database Connection Detected, % "No active database connection!`n`nYou will be directed to the Settings tab to connect."
		 GuiControl, Choose, GUI_Tabs, 1
         return false
    }
	resultTable := ""
	If (!database.GetTable(query, resultTable)) {
		MsgBox, 20, SQLite Error: SQLiteGetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`n`nEnsure the database is connected in the settings tab, and that the SQL query is valid`n`nDo you want to copy the query to the clipboard?"
		IfMsgBox Yes
		{
			clipboard := query
		}
		return false
	}
	return resultTable
}

SQLiteGenerateDateConversion(format, field) {
	normalized := ""
	; Turn it into yyyy-mm-dd h:mm:ss format
	Switch format
	{
		Case "yyyy/mm/dd":	
			; Convert the splitting character to a dash (work forwards from the year to find the char)
			normalized = 
				(
					SUBSTR(REPLACE(%field%, SUBSTR(%field%, 5, 1), '-'), -3, -100)
				)
			; Check for single-digit months (yyyy-m-dd vs yyyy-mm-dd)
			normalized =
				(
					CASE SUBSTR(%normalized%, 7, 1)
						WHEN '-' THEN SUBSTR(%normalized%, 1, 5)||0||SUBSTR(%normalized%, 6, 100)
						ELSE %normalized%
					END
				)
			; Check for single-digit days (yyyy-mm-d vs yyyy-mm-dd)
			normalized =
				(
					CASE SUBSTR(%normalized%, 10, 1)
						WHEN ' ' THEN SUBSTR(%normalized%, 1, 8)||0||SUBSTR(%normalized%, 9, 100)
						ELSE %normalized%
					END
				)
				
		Case "dd/mm/yyyy":
			; Convert the splitting character into dashes (work backwards from the space/year to find the char)
			normalized = 
				(
					SUBSTR(REPLACE(%field%, SUBSTR(%field%, INSTR(%field%, ' ')-4, -1), '-'), -3, -100)
				)
			; Check for single-digit days (d-mm-yyyy vs dd-mm-yyyy)
			normalized =
				(
					CASE SUBSTR(%normalized%, 2, 1)
						WHEN '-' THEN 0||SUBSTR(%normalized%, 1, 100)
						ELSE %normalized%
					END
				)
			; Check for single-digit months (dd-m-yyyy vs dd-mm-yyyy)
			normalized =
				(
					CASE SUBSTR(%normalized%, 5, 1)
						WHEN '-' THEN SUBSTR(%normalized%, 1, 3)||0||SUBSTR(%normalized%, 4, 100)
						ELSE %normalized%
					END
				)
			; Rearrange now that we know the locations of the days/months are static
			normalized = 
				(
					SUBSTR(%normalized%, 7, 4)||'-'||SUBSTR(%normalized%, 4, 2)||'-'||SUBSTR(%normalized%, 1, 2)||SUBSTR(%normalized%, 11)
				)
				
		Case "mm/dd/yyyy":
			; Convert the splitting character into dashes (work backwards from the space/year to find the char)
			normalized = 
				(
					SUBSTR(REPLACE(%field%, SUBSTR(%field%, INSTR(%field%, ' ')-4, -1), '-'), -3, -100)
				)
			; Check for single-digit months (m-dd-yyyy vs mm-dd-yyyy)
			normalized =
				(
					CASE SUBSTR(%normalized%, 2, 1)
						WHEN '-' THEN 0||SUBSTR(%normalized%, 1, 100)
						ELSE %normalized%
					END
				)
			; Check for single-digit days (mm-d-yyyy vs mm-dd-yyyy)
			normalized =
				(
					CASE SUBSTR(%normalized%, 5, 1)
						WHEN '-' THEN SUBSTR(%normalized%, 1, 3)||0||SUBSTR(%normalized%, 4, 100)
						ELSE %normalized%
					END
				)
			; Rearrange now that we know the locations of the days/months are static
			normalized = 
				(
					SUBSTR(%normalized%, 7, 4)||'-'||SUBSTR(%normalized%, 1, 2)||'-'||SUBSTR(%normalized%, 4, 2)||SUBSTR(%normalized%, 11)
				)
	}
	; Check for single digit hours (yyyy-mm-dd h:mm:ss vs yyyy-mm-dd hh:mm:ss)
	normalized = 
		(
			CASE LENGTH(%normalized%)
				WHEN 18 THEN SUBSTR(%normalized%, 1, 11)||'0'||SUBSTR(%normalized%, 12, 100)
				ELSE %normalized%
			END
		)
	; Check for AM/PM
	normalized =
		(
			CASE SUBSTR(%field%, -2, 1)
				WHEN 'P' THEN (
					CASE SUBSTR(%field%, 12, 2)
						WHEN '12' THEN %normalized%
						ELSE DATETIME(%normalized%, '+12 hours')
					END )
				ELSE %normalized%
			END
		)
	return normalized
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
