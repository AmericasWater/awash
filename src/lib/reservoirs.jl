## Reservoir data library
#
# Functions to handle reservoirs.

using DataFrames
using CSV
using GeoArrays
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
        @warn "Config does not contain dataset; assuming `counties`."
        dataset = "counties"
    end

    if dataset == "three"
        DataFrame(collection="three", colid=2)
    else
        try
            reservoirs = CSV.read(loadpath("reservoirs/allreservoirs.csv"), types=[String, String, Union{Float64, Missing}, Float64, Float64, Union{Float64, Missing}, Float64, String, Union{Float64, Missing}, Union{Float64, Missing}], missingstring="NA")
        catch
            reservoirs = CSV.read(loadpath("reservoirs/allreservoirs.csv"), types=[String, String, Union{Float64, Missing}, Float64, Float64, Union{Float64, Missing}, Float64, String], missingstring="\"NA\"")
        end
        if get(config, "filterstate", nothing) != nothing
            reservoirs = reservoirs[floor.(parse.(Int64, reservoirs[!, :fips]) / 1000) .== parse(Int64, config["filterstate"]), :]
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

"""
Estimate the volume evaporation loss
"""
function reservoirloss(evap::Float64, volume::Float64, maxcap::Float64; surfarea::Union{Float64, Missing}=missing, depth::Union{Float64, Missing}=missing)
    ## evap: kg/m^2/s
    ## volume: 1000 m^3
    ## maxcap: 1000 m^3
    ## surfarea: m^2
    ## depth: m

    if maxcap == 0 || volume == 0
        return 0
    end

    if surfarea === missing
        if depth === missing
            depth = (log(maxcap) - 10.250903) / 0.032408
            if depth < 0
                depth = 1
            end
        end

        surfarea = 3 * volume / depth
    end

    kgloss = evap * surfarea * (365.25 * 24 * 3600 / 12)
    m3loss = kgloss / 1000

    1 - max(0, volume - m3loss / 1000) / volume
end

function evaporation_matrix(volumes)
    reservoirs = getreservoirs(config)
    # Get the evaporation data
    evap = ncread(loadpath("global/evaporation-monthly.nc4"), "evap")
    gevap = GeoArray(evap[:, :, 1, :])
    bbox!(gevap, (min_x=-125.5, min_y=24.5, max_x=-65.5, max_y=50.5))
    epsg!(gevap, 4326)

    times = collect(parsemonth(config["startmonth"]):parsemonth(config["endmonth"]))

    weather = zeros(numreservoirs, length(times));
    for ii in 1:numreservoirs
        rc = indices(gevap, [reservoirs[ii, :lon], reservoirs[ii, :lat]])
        monthly = Float64[]
        for mm in 1:12
            ev = convert(Float64, gevap[rc[1], rc[2], mm])
            push!(monthly, reservoirloss(ev, volumes[ii], reservoirs[ii, :MAXCAP] / 1000; depth=reservoirs[ii, :height]))
        end
        monthly[monthly .=== missing] .= 0.01
        weather[ii, :] = monthly[(times .- 1) .% 12 .+ 1]
    end

    println(size(weather'))
    sum2timestep(weather'; dropstart=false) / config["timestep"]
end
