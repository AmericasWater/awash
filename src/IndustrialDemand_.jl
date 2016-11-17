using Mimi
using DataFrames

@defcomp IndustrialDemand begin
    regions = Index()
    crops = Index()

   
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
        v.waterdemand[rr, tt] = p.miningwaterdemand[rr, tt]
    end
end

"""
Add an industrial component to the model.
"""
function initindustrialdemand(m::Model)
    industrialdemand = addcomponent(m, IndustrialDemand);
    
    recorded = readtable(datapath("Colorado/mining.csv"));
    industrialdemand[:miningwaterdemand] = convert(Matrix, recorded)/1000.;   
    
    industrialdemand
end

function constraintoffset_industrialdemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:miningwaterdemand].values[rr, tt] 
    hallsingle(m, :IndustrialDemand, :waterdemand, gen)
end


