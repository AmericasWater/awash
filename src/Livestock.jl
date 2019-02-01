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
end

"""
Just copy through
"""
function run_timestep(c::Livestock, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.demand_copy[rr, :, tt] = p.livestockdemand[rr, :, tt]
    end
end

"""
Add a Livestock component to the model.
"""
function initlivestock(m::Model)
    livestock = addcomponent(m, Livestock)

    recorded = knowndf("exogenous-withdrawals")
    livestock[:livestockdemand] = repeat(convert(Vector,recorded[:,:LI_To])*1383./12*config["timestep"], outer=[1, numscenarios, numsteps])

    livestock
end
