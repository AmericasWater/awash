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
agriculture = initagriculture(m); # optimization-only
waterdemand = initwaterdemand(m); # dep. Agriculture, DomesticDemand
allocation = initallocation(m); # dep. WaterDemand
groundwater = initaquifercontus(m); # Allocation or optimization-only
reservoir = initreservoir(m); # Allocation or optimization-only
returnflows = initreturnflows(m); # exogenous/optimization
waternetwork = initwaternetwork(m); # dep. WaterDemand
transportation = inittransportation(m); # optimization-only
market = initmarket(m); # dep. Transporation, Agriculture

# Connect up the components
waterdemand[:totalirrigation] = agriculture[:totalirrigation];
waterdemand[:domesticuse] = domesticdemand[:waterdemand];

allocation[:waterdemand] = waterdemand[:totaldemand];
waternetwork[:removed] = returnflows[:removed];
allocation[:withdrawals] = returnflows[:copy_withdrawals];

market[:produced] = agriculture[:production];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];

# Run it and time it!
@time run(m)


