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
Get the region index for one or more rows
"""
function regionindex(tbl, rows)
    # Allow any of the column names
    indexes = nothing
    for indexcol in config["indexcols"]
        if indexcol in names(tbl)
            indexes = tbl[rows, indexcol]
            break
        end
    end

    if indexes == nothing
        throw(DomainError("Could not find any index column in table."))
    end

    if typeof(indexes) <: DataVector{Int64}
        return map(index -> lpad("$index", config["indexlen"], config["indexpad"]), indexes)
    end
    if typeof(indexes) <: DataVector{UTF8String}
        return map(index -> lpad(index, config["indexlen"], config["indexpad"]), indexes)
    end
    if typeof(indexes) <: Int64
        return lpad("$indexes", config["indexlen"], config["indexpad"])
    end
    if typeof(indexes) <: UTF8String
        return lpad(indexes, config["indexlen"], config["indexpad"])
    end

    throw(DomainError("Unknown index column type $(typeof(indexes))"))
end

if Pkg.installed("NetCDF") != nothing
    include("datastore-netcdf.jl")
else
    include("datastore-nonetcdf.jl")
end
