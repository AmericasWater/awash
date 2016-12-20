include("convertlib.jl")

config = Dict{Symbol, Any}()
config[:source] = "counties"
config[:target] = "states"
config[:mastersourcefile] = "data/global/counties.csv"
config[:mastertargetfile] = "data/global/states.csv"
config[:mastersourceid] = :state
config[:mastertargetid] = :state
config[:header] = false

orderedconverttable("gwmodel/aquifer_depth.txt", config, (column, values) -> mean(dropna(values)))
