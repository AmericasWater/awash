using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")
config = readconfig("../configs/standard.yml")

include("model.jl")

# Run it and time it!
println("Running model...")
@time run(model)


