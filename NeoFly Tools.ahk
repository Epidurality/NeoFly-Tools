; Script Info
; Small collection of tools for use with the NeoFly career mode addon for MSFS 2020 (https://www.neofly.net/).
;
; Language:         English
; Tested on:        Windows 10 64-bit
; Author:           Epidurality

versionNumber := "0.5.0"
updateLink := "https://github.com/Epidurality/NeoFly-Tools/"

;iniPath := "debug.ini"

; AHK Settings
{
#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%
}

; Includes and paths
{
#Include %A_ScriptDir%/resources/Class_SQLiteDB.ahk ; This is the interface to the SQLite3 DLL. Credit to https://github.com/AHK-just-me/Class_SQLiteDB
#Include %A_ScriptDir%/resources/Vincenty.ahk ; This is for calculating distances given lat/lon values. Credit to https://autohotkey.com/board/topic/88476-vincenty-formula-for-latitude-and-longitude-calculations/
iconPath := A_ScriptDir . "/resources/default.ico"
}

; ==== GLOBAL VARS ====
{
global Pilot := {id: -1, weight: 170} ; Stores information about the current pilot
global Plane := {id: -1, name: "unknown", fuel: -1, maxFuel: -1, payload: -1, pax: -1, cruiseSpeed: -1, location: "unknown", onboardCargo: 0} ; Stores information about the selected Hangar plane
global DB := new SQLiteDB ; SQLite database connection object
global marketRefreshHours := 24 ; How often (in hours) the NeoFly system will force a refresh of the market. This is used to ignore markets which are too old.
global fuelPercentForAircraftMarketPayload := 0.40 ; Percent (as decimal) of fuel to be used in the Effective Payload calculation, only in the Aircraft Market tab results.
global dateFormats := "No Reformatting (Fastest)|yyyy/mm/dd|dd/mm/yyyy|mm/dd/yyyy"

; INI vars declaration
global defaultDBPath
global autoConnect
global autoConnectDefaultTab
global hideTrayIcon
global autoMarketHotkey
global discordWebhookURL

; Read from the INI
If (iniPath="") {
	iniPath := "NeoFly Tools.ini"
}
IniRead, defaultDBPath, %iniPath%, Setup, defaultDBPath, C:\ProgramData\NeoFly\common.db
IniRead, autoConnect, %iniPath%, Setup, autoConnect, 0
IniRead, autoConnectDefaultTab, %iniPath%, Setup, autoConnectDefaultTab, 2
IniRead, hideTrayIcon, %iniPath%, Setup, hideTrayIcon, 0
IniRead, autoMarketHotkey, %iniPath%, Setup, autoMarketHotkey, NumpadEnter
IniRead, discordWebhookURL, %iniPath%, Setup, discordWebhookURL, https://discord.com/api/webhooks/[YourWebhookKeyHere]
}

; ==== GUI ====

; Icon setup
{
	IfExist, %iconPath%
	{
		Menu, Tray, Icon, %iconPath%
	}
}

; GUI setup
{
	Gui, Main:New
	Gui, Main:Default
	Gui, +LastFound +OwnDialogs
	If (hideTrayIcon) {
		Menu, Tray, NoIcon
	} Else {
		Menu, Tray, NoStandard
		Menu, Tray, Add, Show, ShowTool
		Menu, Tray, Add, Hide, HideTool
		Menu, Tray, Add, Reload, ReloadTool
		Menu, Tray, Add, Close, MainGuiClose
	}
	Gui, Add, Tab3, vGUI_Tabs, Settings|Goods Optimizer|Auto-Market|Market Finder|Aircraft Market|Mission Generator|Monitor Hangar
	Gui, Add, StatusBar
}

; Splash Screen
{
	Gui, Splash:New
	Gui, Splash:Add, Text, Center h50 w300, NeoFly Tools is starting...
	Gui, Splash:Add, Progress, x25 y+30 h25 w250 cBlue BackgroundWhite vSplash_Progress, 1
	Gui, Splash:Add, Text, h50 w300 vSplash_Info, Creating GUI...
	Gui, Splash:Show, h150 w300, NeoFly Tools
}

; GUI Settings tab
{
	Gui, Main:Default
	Gui, Tab, Settings
	Gui, Add, Text, xm+10 y70, Database path:
	Gui, Add, Edit, x+10 w300 vSettings_DBPath, % defaultDbPath
	Gui, Add, Button, x+20 gSettings_Connect, Connect
	Gui, Add, Button, x+40 gSettings_Disconnect, Disconnect
	Gui, Add, Text, x+50, NeoFly Tools Version: v%versionNumber%`nUpdates available at`n`t%updateLink%

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
	Gui, Add, DropDownList, x+10 w200 vSettings_MissionDateFormat, %dateFormats%
	Gui, Add, Text, xm+10 y+10 w200, GoodsMarket.RefreshDate format:
	Gui, Add, DropDownList, x+10 w200 vSettings_GoodsDateFormat, %dateFormats%
	Gui, Add, Button, x+20 w150 y+-40 gSettings_TimestampPreview, Preview These Settings
	Gui, Add, Text, xm+10 y+25, Note: The '/' can be any character and leading zeroes don't matter, for example: yyyy.m.d format will work when using yyyy/mm/dd option. Use the button above to double-check.`nNote: Missions and Goods may use different formats depending on your locale.
	Gui, Add, Text, xm+10 y+20, Date Formatting Samples from Database:`t`t`tNote: These dates are drawn from the Missions and GoodsMarket tables, so you must have data in them.
	Gui, Add, ListView, xm+10 y+10 w915 h150 vSettings_TimestampLV, 
}

; GUI Goods Optimizer tab
{
	Gui, Tab, Goods Optimizer
	Gui, Add, Text, xm+10 R2 y70, Departure`nICAO:
	Gui, Add, Edit, x+5 w50 h25 vGoods_DepartureICAO,
	Gui, Add, Text, R2 x+20, Arrival`nICAO:
	Gui, Add, Edit, x+5 w50 h25 Disabled vGoods_ArrivalICAO, ---
	Gui, Add, Text, R2 x+20, Mission`nWeight (lbs):
	Gui, Add, Edit, x+5 w50 h25 Disabled vGoods_MissionWeight, ---
	Gui, Add, Text, R2 x+20, New`nGoods (lbs):
	Gui, Add, Edit, x+5 w50 h25 Disabled vGoods_GoodsWeight, ---
	Gui, Add, Text, R2 x+20, Onboard`nGoods (lbs):
	Gui, Add, Edit, x+5 w50 h25 Disabled vGoods_OnboardCargo, ---
	
	Gui, Add, Button, x+30 y70 w150 gGoods_RefreshHangar, Refresh Hangar
	Gui, Add, CheckBox, x+30 y+-15 vGoods_HangarAll gGoods_RefreshHangar, Show All
	Gui, Add, Text, xm+350 y+10 w300 vGoods_Hangar, Hangar:
	Gui, Add, Checkbox, x+10 vGoods_IgnoreOnboardCargo gGoods_RefreshHangar, Ignore Onboard Cargo
	Gui, Add, ListView, xm+350 y+10 w575 h100 Grid vGoods_HangarLV gGoods_HangarLVClick

	Gui, Add, Text, xm+20 y130 w50 h15, Aircraft:
	Gui, Add, Text, x+10 w250 hp vGoods_PlaneInfo, Double click a plane in the Hangar to select it
	Gui, Add, Text, xm+20 y+10 w50 hp, Fuel:
	Gui, Add, Text, x+10 w250 hp vGoods_FuelInfo, ---
	Gui, Add, Text, xm+20 y+10 w50 hp, Payload:
	Gui, Add, Text, x+10 w250 hp vGoods_PayloadInfo, ---
	Gui, Add, Text, xm+20 y+10 w50 hp, Mission:
	Gui, Add, Text, x+10 w250 hp vGoods_MissionInfo, ---

	Gui, Add, Text, xm+150 y+10, Arrival Requirements:
	Gui, Add, Checkbox, x+20 vGoods_ArrivalILS, ILS
	Gui, Add, Checkbox, x+20 vGoods_ArrivalApproach, Approach
	Gui, Add, Checkbox, x+20 vGoods_ArrivalLights, Rwy Lights
	Gui, Add, Checkbox, x+20 vGoods_ArrivalVASI, VASI/PAPI
	Gui, Add, Checkbox, x+20 vGoods_ArrivalHard, Hard Rwy
	Gui, Add, Text, x+20, Min Rwy Len.
	Gui, Add, Edit, x+10 w100 vGoods_ArrivalRwyLen, 1000

	Gui, Add, Button, xm+10 y+10 gGoods_RefreshMissions, Refresh Missions
	Gui, Add, Text, x+20, Goods Filters:
	Gui, Add, CheckBox, x+20 vGoods_IncludeIllicit, Illicit
	Gui, Add, Checkbox, x+20 vGoods_IncludeFragile Checked, Fragile
	Gui, Add, Checkbox, x+20 vGoods_IncludePerishable Checked, Perishable
	Gui, Add, Checkbox, x+20 vGoods_IncludeNormal Checked, Normal
	
	Gui, Add, Text, xm+10 y+20, NeoFly Missions:
	Gui, Add, Text, x+5 w500 vGoods_MissionsText,
	Gui, Add, Checkbox, x+10 gGoods_ToggleTradeMissions vGoods_ShowTradeMissions Checked, Show Trade/Transit Missions (slower)
	Gui, Add, ListView, xm+10 y+10 w915 h125 Grid vGoods_MissionsLV gGoods_MissionsLVClick

	Gui, Add, Text, xm+10 y+10 vGoods_TradeMissionsPreText, Trade / Transit Missions:
	Gui, Add, Text, x+5 w500 vGoods_TradeMissionsText, 
	Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vGoods_TradeMissionsLV gGoods_TradeMissionsLVClick

	Gui, Add, Text, xm+10 y+10 vGoods_Trades, Optimal Goods:
	Gui, Add, Text, x+5 w300 vGoods_OptimalGoodsText,
	Gui, Font, cRed
	Gui, Add, Text, x+10 w500 vGoods_WarningText
	Gui, Font
	Gui, Add, ListView, xm+10 y+10 w915 h100 Grid vGoods_TradesLV
}

; GUI Auto-Market
{
	Gui, Tab, Auto-Market
	Gui, Add, Text, xm+10 y70, Center ICAO:
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
You can change the Hotkey from {%autoMarketHotkey%} to whatever you'd like by modifying the defaults in the .ini file.
	)
	
}	

