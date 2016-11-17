# Can only be called after loading regionnet.jl

using DataFrames
using RData
include("lib/weather.jl")

statefips = dncload("weather", "state_fips", ["county"])
countyfips = dncload("weather", "county_fips", ["county"])
fips = map(fipsnum -> (fipsnum < 10000 ? "0$fipsnum" : "$fipsnum"), round(Int, statefips * 1000 + countyfips))

counties = readtable(datapath("county-info.csv"), eltypes=[UTF8String, UTF8String, UTF8String, UTF8String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
counties[:FIPS] = map(fips -> length(fips) == 4 ? "0$fips" : fips, counties[:FIPS])
areas=readtable(datapath("agarea.csv"))



counties[isna(counties[:, :TotalArea_sqmi]), :TotalArea_sqmi] = 0
countyareas = reorderfips(counties[:, :TotalArea_sqmi] * 258.999, counties[:FIPS], mastercounties[:fips]) # Ha
#countyareas = areas[:,:x1]
counties[isna(counties[:, :LandArea_sqmi]), :LandArea_sqmi] = 0
countylandareas = reorderfips(counties[:, :LandArea_sqmi] * 258.999, counties[:FIPS], mastercounties[:fips]) # Ha

# Load precipitation from the county-aggregated weather
precip = reorderfips(sum2timestep(dncload("weather", "precip", ["county", "month"])), fips, mastercounties[:fips]); # mm / timestep

# Load data from the water budget

# Reorder stations to gauge order
waternetdata = load(datapath("waternet.RData"));
waternetwork = waternetdata["network"]
waternetwork[:gaugeid] = map(ii -> "$(waternetwork[ii, :collection]).$(waternetwork[ii, :colid])", 1:size(waternetwork)[1])
gaugeindices = map(ii -> findfirst(waternetwork[:gaugeid], gaugeorder[ii]), 1:length(gaugeorder))
waternetwork2 = waternetwork[gaugeindices, :]

addeds = sum2timestep(getadded(waternetwork2))'