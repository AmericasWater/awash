using DataFrames

## Univariate crop parametrs
#unicrop_irrigationrate = Dict("barley" => 12.9, "corn" => 13.0,
#                              "sorghum" => 0., "soybeans" => 16.8,
#                              "wheat" => 21.4, "hay" => 0.) # mm/year
#unicrop_irrigationrate = Dict("barley" => 121.8, "corn" => 187.2,
#                              "sorghum" => 31.2, "soybeans" => 0.0,
#                              "wheat" => 54.8, "hay" => 0.0) # mm/year

#unicrop_irrigationstress = Dict("barley" => 0.0, "corn" => 0.0,
#                                "sorghum" => 0.0, "soybeans" => 0.0,
#                                "wheat" =>54.8, "hay" => 0.0) # (mm/year) / m-deficiency
#unicrop_irrigationstress = Dict("barley" => 95.2, "corn" => 73.1,
#                                "sorghum" => 0., "soybeans" => 0.,
#                                "wheat" => 7.4, "hay" => 0.) # (mm/year) / m-deficiency


unicrop_irrigationrate = Dict("barley" => 1530.148, "corn" => 0,
                              "sorghum" => 0, "soybeans" => 0.0,
                              "wheat" => 0, "hay" => 0.0) # mm/year

unicrop_irrigationstress = Dict("barley" => 298.8803, "corn" => 1864.5602,
                                "sorghum" => 499.6120, "soybeans" => 153.5861,
                                "wheat" => 194.1666, "hay" => 2017.1677) # (mm/year) / m-deficiency


# Irrigation crop parameters
water_requirements = Dict("alfalfa" => 1.63961100235402, "otherhay" => 1.63961100235402,
                          "Barley" => 1.18060761343329, "Barley.Winter" => 1.18060761343329,
                          "Maize" => 1.47596435526564,
                          "Sorghum" => 1.1364914374721,
                          "Soybeans" => 1.37599595071683,
                          "Wheat" => 0.684836198198068, "Wheat.Winter" => 0.684836198198068,
"barley" => 1.18060761343329, "corn" => 1.47596435526564,
"sorghum" => 1.1364914374721, "soybeans" => 1.37599595071683,
"wheat" => 0.684836198198068, "hay" => 1.63961100235402) # in m


crop_demands=Dict("alfalfa" =>  7.66038e6, "otherhay" => 3.12915e6,"Barley" => 4.66905e6, "Barley.Winter" => 0,"Maize" => 7.70103e7,"Sorghum" => 3.95951e6 ,"Soybeans" => 0.0,"Wheat" => 1.10917e5, "Wheat.Winter" => 5.19694e7) 

#crop_demands=Dict("alfalfa" =>  5.60928e10, "otherhay" => 5.60928e10,"Barley" => 2.80464e8, "Barley.Winter" => 2.80464e8,"Maize" => 2.80464e8, "Sorghum" => 5.60928e8 , "Soybeans" =>1.12186e9 ,"Wheat" => 2.80464e9, "Wheat.Winter" => 2.80464e9) 

#areas=convert(Matrix,readtable(datapath("agarea.csv")))



#rainfeds = readtable(joinpath(todata, "Colorado/rainfedareas_colorado.csv"))
#irrigateds = readtable(joinpath(todata, "Colorado/irrigatedareas_colorado.csv"))
#rainfeds=convert(Matrix, rainfeds)*0.404686
#irrigateds=convert(Matrix, irrigateds)*0.404686
#sumareas=rainfeds+irrigateds
#sum_areas=sum(sumareas,2)


# Per year costs
#cultivation_costs = Dict("alfalfa" => 426.55, "otherhay" => 426.55,
#                         "Barley" => 394.71, "Barley.Winter" => 394.71,
#                         "Maize" => 511.65,
#                         "Sorghum" => 327.78,
#                         "Soybeans" => 359.06,
#                         "Wheat" => 271.06, "Wheat.Winter" => 271.06) # USD / acre

cultivation_costs = Dict("alfalfa" => 306., "otherhay" => 306., "Hay" => 306,
                         "Barley" => 442., "Barley.Winter" => 442.,
                         "Maize" => 554.,
                         "Sorghum" => 314.,
                         "Soybeans" => 221.,
                         "Wheat" => 263., "Wheat.Winter" => 263.,
                         "barley" => 442., "corn" => 554.,
                         "sorghum" => 314., "soybeans" => 221.,
"wheat" => 263., "hay" => 306.) # USD / acre

maximum_yields = Dict("alfalfa" => 25., "otherhay" => 25., "Hay" => 306,
                      "Barley" => 200., "Barley.Winter" => 200.,
                      "Maize" => 250.,
                      "Sorghum" => 150.,
                      "Soybeans" => 100.,
                      "Wheat" => 250., "Wheat.Winter" => 250.,
                      "barley" => 200., "corn" => 250.,
                      "sorghum" => 150., "soybeans" => 100.,
"wheat" => 250., "hay" => 306.)

type StatisticalAgricultureModel
    intercept::Float64
    interceptse::Float64
    gdds::Float64
    gddsse::Float64
    kdds::Float64
    kddsse::Float64
    wreq::Float64
    wreqse::Float64

    gddoffset::Float64
    kddoffset::Float64
