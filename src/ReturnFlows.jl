# Return Flows Component
#
# Return flows are defined as a given proportion of the withdrawals
# applied to each county.  Under optimization, withdrawals determine
# the amount and location of returns, as just down-stream of the
# withdrawal canal.
#
# Currently the return side of the Return Flows is not impelemented in
# simulation.

using Mimi

@defcomp ReturnFlows begin
    canals = Index()

    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, time], unit="1000 m^3")
    # Return rate by canal
    returnrate = Parameter(index=[canals], unit="fraction")

    # For now, exact copy of withdrawals; later, the amount actually provided for each withdrawal?
    copy_withdrawals = Variable(index=[canals, time], unit="1000 m^3")
    # Water removed from gauge
    removed = Variable(index=[gauges, time], unit="1000 m^3")
    # Water returned to gauge
    returned = Variable(index=[gauges, time], unit="1000 m^3")
end

function run_timestep(c::ReturnFlows, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for gg in 1:numgauges
        v.removed[gg, tt] = 0.
        v.returned[gg, tt] = 0.
    end

    for pp in 1:nrow(draws)
        v.copy_withdrawals[pp, tt] = p.withdrawals[pp, tt]
        if p.withdrawals[pp, tt] > 0
            gaugeid = draws[pp, :gaugeid]
            vertex = get(wateridverts, gaugeid, nothing)
            if vertex == nothing
                println("Missing $gaugeid")
            else
                gg = vertex_index(vertex)
                v.removed[gg, tt] += p.withdrawals[pp, tt]
            end
        end
    end

    # Propogate in downstream order
    for hh in 1:numgauges
        gg = vertex_index(downstreamorder[hh])
        gauge = downstreamorder[hh].label
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            index = vertex_index(upstream, waternet)
            v.returned[gg, tt] += p.returnrate[index] * v.removed[index, tt]
        end
    end
end

"""
Add a ReturnFlows component to the model.
"""
function initreturnflows(m::Model, includegw::Bool, demandmodel::Union{Model, Void}=nothing)
    returnflows = addcomponent(m, ReturnFlows);

    returnflows[:withdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
    # Calculate return flows from withdrawals
    returnflows[:returnrate] = vector_canalreturns(m, includegw, demandmodel)

    returnflows
end


"""
Construct the return flow rate based on observed sector-specific demands
"""
function vector_canalreturns(m::Model, includegw::Bool, demandmodel::Union{Model, Void}=nothing)
    # Expected returns by county: sum of (RTxRT * RT)
    expectedreturns = grad_waterdemand_totalreturn_totalirrigation(m) * values_waterdemand_recordedirrigation(m, includegw, demandmodel) +
        grad_waterdemand_totalreturn_domesticuse(m) * values_waterdemand_recordeddomestic(m) +
        grad_waterdemand_totalreturn_industrialuse(m) * values_waterdemand_recordedindustrial(m) +
        grad_waterdemand_totalreturn_thermoelectricuse(m) * values_waterdemand_recordedthermoelectric(m) +
        grad_waterdemand_totalreturn_livestockuse(m) * values_waterdemand_recordedlivestock(m)
    # Expected withdrawals by county: sum of RT
    expectedwithdrawals = values_waterdemand_recordedirrigation(m, includegw, demandmodel).x +
        values_waterdemand_recordeddomestic(m).x + values_waterdemand_recordedindustrial(m).x +
        values_waterdemand_recordedthermoelectric(m).x + values_waterdemand_recordedlivestock(m).x

    # Return portion by county
    regionreturns = expectedreturns.f ./ expectedwithdrawals

    # Rearrange to canals
    canalreturns = zeros(nrow(draws))
    if :justif in names(draws)
        for pp in 1:nrow(draws)
            if draws[pp, :justif] == "contains"
                regionid = regionindex(draws, pp)
                rr = findfirst(regionindex(masterregions, :) .== regionid)
                if rr > 0
                    canalreturns[pp] = regionreturns[rr]
                end
            end
        end
    else
        for pp in 1:nrow(draws)
            regionid = regionindex(draws, pp)
            rr = findfirst(regionindex(masterregions, :) .== regionid)
            if rr > 0
                canalreturns[pp] = regionreturns[rr]
            end
        end
    end

    canalreturns
end

"""
Construct a matrix that represents the decrease in outflow caused by withdrawal
"""
function grad_returnflows_outflows_withdrawals(m::Model, includegw::Bool, demandmodel::Union{Model, Void}=nothing)
    canalreturns = vector_canalreturns(m, includegw, demandmodel)

    # Construct room
    function generate(A)
        matrix_gauges_canals(A, canalreturns)
        immediateA = copy(A)

        matrix_downstreamgauges_canals(A)

        A -= immediateA
    end

    roomintersect(m, :WaterNetwork, :outflows, :Allocation, :withdrawals, generate, [:time], [:time])
end
