## Livestock Component
#
# Currently assumes that livestock water demands are exogenously
# provided.

using Mimi
using DataFrames

@defcomp Livestock begin
    regions = Index()

    # Exogenous demands
    livestockdemand = Parameter(index=[regions, time], unit="1000 m^3")

    # Copy through
    demand_copy = Variable(index=[regions, time], unit="1000 m^3")
end

"""
Just copy through
"""
function run_timestep(c::Livestock, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.demand_copy[rr, tt] = p.livestockdemand[rr, tt]
    end
end

"""
Add a Livestock component to the model.
"""
function initlivestock(m::Model)
    livestock = addcomponent(m, Livestock)

    recorded = getfilteredtable("extraction/USGS-2010.csv")
    livestock[:livestockdemand] = repeat(convert(Vector,recorded[:,:LI_To])*1383./12*config["timestep"], outer=[1, numsteps])

    livestock
end
