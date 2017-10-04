include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/agriculture-ers.jl")

includeus = true

maxprofit = Dict{Int64, Vector{Any}}()

# NOTE: Using otherhay edds for cotton and rice
bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
edds_crops = ["Barley", "Maize", "Cotton", "Rice", "Soybeans", "Wheat"]
for ii in 1:length(bayes_crops)
    crop = bayes_crops[ii]
    println(crop)
    # Load degree day data
    gdds = readtable(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-gdd.csv")))
    kdds = readtable(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-kdd.csv")))

    price = ers_information(ers_crop(crop), "price", 2010; includeus=includeus)
    costs = ers_information(ers_crop(crop), "cost", 2010; includeus=includeus)

    bayespath = datapath("agriculture/bayesian/$(crop).csv")
    df = readtable(bayespath)
    for regionid in unique(regionindex(df, :, tostr=false))
        intercept = df[(df[:fips] .== regionid) & (df[:coef] .== "intercept"), :mean][1]
        gdds_coeff = df[(df[:fips] .== regionid) & (df[:coef] .== "gdds"), :mean][1]
        kdds_coeff = df[(df[:fips] .== regionid) & (df[:coef] .== "kdds"), :mean][1]
        time_coeff = df[(df[:fips] .== regionid) & (df[:coef] .== "time"), :mean][1]
        wreq_coeff = df[(df[:fips] .== regionid) & (df[:coef] .== "wreq"), :mean][1]

        weatherrow = findfirst(masterregions[:fips] .== canonicalindex(regionid))
        try
            gdds_row = convert(Matrix{Float64}, gdds[weatherrow, 2:end])
            kdds_row = convert(Matrix{Float64}, kdds[weatherrow, 2:end])
            time_row = 2010 # Give all yields as 2010; otherwise collect(1949:2009)
            price_row = price[weatherrow]
            costs_row = costs[weatherrow]

            yield_irrigated = mean(exp(intercept + gdds_coeff * gdds_row + kdds_coeff * kdds_row + time_coeff * time_row))

            profit = yield_irrigated * price_row - costs_row

            if profit > get(maxprofit, regionid, [-Inf])[1]
                maxprofit[regionid] = [profit, crop, yield_irrigated, price_row, costs_row]
            # else
            #     println(maxprofit[regionid])
            #     println([profit, crop, yield_irrigated, price_row, costs_row])
            end
        end
    end
end

result = DataFrame(fips=Int64[], profit=Float64[], crop=UTF8String[], yield=Float64[], price=Float64[], costs=Float64[])

for fips in keys(maxprofit)
    push!(result, [fips; maxprofit[fips]])
end

if includeus
    writetable("maxbayesian.csv", result)
else
    writetable("maxbayesian-erslimited.csv", result)
end

