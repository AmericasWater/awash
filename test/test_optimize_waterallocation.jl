using Base.Test

using DataArrays
using DataFrames
using OptiMimi

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-10year.yml")

include("../src/optimization-given.jl")

house = optimization_given(true)

using MathProgBase
using Clp
solver = ClpSolver()

@time sol = houseoptimize(house, solver)
# Save the results for simulation
varlens = varlengths(house.model, house.paramcomps, house.parameters)
serialize(open(datapath("extraction/withdrawals$suffix.jld"), "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
serialize(open(datapath("extraction/returns$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numsteps))
serialize(open(datapath("extraction/waterfromgw$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numcounties, numsteps))
serialize(open(datapath("extraction/captures$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:4])+1:end], numreservoirs, numsteps))

# Run the model
include("../src/model.jl")
println("Running model...")
run(model)

# Verify that captures never exceed max capacities
# Verify that storage is never inferior to min capacities
@test sum(model[:WaterNetwork, :outflows] .< -1) == 0
