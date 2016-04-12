# The Water Network component
#
# Determines how flows added and removed from the network propogate through.

using Mimi

@defcomp WaterNetwork begin
    gauges = Index()

    # External
    added = Parameter(index=[gauges, time]) # Water added at node <- currently just runoff
    removed = Parameter(index=[gauges, time]) # Water removed from node

    inflows = Variable(index=[gauges, time]) # Sum of upstream outflows
    outflows = Variable(index=[gauges, time]) # inflow + added - removed
end

"""
Compute the inflows and outflows at each node
"""
function timestep(c::WaterNetwork, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for hh in d.gauges
        gg = vertex_index(downstreamorder[hh])
        gauge = downstreamorder[hh].label
        println("Process $gauge at $gg")
        allflow = 0.
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            allflow += v.outflows[vertex_index(upstream, waternet), tt]
            println(allflow)
        end

        v.inflows[gg, tt] = allflow
        v.outflows[gg, tt] = allflow + p.added[gg, tt] - p.removed[gg, tt]
    end
end

function initwaternetwork(m::Model)
    waternetwork = addcomponent(m, WaterNetwork)

    # addeds loaded by weather.jl

    waternetwork[:added] = addeds[:, 1:numsteps]

    waternetwork
end

function grad_waternetwork_withdrawals_outflows(m::Model)
    waternetdata = read_rda("../data/waternet.RData", convertdataframes=true);
    netdata = waternetdata["network"];

    function generate(A, tt)
        # Fill in GAUGES x CANALS matrix
        # First do locals
        for pp in 1:nrow(draws)
            gaugeid = draws[pp, :gaugeid]
            gg = findfirst(collect(keys(wateridverts)) .== gaugeid)
            if (gg == 0)
                println("Missing $gaugeid")
            else
                A[gg, pp] = -1.
            end
        end

        # Propogate in downstream order
        for hh in 1:numgauges
            gg = vertex_index(downstreamorder[hh])
            println(gg)
            gauge = downstreamorder[hh].label
            for upstream in out_neighbors(wateridverts[gauge], waternet)
                A[gg, :] += A[vertex_index(upstream, waternet), :]
            end
        end
    end

    roomintersect(m, :WaterNetwork, :outflows, :withdrawals, generate)
end

function grad_waternetwork_precipitation_antiwithdrawals(m::Model)
    function generate(A, tt)
        # Fill in CANALS x REGIONS
        # Determine how many canals are in this region
        for rr in 1:numcounties
            fips = parse(Int64, names[rr])
            thiscanals = find(draws[:fips] .== fips)
            for pp in 1:length(thiscanals)
                A[thiscanals[pp], rr] = countyarea[rr] / 100.
            end
        end
    end

    roomintersect(m, :WaterNetwork, :precipitation, :withdrawals, generate)
end

function constraintoffset_waternetwork_runoff(m::Model)
    b = copy(addeds) # Start with direct added

    # Propogate in downstream order
    for hh in 1:numgauges
        #println(maximum(b))
        gg = vertex_index(downstreamorder[hh])
        println(gg)
        gauge = downstreamorder[hh].label
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            b[gg, :] += b[vertex_index(upstream, waternet), :]
        end
    end

    function generate(gg, tt)
        # Determine number of gauges in county
        b[gg, tt]
    end

    hallsingle(m, :WaterNetwork, :outflows, generate)
end

