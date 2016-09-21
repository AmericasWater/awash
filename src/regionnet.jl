using Mimi

# Region Network definitions

using Graphs

typealias RegionNetwork{R, E} IncidenceList{R, E}
typealias SimpleRegionNetwork RegionNetwork{ExVertex, ExEdge}
typealias MyNumeric Float64 #Number

function asmynumeric(array, dims=1)
    if MyNumeric == Float64
        return array
    else
        return convert(Array{MyNumeric, dims}, array)
    end
end

# Region network has OUT nodes to potential sources for IMPORT

empty_regnetwork() = SimpleRegionNetwork(true, ExVertex[], 0, Vector{Vector{ExEdge}}())

using DataFrames

todata = relpath(joinpath(dirname(@__FILE__), "../data"))

if isfile(joinpath(todata, "cache/regionsources$suffix.jld"))
    println("Loading from saved region network...")

    regionnet = deserialize(open(joinpath(todata, "cache/regionnet$suffix.jld"), "r")); # The network
    regverts = deserialize(open(joinpath(todata, "cache/regionvertices$suffix.jld"), "r")); # Mapping from FIPS to vertex
    sourceiis = deserialize(open(joinpath(todata, "cache/regionsources$suffix.jld"), "r")); # Neighbor indexes from region index
else
    println("Trying to create a new region network...")

    # Load the network of counties
    if config["netset"] == "usa"
    counties = readtable(joinpath(todata, "county-info.csv"), eltypes=[UTF8String, UTF8String, UTF8String, UTF8String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
    else
    counties = readtable(joinpath(todata, "county-info$suffix.csv"), eltypes=[UTF8String,     UTF8String, UTF8String, UTF8String, Float64, Float64, Float64, Float64, Float64,       Float64, Float64])
    end
    edges = Dict{UTF8String, Vector{UTF8String}}()

    for row in 1:size(counties, 1)
        neighboring = counties[row, :Neighboring]
        if !isna(neighboring)
            chunks = UTF8String[neighboring[start:start+4] for start in 1:5:length(neighboring)]
            fips = counties[row, :FIPS]
            if length(fips) == 4
                fips = "0" * fips
            end

            # Only include if part of filter
            if get(config, "filterstate", nothing) != nothing
                if fips[1:2] == get(config, "filterstate", nothing)
                    edges[fips] = filter(ff -> ff[1:2] == get(config, "filterstate", nothing), chunks)
                end
            else
                edges[fips] = chunks
            end
        end
    end

    # Construct the network

    regverts = Dict{UTF8String, ExVertex}()
    regionnames = []
    sourceiis = Dict{Int64, Vector{Int64}}()
    regionnet = empty_regnetwork()

    for fips in keys(edges)
        regverts[fips] = ExVertex(length(regionnames)+1, fips)
        push!(regionnames, fips)
        add_vertex!(regionnet, regverts[fips])
    end

    for fips in keys(edges)
        neighbors = edges[fips]
        for neighbor in neighbors
            if !(neighbor in regionnames)
                # Retroactive add
                regverts[neighbor] = ExVertex(length(regionnames)+1, neighbor)
                push!(regionnames, neighbor)
                add_vertex!(regionnet, regverts[neighbor])
            end
            add_edge!(regionnet, regverts[fips], regverts[neighbor])
        end
        sourceiis[indexin([fips], mastercounties[:fips])[1]] = indexin(neighbors, mastercounties[:fips])
    end

    serialize(open(joinpath(todata, "cache/regionnet$suffix.jld"), "w"), regionnet)
    serialize(open(joinpath(todata, "cache/regionvertices$suffix.jld"), "w"), regverts)
    serialize(open(joinpath(todata, "cache/regionsources$suffix.jld"), "w"), sourceiis)
end
