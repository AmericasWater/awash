using Mimi
using OptiMimi

include("../lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

include("../world.jl")
include("../weather.jl")
include("../WaterNetwork.jl")

m = newmodel();

hall = constraintoffset_waternetwork_outflows(m)

# Reorder so GAUGES x TIMESTEPS
flows = reshape(hall.f, numgauges, numsteps)

writecsv("unmodifiedflows.csv", flows)
