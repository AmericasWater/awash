using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")
config = readconfig("../configs/standard.yml")

include("model.jl")

# Run it and time it!
println("Running model...")
@time run(model)

model.components[:IndustrialDemand].Variables.waterdemand
model.components[:UrbanDemand].Variables.waterdemand
model.components[:Allocation].Parameters.withdrawals
model.components[:Allocation].Parameters.watertotaldemand
model.components[:Allocation].Parameters.waterfromgw
model.components[:Allocation].Parameters.waterfromreservoir
model.components[:Allocation].Parameters.waterfromsupersource
model.components[:Allocation].Variables.watergw
model.components[:Allocation].Variables.waterreservoir
model.components[:Allocation].Variables.swsupply
model.components[:Allocation].Parameters.costfromgw
model.components[:Allocation].Parameters.costfromsw
model.components[:Allocation].Parameters.costfromsupersource
model.components[:Allocation].Variables.cost
model.components[:Allocation].Variables.waterallocated
model.components[:Allocation].Variables.balance

model.components[:WaterDemand].Variables.totaldemand
model.components[:WaterDemand].Parameters.totalirrigation
model.components[:WaterDemand].Parameters.domesticuse
model.components[:WaterDemand].Parameters.industrialuse
model.components[:WaterDemand].Parameters.urbanuse
model.components[:WaterDemand].Parameters.thermoelectricuse
model.components[:WaterDemand].Parameters.livestockuse

