using NaNMath, CSV

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")
include("curryield.jl")

includeus = true
bayesdir = "posterior_distributions_variance"

#limityield = "ignore" #"lybymc" #"zeroy" # "limity"
# trendyear = 62 + 60
for limityield in ["ignore", "lybymc"] #["lybymc"]
for profitfix in ["modeled", true] #[false]
for trendyear in [62, 62 + 40, 62 + 60]
for changeirr in ["skip", false, true] #[true]
if changeirr == "skip" && (trendyear != 62 || profitfix == "modeled")
    continue
end

if profitfix != false
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
    
for ii in 1:length(bayes_crops)
    crop = bayes_crops[ii]
    println(crop)

    prepdata = preparecrop(crop, changeirr)
    
    price = ers_information(ers_crop(crop), "price", 2010; includeus=includeus);
    costs = ers_information(ers_crop(crop), "opcost", 2010; includeus=includeus);
    
    df = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/fips_usa.csv"))
    for rr in 1:nrow(df)
        regionid = df[rr, :FIPS]
        weatherrow = findfirst(masterregions[:fips] .== canonicalindex(regionid))
        
        try # fails if weatherrow == 0 or NAs in gdds or kdds
            yield_total = getyield(rr, weatherrow, changeirr, trendyear, limityield, prepdata)
            
            allyields[ii, weatherrow] = yield_total

            price_row = price[weatherrow]
            costs_row = costs[weatherrow]
            if profitfix != false && profitfixdf[weatherrow, :obscrop] == crop
                if profitfix == true
                    costs_row -= profitfixdf[weatherrow, :toadd]
                elseif !changeirr
                    costs_row -= profitfixdf[weatherrow, :esttoadd] + .01
                else
                    costs_row -= profitfixdf[weatherrow, :esttoadd_changeirr] + .01
                end
            end

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
if profitfix == true
    push!(suffixes, "pfixed")
elseif profitfix == "modeled"
    push!(suffixes, "pfixmo")
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
end
end
