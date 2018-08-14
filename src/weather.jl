## Weather information
#
# Load the weather data for the given configuration.

# Can only be called after loading regionnet.jl

using DataFrames
using RData
include("lib/weather.jl")
include("lib/coding.jl")

statefips = dncload("weather", "state_fips", [config["ncregion"]])
if config["ncregion"] == "county"
    countyfips = dncload("weather", "county_fips", ["county"])
    indicies = map(fipsnum -> (fipsnum < 10000 ? "0$fipsnum" : "$fipsnum"), round.(Int, statefips * 1000 + countyfips))
else
    indicies = dncload("weather", "state", ["county"])
end

if config["dataset"] == "counties"
    regions = CSV.read(loadpath("county-info.csv"), types=[Int64, String, String, String, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}, Union{Float64, Missing}], missingstring="NA")
else
    regions = CSV.read(loadpath("county-info.csv"))
end

regions[:FIPS] = regionindex(regions, :)

regions[:TotalArea_sqmi] = replacemissing(regions, :TotalArea_sqmi, 0.)
countyareas = reorderfips(regions[:, :TotalArea_sqmi] * 258.999, regions[:FIPS], masterregions[:fips]) # Ha
regions[:LandArea_sqmi] = replacemissing(regions, :LandArea_sqmi, 0.)
countylandareas = reorderfips(regions[:, :LandArea_sqmi] * 258.999, regions[:FIPS], masterregions[:fips]) # Ha

# Load precipitation from the county-aggregated weather
if get(config, "dataset", "counties") == "paleo"
    precip = zeros(nrow(masterregions), numsteps)
    recharge = zeros(nrow(masterregions), numsteps)
else
    precip = reorderfips(sum2timestep(dncload("weather", "precip", [config["ncregion"], "month"])), indicies, masterregions[:fips]); # mm / timestep
    recharge = reorderfips(sum2timestep(dncload("weather", "recharge", [config["ncregion"], "month"])), indicies, masterregions[:fips]).*repeat(countyareas, outer = [1, numsteps])*100; # 1000m3 / timestep
    precip[isnan.(precip)] = 0
    recharge[isnan.(recharge)] = 0
end

# Load data from the water budget

# Reorder stations to gauge order
if config["ncregion"] == "county"
    waternetdata = load(loadpath("waternet/waternet.RData"));
    waternetwork = waternetdata["network"]
    waternetwork[:gaugeid] = map(ii -> "$(waternetwork[ii, :collection]).$(waternetwork[ii, :colid])", 1:size(waternetwork)[1])
    gaugeindices = map(ii -> findfirst(waternetwork[:gaugeid], gaugeorder[ii]), 1:length(gaugeorder))
    waternetwork2 = waternetwork[gaugeindices, :]
else
    waternetdata = load(loadpath("waternet/waternet-counties.RData"));
    waternetwork = waternetdata["network"]
    waternetwork[:gaugeid] = map(ii -> "$(waternetwork[ii, :collection]).$(waternetwork[ii, :colid])", 1:size(waternetwork)[1])

    waternetwork2 = DataFrame(gaugeid=String[], lat=Float64[], lon=Float64[])
    for gaugeid in gaugeorder
        row = findfirst(waternetwork[:gaugeid] .== gaugeid)
        push!(waternetwork2, [gaugeid, waternetwork[row, :lat], waternetwork[row, :lon]])
    end
end

addeds = sum2timestep(getadded(waternetwork2))' # transpose, so N x T.
