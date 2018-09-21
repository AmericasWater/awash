### SCRIPT TO SAVE FILES
propenv = config["proportionnaturalflowforenvironment"]
reval = config["rescap"]

if get(config, "filtercanals", nothing) != nothing
    configname = "$surfconj-propenv$propenv-rescap$reval-nocanal"
else
    configname = "$surfconj-propenv$propenv-rescap$reval"
end

if get(config, "waterrightconst", nothing) != nothing
    rights = config["waterrightconst"]
    configname = "$configname-$rights"
else
    configname = "$configname-norightconst"
end

if surfconj == "surface"
    include("../../src/optimize-surface.jl");
    #include("optimize-surface.jl");

    if reval == "full"
        writecsv("$savingresultspath/captures-$configname.csv", reshape(sol.sol[sum(varlens[1:3])+1:end], numreservoirs, numsteps))
    end
elseif surfconj == "conj"
    include("../../src/optimize-waterallocation.jl");
    #include("optimize-waterallocation.jl");
    writecsv("$savingresultspath/gw-$configname.csv", reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])],numcounties, numsteps))
    if reval == "full"
        writecsv("$savingresultspath/captures-$configname.csv", reshape(sol.sol[sum(varlens[1:4])+1:end], numreservoirs, numsteps))
    end
else
    error("WRONG OPTIM TYPE")
end

writecsv("$savingresultspath/failure-$configname.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));

if evalsim
    include("../../src/simulate.jl")
    #include("simulate.jl")

    savedata("$savingresultspath/dem_tot-$configname.csv", :WaterDemand, :totaldemand)
    if savedem
        savedata("$savingresultspath/dem_ir.csv", :WaterDemand, :totalirrigation)
        savedata("$savingresultspath/dem_do.csv", :WaterDemand, :domesticuse)
        savedata("$savingresultspath/dem_in.csv", :WaterDemand, :industrialuse)
        savedata("$savingresultspath/dem_ur.csv", :WaterDemand, :urbanuse)
        savedata("$savingresultspath/dem_th.csv", :WaterDemand, :thermoelectricuse)
        savedata("$savingresultspath/dem_li.csv", :WaterDemand, :livestockuse)
    end

    savedata("$savingresultspath/allocation_wgw-$configname.csv", :Allocation, :watergw)
    savedata("$savingresultspath/allocation_wsw-$configname.csv", :Allocation, :swsupply)
    savedata("$savingresultspath/allocation_bal-$configname.csv", :Allocation, :balance)
    #savedata("$savingresultspath/wsi_indexgw-$configname.csv", :WaterStressIndex, :indexgw)
    #savedata("$savingresultspath/wsi_indexsw-$configname.csv", :WaterStressIndex, :indexsw)
    #savedata("$savingresultspath/wsi_indexWaSSli-$configname.csv", :WaterStressIndex, :indexWaSSli)
    #savedata("$savingresultspath/wsi_indexWaSSI-$configname.csv", :WaterStressIndex, :indexWaSSI)
    #savedata("$savingresultspath/wsi_indexWSI.csv", :WaterStressIndex, :indexWSI)
end