end

function StatisticalAgricultureModel(df::DataFrame, filter::Symbol, fvalue::Any)
    interceptrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "intercept"))
    gddsrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "gdds"))
    kddsrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "kdds"))
    wreqrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "wreq"))
    gddoffsetrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "gddoffset"))
    kddoffsetrow = findfirst((df[filter] .== fvalue) & (df[:coef] .== "kddoffset"))

    if interceptrow > 0
        intercept = df[interceptrow, :mean]
        interceptse = df[interceptrow, :serr]
    else
        intercept = 0
        interceptse = 0
    end

    gdds = gddsrow != 0 ? df[gddsrow, :mean] : 0
    gddsse = gddsrow != 0 ? df[gddsrow, :serr] : Inf
    kdds = kddsrow != 0 ? df[kddsrow, :mean] : 0
    kddsse = kddsrow != 0 ? df[kddsrow, :serr] : Inf
    wreq = wreqrow != 0 ? df[wreqrow, :mean] : 0
    wreqse = wreqrow != 0 ? df[wreqrow, :serr] : Inf
    gddoffset = gddoffsetrow != 0 ? df[gddoffsetrow, :mean] : 0
    kddoffset = kddoffsetrow != 0 ? df[kddoffsetrow, :mean] : 0

    StatisticalAgricultureModel(intercept, interceptse, gdds, gddsse, kdds, kddsse, wreq, wreqse, gddoffset, kddoffset)
end

function gaussianpool(mean1, sdev1, mean2, sdev2)
    if isna(sdev1) || isnan(sdev1)
        mean2, sdev2
    elseif isna(sdev2) || isnan(sdev2)
        mean1, sdev1
    else
        (mean1 / sdev1^2 + mean2 / sdev2^2) / (1 / sdev1^2 + 1 / sdev2^2), 1 / (1 / sdev1^2 + 1 / sdev2^2)
    end
end

function fallbackpool(meanfallback, sdevfallback, mean1, sdev1)
    if isna(mean1)
        meanfallback, sdevfallback
    else
        mean1, sdev1
    end
end

function findcroppath(prefix, crop, suffix, recurse=true)
    println(prefix * crop * suffix)
    if isfile(datapath(prefix * crop * suffix))
        return datapath(prefix * crop * suffix)
    end

    if isupper(crop[1]) && isfile(datapath(prefix * lcfirst(crop) * suffix))
        return datapath(prefix * lcfirst(crop) * suffix)
    end

    if islower(crop[1]) && isfile(datapath(prefix * ucfirst(crop) * suffix))
        return datapath(prefix * ucfirst(crop) * suffix)
    end

    if !recurse
        return nothing
    end

    croptrans = Dict{AbstractString, Vector{AbstractString}}("corn" => ["maize"], "hay" => ["otherhay"], "maize" => ["corn"])
    if lowercase(crop) in keys(croptrans)
        for crop2 in croptrans[lowercase(crop)]
            path2 = findcroppath(prefix, crop2, suffix, false)
            if path2 != nothing
                return path2
            end
        end
    end

    return nothing
end

if isfile(cachepath("agmodels.jld"))
    println("Loading from saved region network...")

    agmodels = deserialize(open(cachepath("agmodels.jld"), "r"));
else
    # Prepare all the agricultural models
    agmodels = Dict{UTF8String, Dict{UTF8String, StatisticalAgricultureModel}}() # {crop: {fips: model}}
    nationals = readtable(joinpath(datapath("agriculture/nationals.csv")))
    nationalcrop = Dict{UTF8String, UTF8String}("barley" => "Barley", "corn" => "Maize",
                                                "sorghum" => "Sorghum", "soybeans" => "Soybeans",
                                                "wheat" => "Wheat", "hay" => "alfalfa")
    for crop in allcrops
        println(crop)
        agmodels[crop] = Dict{Int64, StatisticalAgricultureModel}()

        # Create the national model
        national = StatisticalAgricultureModel(nationals, :crop, get(nationalcrop, crop, crop))
        bayespath = nothing #findcroppath("agriculture/bayesian/", crop, ".csv")
        if bayespath != nothing
            counties = readtable(bayespath)
            combiner = fallbackpool
        else
            counties = readtable(findcroppath("agriculture/unpooled-", crop, ".csv"))
            combiner = gaussianpool
        end

        for regionid in unique(regionindex(counties, :, tostr=false))
            county = StatisticalAgricultureModel(counties, lastindexcol, regionid)

            # Construct a pooled or fallback combination
            gdds, gddsse = combiner(national.gdds, national.gddsse, county.gdds, county.gddsse)
            kdds, kddsse = combiner(national.kdds, national.kddsse, county.kdds, county.kddsse)
            wreq, wreqse = combiner(national.wreq, national.wreqse, county.wreq, county.wreqse)
            agmodel = StatisticalAgricultureModel(county.intercept, county.interceptse, gdds, gddsse, kdds, kddsse, wreq, wreqse, county.gddoffset, county.kddoffset)
            agmodels[crop][canonicalindex(regionid)] = agmodel
        end
    end

    fp = open(cachepath("agmodels.jld"), "w")
    serialize(fp, agmodels)
    close(fp)
end
