using Base.Test

## Create a simple model and run it
using DataArrays
using DataFrames
using OptiMimi
include("model.jl")

println("Running model...")
@time run(model)

