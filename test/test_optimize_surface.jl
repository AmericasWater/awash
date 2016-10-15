using Base.Test

using DataArrays
using DataFrames
using OptiMimi

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml")

include("../src/optimization-given.jl")

house = optimization_given(false)

using MathProgBase
using Clp
solver = ClpSolver()

@time sol = houseoptimize(house, solver)

# Save the results, if not available
varlens = varlengths(house.model, house.paramcomps, house.parameters)

if !isfile("../data/extraction/withdrawals$suffix.jld")
    serialize(open("../data/extraction/withdrawals$suffix.jld", "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
end
if !isfile("../data/extraction/returns$suffix.jld")
    serialize(open("../data/extraction/returns$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numsteps))
end
if !isfile("../data/extraction/captures$suffix.jld")
    serialize(open("../data/extraction/captures$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:3])+1:end], numreservoirs, numsteps))
end
