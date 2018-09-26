# Leaps require a full nummonths months to complete, irrespective of
# starting date.

# Returns vector of 0 or more year that completed during this timestep
function timeindex2leapindexes(tt::Int64, timestep::Int64, nummonths::Int64)
    if timestep == nummonths
        return Int64[tt]
    elseif timestep < nummonths
        thisleap = div(tt * timestep, nummonths)
        lastleap = div((tt - 1) * timestep, nummonths)
        if thisleap == lastleap
            return Int64[]
        else
            return collect((lastleap + 1):thisleap)
        end
    else # timestep > nummonths
        thisleap = div(tt * timestep, nummonths)
        lastleap = div((tt - 1) * timestep, nummonths)
        return collect((lastleap + 1):thisleap)
    end
end

# Returns vector of 1 or more timesteps that contributed to the
# completion of this leap, and a scaling value for how each timestep
# contributed (typically all 1's)
function leapindex2timeindexes(yy::Int64, timestep::Int64, nummonths::Int64)
    if timestep == nummonths
        return Int64[yy], [1.0]
    elseif timestep < nummonths
        thismonth = yy * nummonths
        lastmonth = (yy - 1) * nummonths
        firststepbegin = div(lastmonth, timestep) * timestep + 1
        laststepend = div(thismonth + 1, timestep) * timestep
        firstscale = 1.0 - (lastmonth + 1 - firststepbegin) / timestep
        lastscale = 1.0 - (laststepend - thismonth) / timestep

        timeindexes = collect((div(lastmonth, timestep) + 1):div(thismonth, timestep))
        timescaling = [firstscale; ones(length(timeindexes)-2); lastscale]
        return timeindexes, timescaling
    else # timestep > nummonths
        thismonth = yy * nummonths
        lastmonth = (yy - 1) * nummonths
        firststepbegin = div(lastmonth, timestep) * timestep + 1
        laststepend = (div(thismonth, timestep) + 1) * timestep
        firstscale = 1.0 - (lastmonth + 1 - firststepbegin) / timestep
        lastscale = 1.0 - (laststepend - thismonth) / timestep

        if div(lastmonth, timestep) + 1 > div(thismonth, timestep)
            timeindexes = [div(thismonth, timestep) + 1]
            timescaling = [1 - ((1.0 - firstscale) + (1.0 - lastscale))]
        else
            timeindexes = collect((div(lastmonth, timestep) + 1):div(thismonth, timestep))
            if length(timeindexes) == 2
                timescaling = [firstscale; lastscale]
            else
                timescaling = [1 - lastscale - firstscale]
            end
        end
        return timeindexes, timescaling
    end
end

# Returns vector of 1 or more years that were in play during this timestep
function timeindex2contributingleapindexes(tt::Int64, timestep::Int64, nummonths::Int64)
    if timestep == nummonths
        return Int64[tt]
    elseif timestep < nummonths
        thisleap = div(tt * timestep, nummonths)
        lastleap = div((tt - 1) * timestep, nummonths)
        if thisleap == lastleap
            return [lastleap + 1]
        else
            return collect((lastleap + 1):thisleap)
        end
    else # timestep > nummonths
        thisleap = div(tt * timestep, nummonths)
        lastleap = div((tt - 1) * timestep, nummonths)
        return collect((lastleap + 1):thisleap)
    end
end

"""Return a list of the years that finished in this timestep."""
function timeindex2yearindexes(tt::Int64)
    timeindex2leapindexes(tt, config["timestep"], 12)
end

"""Return a list of the years that where involved in this timestep."""
function timeindex2contributingyearindexes(tt::Int64)
    contyys = timeindex2contributingleapindexes(tt, config["timestep"], 12)
    contyys[contyys .<= numharvestyears]
end

"""Return a list of the timesteps that finished in this year."""
function yearindex2timeindexes(yy::Int64)
    tts, weights = leapindex2timeindexes(yy, config["timestep"], 12)
    tts[tts .<= numsteps], weights[tts .<= numsteps]
end
