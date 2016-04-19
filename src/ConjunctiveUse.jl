# The Conjunctive Use component
#
# Combines all of the sources of water demand, and determines the
# conjunctive use division between surface water and groundwater.

using Mimi
using DataFrames

@defcomp ConjunctiveUse begin
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
function timestep(c::ConjunctiveUse, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        # Sum all demands
        v.totaldemand[rr, tt] = p.totalirrigation[rr, tt] + p.domesticuse[rr, tt]
    end
end

"""
Add a ConjunctiveUse component to the model.
"""
function initconjunctiveuse(m::Model)
    conjunctiveuse = addcomponent(m, ConjunctiveUse);

    # Set optimized parameters to 0
    conjunctiveuse[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time])

    conjunctiveuse
end

function grad_conjunctiveuse_swbalance_totalirrigation(m::Model)
    roomdiagonal(m, :ConjunctiveUse, :swbalance, :totalirrigation, (rr, tt) -> 1.)
end

