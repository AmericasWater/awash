# The urban water demand component - comprising domestic, commerical and public supplied industrial sectors
using Mimi
using DataFrames
include("lib/readconfig.jl")

@defcomp UrbanDemand begin
    regions = Index()
    crops = Index()

    # Urban demands - exogeneous for now
    domesticdemand = Parameter(index=[regions, time],unit="1000 m^3")
    commercialdemand = Parameter(index=[regions, time],unit="1000 m^3")

    # Demanded water
    waterdemand = Variable(index=[regions, time],unit="1000 m^3")
end

"""
The quantity of water demanded at each timestep
"""
function run_timestep(c::UrbanDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.waterdemand[rr, tt] = p.domesticdemand[rr, tt]; # XXX: Where is commercial
    end
end

"""
Add an urban component to the model.
"""
function initurbandemand(m::Model)
    urbandemand = addcomponent(m, UrbanDemand);

    # data from USGS 2010 for the 2000 county definition
    recorded = getfilteredtable("extraction/USGS-2010.csv")

    urbandemand[:domesticdemand] = repeat(convert(Vector, recorded[:, :PS_To]) * 1383./12. * config["timestep"], outer=[1, numsteps])
    urbandemand[:commercialdemand] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    urbandemand
end

function constraintoffset_urbandemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:commercialdemand].values[rr, tt] + m.parameters[:domesticdemand].values[rr,tt]
    hallsingle(m, :UrbanDemand, :waterdemand, gen)
end
