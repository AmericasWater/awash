## Minimal Environment Setup
#
# Loads basic information all files need to run model functions.

using DataFrames, CSV
include("lib/datastore.jl")

suffix = getsuffix()

masterregions = CSV.read(datapath(config["masterregions"]), types=[String, String, String])
masterregions[!, :fips] = convert(Vector{String}, masterregions[!, :fips])

if get(config, "filterstate", nothing) != nothing
    masterregions = masterregions[map(fips -> fips[1:2], masterregions[!, :fips]) .== config["filterstate"], :]
end

function clearslate()
    rm(cachepath("extraction/withdrawals$suffix.jld"), force=true)
    rm(cachepath("extraction/waterfromgw$suffix.jld"), force=true)
    rm(cachepath("extraction/captures$suffix.jld"), force=true)
    rm(cachepath("partialhouse2$suffix.jld"), force=true)
    rm(cachepath("partialhouse$suffix.jld"), force=true)
    rm(cachepath("partialhouse-gror$suffix.jld"), force=true)
end
