"""
Return the full path to a standard data file.
"""
function datapath(filename)
    joinpath(dirname(@__FILE__), "../../data/$filename")
end

"""
Either get data from a cached source, or produce it by a fallback generation
Does not save fallback generation: for saving, use ...
"""
function cached_fallback(filename, generate)
    confighash = hash(config) # make specific to configs
    if isfile(datapath("$filename$suffix-$confighash.jld"))
        deserialize(open(datapath("$filename$suffix-$confighash.jld")))
    else
        generate()
    end
end

"""
Dataset descriptions used by ncload.
Dictionary specifies the local filename, excluding the extension, the NetCDF link, the CSV link, and the column dimension.
"""
ncdatasets = Dict{ASCIIString, Dict{ASCIIString, ASCIIString}}("weather" => Dict{ASCIIString, ASCIIString}("filename" => "VIC_WB", "ncurl" => "https://www.dropbox.com/s/j7fi1kgw461icwa/VIC_WB.nc?dl=0", "csvurl" => "https://www.dropbox.com/s/rhuvdi7iu5wa3tl/VIC_WB.csv?dl=0", "csvcoldim" => "county", "nccrc32" => 0x468f7994, "csvcrc" => 0xcefed8fe),
                                                               "runoff" => Dict{ASCIIString, ASCIIString}("filename" => "contributing_runoff_by_gage", "ncurl" => "https://www.dropbox.com/s/itw2dzdv0051acw/contributing_runoff_by_gage.nc?dl=0", "csvurl" => "https://www.dropbox.com/s/fq8vrh4lgoewi40/contributing_runoff_by_gage.csv?dl=0", "csvcoldim" => "gage", "nccrc32" => 0x78f4dc8d, "csvcrc32" => 0x78f4dc8d))
# CRC from julia -e "using CRC; main(ARGS)" (uses CRC_32)
# Currently CRCs are ignored

if Pkg.installed("NetCDF") != nothing
    include("datastore-netcdf.jl")
else
    include("datastore-nonetcdf.jl")
end
