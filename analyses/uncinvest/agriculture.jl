using Gurobi
solver = GurobiSolver()

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/paleo-4scen.yml")

include("../../src/optimization-producer.jl")
sol = houseoptimize(house, solver)
