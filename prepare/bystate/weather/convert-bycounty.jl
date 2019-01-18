using DataFrames
using NetCDF

allfips = ncread("../../../data/cache/counties/VIC_WB.nc", "state_fips")
states = convert(Vector{Int64}, unique(allfips))
num = length(states)

nccreate("../../../data/cache/states/VIC_WB.nc", "state_fips", "state", num)
ncwrite(states, "../../../data/cache/states/VIC_WB.nc", "state_fips")

for variable in ["baseflow", "runoff", "precip", "recharge", "et"]
    data = ncread("../../../data/cache/counties/VIC_WB.nc", variable)
    data[isnan.(data)] = 0
    result = zeros(735, num)
    for ii in 1:length(states)
        result[:, ii] = mean(data[:, allfips .== states[ii]], 2)
    end

    nccreate("../../../data/cache/states/VIC_WB.nc", variable, "month", 735, "state", num, Dict{Any, Any}("units" => "mm"))
    ncwrite(result, "../../../data/cache/states/VIC_WB.nc", variable)
end

nccreate("../../../data/cache/states/VIC_WB.nc", "state", "state", num)
ncwrite(collect(1:num), "../../../data/cache/states/VIC_WB.nc", "state")

nccreate("../../../data/cache/states/VIC_WB.nc", "month", "month", 735)
ncwrite(collect(1:735), "../../../data/cache/states/VIC_WB.nc", "month")

cp("../../../data/cache/states/VIC_WB.nc", expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/VIC_WB-states.nc"), remove_destination=true)
