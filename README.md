# NeoFly Tools
Small collection of tools for use with the NeoFly career mode addon for MSFS 2020 (https://www.neofly.net/).
    
## Instructions:

### Installation:
1. Place all files into a single folder, anywhere you'd like. 
1. If you want to run the "NeoFly Tools.ahk" script directly, you must have AutoHotkey (https://www.autohotkey.com/download/). Alternatively, simply run the "NeoFly Tools.exe". The .exe still needs SQLite3.dll to be in the same folder. If using the .exe, you can delete the .ahk files.
1. If you want to change some of the default parameters (DB Path, etc), you can do so near the top of the NeoFly Tools.ahk file (doesn't affect the .exe).
###### Note: I do not test the .exe beyond simply making sure it runs, though I don't forsee there being issues with using the .exe as this is a relatively simple set of scripts.

### Connecting to the Database:
1. Go to the Sttings tab
1. Ensure that the Database Path is the correct path to your NeoFly "common.db" SQLite database. Normally located in C:\ProgramData\Neofly
1. Press "Connect".
1. Under "Pilot Loaded", you should see the ID and Callsign of your most recently active pilot.

### Goods Optimizer:
This tool is to help optimize your trading in NeoFly. It analyzes your Plane's weight, fuel, and payload, and determines which goods are able to be traded between your Departure (where the Plane currently is) and your Destination (as determined by the destination of your chosen mission).
1. In the Goods Optmizer tab, double-click a Plane from your Hangar. Refresh the Hangar if any changes are made to your Planes in Neofly: this tool does not automatically update any fields. Any changed information must be refreshed to be shown correctly.
1. Once a Plane is chosen, you'll see a list of NeoFly missions and a list of Trade/Transit missions. If no missions appear, make sure that you have searched for missions and the market at your departure ICAO in Neofly, and have searched markets for arrival ICAOs. Markets have a refresh interval; even if you've previously searched a market, it's possible that you need to refresh the market (search it again in NeoFly) to display it in the tool.
1. Double-clicking a mission (or trade mission) will auto-populate the Mission Weight and Arrival ICAO. It will also show you the available goods which the Departure is selling and the Arrival is buying in the Optimal Goods view. The "Buy Qty" will be shown which will maximize the profit you could make for the given Plane and Mission/Arrival combination.
1. The information near the top (Fuel and Payload) should match the values you'll need to use inside of MSFS.
###### NOTE: Some aircraft in the NeoFly database do not match the simulator's values. 

### Aircraft Market:
This tool searches the AircraftMarket table for available Planes for sale. It displays the prices and (approximate) distance to the airport selling the plane. It also estimates your ONE-WAY travel cost of paying to bring your Pilot to the airport selling the plane.
1. Go to the Aircraft Market tab.
1. Use the text field to enter the name (or part of a name) of the aircraft. The name must match (or match part of) the name of the plane as entered in the NeoFly database. For example, "Cessna" or "CJ4".
1. Press search. Results will be shown, with the Distance based on your Pilot's current position.

### Mission Generator:
This lets you generate custom missions for use in NeoFly. 
###### WARNING: All previous tools were designed to open the database read-only. This means they will not harm or modify your database. The mission generator opens the database with WRITE priviliges. Putting incorrect information here, or simply bad programming of the tool (equally if not more likely), means that your game may crash when attempting to load the mission you've added. I suggest noting down the ID (last field), so that you can find and delete it in the database if necessary. 
###### Backup your database. You can use the built-in button, or back it up yourself. I recommend both.
1. Go to the mission generator tab.
1. Backup your database.
1. Choose your Departure ICAO (must be a valid ICAO), and your Arrival (which can be an ICAO for normal missions, or any text you'd like for Tourist/Drop Zone missions).
1. Fill in the Type, Rank, Pax, Cargo, Request and Tooltip texts, reward, and experience. Put whatever text you'd like for Request (appears in the mission browser in NeoFly), and the ToolTip Text (which as far as I can tell, appears when you hover over the mission on the map).
1. Press the "Find Lat/Lon" button. This will automatically find the coordinates of the Departure and Arrival ICAOs, if they can be found in the database. Custom text for Arrival will not auto-populate, and you must enter the correctly formatted coordinates for the arrival in this case.
1. Press the "Calculate Distance" button. This will determine the distance, in nautical miles, based on your coordinates.
1. Set the reward and XP.
1. Click the "Preview" button. This will generate the misson(s) you've detailed and display the results, exactly as they would be entered into the database.
1. Confirm that the preview looks correct.
1. MAKE SURE YOU BACKED UP THAT DATABASE!
1. Double-click a row to commit it to the database. The row will be removed from view and the ID of the row will be added to the text below the list for reference.
1. Search your ICAO for the new mission in NeoFly, and try it out!

### Close/Exit:
1. Either right-click the AutoHotkey script's icon (white H on a green square background) in your taskbar and click "Exit"), or simply close the GUI window via the normal Close "X" button.

## Known Issues:
- Goods Optimizer->Mission view sometimes shows missions where there is no trades available.
- Don't use non-alphanumeric characters in text fields if you can help it. Particularly double-quotes, single quotes, percent-signs (%), etc as the SQL queries are not being sanitized. Especially on the Mission Generator this will cause the SQL query to fail. This might not get fixed as it would require a significant re-write of the SQL handling.

## Planned Updates:
- Mission Generator
  - Add Airline and Humanitarian missions. They currently crash the NeoFly client and I don't know why.
- General
  - Sanitize SQL inputs (not likely to happen)
  - INI file. Low priority since the ahk scripts make this unneccessary, but they would be necessary for the .exe to have changed defaults.
  - Better formatting for $ values, thousands separators.

## Credits:
1. 'AHK-Just-Me' for the SQLite interface for AHK: https://github.com/AHK-just-me/Class_SQLiteDB
1. 'ymg' from the AHK forums for the Vincenty Method distance calculations and script: https://autohotkey.com/board/topic/88476-vincenty-formula-for-latitude-and-longitude-calculations/
1. Whoever wrote the SQLite DLLs: https://www.sqlite.org/download.html
1. 'Sbeuh34' for the OG mission generator and the fantastic multiplayer functionality: https://github.com/sbeuh34
