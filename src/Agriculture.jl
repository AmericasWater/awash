using DataFrames
using Mimi

water_requirements = Dict("alfalfa" => 1.63961100235402, "otherhay" => 1.63961100235402,
                          "Barley" => 1.18060761343329, "Barley.Winter" => 1.18060761343329,
                          "Maize" => 1.47596435526564,
                          "Sorghum" => 1.1364914374721,
                          "Soybeans" => 1.37599595071683,
                          "Wheat" => 0.684836198198068, "Wheat.Winter" => 0.684836198198068) # in m

# Per year costs
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

if isfile(joinpath(todata, "cache/agmodels.jld"))
    println("Loading from saved region network...")

    agmodels = deserialize(open(joinpath(todata, "cache/agmodels.jld"), "r"));
else
    # Prepare all the agricultural models
    agmodels = Dict{UTF8String, Dict{Int64, StatisticalAgricultureModel}}() # {crop: {fips: model}}
    nationals = readtable(joinpath(todata, "agriculture/nationals.csv"))
    for crop in crops
        agmodels[crop] = Dict{Int64, StatisticalAgricultureModel}()

        # Create the national model
        national = StatisticalAgricultureModel(nationals, :crop, crop)
        counties = readtable(joinpath(todata, "agriculture/unpooled-$crop.csv"))
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

    serialize(open(joinpath(todata, "cache/agmodels.jld"), "w"), agmodels)
end

@defcomp Agriculture begin
    year = Index()
    regions = Index()
    crops = Index()

    # Optimized
    # Land area appropriated to each crop, irrigated to full demand (Ha)
    irrigatedareas = Parameter(index=[regions, crops, year], unit="Ha") # vs. year
    rainfedareas = Parameter(index=[regions, crops, year], unit="Ha") # vs. year

    # Internal
    # Yield base: combination of GDDs, KDDs, and intercept
    logirrigatedyield = Parameter(index=[regions, crops, year], unit="none") # vs. year

    # Coefficient on the effects of water deficits
    deficit_coeff = Parameter(index=[regions, crops], unit="1/mm")

    # Water requirements per unit area, in mm
    water_demand = Parameter(index=[crops], unit="mm")

    # Precipitation water per unit area, in mm
    precipitation = Parameter(index=[regions, time], unit="mm")

    # Computed
    # Land area appropriated to each crop
    totalareas = Variable(index=[regions, crops, year], unit="Ha") # vs. year
    # Total agricultural area
    allagarea = Variable(index=[regions, year], unit="Ha") # vs. year

    # Deficit for any unirrigated areas, in mm
    water_deficit = Variable(index=[regions, crops, time], unit="mm")

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, time], unit="1000 m^3")

    # Yield per hectare for rainfed (irrigated has irrigatedyield)
    lograinfedyield = Variable(index=[regions, crops, year], unit="none") # vs. year

    # Total production: lb or bu
    production = Variable(index=[regions, crops, year], unit="lborbu") # vs. year
    # Cultivation costs per acre
    cultivationcost = Variable(index=[regions, crops, time], unit="\$")
end

function run_timestep(s::Agriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    yy = index2yearindex(tt)

    for rr in d.regions
        totalirrigation = 0.
        allagarea = 0.
        for cc in d.crops
            # Calculate deficit by crop, for unirrigated areas
            v.water_deficit[rr, cc, tt] = max(0., p.water_demand[cc] * config["timestep"] / 12. - p.precipitation[rr, tt]) # mm / month

            # Calculate every time, even though it's the same
            v.totalareas[rr, cc, yy] = p.irrigatedareas[rr, cc, yy] + p.rainfedareas[rr, cc, yy]
            allagarea += v.totalareas[rr, cc, yy]

            # Calculate irrigation water, summed across all crops: 1 mm * Ha^2 = 10 m^3
            totalirrigation += v.water_deficit[rr, cc, tt] * p.irrigatedareas[rr, cc, yy] / 100

            if index2time(tt) % 12 == 0 && tt >= 12 / config["timestep"] # December
                # Calculate rainfed yield
                v.lograinfedyield[rr, cc, yy] = p.logirrigatedyield[rr, cc, yy] + p.deficit_coeff[rr, cc] * sum(v.water_deficit[rr, cc, tt-11:tt])

                # Calculate total production
                v.production[rr, cc, yy] = exp(p.logirrigatedyield[rr, cc, yy]) * p.irrigatedareas[rr, cc, yy] * 2.47105 + exp(v.lograinfedyield[rr, cc, yy]) * p.rainfedareas[rr, cc, yy] * 2.47105 # convert acres to Ha
            end
        end

        v.totalirrigation[rr, tt] = totalirrigation
        v.allagarea[rr, yy] = allagarea
    end
end

function initagriculture(m::Model)
    # precip loaded by weather.jl

    # Match up values by FIPS
    logirrigatedyield = -Inf * ones(numcounties, numcrops, numsteps)
    deficit_coeff = zeros(numcounties, numcrops)
    for rr in 1:numcounties
        for cc in 1:numcrops
            fips = parse(Int64, mastercounties[rr, :fips])
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

    agriculture[:logirrigatedyield] = logirrigatedyield
    agriculture[:deficit_coeff] = deficit_coeff
    agriculture[:water_demand] = water_demand
    agriculture[:precipitation] = precip

    # Load in planted area by water management
    rainfeds = readtable(joinpath(todata, "agriculture/rainfedareas.csv"))
    irrigateds = readtable(joinpath(todata, "agriculture/irrigatedareas.csv"))
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
    hallsingle(m, :Agriculture, :allagarea, (rr, tt) -> countylandareas[rr])
end

function grad_agriculture_cost_rainfedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :rainfedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105 / config["timestep"]) # convert acres to Ha
end

function grad_agriculture_cost_irrigatedareas(m::Model)
    roomdiagonal(m, :Agriculture, :cultivationcost, :irrigatedareas, (rr, cc, tt) -> cultivation_costs[crops[cc]] * 2.47105 / config["timestep"]) # convert acres to Ha
end
