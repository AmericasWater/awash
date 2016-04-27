# The industrial demand component - water intensive industry not supplied by the public system
using Mimi
using DataFrames


@defcomp IndustrialDemand begin
    regions = Index()

    # Industrial demand
    industrywaterdemand = Parameter(index=[regions, time])
    miningwaterdemand = Parameter([regions, time])

    # Demanded water
    waterdemand = Variable(index=[regions, time])
end

"""
The quantity of water demanded at each timestep
"""
function timestep(c::DomesticDemand, tt::Int)
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
function initdomesticdemand(m::Model, years)
    industrialdemand = addcomponent(m, DomesticDemand);
    
    # data from USGS 2010 for the 2000 county definition

    industrialdemand[:industrywaterdemand] = readdlm("../data/usgs_industrydemand_2010.txt");
    industrialdemand[:miningwaterdemand] = readdlm("../data/usgs_miningdemand_2010.txt");
    industrialdemand
end

function constraintoffset_industrialdemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:miningwaterdemand].values[rr, tt] + m.parameters[:industrywaterdemand].values[rr,tt]
    hallsingle(m, :IndustrialDemand, :waterdemand, gen)
end


