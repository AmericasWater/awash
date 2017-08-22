include("../../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization

include("../../src/optimization-given.jl")
house = optimization_given(true);

using MathProgBase
using Gurobi
solver = GurobiSolver()

recorded = getfilteredtable("extraction/USGS-2010.csv")
centroids = readtable(datapath("mapping/US_county_2000-simple-latlon-centroids.csv"))
centroids[:fips] = round(Int64, centroids[:NHGISST] * 100 + centroids[:NHGISCTY] / 10)

radius = 100 # km

deg2rad(deg) = deg*pi/180

function distance(long0, lat0, longs, lats)
    long0 = deg2rad(long0)
    lat0 = deg2rad(lat0)
    longs = deg2rad(longs)
    lats = deg2rad(lats)

    R = 6371 # Earth mean radius [km]
    acos(sin(lat0)*sin(lats) + cos(lat0)*cos(lats) .* cos(longs-long0)) * R
end

function within_radius_fips(ii)
    fips = regionindex(masterregions, ii)

    # Find all within state within radius (NOTE: includes given fips)
    thiscounty = centroids[regionindex(centroids, :) .== fips, :]
    withinstate = centroids[centroids[:, :NHGISST] / 10 .== parse(Int64, fips) % 1000, :]
    nearby = withinstate[distance(thiscounty[1, :X], thiscounty[1, :Y], withinstate[:, :X], withinstate[:, :Y]) .<= radius, :]
    radiusfips = regionindex(nearby, :)

    # Also do all neighbors
    withinstate = filter(jj -> jj != 0 && masterregions[jj, :state] == masterregions[ii, :state], sourceiis[ii])
    neighbors = regionindex(masterregions, withinstate)

    unique([radiusfips; neighbors])
end

## Add constraints that sw_i* + sum_j sw_j* < sw_i + sum_j sw_j, so long as in same state
addconstraint!(house, :Allocation, :neighborbalance, :balance)

function genroom(A, tt)
    drawfips = regionindex(draws, :)
    for ii in 1:nrow(masterregions)
        includedfips = within_radius_fips(ii)
        includeddraw = Bool[fips in includedfips for fips in drawfips]

        A[ii, includeddraw] = 1
    end
end

room = roomintersect(house.model, :Allocation, :balance, :withdrawals, genroom)
setconstraint!(house, room_relabel(room, :balance, :Allocation, :neighborbalance))

function genhall(ii, tt)
    includedfips = within_radius_fips(ii)
    allfips = regionindex(masterregions, :)
    includedii = Int64[findfirst(allfips, fips) for fips in includedfips]

    return sum(recorded[includedii, :TO_SW]) * config["timestep"] * 1383. / 12
end

hall = hallsingle(house.model, :Allocation, :balance, genhall)
setconstraintoffset!(house, hall_relabel(hall, :balance, :Allocation, :neighborbalance))

@time sol_100km = houseoptimize(house, solver)
summarizeparameters(house, sol_100km.sol)

df = DataFrame(variable=[repmat(["withdrawals"], length(getparametersolution(house, sol_100km.sol, :withdrawals)));
                         repmat(["waterfromgw"], length(getparametersolution(house, sol_100km.sol, :waterfromgw)))],
               optimized=[getparametersolution(house, sol_100km.sol, :withdrawals);
                          getparametersolution(house, sol_100km.sol, :waterfromgw)])
writetable("radius-$radius.csv", df)
