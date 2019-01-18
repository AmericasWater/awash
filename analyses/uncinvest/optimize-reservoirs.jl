#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/paleo-4scen.yml")
config["proportionnaturalflowforenvironment"] = .37

include("../../src/optimization-investment.jl")

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)

parlens = varlengths(house.model, house.paramcomps, house.parameters)
parends = cumsum(parlens)

increases = reshape(sol.sol[parends[3]+1:parends[4]], numreservoirs, numsteps)
decreases = reshape(sol.sol[parends[4]+1:parends[5]], numreservoirs, numsteps)

rcmax = convert(Vector{Float64}, reservoirdata[:MAXCAP])./1000 #data in cubic meters, change to 1000m3

ddf = DataFrame(cid=map((a, b) -> "$a.$b", reservoirdata[:collection], reservoirdata[:colid]),
                lat=reservoirdata[:lat], lon=reservoirdata[:lon],
                decrease=decreases[:,1], maxcap=reservoirdata[:MAXCAP])
writetable("decreases.csv", ddf)

sum(decreases[:,1] .!= rcmax)

cost_increase = house.f[parends[3]+1:parends[4]]
cost_decrease = house.f[parends[4]+1:parends[5]]

## Adjust the maintenance cost

result = DataFrame(scale=Float64[1], increase=Float64[sum(increases)], decrease=Float64[sum(decreases)], numdecs=Float64[sum(ddf[:decrease] .> 0)])
#result = DataFrame(scale=Float64[], increase=Float64[], decrease=Float64[])

for scale in [10, 4, 2, .5, .25, .1]
    maintenance = grad_reservoir_investcost_storagecapacitymax(m)
    inccosts = grad_reservoir_investcost_increasestorage(m)
    remcosts = grad_reservoir_investcost_reducestorage(m)
    inccosts.A *= scale
    remcosts.A *= scale
    setobjective!(house, -varsum(discounted(m, maintenance * grad_reservoir_storagecapacitymax_increasestorage(m), .03)) + -varsum(discounted(m, inccosts, .03)))
    setobjective!(house, -varsum(discounted(m, maintenance * grad_reservoir_storagecapacitymax_reducestorage(m), .03)) + -varsum(discounted(m, remcosts, .03)))
    sol = houseoptimize(house, solver)

    decreases = reshape(sol.sol[parends[4]+1:parends[5]], numreservoirs, numsteps)
    push!(result, [scale, sum(sol.sol[parends[3]+1:parends[4]]), sum(decreases), sum(decreases[:,1] .> 0)])
    println(result)
end

writetable("decrease-bycost.csv", result)
