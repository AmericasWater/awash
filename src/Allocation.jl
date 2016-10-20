# The allocation module takes as parameters the withdrawals from each gauge and the volumes extracted in each aquifer. For each county and at each timestep, the component computes the amount of water allocated per source type and in total. The component also describes the return flows (the water used by the different sectors and returned to the surface network. 

using Mimi
using Distributions

include("lib/datastore.jl")

@defcomp Allocation begin
    regions = Index()
    aquifers = Index()
    canals = Index()

    # WATER DEMAND aggregated accross all sectors per region
    watertotaldemand = Parameter(index=[regions, time], unit="1000 m^3")

    # SUPPLY
    # How much to send from each gauge to each county - set by optimization
    swwithdrawals = Parameter(index=[canals, time], unit="1000 m^3")
    copy_swwithdrawals = Variable(index=[canals, time], unit="1000 m^3")
    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time], unit="1000 m^3")
    
    # Groundwater extracted from each aquifer 
    gwextraction = Parameter(index=[aquifers, time], unit="1000 m^3")
    copy_gwextraction = Variable(index=[aquifers, time], unit="1000 m^3")
    # Groundwater supplied per region
    gwsupply = Variable(index=[regions, time], unit="1000 m^3")
    
    # Supersource supplied per region
    supersourcesupply = Parameter(index=[regions,time], unit="1000 m^3")
    copy_supersourcesupply = Variable(index=[regions,time], unit="1000 m^3")
    
    # Total supply per region
    totalsupply = Variable(index=[regions, time], unit="1000 m^3")
    # Difference between totalsupply and watertotaldemand
    balance = Variable(index=[regions, time], unit="1000 m^3")
    
    # RETURN FLOWS
    # How much is returned to each withdrawal source - set by optimization
    returns = Parameter(index=[canals, time], unit="1000 m^3")
    copy_returns = Variable(index=[canals, time], unit="1000 m^3")
    # Combination across all canals routing return flow from the counties
    waterreturn = Parameter(index=[regions, time], unit="1000 m^3")
    swreturn = Variable(index=[regions, time], unit="1000 m^3")
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
    for pp in 1:nrow(draws)
        fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
        rr = findfirst(mastercounties[:fips] .== fips)
        if rr > 0
            v.swsupply[rr, tt] += p.swwithdrawals[pp, tt]
        
	    v.swreturn[rr, tt] += p.returns[pp, tt]
        end
        v.copy_swwithdrawals[pp, tt] = p.swwithdrawals[pp, tt]
        v.copy_returns[pp, tt] = p.returns[pp, tt]
    end

    for rr in d.regions
        aa = rr
	v.copy_gwextraction[aa,tt] = p.gwextraction[aa,tt]
	v.gwsupply[rr,tt] = p.gwextraction[aa,tt]
	v.copy_supersourcesupply[rr,tt] = p.supersourcesupply[rr,tt]
	v.totalsupply[rr,tt] = v.swsupply[rr,tt] + v.gwsupply[rr,tt] + v.copy_supersourcesupply[rr,tt]

        v.balance[rr, tt] = v.totalsupply[rr, tt] - p.watertotaldemand[rr, tt]
        v.returnbalance[rr, tt] = v.swreturn[rr, tt] - p.waterreturn[rr, tt]
    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    allocation = addcomponent(m, Allocation);

    # Check if there are saved withdrawals and return flows (from optimize-surface)
    if config["netset"] == "three"
    	allocation[:swwithdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:returns] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:gwextraction] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    	allocation[:supersourcesupply] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    else
	    allocation[:swwithdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
	    allocation[:returns] = cached_fallback("extraction/returns", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
	    allocation[:gwextraction] = cached_fallback("extraction/waterfromgw", () -> zeros(m.indices_counts[:aquifers], m.indices_counts[:time]));
	    allocation[:supersourcesupply] = cached_fallback("extraction/supersource", () -> zeros(m.indices_counts[:regions], m.indices_counts[:time]));
    end

    allocation
end

"""
"""

function makeconstraintdemandmet(aa, tt)
    # The constraint function
    function constraint(model)
       m.components[:Allocation].Parameters.watertotaldemand[aa,tt] - m.components[:Allocation].Variables.waterallocated[aa,tt]
    end
end

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :gwextraction, (rr, tt) -> 1.)
end

function grad_allocation_balance_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :balance, :supersourcesupply, (rr, tt) -> 1.)
end



function grad_allocation_balance_swwithdrawals(m::Model)
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

    roomintersect(m, :Allocation, :balance, :swwithdrawals, generate)
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
        	recorded = readtable(datapath("extraction/USGS-2010.csv"))
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
