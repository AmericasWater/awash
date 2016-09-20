using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")
config = readconfig("../configs/standard-1year-colorado.yml")

include("model_colorado.jl")

# Run it and time it!
println("Running model for Colorado state ...")
@time run(model)


