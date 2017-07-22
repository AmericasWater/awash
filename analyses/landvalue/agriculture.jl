include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/standard-1year.yml")

include("../../src/world.jl")
include("../../src/lib/agriculture-ers.jl")

crops = ["corn", "soyb", "whea", "sorg", "barl"] #"cott", "rice", "oats", "pean"

value = repmat([0.0], size(masterregions, 1))
for crop in crops
    data = ers_information(crop, "Opportunity cost of land", 2010; includeus=false)
    data[isna(data)] = 0
    data = convert(Vector{Float64}, data)
    value = max(value, data)
end

masterregions[:farmvalue] = value

writetable("farmvalue.csv", masterregions)
