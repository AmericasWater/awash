using DataArrays
using DataFrames
using OptiMimi

include("lib/readconfig.jl")

## First, find out how much streamflow is in normal result
config = readconfig("../configs/complete.yml")

include("world.jl")
include("weather.jl")

historical = sum(addeds, 1)

df = DataFrame(month=parsemonth(config["startmonth"]):parsemonth(config["endmonth"]), flows=vec(historical))

## Now the paleo result
config = readconfig("../configs/paleo.yml")

include("world.jl")
include("weather.jl")

paleo = sum(addeds, 1)

df2 = DataFrame(month=parsemonth("10/1450"):parsemonth("9/2005"), flows=vec(paleo))

df[:dataset] = "observed"
df2[:dataset] = "paleo"
writetable("../analyses/paleohist.csv", vcat(df, df2))

## As far as gotten

include("model.jl")

# Run it and time it!
println("Running model...")
@time run(model)
