#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("lib/readconfig.jl")
if !isdefined(:config)
    #config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization
    config = readconfig("../configs/complete-5year.yml")
end

withreservoirs = false

# Run the water demand simulation to determine values
include("model-waterdemand.jl")

println("Running model...")
@time run(model)

include("optimization-given.jl")
house = optimization_given(true, withreservoirs, model)

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
varlens = varlengths(house.model, house.paramcomps, house.parameters)

serialize(open(datapath("extraction/withdrawals$suffix.jld"), "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
serialize(open(datapath("extraction/returns$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numsteps))
serialize(open(datapath("extraction/waterfromgw$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numcounties, numsteps))
if withreservoirs
    serialize(open(datapath("extraction/captures$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:4])+1:end], numreservoirs, numsteps))
elseif isfile(datapath("extraction/captures$suffix.jld"))
    rm(datapath("extraction/captures$suffix.jld"))
end

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
