#cd("../../src")
include("../../src/nui.jl")
config = readconfig("../configs/standard-5year.yml");
savingresultspath = "../analyses/papers/paper2/"


config["waterrightconst"] = nothing;
flowprop = [0. 0.37 0.5];
config["proportionnaturalflowforenvironment"] = flowprop[3];
surfconj = "conj";
savedem = false;
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
# CONJUNCTIVE USE w/ canals, no reservoirs
config["rescap"] = "zero"; # Optimization without reservoirs
config["filtercanals"] = nothing;

### CASE I: w/ SWGW constraint
config["waterrightconst"] = "SWGW"
include("runoptisim.jl")

### CASE II:w/ GW constraint
config["waterrightconst"] = "GW"
include("runoptisim.jl")

### CASE III: w/ SW constraint
config["waterrightconst"] = "SW"
include("runoptisim.jl")

### CASE IV: w/o constraint
config["waterrightconst"] = nothing
include("runoptisim.jl")


