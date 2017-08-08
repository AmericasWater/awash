# The urban water demand component - comprising domestic, commerical and public supplied industrial sectors
using Mimi
using DataFrames
include("lib/readconfig.jl")

@defcomp UrbanDemand begin
    regions = Index()

    # Urban demands - exogeneous for now
    domesticdemand = Parameter(index=[regions, time],unit="1000 m^3")
    #commercialdemand = Parameter(index=[regions, time],unit="1000 m^3")
    urbandemand = Variable(index=[regions, time],unit="1000 m^3")

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
        #v.urbandemand[rr,tt]=p.coef
    end
end

"""
Add an urban component to the model.
"""
function initurbandemand(m::Model)
    urbandemand = addcomponent(m, UrbanDemand);
    urban=zeros(numcounties, numsteps);
#
#    for rr in 1:numcounties 
#        for tt in 1:numsteps 
#            for vv in 1:length(vars)
#                urban[rr,tt]+=exp(coef[vars[vv]]*in_data[vars[vv]][rr,tt]+con)
#            end 
#            end
#        end 
#end
#urbandemand[:domesticdemand] =urban[:,1:numsteps]
    
    
    
    # data from USGS 2010 for the 2000 county definition
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    if config["filterstate"]=="36"    
        deleterows!(recorded,[30,52])
    end 
    urbandemand[:domesticdemand] = repeat(convert(Vector, recorded[:, :PS_To]) * 1383./12. * config["timestep"], outer=[1, numsteps])
    #urbandemand[:commercialdemand] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    urbandemand
end

function constraintoffset_urbandemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:commercialdemand].values[rr, tt] + m.parameters[:domesticdemand].values[rr,tt]
    hallsingle(m, :UrbanDemand, :waterdemand, gen)
end
