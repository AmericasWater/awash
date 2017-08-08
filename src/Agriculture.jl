
using Mimi
using DataFrames
include("lib/datastore.jl")

@defcomp Agriculture begin
    regions = Index()

    # Exogenous demands
    demand = Parameter(index=[regions, time], unit="1000 m^3")

    # Copy through
    demand_copy = Variable(index=[regions, time], unit="1000 m^3")
end

"""
Just copy through
"""
function run_timestep(c::Agriculture, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.demand_copy[rr, tt] = p.demand[rr, tt]
    end
end


function initagriculture(m::Model)
    agriculture = addcomponent(m, Agriculture)

    recorded = getfilteredtable("extraction/USGS-2010.csv")
        if config["filterstate"]=="36"    
    deleterows!(recorded,[30,52])
    end 
    agriculture[:demand] = repeat(convert(Vector, recorded[:, :IR_To]) * 1383./12. * config["timestep"], outer=[1, numsteps])

    agriculture
end
