using Base.Test

function requirepackage(pkg, checkout=false)
    try
        Pkg.installed(pkg)
    catch
        Pkg.add(pkg)
        if checkout
            Pkg.checkout(pkg)
        end
    end
end

requirepackage("YAML")
requirepackage("Mimi")
requirepackage("Graphs")
requirepackage("NetCDF")
requirepackage("DataArrays")
requirepackage("OptiMimi", true)

## Create a simple model and run it
using DataArrays
using DataFrames
using OptiMimi
include("../src/model.jl")

println("Running model...")
@time run(model)

