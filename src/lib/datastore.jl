## Data Management library
#
# Functions for accessing external data.

using NullableArrays
using DataArrays

include("inputcache.jl")

"""
Return the full path to a standard data file.
"""
function datapath(filename, dataset=nothing)
    if dataset == nothing
        dataset = get(config, "dataset", "counties")
    end
    if !startswith(filename, "global") && !startswith(filename, "mapping")
        joinpath(dirname(@__FILE__), "../../data/$dataset/$filename")
    else
        joinpath(dirname(@__FILE__), "../../data/$filename")
    end
end

"""
Return the full path to a file for reading, using dataset logic.
"""
function loadpath(filename)
    fullpath = datapath(filename)
    if isfile(fullpath)
        return fullpath
    end

    if "extdatasets" in keys(config)
        if filename in keys(config["extdatasets"])
            if !isdir(dirname(fullpath))
                mkpath(dirname(fullpath))
            end
            download(config["extdatasets"][filename]["url"], fullpath)
            return fullpath
        end
    end

    if "parent-dataset" in keys(config)
        return datapath(filename, config["parent-dataset"]) # NOTE: This won't recurse fully yet
    end

    return fullpath # posit the filepath anyway
end

"""
Return the full path to a cache data file.
"""
function cachepath(filename)
    dataset = get(config, "dataset", "counties")
    cachedir = joinpath(dirname(@__FILE__), "../../data/cache/$dataset")
    if !isdir(cachedir)
        mkdir(cachedir)
    end
    joinpath(cachedir, filename)
end

"""
Return the normal data suffix
"""
function getsuffix()
    suffix = (get(config, "filterstate", nothing) != nothing ? "-$(config["filterstate"])" : "")
    if config["dataset"] == "dummy"
        suffix = "-dummy";
    elseif config["dataset"] == "three"
        suffix = "-three";
    end

    suffix
end

"""
Retrieve only the part of a file within filterstate, if one is set.
"""
function getfilteredtable(filepath, fipscol=:FIPS)
    if filepath[1] != '/'
        filepath = loadpath(filepath)
    end
    recorded = readtable(filepath)
    if get(config, "filterstate", nothing) != nothing
        recorded = recorded[find(floor(recorded[fipscol]/1e3) .== parse(Int64,config["filterstate"])), :]
    end
    recorded
end

"""
Either get data from a cached source, or produce it by a fallback generation
Does not save fallback generation: for saving, use cache_store
"""
function cached_fallback(filename, generate)
    suffix = getsuffix()
    confighash = hash(config) # make specific to configs
    try
        if isfile(cachepath("$filename$suffix-$confighash.jld"))
            return deserialize(open(cachepath("$filename$suffix-$confighash.jld")))
        elseif isfile(cachepath("$filename$suffix.jld"))
            return deserialize(open(cachepath("$filename$suffix.jld")))
        elseif isfile(datapath("$filename$suffix-$confighash.jld"))
            return deserialize(open(datapath("$filename$suffix-$confighash.jld")))
        elseif isfile(datapath("$filename$suffix.jld"))
            return deserialize(open(datapath("$filename$suffix.jld")))
        end
    end

    generate()
end

"""
Save data to later be restored using cached_fallback or deserialize
"""
function cached_store(filename, object, usehash=true)
    suffix = getsuffix()
    if usehash
        confighash = hash(config) # make specific to configs
        fp = open(cachepath("$filename$suffix-$confighash.jld"), "w")
        serialize(fp, object)
        close(fp)
    else
        fp = open(cachepath("$filename$suffix.jld"), "w")
        serialize(fp, object)
        close(fp)
    end
end

"""
Remove all jld files for this configuration
"""
function cache_clear()
    for filename in readdir(cachepath(""))
        if contains(filename, ".jld")
            println(filename)
            rm(cachepath(filename))
        end
    end
end

"""
Get the region index for one or more rows
"""
function regionindex(tbl, rows; tostr=true)
    global lastindexcol

    # Allow any of the column names
    indexes = nothing
    for indexcol in config["indexcols"]
        if indexcol in names(tbl)
            indexes = tbl[rows, indexcol]
            lastindexcol = indexcol
            break
        end
    end

    if indexes == nothing
        error("Could not find any index column in table.")
    end

    if !tostr
        return indexes
    end

    return canonicalindex(indexes)
end

"""Represent the values in an index in a standardized way."""
function canonicalindex(indexes)
    if typeof(indexes) <: DataVector{Int64} || typeof(indexes) <: Vector{Int64} || typeof(indexes) <: DataVector{Int32} || typeof(indexes) <: Vector{Union{Missings.Missing, Int64}}
        return map(index -> lpad("$index", config["indexlen"], config["indexpad"]), indexes)
    end
    if typeof(indexes) <: NullableArrays.NullableArray{Int64, 1}
        return convert(Vector{String}, map(index -> lpad("$index", config["indexlen"], config["indexpad"]), indexes))
    end
    if typeof(indexes) <: Vector{String} || typeof(indexes) <: DataVector{String} || typeof(indexes) <: Vector{Union{Missings.Missing, String}}
        return map(index -> lpad(index, config["indexlen"], config["indexpad"]), indexes)
    end
    if typeof(indexes) <: NullableArrays.NullableArray{String, 1}
        return convert(Vector{String}, map(index -> lpad(index, config["indexlen"], config["indexpad"]), indexes))
    end
    if typeof(indexes) <: Integer
        return lpad("$indexes", config["indexlen"], config["indexpad"])
    end
    if typeof(indexes) <: String
        return lpad(indexes, config["indexlen"], config["indexpad"])
    end

    error("Unknown index column type $(typeof(indexes))")
