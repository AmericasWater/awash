include("lib/readconfig.jl")
config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization
#config = readconfig("../configs/dummy3.yml")

include("optimization-given.jl")

house = optimization_given(false)
