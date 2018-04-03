# The Return Flows component
#
# Handles the mapping between gauges and canals, on both the
# withdrawal and return sides.
#
# Currently the return side of the Return Flows is not impelemented.

using Mimi

@defcomp ReturnFlows begin
    canals = Index()
    scenarios = Index()

    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, scenarios, time], unit="1000 m^3")
    # How much is returned through canals (assuming 2-way canals!)
    returns = Parameter(index=[canals, scenarios, time], unit="1000 m^3")

    # For now, exact copy of withdrawals; later, the amount actually provided for each withdrawal?
    copy_withdrawals = Variable(index=[canals, scenarios, time], unit="1000 m^3")
    # Water removed from gauge
    removed = Variable(index=[gauges, scenarios, time], unit="1000 m^3")
    # Water returned to gauge
    returned = Variable(index=[gauges, scenarios, time], unit="1000 m^3")
end

function run_timestep(c::ReturnFlows, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for gg in 1:numgauges
        v.removed[gg, :, tt] = 0.
        v.returned[gg, :, tt] = 0.
    end

    for ss in 1:numscenarios
        for pp in 1:nrow(draws)
            v.copy_withdrawals[pp, ss, tt] = p.withdrawals[pp, ss, tt]
            if p.withdrawals[pp, ss, tt] > 0 || p.returns[pp, ss, tt] > 0
                gaugeid = draws[pp, :gaugeid]
                vertex = get(wateridverts, gaugeid, nothing)
                if vertex == nothing
                    println("Missing $gaugeid")
                else
                    gg = vertex_index(vertex)
                    v.removed[gg, ss, tt] += p.withdrawals[pp, ss, tt]
                    v.returned[gg, ss, tt] += p.returns[pp, ss, tt]
                end
            end
        end
    end
end

"""
Add a ReturnFlows component to the model.
"""
function initreturnflows(m::Model)
    returnflows = addcomponent(m, ReturnFlows);

    returnflows[:withdrawals] = zeros(m.indices_counts[:canals], numscenarios, m.indices_counts[:time])
    returnflows[:returns] = zeros(m.indices_counts[:canals], numscenarios, m.indices_counts[:time])

    returnflows
end
