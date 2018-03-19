using NaNMath

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

includeus = true
profitfix = true
limityield = "lybymc" #"zeroy" # "ignore" "limity"

if profitfix
    profitfixdf = readtable("farmvalue-limited.csv")
    profitfixdf[profitfixdf[:obscrop] .== "barl", :obscrop] = "Barley"
    profitfixdf[profitfixdf[:obscrop] .== "corn", :obscrop] = "Corn"
    profitfixdf[profitfixdf[:obscrop] .== "cott", :obscrop] = "Cotton"
    profitfixdf[profitfixdf[:obscrop] .== "rice", :obscrop] = "Rice"
    profitfixdf[profitfixdf[:obscrop] .== "soyb", :obscrop] = "Soybean"
    profitfixdf[profitfixdf[:obscrop] .== "whea", :obscrop] = "Wheat"
end

maxprofit = Dict{Int64, Vector{Any}}()

allprofits = -Inf * ones(6, nrow(masterregions)) # crop, region
allyields = zeros(6, nrow(masterregions))

maximum_yields = Dict("Barley" => 176.5, "Corn" => 246, "Cotton" => 3433.,
                      "Rice" => 10180, "Soybean" => 249, "Wheat" => 142.5)

# NOTE: Using otherhay edds for cotton and rice
bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
edds_crops = ["Barley", "Maize", "Cotton", "Rice", "Soybeans", "Wheat"]
for ii in 1:length(bayes_crops)
    crop = bayes_crops[ii]
    println(crop)
    # Load degree day data
    gdds = readtable(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-gdd.csv")))
    kdds = readtable(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-kdd.csv")))

    price = ers_information(ers_crop(crop), "price", 2010; includeus=includeus)
    costs = ers_information(ers_crop(crop), "cost", 2010; includeus=includeus)

    bayespath = datapath("agriculture/bayesian/$(crop).csv")
    df = readtable(bayespath)
    for regionid in unique(regionindex(df, :, tostr=false))
        intercept = df[(df[:fips] .== regionid) .& (df[:coef] .== "intercept"), :mean][1]
        gdds_coeff = df[(df[:fips] .== regionid) .& (df[:coef] .== "gdds"), :mean][1]
        kdds_coeff = df[(df[:fips] .== regionid) .& (df[:coef] .== "kdds"), :mean][1]
        time_coeff = df[(df[:fips] .== regionid) .& (df[:coef] .== "time"), :mean][1]
        wreq_coeff = df[(df[:fips] .== regionid) .& (df[:coef] .== "wreq"), :mean][1]

        weatherrow = findfirst(masterregions[:fips] .== canonicalindex(regionid))
        try
            gdds_row = convert(Matrix{Float64}, gdds[weatherrow, 2:end])
            kdds_row = convert(Matrix{Float64}, kdds[weatherrow, 2:end])
            time_row = 2010 # Give all yields as 2010; otherwise collect(1949:2009)
            price_row = price[weatherrow]
            costs_row = costs[weatherrow]
            if profitfix && profitfixdf[weatherrow, :obscrop] == crop
                costs_row -= profitfixdf[weatherrow, :toadd]
            end

            logyield = intercept + gdds_coeff * gdds_row + kdds_coeff * kdds_row + time_coeff * time_row
            if limityield == "lybymc"
                logyield[logyield .> log(maximum_yields[crop])] = NA
            end
            yield_irrigated = exp(NaNMath.mean(logyield))
            if limityield != "ignore" && yield_irrigated > maximum_yields[crop]
                if limityield == "limity"
                    yield_irrigated = maximum_yields[crop]
                elseif limityield == "zeroy"
                    yield_irrigated = 0
                end
            end

            allyields[ii, weatherrow] = yield_irrigated

            profit = yield_irrigated * price_row - costs_row

            allprofits[ii, weatherrow] = profit

            if profit > get(maxprofit, regionid, [-Inf])[1]
                maxprofit[regionid] = [profit, crop, yield_irrigated, price_row, costs_row]
            end
        end
    end
end

suffixes = []
if !includeus
    push!(suffixes, "erslimited")
end
if profitfix
    push!(suffixes, "pfixed")
end
if limityield != "ignore"
    push!(suffixes, limityield)
end
if length(suffixes) > 0
    suffixes = [""; suffixes]
end
suffix = join(suffixes, "-")

writecsv("currentprofits$suffix.csv", allprofits')
writecsv("currentyields$suffix.csv", allyields')

result = DataFrame(fips=Int64[], profit=Float64[], crop=String[], yield=Float64[], price=Float64[], costs=Float64[])

for fips in keys(maxprofit)
    push!(result, [fips; maxprofit[fips]])
end

writetable("maxbayesian$suffix.csv", result)
