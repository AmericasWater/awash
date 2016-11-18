include("model-waterdemand.jl")

include("ReturnFlows.jl");
include("Market.jl");
include("Transportation.jl");
include("WaterNetwork.jl");
include("Allocation.jl");
include("Reservoir.jl");
include("Groundwater.jl");
include("IndustrialDemand.jl");
include("UrbanDemand.jl");
include("Thermoelectric.jl")
include("Livestock.jl")
include("PopulationDemand.jl")

## Check if the optimize-surface script has been called
storedresult = cached_fallback("extraction/captures", () -> false)
if storedresult == false
    warn("Missing saved allocation files.  Please run optimize-surface.jl")
elseif size(storedresult)[1] != numreservoirs || size(storedresult)[2] != numsteps
    warn("Cache file does not match current configuration.  Please remove.")
end

println("Creating model...")

allocation = initallocation(model); # dep. WaterDemand, optimization (withdrawals)
returnflows = initreturnflows(model); # dep. Allocation
waternetwork = initwaternetwork(model); # dep. ReturnFlows
groundwater = initaquifer(model); # Allocation or optimization-only
reservoir = initreservoir(model); # Allocation or optimization-only
waternetwork = initwaternetwork(model); # dep. ReturnFlows and WaterNetwork
transportation = inittransportation(model); # optimization-only
market = initmarket(model); # dep. Transporation, Agriculture

# Connect up the components
allocation[:watertotaldemand] = waterdemand[:totaldemand];
allocation[:waterreturn] = waterdemand[:totalreturn];
returnflows[:withdrawals] = allocation[:copy_withdrawals];
returnflows[:returns] = allocation[:copy_returns];
waternetwork[:removed] = returnflows[:removed];
waternetwork[:returned] = returnflows[:returned];
groundwater[:withdrawal] = allocation[:watergw];
reservoir[:inflowsgauges] = waternetwork[:inflows];
reservoir[:outflowsgauges] = waternetwork[:outflows];

market[:produced] = agriculture[:production];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];
