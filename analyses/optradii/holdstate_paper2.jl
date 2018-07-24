#include("../../src/lib/readconfig.jl")
#config = readconfig("../configs/complete-yearly.yml")

#include("../../src/optimization-given.jl")
#using MathProgBase
#using Gurobi
#solver = GurobiSolver()

allowreservoirs = false

house = optimization_given(false, allowreservoirs)
@time sol = houseoptimize(house, solver)

## Prepare constraints on all cross-state flows
values = getconstraintsolution(house, sol, :outflows)
cwro = constraintoffset_waternetwork_outflows(house.model)
offset = cwro.f
offset[isnan(offset)] = 0
outflows = offset - values
outflows = reshape(outflows, house.model.indices_counts[:gauges], house.model.indices_counts[:time])
# outflows constrained as cumulative runoff

house = optimization_given(true, allowreservoirs);

@time sol_before = houseoptimize(house, solver)
summarizeparameters(house, sol_before.sol)

include("../../prepare/bystate/waternet/statelib.jl")

# Specify that outflows + runoff > required, or -outflows < runoff - required
constraintlower = zeros(outflows) # Start with 0
## Specify that outflows + runoff < required, or outflows < required - runoff
constraintupper = Inf * ones(outflows) # default upper constraint is infinity

for hh in length(downstreamorder):-1:1
    gauge = downstreamorder[hh].label
    myregion = getregion(gauge)
    for upstream in out_neighbors(wateridverts[gauge], waternet)
        upregion = getregion(upstream.label)
        if myregion != upregion
            # Determine the gauge number of downstream
            gg = vertex_index(downstreamorder[hh])

            ## Constraint to be within 10% of current flows
            constraintlower[gg, :] = outflows[gg, :]
            constraintupper[gg, :] = outflows[gg, :] * 1.1
        end
    end
end

baselinerunoff = copy(getconstraintoffset(house, :WaterNetwork, :outflows))
setconstraintoffset!(house, :WaterNetwork, :outflows, baselinerunoff - vec(constraintlower))

# Add max flow constraint
# addconstraint!(house, :WaterNetwork, :maxoutflows, :outflows)
# setconstraint!(house, -room_relabel(getroom(house, :WaterNetwork, :outflows, :Allocation, :withdrawals), :outflows, :WaterNetwork, :maxoutflows))
# setconstraintoffset!(house, :WaterNetwork, :maxoutflows, vec(constraintupper) - baselinerunoff)

## Set offset to 0 if no water connections
# for ii in 1:size(house.A)[1]
#     if house.b[ii] < 0 && sum(abs(house.A[ii,:])) == 0
#         house.b[ii] = 0
#     end
# end

## Allow supersource feeding of gauges
addparameter!(house, :WaterNetwork, :added) # include as supersource, but only for that link (no propagation)
setconstraint!(house, roomdiagonal(house.model, :WaterNetwork, :outflows, :added, -1.))
setobjective!(house, hallsingle(house.model, :WaterNetwork, :added, -1000.))

@time sol_after = houseoptimize(house, solver, find(house.b .< Inf))
summarizeparameters(house, sol_after.sol)

df = DataFrame(variable=[repmat(["withdrawals"], length(getparametersolution(house, sol_before.sol, :withdrawals)));
                         repmat(["waterfromgw"], length(getparametersolution(house, sol_before.sol, :waterfromgw)))],
               optimized=[getparametersolution(house, sol_before.sol, :withdrawals);
                          getparametersolution(house, sol_before.sol, :waterfromgw)])
#writetable("radius-nation.csv", df)

df = DataFrame(variable=[repmat(["withdrawals"], length(getparametersolution(house, sol_after.sol, :withdrawals)));
                         repmat(["waterfromgw"], length(getparametersolution(house, sol_after.sol, :waterfromgw)))],
               optimized=[getparametersolution(house, sol_after.sol, :withdrawals);
                          getparametersolution(house, sol_after.sol, :waterfromgw)])
#writetable("radius-state.csv", df)

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