end

"""Return the index for each region key."""
function getregionindices(fipses, tomaster=true)
    if typeof(fipses) <: Vector{Int64} || typeof(fipses) <: DataVector{Int64} || typeof(fipses) <: Vector{Union{Int64, Missing}}
        masterfips = map(x -> parse(Int64, x), masterregions[:fips])
    else
        masterfips = masterregions[:fips]
    end

    if tomaster
        convert(Vector{Int64}, map(fips -> findfirst(masterfips, fips), fipses))
    else
        println(typeof(masterfips))
        println(typeof(fipses))
        convert(Vector{Int64}, map(fips -> findfirst(fipses, fips), masterfips))
    end
end

"""Load a known, named input from its file."""
function knownvariable(collection::AbstractString, name::AbstractString)
    dataset = get(config, "dataset", "counties")

    if collection == "runoff"
        if name in ["gage_latitude", "gage_longitude", "contributing_area"]
            if dataset == "paleo"
                if name == "contributing_area"
                    df = cachereadtable(loadpath("waternet/allarea.csv"))
                    replacemissing(df, :area, 0.)
                else
                    waternetdata = cachereadrda(loadpath("waternet/waternet.RData"))
                    mapping = Dict("gage_latitude" => "lat", "gage_longitude" => "lon")
                    waternetdata["network"][:, Symbol(mapping[name])]
                end
            else
                dncload("runoff", name, ["gage"])
            end
        elseif name == "totalflow"
            if dataset == "paleo"
                ds = cachereadrda(loadpath("waternet/runoff.RData"))
                addeds = convert(Matrix{Float64}, ds["DISAGG"][:, 3:end])'

                ## Inpute the added water for all junctions
                waternetdata = cachereadrda(loadpath("waternet/waternet.RData"))
                stations = waternetdata["stations"]
                stations[:gageid] = ["$(stations[ii, :collection]).$(stations[ii, :colid])" for ii in 1:nrow(stations)]
                network = waternetdata["network"]
                network[:gageid] = ["$(network[ii, :collection]).$(network[ii, :colid])" for ii in 1:nrow(network)]

                contribs = cachereadtable(loadpath("waternet/contribs.csv"), types=[String, String, Float64], null="NA")
                contribs = dropmissing(contribs, :sink)

                addeds = vcat(addeds, zeros(nrow(network) - nrow(stations), size(addeds)[2]))

                for gageid in gaugeorder
                    gageii = findfirst(network[:, :gageid] .== gageid)
                    if gageii <= nrow(stations)
                        continue # Already done
                    end

                    controws = contribs[contribs[:sink] .== gageid, :]

                    sumadded = zeros(size(addeds)[2])
                    numadded = 0

                    for jj in 1:nrow(controws)
                        if isna(controws[jj, :factor])
                            continue
                        end
                        gagejj = findfirst(controws[jj, :source] .== network[:gageid])
                        sumadded += addeds[gagejj, :] * controws[jj, :factor]
                        numadded += 1
                    end

                    if numadded == 0
                        continue
                    end

                    if any(isna.(sumadded))
                        println(controws)
                    end

                    addeds[gageii, :] = sumadded' / numadded
                end

                addeds
            else
                dncload("runoff", name, ["month", "gage"])
            end
        elseif name == "month"
            if dataset == "paleo"
                ds = cachereadrda(loadpath("waternet/runoff.RData"))
                map(x -> parse(Float64, x), ds["DISAGG"][:, 1]) + (ds["DISAGG"][:, 2] - .5) / 12
            else
                dncload("runoff", name, ["month"])
            end
        else
            error("Unknown input $collection:$name.")
        end
    else
        error("Unknown input $collection:$name.")
    end
end

"""
Reorder values to match the master region indexes.
Value is NA if a given region isn't in fipses.
"""
function dataonmaster(fipses, values)
    if typeof(fipses) <: Vector{Int64} || typeof(fipses) <: DataVector{Int64}
        masterfips = map(x -> parse(Int64, x), masterregions[:fips])
    else
        masterfips = masterregions[:fips]
    end

    function valueonmaster(fips)
        index = findfirst(fipses, fips)
        if index == 0
            NA
        else
            values[index]
        end
    end

    map(valueonmaster, masterfips)
end

lastindexcol = nothing

if Pkg.installed("NetCDF") != nothing
    include("datastore-netcdf.jl")
else
    include("datastore-nonetcdf.jl")
end
