using Test
using Pkg

versions = Pkg.installed()

function requirepackage(pkg, checkout=false; version=nothing)
    try
        gotvers = get(versions, pkg, nothing)
        if gotvers == nothing
            error("Needs to be installed.")
        end
        if version != nothing && gotvers != version
            Pkg.pin(pkg, version)
        end
    catch
        if checkout == true
            Pkg.add(PackageSpec(name=pkg, rev="master"))
        elseif typeof(checkout) <: String
            Pkg.add(PackageSpec(name=pkg, rev=checkout))
        else
            Pkg.add(pkg)
        end
        if version != nothing
            Pkg.pin(pkg, version)
        end
    end
end

requirepackage("CSV")
requirepackage("YAML")
#requirepackage("Mimi", "time")
requirepackage("Graphs")
requirepackage("DataFrames")
requirepackage("NetCDF")
requirepackage("OptiMimi")
requirepackage("RData")
requirepackage("Clp")
requirepackage("NaNMath")

include("thetests.jl")
