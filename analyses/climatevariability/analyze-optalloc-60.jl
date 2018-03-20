#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-1year.yml");
config["timestep"] = 1 
config["startweather"] = 13


# Optimization without reservoirs
config["rescap"] = "zero";
for yy in 2:60
	include("../../src/optimize-waterallocation.jl");
	writecsv("../analyses/climatevariability/failuresin_optall_year$yy.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));
	writecsv("../analyses/climatevariability/waterfromgw_optall_year$yy.csv", reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numregions, numsteps))
	config["startweather"] += 12
end

