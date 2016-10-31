using DataFrames
using RData




if isfile(datapath("cache/gwmodel/dfgw$suffix.jld"))
    println("Loading saved groundwater model...")
    dfgw = deserialize(open(datapath("cache/gwmodel/dfgw$suffix.jld"), "r"));
    lateralconductivity = deserialize(open(datapath("cache/gwmodel/lateralconductivity$suffix.jld"), "r"));
    aquiferconnexion = deserialize(open(datapath("cache/gwmodel/aquiferconnexion$suffix.jld"), "r"));

else
    if config["netset"] == "usa"
        println("Generating groundwater model...")
        gw = load(datapath("gwmodel/contusgwmodel.RData"))
        vfips = readdlm(datapath("gwmodel/v_FIPS.txt"));
        
        if config["filterstate"] != nothing
	    vstates = round(Int64, floor(vfips / 1000));
	    subfips = (vstates .== parse(Int64, get(config,"filterstate", nothing)));
        else
	    subfips = 1:3109;
	end
	
        d = gw["aquifer_depth"][subfips[1:3109]];
	p0 = zeros(numaquifers);#gw["piezohead0"].data[subfips[1:3109]];
  	s = gw["vector_storativity"][subfips[1:3109]];
  	a = gw["county_area"][subfips[1:3109]]/1000;
	el = gw["county_elevation"][:V1][subfips[1:3109]];

  	lateralconductivity = gw["matrix_leakage_factor"][subfips[1:3109],subfips[1:3109]];
  	aquiferconnexion = gw["connectivity_matrix"][subfips[1:3109],subfips[1:3109]];

    elseif config["netset"] == "three"
        depthaquif = [-100.; -90.; -95.];
        storagecoef = [5e-4; 5e-4; 5e-4];
        piezohead0 = [-55.; -45.; -53.];
        areaaquif = [8e8; 6e8; 5e8];

     
        lateralconductivity = [  0  1e-4     0;
                              1e-4     0  1e-4;
      	                         0  1e-6     0];

        aquiferconnexion = [0. 1. 0.; 1. 0. 1.; 0 1. 0];
    end
    
    dfgw = DataFrame(Any[d, p0, s, a, el], [:depthaquif, :piezohead0, :storagecoef, :areaaquif, :elevation]) 
    # Save groundwater model
    serialize(open(datapath("cache/gwmodel/dfgw$suffix.jld"), "w"), dfgw)
    serialize(open(datapath("cache/gwmodel/lateralconductivity$suffix.jld"), "w"), lateralconductivity)
    serialize(open(datapath("cache/gwmodel/aquiferconnexion$suffix.jld"), "w"), aquiferconnexion)
end