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

decreases = reshape(decreases, numreservoirs, numsteps)

## Adjust the cost of removing reservoirs

cost_increase = house.f[parends[4]+1:parends[5]]
cost_decrease = house.f[parends[5]+1:parends[6]]

result = []
for scale in [0, .01, .1, 1]
    house.f[parends[5]+1:parends[6]] = cost_decrease * scale
    sol = houseoptimize(house, solver)
    append!(result, sum(sol.sol[parends[5]+1:parends[6]]))
end
