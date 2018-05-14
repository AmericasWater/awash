# The industrial demand component - water intensive industry not supplied by the public system
using Mimi
using DataFrames
include("lib/datastore.jl")
include("lib/industrial.jl")

@defcomp IndustrialDemand begin
    regions = Index()
    industry=Index() 

    #Regression model ax(water)+b=y(revenue)
    wateruserate=Parameter(index=[regions, industry, time],unit="\$/1000m^3")   #slope (a)
    constantvalue=Parameter(index=[regions, industry, time],unit="\$")    #Intercept (b')
    min_wateruse=Parameter(index=[regions, industry, time], unit="1000m^3") #min water level (c) 
    d_value=Parameter(index=[regions, industry, time], unit="\$/1000m^3") #d value (2b) 
    
    
    #Optimized
    #Water used to each industry to generate revenue
    waterused=Parameter(index=[regions, industry, time], unit="1000m^3")  #X:water above c level 
    waterused_norev=Parameter(index=[regions, industry, time], unit="1000m^3") #Y: water below c level 
    
    fake1=Parameter(index=[regions, industry, time], unit="1000m^3") #Fake water use Z
    fake2=Parameter(index=[regions, industry, time], unit="1000m^3") #fake water use W 
    
    waterused_copy=Variable(index=[regions, industry, time], unit="1000m^3") 
    
        
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
        
    for rr in d.regions
        industrywaterdemand=0
        for ii in d.industry
            v.waterused_copy[rr,ii,tt]=p.waterused[rr,ii,tt]+p.waterused_norev[rr,ii,tt]
            industrywaterdemand += v.waterused_copy[rr,ii,tt]
            v.industry_revenue[rr,ii,tt]=(p.waterused_norev[rr,ii,tt]-p.min_wateruse[rr,ii,tt])*p.constantvalue[rr,ii,tt]
-p.d_value[rr,ii,tt]*p.fake1[rr,ii,tt]-p.d_value[rr,ii,tt]*p.fake2[rr,ii,tt]+p.wateruserate[rr,ii,tt]*p.waterused[rr,ii,tt]
            
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
    min_wateruse=zeros(numcounties,numindustries,numsteps);
    indata[:MGwithdrawal]=map(x -> parse(Float64, x), indata[:MGwithdrawal])
    indata[:MG_min_of_min_withdrawal]=map(x -> parse(Float64, x), indata[:MG_min_of_min_withdrawal])
        for tt in 1:numsteps
        if tt==1
            waterused[:,:,tt]=(reshape(indata[indata[:year].==index2year(tt),:MGwithdrawal],11,60))'*3.785.*repmat(convert(Array,month_repeat[tt,:]),numcounties)
            #Historical Withdrawal data with Monthly distribution applied 
              
            #######Statistical model############
            wateruserate[:,:,tt]=                    
            (reshape(indata[indata[:year].==index2year(tt),:m],11,60))'/12*3.785  #Convert slope from $/MG to $/1000m^3) convert annual to monthly 
            constantvalue[:,:,tt]=
            (reshape(indata[indata[:year].==index2year(tt),:b],11,60))'/12*3.785
            min_wateruse[:,:,tt]=                    
            (reshape(indata[indata[:year].==index2year(tt),:MG_min_of_min_withdrawal],11,60))'/12*3.785
            
            else         
            waterused[:,:,tt]=(reshape(indata[indata[:year].==index2year(tt-1),:MGwithdrawal],11,60))'*3.785.*repmat(convert(Array,month_repeat[tt,:]),numcounties)
            #Historical Withdrawal data with Monthly distribution applied 
            
            #######Statistical model############
            wateruserate[:,:,tt]=                    
            (reshape(indata[indata[:year].==index2year(tt-1),:m],11,60))'/12*3.785  #Convert slope from $/MG to $/1000m^3) convert annual to monthly 
            constantvalue[:,:,tt]=
            (reshape(indata[indata[:year].==index2year(tt-1),:b],11,60))'/12*3.785
            min_wateruse[:,:,tt]=
            (reshape(indata[indata[:year].==index2year(tt-1),:MG_min_of_min_withdrawal],11,60))'/12*3.785
            end 
    end
        
    # data from USGS 2010 for the 2000 county definition
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    if config["filterstate"]=="36"    
        deleterows!(recorded,[30,52])
    end 

        industrialdemand = addcomponent(m, IndustrialDemand);
        industrialdemand[:wateruserate]=wateruserate
        industrialdemand[:min_wateruse]=min_wateruse
        industrialdemand[:constantvalue]=constantvalue
        industrialdemand[:waterused] = cached_fallback("extraction/waterused", () ->waterused-min_wateruse); #water above c 
        industrialdemand[:waterused_norev] = cached_fallback("extraction/waterused_norev", () ->min_wateruse); #water below c 

        #Use MGWithdrawal data if not optimized
       
    industrialdemand
end


##Revenue to be optimized 

function constraintoffset_industrialdemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:industrywaterdemand].values[rr,tt]
    hallsingle(m, :IndustrialDemand, :waterdemand, gen)
end



function grad_industrialdemand_totalrevenue_waterused(m::Model)
    roomdiagonal(m, :IndustrialDemand,:totalrevenue,:waterused, (rr,ii,tt) -> 1.)
end

function grad_industrialdemand_totalrevenue_supersource(m::Model)
    roomdiagonal(m, :IndustrialDemand,:totalrevenue,:supersource, (rr,ii,tt) -> 1.)
end

function grad_industrialdemand_totalrevenue_dummy(m::Model)
    roomdiagonal(m, :IndustrialDemand,:totalrevenue,:dummy, (rr,ii,tt) -> 1.)
end


function deriv_industrialdemand_totalrevenue_waterused(m::Model)
    gen(rr, ii, tt) = m.parameters[:wateruserate].values[rr,ii,tt]
    hallsingle(m, :IndustrialDemand,:waterused, gen)
end


function deriv_industrialdemand_totalrevenue_supersource(m::Model)
    gen(rr, ii, tt) = m.parameters[:constantvalue].values[rr,ii,tt]
    hallsingle(m, :IndustrialDemand,:supersource, gen)
end


function deriv_industrialdemand_totalrevenue_dummy(m::Model)
    gen(rr, ii, tt) = m.parameters[:constantvalue].values[rr,ii,tt]
    hallsingle(m, :IndustrialDemand,:dummy, gen)
end

function grad_industrialdemand_positive1_dummy(m::Model)
    roomdiagonal(m,:IndustrialDemand,:positive1,:dummy, (rr,ii,tt)=>1.)
end 

function grad_industrialdemand_positive2_supersource(m::Model)
    roomdiagonal(m, :IndustrialDemand,:positive2,:supersource, (rr,ii,tt) -> 1.)
end


function grad_industrialdemand_balance1_dummy(m::Model)
    roomdiagonal(m,:IndustrialDemand,:balance1,:dummy, (rr,ii,tt)=>1.)
end 

function grad_industrialdemand_balance1_supersource(m::Model)
    roomdiagonal(m, :IndustrialDemand,:balance1,:supersource, (rr,ii,tt) -> 1.)
end













