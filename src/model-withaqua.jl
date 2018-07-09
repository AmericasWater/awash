## Water Demand Model construction, with aquifers
#
# Like model-waterdemand, but also includes aquifers.

## `config` must be defined before loading this file!

include("world.jl")
include("weather.jl")

include("Agriculture.jl");
include("ReturnFlows.jl");
include("WaterDemand.jl");
include("Market.jl");
include("Transportation.jl");
include("WaterNetwork.jl");
include("Groundwater.jl");
include("Allocation.jl");
include("Reservoir.jl");
include("IndustrialDemand.jl");
include("UrbanDemand.jl");
include("Thermoelectric.jl")
include("Livestock.jl")

println("Creating model...")

# First solve entire problem in a single timestep
model = newmodel();

# Add all of the components
thermoelectric = initthermoelectric(model); # exogenous
livestock = initlivestock(model); # exogenous
agriculture = initagriculture(model); # optimization-only
aquaculture = initaquaculture(model); # optimization-only
waterdemand = initwaterdemand(model); # dep. Agriculture, PopulationDemand
allocation = initallocation(model); # dep. WaterDemand, optimization (withdrawals)
returnflows = initreturnflows(model, true); # dep. Allocation
groundwater = initaquifercontus(model); # Allocation or optimization-only
reservoir = initreservoir(model); # Allocation or optimization-only
waternetwork = initwaternetwork(model); # dep. ReturnFlows
transportation = inittransportation(model); # optimization-only
market = initmarket(model); # dep. Transporation, Agriculture
industrialdemand = initindustrialdemand(model);
urbandemand = initurbandemand(model);

# Connect up the components
waterdemand[:totalirrigation] = agriculture[:totalirrigation];
waterdemand[:thermoelectricuse] = thermoelectric[:demand_copy];
waterdemand[:livestockuse] = livestock[:demand_copy];
waterdemand[:urbanuse] = urbandemand[:waterdemand];
waterdemand[:industrialuse] = industrialdemand[:waterdemand];
waterdemand[:aquacultureuse] = aquaculture[:demand];

allocation[:watertotaldemand] = waterdemand[:totaldemand];
allocation[:waterreturn] = waterdemand[:totalreturn];
returnflows[:withdrawals] = allocation[:copy_withdrawals];
waternetwork[:removed] = returnflows[:removed];
waternetwork[:returned] = returnflows[:returned];
allocation[:withdrawals] = returnflows[:copy_withdrawals];
groundwater[:withdrawal] = allocation[:watergw];

market[:produced] = agriculture[:production];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];
