using NaNMath, DataArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]

for crop in bayes_crops
    costs = ers_information(ers_crop(crop), "opcost", 2010; includeus=false);
    println("$crop: $(mean(costs[.!ismissing.(costs)])))")
end
