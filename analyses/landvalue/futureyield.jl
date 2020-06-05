# Rerun 9/17

using NaNMath, CSV, DelimitedFiles, Statistics

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/single.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")
include("curryield.jl")

wheatshares = CSV.read("wheat-shares.csv", copycols=true)
wheatshares[!, :fips] = convert(Vector{Int64}, wheatshares[!, :fips])
wheatshares[!, :spring] = convert(Vector{Float64}, wheatshares[!, :spring])
wheatshares[!, :winter] = convert(Vector{Float64}, wheatshares[!, :winter])

crossval = false
constvar = true
rcp = "rcp85"

onefips = false #53009
onecrops = nothing #["Barley", "Cotton"]

includeus = true
extraneg = true
domcmcdraws = false
onlyprefed = domcmcdraws

#profitfix = true
for mcmcdraw in 1:1000
for profitfix in [true, "modeled"]
    for holdcoeff in [false, true]
        for allowtime in [false, true]
            for futureyear in [2050, 2070]
                for limityield in ["ignore", "lybymc"]
if (onefips != false || onlyprefed) && (limityield != "ignore" || profitfix != "modeled" || holdcoeff != true || allowtime != false)
    continue
end

#holdcoeff = true #false
#allowtime = true #false
#futureyear = 2050
#limityield = "ignore" #"lybymc" #"zeroy" # "limity"
cropdirs = ["barley", "corn", "cotton", "rice", "soybean", "wheat"]

eddmodels = ["access1-0", "bcc-csm1-1", "ccsm4", "cnrm-cm5", "gfdl-cm3", "giss-e2-r",
             "hadgem2-ao", "hadgem2-es", "hadgem2-cc", "inmcm4", "ipsl-cm5b-lr", "miroc5",
             "mri-cgcm3", "miroc-esm-chem", "mpi-esm-lr", "miroc-esm", "noresm1-m"]
biomodels = ["ac", "bc", "cc", "cn", "gf", "gs",
             "hd", "he", "hg", "in", "ip", "mc",
             "mg", "mi", "mp", "mr" , "no"]
if domcmcdraws
    eddmodels = [eddmodels[mcmcdraw % length(eddmodels) + 1]]
    biomodels = [biomodels[mcmcdraw % length(biomodels) + 1]]
end

suffixes = []
if profitfix == true
    push!(suffixes, "pfixed")
elseif profitfix == "modeled"
    push!(suffixes, "pfixmo")
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
if rcp != "rcp85"
    push!(suffixes, rcp)
end
if length(biomodels) == 1
    push!(suffixes, "$(biomodels[1])")
end
if domcmcdraws
    push!(suffixes, "$mcmcdraw")
end
if length(suffixes) > 0
    suffixes = [""; suffixes]
end
suffix = join(suffixes, "-")

if domcmcdraws
    filename = "max$(futureyear)$suffix.csv"
    if isfile(filename)
	continue
    end
    touch(filename)
end

if profitfix != false
    profitfixdf = CSV.read("farmvalue-limited-$mcmcdraw.csv", copycols=true)
    profitfixdf[profitfixdf[!, :obscrop] .== "barl", :obscrop] .= "Barley"
    profitfixdf[profitfixdf[!, :obscrop] .== "corn", :obscrop] .= "Corn"
    profitfixdf[profitfixdf[!, :obscrop] .== "cott", :obscrop] .= "Cotton"
    profitfixdf[profitfixdf[!, :obscrop] .== "rice", :obscrop] .= "Rice"
    profitfixdf[profitfixdf[!, :obscrop] .== "soyb", :obscrop] .= "Soybean"
    profitfixdf[profitfixdf[!, :obscrop] .== "whea", :obscrop] .= "Wheat"
end

maximum_yields = Dict("Barley" => 176.5, "Corn" => 246, "Cotton" => 3433.,
                      "Rice" => 10180, "Soybean" => 249, "Wheat" => 142.5)

# Load historical bioclim data
bios = CSV.read(expanduser("~/Dropbox/Agriculture Weather/us-bioclims-new.csv"))
bios[!, :fips] = trunc.(Int, bios[!, :NHGISST] * 100 + bios[!, :NHGISCTY] / 10)

maxprofit = Dict{Int64, Vector{Any}}()
allprofits = -Inf * ones(6, nrow(masterregions)) # crop, region
allyields = zeros(6, nrow(masterregions))

irrigation = CSV.read("irrigation.csv")

bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
edds_crops = ["Barley", "Maize", "Cotton", "Rice", "Soybeans", "Wheat"]
irr_crops = [:BARLEY, :CORN, :COTTON, :RICE, :SOYBEANS, :WHEAT]
for ii in 1:length(bayes_crops)
    crop = bayes_crops[ii]
    if onefips != false && !in(crop, onecrops)
        continue
    end
    println(crop)

    fullcropdir = "Code_" * cropdirs[ii]
    if crossval
        fullcropdir = fullcropdir * "_cv"
    end
    if constvar
        fullcropdir = fullcropdir * "_variance"
    end

    # Load the second-level coefficients
    b0s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_b0.txt"), ' '))
    b1s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_b1.txt"), ' '))
    b2s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_b2.txt"), ' '))
    b3s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_b3.txt"), ' '))
    b4s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_b4.txt"), ' '))

    if mcmcdraw != nothing
        b0s = b0s[[mcmcdraw], :]
        b1s = b1s[[mcmcdraw], :]
        b2s = b2s[[mcmcdraw], :]
        b3s = b3s[[mcmcdraw], :]
        b4s = b4s[[mcmcdraw], :]
    end

    price = ers_information(ers_crop(crop), "price", 2010; includeus=includeus)
    costs = ers_information(ers_crop(crop), "opcost", 2010; includeus=includeus)

    alldifferences = zeros(6, nrow(bios), length(biomodels))
    for jj in 1:length(biomodels)
        # Load future bioclim data
        bios_future = CSV.read(expanduser("~/Dropbox/Agriculture Weather/bioclims-$futureyear/$(biomodels[jj])85bi$(futureyear % 100).csv"))

        alldifferences[1, :, jj] = bios_future[!, :bio1_mean] - bios[!, :bio1_mean]
        alldifferences[2, :, jj] = bios_future[!, :bio3_mean] - bios[!, :bio3_mean]
        alldifferences[3, :, jj] = bios_future[!, :bio5_mean] - bios[!, :bio5_mean]
        alldifferences[4, :, jj] = bios_future[!, :bio12_mean] - bios[!, :bio12_mean]
        alldifferences[5, :, jj] = bios_future[!, :bio15_mean] - bios[!, :bio15_mean]
        alldifferences[6, :, jj] .= 0 # Fill in this later (GCM-independent)
    end

    differences = mean(alldifferences, dims=3)

    df = CSV.read(expanduser("~/Dropbox/Agriculture Weather/fips_usa.csv"))

    wreqs = ones(nrow(df)) * maximum(Missings.skipmissing(irrigation[:, Symbol("wreq$(irr_crops[ii])")]))
    for kk in 1:nrow(irrigation)
        rr = findfirst(df[!, :FIPS] .== irrigation[kk, :fips])
        if rr != nothing
            differences[6, rr] = irrigation[kk, :irrfrac] - irrigation[kk, irr_crops[ii]]
            if !ismissing(irrigation[kk, Symbol("wreq$(irr_crops[ii])")])
                wreqs[rr] = irrigation[kk, Symbol("wreq$(irr_crops[ii])")]
            end
        end
    end

    allgdds = zeros(nrow(bios), length(eddmodels))
    allkdds = zeros(nrow(bios), length(eddmodels))
    allinvalids = zeros(Bool, nrow(bios), length(eddmodels))

    for jj in 1:length(eddmodels)
        # Load degree day data
        weather = CSV.read(joinpath(expanduser("~/Dropbox/Agriculture Weather/futureedds/$rcp/$(eddmodels[jj])/$(edds_crops[ii]).csv")))
        all2050s = weather[!, :year] .== futureyear
        fips2050s = weather[all2050s, :fips]
        rows2050s = findall(all2050s)
        weatherrows = [any(fips2050s .== fips) ? rows2050s[fips2050s .== fips][1] : 1 for fips in bios[!, :fips]]
        allgdds[:, jj] = weather[weatherrows, :gdds]
        allkdds[:, jj] = weather[weatherrows, :kdds]
        allinvalids[:, jj] = weatherrows .== 1
        if crop == "Wheat"
            weather2 = CSV.read(joinpath(expanduser("~/Dropbox/Agriculture Weather/futureedds/$rcp/$(eddmodels[jj])/$(edds_crops[ii]).Winter.csv")))
            all2050s2 = weather2[!, :year] .== futureyear
            fips2050s2 = weather2[all2050s2, :fips]
            rows2050s2 = findall(all2050s2)
            weatherrows2 = [any(fips2050s2 .== fips) ? rows2050s2[fips2050s2 .== fips][1] : 1 for fips in bios[!, :fips]]
            springshares2 = [let ii = findfirst(wheatshares[!, :fips] .== fips); ii == nothing ? 0. : wheatshares[ii, :spring]; end for fips in bios[!, :fips]]
            allgdds[:, jj] = allgdds[:, jj] .* springshares2 + weather2[weatherrows2, :gdds] .* (1. .- springshares2)
            allkdds[:, jj] = allkdds[:, jj] .* springshares2 + weather2[weatherrows2, :kdds] .* (1. .- springshares2)
            allinvalids[:, jj] = allinvalids[:, jj] .| (weatherrows2 .== 1)
        end
    end

    allgdds[allinvalids] .= 0
    allkdds[allinvalids] .= 0

    gdds = sum(allgdds, dims=2) ./ sum(.!allinvalids, dims=2)
    kdds = sum(allkdds, dims=2) ./ sum(.!allinvalids, dims=2)

    bayes_intercept = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_alpha.txt"), ' ')[:, 1:3111];
    bayes_time = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_beta1.txt"), ' ')[:, 1:3111];
    bayes_wreq = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_beta2.txt"), ' ')[:, 1:3111];
    bayes_gdds = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_beta3.txt"), ' ')[:, 1:3111];
    bayes_kdds = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/coeff_beta4.txt"), ' ')[:, 1:3111];

    bayes_sigma = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa cropyield model revised runs May16/$fullcropdir/sigma_y.txt"), ' ')

    if mcmcdraw != nothing
        bayes_intercept = bayes_intercept[[mcmcdraw], :]
        bayes_time = bayes_time[[mcmcdraw], :]
        bayes_wreq = bayes_wreq[[mcmcdraw], :]
        bayes_gdds = bayes_gdds[[mcmcdraw], :]
        bayes_kdds = bayes_kdds[[mcmcdraw], :]
        bayes_sigma = bayes_sigma[[mcmcdraw], :]
    end

    for kk in 1:nrow(bios)
        fips = bios[!, :fips][kk]
        if onefips != false && onefips != fips
            continue
        end
        rr = findfirst(df[!, :FIPS] .== fips)
        if rr == nothing
            continue
        end

        intercept = bayes_intercept[:, rr]
        time_coeff = bayes_time[:, rr]
        wreq_coeff = bayes_wreq[:, rr]
        gdds_coeff = bayes_gdds[:, rr]
        kdds_coeff = bayes_kdds[:, rr]

        if holdcoeff
            wreq_coeff_future = wreq_coeff + b2s[:, 6] * differences[6, rr]

            if extraneg && isextrapolate(fips, crop)
                wreq_coeff_future = forceneg_coeff(wreq_coeff_future)
                kdds_coeff = forceneg_coeff(kdds_coeff)
            end

            if allowtime
                logyield = intercept + wreq_coeff_future * wreqs[rr] + gdds_coeff * gdds[kk] + kdds_coeff * kdds[kk] + time_coeff * (futureyear - 1948)
            else
                logyield = intercept + wreq_coeff_future * wreqs[rr] + gdds_coeff * gdds[kk] + kdds_coeff * kdds[kk] + time_coeff * 62 # eq. 2010
            end
        else
            # Get new coefficients for the future
            intercept_future = intercept + b0s * differences[:, kk]
            time_coeff_future = time_coeff + b1s * differences[:, kk]
            wreq_coeff_future = wreq_coeff + b2s * differences[:, kk]
            gdds_coeff_future = gdds_coeff + b3s * differences[:, kk]
            kdds_coeff_future = kdds_coeff + b4s * differences[:, kk]

            if extraneg && isextrapolate(fips, crop)
                wreq_coeff_future = forceneg_coeff(wreq_coeff_future)
                kdds_coeff_future = forceneg_coeff(kdds_coeff_future)
            end

            if allowtime
                logyield = intercept_future + wreq_coeff_future * wreqs[rr] + gdds_coeff_future * gdds[kk] + kdds_coeff_future * kdds[kk] + time_coeff_future * (futureyear - 1948)
            else
                logyield = intercept_future + wreq_coeff_future * wreqs[rr] + gdds_coeff_future * gdds[kk] + kdds_coeff_future * kdds[kk] + time_coeff_future * 62 # eq. 2010
            end
        end

        # Also add log bias correction (sigma^2/2), because about to exponentiate
        logyield += (bayes_sigma.^2) / 2

        if limityield == "lybymc"
            logyield[logyield .> log(maximum_yields[crop])] .= NaN
        end
        yield_total = NaNMath.mean(exp.(logyield))
        if limityield != "ignore" && yield_total > maximum_yields[crop]
            if limityield == "limity"
                yield_total = maximum_yields[crop]
            elseif limityield == "zeroy"
                yield_total = 0
            end
        end

        allyields[ii, findfirst(masterregions[!, :fips] .== canonicalindex(fips))] = yield_total

        ersrow = findfirst(masterregions[!, :fips] .== canonicalindex(fips))

        price_row = price[ersrow]
        costs_row = costs[ersrow]
        if profitfix != false && profitfixdf[ersrow, :obscrop] == crop
            if profitfix == true
                costs_row -= profitfixdf[ersrow, :toadd]
            else
                costs_row -= profitfixdf[ersrow, :esttoadd_changeirr] + .01
            end
        end

        profit = yield_total * price_row - costs_row
        if onefips != false
            println("$profit = $yield_total * $price_row - $costs_row")
        end

        allprofits[ii, findfirst(masterregions[!, :fips] .== canonicalindex(fips))] = profit

        if profit > get(maxprofit, fips, [-Inf])[1]
            maxprofit[fips] = [profit, crop, yield_total, price_row, costs_row]
        end
    end
end

if onefips == false

writedlm("all$(futureyear)profits$suffix.csv", allprofits', ',')
writedlm("all$(futureyear)yields$suffix.csv", allyields', ',')

result = DataFrame(fips=Int64[], profit=Float64[], crop=String[], yield=Float64[], price=Float64[], costs=Float64[])

for fips in keys(maxprofit)
    push!(result, [fips; maxprofit[fips]])
end

CSV.write("max$(futureyear)$suffix.csv", result)
end

end
end
end
end
end

if !domcmcdraws
    break
end
end
