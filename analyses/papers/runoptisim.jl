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

config["startweather"] = (starty-1)*12+1;
for yy in 1:(endy-starty+1)

    if surfconj == "surface"
        include("../../src/optimize-surface.jl");
        #include("optimize-surface.jl");
        varlens = varlengths(house.model, house.paramcomps, house.parameters)
        if reval == "full"
            writecsv("$savingresultspath/captures-$configname-$yy.csv", reshape(sol.sol[sum(varlens[1:3])+1:end], numreservoirs, numsteps))
        end

    elseif surfconj == "conj"
        include("../../src/optimize-waterallocation.jl");
        #include("optimize-waterallocation.jl");
        varlens = varlengths(house.model, house.paramcomps, house.parameters)
        writecsv("$savingresultspath/gw-$configname-$yy.csv", reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])],numcounties, numsteps))
    
        if reval == "full"
            writecsv("$savingresultspath/captures-$configname-$yy.csv", reshape(sol.sol[sum(varlens[1:4])+1:end], numreservoirs, numsteps))
        end
    else
        error("WRONG OPTIM TYPE")
    end

    F1 = reshape(sol.sol[1:varlens[1]], numregions, numsteps);
    F2 = reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numregions, numsteps);
    writecsv("$savingresultspath/failure-$configname-$yy.csv", F1+F2);

    if evalsim
        include("../../src/simulate.jl")
        #include("simulate.jl")
        savedata("$savingresultspath/dem_tot-$configname-$yy.csv", :WaterDemand, :totaldemand)
        if savedem
            savedata("$savingresultspath/dem_ir-$yy.csv", :WaterDemand, :totalirrigation)
            savedata("$savingresultspath/dem_do-$yy.csv", :WaterDemand, :domesticuse)
            savedata("$savingresultspath/dem_in-$yy.csv", :WaterDemand, :industrialuse)
            savedata("$savingresultspath/dem_ur-$yy.csv", :WaterDemand, :urbanuse)
            savedata("$savingresultspath/dem_th-$yy.csv", :WaterDemand, :thermoelectricuse)
            savedata("$savingresultspath/dem_li-$yy.csv", :WaterDemand, :livestockuse)

        end

        savedata("$savingresultspath/allocation_wgw-$configname-$yy.csv", :Allocation, :watergw)
        savedata("$savingresultspath/allocation_wsw-$configname-$yy.csv", :Allocation, :swsupply)
        savedata("$savingresultspath/allocation_bal-$configname-$yy.csv", :Allocation, :balance)
        #savedata("$savingresultspath/wsi_indexgw-$configname.csv", :WaterStressIndex, :indexgw)
        #savedata("$savingresultspath/wsi_indexsw-$configname.csv", :WaterStressIndex, :indexsw)
        #savedata("$savingresultspath/wsi_indexWaSSli-$configname.csv", :WaterStressIndex, :indexWaSSli)
        #savedata("$savingresultspath/wsi_indexWaSSI-$configname.csv", :WaterStressIndex, :indexWaSSI)
        #savedata("$savingresultspath/wsi_indexWSI.csv", :WaterStressIndex, :indexWSI)
    end

    config["startweather"] += 12
end
