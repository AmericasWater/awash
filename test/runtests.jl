using Test
using Pkg

function requirepackage(pkg, checkout=false; version=nothing)
    try
        gotvers = Pkg.installed(pkg)
        if gotvers == nothing
            error("Needs to be installed.")
        end
        if version != nothing && gotvers != version
            Pkg.pin(pkg, version)
        end
    catch
        if checkout
            Pkg.add(PackageSpec(name=pkg, rev="master"))
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
requirepackage("Mimi")
requirepackage("Graphs")
requirepackage("DataFrames")
requirepackage("NetCDF")
requirepackage("OptiMimi", true)
requirepackage("RData")
requirepackage("Clp")
requirepackage("NullableArrays")
requirepackage("NaNMath")

include("test_optimize_surface.jl")
include("test_simulate.jl")
include("test_Aquaculture.jl")
include("test_Reservoir_optimization.jl")
include("test_optimize_reservoir.jl")
include("test_caching.jl")
include("test_reservoirs.jl")
include("test_leapsteps.jl")
include("test_agsteps.jl")
