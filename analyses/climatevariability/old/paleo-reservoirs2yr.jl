#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/paleo-2year.yml");
config["timestep"] = 12
config["startweather"] = 1
# Optimization without reservoirs
config["rescap"] = "zero";
include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/paleo2yr/failuresin.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

# Optimization with reservoirs at their current capacities
config["rescap"] = "full";

#cache_clear()
include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/paleo2yr/failurecon.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

include("../../src/simulate.jl")

savedata("../analyses/climatevariability/paleo2yr/captures.csv", :Reservoir, :captures)


