# The industrial demand component - water intensive industry not supplied by the public system
using Mimi
using DataFrames
include("lib/datastore.jl")
include("lib/industrial.jl")

@defcomp IndustrialDemand begin
    regions = Index()
    industry=Index() 

    #Regression model ax(water)+b=y(revenue)
    wateruserate=Parameter(index=[regions, industry, time],unit="\$/1000m^3")
    constantvalue=Parameter(index=[regions, industry, time],unit="\$")
    
    #Optimized
    #Water used to each industry to generate revenue
    waterused=Parameter(index=[regions, industry, time], unit="1000m^3") 
    
    #Computed
    #Total Water used to each industry 
    industry_waterdemand=Variable(index=[regions, time], unit="1000m^3") 
    
    #Revenue generated for each industry by using water 
    industry_revenue=Variable(index=[regions,industry,time], unit="\$") 
    
    # Demanded water
    waterdemand = Variable(index=[regions,time],unit="1000 m^3")
    # Industrial demand
    industrywaterdemand = Variable(index=[regions, time],unit="1000 m^3")
    
end

"""
The quantity of water demanded at each timestep
"""
function run_timestep(c::IndustrialDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions
    
    industrywaterdemand=0
    
    for rr in d.regions
        for ii in d.industry           v.industry_revenue[rr,ii,tt]=p.waterused[rr,ii,tt]*p.wateruserate[rr,ii,tt]+p.constantvalue[rr,ii,tt]
            industrywaterdemand+=p.waterused[rr,ii,tt]
    end
        v.industrywaterdemand[rr, tt]=industrywaterdemand
        v.waterdemand[rr,tt]=v.industrywaterdemand[rr,tt]
    end
end


"""
Add an industrial component to the model.
"""
function initindustrialdemand(m::Model)
    waterused=zeros(numcounties,numindustries,numsteps);
    wateruserate=zeros(numcounties,numindustries,numsteps);
    constantvalue=zeros(numcounties,numindustries,numsteps);
    indata[:MGwithdrawal]=map(x -> parse(Float64, x), indata[:MGwithdrawal])
        
    for tt in 1:numsteps
        if tt==1
            waterused[:,:,tt]=(reshape(indata[indata[:year].==index2year(tt),:MGwithdrawal],11,60))'/12*3.785
            #Convert data from MG to 1000m^3)
            wateruserate[:,:,tt]=                    
            (reshape(indata[indata[:year].==index2year(tt),:m],11,60))'/12*3.785  #Convert slope from $/MG to $/1000m^3) convert annual to monthly 
            constantvalue[:,:,tt]=
            (reshape(indata[indata[:year].==index2year(tt),:b],11,60))'/12
        else 
            waterused[:,:,tt]=(reshape(indata[indata[:year].==index2year(tt-1),:MGwithdrawal],11,60))'/12*3.785
            wateruserate[:,:,tt]=                    
            (reshape(indata[indata[:year].==index2year(tt-1),:m],11,60))'/12*3.785  #Convert slope from $/MG to $/1000m^3) convert annual to monthly 
            constantvalue[:,:,tt]=
            (reshape(indata[indata[:year].==index2year(tt-1),:b],11,60))'/12
        end 
    end
        
    # data from USGS 2010 for the 2000 county definition
    recorded = getfilteredtable("extraction/USGS-2010.csv")

    industrialdemand = addcomponent(m, IndustrialDemand);
    industrialdemand[:wateruserate]=wateruserate
    industrialdemand[:constantvalue]=constantvalue 
    industrialdemand[:waterused] = cached_fallback("extraction/waterused", () ->waterused);
    
    #Use MGWithdrawal data if not optimized
       
    industrialdemand
end


##Revenue to be optimized 
function grad_industrialdemand_revenue_waterused(m::Model)
    roomdiagonal(m, :IndustrialDemand,:revenue,:waterused, (rr, ii, tt) -> m.parameters[:wateruserate].values[rr,ii,tt]+m.parameters[:constantvalue].values[rr,ii,tt])
end

function grad_industrialdemand_waterused(m::Model)
    roomdiagonal(m, :IndustrialDemand,:revenue,:waterused, (rr, ii, tt) -> m.parameters[:wateruserate].values[rr,ii,tt]+m.parameters[:constantvalue].values[rr,ii,tt])
end

function constraintoffset_industrialdemand_waterdemand(m::Model)
    gen(rr, tt) = m.external_parameters[:miningwaterdemand].values[rr, tt] + m.external_parameters[:industrywaterdemand].values[rr,tt]
    hallsingle(m, :IndustrialDemand, :waterdemand, gen)
end