; GUI Market Finder tab
{
	Gui, Tab, Market Finder
	Gui, Add, Text, xm+10 y70 w50, Name:
	Gui, Add, ComboBox, x+10 w200 vMarket_Name, ||Beer|Caviar|Cigarette|Clothes|Coffee|Computer|Contraband Cigars|Fish|Flower|Fruit|Fuel|Magazine|Meat|Mechanical parts|Medicine|Old wine|Phone|Pillza|Vegetable|Whiskey
	Gui, Add, Text, x+20 yp+5, I want to
	Gui, Add, Radio, x+10 yp-5 vMarket_RadioBuy, Buy
	Gui, Add, Radio, y+10 Checked vMarket_RadioSell, Sell
	Gui, Add, Text, x+40 y+-30 w100, Show`nDistance From:
	Gui, Add, Edit, x+10 w75 vMarket_DepartureICAO, KJFK

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
	Gui, Add, Button, x+100 w100 gMarket_Search, Search

	Gui, Add, Text, xm+10 y+10, Markets:
	Gui, Add, Text, x+10 w500 vMarket_MarketsText, Press Search to display relevant markets
	Gui, Add, ListView, xm+10 y+10 w915 h400 Grid vMarket_MarketLV
}

; GUI Aircraft Market tab
{
	Gui, Tab, Aircraft Market
	Gui, Add, Text, xm+10 y70, Aircraft Name (or part of name) as seen in NeoFly database:
	Gui, Add, Edit, w300 vAircraftMarket_Aircraft, Cessna
	Gui, Add, Button, x+20 w100 gAircraftMarket_Search, Search
	Gui, Add, Text, xm+10 y+20, Matching Aircraft:
	Gui, Add, Text, x+10 w500 vAircraftMarket_AircraftText, Press Search to find aircraft in the market
	Gui, Add, ListView, xm+10 y+10 w915 h450 Grid vAircraftMarket_LV
	Gui, Add, Text, xm+10 y+20, Note: Travel Cost represents a one-way trip from your pilot's current location to the plane's Location.
	Gui, Add, Text, xm+10 y+20, % "Other Note: Effective Payload is the payload of the plane after subtracting the Pilot's weight (" . Pilot.weight . "lbs) and " . ROUND(fuelPercentForAircraftMarketPayload*100,0) . "% of max fuel."
}

; GUI Mission Generator tab
{
	Gui, Tab, Mission Generator
	Gui, Add, Button, xm+10 y70 gGenerator_Backup, Backup Database
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

; Gui Monitor Hangar tab
{
	Gui, Tab, Monitor Hangar
	Gui, Add, Text, xm+10 y70, Discord Webhook URL:
	Gui, Add, Edit, x+10 w780 vMonitor_URL, % discordWebhookURL
	
	Gui, Add, Button, xm+10 y+20 vMonitor_Enable gMonitor_Enable, Enable
	Gui, Add, Button, x+30 vMonitor_Disable gMonitor_Disable Disabled, Disable
	Gui, Add, Checkbox, x+40 vMonitor_OfflineMode gMonitor_Disable, Use Offline Mode (uses ETA instead of checking the Hangar - use only if NeoFly is closed)
	Gui, Add, Text, x+30, Refresh Interval (s):
	Gui, Add, Edit, x+5 w50 vMonitor_RefreshInterval, 60
	
	Gui, Add, Text, xm+10 y+20, Hangar:`t`t`tLast Checked:
	Gui, Add, Text, x+10 w600 vMonitor_HangarLastChecked, ---
	Gui, Add, ListView, xm+10 y+10 w915 h200 vMonitor_HangarLV Disabled,

	Gui, Add, Text, xm+10 y+20, Hired Jobs:`t`t`tLast Checked:
	Gui, Add, Text, x+10 w600 vMonitor_HiredLastChecked, ---
	Gui, Add, ListView, xm+10 y+10 w915 h200 vMonitor_HiredLV Disabled,
}

; Main initialization
{
	SB_SetText("Connect to a database using the Settings tab.")
	If (autoConnect) {
		GuiControl, Splash:, Splash_Progress, 25
		GuiControl, Splash:, Splash_Info, Connecting to database and fixing dates...
		GoSub Settings_Connect
		GuiControl, Splash:, Splash_Progress, 66
		GuiControl, Splash:, Splash_Info, Refreshing the Goods Optimizer...
		GoSub Goods_RefreshHangar
		GuiControl, Splash:, Splash_Progress, 80
		GuiControl, Splash:, Splash_Info, Rendering the GUI...
		GuiControl, Choose, GUI_Tabs, %autoConnectDefaultTab%
	}
	GuiControl, Splash:, Splash_Progress, 100
	Gui, Show, h700 w960, NeoFly Tools
	Gui, Splash:Destroy
	Gui, Main:Default
	return
}

; GUI functions
MainGuiClose:
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
	Gui, Main:Show
	return
}

HideTool:
{
	Gui, Main:Hide
	return
}

; ==== SUBROUTINES =====

; == Settings Tab Subroutines ==
Settings_Connect:
{
	Gui, Main:Default
	SB_SetText("Opening " . Settings_DBPath . "...")
	DB := new SQLiteDB
	GuiControlGet, Settings_DBPath
	If (!DB.OpenDB(Settings_DBPath, "R", False)) { ; Connect read-only
		MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		return
	}
	; Get the list of pilots
	PilotQuery =
	(
		SELECT career.name AS [Pilot Callsign], career.id, currentPilot.pilotID AS [Current NeoFly Pilot] FROM career LEFT JOIN currentPilot ON career.id=currentPilot.pilotID
	)
	If !(PilotResult := SQLiteGetTable(DB, PilotQuery)) {
		return
	}
	If (!PilotResult.RowCount) {
		GuiControl, , Settings_Pilot, % "Valid pilots were not able to be loaded from database."
	} Else {
		Loop % PilotResult.RowCount {
			PilotResult.Next(PilotRow)
			If (PilotRow[2] == PilotRow[3]) {
				Pilot.id := PilotRow[2]
				GuiControl, , Settings_Pilot, % "ID: " . PilotRow[2] . "`t Callsign: " . PilotRow[1]
				PilotRow[3] := "<<<"
			} Else {
				PilotRow[3] := " "
			}
		}
		PilotResult.Reset()
		LV_ShowTable(PilotResult, "Settings_PilotLV")
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
	GoSub Settings_TimestampAuto
	return
}

