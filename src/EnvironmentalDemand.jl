## Environmental Water Demand Component

using Mimi
using DataFrames

@defcomp EnvironmentalDemand begin
    regions = Index()
    gauges = Index()

    flowrequirementfactor = Parameter(unit="")
    naturalflow = Parameter(index=[gauges, scenarios, time],unit="1000 m^3")
    minenvironmentalflow = Variable(index=[gauges, scenarios, time],unit="1000 m^3")
end

"""
The quantity of water demanded at each timestep
"""
function run_timestep(c::EnvironmentalDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for gg in d.gauges
        v.minenvironmentalflow[gg, :, tt] = p.flowrequirementfactor * p.naturalflow[gg, :, tt];
    end
end

"""
Add an urban component to the model.
"""
function initenvrionmentaldemand(m::Model)
    environmentaldemand = addcomponent(m, EnvironmentalDemand);
    # set according to config file

    if get(config, "proportionnaturalflowforenvironment", nothing) == nothing
        environmentaldemand[:flowrequirementfactor] = 0.
    else
        environmentaldemand[:flowrequirementfactor] = config["proportionnaturalflowforenvironment"]
    end

    environmentaldemand
end

#function constraintoffset_environmentalflow(m::Model)
#    gen(rr, tt) = m.external_parameters[:naturalflow].values[gg, tt] * m.external_parameters[:flowrequirementfactor].values[]
#    hallsingle(m, :EnvironmentalDemand, :minenvironmentalflow, gen)
#end
