include("../../src/lib/readconfig.jl")
suffix = ""
config = emptyconfig()

include("../../src/lib/datastore.jl")
include("../../src/lib/reservoirs.jl")
include("../../src/waternet.jl")

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

getregion(label) = "$(round(Int64, floor(draws[(draws[:gaugeid] .== label) & (draws[:justif] .== "contains"), :source] / 1000)))"
allregions() = unique(map(fips -> fips[1:2], mastercounties[:state]))

outedges = Dict{ExVertex, Vector{ExVertex}}() # all destined newwaternet nodes (but some might be dropped for region)
merging = Dict{ExVertex, ExVertex}(); # feed runoff from waternet A to newaternet B

index = 0
for hh in length(downstreamorder):-1:1 # start at most downstream
    node = downstreamorder[hh]

    # Has this already been merged into a group node?
    if in(node, keys(merging))
        newnode = merging[node]
    else
        newnode = ExVertex(index += 1, node.label)
        outedges[newnode] = []
    end
    
    upstreams = out_neighbors(node, waternet)
    if length(upstreams) > 0
        # Group into sets in the same region
        byregion = Dict{UTF8String, Vector{ExVertex}}()
        for upstream in upstreams
            region = getregion(upstream.label)
            if length(region) != 1
                region = "missing"
            end
            if !in(region, keys(byregion))
                byregion[region] = []
            end
            push!(byregion[region], upstream)
        end

        # Are these all in the same region?
        if length(byregion) == 1
            # Merge them all together
            for upstream in upstreams
                merging[upstream] = newnode
            end
        else
            for (region, upstreams) in byregion
                regionnode = ExVertex(index += 1, upstreams[1].label)
                for upstream in upstreams
                    merging[upstream] = regionnode
                end
                push!(outedges[newnode], regionnode)
            end
        end
    end
end

# Now construct the final network

newwateridverts = Dict{UTF8String, ExVertex}();
newwaternet = empty_extnetwork();

result = DataFrame(node=UTF8String[], outnode=UTF8String[])

# Add node for each region
for region in allregions()
    newwateridverts[region] = ExVertex(length(newwateridverts), region)
    add_vertex!(newwaternet, newwateridverts[region])
    push!(result, [region, ""])
end

for (newnode, outnewnodes) in outedges
    if length(outnewnodes) == 0
        # Replace this merged region node with the whole state
        for node in keys(merging)
            if merging[node] == newnode
                merging[node] = newwateridverts[getregion(label(node))]
            end
        end
    else
        newwateridverts[label(newnode)] = newnode
        add_vertex!(newaternet, newnode)
        for newoutnode in outnewnodes
            add_edge!(newwaternet, newnode, newoutnode)
            push!(result, [newnode.label, newoutnode.label])
        end
    end
end

serialize(open(datapath("cache/newwaternet.jld"), "w"), newwaternet)
serialize(open(datapath("cache/newwateridverts.jld"), "w"), newwateridverts)
#serialize(open(datapath("cache/waterdraws$suffix.jld"), "w"), draws)

writetable("newnetwork.csv", result)
