## Thermoelectric Cooling Component
#
# Currently assumes that cooling water demands are exogenously
# defined.

using Mimi
using DataFrames
include("lib/datastore.jl")

@defcomp Thermoelectric begin
    regions = Index()
    scenarios = Index()

    # Exogenous demands
    thermodemand = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    # Copy through
    demand_copy = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    """
    Just copy through
    """
    function run_timestep(p, v, d, t)
        for rr in d.regions
            v.demand_copy[rr, :, tt] = p.thermodemand[rr, :, tt]
        end
    end
end

"""
Add a Thermoelectric component to the model.
"""
function initthermoelectric(m::Model)
    thermoelectric = add_comp!(m, Thermoelectric)

    recorded = knowndf("exogenous-withdrawals")
    thermoelectric[:thermodemand] = repeat(convert(Vector, recorded[:, :PT_To]) * 1383. / 12. * config["timestep"], outer=[1, numscenarios, numsteps])

    thermoelectric
end
