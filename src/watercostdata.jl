using DataFrames
using RData

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
	end



    
# gw: extraction cost prop to drawdown to watertable
	aquiferextractioncost = zeros(numcounties)
    colorado_drawdown= readtable(joinpath(datapath("drawdown.csv")))
    #80.6 replaced with 1000000
    aquiferextractioncost=array(0.3048*colorado_drawdown[:mean]*energycostperlift)
#end 
### TREATMENT COST
# treatment cost information at the county level
# in $ per 1000m3 treated

### DISTRIBUTION COST
# first model: only pressure cost (10m of lift)
