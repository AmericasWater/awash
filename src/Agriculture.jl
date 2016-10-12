
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
    
    #Unit cultivation cost 
    #cultivation_costs=Parameter(index=[crops],unit="dollar per Acre")
    
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

    # Total production: lb or bu
    production = Variable(index=[regions, crops, time], unit="lborbu")
    # Cultivation costs per acre
    cultivationcost = Variable(index=[regions, crops, time], unit="\$")
end

function run_timestep(s::Agriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    for rr in d.regions
        totalirrigation = p.othercropsirrigation[rr, tt]
        allagarea = p.othercropsarea[rr, tt]
        for cc in d.crops
            v.totalareas[rr, cc, tt] = p.irrigatedareas[rr, cc, tt] + p.rainfedareas[rr, cc, tt]
            allagarea += v.totalareas[rr, cc, tt]

            # Calculate deficit by crop, for unirrigated areas
            v.water_deficit[rr, cc, tt] = max(0., p.water_demand[cc] - p.precipitation[rr, tt])

            # Calculate irrigation water, summed across all crops: 1 mm * Ha^2 = 10 m^3
            totalirrigation += v.water_deficit[rr, cc, tt] * p.irrigatedareas[rr, cc, tt] / 100
            
            # Calculate rainfed yield
            v.lograinfedyield[rr, cc, tt] = p.logirrigatedyield[rr, cc, tt] + p.deficit_coeff[rr, cc] * v.water_deficit[rr, cc, tt]
            
            # Calculate total production
            v.production[rr, cc, tt] = exp(p.logirrigatedyield[rr, cc, tt]) * p.irrigatedareas[rr, cc, tt] * 2.47105 + exp(v.lograinfedyield[rr, cc, tt]) * p.rainfedareas[rr, cc, tt] * 2.47105 # convert acres to Ha
            # Calculate cultivation cost 
            v.cultivationcost[rr,cc,tt]=v.totalareas[rr,cc,tt]*cultivation_costs[crops[cc]]*2.47105
            
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

                deficit_coeff[rr, cc] = min(0., thismodel.wreq) # must be negative
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
    agriculture[:precipitation] = precip

    # Load in planted area by water management
    rainfeds = readtable(joinpath(todata, "Colorado/rainfedareas_colorado.csv"))
    irrigateds = readtable(joinpath(todata, "Colorado/irrigatedareas_colorado.csv"))
    for cc in 2:ncol(rainfeds)
        # Replace NAs with 0, and convert to float. TODO: improve this
        rainfeds[isna(rainfeds[cc]), cc] = 0.
        irrigateds[isna(irrigateds[cc]), cc] = 0.
        # Convert to Ha
        rainfeds[cc] = rainfeds[cc] * 0.404686
        irrigateds[cc] = irrigateds[cc] * 0.404686
    end
    agriculture[:rainfedareas] = repeat(convert(Matrix, rainfeds[:, 2:end]), outer=[1, 1, numsteps])
    agriculture[:irrigatedareas] = repeat(convert(Matrix, irrigateds[:, 2:end]), outer=[1, 1, numsteps])

    knownareas = readtable(datapath("Colorado/knownareas_colorado.csv"))
    #knownareas = readtable(datapath("agriculture/knownareas.csv"))
    agriculture[:othercropsarea] = repeat(convert(Vector, knownareas[:total] - knownareas[:known]), outer=[1, numsteps])
    
    recorded= readtable(datapath("Colorado/agriculture.csv"));
    #recorded = readtable(datapath("extraction/USGS-2010.csv"))

    othercropirrigation = ((knownareas[:total] - knownareas[:known]) ./ knownareas[:total]) * config["timestep"] .* recorded[:, 3] * 1382592. / (1000. * 12)

    othercropirrigation[knownareas[:total] .== 0] = 0
    agriculture[:othercropsirrigation] = repeat(convert(Vector, othercropirrigation), outer=[1, numsteps])

    
    agriculture
end

function grad_agriculture_production_irrigatedareas(m::Model)
    roomdiagonal(m, :Agriculture, :production, :irrigatedareas, (rr, cc, tt) -> exp(m.parameters[:logirrigatedyield].values[rr, cc, tt]) * 2.47105 * .99 / config["timestep"]) # Convert Ha to acres
    # 1% lost to irrigation technology (makes irrigated and rainfed not perfectly equivalent)
end

function grad_agriculture_production_rainfedareas(m::Model)
    gen(rr, cc, tt) = exp(m.parameters[:logirrigatedyield].values[rr, cc, tt] + m.parameters[:deficit_coeff].values[rr, cc] * max(0., m.parameters[:water_demand].values[cc] - m.parameters[:precipitation].values[rr, tt])) * 2.47105 / config["timestep"] # Convert Ha to acres
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
    function generate(A, tt)
        for rr in 1:numcounties
            for cc in 1:numcrops
                A[rr, fromindex([rr, cc], [numcounties, numcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :Agriculture, :allagarea, :rainfedareas, generate)
end

function constraintoffset_agriculture_allagarea(m::Model)
    hallsingle(m, :Agriculture, :allagarea, (rr, tt) -> countylandareas[rr] - m.parameters[:othercropareas][rr, tt])
end

function grad_agriculture_cost_rainfedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :rainfedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105 / config["timestep"]) # convert acres to Ha
end

function grad_agriculture_cost_irrigatedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :irrigatedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105 / config["timestep"]) # convert acres to Ha
end
