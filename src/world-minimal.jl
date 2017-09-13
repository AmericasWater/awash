using DataFrames
include("lib/datastore.jl")

suffix = getsuffix()

masterregions = readtable(datapath(config["masterregions"]), eltypes=[UTF8String, UTF8String, UTF8String])

if get(config, "filterstate", nothing) != nothing
    masterregions = masterregions[map(fips -> fips[1:2], masterregions[:fips]) .== config["filterstate"], :]
end
