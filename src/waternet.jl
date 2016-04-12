using Mimi
using Graphs
using DataFrames

typealias RegionNetwork{R, E} IncidenceList{R, E}
typealias OverlaidRegionNetwork RegionNetwork{ExVertex, ExEdge}

filtersincludeupstream = false # true to include all upstream nodes during a filter

# Water network has OUT nodes to UPSTREAM

empty_extnetwork() = OverlaidRegionNetwork(true, ExVertex[], 0, Vector{Vector{ExEdge}}())

if isfile("../data/waternet$suffix.jld")
    println("Loading from saved water network...")

    waternet = deserialize(open("../data/waternet$suffix.jld", "r"));
    wateridverts = deserialize(open("../data/wateridverts$suffix.jld", "r"));
    draws = deserialize(open("../data/waterdraws$suffix.jld", "r"));
else
    # Load the network of counties
    if netset == "usa"
        waternetdata = read_rda("../data/waternet.RData", convertdataframes=true);
        drawsdata = read_rda("../data/countydraws.RData", convertdataframes=true);
    else
        waternetdata = read_rda("../data/dummynet.RData", convertdataframes=true);
        drawsdata = read_rda("../data/dummydraws.RData", convertdataframes=true);
    end

    netdata = waternetdata["network"];

    # Load the county-network connections
    draws = drawsdata["draws"];
    draws[:source] = round(Int64, draws[:source])
    # Label all with the node name
    draws[:gaugeid] = ""
    for ii in 1:nrow(draws)
        row = draws[ii, :source]
        draws[ii, :gaugeid] = "$(netdata[row, :collection]).$(netdata[row, :colid])"
    end

    if filterstate != nothing
        states = round(Int64, draws[:fips] / 1000)
        draws = draws[states .== parse(Int64, filterstate), :]

        includeds = falses(nrow(netdata))
        if filtersincludeupstream
            # Flag all upstream nodes
            checks = draws[:source]
            while length(checks) > 0
                includeds[checks] = true

                nexts = []
                for check in checks
                    nexts = [nexts; find(netdata[:nextpt] .== check)]
                end

                checks = nexts
            end
        else
            includeds[draws[:source]] = true
        end

        # Clean out the source column, so these no longer have meaning!
        draws[:source] = nothing
    else
        includeds = trues(nrow(netdata))
    end

    wateridverts = Dict{UTF8String, ExVertex}();
    waternet = empty_extnetwork();
    for row in 1:nrow(netdata)
        if !includeds[row]
            continue
        end

        println(row)
        nextpt = netdata[row, :nextpt]
        if isna(nextpt)
            continue
        end

        thisid = "$(netdata[row, :collection]).$(netdata[row, :colid])"
        nextid = "$(netdata[nextpt, :collection]).$(netdata[nextpt, :colid])"

        if thisid == nextid
            error("Same same!")
        end

        if thisid in keys(wateridverts) && nextid in keys(wateridverts) &&
            wateridverts[nextid] in out_neighbors(wateridverts[thisid], waternet)
            # error("No backsies!")
            continue
        end

        if !(thisid in keys(wateridverts))
            wateridverts[thisid] = ExVertex(length(wateridverts)+1, thisid)
            add_vertex!(waternet, wateridverts[thisid])
        end

        if !(nextid in keys(wateridverts))
            wateridverts[nextid] = ExVertex(length(wateridverts)+1, nextid)
            add_vertex!(waternet, wateridverts[nextid])
        end

        add_edge!(waternet, wateridverts[nextid], wateridverts[thisid])

        #if test_cyclic_by_dfs(waternet)
        #    error("Cycles off the road!")
        #end
    end

    # Construct the network
    serialize(open("../data/waternet$suffix.jld", "w"), waternet)
    serialize(open("../data/wateridverts$suffix.jld", "w"), wateridverts)
    serialize(open("../data/waterdraws$suffix.jld", "w"), draws)
end

# Prepare the model
downstreamorder = topological_sort_by_dfs(waternet)[end:-1:1];

