using Dates

include("datastore.jl")

cropcalendar = getfilteredtable("../../prepare/agriculture/countycalendars.csv", :fips)

"""
Returns an ordered list of m over entire period
"""
function getcropdemand(tt, crop)
    df = cropcalendar[cropcalendar[:crop] .== crop,:]
    stepstart, stepend = getdaysofyear(tt) # stepend always positive, and stepstart < stepend

    irrigdays = zeros(nrow(df))
    irrigdays[(df[:plant] .<= stepstart) .& (df[:harvest] .>= stepend)] = stepend - stepstart + 1
    irrigdays[(df[:plant] .> stepstart) .& (df[:harvest] .>= stepend)] = max.(0, stepend - df[:plant] + 1)
    irrigdays[(df[:plant] .<= stepstart) .& (df[:harvest] .< stepend)] = max.(0, df[:harvest] - stepstart + 1)
    irrigdays[(df[:plant] .> stepstart) .& (df[:harvest] .< stepend)] = df[:harvest] - df[:plant] + 1

    demand = water_requirements[crop] * irrigdays ./ (df[:harvest] - df[:plant] + 1)

    dataonmaster(df[:fips], demand)
end

"""
Return the first and last day of year of the given timestep
The last day of year will always be positive, and the first will always be less.
"""
function getdaysofyear(tt)
    first = Date(parseyear(config["startmonth"]), (parsemonth(config["startmonth"]) + (tt - 1) * config["timestep"]) % 12)
    last = (first + Dates.Month(config["timestep"])) - Dates.Day(1)

    enddoy = Dates.dayofyear(last)
    startdoy = enddoy - Dates.value(last - first)

    startdoy, enddoy
end
