include("../../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization

include("../../src/optimization-given.jl")
house = optimization_given(true);

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol_before = houseoptimize(house, solver)
summarizeparameters(house, sol_before.sol)

include("../../prepare/bystate/waternet/statelib.jl")

## Add constraints on all cross-state flows
outflows = readtable("../../data/counties/extraction/outflows-bygauge.csv", header=false)
outflows = convert(Matrix{Float64}, outflows)
# outflows constrained as cumulative runoff

# Specify that outflows + runoff > required, or -outflows < runoff - required
constraintlower = getconstraintoffset(house, :WaterNetwork, :outflows, reshp=true)
## Specify that outflows + runoff < required, or outflows < required - runoff
constraintupper = Inf * ones(constraintlower) # default upper constraint is infinity

for hh in length(downstreamorder):-1:1
    gauge = downstreamorder[hh].label
    myregion = getregion(gauge)
    for upstream in out_neighbors(wateridverts[gauge], waternet)
        upregion = getregion(upstream.label)
        if myregion != upregion
            # Determine the gauge number of upstream
            gg = vertex_index(upstream)
            # Constrain upstream's outflow to be as produced by optimize-surface
            sumrunoffs = copy(constraintlower[gg, :])
            ## Constraint to be within 10% of current flows
            constraintlower[gg, :] = sumrunoffs - outflows[gg, :] * .9
            constraintupper[gg, :] = outflows[gg, :] * 1.1 - sumrunoffs
        end
    end
end

setconstraintoffset!(house, :WaterNetwork, :outflows, vec(constraintlower))

# Add max flow constraint
addconstraint!(house, :WaterNetwork, :maxoutflows, :outflows)
setconstraint!(house, -room_relabel(getroom(house, :WaterNetwork, :outflows, :Allocation, :withdrawals), :outflows, :WaterNetwork, :maxoutflows))
setconstraintoffset!(house, :WaterNetwork, :maxoutflows, vec(constraintupper))

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

@time sol_after = houseoptimize(house, solver, find(house.b .< Inf))
summarizeparameters(house, sol_after.sol)

## Also look at total USGS withdrawals
recorded = readtable(datapath("extraction/USGS-2010.csv"))

DataFrame(source=["Surface", "Ground"], nation=[sum(getparametersolution(house, sol_before.sol, :withdrawals)), sum(getparametersolution(house, sol_before.sol, :waterfromgw))],
          state=[sum(getparametersolution(house, sol_after.sol, :withdrawals)), sum(getparametersolution(house, sol_after.sol, :waterfromgw))],
          county=[sum(recorded[:TO_SW]) * 1383., sum(recorded[:TO_GW]) * 1383.])

DataFrame(source=["Surface", "Ground"],
          Nation2State=[sum(getparametersolution(house, sol_after.sol, :withdrawals) - getparametersolution(house, sol_before.sol, :withdrawals)) / sum(getparametersolution(house, sol_before.sol, :withdrawals)),
                        sum(getparametersolution(house, sol_after.sol, :waterfromgw) - getparametersolution(house, sol_before.sol, :waterfromgw)) / sum(getparametersolution(house, sol_before.sol, :waterfromgw))],
State2County=[(sum(recorded[:TO_SW] * 1383.) - sum(getparametersolution(house, sol_after.sol, :withdrawals))) / sum(getparametersolution(house, sol_after.sol, :withdrawals)),
              (sum(recorded[:TO_GW] * 1383.) - sum(getparametersolution(house, sol_after.sol, :waterfromgw))) / sum(getparametersolution(house, sol_after.sol, :waterfromgw))])
