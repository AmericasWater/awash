## Perform Optimization with known demands
#
# Optimize a model from `optimization-given` with both surface and
# groundwater.

#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("lib/readconfig.jl")
if !(@isdefined config)
    config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization
end

if "rescap" in keys(config) && config["rescap"] == "zero"
	withreservoirs = false
else
	withreservoirs = true
end


# Run the water demand simulation to determine values
if get(config, "demandmodel", nothing) == "USGS"
    include("optimization-given.jl")
    house = optimization_given(true, withreservoirs, nothing, get(config, "waterrightconst", nothing))
else
    include("model-waterdemand.jl")
    println("Running demand model...")
    @time run(model)
    include("optimization-given.jl")
    house = optimization_given(true, withreservoirs, model)
end

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

# If model is infeasible, figure out what's causing that
#topbot = findinfeasiblepair(house, solver)
#sol = linprog(-house.f, house.A[1:topbot[1],:], '<', house.b[1:topbot[1]], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[1:topbot[1]-1,:], '<', house.b[1:topbot[1]-1], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[topbot[2]:end,:], '<', house.b[topbot[2]:end], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[topbot[2]+1:end,:], '<', house.b[topbot[2]+1:end], house.lowers, house.uppers, solver)

summarizeparameters(house, sol.sol)

# Look at the constraints: only possible for small models
#constraining(house, sol.sol)

# Save the results
save_optimization_given(house, sol, allowgw=true, allowreservoirs=withreservoirs)

analysis = nothing

if analysis == :shadowcost
    varlens = varlengths(m, house.constcomps, house.constraints)
    lambdas = sol.attrs[:lambda][sum(varlens[1])+1:sum(varlens[1:2])]
    lambdas = reshape(lambdas, (3109, 2))
    df = convert(DataFrame, lambdas)
    df[:fips] = map(x -> parse(Int64, x), masterregions[:fips])
    writetable("../results/shadowprice-alloc.csv", df)
    usmap(DataFrame(fips=df[:fips], value=df[:x1]))
end