Settings_Disconnect:
{
	Gui, Main:Default
	SB_SetText("Disconnecting from the database...")
	DB.CloseDB()
	GuiControl, , Settings_Pilot, % "Connect to a database to select a pilot"
	LV_Clear("Settings_PilotLV")
	LV_Clear("Goods_HangarLV")
	LV_Clear("Goods_MissionsLV")
	LV_Clear("Goods_TradeMissionsLV")
	LV_Clear("Goods_TradesLV")
	LV_Clear("Settings_TimestampLV")
	SB_SetText("Disconnected from the database")
}

Settings_PilotLVClick:
{
	If (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
		Gui, Main:Default
		Gui, ListView, Settings_PilotLV
		LV_GetText(lvID, A_EventInfo, 2)
		LV_GetText(lvCallsign, A_EventInfo, 1)
		Pilot.id := lvID
		GuiControl, , Settings_Pilot, % "ID: " . Pilot.id . "`t Callsign: " . lvCallsign
		GoSub Goods_RefreshHangar
	}
	return
}

Settings_TimestampAuto:
{
	Gui, Main:Default
	SB_SetText("Attempting timestamp conversion...")
	; Check the Missions timestamps
	Loop, Parse, dateFormats, | 
	{
		GuiControl, Choose, Settings_MissionDateFormat, %A_Index%
		qExpiration := SQLiteGenerateDateConversion(A_LoopField, "expiration")
		MissionTimeCheckQuery = 
		( 
			SELECT DISTINCT 
				'Missions.Expiration' AS [DB Field], 
				expiration AS [DB Value], %qExpiration% AS Formatted, 
				IFNULL(DATETIME(%qExpiration%), 'INVALID') AS Validation,
				IFNULL(JULIANDAY(%qExpiration%, 'localtime')-JULIANDAY('now','localtime'), 'INVALID') AS [Then-Now(Days)]
			FROM missions ORDER BY Validation DESC LIMIT 1
		)
		If !(MissionTimeCheckResult := SQLiteGetTable(DB, MissionTimeCheckQuery)) {
			return
		}
		MissionTimeCheckResult.GetRow(1, MissionTimeCheckRow)
		If !(MissionTimeCheckRow[3] = "INVALID" || MissionTimeCheckRow[4] = "INVALID") { ; This format worked
			break ; Exit the loop to stop choosing mission formats
		}
	}
	; Check the GoodsMarket timestamps
	Loop, Parse, dateFormats, | 
	{
		GuiControl, Choose, Settings_GoodsDateFormat, %A_Index%
		qRefreshDate := SQLiteGenerateDateConversion(A_LoopField, "refreshDate")
		GoodsTimeCheckQuery = 
		( 
			SELECT DISTINCT 
				'GoodsMarket.RefreshDate' AS [DB Field], 
				refreshDate AS [DB Value], %qRefreshDate% AS Formatted, 
				IFNULL(DATETIME(%qRefreshDate%), 'INVALID') AS Validation,
				IFNULL(JULIANDAY(%qRefreshDate%)-JULIANDAY('now','localtime'), 'INVALID') AS [Diff to Now]
			FROM goodsMarket ORDER BY Validation DESC LIMIT 1
		)
		If !(GoodsTimeCheckResult := SQLiteGetTable(DB, GoodsTimeCheckQuery)) {
			return
		}
		GoodsTimeCheckResult.GetRow(1, GoodsTimeCheckRow)
		If !(GoodsTimeCheckRow[3] = "INVALID" || GoodsTimeCheckRow[4] = "INVALID") { ; This format worked
			break ; Stop choosing mission formats
		}
	}
	SB_SetText("Timestamp conversion was performed")
	GoSub Settings_TimestampPreview
	return
}
	
Settings_TimestampPreview:
{
	Gui, Main:Default
	SB_SetText("Previewing timestamp conversions...")
	GuiControlGet, Settings_MissionDateFormat
	GuiControlGet, Settings_GoodsDateFormat
	; Show the user the complete output
	qExpiration := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "expiration")
	qRefreshDate := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "refreshDate")
	TimestampsPreviewQuery = 
	( 
		SELECT * FROM (
			SELECT DISTINCT 
				'GoodsMarket.RefreshDate' AS [DB Field], 
				refreshDate AS [DB Value], %qRefreshDate% AS Formatted, 
				IFNULL(DATETIME(%qRefreshDate%), 'INVALID') AS [Validation],
				IFNULL(JULIANDAY(%qRefreshDate%)-JULIANDAY('now','localtime'), 'INVALID') AS [Diff to Now]
			FROM goodsMarket ORDER BY id DESC LIMIT 300 )
		UNION ALL SELECT * FROM (
			SELECT DISTINCT 
				'Missions.Expiration' AS [DB Field], 
				expiration AS [DB Value], %qExpiration% AS Formatted, 
				IFNULL(DATETIME(%qExpiration%), 'INVALID') AS [Validation],
				IFNULL(JULIANDAY(%qExpiration%, 'localtime')-JULIANDAY('now','localtime'), 'INVALID') AS [Then-Now(Days)]
			FROM missions ORDER BY id DESC LIMIT 300 )
		ORDER BY Validation DESC
	)
	If !(TimestampsPreviewResult := SQLiteGetTable(DB, TimestampsPreviewQuery)) {
		return
	}
	LV_ShowTable(TimestampsPreviewResult, "Settings_TimestampLV")
	SB_SetText("Timestamp conversions previewed.")
	return
}

; == Goods Tab Subroutines ==
Goods_RefreshHangar:
{
	Gui, Main:Default
	SB_SetText("Refreshing hangar...")
	GuiControlGet, Goods_HangarAll
	LV_Clear("Goods_MissionsLV")
	LV_Clear("Goods_TradeMissionsLV")
	LV_Clear("Goods_TradesLV")
	GuiControl, , Goods_ArrivalICAO, ---
	GuiControl, , Goods_MissionWeight, ---
	GuiControl, , Goods_GoodsWeight, ---
	GuiControl, , Goods_MissionsText
	GuiControl, , Goods_TradeMissionsText
	qPilotID := Pilot.id
	If (Goods_HangarAll) {
		qStatusClause := "hangar.status != 5"
	} Else {
		qStatusClause := "hangar.status = 0"
	}
	hangarQuery = 
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
			hangar.Qualification,
			aircraftdata.CruiseSpeedktas AS [Cruise Speed (kts)],
			onboardCargo.totalCargo AS [Onboard Cargo (lbs)]
		FROM hangar 
		INNER JOIN 
			aircraftdata ON hangar.Aircraft=aircraftdata.Aircraft
		LEFT JOIN (
			SELECT planeid, SUM(totalweight) AS totalCargo FROM cargo GROUP BY planeid ) AS onboardCargo ON hangar.id = onboardCargo.planeid
		WHERE owner=%qPilotID% 
		AND %qStatusClause%
		ORDER BY hangar.id
	)
	If !(hangarResult := SQLiteGetTable(DB, hangarQuery)) {
		return
	}
	LV_ShowTable(hangarResult, "Goods_HangarLV")
	SB_SetText("Hangar refreshed")
	return
}

