#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("lib/readconfig.jl")

config = readconfig("../configs/standard-1year-colorado.yml") # Just use 1 year for optimization

include("optimization-given.jl")

house = optimization_given(true)

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

# If model is infeasible, figure out what's causing that
#topbot = findinfeasiblepair(house, solver)
#sol = linprog(-house.f, house.A[1:topbot[1],:], '<', house.b[1:topbot[1]], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[1:topbot[1]-1,:], '<', house.b[1:topbot[1]-1], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[topbot[2]:end,:], '<', house.b[topbot[2]:end], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[topbot[2]+1:end,:], '<', house.b[topbot[2]+1:end], house.lowers, house.uppers, solver)

summarizeparameters(house, sol.sol)

# Look at the constraints: only possible for small models
#constraining(house, sol.sol)

# Save the results
varlens = varlengths(house.model, house.paramcomps, house.parameters)

serialize(open("../data/extraction/withdrawals$suffix.jld", "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
serialize(open("../data/extraction/returns$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numsteps))
serialize(open("../data/extraction/captures$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numreservoirs, numsteps))
serialize(open("../data/extraction/waterfromgw$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:4])+1:end], numcounties, numsteps))
