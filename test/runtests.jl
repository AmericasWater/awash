using Base.Test
using Dates

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
        Pkg.add(pkg)
        if checkout
            Pkg.checkout(pkg)
        end
        if version != nothing
            Pkg.pin(pkg, version)
        end
    end
end

requirepackage("CSV")
requirepackage("YAML")
requirepackage("Mimi", version=v"0.4.0")
requirepackage("Graphs")
requirepackage("NetCDF")
requirepackage("DataArrays")
requirepackage("OptiMimi", true)
requirepackage("RData")
requirepackage("Clp")
requirepackage("NullableArrays")
requirepackage("NaNMath")

println("test_optimize_surface.jl: $(Dates.now())")
include("test_optimize_surface.jl")
println("test_simulate.jl: $(Dates.now())")
include("test_simulate.jl")
println("test_Aquaculture.jl: $(Dates.now())")
include("test_Aquaculture.jl")
println("test_Reservoir_optimization.jl: $(Dates.now())")
include("test_Reservoir_optimization.jl")
println("test_optimize_reservoir.jl: $(Dates.now())")
include("test_optimize_reservoir.jl")
println("test_caching.jl: $(Dates.now())")
include("test_caching.jl")
println("test_reservoirs.jl: $(Dates.now())")
include("test_reservoirs.jl")
println("test_leapsteps.jl: $(Dates.now())")
include("test_leapsteps.jl")
println("test_agsteps.jl: $(Dates.now())")
include("test_agsteps.jl")
