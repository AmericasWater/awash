using Mimi
using Distributions

include("lib/datastore.jl")

@defcomp Allocation begin
    regions = Index()

    # Water demand aggregated accross all sectors
    watertotaldemand = Parameter(index=[regions, time], unit="1000 m^3")
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

    # Extracted water (1000 m3) to be set by optimisation - super source represents failure.
    waterfromgw = Parameter(index=[regions, time], unit="1000 m^3")
    waterfromreservoir = Parameter(index=[regions,time], unit="1000 m^3")
    waterfromsupersource = Parameter(index=[regions,time], unit="1000 m^3")
    watergw = Variable(index=[regions, time], unit="1000 m^3")
    waterreservoir = Variable(index=[regions,time], unit="1000 m^3")
    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, time], unit="1000 m^3")
    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time], unit="1000 m^3")

    # The cost in USD / 1000 m^3 of extraction and treatment cost
    costfromgw = Parameter(index=[regions,time], unit="\$/1000 m^3")
    costfromsw = Parameter(index=[regions,time], unit="\$/1000 m^3")
    costfromsupersource = Parameter(unit="\$/1000 m^3")

    # Total cost for eachs county
    cost = Variable(index=[regions, time], "\$")

    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time], unit="1000 m^3")
    # Combination across all canals routing return flow from the counties
    swreturn = Variable(index=[regions, time], unit="1000 m^3")

    # Amount available from all sources
    waterallocated = Variable(index=[regions,time], unit="1000 m^3")

    # Difference between waterallocated and watertotaldemand
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
    println(size(p.withdrawals))

    v.swsupply[:, tt] = zeros(numcounties)
    v.swreturn[:, tt] = zeros(numcounties)
    for pp in 1:nrow(draws)
        fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
        rr = findfirst(mastercounties[:fips] .== fips)
        if rr > 0
            println("A")
            v.swsupply[rr, tt] += p.withdrawals[pp, tt]
            v.swreturn[rr, tt] += p.returns[pp, tt]
        end
        println("B")
        v.copy_withdrawals[pp, tt] = p.withdrawals[pp, tt]
        v.copy_returns[pp, tt] = p.returns[pp, tt]
        println("C")
    end

    for rr in d.regions
        v.watergw[rr,tt] = p.waterfromgw[rr,tt]
        v.waterreservoir[rr,tt] = p.waterfromreservoir[rr,tt]
        v.waterallocated[rr,tt] = p.waterfromgw[rr,tt]+p.waterfromreservoir[rr,tt]+p.waterfromsupersource[rr,tt] + v.swsupply[rr, tt]
        v.cost[rr, tt] = p.waterfromgw[rr,tt]*p.costfromgw[rr,tt] + (p.waterfromreservoir[rr,tt] + v.swsupply[rr,tt])*p.costfromsw[rr,tt] + p.waterfromsupersource[rr,tt]*p.costfromsupersource

        v.balance[rr, tt] = v.waterallocated[rr, tt] - p.watertotaldemand[rr, tt]
        v.returnbalance[rr, tt] = v.swreturn[rr, tt] - p.waterreturn[rr, tt]
    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    allocation = addcomponent(m, Allocation);
    allocation[:watertotaldemand] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    allocation[:costfromgw] = 100. * ones(m.indices_counts[:regions], m.indices_counts[:time]) #(1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromsw] = 10. * repeat(rand(Normal(35, 3), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromsupersource] = 100000.0;

    # Check if there are saved withdrawals and return flows (from optimize-surface)
    allocation[:withdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
    allocation[:returns] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))

    mingw=readdlm("../data/demand/MIWGWFr.txt");
    indgw=readdlm("../data/demand/INWGWFr.txt");
    psgw=readdlm("../data/demand/PSWGWFr.txt");
    minsw=readdlm("../data/demand/MIWSWFr.txt");
    indsw=readdlm("../data/demand/INWSWFr.txt");
    pssw=readdlm("../data/demand/PSWSWFr.txt");

    allocation[:waterfromgw] = mingw + indgw + psgw;
    allocation[:waterfromreservoir] = minsw + indsw + pssw;
    allocation[:waterfromsupersource] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
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
       m.components[:Allocation].Parameters.watertotaldemand[aa,tt] - m.components[:Allocation].Variables.waterallocated[aa,tt]
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
