# The thermoelectric component

using Mimi
using DataFrames

@defcomp Thermoelectric begin
    regions = Index()
    crops = Index()

    # Exogenous demands
    demand = Parameter(index=[regions, time], unit="1000 m^3")

    # Copy through
    demand_copy = Variable(index=[regions, time], unit="1000 m^3")
end

"""
Just copy through
"""
function run_timestep(c::Thermoelectric, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.demand_copy[rr, tt] = p.demand[rr, tt]
    end
end

"""
Add a Thermoelectric component to the model.
"""
function initthermoelectric(m::Model)
    thermoelectric = addcomponent(m, Thermoelectric)

    recorded = readtable("../data/extraction/USGS-2010.csv")
    thermoelectric[:demand] = repeat(convert(Vector, recorded[:, :PT_To] * 1382592. / (1000. * config["timestep"])), outer=[1, numsteps])

    thermoelectric
end
