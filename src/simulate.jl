using DataArrays
using OptiMimi

netset = "usa" # dummy or usa

# Only include counties within this state (give as 2 digit FIPS)
# "10" for Delaware (3 counties), "08" for Colorado (64 counties)
filterstate = nothing #"10"

include("world.jl")
include("weather.jl")

include("Agriculture.jl")
include("ReturnFlows.jl")
include("WaterDemand.jl")
include("DomesticDemand.jl")
include("Thermoelectric.jl")
include("Livestock.jl")
include("Market.jl")
include("Transportation.jl")
include("WaterNetwork.jl")
include("Groundwater.jl")
include("Allocation.jl")
include("Reservoir.jl")

println("Creating model...")

# First solve entire problem in a single timestep
m = newmodel();

# Add all of the components
domesticdemand = initdomesticdemand(m, m.indices_values[:time]); # exogenous
thermoelectric = initthermoelectric(m); # exogenous
livestock = initlivestock(m); # exogenous
agriculture = initagriculture(m); # optimization-only
waterdemand = initwaterdemand(m); # dep. Agriculture, DomesticDemand
allocation = initallocation(m); # dep. WaterDemand, optimization (withdrawals)
returnflows = initreturnflows(m); # dep. Allocation
groundwater = initaquifercontus(m); # Allocation or optimization-only
reservoir = initreservoir(m); # Allocation or optimization-only
waternetwork = initwaternetwork(m); # dep. ReturnFlows
transportation = inittransportation(m); # optimization-only
market = initmarket(m); # dep. Transporation, Agriculture

# Connect up the components
waterdemand[:totalirrigation] = agriculture[:totalirrigation];
waterdemand[:domesticuse] = domesticdemand[:waterdemand];
waterdemand[:thermoelectricuse] = thermoelectric[:demand_copy];
waterdemand[:livestockuse] = livestock[:demand_copy];

allocation[:waterdemand] = waterdemand[:totaldemand];
allocation[:waterreturn] = waterdemand[:totalreturn];
returnflows[:withdrawals] = allocation[:copy_withdrawals];
returnflows[:returns] = allocation[:copy_returns];
waternetwork[:removed] = returnflows[:removed];
waternetwork[:returned] = returnflows[:returned];

market[:produced] = agriculture[:production];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];

# Run it and time it!
@time run(m)


