## Complete Model construction
#
# Includes both water management and production management.

include("model-waterdemand.jl")

## Check if the optimize-surface script has produced captures data
storedcaptures = cached_fallback("extraction/captures", () -> false)
println("DDD")
if storedcaptures == false
    @warn "Missing saved reservoirs file.  Please run optimize-surface.jl with allowreservoirs."
elseif size(storedcaptures)[1] != numreservoirs || size(storedcaptures)[2] != numsteps
    @warn "Reservoir file does not match current configuration.  Please remove."
end

include("ReturnFlows.jl");
include("WaterNetwork.jl");
include("Allocation.jl");
include("Reservoir.jl");
include("WaterCost.jl");
include("EnvironmentalDemand.jl")
include("WaterStressIndex.jl")

allocation = initallocation(model); # dep. WaterDemand, optimization (withdrawals)
watercost = initwatercost(model); # dep. Allocation
returnflows = initreturnflows(model, true); # dep. Allocation
waternetwork = initwaternetwork(model); # dep. ReturnFlows
reservoir = initreservoir(model); # Allocation and WaterNetwork or optimization-only
environmentaldemand = initenvironmentaldemand(model); # dep. WaterNetwork
waterstressindex = initwaterstressindex(model);

# Connect up the components
allocation[:watertotaldemand] = waterdemand[:totaldemand];
returnflows[:swwithdrawals] = allocation[:copy_swwithdrawals];
waternetwork[:removed] = returnflows[:removed];
waternetwork[:returned] = returnflows[:returned];
watercost[:gwextraction] = allocation[:copy_gwextraction];
watercost[:swwithdrawals] = allocation[:copy_swwithdrawals];
watercost[:supersourcesupply] = allocation[:copy_supersourcesupply];
reservoir[:inflowsgauges] = waternetwork[:inflows];
reservoir[:outflowsgauges] = waternetwork[:outflows];

environmentaldemand[:naturalflows] = waternetwork[:unmodifieds];
environmentaldemand[:outflowsgauges] = waternetwork[:outflows];
waterstressindex[:inflowgauge] = waternetwork[:inflows];
waterstressindex[:withdrawalsw] = returnflows[:removed];
waterstressindex[:withdrawalswregion] = allocation[:swsupply];
waterstressindex[:withdrawalgw] = allocation[:gwsupply];
