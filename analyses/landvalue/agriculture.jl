using DataArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/standard-1year.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

do_cropdrop = true

if do_cropdrop
    crops = ["corn", "soyb", "whea", "barl", "cott", "rice"]
else
    crops = ["corn", "soyb", "whea", "sorg", "barl", "cott", "rice", "oats", "pean"]
end

value = repmat([0.0], size(masterregions, 1))
maxvalue = repmat(["none"], size(masterregions, 1))
profit = repmat([0.0], size(masterregions, 1))
maxprofit = repmat(["none"], size(masterregions, 1))
for crop in crops
    data = ers_information(crop, "Opportunity cost of land", 2010; includeus=false)
    data[isna.(data)] = 0
    data = convert(Vector{Float64}, data)

    maxvalue[data .> value] = crop
    value = max(value, data)

    data = ers_information(crop, "revenue", 2010; includeus=false) - ers_information(crop, "cost", 2010; includeus=false)
    data[isna.(data)] = 0
    data = convert(Vector{Float64}, data)

    maxprofit[data .> profit] = crop
    profit = max(profit, data)
end

masterregions[:farmvalue] = value
masterregions[:valuesource] = maxvalue
masterregions[:profit] = profit
masterregions[:profitsource] = maxprofit

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
        if !isna(observed) && observed != maxprofit[ii]
            obscrop[ii] = observed
            data = ers_information(observed, "revenue", 2010; includeus=false) - ers_information(observed, "cost", 2010; includeus=false)
            data[isna.(data)] = 0
            data = convert(Vector{Float64}, data)

            toadd[ii] = profit[ii] - data[ii]
        end
    end
end

masterregions[:obscrop] = obscrop
masterregions[:toadd] = toadd

if do_cropdrop
    writetable("farmvalue-limited.csv", masterregions)
else
    writetable("farmvalue.csv", masterregions)
end
