"""
Return the full path to a standard data file.
"""
function datapath(filename)
    dataset = get(config, "dataset", "counties")
    if !startswith(filename, "global") && !startswith(filename, "mapping")
        joinpath(dirname(@__FILE__), "../../data/$dataset/$filename")
    else
        joinpath(dirname(@__FILE__), "../../data/$filename")
    end
end

"""
Return the full path to a cache data file.
"""
function cachepath(filename)
    dataset = get(config, "dataset", "counties")
    joinpath(dirname(@__FILE__), "../../data/cache/$dataset/$filename")
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
    recorded = readtable(datapath(filepath))
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
        if isfile(datapath("$filename$suffix-$confighash.jld"))
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
        fp = open(datapath("$filename$suffix-$confighash.jld"), "w")
        serialize(fp, object)
        close(fp)
    else
        fp = open(datapath("$filename$suffix.jld"), "w")
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
    if typeof(indexes) <: DataVector{Int64} || typeof(indexes) <: Vector{Int64}
        return map(index -> lpad("$index", config["indexlen"], config["indexpad"]), indexes)
    end
    if typeof(indexes) <: DataVector{String}
        return map(index -> lpad(index, config["indexlen"], config["indexpad"]), indexes)
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
function getregionindices(fipses)
    map(fips -> findfirst(masterregions[:fips], fips), fipses)
end

lastindexcol = nothing

if Pkg.installed("NetCDF") != nothing
    include("datastore-netcdf.jl")
else
    include("datastore-nonetcdf.jl")
end
