# Netlogo Model for Firefighting
**Overview**<br/>
This is a NetLogo model representing a wildfire fighting scenario of a System-of-Systems (SoS), developed in a work to analyze the SoS and its effectiveness. The outputs from the simulation are data which are extended outside NetLogo to Key Performance Indicators (KPIs) which represents stakeholders' interests. The model provides tools for monitoring the fire and generate temporal reports to evaluate the fire situation. Fire suppression is handled by firefighting agents (ground crews and helicopters), which act based on predefined strategies which adapt depending on the situation.

**Installation and Requirements**<br/>
To run this model, you need: <br/>
NetLogo 6.0+ (free download)<br/> 
The following file placed in the model's directory: 
elevation.asc – GIS elevation data<br/>

**Environment**<br/>
The map and fire scenario is from an area of a large Swedish wildfire 2014 (report: https://www.msb.se/sv/publikationer/skogsbranden-i-vastmanland-2014--observatorsrapport/). From that scenario, the elevation as well as the current temperature and wind speed are extracted. The patches have different colors depending on the elevation, being green (forest), blue (water), and black (other non-burnable areas).<br/>
In the model there are also two cities placed (orange squares) to represent residential areas to influence the firefighters' tactics.

**Simulation Flow**<br/>
- Click "setup": Loads and processes elevation raster, computes slope and aspect, applies values to patches, and color them accordingly. Resets key variables<br/>
- Click "go": Starts the fire from a given ignition point. The fire starts spreading. The agents start extinguishing the fire after "response-time" amount of ticks. The simulation counts upwards with ticks representing minutes. <br/>

**Simulation input variables**<br/>
Each simulation is run according to the SoS design variables you choose by yourself in the simulatoin interface: 
- response-time - The time (minutes) it takes for the SoS to start the firefighting operation<br/>
- agent-amount - The amount of agents there are in the operation<br/>
- perc-ground - How big proportation of the agent-amount which is ground agents, the rest is helicopters.<br/>
- time-strategy-update - How often the fire assessment is done, to redistribute agents around the fire.<br/>
- strategy-choice - Which of the strategies the agents do:<br/>
_largest-firesector: Concentrates all agents on the sector with the most active fires<br/>
largest-rel-change: Focuses on the sector with the fastest relative increase<br/>
protect-city: Assigns agents to areas close to city zones<br/>
spread-agents-equally: Distributes agents evenly across all fire sectors<br/>
decentralized-decision: The decisions of where to attack the fire is made by the agents. The helicopters target fires near water and the ground firefighters go to nearest fire depending on their location.<br/>
go-around: Helicopters and firefighters move in opposite directions around the fire<br/>_

**Fire Spread Functions**<br/>
- general_fire_spread: Basic spread to nearby patches based on heat<br/>
- head_fire_spread: Enhanced spread along wind direction<br/>
- ignite: Starts new fire agents if patch temperature exceeds threshold<br/>
- fire_dying: Fire dies if it has burned for some period of time or cooled by water<br/>
Each fire is categorized into head, heel, left flank, or right flank, based on its direction relative to the fire center and wind.<br/>

A "Situation Assessment" is done regularly to evaluate the fire situation. Every "hour" (60 ticks), the model:<br/>
- Generates a snapshot of fire counts per sector to compare the sectors fire size.<br/>
- Computes both numerical and relative change rates of the fire spread.<br/>

**Plots in user interface**<br/>

Situation assessment: <br/>
- Number of fires agents in each sector<br/>
- Total amount of fire agents <br/>
- Relative change rate of fire agents in each sector from last situation assessment <br/>
- Numerical change rate of fire agents in each sector from last situation assessment <br/>
- How many fires exitinguished by ground firefighters and helicopters <br/>

Costs:<br/>
- Firefighters costs, helicopter costs, and number of firefighters and helicopters.<br/>

Burn:<br/>
- Burnt area, value of burnt area, nr of burnt cities, emitted CO2 from burned trees.<br/>

**Outputs**<br/>
The simulations are run with Python according to a Design of Experiments. The following outputs are derived and saved in CSV files:<br/>
- Burned area (burned-area)<br/>
- Lost forest value (forest_value_loss)<br/>
- Burned area of cities (burned-society-hec<br/>
- Helicopter active hours (h-hours)<br/>
- Firefighter ground active hours (ff-hours)<br/>
- Amount of fires extinguished by helicopters (h-fire-ext)<br/>
- Amount of fires extinguished by ground firefighters (ff-fire-ext)<br/>

