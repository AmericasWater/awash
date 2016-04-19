# The Water Demand component
#
# Combines all of the sources of water demand.

using Mimi
using DataFrames

@defcomp WaterDemand begin
    regions = Index()

    # External
    # Irrigation water (1000 m^3)
    totalirrigation = Parameter(index=[regions, time])
    # Combined water use for domestic sinks (1000 m^3)
    domesticuse = Parameter(index=[regions, time])

    # Internal
    # Total water demand (1000 m^3)
    totaldemand = Variable(index=[regions, time])
end

"""
Compute the amount extracted and the cost for doing it.
"""
function timestep(c::WaterDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        # Sum all demands
        v.totaldemand[rr, tt] = p.totalirrigation[rr, tt] + p.domesticuse[rr, tt]
    end
end

"""
Add a WaterDemand component to the model.
"""
function initwaterdemand(m::Model)
    waterdemand = addcomponent(m, WaterDemand);

    # Set optimized parameters to 0
    waterdemand[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time])

    waterdemand
end

function grad_waterdemand_swbalance_totalirrigation(m::Model)
    roomdiagonal(m, :WaterDemand, :swbalance, :totalirrigation, (rr, tt) -> 1.)
end

