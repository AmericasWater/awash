## Livestock Component
#
# Currently assumes that livestock water demands are exogenously
# provided.

using Mimi
using DataFrames

@defcomp Livestock begin
    regions = Index()
    scenarios = Index()

    # Exogenous demands
    livestockdemand = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    # Copy through
    demand_copy = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    """
    Just copy through
    """
    function run_timestep(p, v, d, tt)
        for rr in d.regions
            v.demand_copy[rr, :, tt] = p.livestockdemand[rr, :, tt]
        end
    end
end

"""
Add a Livestock component to the model.
"""
function initlivestock(m::Model)
    livestock = add_comp!(m, Livestock)

    recorded = knowndf("exogenous-withdrawals")
    livestock[:livestockdemand] = repeat(convert(Vector,recorded[:,:LI_To])*1383. / 12*config["timestep"], outer=[1, numscenarios, numsteps])

    livestock
end
