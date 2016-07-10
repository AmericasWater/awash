# Can only be called after loading regionnet.jl

using DataFrames
using NetCDF
include("lib/weather.jl")

statefips = ncread(datapath("VIC_WB.nc"), "state_fips")
countyfips = ncread(datapath("VIC_WB.nc"), "county_fips")
fips = map(fipsnum -> (fipsnum < 10000 ? "0$fipsnum" : "$fipsnum"), round(Int, statefips * 1000 + countyfips))

counties = readtable(datapath("county-info.csv"), eltypes=[UTF8String, UTF8String, UTF8String, UTF8String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
counties[:FIPS] = map(fips -> length(fips) == 4 ? "0$fips" : fips, counties[:FIPS])

counties[isna(counties[:, :TotalArea_sqmi]), :TotalArea_sqmi] = 0
countyareas = reorderfips(counties[:, :TotalArea_sqmi] * 258.999, counties[:FIPS], mastercounties[:fips]) # Ha
counties[isna(counties[:, :LandArea_sqmi]), :LandArea_sqmi] = 0
countylandareas = reorderfips(counties[:, :LandArea_sqmi] * 258.999, counties[:FIPS], mastercounties[:fips]) # Ha

# Load precipitation from the county-aggregated weather
precip = reorderfips(sum2timestep(ncread(datapath("VIC_WB.nc"), "precip")), fips, mastercounties[:fips]); # mm / timestep

# Load data from the water budget

# Match up gages to stations
waternetdata = read_rda(datapath("waternet.RData"), convertdataframes=true);
addeds = sum2timestep(getadded(waternetdata["network"]))' # transpose, so N x T.