Goods_HangarLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
		Gui, Main:Default
		GuiControlGet, Goods_IgnoreOnboardCargo
		; Load the Plane info into the global vars for other things to use
		Gui, ListView, Goods_HangarLV
		LV_GetText(lvID, A_EventInfo, 1)
		LV_GetText(lvName, A_EventInfo, 2)
		LV_GetText(lvPayload, A_EventInfo, 4)
		LV_GetText(lvPax, A_EventInfo, 5)
		LV_GetText(lvLocation, A_EventInfo, 6)
		LV_GetText(lvFuel, A_EventInfo, 9)	
		LV_GetText(lvMaxFuel, A_EventInfo, 10)
		LV_GetText(lvCruiseSpeed, A_EventInfo, 12)
		LV_GetText(lvOnboardCargo, A_EventInfo, 13)
		Plane.id := lvId
		Plane.name := lvName
		Plane.payload := lvPayload
		Plane.pax := lvPax
		Plane.location := lvLocation
		Plane.fuel := lvFuel
		Plane.maxFuel := lvMaxFuel
		Plane.cruiseSpeed := lvCruiseSpeed
		If (Goods_IgnoreOnboardCargo || lvOnboardCargo = "") { ; if the checkbox is set or the onboardCargo result is blank (no cargo entries)...
			Plane.onboardCargo := 0
		} else {
			Plane.onboardCargo := lvOnboardCargo
		}
		GuiControl, , Goods_OnboardCargo, % Plane.onboardCargo
		GuiControl, , Goods_PlaneInfo, % Plane.name . " (ID#" . Plane.id . ")"
		GuiControl, , Goods_PayloadInfo, % "Double-click a mission"
		GuiControl, , Goods_FuelInfo, % Plane.fuel . " / " . Plane.maxFuel . "lbs (" . FLOOR(Plane.fuel*100/Plane.maxFuel) . "%)"
		GuiControl, , Goods_MissionInfo, Choose mission
		GuiControl, , Goods_DepartureICAO, % Plane.location
		GuiControl, , Market_DepartureICAO, % Plane.location
		GuiControl, , Auto_CenterICAO, % Plane.location
		SB_SetText("Selected the " . Plane.name . "(#" . Plane.id . ") from the Goods Market hangar")
		GoSub Goods_RefreshMissions
	}
	return
}

Goods_RefreshMissions:
{
	Gui, Main:Default
	SB_SetText("Refreshing missions...")
	LV_Clear("Goods_TradeMissionsLV")
	LV_Clear("Goods_MissionsLV")
	LV_Clear("Goods_TradesLV")
	GuiControl, , Goods_ArrivalICAO, ---
	GuiControl, , Goods_MissionWeight, ---
	GuiControl, , Goods_GoodsWeight, ---
	GuiControl, , Goods_MissionsText
	GuiControl, , Goods_TradeMissionsText
	GuiControl, , Goods_OptimalGoodsText, Double-Click a Mission/Trade Mission to see Optimal Goods to bring
	GuiControl, , Goods_WarningText
	GuiControlGet, Goods_DepartureICAO
	GuiControlGet, Goods_IncludeIllicit
	GuiControlGet, Goods_IncludeNormal
	GuiControlGet, Goods_IncludeFragile
	GuiControlGet, Goods_IncludePerishable
	GuiControlGet, Goods_ArrivalILS
	GuiControlGet, Goods_ArrivalApproach
	GuiControlGet, Goods_ArrivalLights
	GuiControlGet, Goods_ArrivalHard
	GuiControlGet, Goods_ArrivalRwyLen
	GuiControlGet, Goods_ArrivalVASI
	GuiControlGet, Settings_MissionDateFormat
	GuiControlGet, Settings_GoodsDateFormat
	GuiControlGet, Goods_ShowTradeMissions
	; Check to see if the Departure ICAO has a valid market.
	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	validMarketQuery = 
	(
		SELECT 
			ROUND((JULIANDAY(%qRefreshDateField%)-JULIANDAY('now', 'localtime'))*24+%marketRefreshHours%, 2) AS [Time Left (hrs)]
		FROM goodsMarket AS gm
		WHERE 
			gm.location = '%Goods_DepartureICAO%'
			AND [Time Left (hrs)] > 0
		LIMIT 1
	)
	If !(validMarketResult := SQLiteGetTable(DB, validMarketQuery)) {
		return
	}
	If !(validMarketResult.RowCount) {
		GuiControl, , Goods_MissionsText, % "Could not find valid market at Departure ICAO: '" . Goods_DepartureICAO . "'"
		LV_Clear("Goods_MissionsLV")
		LV_Clear("Goods_TradeMissionsLV")
		LV_Clear("Goods_TradesLV")
		SB_SetText("Unable to refresh missions")
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
	qPayload := Plane.payload - Plane.fuel - Pilot.weight - Plane.onboardCargo ; This is effectively what space the plane has left to work with to stay under 100% Sim payload.
	qPax := Plane.pax
	; Get NeoFly missions
	GuiControl, , Goods_MissionsText, % "Looking for missions..."
	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	qExpirationField := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "m.expiration")
	NFMissionsQuery =
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
			ROUND((JULIANDAY(%qRefreshDateField%)-JULIANDAY('now', 'localtime'))*24+%marketRefreshHours%, 2) AS [Time Left (hrs)],
			'' AS [Can Buy At Arrival],
			ROUND((JULIANDAY(%qExpirationField%)-JULIANDAY('now', 'localtime'))*24, 2) AS [Mission Expires (hrs)],
			a.num_runway_end_ils AS [ILS],
			a.num_approach AS [Approaches],
			a.num_runway_light AS [Rwy Lights],
			a.num_runway_end_vasi AS [VASI/PAPI],
			a.num_runway_hard AS [Hard Rwys],			
			a.longest_runway_length AS [Rwy Len]			
		FROM missions AS m
		LEFT JOIN goodsMarket AS gm
		ON gm.location=m.arrival
		INNER JOIN airport AS a
		ON a.ident=m.arrival
		WHERE
			departure='%Goods_DepartureICAO%'
			AND a.num_runway_hard >= %Goods_ArrivalHard%
			AND a.num_runway_light >= %Goods_ArrivalLights%
			AND a.num_runway_end_ils >= %Goods_ArrivalILS%
			AND a.num_runway_end_vasi >= %Goods_ArrivalVASI%
			AND a.num_approach >= %Goods_ArrivalApproach%
			AND a.longest_runway_length >= %Goods_ArrivalRwyLen%
			AND gm.location != '%Goods_DepartureICAO%'
			AND m.weight <= %qPayload%
			AND m.pax <= %qPax%
			AND [Time Left (hrs)] > 0
			AND [Mission Expires (hrs)] > 0
		GROUP BY m.id
	)
	If !(NFMissionsResult := SQLiteGetTable(DB, NFMissionsQuery)) {
		return
	}
	; Analyze NeoFly missions
	If !(NFMissionsResult.RowCount) {
		GuiControl, , Goods_MissionsText, % "Could not find missions at Departure ICAO: '" . Goods_DepartureICAO . "'"
		SB_SetText("Unable to refresh missions")
	} else {
		GuiControl, , Goods_MissionsText, % "Analyzing " NFMissionsResult.RowCount . " missions..."
		qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
		qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
		Loop % NFMissionsResult.RowCount {
			NFMissionsResult.Next(NFMissionsRow)
			qDeparture := NFMissionsRow[2]
			qArrival := NFMissionsRow[3]
			qCargo := NFMissionsRow[6]
			qPay := NFMissionsRow[7]
			NFMissionsGoodsQuery = 
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
			If !(NFMissionsGoodsResult := SQLiteGetTable(DB, NFMissionsGoodsQuery)) {
				return
			}
			totalProfit := 0
			availablePayload := Plane.payload - Plane.fuel - qCargo - Pilot.weight - Plane.onboardCargo
			Loop % NFMissionsGoodsResult.RowCount {
				NFMissionsGoodsResult.Next(NFMissionsGoodsRow)
				maxQty := FLOOR(MIN(NFMissionsGoodsRow[4], availablePayload/NFMissionsGoodsRow[2]))
				totalProfit := totalProfit + (maxQty * NFMissionsGoodsRow[3])
				availablePayload -= maxQty*NFMissionsGoodsRow[2]
			}
			NFMissionsRow[10] := totalProfit
			NFMissionsRow[11] := totalProfit + NFMissionsRow[7]
			NFMissionsRow[12] := ROUND(NFMissionsRow[11]/NFMissionsRow[4],0)
			NFMissionsNextGoodsQuery = 
			(
				SELECT name FROM goodsMarket WHERE location='%qArrival%' AND tradetype=0 AND quantity>0 AND type %qIllicit% ORDER BY unitprice/unitweight DESC
			)
			If !(NFMissionsNextGoodsResult := SQLiteGetTable(DB, NFMissionsNextGoodsQuery)) {
				return
			}
			Loop % NFMissionsNextGoodsResult.RowCount {
				NFMissionsNextGoodsResult.Next(NFMissionsNextGoodsRow)
				NFMissionsRow[14] := NFMissionsRow[14] . NFMissionsNextGoodsRow[1] . ", "
			}
		}
		NFMissionsResult.Reset()
		GuiControl, , Goods_MissionsText, % "Displaying " . NFMissionsResult.RowCount " missions"
		LV_ShowTable(NFMissionsResult, "Goods_MissionsLV", FALSE)
		LV_ModifyCol(12, "SortDesc")
		GuiControl, +ReDraw, Goods_MissionsLV
	}
	
	; Get viable trade missions
	If (Goods_ShowTradeMissions) {	
		GuiControl, , Goods_TradeMissionsText, % "Looking for trade missions..."
		qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
		qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
		TradesQuery = 
		(
			SELECT 
				'%Goods_DepartureICAO%' AS Departure, 
				gm.location AS Arrival, 
				0 AS [Trade Profit], 
				0 AS Distance, 
				0 AS [Profit/nm],
				a.lonx AS [Arrival Lon],
				a.laty AS [Arrival Lat],
				gm.[Time Left (hrs)] AS [Time Left (hrs)],
				'' AS [Can Buy At Arrival],
				a.num_runway_end_ils AS [ILS],
				a.num_approach AS [Approaches],
				a.num_runway_light AS [Rwy Lights],
				a.num_runway_end_vasi AS [VASI/PAPI],
				a.num_runway_hard AS [Hard Rwys],			
				a.longest_runway_length AS [Rwy Len]
			FROM (
				SELECT
					dest.location AS location,
					ROUND((JULIANDAY(%qDestRefreshDateField%)-JULIANDAY('now', 'localtime'))*24+%marketRefreshHours%, 2) AS [Time Left (hrs)]
				FROM
					goodsMarket AS dep
				INNER JOIN
					goodsMarket AS dest ON dep.name=dest.name
				INNER JOIN
					airport AS a ON dest.location=a.ident
				WHERE
					dep.location='%Goods_DepartureICAO%'
					AND dep.type %qIllicit%
					AND dep.type %qNormal%
					AND dep.type %qPerishable%
					AND dep.type %qFragile%
					AND dep.tradeType=0
					AND dest.tradeType=1
					AND [Time Left (hrs)] > 0 
				GROUP BY dest.location ) AS gm
			INNER JOIN 
				airport AS a ON a.ident=gm.location
			WHERE
				a.num_runway_hard >= %Goods_ArrivalHard%
				AND a.num_runway_light >= %Goods_ArrivalLights%
				AND a.num_runway_end_ils >= %Goods_ArrivalILS%
				AND a.num_runway_end_vasi >= %Goods_ArrivalVASI%
				AND a.num_approach >= %Goods_ArrivalApproach%
				AND a.longest_runway_length >= %Goods_ArrivalRwyLen%
		)
		If !(TradesResult := SQLiteGetTable(DB, TradesQuery)) {
			return
		}
		If !(TradesResult.RowCount) {
			GuiControl, , Goods_TradeMissionsText, % "Could not find suitable trade markets"
		} else {
			GuiControl, , Goods_TradeMissionsText, % "Analyzing " TradesResult.RowCount . " trade missions..."
			; Get plane location for distance calcs
			qPlaneID := Plane.id
			PlaneLocQuery = 
			(
				SELECT a.lonx, a.laty
				FROM airport AS a
				INNER JOIN hangar AS h
				ON a.ident=h.Location
				WHERE h.id=%qPlaneID%
				LIMIT 1
			)
			If !(PlaneLocResult := SQLiteGetTable(DB, PlaneLocQuery)) {
				return
			}
			PlaneLocResult.GetRow(1, PlaneLocRow)
			pilotLonX := PlaneLocRow[1]
			pilotLatY := PlaneLocRow[2]
			; Analyze each trade mission
			qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
			qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
			Loop % TradesResult.RowCount {
				TradesResult.Next(TradesRow)
				qDeparture := TradesRow[1]
				qArrival := TradesRow[2]
				TradesGoodsQuery = 
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
					INNER JOIN goodsMarket AS dest 
					ON dep.name=dest.name
					WHERE
						[Profit/u] > 0
						AND dep.location='%qDeparture%'
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
				If !(TradesGoodsResult := SQLiteGetTable(DB, TradesGoodsQuery)) {
					return
				}
				totalProfit := 0
				availablePayload := Plane.payload - Plane.fuel - Pilot.weight
				Loop % TradesGoodsResult.RowCount {
					TradesGoodsResult.Next(TradesGoodsRow)
					maxQty := FLOOR(MIN(TradesGoodsRow[4], availablePayload/TradesGoodsRow[2]))
					totalProfit += maxQty * TradesGoodsRow[3]
					availablePayload := availablePayload - maxQty*TradesGoodsRow[2]
				}
				TradesRow[3] := totalProfit
				TradesRow[4] := ROUND(0.000539957*InvVincenty(pilotLatY, pilotLonX, TradesRow[7], TradesRow[6]), 0)
				TradesRow[5] := ROUND(TradesRow[3]/TradesRow[4],0)
				TradesNextGoodsQuery = 
				(
					SELECT name FROM goodsMarket WHERE location='%qArrival%' AND tradetype=0 AND quantity>0 AND type %qIllicit% ORDER BY unitprice/unitweight DESC
				)
				If !(TradesNextGoodsResult := SQLiteGetTable(DB, TradesNextGoodsQuery)) {
					return
				}
				Loop % TradesNextGoodsResult.RowCount {
					TradesNextGoodsResult.Next(TradesNextGoodsResultRow)
					TradesRow[9] := TradesRow[9] . TradesNextGoodsResultRow[1] . ", "
				}
			}
			TradesResult.Reset()
			GuiControl, , Goods_TradeMissionsText, % "Displaying " . TradesResult.RowCount . " trade missions"
			LV_ShowTable(TradesResult, "Goods_TradeMissionsLV", FALSE)
			LV_ModifyCol(5, "SortDesc")
			GuiControl, +ReDraw, Goods_TradeMissionsLV
		}
	}
	SB_SetText("Missions refreshed")
	return
}

