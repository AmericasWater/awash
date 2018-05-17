#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/monthly-6scen.yml")
config["proportionnaturalflowforenvironment"] = .37

include("../../src/optimization-investment.jl")

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)

parlens = varlengths(house.model, house.paramcomps, house.parameters)
parends = cumsum(parlens)

captures = reshape(sol.sol[parends[3]+1:parends[4]], numreservoirs, numscenarios, numsteps)
capmaxs = maximum(maximum(cumsum(captures, 3), 3), 2)
#capstds = maximum(std(captures, 3), 2)

writetable("captures-monthly.csv", DataFrame(cid=map((a, b) -> "$a.$b", reservoirdata[:collection], reservoirdata[:colid]),
                                             lat=reservoirdata[:lat], lon=reservoirdata[:lon],
                                             capmaxs=vec(capmaxs), maxcap=reservoirdata[:MAXCAP]))

## Also get out the solution without reservoirs

include("../../src/optimization-given.jl")
house_nores = optimization_given(true, false)

sol_nores = houseoptimize(house_nores, solver)

gwextracts = reshape(sol.sol[parends[6]+1:parends[7]], numregions, numscenarios, numsteps)

parlens_nores = varlengths(house_nores.model, house_nores.paramcomps, house_nores.parameters)
parends_nores = cumsum(parlens_nores)

gwextracts_nores = reshape(sol_nores.sol[parends_nores[3]+1:parends_nores[4]], numregions, numscenarios, numsteps)


gwmaxs = maximum(sum(gwextracts_nores, 3), 2)
dgwmaxs = sum(maximum(gwextracts_nores - gwextracts, 2), 3)
dgwmins = sum(minimum(gwextracts_nores - gwextracts, 2), 3)

writetable("groundwater-monthly.csv", DataFrame(fips=masterregions[:fips], maxsums=vec(gwmaxs),
                                                summaxdiff=vec(dgwmaxs), summindiff=vec(dgwmins)))

# Reservoir with the most reservoir demand

gauge = findfirst(isreservoir .== 1449)
fips = draws[draws[:source] .== gauge, :fips][1]
canals = find(draws[:fips] .== fips)

inflows = addeds[1643, :, :] + addeds[14032, :, :] + addeds[gauge, :, :] - (recorded[recorded[:FIPS] .== 45063, :TO_To] + recorded[recorded[:FIPS] .== 45079, :TO_To])[1] * 1383. / 12 # Note: upstream counties have no choice but to use available SW

recorded = getfilteredtable("extraction/USGS-2010.csv")
demands = recorded[recorded[:FIPS] .== fips, :TO_To][1] * 1383. / 12

swextracts = reshape(sol.sol[parends[1]+1:parends[2]], numcanals, numscenarios, numsteps)
swextracts = sum(swextracts[canals, :, :], 1)

gwextracts = reshape(sol.sol[parends[6]+1:parends[7]], numregions, numscenarios, numsteps)

writetable("optimum-1449.csv", DataFrame(precip=vec(precip[findfirst(masterregions[:fips] .== "$fips"), :, :]),
                                         captures=vec(captures[1449, :, :]),
                                         inflows=vec(inflows),
                                         demands=repeat([demands], inner=6, outer=12),
                                         swextracts=vec(swextracts),
                                         gwextracts=vec(gwextracts[findfirst(masterregions[:fips] .== "$fips"), :, :]),
                                         month=repeat(collect(1:12), inner=6),
                                         scenario=repeat(collect(1:6), outer=12)))

