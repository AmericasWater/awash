using Test

using DataFrames
using OptiMimi

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year-state.yml")

include("../src/optimization-given.jl")

house = optimization_given(false)

using MathProgBase
using Clp
solver = ClpSolver()

@time sol = houseoptimize(house, solver)
# Save the results for simulation
save_optimization_given(house, sol, false, true)

# Run the model
include("../src/model-surfacewater.jl")
println("Running model...")
run(model)

# Verify that captures never exceed max capacities
@test sum(model[:Reservoir, :storage] .> model[:Reservoir, :storagecapacitymax]) == 0
# Verify that storage is never inferior to min capacities
@test sum(model[:Reservoir, :storage] .< model[:Reservoir, :storagecapacitymin]) == 0
