#cd("../../src")
include("nui.jl")
config = readconfig("../configs/standard-60year.yml");
savingresultspath = "../analyses/waterstressindex/60years/"


#### PART I: current withdrawals risk
config["rescap"] = "zero"; # Optimization without reservoirs
config["filtercanals"] = nothing;
config["waterrightconst"] = nothing;
flowprop = [0. 0.37 0.5];
config["proportionnaturalflowforenvironment"] = flowprop[3];
surfconj = "surface";
savedem = true;

rm("../data/cache/counties/extraction/withdrawals.jld")
rm("../data/cache/counties/extraction/waterfromgw.jld")
rm("../data/cache/counties/extraction/returns.jld")
rm("../data/cache/counties/partialhouse.jld")
rm("../data/cache/counties/partialhouse2.jld")

include("runoptisim.jl")


#### PART II: conjunctive strategy
surfconj = "conj";
savedem = false;
config["waterrightconst"] = "SWGW";
include("runoptisim.jl")
config["waterrightconst"] = "GW";
include("runoptisim.jl")
config["waterrightconst"] = "SW";
include("runoptisim.jl")
config["waterrightconst"] = nothing;
include("runoptisim.jl")

#### PART III: infra strategy
config["rescap"] = "full"; # Optimization without reservoirs
config["filtercanals"] = nothing;
config["waterrightconst"] = nothing;
surfconj = "surface";
include("runoptisim.jl")

rm("../data/cache/counties/extraction/withdrawals.jld")
rm("../data/cache/counties/extraction/waterfromgw.jld")
rm("../data/cache/counties/extraction/returns.jld")
rm("../data/cache/counties/partialhouse.jld")
rm("../data/cache/counties/partialhouse2.jld")
config["rescap"] = "zero"; # Optimization without reservoirs
config["filtercanals"] = "contains";
config["waterrightconst"] = nothing;
surfconj = "surface";
include("runoptisim.jl")
