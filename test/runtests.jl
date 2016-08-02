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

requirepackage("YAML")
requirepackage("Mimi", true)
requirepackage("Graphs")
requirepackage("NetCDF")
requirepackage("DataArrays")
requirepackage("OptiMimi", true)

## Create a simple model and run it
using DataArrays
using DataFrames
using OptiMimi

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml")

include("../src/model.jl")

println("Running model...")
@time run(model)

include("test_Aquaculture.jl")
include("test_Reservoir_optimization.jl")
include("test_caching.jl")
