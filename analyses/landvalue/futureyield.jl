using NaNMath, DataArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/single.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

includeus = true
profitfix = true
holdcoeff = false #true
allowtime = false
limityield = "ignore" #"lybymc" #"zeroy" # "limity"
futureyear = 2050
bayesdir = "posterior_distributions_variance"
cropdirs = ["barley", "corn", "cotton", "rice", "soybean", "wheat"]

eddmodels = ["access1-0", "bcc-csm1-1", "ccsm4", "cnrm-cm5", "gfdl-cm3", "giss-e2-r",
             "hadgem2-ao", "hadgem2-es", "hadgem2-cc", "inmcm4", "ipsl-cm5b-lr", "miroc5",
             "mri-cgcm3", "miroc-esm-chem", "mpi-esm-lr", "miroc-esm", "noresm1-m"]
biomodels = ["ac", "bc", "cc", "cn", "gf", "gs",
             "hd", "he", "hg", "in", "ip", "mc",
             "mg", "mi", "mp", "mr" , "no"]

if profitfix
    profitfixdf = readtable("farmvalue-limited.csv")
    profitfixdf[profitfixdf[:obscrop] .== "barl", :obscrop] = "Barley"
    profitfixdf[profitfixdf[:obscrop] .== "corn", :obscrop] = "Corn"
    profitfixdf[profitfixdf[:obscrop] .== "cott", :obscrop] = "Cotton"
    profitfixdf[profitfixdf[:obscrop] .== "rice", :obscrop] = "Rice"
    profitfixdf[profitfixdf[:obscrop] .== "soyb", :obscrop] = "Soybean"
    profitfixdf[profitfixdf[:obscrop] .== "whea", :obscrop] = "Wheat"
end

maximum_yields = Dict("Barley" => 176.5, "Corn" => 246, "Cotton" => 3433.,
                      "Rice" => 10180, "Soybean" => 249, "Wheat" => 142.5)

# Load historical bioclim data
bios = readtable(expanduser("~/Dropbox/Agriculture Weather/us-bioclims-new.csv"))
bios[:fips] = trunc(Int, bios[:NHGISST] * 100 + bios[:NHGISCTY] / 10)

maxprofit = Dict{Int64, Vector{Any}}()
allprofits = -Inf * ones(6, nrow(masterregions)) # crop, region
allyields = zeros(6, nrow(masterregions))

bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
edds_crops = ["Barley", "Maize", "Cotton", "Rice", "Soybeans", "Wheat"]
for ii in 1:length(bayes_crops)
    crop = bayes_crops[ii]
    println(crop)

    # Load the second-level coefficients
    b0s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b0.txt"), separator=' ', header=false))
    b1s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b1.txt"), separator=' ', header=false))
    b2s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b2.txt"), separator=' ', header=false))
    b3s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b3.txt"), separator=' ', header=false))
    b4s = convert(Matrix{Float64}, readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_b4.txt"), separator=' ', header=false))

    price = ers_information(ers_crop(crop), "price", 2010; includeus=includeus)
    costs = ers_information(ers_crop(crop), "opcost", 2010; includeus=includeus)

    alldifferences = zeros(6, nrow(bios), length(biomodels))
    for jj in 1:length(biomodels)
        # Load future bioclim data
        bios_future = readtable(expanduser("~/Dropbox/Agriculture Weather/bioclims-$futureyear/$(biomodels[jj])85bi$(futureyear % 100).csv"))

        alldifferences[1, :, jj] = bios_future[:bio1_mean] - bios[:bio1_mean]
        alldifferences[2, :, jj] = bios_future[:bio3_mean] - bios[:bio3_mean]
        alldifferences[3, :, jj] = bios_future[:bio5_mean] - bios[:bio5_mean]
        alldifferences[4, :, jj] = bios_future[:bio12_mean] - bios[:bio12_mean]
        alldifferences[5, :, jj] = bios_future[:bio15_mean] - bios[:bio15_mean]
        alldifferences[6, :, jj] = 0
    end

    differences = mean(alldifferences, 3)

    allgdds = zeros(nrow(bios), length(eddmodels))
    allkdds = zeros(nrow(bios), length(eddmodels))
    allinvalids = zeros(Bool, nrow(bios), length(eddmodels))

    for jj in 1:length(eddmodels)
        # Load degree day data
        weather = readtable(joinpath(expanduser("~/Dropbox/Agriculture Weather/futureedds/rcp85/$(eddmodels[jj])/$(edds_crops[ii]).csv")))
        all2050s = weather[:year] .== futureyear
        fips2050s = weather[all2050s, :fips]
        rows2050s = find(all2050s)
        weatherrows = [any(fips2050s .== fips) ? rows2050s[fips2050s .== fips][1] : 1 for fips in bios[:fips]]
        allgdds[:, jj] = weather[weatherrows, :gdds]
        allkdds[:, jj] = weather[weatherrows, :kdds]
        allinvalids[:, jj] = weatherrows .== 1
    end

    allgdds[allinvalids] = 0
    allkdds[allinvalids] = 0

    gdds = sum(allgdds, 2) ./ sum(.!allinvalids, 2)
    kdds = sum(allkdds, 2) ./ sum(.!allinvalids, 2)

    bayes_intercept = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_alpha.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_time = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta1.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_gdds = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta3.txt"), separator=' ', header=false)[:, 1:3111];
    bayes_kdds = readtable(expanduser("~/Dropbox/Agriculture Weather/$bayesdir/$(cropdirs[ii])/coeff_beta4.txt"), separator=' ', header=false)[:, 1:3111];

    df = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/fips_usa.csv"))

    for kk in 1:nrow(bios)
        fips = bios[:fips][kk]
        rr = findfirst(df[:FIPS] .== fips)
        if rr == 0
            continue
        end

        intercept = bayes_intercept[:, rr]
        gdds_coeff = bayes_gdds[:, rr]
        kdds_coeff = bayes_kdds[:, rr]
        time_coeff = bayes_time[:, rr]

        if holdcoeff
            if allowtime
                logyield = intercept + gdds_coeff * gdds[kk] + kdds_coeff * kdds[kk] + time_coeff * (futureyear - 1948)
            else
                logyield = intercept + gdds_coeff * gdds[kk] + kdds_coeff * kdds[kk] + time_coeff * 62 # eq. 2010
            end
        else
            # Get new coefficients for the future
            intercept_future = intercept + b0s * differences[:, kk]
            gdds_coeff_future = gdds_coeff + b1s * differences[:, kk]
            kdds_coeff_future = kdds_coeff + b2s * differences[:, kk]
            time_coeff_future = time_coeff + b3s * differences[:, kk]

            if allowtime
                logyield = intercept_future + gdds_coeff_future * gdds[kk] + kdds_coeff_future * kdds[kk] + time_coeff_future * (futureyear - 1948)
            else
                logyield = intercept_future + gdds_coeff_future * gdds[kk] + kdds_coeff_future * kdds[kk] + time_coeff_future * 62 # eq. 2010
            end
        end

        if limityield == "lybymc"
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

        allyields[ii, findfirst(masterregions[:fips] .== canonicalindex(fips))] = yield_irrigated

        ersrow = findfirst(masterregions[:fips] .== canonicalindex(fips))

        price_row = price[ersrow]
        costs_row = costs[ersrow]
        if profitfix && profitfixdf[ersrow, :obscrop] == crop
            costs_row -= profitfixdf[ersrow, :toadd]
        end

        profit = yield_irrigated * price_row - costs_row

        allprofits[ii, findfirst(masterregions[:fips] .== canonicalindex(fips))] = profit

        if profit > get(maxprofit, fips, [-Inf])[1]
            maxprofit[fips] = [profit, crop, yield_irrigated, price_row, costs_row]
        end
    end
end

suffixes = []
if profitfix
    push!(suffixes, "pfixed")
end
if !allowtime
    push!(suffixes, "notime")
end
if holdcoeff
    push!(suffixes, "histco")
end
if limityield != "ignore"
    push!(suffixes, limityield)
end
if length(suffixes) > 0
    suffixes = [""; suffixes]
end
suffix = join(suffixes, "-")

writecsv("all$(futureyear)profits$suffix.csv", allprofits')
writecsv("all$(futureyear)yields$suffix.csv", allyields')

result = DataFrame(fips=Int64[], profit=Float64[], crop=String[], yield=Float64[], price=Float64[], costs=Float64[])

for fips in keys(maxprofit)
    push!(result, [fips; maxprofit[fips]])
end

writetable("max$(futureyear)$suffix.csv", result)
