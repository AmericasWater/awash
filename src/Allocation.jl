using Mimi
using Distributions

include("lib/datastore.jl")
include("lib/watercostdata.jl")

@defcomp Allocation begin
    regions = Index()
    scenario = Index()

    # Water demand aggregated accross all sectors
    watertotaldemand = Parameter(index=[regions, time], unit="1000 m^3")
    # Water return flows
    waterreturn = Parameter(index=[regions, scenario, time], unit="1000 m^3")

    # Extracted water and returned water set by optimisation
    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, scenario, time], unit="1000 m^3")
    # How much is returned to each withdrawal source?
    returns = Parameter(index=[canals, scenario, time], unit="1000 m^3")

    # For now, exact copy of withdrawals; later, the amount actually provided for each withdrawal?
    copy_withdrawals = Variable(index=[canals, scenario, time], unit="1000 m^3")
    # For now, exact copy of returns; later, the amount actually returned?
    copy_returns = Variable(index=[canals, scenario, time], unit="1000 m^3")

    # Extracted water (1000 m3) to be set by optimisation - super source represents failure.
    waterfromgw = Parameter(index=[regions, scenario, time], unit="1000 m^3")
    waterfromsupersource = Parameter(index=[regions, scenario, time], unit="1000 m^3")
    watergw = Variable(index=[regions, scenario, time], unit="1000 m^3")

    # The cost in USD / 1000 m^3 of extraction and treatment cost
    unitgwcost = Parameter(index=[regions, scenario, time], unit="\$/1000 m^3")
    unitswcost = Parameter(index=[canals, scenario, time], unit="\$/1000 m^3")
    unitsupercost = Parameter(unit="\$/1000 m^3")
    # Total cost for each county
    swcost = Variable(index=[regions, scenario, time], unit="\$")
    cost = Variable(index=[regions, scenario, time], unit="\$")

    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, scenario, time], unit="1000 m^3")
    # Combination across all canals routing return flow from the counties
    swreturn = Variable(index=[regions, scenario, time], unit="1000 m^3")
    # Amount available from all sources
    waterallocated = Variable(index=[regions, scenario, time], unit="1000 m^3")

    # Difference between waterallocated and watertotaldemand
    balance = Variable(index=[regions, scenario, time], unit="1000 m^3")
    # Difference between swreturn and waterreturn: should be <= 0
    returnbalance = Variable(index=[regions, scenario, time], unit="1000 m^3")
end

"""
Sums the water from various sources and computes the cost
"""
function run_timestep(c::Allocation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for ss in d.scenarios
        # Surface water calculations
        v.swsupply[:, ss, tt] = zeros(numcounties)
        v.swreturn[:, ss, tt] = zeros(numcounties)
        v.swcost[:, ss, tt] = zeros(numcounties)
        for pp in 1:nrow(draws)
            regionids = regionindex(draws, pp)
            rr = findfirst(regionindex(masterregions, :) .== regionids)
            if rr > 0
                v.swsupply[rr, ss, tt] += p.withdrawals[pp, ss, tt]
                v.swreturn[rr, ss, tt] += p.returns[pp, ss, tt]
                v.swcost[rr, ss, tt] += p.withdrawals[pp, ss, tt] * p.unitswcost[pp, ss, tt]
            end
            v.copy_withdrawals[pp, ss, tt] = p.withdrawals[pp, ss, tt]
            v.copy_returns[pp, ss, tt] = p.returns[pp, ss, tt]
        end

        for rr in d.regions
            v.watergw[rr, ss, tt] = p.waterfromgw[rr, ss, tt]
            v.waterallocated[rr, ss, tt] = p.waterfromgw[rr, ss, tt] + p.waterfromsupersource[rr, ss, tt] + v.swsupply[rr, ss, tt]
            v.cost[rr, ss, tt] = p.waterfromgw[rr, ss, tt]*p.unitgwcost[rr, ss, tt] + v.swcost[rr, ss, tt] + p.waterfromsupersource[rr, ss, tt]*p.unitsupercost
            v.balance[rr, ss, tt] = v.waterallocated[rr, ss, tt] - p.watertotaldemand[rr, tt]
            v.returnbalance[rr, ss, tt] = v.swreturn[rr, ss, tt] - p.waterreturn[rr, ss, tt]
        end
    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    allocation = addcomponent(m, Allocation);
    allocation[:watertotaldemand] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    # Check if there are saved withdrawals and return flows (from optimize-surface)

    allocation[:unitgwcost] = repeat(aquiferextractioncost, outer = [1, m.indices_counts[:scenario], m.indices_counts[:time]])+0.1;
    allocation[:unitswcost] = repeat(canalextractioncost, outer = [1, m.indices_counts[:scenario], m.indices_counts[:time]])+0.1;
    allocation[:unitsupercost] = 1e6
    if config["dataset"] == "three"
	allocation[:withdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:scenario], m.indices_counts[:time]);
    	allocation[:returns] = zeros(m.indices_counts[:canals], m.indices_counts[:scenario], m.indices_counts[:time]);
    	allocation[:waterfromgw] = zeros(m.indices_counts[:regions], m.indices_counts[:scenario], m.indices_counts[:time]);
    	allocation[:waterfromsupersource] = zeros(m.indices_counts[:regions], m.indices_counts[:scenario], m.indices_counts[:time]);
    else
        recorded = getfilteredtable("extraction/USGS-2010.csv")

	allocation[:withdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:scenario], m.indices_counts[:time]))
	allocation[:returns] = cached_fallback("extraction/returns", () -> zeros(m.indices_counts[:canals], m.indices_counts[:scenario], m.indices_counts[:time]))
	allocation[:waterfromgw] = cached_fallback("extraction/waterfromgw", () -> repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"], outer=[1, m.indices_counts[:scenario], m.indices_counts[:time]]))
    	allocation[:waterfromsupersource] = cached_fallback("extraction/supersource", () -> zeros(m.indices_counts[:regions], m.indices_counts[:scenario], m.indices_counts[:time]));
    end

    allocation
end

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromgw, 1.)
end

