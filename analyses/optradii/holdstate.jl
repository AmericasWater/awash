cd("../../src")
include("lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization

include("optimization-given.jl")
house = optimization_given(true)

include("../prepare/bystate/statelib.jl")

## Add constraints on all cross-state flows
outflows = readtable("../data/extraction/outflows-bygauge.csv", header=false)
# outflows constrained as cumulative runoff
constraintoffset = getconstraintoffset(house, :WaterNetwork, :outflows, reshp=true)
origco = copy(constraintoffset)

for hh in length(downstreamorder):1
    gauge = downstreamorder[hh].label
    myregion = getregion(gauge)
    for upstream in out_neighbors(wateridverts[gauge], waternet)
        upregion = getregion(upstream.label)
        if myregion != upregion
            # Determine the gauge number of upstream

            # Constrain upstream's outflow to be as produced by optimize-surface
            # Specify that outflows + runoff > required, or -outflows < runoff - required
            constraintoffset[gg, :] = constraintoffset[gg, :] - outflows[gg, :]
        end
    end
end

setconstraintoffset!(house, :WaterNetwork, :outflows, vec(constraintoffset))

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

# Save the results
varlens = varlengths(house.model, house.paramcomps, house.parameters)

serialize(open("statewithdrawals$suffix.jld", "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
serialize(open("statereturns$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numsteps))
serialize(open("statecaptures$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numreservoirs, numsteps))
serialize(open("statewaterfromgw$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:4])+1:end], numcounties, numsteps))
