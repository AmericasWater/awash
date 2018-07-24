#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/paleo-1year.yml");
# Optimization without reservoirs
config["rescap"] = "zero";
include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/paleo_1yr_1month/failuresin.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

# Optimization with reservoirs at their current capacities
config["rescap"] = "full";

#cache_clear()
include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/paleo_1yr_1month/failurecon.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

include("../../src/simulate.jl")

savedata("../analyses/climatevariability/paleo_1yr_1month/captures.csv", :Reservoir, :captures)

savedata("../analyses/climatevariability/paleo_1yr_1month/dem_tot.csv", :Allocation, :watertotaldemand)

savedata("../analyses/climatevariability/paleo_1yr_1month/storagecapmax.csv", :Reservoir, :storagecapacitymax)

savedata("../analyses/climatevariability/paleo_1yr_1monthstorage.csv", :Reservoir, :storage)



