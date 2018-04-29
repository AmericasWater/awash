using Base.Test

using DataArrays
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
varlens = varlengths(house.model, house.paramcomps, house.parameters)
serialize(open(datapath("extraction/withdrawals$suffix.jld"), "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numscenarios, numsteps))
serialize(open(datapath("extraction/returns$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numscenarios, numsteps))
serialize(open(datapath("extraction/captures$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:3])+1:end], numreservoirs, numscenarios, numsteps))

# Run the model
include("../src/model.jl")
println("Running model...")
run(model)

# Verify that captures never exceed max capacities
@test sum(model[:Reservoir, :storage] .> model[:Reservoir, :storagecapacitymax]) == 0
# Verify that storage is never inferior to min capacities
@test sum(model[:Reservoir, :storage] .< model[:Reservoir, :storagecapacitymin]) == 0
