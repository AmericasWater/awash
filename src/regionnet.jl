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

if isfile(joinpath(todata, "regionsources$suffix.jld"))
    println("Loading from saved region network...")

    regionnet = deserialize(open(joinpath(todata, "regionnet$suffix.jld"), "r"));
    names = deserialize(open(joinpath(todata, "regionnames$suffix.jld"), "r"));
    regverts = deserialize(open(joinpath(todata, "regionvertices$suffix.jld"), "r"));
    sourceiis = deserialize(open(joinpath(todata, "regionsources$suffix.jld"), "r"));
else
    println("Trying to create a new region network...")

    # Load the network of counties
    counties = readtable("../data/county-info.csv", eltypes=[UTF8String, UTF8String, UTF8String, UTF8String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])

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
            if filterstate != nothing
                if fips[1:2] == filterstate
                    edges[fips] = filter(ff -> ff[1:2] == filterstate, chunks)
                end
            else
                edges[fips] = chunks
            end
        end
    end

    # Construct the network

    regverts = Dict{UTF8String, ExVertex}()
    names = []
    sourceiis = Dict{Int64, Vector{Int64}}()
    regionnet = empty_regnetwork()

    for fips in keys(edges)
        regverts[fips] = ExVertex(length(names)+1, fips)
        push!(names, fips)
        add_vertex!(regionnet, regverts[fips])
    end

    for (fips, neighbors) in edges
        for neighbor in neighbors
            if !(neighbor in names)
                # Retroactive add
                regverts[neighbor] = ExVertex(length(names)+1, neighbor)
                push!(names, neighbor)
                add_vertex!(regionnet, regverts[neighbor])
            end
            add_edge!(regionnet, regverts[fips], regverts[neighbor])
        end
        sourceiis[indexin([fips], names)[1]] = indexin(neighbors, names)
    end

    serialize(open(joinpath(todata, "regionnet$suffix.jld"), "w"), regionnet)
    serialize(open(joinpath(todata, "regionnames$suffix.jld"), "w"), names)
    serialize(open(joinpath(todata, "regionvertices$suffix.jld"), "w"), regverts)
    serialize(open(joinpath(todata, "regionsources$suffix.jld"), "w"), sourceiis)
end
