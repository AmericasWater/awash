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

mirrorfile("aquaculture/production.csv", config)

function translate(column, values)
    if in(column, [:STATEFIPS, :COUNTY, :COUNTYFIPS, :FIPS, :STATE])
        nothing
    elseif column == :YEAR
        values[1]
    else
        sum(values)
    end
end

converttable("aquaculture/usgsextract.csv", config, translate)
