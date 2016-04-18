# The Return Flows component
#
# Handles the mapping between gauges and canals, on both the
# withdrawal and return sides.
#
# Currently the return side of the Return Flows is not impelemented.

using Mimi

@defcomp ReturnFlows begin
    canals = Index()

    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, time])

    # For now, exact copy of withdrawals; later, the amount actually provided for each withdrawal?
    copy_withdrawals = Variable(index=[canals, time])
    # Water removed from gauge
    removed = Variable(index=[gauges, time])
end

function timestep(c::ReturnFlows, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for gg in 1:numgauges
        v.removed[gg, tt] = 0.
    end

    for pp in 1:nrow(draws)
        v.copy_withdrawals[pp, tt] = p.withdrawals[pp, tt]
        if p.withdrawals[pp, tt] > 0
            gaugeid = draws[pp, :gaugeid]
            gg = findfirst(collect(keys(wateridverts)) .== gaugeid)
            if (gg == 0)
                println("Missing $gaugeid")
            else
                v.removed[gg, tt] += p.withdrawals[pp, tt]
            end
        end
    end
end

"""
Add a ReturnFlows component to the model.
"""
function initreturnflows(m::Model)
    returnflows = addcomponent(m, ReturnFlows);

    returnflows[:withdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:time])

    returnflows
end
