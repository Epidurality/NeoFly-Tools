# NeoFly Tools
Small collection of tools for use with the NeoFly career mod addon for MSFS 2020 (https://www.neofly.net/).

[Jump to Change Log](#change-log)

[Jump to Known Issues](#known-issues)

## Donations
If you find these tools useful, please consider donating to show your support. However, I encourage you to first donate in support of NeoFly as these tools are useless without the excellent, *unpaid* effort of its developers. Plus, perks!
- [Donate to NeoFly](https://www.neofly.net/store)
- [Support these tools](https://www.paypal.com/donate?hosted_button_id=95SBRGV8W9LN6)

## Instructions:
I've taken the time to document the procedures and nuances of the program, please take the time to read them before posting issues you're having. **Please read this ReadMe fully. It may answer a question you have, or help to diagnose a bug!** 

### Installation:
1. Download the latest release folder and make sure all files are in the same folder. They do **not** need to be with your NeoFly folder; you can leave them on the desktop or wherever, as long as all included files are kept together.
    1. If using the *Executable / Binary* version, simply run the *NeoFly Tools.exe*.
	1. If you prefer using the Script version, download the *Source* folder instead and run the *NeoFly Tools.ahk* script. Requires AutoHotkey (https://www.autohotkey.com/).
1. Configure your defaults and certain settings using the *NeoFly Tools.ini* file.
1. Requires NeoFly 2.12 (Tail Number update) or later.

### Connecting to the Database:
1. Go to the Settings tab
1. Ensure that the Database Path is the correct path to your NeoFly *common.db* SQLite database. Normally located in *C:\ProgramData\Neofly*
1. Press Connect.
1. Under "Pilot Loaded", you should see the ID and Callsign of your most recently active pilot.
1. You may choose a different Pilot from the list (double-click). This effectivly only affects the list of planes in your Hangar, as most other tables are shared in the database.
1. In the bottom half of the Settings tab, there is information about the Date Formats used for the NeoFly database.
    1. NeoFly does not use standard SQLite formats for dates, so the dates must be converted from how they appear in the database before they can be analyzed by these Tools.
	1. Depending on your locale, there may be separate date formats for the *Missions.expiry* field and the *GoodsMarket.refreshDate* field.
1. NeoFly Tools will automatically attempt to detect your Timestamp formats every time you connect to a database.
    1. If the Samples from Database view appears correct (no INVALID entries), then the time format has likely been set correctly.
    1. If none of the available formats work for you, please use the GitHub "Issues" feature with an example of your timestamp as it shows in the *DB Value* column.
	1. It's also possible that, if you have a new/empty/nearly empty database, the automatic date detection can be erroneous (for example if you had ambiguous dates, like 12-12-2012, or no dates at all).
	1. If you have problems with other functions of the Tools, please **double check your dates are being formatted correctly**.

### Goods Optimizer:
This tool is to help optimize your trading in NeoFly. It analyzes your Plane's weight, fuel, and payload, and determines which goods are able to be traded between your Departure (where the Plane currently is) and your Arrival (as determined by the destination of your chosen mission).
1. Search the market at your Departure ICAO in NeoFly.
1. Optionally, search the Missions at your Departure ICAO in NeoFly.
1. Search a few markets of your choosing (previewing also works). Note that markets are only valid for 24 hours, after which time you will have to search/preview them again.
1. In the goods optimizer, double-click the plane you want to use from the Hangar view. This will auto-populate your Fuel and Departure, as well as allow the Optimizer to establish your available payload.
1. The *NeoFly Missions* view and *Trade / Transit Missions* view will display all possibilities for trading given your current Departure ICAO.
	1. Note: The NeoFly missions will be filtered based on the Range, Payload, and Pax capabilities of your airplane, but are NOT filtered for your pilot rank.
1. The Trade Profit takes into account your on-board fuel, payload capacity, etc to determine how many goods you're able to bring with you on the flight.
    1. The Optimizer does NOT take range into account for analyzing your plane's viability for the mission. Make sure you have enough fuel to go the distance!
	1. If you make changes to your fuel levels in NeoFly, refresh the Hangar!
	1. If you select *Allow Overweight*, the Optimizer will take advantage of the fact that NeoFly does not subtract the Fuel weight from the Max Payload of Planes. You can effectively overweight any Plane by up to the current fuel weight.
	    1. Script will use whichever is lower: the maximum weight allowed by NeoFly to start the mission, or the custom overweight amount you enter in the field. All results should still be viable flights in NeoFly, even if MSFS shows you're overloaded.
	    1. Be careful if you're flying these yourself and not AI! Maximum weight limits exist for a reason.
1. Once you've found a Mission or Trade mission you like, double-click the row. This will populate the *Optimized Goods* view, which shows a breakdown of which goods you should buy and in which quantities.
    1. Buy Qty is the Optimized quantity you should be purchasing at your Departure ICAO.
	1. You can also click the Summary button near the top to pop-out a summary information window based on the information shown (which will overlay NeoFly if NeoFly is open, or overlay the main GUI otherwise).
1. *Buy it For Me* function is available in the Summary window. Pressing that button will add ALL cargo shown to your indicated aircraft, **and create a loan in the amount shown**.
    1. Note: The NeoFly GUI will not update the market, your plane's cargo, or the loans until you refresh the market / the loans.
	1. **Backup your database before the first few times you use this feature.**
###### NOTE: Some aircraft in the NeoFly database do not match the simulator's values. Either edit the database (see the NeoFly documents/discord for help on this), or manually adjust the values to suit. Without matching values, the percentages shown for Payload and Fuel will not be correct.

### Auto-Market Search:
Automatically fills in the Market ICAO box in NeoFly and presses Enter, based on the list of ICAOs you've chosen in the Auto-Market tab.
1. Enter your Center ICAO and your desired distance limit.
1. Press the *List* button. The script will find any Missions originating from the Center ICAO, and give you a list of destinations so that you may search the destination markets.
    1. Note: This of course means that your Center ICAO needs to have missions available in the database.
	1. ICAOs that already have valid markets (don't need to be searched) will not appear in the list.
1. Select the ICAO(s) you wish to search.
    1. You can Ctrl+Click or Shift+Click to multi-select entries in the table above.
1. Press *Load for Entry*.
    1. The Hotkey is only active after you've pressed Load for Entry. Active status is affirmed by a tooltip appearing by your cursor.
1. Ensure your cursor is in the ICAO edit box in the NeoFly Market tab. 
1. When you press the hotkey, it will go through each ICAO you've selected above, doing the following:
    1. Send Ctrl+A to highlight any text in the ICAO box
    1. Send the new ICAO name, corresponding to the first selected ICAO left in the list view above
    1. Send the Enter key to search the Market
    1. Remove the already-searched ICAO from the list above.
1. Press the hotkey again, and it will do the same with the next selected ICAO.
1. When the selected list is exhausted, or the user presses the *Stop Entry* button, the entry script will be disabled. Alternatively, you can use the stop Hotkey.
1. There is also an *Auto Entry* mode, where you need only press the hotkey once and the script will automatically enter remaining ICAOs without you pressing the hotkey repeatedly.
    1. Adjust the *Delay in Auto Entry* time to your liking.
    1. Note: NeoFly can accept and process the searches very quickly, however it will visually look like the markets are not being generated fast enough. By default the time is set to 1500ms (1.5s) to allow enough time for the NeoFly GUI to process the market, but this is not necessary. A delay of 500ms has worked in testing.

### Market Finder:
Displays where you can find Markets selling or buying the Good you specify. Useful for finding somewhere to sell your load of goods.
1. Enter the information about the good(s) you wish to find. The *Name* field uses a LIKE search, meaning "pho" will match with "Phone" as well as "Telephoto Lens"
	1. If you leave this blank (or the ICAO is invalid), the distance calculations will not be performed.
1. Press the search button.

### Aircraft Market:
This tool searches the AircraftMarket table for available Planes for sale. It displays the prices and (approximate) distance to the airport selling the plane. It also estimates your ONE-WAY travel cost of paying to bring your Pilot to the airport selling the plane.
1. Use the text field to enter the name (or part of a name) of the aircraft. The *Aircraft Name* field uses a LIKE search, meaning "Cub" will match with "XCub" as well as "Savage Cub"
1. Press search. Results will be shown, with the Distance based on your Pilot's current position.
1. The *Compare Models* button displays one of each model plane to allow you to compare their stats (*Aircraft Name* field is ignored for this to show all available models).
    1. Note: Lowest Price will default to the Base Cost if no planes of that type are available for sale.

### Mission Generator:
This lets you generate custom missions for use in NeoFly. 
1. **Backup your database.**
1. Go to the mission generator tab.
1. Choose your Departure ICAO (must be a valid ICAO), and your Arrival (which can be an ICAO for normal missions, or any text you'd like for Tourist/Drop Zone missions).
1. Fill in the Type, Rank, Pax, Cargo, Request and Tooltip texts, reward, and experience. Put whatever text you'd like for Request (appears in the mission browser in NeoFly), and the ToolTip Text (which as far as I can tell, appears when you hover over the mission on the map).
1. Press the "Find Lat/Lon" button. This will automatically find the coordinates of the Departure and Arrival ICAOs, if they can be found in the database. Custom text for Arrival will not auto-populate, and you must enter the correctly formatted coordinates for the arrival in this case.
1. Press the "Calculate Distance" button. This will determine the distance, in nautical miles, based on your coordinates.
1. Click the "Preview" button. This will generate the misson(s) you've detailed and display the results, exactly as they would be entered into the database.
1. Confirm that the preview looks correct.
1. Double-click a row to commit it to the database. The row will be removed from view and the ID of the row will be added to the text below the list for reference.
1. Search your ICAO for the new mission in NeoFly, and try it out!
    1. Note: use Search, not Reset, in NeoFly as Reset will overwrite the mission you just made.
1. Don't save over your backups until you're sure that NeoFly has accepted your new mission(s).

### Monitor Hangar:
When enabled, will alert you via Discord Webhook when a plane returns to the Hangar and is available for use.
1. Enable webhooks on Discord (other services are untested, but will work if they follow Discord's POST Json data format).
    1. If you're not familiar with Discord Webhooks, google is your friend. All you need is the Webhook URL provided by your channel integration.
1. Enter the Webhook URL into the URL field.
    1. The default can be changed in the INI file.
1. Press the Enable button.
1. Your currently available (status=0) Planes will show up in the Hangar view. Any active Hired Jobs (from the rentJobs table in the database) will show up in the Hired Jobs view.
1. Once enabled, the script will check for changes to the Hangar view at the Refresh Interval. If a Plane gets added to the view, that means it must have been recently made available for use. The script will then send a message via Webhook saying which Plane(s) became available.
    1. If you check the Offline Mode box, the script will not rely on the Hangar view to change. It will monitor the Hired Jobs, and send the notification when the job is expected to have expired. This means that NeoFly does not have to be open/running for the notifications to be sent. It's also not that accurate, and might be early or late.
	1. Note: if NeoFly IS running, and you are in Offline mode, it's possible to miss the notification (since the Hired Job will be removed from the view, and unable to be checked).
1. Messages will only be sent once per status change.

### Company Manager:
Collection of scripts to augment the company management in NeoFly.
1. **Backup your database before the first few times you use some of these features.**
1. Loan Cleaner
    1. Removes records of loans that have already been paid.
1. Finance Viewer
	1. Lists and summarizes your finances based on a given range.

### Close/Exit:
1. Either right-click the script's icon in your taskbar and click "Exit", or simply close the GUI window via the normal Close "X" button.
1. You do not need to Disconnect from the database via the GUI; this will be done automatically when you close the GUI/script normally.

## Credits:
1. 'AHK-Just-Me' for the SQLite interface for AHK: https://github.com/AHK-just-me/Class_SQLiteDB
1. 'ymg' from the AHK forums for the Vincenty Method distance calculations and script: https://autohotkey.com/board/topic/88476-vincenty-formula-for-latitude-and-longitude-calculations/
1. Whoever wrote the SQLite DLLs: https://www.sqlite.org/download.html
1. 'Sbeuh34' for the OG mission generator and the multiplayer functionality: https://github.com/sbeuh34
1. Basic wrench/tool icon made by Freepik from www.flaticon.com

## Known Issues:
- Localization of dates and number formats will continue to be an issue until all localization differences are accounted for.
    - Auto-Timestamp chooser when connecting to a database only looks at the newest few entries in the database. Some databases have multiple timestamp formats for the same field depending on NeoFly version used to create them. Manually check your DB if you still have issues.
    - Auto-Timestamp chooser basically doesn't work with brand-new databases, since the Markets are not populated yet so there are no dates to check.
- Don't use non-alphanumeric characters in text fields if you can help it. Particularly double-quotes, single quotes, percent-signs (%), etc as the SQL queries are not being sanitized. Especially on the Mission Generator this will cause the SQL query to fail. This might not get fixed as it would require a significant re-write of the SQL handling.
- Can't make numbers prettier in ListViews or else they become unsortable.

## New Issues:
Please use the GitHub "Issues" feature to raise any bugs or problems you've come across.

## Planned Updates:
- Soon:
	- Add mission info to Auto-Market to allow sorting by specific types of destination missions.
	- Add heading to Trade Mission routes.
- Not as soon:
    - Randomize mission generation further.
    - Add new mission types: Airline, Humanitarian, SAR, Intercept
	- Remove some of the unneccessary columns in various views; they're useful for debugging these early versions, but useless for most people.
	
## Feature Requests:
Please use the GitHub "Issues" feature to request any new features or improvements. Feedback is welcomed!

## Change Log:

### v0.6.0
- Added ability to Auto-Buy goods from Optimizer Summary.
- Greatly decreased the load times of Optimizer by removing some redundant time checks.
- Added ^Auto Lenth* feature which does an approximation based on Payload of the aircraft for the length of runway required.
- Added a "Clean Up Loans" function in the new *Company Manager* tab.
- Fixed Mission Generation failure due to new database column for Heading in missions
- Added Range as a filter to Optimizer.
- Added the *Auto Range* checkbox, which will use the range of your aircraft.
- Moved and improved Backup function. Now resides with Settings, and appends a timestamp to allow multiple backups.
- Changed how Overweight operates (no more checkbox)
- Added *Auto-Manage Options* to Optimizer. Defaults to max $$ (AI) or reasonable options for user pilot.
- Added a "make numbers readable" function so that displaying large values becomes prettier. No, it won't be correct in all locales necessarily, but it's better.

### v0.5.0
- Added an automatic timestamp format picker and check.
- Added "Offline Mode" to *Hangar Monitor*
- Fixed bugs with the *Auto-Market* thinking the list was empty
- Added a simple check to see if the Market you've chosen in the Goods Optimizer may expire before you can reach it.
- Added a Splash Screen on startup since startup with AutoConnect enabled now takes a moment.
- Added a "go back to centerICAO" feature to the Auto-Market; will now re-enter your Center ICAO on the last hotkey press.
- Renamed a whole bunch of variables to avoid cross-talk in the global scope now that there are timers and asynchronous code execution. Should avoid unexpected behaviour bugs.
- Added functionality for multiple GUIs in the future.
- Added a "No Reformatting" option to the timestamp formats. For those few with SQLite compatible dates in the DB, this will increase performance.
- Filtered Optimizer to exclude goods that they no longer have any of (if you've previously cleaned them out, for instance)
- Fixed bug with Auto-Market where ICAOs that already have markets were being displayed in some Locales
- Added existing goods to plane weight calculation and sim payload numbers. Useful if you've already loaded some stuff and lose track, or if you're taking off with goods leftover etc.
- Added the new TailNumber feature to views and some information text. This means that NeoFly 2.12+ is required so that hangar.tailNumber is populated in the database.
- Reconfigured loading of Goods Optimizer list views slightly - should improve performance.
- Added Right-Click menu to Optimizer mission views for some QoL quick functions.
- Added a warning when the user refreshes missions/optimal goods when the plane selected has changed critical parameters (fuel, onboard cargo, location, availability).
- Added more descriptive text for when results are unavailable in Goods Optimizer.
- Added "Allow Overweight" in Optimizer. This lets you max out NeoFly's Goods+Mission weight, taking advantage of the fact that it doesn't subtract Fuel Weight from the Max Payload of the plane.
- Limited the Auto-Timestamp check to 300 rows to ensure NeoFly's current/newest timestamps are what gets formatted correctly.
- Increased performance of Timestamp list view, queries. Leads to lower "load times".
- Added a Summary GUI to the Optimizer (click the *Summary* button at the top of the Optimizer). Useful for overlaying on NeoFly.
- Updated text in Optimizer more intelligently.
- Added "Tower" to the list of Arrival filters in the Optimizer.
- Added a *Compare Models* button to the Aircraft Market tab which displays one of each model plane to allow you to compare their stats. Also provides the lowest price found in the AircraftMarket for each plane, which you can then search specifically to locate.
- Added a more automatic *Auto-Market* function.
- Corrected wrong handling of 12AM timestamps.

### v0.4.0
- Added filters for NeoFly missions list in Optimizer.
- Added ability to hide the Trade/Transit missions portions of the Optimizer (helps with slower speed of queries)
- Added an extra layer to the Timestamp validation (there's now a small bit of timestamp math so that you can confirm things are working correctly).
- Changed from displaying the raw dates to displaying how long is left in the items's lifespan (*Time Left (hrs)* columns). This should help avoid choosing markets that are about to reset, leaving you with goods you can't sell where you expected to.
- Slightly increased Optimizer search speed by pre-checking for a valid market at the Departure, then ignoring it as a requirement in the searches - avoids an extra convoluted date reformat.
- Added INI file to streamline into "one release" instead of script and binary versions. Source/script version is of course still available.
- Handled blank XP/Reward scenario in Mission Generator.
- Removed "net zero" goods from Goods Optimizer. Will no longer show results where Profit/u is 0 or negative.
- Added the *Hanger Monitor* which will alert you via Discord Webhook when a Plane returns to the Hangar. Also shows you the ETA of Hired missions.
- GUI tweaks

### v0.3.0
- Added a *Disconnect* button to the Settings page. Note: this isn't necessary in any way. Closing the program gracefully will call CloseDB(), and the DB is only kept open in ReadOnly anyways.
- Added a rudimentary *Market Finder* to search for specific goods being bought or sold. Useful if you have a load of something you need to get rid of.
- Added more descriptive text on screen/message boxes for handling database connection and query issues.
- Changed the StatusBar texts to be more standard and lets you know if the script is 'doing something' (Doing something...  -->  Something done).
- Added filters for cargo type in Optimizer.
- Fixed date formats for most localizations, I think. Don't look at the SQL queries that are produced, it's embarrassing. This also causes the queries to be very slow. Learn to live with it.
- Added a "Date Format" drop-down in the Settings tab.
- Added a whole date-format-checking thing in the Settings tab. See the Instructions on how this works.
- Changed the default Expiration in the Mission Generator. It now uses the last-generated mission in your database as the default date text when you Connect, to avoid localization conversion.
- Added the Auto-Market search feature. Clunky but it works fine.
- Added distance calculation to the Market Finder
- Gui tweaks

### v0.2.1
- Fixed localization bug with *dd.mm.yyyy* formatting
- Fixed bug where missions weren't showing up due to incorrect Pax counts

### v0.2.0
- Added ability to sort on any numerical column properly (number based instead of text based sort).
- Added several columns to the Aircraft Market search results for more information about the planes, including the Effective Payload stat as a more accurate representation of how much a plane will typically carry.
- Added ability to see airborne planes in the Goods Optimizer, along with seeing plane statuses. Use the Show All checkbox. Does not show Status=5 planes (no longer in your Hangar, crashed, sold, etc)
- Added ability to choose a Departure ICAO after choosing a plane. Changing the Departure ICAO, then clicking Refresh Missions will allow you to see markets as if the plane as shown was at that ICAO. Useful for planning ahead while in-flight when combined with the Show All hangar feature.
- Rounded down the % fuel in the Goods Optimizer to ensure that, if using these % values to adjust the Sim values, your plane will always have enough payload to satisfy NeoFly's requirements. This is due to rounding errors and lack of precision in the % sliders in the Sim.
- Improved Mission Generator ID generation so that it could be used as a pseudo-multiplayer (IDs are now calculated at database insertion instead of before; this should avoid ID conflicts when using separate databases to generate the same missions). Changed how generated IDs are displayed to the user.
- Added custom icon complete with NeoFly colors.
- Customized tray icon. Added ability to show/hide the GUI window without fully closing the program - access by right-clicking the tray icon.
- Added ability to completely remove the tray icon via a flag in the script. Useful if you don't like notification area clutter, but will remove above functionalities.
- Fixed bug where missions would not show up in the Optimizer if the Pax# was the same as the plane's max pax (< instead of <=).
- Fixed bug where totals in the Mission views of Optimizer would show incorrect total profits caused by incorrect sorting of the goods.
- Fixed bug where missions would still be shown even if the Departure ICAO did not have an up-to-date market (there is now a pre-check for the market)
- Fixed bug where code was using UTC when NeoFly database uses local time - caused markets not to appear for some hours depending on time difference.
- Added ability to filter-out Illicit Cargo in the goods optimizer.
- Added a list of goods which will be available for purchase at the Arrival ICAO in the Goods Optimizer Mission views - helps you be more informed about what your next trade mission will likely be.
- Minor UI tweaks.
- Probably other stuff I missed.

### v0.1.1
- Fixed a localization issue (Goods Market in NeoFly tables has RefreshDate in strange formats). This may still be an issue depending on how your dates are formatted. The work-around was dirty.
- Minor UI tweaks, organization, text, etc.

### v0.1.0
- Initial public release.