Goods_MissionsLVClick:
{
	if (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
		Gui, Main:Default
		GuiControl, , Goods_WarningText
		Gui, ListView, Goods_MissionsLV
		LV_GetText(lvID, A_EventInfo, 1)
		LV_GetText(lvDeparture, A_EventInfo, 2)
		LV_GetText(lvArrival, A_EventInfo, 3)
		LV_GetText(lvMissionWeight, A_EventInfo, 6)
		LV_GetText(lvMissionType, A_EventInfo, 8)
		LV_GetText(lvTimeLeft, A_EventInfo, 13)
		LV_GetText(lvDistance, A_EventInfo, 4)
		If (lvTimeLeft < lvDistance/Plane.cruiseSpeed+1) {
			GuiControl, , Goods_WarningText, Warning: There are only %lvTimeleft% hours left to deliver goods to this market before it refreshes.
		}
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
		Gui, Main:Default
		GuiControl, , Goods_WarningText
		Gui, ListView, Goods_TradeMissionsLV
		LV_GetText(lvDeparture, A_EventInfo, 1)
		LV_GetText(lvArrival, A_EventInfo, 2)
		LV_GetText(lvTimeLeft, A_EventInfo, 8)
		LV_GetText(lvDistance, A_EventInfo, 4)
		If (lvTimeLeft < lvDistance/Plane.cruiseSpeed+1) {
			GuiControl, , Goods_WarningText, Warning: There are only %lvTimeleft% hours left to deliver goods to this market before it refreshes.
		}
		GuiControl, , Goods_MissionWeight, 0
		GuiControl, , Goods_ArrivalICAO, % lvArrival
		GuiControl, , Goods_MissionInfo, % lvDeparture . ">" . lvArrival . " - Goods Trade / Transit"
		GoSub Goods_RefreshMarket
	}
	return
}

