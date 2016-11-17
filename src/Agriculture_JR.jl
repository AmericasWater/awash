using DataFrames
using Mimi

include("lib/agriculture.jl")

## This is identical to the definition of Agriculture, except where CONSTANT! is noted.

@defcomp Agriculture begin
    regions = Index()
    crops = Index()

    # Optimized
    # Land area appropriated to each crop, irrigated to full demand (Ha)
    irrigatedareas = Parameter(index=[regions, crops], unit="Ha") # CONSTANT!
    rainfedareas = Parameter(index=[regions, crops], unit="Ha") # CONSTANT!

    # Inputs
    othercropsarea = Parameter(index=[regions], unit="Ha") # CONSTANT!
    othercropsirrigation = Parameter(index=[regions, time], unit="1000 m^3")

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
    totalareas = Variable(index=[regions, crops], unit="Ha") # CONSTANT!
    # Total agricultural area
    allagarea = Variable(index=[regions], unit="Ha") # CONSTANT!

    # Deficit for any unirrigated areas, in mm
    water_deficit = Variable(index=[regions, crops, time], unit="mm")

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, time], unit="1000 m^3")

    # Yield per hectare for rainfed (irrigated has irrigatedyield)
    lograinfedyield = Variable(index=[regions, crops, time], unit="none")

    # Total production: lb or bu
    production = Variable(index=[regions, crops, time], unit="lborbu")
    # Total cultivation costs per crop
    cultivationcost = Variable(index=[regions, crops], unit="\$") # CONSTANT!
end

function init(s::Agriculture)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    for rr in d.regions
        allagarea = p.othercropsarea[rr]
        for cc in d.crops
            v.totalareas[rr, cc] = p.irrigatedareas[rr, cc] + p.rainfedareas[rr, cc]
            allagarea += v.totalareas[rr, cc]

            # Calculate cultivation costs
            v.cultivationcost[rr, cc] = v.totalareas[rr, cc] * cultivation_costs[crops[cc]] * 2.47105 * config["timestep"] / 12 # convert acres to Ha
        end

        v.allagarea[rr, tt] = allagarea
    end
end

