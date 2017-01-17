using DataFrames
using RData


if isfile(datapath("cache/gwmodel/dfgw$suffix.csv"))
    println("Loading saved groundwater model...")
    dfgw = readtable(datapath("cache/gwmodel/dfgw$suffix.csv"));
    lateralconductivity = convert(Array, readtable(datapath("cache/gwmodel/lateralconductivity$suffix.csv")));
    aquiferconnexion = convert(Array, readtable(datapath("cache/gwmodel/aquiferconnexion$suffix.csv")));

else
    if config["dataset"] == "counties"
        dfgw = readtable(datapath("gwmodel/dfgw.csv"));
        lateralconductivity = deserialize(open(datapath("gwmodel/lateralconductivity.jld"), "r"));
        aquiferconnexion = deserialize(open(datapath("gwmodel/aquiferconnexion.jld"), "r"));
        
        if config["filterstate"] != nothing
            println("Generating regionnal groundwater model...")
	    vstates = round(Int64, floor(dfgw[:fips] ./ 1000));
	    subfips = find(vstates .== parse(Int64, get(config,"filterstate", nothing)));
	
            dfgw = dfgw[subfips,:];

  	    lateralconductivity = lateralconductivity[subfips,subfips];
  	    aquiferconnexion = aquiferconnexion[subfips,subfips];

            # Save groundwater model
            writetable(datapath("cache/gwmodel/dfgw$suffix.csv"), dfgw)
            writetable(datapath("cache/gwmodel/lateralconductivity$suffix.csv"), convert(DataFrame, lateralconductivity))
            writetable(datapath("cache/gwmodel/aquiferconnexion$suffix.csv"), convert(DataFrame, aquiferconnexion))

        end
    elseif config["dataset"] == "three"
        d = [-100.; -90.; -95.];
        s = [5e-4; 5e-4; 5e-4];
        p0 = [-55.; -45.; -53.];
        a = [8e8; 6e8; 5e8];
        el = [10; 14; 9];
        dfgw = DataFrame(Any[[1 2 3], d, p0, s, a, el], [:fips, :depthaquif, :piezohead0, :storagecoef, :areaaquif, :elevation]);
     
        lateralconductivity = [  0  1e-4     0;
                              1e-4     0  1e-4;
      	                         0  1e-6     0];

        aquiferconnexion = [0. 1. 0.; 1. 0. 1.; 0 1. 0];
    end
end