Goods_RefreshMarket:
{
	Gui, Main:Default
	SB_SetText("Refreshing optimal goods...")
	GuiControl, Text, Goods_OptimalGoodsText, % "Finding optimal goods..."
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
	OptimalQuery = 
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
			[Profit/u] > 0
			AND dep.tradeType=0
			AND dest.tradeType=1
			AND dep.location='%Goods_DepartureICAO%'
			AND dep.type %qIllicit%
			AND dep.type %qNormal%
			AND dep.type %qPerishable%
			AND dep.type %qFragile%
			AND dest.location='%Goods_ArrivalICAO%'
			AND dep.quantity>0
			AND dest.quantity>0
			AND %qDepRefreshDateField% > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
			AND %qDestRefreshDateField% > DATETIME('now', '-%marketRefreshHours% hours', 'localtime')
		ORDER BY [Profit/lb] DESC
	)
	If !(OptimalResult := SQLiteGetTable(DB, OptimalQuery)) {
		return
	}
	GuiControl, Text, Goods_OptimalGoodsText, % "Analyzing " . OptimalResult.RowCount . " viable goods..."
	; Optimize these trades
	simPayload := Plane.payload - Plane.fuel
	totalProfit := 0
	availablePayload := Plane.payload - Plane.fuel- Goods_MissionWeight - Pilot.weight - Plane.onboardCargo
	goodsWeight := availablePayload
	OptimalResult.ColumnNames[10] := "Buy Qty"
	OptimalResult.ColumnNames[12] := "Profit"
	OptimalResult.ColumnNames[13] := "Weight"
	Loop % OptimalResult.RowCount {
		OptimalResult.Next(OptimalRow)
		maxQty := FLOOR(MIN(OptimalRow[10], availablePayload/OptimalRow[3]))
		OptimalRow[10] := maxQty
		OptimalRow[12] := maxQty * OptimalRow[8]
		OptimalRow[11] := maxQty * OptimalRow[5]
		OptimalRow[13] := Round(maxQty * OptimalRow[3],2)
		totalProfit += OptimalRow[12]
		availablePayload := availablePayload - maxQty*OptimalRow[3]
	}
	OptimalResult.Reset()
	goodsWeight -= availablePayload
	GuiControl, , Goods_PayloadInfo, % ROUND(simPayload-availablePayload,2) . " / " . simPayload . "lbs (" . CEIL((simPayload-availablePayload)*100/simPayload) . "%)"
	GuiControl, , Goods_GoodsWeight, % ROUND(goodsWeight,0)
	GuiControl, Text, Goods_OptimalGoodsText, % "Displaying " . OptimalResult.RowCount . " viable goods"
	LV_ShowTable(OptimalResult, "Goods_TradesLV")
	SB_SetText("Optimal goods refreshed")
	return
}

Goods_ToggleTradeMissions:
{
	Gui, Main:Default
	GuiControlGet, Goods_ShowTradeMissions
	If (Goods_ShowTradeMissions) {
		GuiControl, Move, Goods_MissionsLV, h125
		GuiControl, Show, Goods_TradeMissionsLV
		GuiControl, Show, Goods_TradeMissionsText
		GuiControl, Show, Goods_TradeMissionsPreText
	} else {
		GuiControl, Hide, Goods_TradeMissionsLV
		GuiControl, Hide, Goods_TradeMissionsText
		GuiControl, Hide, Goods_TradeMissionsPreText
		GuiControl, Move, Goods_MissionsLV, h250
	}
	return
}

; == Auto-Market tab Subroutines ==
Auto_List:
{
	Gui, Main:Default
	SB_SetText("Finding list ICAOs to search...")
	LV_Clear("Auto_ListLV")
	GuiControlGet, Auto_CenterICAO
	GuiControlGet, Auto_MaxDistance
	GuiControlGet, Settings_MissionDateFormat
	GuiControlGet, Settings_GoodsDateFormat
	qExpiration := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "m.expiration")
	qRefreshDate := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	AutoListQuery = 
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
				SELECT DISTINCT gm.location FROM goodsMarket AS gm WHERE %qRefreshDate% > DATETIME('now', '-%marketRefreshHours% hours', 'localtime') )
		ORDER BY ICAO
	)
	If !(AutoListResult := SQLiteGetTable(DB, AutoListQuery)) {
		return
	}
	LV_ShowTable(AutoListResult, "Auto_ListLV")	
	SB_SetText("Found list of ICAOs to search")
	return
}

Auto_Load:
{
	Gui, ListView, Auto_ListLV
	If !(LV_GetCount("Selected")) {
		MsgBox You must select at least 1 ICAO for entry.
		return
	}
	HotKey, %autoMarketHotkey%, Auto_Entry, On
	ToolTip % "READ THE INSTRUCTIONS BELOW!`t`t" . LV_GetCount("Selected") . " ICAOs left to enter"
	SB_SetText("Auto-Market entry is active")
	return
}

Auto_Entry:
{
	Gui, Main:Default
	SB_SetText("Entering next ICAO into Trading tab of NeoFly...")
	GuiControlGet, Auto_IgnoreWindow
	If (!Auto_IgnoreWindow) {
		WinGet, activeProcess, ProcessName, A
		If !(activeProcess="NeoFly.exe") {
			ToolTip, NeoFly does not appear to be the active window.
			return
		}
	}
	GuiControlGet, Auto_CenterICAO
	Gui, ListView, Auto_ListLV
	EntryRow := LV_GetNext()
	If !(EntryRow) {
		SB_SetText("Sending back to Center ICAO...")
		Send ^a{Delete}%Auto_CenterICAO%{Enter}
		GoSub Auto_Unload
		return
	} else {
		LV_GetText(ICAO, EntryRow, 1)
		SB_SetText("Sending " . ICAO . " from Row " . EntryRow)
		Send ^a{Delete}%ICAO%{Enter}
		LV_Delete(EntryRow)
	}
	If !(LV_GetCount("Selected")) { ; No more selected ICAOs
		ToolTip % "Press {" . autoMarketHotkey . "} again to return to the " . Auto_CenterICAO . " market."
	} else { ; There's more ICAOs to search
		ToolTip % LV_GetCount("Selected") . "  ICAOs left to enter"
	}
	SB_SetText("ICAO entered into trading tab of NeoFly")
	return
}

Auto_Unload:
{
	Gui, Main:Default
	SB_SetText("Turning off Auto-Market hotkey")
	HotKey, %autoMarketHotkey%, Off
	ToolTip
	SB_SetText("Auto-Market entry is stopped")
	return
}

