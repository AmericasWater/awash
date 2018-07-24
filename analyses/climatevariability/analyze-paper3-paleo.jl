#cd("../../src")
include("../../src/nui.jl")

savingresultspath = "../analyses/climatevariability/paper3/paleo_1451-2000/"
starty = 1451;
endy = 2000;
simyrs = 50;
flowprop = [0. 0.37 0.5];
surfconj = "surface";
savedem = true;
evalsim = false;


config = readconfig("../configs/paleo-yearly.yml");
config["proportionnaturalflowforenvironment"] = flowprop[2];
config["waterrightconst"] = nothing;


if isfile("../data/paleo/extraction/withdrawals.jld")
    rm("../data/paleo/extraction/withdrawals.jld")
end
if isfile("../data/paleo/extraction/waterfromgw.jld")
    rm("../data/paleo/extraction/waterfromgw.jld")
end
if isfile("../data/paleo/extraction/returns.jld")
    rm("../data/paleo/extraction/returns.jld")    
end
if isfile("../data/cache/paleo/partialhouse-gwwo.jld")
    rm("../data/cache/paleo/partialhouse-grwo.jld")
    rm("../data/cache/paleo/partialhouse-gwwo.jld")
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
#config["rescap"] = "zero"; # Optimization without reservoirs

#rm("../data/paleo/extraction/withdrawals.jld")
#rm("../data/paleo/extraction/returns.jld")
#rm("../data/cache/paleo/partialhouse.jld")
#rm("../data/cache/paleo/partialhouse2.jld")


#include("runoptisim.jl")