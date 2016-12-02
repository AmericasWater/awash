using NetCDF

"""
Download all the datasets that we will need
"""
function predownload()
    for name in keys(ncdatasets)
        filepath = cachepath(ncdatasets[name]["filename"] * ".nc")

        if !isfile(filepath)
            println("Downloading $name...")
            download(ncdatasets[name]["ncurl"], filepath)
        end
    end
end

"""
Get an array from a NetCDF file, downloading as needed
"""
function dncload(name::AbstractString, variable::AbstractString, dims::Vector{ASCIIString})
    filepath = cachepath(ncdatasets[name]["filename"] * ".nc")

    if !isfile(filepath)
        println("Downloading $name...")
        download(ncdatasets[name]["ncurl"], filepath)
    end

    ## TODO: check dims

    return ncread(filepath, variable)
end
