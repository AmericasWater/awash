include("../../src/lib/readconfig.jl")
config = readconfig("../configs/complete-yearly.yml")

include("../../src/optimization-given.jl")
house = optimization_given(true, false);

using MathProgBase
using Gurobi
solver = GurobiSolver()

recorded = getfilteredtable("extraction/USGS-2010.csv")
centroids = readtable(datapath("mapping/US_county_2000-simple-latlon-centroids.csv"))
centroids[:fips] = round(Int64, centroids[:NHGISST] * 100 + centroids[:NHGISCTY] / 10)

## Add constraints that sw_i* < sw_i
addconstraint!(house, :Allocation, :neighborbalance, :balance)

function genroom(A)
    # Fill in COUNTIES x CANALS matrix
    for pp in 1:nrow(draws)
        rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
        if rr > 0
            A[rr, pp] = 1.
        end
    end
end

room = roomintersect(house.model, :Allocation, :balance, :withdrawals, genroom, [:time], [:time])
setconstraint!(house, room_relabel(room, :balance, :Allocation, :neighborbalance))

function genhall(ii)
    return recorded[ii, :TO_SW] * config["timestep"] * 1383. / 12
end

hall = hallsingle(house.model, :Allocation, :balance, genhall, [:time])
setconstraintoffset!(house, hall_relabel(hall, :balance, :Allocation, :neighborbalance))

@time sol_distance = houseoptimize(house, solver)
summarizeparameters(house, sol_distance.sol)

df = DataFrame(variable=[repmat(["withdrawals"], length(getparametersolution(house, sol_distance.sol, :withdrawals)));
                         repmat(["waterfromgw"], length(getparametersolution(house, sol_distance.sol, :waterfromgw)))],
               optimized=[getparametersolution(house, sol_distance.sol, :withdrawals);
                          getparametersolution(house, sol_distance.sol, :waterfromgw)])
writetable("radius-single.csv", df)
