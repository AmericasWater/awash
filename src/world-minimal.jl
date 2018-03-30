using DataFrames
include("lib/datastore.jl")

suffix = getsuffix()

masterregions = readtable(datapath(config["masterregions"]), eltypes=[String, String, String])

if get(config, "filterstate", nothing) != nothing
    masterregions = masterregions[map(fips -> fips[1:2], masterregions[:fips]) .== config["filterstate"], :]
    if config["filterstate"]=="36"
	    masterregions=masterregions[masterregions[:fips].!="36059",:    ]
	    masterregions=masterregions[masterregions[:fips].!="36103",:    ]
    end
end
