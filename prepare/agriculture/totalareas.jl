using DataFrames

irrigateds = readtable("../../data/counties/agriculture/irrigatedareas.csv")
rainfeds = readtable("../../data/counties/agriculture/rainfedareas.csv")

alltotals = DataFrame(FIPS=irrigateds[:FIPS])
mapping = Dict{Symbol, Vector{Symbol}}(:barley => [:Barley, :Barley_Winter],
                                                       :corn => [:Maize], :sorghum => [:Sorghum],
                                                       :soybeans => [:Soybean],
                                                       :wheat => [:Wheat, :Wheat_Winter],
                                                       :hay => [:Alfalfa, :Otherhay])
for crop in [:barley, :corn, :sorghum, :soybeans, :wheat, :hay]
    totals = zeros(nrow(irrigateds))
    for irrcrop in mapping[crop]
        thisirrigateds = irrigateds[irrcrop]
        thisirrigateds[isna.(thisirrigateds)] = 0

        thisrainfeds = rainfeds[irrcrop]
        thisrainfeds[isna.(thisrainfeds)] = 0

        totals = totals + thisirrigateds + thisrainfeds
    end

    alltotals[crop] = totals
end

writetable("../../data/counties/agriculture/totalareas.csv", alltotals)
