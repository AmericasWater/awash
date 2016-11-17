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
    waterfromsw = Parameter(index=[regions, time], unit="1000 m^3")
    waterfromreservoir = Parameter(index=[regions,time], unit="1000 m^3")
    waterfromsupersource = Parameter(index=[regions,time], unit="1000 m^3")
    watergw = Variable(index=[regions, time], unit="1000 m^3")
    waterreservoir = Variable(index=[regions,time], unit="1000 m^3")

    # The cost in USD / 1000 m^3 of extraction 
    unitgwextractioncost = Parameter(index=[aquifers, time], unit="\$/1000 m^3")
    unitswextractioncost = Parameter(index=[canals, time], unit="\$/1000 m^3")
    unitsupersourcecost = Parameter(unit="\$/1000 m^3")
    
    # Total water cost for eachs county
    cost = Variable(index=[regions, time], "\$")
    swcost = Variable(index=[regions, time], "\$")

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
function run_timestep(c::Allocation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    # Surface water calculations
    v.swsupply[:, tt] = zeros(numcounties)
    v.swreturn[:, tt] = zeros(numcounties)
    v.swcost[:,tt] = zeros(numcounties)
    for pp in 1:nrow(draws)
        fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
        rr = findfirst(mastercounties[:fips] .== fips)
        if rr > 0
            v.swsupply[rr, tt] += p.withdrawals[pp, tt]
            v.swcost[rr, tt] += p.withdrawals[pp, tt] * p.unitswextractioncost[pp,tt]
            v.swreturn[rr, tt] += p.returns[pp, tt]
        end
        v.copy_withdrawals[pp, tt] = p.withdrawals[pp, tt]
        v.copy_returns[pp, tt] = p.returns[pp, tt]
    end


    for rr in d.regions
        v.watergw[rr,tt] = p.waterfromgw[rr,tt]
        v.waterallocated[rr,tt] = p.waterfromgw[rr,tt]+p.waterfromsupersource[rr,tt] + v.swsupply[rr, tt]
        v.cost[rr, tt] = p.waterfromgw[rr,tt]*p.unitgwextractioncost[rr,tt] + v.swcost[rr,tt] + p.waterfromsupersource[rr,tt]*p.unitsupersourcecost 

        v.balance[rr, tt] = v.waterallocated[rr, tt] - p.watertotaldemand[rr, tt]
        v.returnbalance[rr, tt] = v.swreturn[rr, tt] - p.waterreturn[rr, tt]
       
    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    gwtotal = readtable(joinpath(todata, "Colorado/GW_Total.csv"));
    gwtotal=repeat(sum(convert(Matrix, gwtotal),2)/1000.,outer=[1,numsteps])
    allocation = addcomponent(m, Allocation);
    allocation[:watertotaldemand] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    
    allocation[:unitgwextractioncost] = repeat(aquiferextractioncost, outer = [1,numsteps])+0.1;
    allocation[:unitswextractioncost] = repeat(canalextractioncost, outer = [1,numsteps])+0.1;
    allocation[:unitsupersourcecost] = 1e6 
    #was 0.2*0.1 or 0.001 

    # Check if there are saved withdrawals and return flows (from optimize-surface)
    if config["netset"] == "three"
	    allocation[:withdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:returns] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:waterfromgw] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    	allocation[:waterfromreservoir] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    	allocation[:waterfromsupersource] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    else
        allocation[:withdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
        
        allocation[:returns] = cached_fallback("extraction/returns", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
        allocation[:waterfromgw] = cached_fallback("extraction/waterfromgw", () -> gwtotal);
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
    roomdiagonal(m, :Allocation, :cost, :waterfromgw, (rr, tt) -> m.parameters[:unitgwextractioncost].values[rr,tt])
end

function grad_allocation_cost_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromsupersource, (rr, tt) -> 1e6)
end

## Optional cost for drawing down a river (environmental change)
function grad_allocation_cost_withdrawals(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            fips = draws[pp, :fips] < 10000 ? (draws[pp, :fips] < 10 ? "0000$(draws[pp, :fips])" : "0$(draws[pp, :fips])") : "$(draws[pp, :fips])"
            rr = findfirst(mastercounties[:fips] .== fips)
            if rr > 0
                A[rr, pp] = m.parameters[:unitswextractioncost].values[rr,pp]
            end
        end
    end

    roomintersect(m, :Allocation, :cost, :withdrawals, generate)
end

function grad_allocation_balance_withdrawals(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            fips = draws[pp, :fips] < 10000 ? (draws[pp, :fips] < 10 ? "0000$(draws[pp, :fips])" : "0$(draws[pp, :fips])") : "$(draws[pp, :fips])"
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
            fips = draws[pp, :fips] < 10000 ? (draws[pp, :fips] < 10 ? "0000$(draws[pp, :fips])" : "0$(draws[pp, :fips])") : "$(draws[pp, :fips])"
            rr = findfirst(mastercounties[:fips] .== fips)
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :returnbalance, :returns, generate)
end

function constraintoffset_allocation_recordedtotal(m::Model, includegw::Bool, demandmodel::Union{Model, Void}=nothing)
    if demandmodel == nothing
        println("nothing") 
        constraintoffset_allocation_recordedbalance(m, includegw)
    else
        hallvalues(m, :Allocation, :balance, demandmodel[:WaterDemand, :totaldemand])
    end
end

function constraintoffset_allocation_recordedbalance(m::Model, optimtype)
    if config["netset"] == "three"
		if optimtype == false
			gen(rr, tt) = 1. * (rr > 1)
		elseif optimtype == true
			gen(rr, tt) = 2. * (rr > 1)
		end
	        hallsingle(m, :Allocation, :balance, gen)
    else
		if optimtype
            
            recorded = sum(convert(Matrix,readtable(datapath("Colorado/Total.csv"))),2)
            gen(rr, tt) = recorded[rr, tt] / 1000.
            println("using CO_Total") 
            
            
            #use when using results from optimization
            #recorded1=readtable(datapath("../results/Colorado/totalirrigation1.csv"));
            #recorded2=convert(Matrix,readtable(datapath("Colorado/domestic.csv")))/1000;
            #recorded3=convert(Matrix,readtable(datapath("Colorado/livestock.csv")))/1000;
            #recorded4=convert(Matrix,readtable(datapath("Colorado/mining.csv")))/1000;
            #recorded5=convert(Matrix,readtable(datapath("Colorado/thermo.csv")))/1000;
            gen(rr,tt)=recorded1[rr,tt]+recorded2[rr,tt]+recorded3[rr,tt]+recorded4[rr,tt]+recorded5[rr,tt]
            
		else optimtype
            recorded = repeat(sum(convert(Matrix,readtable(datapath("Colorado/SW_Total.csv"))),2),outer=[1,numsteps])
        	gen(rr, tt) = recorded[rr, tt] / 1000.
            println("using SW_Total")
        end 
		hallsingle(m, :Allocation, :balance, gen)
    end
end

function grad_allocation_returnbalance_waterreturn(m::Model)
    roomdiagonal(m, :Allocation, :returnbalance, :waterreturn, (rr, tt) -> 1.)
end

#function constraintoffset_allocation_waterlimit(m::Model)
#    gen=6488602.6457371
#    hallsingle(m, :Allocation, :waterlimit, gen)
#end 