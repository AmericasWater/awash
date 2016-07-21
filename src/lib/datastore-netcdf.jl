using NetCDF

"""
Get an array from a NetCDF file, downloading as needed
"""
function dncload(name::AbstractString, variable::AbstractString, dims::Vector{ASCIIString})
    filepath = datapath("cache/" * ncdatasets[name]["filename"] * ".nc")

    if !isfile(filepath)
        println("Downloading $name...")
        download(ncdatasets[name]["ncurl"], filepath)
    end

    ## TODO: check dims

    return ncread(filepath, variable)
end
