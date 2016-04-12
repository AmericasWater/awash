# Can only be called after loading regionnet.jl

using NetCDF

statefips = ncread("../data/VIC_WB.nc", "state_fips")
countyfips = ncread("../data/VIC_WB.nc", "county_fips")
fips = map(fipsnum -> (fipsnum < 10000 ? "0$fipsnum" : "$fipsnum"), round(Int, statefips * 1000 + countyfips))

counties = readtable("../data/county-info.csv", eltypes=[UTF8String, UTF8String, UTF8String, UTF8String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
counties[:FIPS] = map(fips -> length(fips) == 4 ? "0$fips" : fips, counties[:FIPS])

function reorderfips(weather::DataArrays.DataArray{Float64, 1}, fromfips, tofips)
    result = zeros(length(tofips))
    for rr in 1:length(tofips)
        ii = findfirst(fromfips .== tofips[rr])
        if ii > 0
            result[rr] = weather[ii]
        end
    end

    result
end

counties[isna(counties[:, :TotalArea_sqmi]), :TotalArea_sqmi] = 0
countyareas = reorderfips(counties[:, :TotalArea_sqmi] * 258.999, counties[:FIPS], names) # Ha
counties[isna(counties[:, :LandArea_sqmi]), :LandArea_sqmi] = 0
countylandareas = reorderfips(counties[:, :LandArea_sqmi] * 258.999, counties[:FIPS], names) # Ha

function reorderfips(weather::Array{Float64, 2}, fromfips, tofips)
    result = zeros(length(tofips), size(weather, 1))
    for rr in 1:length(tofips)
        ii = findfirst(fromfips .== tofips[rr])
        if ii > 0
            result[rr, :] = weather[:, ii]
        end
    end

    result
end

function sum2year(weather)
    byyear = zeros(size(weather, 1), round(Int64, size(weather, 2) / 12))
    for year in 1:round(Int64, size(weather, 2) / 12)
        allcounties = zeros(size(weather, 1))
        for month in 1:12
            allcounties += weather[:, round(Int64, (year - 1) * 12 + month)]
        end

        byyear[:, year] = allcounties
    end

    byyear
end

# Load data from the water budget
# Currently summing over all months
runoff = sum2year(reorderfips(ncread("../data/VIC_WB.nc", "runoff"), fips, names));
precip = sum2year(reorderfips(ncread("../data/VIC_WB.nc", "precip"), fips, names)); # mm / month

# Convert runoff to a gauge measure
waternetdata = read_rda("../data/waternet.RData", convertdataframes=true);
stations = waternetdata["stations"];

XX = spzeros(numgauges, numcounties) # contributions
# Fill in XX by column, with columns summing to 1
for rr in 1:numcounties
    println(rr)
    if isna(countyareas[rr])
        continue
    end
    fips = parse(Int64, names[rr])
    countygauges = draws[draws[:fips] .== fips, :gaugeid]
    countyindexes = [gaugeid in keys(wateridverts) ? vertex_index(wateridverts[gaugeid]) : 0 for gaugeid in countygauges]
    gauges = convert(Vector{Int64}, countyindexes)

    invalids = gauges .== 0
    gauges[invalids] = nrow(stations) + 1
    stationareas = stations[gauges[gauges .<= nrow(stations)], :area]
    if length(stationareas) == 0
        continue
    end

    medarea = median(dropna(stationareas))
    allareas = ones(length(gauges))
    allareas[gauges .<= nrow(stations)] = stationareas
    allareas[isnan(allareas)] = 1

    XX[gauges, rr] = (allareas / sum(allareas)) * countyareas[rr] / 100
end

addeds = XX * runoff;

