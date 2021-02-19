; Script Info
; Small collection of tools for use with the NeoFly career mode addon for MSFS 2020 (https://www.neofly.net/).
;
; Language:         English
; Tested on:        Windows 10 64-bit
; Author:           Epidurality

versionNumber := "0.7.0"
updateLink := "https://github.com/Epidurality/NeoFly-Tools/"

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
global dateFormats := "No Reformatting (Fastest)|yyyy/mm/dd|dd/mm/yyyy|mm/dd/yyyy|COULD NOT DETECT"

; INI vars declaration
global defaultDBPath
global autoConnect
global autoConnectDefaultTab
global hideTrayIcon
global autoMarketHotkey
global autoMarketStopHotkey
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
IniRead, autoMarketStopHotkey, %iniPath%, Setup, autoMarketStopHotkey, NumpadSub
IniRead, discordWebhookURL, %iniPath%, Setup, discordWebhookURL, https://discord.com/api/webhooks/[YourWebhookKeyHere]
}

; ==== Main GUI ====

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
	Gui, Add, Tab3, vGUI_Tabs, Settings|Goods Optimizer|Auto-Market|Market Finder|Aircraft Market|Mission Generator|Monitor Hangar|Company Manager|Flight Tools
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

; Context menus
{
	Menu, MissionsContextMenu, Add, Use As Departure, MissionsContext_UseAsDeparture
	Menu, MissionsContextMenu, Add, Market Finder, MissionsContext_MarketFinder
	
	Menu, TradeMissionsContextMenu, Add, Use As Departure, TradeMissionsContext_UseAsDeparture
	Menu, TradeMissionsContextMenu, Add, Market Finder, TradeMissionsContext_MarketFinder
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

	Gui, Add, Button, xm+10 y+10 gSettings_Backup, Backup Database
	Gui, Add, Text, R2 x+10 w600, Always backup your database before using this tool for the first time, or after updates.

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
	Gui, Add, ListView, xm+10 y+10 w915 h150 Count1000 vSettings_TimestampLV, 
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
	Gui, Add, CheckBox, x+30 y+-15 vGoods_HangarAll gGoods_RefreshHangar, Show All Planes
	Gui, Add, Text, xm+350 y+10 vGoods_Hangar, Hangar:
	Gui, Add, Checkbox, x+40 vGoods_ManageOptions gGoods_ManageOptions, Auto-Manage Options
	Gui, Add, Checkbox, x+100 vGoods_IgnoreOnboardCargo gGoods_RefreshHangar, Ignore Onboard Cargo
	Gui, Add, ListView, xm+350 y+10 w575 h100 Grid vGoods_HangarLV gGoods_HangarLVClick

	Gui, Add, Button, xm+100 y105 h20 w150 gSummary_Show, Summary / AutoBuy
	Gui, Add, Text, xm+20 y+5 w50 h15, Aircraft:
	Gui, Add, Text, x+10 w250 hp vGoods_PlaneInfo, Double click a plane in the Hangar to select it
	Gui, Add, Text, xm+20 y+10 w50 hp, Fuel:
	Gui, Add, Text, x+10 w250 hp vGoods_FuelInfo, ---
	Gui, Add, Text, xm+20 y+10 w50 hp, Payload:
	Gui, Add, Text, x+10 w250 hp vGoods_PayloadInfo, ---
	Gui, Add, Text, xm+20 y+10 w50 hp, Mission:
	Gui, Add, Text, x+10 w250 hp vGoods_MissionInfo, ---

	Gui, Add, Text, xm+70 y+10, Arrival Requirements:
	Gui, Add, Checkbox, x+20 vGoods_ArrivalILS gGoods_RefreshMissions, ILS
	Gui, Add, Checkbox, x+20 vGoods_ArrivalApproach gGoods_RefreshMissions, Approach
	Gui, Add, Checkbox, x+20 vGoods_ArrivalLights gGoods_RefreshMissions, Rwy Lights
	Gui, Add, Checkbox, x+20 vGoods_ArrivalVASI gGoods_RefreshMissions, VASI/PAPI
	Gui, Add, Checkbox, x+20 vGoods_ArrivalHard gGoods_RefreshMissions, Hard Rwy
	Gui, Add, Checkbox, x+20 vGoods_ArrivalTower gGoods_RefreshMissions, Tower
	Gui, Add, Text, x+20, Min Rwy Len.
	Gui, Add, Edit, x+10 w50 vGoods_ArrivalRwyLen, 0
	Gui, Add, Checkbox, x+5 vGoods_AutoRwyLen Checked, Auto

	Gui, Add, Button, xm+10 y+10 gGoods_RefreshMissions, Refresh Missions
	Gui, Add, Text, x+20, Goods Filters:
	Gui, Add, CheckBox, x+20 vGoods_IncludeIllicit gGoods_RefreshMissions, Illicit
	Gui, Add, Checkbox, x+20 vGoods_IncludeFragile Checked gGoods_RefreshMissions, Fragile
	Gui, Add, Checkbox, x+20 vGoods_IncludePerishable Checked gGoods_RefreshMissions, Perishable
	Gui, Add, Checkbox, x+20 vGoods_IncludeNormal Checked gGoods_RefreshMissions, Normal
	Gui, Add, Text, x+20,  Overweight:
	Gui, Add, Edit, x+2 vGoods_MaxOverweight w50 h20, 0
	Gui, Add, Text, x+2, lbs
	Gui, Add, Text, x+20, Max Range:
	Gui, Add, Edit, x+2 vGoods_MaxRange w40 h20, 9999
	Gui, Add, Checkbox, x+5 vGoods_AutoMaxRange Checked, Auto
	
	Gui, Add, Text, xm+10 y+20, NeoFly Missions:
	Gui, Add, Text, x+5 w500 vGoods_MissionsText,
	Gui, Add, Checkbox, x+10 gGoods_ToggleTradeMissions vGoods_ShowTradeMissions Checked, Show Trade/Transit Missions
	Gui, Add, Checkbox, x+10 gGoods_RefreshMissions vGoods_ShowAllNFMissions, Show Missions w/o Trades
	Gui, Add, ListView, xm+10 y+10 w915 h125 Count100 Grid vGoods_MissionsLV gGoods_MissionsLVClick

	Gui, Add, Text, xm+10 y+10 vGoods_TradeMissionsPreText, Trade / Transit Missions:
	Gui, Add, Text, x+5 w500 vGoods_TradeMissionsText, 
	Gui, Add, ListView, xm+10 y+10 w915 h100 Count500 Grid vGoods_TradeMissionsLV gGoods_TradeMissionsLVClick

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
	Gui, Add, Button, x+30 gAuto_AutoEntry, Auto Entry
	Gui, Add, Checkbox, x+30 vAuto_IgnoreWindow, Ignore Active Window Check`n(only use if script is not properly detecting that NeoFly is the active window)
	Gui, Add, Text, x+10, Delay in Auto Entry (ms):
	Gui, Add, Edit, x+5 vAuto_Delay, 1500
	
	Gui, Font, Bold
	Gui, Add, Text, xm+10 y+30, Please read the included Readme for instructions on using this part of the tool.
	Gui, Font
	
}	

; GUI Market Finder tab
{
	Gui, Tab, Market Finder
	Gui, Add, Text, xm+10 y70 w50, Name:
	Gui, Add, ComboBox, x+10 w200 vMarket_Name, ||Beer|Caviar|Cigarette|Clothes|Coffee|Computer|Contraband Cigars|Fish|Flower|Fruit|Fuel|Magazine|Meat|Mechanical parts|Medicine|Old wine|Phone|Pillza|Vegetable|Whiskey
	Gui, Add, Text, x+20 yp+5, I want to
	Gui, Add, Radio, x+10 yp-5 vMarket_RadioBuy, Buy
	Gui, Add, Radio, y+10 Checked vMarket_RadioSell, Sell
	Gui, Add, Text, x+40 y+-30, Show`nDistance From:
	Gui, Add, Edit, x+10 w75 vMarket_DepartureICAO, KJFK
	Gui, Add, Text, x+20, Show Goods`nOnly At:
	Gui, Add, Edit, x+10 w75 vMarket_FilterICAO,

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
	Gui, Add, Button, x+150 gAircraftMarket_Compare, Compare Models
	Gui, Add, Text, xm+10 y+20, Matching Aircraft:
	Gui, Add, Text, x+10 w500 vAircraftMarket_AircraftText, Press Search to find aircraft in the market
	Gui, Add, ListView, xm+10 y+10 w915 h450 Grid vAircraftMarket_LV
	Gui, Add, Text, xm+10 y+20, Note: Travel Cost represents a one-way trip from your pilot's current location to the plane's Location.
	Gui, Add, Text, xm+10 y+20, % "Other Note: Effective Payload is the payload of the plane after subtracting the Pilot's weight (" . Pilot.weight . "lbs) and " . ROUND(fuelPercentForAircraftMarketPayload*100,0) . "% of max fuel."
}

; GUI Mission Generator tab
{
	Gui, Tab, Mission Generator
	Gui, Add, Text, xm+10 y70, Departure ICAO:
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
	Gui, Add, Edit, x+5 w100 vGenerator_dist, 100
	Gui, Add, Text, x+20, Heading (degrees):
	Gui, Add, Edit, x+5 w60 vGenerator_hdg, 0

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

; Gui Company Manager tab
{
	Gui, Tab, Company Manager
	Gui, Add, Button, xm+10 y70 gCompany_CleanLoans, Clean Up Loans
	Gui, Add, Button, xm+10 y+20 gCompany_Finances, View Finances
	Gui, Add, DropDownList, x+10 vCompany_FinancesPeriod, 24 Hours||7 Days|30 Days|All Time
	Gui, Add, ListView, xm+10 y+10 w915 h200 Grid vCompany_FinancesLV
}

; Gui Flight Tools tab
{
	Gui, Tab, Flight Tools
	Gui, Add, GroupBox, xm+10 y70 w915 h100, Descent Calculator
	
	Gui, Add, Text, xp+20 yp+20 Section, Airport ICAO:
	Gui, Add, Edit, x+5 w50 vFlight_AirportICAO, KJFK
	Gui, Add, Text, x+20, Altitude (ft):
	Gui, Add, Edit, x+5 w50 vFlight_CurrentAltitude, 10500	
	Gui, Add, Text, x+20, Ground Speed (kts):
	Gui, Add, Edit, x+5 w50 vFlight_Speed, 120
	Gui, Add, Text, x+20, Glide Slope (deg):
	Gui, Add, Edit, x+5 w50 vFlight_GlideSlope, 3
	
	Gui, Add, Button, xs y+10 gFlight_CalculateDescent, Calculate Descent
	Gui, Add, Text, x+40, Start at (nm):
	Gui, Add, Text, x+5 w50 vFlight_DescentDistance, ---
	Gui, Add, Text, x+20, Descend at (fpm):
	Gui, Add, Text, x+5 w50 vFlight_DescentRate, ---
	Gui, Add, Text, x+20, Airport Altitude (ft):
	Gui, Add, Text, x+5 w50 vFlight_AirportAlt, ---
	
	Gui, Add, GroupBox, xm+10 y+50 w915 h60, Stopwatch
	Gui, Font, s15
	Gui, Add, Text, xp+20 yp+20 w200 Center vFlight_StopwatchDisplay, 0:00:00
	Gui, Font
	Gui, Add, Button, x+10 w60 vFlight_StopwatchStart gFlight_StopwatchStart, Start
	Gui, Add, Button, x+20 w60 vFlight_StopwatchStop gFlight_StopwatchStop Disabled, Stop
}

; ==== Summary GUI ====
{
	Gui, Summary:New
	Gui, Summary:Default
	Gui, +AlwaysOnTop -MinimizeBox -MaximizeBox
	Gui, Add, Text, xm, Mission:
	Gui, Add, Text, xm+20 w280 vSummary_MissionInfo, Summary_MissionInfo
	Gui, Add, Text, xm+ y+10, Aircraft:
	Gui, Add, Text, xm+20 w280 vSummary_PlaneInfo, Summary_PlaneInfo
	Gui, Font, bold
	Gui, Add, Text, xm y+20, Goods to buy:
	Gui, Font
	Gui, Add, ListView, xm y+5 w280 h150 vSummary_ToBuyLV, Good|Qty
	Gui, Add, Text, xm y+20 w60, Fuel:
	Gui, Add, Text, x+5 w220 vSummary_FuelInfo, Summary_FuelInfo
	Gui, Add, Text, xm w60, Payload:
	Gui, Add, Text, x+5 w220 vSummary_PayloadInfo, Summary_PayloadInfo
	Gui, Add, Text, xm y+10 cRed w280 h50 +wrap, Summary_WarningText
	Gui, Add, Button, x65 y+10 w150 gSummaryGuiClose, Close
	Gui, Add, Button, x65 y+20 w150 gSummary_Buy vSummary_Buy, Buy for Me!
}

; ==== Main initialization ====
{
	Gui, Main:Default
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
}

return ; End of auto-run at startup.

; ==== SUBROUTINES =====
; GUI functions

; == Main Gui/Context Subroutines
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

MainGuiContextMenu:
{
	Switch A_GuiControl
	{
		Case "Goods_MissionsLV":
			Gui, Main:Default
			Gui, ListView, Goods_MissionsLV
			LV_GetText(lvContent, LV_GetNext(), 1)
			If (lvContent<>"") { ; Only if the list view has a valid selected row...
				Menu, MissionsContextMenu, Show, %A_GuiX%, %A_GuiY%
			}
			return
		Case "Goods_TradeMissionsLV":
			Gui, Main:Default
			Gui, ListView, Goods_TradeMissionsLV
			LV_GetText(lvContent, LV_GetNext(), 1)
			If (lvContent<>"") { ; Only if the list view has a valid selected row...
				Menu, TradeMissionsContextMenu, Show, %A_GuiX%, %A_GuiY%
			}
			return
		Default:
			return
	}
	return
}

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

Settings_Backup:
{
	Gui, Main:Default
	SB_SetText("Backing up database...")
	GuiControlGet, Settings_DBPath
	FormatTime, timestampSuffix, , yyyyMMddHHmmss
	BackupPath := Settings_DBPath . ".backup" . timestampSuffix
	MsgBox, 36, Backup Confirmation, Clicking YES will attempt to create a backup of:`n`n%Settings_DBPath%`nas`n%BackupPath%`n`nCreate backup?
	IfMsgBox Yes 
	{
		IfNotExist %Settings_DBPath%
		{
			MsgBox, 16, Error, Cannot find file specified. Please double-check your database path in the Settings tab.
			return
		}
		FileCopy, %Settings_DBPath%, %BackupPath%, true
		If (ErrorLevel) {
			MsgBox, 16, Error, Could not complete backup. Error:`n%A_LastError%
		} else {
			MsgBox, 64, Success!, Backup performed, but it's a good idea to double-check if this was the first time backup up this database.`n`nRemember to periodically delete old backup versions
		}
	} else {
		MsgBox, 64, Aborted, Backup was not performed.
	}
	SB_SetText("Database backup complete")
	return
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
			SELECT * FROM (
				SELECT DISTINCT 
					'Missions.Expiration' AS [DB Field], 
					expiration AS [DB Value], %qExpiration% AS Formatted, 
					IFNULL(DATETIME(%qExpiration%), 'INVALID') AS Validation,
					IFNULL(JULIANDAY(%qExpiration%, 'localtime')-JULIANDAY('now','localtime'), 'INVALID') AS [Then-Now(Days)]
				FROM missions ORDER BY id DESC LIMIT 300 )
			ORDER BY Validation DESC LIMIT 1
		)
		If !(MissionTimeCheckResult := SQLiteGetTable(DB, MissionTimeCheckQuery)) {
			return
		}
		MissionTimeCheckResult.GetRow(1, MissionTimeCheckRow)
		If (MissionTimeCheckRow[3] != "INVALID" && MissionTimeCheckRow[4] != "INVALID" && MissionTimeCheckResult.RowCount>0) { ; This format worked
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
			SELECT * FROM (
				SELECT DISTINCT 
					'GoodsMarket.RefreshDate' AS [DB Field], 
					refreshDate AS [DB Value], %qRefreshDate% AS Formatted, 
					IFNULL(DATETIME(%qRefreshDate%), 'INVALID') AS Validation,
					IFNULL(JULIANDAY(%qRefreshDate%)-JULIANDAY('now','localtime'), 'INVALID') AS [Then-Now(Days)]
				FROM goodsMarket ORDER BY id DESC LIMIT 300 )
			ORDER BY Validation DESC LIMIT 1
		)
		If !(GoodsTimeCheckResult := SQLiteGetTable(DB, GoodsTimeCheckQuery)) {
			return
		}
		GoodsTimeCheckResult.GetRow(1, GoodsTimeCheckRow)
		If (GoodsTimeCheckRow[3] != "INVALID" && GoodsTimeCheckRow[4] != "INVALID" && GoodsTimeCheckResult.RowCount>0) { ; This format worked
			break ; Stop choosing mission formats
		}
	}
	GuiControlGet, Settings_MissionDateFormat
	GuiControlGet, Settings_GoodsDateFormat
	; This just dynamically gets the last element, which will always be our "error" element, of the dropbox.
	Loop, Parse, dateFormats, |
	{
		lastFormat := A_LoopField
	}
	If (Settings_MissionDateFormat = lastFormat || Settings_GoodsDateFormat = lastFormat) { ; Was not able to detect one of the dates reliably
		MsgBox, 16, Timestamp Error, % "Could not reliably detect Mission and/or GoodsMarket timestamp format.`n`nProgram will not function correctly if dates are not set properly.`n`nEnsure you have searched Markets and Missions to increase reliability of automatic timestamp detection."
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
				IFNULL(DATETIME(%qRefreshDate%), 'INVALID') AS Validation,
				IFNULL(JULIANDAY(%qRefreshDate%)-JULIANDAY('now','localtime'), 'INVALID') AS [Then-Now(Days)]
			FROM goodsMarket ORDER BY id DESC LIMIT 300 )
		UNION ALL SELECT * FROM (
			SELECT DISTINCT 
				'Missions.Expiration' AS [DB Field], 
				expiration AS [DB Value], %qExpiration% AS Formatted, 
				IFNULL(DATETIME(%qExpiration%), 'INVALID') AS Validation,
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
	GuiControl, , Goods_PayloadInfo
	GuiControl, , Goods_PlaneInfo, Double-click a Plane from the Hangar
	GuiControl, , Goods_MissionInfo
	GuiControl, , Goods_FuelInfo
	GuiControl, , Goods_OptimalGoodsText
	GuiControl, , Goods_WarningText
	qPilotID := Pilot.id
	If (Goods_HangarAll) {
		qStatusClause := "hangar.status != 5"
	} Else {
		qStatusClause := "hangar.status = 0"
	}
	hangarQuery = 
	(
		SELECT 
			hangar.id AS ID,
			hangar.tailNumber AS Tail,
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
			IFNULL(onboardCargo.totalCargo,0) AS [Onboard Cargo (lbs)],
			hangar.Rangenm AS Range
		FROM hangar 
		INNER JOIN 
			aircraftdata ON hangar.Aircraft=aircraftdata.Aircraft
		LEFT JOIN (
			SELECT planeid, SUM(totalweight) AS totalCargo FROM cargo GROUP BY planeid ) AS onboardCargo ON hangar.id = onboardCargo.planeid
		WHERE owner=%qPilotID% 
		AND %qStatusClause%
		ORDER BY hangar.tailNumber, hangar.id
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
		; Load the Plane info into the global vars for other things to use
		Gui, ListView, Goods_HangarLV
		LV_GetText(lvID, A_EventInfo, 1)
		LV_GetText(lvTailNum, A_EventInfo, 2)
		LV_GetText(lvName, A_EventInfo, 3)
		LV_GetText(lvPayload, A_EventInfo, 5)
		LV_GetText(lvPax, A_EventInfo, 6)
		LV_GetText(lvLocation, A_EventInfo, 7)
		LV_GetText(lvFuel, A_EventInfo, 10)	
		LV_GetText(lvMaxFuel, A_EventInfo, 11)
		LV_GetText(lvQualification, A_EventInfo, 12)
		LV_GetText(lvCruiseSpeed, A_EventInfo, 13)
		LV_GetText(lvOnboardCargo, A_EventInfo, 14)
		LV_GetText(lvRange, A_EventInfo, 15)
		GuiControlGet, Goods_ManageOptions
		If (Goods_ManageOptions) { ; If we're auto-managing the options...
			qPilotID := Pilot.id
			PilotLocationQuery =
			(
				SELECT pilotCurrentICAO FROM career WHERE id = %qPilotID% LIMIT 1
			)
			If !(PilotLocationResult := SQLiteGetTable(DB, PilotLocationQuery)) {
				return
			}
			PilotLocationResult.GetRow(1, PilotLocationRow)
			If (lvLocation = PilotLocationRow[1]) { ; Assume User is flying
				GuiControl, , Goods_AutoRwyLen, 1
				GuiControl, , Goods_AutoMaxRange, 1
				GuiControl, , Goods_MaxOverweight, 0
				GuiControl, , Goods_IncludeIllicit, 0
				GuiControl, , Goods_IncludeFragile, 1
				GuiControl, , Goods_IncludePerishable, 1
				GuiControl, , Goods_IncludeNormal, 1
				If (lvQualification != "A") {
					GuiControl, , Goods_ArrivalHard, 1
				}
				If (lvQualifiction != "A" && lvQualifiction != "B") {
					GuiControl, , Goods_ArrivalVASI, 1
				}
			} else { ; Assume AI is flying
				GuiControl, , Goods_AutoRwyLen, 0
				GuiControl, , Goods_ArrivalRwyLen, 0
				GuiControl, , Goods_MaxOverweight, 99999
				GuiControl, , Goods_AutoMaxRange, 1
				GuiControl, , Goods_IncludeIllicit, 1
				GuiControl, , Goods_IncludeFragile, 1
				GuiControl, , Goods_IncludePerishable, 1
				GuiControl, , Goods_IncludeNormal, 1
				GuiControl, , Goods_ArrivalILS, 0
				GuiControl, , Goods_ArrivalApproach, 0
				GuiControl, , Goods_ArrivalLights, 0
				GuiControl, , Goods_ArrivalVASI, 0
				GuiControl, , Goods_ArrivalHard, 0
				GuiControl, , Goods_ArrivalTower, 0
			}
		}
		GuiControlGet, Goods_IgnoreOnboardCargo
		GuiControlGet, Goods_AutoRwyLen
		GuiControlGet, Goods_AutoMaxRange
		If (Goods_AutoRwyLen) {
			GuiControl, Text, Goods_ArrivalRwyLen, % CEIL((1300*Ln(lvPayload)-7700)/500)*500+500
		}
		If (Goods_AutoMaxRange) {
			GuiControl, Text, Goods_MaxRange, % lvRange
		}
		Plane.id := lvId
		Plane.name := lvName . " " . lvTailNum
		Plane.payload := lvPayload
		Plane.pax := lvPax
		Plane.location := lvLocation
		Plane.fuel := lvFuel
		Plane.maxFuel := lvMaxFuel
		Plane.cruiseSpeed := lvCruiseSpeed
		If (Goods_IgnoreOnboardCargo) { ; if the checkbox is set or the onboardCargo result is blank (no cargo entries)...
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
	GuiControl, , Goods_OptimalGoodsText, Double-Click a Mission/Trade Mission
	GuiControl, , Goods_WarningText
	GuiControl, , Goods_PayloadInfo, Double-Click a Mission/Trade Mission
	GuiControl, , Goods_MissionInfo, Double-Click a Mission/Trade Mission
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
	GuiControlGet, Goods_MaxOverweight
	GuiControlGet, Goods_ArrivalTower
	GuiControlGet, Goods_ShowAllNFMissions
	GuiControlGet, Goods_MaxRange
	; Check to see if the Departure ICAO has a valid market.
	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	If (true) { ; REMOVING NOW THAT THE ALL MISSION CHECKBOX EXISTS, BUT KEEPING IN CASE THIS CAUSES OTHER ISSUES.
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
			GuiControl, , Goods_MissionsText, % "You MUST Search the market at departure ICAO: '" . Goods_DepartureICAO . "'"
			LV_Clear("Goods_MissionsLV")
			LV_Clear("Goods_TradeMissionsLV")
			LV_Clear("Goods_TradesLV")
			SB_SetText("Unable to refresh missions")
			return
		}
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
	qPayload := Plane.payload+MIN(Plane.fuel, Goods_MaxOverweight) - Plane.fuel-Pilot.weight-Plane.onboardCargo
	If (qPayload<200) {
		GuiControl, Text, Goods_WarningText, % "Available plane payload is only " . qPayload . "lbs, and may limit search results."
	}
	qPax := Plane.pax
	; Get NeoFly missions
	GuiControl, , Goods_MissionsText, % "Looking for missions..."
	qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "gm.refreshDate")
	qExpirationField := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "m.expiration")
	If (Goods_ShowAllNFMissions) {
		qGoodsJoinReq := "AND [Time Left (hrs)] > 0"
		qGoodsWhereReq := ""
	} else {
		qGoodsJoinReq := ""
		qGoodsWhereReq := "AND [Time Left (hrs)] > 0"
	}
	
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
			m.reward AS [Total Income],
			0 AS [Income/nm],
			ROUND((JULIANDAY(%qRefreshDateField%)-JULIANDAY('now', 'localtime'))*24+%marketRefreshHours%, 2) AS [Time Left (hrs)],
			'' AS [Can Buy At Arrival],
			ROUND((JULIANDAY(%qExpirationField%)-JULIANDAY('now', 'localtime'))*24, 2) AS [Mission Expires (hrs)],
			a.num_runway_end_ils AS [ILS],
			a.num_approach AS [Approaches],
			a.num_runway_light AS [Rwy Lights],
			a.num_runway_end_vasi AS [VASI/PAPI],
			a.num_runway_hard AS [Hard Rwys],			
			a.longest_runway_length AS [Rwy Len],
			a.has_tower_object AS [Tower],
			m.missionHeading AS Hdg
		FROM missions AS m
		LEFT JOIN goodsMarket AS gm
		ON 
			gm.location=m.arrival
			%qGoodsJoinReq%
		INNER JOIN airport AS a
		ON a.ident=m.arrival
		WHERE
			departure='%Goods_DepartureICAO%'
			AND m.dist <= %Goods_MaxRange%
			AND a.num_runway_hard >= %Goods_ArrivalHard%
			AND a.num_runway_light >= %Goods_ArrivalLights%
			AND a.num_runway_end_ils >= %Goods_ArrivalILS%
			AND a.num_runway_end_vasi >= %Goods_ArrivalVASI%
			AND a.num_approach >= %Goods_ArrivalApproach%
			AND a.longest_runway_length >= %Goods_ArrivalRwyLen%
			AND a.has_tower_object >= %Goods_ArrivalTower%
			AND m.weight <= %qPayload%
			AND m.pax <= %qPax%
			AND [Mission Expires (hrs)] > 0
			%qGoodsWhereReq%
		GROUP BY m.id
	)
	If !(NFMissionsResult := SQLiteGetTable(DB, NFMissionsQuery)) {
		return
	}
	; Analyze NeoFly missions
	If !(NFMissionsResult.RowCount) { ; If none are displayed, show the user a bit more detail of why that might be
		NFMissionsCheckQuery =
		(
			SELECT m.id FROM missions AS m WHERE m.departure='%Goods_DepartureICAO%' AND %qExpirationField% > DATETIME('now','localtime')
		)
		If !(NFMissionsCheckResult := SQLiteGetTable(DB, NFMissionsCheckQuery)) {
			return
		}
		If !(NFMissionsCheckResult.RowCount) {
			GuiControl, , Goods_MissionsText, % "Could not find any missions at '" . Goods_DepartureICAO . "', try Reset in NeoFly Missions tab."
		} else {
			GuiControl, , Goods_MissionsText, % "Found current missions at '" . Goods_DepartureICAO . "', but either don't meet criteria or don't have markets at destinations."
		}
		SB_SetText("No viable NeoFly Missions found")
	} else {
		GuiControl, , Goods_MissionsText, % "Analyzing " NFMissionsResult.RowCount . " missions..."
		qDepRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dep.refreshDate")
		qDestRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "dest.refreshDate")
		If (Goods_ShowAllNFMissions) {
			qGoodsSelectReq := "ROUND((JULIANDAY(" . qDestRefreshDateField . ")-JULIANDAY('now', 'localtime'))*24+" . marketRefreshHours . ", 2)"
		} else {
			qGoodsSelectReq := 99
		}
		Loop % NFMissionsResult.RowCount {
			NFMissionsResult.Next(NFMissionsRow)
			If (NFMissionsRow[13] = "") { ; This means there was no available cargo/market, so we can skip the analysis.
				continue
			}
			qDeparture := NFMissionsRow[2]
			qArrival := NFMissionsRow[3]
			qMissionCargo := NFMissionsRow[6]
			qPay := NFMissionsRow[7]
			NFMissionsGoodsQuery = 
			(
				SELECT
					dep.name AS Good,
					replace(dep.unitWeight, ',', '.') AS [Weight/u],
					dest.unitPrice - dep.unitPrice AS [Profit/u],
					MIN(dest.quantity, dep.quantity) AS [Max Qty],
					%qGoodsSelectReq% AS [Time Left (hrs)]
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
					AND [Time Left (hrs)] > 0
				ORDER BY [Profit/u]/[Weight/u] DESC
			)
			If !(NFMissionsGoodsResult := SQLiteGetTable(DB, NFMissionsGoodsQuery)) {
				return
			}
			If (NFMissionsGoodsResult.RowCount) {
				totalProfit := 0
				availablePayload := Plane.payload+MIN(Plane.fuel, Goods_MaxOverweight) - Plane.fuel-Pilot.weight-Plane.onboardCargo-qMissionCargo
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
				a.longest_runway_length AS [Rwy Len],
				a.has_tower_object AS [Tower]
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
				AND a.has_tower_object >= %Goods_ArrivalTower%
				AND a.longest_runway_length >= %Goods_ArrivalRwyLen%
		)
		If !(TradesResult := SQLiteGetTable(DB, TradesQuery)) {
			return
		}
		If !(TradesResult.RowCount) {
			GuiControl, , Goods_TradeMissionsText, % "Could not find suitable trade markets. Try searching more in NeoFly or changing criteria."
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
						MIN(dest.quantity, dep.quantity) AS [Max Qty]		
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
					ORDER BY [Profit/u]/[Weight/u] DESC
				)
				If !(TradesGoodsResult := SQLiteGetTable(DB, TradesGoodsQuery)) {
					return
				}
				totalProfit := 0
				availablePayload := Plane.payload+MIN(Plane.fuel, Goods_MaxOverweight) - Plane.fuel-Pilot.weight-Plane.onboardCargo
				Loop % TradesGoodsResult.RowCount {
					TradesGoodsResult.Next(TradesGoodsRow)
					maxQty := FLOOR(MIN(TradesGoodsRow[4], availablePayload/TradesGoodsRow[2]))
					totalProfit += maxQty * TradesGoodsRow[3]
					availablePayload := availablePayload - maxQty*TradesGoodsRow[2]
				}
				TradesRow[3] := totalProfit
				TradesRow[4] := ROUND(distanceFromCoord(pilotLonX, pilotLatY, TradesRow[6], TradesRow[7]))
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
	GoSub Goods_CheckHangar
	SB_SetText("Missions refreshed")
	return
}

