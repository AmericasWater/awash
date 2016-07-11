using Base.Test

function requirepackage(pkg, checkout=false)
    try
        println("Checking $pkg")
        Pkg.installed(pkg)
        println("Installed.")
    catch
        println("Install $pkg")
        Pkg.add(pkg)
        if checkout
            Pkg.checkout(pkg)
        end
        println("Done.")
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

