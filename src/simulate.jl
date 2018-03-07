using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")
if !isdefined(:config) || isempty(config)
     config = readconfig("../configs/single.yml") 
end

include("model.jl")

# Run it and time it!
println("Running model...")
@time run(model)
