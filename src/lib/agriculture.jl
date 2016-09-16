using DataFrames

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

maximum_yields = Dict("alfalfa" => 25., "otherhay" => 25.,
                      "Barley" => 200., "Barley.Winter" => 200.,
                      "Maize" => 250.,
                      "Sorghum" => 150.,
                      "Soybeans" => 100.,
                      "Wheat" => 250., "Wheat.Winter" => 250.)

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

function fallbackpool(meanfallback, sdevfallback, mean1, sdev1)
    if isna(mean1)
        meanfallback, sdevfallback
    else
        mean1, sdev1
    end
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
        if isfile(joinpath(todata, "agriculture/bayesian/$crop.csv"))
            counties = readtable(joinpath(todata, "agriculture/bayesian/$crop.csv"))
            combiner = fallbackpool
        else
            counties = readtable(joinpath(todata, "agriculture/unpooled-$crop.csv"))
            combiner = gaussianpool
        end

        for fips in unique(counties[:fips])
            county = StatisticalAgricultureModel(counties, :fips, fips)

            # Construct a pooled or fallback combination
            gdds, gddsse = combiner(national.gdds, national.gddsse, county.gdds, county.gddsse)
            kdds, kddsse = combiner(national.kdds, national.kddsse, county.kdds, county.kddsse)
            wreq, wreqse = combiner(national.wreq, national.wreqse, county.wreq, county.wreqse)
            agmodel = StatisticalAgricultureModel(county.intercept, county.interceptse, gdds, gddsse, kdds, kddsse, wreq, wreqse)
            agmodels[crop][fips] = agmodel
        end
    end

    serialize(open(joinpath(todata, "cache/agmodels.jld"), "w"), agmodels)
end
