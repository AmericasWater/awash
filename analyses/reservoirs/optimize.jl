using DataFrames, CSV

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

using Gurobi
solver = GurobiSolver()

burnyears = 2
saveyears = 1
postyears = 2

finaldf = DataFrame(startyear=Int64[], resid=String[], time=Int64[], storage=Float64[], storagemax=Float64[])
storage0 = nothing

for startyear in 1949:saveyears:(2010 - burnyears - saveyears - postyears)
    global finaldf, storage0

    config["startmonth"] = "10/$startyear"
    config["endmonth"] = "9/$(startyear + burnyears + saveyears + postyears)"
    config["startweather"] = 12 * (startyear - 1949) + 1

    rm("../../data/cache/counties/extraction/withdrawals.jld", force=true)
    include("../../src/optimization-given.jl")

    house = optimization_given(false, true, nocache=true, storage0=storage0)
    sol = houseoptimize(house, solver)
    dstorages = getconstraintsolution(house, sol, :storagemax)

    resids = ["$(reservoirdata[ii, :collection]).$(reservoirdata[ii, :colid])" for ii in 1:nrow(reservoirdata)]

    #sum(constraintoffset_reservoir_storagecapacitymin(house.model).f)
    #sum(constraintoffset_reservoir_storage0(house.model).f)

    if storage0 == nothing
        finaldf = vcat(finaldf, DataFrame(startyear=(startyear + burnyears) * ones(Int64, numreservoirs * saveyears * 12), resid=repeat(resids, outer=saveyears * 12), time=repeat(1:(saveyears * 12), inner=numreservoirs), storage=dstorages[(numreservoirs * burnyears * 12 + 1):(numreservoirs * (burnyears + saveyears) * 12)], storagemax=constraintoffset_reservoir_storagecapacitymax(house.model).f[(numreservoirs * burnyears * 12 + 1):(numreservoirs * (burnyears + saveyears) * 12)]))
        storage0 = dstorages[(numreservoirs * saveyears * 12 + 1):(numreservoirs * (saveyears * 12 + 1))]
    else
        finaldf = vcat(finaldf, DataFrame(startyear=(startyear + burnyears) * ones(Int64, numreservoirs * saveyears * 12), resid=repeat(resids, outer=saveyears * 12), time=repeat(1:(saveyears * 12), inner=numreservoirs), storage=repeat(storage0, outer=saveyears * 12) + dstorages[(numreservoirs * burnyears * 12 + 1):(numreservoirs * (burnyears + saveyears) * 12)], storagemax=constraintoffset_reservoir_storagecapacitymax(house.model).f[(numreservoirs * burnyears * 12 + 1):(numreservoirs * (burnyears + saveyears) * 12)]))
        storage0 = storage0 + dstorages[(numreservoirs * saveyears * 12 + 1):(numreservoirs * (saveyears * 12 + 1))]
    end

    CSV.write("storage.csv", finaldf)

    storage0[storage0 .< 0] .= 0 # numerical error
end
