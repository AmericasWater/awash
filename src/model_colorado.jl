## `config` must be defined before loading this file!

include("world.jl")
include("weather.jl")

include("Agriculture.jl");
include("WaterDemand.jl");
include("Market.jl");
include("WaterNetwork.jl");
include("Groundwater.jl");
include("Allocation.jl");
include("Reservoir.jl");
include("UrbanDemand.jl");
include("Thermoelectric.jl")

println("Creating model...")

# First solve entire problem in a single timestep
model = newmodel();

# Add all of the components
thermoelectric = initthermoelectriccolorado(model); # exogenous
#agriculture = initagriculturecolorado(model); # optimization-only
urbandemand = initurbandemandcolorado(model); # exogenous
agriculture = initagriculture(model); # optimization-only


waterdemand = initwaterdemand(model); # dep. Agriculture, PopulationDemand
allocation = initallocation(model); # dep. WaterDemand, optimization (withdrawals)
groundwater = initaquifer(model); # Allocation or optimization-only
reservoir = initreservoir(model); # Allocation or optimization-only
waternetwork = initwaternetwork(model); # dep. ReturnFlows
market = initmarket(model); # dep. Transporation, Agriculture

# Connect up the components
waterdemand[:totalirrigation] = agriculture[:totalirrigation];
waterdemand[:thermoelectricuse] = thermoelectric[:demand_copy];
waterdemand[:urbanuse] = urbandemand[:waterdemand];

allocation[:watertotaldemand] = waterdemand[:totaldemand];
allocation[:waterreturn] = waterdemand[:totalreturn];
groundwater[:withdrawal] = allocation[:watergw];

market[:produced] = agriculture[:production];