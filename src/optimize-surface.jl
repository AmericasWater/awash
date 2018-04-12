#### Determine the gauge-level surface extractions that reproduce observed flows at minimum cost

include("lib/readconfig.jl")
if !isdefined(:config)
    ##config = readconfig("../configs/single.yml") # Just use 1 year for optimization
    config = readconfig("../configs/paleo-4scen.yml") 
end

allowreservoirs = true

include("optimization-given.jl")
house = optimization_given(false, allowreservoirs)

serialize(open(datapath("fullhouse$suffix.jld"), "w"), house)

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)

# Look at the constraints: only possible for small models
#constdf = constraining(house, sol.sol)

save_optimization_given(house, false, allowreservoirs)

# How much water is in the streams?
values = getconstraintsolution(house, sol, :outflows)

cwro = deserialize(open(datapath("partialhouse2$suffix.jld"), "r"));
offset = cwro.f
offset[isnan.(offset)] = 0
outflows = offset - values
outflows = reshape(outflows, house.model.indices_counts[:gauges], house.model.indices_counts[:time])
writecsv(datapath("extraction/outflows-bygauge.csv"), outflows)
