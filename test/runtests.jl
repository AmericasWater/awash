using Base.Test

function requirepackage(pkg, checkout=false)
    try
        version = Pkg.installed(pkg)
        if version == nothing
            error("Needs to be installed.")
        end
    catch
        Pkg.add(pkg)
        if checkout
            Pkg.checkout(pkg)
        end
    end
end

requirepackage("CSV")
requirepackage("YAML")
requirepackage("Mimi")
Pkg.checkout("Mimi")
requirepackage("Graphs")
requirepackage("NetCDF")
requirepackage("DataArrays")
requirepackage("OptiMimi")
Pkg.checkout("OptiMimi")
requirepackage("RData")
requirepackage("Clp")

include("test_optimize_surface.jl")
include("test_simulate.jl")
include("test_Aquaculture.jl")
include("test_Reservoir_optimization.jl")
include("test_caching.jl")
include("test_reservoirs.jl")
