# The consumption component
#
# Each region has an `demand`, and compares this to the amount of `marketed`
# resource.  The result is a `surplus`, which may be negative if `marketed` <
# `demand`.

using Mimi
using Distributions

@defcomp Consumption begin
    regions = Index()

    # Internal
    # Resource demands
    demand = Parameter(index=[regions, time])

    # External
    # Resource availability from Economy
    marketed = Parameter(index=[regions, time])

    # Resource surplus over (or below) demand
    surplus = Variable(index=[regions, time])
end

"""
Compute the `surplus` as `marketed` - `demand`.
"""
function timestep(c::Consumption, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.surplus[rr, tt] = p.marketed[rr, tt] - p.demand[rr, tt]
    end
end

"""
Add a consumption component to the model.
"""
function initconsumption(m::Model)
    consumption = addcomponent(m, Consumption)

    # Use random demands, from a LogNormal distribution and constant across all
    # time.
    consumption[:demand] = repeat(asmynumeric(rand(LogNormal(log(1000.0), log(10.0)), m.indices_counts[:regions])), outer=[1, m.indices_counts[:time]]);

    consumption
end
