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
df2 = DataFrame(regions=["global"], time=[2000], value=[sum(df2[:returned])], variable=[:returned])
df3available = vec(sum(model[:Market, :available], 2))
df3 = DataFrame(regions=repeat(masterregions[:state], outer=[2]), time=repeat([minimum(df1[:time]), maximum(df1[:time])], inner=[nrow(masterregions)]), value=df3available, variable=:available)

alldf = vcat(df1, df2, df3)

outputpath = joinpath(dirname(@__FILE__), "../results/simulate-test.csv")
if isfile(outputpath)
    compdf = readtable(outputpath)
    @test nrow(compdf) == nrow(alldf)
    for ii in 1:nrow(alldf)
        @test compdf[ii, :regions] == string(alldf[ii, :regions])
        @test compdf[ii, :time] == alldf[ii, :time]
        @test compdf[ii, :variable] == string(alldf[ii, :variable])
        @test compdf[ii, :value] == alldf[ii, :value]
    end
else
    writetable(outputpath, alldf)
end
