## Reservoir data library
#
# Functions to handle reservoirs.

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
    if in("dataset", keys(config))
        dataset = config["dataset"]
    else
        warn("Config does not contain dataset; assuming `counties`.")
        dataset = "counties"
    end

    if dataset == "three"
        DataFrame(collection="three", colid=2)
    else
        reservoirs = readtable(loadpath("reservoirs/allreservoirs.csv"), eltypes=[String, String, Float64, Float64, Float64, Float64, Float64])
        if get(config, "filterstate", nothing) != nothing
            reservoirs = reservoirs[floor(reservoirs[:fips] / 1000) .== parse(Int64, config["filterstate"]), :]
        end

        reservoirs
    end
end

"""
Calculate the estimated cost of construction of a reservoir of this capacity
"""
function estimatecost(capacity)
    capacityaf = capacity * 1000 / 1233.48 # Convert to acre-ft
    if log(capacityaf) < 10
        capacityaf = exp(10)
    end

    exp.(0.7 + 0.9 * log((log(capacityaf) - 9.5) / 0.01)) * 1e6 # dollars
end

"""
Marginal cost of increasing capacity, at the given capacity
"""
function marginalcost(capacity)
    capacityaf = capacity * 1000 / 1233.48 # Convert to acre-ft
    if log(capacityaf) < 10
        capacityaf = exp(10)
    end

    estimatecost(capacity) * 0.9 * ((1 / capacityaf) / (log(capacityaf) - 9.5)) # Convert back to 1000 m^3, in dollars
end

