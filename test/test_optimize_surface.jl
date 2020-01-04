using Test

using DataFrames
using OptiMimi
using CSV

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year-state.yml")

include("../src/optimization-given.jl")

house = optimization_given(false)

using MathProgBase
using Clp
solver = ClpSolver()
# using Gurobi
# solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

# Save the results, if not available
varlens = varlengths(house.model, house.paramcomps, house.parameters, Dict(:quartersupersourcesupply => :supersourcesupply))
# varlengths(house.model, house.constcomps, house.constraints)


allparams = Symbol[]
allvalues = Float64[]
for ii in 1:length(house.parameters)
    if house.parameters[ii] in [:swwithdrawals]
        # Just include sum, since not completely constrained
        global allparams = [allparams; house.parameters[ii]]
        global allvalues = [allvalues; sum(sol.sol[sum([1; varlens[1:(ii-1)]]):sum(varlens[1:ii])])]
    else
        global allparams = [allparams; repeat([house.parameters[ii]], outer=[varlens[ii]])]
        global allvalues = [allvalues; sol.sol[sum([1; varlens[1:(ii-1)]]):sum(varlens[1:ii])]]
    end
end
alldf = DataFrame(parameter=allparams, value=allvalues)

outputpath = joinpath(dirname(@__FILE__), "../results/optimize-surface-test.csv")
if isfile(outputpath)
    compdf = CSV.read(outputpath)
    @test nrow(compdf) == nrow(alldf)
    mismatches = Int64[]
    for ii in 1:nrow(alldf)
        @test compdf[ii, :parameter] == string(alldf[ii, :parameter])
        if abs(compdf[ii, :value] - alldf[ii, :value]) / max(compdf[ii, :value], alldf[ii, :value]) > 0.1
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
    CSV.write(outputpath, alldf)
end

save_optimization_given(house, sol, false, true)
