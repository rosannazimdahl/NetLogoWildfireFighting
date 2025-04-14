# NetLogoWildfireFighting
**Overview**<br/>
This is a NetLogo model representing a wildfire fighting scenario of a System-of-Systems (SoS), developed in a work to analyze the SoS and its effectiveness. The outputs from the simulation are data which represents stakeholders' interests, which are extended and put together outside NetLogo to Key Performance Indicators (KPIs). The model provides tools for monitoring the fire and generate temporal reports to evaluate the fire situation. Fire suppression is handled by firefighting agents (ground crews and helicopters), which act based on predefined strategies which adapt depending on the situation.

**Installation and Requirements**<br/>
To run this model, you need: <br/>
NetLogo 6.0+ (free download)<br/> 
The following file placed in the model's directory: 
elevation.asc – GIS elevation data<br/>

**Environment**<br/>
The map and fire scenario is from an area of a large Swedish wildfire 2014, read the wildfire report here: https://www.msb.se/sv/publikationer/skogsbranden-i-vastmanland-2014--observatorsrapport/". From there is the elevation as well as the current temperature and wind speed during that particular wildfire.

**Global Variables**<br/>
The model uses global variables to track:<br/>
Forest state (initial-trees, burned-area)<br/>
Sector-specific fire stats (head-fires, heel-fires, etc.)<br/>
Damage costs (forest_value_loss, house_loss)<br/>
Time-based reporting (hourly-reports, relative-change-rate, etc.)<br/>
Agent-specific statistics (ff-water, h-hours, etc.)<br/>
Agents and Patch Variables<br/>

**The model uses these agent types:**<br/>
fires: Represent active fire edges<br/>
firefighters: Ground crews (teams of 5 people + equipment)<br/>
helicopters: Aerial fire suppression agents<br/>
ICs: Placeholder for command/control agents (not currently used)<br/>

Patch variables store local attributes:<br/>
p_elevation: From GIS raster<br/>
temperature: Patch temperature<br/>
value, houses: Asset value and building presence<br/>
updated-this-tick: Ensures fire doesn’t spread multiple times per tick<br/>

**🔄 Simulation Flow**<br/>
Setup Procedures<br/>
setup_GIS: Loads and processes elevation raster, computes slope and aspect, and applies values to patches.<br/>
setup_patches: Initializes the map (forest, water, city zones, etc.)<br/>
init_var: Resets key variables<br/>
setup_fire: Starts the fire from a given ignition point<br/>

**Fire Spread**<br/>
general_fire_spread: Basic spread to nearby patches based on heat<br/>
head_fire_spread: Enhanced spread along wind direction<br/>
ignite: Starts new fire agents if patch temperature exceeds threshold<br/>
fire_dying: Fire dies if it's old, cooled, or isolated<br/>
Each fire is categorized into head, heel, left flank, or right flank, based on its direction relative to the fire center and wind.<br/>

**Response Strategies**<br/>
Agents receive new targets and move based on one of several strategies:<br/>

largest-firesector: Concentrates all agents on the sector with the most active fires<br/>
largest-rel-change: Focuses on the sector with the fastest relative increase<br/>
protect-city: Assigns agents to areas close to urban zones<br/>
spread-agents-equally: Distributes agents evenly across all fire sectors<br/>
decentralized-decision: Helicopters target fires near water, firefighters go to nearest fire<br/>
go-around: Helicopters and firefighters move in opposite directions around the fire<br/>
Reporting and Visualization<br/>

**Design variables**<br/>
response-time - The time it takes for the SoS <br/>
agent-amount<br/>
perc-ground<br/>
Time strategy update<br/>
Strategy-choice<br/>

Every "hour" (60 ticks), the model:<br/>
- Generates a snapshot of fire counts per sector.<br/>
- Computes both numerical and relative change rates<br/>
Plots:<br/>
Number of fires in each sector<br/>
Numerical change rate<br/>
Relative change rate<br/>
Updates the minimum distance from fire to the city area<br/>


**Outputs**

**KPIs**
