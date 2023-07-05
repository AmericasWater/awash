using Test

include("../src/lib/datastore.jl")

countyareas = joinpath(dirname(@__FILE__), "../data/counties/agriculture/knownareas.csv")
stateareas = joinpath(dirname(@__FILE__), "../data/states/agriculture/knownareas.csv")

@test checkheader(countyareas, [Int64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
@test checkheader(countyareas, [String, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
@test !checkheader(stateareas, [Int64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
@test checkheader(stateareas, [String, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
