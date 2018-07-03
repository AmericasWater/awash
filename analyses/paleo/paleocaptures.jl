include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/paleo-10year.yml")

include("../../src/optimization-given.jl")
redogwwo = true
house = optimization_given(true, true)

using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)
