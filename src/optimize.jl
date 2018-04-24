## Perform Optimization with endogenous demands
#
# Optimize a model from `optimization`, with endogenous water demands.

using Mimi
using OptiMimi
include("lib/readconfig.jl")
include("lib/datastore.jl")

config = readconfig("../configs/standard-1year.yml")

suffix = getsuffix()

if config["cst"]=="true"
    include("optimization_cst.jl")
else
    include ("optimization.jl")
end

using MathProgBase
@time sol = linprog(-house.f, house.A, '<', house.b, house.lowers, house.uppers)

analysis = nothing

if analysis == :shadowcost
    varlens = varlengths(m, house.constcomps, house.constraints)
    lambdas = sol.attrs[:lambda][sum(varlens[1:2])+1:sum(varlens[1:3])]
    lambdas = reshape(lambdas, (3109, 2))
    df = convert(DataFrame, lambdas)
    df[:fips] = map(x -> parse(Int64, x), masterregions[:fips])
    writetable("../results/shadowprice.csv", df)
    usmap(DataFrame(fips=df[:fips], value=df[:x1]))
elseif analysis == :debug
    coning = constraining(house, convert(Vector{Float64}, sol.sol))

    rdf = DataFrame(fips=masterregions[:fips]);
    cdf = DataFrame(fips=repmat(masterregions[:fips], numallcrops), crop=vec(repeat(allcrops, inner=[numcounties, 1])));

    # Look at parameter values
    varlens = varlengths(m, house.paramcomps, house.parameters)
    for ii in 1:length(house.parameters)
        println(house.parameters[ii])
        index1 = sum(varlens[1:ii-1]) + 1
        index2 = sum(varlens[1:ii])

        values = sol.sol[index1:index2]

        if varlens[ii] == nrow(rdf)
            rdf[house.parameters[ii]] = values
        elseif varlens[ii] == nrow(cdf)
            cdf[house.parameters[ii]] = values
        else
            #println("Cannot store: $(varlens[ii])")
        end

        if (sum(values .!= 0) == 0)
            println("All zero.")
        else
            println(values[1:min(100, index2 - index1 + 1)])
            println("Sum: $(sum(values))")
        end
    end


    # Get constraint values
    constvalues = house.A * sol.sol

    varlens = varlengths(m, house.constcomps, house.constraints)
    for ii in 1:length(house.constraints)
        println(house.constraints[ii])
        index1 = sum(varlens[1:ii-1]) + 1
        index2 = sum(varlens[1:ii])

        values = constvalues[index1:index2]

        if varlens[ii] == nrow(rdf)
            rdf[house.constraints[ii]] = values
        elseif varlens[ii] == nrow(cdf)
            cdf[house.constraints[ii]] = values
        else
            #println("Cannot store: $(varlens[ii])")
        end

        if (sum(values .!= 0) == 0)
            println("All zero.")
        else
            println(values[1:min(100, index2 - index1 + 1)])
        end
    end

    varlens = varlengths(m, house.paramcomps, house.parameters)

    if config["filterstate"] == "08"
        serialize(open(datapath("extraction/waterfromgw$suffix.jld"), "w"), reshape(sol.sol[1:sum(varlens[1])], numcounties, numsteps))
        serialize(open(datapath("extraction/withdrawals$suffix.jld"), "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
        serialize(open(datapath("extraction/totalareas_cst$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcounties,8))
        serialize(open(datapath("extraction/returns$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numcanals, numsteps))
    end

    writetable("../results/regionout.csv", rdf)
    writetable("../results/cropsout.csv", cdf)
    print("Total production")
    println(round(constvalues[sum(varlens[1:(end-1)])+1:end]))

end

