# need waternet
# this script breaks down

using DataFrames
using RData

include("lib/datastore.jl")
include("lib/inputcache.jl")

# energy cost to lift 1000m3 by 1m
energycostperlift = 0.05 # in $/1000m3 /m of lift | value from CALVIN
mingwextcost = 0. #we assume that the cost of extraction is at least mingwextcost


### EXTRACTION COST
# sw: compute relative elevation if source downhill, 0 otherwise
# if missing information, default value is specified by naelev
naelev = 0.
if get(config, "watercost-extraction", true)
    if isfile(datapath("cache/canalextractioncost$suffix.jld"))
        println("Loading extraction cost from saved data...")
	canalextractioncost = deserialize(open(datapath("cache/canalextractioncost$suffix.jld"), "r"));
	aquiferextractioncost = deserialize(open(datapath("cache/aquiferextractioncost$suffix.jld"), "r"));
    else
	canalextractioncost = zeros(numcanals)
	for ii in 1:numcanals
		gauge_id = draws[ii,:gaugeid][(search(draws[ii,:gaugeid],".")[1]+1):end]
		indx = find(waternetdata["stations"][:colid] .== gauge_id)
		if length(indx) == 0
			canalextractioncost[ii] = naelev
		else
			if length(indx)>1
				indx = indx[find(waternetdata["stations"][indx,:collection] .== draws[ii,:gaugeid][1:(search(draws[ii,:gaugeid],".")[1]-1)])]
			end
			elevation_source = waternetdata["stations"][indx, :elev][1]

                        if :fips in names(draws)
			    county_id = draws[ii, :fips] < 10000 ? "0$(draws[ii, :fips])" : "$(draws[ii, :fips])"
                        else
                            county_id = draws[ii, :state]
                        end
                        if ismissing(county_id) || county_id == "missing"
                            canalextractioncost[ii] = 0
                        else
                            counties = knowndf("region-info")
			    elevation_county = counties[:Elevation_ft][find(regionindex(counties, :) .== county_id)][1] *0.305
			    if ismissing(elevation_county) # if county-info does not have elevation information, use values from gw model
				elevation_county = readtable(datapath("gwmodel/county_elevation.txt"))[1][find(regionindex(counties, :) .== county_id)][1]
			    end

			    if elevation_source < elevation_county
				canalextractioncost[ii] = elevation_county - elevation_source
			    end
                        end
		end
	end

	# gw: extraction cost prop to drawdown to watertable
	aquiferextractioncost = zeros(numcounties)
        drawdowndeepaquifer = readdlm(datapath("cost/drawdown0.txt"))
	for ii in 1:numregions
            # For now, assume that regions == GW aquifers
	    aquiferextractioncost[ii] = drawdowndeepaquifer[ii]
	end
	aquiferextractioncost[find(aquiferextractioncost .<mingwextcost)] = mingwextcost

# compute costs
	canalextractioncost *= energycostperlift
	aquiferextractioncost *= energycostperlift

# save
	serialize(open(cachepath("canalextractioncost$suffix.jld"), "w"), canalextractioncost)
	serialize(open(cachepath("aquiferextractioncost$suffix.jld"), "w"), aquiferextractioncost)
    end

    else
	    ## if watercost-extraction == false in configuration file, we assume a higher cost to extract GW than SW
	    canalextractioncost = ones(numcanals)
	    aquiferextractioncost = 100*ones(numaquifers)
end

### TREATMENT COST
# treatment cost information at the county level
# in $ per 1000m3 treated
if get(config, "watercost-treatment", false)
	swtreatmentcost = 10*ones(numcounties)
	gwtreatmentcost = ones(numcounties)
else
	swtreatmentcost = zeros(numcounties)
	gwtreatmentcost = zeros(numcounties)
end

### DISTRIBUTION COST
# first model: only pressure cost (10m of lift)
distributioncost = 10. * energycostperlift * ones(numcounties)







