#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-10year.yml");


# Optimization without reservoirs
config["rescap"] = "zero";
config["filtercanals"] = "contains";
config["waterrightconst"] = nothing;
flowprop = [0. 0.37 0.5]

# Optimization with reservoirs at their current capacities
#config["rescap"] = "full";
for ee in 1:length(flowprop)
    savingresultspath = "../analyses/waterstressindex/10years/"
    config["proportionnaturalflowforenvironment"] = flowprop[ee]
    propenv = config["proportionnaturalflowforenvironment"]
    reval = config["rescap"]
    if get(config, "filtercanals", nothing) != nothing
        configname = "surface-propenv$propenv-rescap$reval-nocanal"
    else
        configname = "surface-propenv$propenv-rescap$reval"
    end

    include("../../src/optimize-surface.jl");
    writecsv("$savingresultspath/failure-$configname.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

    include("../../src/simulate.jl")

    savedata("$savingresultspath/dem_tot-$configname.csv", :WaterDemand, :totaldemand)
    #savedata("$savingresultspath/dem_ir.csv", :WaterDemand, :totalirrigation)
    #savedata("$savingresultspath/dem_do.csv", :WaterDemand, :domesticuse)
    #savedata("$savingresultspath/dem_in.csv", :WaterDemand, :industrialuse)
    #savedata("$savingresultspath/dem_ur.csv", :WaterDemand, :urbanuse)
    #savedata("$savingresultspath/dem_th.csv", :WaterDemand, :thermoelectricuse)
    #savedata("$savingresultspath/dem_li.csv", :WaterDemand, :livestockuse)

    savedata("$savingresultspath/allocation_wgw-$configname.csv", :Allocation, :watergw)
    savedata("$savingresultspath/allocation_wsw-$configname.csv", :Allocation, :swsupply)
    savedata("$savingresultspath/allocation_bal-$configname.csv", :Allocation, :balance)

    savedata("$savingresultspath/wsi_indexgw-$configname.csv", :WaterStressIndex, :indexgw)
    savedata("$savingresultspath/wsi_indexsw-$configname.csv", :WaterStressIndex, :indexsw)
    savedata("$savingresultspath/wsi_indexWaSSli-$configname.csv", :WaterStressIndex, :indexWaSSli)
    savedata("$savingresultspath/wsi_indexWaSSI-$configname.csv", :WaterStressIndex, :indexWaSSI)
    #savedata("$savingresultspath/wsi_indexWSI.csv", :WaterStressIndex, :indexWSI)

    if get(config, "filtercanals", nothing) != nothing
        configname = "conj-propenv$propenv-rescap$reval-nocanal"
    else
        configname = "conj-propenv$propenv-rescap$reval"
    end
    include("../../src/optimize-waterallocation.jl");
    writecsv("$savingresultspath/failure-$configname.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

    include("../../src/simulate.jl")

    savedata("$savingresultspath/dem_tot-$configname.csv", :WaterDemand, :totaldemand)
    #savedata("$savingresultspath/dem_ir.csv", :WaterDemand, :totalirrigation)
    #savedata("$savingresultspath/dem_do.csv", :WaterDemand, :domesticuse)
    #savedata("$savingresultspath/dem_in.csv", :WaterDemand, :industrialuse)
    #savedata("$savingresultspath/dem_ur.csv", :WaterDemand, :urbanuse)
    #savedata("$savingresultspath/dem_th.csv", :WaterDemand, :thermoelectricuse)
    #savedata("$savingresultspath/dem_li.csv", :WaterDemand, :livestockuse)

    savedata("$savingresultspath/allocation_wgw-$configname.csv", :Allocation, :watergw)
    savedata("$savingresultspath/allocation_wsw-$configname.csv", :Allocation, :swsupply)
    savedata("$savingresultspath/allocation_bal-$configname.csv", :Allocation, :balance)

    savedata("$savingresultspath/wsi_indexgw-$configname.csv", :WaterStressIndex, :indexgw)
    savedata("$savingresultspath/wsi_indexsw-$configname.csv", :WaterStressIndex, :indexsw)
    savedata("$savingresultspath/wsi_indexWaSSli-$configname.csv", :WaterStressIndex, :indexWaSSli)
    savedata("$savingresultspath/wsi_indexWaSSI-$configname.csv", :WaterStressIndex, :indexWaSSI)
    #savedata("$savingresultspath/wsi_indexWSI.csv", :WaterStressIndex, :indexWSI)
end


config["filtercanals"] = nothing;
config["waterrightconst"] = "GW";

for ee in 1:length(flowprop)
    savingresultspath = "../analyses/waterstressindex/10years/"
    config["proportionnaturalflowforenvironment"] = flowprop[ee]
    propenv = config["proportionnaturalflowforenvironment"]
    reval = config["rescap"]

    if get(config, "filtercanals", nothing) != nothing
        configname = "conj-propenv$propenv-rescap$reval-nocanal"
    else
        configname = "conj-propenv$propenv-rescap$reval"
    end
    if get(config, "waterrightconst", nothing) != nothing
        waterrightval = config["waterrightconst"]
        configname = "$configname-rights$waterrightval"
    end


    include("optimize-waterallocation.jl");
    writecsv("$savingresultspath/failure-$configname.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

    include("simulate.jl")

    savedata("$savingresultspath/dem_tot-$configname.csv", :WaterDemand, :totaldemand)
    #savedata("$savingresultspath/dem_ir.csv", :WaterDemand, :totalirrigation)
    #savedata("$savingresultspath/dem_do.csv", :WaterDemand, :domesticuse)
    #savedata("$savingresultspath/dem_in.csv", :WaterDemand, :industrialuse)
    #savedata("$savingresultspath/dem_ur.csv", :WaterDemand, :urbanuse)
    #savedata("$savingresultspath/dem_th.csv", :WaterDemand, :thermoelectricuse)
    #savedata("$savingresultspath/dem_li.csv", :WaterDemand, :livestockuse)

    savedata("$savingresultspath/allocation_wgw-$configname.csv", :Allocation, :watergw)
    savedata("$savingresultspath/allocation_wsw-$configname.csv", :Allocation, :swsupply)
    savedata("$savingresultspath/allocation_bal-$configname.csv", :Allocation, :balance)

    savedata("$savingresultspath/wsi_indexgw-$configname.csv", :WaterStressIndex, :indexgw)
    savedata("$savingresultspath/wsi_indexsw-$configname.csv", :WaterStressIndex, :indexsw)
    savedata("$savingresultspath/wsi_indexWaSSli-$configname.csv", :WaterStressIndex, :indexWaSSli)
    savedata("$savingresultspath/wsi_indexWaSSI-$configname.csv", :WaterStressIndex, :indexWaSSI)
    #savedata("$savingresultspath/wsi_indexWSI.csv", :WaterStressIndex, :indexWSI)
end
