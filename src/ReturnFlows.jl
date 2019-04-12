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
using OptiMimi

@defcomp ReturnFlows begin
    canals = Index()
    scenarios = Index()

    # How much to send from each gauge to each county
    swwithdrawals = Parameter(index=[canals, scenarios, time], unit="1000 m^3")
    # Return rate by canal
    returnrate = Parameter(index=[canals], unit="fraction")

    # For now, exact copy of withdrawals; later, the amount actually provided for each withdrawal?
    copy_swwithdrawals = Variable(index=[canals, scenarios, time], unit="1000 m^3")
    # Water removed from gauge
    removed = Variable(index=[gauges, scenarios, time], unit="1000 m^3")
    # Water returned to gauge
    returned = Variable(index=[gauges, scenarios, time], unit="1000 m^3")

    function run_timestep(p, v, d, t)
        for gg in 1:numgauges
            v.removed[gg, :, tt] .= 0.
            v.returned[gg, :, tt] .= 0.
        end

        for ss in 1:numscenarios
            for pp in 1:nrow(draws)
                v.copy_swwithdrawals[pp, ss, tt] = p.swwithdrawals[pp, ss, tt]
                if p.swwithdrawals[pp, ss, tt] > 0
                    gaugeid = draws[pp, :gaugeid]
                    vertex = get(wateridverts, gaugeid, nothing)
                    if vertex == nothing
                        println("Missing $gaugeid")
                    else
                        gg = vertex_index(vertex)
                        v.removed[gg, ss, tt] += p.swwithdrawals[pp, ss, tt]
                    end
                end
            end
        end

        # Propogate in downstream order
        for hh in 1:numgauges
            gg = vertex_index(downstreamorder[hh])
            gauge = downstreamorder[hh].label
            for upstream in out_neighbors(wateridverts[gauge], waternet)
                index = vertex_index(upstream, waternet)
                v.returned[gg, :, tt] += p.returnrate[index] * v.removed[index, :, tt]
            end
        end
    end
end

"""
Add a ReturnFlows component to the model.
"""
function initreturnflows(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    returnflows = add_comp!(m, ReturnFlows);

    returnflows[:swwithdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], numscenarios, m.indices_counts[:time]))
    # Calculate return flows from withdrawals
    returnflows[:returnrate] = vector_canalreturns(m, includegw, demandmodel)

    returnflows
end


"""
Construct the return flow rate based on observed sector-specific demands
"""
function vector_canalreturns(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    # Expected returns by county: sum of (RSTxRST * RST)
    expectedreturns = grad_waterdemand_totalreturn_totalirrigation(m) * values_waterdemand_recordedirrigation(m, includegw, demandmodel) +
        grad_waterdemand_totalreturn_domesticuse(m) * values_waterdemand_recordeddomestic(m) +
        grad_waterdemand_totalreturn_industrialuse(m) * values_waterdemand_recordedindustrial(m) +
        grad_waterdemand_totalreturn_thermoelectricuse(m) * values_waterdemand_recordedthermoelectric(m) +
        grad_waterdemand_totalreturn_livestockuse(m) * values_waterdemand_recordedlivestock(m)
    # Expected withdrawals by county: sum of RST
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
                if rr != nothing
                    canalreturns[pp] = regionreturns[rr]
                end
            end
        end
    else
        for pp in 1:nrow(draws)
            regionid = regionindex(draws, pp)
            rr = findfirst(regionindex(masterregions, :) .== regionid)
            if rr != nothing
                canalreturns[pp] = regionreturns[rr]
            end
        end
    end

    canalreturns
end

"""
Construct a matrix that represents the decrease in outflow caused by withdrawal
"""
function grad_returnflows_outflows_swwithdrawals(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    canalreturns = vector_canalreturns(m, includegw, demandmodel)

    # Construct room
    function generate(A)
        matrix_gauges_canals(A, canalreturns)
        immediateA = copy(A)

        matrix_downstreamgauges_canals(A)

        for ii in eachindex(A)
            A[ii] -= immediateA[ii]
        end
    end

    roomintersect(m, :WaterNetwork, :outflows, :Allocation, :swwithdrawals, generate, [:scenarios, :time], [:scenarios, :time])
end
