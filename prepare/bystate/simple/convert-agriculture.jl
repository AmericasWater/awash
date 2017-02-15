include("convertlib.jl")

## Master data
config = Dict{Symbol, Any}()
config[:source] = "counties"
config[:sourceid] = :FIPS
config[:target] = "states"
config[:targetid] = :ST
config[:masterfile] = "data/global/counties.csv"
config[:mastersourceid] = :fips
config[:mastertargetid] = :state
config[:forcematching] = false

function translate(column, values)
    if in(column, [:FIPS, :FID, :County, :Total_Agriculture_Demand])
        nothing
    elseif column == :State
        values[1]
    else
        if typeof(values[1]) <: AbstractString
            values = map(x -> ismatch(r"^[-+]?[0-9]*\.?[0-9]+$", x) ? parse(Float64, x) : 0, values)
        end
        sum(values)
    end
end

converttable("agriculture/allyears/Master_Spreadsheet_All.csv", config, translate)

## Model coefficients
config = Dict{Symbol, Any}()
config[:source] = "counties"
config[:sourceid] = :fips
config[:target] = "states"
config[:targetid] = :state
config[:masterfile] = "data/global/counties.csv"
config[:mastersourceid] = :fips
config[:mastertargetid] = :state

function translatechunk(subdf)
    subresult = DataFrame(coef=UTF8String[], mean=Float64[], serr=Float64[])

    for coef in unique(subdf[:coef])
        means = subdf[subdf[:coef] .== coef, :mean]
        serrs = subdf[subdf[:coef] .== coef, :serr]
        invvars = 1 ./ (serrs.^2)

        poolmean = sum(means .* invvars) / sum(invvars)
        poolserr = 1 ./ sum(invvars)

        push!(subresult, [coef, poolmean, poolserr])
    end

    subresult
end

for filename in readdir("../../../data/counties/agriculture/bayesian")
    chunkyconverttable("agriculture/bayesian/$filename", config, translatechunk)
end

for filename in readdir("../../../data/counties/agriculture")
    if startswith(filename, "unpooled-")
        chunkyconverttable("agriculture/$filename", config, translatechunk)
    end
end

## Other county-specific data
config = Dict{Symbol, Any}()
config[:source] = "counties"
config[:target] = "states"
config[:mastersourcefile] = "data/global/counties.csv"
config[:mastertargetfile] = "data/global/states.csv"
config[:mastersourceid] = :state
config[:mastertargetid] = :state

for filename in readdir("../../../data/counties/agriculture/edds")
    orderedconverttable("agriculture/edds/$filename", config, (column, values) -> mean(dropna(values)))
end

function translate(column, values)
    if column == :FIPS
        :targetid
    else
        sum(dropna(values))
    end
end

orderedconverttable("agriculture/irrigatedareas.csv", config, translate)
orderedconverttable("agriculture/rainfedareas.csv", config, translate)
orderedconverttable("agriculture/knownareas.csv", config, translate)

mirrorfile("agriculture/nationals.csv", config)
