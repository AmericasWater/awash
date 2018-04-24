## Simulate Paleoreconstruction
#
# Run the model using paleo streamflows.

using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")

config = readconfig("../configs/paleo.yml")

include("world.jl")
include("weather.jl")

include("model.jl")

# Run it and time it!
println("Running model...")
@time run(model)
