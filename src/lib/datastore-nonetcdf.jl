using CSV
using DataFrames

"""
Download all the datasets that we will need
"""
function predownload()
    for name in keys(config["ncdatasets"])
        filepath = cachepath(config["ncdatasets"][name]["filename"] * ".csv")

        if !isfile(filepath)
            println("Downloading $name...")
            download(config["ncdatasets"][name]["csvurl"], filepath)
        end
    end
end

if !isdefined(:currentCSVFiles)
    # Store previously opened CSVs
    const currentCSVFiles = Dict{String, DataFrame}()
end

"""
Get an array from a CSV file, downloading as needed
"""
function dncload{T<:AbstractString}(name::AbstractString, variable::AbstractString, dims::Vector{T})
    filepath = cachepath(config["ncdatasets"][name]["filename"] * ".csv")

    if !isfile(filepath)
        println("Downloading $name...")
        download(config["ncdatasets"][name]["csvurl"], filepath)
    end

    if filepath in keys(currentCSVFiles)
        df = currentCSVFiles[filepath]
    else
        df = CSV.read(filepath, header=false)
        currentCSVFiles[filepath] = df
    end

    datacols = [false; !isnan.(vec(convert(DataMatrix{Float64}, df[1, 2:end])))] # assumes there's at least one coldim variable

    if length(dims) == 1 && dims[1] == config["ncdatasets"][name]["csvcoldim"]
        return vec(convert(DataMatrix{Float64}, df[df[1] .== variable, datacols]))
    elseif length(dims) == 1 && dims[1] != config["ncdatasets"][name]["csvcoldim"]
        error("NetCDF vectors that do not follow the column dimension are not saved.")
    elseif length(dims) == 2 && dims[2] == config["ncdatasets"][name]["csvcoldim"]
        return convert(DataMatrix{Float64}, df[df[1] .== variable, datacols])' # transpose it -- strange that it needs to be done here!
    elseif length(dims) == 2 && dims[1] == config["ncdatasets"][name]["csvcoldim"]
        return convert(DataMatrix{Float64}, df[df[1] .== variable, datacols])
    else
        error("Reading arrays with three dimensions from CSVs not implemented yet.")
    end
end
