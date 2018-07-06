using NaNMath, DataArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

includeus = true
profitfix = true
limityield = "ignore" #"lybymc" #"zeroy" # "limity"
bayesdir = "posterior_distributions_variance"
cropdirs = ["barley", "corn", "cotton", "rice", "soybean", "wheat"]

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

bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
edds_crops = ["Barley", "Maize", "Cotton", "Rice", "Soybeans", "Wheat"]
for ii in 1:length(bayes_crops)
    crop = bayes_crops[ii]
    println(crop)
    # Load degree day data
    gdds = readtable(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-gdd.csv")));
    kdds = readtable(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-kdd.csv")));

    price = ers_information(ers_crop(crop), "price", 2010; includeus=includeus);
    costs = ers_information(ers_crop(crop), "opcost", 2010; includeus=includeus);

    bayes_intercept = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_alpha.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_time = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta1.txt"), separator=' ', header=false)[:, 1:3111];
    # bayes_wreq = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta2.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_gdds = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta3.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_kdds = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta4.txt"), separator=' ', header=false)[:, 1:3111];

    df = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/fips_usa.csv"))
    for rr in 1:nrow(df)
        regionid = df[rr, :FIPS]

        intercept = bayes_intercept[:, rr]
        gdds_coeff = bayes_gdds[:, rr]
        kdds_coeff = bayes_kdds[:, rr]
        time_coeff = bayes_time[:, rr]

        weatherrow = findfirst(masterregions[:fips] .== canonicalindex(regionid))
        try # fails if weatherrow == 0 or NAs in gdds or kdds
            gdds_row = convert(Matrix{Float64}, gdds[weatherrow, end-9:end]) #2:end])
            kdds_row = convert(Matrix{Float64}, kdds[weatherrow, end-9:end]) #2:end])
            time_row = 62 # Give all yields as 2010; otherwise collect(1:61)
            price_row = price[weatherrow]
            costs_row = costs[weatherrow]
            if profitfix && profitfixdf[weatherrow, :obscrop] == crop
                costs_row -= profitfixdf[weatherrow, :toadd]
            end

            logyield = intercept .+ gdds_coeff * gdds_row + kdds_coeff * kdds_row .+ time_coeff * time_row
            if limityield == "lybymc"
                logyield = vec(logyield)
                logyield[logyield .> log(maximum_yields[crop])] = NaN
            end
            yield_irrigated = NaNMath.mean(exp.(logyield))
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
