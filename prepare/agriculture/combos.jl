using DataFrames

calendars = readtable("countycalendars.csv")

croporder = unique(calendars[:crop])
countyorder = unique(calendars[[:state, :county]])

df = DataFrame(state=[], county=[], combo=[])

for ii in 1:nrow(countyorder)
    println(ii)

    countyrows = calendars[(countyorder[ii, :state] .== calendars[:state]) & (countyorder[ii, :county] .== calendars[:county]),:]

    for jj in 1:(length(croporder)-1)
        for kk in (jj+1):length(croporder)
            # Can one plant both of these?
            cropjjrow = countyrows[(croporder[jj] .== countyrows[:crop]), :]
            cropkkrow = countyrows[(croporder[kk] .== countyrows[:crop]), :]
            if !isna(cropjjrow[1, :harvest]) && !isna(cropkkrow[1, :harvest])
                if (cropjjrow[1, :harvest] < cropkkrow[1, :plant]) & (cropkkrow[1, :harvest] < cropjjrow[1, :plant] + 365)
                    push!(df, [countyorder[ii, :state], countyorder[ii, :county], "$(croporder[jj])-$(croporder[kk])"])
                elseif (cropkkrow[1, :harvest] < cropjjrow[1, :plant]) & (cropjjrow[1, :harvest] < cropkkrow[1, :plant] + 365)
                    push!(df, [countyorder[ii, :state], countyorder[ii, :county], "$(croporder[kk])-$(croporder[jj])"])
                end
            end
        end
    end
end

unique(df[:combo])
