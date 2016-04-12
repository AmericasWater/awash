using DataFrames
using Mimi

water_requirements = Dict("alfalfa" => 1.63961100235402, "otherhay" => 1.63961100235402,
                          "Barley" => 1.18060761343329, "Barley.Winter" => 1.18060761343329,
                          "Maize" => 1.47596435526564,
                          "Sorghum" => 1.1364914374721,
                          "Soybeans" => 1.37599595071683,
                          "Wheat" => 0.684836198198068, "Wheat.Winter" => 0.684836198198068) # in m

cultivation_costs = Dict("alfalfa" => 306., "otherhay" => 306.,
                         "Barley" => 442., "Barley.Winter" => 442.,
                         "Maize" => 554.,
                         "Sorghum" => 314.,
                         "Soybeans" => 221.,
                         "Wheat" => 263., "Wheat.Winter" => 263.) # USD / acre

maximum_yield = 100. # total arbitrary number, because of some crazy outliers

type StatisticalAgricultureModel
    intercept::Float64
    interceptse::Float64
    gdds::Float64
    gddsse::Float64
    kdds::Float64
    kddsse::Float64
    wreq::Float64
    wreqse::Float64
end

function StatisticalAgricultureModel(df::DataFrame, filter::Symbol, fvalue::Any)
    interceptrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "intercept"))
    gddsrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "gdds"))
    kddsrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "kdds"))
    wreqrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "wreq"))

    if interceptrow > 0
        intercept = df[interceptrow, :mean]
        interceptse = df[interceptrow, :serr]
    else
        intercept = 0
        interceptse = 0
    end

    gdds = df[gddsrow, :mean]
    gddsse = df[gddsrow, :serr]
    kdds = df[kddsrow, :mean]
    kddsse = df[kddsrow, :serr]
    wreq = df[wreqrow, :mean]
    wreqse = df[wreqrow, :serr]

    StatisticalAgricultureModel(intercept, interceptse, gdds, gddsse, kdds, kddsse, wreq, wreqse)
end

function gaussianpool(mean1, sdev1, mean2, sdev2)
    (mean1 / sdev1^2 + mean2 / sdev2^2) / (1 / sdev1^2 + 1 / sdev2^2), 1 / (1 / sdev1^2 + 1 / sdev2^2)
end

if isfile(joinpath(todata, "agmodels.jld"))
    println("Loading from saved region network...")

    agmodels = deserialize(open(joinpath(todata, "agmodels.jld"), "r"));
else
    # Prepare all the agricultural models
    agmodels = Dict{UTF8String, Dict{Int64, StatisticalAgricultureModel}}() # {crop: {fips: model}}
    nationals = readtable("../data/nationals.csv")
    for crop in crops
        agmodels[crop] = Dict{Int64, StatisticalAgricultureModel}()

        # Create the national model
        national = StatisticalAgricultureModel(nationals, :crop, crop)
        counties = readtable("../data/unpooled-$crop.csv")
        for fips in unique(counties[:fips])
            county = StatisticalAgricultureModel(counties, :fips, fips)
            # Construct a pooled combination
            gdds, gddsse = gaussianpool(national.gdds, national.gddsse, county.gdds, county.gddsse)
            kdds, kddsse = gaussianpool(national.kdds, national.kddsse, county.kdds, county.kddsse)
            wreq, wreqse = gaussianpool(national.wreq, national.wreqse, county.wreq, county.wreqse)
            agmodel = StatisticalAgricultureModel(county.intercept, county.interceptse, gdds, gddsse, kdds, kddsse, wreq, wreqse)
            agmodels[crop][fips] = agmodel
        end
    end

    serialize(open(joinpath(todata, "agmodels.jld"), "w"), agmodels)
end

@defcomp Agriculture begin
    regions = Index()
    crops = Index()

    # Optimized
    # Land area appropriated to each crop, irrigated to full demand (Ha)
    irrigatedareas = Parameter(index=[regions, crops, time])
    rainfedareas = Parameter(index=[regions, crops, time])

    # Internal
    # Yield base: combination of GDDs, KDDs, and intercept
    logirrigatedyield = Parameter(index=[regions, crops, time])

    # Coefficient on the effects of water deficits
    deficit_coeff = Parameter(index=[regions, crops])

    # Water requirements per unit area, in mm
    water_demand = Parameter(index=[crops])

    # Precipitation water per unit area, in mm
    precipitation = Parameter(index=[regions, time])

    # Computed
    # Land area appropriated to each crop
    totalareas = Variable(index=[regions, crops, time])
    # Total agricultural area
    allagarea = Variable(index=[regions, time])

    # Deficit for any unirrigated areas, in mm
    water_deficit = Variable(index=[regions, crops, time])

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, time])

    # Yield per hectare for rainfed (irrigated has irrigatedyield)
    lograinfedyield = Variable(index=[regions, crops, time])

    # Total production: lb or bu
    production = Variable(index=[regions, crops, time])
    # Cultivation costs per acre
    cultivationcost = Variable(index=[regions, crops, time])
