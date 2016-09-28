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
include("Thermoelectric.jl");
include("Livestock.jl");
include("WaterCost.jl");
include("PopulationDemand.jl")

## Check if the optimize-surface script has been called
storedresult = cached_fallback("extraction/captures", () -> false)
if storedresult == false
    warn("Missing saved allocation files.  Please run optimize-surface.jl")
elseif size(storedresult)[1] != numreservoirs || size(storedresult)[2] != numsteps
    warn("Cache file does not match current configuration.  Please remove.")
end

println("Creating model...")

# First solve entire problem in a single timestep
model = newmodel();

# Add all of the components
thermoelectric = initthermoelectric(model); # exogenous
livestock = initlivestock(model); # exogenous
agriculture = initagriculture(model); # optimization-only
industrialdemand = initindustrialdemand(model); # exogenous
urbandemand = initurbandemand(model); # exogenous
waterdemand = initwaterdemand(model); # dep. Agriculture, PopulationDemand
allocation = initallocation(model); # dep. WaterDemand, optimization (withdrawals)
watercost = initwatercost(model); # dep. Allocation
returnflows = initreturnflows(model); # dep. Allocation
groundwater = initaquifer(model); # Allocation or optimization-only
reservoir = initreservoir(model); # Allocation or optimization-only
waternetwork = initwaternetwork(model); # dep. ReturnFlows
transportation = inittransportation(model); # optimization-only
market = initmarket(model); # dep. Transporation, Agriculture

# Connect up the components
waterdemand[:totalirrigation] = agriculture[:totalirrigation];
waterdemand[:thermoelectricuse] = thermoelectric[:demand_copy];
waterdemand[:livestockuse] = livestock[:demand_copy];
waterdemand[:urbanuse] = urbandemand[:waterdemand];
waterdemand[:industrialuse] = industrialdemand[:waterdemand];

allocation[:totalwaterdemand] = waterdemand[:totaldemand];
allocation[:totaldemandreturn] = waterdemand[:totalreturn];
watercost[:gwextraction] = allocation[:gwextraction_copy];
watercost[:swwithdrawals] = allocation[:withdrawals_copy];
watercost[:supersourcesupply] = allocation[:supersourcesupply_copy];
returnflows[:withdrawals] = allocation[:withdrawals_copy];
returnflows[:returns] = allocation[:returns_copy];
waternetwork[:removed] = returnflows[:removed];
waternetwork[:returned] = returnflows[:returned];
groundwater[:withdrawal] = allocation[:gwextraction_copy];

market[:produced] = agriculture[:production];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];
