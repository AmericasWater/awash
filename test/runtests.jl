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
requirepackage("Graphs")
requirepackage("NetCDF")
requirepackage("DataArrays")
requirepackage("OptiMimi")
Pkg.checkout("OptiMimi")
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