; == Market Finder Tab Subroutines ==
Market_Search:
{
	Gui, Main:Default
	SB_SetText("Searching the markets...")
	GuiControl, Text, Market_MarketsText, % "Looking for markets..."
	GuiControlGet, Market_Name
	GuiControlGet, Market_RadioBuy
	GuiControlGet, Market_RadioSell
	GuiControlGet, Market_Normal
	GuiControlGet, Market_Fragile
	GuiControlGet, Market_Perishable
	GuiControlGet, Market_Illicit
	GuiControlGet, Market_MinimumPrice
	GuiControlGet, Market_MaximumPrice
	GuiControlGet, Market_DepartureICAO
	GuiControlGet, Settings_GoodsDateFormat
	qTypeConditions := ""
	If (Market_Normal=1) {
		qTypeConditions := qTypeConditions . "OR gm.type=1 "
	}
	If (Market_Fragile=1) {
		qTypeConditions := qTypeConditions . "OR gm.type=2 "
	}
	If (Market_Perishable=1) {
		qTypeConditions := qTypeConditions . "OR gm.type=3 "
	}
	If (Market_Illicit=1) {
		qTypeConditions := qTypeConditions . "OR gm.type=4 "
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
	; Get the list of markets
	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	MarketFinderQuery =
	(
		SELECT
			gm.name AS Good,
			CASE
				WHEN gm.type = 1 THEN 'Normal'
				WHEN gm.type = 2 THEN 'Fragile'
				WHEN gm.type = 3 THEN 'Perishable'
				WHEN gm.type = 4 THEN 'Illicit'
				ELSE 'Unknown' 
			END Type,
			gm.location AS Location,
			'N/A' AS Distance,
			gm.quantity AS [Quantity],
			gm.unitprice AS [Price/u],
			gm.unitweight AS [Price/lb],
			CASE
				WHEN gm.tradetype = 0 THEN 'For Sale'
				WHEN gm.tradetype = 1 THEN 'Will Buy'
				ELSE 'Unknown'
			END [Trade Type],
			CASE gm.ttl
				WHEN 720 THEN 'Non-P.able'
				WHEN 0 THEN 'N/A'
				ELSE gm.ttl||'hrs'
			END AS [Time to Live],
			ROUND((JULIANDAY(%qRefreshDateField%)-JULIANDAY('now', 'localtime'))*24+%marketRefreshHours%, 2) AS [Time Left (hrs)],
			gm.id AS [Database ID],
			a.lonx AS Longitude,
			a.laty AS Latitude
		FROM goodsMarket AS gm
		INNER JOIN airport AS a ON a.ident=gm.location
		WHERE
			gm.name LIKE '`%%Market_Name%`%'
			AND [Time Left (hrs)] > 0
			AND (%qTypeConditions%)
			AND gm.tradetype = %qTradeType%
		ORDER BY Location ASC
	)
	If !(MarketFinderResult := SQLiteGetTable(DB, MarketFinderQuery)) {
		return
	}
	GuiControl, Text, Market_MarketsText, % "Analyzing " . MarketFinderResult.RowCount . " matching markets..."
	; Calculate the distance to the market from given location
	MarketDepQuery =
	(
		SELECT lonx, laty FROM airport WHERE ident = '%Market_DepartureICAO%'
	)
	If !(MarketDepResult := SQLiteGetTable(DB, MarketDepQuery)) {
		return
	} 
	If (MarketDepResult.RowCount) {
		MarketDepResult.GetRow(1, MarketDepRow)
		depPosLonX := MarketDepRow[1]
		depPosLatY := MarketDepRow[2]
		Loop % MarketFinderResult.RowCount { ; Loop through each result, putting in the distance
			MarketFinderResult.Next(MarketFinderRow)
			MarketFinderRow[4] := ROUND(0.000539957*InvVincenty(depPosLatY, depPosLonX, MarketFinderRow[13], MarketFinderRow[12]), 0)
		}
		MarketFinderResult.Reset()
	}
	GuiControl, Text, Market_MarketsText, % "Showing " . MarketFinderResult.RowCount . " matching markets"
	LV_ShowTable(MarketFinderResult, "Market_MarketLV")
	SB_SetText("Markets searched")
	return
}

; == Aircraft Market Tab Subroutines ==
AircraftMarket_Search:
{
	Gui, Main:Default
	SB_SetText("Searching aircraft market...")
	GuiControl, Text, AircraftMarket_AircraftText, % "Searching aircraft market..."
	GuiControlGet, AircraftMarket_Aircraft
	moveCostPerMile := 9.0
	PilotLocationQuery = 
	(	
		SELECT lonx, laty FROM airport WHERE ident=(SELECT pilotCurrentICAO FROM career WHERE id=(SELECT pilotID FROM currentPilot LIMIT 1) LIMIT 1) LIMIT 1
	)
	If !(PilotLocationResult := SQLiteGetTable(DB, PilotLocationQuery)) {
		return
	}
	If (!PilotLocationResult.HasRows) {
		return
	} Else {
		PilotLocationResult.GetRow(1, PilotLocationRow)
		pilotLonX := PilotLocationRow[1]
		pilotLatY := PilotLocationRow[2]
	}

	qPilotWeight := Pilot.weight
	AircraftMarketQuery = 
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

	If !(AircraftMarketResult := SQLiteGetTable(DB, AircraftMarketQuery)) {
		return
	}
	GuiControl, Text, AircraftMarket_AircraftText, % "Analying " . AircraftMarketResult.RowCount . " found aircraft..."
	Loop % AircraftMarketResult.RowCount {
		AircraftMarketResult.Next(AircraftMarketRow)
		AircraftMarketRow[6] := ROUND(0.000539957*InvVincenty(pilotLatY, pilotLonX, AircraftMarketRow[8], AircraftMarketRow[7]), 0)
		AircraftMarketRow[4] := ROUND(AircraftMarketRow[6] * moveCostPerMile,0)
		AircraftMarketRow[5] := ROUND(AircraftMarketRow[3] + AircraftMarketRow[4],0)
		AircraftMarketRow[16] := ROUND(AircraftMarketRow[5] / AircraftMarketRow[11],0) ; Cost/range
		AircraftMarketRow[17] := ROUND(AircraftMarketRow[5] / AircraftMarketRow[13],0) ; Cost/payload
		AircraftMarketRow[18] := ROUND(AircraftMarketRow[5] / AircraftMarketRow[14],0) ; Cost/effective payload
		AircraftMarketRow[19] := ROUND(AircraftMarketRow[5] / AircraftMarketRow[15],0) ; Cost/Pax
	}
	AircraftMarketResult.reset()
	GuiControl, Text, AircraftMarket_AircraftText, % "Showing " . AircraftMarketResult.RowCount . " found aircraft"
	LV_ShowTable(AircraftMarketResult, "AircraftMarket_LV")
	LV_ModifyCol(5, "Sort")
	SB_SetText("Aircraft market searched")
	return
}

; == Mission Generator Tab Subroutines ==
Generator_Backup:
{
	Gui, Main:Default
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
	Gui, Main:Default
	GuiControlGet, Generator_departure
	GuiControlGet, Generator_arrival
	DepartureLocQuery = 
	(
		SELECT lonx, laty FROM airport WHERE ident='%Generator_departure%' LIMIT 1
	)
	If !(DepartureLocResult := SQLiteGetTable(DB, DepartureLocQuery)) {
		return
	}
	DepartureLocResult.GetRow(1, DepartureLocRow)
	lonDep := DepartureLocRow[1]
	latDep := DepartureLocRow[2]
	ArrivalLocQuery = 
	(
		SELECT lonx, laty FROM airport WHERE ident='%Generator_arrival%' LIMIT 1
	)
	If !(ArrivalLocResult := SQLiteGetTable(DB, ArrivalLocQuery)) {
		return
	}
	ArrivalLocResult.GetRow(1, ArrivalLocRow)
	lonArriv := ArrivalLocRow[1]
	latArriv := ArrivalLocRow[2]
	GuiControl, , Generator_lonDep, % lonDep
	GuiControl, , Generator_latDep, % latDep
	GuiControl, , Generator_lonArriv, % lonArriv
	GuiControl, , Generator_latArriv, % latArriv
	return
}

Generator_Distance:
{
	Gui, Main:Default
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
	Gui, Main:Default
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
	If Generator_xp Is Not number
	{
		qXP := 0
	} else {
		qXP := Generator_xp
	}
	GeneratorPreviewQuery := ""
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
			If Generator_Reward Is Not number
			{
				qReward := 0
			} else {
				qReward := Generator_reward
			}
		}
		NextPreviewQuery =
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
				%qXP% AS xp
		)
		GeneratorPreviewQuery := GeneratorPreviewQuery . NextPreviewQuery
		If (A_Index<Generator_Quantity) {
			GeneratorPreviewQuery := GeneratorPreviewQuery . " UNION ALL "
		}
	}
	If !(GeneratorPreviewResult := SQLiteGetTable(DB, GeneratorPreviewQuery)) {
		return
	}
	LV_ShowTable(GeneratorPreviewResult, "Generator_PreviewLV")
	SB_SetText("Mission previews generated")
	return
}

