include("datastore.jl")

"Reorder `values`, currently ordered according to `fromfips`, to `tofips` order."
function reorderfips(values::DataArrays.DataArray{Float64, 1}, fromfips, tofips)
    result = zeros(length(tofips))
    for rr in 1:length(tofips)
        ii = findfirst(fromfips .== tofips[rr])
        if ii > 0
            result[rr] = values[ii]
        end
    end

    result
end

"Reorder `weather` and transpose, a T x N(`fromfips`) matrix, into a N(`tofips`) x T matrix."
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

"""
Sum values within each timestep, returning a T x N(columns) matrix.

Assumes that `config` is defined globally
"""
function sum2timestep(weather)
    if config["timestep"] == 1
        return weather[config["startweather"]:config["startweather"]+numsteps-1, :]
    end

    bytimestep = zeros(numsteps, size(weather, 2))
    for timestep in 1:numsteps
        allcounties = zeros(1, size(weather, 2))
        for month in 1:config["timestep"]
            allcounties += weather[round(Int64, (timestep - 1) * config["timestep"] + month + config["startweather"] - 1), :]
        end

        bytimestep[timestep, :] = allcounties
    end

    bytimestep
end

"""
Return a matrix of MONTH x GAUGES (to match order for `sum2timestep`).

# Arguments
* `stations::DataFrame`: Contains `lat` and `lon` columns to match up
  with the data; the result matrix will have the same number of rows.
"""
function getadded(stations::DataFrame)
    # Check if the weather file needs to be downloaded
    gage_latitude = dncload("runoff", "gage_latitude", ["gage"])
    gage_longitude = dncload("runoff", "gage_longitude", ["gage"])
    gage_totalflow = dncload("runoff", "totalflow", ["month", "gage"])

    added = zeros(size(gage_totalflow, 2), nrow(stations)) # contributions

    for ii in 1:nrow(stations)
        gage = find((stations[ii, :lat] .== gage_latitude) & (stations[ii, :lon] .== gage_longitude))
        if length(gage) != 1
            continue
        end

        added[:, ii] = vec(gage_totalflow[gage[1], :])
    end

    added
end
