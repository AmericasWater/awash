# The Water Demand component
#
# Combines all of the sources of water demand.

using Mimi
using DataFrames

@defcomp WaterDemand begin
    regions = Index()

    # External
    # Irrigation water (1000 m^3)
    totalirrigation = Parameter(index=[regions, time], units="1000 m^3")
    # Combined water use for domestic sinks (1000 m^3)
    domesticuse = Parameter(index=[regions, time], units="1000 m^3")
    industrialuse = Parameter(index=[regions,time],units="1000 m^3")
    urbanuse = Parameter(index=[regions,time], units="1000 m^3")

    # Internal
    # Total water demand (1000 m^3)
    totaldemand = Variable(index=[regions, time], units="1000 m^3")
end

"""
Compute the amount extracted and the cost for doing it.
"""
function timestep(c::WaterDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

        v.totaldemand[:, tt] = p.totalirrigation[:, tt] + p.domesticuse[:, tt] + p.industrialuse[:, tt] + p.urbanuse[:, tt];
end

"""
Add a WaterDemand component to the model.
"""
function initwaterdemand(m::Model)
    waterdemand = addcomponent(m, WaterDemand);

    # Set optimized parameters to 0

    #waterdemand[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    #waterdemand[:industrialuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    #waterdemand[:urbanuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    #waterdemand[:domesticuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time])
   
    waterdemand[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:industrialuse] = readdlm("../data/INWFrTo.txt") + readdlm("../data/MIWFrTo.txt");
    waterdemand[:urbanuse] = readdlm("../data/PSdem.txt");
    waterdemand[:domesticuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time])


    waterdemand
end

function grad_waterdemand_swbalance_totalirrigation(m::Model)
    roomdiagonal(m, :WaterDemand, :swbalance, :totalirrigation, (rr, tt) -> 1.)
end