MissionsContext_UseAsDeparture:
{
	Gui, Main:Default
	Gui, ListView, Goods_MissionsLV
	LV_GetText(lvArrival, LV_GetNext(), 3)
	If (lvArrival<>"") {
		GuiControl, Text, Goods_DepartureICAO, % lvArrival
		GoSub Goods_RefreshMissions
	}
	return
}

MissionsContext_MarketFinder:
{
	Gui, Main:Default
	Gui, ListView, Goods_MissionsLV
	LV_GetText(lvArrival, LV_GetNext(), 3)
	If (lvArrival<>"") {
		GuiControl, Text, Market_FilterICAO, % lvArrival
		GuiControl, Choose, GUI_Tabs, Market Finder
		GoSub Market_Search
	}
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
		If (lvTimeLeft != "" && lvTimeLeft < lvDistance/Plane.cruiseSpeed+1) {
			GuiControl, , Goods_WarningText, Warning: There are only %lvTimeleft% hours left to deliver goods to this market before it refreshes.
		}
		GuiControl, , Goods_MissionWeight, % lvMissionWeight
		GuiControl, , Goods_ArrivalICAO, % lvArrival
		GuiControl, , Goods_MissionInfo, % lvDeparture . ">" . lvArrival . " - " . lvMissionType
		GoSub Goods_RefreshMarket
	}
	return
}