function grad_allocation_balance_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromsupersource, 1.)
end

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromgw, 1.)
end

function grad_allocation_cost_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromgw, (rr, tt) -> m.external_parameters[:unitgwcost].values[rr,tt])
end

function grad_allocation_cost_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromsupersource, 10000.)
end

function grad_allocation_cost_withdrawals(m::Model)
    @assert nrow(draws) == size(m.external_parameters[:unitswcost].values[:, 1])[1]

    function generate(A)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            println(pp)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr > 0
                A[rr, pp] = m.external_parameters[:unitswcost].values[pp, 1]
            end
        end
    end

    roomintersect(m, :Allocation, :cost, :withdrawals, generate, [:time], [:time])
end

function grad_allocation_balance_withdrawals(m::Model)
    function generate(A)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :balance, :withdrawals, generate, [:time], [:time])
end

function grad_allocation_returnbalance_returns(m::Model)
    function generate(A)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :returnbalance, :returns, generate, [:time], [:time])
end

function constraintoffset_allocation_recordedtotal(m::Model, includegw::Bool, demandmodel::Union{Model, Void}=nothing)
    if demandmodel == nothing
        constraintoffset_allocation_recordedbalance(m, includegw)
    else
        hallvalues(m, :Allocation, :balance, demandmodel[:WaterDemand, :totaldemand])
    end
end

function constraintoffset_allocation_recordedbalance(m::Model, optimtype)
    if config["dataset"] == "three"
	if optimtype == false
	    genuu(rr, tt) = 1. * (rr > 1)
	else
	    genuu(rr, tt) = 2. * (rr > 1)
	end
	hallsingle(m, :Allocation, :balance, genuu)
    else
        recorded = getfilteredtable("extraction/USGS-2010.csv")
	# MISSING HERE BREAKDOWN IN FUNCTION OF WHAT WE WANT TO OPTIMIZE
	gen(rr, tt) = config["timestep"] * (optimtype ? recorded[rr, :TO_To] : recorded[rr, :TO_SW]) * 1383. / 12
	hallsingle(m, :Allocation, :balance, gen)
    end
end

function grad_allocation_returnbalance_waterreturn(m::Model)
    roomdiagonal(m, :Allocation, :returnbalance, :waterreturn, 1.)
end

function constraintoffset_allocation_otherdemand(m::Model)
    other=readtable(datapath("other.csv"))
    gen(rr,tt)=other[rr,:x1]
    hallsingle(m, :Allocation, :balance,gen)
end



