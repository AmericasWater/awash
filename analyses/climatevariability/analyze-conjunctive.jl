include("../../src/nui.jl")
config = readconfig("../configs/standard-10year.yml");
config["timestep"] = 12
config["rescap"] = "zero";

include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/analyzeconjunctive/failureoptsurface.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));
recorded = getfilteredtable("extraction/USGS-2010.csv")
writecsv("../analyses/climatevariability/analyzeconjunctive/recordedtot_optsurface.csv", repeat(convert(Vector, recorded[:,:TO_To]) * config["timestep"] * 1383./12., outer=[1, numsteps]))
writecsv("../analyses/climatevariability/analyzeconjunctive/recordedsw_optsurface.csv", repeat(convert(Vector, recorded[:,:TO_SW]) * config["timestep"] * 1383./12., outer=[1, numsteps]))
writecsv("../analyses/climatevariability/analyzeconjunctive/recordedgw_optsurface.csv", repeat(convert(Vector, recorded[:,:TO_GW]) * config["timestep"] * 1383./12., outer=[1, numsteps]))


include("../../src/optimize-waterallocation.jl");
writecsv("../analyses/climatevariability/analyzeconjunctive/waterfromgw_optallocation.csv", reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numregions, numsteps))

include("../../src/simulate.jl")

savedata("../analyses/climatevariability/analyzeconjunctive/waterfromgw_optallocationsim.csv", :Allocation, :waterfromgw)
savedata("../analyses/climatevariability/analyzeconjunctive/waterfromsw_optallocationsim.csv", :Allocation, :swsupply)
savedata("../analyses/climatevariability/analyzeconjunctive/piezohead_optallocationsim.csv", :Aquifer, :piezohead)

