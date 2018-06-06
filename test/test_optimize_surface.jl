using Base.Test

using DataArrays
using DataFrames
using OptiMimi

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year-state.yml")

include("../src/optimization-given.jl")

house = optimization_given(false)

using MathProgBase
using Clp
solver = ClpSolver()

@time sol = houseoptimize(house, solver)

# Save the results, if not available
varlens = varlengths(house.model, house.paramcomps, house.parameters)

allparams = Symbol[]
allvalues = Float64[]
for ii in 1:length(house.parameters)
    if house.parameters[ii] in [:withdrawals, :returns]
        # Just include sum, since not completely constrained
        allparams = [allparams; house.parameters[ii]]
        allvalues = [allvalues; sum(sol.sol[sum([1; varlens[1:(ii-1)]]):sum(varlens[1:ii])])]
    else
        allparams = [allparams; repeat([house.parameters[ii]], outer=[varlens[ii]])]
        allvalues = [allvalues; sol.sol[sum([1; varlens[1:(ii-1)]]):sum(varlens[1:ii])]]
    end
end
alldf = DataFrame(parameter=allparams, value=allvalues)

outputpath = joinpath(dirname(@__FILE__), "../results/optimize-surface-test.csv")
if isfile(outputpath)
    compdf = readtable(outputpath)
    @test nrow(compdf) == nrow(alldf)
    mismatches = Int64[]
    for ii in 1:nrow(alldf)
        @test compdf[ii, :parameter] == string(alldf[ii, :parameter])
        if abs(compdf[ii, :value] - alldf[ii, :value]) / max(compdf[ii, :value], alldf[ii, :value]) > 0.01
            push!(mismatches, ii)
        end
    end

    if length(mismatches) > 0
        println(mismatches)
        println(alldf[mismatches, :])
        println(compdf[mismatches, :])
    end
    @test length(mismatches) == 0
else
    writetable(outputpath, alldf)
end

if !isfile(datapath("extraction/withdrawals$suffix.jld"))
    serialize(open(datapath("extraction/withdrawals$suffix.jld"), "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numsteps))
end
if !isfile(datapath("extraction/captures$suffix.jld"))
    serialize(open(datapath("extraction/captures$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:2])+1:end], numreservoirs, numsteps))
end