function run_timestep(s::Agriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    for rr in d.regions
        totalirrigation = p.othercropsirrigation[rr, tt]
        for cc in d.crops
            # Calculate deficit by crop, for unirrigated areas
            v.water_deficit[rr, cc, tt] = max(0., p.water_demand[cc] - p.precipitation[rr, tt])

            # Calculate irrigation water, summed across all crops: 1 mm * Ha^2 = 10 m^3
            totalirrigation += v.water_deficit[rr, cc, tt] * p.irrigatedareas[rr, cc] / 100

            # Calculate rainfed yield
            v.lograinfedyield[rr, cc, tt] = p.logirrigatedyield[rr, cc, tt] + p.deficit_coeff[rr, cc] * v.water_deficit[rr, cc, tt]

            # Calculate total production
            v.production[rr, cc, tt] = exp(p.logirrigatedyield[rr, cc, tt]) * p.irrigatedareas[rr, cc] * 2.47105 + exp(v.lograinfedyield[rr, cc, tt]) * p.rainfedareas[rr, cc] * 2.47105 # convert acres to Ha
        end

        v.totalirrigation[rr, tt] = totalirrigation
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
    for cc in 1:numcrops
        water_demand[cc] = water_requirements[crops[cc]] * 1000
    end

    agriculture = addcomponent(m, Agriculture)

    agriculture[:logirrigatedyield] = logirrigatedyield
    agriculture[:deficit_coeff] = deficit_coeff
    agriculture[:water_demand] = water_demand

    # Sum precip to a yearly level
    stepsperyear = floor(Int64, 12 / config["timestep"])
    rollingsum = cumsum(precip, 2) - cumsum([zeros(numcounties, stepsperyear) precip[:, 1:size(precip)[2] - stepsperyear]],2)
    agriculture[:precipitation] = rollingsum

    # Load in planted area by water management
    rainfeds = readtable(joinpath(todata, "agriculture/rainfedareas.csv"));
    rainfeds=rainfeds[216:278,:]
    irrigateds = readtable(joinpath(todata, "agriculture/irrigatedareas.csv"))
    irrigateds=irrigateds[216:278,:]
    for cc in 2:ncol(rainfeds)
        # Replace NAs with 0, and convert to float. TODO: improve this
        rainfeds[isna(rainfeds[cc]), cc] = 0.
        irrigateds[isna(irrigateds[cc]), cc] = 0.
        # Convert to Ha
        rainfeds[cc] = rainfeds[cc] * 0.404686
        irrigateds[cc] = irrigateds[cc] * 0.404686
    end
    agriculture[:rainfedareas] = convert(Matrix, rainfeds[:, 2:end])
    agriculture[:irrigatedareas] = convert(Matrix, irrigateds[:, 2:end])

    knownareas = readtable(datapath("agriculture/knownareas.csv"))[216:278,:]
    agriculture[:othercropsarea] = convert(Vector, knownareas[:total] - knownareas[:known])

    recorded = readtable(datapath("extraction/USGS-2010.csv"))[216:278,:]
    othercropirrigation = (knownareas[:total] - knownareas[:known]) 
    othercropirrigation[knownareas[:total] .== 0] = 0
    agriculture[:othercropsirrigation] = repeat(convert(Vector, othercropirrigation), outer=[1, numsteps])

    agriculture
end

function grad_agriculture_production_irrigatedareas(m::Model)
    function gen(rr1, cc1, tt, rr2, cc2)
        if rr1 == rr2 && cc1 == cc2
            for rr in 1:numcounties
                for cc in 1:numcrops
                    for tt in 1:numsteps
            exp(m.parameters[:logirrigatedyield].values[rr, cc, tt]) * 2.47105 * .99 * config["timestep"]/12 # Convert Ha to acres
            # 1% lost to irrigation technology (makes irrigated and rainfed not perfectly equivalent)
                    end
                end
            end
            
        else
            0.
        end
    end
    roomsingle(m, :Agriculture, :production, :irrigatedareas, gen)
end

function grad_agriculture_production_rainfedareas(m::Model)
    function gen(rr1, cc1, tt, rr2, cc2)
        if rr1 == rr2 && cc1 == cc2
             for rr in 1:numcounties
                for cc in 1:numcrops
                    for tt in 1:numsteps
            exp(m.parameters[:logirrigatedyield].values[rr, cc, tt] + m.parameters[:deficit_coeff].values[rr, cc] * max(0., m.parameters[:water_demand].values[cc] - m.parameters[:precipitation].values[rr, tt])) * 2.47105 * config["timestep"]/12 # Convert Ha to acres
                    end
                end
            end
            
        else
            0.
        end
    end
    roomsingle(m, :Agriculture, :production, :rainfedareas, gen)
end

function grad_agriculture_totalirrigation_irrigatedareas(m::Model)
    function generate(rr1, tt, rr2, cc)
        if rr1 != rr2
            0.
        else
            max(0., m.parameters[:water_demand].values[cc] - m.parameters[:precipitation].values[rr1, tt]) / 100
        end
    end

    roomsingle(m, :Agriculture, :totalirrigation, :irrigatedareas, generate)
end

function grad_agriculture_allagarea_irrigatedareas(m::Model)
    roomsingle(m, :Agriculture, :allagarea, :irrigatedareas, (rr1, rr2, cc) -> (rr1 == rr2 ? 1. : 0.))
end

function grad_agriculture_allagarea_rainfedareas(m::Model)
    roomsingle(m, :Agriculture, :allagarea, :rainfedareas, (rr1, rr2, cc) -> (rr1 == rr2 ? 1. : 0.))
end

function constraintoffset_agriculture_allagarea(m::Model)
    hallsingle(m, :Agriculture, :allagarea, (rr) -> areas[rr,1])
end

function grad_agriculture_cost_rainfedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :rainfedareas, (rr, cc) -> cultivation_costs[crops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end

function grad_agriculture_cost_irrigatedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :irrigatedareas, (rr, cc) -> cultivation_costs[crops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end