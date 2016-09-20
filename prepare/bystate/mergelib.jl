function mergedown(nodes, waternet)
    outedges = Dict{ExVertex, Vector{ExVertex}}() # all destined newwaternet nodes (but some might be dropped for region)
    merging = Dict{ExVertex, ExVertex}(); # feed runoff from waternet A to newwaternet B

    newwateridverts = Dict{UTF8String, ExVertex}();
    newwaternet = empty_extnetwork(); # The final network (need to add nodes in initial loop)
    result = DataFrame(node=UTF8String[], outnode=UTF8String[])

    # Add node for each region
    index = 0
    newwateridverts["missing"] = ExVertex(index += 1, "missing")
    add_vertex!(newwaternet, newwateridverts["missing"])
    push!(result, ["missing", ""])

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

        # Has this already been merged into a group node?
        #region = getregion(node.label)
        #if region == "missing"
        #    newnode = newwateridverts["missing"]
        #elseif in(node, keys(merging))
        if in(node, keys(merging))
            newnode = merging[node]
        else
            # Make a new node
            newnode = ExVertex(index += 1, node.label)
            add_vertex!(newwaternet, newnode)
            outedges[newnode] = []
        end

        upstreams = out_neighbors(node, waternet)

        if length(upstreams) > 0
            # Group into sets in the same region
            byregion = Dict{UTF8String, Vector{ExVertex}}()
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
                for upstream in upstreams
                    merging[upstream] = newnode
                end
            else
                for (region, upstreams) in byregion
                    regionnode = ExVertex(index += 1, upstreams[1].label)
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

    # Now construct the final network
    for (newnode, outnewnodes) in outedges
        if length(outnewnodes) == 0
            # Replace this merged region node with the whole state
            for node in keys(merging)
                if merging[node] == newnode
                    region = getregion(node.label)
                    if !in(region, keys(newwateridverts)) # missing if Alaska, etc.
                        merging[node] = newwateridverts[region]
                    end
                end
            end
        else
            newwateridverts[newnode.label] = newnode
            add_vertex!(newwaternet, newnode)
            for newoutnode in outnewnodes
                if !in(newoutnode.label, keys(newwateridverts))
                    add_vertex!(newwaternet, newoutnode)
                end
                add_edge!(newwaternet, newnode, newoutnode)
                push!(result, [newnode.label, newoutnode.label])
            end
        end
    end

    newwateridverts, newwaternet, result
end
