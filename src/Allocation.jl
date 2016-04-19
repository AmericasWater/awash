using Mimi
using Distributions

@defcomp Allocation begin
    regions = Index()

    # Water demand
    waterdemand = Parameter(index=[regions, time])

    # Extracted water (m3) to be set by optimisation - super source represents failure.
    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, time])

    # How much is taking from groundwater
    waterfromgw = Parameter(index=[regions, time])
    waterfromreservoir = Parameter(index=[regions,time])
    waterfromsupersource = Parameter(index=[regions,time])
    watergw = Variable(index=[regions, time])
    waterreservoir = Variable(index=[regions,time])

    # Unit costs ($/m3)
    # The cost in USD / m^3 of pumping
    costfromgw = Parameter(index=[regions,time])
    costfromreservoir = Parameter(index=[regions,time])
    costfromsupersource = Parameter()

    # Total cost and volumes for each county
    # The cost to pump it (USD)
    cost = Variable(index=[regions, time])

    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time])

    # Amount available from all sources
    waterallocated = Variable(index=[regions,time])

    # Difference between waterallocated and waterdemand
    balance = Variable(index=[regions, time])
end

"""
Sums the water from various sources and computes the cost
"""
function timestep(c::Allocation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    # Surface water calculations
    v.swsupply[:, tt] = zeros(numcounties)
    for pp in 1:nrow(draws)
        fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
        rr = findfirst(names .== fips)
        if rr > 0
            v.swsupply[rr, tt] += p.withdrawals[pp, tt]
        end
    end

    for cty in d.regions
        #v.waterfromSuperSource[cty,tt]= p.waterdemand[cty,tt] - (p.waterfromGW[cty,tt]+p.waterfromreservoir[cty,tt])
        v.watergw[cty,tt] = p.waterfromgw[cty,tt]
        v.waterreservoir[cty,tt] = p.waterfromreservoir[cty,tt]
        v.waterallocated[cty,tt] = p.waterfromgw[cty,tt]+p.waterfromreservoir[cty,tt]+p.waterfromsupersource[cty,tt] + v.swsupply[cty, tt]
        v.cost[cty, tt] = p.waterfromgw[cty,tt]*p.costfromgw[cty,tt] + p.waterfromreservoir[cty,tt]*p.costfromreservoir[cty,tt] + p.waterfromsupersource[cty,tt]*p.costfromsupersource

        v.balance[cty, tt] = v.waterallocated[cty, tt] - p.waterdemand[cty, tt]
    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    allocation = addcomponent(m, Allocation)
    # Use random demands, from a LogNormal distribution and constant across all
    # time.
    Adem = rand(Normal(5e4, 1e3), m.indices_counts[:regions]*m.indices_counts[:time]);
    allocation[:waterdemand] = reshape(Adem,m.indices_counts[:regions],m.indices_counts[:time]);
    #demand[:waterdemand] = repeat(rand(LogNormal(log(1000.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);

    # From http://www.oecd.org/unitedstates/45016437.pdf
    # Varies between 6.78 to 140 USD / 1000 m^3
    allocation[:costfromgw] = (100. / 1000.) * ones(m.indices_counts[:regions], m.indices_counts[:time]) #(1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromreservoir] = (1/100)*repeat(rand(Normal(35, 3), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromsupersource] = 100.0;

    allocation[:withdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:time])

    allocation[:waterfromgw] = repeat(0*rand(LogNormal(log(50.0), log(10.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromreservoir] = repeat(0*rand(LogNormal(log(300.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromsupersource] = repeat(0*rand(LogNormal(log(500.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation
end

"""
The objective is to minimize water allocation costs at all time
"""
function waterallocationobj(m::Model)
    -sum(m.components[:Allocation].Variables.cost)
end

function makeconstraintdemandmet(aa, tt)
    # The constraint function
    function constraint(model)
       m.components[:Allocation].Parameters.waterdemand[aa,tt] - m.components[:Allocation].Variables.waterallocated[aa,tt]
    end
end

function soleobjective_allocation(m::Model)
    sum(model[:Allocation, :cost])
end

function grad_allocation_swbalance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :swbalance, :waterfromgw, (rr, tt) -> 1.)
end

function grad_allocation_cost_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromgw, (rr, tt) -> 100. / 1000.)
end

function grad_allocation_swbalance_withdrawals(m::Model)
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

    roomintersect(m, :Allocation, :swbalance, :withdrawals, generate)
end
