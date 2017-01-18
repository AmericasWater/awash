include("convertlib.jl")

config = Dict{Symbol, Any}()
config[:source] = "counties"
config[:target] = "states"
config[:mastersourcefile] = "data/global/counties.csv"
config[:mastertargetfile] = "data/global/states.csv"
config[:mastersourceid] = :state
config[:mastertargetid] = :state
config[:header] = false

orderedconverttable("cost/drawdown0.txt", config, (column, values) -> mean(dropna(values)))

orderedconverttable("gwmodel/aquifer_depth.txt", config, (column, values) -> mean(dropna(values)))
orderedconverttable("gwmodel/vector_storativity.txt", config, (column, values) -> mean(dropna(values)))
orderedconverttable("gwmodel/county_area.txt", config, (column, values) -> sum(dropna(values)))
orderedconverttable("gwmodel/county_elevation.txt", config, (column, values) -> mean(dropna(values)))
orderedconverttable("gwmodel/piezohead0.txt", config, (column, values) -> mean(dropna(values)))

config[:separator] = ' '

sourceregions = readtable(joinpath(todata, config[:mastersourcefile]),
                          eltypes=[UTF8String, UTF8String, UTF8String])
targetregions = readtable(joinpath(todata, config[:mastertargetfile]),
                          eltypes=[UTF8String, UTF8String, UTF8String])

function translatechunk(region, subdf)
    if nrow(subdf) == 0
        return zeros(Float64, length(targetregions[config[:mastertargetid]]))
    end

    values = []
    for otherregion in targetregions[config[:mastertargetid]]
        if region == otherregion
            push!(values, 0.)
        elseif any(sourceregions[config[:mastersourceid]] .== otherregion)
            push!(values, sum(convert(Array, subdf[:, sourceregions[config[:mastersourceid]] .== otherregion])))
        else
            push!(values, 0.)
        end
    end

    values
end

chunkyorderedconverttable("gwmodel/matrix_leakage_factor.txt", config, translatechunk)

function translatechunk(region, subdf)
    if nrow(subdf) == 0
        return zeros(Int64, length(targetregions[config[:mastertargetid]]))
    end

    values = []
    for otherregion in targetregions[config[:mastertargetid]]
        if region == otherregion
            push!(values, 0)
        elseif any(sourceregions[config[:mastersourceid]] .== otherregion) && any(convert(Array, subdf[:, sourceregions[config[:mastersourceid]] .== otherregion]) .> 0)
            push!(values, 1)
        else
            push!(values, 0)
        end
    end

    values
end

chunkyorderedconverttable("gwmodel/connectivity_matrix.txt", config, translatechunk)

`Rscript convert-groundwater2.R`
