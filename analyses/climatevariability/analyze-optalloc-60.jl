include("../../src/nui.jl")
config = readconfig("../configs/standard-10year.yml");
config["timestep"] = 12 
config["startweather"] = 1


# Optimization without reservoirs
config["rescap"] = "zero";
for yy in 1:6
	include("../../src/optimize-waterallocation.jl");
	writecsv("../analyses/climatevariability/failuresin_optall_part$yy.csv", reshape(sol.sol[1:varlens[1]], numregions, numsteps));
	writecsv("../analyses/climatevariability/waterfromgw_optall_part$yy.csv", reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numregions, numsteps))
	config["startweather"] += 120
end

