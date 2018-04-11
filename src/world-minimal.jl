## Minimal Environment Setup
#
# Loads basic information all files need to run model functions.

using DataFrames
include("lib/datastore.jl")

suffix = getsuffix()

masterregions = readtable(datapath(config["masterregions"]), eltypes=[String, String, String])

if get(config, "filterstate", nothing) != nothing
    masterregions = masterregions[map(fips -> fips[1:2], masterregions[:fips]) .== config["filterstate"], :]
end
