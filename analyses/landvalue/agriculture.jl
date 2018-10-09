using DataArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/standard-1year.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")
include("curryield.jl")

do_cropdrop = true

bayesdir = "posterior_distributions_variance"
crop2bayes_crop = Dict("barl" => "Barley", "corn" => "Corn", "cott" => "Cotton",
                       "rice" => "Rice", "soyb" => "Soybean", "whea" => "Wheat")


if do_cropdrop
    crops = ["corn", "soyb", "whea", "barl", "cott", "rice"]
else
    crops = ["corn", "soyb", "whea", "sorg", "barl", "cott", "rice", "oats", "pean"]
end

fipsdf = readtable(expanduser("~/Dropbox/Agriculture Weather/posterior_distributions/fips_usa.csv"))

value = repmat([0.0], size(masterregions, 1))
maxvalue = repmat(["none"], size(masterregions, 1))
profit = repmat([0.0], size(masterregions, 1))
maxprofit = repmat(["none"], size(masterregions, 1))
estprofit = repmat([0.0], size(masterregions, 1))
maxestprofit = repmat(["none"], size(masterregions, 1))
estprofit_changeirr = repmat([0.0], size(masterregions, 1))
maxestprofit_changeirr = repmat(["none"], size(masterregions, 1))
for crop in crops
    data = ers_information(crop, "Opportunity cost of land", 2010; includeus=false)
    data[isna.(data)] = 0
    data = convert(Vector{Float64}, data)

    maxvalue[data .> value] = crop
    value = max(value, data)

    data = ers_information(crop, "revenue", 2010; includeus=false) - ers_information(crop, "cost", 2010; includeus=false)
    data[isna.(data)] = 0
    data = convert(Vector{Float64}, data)

    price_all = ers_information(crop, "price", 2010; includeus=true);
    costs_all = ers_information(crop, "opcost", 2010; includeus=true);
    
    maxprofit[data .> profit] = crop
    profit = max(profit, data)

    # Determine the profit under the estimated yields
    prepdata = preparecrop(crop2bayes_crop[crop], false)
    prepdata_changeirr = preparecrop(crop2bayes_crop[crop], true)

    cropprofit = zeros(nrow(masterregions))
    cropprofit_changeirr = zeros(nrow(masterregions))
    for weatherrow in 1:nrow(masterregions)
        rr = findfirst(fipsdf[:FIPS] .== parse(Int64, masterregions[weatherrow, :fips]))
        total_yield = getyield(rr, weatherrow, false, 62, prepdata)
        cropprofit[weatherrow] = yield_total * price_all[weatherrow] - costs_all[weatherrow]
        
        total_yield_changeirr = getyield(rr, weatherrow, true, 62, prepdata_changeirr)
        cropprofit_changeirr[weatherrow] = yield_total * price_all[weatherrow] - costs_all[weatherrow]
    end

    maxextprofit[cropprofit .> estprofit] = crop
    estprofit = max(estprofit, cropprofit)
    
    maxextprofit_changeirr[cropprofit_changeirr .> estprofit_changeirr] = crop
    estprofit_changeirr = max(estprofit_changeirr, cropprofit_changeirr)    
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

actualcrops = readtable("actualcrops.csv")
actualcrops[:fips] = canonicalindex(actualcrops[:fips])
actualcrops[!ismissing.(actualcrops[:maxcrop_before]) .& (actualcrops[:maxcrop_before] .== "COTTON"), :maxcrop_before] = "cott"
actualcrops[!ismissing.(actualcrops[:maxcrop_before]) .& (actualcrops[:maxcrop_before] .== "SOYBEANS"), :maxcrop_before] = "soyb"
actualcrops[!ismissing.(actualcrops[:maxcrop_before]) .& (actualcrops[:maxcrop_before] .== "CORN"), :maxcrop_before] = "corn"
actualcrops[!ismissing.(actualcrops[:maxcrop_before]) .& (actualcrops[:maxcrop_before] .== "WHEAT"), :maxcrop_before] = "whea"
actualcrops[!ismissing.(actualcrops[:maxcrop_before]) .& (actualcrops[:maxcrop_before] .== "RICE"), :maxcrop_before] = "rice"
actualcrops[!ismissing.(actualcrops[:maxcrop_before]) .& (actualcrops[:maxcrop_before] .== "BARLEY"), :maxcrop_before] = "barl"

obscrop = repeat(["none"], outer=nrow(masterregions))
toadd = zeros(nrow(masterregions))
for ii in 1:nrow(masterregions)
    println(ii)
    fips = masterregions[ii, :fips]
    obsrow = actualcrops[actualcrops[:fips] .== fips, :]
    if nrow(obsrow) == 1
        observed = obsrow[1, :maxcrop_before]
        if !isna(observed)
            obscrop[ii] = observed
            data = ers_information(observed, "revenue", 2010; includeus=false) - ers_information(observed, "cost", 2010; includeus=false)
            data[isna.(data)] = 0
            data = convert(Vector{Float64}, data)

            if observed != maxprofit[ii]
                toadd[ii] = profit[ii] - data[ii]
            end
            if observed != maxestprofit[ii]
                esttoadd[ii] = estprofit[ii] - data[ii]
            end
            if observed != maxestprofit_changeirr[ii]
                esttoadd_changeirr[ii] = estprofit_changeirr[ii] - data[ii]
            end
        end
    end
end

masterregions[:obscrop] = obscrop
masterregions[:toadd] = toadd
masterregions[:esttoadd] = toadd
masterregions[:esttoadd_changeirr] = toadd

if do_cropdrop
    writetable("farmvalue-limited.csv", masterregions)
else
    writetable("farmvalue.csv", masterregions)
end
