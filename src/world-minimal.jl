## Minimal Environment Setup
#
# Loads basic information all files need to run model functions.

using DataFrames
include("lib/datastore.jl")

suffix = getsuffix()


masterregions = CSV.read(datapath(config["masterregions"]), types=[String, String, String])
masterregions[:fips] = convert(Vector{String}, masterregions[:fips])

if get(config, "filterstate", nothing) != nothing
    masterregions = masterregions[map(fips -> fips[1:2], masterregions[:fips]) .== config["filterstate"], :]
end
