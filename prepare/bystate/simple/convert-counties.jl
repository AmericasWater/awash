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

masterstates = readtable("../../../data/global/states.csv", eltypes=[UTF8String, UTF8String, UTF8String])

function translate(column, values)
    if in(column, [:FIPS, :County, :ST])
        nothing
    elseif column == :Neighboring
        neighborstates = []
        for value in values
            for ii in 1:5:length(value)
                push!(neighborstates, value[ii:ii+1])
            end
        end

        statecodes = []
        for statefips in unique(neighborstates)
            push!(statecodes, masterstates[masterstates[:fips] .== statefips, :state][1])
        end

        join(statecodes)
    elseif in(column, [:UrbanPop_2010, :RuralPop_2010, :TotalArea_sqmi, :LandArea_sqmi, :WaterArea_sqmi])
        sum(dropna(values))
    else # MedianHouseholdInc-2008-12,Elevation-ft
        mean(dropna(values))
    end
end

converttable("county-info.csv", config, translate; eltypes=[Int64, UTF8String, UTF8String, UTF8String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])

function translatechunk(subdf)
    subresult = DataFrame(year=Int64[], population=Int64[])

    for year in unique(subdf[:year])
        population = sum(dropna(subdf[subdf[:year] .== year, :population]))

        push!(subresult, [year, population])
    end

    subresult
end

chunkyconverttable("county-pops.csv", config, translatechunk)
