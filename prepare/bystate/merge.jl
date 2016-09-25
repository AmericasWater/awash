include("../../src/lib/readconfig.jl")
suffix = ""
config = emptyconfig()

include("../../src/lib/datastore.jl")
include("../../src/lib/reservoirs.jl")
include("../../src/waternet.jl")

include("mergelib.jl")

waternetdata = load(datapath("waternet.RData"));
netdata = waternetdata["network"];

drawsdata = load(datapath("countydraws.RData"));
draws = drawsdata["draws"];
draws[:source] = round(Int64, draws[:source]);

# Label all with the node name
draws[:gaugeid] = ""
for ii in 1:nrow(draws)
    row = draws[ii, :source]
    draws[ii, :gaugeid] = "$(netdata[row, :collection]).$(netdata[row, :colid])"
end

mastercounties = readtable(datapath("global/counties$suffix.csv"), eltypes=[UTF8String, UTF8String, UTF8String])

function getregion(label)
    regions = round(Int64, floor(draws[(draws[:gaugeid] .== label) & (draws[:justif] .== "contains"), :source] / 1000))
    if length(regions) == 1
        regions[1] < 10 ? "0$(regions[1])" : "$(regions[1])"
    elseif length(regions) == 0
        "missing"
    else
        "multiple"
    end
end

allregions() = unique(map(fips -> fips[1:2], mastercounties[:fips]))

newwateridverts, newwaternet, result = mergedown(downstreamorder[length(downstreamorder):-1:1], waternet)

serialize(open(datapath("cache/newwaternet.jld"), "w"), newwaternet)
serialize(open(datapath("cache/newwateridverts.jld"), "w"), newwateridverts)

writetable("newnetwork.csv", result)

exit()

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