Generator_PreviewLVClick:
{
	If (A_GuiEvent = "DoubleClick") {
		If (A_EventInfo == 0) {
			return
		}
		Gui, Main:Default
		SB_SetText("Committing mission to database...")
		Gui, ListView, Goods_PreviewLV
		varList := ""
		Loop % LV_GetCount("Column") {
			LV_GetText(qVar%A_Index%, A_EventInfo, A_Index)
		}

		GeneratorCommitQuery = 
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
		If (!DB.Exec(GeneratorCommitQuery)) {
			MsgBox, 20, SQLite Error: SQLiteGetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`n`nEnsure the database is connected in the settings tab, and that the SQL query is valid`n`nDo you want to copy the query to the clipboard?"
			IfMsgBox Yes
			{
				clipboard := GeneratorCommitQuery
			}
			return
		}
		LastIDQuery =
		(
			SELECT id FROM missions ORDER BY id DESC LIMIT 1
		)
		If !(LastIDResult := SQLiteGetTable(DB, LastIDQuery)) {
			return
		}
		LastIDResult.GetRow(1,LastIDRow)
		insertedId := LastIDRow[1]

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

; == Monitor Hangar Tab Subroutines ==
Monitor_Check:
{
	Gui, Main:Default
	SB_SetText("Checking Hangar Monitor...")
	GuiControlGet, Monitor_URL
	GuiControlGet, Settings_MissionDateFormat
	If !(Monitor_OfflineMode) {
		; Get Available hangar planes
		qPilotID := Pilot.id
		MonitorHangarQuery = 
		(
			SELECT 
				hangar.id AS [Aircraft ID], 
				hangar.Aircraft, 
				CASE hangar.status
					WHEN 0 THEN 'Available'
					WHEN 1 THEN 'Flying'
					WHEN 3 THEN 'Hired'
					WHEN 5 THEN 'Removed'
					ELSE 'Unknown'
				END AS Status,
				hangar.Location
			FROM hangar
			WHERE owner=%qPilotID%
			AND hangar.status = 0
			ORDER BY hangar.id
		)
		If !(MonitorHangarResult := SQLiteGetTable(DB, MonitorHangarQuery)) { ; Disable the checks if the DB cannot be queried, to avoid infinite warnings.
			GoSub Monitor_Disable
			return
		}
		If !(monitorCheckFirstPass) { ; Skip the check if this is the first time running the Monitor Check
			; Check the Hangar table for changes
			Loop % MonitorHangarResult.RowCount {
				MonitorHangarResult.Next(MonitorHangarRow)
				planeIsOld := false
				Gui, ListView, Monitor_HangarLV
				Loop % LV_GetCount() {
					LV_GetText(oldID, A_Index)
					If (MonitorHangarRow[1] = oldId) { ; Plane was already in the table, so not new
						planeIsOld := true
						Break
					}
				}
				If !(planeIsOld) { ; Plane wasn't found in the table, must be new.
					postMessage := MonitorHangarRow[2] . " (#" . MonitorHangarRow[1] . ") is now " . MonitorHangarRow[3] . " at " . MonitorHangarRow[4]
					postdata =
					(
					{
						"username": "NeoFly Tools",
						"content": "%postMessage%"
					}
					)
					Webhook_PostSend(Monitor_URL, postdata)
				}
			}
		MonitorHangarResult.Reset()
		}
		LV_ShowTable(MonitorHangarResult, "Monitor_HangarLV")
		FormatTime, currTime, , yyyy-MM-dd HH:mm:ss
		GuiControl, Text, Monitor_HangarLastChecked, % currTime
	}
	; Get active hired missions
	qDateStart := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "rj.dateStart")
	MonitorHiredQuery =
	(
		SELECT
			rj.id AS [Job ID], 
			h.Aircraft, 
			CASE h.status
				WHEN 0 THEN 'Available'
				WHEN 1 THEN 'Flying'
				WHEN 3 THEN 'Hired'
				WHEN 5 THEN 'Removed'
				ELSE 'Unknown'
			END AS Status,
			rj.departure AS Departure,
			rj.destination AS Arrival,
			rj.pilotname AS Pilot,
			%qDateStart% AS [Departed At],
			rj.distance AS Distance,
			rj.speed AS Speed,
			DATETIME(JULIANDAY(%qDateStart%) + (1.0*rj.distance/rj.speed/24.0)) AS [ETA],
			ROUND(24.0*60.0*(JULIANDAY(%qDateStart%) + (1.0*rj.distance/rj.speed/24.0) - JULIANDAY('now', 'localtime')), 2) AS [Est. Time Remaining (mins)]
		FROM rentJob AS rj
		INNER JOIN hangar AS h ON h.id=rj.aircraftID
		WHERE h.owner=%qPilotID%
		AND rj.status=2
		ORDER BY rj.id
	)
	If !(MonitorHiredResult := SQLiteGetTable(DB, MonitorHiredQuery)) {
		GoSub Monitor_Disable ; Disable the checks if the DB cannot be queried, to avoid infinite warnings.
		return
	}
	If (!monitorCheckFirstPass && Monitor_OfflineMode) { ; If this isn't the first pass and we're in Offline mode, do the check.
		; Check through the results
		Loop % MonitorHiredResult.RowCount {
			MonitorHiredResult.Next(MonitorHiredRow)
			Gui, ListView, Monitor_HiredLV
			Loop % LV_GetCount() { ; Cross-check the Hired table to see if any have switched from + to - time remaining.
				LV_GetText(oldID, A_Index, 1)
				If (MonitorHiredRow[1] = oldID) { ; This is the same job
					LV_GetText(oldTR, A_Index, 11)
					If (MonitorHiredRow[11]<=0 && oldTR>0) { ; Job has transitioned from time remaining to time elapsed
						postMessage := MonitorHiredRow[6] . " should be at " . MonitorHiredRow[5] . " with the " . MonitorHiredRow[2] . " (#" . MonitorHiredRow[1] . ")"
						postdata =
						(
						{
							"username": "NeoFly Tools",
							"content": "%postMessage%"
						}
						)
						Webhook_PostSend(Monitor_URL, postdata)
					}
				}
				break ; Can break the LV loop since we found the ID.
			}
		}
	}
	MonitorHiredResult.Reset()
	LV_ShowTable(MonitorHiredResult, "Monitor_HiredLV")
	monitorCheckFirstPass := false ; Unset the first-pass market
	FormatTime, currTime, , yyyy-MM-dd HH:mm:ss
	GuiControl, Text, Monitor_HiredLastChecked, % currTime
	SB_SetText("Hangar Monitor check complete")
	return
}

Monitor_Enable:
{
	Gui, Main:Default
	SB_SetText("Enabling hangar monitor...")
	GuiControl, Disable, Monitor_Enable
	GuiControl, Disable, Monitor_RefreshInterval
	GuiControl, Enable, Monitor_Disable
	GuiControl, Enable, Monitor_HiredLV
	GuiControlGet, Monitor_OfflineMode
	GuiControlGet, Monitor_RefreshInterval
	If !(Monitor_OfflineMode) {
		GuiControl, Enable, Monitor_HangarLV
	}
	
	monitorCheckFirstPass := true
	GoSub Monitor_Check
	SetTimer, Monitor_Check, % Monitor_RefreshInterval*1000
	SB_SetText("Hangar monitor enabled, refreshing every " . Monitor_RefreshInterval . " seconds")
	return
}

Monitor_Disable:
{
	Gui, Main:Default
	SB_SetText("Disabling hangar monitor...")
	SetTimer, Monitor_Check, Off
	GuiControl, Enable, Monitor_Enable
	GuiControl, Enable, Monitor_RefreshInterval
	GuiControl, Disable, Monitor_Disable
	GuiControl, Text, Monitor_HangarLastChecked, ---
	GuiControl, Text, Monitor_HiredLastChecked, ---
	LV_Clear("Monitor_HangarLV")
	LV_Clear("Monitor_HiredLV")
	GuiControl, Disable, Monitor_HangarLV
	GuiControl, Disable, Monitor_HiredLV
	SB_SetText("Hangar monitor disabled")
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
		Default: ; Simply return the original field if not in list of supported
			return field
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
LV_ShowTable(Table, LV, drawImmediate := TRUE) {
	Critical, On ; Make this thread critical so that the LV can be completed before the next LV_ShowTable is called.
	Gui, ListView, %LV%
	LV_Clear(LV)
	GuiControl, Disable, %LV%
	GuiControl, -ReDraw, %LV%
	If (Table.HasNames) {
		Loop, % Table.ColumnCount {
			LV_InsertCol(A_Index,"", Table.ColumnNames[A_Index])
		}
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
	If (drawImmediate) {
		GuiControl, +ReDraw, %LV%
	}
	GuiControl, Enable, %LV%
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

; == Webhook functions ==
Webhook_PostSend(url, postdata) {
	Try {
		WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		WebRequest.Open("POST", url, false)
		WebRequest.SetRequestHeader("Content-Type", "application/json")
		WebRequest.Send(postdata)
	} catch e {
		MsgBox % "Could not send webhook.`n`nError:`n" . e
	}
}

