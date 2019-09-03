include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/standard-1year.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

crops = ["corn", "soyb", "whea", "barl", "cott", "rice"]

df = DataFrame(fips=masterregions[:fips])
for crop in crops
    data = ers_information(crop, "revenue", 2010; includeus=true) - ers_information(crop, "cost", 2010; includeus=true)
    df[Symbol(crop)] = data
end

CSV.write("actualprofit.csv", df)
