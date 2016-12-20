# The industrial demand component - water intensive industry not supplied by the public system
using Mimi
using DataFrames
include("lib/datastore.jl")

@defcomp IndustrialDemand begin
    regions = Index()
    crops = Index()

    # Industrial demand
    industrywaterdemand = Parameter(index=[regions, time],unit="1000 m^3")
    miningwaterdemand = Parameter(index=[regions, time],unit="1000 m^3")

    # Demanded water
    waterdemand = Variable(index=[regions, time],unit="1000 m^3")
end

"""
The quantity of water demanded at each timestep
"""
function run_timestep(c::IndustrialDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.waterdemand[rr, tt] = p.industrywaterdemand[rr, tt] + p.miningwaterdemand[rr, tt]
    end
end

"""
Add an industrial component to the model.
"""
function initindustrialdemand(m::Model)
    industrialdemand = addcomponent(m, IndustrialDemand);

    # data from USGS 2010 for the 2000 county definition
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    industrialdemand[:industrywaterdemand] = repeat(convert(Vector, recorded[:,:IN_To]) * config["timestep"] * 1383./12., outer=[1, m.indices_counts[:time]]);
    industrialdemand[:miningwaterdemand] = repeat(convert(Vector,recorded[:,:MI_To]) * config["timestep"] * 1383./12., outer=[1, m.indices_counts[:time]]);
    industrialdemand
end

function constraintoffset_industrialdemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:miningwaterdemand].values[rr, tt] + m.parameters[:industrywaterdemand].values[rr,tt]
    hallsingle(m, :IndustrialDemand, :waterdemand, gen)
end


