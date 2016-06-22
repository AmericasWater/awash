# List every parameter and its options for being set
## Possible options:
## initialized constant (later: possible sources)
## default connection (later: possible connections)
## optimization constraint (later: possible optimizations)

include("model.jl")

using DataFrames
using StatsBase
import Mimi: CertainScalarParameter, UncertainScalarParameter

allvariables = []
allvariablescomponents = []
for component in model.components
    for variable in fieldnames(component[2].Variables)
        push!(allvariables, getfield(component[2].Variables, variable))
        push!(allvariablescomponents, component)
    end
end

df = DataFrame(component=[], parameter=[], initialized=[], connected=[], optimized=[])

for component in model.components
    for parameter in fieldnames(component[2].Parameters)
        initialized = "nope"
        connected = "nope"
        optimized = "nope"
        if in(string(component[1])*string(parameter), model.parameters_that_are_set)
            if !haskey(model.parameters, parameter)
                continue
            end

            p = model.parameters[parameter]
            if isa(p, CertainScalarParameter) || isa(p, UncertainScalarParameter)
                continue
            end

            if in(getfield(component[2].Parameters, parameter), allvariables)
                connected = allvariablescomponents[findfirst(allvariables, getfield(component[2].Parameters, parameter))][1]
            else
                # Check autocorrelation to see if identical or random
                ac = StatsBase.autocor(vec(model.parameters[parameter].values), [1])
                if (isnan(ac[1]))
                    initialized = "nan"
                elseif (ac[1] == 1)
                    initialized = "constant"
                elseif (ac[1] < .05)
                    initialized = "random"
                else
                    initialized = "provided"
                end
            end
        end

        push!(df, [component[1], parameter, initialized, connected, optimized])
    end
end

