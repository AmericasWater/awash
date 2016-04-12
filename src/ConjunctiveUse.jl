# The conjunctiveuse component
#
# Combines all of the sources of water demand, and determines the
# conjunctive use division between surface water and groundwater.

using Mimi
using DataFrames

@defcomp ConjunctiveUse begin
    regions = Index()

    # External
    # Irrigation water (1000 m^3)
    totalirrigation = Parameter(index=[regions, time])
    # Combined water use for domestic sinks (1000 m^3)
    domesticuse = Parameter(index=[regions, time])

    # Optimized
    # How much is taking from groundwater
    pumping = Parameter(index=[regions, time])
    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, time])

    # Internal
    # The cost in USD / 1000m^3 of pumping
    cost_pumping = Parameter(index=[regions, time])

    # Total water demand (1000 m^3)
    totaldemand = Variable(index=[regions, time])
    # Portion from surface water, in 1000 m^3
    swdemand = Variable(index=[regions, time])
    # Groundwater to pump, in 1000 m^3
    gwdemand = Variable(index=[regions, time])

    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time])
    # Difference between swsupply and swdemand
    swbalance = Variable(index=[regions, time])

    # The cost to pump it (USD)
    pumpingcost = Variable(index=[regions, time])
end

"""
Compute the amount extracted and the cost for doing it.
"""
function timestep(c::ConjunctiveUse, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        # Sum all demands
        v.totaldemand[rr, tt] = p.totalirrigation[rr, tt] + p.domesticuse[rr, tt]

        # Split into surface and groundwater
        v.gwdemand[rr, tt] = v.pumping[rr, tt]
        v.swdemand[rr, tt] = v.totaldemand[rr, tt] - p.pumping[rr, tt]

        # Total cost is pumping * cost-per-unit
        v.pumpingcost[rr, tt] = v.gwdemand[rr, tt] * p.cost_pumping[rr, tt]
    end
end

"""
Add a conjunctiveuse component to the model.
"""
function initconjunctiveuse(m::Model)
    conjunctiveuse = addcomponent(m, ConjunctiveUse);

    # From http://www.oecd.org/unitedstates/45016437.pdf
    # Varies between 6.78 to 140 USD / 1000 m^3
    conjunctiveuse[:cost_pumping] = 100. * ones(m.indices_counts[:regions], m.indices_counts[:time])

    # Set optimized parameters to 0
    conjunctiveuse[:pumping] = zeros(m.indices_counts[:regions], m.indices_counts[:time])
    conjunctiveuse[:withdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:time])
    conjunctiveuse[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time])

    conjunctiveuse
end

function soleobjective_conjunctiveuse(m::Model)
    sum(model[:ConjunctiveUse, :pumpingcost])
end

function grad_conjunctiveuse_totalirrigation_swbalance(m::Model)
    roomdiagonal(m, :ConjunctiveUse, :swbalance, :totalirrigation, (rr, tt) -> 1.)
end

function grad_conjunctiveuse_pumping_swbalance(m::Model)
    roomdiagonal(m, :ConjunctiveUse, :swbalance, :pumping, (rr, tt) -> 1.)
end

function grad_conjunctiveuse_withdrawals_swbalance(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
            rr = findfirst(names .== fips)
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :ConjunctiveUse, :swbalance, :withdrawals, generate)
end

function grad_conjunctiveuse_pumping_cost(m::Model)
    roomdiagonal(m, :ConjunctiveUse, :pumpingcost, :pumping, (rr, tt) -> 100.)
end

