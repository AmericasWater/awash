## Water Network Component
#
# Determines how flows added and removed from the network propogate
# through.

# Requires `addeds` from weather.jl

using Mimi

@defcomp WaterNetwork begin
    gauges = Index()
    scenarios = Index()

    # External
    added = Parameter(index=[gauges, scenarios, time], unit="1000 m^3") # Water added at node from runoff
    removed = Parameter(index=[gauges, scenarios, time], unit="1000 m^3") # Water removed from node
    returned = Parameter(index=[gauges, scenarios, time], unit="1000 m^3") # Water returns to a node from canals

    inflows = Variable(index=[gauges, scenarios, time], unit="1000 m^3") # Sum of upstream outflows
    outflows = Variable(index=[gauges, scenarios, time], unit="1000 m^3") # inflow + added - removed + returned
    unmodifieds = Variable(index=[gauges, scenarios, time], unit="1000 m^3") # Sum of upstream unmodifieds + added
end

"""
Compute the inflows and outflows at each node
"""
function run_timestep(c::WaterNetwork, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for hh in d.gauges
        gg = vertex_index(downstreamorder[hh])
        gauge = downstreamorder[hh].label
        allflow = zeros(numscenarios)
        unmodified = zeros(numscenarios)
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            allflow += v.outflows[vertex_index(upstream, waternet), :, tt]
            unmodified += v.unmodifieds[vertex_index(upstream, waternet), :, tt]
        end

        v.inflows[gg, :, tt] = allflow
        v.outflows[gg, :, tt] = allflow + p.added[gg, :, tt] - p.removed[gg, :, tt] + p.returned[gg, :, tt]
        v.unmodifieds[gg, :, tt] = unmodified + p.added[gg, :, tt]
    end
end

function initwaternetwork(m::Model)
    waternetwork = addcomponent(m, WaterNetwork)

    # addeds loaded by weather.jl
    waternetwork[:added] = addeds[:, :, 1:numsteps]
    waternetwork[:removed] = zeros(numgauges, numscenarios, numsteps)
    waternetwork[:returned] = zeros(numgauges, numscenarios, numsteps)

    waternetwork
end

function matrix_gauges_canals(A::Matrix{Float64}, canal_values::Vector{Float64})
    # Fill in GAUGES x CANALS matrix with local relationships
    for pp in 1:nrow(draws)
        gaugeid = draws[pp, :gaugeid]
        vertex = get(wateridverts, gaugeid, nothing)
        if vertex == nothing
            println("Missing $gaugeid")
        else
            gg = vertex_index(vertex)
            A[gg, pp] = canal_values[pp]
        end
    end
end

function matrix_downstreamgauges_canals(A::Matrix{Float64})
    # Propogate in downstream order
    for hh in 1:numgauges
        gg = vertex_index(downstreamorder[hh])
        gauge = downstreamorder[hh].label
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            index = vertex_index(upstream, waternet)
            A[gg, :] += A[index, :]
        end
    end
end

"""
Construct a matrix that represents the *immediate* decrease in outflow caused by withdrawal
"""
function grad_waternetwork_immediateoutflows_withdrawals(m::Model)
    function generate(A)
        matrix_gauges_canals(A, -ones(nrow(draws)))
    end

    roomintersect(m, :WaterNetwork, :outflows, :Allocation, :withdrawals, generate, [:scenarios, :time], [:scenarios, :time])
end

"""
Construct a matrix that represents the decrease in outflow caused by withdrawal
"""
function grad_waternetwork_outflows_withdrawals(m::Model)
    function generate(A)
        matrix_gauges_canals(A, -ones(nrow(draws)))
        matrix_downstreamgauges_canals(A)
    end

    roomintersect(m, :WaterNetwork, :outflows, :Allocation, :withdrawals, generate, [:scenarios, :time], [:scenarios, :time])
end

function grad_waternetwork_antiwithdrawals_precipitation(m::Model)
    function generate(A)
        # Fill in CANALS x REGIONS
        # Determine how many canals are in this region
        for rr in 1:numcounties
            fips = parse(Int64, masterregions[rr, :fips])
            thiscanals = find(draws[:fips] .== fips)
            for pp in 1:length(thiscanals)
                A[thiscanals[pp], rr] = countyarea[rr] / 100.
            end
        end
    end

    roomintersect(m, :WaterNetwork, :precipitation, :withdrawals, generate, [:scenarios, :time], [:scenarios, :time])
end

"""
Construct a vector of maximum outflows, as the sum downstream of all contributing runoff.
"""
function constraintoffset_waternetwork_outflows(m::Model)
    b = copy(addeds) # Start with direct added

    # Propogate in downstream order
    for hh in 1:numgauges
        gg = vertex_index(downstreamorder[hh])
        gauge = downstreamorder[hh].label
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            b[gg, :, :] += b[vertex_index(upstream, waternet), :, :]
        end
    end

    generate = get(config, "proportionnaturalflowforenvironment", nothing) == nothing ? (gg, ss, tt) -> b[gg, ss, tt] : (gg, ss, tt) -> (1-config["proportionnaturalflowforenvironment"])*b[gg, ss, tt]

    hallsingle(m, :WaterNetwork, :outflows, generate)
end
