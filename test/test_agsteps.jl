using Base.Test
using DataFrames

include("../src/lib/readconfig.jl")
config = readconfig("../configs/complete-yearly.yml")
config["filterstate"] = "08"

include("../src/model.jl")
run(model)
model_yearly = model

config = readconfig("../configs/complete.yml")
config["filterstate"] = "08"

include("../src/model.jl")
run(model)
model_monthly = model

@test size(model_yearly[:Agriculture, :allirrigation]) != size(model_monthly[:Agriculture, :allirrigation])
@test mean(model_yearly[:Agriculture, :allirrigation], 2) != mean(model_monthly[:Agriculture, :allirrigation], 2)

@test sum(model_yearly[:Agriculture, :allcropproduction] .== 0) / prod(size(model_yearly[:Agriculture, :allcropproduction])) < sum(model_monthly[:Agriculture, :allcropproduction] .== 0) / prod(size(model_monthly[:Agriculture, :allcropproduction]))
@test sum(model_yearly[:Agriculture, :allirrigation] .== 0) / prod(size(model_yearly[:Agriculture, :allcropproduction])) < sum(model_monthly[:Agriculture, :allcropproduction] .== 0) / prod(size(model_monthly[:Agriculture, :allcropproduction]))

@test sum(model_yearly[:Agriculture, :allcropareas], 3) / 61 ≈ sum(model_monthly[:Agriculture, :allcropareas], 3) / 735
@test sum(model_yearly[:Agriculture, :allcropproduction], 3) == sum(model_monthly[:Agriculture, :allcropproduction], 3)
@test sum(model_yearly[:Agriculture, :allirrigation], 2) ≈ sum(model_monthly[:Agriculture, :allirrigation][:, 1:end-3], 2)
@test mean(model_yearly[:Agriculture, :allagarea], 2) ≈ mean(model_monthly[:Agriculture, :allagarea], 2)
