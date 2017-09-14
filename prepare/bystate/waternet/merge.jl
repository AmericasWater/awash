include("../../../src/lib/readconfig.jl")
suffix = ""
config = emptyconfig()

include("../../../src/lib/datastore.jl")
include("../../../src/lib/reservoirs.jl")
include("../../../src/waternet.jl")

include("mergelib.jl")
include("statelib.jl")

mastercounties = readtable(datapath("global/counties$suffix.csv"), eltypes=[String, String, String])

allregions() = unique(map(fips -> fips[1:2], mastercounties[:fips]))

newwateridverts, newwaternet, result = mergedown(downstreamorder[length(downstreamorder):-1:1], waternet)
println(nrow(result))
newwateridverts, newwaternet, result = clearunconnected(newwateridverts, newwaternet, result)
println(nrow(result))
minrows = Inf
while nrow(result) < minrows
    println("$(nrow(result)) < $minrows")
    minrows = nrow(result)
    newwateridverts, newwaternet, result = mergedown(values(newwateridverts), newwaternet)
    println(nrow(result))
    newwateridverts, newwaternet, result = clearunconnected(newwateridverts, newwaternet, result)
end

map(ii -> "$(getregion(result[ii, :node])) -> $(getregion(result[ii, :outnode]))", 100:200)

serialize(open("../../../data/states/waternet/waternet.jld", "w"), newwaternet)
serialize(open("../../../data/states/waternet/wateridverts.jld", "w"), newwateridverts)

writetable("newnetwork.csv", result)

stateindexes = readtable("../../../data/global/states.csv")

newdraws = DataFrame(state=String[], gaugeid=String[])
for node in values(newwateridverts)
    if getregion(node.label) == "missing"
        state = "missing"
    else
        state = stateindexes[stateindexes[:fips] .== parse(Int64, getregion(node.label)), :state][1]
    end
    push!(newdraws, [state, node.label])
end
serialize(open("../../../data/states/waternet/waterdraws.jld", "w"), newdraws)
