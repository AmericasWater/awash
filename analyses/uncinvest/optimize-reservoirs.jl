#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("lib/readconfig.jl")
config = readconfig("../configs/paleo-4scen.yml")

include("optimization-given.jl")
house = optimization_given(true, withreservoirs, model)

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)

