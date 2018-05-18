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

increases = reshape(sol.sol[parends[4]+1:parends[5]], numreservoirs, numsteps)
decreases = reshape(sol.sol[parends[5]+1:parends[6]], numreservoirs, numsteps)

rcmax = convert(Vector{Float64}, reservoirdata[:MAXCAP])./1000 #data in cubic meters, change to 1000m3

decreases .== rcmax

cost_increase = house.f[parends[4]+1:parends[5]]
cost_decrease = house.f[parends[5]+1:parends[6]]

## Adjust the maintenance cost

result = DataFrame(scale=Float64[], decrease=Float64[])

for scale in [1e-7, 1e-8] #[1e-6, 1e-5] #1e-4, 1e-3] #[0, .01, .1, 1]
    maintenance = grad_reservoir_investcost_storagecapacitymax(m)
    maintenance.A *= scale
    setobjective!(house, -varsum(discounted(m, maintenance * grad_reservoir_storagecapacitymax_reducestorage(m), .03)) + -varsum(discounted(m, grad_reservoir_investcost_reducestorage(m), .03)))
    sol = houseoptimize(house, solver)
    push!(result, [scale, sum(sol.sol[parends[5]+1:parends[6]])])
end

writetable("decrease-bycost.csv", result)
