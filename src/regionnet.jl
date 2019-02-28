## Construct Region Network
#
# Setup the network between regions, used for transportation.

using Mimi
using Graphs
using Serialization

# Region Network definitions

include("lib/inputcache.jl")

if !(@isdefined RegionNetwork)
    RegionNetwork{R, E} = IncidenceList{R, E}
end
SimpleRegionNetwork = RegionNetwork{ExVertex, ExEdge}
MyNumeric = Float64 #Number

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

if isfile(cachepath("regionsources$suffix.jld"))
    println("Loading from saved region network...")

    regionnet = deserialize(open(cachepath("regionnet$suffix.jld"), "r")); # The network
    regverts = deserialize(open(cachepath("regionvertices$suffix.jld"), "r")); # Mapping from indexcol to vertex
    sourceiis = deserialize(open(cachepath("regionsources$suffix.jld"), "r")); # Neighbor indexes from region index
else
    println("Trying to create a new region network...")

    # Load the network of counties
    counties = knowndf("region-info")
    edges = Dict{String, Vector{String}}()

    for row in 1:size(counties, 1)
        neighboring = counties[row, :Neighboring]
        if !ismissing.(neighboring)
            chunks = String[neighboring[start:start+config["indexlen"]-1] for start in 1:config["indexlen"]:length(neighboring)]
            index = regionindex(counties, row)

            # Only include if part of filter; only designed for counties dataset
            if get(config, "filterstate", nothing) != nothing
                if index[1:2] == get(config, "filterstate", nothing)
                    edges[index] = filter(ff -> ff[1:2] == get(config, "filterstate", nothing), chunks)
                end
            else
                edges[index] = chunks
            end
        end
    end

    # Construct the network

    regverts = Dict{String, ExVertex}()
    regionnames = []
    sourceiis = Dict{Int64, Vector{Int64}}()
    regionnet = empty_regnetwork()

    for index in keys(edges)
        regverts[index] = ExVertex(length(regionnames)+1, index)
        push!(regionnames, index)
        add_vertex!(regionnet, regverts[index])
    end

    for index in keys(edges)
        neighbors = edges[index]
        for neighbor in neighbors
            if !(neighbor in regionnames)
                # Retroactive add
                regverts[neighbor] = ExVertex(length(regionnames)+1, neighbor)
                push!(regionnames, neighbor)
                add_vertex!(regionnet, regverts[neighbor])
            end
            add_edge!(regionnet, regverts[index], regverts[neighbor])
        end
        sourceiis[indexin([index], regionindex(masterregions, :))[1]] = indexin(neighbors, regionindex(masterregions, :))
    end

    serialize(open(cachepath("regionnet$suffix.jld"), "w"), regionnet)
    serialize(open(cachepath("regionvertices$suffix.jld"), "w"), regverts)
    serialize(open(cachepath("regionsources$suffix.jld"), "w"), sourceiis)
end
