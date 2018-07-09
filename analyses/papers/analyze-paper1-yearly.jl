#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-1year.yml");
savingresultspath = "../analyses/papers/paper1-yearly/"

config["timestep"] = 12
config["waterrightconst"] = nothing;
config["endmonth"] = "9/2030";
flowprop = [0. 0.37 0.5];
config["proportionnaturalflowforenvironment"] = flowprop[3];
surfconj = "surface";
savedem = true;
evalsim = false;

if isfile("../data/counties/extraction/withdrawals.jld")
    rm("../data/counties/extraction/withdrawals.jld")
    if isfile("../data/counties/extraction/waterfromgw.jld")
        rm("../data/counties/extraction/waterfromgw.jld")
    end
    rm("../data/counties/extraction/returns.jld")    
end
if isfile("../data/cache/counties/partialhouse.jld")
    rm("../data/cache/counties/partialhouse.jld")
    rm("../data/cache/counties/partialhouse2.jld")
end


#####################################
# CASE I: w/ canals, no reservoirs
config["rescap"] = "zero"; # Optimization without reservoirs
config["filtercanals"] = nothing;
include("runoptisim-all.jl")


#####################################
# CASE II: w/ canals and w/ reservoirs
config["rescap"] = "full"; # Optimization with reservoirs
include("runoptisim-all.jl")


#####################################
# CASE III: no canals, no reservoirs
config["filtercanals"] = "contains";
config["rescap"] = "zero"; # Optimization without reservoirs

rm("../data/counties/extraction/withdrawals.jld")
rm("../data/counties/extraction/returns.jld")
rm("../data/cache/counties/partialhouse.jld")
rm("../data/cache/counties/partialhouse2.jld")


include("runoptisim-all.jl")
