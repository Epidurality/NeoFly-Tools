# NeoFly Tools
Small collection of tools for use with the NeoFly career mode addon for MSFS 2020 (https://www.neofly.net/).

## Instructions:

### Installation:
1a. Download the Source Code zip from the latest release. Place all source files into a single folder, anywhere you'd like. These are normal AHK scripts which can be run with AutoHotkey (https://www.autohotkey.com/download/)
######
1b. Alternatively, download the binary (NeoFly Tools.exe) and the SQLite3.dll files and make sure they are in the same folder. The compiled .exe is made by simply compiling the scripts using AHK's built-in compiler. It does not require an installation of AutoHotkey, and will run on its own.
######
In either case, make sure that "sqlite.dll" is in the same directory as your *NeoFly Tools.ahk* or *NeoFly Tools.exe*

###### Note: I do not test the .exe beyond simply making sure it runs, though I don't forsee there being issues with using the .exe as this is a relatively simple set of scripts.

### Connecting to the Database:
1. Go to the Sttings tab
1. Ensure that the Database Path is the correct path to your NeoFly *common.db* SQLite database. Normally located in *C:\ProgramData\Neofly*
1. Press Connect.
1. Under "Pilot Loaded", you should see the ID and Callsign of your most recently active pilot.

### Goods Optimizer:
This tool is to help optimize your trading in NeoFly. It analyzes your Plane's weight, fuel, and payload, and determines which goods are able to be traded between your Departure (where the Plane currently is) and your Destination (as determined by the destination of your chosen mission).
1. Search the market at your Departure ICAO in NeoFly.
1. Optionally, search the Missions at your Departure ICAO in NeoFly.
1. Search a few markets of your choosing (previewing also works). Note that markets are only valid for 24 hours, after which time you will have to search/preview them again.
1. In the goods optimizer, double-click the plane you plan to use from the Hangar view. This will auto-populate your Fuel and Departure, as well as allow the Optimizer to establish your available payload. It will also automatically refresh the mission views.
1. The *NeoFly Missions* view and *Trade / Transit Missions* view will display all possibilities for trading given your current Departure ICAO (by default sorted by Income per distance, Income/nm).
    1. Additionally, *Can Buy At Arrival* is shown in each mission view, and contains a list of the purchasable goods at the **ARRIVAL** ICAO. This list is useful, as you'll come to know that some goods produce more profit than others (Phones, for instance, are highly profitable for their weight). This field will give you an idea of how profitable the next trade mission may be.
	1. Note: The NeoFly missions will be filtered based on the Payload and Pax capacity of your airplane, but are NOT filtered for your pilot rank or distance/range.
1. The Trade Profit takes into account your on-board fuel, payload capacity, etc to determine how many goods you're able to bring with you on the flight.
    1. The Optimizer does NOT take range into account for analyzing your plane's viability for the mission. Make sure you have enough fuel to go the distance!
	1. If you make changes to your fuel levels in NeoFly, refresh the Hangar!
1. Once you've found a Mission or Trade mission you like, double-click the row. This will populate the *Optimized Goods* view, which shows a breakdown of which goods you should buy and in which quantities.
    1. Buy Qty is the Optimized quantity you should be purchasing at your Departure ICAO.
###### NOTE: Some aircraft in the NeoFly database do not match the simulator's values. Either edit the database (see the NeoFly documents/discord for help on this), or manually adjust the values to suit.

### Aircraft Market:
This tool searches the AircraftMarket table for available Planes for sale. It displays the prices and (approximate) distance to the airport selling the plane. It also estimates your ONE-WAY travel cost of paying to bring your Pilot to the airport selling the plane.
1. Go to the Aircraft Market tab.
1. Use the text field to enter the name (or part of a name) of the aircraft. The name must match (or match part of) the name of the plane as entered in the NeoFly database. For example, "Cessna" or "CJ4".
1. Press search. Results will be shown, with the Distance based on your Pilot's current position.

### Mission Generator:
This lets you generate custom missions for use in NeoFly. 
###### WARNING: All previous tools were designed to open the database read-only. This means they will not harm or modify your database. The mission generator opens the database with WRITE priviliges. Putting incorrect information here, or simply bad programming of the tool (equally if not more likely), means that your game may crash when attempting to load the mission you've added. I suggest noting down the generated IDs, so that you can find and delete it in the database if necessary.
###### Backup your database. You can use the built-in button, or back it up yourself. I recommend both.
1. Go to the mission generator tab.
1. Backup your database.
1. Choose your Departure ICAO (must be a valid ICAO), and your Arrival (which can be an ICAO for normal missions, or any text you'd like for Tourist/Drop Zone missions).
1. Fill in the Type, Rank, Pax, Cargo, Request and Tooltip texts, reward, and experience. Put whatever text you'd like for Request (appears in the mission browser in NeoFly), and the ToolTip Text (which as far as I can tell, appears when you hover over the mission on the map).
1. Press the "Find Lat/Lon" button. This will automatically find the coordinates of the Departure and Arrival ICAOs, if they can be found in the database. Custom text for Arrival will not auto-populate, and you must enter the correctly formatted coordinates for the arrival in this case.
1. Press the "Calculate Distance" button. This will determine the distance, in nautical miles, based on your coordinates.
1. Click the "Preview" button. This will generate the misson(s) you've detailed and display the results, exactly as they would be entered into the database.
1. Confirm that the preview looks correct.
1. MAKE SURE YOU BACKED UP THAT DATABASE!
1. Double-click a row to commit it to the database. The row will be removed from view and the ID of the row will be added to the text below the list for reference.
1. Search your ICAO for the new mission in NeoFly, and try it out!

### Close/Exit:
1. Either right-click the AutoHotkey script's icon (white H on a green square background) in your taskbar and click "Exit"), or simply close the GUI window via the normal Close "X" button.

## Known Issues:
- Don't use non-alphanumeric characters in text fields if you can help it. Particularly double-quotes, single quotes, percent-signs (%), etc as the SQL queries are not being sanitized. Especially on the Mission Generator this will cause the SQL query to fail. This might not get fixed as it would require a significant re-write of the SQL handling.

## New Issues:
Please use the GitHub "Issues" feature to raise any bugs or problems you've come across.

## Planned Updates:
- Randomize missions further.
- Add new mission types: Airline, Humanitarian, SAR, Intercept
- Market Search (search for goods that are being sold or bought)

## Feature Requests:
Please use the GitHub "Issues" feature to request any new features or improvements. Feedback is welcomed!

## Credits:
1. 'AHK-Just-Me' for the SQLite interface for AHK: https://github.com/AHK-just-me/Class_SQLiteDB
1. 'ymg' from the AHK forums for the Vincenty Method distance calculations and script: https://autohotkey.com/board/topic/88476-vincenty-formula-for-latitude-and-longitude-calculations/
1. Whoever wrote the SQLite DLLs: https://www.sqlite.org/download.html
1. 'Sbeuh34' for the OG mission generator and the fantastic multiplayer functionality: https://github.com/sbeuh34
1. Basic wrench/tool icon made by Freepik from www.flaticon.com

## Change Log:

### v0.2.0
- Added ability to sort on any numerical column properly (number based instead of text based sort).
- Added several columns to the Aircraft Market search results for more information about the planes, including the Effective Payload stat as a more accurate representation of how much a plane will typically carry.
- Added ability to see airborne planes in the Goods Optimizer, along with seeing plane statuses.
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
