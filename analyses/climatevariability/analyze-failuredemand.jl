#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-10year.yml");


# Optimization without reservoirs
config["rescap"] = "zero";
# Optimization with reservoirs at their current capacities
#config["rescap"] = "full";

include("../../src/optimize-surface.jl");
writecsv("../analyses/climatevariability/failure.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

include("../../src/simulate.jl")

savedata("../analyses/climatevariability/dem_tot.csv", :WaterDemand, :totaldemand)
savedata("../analyses/climatevariability/dem_ir.csv", :WaterDemand, :totalirrigation)
savedata("../analyses/climatevariability/dem_do.csv", :WaterDemand, :domesticuse)
savedata("../analyses/climatevariability/dem_in.csv", :WaterDemand, :industrialuse)
savedata("../analyses/climatevariability/dem_ur.csv", :WaterDemand, :urbanuse)
savedata("../analyses/climatevariability/dem_th.csv", :WaterDemand, :thermoelectricuse)
savedata("../analyses/climatevariability/dem_li.csv", :WaterDemand, :livestockuse)


savedata("../analyses/climatevariability/allocation_wgw.csv", :Allocation, :watergw)
savedata("../analyses/climatevariability/allocation_wsw.csv", :Allocation, :swsupply)
savedata("../analyses/climatevariability/allocation_bal.csv", :Allocation, :balance)
