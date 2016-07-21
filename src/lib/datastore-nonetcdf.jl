using DataFrames

if !isdefined(:currentCSVFiles)
    """
    Store previously opened CSVs
    """
    const currentCSVFiles = Dict{ASCIIString, DataFrame}()
end

"""
Get an array from a CSV file, downloading as needed
"""
function dncload(name::AbstractString, variable::AbstractString, dims::Vector{ASCIIString})
    filepath = datapath("cache/" * ncdatasets[name]["filename"] * ".csv")

    if !isfile(filepath)
        println("Downloading $name...")
        download(ncdatasets[name]["csvurl"], filepath)
    end

    if filepath in keys(currentCSVFiles)
        df = currentCSVFiles[filepath]
    else
        df = readtable(filepath, header=false)
        currentCSVFiles[filepath] = df
    end

    datacols = [false; !isnan(vec(convert(DataMatrix{Float64}, df[1, 2:end])))] # assumes there's at least one coldim variable

    if length(dims) == 1 && dims[1] == ncdatasets[name]["csvcoldim"]
        return vec(convert(DataMatrix{Float64}, df[df[1] .== variable, datacols]))
    elseif length(dims) == 1 && dims[1] != ncdatasets[name]["csvcoldim"]
        error("NetCDF vectors that do not follow the column dimension are not saved.")
    elseif length(dims) == 2 && dims[2] == ncdatasets[name]["csvcoldim"]
        return convert(DataMatrix{Float64}, df[df[1] .== variable, datacols])' # transpose it -- strange that it needs to be done here!
    elseif length(dims) == 2 && dims[1] == ncdatasets[name]["csvcoldim"]
        return convert(DataMatrix{Float64}, df[df[1] .== variable, datacols])
    else
        error("Reading arrays with three dimensions from CSVs not implemented yet.")
    end
end
