# The urban water demand component - comprising domestic, commerical and public supplied industrial sectors
using Mimi
using DataFrames

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
function timestep(c::UrbanDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.waterdemand[rr, tt] = p.domesticdemand[rr, tt];
    end
end

"""
Add an urban component to the model.
"""
function initurbandemand(m::Model)
    urbandemand = addcomponent(m, UrbanDemand);

    # data from USGS 2010 for the 2000 county definition
    urbandemand[:domesticdemand] = readdlm("../data/demand/PSdem.txt");
    M = zeros(m.indices_counts[:regions], m.indices_counts[:time]);#readdlm("../data/COandINPSDel.txt");
    urbandemand[:commercialdemand] = 0*M;
    urbandemand
end

function constraintoffset_urbandemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:commercialdemand].values[rr, tt] + m.parameters[:domesticdemand].values[rr,tt]
    hallsingle(m, :UrbanDemand, :waterdemand, gen)
end
