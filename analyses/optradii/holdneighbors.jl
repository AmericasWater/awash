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
addconstraint!(house, :Allocation, :neighborbalance, :balance)

function genroom(A, tt)
    drawfips = regionindex(draws, :)
    for ii in 1:nrow(masterregions)
        withinstate = filter(jj -> jj != 0 && masterregions[jj, :state] == masterregions[ii, :state], sourceiis[ii])
        includedfips = regionindex(masterregions, [ii; withinstate])
        includeddraw = Bool[fips in includedfips for fips in drawfips]

        A[ii, includeddraw] = 1
    end
end

room = roomintersect(house.model, :Allocation, :balance, :withdrawals, genroom)
setconstraint!(house, room_relabel(room, :balance, :Allocation, :neighborbalance))

function genhall(ii, tt)
    withinstate = filter(jj -> jj != 0 && masterregions[jj, :state] == masterregions[ii, :state], sourceiis[ii])
    if length(withinstate) == 0
        return recorded[ii, :TO_SW] * config["timestep"] * 1383. / 12
    else
        return (recorded[ii, :TO_SW] + sum(recorded[withinstate, :TO_SW])) * config["timestep"] * 1383. / 12
    end
end

hall = hallsingle(house.model, :Allocation, :balance, genhall)
setconstraintoffset!(house, hall_relabel(hall, :balance, :Allocation, :neighborbalance))

@time sol_neighbors = houseoptimize(house, solver)
summarizeparameters(house, sol_neighbors.sol)

## Also look at total USGS withdrawals
recorded = readtable(datapath("extraction/USGS-2010.csv"))

DataFrame(source=["Surface", "Ground"], nation=[sum(getparametersolution(house, sol_before.sol, :withdrawals)), sum(getparametersolution(house, sol_before.sol, :waterfromgw))],
          neighbors=[sum(getparametersolution(house, sol_neighbors.sol, :withdrawals)), sum(getparametersolution(house, sol_neighbors.sol, :waterfromgw))],
          county=[sum(recorded[:TO_SW]) * 1383., sum(recorded[:TO_GW]) * 1383.])

DataFrame(source=["Surface", "Ground"],
          Nation2Neighbors=[sum(getparametersolution(house, sol_neighbors.sol, :withdrawals) - getparametersolution(house, sol_before.sol, :withdrawals)) / sum(getparametersolution(house, sol_before.sol, :withdrawals)),
                        sum(getparametersolution(house, sol_neighbors.sol, :waterfromgw) - getparametersolution(house, sol_before.sol, :waterfromgw)) / sum(getparametersolution(house, sol_before.sol, :waterfromgw))],
Neighbors2County=[(sum(recorded[:TO_SW] * 1383.) - sum(getparametersolution(house, sol_neighbors.sol, :withdrawals))) / sum(getparametersolution(house, sol_neighbors.sol, :withdrawals)),
              (sum(recorded[:TO_GW] * 1383.) - sum(getparametersolution(house, sol_neighbors.sol, :waterfromgw))) / sum(getparametersolution(house, sol_neighbors.sol, :waterfromgw))])
