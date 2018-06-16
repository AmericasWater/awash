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
    environmentaldemand[:flowrequirementfactor] = get(config, "proportionnaturalflowforenvironment", 0.)

    environmentaldemand
end

function constraintoffset_environmentalflows(m::Model)
    b = copy(addeds) # Start with direct added

    # Propogate in downstream order
    for hh in 1:numgauges
        gg = vertex_index(downstreamorder[hh])
        gauge = downstreamorder[hh].label
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            b[gg, :, :] += .99 * b[vertex_index(upstream, waternet), :, :]
        end
    end

    function generate(gg, ss, tt)
        (config["proportionnaturalflowforenvironment"])*b[gg, ss, tt]
    end

    hallsingle(m, :WaterNetwork, :outflows, generate)
end
