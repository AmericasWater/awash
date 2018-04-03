# The industrial demand component - water intensive industry not supplied by the public system
using Mimi
using DataFrames
include("lib/datastore.jl")
include("lib/industrial.jl")

@defcomp IndustrialDemand begin
    regions = Index()
    industry=Index() 

    #Regression model ax+b=y
    wateruserate=Parameter(index=[regions, industry, time],unit="\$/1000m^3")
    constantvalue=Parameter(index=[regions, industry, time],unit="\$")
    
    #Optimized
    #Water used to each industry to generate revenue
    water_used=Parameter(index=[regions, industry, time], unit="1000m^3") 
    
    #Computed
    #Total Water used to each industry 
    industry_waterdemand=Variable(index=[regions, time], unit="1000m^3") 
    
    #Revenue generated for each industry by using water 
    industry_revenue=Variable(index=[regions,industry,time], unit="\$") 
    
    # Demanded water
    waterdemand = Variable(index=[regions, time],unit="1000 m^3")
    # Industrial demand
    industrywaterdemand = Parameter(index=[regions, time],unit="1000 m^3")
    
end

"""
The quantity of water demanded at each timestep
"""
function run_timestep(c::IndustrialDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.waterdemand[rr, tt] = p.industrywaterdemand[rr, tt]
        for ii in d.industry
            v.industry_revenue[rr,ii,tt]=p.waterused[rr,ii,tt]*p.wateruserate[rr,ii,tt]+p.constantvalue[rr,ii,tt]
            
            
    end
end





"""
Add an industrial component to the model.
"""
function initindustrialdemand(m::Model)
        wateruserate=zeros(numcounties,numindustries,numstep);
        constantvalue=zeros(numcounties,numindustries,numstep);
        
        for rr in 1:numcounties
            for ii in 1:numindustries 
                for tt in 1:numstep
                    wateruserate[rr,ii,tt]=indata[:m]
        
        
        wateruserate=indata[:m]*3.785  #Convert slope from $/MG to $/1000m^3) 
        constantvalue=indata[:b];
        

    # data from USGS 2010 for the 2000 county definition
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    if config["filterstate"]=="36"    
        deleterows!(recorded,[30,52])
    end 

        industrialdemand = addcomponent(m, IndustrialDemand);
        industrialdemand[:wateruserate]=wateruserate
        industrialdemand[:constantvalue]=constantvalue 

        
        
        industrialdemand[:industrywaterdemand] = repeat(convert(Vector, recorded[:,:IN_To]) * config["timestep"] * 1383./12., outer=[1, m.indices_counts[:time]]);
#    industrialdemand[:miningwaterdemand] = repeat(convert(Vector,recorded[:,:MI_To]) * config["timestep"] * 1383./12., outer=[1, m.indices_counts[:time]]);
  
        
        
        
        
        
        
    industrialdemand
end

function constraintoffset_industrialdemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:miningwaterdemand].values[rr, tt] + m.parameters[:industrywaterdemand].values[rr,tt]
    hallsingle(m, :IndustrialDemand, :waterdemand, gen)
end


