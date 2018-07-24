#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-1yearmonthly.yml");
savingresultspath = "../analyses/papers/paper3/"


config["waterrightconst"] = nothing;
flowprop = [0. 0.37 0.5];
config["proportionnaturalflowforenvironment"] = flowprop[3];
surfconj = "surface";
savedem = true;
evalsim = false;
starty = 1;
endy = 2;

if isfile("../data/paleo/extraction/withdrawals.jld")
    rm("../data/paleo/extraction/withdrawals.jld")
    if isfile("../data/paleo/extraction/waterfromgw.jld")
        rm("../data/paleo/extraction/waterfromgw.jld")
    end
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
config["rescap"] = "full"; # Optimization with reservoirs
include("runoptisim.jl")


#####################################
# CASE III: no canals, no reservoirs
config["filtercanals"] = "contains";
config["rescap"] = "zero"; # Optimization without reservoirs

rm("../data/paleo/extraction/withdrawals.jld")
rm("../data/paleo/extraction/returns.jld")
rm("../data/cache/paleo/partialhouse.jld")
rm("../data/cache/paleo/partialhouse2.jld")


include("runoptisim.jl")