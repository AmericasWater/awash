using Base.Test

## Create a simple model and run it
using DataArrays
using DataFrames
using OptiMimi

include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard-1year-state.yml")

include("../src/model.jl")

println("Running model...")
@time run(model)

df1 = getdataframe(model, :Agriculture, :allirrigation)
rename!(df1, :allirrigation, :value)
df1[:variable] = :allirrigation
df2 = getdataframe(model, :ReturnFlows, :returned)
rename!(df2, :gauges, :regions)
rename!(df2, :returned, :value)
df2[:variable] = :returned
df3available = vec(sum(model[:Market, :available], 2))
df3 = DataFrame(regions=repeat(masterregions[:state], outer=[2]), time=repeat([minimum(df1[:time]), maximum(df1[:time])], inner=[nrow(masterregions)]), value=df3available, variable=:available)

alldf = vcat(df1, df2, df3)
writetable("../results/simulate-test.csv", alldf)
