using Mimi
using Distributions

@defcomp Allocation begin
    regions = Index()

    # Water demand
    waterdemand = Parameter(index=[regions, time], unit="1000 m^3")
    # Water return flows
    waterreturn = Parameter(index=[regions, time], unit="1000 m^3")

    # Extracted water and returned water set by optimisation
    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, time], unit="1000 m^3")
    # How much is returned to each withdrawal source?
    returns = Parameter(index=[canals, time], unit="1000 m^3")

    # For now, exact copy of withdrawals; later, the amount actually provided for each withdrawal?
    copy_withdrawals = Variable(index=[canals, time], unit="1000 m^3")
    # For now, exact copy of returns; later, the amount actually returned?
    copy_returns = Variable(index=[canals, time], unit="1000 m^3")

    # How much is taking from groundwater
    waterfromgw = Parameter(index=[regions, time], unit="1000 m^3")
    waterfromreservoir = Parameter(index=[regions,time], unit="1000 m^3")
    waterfromsupersource = Parameter(index=[regions,time], unit="1000 m^3")
    watergw = Variable(index=[regions, time], unit="1000 m^3")
    waterreservoir = Variable(index=[regions,time], unit="1000 m^3")

    # Unit costs ($/m3)
    # The cost in USD / 1000 m^3 of pumping
    costfromgw = Parameter(index=[regions,time], unit="\$/1000 m^3")
    costfromreservoir = Parameter(index=[regions,time], unit="\$/1000 m^3")
    costfromsupersource = Parameter(unit="\$/1000 m^3")

    # Total cost and volumes for each county
    # The cost to pump it (USD)
    cost = Variable(index=[regions, time], "\$")

    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time], unit="1000 m^3")
    # Combination across all canals routing return flow from the counties
    swreturn = Variable(index=[regions, time], unit="1000 m^3")

    # Amount available from all sources
    waterallocated = Variable(index=[regions, time], unit="1000 m^3")

    # Difference between waterallocated and waterdemand: should be >= 0
    balance = Variable(index=[regions, time], unit="1000 m^3")
    # Difference between swreturn and waterreturn: should be <= 0
    returnbalance = Variable(index=[regions, time], unit="1000 m^3")
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
    v.swreturn[:, tt] = zeros(numcounties)
    for pp in 1:nrow(draws)
        fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
        rr = findfirst(mastercounties[:fips] .== fips)
        if rr > 0
            v.swsupply[rr, tt] += p.withdrawals[pp, tt]
            v.swreturn[rr, tt] += p.returns[pp, tt]
        end
        v.copy_withdrawals[pp, tt] = p.withdrawals[pp, tt]
        v.copy_returns[pp, tt] = p.returns[pp, tt]
    end

    for cty in d.regions
        #v.waterfromSuperSource[cty,tt]= p.waterdemand[cty,tt] - (p.waterfromGW[cty,tt]+p.waterfromreservoir[cty,tt])
        v.watergw[cty,tt] = p.waterfromgw[cty,tt]
        v.waterreservoir[cty,tt] = p.waterfromreservoir[cty,tt]
        v.waterallocated[cty,tt] = p.waterfromgw[cty,tt]+p.waterfromreservoir[cty,tt]+p.waterfromsupersource[cty,tt] + v.swsupply[cty, tt]
        v.cost[cty, tt] = p.waterfromgw[cty,tt]*p.costfromgw[cty,tt] + p.waterfromreservoir[cty,tt]*p.costfromreservoir[cty,tt] + p.waterfromsupersource[cty,tt]*p.costfromsupersource

        v.balance[cty, tt] = v.waterallocated[cty, tt] - p.waterdemand[cty, tt]
        v.returnbalance[cty, tt] = v.swreturn[cty, tt] - p.waterreturn[cty, tt]
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
    allocation[:waterdemand] = 1000. * reshape(Adem,m.indices_counts[:regions],m.indices_counts[:time]);
    #demand[:waterdemand] = repeat(rand(LogNormal(log(1000.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);

    # From http://www.oecd.org/unitedstates/45016437.pdf
    # Varies between 6.78 to 140 USD / 1000 m^3
    allocation[:costfromgw] = 100. * ones(m.indices_counts[:regions], m.indices_counts[:time]) #(1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromreservoir] = 10. * repeat(rand(Normal(35, 3), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromsupersource] = 100000.0;

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

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromgw, (rr, tt) -> 1.)
end

function grad_allocation_balance_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromsupersource, (rr, tt) -> 1.)
end

function grad_allocation_cost_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromgw, (rr, tt) -> 100. / 1000.)
end

function grad_allocation_cost_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromsupersource, (rr, tt) -> 1000.)
end

## Optional cost for drawing down a river (environmental change)
function grad_allocation_cost_withdrawals(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromsupersource, (cc, tt) -> .01)
end

function grad_allocation_balance_withdrawals(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
            rr = findfirst(mastercounties[:fips] .== fips)
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :balance, :withdrawals, generate)
end

function grad_allocation_returnbalance_returns(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
            rr = findfirst(mastercounties[:fips] .== fips)
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :returnbalance, :returns, generate)
end

function constraintoffset_allocation_recordedbalance(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = recorded[rr, :TO_SW] * 1382592. / 1000.
    hallsingle(m, :Allocation, :balance, gen)
end

function grad_allocation_returnbalance_waterreturn(m::Model)
    roomdiagonal(m, :Allocation, :returnbalance, :waterreturn, (rr, tt) -> 1.)
end
