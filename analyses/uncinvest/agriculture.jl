include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/paleo-4scen.yml")

include("../../src/optimization.jl")
sol = houseoptimize(house, solver)
