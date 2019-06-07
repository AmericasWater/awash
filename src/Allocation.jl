## Water Allocation Component
#
# Determines how aggregate water demands per region can be satisfied
# by available surface, ground, and purchased water resources.
#
# The allocation module takes as parameters the withdrawals from each gauge and the volumes extracted in each aquifer. For each county and at each timestep, the component computes the amount of water allocated per source type and in total. The component also describes the return flows (the water used by the different sectors and returned to the surface network.

using Mimi
using Distributions

include("lib/datastore.jl")
include("lib/watercostdata.jl")

@defcomp Allocation begin
    regions = Index()
    aquifers = Index()
    canals = Index()
    scenarios = Index()

    # Water demand aggregated accross all sectors per region
    watertotaldemand = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    # SUPPLY
    # How much to send from each gauge to each county - set by optimization
    swwithdrawals = Parameter(index=[canals, scenarios, time], unit="1000 m^3")
    copy_swwithdrawals = Variable(index=[canals, scenarios, time], unit="1000 m^3")
    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    # Groundwater extracted from each aquifer
    gwextraction = Parameter(index=[aquifers, scenarios, time], unit="1000 m^3")
    copy_gwextraction = Variable(index=[aquifers, scenarios, time], unit="1000 m^3")
    # Groundwater supplied per region
    gwsupply = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    # Supersource supplied per region
    supersourcesupply = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    copy_supersourcesupply = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    # Total supply per region
    totalsupply = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    # Difference between totalsupply and watertotaldemand
    balance = Variable(index=[regions, scenarios , time], unit="1000 m^3")

    """
    Sums the water from various sources and computes the cost
    """
    function run_timestep(p, v, d, tt)
        for ss in d.scenarios
            # Surface water calculations
            v.swsupply[:, ss, tt] = zeros(numcounties)
            for pp in 1:nrow(draws)
                regionids = regionindex(draws, pp)
                rr = findfirst(regionindex(masterregions, :) .== regionids)
                if rr != nothing
                    v.swsupply[rr, ss, tt] += p.swwithdrawals[pp, ss, tt]
                end
                v.copy_swwithdrawals[pp, ss, tt] = p.swwithdrawals[pp, ss, tt]
            end

            for rr in d.regions
                aa = rr
                v.copy_gwextraction[aa, ss, tt] = p.gwextraction[aa, ss, tt]
                v.gwsupply[rr, ss, tt] = p.gwextraction[aa, ss, tt]
                v.copy_supersourcesupply[rr, ss, tt] = p.supersourcesupply[rr, ss, tt]
                v.totalsupply[rr, ss, tt] = v.swsupply[rr, ss, tt] + v.gwsupply[rr, ss, tt] + v.copy_supersourcesupply[rr, ss, tt]
                v.balance[rr, ss, tt] = v.totalsupply[rr, ss, tt] - p.watertotaldemand[rr, ss, tt]
            end
        end
    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    allocation = add_comp!(m, Allocation);
    allocation[:watertotaldemand] = zeros(dim_count(m, :regions), numscenarios, dim_count(m, :time));
    # allocation[:watertotaldemand] .= 7.820581169848508e6 #max total annual water use from simulation

    # Check if there are saved withdrawals (from optimize-surface)
    if config["dataset"] == "three"
	allocation[:swwithdrawals] = zeros(dim_count(m, :canals), dim_count(m, :scenarios), dim_count(m, :time));
    	allocation[:gwextraction] = zeros(dim_count(m, :regions), dim_count(m, :scenarios), dim_count(m, :time));
    	allocation[:supersourcesupply] = zeros(dim_count(m, :regions), dim_count(m, :scenarios), dim_count(m, :time));
    else
        recorded = knowndf("exogenous-withdrawals")

	allocation[:swwithdrawals] = cached_fallback("extraction/withdrawals", () -> zeros(dim_count(m, :canals), dim_count(m, :scenarios), dim_count(m, :time)))
	allocation[:gwextraction] = cached_fallback("extraction/waterfromgw", () -> repeat(convert(Vector, recorded[:, :TO_GW]) * 1383. / 12. *config["timestep"], outer=[1, dim_count(m, :scenarios), dim_count(m, :time)]))
    	allocation[:supersourcesupply] = cached_fallback("extraction/supersource", () -> zeros(dim_count(m, :regions), dim_count(m, :scenarios), dim_count(m, :time)));
    end

    allocation
end

"""
"""

function makeconstraintdemandmet(aa, tt)
    # The constraint function
    function constraint(model)
       m.components[:Allocation].Parameters.watertotaldemand[aa,:,tt] - m.components[:Allocation].Variables.waterallocated[aa,:,tt]
    end
end

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :gwextraction, 1.)
end

function grad_allocation_balance_supersourcesupply(m::Model)
    roomdiagonal(m, :Allocation, :balance, :supersourcesupply, 1.)
end

function grad_allocation_balance_swwithdrawals(m::Model)
    function generate(A)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr != nothing
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :balance, :swwithdrawals, generate, [:scenarios, :time], [:scenarios, :time])
end

function constraintoffset_allocation_recordedtotal(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    if demandmodel == nothing
        constraintoffset_allocation_recordedbalance(m, includegw)
    else
        hallvalues(m, :Allocation, :balance, demandmodel[:WaterDemand, :totaldemand])
    end
end

function constraintoffset_allocation_recordedbalance(m::Model, optimtype)
    if config["dataset"] == "three"
	if optimtype == false
	    genuu(rr, ss, tt) = 1. * (rr > 1)
	else
	    genuu(rr, ss, tt) = 2. * (rr > 1)
	end
	hallsingle(m, :Allocation, :balance, genuu)
    else
        recorded = knowndf("exogenous-withdrawals")
	# MISSING HERE BREAKDOWN IN FUNCTION OF WHAT WE WANT TO OPTIMIZE
	gen(rr, ss, tt) = config["timestep"] * (optimtype ? recorded[rr, :TO_To] : recorded[rr, :TO_SW]) * 1383. / 12
	hallsingle(m, :Allocation, :balance, gen)
    end
end


function grad_allocation_watertotaldemand_waterfromgw(m::Model)    #STATE LEVEL CONSTRAINT
    function generate(A,tt)
        A[:] = 1
    end
    roomintersect(m,:Allocation, :watertotaldemand, :waterfromgw,generate)
end


function grad_allocation_watertotaldemand_withdrawals(m::Model)    #STATE LEVEL CONSTRAINT
    function generate(A,tt)
        A[:] = 1
    end
    roomintersect(m, :Allocation, :watertotaldemand, :withdrawals, generate)
end


function constraintoffset_allocation_watertotaldemand(m::Model) #STATE LEVEL CONSTRAINT
    gen(tt)=(7.820581169848508e6)*2
    hallsingle(m, :Allocation, :watertotaldemand, gen)
end



function constraintoffset_allocation_otherdemand(m::Model)
    other = readtable(datapath("other.csv"))
    gen(rr, ss, tt)=other[rr,:x1]
    hallsingle(m, :Allocation, :balance, gen)
end
