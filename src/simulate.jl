using DataArrays
using DataFrames
using OptiMimi
include("model.jl")

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

