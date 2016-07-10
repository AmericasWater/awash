using Base.Test

Pkg.add("Mimi")
Pkg.add("Graphs")
Pkg.add("NetCDF")
Pkg.add("DataArrays")
Pkg.add("OptiMimi")
Pkg.checkout("OptiMimi")

## Create a simple model and run it
using DataArrays
using DataFrames
using OptiMimi
include("../model.jl")

println("Running model...")
@time run(model)

