#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/monthly-6scen.yml")
using MathProgBase
using Gurobi
solver = GurobiSolver()

for envflowreq in [.37, .50]
    config["proportionnaturalflowforenvironment"] = envflowreq

    include("../../src/optimization-investment.jl")

    sol = houseoptimize(house, solver)

    summarizeparameters(house, sol.sol)

    parlens = varlengths(house.model, house.paramcomps, house.parameters)
    parends = cumsum(parlens)

    captures = reshape(sol.sol[parends[2]+1:parends[3]], numreservoirs, numscenarios, numsteps)[:, :, 13:24]
    capmaxs = maximum(maximum(cumsum(captures, 3), 3), 2) # maximum storage over year and scenario
    #capstds = maximum(std(captures, 3), 2)

    writetable("captures-monthly-$(envflowreq*100).csv", DataFrame(cid=map((a, b) -> "$a.$b", reservoirdata[:collection], reservoirdata[:colid]),
                                                                   lat=reservoirdata[:lat], lon=reservoirdata[:lon],
                                                                   capmaxs=vec(capmaxs), maxcap=reservoirdata[:MAXCAP]))

    ## Also get out the solution without reservoirs

    include("../../src/optimization-given.jl")
    house_nores = optimization_given(true, false)

    sol_nores = houseoptimize(house_nores, solver)

    gwextracts = reshape(sol.sol[parends[5]+1:parends[6]], numregions, numscenarios, numsteps)[:, :, 13:24]

    parlens_nores = varlengths(house_nores.model, house_nores.paramcomps, house_nores.parameters)
    parends_nores = cumsum(parlens_nores)

    gwextracts_nores = reshape(sol_nores.sol[parends_nores[2]+1:parends_nores[3]], numregions, numscenarios, numsteps)[:, :, 13:24]

    gwmaxs_nores = maximum(sum(gwextracts_nores, 3), 2)
    gwmaxs = maximum(sum(gwextracts, 3), 2)
    dgwmaxs = sum(maximum(gwextracts_nores - gwextracts, 2), 3)
    dgwmins = sum(minimum(gwextracts_nores - gwextracts, 2), 3)

    writetable("groundwater-monthly-$(envflowreq*100).csv", DataFrame(fips=masterregions[:fips], maxsums=vec(gwmaxs_nores), maxsums_res=vec(gwmaxs),
                                                                      summaxdiff=vec(dgwmaxs), summindiff=vec(dgwmins)))
end

# Understand ability to satisfy demands of 16081

gwmaxs[masterregions[:fips] .== "16081"] # Expect 0

# How many nodes feed me? --> Just two local ones
draws[draws[:fips] .== 16081, :] # These end up being the only ones
netdata[.!isna.(netdata[:nextpt]) .& (netdata[:nextpt] .== findfirst(netdata[:cid] .== "usgs.13052200")), :]
netdata[.!isna.(netdata[:nextpt]) .& (netdata[:nextpt] .== findfirst(netdata[:cid] .== "junction.16750-up")), :]
allrows = [findfirst(waternetwork2[:gaugeid] .== "usgs.13052200"), findfirst(waternetwork2[:gaugeid] .== "junction.16750-up")]

# How much water available in those? --> about 4k
addeds[allrows, :, :]

# How much do we need? --> about 20k
recorded = getfilteredtable("extraction/USGS-2010.csv")
recorded[recorded[:FIPS] .== 16081, :TO_To][1] * 1383. / 12 # Compare to this

# What is the result of the balance constraint? --> Exactly meets it
balsol = getconstraintsolution(house_nores, sol_nores, :balance)
balsol = reshape(balsol, numregions, numscenarios, numsteps)

ii = findfirst(masterregions[:fips] .== "16081")
balsol[ii, :, :]

varlens = varlengths(house_nores.model, house_nores.constcomps, house_nores.constraints)
varlens = cumsum(varlens)

xx = sub2ind((numregions, numscenarios, numsteps), ii, 1, 1)
house_nores.A[varlens[1] + xx, :]

parlens_nores = varlengths(house_nores.model, house_nores.paramcomps, house_nores.parameters)
parends_nores = cumsum(parlens_nores)

# Connected to SS, GW, and 453625:453626 = withdrawals 5929:5930
ind2sub((numcanals, numscenarios, numsteps), 5929)
# draws[5929, :] --> correct

# How much is withdrawn? --> All from the 5929
sol.sol[parends_nores[1] + (5929:5930)]

# What constraints withdrawals on 5929 hit? --> a lot
house_nores.A[:, parends_nores[1] + 5929]

# What does the constraint on that gauge look like? --> -27637.188847500005
outsol = getconstraintsolution(house_nores, sol_nores, :outflows)
outsol = reshape(outsol, numgauges, numscenarios, numsteps)
gg = findfirst(gaugeorder .== draws[5929, :gaugeid])
outsol[gg, 1, 1]

# What does the offset look like? --> 8734.665808572945
reshape(cwro.f, numgauges, numscenarios, numsteps)[gg, 1, 1]

# What drives against that constraint? --> 453625, 453626, -3856634 = canal 5929, 5930, return 5930
house_nores.A[gg, :]

sol_nores.sol[[453625, 453626, 3856634]]
## BINGO!  Returning twice what I withdrew: Look at return

# What is the constraint solution on returnbalance? --> 48419.068847500006
retsol = getconstraintsolution(house_nores, sol_nores, :returnbalance)
retsol = reshape(retsol, numregions, numscenarios, numsteps)
retsol[ii, 1, 1]

# What do I have to drive it?  --> 3856633, 3856634 = canal 5929, 5930
house_nores.A[varlens[2] + ii, :]
sol_nores.sol[[3856633, 3856634]] # all on second




## CURIOUS:
# - junction.16750-up has no upstream nodes
# - addeds does not match outflow constraint


# Reservoir with the most reservoir demand

gauge = findfirst(isreservoir .== 1449)
fips = draws[draws[:source] .== gauge, :fips][1]
canals = find(draws[:fips] .== fips)

inflows = addeds[1643, :, :] + addeds[14032, :, :] + addeds[gauge, :, :] - (recorded[recorded[:FIPS] .== 45063, :TO_To] + recorded[recorded[:FIPS] .== 45079, :TO_To])[1] * 1383. / 12 # Note: upstream counties have no choice but to use available SW

recorded = getfilteredtable("extraction/USGS-2010.csv")
demands = recorded[recorded[:FIPS] .== fips, :TO_To][1] * 1383. / 12

swextracts = reshape(sol.sol[parends[1]+1:parends[2]], numcanals, numscenarios, numsteps)[:, :, 13:24]
swextracts = sum(swextracts[canals, :, :], 1)

gwextracts = reshape(sol.sol[parends[6]+1:parends[7]], numregions, numscenarios, numsteps)[:, :, 13:24]

writetable("optimum-1449.csv", DataFrame(precip=vec(precip[findfirst(masterregions[:fips] .== "$fips"), :, :]),
                                         captures=vec(captures[1449, :, :]),
                                         inflows=vec(inflows),
                                         demands=repeat([demands], inner=6, outer=12),
                                         swextracts=vec(swextracts),
                                         gwextracts=vec(gwextracts[findfirst(masterregions[:fips] .== "$fips"), :, :]),
                                         month=repeat(collect(1:12), inner=6),
                                         scenario=repeat(collect(1:6), outer=12)))

