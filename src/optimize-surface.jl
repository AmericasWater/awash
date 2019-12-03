## Perform Optimization with known demands
#
# Optimize a model from `optimization-given` with only surface waters.

#### Determine the gauge-level surface extractions that reproduce observed flows at minimum cost

include("lib/readconfig.jl")
if !(@isdefined config)
    ##config = readconfig("../configs/single.yml") # Just use 1 year for optimization
    config = readconfig("../configs/standard-1yearmonthly.yml")
end

if "rescap" in keys(config) && config["rescap"] == "zero"
	allowreservoirs = false
else
	allowreservoirs = true
end

include("optimization-given.jl")
house = optimization_given(false, allowreservoirs)

serialize(open(datapath("fullhouse$suffix.jld"), "w"), house)

using MathProgBase
using Clp
solver = ClpSolver()

@time sol = houseoptimize(house, solver)

summarizeparameters(house, sol.sol)

# Look at the constraints: only possible for small models
#constdf = constraining(house, sol.sol)

# Save the results
save_optimization_given(house, sol, false, allowreservoirs)
