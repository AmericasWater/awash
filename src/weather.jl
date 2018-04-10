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

regions = readtable(loadpath("county-info.csv"), eltypes=[String, String, String, String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
regions[:FIPS] = regionindex(regions, :)

regions[isna.(regions[:, :TotalArea_sqmi]), :TotalArea_sqmi] = 0
countyareas = reorderfips(regions[:, :TotalArea_sqmi] * 258.999, regions[:FIPS], masterregions[:fips]) # Ha
regions[isna.(regions[:, :LandArea_sqmi]), :LandArea_sqmi] = 0
countylandareas = reorderfips(regions[:, :LandArea_sqmi] * 258.999, regions[:FIPS], masterregions[:fips]) # Ha

# Load precipitation from the county-aggregated weather
if get(config, "dataset", "counties") == "paleo"
    precip = zeros(nrow(masterregions), numscenarios, numsteps)
else
    precip = reorderfips(sum2timestep(dncload("weather", "precip", [config["ncregion"], "month"])), indicies, masterregions[:fips]); # mm / timestep
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

addeds = sum2timestep(getadded(waternetwork2))
