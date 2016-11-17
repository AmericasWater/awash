using DataFrames
using Mimi

include("lib/agriculture.jl")

@defcomp Agriculture begin
    regions = Index()
    crops = Index()

    # Optimized
    # Land area appropriated to each crop, irrigated to full demand (Ha)
    irrigatedareas = Parameter(index=[regions, crops, time], unit="Ha")
    rainfedareas = Parameter(index=[regions, crops, time], unit="Ha")
 
    # Inputs
    othercropsarea = Parameter(index=[regions, time], unit="Ha")
    othercropsirrigation = Parameter(index=[regions, time], unit="1000 m^3")

    totalirrigated=Variable(index=[regions, time], unit="Ha")
    totalrainfed=Variable(index=[regions, time], unit="Ha")
    # Internal
    # Yield base: combination of GDDs, KDDs, and intercept
    logirrigatedyield = Parameter(index=[regions, crops, time], unit="none")

    # Coefficient on the effects of water deficits
    deficit_coeff = Parameter(index=[regions, crops], unit="1/mm")

    # Water requirements per unit area, in mm
    water_demand = Parameter(index=[crops], unit="mm")

    # Precipitation water per unit area, in mm
    precipitation = Parameter(index=[regions, time], unit="mm")

    # Computed
    # Land area appropriated to each crop
    totalareas = Variable(index=[regions, crops, time], unit="Ha")
    # Total agricultural area
    allagarea = Variable(index=[regions, time], unit="Ha")

    # Deficit for any unirrigated areas, in mm
    water_deficit = Variable(index=[regions, crops, time], unit="mm")

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, time], unit="1000 m^3")

    # Yield per hectare for rainfed (irrigated has irrigatedyield)
    lograinfedyield = Variable(index=[regions, crops, time], unit="none")
    
    #total crop production 
    totalproduction=Variable(index=[crops,time], unit="lborbu")
    
    #cropdemand per crop
    cropdemand=Parameter(index=[crops,time], unit="buorlb")
    
    # Total production: lb or bu
    production = Variable(index=[regions, crops, time], unit="lborbu")
    # Total cultivation costs per crop
    cultivationcost = Variable(index=[regions, crops, time], unit="\$")
    upperbound=Parameter(index=[regions,crops,time],unit="Ha")
    #lowerbound=Parameter(index=[regions,crops,time],unit="Ha")
end

