include("../../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization

include("../../src/optimization-given.jl")
house = optimization_given(true);

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol_before = houseoptimize(house, solver)
summarizeparameters(house, sol_before.sol)

recorded = getfilteredtable("extraction/USGS-2010.csv")

## Add constraints that sw_i* + sum_j sw_j* < sw_i + sum_j sw_j, so long as in same state
addconstraint!(house, :Allocation, :neighborwithdrawals, :withdrawals)

room = roomempty(house.model, :Allocation, :withdrawals, :withdrawals) ## XXX: Replace with county-level (3109) constraint
swtotals = []
for ii in 1:nrow(masterregions)
    ## XXX: Rewrite so summing over all gauges within any of these counties
    room.A[ii, ii] = 1
    withinstate = filter(jj -> jj != 0 && masterregions[jj, :state] == masterregions[ii, :state], sourceiis[ii])
    if length(withinstate) == 0
        push!(swtotals, recorded[ii, :TO_SW] * config["timestep"] * 1383. / 12)
    else
        room.A[ii, withinstate] = 1
        push!(swtotals, (recorded[ii, :TO_SW] + sum(recorded[withinstate, :TO_SW])) * config["timestep"] * 1383. / 12)
    end
end

setconstraintoffset!(house, LinearProgrammingHall(:Allocation, :neighborwithdrawals, swtotals))

@time sol_after = houseoptimize(house, solver)
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
