using Base.Test

## Create a simple model and run it
using DataArrays
using DataFrames
using OptiMimi

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-60year-colorado.yml");

include("../src/model.jl")

println("Running model...")
@time run(model)
