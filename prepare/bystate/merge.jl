include("../../src/lib/readconfig.jl")
suffix = ""
config = emptyconfig()

include("../../src/lib/datastore.jl")
include("../../src/lib/reservoirs.jl")
include("../../src/waternet.jl")

include("mergelib.jl")
include("statelib.jl")

mastercounties = readtable(datapath("global/counties$suffix.csv"), eltypes=[UTF8String, UTF8String, UTF8String])

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

serialize(open(datapath("cache/newwaternet.jld"), "w"), newwaternet)
serialize(open(datapath("cache/newwateridverts.jld"), "w"), newwateridverts)

writetable("newnetwork.csv", result)

newdraws = DataFrame(region=UTF8String[], gaugeid=UTF8String[])
for node in values(newwateridverts)
    push!(newdraws, [getregion(node.label), node.label])
end
serialize(open(datapath("cache/newwaterdraws.jld"), "w"), newdraws)
