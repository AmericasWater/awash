using CSV, Missings

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/standard-1year.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")
include("curryield.jl")

# masterregions[:soy_revenue] = ers_information("soyb", "revenue", 2010; includeus=false)
# masterregions[:soy_opcost] = ers_information("soyb", "opcost", 2010; includeus=false)
# masterregions[:soy_opcost_full] = ers_information("soyb", "opcost", 2010; includeus=true)
# masterregions[:soy_price] = ers_information(crop, "price", 2010; includeus=false)
# masterregions[:soy_price_full] = ers_information(crop, "price", 2010; includeus=true)
# CSV.write("soydata.csv", masterregions)

crop2bayes_crop = Dict("barl" => "Barley", "corn" => "Corn", "cott" => "Cotton",
                       "rice" => "Rice", "soyb" => "Soybean", "whea" => "Wheat")

do_cropdrop = true
extraneg = true
domcmcdraws = true # << for MC

if do_cropdrop
    crops = ["corn", "soyb", "whea", "barl", "cott", "rice"]
else
    crops = ["corn", "soyb", "whea", "sorg", "barl", "cott", "rice", "oats", "pean"]
end

actualcrops = CSV.read("actualcrops.csv"; copycols=true)
actualcrops[!, :fips] = canonicalindex(actualcrops[!, :fips])
actualcrops[.!ismissing.(actualcrops[!, :maxcrop]) .& (actualcrops[!, :maxcrop] .== "COTTON"), :maxcrop] .= "cott"
actualcrops[.!ismissing.(actualcrops[!, :maxcrop]) .& (actualcrops[!, :maxcrop] .== "SOYBEANS"), :maxcrop] .= "soyb"
actualcrops[.!ismissing.(actualcrops[!, :maxcrop]) .& (actualcrops[!, :maxcrop] .== "CORN"), :maxcrop] .= "corn"
actualcrops[.!ismissing.(actualcrops[!, :maxcrop]) .& (actualcrops[!, :maxcrop] .== "WHEAT"), :maxcrop] .= "whea"
actualcrops[.!ismissing.(actualcrops[!, :maxcrop]) .& (actualcrops[!, :maxcrop] .== "RICE"), :maxcrop] .= "rice"
actualcrops[.!ismissing.(actualcrops[!, :maxcrop]) .& (actualcrops[!, :maxcrop] .== "BARLEY"), :maxcrop] .= "barl"

# Collect observed crop
obscrop = repeat(["none"], outer=nrow(masterregions))
for ii in 1:nrow(masterregions)
    fips = masterregions[ii, :fips]
    obsrow = actualcrops[actualcrops[!, :fips] .== fips, :]
    if nrow(obsrow) == 1
        observed = obsrow[1, :maxcrop]
        if !ismissing(observed)
            obscrop[ii] = observed
        end
    end
end

fipsdf = CSV.read(expanduser("~/Dropbox/Agriculture Weather/fips_usa.csv"))

for mcmcdraw in 1:1000

if domcmcdraws
    if do_cropdrop
        filename = "farmvalue-limited-$mcmcdraw.csv"
    else
        filename = "farmvalue-$mcmcdraw.csv"
    end

    if isfile(filename)
        continue
    end
    touch(filename)
end

