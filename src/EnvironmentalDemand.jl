## Environmental Water Demand Component

using Mimi
using DataFrames

@defcomp EnvironmentalDemand begin
    regions = Index()
    gauges = Index()

    flowrequirementfactor = Parameter(unit="")
    naturalflow = Parameter(index=[gauges, time],unit="1000 m^3")
    minenvironmentalflow = Variable(index=[gauges, time],unit="1000 m^3")
    environmentaldemand = Variable(index=[regions, time],unit="1000 m^3")
end

"""
The quantity of water demanded at each timestep
"""
function run_timestep(c::UrbanDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    v.environmentaldemand[:, tt] <- zeros(numregions);
    for gg in d.gauges
        v.minenvironmentalflow[gg, tt] = p.flowrequirementfactor * p.naturalflow[gg, tt];
    end
end

"""
Add an urban component to the model.
"""
function initenvrionmentaldemand(m::Model)
    environmentaldemand = addcomponent(m, EnvironmentalDemand);
    # set according to config file
    environmentaldemand[:flowrequirementfactor] = config["proportionnaturalflowforenvironment"]

    environmentaldemand
end

function constraintoffset_environmentalflow(m::Model)
    gen(rr, tt) = m.external_parameters[:naturalflow].values[gg, tt] * m.external_parameters[:flowrequirementfactor].values[]
    hallsingle(m, :EnvironmentalDemand, :minenvironmentalflow, gen)
end
