## Groundwater data
#
# Loads groundwater structure for different configurations.

using DataFrames, DelimitedFiles
using RData
using CSV

if config["dataset"] == "states"
    @warn "State level groundwater model for US is inexistant"
    dfgw = DataFrame(Any[50*ones(49), zeros(49), ones(49)*0.1, ones(49), zeros(49)], [:depthaquif, :piezohead0, :storagecoef, :areaaquif, :elevation]);
    lateralconductivity = zeros(49,49);
    aquiferconnexion = zeros(49,49);

elseif isfile(loadpath("gwmodel/dfgw$suffix.csv"))
    println("Loading saved groundwater model...")
    dfgw = CSV.read(loadpath("gwmodel/dfgw$suffix.csv"));
    lateralconductivity = convert(Matrix, CSV.read(loadpath("gwmodel/lateralconductivity$suffix.csv")));
    aquiferconnexion = convert(Matrix, CSV.read(loadpath("gwmodel/aquiferconnexion$suffix.csv")));

elseif configdescends(config, "counties")
    dfgw = CSV.read(loadpath("gwmodel/dfgw.csv"));
    lateralconductivity = Array(readdlm(loadpath("gwmodel/lateralconductivity.csv"), ',')[2:end,:])
    aquiferconnexion = Array(readdlm(loadpath("gwmodel/aquiferconnexion.csv"), ',')[2:end,:])

    if config["filterstate"] != nothing
        println("Generating regionnal groundwater model...")
	vstates = round.(Int64, floor.(dfgw[!, :fips] ./ 1000));
	subfips = findall(vstates .== parse(Int64, get(config,"filterstate", nothing)));

        dfgw = dfgw[subfips,:];
  	lateralconductivity = lateralconductivity[subfips,subfips];
  	aquiferconnexion = aquiferconnexion[subfips,subfips];

        # Save state specific groundwater model
        CSV.write(datapath("gwmodel/dfgw$suffix.csv"), dfgw)
        CSV.write(datapath("gwmodel/lateralconductivity$suffix.csv"), convert(DataFrame, lateralconductivity))
        CSV.write(datapath("gwmodel/aquiferconnexion$suffix.csv"), convert(DataFrame, aquiferconnexion))

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

