#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/paleo-4scen.yml")

include("../../src/optimization-investment.jl")

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)

