include("model-waterdemand.jl")

## Check if the optimize-surface script has produced captures data
storedcaptures = cached_fallback("extraction/captures", () -> false)
if storedcaptures == false
    warn("Missing saved reservoirs file.  Please run optimize-surface.jl with allowreservoirs.")
elseif size(storedresult)[1] != numreservoirs || size(storedresult)[2] != numsteps
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
returnflows = initreturnflows(model); # dep. Allocation
groundwater = initaquifer(model); # Allocation or optimization-only
reservoir = initreservoir(model); # Allocation or optimization-only
waternetwork = initwaternetwork(model); # dep. ReturnFlows
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

market[:produced] = agriculture[:allcropproduction];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];
