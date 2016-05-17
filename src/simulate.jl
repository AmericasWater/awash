using DataArrays
using DataFrames
using OptiMimi
cd("Dropbox/POSTDOC/AW-julia/operational-problem-main/src")
pwd()
workspace()
netset = "usa" # dummy or usa

# Only include counties within this state (give as 2 digit FIPS)
# "10" for Delaware (3 counties), "08" for Colorado (64 counties)
filterstate = nothing #"10"

include("world.jl")
include("weather.jl")

<<<<<<< HEAD
include("Agriculture.jl");
include("ReturnFlows.jl");
include("WaterDemand.jl");
#include("DomesticDemand.jl");
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
=======
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
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45

println("Creating model...")

# First solve entire problem in a single timestep
m = newmodel();

# Add all of the components
<<<<<<< HEAD
#domesticdemand = initdomesticdemand(m, m.indices_values[:time]); # exogenous
=======
domesticdemand = initdomesticdemand(m, m.indices_values[:time]); # exogenous
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45
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
industrialdemand = initindustrialdemand(m);
urbandemand = initurbandemand(m);

# Connect up the components
waterdemand[:totalirrigation] = agriculture[:totalirrigation];
<<<<<<< HEAD
waterdemand[:thermoelectricuse] = thermoelectric[:demand_copy];
waterdemand[:livestockuse] = livestock[:demand_copy];
#waterdemand[:domesticuse] = domesticdemand[:waterdemand];
waterdemand[:urbanuse] = urbandemand[:waterdemand];
waterdemand[:industrialuse] = industrialdemand[:waterdemand];
=======
waterdemand[:domesticuse] = domesticdemand[:waterdemand];
waterdemand[:thermoelectricuse] = thermoelectric[:demand_copy];
waterdemand[:livestockuse] = livestock[:demand_copy];
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45

allocation[:waterdemand] = waterdemand[:totaldemand];
allocation[:waterreturn] = waterdemand[:totalreturn];
returnflows[:withdrawals] = allocation[:copy_withdrawals];
returnflows[:returns] = allocation[:copy_returns];
waternetwork[:removed] = returnflows[:removed];
<<<<<<< HEAD
allocation[:withdrawals] = returnflows[:copy_withdrawals];
groundwater[:withdrawal] = allocation[:watergw];
=======
waternetwork[:added] = returnflows[:added];
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45

market[:produced] = agriculture[:production];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];

# Run it and time it!
@time run(m)

m.components[:IndustrialDemand].Variables.waterdemand
m.components[:UrbanDemand].Variables.waterdemand
m.components[:Allocation].Parameters.withdrawals
m.components[:Allocation].Parameters.waterdemand
m.components[:Allocation].Parameters.waterfromgw
m.components[:Allocation].Parameters.waterfromreservoir
m.components[:Allocation].Parameters.waterfromsupersource
m.components[:Allocation].Variables.watergw
m.components[:Allocation].Variables.waterreservoir
m.components[:Allocation].Variables.swsupply
m.components[:Allocation].Parameters.costfromgw
m.components[:Allocation].Parameters.costfromsw
m.components[:Allocation].Parameters.costfromsupersource
m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocated
m.components[:Allocation].Variables.balance

m.components[:WaterDemand].Variables.totaldemand
m.components[:WaterDemand].Parameters.totalirrigation
m.components[:WaterDemand].Parameters.domesticuse
m.components[:WaterDemand].Parameters.industrialuse
m.components[:WaterDemand].Parameters.urbanuse
m.components[:WaterDemand].Parameters.thermoelectricuse
m.components[:WaterDemand].Parameters.livestockuse

