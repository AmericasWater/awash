#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-yearly.yml");
savingresultspath = "../analyses/climatevariability/paper3/counties/"


config["waterrightconst"] = nothing;
flowprop = [0. 0.37 0.5];
config["proportionnaturalflowforenvironment"] = flowprop[3];
surfconj = "surface";
savedem = true;
evalsim = false;
starty = 1951;
endy = 2000;
simyrs = 50;

if isfile("../data/counties/extraction/withdrawals.jld")
    rm("../data/counties/extraction/withdrawals.jld")
end
if isfile("../data/counties/extraction/waterfromgw.jld")
    rm("../data/counties/extraction/waterfromgw.jld")
end
if isfile("../data/counties/extraction/returns.jld")
    rm("../data/counties/extraction/returns.jld")    
end
if isfile("../data/cache/counties/partialhouse-grwo.jld")
    rm("../data/cache/counties/partialhouse-grwo.jld")
    rm("../data/cache/counties/partialhouse-gwwo.jld")
end


#####################################
# CASE I: w/ canals, no reservoirs
config["rescap"] = "zero"; # Optimization without reservoirs
config["filtercanals"] = nothing;
include("runoptisim.jl")


#####################################
# CASE II: w/ canals and w/ reservoirs
#config["rescap"] = "full"; # Optimization with reservoirs
#include("runoptisim.jl")


#####################################
# CASE III: no canals, no reservoirs
#config["filtercanals"] = "contains";
config["rescap"] = "zero"; # Optimization without reservoirs

#rm("../data/counties/extraction/withdrawals.jld")
#rm("../data/counties/extraction/returns.jld")
#rm("../data/cache/counties/partialhouse.jld")
#rm("../data/cache/counties/partialhouse2.jld")


#include("runoptisim.jl")