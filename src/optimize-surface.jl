#### Determine the gauge-level surface extractions that reproduce observed flows at minimum cost

include("lib/readconfig.jl")
if !isdefined(:config)
    config = readconfig("../configs/single.yml") # Just use 1 year for optimization
end

if "rescap" in keys(config) && config["rescap"] == "zero"
	allowreservoirs = false
else
	allowreservoirs = true
end

include("optimization-given.jl")
house = optimization_given(false, allowreservoirs)

serialize(open(datapath("fullhouse$suffix.jld"), "w"), house)

using MathProgBase
using Clp
solver = ClpSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)

# Look at the constraints: only possible for small models
#constdf = constraining(house, sol.sol)

# Save the results
varlens = varlengths(house.model, house.paramcomps, house.parameters)

serialize(open(datapath("extraction/withdrawals$suffix.jld"), "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
serialize(open(datapath("extraction/returns$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numsteps))
if allowreservoirs
    serialize(open(datapath("extraction/captures$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:3])+1:end], numreservoirs, numsteps))
end

# How much water is in the streams?
values = getconstraintsolution(house, sol, :outflows)

cwro = deserialize(open(cachepath("partialhouse2$suffix.jld"), "r"));
offset = cwro.f
offset[isnan.(offset)] = 0
outflows = offset - values
outflows = reshape(outflows, house.model.indices_counts[:gauges], house.model.indices_counts[:time])
writecsv(datapath("extraction/outflows-bygauge.csv"), outflows)