TradeMissionsContext_UseAsDeparture:
{
	Gui, Main:Default
	Gui, ListView, TradeMissionsLV
	LV_GetText(lvArrival, LV_GetNext(), 2)
	If (lvArrival<>"") {
		Gui, Tab, Market Finder
		GuiControl, Text, Goods_DepartureICAO, % lvArrival
		GoSub Goods_RefreshMissions
	}
	return
}

TradeMissionsContext_MarketFinder:
{
	Gui, Main:Default
	Gui, ListView, TradeMissionsLV
	LV_GetText(lvArrival, LV_GetNext(), 2)
	If (lvArrival<>"") {
		GuiControl, Text, Market_FilterICAO, % lvArrival
		GuiControl, Choose, GUI_Tabs, Market Finder
		GoSub Market_Search
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
	GuiControlGet, Goods_AllowOverweight
	GuiControlGet, Goods_MaxOverweight
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
			replace(dep.unitWeight, ',', '.')*MIN(dest.quantity, dep.quantity) AS [Max Weight],
			dep.id AS ID
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
	availablePayload := Plane.payload+MIN(Plane.fuel, Goods_MaxOverweight) - Plane.fuel-Pilot.weight-Plane.onboardCargo-Goods_MissionWeight
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
	simExpectedPayload := Goods_MissionWeight + Pilot.weight + Plane.onboardCargo + goodsWeight
	GuiControl, , Goods_PayloadInfo, % ROUND(simExpectedPayload,2) . " / " . simPayload . "lbs (" . CEIL((simExpectedPayload)*100/simPayload) . "%)"
	GuiControl, , Goods_GoodsWeight, % ROUND(goodsWeight,0)
	GuiControl, Text, Goods_OptimalGoodsText, % "Displaying " . OptimalResult.RowCount . " viable goods"
	LV_ShowTable(OptimalResult, "Goods_TradesLV")
	GoSub Goods_CheckHangar
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

Goods_CheckHangar:
{
	Gui, Main:Default
	 ;Plane := {id: -1, name: "unknown", fuel: -1, maxFuel: -1, payload: -1, pax: -1, cruiseSpeed: -1, location: "unknown", onboardCargo: 0}
	qPlaneID := Plane.id
	CheckHangarQuery = 
	(
		SELECT 
			hangar.id AS ID,
			hangar.Location AS Location,
			hangar.currentFuel AS Fuel,
			IFNULL(onboardCargo.totalCargo,0) AS [Onboard Cargo (lbs)]
		FROM hangar 
		LEFT JOIN (
			SELECT planeid, SUM(totalweight) AS totalCargo FROM cargo GROUP BY planeid ) AS onboardCargo ON hangar.id = onboardCargo.planeid 
		WHERE ID=%qPlaneID%
		ORDER BY ID 
		LIMIT 1
	)
	If !(CheckHangarResult := SQLiteGetTable(DB, CheckHangarQuery)) {
		return
	}
	CheckHangarResult.GetRow(1, CheckHangarRow)
	If (Plane.id != CheckHangarRow[1] || Plane.location != CheckHangarRow[2] || Plane.fuel != CheckHangarRow[3] || Plane.onboardCargo != CheckHangarRow[4]) {
		GuiControl, Text, Goods_WarningText, Change detected with chosen plane! Refresh the Hangar.
	}
	return
}

Goods_ManageOptions:
{
	Gui, Main:Default
	GuiControlGet, Goods_ManageOptions
	If (Goods_ManageOptions) {
		MsgBox, 64, Auto-Manage Options, When enabled, this feature automatically assumes if the User will be flying, or AI (based on Pilot location).`n`nIt will automatically adjust settings and filters for common optimizations.`n`nUncheck this feature to stop NeoFly Tools from adjusting filters on its own.
	}
	return
}

; == Summary Window Subroutines ==
Summary_Show:
{
	GoSub Goods_CheckHangar
	Gui, Main:Default
	GuiControlGet, Goods_WarningText
	GuiControlGet, Goods_MissionInfo
	GuiControlGet, Goods_PlaneInfo
	GuiControlGet, Goods_FuelInfo
	GuiControlGet, Goods_PayloadInfo
	GuiControlGet, Goods_DepartureICAO
	; Get information at time of summary creation, so that changes in the Main GUI don't change values this portion will use.
	SummaryData := {planeID: Plane.id, departureICAO: Goods_DepartureICAO, goodsCount: 0, goodsList: []}
	; Change the GUI contents
	Gui, Summary:Default
	GuiControl, Enable, Summary_Buy
	GuiControl, Text, Summary_PayloadInfo, % Goods_PayloadInfo
	GuiControl, Text, Summary_MissionInfo, % Goods_MissionInfo
	GuiControl, Text, Summary_PlaneInfo, % Goods_PlaneInfo
	GuiControl, Text, Summary_FuelInfo, % Goods_FuelInfo
	GuiControl, Text, Summary_WarningText, % Goods_WarningText
	Gui, ListView, Summary_ToBuyLV
	LV_Delete()
	; Populate list of goods
	Gui, Main:Default
	Gui, ListView, Goods_TradesLV
	Loop % LV_GetCount() {
		Gui, Main:Default
		Gui, ListView, Goods_TradesLV
		LV_GetText(lvGood, A_Index, 1)
		LV_GetText(lvQty, A_Index, 10)
		LV_GetText(lvID, A_Index, 14)
		SummaryData.goodsList[A_Index,"id"] := lvID
		SummaryData.goodsList[A_Index,"quantity"] := lvQty
		SummaryData.goodsCount := A_Index
		Gui, Summary:Default
		Gui, ListView, Summary_ToBuyLV
		LV_Add("", lvGood, lvQty)
	}
	Gui, Summary:Default
	Gui, ListView, Summary_ToBuyLV
	LV_ModifyCol(1, "AutoHdr") ; Auto-size columns
	LV_ModifyCol(2, "AutoHdr")
	Gui, Main:Default
	; Get the position to show the Summary, either on NeoFly or on the Tools.
	WinGet, nfState, MinMax, ahk_exe NeoFly.exe
	If (nfState=1 || nfState=0) { ; 1=maximized, 0=shown but not maximized
		WinGetPos, nfX, nfY, nfW, nfH, ahk_exe NeoFly.exe
		summaryX := "x" . nfX + nfW/2
		summaryY := "y" . nfY + nfH/4
	} else {
		summaryX := ""
		summaryY := ""
	}
	Gui, Summary:Show, %summaryX% %summaryY% w300, Optimizer Summary
	return
}

Summary_Buy:
{
	Gui, Summary:Default
	Gui, -AlwaysOnTop ; Otherwise the confirmation msgbox will be hidden
	Gui, Main:Default
	GuiControlGet, Settings_GoodsDateFormat
	; Get the goods information required for database changes
	If (SummaryData.goodsCount<1) {
		return
	}
	GoodsSelectQuery := ""
	Loop % SummaryData.goodsCount {
		qQty := SummaryData.goodsList[A_Index,"quantity"]
		If (qQty<=0) { ; It was a viable good but we didn't buy any
			Continue ; Skip this loop
		}
		qID := SummaryData.goodsList[A_Index,"id"]
		qPlaneID := SummaryData.planeID
		qRefreshDateField := SQLiteGenerateDateConversion(Settings_GoodsDateFormat, "refreshdate")
		If (A_Index>1) {
		GoodsSelectQuery := GoodsSelectQuery . "`nUNION ALL`n"
		}
		GoodsSelectQueryNext =
		(
			SELECT id, %qPlaneID% AS planeid, name, type, unitprice AS buyprice, %qQty% AS quantity, location AS locationbuy, REPLACE(unitweight, ',', '.')*%qQty% AS totalweight, unitweight, 'a' AS expirationdate, ttl
			FROM goodsMarket
			WHERE id = %qID%			
		)
		GoodsSelectQuery := GoodsSelectQuery . GoodsSelectQueryNext
	}
	If !(GoodsSelectResult := SQLiteGetTable(DB, GoodsSelectQuery)) {
		return
	}
	; Determine expiration dates
	RegRead, dateFormat, HKEY_CURRENT_USER\Control Panel\International, sShortDate
	RegRead, timeFormat, HKEY_CURRENT_USER\Control Panel\International, sTimeFormat
	timestampFormat := dateFormat . " " . timeFormat
	timestampFormat24Force := dateFormat . " " . "HH:mm:ss"
	totalCost := 0
	Loop % GoodsSelectResult.RowCount {
		GoodsSelectResult.Next(GoodsSelectRow)
		goodExpiration := A_Now
		EnvAdd, goodExpiration, GoodsSelectRow[11], Hours
		FormatTime, goodExpiration, %goodExpiration%, %timestampFormat%
		GoodsSelectRow[10] := goodExpiration
		totalCost := totalCost + GoodsSelectRow[5]*GoodsSelectRow[6]
	}
	GoodsSelectResult.Reset()
	; Confirm to the user
	MsgBox, 36, Confirm Goods Purchase, % "Are you sure you want to purchase these goods?`n`nTotal cost will be:`t`t" . prettyNumbers(totalCost, true) . " `n`nNOTE: Currently this script cannot directly edit your bank account, so instead it will add a loan (with 0 interest) of this amount for you to pay later."
	IfMsgBox Yes
	{
		qPilotID := Pilot.id
		; Open DB with write privileges
		DB.CloseDB()
		GuiControlGet, Settings_DBPath
		If (!DB.OpenDB(Settings_DBPath, "W", false)) {
			MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
			return
		}
		; Commit each good
		Loop % GoodsSelectResult.RowCount {
			GoodsSelectResult.Next(GoodsSelectRow)
			lvGMID := GoodsSelectRow[1]
			lvPlaneID := GoodsSelectRow[2]
			lvName := GoodsSelectRow[3]
			lvType := GoodsSelectRow[4]
			lvBuyPrice := GoodsSelectRow[5]
			lvQuantity := GoodsSelectRow[6]
			lvLocationBuy := GoodsSelectRow[7]
			lvTotalWeight := GoodsSelectRow[8]
			lvUnitWeight := GoodsSelectRow[9]
			lvExpirationDate := GoodsSelectRow[10]
			lvCargoID := "(SELECT IFNULL(id,0) FROM cargo ORDER BY id DESC LIMIT 1)+1"
			lvLoanID := "(SELECT IFNULL(id,0) FROM loans ORDER BY id DESC LIMIT 1)+1"
			FormatTime, lvStartDate, , %timestampFormat24Force%
			lvDuration := FLOOR(lineCost/10000)
			Gui, Main:Default
			CargoBuyQuery =
			(
				INSERT INTO cargo (id, planeid, name, type, buyprice, quantity, locationbuy, totalweight, unitweight, expirationdate)
				VALUES (%lvCargoID%, %lvPlaneID%, '%lvName%', %lvType%, %lvBuyPrice%, %lvQuantity%, '%lvLocationBuy%', CAST(%lvTotalWeight% AS INT), '%lvUnitWeight%', '%lvExpirationDate%');
				
				UPDATE goodsMarket SET quantity = quantity - %lvQuantity% WHERE id = %lvGMID%;			
			)
			;UPDATE career SET cash = cash - %lineCost% WHERE id = %qPilotID%;
			If (!DB.Exec(CargoBuyQuery)) {
				MsgBox, 20, SQLite Error: SQLiteGetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`n`nEnsure the database is connected in the settings tab, and that the SQL query is valid`n`nDo you want to copy the query to the clipboard?"
				IfMsgBox Yes
				{
					clipboard := CargoBuyQuery
				}
			}
		}
		; Temporary work-around: make a loan for the same amount of the goods we basically just cheated in.
		LoanOffsetQuery = 
		(
			INSERT INTO loans (id, ownerId, amount, interestRate, startDate, duration, statusId, billingInterval)
			VALUES (%lvLoanID%, %qPilotID%, %totalCost%, 0, '%lvStartDate%', %lvDuration%, 1, 30)
		)
		If (!DB.Exec(LoanOffsetQuery)) {
			MsgBox, 20, SQLite Error: SQLiteGetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`n`nEnsure the database is connected in the settings tab, and that the SQL query is valid`n`nDo you want to copy the query to the clipboard?"
			IfMsgBox Yes
			{
				clipboard := LoanOffsetQuery
			}
		}
		; Close the DB and re-open read-only.
		DB.CloseDB()
		If (!DB.OpenDB(Settings_DBPath, "R", false)) {
			MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
			return
		}
		Gui, Summary:Default
		Gui, ListView, Summary_ToBuyLV
		LV_Delete()
		GuiControl, Disable, Summary_Buy
	}
	Gui, Summary:Default
	Gui, +AlwaysOnTop
	return
}

SummaryGuiClose:
{
	Gui, Summary:Hide
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
	HotKey, %autoMarketStopHotkey%, Auto_Unload, On
	ToolTip % "Press {" . autoMarketHotkey . "} to begin the entries"
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
	autoEntryViable := true ; Set flag if we made it to here so that Auto Entry knows we're good to go again.
	return
}

Auto_AutoEntry:
{
	HotKey, %autoMarketHotkey%, Auto_AutoEntryBegin, On
	HotKey, %autoMarketStopHotkey%, Auto_Unload, On
	ToolTip % "Press {" . autoMarketHotkey . "} to begin the Auto Entry"
	return
}

Auto_AutoEntryBegin:
{
	Gui, Main:Default
	GuiControlGet, Auto_Delay
	SetTimer, Auto_Entry, %Auto_Delay%
	return
}

Auto_Unload:
{
	Gui, Main:Default
	SB_SetText("Turning off Auto-Market hotkey")
	HotKey, %autoMarketHotkey%, Off
	HotKey, %autoMarketStopHotkey%, Off
	SetTimer, Auto_Entry, Delete
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
	GuiControlGet, Market_FilterICAO
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
			AND gm.location LIKE '`%%Market_FilterICAO%`%'
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

AircraftMarket_Compare:
{
	SB_SetText("Comparing plane models...")
	qPilotWeight := Pilot.weight
	AircraftCompareQuery = 
	(
		SELECT
			ad.aircraft AS Airplane,
			MIN(MIN(CAST(ad.cost AS INT), CAST(IFNULL(am.cost, 99999999999) AS INT))) AS [Lowest Price],
			ad.cost AS [Base Cost],
			ad.Qualification AS Qualification,
			ad.CruiseSpeedktas AS [Cruise Speed (kts)],
			ad.rangenm AS [Range(nm)],
			ad.FuelCaplbs AS [Max Fuel(lbs)],
			ad.MaxPayloadlbs AS [Max Payload],
			CAST(ad.MaxPayloadlbs - (ad.FuelCaplbs*%fuelPercentForAircraftMarketPayload%) - %qPilotWeight% AS INT) AS [Effective Payload],
			ad.Pax AS [Pax],
			CAST(MIN(MIN(CAST(ad.cost AS INT), CAST(IFNULL(am.cost, 99999999999) AS INT)))/ad.rangenm AS INT) AS [Price/Range],
			CAST(MIN(MIN(CAST(ad.cost AS INT), CAST(IFNULL(am.cost, 99999999999) AS INT)))/ad.MaxPayloadlbs AS INT) AS [Price/Payload],
			CAST(MIN(MIN(CAST(ad.cost AS INT), CAST(IFNULL(am.cost, 99999999999) AS INT)))/(ad.MaxPayloadlbs - (ad.FuelCaplbs*%fuelPercentForAircraftMarketPayload%) - %qPilotWeight%) AS INT) AS [Price/Effective Payload],
			CAST(MIN(MIN(CAST(ad.cost AS INT), CAST(IFNULL(am.cost, 99999999999) AS INT)))/ad.Pax AS INT) AS [Price/Pax],
			COUNT(am.aircraft) AS [Num For Sale]
		FROM aircraftData AS ad
		LEFT JOIN aircraftMarket AS am ON ad.Aircraft = am.Aircraft
		GROUP BY Airplane
		ORDER BY Airplane ASC
		
	)
	If !(AircraftCompareResult := SQLiteGetTable(DB, AircraftCompareQuery)) {
		return
	}
	GuiControl, Text, AircraftMarket_AircraftText, % "Showing all known types of aircraft for comparison"
	LV_ShowTable(AircraftCompareResult, "AircraftMarket_LV")
	SB_SetText("Showed plane model details")
	return
}

; == Mission Generator Tab Subroutines ==
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
	GuiControlGet, Generator_lonDep ; La
	GuiControlGet, Generator_latDep ; Qa
	GuiControlGet, Generator_lonArriv ; Lb
	GuiControlGet, Generator_latArriv ; Qb
	distanceNM := ROUND(distanceFromCoord(Generator_lonDep, Generator_latDep, Generator_lonArriv, Generator_latArriv))
	heading := ROUND(headingFromCoord(Generator_lonDep, Generator_latDep, Generator_lonArriv, Generator_latArriv))
	GuiControl, Text, Generator_dist, % distanceNM
	GuiControl, Text, Generator_hdg, % heading
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
				%qXP% AS xp,
				%Generator_hdg% AS missionHeading
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
		; Lazy way of getting all the columns into variables for use in the query
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
				(SELECT id FROM missions ORDER BY id DESC LIMIT 1)+1 AS id,
				%qVar35% AS missionHeading
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
				hangar.Location,
				hangar.tailNumber AS Tail
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
					postMessage := MonitorHangarRow[2] . " " . MonitorHangarRow[5] " (#" . MonitorHangarRow[1] . ") is now " . MonitorHangarRow[3] . " at " . MonitorHangarRow[4]
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
			ROUND(24.0*60.0*(JULIANDAY(%qDateStart%) + (1.0*rj.distance/rj.speed/24.0) - JULIANDAY('now', 'localtime')), 2) AS [Est. Time Remaining (mins)],
			h.tailNumber AS Tail
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
						postMessage := MonitorHiredRow[6] . " should be at " . MonitorHiredRow[5] . " with the " . MonitorHiredRow[2] . " " . MonitorHiredRow[12] " (#" . MonitorHiredRow[1] . ")"
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

; == Company Manager Tab Subroutines == 
Company_CleanLoans:
{
	
	Gui, Main:Default
	MsgBox, 36, Confirm Loan Wipe, Are you sure you want to do this?`n`nThis will wipe the Loans and LoanPayments tables of all records of any loans which have a "paid" status for this pilot.`n`nThis information will be non-recoverable.`n`nRecommend backing up your database first.
	IfMsgBox No
	{
		return
	}
	SB_SetText("Cleaning up loans...")
	qOwnerId := Pilot.id
	CleanLoansQuery = 
	(
		DELETE FROM loanpayments WHERE loanId IN (
			SELECT id FROM loans WHERE ownerID = %qOwnerID% AND statusID = 2 );
			
		DELETE FROM loans WHERE ownerID = %qOwnerID% AND statusID = 2;
	)
	DB.CloseDB()
	GuiControlGet, Settings_DBPath
	If (!DB.OpenDB(Settings_DBPath, "W", false)) {
		MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		return
	}
	If (!DB.Exec(CleanLoansQuery)) {
		MsgBox, 20, SQLite Error: SQLiteGetTable, % "Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode . "`n`nEnsure the database is connected in the settings tab, and that the SQL query is valid`n`nDo you want to copy the query to the clipboard?"
		IfMsgBox Yes
		{
			clipboard := CleanLoansQuery
		}
		return
	}
	
	; Re-open read only
	DB.CloseDB()
	If (!DB.OpenDB(Settings_DBPath, "R", false)) {
		MsgBox, 16, SQLite Error, % "Could not connect to database.`n`nMsg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode
		return
	}
	SB_SetText("Loans cleaned")
	return
}

Company_Finances:
{
	SB_SetText("Displaying pilot financials...")
	Gui, Main:Default
	GuiControlGet, Company_FinancesPeriod
	GuiControlGet, Settings_MissionDateFormat
	Switch Company_FinancesPeriod
	{
		Case "24 Hours":
			qDateMin := "DATETIME('now','localtime','-1 days')"
			qDateMax := "DATETIME('now','localtime','+1 days')"
		Case "7 Days":
			qDateMin := "DATETIME('now','localtime','-7 days')"
			qDateMax := "DATETIME('now','localtime','+1 days')"
		Case "30 Days":
			qDateMin := "DATETIME('now','localtime','-30 days')"
			qDateMax := "DATETIME('now','localtime','+1 days')"
		Case "All Time", Default:
			qDateMin := "DATETIME('now','localtime','-100 years')"
			qDateMax := "DATETIME('now','localtime','+1 days')"
	}
	qBalancesDate := SQLiteGenerateDateConversion(Settings_MissionDateFormat, "date")
	BalancesSelectQuery = 
	(
		SELECT date AS [Transaction Date], description AS Description, incomes AS Income, expenses AS Expenses, '' AS ''
		FROM balances
		WHERE owner = (SELECT pilotID FROM currentPilot LIMIT 1)
		AND [Transaction Date] >= %qDateMin%
		AND [Transaction Date] <= %qDateMax%
		ORDER BY [Transaction Date] DESC
	)
	clipboard := BalancesSelectQuery
	If !(BalancesSelectResult := SQLiteGetTable(DB, BalancesSelectQuery)) {
		return
	}
	LV_ShowTable(BalancesSelectResult, "Company_FinancesLV", false)
	BalancesSelectResult.Reset()
	; Find the totals
	expensesTotal := 0
	incomeTotal := 0
	fuelTotal := 0
	airportFeesTotal := 0
	playerMissionTotal := 0
	aiMissionTotal := 0
	insuranceTotal := 0
	movingTotal := 0
	loanTakeTotal := 0
	loanPayTotal := 0
	goodsBuyTotal := 0
	goodsSellTotal := 0
	dispWageTotal := 0
	fboRentTotal := 0
	planePurchaseTotal := 0
	crewHiringTotal := 0
	Loop % BalancesSelectResult.RowCount {
		BalancesSelectResult.Next(BalancesSelectRow)
		netLineAmount := BalancesSelectRow[3] - BalancesSelectRow[4]
		incomeTotal := incomeTotal + BalancesSelectRow[3]
		expensesTotal := expensesTotal - BalancesSelectRow[4]
		If (InStr(BalancesSelectRow[2], "Fuel added")) {
			fuelTotal += %netLineAmount%
		} else If (InStr(BalancesSelectRow[2], "Airport fees")) {
			airportFeesTotal += %netLineAmount%
		} else If (InStr(BalancesSelectRow[2], "Payment for mission:")) {
			playerMissionTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Payment for")) {
			aiMissionTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Insurance cost")) {
			insuranceTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Moving")) {
			movingTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "New Loan")) {
			loanTakeTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Payment on")) {
			loanPayTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Buy")) {
			goodsBuyTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Sell")) {
			goodsSellTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Wage")) {
			dispWageTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Fbo rent")) {
			fboRentTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Plane purchase")) {
			planePurchaseTotal += %netLineAmount%
		} else if (InStr(BalancesSelectRow[2], "Hiring")) {
			crewHiringTotal += %netLineAmount%
		}
	}
	Gui, ListView, Company_FinancesLV
	LV_Insert(1, "", "-------", "-------")
	LV_Insert(1, "", Company_FinancesPeriod, "Net:", prettyNumbers(incomeTotal+expensesTotal, true), "")
	LV_Insert(1, "", Company_FinancesPeriod, "Totals:", prettyNumbers(incomeTotal, true), prettyNumbers(-expensesTotal, true))
	LV_ModifyCol(3, "AutoHdr")
	LV_ModifyCol(4, "AutoHdr")
	GuiControl, +ReDraw, Company_FinancesLV
	SB_SetText("Financials displayed")
	return
}

; == Flight Tools Tab Subroutines == 
Flight_CalculateDescent:
{
	GuiControlGet, Flight_AirportICAO
	GuiControlGet, Flight_Speed
	GuiControlGet, Flight_GlideSlope
	GuiControlGet, Flight_CurrentAltitude
	AirportAltitudeQuery = 
	(
		SELECT altitude FROM airport WHERE ident = '%Flight_AirportICAO%' LIMIT 1
	)
	If !(AirportAltitudeResult := SQLiteGetTable(DB, AirportAltitudeQuery)) {
		return
	}
	If !(AirportAltitudeResult.RowCount) {
		MsgBox, No airport found for that ICAO.
		return
	}
	AirportAltitudeResult.GetRow(1, AirportAltitudeRow)
	GuiControl, Text, Flight_AirportAlt, % AirportAltitudeRow[1]
	GuiControl, Text, Flight_DescentDistance, % ROUND((Flight_CurrentAltitude-AirportAltitudeRow[1])/Tan(dtr(Flight_GlideSlope))/6076.12,1)
	GuiControl, Text, Flight_DescentRate, % CEIL(100.0*Flight_Speed/60.0*Flight_GlideSlope/50)*50
	return
}

Flight_StopwatchStart:
{
	Gui, Main:Default
	GuiControl, Disable, Flight_StopwatchStart
	GuiControl, Enable, Flight_StopwatchStop
	GuiControl, Text, Flight_StopwatchDisplay, 0:00:00
	TimerStarted := A_TickCount
	SetTimer, Flight_StopwatchTick, 1000
	return
}

Flight_StopwatchStop:
{
	Gui, Main:Default
	GuiControl, Enable, Flight_StopwatchStart
	GuiControl, Disable, Flight_StopwatchStop
	SetTimer, Flight_StopwatchTick, Off
	return
}

Flight_StopwatchTick:
{
	Gui, Main:Default
	timeElapsed := A_YYYY
	secElapsed := ROUND((A_TickCount - TimerStarted)/1000)
	EnvAdd, timeElapsed, %secElapsed%, Seconds
	FormatTime, formattedTime, %timeElapsed%, H:mm:ss
	GuiControl, Text, Flight_StopwatchDisplay, % formattedTime
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

SQLitePreviewTable(Table) {
	global Preview_LV
	Gui, Preview:Destroy
	Gui, Preview:New
	Gui, Preview:Default
	Gui, Preview:Add, ListView, w800 h600 Grid vPreview_LV
	LV_ShowTable(Table, "Preview_LV")
	Gui, Preview:Show
	Table.Reset()
	return
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
	; Check for AM/PM, subtract 12hours if AM
	normalized =
		(
			CASE SUBSTR(%field%, -2, 1)
				WHEN 'P' THEN (
					CASE SUBSTR(%field%, 12, 2)
						WHEN '12' THEN %normalized%
						ELSE DATETIME(%normalized%, '+12 hours')
					END )
				WHEN 'A' THEN (
					CASE SUBSTR(%field%, 12, 2)
						WHEN '12' THEN DATETIME(%normalized%, '-12 hours')
						ELSE %normalized%
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
			LV_ModifyCol(A_Index, "Float")
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

GetDateFormat(dateSample) {
	return
}

; == Math functions ==
headingFromCoord(lonA, latA, lonB, latB) {
	lonA := dtr(lonA)
	latA := dtr(latA)
	lonB := dtr(lonB)
	latB := dtr(latB)
	dL := lonB - lonA
	X := cos(latB) * sin(dL)
	Y := cos(latA)*sin(latB) - sin(latA)*cos(latB)*cos(dL)
	return MOD(rtd(atan2(X,Y))+360,360)
}

distanceFromCoord(lonA, latA, lonB, latB) {
	return 0.000539957*InvVincenty(latA, lonA, latB, lonB)
}

; == Formatting functions ==
prettyNumbers(inputNumber, isCurrency = false) {
	LOCALE_USER_DEFAULT = 0x400
	ffl = 32
	VarSetCapacity(ff, ffl)
	DllCall("GetNumberFormat"
			, "UInt", LOCALE_USER_DEFAULT ; LCID Locale
			, "UInt", 0 ; DWORD dwFlags
			, "Str", inputNumber ; LPCTSTR lpValue
			, "UInt", 0 ; CONST NUMBERFMT* lpFormat
			, "Str", ff ; LPTSTR lpNumberStr
			, "Int", ffl) ; int cchNumber
	If (isCurrency) {
		RegRead, currencySymbol, HKEY_CURRENT_USER,Control Panel\International, sCurrency
		return currencySymbol . ff
	} else {
		return ff
	}
}

; NOTES RE DATE FORMATS
/*
This is just here to remind me what different date codes have been shown so far.

Mission					|		Goods		
-----------------------------------------------
2021-01-25 17:51:55			20/01/2021 20:48:15	
27/10/2020 02:38:30			03/12/2020 16:15:32			
22.11.2020 00:00:43			01.12.2020 16:37:53			
2021-01-21 17:01:29			3/02/2021 11:33:55 AM		
2021-02-19 04:38:58			2021-02-13 12:30:58 PM
2021-01-23 23:17:35			1/16/2021 11:48:30 PM
30/10/2020 06:03:34			30/11/2020 12:51:04

Assumptions:

Date format always follows HKEY_CURRENT_USER\Control Panel\International, sShortDate
Time format follows HKEY_CURRENT_USER\Control Panel\International, sTimeFormat ONLY FOR GOODS. Missions seem to always use 24hr format.

*/






