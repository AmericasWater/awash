## Weather data library
#
# Management functions for weather data.

include("datastore.jl")

"Reorder `values`, currently ordered according to `fromfips`, to `tofips` order."
function reorderfips(values::Union{Array{Union{Missing, Float64}, 1}, Vector{Float64}}, fromfips, tofips)
    result = zeros(length(tofips))
    for rr in 1:length(tofips)
        ii = findfirst(fromfips .== tofips[rr])
        if ii != nothing
            result[rr] = values[ii]
        end
    end

    result
end

"Reorder `weather`, a N(`fromfips`) x S x T matrix, into a N(`tofips`) x S x T matrix."
function reorderfips(weather::Union{Array{Union{Missing, Float64}, 3}, Array{Float64, 3}}, fromfips, tofips)
    result = zeros(length(tofips), size(weather, 2), size(weather, 3))
    for rr in 1:length(tofips)
        ii = findfirst(fromfips .== tofips[rr])
        if ii != nothing
            result[rr, :, :] = weather[ii, :, :]
        end
    end

    result
end

"""
Takes T x N and returns N x S x T for scenario spans.
"""
function scenarioextract(weather, eachstep; dropstart::Bool=true)
    if dropstart
        weatherfromstart = weather[get(config, "startweather", 1):end, :]
    else
        weatherfromstart = weather
    end
    scenarios = get(config, "scenarios", [1])

    if eachstep
        bytimestep = zeros(size(weather, 2), numscenarios, numsteps * config["timestep"])
        for ss in 1:length(scenarios)
            bytimestep[:, ss, :] = weather[scenarios[ss]:scenarios[ss]+numsteps*config["timestep"]-1, :]'
        end
    else
        bytimestep = zeros(size(weather, 2), numscenarios, numsteps)
        for ss in 1:length(scenarios)
            bytimestep[:, ss, :] = weather[scenarios[ss]:scenarios[ss]+numsteps-1, :]'
        end
    end

    bytimestep
end

"""
Sum values within each timestep, and reorder dimensions, returning a N x S x T matrix.

Assumes that `config` is defined globally
"""
function sum2timestep(weather; dropstart::Bool=true)
    if config["timestep"] == 1
        return scenarioextract(weather, true)
    end

    if dropstart
        weatherfromstart = weather[get(config, "startweather", 1):end, :]
    else
        weatherfromstart = weather
    end
    scenarios = get(config, "scenarios", [1])

    bytimestep = zeros(size(weather, 2), numscenarios, numsteps)

    for ss in 1:length(scenarios)
        for timestep in 1:numsteps
            allcounties = zeros(size(weather, 2))
            for month in 1:config["timestep"]
                allcounties += weatherfromstart[round.(Int64, (timestep - 1) * config["timestep"] + month + scenarios[ss] - 1), :]
            end

            bytimestep[:, ss, timestep] = allcounties
        end
    end

    bytimestep
end

"""
Return a matrix of MONTH x GAUGES (to match order for `sum2timestep`).
Return as 1000 m^3

# Arguments
* `stations::DataFrame`: Contains `lat` and `lon` columns to match up
  with the data; the result matrix will have the same number of rows.
"""
function getadded(stations::DataFrame)
    # Check if the weather file needs to be downloaded
    gage_latitude = knownvariable("runoff", "gage_latitude")
    gage_longitude = knownvariable("runoff", "gage_longitude")
    gage_totalflow = knownvariable("runoff", "totalflow")
    gage_area = knownvariable("runoff", "contributing_area")

    added = zeros(size(gage_totalflow, 2), nrow(stations)) # contributions (1000 m^3)

    stationmatches = repeat([false], nrow(stations))
    gagematches = repeat([false], length(gage_latitude))
    for ii in 1:nrow(stations)
        gage = findall((abs.(stations[ii, :lat] .- gage_latitude) .< 1e-6) .& (abs.(stations[ii, :lon] .- gage_longitude) .< 1e-6))
        if length(gage) != 1 || gage[1] > size(gage_totalflow)[1]
            continue
        end

        added[:, ii] = vec(gage_totalflow[gage[1], :]) * gage_area[gage[1]]
        stationmatches[ii] = true
        gagematches[gage[1]] = true
    end

    # Fill all remaining unmatched flow data to closest unmatched station
    for jj in findall(.!gagematches)
        dists = sqrt.((stations[:, :lat] .- gage_latitude[jj]).^2 + (stations[:, :lon] .- gage_longitude[jj]).^2)
        ii = argmin(dists)
        if dists[ii] > 1 && !("filterstate" in keys(config))
            println("Gage $jj cannot be matched: $(gage_latitude[jj]), $(gage_longitude[jj]) closest to $(stations[ii, :lat]), $(stations[ii, :lon])")
        end

        added[:, ii] = vec(gage_totalflow[jj, :]) * gage_area[jj]
        stationmatches[ii] = true
        gagematches[jj] = true
    end

    added[isnan.(added)] .= 0 # if NaN, set to 0 so doesn't propagate

    added
end

"""
Get the number of steps represented in a weather file.
"""
function getmaxsteps()
    length(knownvariable("runoff", "month"))
end
