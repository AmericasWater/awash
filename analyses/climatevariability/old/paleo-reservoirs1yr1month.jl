#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/paleo-1year.yml");
config["timestep"] = 1
config["startweather"] = 1
# Optimization without reservoirs
config["rescap"] = "zero";
include("../../src/optimize-waterallocation.jl");
writecsv("../analyses/climatevariability/paleo1yr1month/failuresin.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

# Optimization with reservoirs at their current capacities
config["rescap"] = "full";

#cache_clear()
include("../../src/optimize-waterallocation.jl");
writecsv("../analyses/climatevariability/paleo1yr1month/failurecon.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

include("../../src/simulate.jl")

savedata("../analyses/climatevariability/paleo1yr1month/captures.csv", :Reservoir, :captures)


