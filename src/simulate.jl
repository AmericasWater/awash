using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")
if !isdefined(:config) || isempty(config)
    #config = readconfig("../configs/standard-1year.yml")
    config = readconfig("../configs/paleo-4scen.yml") 
end
include("model.jl")

# Run it and time it!
println("Running model...")
@time run(model)
