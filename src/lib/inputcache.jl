## File Caching library
#
# Provides a cache for files that only need to be loaded once.

if !(@isdefined inputvalues)
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

function knowndf(filenickname::AbstractString)
    if filenickname == "exogenous-withdrawals"
        try
            getfilevalue(loadpath("extraction/USGS-2010.csv"), "filtered",
                         () -> getfilteredtable("extraction/USGS-2010.csv", missingstring="NA")) # , types=[repeat([String], 5); Union{Missing, Int64}; repeat([Float64], 25)]
        catch
            getfilevalue(loadpath("extraction/USGS-2010.csv"), "filtered",
                         () -> getfilteredtable("extraction/USGS-2010.csv", types=[String; Union{Missing, Int64}; String; repeat([Float64], 30)], missingstring="NA"))
        end
    elseif filenickname == "agriculture-knownareas"
        filepath = loadpath("agriculture/knownareas.csv")
        getfilevalue(filepath, "filtered",
                     () -> checkheader(filepath, [Int64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64]) ? getfilteredtable("agriculture/knownareas.csv", :fips, types=[Int64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64]) : getfilteredtable("agriculture/knownareas.csv", :state, types=[String, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64]))
    elseif filenickname == "region-info"
        getfilevalue(loadpath("county-info.csv"), "*",
                     () -> configdescends(config, "counties") ? CSV.read(loadpath("county-info.csv"), types=[Int64, String, String, String, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}], missingstring="NA") : CSV.read(loadpath("county-info.csv")))
    elseif filenickname == "irrigation-bymonth"
            getfilevalue(loadpath("demand/agmonthshares.csv"), "filtered",
                         () -> getfilteredtable("demand/agmonthshares.csv", missingstring="NA"))
    else
        error("Unknown DataFrame $filenickname.")
    end
end
