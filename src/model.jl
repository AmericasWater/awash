## Complete Model construction
#
# Includes both water management and production management.

include("model-waterdemand.jl")

## Check if the optimize-surface script has produced captures data
storedcaptures = cached_fallback("extraction/captures", () -> false)
if storedcaptures == false
    warn("Missing saved reservoirs file.  Please run optimize-surface.jl with allowreservoirs.")
elseif size(storedcaptures)[1] != numreservoirs || size(storedcaptures)[2] != numsteps
    warn("Reservoir file does not match current configuration.  Please remove.")
end

include("ReturnFlows.jl");
include("Market.jl");
include("Transportation.jl");
include("WaterNetwork.jl");
include("Groundwater.jl");
include("Allocation.jl");
include("Reservoir.jl");

allocation = initallocation(model); # dep. WaterDemand, optimization (withdrawals)
println("AA")
returnflows = initreturnflows(model); # dep. Allocation
groundwater = initaquifer(model); # Allocation or optimization-only
println("B")
waternetwork = initwaternetwork(model); # dep. ReturnFlows
reservoir = initreservoir(model); # Allocation and WaterNetwork or optimization-only
println("C")
transportation = inittransportation(model); # optimization-only
market = initmarket(model); # dep. Transportation, Agriculture
println("D")

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

market[:produced] = agriculture[:allcropproduction];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];
