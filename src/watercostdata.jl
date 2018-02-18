using DataFrames
using RData

include("lib/datastore.jl")

# energy cost to lift 1000m3 by 1m
#energycostperlift = 1.

# energy cost to lift 1000m3 by 1m
energycostperlift = 0.423133696 # in $/1000m3 /m of lift | value from CALVIN was 0.02

### EXTRACTION COST
# sw: compute relative elevation if source downhill, 0 otherwise
# if missing information, default value is specified by naelev
if isfile(datapath("canalextractioncost$suffix.jld"))
    println("Loading extraction cost from saved data...")
    canalextractioncost = deserialize(open(datapath("canalextractioncost$suffix.jld"), "r"))*energycostperlift;
else
    ## Optional cost for drawing down a river (environmental change)
    # Marginal cost is $3178.73 / MG, but 92% not subject to treatment costs, so $248.53 / MG
    canalextractioncost = 65.65 * ones(numcanals)
end

if isfile(datapath("drawdown.csv"))
    # gw: extraction cost prop to drawdown to watertable
    drawdown = readtable(datapath("drawdown.csv"))
    #80.6 replaced with 1000000
    aquiferextractioncost=array(0.3048*drawdown[:mean]*energycostperlift)
else
    # In docs/Optimization%20by%20Radius.ipynb, find that 1 MG costs $1464.37
    # 1 MG = 3.785411784 1000 m^3, so 1000 m^3 costs $386.85
    aquiferextractioncost = 386.85 * ones(numregions)
end

### TREATMENT COST
# treatment cost information at the county level
# in $ per 1000m3 treated

### DISTRIBUTION COST
# first model: only pressure cost (10m of lift)
