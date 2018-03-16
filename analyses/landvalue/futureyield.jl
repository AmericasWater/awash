include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/single.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

includeus = true
futureyear = 2050

eddmodels = ["access1-0", "bcc-csm1-1", "ccsm4", "cnrm-cm5", "gfdl-cm3", "giss-e2-r",
             "hadgem2-ao", "hadgem2-es", "hadgem2-cc", "inmcm4", "ipsl-cm5b-lr", "miroc5",
             "mri-cgcm3", "miroc-esm-chem", "mpi-esm-lr", "miroc-esm", "noresm1-m"]
biomodels = ["ac", "bc", "cc", "cn", "gf", "gs",
             "hd", "he", "hg", "in", "ip", "mc",
             "mg", "mi", "mp", "mr" , "no"]

# Load historical bioclim data
bios = readtable(expanduser("~/Dropbox/Agriculture Weather/us-bioclims-new.csv"))
bios[:fips] = trunc(Int, bios[:NHGISST] * 100 + bios[:NHGISCTY] / 10)

maxprofit = Dict{Int64, Vector{Any}}()
allprofits = -Inf * ones(6, nrow(masterregions)) # crop, region

bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
edds_crops = ["Barley", "Maize", "Cotton", "Rice", "Soybeans", "Wheat"]
for ii in 1:length(bayes_crops)
    crop = bayes_crops[ii]
    println(crop)

    # Load the second-level coefficients
    dfb0s = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/$crop/coeff_b0.txt"), separator=' ', header=false)
    b0s = [mean(dfb0s[:, col]) for col in 1:ncol(dfb0s)]
    dfb1s = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/$crop/coeff_b1.txt"), separator=' ', header=false)
    b1s = [mean(dfb1s[:, col]) for col in 1:ncol(dfb1s)]
    dfb2s = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/$crop/coeff_b2.txt"), separator=' ', header=false)
    b2s = [mean(dfb2s[:, col]) for col in 1:ncol(dfb2s)]
    dfb3s = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/$crop/coeff_b3.txt"), separator=' ', header=false)
    b3s = [mean(dfb3s[:, col]) for col in 1:ncol(dfb3s)]
    dfb4s = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/$crop/coeff_b4.txt"), separator=' ', header=false)
    b4s = [mean(dfb4s[:, col]) for col in 1:ncol(dfb4s)]

    price = ers_information(ers_crop(crop), "price", 2010; includeus=includeus)
    costs = ers_information(ers_crop(crop), "cost", 2010; includeus=includeus)

    df = readtable(datapath("agriculture/bayesian/$(crop).csv"))

    if crop == "Corn"
        alldifferences = zeros(5, nrow(bios), length(biomodels))
    else
        alldifferences = zeros(6, nrow(bios), length(biomodels))
    end
    for jj in 1:length(biomodels)
        # Load future bioclim data
        bios_future = readtable(expanduser("~/Dropbox/Agriculture Weather/bioclims-$futureyear/$(biomodels[jj])85bi$(futureyear % 100).csv"))

        alldifferences[1, :, jj] = bios_future[:bio1_mean] - bios[:bio1_mean]
        alldifferences[2, :, jj] = bios_future[:bio3_mean] - bios[:bio3_mean]
        alldifferences[3, :, jj] = bios_future[:bio5_mean] - bios[:bio5_mean]
        alldifferences[4, :, jj] = bios_future[:bio12_mean] - bios[:bio12_mean]
        alldifferences[5, :, jj] = bios_future[:bio15_mean] - bios[:bio15_mean]
        if crop != "Corn"
            alldifferences[6, :, jj] = 0
        end
    end

    differences = mean(alldifferences, 3)

    allgdds = zeros(nrow(bios), length(eddmodels))
    allkdds = zeros(nrow(bios), length(eddmodels))
    allinvalids = zeros(Bool, nrow(bios), length(eddmodels))

    for jj in 1:length(eddmodels)
        # Load degree day data
        weather = readtable(joinpath(datapath("agriculture/futureedds/rcp85/$(eddmodels[jj])/$(edds_crops[ii]).csv")))
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

    for kk in 1:nrow(bios)
        fips = bios[:fips][kk]
        if !any(df[:fips] .== fips)
            continue
        end
        intercept = df[(df[:fips] .== fips) .& (df[:coef] .== "intercept"), :mean][1]
        gdds_coeff = df[(df[:fips] .== fips) .& (df[:coef] .== "gdds"), :mean][1]
        kdds_coeff = df[(df[:fips] .== fips) .& (df[:coef] .== "kdds"), :mean][1]
        time_coeff = df[(df[:fips] .== fips) .& (df[:coef] .== "time"), :mean][1]

        # Get new coefficients for the future
        intercept_future = intercept + sum(b0s .* differences[:, kk])
        gdds_coeff_future = gdds_coeff + sum(b1s .* differences[:, kk])
        kdds_coeff_future = kdds_coeff + sum(b2s .* differences[:, kk])
        time_coeff_future = time_coeff + sum(b3s .* differences[:, kk])

        yield_irrigated = mean(exp(intercept_future + gdds_coeff_future * gdds[kk] + kdds_coeff_future * kdds[kk] + time_coeff_future * futureyear))

        ersrow = findfirst(masterregions[:fips] .== canonicalindex(fips))

        price_row = price[ersrow]
        costs_row = costs[ersrow]

        profit = yield_irrigated * price_row - costs_row

        allprofits[ii, findfirst(masterregions[:fips] .== canonicalindex(fips))] = profit

        if profit > get(maxprofit, fips, [-Inf])[1]
            maxprofit[fips] = [profit, crop, yield_irrigated, price_row, costs_row]
        end
    end
end

writecsv("futureprofits.csv", allprofits')

result = DataFrame(fips=Int64[], profit=Float64[], crop=String[], yield=Float64[], price=Float64[], costs=Float64[])

for fips in keys(maxprofit)
    push!(result, [fips; maxprofit[fips]])
end

writetable("maxfuture.csv", result)
