using Mimi
using Distributions

include("lib/datastore.jl")
include("watercostdata.jl")

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
    waterfromsupersource = Parameter(index=[regions,time], unit="1000 m^3")
    watergw = Variable(index=[regions, time], unit="1000 m^3")

    # The cost in USD / 1000 m^3 of extraction and treatment cost
    unitgwcost = Parameter(index=[regions,time], unit="\$/1000 m^3")
    unitswcost = Parameter(index=[canals,time], unit="\$/1000 m^3")
    swcost=Variable(index=[regions,time], unit="\$")
    unitsupercost = Parameter(unit="\$/1000 m^3")
    cost=Variable(index=[regions,time], unit="\$")
    # Total cost for eachs county

    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time], unit="1000 m^3")
    # Combination across all canals routing return flow from the counties
    swreturn = Variable(index=[regions, time], unit="1000 m^3")
    totaluse=Parameter(index=[time],unit="1000m^3")
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
function run_timestep(c::Allocation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    # Surface water calculations
    v.swsupply[:, tt] = zeros(numcounties)
    v.swreturn[:, tt] = zeros(numcounties)
    v.swcost[:,tt] = zeros(numcounties)
    for pp in 1:nrow(draws)
        regionids = regionindex(draws, pp)
        rr = findfirst(regionindex(masterregions, :) .== regionids)
        if rr > 0
            v.swsupply[rr, tt] += p.withdrawals[pp, tt]
            v.swreturn[rr, tt] += p.returns[pp, tt]
            v.swcost[rr, tt] += p.withdrawals[pp, tt]*p.unitswcost[pp,tt]
        end
        v.copy_withdrawals[pp, tt] = p.withdrawals[pp, tt]
        v.copy_returns[pp, tt] = p.returns[pp, tt]
    end

    for rr in d.regions
        v.watergw[rr,tt] = p.waterfromgw[rr,tt]
        v.waterallocated[rr,tt] = p.waterfromgw[rr,tt]+p.waterfromsupersource[rr,tt] + v.swsupply[rr, tt]
        v.cost[rr, tt] = p.waterfromgw[rr,tt]*p.unitgwcost[rr,tt]+v.swcost[rr,tt] +p.waterfromsupersource[rr,tt]*p.unitsupercost
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


    # Check if there are saved withdrawals and return flows (from optimize-surface)

   allocation[:unitgwcost] = repeat(aquiferextractioncost, outer = [1,numsteps])+0.1;
   allocation[:unitswcost] = repeat(canalextractioncost, outer = [1,numsteps])+0.1;
   allocation[:unitsupercost] = 1e6
   totaluse=ones(m.indices_counts[:time])
   allocation[:totaluse]=totaluse*7.820581169848508e6 #max total annual water use from simulation
    if config["dataset"] == "three"
	allocation[:withdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:returns] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:waterfromgw] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    	allocation[:waterfromsupersource] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    else
        recorded = getfilteredtable("extraction/USGS-2010.csv")

	allocation[:withdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
	allocation[:returns] = cached_fallback("extraction/returns", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
	allocation[:waterfromgw] = cached_fallback("extraction/waterfromgw", () -> repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"], outer=[1,numsteps])) #zeros(m.indices_counts[:regions], m.indices_counts[:time]));
        #allocation[:waterfromgw] =convert(Array,readtable(datapath("extraction/gw1.csv")))
    	allocation[:waterfromsupersource] = cached_fallback("extraction/supersource", () -> zeros(m.indices_counts[:regions], m.indices_counts[:time]));
    end

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

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromgw, (rr, tt) -> 1.)
end

function grad_allocation_cost_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromgw, (rr, tt) -> m.parameters[:unitgwcost].values[rr,tt])
end

function grad_allocation_cost_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromsupersource, (rr, tt) -> 10000.)
end

function grad_allocation_cost_withdrawals(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr > 0
                A[rr, pp] = m.parameters[:unitswcost].values[pp]
            end
        end
    end
    roomintersect(m, :Allocation, :cost, :withdrawals, generate)
end

function grad_allocation_balance_withdrawals(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
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
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :returnbalance, :returns, generate)
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
			gen(rr, tt) = 1. * (rr > 1)
		elseif optimtype == true
			gen(rr, tt) = 2. * (rr > 1)
		end
	        hallsingle(m, :Allocation, :balance, gen)
    else
          recorded = getfilteredtable("extraction/USGS-2010.csv")
		# MISSING HERE BREAKDOWN IN FUNCTION OF WHAT WE WANT TO OPTIMIZE
		if optimtype == false
			gen(rr, tt) = config["timestep"] * recorded[rr, :TO_SW] * 1383. / 12
		elseif optimtype == true
			gen(rr, tt) = config["timestep"] * recorded[rr, :TO_To] * 1383. / 12
		end
		hallsingle(m, :Allocation, :balance, gen)
    end
end

function grad_allocation_returnbalance_waterreturn(m::Model)
    roomdiagonal(m, :Allocation, :returnbalance, :waterreturn, (rr, tt) -> 1.)
end




function grad_allocation_totaluse_waterfromgw(m::Model)    #STATE LEVEL CONSTRAINT
    function generate(A,tt)
        A[:] = 1
    end
    roomintersect(m,:Allocation, :totaluse, :waterfromgw,generate)
end


function grad_allocation_totaluse_withdrawals(m::Model)    #STATE LEVEL CONSTRAINT
    function generate(A,tt)
        A[:] = 1
    end
    roomintersect(m,:Allocation, :totaluse, :withdrawals,generate)
end


function constraintoffset_allocation_totaluse(m::Model) #STATE LEVEL CONSTRAINT
    gen(tt)=(7.820581169848508e6)*2
    hallsingle(m, :Allocation, :totaluse,gen)
end



function constraintoffset_allocation_otherdemand(m::Model)
    other=readtable(datapath("other.csv"))
    gen(rr,tt)=other[rr,:x1]
    hallsingle(m, :Allocation, :balance,gen)
end



