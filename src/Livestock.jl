# The livestock component

using Mimi
using DataFrames

@defcomp Livestock begin
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
function run_timestep(c::Livestock, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.demand_copy[rr, tt] = p.demand[rr, tt]
    end
end

"""
Add a Livestock component to the model.
"""
function initlivestock(m::Model)
    livestock = addcomponent(m, Livestock)

    recorded = readtable(datapath("extraction/USGS-2010.csv"));

    if get(config, "filterstate", nothing) != nothing
        livestock[:demand] = repeat(convert(Vector,recorded[find(recorded[:STATEFIPS] .== parse(Int64,config["filterstate"])),:LI_To])*1383./12*config["timestep"], outer=[1, numsteps])
    else
        livestock[:demand] = repeat(convert(Vector,recorded[:,:LI_To])*1383./12*config["timestep"], outer=[1, numsteps])
    end

    livestock
end
