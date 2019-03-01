using Graphs
using DataFrames

if !(@isdefined RegionNetwork)
    const RegionNetwork{R, E} = IncidenceList{R, E}
    const OverlaidRegionNetwork = RegionNetwork{ExVertex, ExEdge}
end

# Water network has OUT nodes to UPSTREAM
empty_extnetwork() = OverlaidRegionNetwork(true, ExVertex[], 0, Vector{Vector{ExEdge}}())

function mergedown(nodes, waternet)
    outedges = Dict{ExVertex, Vector{ExVertex}}() # all destined newwaternet nodes (but some might be dropped for region)
    merging = Dict{ExVertex, ExVertex}(); # feed runoff from waternet A to newwaternet B

    newwateridverts = Dict{String, ExVertex}();
    newwaternet = empty_extnetwork(); # The final network (need to add nodes in initial loop)
    result = DataFrame(node=String[], outnode=String[])

    # Add node for each region
    index = 0
    newwateridverts["missing"] = ExVertex(index += 1, "missing")
    add_vertex!(newwaternet, newwateridverts["missing"])
    push!(result, ["missing", ""])
    outedges[newwateridverts["missing"]] = []

    for region in allregions()
        newwateridverts[region] = ExVertex(index += 1, region)
        add_vertex!(newwaternet, newwateridverts[region])
        push!(result, [region, ""])
    end

    # Add other vertexes and construct data structure
    for node in nodes # start at most downstream
        if index % 100 == 0
            println(index)
        end

        upstreams = out_neighbors(node, waternet)

        # Has this already been merged into a group node?
        #region = getregion(node.label)
        #if region == "missing"
        #    newnode = newwateridverts["missing"]
        #elseif in(node, keys(merging))
        if in(node, keys(merging))
            newnode = merging[node]
        elseif in(node.label, keys(newwateridverts))
            newnode = newwateridverts[node.label]
        elseif length(upstreams) == 0
            region = getregion(node.label)
            merging[node] = newwateridverts[region]
            continue
        else
            # Make a new node
            newnode = ExVertex(index += 1, node.label)
            newwateridverts[node.label] = newnode
            add_vertex!(newwaternet, newwateridverts[node.label])
            outedges[newnode] = []
        end

        if length(upstreams) > 0
            # Group into sets in the same region
            byregion = Dict{String, Vector{ExVertex}}()
            for upstream in upstreams
                region = getregion(upstream.label)
                if region == "missing"
                    merging[upstream] = newwateridverts["missing"]
                end
                if !in(region, keys(byregion))
                    byregion[region] = []
                end
                push!(byregion[region], upstream)
            end

            # Are these all in the same region?
            if length(byregion) == 1
                # Merge them all together
                if collect(keys(byregion))[1] == getregion(node.label) # same region as node
                    for upstream in upstreams
                        merging[upstream] = newnode
                    end
                else
                    # All in a neighboring region
                    mergelabel = collect(values(byregion))[1][1].label
                    mergenode = ExVertex(index += 1, mergelabel)
                    newwateridverts[mergelabel] = mergenode

                    add_vertex!(newwaternet, mergenode)
                    outedges[mergenode] = []

                    for upstream in upstreams
                        merging[upstream] = mergenode
                    end

                    push!(outedges[newnode], mergenode)
                end
            else
                for (region, upstreams) in byregion
                    if region == getregion(node.label)
                        for upstream in upstreams
                            merging[upstream] = newnode
                        end
                    else
                        regionlabel = upstreams[1].label
                        regionnode = ExVertex(index += 1, regionlabel)
                        newwateridverts[regionlabel] = regionnode

                        add_vertex!(newwaternet, regionnode)
                        outedges[regionnode] = []

                        for upstream in upstreams
                            merging[upstream] = regionnode
                        end

                        push!(outedges[newnode], regionnode)
                    end
                end
            end
        end
    end

    #println("Outedges:")
    #println(outedges)

    #println("Merging:")
    #println(merging)

    # Now construct the final network
    for (newnode, outnewnodes) in outedges
        for newoutnode in outnewnodes
            # Trace merging to the end
            add_edge!(newwaternet, newnode, newoutnode)
            push!(result, [newnode.label, newoutnode.label])
        end
    end

    newwateridverts, newwaternet, result
end

function clearunconnected(wateridverts, waternet, result)
    connections = Dict(node => length(out_neighbors(node, waternet)) for node = vertices(waternet))
    for node in vertices(waternet)
        for neighbor in out_neighbors(node, waternet)
            connections[neighbor] += 1
        end
    end

    #println("Connects:")
    #println(connections)

    newwateridverts = Dict{String, ExVertex}();
    newwaternet = empty_extnetwork(); # The final network (need to add nodes in initial loop)
    newresult = DataFrame(node=String[], outnode=String[])

    index = 0
    for node in keys(connections)
        if connections[node] > 0
            if !in(node.label, keys(newwateridverts))
                newwateridverts[node.label] = ExVertex(index += 1, node.label)
                add_vertex!(newwaternet, newwateridverts[node.label])
            end
            for neighbor in out_neighbors(node, waternet)
                if connections[neighbor] > 0
                    if !in(neighbor.label, keys(newwateridverts))
                        newwateridverts[neighbor.label] = ExVertex(index += 1, neighbor.label)
                        add_vertex!(newwaternet, newwateridverts[neighbor.label])
                    end
                    add_edge!(newwaternet, newwateridverts[node.label], newwateridverts[neighbor.label])
                    push!(newresult, [node.label, neighbor.label])
                end
            end
        end
    end

    newwateridverts, newwaternet, newresult
end