function run_timestep(s::Agriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions
    
    p.upperbound=0.2*ones(numcounties,numcrops,numsteps)
    v.totalproduction[:,tt] = zeros(numcrops)
    for rr in d.regions
        totalirrigation = p.othercropsirrigation[rr, tt]
        allagarea = p.othercropsarea[rr, tt]
        for cc in d.crops
            v.totalirrigated[rr,tt] +=p.irrigatedareas[rr,cc,tt]
            v.totalrainfed[rr,tt] +=p.rainfedareas[rr,cc,tt]
            
            v.totalareas[rr, cc, tt] = p.irrigatedareas[rr, cc, tt] + p.rainfedareas[rr, cc, tt]
            allagarea += v.totalareas[rr, cc, tt]
            
            # Calculate deficit by crop, for unirrigated areas
            v.water_deficit[rr, cc, tt] = max(0., p.water_demand[cc] - p.precipitation[rr, tt])

            # Calculate irrigation water, summed across all crops: 1 mm * Ha^2 = 10 m^3
            totalirrigation += v.water_deficit[rr, cc, tt] * p.irrigatedareas[rr, cc, tt] / 100 

            # Calculate rainfed yield
            v.lograinfedyield[rr, cc, tt] = p.logirrigatedyield[rr, cc, tt] + p.deficit_coeff[rr, cc] * v.water_deficit[rr, cc, tt]

            # Calculate total production
            v.production[rr, cc, tt] = exp(p.logirrigatedyield[rr, cc, tt]) * p.irrigatedareas[rr, cc, tt] * 2.47105+ exp(v.lograinfedyield[rr, cc, tt]) * p.rainfedareas[rr, cc, tt] * 2.47105 # convert acres to Ha

            # Calculate cultivation costs
            v.cultivationcost[rr, cc, tt] = v.totalareas[rr, cc, tt] * cultivation_costs[crops[cc]] * 2.47105 * config["timestep"]/12 # convert acres to Ha
            v.totalproduction[cc,tt] += v.production[rr,cc,tt]
        end

        v.totalirrigation[rr, tt] = totalirrigation
        v.allagarea[rr, tt] = allagarea
    end
end

function initagriculture(m::Model)
    # precip loaded by weather.jl

    # Match up values by FIPS
    logirrigatedyield = -Inf * ones(numcounties, numcrops, numsteps)
    deficit_coeff = zeros(numcounties, numcrops)
    
    for cc in 1:numcrops
        # Load degree day data
        gdds = readtable(joinpath(todata, "agriculture/edds/$(crops[cc])-gdd.csv"))
        kdds = readtable(joinpath(todata, "agriculture/edds/$(crops[cc])-kdd.csv"))

        for rr in 1:numcounties
            fips = parse(Int64, mastercounties[rr, :fips])
            if fips in keys(agmodels[crops[cc]])
                thismodel = agmodels[crops[cc]][fips]
                for tt in 1:numsteps
                    year = index2year(tt)
                    if year >= 1949 && year <= 2009
                        numgdds = gdds[rr, symbol("x$year")]
                        if isna(numgdds)
                            numgdds = 0
                        end

                        numkdds = kdds[rr, symbol("x$year")]
                        if isna(numkdds)
                            numkdds = 0
                        end
                    else
                        numgdds = numkdds = 0
                    end

                    logmodelyield = thismodel.intercept + thismodel.gdds * numgdds + thismodel.kdds * numkdds
                    logirrigatedyield[rr, cc, tt] = min(logmodelyield, log(maximum_yields[crops[cc]]))
                end

                deficit_coeff[rr, cc] = min(0., thismodel.wreq / 1000) # must be negative, convert to 1/mm
            end
        end
    end

    water_demand = zeros(numcrops)
    crop_demand=zeros(numcrops,numsteps)
    
    for cc in 1:numcrops
        water_demand[cc] = water_requirements[crops[cc]] * 1000
        crop_demand[cc]=crop_demands[crops[cc]]
            for tt in 2:12
            crop_demand[:,tt]=crop_demand[:,1]
        end
    end
    

    
    agriculture = addcomponent(m, Agriculture)

    agriculture[:logirrigatedyield] = logirrigatedyield
    agriculture[:deficit_coeff] = deficit_coeff
    agriculture[:water_demand] = water_demand
    agriculture[:cropdemand]=crop_demand

    # Sum precip to a yearly level
    stepsperyear = floor(Int64, 12 / config["timestep"])
    rollingsum = cumsum(precip, 2) - cumsum([zeros(numcounties, stepsperyear) precip[:, 1:size(precip)[2] - stepsperyear]],2)
    agriculture[:precipitation] = rollingsum

    agriculture[:upperbound]=0.2*ones(numcounties,numcrops,numsteps)
    
    
   # Load in planted area by water management
    rainfed = readtable(joinpath(todata, "Colorado/rainfedareas_colorado.csv"));
    irrigated = readtable(joinpath(todata, "Colorado/irrigatedareas_colorado.csv"));
    rainfeds=repeat(convert(Matrix, rainfed)*0.404686, outer=[1, 1, numsteps]); #Acre to Ha
    irrigateds=repeat(convert(Matrix, irrigated)*0.404686, outer=[1, 1, numsteps]); #Acre to Ha
   
    agriculture[:rainfedareas] = cached_fallback("extraction/rainfedareas", () ->rainfeds) #should be in Ha
    agriculture[:irrigatedareas] = cached_fallback("extraction/irrigatedareas", () ->irrigateds)#should be in Ha

    knownareas = readtable(datapath("Colorado/knownareas_colorado.csv"))
    agriculture[:othercropsarea] = repeat(convert(Vector, knownareas[:total] - knownareas[:known]), outer=[1, numsteps])   
    othercropirrigation = ((knownareas[:total] - knownareas[:known]) ./ knownareas[:total]) * config["timestep"] 
    othercropirrigation[knownareas[:total] .== 0] = 0
    agriculture[:othercropsirrigation] = repeat(convert(Vector, othercropirrigation), outer=[1, numsteps])

    agriculture
end

function grad_agriculture_production_irrigatedareas(m::Model)
    roomdiagonal(m, :Agriculture, :production, :irrigatedareas, (rr, cc, tt) -> exp(m.parameters[:logirrigatedyield].values[rr, cc, tt]) * 2.47105 * .99) # Convert Ha to acres
    # 1% lost to irrigation technology (makes irrigated and rainfed not perfectly equivalent)
end


function grad_agriculture_production_rainfedareas(m::Model)
    gen(rr, cc, tt) = exp(m.parameters[:logirrigatedyield].values[rr, cc, tt] + m.parameters[:deficit_coeff].values[rr, cc] * max(0., m.parameters[:water_demand].values[cc] - m.parameters[:precipitation].values[rr, tt])) * 2.47105  # Convert Ha to acres
    roomdiagonal(m, :Agriculture, :production, :rainfedareas, gen)
end

function grad_agriculture_totalirrigation_irrigatedareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for cc in 1:numcrops
                A[rr, fromindex([rr, cc], [numcounties, numcrops])] = max(0., m.parameters[:water_demand].values[cc] - m.parameters[:precipitation].values[rr, tt]) / 100 
            end
        end

        return A
    end
    roomintersect(m, :Agriculture, :totalirrigation, :irrigatedareas, generate)
end

function grad_agriculture_allagarea_irrigatedareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for cc in 1:numcrops
                A[rr, fromindex([rr, cc], [numcounties, numcrops])] = 1.
            end
        end
        return A
    end
    roomintersect(m, :Agriculture, :allagarea, :irrigatedareas, generate)
end

function grad_agriculture_allagarea_rainfedareas(m::Model)
    function generate(A, tt) #63*60 rr,tt
        for rr in 1:1
            for cc in 1:numcrops
                A[rr, fromindex([rr, cc], [numcounties, numcrops])] = 1.
            end
        end
        return A
    end
    roomintersect(m, :Agriculture, :allagarea, :rainfedareas, generate)
end


function constraintoffset_agriculture_allagarea(m::Model)
   hallsingle(m, :Agriculture, :allagarea, (rr, tt) -> areas[rr,tt]- m.parameters[:othercropsarea].values[rr, tt])
   #hallsingle(m, :Agriculture, :allagarea, (rr, tt) -> countyareas[rr]- m.parameters[:othercropsarea].values[rr, tt])
    #data in Ha 
end


function grad_agriculture_cost_rainfedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :rainfedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end

function grad_agriculture_cost_irrigatedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :irrigatedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end


###fix here####
function constraintoffset_fixed_agriculture_cropdemand(m::Model)
    hallsingle(m, :Agriculture, :totalproduction, (cc,tt) ->m.parameters[:cropdemand].values[cc,tt]*0.0)
end

function constraintoffset_agriculture_cropdemand(m::Model)
    hallsingle(m, :Agriculture, :totalproduction, (cc,tt) ->m.parameters[:cropdemand].values[cc,tt]*0.0)
end


function grad_agriculture_totalproduction_rainfedareas(m::Model)
    function generate(A,cc,tt)          
        for rr in 1:numcounties  
            A[1, rr] = exp(m.parameters[:logirrigatedyield].values[rr,cc,tt]+m.parameters[:deficit_coeff].values[rr,cc]*max(0,m.parameters[:water_demand].values[cc]-m.parameters[:precipitation].values[rr,tt]))*2.47*0.99 #fromindex([rr, cc], [numcounties,numcrops])] =1.         
        end
        return A
    end
    roomintersect(m, :Agriculture, :totalproduction, :rainfedareas, generate)
end

function grad_agriculture_totalproduction_irrigatedareas(m::Model)
    function generate(A,cc,tt)          #rr*cc 
        for rr in 1:numcounties  
            A[1, rr] = exp(m.parameters[:logirrigatedyield].values[rr,cc,tt])*2.47*0.99      
        end
        return A
    end
    roomintersect(m, :Agriculture, :totalproduction, :rainfedareas, generate)
end

function grad_agriculture_upperbound_rainfedareas(m::Model)
    function generate(A,cc,tt)          #rr*cc 
        for rr in 1:numcounties 
            for cc in 1:numcrops
            for tt in 1:numsteps
                A[rr,cc] = 1     
                end 
            end 
        end
        return A
    end
    roomintersect(m, :Agriculture, :upperbound, :rainfedareas, generate)
end



function grad_agriculture_production_rainfedareas(m::Model)
    tt=1:2
    roomdiagonal(m, :Agriculture, :production, :rainfedareas, (rr,cc,tt)->gen(rr,cc,1))
end






function constraintoffset_agriculture_upperbound(m::Model)
    hallsingle(m, :Agriculture, :upperbound, (rr,cc,tt) -> m.parameters[:upperbound].values[rr,cc,tt])
end
