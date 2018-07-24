#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-10year.yml");
config["timestep"] = 12
config["startweather"] = 612
# Optimization without reservoirs
config["rescap"] = "zero";
include("../../src/optimize-waterallocation.jl");
writecsv("../analyses/climatevariability/analyzereservoir1/failuresin.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

# Optimization with reservoirs at their current capacities
config["rescap"] = "full";

#cache_clear()
include("../../src/optimize-waterallocation.jl");
writecsv("../analyses/climatevariability/analyzereservoir1/failurecon.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

include("../../src/simulate.jl")

savedata("../analyses/climatevariability/analyzereservoir1/dem_tot.csv", :Allocation, :watertotaldemand)

savedata("../analyses/climatevariability/analyzereservoir1/captures.csv", :Reservoir, :captures)

savedata("../analyses/climatevariability/analyzereservoir1/storagecapmax.csv", :Reservoir, :storagecapacitymax)

savedata("../analyses/climatevariability/analyzereservoir1/storage.csv", :Reservoir, :storage)


