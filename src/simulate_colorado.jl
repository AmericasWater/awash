using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")
config = readconfig("../configs/standard-60year-colorado.yml")
#config = readconfig("../configs/dummy3.yml")
#config = readconfig("../configs/standard-1year-delaware.yml")

include("model.jl")

# Run it and time it!
println("Running model for Colorado state ...")
@time run(model)


