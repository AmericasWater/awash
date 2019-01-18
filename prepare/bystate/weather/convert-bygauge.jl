using Graphs
using NetCDF
using RData
using DataFrames

oldwaternet = deserialize(open("../../../data/cache/counties/waternet.jld"))
newwaternet = deserialize(open("../../../data/states/waternet/waternet.jld"))

# Collect data for matching data
gage_latitude = ncread("../../../data/cache/counties/contributing_runoff_by_gage.nc", "gage_latitude")
gage_longitude = ncread("../../../data/cache/counties/contributing_runoff_by_gage.nc", "gage_longitude")

waternetdata = load("../../../data/counties/waternet/waternet.RData");
waternetwork = waternetdata["network"]
waternetwork[:gaugeid] = map(ii -> "$(waternetwork[ii, :collection]).$(waternetwork[ii, :colid])", 1:size(waternetwork)[1])

function findupstream(node::ExVertex)
    upstreams = [node.label]
    for upstream in out_neighbors(node, oldwaternet)
        if !(upstream.label in newlabels)
            append!(upstreams, findupstream(upstream))
        end
    end

    upstreams
end

## Collect all new labels
newlabels = []
for newnode in vertices(newwaternet)
    push!(newlabels, newnode.label)
end

num = length(newlabels)

# Get all the data
contributing_area = ncread("../../../data/cache/counties/contributing_runoff_by_gage.nc", "contributing_area")
runoff = ncread("../../../data/cache/counties/contributing_runoff_by_gage.nc", "runoff")
runoff[isnan.(runoff)] = 0
baseflow = ncread("../../../data/cache/counties/contributing_runoff_by_gage.nc", "baseflow")
baseflow[isnan.(baseflow)] = 0
totalflow = ncread("../../../data/cache/counties/contributing_runoff_by_gage.nc", "totalflow")
totalflow[isnan.(totalflow)] = 0

# Set up repositories for results
newcontributing_area = zeros(num)
newlatitude = zeros(num)
newlongitude = zeros(num)
newrunoff = zeros(num, 735)
newbaseflow = zeros(num, 735)
newtotalflow = zeros(num, 735)

## Determine set of nodes associated with each
for ii in 1:length(newlabels)
    println(ii)
    # Find this in the old waternet
    oldupstreams = nothing
    for oldnode in vertices(oldwaternet)
        if oldnode.label == newlabels[ii]
            oldupstreams = findupstream(oldnode)
            break
        end
    end

    # Translate into indexes
    indices = []
    for oldupstream in oldupstreams
        row = findfirst(waternetwork[:gaugeid] .== oldupstream)
        index = find((gage_latitude .== waternetwork[row, :lat]) .& (gage_longitude .== waternetwork[row, :lon]))
        append!(indices, index) 
   end

    newcontributing_area[ii] = sum(contributing_area[indices])
    if length(indices) > 0
        newlatitude[ii] = gage_latitude[indices[1]]
        newlongitude[ii] = gage_longitude[indices[1]]
    end
    newrunoff[ii, :] = sum(runoff[indices, :], 1)
    newbaseflow[ii, :] = sum(baseflow[indices, :], 1)
    newtotalflow[ii, :] = sum(totalflow[indices, :], 1)
end

rm("../../../data/cache/states/contributing_runoff_by_gage.nc")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "contributing_area", "gage", num)
ncwrite(newcontributing_area, "../../../data/cache/states/contributing_runoff_by_gage.nc", "contributing_area")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "gage_latitude", "gage", num)
ncwrite(newlatitude, "../../../data/cache/states/contributing_runoff_by_gage.nc", "gage_latitude")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "gage_longitude", "gage", num)
ncwrite(newlongitude, "../../../data/cache/states/contributing_runoff_by_gage.nc", "gage_longitude")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "runoff", "gage", num, "month", 735, Dict{Any, Any}("units" => "mm/month"))
ncwrite(newrunoff, "../../../data/cache/states/contributing_runoff_by_gage.nc", "runoff")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "baseflow", "gage", num, "month", 735, Dict{Any, Any}("units" => "mm/month"))
ncwrite(newbaseflow, "../../../data/cache/states/contributing_runoff_by_gage.nc", "baseflow")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "totalflow", "gage", num, "month", 735, Dict{Any, Any}("units" => "mm/month"))
ncwrite(newtotalflow, "../../../data/cache/states/contributing_runoff_by_gage.nc", "totalflow")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "gage", "gage", num)
ncwrite(collect(1:num), "../../../data/cache/states/contributing_runoff_by_gage.nc", "gage")

nccreate("../../../data/cache/states/contributing_runoff_by_gage.nc", "month", "month", 735)
ncwrite(collect(1:735), "../../../data/cache/states/contributing_runoff_by_gage.nc", "month")

cp("../../../data/cache/states/contributing_runoff_by_gage.nc", expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/contributing_runoff_by_gage-states.nc"), remove_destination=true)