let
value = repeat([0.0], size(masterregions, 1))
maxvalue = repeat(["none"], size(masterregions, 1))
profit = repeat([0.0], size(masterregions, 1))
maxprofit = repeat(["none"], size(masterregions, 1))
estprofit = repeat([0.0], size(masterregions, 1))
obsestprofit = repeat([0.0], size(masterregions, 1))
maxestprofit = repeat(["none"], size(masterregions, 1))
estprofit_changeirr = repeat([0.0], size(masterregions, 1))
obsestprofit_changeirr = repeat([0.0], size(masterregions, 1))
maxestprofit_changeirr = repeat(["none"], size(masterregions, 1))
for crop in crops
    data = ers_information(crop, "Opportunity cost of land", 2010; includeus=false)
    data[ismissing.(data)] .= 0
    data = convert(Vector{Float64}, data)

    maxvalue[data .> value] .= crop
    value = max.(value, data)

    data = ers_information(crop, "revenue", 2010; includeus=false) - ers_information(crop, "cost", 2010; includeus=false)
    data[ismissing.(data)] .= -Inf
    data = convert(Vector{Float64}, data)

    price_all = ers_information(crop, "price", 2010; includeus=true);
    costs_all = ers_information(crop, "opcost", 2010; includeus=true);

    maxprofit[data .> profit] .= crop
    profit = max.(profit, data)

    # Determine the profit under the estimated yields
    if domcmcdraws
        prepdata = preparecrop(crop2bayes_crop[crop], false, true, false, mcmcdraw)
        prepdata_changeirr = preparecrop(crop2bayes_crop[crop], false, true, true, mcmcdraw)
    else
        prepdata = preparecrop(crop2bayes_crop[crop], false, true, false)
        prepdata_changeirr = preparecrop(crop2bayes_crop[crop], false, true, true)
    end

    cropprofit = zeros(nrow(masterregions))
    cropprofit_changeirr = zeros(nrow(masterregions))
    for weatherrow in 1:nrow(masterregions)
        fips = parse(Int64, masterregions[weatherrow, :fips])
        rr = findfirst(fipsdf[!, :FIPS] .== fips)
        if rr == nothing
            cropprofit[weatherrow] = -Inf
            cropprofit_changeirr[weatherrow] = -Inf
        else
            forceneg = extraneg && isextrapolate(fips, crop2bayes_crop[crop])
            yield_total = getyield(rr, weatherrow, false, 62, "ignore", forceneg, prepdata)
            if ismissing(yield_total)
                cropprofit[weatherrow] = -Inf
            else
                cropprofit[weatherrow] = yield_total * price_all[weatherrow] - costs_all[weatherrow]
            end

            yield_total_changeirr = getyield(rr, weatherrow, true, 62, "ignore", forceneg, prepdata_changeirr)
            if ismissing(yield_total_changeirr)
                cropprofit_changeirr[weatherrow] = -Inf
            else
                cropprofit_changeirr[weatherrow] = yield_total_changeirr * price_all[weatherrow] - costs_all[weatherrow]
            end
        end
    end

    obsestprofit[obscrop .== crop] .= cropprofit[obscrop .== crop]
    maxestprofit[cropprofit .> estprofit] .= crop
    estprofit = max.(estprofit, cropprofit)

    obsestprofit_changeirr[obscrop .== crop] .= cropprofit_changeirr[obscrop .== crop]
    maxestprofit_changeirr[cropprofit_changeirr .> estprofit_changeirr] .= crop
    estprofit_changeirr = max.(estprofit_changeirr, cropprofit_changeirr)
end

masterregions[:farmvalue] = value
masterregions[:valuesource] = maxvalue
masterregions[:profit] = profit
masterregions[:profitsource] = maxprofit
masterregions[:estprofit] = estprofit
masterregions[:estprofitsource] = maxestprofit
masterregions[:estprofit_changeirr] = estprofit_changeirr
masterregions[:estprofitsource_changeirr] = maxestprofit_changeirr

## Figure out change in profit needed to breakeven with observed

toadd = zeros(nrow(masterregions))
esttoadd = zeros(nrow(masterregions))
esttoadd_changeirr = zeros(nrow(masterregions))
for ii in 1:nrow(masterregions)
    println(ii)
    fips = masterregions[ii, :fips]
    obsrow = actualcrops[actualcrops[:fips] .== fips, :]
    if nrow(obsrow) == 1
        observed = obsrow[1, :maxcrop]
        if !ismissing(observed)
            obscrop[ii] = observed
            data = ers_information(observed, "revenue", 2010; includeus=false) - ers_information(observed, "cost", 2010; includeus=false)
            if typeof(data) <: Vector{Missing}
                data = zeros(length(data))
            else
                data = collect(Missings.replace(data, -Inf))
            end

            if observed != maxprofit[ii]
                toadd[ii] = profit[ii] - data[ii]
            end
            if observed != maxestprofit[ii]
                esttoadd[ii] = estprofit[ii] - obsestprofit[ii]
            end
            if observed != maxestprofit_changeirr[ii]
                esttoadd_changeirr[ii] = estprofit_changeirr[ii] - obsestprofit_changeirr[ii]
            end
        end
    end
end

masterregions[:obscrop] = obscrop
masterregions[:toadd] = toadd
masterregions[:esttoadd] = esttoadd
masterregions[:esttoadd_changeirr] = esttoadd_changeirr

if domcmcdraws
    if do_cropdrop
        CSV.write("farmvalue-limited-$mcmcdraw.csv", masterregions)
    else
        CSV.write("farmvalue-$mcmcdraw.csv", masterregions)
    end
else
    if do_cropdrop
        CSV.write("farmvalue-limited.csv", masterregions)
    else
        CSV.write("farmvalue.csv", masterregions)
    end
end
end
end
