using NaNMath, DataArrays, CSV

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

includeus = true
profitfix = true
limityield = "ignore" #"lybymc" #"zeroy" # "limity"
bayesdir = "posterior_distributions_variance"
cropdirs = ["barley", "corn", "cotton", "rice", "soybean", "wheat"]

irrigation = CSV.read("irrigation.csv")

# trendyear = 62 + 60
for trendyear in [62, 62 + 40, 62 + 60]
for changeirr in ["skip"] #, false, true] XXX
if changeirr == "skip" && trendyear != 62
    continue
end
    
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
irr_crops = [:BARLEY, :CORN, :COTTON, :RICE, :SOYBEANS, :WHEAT]
    
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
    bayes_wreq = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta2.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_gdds = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta3.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_kdds = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta4.txt"), separator=' ', header=false)[:, 1:3111];

    if changeirr == true
        b0s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b0.txt"), separator=' ', header=false))
        b1s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b1.txt"), separator=' ', header=false))
        b2s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b2.txt"), separator=' ', header=false))
        b3s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b3.txt"), separator=' ', header=false))
        b4s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b4.txt"), separator=' ', header=false))
    end

    wreq_max = maximum(Missings.skipmissing(irrigation[:, Symbol("wreq$(irr_crops[ii])")]))
    
    df = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/fips_usa.csv"))
    for rr in 1:nrow(df)
        regionid = df[rr, :FIPS]
        weatherrow = findfirst(masterregions[:fips] .== canonicalindex(regionid))
        
        try # fails if weatherrow == 0 or NAs in gdds or kdds
            if changeirr == true
                intercept = bayes_intercept[:, rr] + b0s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
                time_coeff = bayes_time[:, rr] + b1s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
                wreq_coeff = bayes_wreq[:, rr] + b2s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
                gdds_coeff = bayes_gdds[:, rr] + b3s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
                kdds_coeff = bayes_kdds[:, rr] + b4s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
            else
                intercept = bayes_intercept[:, rr]
                wreq_coeff = bayes_wreq[:, rr]
                gdds_coeff = bayes_gdds[:, rr]
                kdds_coeff = bayes_kdds[:, rr]
                time_coeff = bayes_time[:, rr]
            end

            gdds_row = convert(Matrix{Float64}, gdds[weatherrow, end-9:end]) #2:end])
            kdds_row = convert(Matrix{Float64}, kdds[weatherrow, end-9:end]) #2:end])
            time_row = trendyear # Give all yields as 2010; otherwise collect(1:61)
            price_row = price[weatherrow]
            costs_row = costs[weatherrow]
            if ismissing(irrigation[weatherrow, Symbol("wreq$(irr_crops[ii])")])
                wreq_row = wreq_max
            else
                wreq_row = irrigation[weatherrow, Symbol("wreq$(irr_crops[ii])")]
            end
                                  
            if profitfix && profitfixdf[weatherrow, :obscrop] == crop
                costs_row -= profitfixdf[weatherrow, :toadd]
            end

            if changeirr == "skip"
                logyield = intercept .+ wreq_coeff * wreq_row .+ gdds_coeff * gdds_row .+ kdds_coeff * kdds_row .+ time_coeff * time_row
            else
                logyield = intercept .+ gdds_coeff * gdds_row .+ kdds_coeff * kdds_row .+ time_coeff * time_row
            end
            if limityield == "lybymc"
                logyield = vec(logyield)
                logyield[logyield .> log(maximum_yields[crop])] = NaN
            end
            yield_total = NaNMath.mean(exp.(logyield))
            if limityield != "ignore" && yield_total > maximum_yields[crop]
                if limityield == "limity"
                    yield_total = maximum_yields[crop]
                elseif limityield == "zeroy"
                    yield_total = 0
                end
            end

            allyields[ii, weatherrow] = yield_total

            profit = yield_total * price_row - costs_row

            allprofits[ii, weatherrow] = profit

            if profit > get(maxprofit, regionid, [-Inf])[1]
                maxprofit[regionid] = [profit, crop, yield_total, price_row, costs_row]
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
if changeirr == true
    push!(suffixes, "chirr")
elseif changeirr == "skip"
    push!(suffixes, "allir")
end
if length(suffixes) > 0
    suffixes = [""; suffixes]
end
if trendyear != 62
    push!(suffixes, "$(2010+trendyear - 62)")
end
suffix = join(suffixes, "-")

writecsv("currentprofits$suffix.csv", allprofits')
writecsv("currentyields$suffix.csv", allyields')

result = DataFrame(fips=Int64[], profit=Float64[], crop=String[], yield=Float64[], price=Float64[], costs=Float64[])

for fips in keys(maxprofit)
    push!(result, [fips; maxprofit[fips]])
end

CSV.write("maxbayesian$suffix.csv", result)
end
end
