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

    outputs
end

include("world-minimal.jl")

clearslate()

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
sol, profile7 = resultandprofile(@timed houseoptimize(house, solver))

outputs3 = optimoutputs(house, sol)

result = DataFrame(
    group=[repeat(["load(optimization-given)", "optimization_given", "houseoptimize(given)", "load(model)", "run(model)", "load(optimization)", "houseoptimize(full)"], inner=length(keys(profile1))); repmat(["outputs.given"], length(outputs1)); repmat(["outputs.model"], length(outputs2)); repmat(["outputs.full"], length(outputs3))],
    task=[repmat([:profiling], 7 * length(keys(profile1))); repmat([:outputs], length(outputs1) + length(outputs2) + length(outputs3))],
                   variable=[collect(keys(profile1)); collect(keys(profile2)); collect(keys(profile3)); collect(keys(profile4)); collect(keys(profile5)); collect(keys(profile6)); collect(keys(profile7)); collect(keys(outputs1)); collect(keys(outputs2)); collect(keys(outputs3))],
                   value=[collect(values(profile1)); collect(values(profile2)); collect(values(profile3)); collect(values(profile4)); collect(values(profile5)); collect(values(profile6)); collect(values(profile7)); collect(values(outputs1)); collect(values(outputs2)); collect(values(outputs3))])

writetable("../results/diagnostic.csv", result)
