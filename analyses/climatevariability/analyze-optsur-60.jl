#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-1year.yml");
config["timestep"] = 1 
config["startweather"] = 1


# Optimization without reservoirs
config["rescap"] = "zero";
for yy in 1:60
	include("../../src/optimize-surface.jl");
	writecsv("../analyses/climatevariability/failuresin_optsur_year$yy.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));
	config["startweather"] += 12
end

