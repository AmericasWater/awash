using DataFrames
include("datastore.jl")

"""
Return a DataFrame containing `collection` and `colid` fields matching those in
the Water Network.

Any additional columns can be provided, to be used by other components.

Rows may be excluded, to represent that a given reservoir should be modeled as a
stream at the specified timestep (in months).
"""
function getreservoirs(config::Union{Dict{Any,Any},Dict{AbstractString,Any}})
    if in("netset", keys(config))
        netset = config["netset"]
    else
        warn("Config does not contain netset; assuming USA.")
        netset = "usa"
    end

    if netset == "three"
        DataFrame(collection="three", colid=2)
    else
        reservoirs = readtable(datapath("reservoirs/allreservoirs.csv"))
        if get(config, "filterstate", nothing) != nothing
            reservoirs = reservoirs[floor(reservoirs[:fips] / 1000) .== parse(Int64, config["filterstate"]), :]
        end

        reservoirs
    end
end
