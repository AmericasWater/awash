## Large Dataset library, using NetCDFs
#
# Handles large data files what need to be downloaded, which are done
# in NetCDF format for computers with that package.

using NetCDF

"""
Download all the datasets that we will need
"""
function predownload()
    for name in keys(config["ncdatasets"])
        filepath = cachepath(config["ncdatasets"][name]["filename"] * ".nc")

        if !isfile(filepath)
            println("Downloading $name...")
            download(config["ncdatasets"][name]["ncurl"], filepath)
        end
    end
end

"""
Get an array from a NetCDF file, downloading as needed
"""
function dncload(name::AbstractString, variable::AbstractString, dims::Vector{T}) where T <: AbstractString
    filepath = cachepath(config["ncdatasets"][name]["filename"] * ".nc")

    if !isfile(filepath)
        println("Downloading $name...")
        download(config["ncdatasets"][name]["ncurl"], filepath)
    end

    ## TODO: check dims

    return ncread(filepath, variable)
end
