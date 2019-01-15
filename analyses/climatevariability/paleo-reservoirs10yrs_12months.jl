#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/paleo-10year.yml");
# Optimization without reservoirs
config["rescap"] = "zero";
include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/paleo_10yrs_12months/failuresin.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

# Optimization with reservoirs at their current capacities
config["rescap"] = "full";

#cache_clear()
include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/paleo_10yrs_12months/failurecon.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

include("../../src/simulate.jl")

savedata("../analyses/climatevariability/paleo_10yrs_12months/captures.csv", :Reservoir, :captures)

savedata("../analyses/climatevariability/paleo_10yrs_12months/dem_tot.csv", :Allocation, :watertotaldemand)

savedata("../analyses/climatevariability/paleo_10yrs_12months/storagecapmax.csv", :Reservoir, :storagecapacitymax)

savedata("../analyses/climatevariability/paleo_10yrs_12months/storage.csv", :Reservoir, :storage)



