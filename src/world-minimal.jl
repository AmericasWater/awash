using DataFrames
using CSV
include("lib/datastore.jl")

suffix = getsuffix()

masterregions = CSV.read(datapath(config["masterregions"]), eltypes=[String, String, String])

if get(config, "filterstate", nothing) != nothing
    masterregions = masterregions[map(fips -> fips[1:2], masterregions[:fips]) .== config["filterstate"], :]
end
