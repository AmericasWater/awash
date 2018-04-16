## File Caching library
#
# Provides a cache for files that only need to be loaded once.

if !isdefined(:inputvalues)
    # Store previously opened CSVs
    const inputvalues = Dict{String, Any}()
end

"""
Get a value which can be cached as a direct result of a file.
"""
function getfilevalue(fullpath::AbstractString, name::AbstractString, process::Function)
    key = "$fullpath:$name"
    if !(key in keys(inputvalues))
        inputvalues[key] = process()
    end

    inputvalues[key]
end

function cachereadtable(fullpath::AbstractString; kwargs...)
    getfilevalue(fullpath, "*", () -> readtable(fullpath; kwargs...))
end

function cachereadrda(fullpath::AbstractString)
    getfilevalue(fullpath, "*", () -> FileIO.load(fullpath))
end

function clearfilecache()
    empty!(inputvalues)
end