end

function timestep(s::Agriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    for rr in d.regions
        totalirrigation = 0.
        allagarea = 0.
        for cc in d.crops
            v.totalareas[rr, cc, tt] = p.irrigatedareas[rr, cc, tt] + p.rainfedareas[rr, cc, tt]
            allagarea += v.totalareas[rr, cc, tt]

            # Calculate deficit by crop, for unirrigated areas
            v.water_deficit[rr, cc, tt] = p.water_demand[cc] - p.precipitation[rr, tt]

            # Calculate irrigation water, summed across all crops: 1 mm * Ha^2 = 10 m^3
            totalirrigation += v.water_deficit[rr, cc, tt] * p.irrigatedareas[rr, cc, tt] / 100

            # Calculate rainfed yield
            v.lograinfedyield[rr, cc, tt] = p.logirrigatedyield[rr, cc, tt] + p.deficit_coeff[rr, cc] * v.water_deficit[rr, cc, tt]

            # Calculate total production
            v.production[rr, cc, tt] = exp(p.logirrigatedyield[rr, cc, tt]) * p.irrigatedareas[rr, cc, tt] * 2.47105 + exp(v.lograinfedyield[rr, cc, tt]) * p.rainfedareas[rr, cc, tt] * 2.47105 # convert acres to Ha
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
    for rr in 1:numcounties
        for cc in 1:numcrops
            fips = parse(Int64, names[rr])
            if fips in keys(agmodels[crops[cc]])
                thismodel = agmodels[crops[cc]][fips]
                logirrigatedyield[rr, cc, :] = repmat([min(thismodel.intercept, log(maximum_yield))], numsteps)
                deficit_coeff[rr, cc] = min(0., thismodel.wreq) # must be negative
            end
        end
    end

    water_demand = zeros(numcrops)
    for cc in 1:numcrops
        water_demand[cc] = water_requirements[crops[cc]] * 1000
    end

    agriculture = addcomponent(m, Agriculture)

    agriculture[:logirrigatedyield] = repeat(logirrigatedyield, outer=[1, 1, numsteps])
    agriculture[:deficit_coeff] = deficit_coeff
    agriculture[:water_demand] = water_demand
    agriculture[:precipitation] = precip

    # Zero the optimized parameters
    agriculture[:rainfedareas] = zeros(numcounties, numcrops, numsteps)
    agriculture[:irrigatedareas] = zeros(numcounties, numcrops, numsteps)

    agriculture
end

function grad_agriculture_irrigatedareas_production(m::Model)
    roomdiagonal(m, :Agriculture, :production, :irrigatedareas, (rr, cc, tt) -> exp(m.parameters[:logirrigatedyield].values[rr, cc, tt]) * 2.47105 * .99) # Convert Ha to acres
    # 1% lost to irrigation technology (makes irrigated and rainfed not perfectly equivalent)
end

function grad_agriculture_rainfedareas_production(m::Model)
    gen(rr, cc, tt) = exp(m.parameters[:logirrigatedyield].values[rr, cc, tt] + m.parameters[:deficit_coeff].values[rr, cc] * max(0., m.parameters[:water_demand].values[cc] - m.parameters[:precipitation].values[rr, tt])) * 2.47105 # Convert Ha to acres
    roomdiagonal(m, :Agriculture, :production, :rainfedareas, gen)
end

function grad_agriculture_irrigatedareas_totalirrigation(m::Model)
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

function grad_agriculture_irrigatedareas_allagarea(m::Model)
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

function grad_agriculture_rainfedareas_allagarea(m::Model)
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
    hallsingle(m, :Agriculture, :allagarea, (rr, tt) -> countylandareas[rr])
end

function grad_agriculture_rainfedareas_cost(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :rainfedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105) # convert acres to Ha
end

function grad_agriculture_irrigatedareas_cost(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :irrigatedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105) # convert acres to Ha
end
