#### Determine the gauge-level surface extractions that reproduce observed flows at minimum cost

include("lib/readconfig.jl")
if !isdefined(:config)
    config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization
end

include("optimization-given.jl")
house = optimization_given(false)

serialize(open("../data/fullhouse$suffix.jld", "w"), house)

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
serialize(open("../data/extraction/captures$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:3])+1:end], numreservoirs, numsteps))

# How much water is in the streams?
values = getconstraintsolution(house, sol, :outflows)

cwro = deserialize(open(joinpath(todata, "partialhouse2$suffix.jld"), "r"));
offset = cwro.f
offset[isnan(offset)] = 0
outflows = offset - values
outflows = reshape(outflows, house.model.indices_counts[:gauges], house.model.indices_counts[:time])
writecsv("../data/extraction/outflows-bygauge.csv", outflows)
