# The thermoelectric component

using Mimi
using DataFrames
include("lib/datastore.jl")

@defcomp Thermoelectric begin
    regions = Index()

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

    recorded = getfilteredtable("extraction/USGS-2010.csv")
    thermoelectric[:demand] = repeat(convert(Vector, recorded[:, :PT_To]) * 1383./12. * config["timestep"], outer=[1, numsteps])

    thermoelectric
end




