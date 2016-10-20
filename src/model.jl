include("model-waterdemand.jl")

include("ReturnFlows.jl");
include("Market.jl");
include("Transportation.jl");
include("WaterNetwork.jl");
include("Groundwater.jl");
include("Allocation.jl");
include("Reservoir.jl");
include("WaterCost.jl");

allocation = initallocation(model); # dep. WaterDemand, optimization (withdrawals)
watercost = initwatercost(model); # dep. Allocation
returnflows = initreturnflows(model); # dep. Allocation
groundwater = initaquifer(model); # Allocation or optimization-only
reservoir = initreservoir(model); # Allocation or optimization-only
waternetwork = initwaternetwork(model); # dep. ReturnFlows
transportation = inittransportation(model); # optimization-only
market = initmarket(model); # dep. Transporation, Agriculture

# Connect up the components

allocation[:watertotaldemand] = waterdemand[:totaldemand];
allocation[:waterreturn] = waterdemand[:totalreturn];
watercost[:gwextraction] = allocation[:copy_gwextraction];
watercost[:swwithdrawals] = allocation[:copy_swwithdrawals];
watercost[:supersourcesupply] = allocation[:copy_supersourcesupply];
returnflows[:withdrawals] = allocation[:copy_swwithdrawals];
returnflows[:returns] = allocation[:copy_returns];
waternetwork[:removed] = returnflows[:removed];
waternetwork[:returned] = returnflows[:returned];
groundwater[:withdrawal] = allocation[:copy_gwextraction];

market[:produced] = agriculture[:production];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];
