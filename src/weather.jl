## Weather information
#
# Load the weather data for the given configuration.

# Can only be called after loading regionnet.jl

using DataFrames
using RData
include("lib/weather.jl")
include("lib/coding.jl")
include("lib/inputcache.jl")

statefips = dncload("weather", "state_fips", [config["ncregion"]])
if config["ncregion"] == "county"
    countyfips = dncload("weather", "county_fips", ["county"])
    indicies = map(fipsnum -> (fipsnum < 10000 ? "0$fipsnum" : "$fipsnum"), round.(Int, statefips * 1000 + countyfips))
else
    indicies = dncload("weather", "state", ["county"])
end

regions = knowndf("region-info")

regions[!, :FIPS] = regionindex(regions, :)

regions[!, :TotalArea_sqmi] = replacemissing(regions, :TotalArea_sqmi, 0.)
countyareas = reorderfips(regions[:, :TotalArea_sqmi] * 258.999, regions[!, :FIPS], masterregions[!, :fips]) # Ha
regions[!, :LandArea_sqmi] = replacemissing(regions, :LandArea_sqmi, 0.)
countylandareas = reorderfips(regions[:, :LandArea_sqmi] * 258.999, regions[!, :FIPS], masterregions[!, :fips]) # Ha

# Load precipitation from the county-aggregated weather
if get(config, "dataset", "counties") == "paleo"
    fullprecip = zeros(nrow(masterregions), numscenarios, numsteps * config["timestep"])
    precip = zeros(nrow(masterregions), numscenarios, numsteps)
    recharge = zeros(nrow(masterregions), numscenarios, numsteps)
else
    fullprecip = reorderfips(scenarioextract(dncload("weather", "precip", [config["ncregion"], "month"]), true), indicies, masterregions[!, :fips]); # mm / month
    precip = reorderfips(sum2timestep(dncload("weather", "precip", [config["ncregion"], "month"])), indicies, masterregions[!, :fips]); # mm / timestep
    recharge = reorderfips(sum2timestep(dncload("weather", "recharge", [config["ncregion"], "month"])), indicies, masterregions[!, :fips]).*repeat(countyareas, outer = [1, numscenarios, numsteps])*100; # 1000m3 / timestep
    fullprecip[isnan.(fullprecip)] .= 0
    precip[isnan.(precip)] .= 0
    recharge[isnan.(recharge)] .= 0

    fullprecip[findall(masterregions[!, :fips] .== "25019"),:,:] .= 0 # set to 0 for Nantucket, MA
    precip[findall(masterregions[!, :fips] .== "25019"),:,:] .= 0
    recharge[findall(masterregions[!, :fips] .== "25019"),:,:] .= 0
    fullprecip[findall(masterregions[!, :fips] .== "53055"),:,:] .= 0 # set to 0 for San Juan, WA
    precip[findall(masterregions[!, :fips] .== "53055"),:,:] .= 0
    recharge[findall(masterregions[!, :fips] .== "53055"),:,:] .= 0
end

# Load data from the water budget

# Reorder stations to gauge order
if config["ncregion"] == "county"
    waternetdata = load(loadpath("waternet/waternet.RData"));
    waternetwork = waternetdata["network"]
    waternetwork[!, :gaugeid] = map(ii -> "$(waternetwork[ii, :collection]).$(waternetwork[ii, :colid])", 1:size(waternetwork)[1])
    gaugeindices = map(ii -> findfirst(waternetwork[!, :gaugeid] .== gaugeorder[ii]), 1:length(gaugeorder))
    waternetwork2 = waternetwork[gaugeindices, :]
else
    waternetdata = load(loadpath("waternet/waternet-counties.RData"));
    waternetwork = waternetdata["network"]
    waternetwork[!, :gaugeid] = map(ii -> "$(waternetwork[ii, :collection]).$(waternetwork[ii, :colid])", 1:size(waternetwork)[1])

    waternetwork2 = DataFrame(gaugeid=String[], lat=Float64[], lon=Float64[], dist=Float64[])
    for gaugeid in gaugeorder
        row = findfirst(waternetwork[!, :gaugeid] .== gaugeid)
        push!(waternetwork2, [gaugeid, waternetwork[row, :lat], waternetwork[row, :lon], 0.]) # fill in dist later
    end

    for vertex in vertices(waternet)
        for edge in out_edges(vertex, waternet)
            downgid = source(edge).label
            downrow = waternetwork2[waternetwork2[!, :gaugeid] .== downgid, :]
            upgid = target(edge).label
            uprow = waternetwork2[waternetwork2[!, :gaugeid] .== upgid, :]
            dist = 100.0 * sqrt((downrow[1, :lat] - uprow[1, :lat])^2 + (downrow[1, :lon] - uprow[1, :lon])^2) # rough approximation
            waternetwork2[waternetwork2[!, :gaugeid] .= upgid, :dist] .= dist
        end
    end
end

addeds = sum2timestep(getadded(waternetwork2))

## Prepare evaporation information
if config["ncregion"] == "county"
    temps = ncread(loadpath("tasmat.nc4"), "tas")
    temps = temps[10:end, gaugeindices]

    sumtemps = sum2timestep(temps)
    meantemps = sumtemps / config["timestep"]

    gaugetas = convert(Array{Union{Missing, Float64}, 3}, meantemps)
    gaugetas[gaugetas .< -50] .= missing
end
