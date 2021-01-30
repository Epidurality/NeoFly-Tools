# neofly_tools
Small collection of tools for use with the NeoFly career mode for MSFS 2020.

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
    
    
INSTRUCTIONS:
  Connecting to the Database:
    1) Go to the Sttings tab
    2) Ensure that the Database Path is the correct path to your NeoFly "common.db" SQLite database. Normally located in C:\ProgramData\Neofly
    3) Press "Connect".
    4) Under "Pilot Loaded", you should see the ID and Callsign of your most recently active pilot.
    
  Goods Optimizer:
    This tool is to help optimize your trading in NeoFly. It analyzes your Plane's weight, fuel, and payload, and determines which goods are able to be traded between your Departure (where the Plane currently is) and your Destination (as determined by the destination of your chosen mission).
    1) Connect to your NeoFly database via the Settings page. Ensure that a valid Pilot is found.
    2) In the Goods Optmizer tab, double-click a Plane from your Hangar. Refresh the Hangar if any changes are made to your Planes in Neofly: this tool does not automatically update any fields. Any changed information must be refreshed to be shown correctly.
    3) Once a Plane is chosen, the "Viable Missions with Markets" and "Trade Missions Available" will populate. If no missions appear, make sure that you have searched for missions and the market at your departure ICAO in Neofly, and have searched markets for arrival ICAOs.
    4) Double-clicking a mission (or trade mission) will auto-populate the Mission Weight and Arrival ICAO. It will also show you the available goods which the Departure is selling and the Arrival is buying (Suitable Market Goods). In the Optimum Trades view, quantities will be shown which will maximize the profit you could make for the given Plane and Mission/Arrival combination.
    
    Aircraft Market:
    This tool searches the AircraftMarket table for available Planes for sale. It displays the prices and (approximate) distance to the airport selling the plane. It also estimates your ONE-WAY travel cost of paying to bring your Pilot to the airport selling the plane.
    1) Ensure your database is connected.
    2) Use the text field to enter the name (or part of a name) of the aircraft. The name must match (or match part of) the name of the plane as entered in the NeoFly database. For example, "Cessna" or "CJ4".
    3) Press search. Results will be shown, with the Distance based on your Pilot's current position.
    
    Mission Generator:
    This lets you generate custom missions for use in NeoFly. WARNING: All previous tools were designed to open the database read-only. This means they will not harm or modify your database. The mission generator opens the database with WRITE priviliges. Putting incorrect information here, or simply bad programming of the tool (equally if not more likely), means that your game may crash when attempting to load the mission you've added. I suggest noting down the ID (last field), so that you can find and delete it in the database if necessary.
    1) Backup your database. You can use the built-in button, or back it up yourself. I recommend both.
    2) Choose your Departure ICAO (must be a valid ICAO), and your Arrival (which can be an ICAO for normal missions, or any text you'd like for Tourist/Emergency/Drop Zone missions).
    3) Select the mission type and rank. Put whatever text you'd like for Request (appears in the mission browser in NeoFly), and the ToolTip Text (which as far as I can tell, appears when you hover over the mission on the map).
    4) CHANGE THE EXPIRATION DATE AND/OR TIME. By default, the Expiration is set to "now" and will lead to the mission not being shown, as it will be expired.
    5) Press the "Find Lat/Lon" button. This will automatically find the coordinates of the Departure and Arrival ICAOs, if they can be found in the database. Custom text for Arrival will not auto-populate, and you must enter the correctly formatted coordinates for the arrival in this case.
    6) Press the "Calculate Distance" button. This will use the Vincenty method (thank you to 'ymg' from the AHK forums, https://autohotkey.com/board/topic/88476-vincenty-formula-for-latitude-and-longitude-calculations/) to determine the distance, in nautical miles, based on your coordinates.
    7) Set the reward and XP.
    8) Click the "Preview" button. This will generate the misson you've detailed and display the results, exactly as they would be entered into the database.
    9) Confirm that the preview looks correct, then press "Commit to Database". 
      NOTE: Changing something AFTER the preview is generated WILL NOT be reflected in the preview until you re-preview. It WILL however be committed when you press the button, regardless of what's in the preview.
    10) Search your ICAO for the new mission in NeoFly, and try it out!
