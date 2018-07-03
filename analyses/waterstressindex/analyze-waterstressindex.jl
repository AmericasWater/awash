#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-10year.yml");


# Optimization without reservoirs
config["rescap"] = "zero";
# Optimization with reservoirs at their current capacities
#config["rescap"] = "full";

include("../../src/optimize-surface.jl");
writecsv("../analyses/waterstressindex/failure.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

include("../../src/simulate.jl")

savedata("../analyses/waterstressindex/dem_tot.csv", :WaterDemand, :totaldemand)
savedata("../analyses/waterstressindex/dem_ir.csv", :WaterDemand, :totalirrigation)
savedata("../analyses/waterstressindex/dem_do.csv", :WaterDemand, :domesticuse)
savedata("../analyses/waterstressindex/dem_in.csv", :WaterDemand, :industrialuse)
savedata("../analyses/waterstressindex/dem_ur.csv", :WaterDemand, :urbanuse)
savedata("../analyses/waterstressindex/dem_th.csv", :WaterDemand, :thermoelectricuse)
savedata("../analyses/waterstressindex/dem_li.csv", :WaterDemand, :livestockuse)


savedata("../analyses/waterstressindex/allocation_wgw.csv", :Allocation, :watergw)
savedata("../analyses/waterstressindex/allocation_wsw.csv", :Allocation, :swsupply)
savedata("../analyses/waterstressindex/allocation_bal.csv", :Allocation, :balance)

savedata("../analyses/waterstressindex/wsi_indexgw.csv", :WaterStressIndex, :indexgw)
savedata("../analyses/waterstressindex/wsi_indexsw.csv", :WaterStressIndex, :indexsw)
savedata("../analyses/waterstressindex/wsi_indexWaSSli.csv", :WaterStressIndex, :indexWaSSli)
savedata("../analyses/waterstressindex/wsi_indexWaSSI.csv", :WaterStressIndex, :indexWaSSI)
#savedata("../analyses/waterstressindex/wsi_indexWSI.csv", :WaterStressIndex, :indexWSI)
