include("convertlib.jl")

config = Dict{Symbol, Any}()
config[:source] = "counties"
config[:sourceid] = :FIPS_county
config[:target] = "states"
config[:targetid] = :ST
config[:masterfile] = "data/global/counties.csv"
config[:mastersourceid] = :fips
config[:mastertargetid] = :state
config[:forcematching] = false

function translatechunk(subdf)
    if nrow(subdf) == 0
        return DataFrame(year=Int64[], state_name=UTF8String[], PS_TOPop=Int64[], est_water_demand3=Float64[], per_capita=Float64[])
    end
    
    populations = subdf[:est_water_demand3] ./ subdf[:per_capita]
    totaldemand = sum(dropna(subdf[:est_water_demand3]))
    totalpop = sum(dropna(populations))
    
        DataFrame(year=[subdf[1, :year]], state_name=[subdf[1, :state_name]], PS_TOPop=[sum(dropna(subdf[:PS_TOPop]))], est_water_demand3=[totaldemand], per_capita=[totaldemand / totalpop])
end

chunkyconverttable("demand/urbandemand_May11.csv", config, translatechunk)
