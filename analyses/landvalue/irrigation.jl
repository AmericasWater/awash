using DataFrames
using CSV, Missings

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/single.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/datastore.jl")

knownareas = getfilteredtable("agriculture/knownareas.csv", :fips)

irrigation = readtable(expanduser("~/Dropbox/Agriculture Weather/irrigation/summary.csv"))
irrigation[:fips] = round.(Int64, irrigation[:NHGISST] * 100 + irrigation[:NHGISCTY] / 10)

predfiles = Dict(:BARLEY => "predictors-Barley-combined.csv", :CORN => "predictors-Maize-combined.csv",
                 :COTTON => "predictors-Cotton-combined.csv", :RICE => "predictors-Rice-combined.csv",
                 :SOYBEANS => "predictors-Soybeans-combined.csv", :WHEAT => "predictors-Wheat-combined.csv")
preddata = Dict()
for crop in keys(predfiles)
    data = readtable(expanduser("~/Dropbox/Agriculture Weather/cropfiles/$(predfiles[crop])"))
    preddata[crop] = data
end

cropirr = Dict(:BARLEY => "ba", :CORN => "cn", :COTTON => "co", :RICE => "ri", :SOYBEANS => "sy", :WHEAT => "wh")

results = DataFrame(fips=Int64[], irrfrac=Float64[], BARLEY=Float64[], CORN=Float64[], COTTON=Float64[], RICE=Float64[], SOYBEANS=Float64[], WHEAT=Float64[], wreqBARLEY=Union{Float64, Missing}[], wreqCORN=Union{Float64, Missing}[], wreqCOTTON=Union{Float64, Missing}[], wreqRICE=Union{Float64, Missing}[], wreqSOYBEANS=Union{Float64, Missing}[], wreqWHEAT=Union{Float64, Missing}[])
for ii in 1:nrow(knownareas)
    irtotal = 0
    rntotal = 0
    irrrow = irrigation[irrigation[:fips] .== knownareas[ii, :fips], :]

    cropfracs = []
    wreqs = []
    for crop in keys(cropirr)
        ircrop = irrrow[Symbol("$(cropirr[crop])irsum")][1]
        rncrop = irrrow[Symbol("$(cropirr[crop])rnsum")][1]
        areacrop = knownareas[ii, crop]
        if ircrop == 0 && rncrop == 0
            rncrop = areacrop
            push!(cropfracs, 0.0)
        else
            sumcrop = ircrop + rncrop
            push!(cropfracs, ircrop / sumcrop)
            ircrop *= areacrop / sumcrop
            rncrop *= areacrop / sumcrop
        end
        irtotal += ircrop
        rntotal += rncrop

        wreqvals = collect(Missings.skip(preddata[crop][preddata[crop][:fips] .== knownareas[ii, :fips], :wreq]))
        if length(wreqvals) > 0
            push!(wreqs, mean(wreqvals))
        else
            push!(wreqs, Missings.missing)
        end
    end

    try
        wreqs = collect(Missings.replace(wreqs, mean(Missings.skip(wreqs))))
    end
    if irtotal == 0 && rntotal == 0
        push!(results, [knownareas[ii, :fips]; 0.0; cropfracs; wreqs])
    else
        push!(results, [knownareas[ii, :fips]; irtotal / (irtotal + rntotal); cropfracs; wreqs])
    end
end

CSV.write("irrigation.csv", results)
