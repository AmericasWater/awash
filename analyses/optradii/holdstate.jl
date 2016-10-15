cd("../../src")
include("lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization

include("optimization-given.jl")
house = optimization_given(true)

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol_before = houseoptimize(house, solver)
summarizeparameters(house, sol_before.sol)

include("../prepare/bystate/statelib.jl")

## Add constraints on all cross-state flows
outflows = readtable("../data/extraction/outflows-bygauge.csv", header=false)
outflows = convert(Matrix{Float64}, outflows)
# outflows constrained as cumulative runoff
constraintoffset = getconstraintoffset(house, :WaterNetwork, :outflows, reshp=true)
origco = copy(constraintoffset)

for hh in length(downstreamorder):-1:1
    gauge = downstreamorder[hh].label
    myregion = getregion(gauge)
    for upstream in out_neighbors(wateridverts[gauge], waternet)
        upregion = getregion(upstream.label)
        if myregion != upregion
            # Determine the gauge number of upstream
            gg = vertex_index(upstream)
            # Constrain upstream's outflow to be as produced by optimize-surface
            # Specify that outflows + runoff > required, or -outflows < runoff - required
            constraintoffset[gg, :] = constraintoffset[gg, :] - outflows[gg, :]
        end
    end
end

##sum(constraintoffset - origco)
setconstraintoffset!(house, :WaterNetwork, :outflows, vec(constraintoffset))

## Set offset to 0 if no water connections
for ii in 1:size(house.A)[1]
    if house.b[ii] < 0 && sum(abs(house.A[ii,:])) == 0
        house.b[ii] = 0
    end
end

## Allow supersource feeding of gauges
addparameter!(house, :WaterNetwork, :added) # include as supersource
setconstraint!(house, roomdiagonal(house.model, :WaterNetwork, :outflows, :added, (gg, tt) -> -1.))
setobjective!(house, hallsingle(house.model, :WaterNetwork, :added, (gg, tt) -> -1000.))

@time sol_after = houseoptimize(house, solver)
summarizeparameters(house, sol_after.sol)

getparametersolution(house, sol_before.sol, :waterfromgw) - getparametersolution(house, sol_after.sol, :waterfromgw)
getparametersolution(house, sol_before.sol, :withdrawals) - getparametersolution(house, sol_after.sol, :withdrawals)

## Also look at total USGS withdrawals
recorded = readtable(datapath("extraction/USGS-2010.csv"))
sum(recorded[:TO_SW]) * 1383.
sum(recorded[:TO_GW]) * 1383.
