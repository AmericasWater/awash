using OptiMimi
using MathProgBase
using Gurobi

include("lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml")

solver = GurobiSolver()

function resultandprofile(values)
    result = values[1]
    profile = Dict{Symbol, Float64}()
    profile[:elapsed] = values[2]
    profile[:allocated] = values[3]
    profile[:garbage] = values[4]

    result, profile
end

function optimoutputs(house, sol)
    varlens = varlengths(house.model, house.paramcomps, house.parameters)
    outputs = Dict{Symbol, Float64}()
    for ii in 1:length(house.parameters)
        index1 = sum(varlens[1:ii-1]) + 1
        index2 = sum(varlens[1:ii])

        values = sol.sol[index1:index2]

        outputs[house.parameters[ii]] = sum(values)
    end
end

include("world-minimal.jl")

rm(datapath("extraction/withdrawals$suffix.jld"), force=true)
rm(datapath("extraction/returns$suffix.jld"), force=true)
rm(datapath("extraction/waterfromgw$suffix.jld"), force=true)
rm(datapath("extraction/captures$suffix.jld"), force=true)
rm(cachepath("partialhouse2$suffix.jld"), force=true)
rm(cachepath("partialhouse$suffix.jld"), force=true)
rm(cachepath("partialhouse-gror$suffix.jld"), force=true)

## Optimize canal usage
ignore, profile1 = resultandprofile(@timed include("optimization-given.jl"))
house, profile2 = resultandprofile(@timed optimization_given(false, false))
sol, profile3 = resultandprofile(@timed houseoptimize(house, solver))

save_optimization_given(house, sol, false, false)

outputs1 = optimoutputs(house, sol)

## Run the simulation
ignore, profile4 = resultandprofile(@timed include("model.jl"))
ignore, profile5 = resultandprofile(@timed run(model))

outputs2 = Dict{Symbol, Float64}()
outputs2[:waterallocated] = sum(model[:Allocation, :waterallocated])

## Run the full optimization
ignore, profile6 = resultandprofile(@timed include("optimization.jl"))
sol, profile7 = resultandprofile(@timed linprog(-house.f, house.A, '<', house.b, house.lowers, house.uppers))

outputs3 = optimoutputs(house, sol)

result = DataFrame(group=[repmat([:profiling], 7 * length(keys(profile))); repmat([:outputs], length(outputs1) + length(outputs2) + length(outputs3))],
                   variable=[keys(profile1); keys(profile2); keys(profile3); keys(profile4); keys(profile5); keys(profile6); keys(profile7); keys(outputs1); keys(outputs2); keys(outputs3)],
                   value=[values(profile1); values(profile2); values(profile3); values(profile4); values(profile5); values(profile6); values(profile7); values(outputs1); values(outputs2); values(outputs3)])

writetable("../results/diagnostic.csv", result)
